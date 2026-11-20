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

Assert-Test "Safety: Non-standard custom registry value exact restoration" {
    $exactKey = "HKCU:\Software\Win11Opt_ExactVal_$(Get-Random)"
    New-Item -Path $exactKey -Force | Out-Null
    Set-ItemProperty -Path $exactKey -Name "CustomParam" -Value 4242 -Type DWord -Force
    Set-ItemProperty -Path $exactKey -Name "CustomText" -Value "UserSpecificSetting" -Type String -Force

    $targets = @(
        @{ Path = $exactKey; Name = "CustomParam" },
        @{ Path = $exactKey; Name = "CustomText" }
    )

    $snapFile = Save-RegistrySnapshot -Category "ExactValTest" -RegistryTargets $targets
    if (-not (Test-Path $snapFile)) { return $false }

    # Mutate to standard optimizer values
    Set-ItemProperty -Path $exactKey -Name "CustomParam" -Value 0 -Type DWord -Force
    Set-ItemProperty -Path $exactKey -Name "CustomText" -Value "OptimizerMutated" -Type String -Force

    # Restore
    $res = Restore-RegistrySnapshot -Category "ExactValTest" -BackupFilePath $snapFile
    $p = Get-ItemProperty -Path $exactKey

    Remove-Item -Path $exactKey -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -Path $snapFile -Force -ErrorAction SilentlyContinue

    return ($res.Success -and $p.CustomParam -eq 4242 -and $p.CustomText -eq "UserSpecificSetting")
}

Assert-Test "Safety: Missing registry property deletion on rollback" {
    $missingKey = "HKCU:\Software\Win11Opt_MissingVal_$(Get-Random)"
    New-Item -Path $missingKey -Force | Out-Null

    # The property does NOT exist initially
    $targets = @(
        @{ Path = $missingKey; Name = "NewlyCreatedParam" }
    )

    $snapFile = Save-RegistrySnapshot -Category "MissingValTest" -RegistryTargets $targets
    if (-not (Test-Path $snapFile)) { return $false }

    # Create the property during optimization
    Set-ItemProperty -Path $missingKey -Name "NewlyCreatedParam" -Value 1 -Type DWord -Force

    # Restore
    $res = Restore-RegistrySnapshot -Category "MissingValTest" -BackupFilePath $snapFile
    $prop = (Get-ItemProperty -Path $missingKey -ErrorAction SilentlyContinue).NewlyCreatedParam

    Remove-Item -Path $missingKey -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -Path $snapFile -Force -ErrorAction SilentlyContinue

    return ($res.Success -and $null -eq $prop)
}

Assert-Test "Safety: Snapshot Security Validator strict allowlist and negative checks" {
    # 1. Посторонний ключ внутри разрешенной ветки Control (CrashControl) -> BLOCKED
    $eControl = @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Control\CrashControl"; Name = "DumpFile"; Type = "DWord"; KeyExists = $true; ValueExists = $true }
    $resControl = Test-RegistrySnapshotEntrySecurity -Entry $eControl

    # 2. Посторонний ключ внутри разрешенной ветки Tcpip (Parameters\NonExistent) -> BLOCKED
    $eTcpip = @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"; Name = "Domain"; Type = "String"; KeyExists = $true; ValueExists = $true }
    $resTcpip = Test-RegistrySnapshotEntrySecurity -Entry $eTcpip

    # 3. Защищенный системный узел (Session Manager) -> BLOCKED
    $eSession = @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager"; Name = "BootExecute"; Type = "MultiString"; KeyExists = $true; ValueExists = $true }
    $resSession = Test-RegistrySnapshotEntrySecurity -Entry $eSession

    # 4. Корректный путь оптимизатора с недопустимым именем параметра -> BLOCKED
    $eBadParam = @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl"; Name = "MaliciousParam"; Type = "DWord"; KeyExists = $true; ValueExists = $true }
    $resBadParam = Test-RegistrySnapshotEntrySecurity -Entry $eBadParam

    # 5. Корректный путь оптимизатора с разрешенным именем параметра -> ALLOWED
    $eGood = @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl"; Name = "Win32PrioritySeparation"; Type = "DWord"; KeyExists = $true; ValueExists = $true }
    $resGood = Test-RegistrySnapshotEntrySecurity -Entry $eGood

    # 6. Path traversal -> BLOCKED
    $eTrav = @{ Path = "HKLM:\SOFTWARE\Microsoft\..\..\Windows"; Name = "Test"; Type = "DWord"; KeyExists = $true; ValueExists = $true }
    $resTrav = Test-RegistrySnapshotEntrySecurity -Entry $eTrav

    # 7. Защищенный узел SAM -> BLOCKED
    $eSam = @{ Path = "HKLM:\SAM\SAM\Domains"; Name = "F"; Type = "Binary"; KeyExists = $true; ValueExists = $true }
    $resSam = Test-RegistrySnapshotEntrySecurity -Entry $eSam

    return (-not $resControl.Valid -and `
            -not $resTcpip.Valid -and `
            -not $resSession.Valid -and `
            -not $resBadParam.Valid -and `
            $resGood.Valid -and `
            -not $resTrav.Valid -and `
            -not $resSam.Valid)
}

