# Safety.psm1 - Module for System Restore Point creation, state snapshots, and rollback engine
# Encoding: UTF-8

Set-StrictMode -Version Latest

$Script:BackupDir = Join-Path -Path $PSScriptRoot -ChildPath "..\Backups"

function Initialize-SafetyModule {
    if (-not (Test-Path -Path $Script:BackupDir)) {
        New-Item -Path $Script:BackupDir -ItemType Directory -Force | Out-Null
    }
}

function Test-IsSafetyAdmin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]$identity
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Invoke-BackupRotation {
    [CmdletBinding()]
    param(
        [int]$MaxBackups = 50,
        [int]$MaxAgeDays = 30
    )

    Initialize-SafetyModule

    try {
        $files = @(Get-ChildItem -Path $Script:BackupDir -Filter "Backup_*.json" -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending)

        if ($files.Count -le $MaxBackups) {
            return
        }

        # Оставляем новейшие $MaxBackups файлов, более старые ротируем, если они старше $MaxAgeDays
        $cutoffDate = (Get-Date).AddDays(-$MaxAgeDays)
        $excessFiles = $files | Select-Object -Skip $MaxBackups

        foreach ($oldFile in $excessFiles) {
            if ($oldFile.LastWriteTime -lt $cutoffDate) {
                Remove-Item -Path $oldFile.FullName -Force -ErrorAction SilentlyContinue
                Write-Verbose "Ротирован устаревший бэкап: $($oldFile.Name)"
            }
        }
    } catch {
        Write-Verbose "Предупреждение при ротации резервных копий: $_"
    }
}

function New-OptimizerRestorePoint {
    [CmdletBinding()]
    param(
        [string]$Description = "Win11Optimizer_Checkpoint"
    )

    Initialize-SafetyModule

    Write-Host "[Safety] Подготовка точки восстановления системы..." -ForegroundColor Cyan

    try {
        # Проверяем и запускаем службу теневого копирования / восстановления
        $srService = Get-Service -Name "srservice" -ErrorAction SilentlyContinue
        if ($srService -and $srService.Status -ne 'Running') {
            Start-Service -Name "srservice" -ErrorAction SilentlyContinue
        }
        $vssService = Get-Service -Name "VSS" -ErrorAction SilentlyContinue
        if ($vssService -and $vssService.Status -ne 'Running') {
            Start-Service -Name "VSS" -ErrorAction SilentlyContinue
        }

        # Включаем защиту системы на системном диске, если выключена
        $systemDrive = $env:SystemDrive
        if ([string]::IsNullOrWhiteSpace($systemDrive)) { $systemDrive = "C:" }
        try {
            Enable-ComputerRestore -Drive "$systemDrive\" -ErrorAction SilentlyContinue
        } catch {
            Write-Verbose "Enable-ComputerRestore notice: $_"
        }

        # Сохранение исходного состояния SystemRestorePointCreationFrequency перед обходом 24ч лимита
        $srKey = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore"
        $srParam = "SystemRestorePointCreationFrequency"
        if (Test-Path $srKey) {
            Save-RegistrySnapshot -Category "SystemRestore" -RegistryTargets @(
                @{ Path = $srKey; Name = $srParam }
            ) | Out-Null

            Set-ItemProperty -Path $srKey -Name $srParam -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
        }

        $timestamp = (Get-Date).ToString("yyyyMMdd_HHmmss")
        $pointDesc = "${Description}_$timestamp"
        Checkpoint-Computer -Description $pointDesc -RestorePointType "MODIFY_SETTINGS" -ErrorAction Stop
        Write-Host "[Safety] Точка восстановления успешно создана: $pointDesc" -ForegroundColor Green
        return @{ Success = $true; Description = $pointDesc }
    }
    catch {
        Write-Host "[Safety WARNING] Не удалось создать точку восстановления: $($_.Exception.Message)" -ForegroundColor Yellow
        Write-Host "[Safety] Резервные копии реестра будут сохранены локально в папку Backups." -ForegroundColor Yellow
        return @{ Success = $false; Error = $_.Exception.Message }
    }
}

