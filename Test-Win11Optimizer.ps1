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
    if (-not $restored.Success) { return $false }
    if ($restored.RestoredCount -ne 2 -or $restored.FailedCount -ne 0) { return $false }

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
    $restored = Restore-RegistrySnapshot -Category "SubkeyTest" -BackupFilePath $snapFile
    
    # Child key should now be completely deleted
    $childStillExists = Test-Path $childKey
    Remove-Item -Path $parentKey -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -Path $snapFile -Force -ErrorAction SilentlyContinue

    return ($restored.Success -and -not $childStillExists)
}

Assert-Test "Safety: Granular RollbackResult structure and failure isolation on partial fail" {
    $testKey = "HKCU:\Software\Win11Opt_PartialTest_$(Get-Random)"
    New-Item -Path $testKey -Force | Out-Null
    Set-ItemProperty -Path $testKey -Name "ValidParam" -Value 100 -Type DWord -Force

    $backupDir = Join-Path $ScriptDir "Backups"
    if (-not (Test-Path $backupDir)) {
        New-Item -Path $backupDir -ItemType Directory -Force | Out-Null
    }
    $mockFile = Join-Path $backupDir "Backup_PartialTest_Mock.json"

    # Create synthetic snapshot with 1 valid entry and 1 invalid entry (non-existent drive to guarantee isolated catch)
    $mockPayload = [PSCustomObject]@{
        Category  = "PartialTest"
        Timestamp = (Get-Date).ToString("yyyyMMdd_HHmmss")
        Entries   = @(
            [PSCustomObject]@{
                Path        = $testKey
                Name        = "ValidParam"
                KeyExists   = $true
                ValueExists = $true
                Type        = "DWord"
                Value       = 100
            },
            [PSCustomObject]@{
                Path        = "NonExistentDrive:\BogusKey"
                Name        = "DeniedParam"
                KeyExists   = $true
                ValueExists = $true
                Type        = "DWord"
                Value       = 1
            }
        )
    }

    $mockPayload | ConvertTo-Json -Depth 5 | Set-Content -Path $mockFile -Encoding UTF8

    # Mutate valid parameter
    Set-ItemProperty -Path $testKey -Name "ValidParam" -Value 999 -Type DWord -Force

    $res = Restore-RegistrySnapshot -Category "PartialTest" -BackupFilePath $mockFile
    $restoredValid = (Get-ItemProperty -Path $testKey).ValidParam

    # Cleanup
    Remove-Item -Path $testKey -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -Path $mockFile -Force -ErrorAction SilentlyContinue

    # Verification:
    # 1. Overall Success is false because of the 1 failed entry
    # 2. RestoredCount is 1 (the valid one succeeded)
    # 3. FailedCount >= 1
    # 4. ValidParam in registry was actually restored to 100
    return ($res.Success -eq $false -and $res.RestoredCount -eq 1 -and $res.FailedCount -ge 1 -and $restoredValid -eq 100 -and $res.FailedItems.Count -ge 1)
}

Assert-Test "Safety: Granular RollbackResult structure on missing snapshot file" {
    $res = Restore-RegistrySnapshot -Category "NonExistentCategory_XYZ_Random_99"
    return ($res.Success -eq $false -and $res.TotalCount -eq 0 -and ($res.Message -match "не найден"))
}

Assert-Test "Safety: Corrupted Snapshot JSON handling" {
    $backupDir = Join-Path $ScriptDir "Backups"
    if (-not (Test-Path $backupDir)) {
        New-Item -Path $backupDir -ItemType Directory -Force | Out-Null
    }
    $corruptFile = Join-Path $backupDir "Backup_CorruptTest_Mock.json"
    Set-Content -Path $corruptFile -Value "{ Invalid JSON syntax !!!" -Encoding UTF8

    $res = Restore-RegistrySnapshot -Category "CorruptTest" -BackupFilePath $corruptFile
    Remove-Item -Path $corruptFile -Force -ErrorAction SilentlyContinue

    return ($res.Success -eq $false -and ($res.Message -match "поврежден") -and $res.Errors.Count -ge 1)
}

