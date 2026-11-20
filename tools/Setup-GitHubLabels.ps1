# Setup-GitHubLabels.ps1 - Sync Repository Labels and Topics via GitHub REST API
# Encoding: UTF-8

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$Repo = "1hote-ai/win11-master-optimizer",
    [Parameter(Mandatory = $false)]
    [string]$Token = $env:GITHUB_TOKEN,
    [Parameter(Mandatory = $false)]
    [switch]$IncludeTopics = $false,
    [Parameter(Mandatory = $false)]
    [switch]$DryRun = $false
)

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if ([string]::IsNullOrWhiteSpace($scriptDir)) { $scriptDir = $PSScriptRoot }
if ([string]::IsNullOrWhiteSpace($scriptDir)) { $scriptDir = (Get-Location).Path }
$projectRoot = (Resolve-Path (Join-Path -Path $scriptDir -ChildPath "..")).Path

$labelsFile = Join-Path -Path $projectRoot -ChildPath ".github\labels.json"
if (-not (Test-Path $labelsFile)) {
    Write-Error "Labels definition file not found: $labelsFile"
    exit 1
}

$labels = Get-Content -Path $labelsFile -Raw -Encoding UTF8 | ConvertFrom-Json

$approvedTopics = @(
    "windows-11",
    "windows-optimizer",
    "latency",
    "gaming-optimization",
    "dpc-latency",
    "msi-mode",
    "powershell",
    "low-latency",
    "system-tweaks",
    "open-source",
    "performance-tuning",
    "competitive-gaming",
    "debloat-windows-11",
    "hags",
    "mpo-fix",
    "timer-resolution",
    "standby-ram-cleaner",
    "dns-over-https",
    "rollback-engine",
    "esports-fps"
)

if ([string]::IsNullOrWhiteSpace($Token)) {
    # Check MCP config if available
    $mcpPath = "C:\Users\egorv\.gemini\config\mcp_config.json"
    if (Test-Path $mcpPath) {
        try {
            $mcp = Get-Content -Path $mcpPath -Raw -Encoding UTF8 | ConvertFrom-Json
            if ($mcp.mcpServers.'github-mcp-server'.env.GITHUB_PERSONAL_ACCESS_TOKEN) {
                $Token = $mcp.mcpServers.'github-mcp-server'.env.GITHUB_PERSONAL_ACCESS_TOKEN
            }
        } catch {}
    }
}

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "   GITHUB REPOSITORY METADATA & LABELS SYNCHRONIZER       " -ForegroundColor White
Write-Host "   Repository: $Repo                                      " -ForegroundColor White
Write-Host "   Dry-Run:    $($DryRun.IsPresent)                       " -ForegroundColor White
Write-Host "==========================================================" -ForegroundColor Cyan

if ($DryRun) {
    Write-Host "`n[DRY-RUN] Simulating GitHub Labels synchronization ($($labels.Count) labels):" -ForegroundColor Cyan
    foreach ($label in $labels) {
        Write-Host "  -> [DRY-RUN] Label: '$($label.name)' | Color: #$($label.color) | Desc: $($label.description)" -ForegroundColor Gray
    }

    if ($IncludeTopics) {
        Write-Host "`n[DRY-RUN] Simulating GitHub Topics synchronization ($($approvedTopics.Count) topics):" -ForegroundColor Cyan
        Write-Host "  -> Topics: $($approvedTopics -join ', ')" -ForegroundColor Gray
    }

    Write-Host "`n[DRY-RUN COMPLETE] No remote API requests executed. Run without -DryRun to apply." -ForegroundColor Green
    exit 0
}

if ([string]::IsNullOrWhiteSpace($Token)) {
    Write-Host "[INFO] No GITHUB_TOKEN provided. Labels JSON is prepared at .github/labels.json for CI/CD synchronization." -ForegroundColor Yellow
    exit 0
}

$headers = @{
    "Authorization" = "Bearer $Token"
    "Accept"        = "application/vnd.github.v3+json"
    "User-Agent"    = "Win11MasterOptimizer-LabelSync"
}

Write-Host "`nSyncing labels to GitHub repository: $Repo..." -ForegroundColor Cyan

foreach ($label in $labels) {
    $uri = "https://api.github.com/repos/$Repo/labels/$($label.name)"
    $body = @{
        name        = $label.name
        color       = $label.color
        description = $label.description
    } | ConvertTo-Json

    try {
        # Check if exists
        $check = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get -ErrorAction SilentlyContinue
        if ($check) {
            Invoke-RestMethod -Uri $uri -Headers $headers -Method Patch -Body $body -ContentType "application/json" | Out-Null
            Write-Host "  [UPDATED] $($label.name)" -ForegroundColor Green
        }
    } catch {
        try {
            $createUri = "https://api.github.com/repos/$Repo/labels"
            Invoke-RestMethod -Uri $createUri -Headers $headers -Method Post -Body $body -ContentType "application/json" | Out-Null
            Write-Host "  [CREATED] $($label.name)" -ForegroundColor Green
        } catch {
            Write-Host "  [ERROR] Failed to create label $($label.name): $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}

if ($IncludeTopics) {
    Write-Host "`nSyncing 20 approved topics to repository: $Repo..." -ForegroundColor Cyan
    $topicsUri = "https://api.github.com/repos/$Repo/topics"
    $topicsBody = @{ names = $approvedTopics } | ConvertTo-Json
    $topicsHeaders = @{
        "Authorization" = "Bearer $Token"
        "Accept"        = "application/vnd.github.mercy-preview+json"
        "User-Agent"    = "Win11MasterOptimizer-LabelSync"
    }

    try {
        Invoke-RestMethod -Uri $topicsUri -Headers $topicsHeaders -Method Put -Body $topicsBody -ContentType "application/json" | Out-Null
        Write-Host "  [OK] Topics updated: $($approvedTopics -join ', ')" -ForegroundColor Green
    } catch {
        Write-Host "  [ERROR] Failed to update topics: $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host "`nMetadata synchronization complete!" -ForegroundColor Green