function Restore-SystemRestorePointCreationFrequency {
    [CmdletBinding()]
    param()

    Initialize-SafetyModule
    Write-Host "[Safety] Восстановление исходного состояния SystemRestorePointCreationFrequency..." -ForegroundColor Yellow
    $res = Restore-RegistrySnapshot -Category "SystemRestore"
    if ($res.Success) {
        Write-Host "[Safety] Параметр частоты контрольных точек возвращен к исходному состоянию." -ForegroundColor Green
    } else {
        # Если снимка не было (дефолт Windows) - удаляем параметр
        $srKey = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore"
        $srParam = "SystemRestorePointCreationFrequency"
        if (Test-Path $srKey) {
            Remove-ItemProperty -Path $srKey -Name $srParam -ErrorAction SilentlyContinue
            Write-Host "[Safety] Параметр SystemRestorePointCreationFrequency удален (заводской дефолт Windows)." -ForegroundColor Green
        }
    }
    return $res
}

function Save-RegistrySnapshot {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Category,
        [Parameter(Mandatory = $true)]
        [array]$RegistryTargets, # Array of @{ Path = '...'; Name = '...'; Hive = 'HKLM/HKCU' }
        [switch]$DryRun = $false
    )

    if ($DryRun) {
        return $null
    }

    Initialize-SafetyModule
    Invoke-BackupRotation

    $timestamp = (Get-Date).ToString("yyyyMMdd_HHmmss")
    $backupFileName = "Backup_${Category}_$timestamp.json"
    $backupFilePath = Join-Path -Path $Script:BackupDir -ChildPath $backupFileName

    $snapshotData = [System.Collections.Generic.List[PSObject]]::new()

    foreach ($target in $RegistryTargets) {
        $path = $target.Path
        $name = $target.Name

        $entry = [PSCustomObject]@{
            Path        = $path
            Name        = $name
            KeyExists   = $false
            ValueExists = $false
            Value       = $null
            Type        = $null
        }

        if (Test-Path -Path $path) {
            $entry.KeyExists = $true
            try {
                $prop = Get-ItemProperty -Path $path -Name $name -ErrorAction Stop
                $entry.ValueExists = $true
                $entry.Value = $prop.$name
                
                # Определение типа реестра через .NET Microsoft.Win32.Registry
                $regKey = Get-Item -Path $path
                $valKind = $regKey.GetValueKind($name)
                $entry.Type = $valKind.ToString()
            } catch {
                # Значение не существует в существующем ключе
                $entry.ValueExists = $false
            }
        } else {
            $entry.KeyExists = $false
            $entry.ValueExists = $false
        }

        $snapshotData.Add($entry)
    }

    $finalPayload = [PSCustomObject]@{
        Category  = $Category
        Timestamp = $timestamp
        Date      = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        Entries   = $snapshotData
    }

    $json = $finalPayload | ConvertTo-Json -Depth 5
    [System.IO.File]::WriteAllText($backupFilePath, $json, [System.Text.Encoding]::UTF8)

    Write-Host "[Safety] Снимок состояния реестра сохранен: $backupFileName" -ForegroundColor Cyan
    return $backupFilePath
}