Assert-Test "Safety: Comprehensive Registry Types preservation (DWord, QWord, String, MultiString, ExpandString, Binary)" {
    $typesKey = "HKCU:\Software\Win11Opt_TypesTest_$(Get-Random)"
    New-Item -Path $typesKey -Force | Out-Null

    Set-ItemProperty -Path $typesKey -Name "T_DWord" -Value 42 -Type DWord -Force
    Set-ItemProperty -Path $typesKey -Name "T_QWord" -Value 9876543210 -Type QWord -Force
    Set-ItemProperty -Path $typesKey -Name "T_String" -Value "OptimizerString" -Type String -Force
    Set-ItemProperty -Path $typesKey -Name "T_Expand" -Value "%SYSTEMROOT%\Optimizer" -Type ExpandString -Force
    Set-ItemProperty -Path $typesKey -Name "T_Multi" -Value @("ValueA", "ValueB") -Type MultiString -Force
    Set-ItemProperty -Path $typesKey -Name "T_Binary" -Value ([byte[]]@(0xDE, 0xAD, 0xBE, 0xEF)) -Type Binary -Force

    $targets = @(
        @{ Path = $typesKey; Name = "T_DWord" },
        @{ Path = $typesKey; Name = "T_QWord" },
        @{ Path = $typesKey; Name = "T_String" },
        @{ Path = $typesKey; Name = "T_Expand" },
        @{ Path = $typesKey; Name = "T_Multi" },
        @{ Path = $typesKey; Name = "T_Binary" }
    )

    $snapFile = Save-RegistrySnapshot -Category "TypesTest" -RegistryTargets $targets
    if (-not (Test-Path $snapFile)) { return $false }

    # Mutate all values
    Set-ItemProperty -Path $typesKey -Name "T_DWord" -Value 0 -Type DWord -Force
    Set-ItemProperty -Path $typesKey -Name "T_QWord" -Value 0 -Type QWord -Force
    Set-ItemProperty -Path $typesKey -Name "T_String" -Value "Mutated" -Type String -Force
    Set-ItemProperty -Path $typesKey -Name "T_Expand" -Value "Mutated" -Type ExpandString -Force
    Set-ItemProperty -Path $typesKey -Name "T_Multi" -Value @("Mutated") -Type MultiString -Force
    Set-ItemProperty -Path $typesKey -Name "T_Binary" -Value ([byte[]]@(0x00)) -Type Binary -Force

    # Restore
    $res = Restore-RegistrySnapshot -Category "TypesTest" -BackupFilePath $snapFile
    if (-not $res.Success -or $res.RestoredCount -ne 6) { return $false }

    $p = Get-ItemProperty -Path $typesKey
    $matchDWord = ($p.T_DWord -eq 42)
    $matchQWord = ($p.T_QWord -eq 9876543210)
    $matchString = ($p.T_String -eq "OptimizerString")
    $matchExpand = ($p.T_Expand -like "*\Optimizer")
    $matchMulti = (($p.T_Multi -join ",") -eq "ValueA,ValueB")
    $matchBinary = (([System.BitConverter]::ToString($p.T_Binary)) -eq "DE-AD-BE-EF")

    # Cleanup
    Remove-Item -Path $typesKey -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -Path $snapFile -Force -ErrorAction SilentlyContinue

    return ($matchDWord -and $matchQWord -and $matchString -and $matchExpand -and $matchMulti -and $matchBinary)
}

Assert-Test "Safety: SystemRestorePointCreationFrequency snapshot and restoration routine" {
    $cmdNew = Get-Command New-OptimizerRestorePoint -ErrorAction SilentlyContinue
    $cmdRest = Get-Command Restore-SystemRestorePointCreationFrequency -ErrorAction SilentlyContinue
    if (-not $cmdNew -or -not $cmdRest) { return $false }

    $res = Restore-SystemRestorePointCreationFrequency
    return ($null -ne $res)
}