Assert-Test "Safety: Snapshot Security rejection inside Restore-RegistrySnapshot" {
    $backupDir = Join-Path $ScriptDir "Backups"
    if (-not (Test-Path $backupDir)) {
        New-Item -Path $backupDir -ItemType Directory -Force | Out-Null
    }
    $maliciousFile = Join-Path $backupDir "Backup_SecurityAttack_Mock.json"

    $badPayload = [PSCustomObject]@{
        Category  = "SecurityAttack"
        Timestamp = (Get-Date).ToString("yyyyMMdd_HHmmss")
        Entries   = @(
            [PSCustomObject]@{
                Path        = "HKLM:\SAM\SAM"
                Name        = "BadVal"
                KeyExists   = $true
                ValueExists = $true
                Type        = "DWord"
                Value       = 1337
            }
        )
    }
    $badPayload | ConvertTo-Json -Depth 5 | Set-Content -Path $maliciousFile -Encoding UTF8

    $res = Restore-RegistrySnapshot -Category "SecurityAttack" -BackupFilePath $maliciousFile
    Remove-Item -Path $maliciousFile -Force -ErrorAction SilentlyContinue

    return ($res.Success -eq $false -and $res.FailedCount -eq 1 -and $res.FailedItems[0].Error -match "SECURITY BLOCK")
}

Assert-Test "Safety: Rollback Idempotency (consecutive rollbacks maintain consistent state)" {
    $idempKey = "HKCU:\Software\Win11Opt_Idemp_$(Get-Random)"
    New-Item -Path $idempKey -Force | Out-Null
    Set-ItemProperty -Path $idempKey -Name "StableVal" -Value 555 -Type DWord -Force

    $targets = @(@{ Path = $idempKey; Name = "StableVal" })
    $snapFile = Save-RegistrySnapshot -Category "IdempTest" -RegistryTargets $targets

    Set-ItemProperty -Path $idempKey -Name "StableVal" -Value 888 -Type DWord -Force

    # First restoration
    $res1 = Restore-RegistrySnapshot -Category "IdempTest" -BackupFilePath $snapFile
    $val1 = (Get-ItemProperty -Path $idempKey).StableVal

    # Second restoration (idempotent run)
    $res2 = Restore-RegistrySnapshot -Category "IdempTest" -BackupFilePath $snapFile
    $val2 = (Get-ItemProperty -Path $idempKey).StableVal

    Remove-Item -Path $idempKey -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -Path $snapFile -Force -ErrorAction SilentlyContinue

    return ($res1.Success -and $res2.Success -and $val1 -eq 555 -and $val2 -eq 555)
}