function Test-RegistrySnapshotEntrySecurity {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $Entry
    )

    if ($null -eq $Entry -or -not ($Entry -is [PSCustomObject] -or $Entry -is [hashtable])) {
        return [PSCustomObject]@{ Valid = $false; Error = "Запись снимка не является объектом" }
    }

    $path = $null
    $name = $null
    $type = $null
    $keyExists = $null
    $valExists = $null

    if ($Entry -is [hashtable]) {
        if ($Entry.ContainsKey('Path')) { $path = $Entry['Path'] }
        if ($Entry.ContainsKey('Name')) { $name = $Entry['Name'] }
        if ($Entry.ContainsKey('Type')) { $type = $Entry['Type'] }
        if ($Entry.ContainsKey('KeyExists')) { $keyExists = $Entry['KeyExists'] }
        if ($Entry.ContainsKey('ValueExists')) { $valExists = $Entry['ValueExists'] }
    } else {
        if ($Entry.PSObject.Properties['Path']) { $path = $Entry.Path }
        if ($Entry.PSObject.Properties['Name']) { $name = $Entry.Name }
        if ($Entry.PSObject.Properties['Type']) { $type = $Entry.Type }
        if ($Entry.PSObject.Properties['KeyExists']) { $keyExists = $Entry.KeyExists }
        if ($Entry.PSObject.Properties['ValueExists']) { $valExists = $Entry.ValueExists }
    }

    if ([string]::IsNullOrWhiteSpace($path)) {
        return [PSCustomObject]@{ Valid = $false; Error = "Отсутствует или пуст обязательный путь реестра (Path)" }
    }

    if ($null -eq $name) {
        return [PSCustomObject]@{ Valid = $false; Error = "Отсутствует обязательное поле имени параметра (Name)" }
    }

    if ($null -ne $keyExists -and -not ($keyExists -is [bool])) {
        return [PSCustomObject]@{ Valid = $false; Error = "Поле KeyExists не является булевым значением" }
    }

    if ($null -ne $valExists -and -not ($valExists -is [bool])) {
        return [PSCustomObject]@{ Valid = $false; Error = "Поле ValueExists не является булевым значением" }
    }

    $pathStr = [string]$path

    # Блокировка path traversal, служебных спецсимволов и инъекций
    if ($pathStr -match '(\.\.|\*|\?|;|\0|\r|\n)') {
        return [PSCustomObject]@{ Valid = $false; Error = "Путь содержит недопустимые спецсимволы или попытку обхода каталогов (traversal): $pathStr" }
    }

    # Валидация корня: разрешены только разделы реестра HKLM:\ и HKCU:\
    $isRegistryRoot = ($pathStr -like "HKLM:\*" -or $pathStr -like "HKCU:\*")
    if (-not $isRegistryRoot) {
        return [PSCustomObject]@{ Valid = $false; Error = "Запрещенный корневой раздел. Разрешены только ветки реестра HKLM:\ и HKCU:\. Задано: $pathStr" }
    }

    # Черный список критических системных узлов безопасности
    $blockedSubstrings = @(
        "HKLM:\SAM",
        "HKLM:\SECURITY",
        "HKLM:\BCD00000000",
        "\Control\Lsa",
        "\Control\Session Manager",
        "\Services\WinDefend",
        "\Services\MpsSvc",
        "\Services\LanmanServer"
    )

    foreach ($blocked in $blockedSubstrings) {
        if ($pathStr -like "*$blocked*") {
            return [PSCustomObject]@{ Valid = $false; Error = "Попытка доступа к защищенному системному узлу: $blocked" }
        }
    }

    # Строгий allowlist точных путей реестра (regex) и разрешенных имен параметров
    $strictAllowRules = @(
        # 1. Safety
        @{
            Pattern = '^HKLM:\\SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\SystemRestore$'
            Names   = @('SystemRestorePointCreationFrequency')
        },
        # 2. GamingLatency: PowerThrottling, PriorityControl, SystemProfile, DeviceGuard, MSI
        @{
            Pattern = '^HKLM:\\SYSTEM\\CurrentControlSet\\Control\\Power\\PowerThrottling$'
            Names   = @('PowerThrottlingOff')
        },
        @{
            Pattern = '^HKLM:\\SYSTEM\\CurrentControlSet\\Control\\PriorityControl$'
            Names   = @('Win32PrioritySeparation')
        },
        @{
            Pattern = '^HKLM:\\SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\Multimedia\\SystemProfile$'
            Names   = @('SystemResponsiveness', 'NetworkThrottlingIndex')
        },
        @{
            Pattern = '^HKLM:\\SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\Multimedia\\SystemProfile\\Tasks\\Games$'
            Names   = @('GPU Priority', 'Priority', 'Scheduling Category', 'SFIO Priority')
        },
        @{
            Pattern = '^HKLM:\\SYSTEM\\CurrentControlSet\\Control\\DeviceGuard$'
            Names   = @('EnableVirtualizationBasedSecurity', 'HypervisorEnforcedCodeIntegrity')
        },
        @{
            Pattern = '^HKLM:\\SYSTEM\\CurrentControlSet\\Enum\\PCI\\[^\\]+\\[^\\]+\\Device Parameters\\Interrupt Management\\MessageSignaledInterruptProperties$'
            Names   = @('MSISupported')
        },
        @{
            Pattern = '^HKLM:\\SYSTEM\\CurrentControlSet\\Enum\\PCI\\[^\\]+\\[^\\]+\\Device Parameters\\Interrupt Management\\Affinity Policy$'
            Names   = @('DevicePriority')
        },
        # 3. NetworkGaming: Nagle & DNS on network interfaces
        @{
            Pattern = '^HKLM:\\SYSTEM\\CurrentControlSet\\Services\\Tcpip\\Parameters\\Interfaces\\\{?[a-f0-9\-]+\}?$'
            Names   = @('TcpAckFrequency', 'TCPNoDelay', 'TcpDelAckTicks', 'NameServer', 'DhcpNameServer')
        },
        # 4. GpuDisplay: DWM MPO, HAGS, DirectX, Driver Update Protection, NVIDIA HDCP
        @{
            Pattern = '^HKLM:\\SOFTWARE\\Microsoft\\Windows\\Dwm$'
            Names   = @('OverlayTestMode')
        },
        @{
            Pattern = '^HKLM:\\SYSTEM\\CurrentControlSet\\Control\\GraphicsDrivers$'
            Names   = @('HwSchMode')
        },
        @{
            Pattern = '^HKCU:\\Software\\Microsoft\\DirectX\\UserGpuPreferences$'
            Names   = @('DirectXUserGlobalSettings')
        },
        @{
            Pattern = '^HKLM:\\SOFTWARE\\Policies\\Microsoft\\Windows\\WindowsUpdate$'
            Names   = @('ExcludeWUDriversInQualityUpdate')
        },
        @{
            Pattern = '^HKLM:\\SYSTEM\\CurrentControlSet\\Control\\Class\\\{4d36e968-e325-11ce-bfc1-08002be10318\}\\\d+$'
            Names   = @('RMHdcpKeyglobZero')
        },
        # 5. Debloat: AI Recall, Copilot, Bing, Widgets, Telemetry, Privacy, Ads
        @{
            Pattern = '^(HKLM|HKCU):\\SOFTWARE\\Policies\\Microsoft\\Windows\\WindowsAI$'
            Names   = @('DisableAIDataAnalysis')
        },
        @{
            Pattern = '^(HKLM|HKCU):\\SOFTWARE\\Policies\\Microsoft\\Windows\\WindowsCopilot$'
            Names   = @('TurnOffWindowsCopilot')
        },
        @{
            Pattern = '^HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\Explorer\\Advanced$'
            Names   = @('ShowCopilotButton', 'TaskbarDa', 'HideFileExt', 'Hidden', 'LaunchTo', 'UseCompactMode', 'TaskbarAnimations', 'ShowRecent', 'Start_AccountNotifications')
        },
        @{
            Pattern = '^HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\Search$'
            Names   = @('BingSearchEnabled', 'SearchboxTaskbarMode')
        },
        @{
            Pattern = '^HKCU:\\SOFTWARE\\Policies\\Microsoft\\Windows\\Explorer$'
            Names   = @('DisableSearchBoxSuggestions')
        },
        @{
            Pattern = '^HKLM:\\SOFTWARE\\Policies\\Microsoft\\Windows\\Explorer$'
            Names   = @('HideRecommendedSection')
        },
        @{
            Pattern = '^HKLM:\\SOFTWARE\\Policies\\Microsoft\\Windows\\Windows Search$'
            Names   = @('DisableWebSearch', 'ConnectedSearchUseWeb', 'AllowCortana', 'EnableDynamicContentInWSB')
        },
        @{
            Pattern = '^HKLM:\\SOFTWARE\\Policies\\Microsoft\\Dsh$'
            Names   = @('AllowNewsAndInterests')
        },
        @{
            Pattern = '^HKLM:\\SOFTWARE\\Policies\\Microsoft\\Windows\\DataCollection$'
            Names   = @('AllowTelemetry', 'DoNotShowFeedbackNotifications')
        },
        @{
            Pattern = '^HKCU:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Privacy$'
            Names   = @('TailoredExperiencesWithDiagnosticDataEnabled')
        },
        @{
            Pattern = '^HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\AdvertisingInfo$'
            Names   = @('Enabled')
        },
        # 6. SystemUI: Context Menu CLSID, Explorer, Maintenance, GameDVR, PhotoViewer
        @{
            Pattern = '^HKCU:\\Software\\Classes\\CLSID\\\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2\}(\\InprocServer32)?$'
            Names   = @('', '(default)', 'InprocServer32')
        },
        @{
            Pattern = '^HKLM:\\SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\Schedule\\Maintenance$'
            Names   = @('MaintenanceDisabled')
        },
        @{
            Pattern = '^HKCU:\\System\\GameConfigStore$'
            Names   = @('GameDVR_Enabled', 'GameDVR_FSEBehaviorMode', 'GameDVR_HonorUserFSEBehaviorMode', 'GameDVR_DXGIHonorFSEWindowsCompatible', 'GameDVR_EFSEFeatureFlags')
        },
        @{
            Pattern = '^HKLM:\\SOFTWARE\\Policies\\Microsoft\\Windows\\GameDVR$'
            Names   = @('AllowGameDVR')
        },
        @{
            Pattern = '^HKCU:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\GameDVR$'
            Names   = @('AppCaptureEnabled')
        },
        @{
            Pattern = '^HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\SearchSettings$'
            Names   = @('IsDynamicContentInSearchBoxEnabled', 'IsSearchHighlightsEnabled')
        },
        @{
            Pattern = '^HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\Explorer$'
            Names   = @('ShowFrequent', 'ShowRecent')
        },
        @{
            Pattern = '^HKCU:\\Control Panel\\Desktop$'
            Names   = @('MenuShowDelay')
        },
        @{
            Pattern = '^HKLM:\\SOFTWARE\\Classes\\CLSID\\\{f874310e-b6b7-47dc-bc84-b9e6b38f5903\}$'
            Names   = @('System.IsPinnedToNameSpaceTree')
        },
        @{
            Pattern = '^HKCU:\\Software\\Classes\\CLSID\\\{e88865ea-0e1c-4e20-9aa6-edcd0212c87c\}$'
            Names   = @('System.IsPinnedToNameSpaceTree')
        },
        @{
            Pattern = '^HKLM:\\SOFTWARE\\Microsoft\\PolicyManager\\current\\device\\Education$'
            Names   = @('IsEducationEnvironment')
        },
        @{
            Pattern = '^HKLM:\\SOFTWARE\\Microsoft\\PolicyManager\\current\\device\\Start$'
            Names   = @('HideRecommendedSection')
        },
        @{
            Pattern = '^HKLM:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Explorer\\Desktop\\NameSpace\\\{f874310e-b6b7-47dc-bc84-b9e6b38f5903\}$'
            Names   = @('', '(default)')
        },
        @{
            Pattern = '^HKLM:\\SOFTWARE\\Microsoft\\Windows Photo Viewer\\Capabilities\\FileAssociations$'
            Names   = @('.jpg', '.jpeg', '.png', '.bmp', '.tif', '.tiff', '.gif', '.ico')
        },
        # 7. Low-Latency Input & Competitive UI
        @{
            Pattern = '^HKCU:\\Control Panel\\Mouse$'
            Names   = @('MouseSpeed', 'MouseThreshold1', 'MouseThreshold2')
        },
        @{
            Pattern = '^HKCU:\\Control Panel\\Keyboard$'
            Names   = @('KeyboardDelay', 'KeyboardSpeed')
        },
        @{
            Pattern = '^HKCU:\\Control Panel\\Accessibility\\Keyboard Response$'
            Names   = @('AutoRepeatDelay', 'AutoRepeatRate', 'DelayBeforeAcceptance', 'Flags', 'BounceTime')
        },
        @{
            Pattern = '^HKCU:\\Software\\Microsoft\\GameBar$'
            Names   = @('AutoGameModeEnabled', 'AllowAutoGameMode', 'GamepadDoublePressIntervalMs')
        },
        @{
            Pattern = '^(HKLM|HKCU):\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Explorer\\FolderDescriptions\\\{e88865ea-0e1c-4e20-9aa6-ed353b747f69\}\\PropertyBag$'
            Names   = @('ThisPCPolicy')
        },
        # 8. Sandbox for automated tests
        @{
            Pattern = '^HKCU:\\Software\\Win11Opt.*$'
            Names   = @('*')
        },
        @{
            Pattern = '^HKCU:\\Software\\Win11Optimizer.*$'
            Names   = @('*')
        }
    )

    $isPathAllowed = $false
    $matchedRule = $null

    foreach ($rule in $strictAllowRules) {
        if ($pathStr -match $rule.Pattern) {
            $isPathAllowed = $true
            $matchedRule = $rule
            break
        }
    }

    if (-not $isPathAllowed) {
        return [PSCustomObject]@{ Valid = $false; Error = "Путь реестра '$pathStr' не входит в строгий allowlist оптимизатора" }
    }

    # Валидация имени параметра
    $nameStr = [string]$name
    if ($matchedRule.Names -notcontains '*' -and -not ($matchedRule.Names -contains $nameStr)) {
        return [PSCustomObject]@{ Valid = $false; Error = "Недопустимое имя параметра '$nameStr' для пути '$pathStr'. Разрешены только: $($matchedRule.Names -join ', ')" }
    }

    # Проверка допустимого типа реестра
    if ($valExists -eq $true -or ($null -ne $type -and [string]$type -ne "")) {
        $validTypes = @("DWord", "QWord", "String", "ExpandString", "MultiString", "Binary")
        if ([string]::IsNullOrWhiteSpace($type) -or ($type -notin $validTypes)) {
            return [PSCustomObject]@{ Valid = $false; Error = "Недопустимый тип реестра: $type" }
        }
    }

    return [PSCustomObject]@{ Valid = $true; Error = $null }
}