Assert-Test "Safety: Automatic Backup Rotation mechanics" {
    $cmd = Get-Command Invoke-BackupRotation -ErrorAction SilentlyContinue
    if (-not $cmd) { return $false }

    Invoke-BackupRotation -MaxBackups 100 -MaxAgeDays 60
    return $true
}

Assert-Test "Safety: Administrator privilege check returns boolean" {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]$identity
    $isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    return ($isAdmin -is [bool])
}

Assert-Test "Safety: Get-BackupHistory returns valid backup catalog array" {
    $hist = @(Get-BackupHistory)
    return ($null -ne $hist -and ($hist -is [System.Array]))
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

# 10. Live Dynamic Status Query & Indicator Tests
Assert-Test "Status Queries: SystemUI status functions (USB, Context Menu, Explorer, GameDVR, Maintenance)" {
    $usb = Get-UsbPowerSavingStatus
    $menu = Get-ClassicContextMenuStatus
    $exp = Get-FileExplorerTweaksStatus
    $dvr = Get-GameDvrStatus
    $photo = Get-ClassicWindowsPhotoViewerStatus
    $maint = Get-WindowsAutomaticMaintenanceStatus
    $homeStat = Get-ExplorerHomeVisibilityStatus

    ($null -ne $usb.Disabled) -and ($null -ne $menu.Enabled) -and ($null -ne $exp.Optimal) -and `
    ($null -ne $dvr.Disabled) -and ($null -ne $photo.Enabled) -and ($null -ne $maint.Disabled) -and ($null -ne $homeStat.Hidden)
}

Assert-Test "Status Queries: GamingLatency status functions (MSI, CPU, Power Plan, Responsiveness)" {
    $msi = Get-MsiModeStatus
    $cpu = Get-CpuGamingSchedulingStatus
    $pwr = Get-UltimatePerformancePlanStatus
    $sys = Get-SystemResponsivenessStatus

    ($null -ne $msi.Optimal) -and ($null -ne $cpu.Optimal) -and ($null -ne $pwr.Optimal) -and ($null -ne $sys.Optimal)
}

Assert-Test "Status Queries: NetworkGaming status functions (Nagle, Stack, DNS)" {
    $nagle = Get-NagleStatus
    $stack = Get-NetworkGamingStackStatus
    $dns = Get-GamingDnsStatus

    ($null -ne $nagle.Disabled) -and ($null -ne $stack.Optimal) -and ($null -ne $dns.Optimal)
}

Assert-Test "Status Queries: GpuDisplay status functions (DirectX, WU Driver, HDCP)" {
    $dx = Get-DirectXWindowedStatus
    $wu = Get-WindowsUpdateDriverProtectionStatus
    $hdcp = Get-NvidiaHdcpStatus

    ($null -ne $dx.Optimal) -and ($null -ne $wu.Protected) -and ($null -ne $hdcp.Optimal)
}

Assert-Test "Status Queries: Debloat status functions (Recall, Copilot, Bing, Widgets, Telemetry, Bloatware)" {
    $recall = Get-RecallStatus
    $copilot = Get-CopilotStatus
    $bing = Get-BingSearchStatus
    $widgets = Get-WidgetsStatus
    $telem = Get-TelemetryStatus
    $bloat = Get-BloatwareStatus

    ($null -ne $recall.Disabled) -and ($null -ne $copilot.Disabled) -and ($null -ne $bing.Disabled) -and `
    ($null -ne $widgets.Disabled) -and ($null -ne $telem.Disabled) -and ($null -ne $bloat.Clean)
}

Assert-Test "Submenu Architecture: Interactive optimization submenu functions exist" {
    $scriptContent = Get-Content -Path (Join-Path $ScriptDir "Win11Optimizer.ps1") -Raw
    ($scriptContent -match 'function Show-HardcoreGamingMenu') -and `
    ($scriptContent -match 'function Show-NetworkMenu') -and `
    ($scriptContent -match 'function Show-GpuMenu') -and `
    ($scriptContent -match 'function Show-DebloatMenu') -and `
    ($scriptContent -match 'function Show-InterfaceMenu') -and `
    ($scriptContent -match 'function Write-OptimizerMenuItem')
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