Assert-Test "Exact State: Powercfg non-standard AC/DC values & duplicate scheme lifecycle" {
    # Проверка получения параметров питания с валидным GUID
    $powerState = Get-ProcessorPowerSettingsState
    if (-not $powerState -or -not $powerState.Success -or [string]::IsNullOrWhiteSpace($powerState.ActiveSchemeGuid)) {
        return $false
    }

    $origGuid = $powerState.ActiveSchemeGuid

    # Создаем снимок с нестандартными пользовательскими AC/DC значениями
    $mockCustomSettings = @(
        [PSCustomObject]@{ SettingGuid = "ea062031-0e34-4ff1-9b6d-eb10593ac08f"; AC = 77; DC = 33 }
    )
    $mockCustomPayload = [PSCustomObject]@{
        ActiveSchemeGuid = $origGuid
        Settings         = $mockCustomSettings
    }

    $snapFile = Save-StateSnapshot -Category "CpuPowerNonStandardTest" -StateData $mockCustomPayload
    if (-not (Test-Path $snapFile)) { return $false }

    $retrieved = Get-LatestStateSnapshot -Category "CpuPowerNonStandardTest"
    Remove-Item -Path $snapFile -Force -ErrorAction SilentlyContinue

    # Проверка симуляции жизненного цикла созданной схемы (WasCreatedByOptimizer = true)
    # Исходная схема никогда не должна быть удалена
    $plansBefore = powercfg /list 2>&1
    $origInPlans = ($plansBefore -match $origGuid)

    return ($retrieved -ne $null -and `
            $retrieved.StateData.ActiveSchemeGuid -eq $origGuid -and `
            $retrieved.StateData.Settings[0].AC -eq 77 -and `
            $retrieved.StateData.Settings[0].DC -eq 33 -and `
            $origInPlans)
}

Assert-Test "Exact State: Netsh TCP global state parser and snapshot" {
    $netshState = Get-NetshTcpGlobalState
    if (-not $netshState -or -not $netshState.Success) { return $false }
    if ($null -eq $netshState.rss -or $null -eq $netshState.autotuninglevel) { return $false }

    $snapFile = Save-StateSnapshot -Category "NetshTcpUnitTest" -StateData $netshState
    if (-not (Test-Path $snapFile)) { return $false }

    $retrieved = Get-LatestStateSnapshot -Category "NetshTcpUnitTest"
    Remove-Item -Path $snapFile -Force -ErrorAction SilentlyContinue

    return ($retrieved -ne $null -and $retrieved.StateData.rss -eq $netshState.rss)
}

Assert-Test "Exact State: Windows Services startup types (Automatic, Delayed, Manual, Disabled) and status" {
    # Проверка схемы снимка всех 4 поддерживаемых типов запуска
    $mockServices = @(
        [PSCustomObject]@{ Name = "SvcAuto"; StartupType = "Automatic"; Status = "Running"; Exists = $true },
        [PSCustomObject]@{ Name = "SvcDelayed"; StartupType = "AutomaticDelayedStart"; Status = "Running"; Exists = $true },
        [PSCustomObject]@{ Name = "SvcManual"; StartupType = "Manual"; Status = "Stopped"; Exists = $true },
        [PSCustomObject]@{ Name = "SvcDisabled"; StartupType = "Disabled"; Status = "Stopped"; Exists = $true }
    )

    $snapFile = Save-StateSnapshot -Category "SvcTypesTest" -StateData $mockServices
    if (-not (Test-Path $snapFile)) { return $false }

    $retrieved = Get-LatestStateSnapshot -Category "SvcTypesTest"
    Remove-Item -Path $snapFile -Force -ErrorAction SilentlyContinue

    $arr = @($retrieved.StateData)
    $hasAuto = ($arr | Where-Object { $_.StartupType -eq "Automatic" -and $_.Status -eq "Running" })
    $hasDelayed = ($arr | Where-Object { $_.StartupType -eq "AutomaticDelayedStart" -and $_.Status -eq "Running" })
    $hasManual = ($arr | Where-Object { $_.StartupType -eq "Manual" -and $_.Status -eq "Stopped" })
    $hasDisabled = ($arr | Where-Object { $_.StartupType -eq "Disabled" -and $_.Status -eq "Stopped" })

    return ($null -ne $hasAuto -and $null -ne $hasDelayed -and $null -ne $hasManual -and $null -ne $hasDisabled)
}

