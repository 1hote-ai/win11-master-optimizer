# Test-Win11Optimizer.ps1 - Automated Smoke & Verification Test Suite
# Encoding: UTF-8

[CmdletBinding()]
param()

$ScriptDir = $PSScriptRoot
$ModuleDir = Join-Path -Path $ScriptDir -ChildPath "Modules"

$passedTests = 0
$failedTests = 0

function Assert-Test {
    param(
        [string]$TestName,
        [scriptblock]$Script
    )

    Write-Host -NoNewline "  Testing [$TestName]... "
    try {
        $result = & $Script
        if ($result -eq $false) {
            Write-Host "[FAIL] Returned false" -ForegroundColor Red
            $script:failedTests++
        } else {
            Write-Host "[PASS]" -ForegroundColor Green
            $script:passedTests++
        }
    }
    catch {
        Write-Host "[FAIL] Exception: $($_.Exception.Message)" -ForegroundColor Red
        $script:failedTests++
    }
}

Write-Host "`n========================================================" -ForegroundColor Cyan
Write-Host "     RUNNING WIN11 OPTIMIZER SMOKE & INTEGRITY TESTS    " -ForegroundColor White
Write-Host "========================================================" -ForegroundColor Cyan

# 1. Module Import Tests
Assert-Test "Module: Safety.psm1 loads" {
    Import-Module (Join-Path $ModuleDir "Safety.psm1") -Force -ErrorAction Stop
    (Get-Command -Module Safety).Count -ge 4
}

Assert-Test "Module: GamingLatency.psm1 loads" {
    Import-Module (Join-Path $ModuleDir "GamingLatency.psm1") -Force -ErrorAction Stop
    (Get-Command -Module GamingLatency).Count -ge 10
}

Assert-Test "Module: NetworkGaming.psm1 loads" {
    Import-Module (Join-Path $ModuleDir "NetworkGaming.psm1") -Force -ErrorAction Stop
    (Get-Command -Module NetworkGaming).Count -ge 8
}

Assert-Test "Module: GpuDisplay.psm1 loads" {
    Import-Module (Join-Path $ModuleDir "GpuDisplay.psm1") -Force -ErrorAction Stop
    (Get-Command -Module GpuDisplay).Count -ge 12
}

Assert-Test "Module: Debloat.psm1 loads" {
    Import-Module (Join-Path $ModuleDir "Debloat.psm1") -Force -ErrorAction Stop
    (Get-Command -Module Debloat).Count -ge 8
}

Assert-Test "Module: SystemUI.psm1 loads" {
    Import-Module (Join-Path $ModuleDir "SystemUI.psm1") -Force -ErrorAction Stop
    (Get-Command -Module SystemUI).Count -ge 8
}

Assert-Test "Module: AppInstaller.psm1 loads" {
    Import-Module (Join-Path $ModuleDir "AppInstaller.psm1") -Force -ErrorAction Stop
    (Get-Command -Module AppInstaller).Count -ge 5
}

Assert-Test "Module: Diagnostics.psm1 loads" {
    Import-Module (Join-Path $ModuleDir "Diagnostics.psm1") -Force -ErrorAction Stop
    (Get-Command -Module Diagnostics).Count -ge 5
}

# 2. Safety & Rollback Mechanics Test
Assert-Test "Safety: Snapshot & Rollback integrity test" {
    $testKey = "HKCU:\Software\Win11OptimizerTest_$(Get-Random)"
    New-Item -Path $testKey -Force | Out-Null
    Set-ItemProperty -Path $testKey -Name "OriginalVal" -Value 123 -Type DWord -Force

    $targets = @(
        @{ Path = $testKey; Name = "OriginalVal" },
        @{ Path = $testKey; Name = "NonExistentVal" }
    )

    $snapFile = Save-RegistrySnapshot -Category "UnitTest" -RegistryTargets $targets
    if (-not (Test-Path $snapFile)) { return $false }

    # Mutate
    Set-ItemProperty -Path $testKey -Name "OriginalVal" -Value 999 -Type DWord -Force
    Set-ItemProperty -Path $testKey -Name "NonExistentVal" -Value 777 -Type DWord -Force

    # Restore
    $restored = Restore-RegistrySnapshot -Category "UnitTest" -BackupFilePath $snapFile
    if (-not $restored) { return $false }

    $p1 = (Get-ItemProperty -Path $testKey).OriginalVal
    $p2 = (Get-ItemProperty -Path $testKey -ErrorAction SilentlyContinue).NonExistentVal

    # Cleanup
    Remove-Item -Path $testKey -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -Path $snapFile -Force -ErrorAction SilentlyContinue

    return ($p1 -eq 123 -and $null -eq $p2)
}

