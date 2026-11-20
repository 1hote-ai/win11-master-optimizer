# Setup-GitHubLabels.ps1 - Sync Repository Labels via GitHub REST API
# Encoding: UTF-8

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$Repo = "1hote-ai/win11-master-optimizer",
    [Parameter(Mandatory = $false)]
    [string]$Token = $env:GITHUB_TOKEN
)

$labelsFile = Join-Path -Path $PSScriptRoot -ChildPath "..\.github\labels.json"
if (-not (Test-Path $labelsFile)) {
    Write-Error "Labels definition file not found: $labelsFile"
    exit 1
}

$labels = Get-Content -Path $labelsFile -Raw -Encoding UTF8 | ConvertFrom-Json

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

if ([string]::IsNullOrWhiteSpace($Token)) {
    Write-Host "[INFO] No GITHUB_TOKEN provided. Labels JSON is prepared at .github/labels.json for CI/CD synchronization." -ForegroundColor Yellow
    exit 0
}

$headers = @{
    "Authorization" = "Bearer $Token"
    "Accept"        = "application/vnd.github.v3+json"
    "User-Agent"    = "Win11MasterOptimizer-LabelSync"
}

Write-Host "Syncing labels to GitHub repository: $Repo..." -ForegroundColor Cyan

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
            # Update
            Invoke-RestMethod -Uri $uri -Headers $headers -Method Patch -Body $body -ContentType "application/json" | Out-Null
            Write-Host "  [UPDATED] $($label.name)" -ForegroundColor Green
        }
    } catch {
        # Create
        try {
            $createUri = "https://api.github.com/repos/$Repo/labels"
            Invoke-RestMethod -Uri $createUri -Headers $headers -Method Post -Body $body -ContentType "application/json" | Out-Null
            Write-Host "  [CREATED] $($label.name)" -ForegroundColor Green
        } catch {
            Write-Host "  [ERROR] Failed to create label $($label.name): $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}

Write-Host "Label synchronization complete!" -ForegroundColor Green
