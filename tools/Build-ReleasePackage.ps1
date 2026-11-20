# Build-ReleasePackage.ps1 - Automated Release Packaging and Checksum Generation
# Encoding: UTF-8

[CmdletBinding()]
param(
    [string]$Version = "v0.1.0-beta",
    [string]$OutputDir = ""
)

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if ([string]::IsNullOrWhiteSpace($scriptDir)) {
    $scriptDir = $PSScriptRoot
}
if ([string]::IsNullOrWhiteSpace($scriptDir)) {
    $scriptDir = (Get-Location).Path
}

$projectRoot = (Resolve-Path (Join-Path -Path $scriptDir -ChildPath "..")).Path

if ([string]::IsNullOrWhiteSpace($OutputDir)) {
    $OutputDir = Join-Path -Path $projectRoot -ChildPath "dist"
}

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "   BUILDING RELEASE ARCHIVE FOR WIN11 MASTER OPTIMIZER    " -ForegroundColor White
Write-Host "   Version: $Version                                      " -ForegroundColor White
Write-Host "==========================================================" -ForegroundColor Cyan

# 1. Verification of Automated Tests before packaging
Write-Host "`n[Step 1/5] Executing pre-packaging automated test suite..." -ForegroundColor Cyan
$testScript = Join-Path -Path $projectRoot -ChildPath "Test-Win11Optimizer.ps1"
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $testScript
if ($LASTEXITCODE -ne 0) {
    Write-Error "Automated test suite failed with exit code $LASTEXITCODE! Packaging aborted."
    exit 1
}
Write-Host "  [OK] All smoke and integrity tests passed successfully." -ForegroundColor Green

# 2. Prepare Distribution Directory
Write-Host "`n[Step 2/5] Preparing output directory: $OutputDir..." -ForegroundColor Cyan
if (-not (Test-Path $OutputDir)) {
    New-Item -Path $OutputDir -ItemType Directory -Force | Out-Null
}

$stagingDir = Join-Path -Path $OutputDir -ChildPath "win11-master-optimizer-$Version"
if (Test-Path $stagingDir) {
    Remove-Item -Path $stagingDir -Recurse -Force
}
New-Item -Path $stagingDir -ItemType Directory -Force | Out-Null

# 3. Copy clean release payload (excluding personal backups and reports)
Write-Host "`n[Step 3/5] Staging clean payload files..." -ForegroundColor Cyan

$itemsToCopy = @(
    "Win11Optimizer.ps1",
    "Test-Win11Optimizer.ps1",
    "Start.bat",
    "Start-Optimizer.bat",
    "Запустить Оптимизатор.bat",
    "LICENSE",
    "README.md",
    "README.ru.md",
    "CONTRIBUTING.md",
    "SECURITY.md",
    "CHANGELOG.md",
    "ROADMAP.md",
    "SUPPORT.md",
    ".gitignore"
)

foreach ($item in $itemsToCopy) {
    $src = Join-Path -Path $projectRoot -ChildPath $item
    if (Test-Path $src) {
        Copy-Item -Path $src -Destination $stagingDir -Force
        Write-Host "  -> Staged: $item" -ForegroundColor Gray
    }
}

# Copy directories
Copy-Item -Path (Join-Path -Path $projectRoot -ChildPath "Modules") -Destination $stagingDir -Recurse -Force
Copy-Item -Path (Join-Path -Path $projectRoot -ChildPath "docs") -Destination $stagingDir -Recurse -Force
Remove-Item -Path (Join-Path -Path $stagingDir -ChildPath "docs\RELEASE_NOTES_*.md") -Force -ErrorAction SilentlyContinue
Copy-Item -Path (Join-Path -Path $projectRoot -ChildPath "assets") -Destination $stagingDir -Recurse -Force
Copy-Item -Path (Join-Path -Path $projectRoot -ChildPath ".github") -Destination $stagingDir -Recurse -Force
Copy-Item -Path (Join-Path -Path $projectRoot -ChildPath "tools") -Destination $stagingDir -Recurse -Force

# Create clean empty Backups and Reports folders with .gitkeep
$stageBackups = Join-Path -Path $stagingDir -ChildPath "Backups"
$stageReports = Join-Path -Path $stagingDir -ChildPath "Reports"
New-Item -Path $stageBackups -ItemType Directory -Force | Out-Null
New-Item -Path $stageReports -ItemType Directory -Force | Out-Null
Set-Content -Path (Join-Path -Path $stageBackups -ChildPath ".gitkeep") -Value "" -Encoding UTF8
Set-Content -Path (Join-Path -Path $stageReports -ChildPath ".gitkeep") -Value "" -Encoding UTF8

# 4. Create ZIP archive
Write-Host "`n[Step 4/5] Creating release ZIP archive..." -ForegroundColor Cyan
$zipFile = Join-Path -Path $OutputDir -ChildPath "win11-master-optimizer-$Version.zip"
if (Test-Path $zipFile) {
    Remove-Item -Path $zipFile -Force
}

Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::CreateFromDirectory($stagingDir, $zipFile, [System.IO.Compression.CompressionLevel]::Optimal, $false)
Write-Host "  [OK] Release ZIP created: $zipFile" -ForegroundColor Green

# 5. Compute SHA-256 Checksum
Write-Host "`n[Step 5/5] Computing SHA-256 checksum..." -ForegroundColor Cyan
$sha256 = (Get-FileHash -Path $zipFile -Algorithm SHA256).Hash
$checksumFile = "$zipFile.sha256"
Set-Content -Path $checksumFile -Value "$sha256 *win11-master-optimizer-$Version.zip" -Encoding UTF8

Write-Host "==========================================================" -ForegroundColor Green
Write-Host "   RELEASE PACKAGE SUCCESSFULLY BUILT                     " -ForegroundColor White
Write-Host "   Archive:  $zipFile                                     " -ForegroundColor White
Write-Host "   Size:     $([math]::Round((Get-Item $zipFile).Length / 1KB, 2)) KB" -ForegroundColor White
Write-Host "   SHA-256:  $sha256                                      " -ForegroundColor Yellow
Write-Host "==========================================================" -ForegroundColor Green

# Cleanup staging directory
Remove-Item -Path $stagingDir -Recurse -Force

return [PSCustomObject]@{
    ZipPath   = $zipFile
    Sha256    = $sha256
    Version   = $Version
    Success   = $true
}
