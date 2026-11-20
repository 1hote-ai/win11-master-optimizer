<#
.SYNOPSIS
    Windows 11 Master Optimizer - Fast Web Bootstrap Loader
    Usage:
        irm https://raw.githubusercontent.com/1hote-ai/win11-master-optimizer/launch/preparation/boot.ps1 | iex
#>
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$ErrorActionPreference = 'Stop'

# Auto-Elevation check
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "[UAC] Запрос прав Администратора..." -ForegroundColor Yellow
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command `"& { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; irm https://raw.githubusercontent.com/1hote-ai/win11-master-optimizer/launch/preparation/boot.ps1 | iex }`"" -Verb RunAs
    exit
}

$zipUrl = "https://github.com/1hote-ai/win11-master-optimizer/archive/refs/heads/launch/preparation.zip"
$tempZip = Join-Path -Path $env:TEMP -ChildPath "win11opt_web.zip"
$extractDir = Join-Path -Path $env:TEMP -ChildPath "win11opt_live"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "   WINDOWS 11 MASTER OPTIMIZER - WEB BOOTSTRAP           " -ForegroundColor White
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "-> Загрузка релизного дистрибутива с GitHub..." -ForegroundColor Cyan

Invoke-WebRequest -Uri $zipUrl -OutFile $tempZip -UseBasicParsing

if (Test-Path $extractDir) {
    Remove-Item -Path $extractDir -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host "-> Распаковка компонентов..." -ForegroundColor Cyan
Expand-Archive -Path $tempZip -DestinationPath $extractDir -Force

Write-Host "-> Разблокировка файлов (Unblock-File)..." -ForegroundColor Cyan
Get-ChildItem -Path $extractDir -Recurse | Unblock-File -ErrorAction SilentlyContinue

$rootFolder = Get-ChildItem -Path $extractDir -Directory | Select-Object -First 1
if ($rootFolder) {
    Set-Location $rootFolder.FullName
    $mainScript = Join-Path -Path $rootFolder.FullName -ChildPath "Win11Optimizer.ps1"
    Write-Host "-> Запуск Windows 11 Master Optimizer...`n" -ForegroundColor Green
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $mainScript
} else {
    Write-Error "Ошибка: распакованная папка проекта не найдена в $extractDir"
}