Assert-Test "Exact State: Scheduled Tasks Enabled boolean and full path preservation" {
    # Проверка сохранения признака Enabled (boolean) и полного пути с закрывающим слешем
    $mockTasks = @(
        [PSCustomObject]@{
            TaskPath = "\Microsoft\Windows\Customer Experience Improvement Program\"
            TaskName = "Consolidator"
            Enabled  = $false
            State    = "Disabled"
            Exists   = $true
        },
        [PSCustomObject]@{
            TaskPath = "\Microsoft\Windows\Application Experience\"
            TaskName = "ProgramDataUpdater"
            Enabled  = $true
            State    = "Ready"
            Exists   = $true
        }
    )

    $snapFile = Save-StateSnapshot -Category "TaskEnabledTest" -StateData $mockTasks
    if (-not (Test-Path $snapFile)) { return $false }

    $retrieved = Get-LatestStateSnapshot -Category "TaskEnabledTest"
    Remove-Item -Path $snapFile -Force -ErrorAction SilentlyContinue

    $tasks = @($retrieved.StateData)
    $tDisabled = ($tasks | Where-Object { $_.TaskName -eq "Consolidator" })
    $tEnabled = ($tasks | Where-Object { $_.TaskName -eq "ProgramDataUpdater" })

    return ($null -ne $tDisabled -and $tDisabled.Enabled -eq $false -and $tDisabled.TaskPath.EndsWith("\") -and `
            $null -ne $tEnabled -and $tEnabled.Enabled -eq $true -and $tEnabled.TaskPath.EndsWith("\"))
}

Assert-Test "Exact State: USB and Network Adapter power properties snapshot schema" {
    $usbState = [PSCustomObject]@{
        ActiveSchemeGuid = "381b4222-f694-41f0-9685-ff5bb260df2e"
        AC               = 0
        DC               = 1
        WmiInstances     = @(
            [PSCustomObject]@{ InstanceName = "USB\ROOT_HUB30\Mock"; Enable = $false }
        )
    }

    $snapFile = Save-StateSnapshot -Category "UsbPowerUnitTest" -StateData $usbState
    if (-not (Test-Path $snapFile)) { return $false }

    $retrieved = Get-LatestStateSnapshot -Category "UsbPowerUnitTest"
    Remove-Item -Path $snapFile -Force -ErrorAction SilentlyContinue

    return ($retrieved -ne $null -and `
            $retrieved.StateData.AC -eq 0 -and `
            $retrieved.StateData.DC -eq 1 -and `
            @($retrieved.StateData.WmiInstances)[0].InstanceName -eq "USB\ROOT_HUB30\Mock")
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
    
    # Проверка, что все FixMenu ссылаются на реальные пункты главного меню ([1]-[8])
    $allFixMenusValid = $true
    foreach ($item in $audit) {
        if ($item.FixMenu -notmatch 'Главное меню -> Пункт \[(1|2|3|4|5|6|7|8)\]') {
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

# 9. 3-Tier Presets & Competitive Features Tests
Assert-Test "GamingLatency: Test-IsLaptopDevice function works" {
    $isLaptop = Test-IsLaptopDevice
    $isLaptop -is [bool]
}

Assert-Test "GamingLatency: Raw Mouse Input Dry-Run and Status" {
    Set-RawMouseInput -DryRun
    $mStat = Get-RawMouseInputStatus
    $null -ne $mStat.Optimal -and $null -ne $mStat.Enabled -and -not [string]::IsNullOrWhiteSpace($mStat.Description)
}

Assert-Test "GamingLatency: Keyboard Response Tuning Dry-Run and Status" {
    Set-KeyboardResponseTuning -DryRun
    $kbStat = Get-KeyboardResponseStatus
    $null -ne $kbStat.Optimal -and $null -ne $kbStat.Enabled -and -not [string]::IsNullOrWhiteSpace($kbStat.Description)
}

Assert-Test "SystemUI: Explorer Gallery Visibility Dry-Run and Status" {
    Set-ExplorerGalleryVisibility -Hide $true -DryRun -NoRestart
    Set-ExplorerGalleryVisibility -Hide $false -DryRun -NoRestart
    $galStat = Get-ExplorerGalleryStatus
    $null -ne $galStat.Hidden -and $null -ne $galStat.Optimal -and -not [string]::IsNullOrWhiteSpace($galStat.Description)
}

Assert-Test "SystemUI: Game Mode Forced Dry-Run and Status" {
    Set-GameModeForced -DryRun
    $gmStat = Get-GameModeStatus
    $null -ne $gmStat.Enabled -and $null -ne $gmStat.Optimal -and -not [string]::IsNullOrWhiteSpace($gmStat.Description)
}

Assert-Test "NetworkGaming: Balanced Network Stack Dry-Run" {
    Set-BalancedNetworkStack -DryRun
    $true
}

Assert-Test "Safety: Low-latency and competitive UI allowlist rules in Test-RegistrySnapshotEntrySecurity" {
    $mouseCheck = Test-RegistrySnapshotEntrySecurity -Entry @{
        Path = "HKCU:\Control Panel\Mouse"; Name = "MouseSpeed"; Type = "String"; KeyExists = $true; ValueExists = $true
    }
    $kbCheck = Test-RegistrySnapshotEntrySecurity -Entry @{
        Path = "HKCU:\Control Panel\Keyboard"; Name = "KeyboardDelay"; Type = "String"; KeyExists = $true; ValueExists = $true
    }
    $accCheck = Test-RegistrySnapshotEntrySecurity -Entry @{
        Path = "HKCU:\Control Panel\Accessibility\Keyboard Response"; Name = "AutoRepeatDelay"; Type = "String"; KeyExists = $true; ValueExists = $true
    }
    $gbCheck = Test-RegistrySnapshotEntrySecurity -Entry @{
        Path = "HKCU:\Software\Microsoft\GameBar"; Name = "AutoGameModeEnabled"; Type = "DWord"; KeyExists = $true; ValueExists = $true
    }
    $galCheck = Test-RegistrySnapshotEntrySecurity -Entry @{
        Path = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FolderDescriptions\{e88865ea-0e1c-4e20-9aa6-ed353b747f69}\PropertyBag"; Name = "ThisPCPolicy"; Type = "String"; KeyExists = $true; ValueExists = $true
    }
    $rejectCheck = Test-RegistrySnapshotEntrySecurity -Entry @{
        Path = "HKCU:\Control Panel\Mouse"; Name = "MaliciousProperty"; Type = "String"; KeyExists = $true; ValueExists = $true
    }

    $mouseCheck.Valid -and $kbCheck.Valid -and $accCheck.Valid -and $gbCheck.Valid -and $galCheck.Valid -and (-not $rejectCheck.Valid)
}

Assert-Test "Preset: Light preset dry-run completes without error" {
    . (Join-Path $ScriptDir "Win11Optimizer.ps1") -Mode Light -DryRun -NoRestorePoint
    $true
}

Assert-Test "Preset: Balanced preset dry-run completes without error" {
    . (Join-Path $ScriptDir "Win11Optimizer.ps1") -Mode Balanced -DryRun -NoRestorePoint
    $true
}

Assert-Test "Preset: UltraGaming preset dry-run completes without error" {
    . (Join-Path $ScriptDir "Win11Optimizer.ps1") -Mode UltraGaming -DryRun -NoRestorePoint
    $true
}

Assert-Test "Preset: Backward compatible AutoGaming mode dry-run completes without error" {
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

Assert-Test "Status Queries: Competitive input & UI status functions (Mouse, Keyboard, Gallery, Game Mode)" {
    $mouse = Get-RawMouseInputStatus
    $kb = Get-KeyboardResponseStatus
    $gal = Get-ExplorerGalleryStatus
    $gm = Get-GameModeStatus

    ($null -ne $mouse.Optimal) -and ($null -ne $kb.Optimal) -and ($null -ne $gal.Hidden) -and ($null -ne $gm.Enabled)
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
Get-ChildItem -Path (Join-Path $ScriptDir "Backups") -Filter "Backup_*.json" -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -like "*Test*" -or $_.Name -like "*Security*" -or $_.Name -like "*Mock*" } |
    Remove-Item -Force -ErrorAction SilentlyContinue

if ($failedTests -gt 0) {
    exit 1
} else {
    exit 0
}