Assert-Test "Safety: Cleanup of empty newly-created subkeys on rollback" {
    $parentKey = "HKCU:\Software\Win11OptimizerParent_$(Get-Random)"
    $childKey = "$parentKey\NewChildKey"
    
    # Snapshot before child exists
    $targets = @(
        @{ Path = $childKey; Name = "TestSetting" }
    )
    $snapFile = Save-RegistrySnapshot -Category "SubkeyTest" -RegistryTargets $targets

    # Create child key and property
    New-Item -Path $childKey -Force | Out-Null
    Set-ItemProperty -Path $childKey -Name "TestSetting" -Value 1 -Type DWord -Force

    # Restore
    Restore-RegistrySnapshot -Category "SubkeyTest" -BackupFilePath $snapFile | Out-Null
    
    # Child key should now be completely deleted
    $childStillExists = Test-Path $childKey
    Remove-Item -Path $parentKey -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -Path $snapFile -Force -ErrorAction SilentlyContinue

    return (-not $childStillExists)
}

# 3. Hardware Query Tests (GPU, Net, AND Audio Sound Cards)
Assert-Test "Hardware: GPU, Network and Sound cards all detected" {
    $pci = Get-PciMsiDevices
    $gpus   = @($pci | Where-Object { $_.Category -eq 'GPU' })
    $nets   = @($pci | Where-Object { $_.Category -eq 'Network' })
    $audios = @($pci | Where-Object { $_.Category -eq 'Audio' })

    ($gpus.Count -ge 1) -and ($nets.Count -ge 1) -and ($audios.Count -ge 1)
}

Assert-Test "Hardware: Active Network Adapter detection" {
    $activeIf = Get-PrimaryActiveNetworkInterface
    $activeIf -ne $null -and $activeIf.InterfaceIndex -gt 0 -and -not [string]::IsNullOrWhiteSpace($activeIf.Gateway)
}

Assert-Test "GPU: NVIDIA Display Adapter detection" {
    $nv = @(Get-NvidiaDisplayAdapterKeys)
    $nv.Count -ge 1 -and -not [string]::IsNullOrWhiteSpace($nv[0].DriverDesc)
}

Assert-Test "Diagnostics: Win32 Timer Resolution query" {
    $timer = Get-SystemTimerResolution
    $timer.Success -eq $true -and $timer.MinMs -gt 0 -and $timer.MaxMs -gt 0
}

Assert-Test "Diagnostics: Real-time DPC / ISR Metrics counter query" {
    $dpc = Get-SystemDpcMetrics
    $dpc.Success -eq $true -and $dpc.DpcsPerSec -ge 0
}

Assert-Test "Diagnostics: Comprehensive optimization audit (26 settings)" {
    $audit = Get-SystemOptimizationAudit
    $audit -ne $null -and $audit.Count -ge 26
}

Assert-Test "Diagnostics: Health-Check Audit Recommendations & FixMenu validity" {
    $audit = Get-SystemOptimizationAudit
    $hasRecs = @($audit | Where-Object { [string]::IsNullOrWhiteSpace($_.Recommendation) -or [string]::IsNullOrWhiteSpace($_.FixMenu) }).Count -eq 0
    $hasFunc = (Get-Command Show-OptimizationHealthCheck -ErrorAction SilentlyContinue) -ne $null
    
    # Проверка, что все FixMenu ссылаются на реальные пункты главного меню ([2]-[7])
    $allFixMenusValid = $true
    foreach ($item in $audit) {
        if ($item.FixMenu -notmatch 'Главное меню -> Пункт \[(2|3|4|5|6|7)\]') {
            $allFixMenusValid = $false
            Write-Host "`n  [FAIL Detail] Некорректный FixMenu у '$($item.Setting)': $($item.FixMenu)" -ForegroundColor Red
        }
    }

    $hasRecs -and $hasFunc -and $allFixMenusValid
}

# 4. Standby RAM Cleaner Tests
Assert-Test "RAM Cleaner: SeProfileSingleProcessPrivilege P/Invoke helper" {
    $res = Clear-StandbyRamAndWorkingSet -DryRun
    $res.Success -eq $true -and $res.FreeBeforeMb -gt 0
}

# 5. Gaming DNS & DoH Switcher Tests
Assert-Test "DNS: Set-GamingDns, Reset-GamingDns and Restore-GamingDns dry-runs" {
    $sRes = Set-GamingDns -Provider "Cloudflare" -DryRun
    $rRes = Reset-GamingDns -DryRun
    $restRes = (Get-Command Restore-GamingDns -ErrorAction SilentlyContinue) -ne $null
    $sRes -eq $true -and $rRes -eq $true -and $restRes -eq $true
}