function Save-StateSnapshot {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Category,
        [Parameter(Mandatory = $true)]
        $StateData,
        [switch]$DryRun = $false
    )

    if ($DryRun) { return $null }

    Initialize-SafetyModule
    Invoke-BackupRotation

    $timestamp = (Get-Date).ToString("yyyyMMdd_HHmmss")
    $backupFileName = "Backup_${Category}_$timestamp.json"
    $backupFilePath = Join-Path -Path $Script:BackupDir -ChildPath $backupFileName

    $payload = [PSCustomObject]@{
        Category  = $Category
        Timestamp = $timestamp
        Date      = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        StateData = $StateData
    }

    try {
        $json = $payload | ConvertTo-Json -Depth 10
        [System.IO.File]::WriteAllText($backupFilePath, $json, [System.Text.Encoding]::UTF8)
        Write-Verbose "Сохранен снимок состояния $Category в $backupFileName"
        return $backupFilePath
    } catch {
        Write-Host "[Safety WARNING] Ошибка сохранения снимка состояния ${Category}: $($_.Exception.Message)" -ForegroundColor Yellow
        return $null
    }
}

function Get-LatestStateSnapshot {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Category
    )

    Initialize-SafetyModule

    $files = @(Get-ChildItem -Path $Script:BackupDir -Filter "Backup_${Category}_*.json" -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending)

    if ($files.Count -eq 0) {
        return $null
    }

    $targetFile = $files[0].FullName
    try {
        $raw = [System.IO.File]::ReadAllText($targetFile, [System.Text.Encoding]::UTF8)
        $payload = $raw | ConvertFrom-Json
        if (-not $payload -or $null -eq $payload.StateData) {
            Write-Verbose "Файл снимка $targetFile поврежден или не содержит StateData"
            return $null
        }
        return [PSCustomObject]@{
            TargetFile = $targetFile
            Category   = $payload.Category
            Timestamp  = $payload.Timestamp
            StateData  = $payload.StateData
        }
    } catch {
        Write-Verbose "Ошибка чтения снимка состояния ${targetFile}: $_"
        return $null
    }
}

function Restore-RegistrySnapshot {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$Category = "",
        [Parameter(Mandatory = $false)]
        [string]$BackupFilePath = ""
    )

    Initialize-SafetyModule

    $result = [PSCustomObject]@{
        Success       = $false
        RestoredCount = 0
        FailedCount   = 0
        TotalCount    = 0
        RestoredItems = @()
        FailedItems   = @()
        Errors        = @()
        TargetFile    = $null
        Message       = ""
    }

    $targetFile = $null

    if (-not [string]::IsNullOrWhiteSpace($BackupFilePath) -and (Test-Path $BackupFilePath)) {
        $targetFile = $BackupFilePath
    } elseif (-not [string]::IsNullOrWhiteSpace($Category)) {
        # Ищем самый свежий бэкап категории
        $files = @(Get-ChildItem -Path $Script:BackupDir -Filter "Backup_${Category}_*.json" -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending)
        if ($files.Count -gt 0) {
            $targetFile = $files[0].FullName
        }
    } else {
        # Ищем самый свежий бэкап вообще
        $files = @(Get-ChildItem -Path $Script:BackupDir -Filter "Backup_*.json" -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending)
        if ($files.Count -gt 0) {
            $targetFile = $files[0].FullName
        }
    }

    if (-not $targetFile -or -not (Test-Path $targetFile)) {
        $msg = "[Safety WARNING] Файл резервной копии не найден" + $(if ($Category) { " для категории '$Category'" } else { "" }) + "."
        Write-Host $msg -ForegroundColor Yellow
        $result.Message = $msg
        $result.Errors += $msg
        return $result
    }

    $result.TargetFile = $targetFile
    Write-Host "[Safety] Откат из снимка: $(Split-Path $targetFile -Leaf)..." -ForegroundColor Yellow

    # Валидация содержимого JSON файла
    $rawJson = $null
    $payload = $null
    try {
        $rawJson = [System.IO.File]::ReadAllText($targetFile, [System.Text.Encoding]::UTF8)
        $payload = $rawJson | ConvertFrom-Json
        if (-not $payload -or $null -eq $payload.Entries) {
            throw "Некорректная структура файла резервной копии (отсутствует поле Entries)"
        }
    } catch {
        $msg = "[Safety ERROR] Файл резервной копии поврежден или имеет неверный формат: $($_.Exception.Message)"
        Write-Host $msg -ForegroundColor Red
        $result.Message = $msg
        $result.Errors += $msg
        return $result
    }

    $result.TotalCount = $payload.Entries.Count

    if ($result.TotalCount -eq 0) {
        $msg = "[Safety] Снимок пуст, восстанавливать нечего."
        Write-Host $msg -ForegroundColor Yellow
        $result.Success = $true
        $result.Message = $msg
        return $result
    }

    $isAdmin = Test-IsSafetyAdmin
    $restoredList = [System.Collections.Generic.List[PSObject]]::new()
    $failedList   = [System.Collections.Generic.List[PSObject]]::new()
    $errorList    = [System.Collections.Generic.List[string]]::new()

    foreach ($entry in $payload.Entries) {
        # Валидация безопасности и структуры записи снимка
        $secCheck = Test-RegistrySnapshotEntrySecurity -Entry $entry
        if (-not $secCheck.Valid) {
            $errMsg = "[SECURITY BLOCK] Снимок отклонен системой безопасности: $($secCheck.Error)"
            $failedList.Add([PSCustomObject]@{
                Path   = if ($entry -and $entry.Path) { [string]$entry.Path } else { "UNKNOWN" }
                Name   = if ($entry -and $null -ne $entry.Name) { [string]$entry.Name } else { "UNKNOWN" }
                Error  = $errMsg
                Action = "SecurityValidation"
            })
            $errorList.Add($errMsg)
            Write-Host "  $errMsg" -ForegroundColor Red
            continue
        }

        $path = $entry.Path
        $name = $entry.Name

        # Проверка прав: запись в HKLM требует прав администратора
        if ($path -like "HKLM:*" -and -not $isAdmin) {
            $errMsg = "Требуются права Администратора для записи в $path"
            $failedList.Add([PSCustomObject]@{
                Path   = $path
                Name   = $name
                Error  = $errMsg
                Action = "PrivilegeCheck"
            })
            $errorList.Add("$path\${name}: $errMsg")
            Write-Host "  [FAIL] $path\${name}: $errMsg" -ForegroundColor Red
            continue
        }

        try {
            if (-not $entry.KeyExists) {
                # Ключа раньше не существовало — удаляем созданное значение, и если ключ стал пуст — удаляем ключ
                if (Test-Path $path) {
                    Remove-ItemProperty -Path $path -Name $name -ErrorAction Stop
                    $keyItem = Get-Item -Path $path -ErrorAction SilentlyContinue
                    if ($keyItem -and $keyItem.ValueCount -eq 0 -and $keyItem.SubKeyCount -eq 0) {
                        Remove-Item -Path $path -Force -ErrorAction Stop
                    }
                }
            } elseif (-not $entry.ValueExists) {
                # Ключ был, но значения не было — удаляем добавленное значение
                if (Test-Path $path) {
                    $prop = Get-ItemProperty -Path $path -Name $name -ErrorAction SilentlyContinue
                    if ($prop -and $null -ne $prop.$name) {
                        Remove-ItemProperty -Path $path -Name $name -ErrorAction Stop
                    }
                }
            } else {
                # Значение было — восстанавливаем исходное значение и тип
                if (-not (Test-Path $path)) {
                    New-Item -Path $path -Force -ErrorAction Stop | Out-Null
                }

                $regType = "String"
                switch ($entry.Type) {
                    "DWord"        { $regType = "DWord" }
                    "QWord"        { $regType = "QWord" }
                    "Binary"       { $regType = "Binary" }
                    "MultiString"  { $regType = "MultiString" }
                    "ExpandString" { $regType = "ExpandString" }
                    default        { $regType = "String" }
                }

                Set-ItemProperty -Path $path -Name $name -Value $entry.Value -Type $regType -Force -ErrorAction Stop

                # Верификация записи
                $verify = Get-ItemProperty -Path $path -Name $name -ErrorAction Stop
                if ($null -eq $verify -or $null -eq $verify.$name) {
                    throw "Верификация не удалась: параметр не обнаружен после записи"
                }
            }

            $restoredList.Add([PSCustomObject]@{
                Path  = $path
                Name  = $name
                Type  = $entry.Type
                Value = $entry.Value
            })
        } catch {
            $errText = $_.Exception.Message
            $failedList.Add([PSCustomObject]@{
                Path   = $path
                Name   = $name
                Error  = $errText
                Action = "RestoreEntry"
            })
            $errorList.Add("$path\${name}: $errText")
            Write-Host "  [FAIL] $path\${name}: $errText" -ForegroundColor Red
        }
    }

    $result.RestoredCount = $restoredList.Count
    $result.FailedCount   = $failedList.Count
    $result.RestoredItems = $restoredList.ToArray()
    $result.FailedItems   = $failedList.ToArray()
    $result.Errors        = $errorList.ToArray()

    if ($result.FailedCount -eq 0 -and $result.RestoredCount -gt 0) {
        $result.Success = $true
        $result.Message = "Успешно восстановлено параметров: $($result.RestoredCount) из $($result.TotalCount)"
        Write-Host "[Safety] $($result.Message)" -ForegroundColor Green
    } elseif ($result.RestoredCount -gt 0 -and $result.FailedCount -gt 0) {
        $result.Success = $false
        $result.Message = "Откат выполнен ЧАСТИЧНО: успешно $($result.RestoredCount), сбоев $($result.FailedCount) из $($result.TotalCount)"
        Write-Host "[Safety WARNING] $($result.Message)" -ForegroundColor Yellow
        Write-Host "[Safety] Не удалось восстановить следующие параметры:" -ForegroundColor Yellow
        foreach ($f in $result.FailedItems) {
            Write-Host "   - $($f.Path)\$($f.Name): $($f.Error)" -ForegroundColor Yellow
        }
    } else {
        $result.Success = $false
        $result.Message = "Откат завершился ошибкой: не удалось восстановить ни один параметр ($($result.FailedCount) сбоев)"
        Write-Host "[Safety ERROR] $($result.Message)" -ForegroundColor Red
    }

    return $result
}

function Get-BackupHistory {
    Initialize-SafetyModule
    $files = Get-ChildItem -Path $Script:BackupDir -Filter "Backup_*.json" -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending
    $history = @()
    foreach ($file in $files) {
        try {
            $raw = [System.IO.File]::ReadAllText($file.FullName, [System.Text.Encoding]::UTF8) | ConvertFrom-Json
            $entryCount = 0
            if ($raw.PSObject.Properties['Entries'] -and $null -ne $raw.Entries) {
                $entryCount = @($raw.Entries).Count
            }
            $history += [PSCustomObject]@{
                FileName  = $file.Name
                Category  = $raw.Category
                Date      = $raw.Date
                Count     = $entryCount
                FullPath  = $file.FullName
            }
        } catch {
            # Skip invalid files
        }
    }
    return ,@($history)
}

Export-ModuleMember -Function New-OptimizerRestorePoint, Restore-SystemRestorePointCreationFrequency, `
                             Save-RegistrySnapshot, Restore-RegistrySnapshot, Get-BackupHistory, Invoke-BackupRotation, `
                             Test-RegistrySnapshotEntrySecurity, Save-StateSnapshot, Get-LatestStateSnapshot