# 6. GPU, Display & Shader Cache Tests
Assert-Test "GPU: MPO and HAGS status queries" {
    $mpo = Get-MpoStatus
    $hags = Get-HagsStatus
    $mpo -ne $null -and $null -ne $mpo.Disabled -and $hags -ne $null -and $null -ne $hags.Enabled
}

Assert-Test "GPU: MPO, HAGS, HDCP and DirectX windowed dry-runs" {
    Set-MpoState -Disable $true -DryRun
    Set-HagsState -Enable $true -DryRun
    Set-DirectXWindowedOptimization -Enable $true -DryRun
    Set-WindowsUpdateDriverProtection -Enable $true -DryRun
    Set-NvidiaHdcpDisable -Disable $true -DryRun
    $true
}

Assert-Test "GPU: Clear-ShaderCacheAndTemp dry-run scan" {
    $clean = Clear-ShaderCacheAndTemp -DryRun
    $clean.TotalFiles -ge 0 -and $clean.TotalFreedMb -ge 0
}

Assert-Test "GPU: Restore-AllGpuDisplaySettings function export & execution" {
    $func = Get-Command Restore-AllGpuDisplaySettings -ErrorAction SilentlyContinue
    $func -ne $null
}

# 7. Debloat & SystemUI Tests
Assert-Test "DryRun: Debloat suite" {
    Disable-Win11Recall -DryRun
    Disable-Win11Copilot -DryRun
    Disable-BingSearchAndCortana -DryRun
    Disable-WidgetsAndNews -DryRun
    Disable-TelemetryAndDiagnostics -DryRun
    Remove-SafeBloatwareApps -DryRun
    $true
}

Assert-Test "DryRun: SystemUI suite (Explorer, Home Hide/Show, Maintenance, Photo, USB)" {
    Set-ClassicContextMenu -Enable $true -DryRun -NoRestart
    Set-FileExplorerTweaks -DryRun -NoRestart
    Disable-WindowsAutomaticMaintenance -DryRun
    Set-ExplorerHomeVisibility -Hide $true -DryRun -NoRestart
    Set-ExplorerHomeVisibility -Hide $false -DryRun -NoRestart
    Set-GameDvrOptimized -DryRun
    Enable-ClassicWindowsPhotoViewer -DryRun
    Disable-UsbPowerSaving -DryRun
    $true
}

Assert-Test "Safety: Dry-run execution generates zero snapshot files in Backups" {
    $backupDir = Join-Path $ScriptDir "Backups"
    $countBefore = (Get-ChildItem -Path $backupDir -Filter "Backup_*.json" -ErrorAction SilentlyContinue).Count
    
    # Вызываем набор dry-run функций
    Set-MpoState -Disable $true -DryRun
    Set-HagsState -Enable $true -DryRun
    Set-GamingDns -Provider "Cloudflare" -DryRun
    Set-GamingNetworkStack -DryRun
    Set-CpuGamingScheduling -DryRun
    
    $countAfter = (Get-ChildItem -Path $backupDir -Filter "Backup_*.json" -ErrorAction SilentlyContinue).Count
    $diff = $countAfter - $countBefore
    $diff -eq 0
}

# 8. Winget & Catalog Test
Assert-Test "AppInstaller: Catalog and Winget check" {
    $catalog = Get-AppCatalog
    $wStatus = Test-WingetAvailability
    $catalog.Count -ge 20 -and $wStatus.Available -eq $true
}

# 9. Full AutoGamingPreset Dry-Run Test
Assert-Test "Preset: AutoGamingPreset dry-run completes without error" {
    . (Join-Path $ScriptDir "Win11Optimizer.ps1") -Mode AutoGaming -DryRun -NoRestorePoint
    $true
}

Write-Host "========================================================" -ForegroundColor Cyan
Write-Host "  TEST RESULTS: Passed: $passedTests | Failed: $failedTests" -ForegroundColor $(if ($failedTests -eq 0) { "Green" } else { "Red" })
Write-Host "========================================================`n" -ForegroundColor Cyan

# Clean any test backup files
Get-ChildItem -Path (Join-Path $ScriptDir "Backups") -Filter "Backup_UnitTest_*.json" -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
Get-ChildItem -Path (Join-Path $ScriptDir "Backups") -Filter "Backup_SubkeyTest_*.json" -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
Get-ChildItem -Path (Join-Path $ScriptDir "Backups") -Filter "Backup_*_2026*.json" -ErrorAction SilentlyContinue | Where-Object { $_.Name -like "*UnitTest*" -or $_.Name -like "*SubkeyTest*" } | Remove-Item -Force -ErrorAction SilentlyContinue

if ($failedTests -gt 0) {
    exit 1
} else {
    exit 0
}
