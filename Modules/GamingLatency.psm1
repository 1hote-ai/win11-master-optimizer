# GamingLatency.psm1 - Deep Low-Latency, MSI Mode, CPU Scheduling and Responsiveness
# Encoding: UTF-8

Set-StrictMode -Version Latest

Import-Module (Join-Path -Path $PSScriptRoot -ChildPath "Safety.psm1") -ErrorAction SilentlyContinue

function Get-PciMsiDevices {
    [CmdletBinding()]
    param(
        [string[]]$Classes = @('Display', 'Net', 'Media', 'System')
    )

    $results = [System.Collections.Generic.List[PSCustomObject]]::new()
    
    # Получаем устройства PCI из Win32_PnPEntity (включая GPU, Сеть и Аудио контроллеры)
    $pnpDevices = Get-CimInstance Win32_PnPEntity | Where-Object { 
        $_.DeviceID -like 'PCI\*' -and (
            $_.PNPClass -in @('Display', 'Net', 'Media') -or 
            ($_.PNPClass -eq 'System' -and (
                $_.Name -like "*Audio*" -or 
                $_.Name -like "*Звук*" -or 
                $_.Service -in @('HDAudBus', 'HdAudAddService')
            ))
        )
    }

    foreach ($dev in $pnpDevices) {
        $devId = $dev.DeviceID
        $regBase = "HKLM:\SYSTEM\CurrentControlSet\Enum\$devId\Device Parameters\Interrupt Management"
        $msiKey = "$regBase\MessageSignaledInterruptProperties"
        $affinityKey = "$regBase\Affinity Policy"

        $msiSupported = $null
        $devicePriority = $null

        if (Test-Path -Path $msiKey) {
            $msiProp = Get-ItemProperty -Path $msiKey -ErrorAction SilentlyContinue
            if ($msiProp -and $null -ne $msiProp.MSISupported) {
                $msiSupported = [int]$msiProp.MSISupported
            }
        }

        if (Test-Path -Path $affinityKey) {
            $affProp = Get-ItemProperty -Path $affinityKey -ErrorAction SilentlyContinue
            if ($affProp -and $null -ne $affProp.DevicePriority) {
                $devicePriority = [int]$affProp.DevicePriority
            }
        }

        $priorityText = switch ($devicePriority) {
            1 { "Low (1)" }
            2 { "Normal (2)" }
            3 { "High (3)" }
            default { "Default/Undefined" }
        }

        $category = switch ($dev.PNPClass) {
            'Display' { 'GPU' }
            'Net'     { 'Network' }
            default   { 'Audio' }
        }

        $results.Add([PSCustomObject]@{
            Name            = $dev.Name
            PNPClass        = $dev.PNPClass
            Category        = $category
            DeviceID        = $devId
            MSISupported    = $msiSupported
            DevicePriority  = $devicePriority
            PriorityText    = $priorityText
            MsiActive       = ($msiSupported -eq 1)
            RegBase         = $regBase
        })
    }

    if ($Classes -and $Classes.Count -gt 0) {
        return @($results | Where-Object { $_.PNPClass -in $Classes -or $_.Category -in $Classes })
    }

    return $results
}

function Set-GamingMsiMode {
    [CmdletBinding()]
    param(
        [switch]$DryRun = $false
    )

    Write-Host "`n[MSI Optimizer] Сканирование PCI устройств (GPU, Сеть, Звуковые карты)..." -ForegroundColor Cyan
    $devices = Get-PciMsiDevices

    if (-not $devices -or $devices.Count -eq 0) {
        Write-Host "[MSI Optimizer] Подходящих PCI устройств не обнаружено." -ForegroundColor Yellow
        return
    }

    if ($DryRun) {
        foreach ($dev in $devices) {
            $catLabel = if ($dev.Category) { $dev.Category } else { $dev.PNPClass }
            Write-Host "  -> Оптимизация [$catLabel]: $($dev.Name)" -ForegroundColor White
            Write-Host "     [DRY-RUN] Будет установлено: MSISupported=1, DevicePriority=3 (High)" -ForegroundColor DarkGray
        }
        return
    }

    # Резервное копирование перед модификацией
    $backupTargets = @()
    foreach ($dev in $devices) {
        $backupTargets += @{ Path = "$($dev.RegBase)\MessageSignaledInterruptProperties"; Name = "MSISupported" }
        $backupTargets += @{ Path = "$($dev.RegBase)\Affinity Policy"; Name = "DevicePriority" }
    }
    Save-RegistrySnapshot -Category "MSIMode" -RegistryTargets $backupTargets -DryRun:$DryRun | Out-Null

    $appliedCount = 0

    foreach ($dev in $devices) {
        $catLabel = if ($dev.Category) { $dev.Category } else { $dev.PNPClass }
        Write-Host "  -> Оптимизация [$catLabel]: $($dev.Name)" -ForegroundColor White
        
        $msiKey = "$($dev.RegBase)\MessageSignaledInterruptProperties"
        $affinityKey = "$($dev.RegBase)\Affinity Policy"

        try {
            if (-not (Test-Path $msiKey)) {
                New-Item -Path $msiKey -Force | Out-Null
            }
            Set-ItemProperty -Path $msiKey -Name "MSISupported" -Value 1 -Type DWord -Force

            if (-not (Test-Path $affinityKey)) {
                New-Item -Path $affinityKey -Force | Out-Null
            }
            # Устанавливаем высокий приоритет для прерываний (3 = High)
            Set-ItemProperty -Path $affinityKey -Name "DevicePriority" -Value 3 -Type DWord -Force
            
            Write-Host "     [OK] MSI Mode: ВКЛ (1) | Приоритет: HIGH (3)" -ForegroundColor Green
            $appliedCount++
        }
        catch {
            Write-Host "     [ERROR] Ошибка настройки устройства: $($_.Exception.Message)" -ForegroundColor Red
        }
    }

    Write-Host "`n[MSI Optimizer] Настроено устройств: $appliedCount. Изменения вступят в силу после перезагрузки." -ForegroundColor Green
}

function Restore-GamingMsiMode {
    [CmdletBinding()]
    param()

    Write-Host "[MSI Optimizer] Откат настроек MSI Mode к исходным..." -ForegroundColor Yellow
    $restored = Restore-RegistrySnapshot -Category "MSIMode"
    if (-not $restored.Success) {
        Write-Host "[MSI Optimizer WARNING] Снимок реестра не найден. Оставляем текущую конфигурацию драйверов." -ForegroundColor Yellow
    }
}

function Restore-ActivePowerScheme {
    [CmdletBinding()]
    param()

    $snap = Get-LatestStateSnapshot -Category "ActivePowerScheme"
    if ($snap -and $snap.StateData -and $snap.StateData.ActiveSchemeGuid) {
        $origGuid = $snap.StateData.ActiveSchemeGuid

        # 1. Сначала активируем именно исходную схему пользователя
        powercfg -setactive $origGuid 2>&1 | Out-Null

        $curActive = powercfg /getactivescheme 2>&1
        $switchedOk = ($curActive -match $origGuid)
        if ($switchedOk) {
            Write-Host "  [OK] Первоначальная схема питания ($origGuid) восстановлена." -ForegroundColor Green
        } else {
            Write-Host "  [WARNING] Не удалось переключить активную схему питания на $origGuid." -ForegroundColor Yellow
        }

        # 2. Удаление схемы, созданной оптимизатором:
        # - Удаляем только если схема была создана оптимизатором ($snap.StateData.WasCreatedByOptimizer -eq $true)
        # - Не удаляем схему, если она по-прежнему активна
        # - Ни при каких обстоятельствах не удаляем исходную схему пользователя ($createdGuid -ne $origGuid)
        if ($snap.StateData.WasCreatedByOptimizer -and -not [string]::IsNullOrWhiteSpace($snap.StateData.CreatedSchemeGuid)) {
            $createdGuid = $snap.StateData.CreatedSchemeGuid
            if ($createdGuid -ne $origGuid -and -not ($curActive -match $createdGuid)) {
                $listBefore = powercfg /list 2>&1
                if ($listBefore -match $createdGuid) {
                    powercfg -delete $createdGuid 2>&1 | Out-Null
                    $listAfter = powercfg /list 2>&1
                    if (-not ($listAfter -match $createdGuid)) {
                        Write-Host "  [OK] Временная схема Ultimate Performance ($createdGuid), созданная оптимизатором, безопасно удалена." -ForegroundColor Green
                    }
                }
            }
        }
        return $switchedOk
    }
    return $false
}

function Get-ProcessorPowerSettingsState {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$SchemeGuid = ""
    )

    $targetGuid = $SchemeGuid
    if ([string]::IsNullOrWhiteSpace($targetGuid)) {
        # Сначала проверяем, есть ли сохраненный снимок исходной схемы питания
        $activeSnap = Get-LatestStateSnapshot -Category "ActivePowerScheme"
        if ($activeSnap -and $activeSnap.StateData -and $activeSnap.StateData.ActiveSchemeGuid) {
            $targetGuid = $activeSnap.StateData.ActiveSchemeGuid
        } else {
            $activeScheme = powercfg /getactivescheme 2>&1
            if ($activeScheme -match '([a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12})') {
                $targetGuid = $Matches[1]
            }
        }
    }

    if ([string]::IsNullOrWhiteSpace($targetGuid)) {
        $targetGuid = "SCHEME_CURRENT"
    }

    $lines = powercfg /q $targetGuid SUB_PROCESSOR 2>&1
    $curGuid = $null
    $settings = @{}

    foreach ($line in $lines) {
        if ($line -match '([a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12})') {
            $curGuid = $Matches[1].ToLower()
            if (-not $settings.ContainsKey($curGuid)) {
                $settings[$curGuid] = [PSCustomObject]@{ SettingGuid = $curGuid; AC = $null; DC = $null }
            }
        }
        if ($line -match ':\s*0x([0-9a-fA-F]+)') {
            $val = [Convert]::ToInt32($Matches[1], 16)
            if ($line -match '(сети|AC)') {
                if ($curGuid) { $settings[$curGuid].AC = $val }
            } elseif ($line -match '(батарей|DC)') {
                if ($curGuid) { $settings[$curGuid].DC = $val }
            }
        }
    }

    return [PSCustomObject]@{
        Success          = [bool](-not [string]::IsNullOrWhiteSpace($targetGuid) -and $targetGuid -ne "SCHEME_CURRENT")
        ActiveSchemeGuid = $targetGuid
        Settings         = @($settings.Values)
    }
}

function Enable-UltimatePerformancePlan {
    [CmdletBinding()]
    param([switch]$DryRun = $false)

    Write-Host "`n[Power Plan] Активация схемы питания 'Максимальная производительность' (Ultimate Performance)..." -ForegroundColor Cyan

    if ($DryRun) {
        Write-Host "  [DRY-RUN] Будет разблокирована и активирована схема питания Ultimate Performance." -ForegroundColor DarkGray
        return $true
    }

    # Сохраняем исходную активную схему питания перед переключением
    $origGuid = $null
    $activeScheme = powercfg /getactivescheme 2>&1
    if ($activeScheme -match '([a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12})') {
        $origGuid = $Matches[1]
    }

    try {
        # Проверяем, существует ли уже схема Максимальная производительность
        $plans = powercfg /list 2>&1
        $targetGuid = $null
        $wasCreated = $false

        foreach ($line in ($plans -split "`r?`n")) {
            if ($line -like "*Максимальная производительность*" -or $line -like "*Ultimate Performance*") {
                if ($line -match 'GUID.*?:\s*([a-f0-9\-]+)') {
                    $targetGuid = $matches[1]
                    break
                }
            }
        }

        if (-not $targetGuid) {
            # Разблокируем встроенную схему Ultimate Performance дубликатом
            $dupOut = powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61 2>&1
            if ($dupOut -match 'GUID.*?:\s*([a-f0-9\-]+)') {
                $targetGuid = $matches[1]
                $wasCreated = $true
            }
        }

        if ($origGuid) {
            Save-StateSnapshot -Category "ActivePowerScheme" -StateData @{
                ActiveSchemeGuid      = $origGuid
                CreatedSchemeGuid     = if ($wasCreated) { $targetGuid } else { $null }
                WasCreatedByOptimizer = [bool]$wasCreated
            } -DryRun:$DryRun | Out-Null
        }

        if ($targetGuid) {
            powercfg -setactive $targetGuid 2>&1 | Out-Null
            Write-Host "  [OK] Схема 'Максимальная производительность' ($targetGuid) успешно активирована!" -ForegroundColor Green
            return $true
        } else {
            Write-Host "  [WARNING] Не удалось разблокировать схему питания. Оптимизируем текущую схему." -ForegroundColor Yellow
            return $false
        }
    } catch {
        Write-Host "  [ERROR] Ошибка переключения схемы питания: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Set-CpuGamingScheduling {
    [CmdletBinding()]
    param(
        [switch]$DryRun = $false
    )

    Write-Host "`n[CPU Optimization] Применение низколатентного планирования потоков и отключение Power Throttling..." -ForegroundColor Cyan

    if ($DryRun) {
        Write-Host "  [DRY-RUN] Будет установлено: PowerThrottlingOff = 1, Win32PrioritySeparation = 38 (0x26)" -ForegroundColor DarkGray
        Write-Host "  [DRY-RUN] Будет отключен Core Parking (CPMINCORES=100) и выставлен PERFEPP=0" -ForegroundColor DarkGray
        return
    }

    $targets = @(
        @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling"; Name = "PowerThrottlingOff" },
        @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl"; Name = "Win32PrioritySeparation" }
    )
    Save-RegistrySnapshot -Category "CpuScheduling" -RegistryTargets $targets -DryRun:$DryRun | Out-Null

    try {
        # 1. Отключение Power Throttling (предотвращает замедление фоновых/игровых потоков)
        $ptKey = "HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling"
        if (-not (Test-Path $ptKey)) {
            New-Item -Path $ptKey -Force | Out-Null
        }
        Set-ItemProperty -Path $ptKey -Name "PowerThrottlingOff" -Value 1 -Type DWord -Force
        Write-Host "  [OK] Power Throttling отключен (PowerThrottlingOff = 1)" -ForegroundColor Green

        # 2. Win32PrioritySeparation = 38 (0x26 - короткие переменные кванты с максимальным приоритетом активного окна)
        $priKey = "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl"
        Set-ItemProperty -Path $priKey -Name "Win32PrioritySeparation" -Value 38 -Type DWord -Force
        Write-Host "  [OK] Win32PrioritySeparation установлен в 38 (0x26 - Gaming Foreground Boost)" -ForegroundColor Green

        # 3. Снимок точных текущих параметров питания процессора (AC/DC) перед изменением
        $procPowerState = Get-ProcessorPowerSettingsState
        Save-StateSnapshot -Category "CpuPowerSettings" -StateData $procPowerState -DryRun:$DryRun | Out-Null

        # Отключение парковки ядер CPU (Core Parking) и задержек перехода P-State в активной схеме питания
        powercfg -setacvalueindex SCHEME_CURRENT SUB_PROCESSOR CPMINCORES 100 2>&1 | Out-Null
        powercfg -setacvalueindex SCHEME_CURRENT SUB_PROCESSOR CPMINCORES1 100 2>&1 | Out-Null
        powercfg -setacvalueindex SCHEME_CURRENT SUB_PROCESSOR PERFEPP 0 2>&1 | Out-Null
        powercfg -setacvalueindex SCHEME_CURRENT SUB_PROCESSOR PROCTHROTTLEMIN 100 2>&1 | Out-Null
        powercfg -setacvalueindex SCHEME_CURRENT SUB_PROCESSOR PERFBOOSTMODE 2 2>&1 | Out-Null
        powercfg -setactive SCHEME_CURRENT 2>&1 | Out-Null
        Write-Host "  [OK] Core Parking отключен (100% ядер активны, PERFEPP=0 максимальная производительность)" -ForegroundColor Green
    }
    catch {
        Write-Host "  [ERROR] Ошибка оптимизации CPU: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Restore-CpuGamingScheduling {
    [CmdletBinding()]
    param()

    Write-Host "[CPU Optimization] Откат параметров CPU к дефолту..." -ForegroundColor Yellow
    $restored = Restore-RegistrySnapshot -Category "CpuScheduling"
    
    if (-not $restored.Success) {
        # Если снимка не было, возвращаем стандартные дефолты Windows
        Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl" -Name "Win32PrioritySeparation" -Value 2 -Type DWord -Force -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling" -Name "PowerThrottlingOff" -ErrorAction SilentlyContinue
    }
    
    # 1. Возврат исходной активной схемы электропитания и очистка созданного дубликата
    Restore-ActivePowerScheme | Out-Null

    # 2. Точное восстановление исходных параметров электропитания процессора из снимка
    $snap = Get-LatestStateSnapshot -Category "CpuPowerSettings"
    if ($snap -and $snap.StateData -and $snap.StateData.Settings -and -not [string]::IsNullOrWhiteSpace($snap.StateData.ActiveSchemeGuid)) {
        # Передаем именно сохраненный GUID исходной схемы, а не текущую активную схему
        $targetScheme = $snap.StateData.ActiveSchemeGuid
        $allRestoredOk = $true

        foreach ($s in $snap.StateData.Settings) {
            if ($null -ne $s.AC) {
                powercfg -setacvalueindex $targetScheme SUB_PROCESSOR $s.SettingGuid $s.AC 2>&1 | Out-Null
            }
            if ($null -ne $s.DC) {
                powercfg -setdcvalueindex $targetScheme SUB_PROCESSOR $s.SettingGuid $s.DC 2>&1 | Out-Null
            }
        }
        # Применяем изменения к целевой схеме
        powercfg -setactive $targetScheme 2>&1 | Out-Null

        # Верификация восстановления параметров
        $verifyState = Get-ProcessorPowerSettingsState -SchemeGuid $targetScheme
        $settingsMap = @{}
        foreach ($vs in $verifyState.Settings) { $settingsMap[$vs.SettingGuid] = $vs }

        foreach ($s in $snap.StateData.Settings) {
            if ($settingsMap.ContainsKey($s.SettingGuid)) {
                $cur = $settingsMap[$s.SettingGuid]
                if ($null -ne $s.AC -and $cur.AC -ne $s.AC) { $allRestoredOk = $false }
                if ($null -ne $s.DC -and $cur.DC -ne $s.DC) { $allRestoredOk = $false }
            }
        }

        if ($allRestoredOk) {
            Write-Host "  [OK] Первоначальные параметры питания процессора (AC/DC) для схемы $targetScheme точно восстановлены." -ForegroundColor Green
        } else {
            Write-Host "  [WARNING] Часть параметров питания процессора схемы $targetScheme не совпадает с исходными." -ForegroundColor Yellow
        }
    } else {
        # Fallback на дефолтные параметры схемы электропитания только при отсутствии снимка
        powercfg -setacvalueindex SCHEME_CURRENT SUB_PROCESSOR CPMINCORES 10 2>&1 | Out-Null
        powercfg -setacvalueindex SCHEME_CURRENT SUB_PROCESSOR PERFEPP 50 2>&1 | Out-Null
        powercfg -setacvalueindex SCHEME_CURRENT SUB_PROCESSOR PROCTHROTTLEMIN 5 2>&1 | Out-Null
        powercfg -setactive SCHEME_CURRENT 2>&1 | Out-Null
        Write-Host "  [WARNING] Снимок питания CPU не найден: применены стандартные значения SCHEME_CURRENT." -ForegroundColor Yellow
    }

    Write-Host "[CPU Optimization] Параметры CPU возвращены к исходным значениям." -ForegroundColor Green
}

function Set-SystemResponsivenessGaming {
    [CmdletBinding()]
    param(
        [switch]$DryRun = $false
    )

    Write-Host "`n[System Responsiveness] Настройка системного мультимедийного профиля..." -ForegroundColor Cyan

    if ($DryRun) {
        Write-Host "  [DRY-RUN] Будет установлено: SystemResponsiveness=0, GPU Priority=8, Priority=6" -ForegroundColor DarkGray
        return
    }

    $targets = @(
        @{ Path = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"; Name = "SystemResponsiveness" },
        @{ Path = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"; Name = "NetworkThrottlingIndex" },
        @{ Path = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games"; Name = "GPU Priority" },
        @{ Path = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games"; Name = "Priority" },
        @{ Path = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games"; Name = "Scheduling Category" },
        @{ Path = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games"; Name = "SFIO Priority" }
    )
    Save-RegistrySnapshot -Category "SystemResponsiveness" -RegistryTargets $targets -DryRun:$DryRun | Out-Null

    try {
        $sysProfile = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
        Set-ItemProperty -Path $sysProfile -Name "SystemResponsiveness" -Value 0 -Type DWord -Force
        Set-ItemProperty -Path $sysProfile -Name "NetworkThrottlingIndex" -Value 0xFFFFFFFF -Type DWord -Force

        $tasksGames = "$sysProfile\Tasks\Games"
        if (-not (Test-Path $tasksGames)) {
            New-Item -Path $tasksGames -Force | Out-Null
        }
        Set-ItemProperty -Path $tasksGames -Name "Affinity" -Value 0 -Type DWord -Force
        Set-ItemProperty -Path $tasksGames -Name "Background Only" -Value "False" -Type String -Force
        Set-ItemProperty -Path $tasksGames -Name "Clock Rate" -Value 10000 -Type DWord -Force
        Set-ItemProperty -Path $tasksGames -Name "GPU Priority" -Value 8 -Type DWord -Force
        Set-ItemProperty -Path $tasksGames -Name "Priority" -Value 6 -Type DWord -Force
        Set-ItemProperty -Path $tasksGames -Name "Scheduling Category" -Value "High" -Type String -Force
        Set-ItemProperty -Path $tasksGames -Name "SFIO Priority" -Value "High" -Type String -Force

        Write-Host "  [OK] SystemResponsiveness = 0 (100% ресурсов отдано играм без резервации 20% Windows)" -ForegroundColor Green
        Write-Host "  [OK] NetworkThrottlingIndex = 0xFFFFFFFF (отключение троттлинга сетевых пакетов)" -ForegroundColor Green
        Write-Host "  [OK] Профиль Games: GPU Priority = 8 | Priority = 6 | Category = High" -ForegroundColor Green
    }
    catch {
        Write-Host "  [ERROR] Ошибка настройки SystemResponsiveness: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Restore-SystemResponsiveness {
    [CmdletBinding()]
    param()

    Write-Host "[System Responsiveness] Откат SystemResponsiveness..." -ForegroundColor Yellow
    $restored = Restore-RegistrySnapshot -Category "SystemResponsiveness"
    
    # Восстановление дефолтов только если снимка не было
    if (-not $restored.Success) {
        $sysProfile = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
        Set-ItemProperty -Path $sysProfile -Name "SystemResponsiveness" -Value 20 -Type DWord -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $sysProfile -Name "NetworkThrottlingIndex" -Value 10 -Type DWord -Force -ErrorAction SilentlyContinue
        Write-Host "[System Responsiveness] Восстановлены стандартные значения Windows (20/10)." -ForegroundColor Green
    }
}

function Get-VbsStatus {
    try {
        $dg = Get-CimInstance -ClassName Win32_DeviceGuard -Namespace root\Microsoft\Windows\DeviceGuard -ErrorAction Stop
        $vbsRunning = ($dg.VirtualizationBasedSecurityStatus -eq 2)
        $hvciRunning = ($dg.SecurityServicesRunning -contains 1 -or $dg.SecurityServicesRunning -contains 2)
        return @{
            VbsActive  = $vbsRunning
            HvciActive = $hvciRunning
            RawStatus  = $dg.VirtualizationBasedSecurityStatus
        }
    } catch {
        return @{
            VbsActive  = $false
            HvciActive = $false
            RawStatus  = 0
        }
    }
}

function Set-VbsState {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [bool]$Enable,
        [switch]$DryRun = $false
    )

    $actionName = if ($Enable) { "Включение" } else { "Отключение" }
    Write-Host "`n[VBS / Memory Integrity] $actionName изоляции ядра (HVCI/VBS)..." -ForegroundColor Cyan

    if (-not $Enable) {
        Write-Host "  [ВНИМАНИЕ] Отключение изоляции ядра (VBS/HVCI) увеличивает FPS на 5-15% в процессорах" -ForegroundColor Yellow
        Write-Host "  без аппаратной виртуализации, но снижает защиту ядра от вредоносных драйверов." -ForegroundColor Yellow
    }

    if ($DryRun) {
        Write-Host "  [DRY-RUN] Режим Dry-Run: реестровые ключи DeviceGuard не будут изменены." -ForegroundColor DarkGray
        return
    }

    $val = if ($Enable) { 1 } else { 0 }

    try {
        $dgPath = "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard"
        if (-not (Test-Path $dgPath)) { New-Item -Path $dgPath -Force | Out-Null }
        Set-ItemProperty -Path $dgPath -Name "EnableVirtualizationBasedSecurity" -Value $val -Type DWord -Force

        $hvciPath = "$dgPath\Scenarios\HypervisorEnforcedCodeIntegrity"
        if (-not (Test-Path $hvciPath)) { New-Item -Path $hvciPath -Force | Out-Null }
        Set-ItemProperty -Path $hvciPath -Name "Enabled" -Value $val -Type DWord -Force

        Write-Host "  [OK] Параметры VBS/HVCI обновлены. Требуется перезагрузка компьютера." -ForegroundColor Green
    }
    catch {
        Write-Host "  [ERROR] Ошибка изменения VBS: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Win32 Memory P/Invoke Cleaner (SeProfileSingleProcessPrivilege + NtSetSystemInformation)
try {
    $cleanerTypeDefinition = @"
using System;
using System.Diagnostics;
using System.Runtime.InteropServices;

public class Win11MemoryCleaner {
    [DllImport("ntdll.dll")]
    public static extern int NtSetSystemInformation(int SystemInformationClass, ref int SystemInformation, int SystemInformationLength);

    [DllImport("advapi32.dll", SetLastError = true)]
    public static extern bool OpenProcessToken(IntPtr ProcessHandle, uint DesiredAccess, out IntPtr TokenHandle);

    [DllImport("advapi32.dll", SetLastError = true, CharSet = CharSet.Auto)]
    public static extern bool LookupPrivilegeValue(string lpSystemName, string lpName, out long lpLuid);

    [DllImport("advapi32.dll", SetLastError = true)]
    public static extern bool AdjustTokenPrivileges(IntPtr TokenHandle, bool DisableAllPrivileges, ref TOKEN_PRIVILEGES NewState, uint BufferLength, IntPtr PreviousState, IntPtr ReturnLength);

    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool CloseHandle(IntPtr hObject);

    [StructLayout(LayoutKind.Sequential, Pack = 1)]
    public struct TOKEN_PRIVILEGES {
        public int PrivilegeCount;
        public long Luid;
        public int Attributes;
    }

    private const int SE_PRIVILEGE_ENABLED = 0x00000002;
    private const int TOKEN_QUERY = 0x00000008;
    private const int TOKEN_ADJUST_PRIVILEGES = 0x00000020;
    private const int SystemMemoryListInformation = 80; // 0x50
    private const int MemoryEmptyWorkingSets = 2;
    private const int MemoryPurgeStandbyList = 4;

    public static bool EnablePrivilege(string privilegeName) {
        IntPtr hToken;
        if (!OpenProcessToken(Process.GetCurrentProcess().Handle, TOKEN_ADJUST_PRIVILEGES | TOKEN_QUERY, out hToken)) {
            return false;
        }
        try {
            long luid;
            if (!LookupPrivilegeValue(null, privilegeName, out luid)) {
                return false;
            }
            TOKEN_PRIVILEGES tp = new TOKEN_PRIVILEGES();
            tp.PrivilegeCount = 1;
            tp.Luid = luid;
            tp.Attributes = SE_PRIVILEGE_ENABLED;
            return AdjustTokenPrivileges(hToken, false, ref tp, 0, IntPtr.Zero, IntPtr.Zero);
        } finally {
            CloseHandle(hToken);
        }
    }

    public static int PurgeStandbyList() {
        EnablePrivilege("SeProfileSingleProcessPrivilege");
        EnablePrivilege("SeIncreaseQuotaPrivilege");
        int command = MemoryPurgeStandbyList;
        return NtSetSystemInformation(SystemMemoryListInformation, ref command, sizeof(int));
    }

    public static int PurgeWorkingSets() {
        EnablePrivilege("SeProfileSingleProcessPrivilege");
        EnablePrivilege("SeIncreaseQuotaPrivilege");
        int command = MemoryEmptyWorkingSets;
        return NtSetSystemInformation(SystemMemoryListInformation, ref command, sizeof(int));
    }
}
"@
    if (-not ([System.Management.Automation.PSTypeName]'Win11MemoryCleaner').Type) {
        Add-Type -TypeDefinition $cleanerTypeDefinition -Language CSharp -ErrorAction SilentlyContinue
    }
} catch {}

function Clear-StandbyRamAndWorkingSet {
    [CmdletBinding()]
    param(
        [switch]$DryRun = $false
    )

    Write-Host "`n[RAM Cleaner] Очистка Standby RAM кэша и выгрузка неиспользуемых системных Working Sets..." -ForegroundColor Cyan

    $osBefore = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
    $freeBeforeMb = if ($osBefore) { [math]::Round($osBefore.FreePhysicalMemory / 1024, 0) } else { 0 }

    if ($DryRun) {
        Write-Host "  [DRY-RUN] Будет вызван NtSetSystemInformation (MemoryPurgeStandbyList + MemoryEmptyWorkingSets) с получением SeProfileSingleProcessPrivilege." -ForegroundColor DarkGray
        Write-Host "  [DRY-RUN] Свободно памяти сейчас: $freeBeforeMb МБ" -ForegroundColor DarkGray
        return [PSCustomObject]@{
            Success       = $true
            FreedMb       = 0
            FreeBeforeMb  = $freeBeforeMb
            FreeAfterMb   = $freeBeforeMb
            StandbyStatus = 0
            WsStatus      = 0
        }
    }

    $standbyStatus = -1
    $wsStatus = -1
    try {
        $standbyStatus = [Win11MemoryCleaner]::PurgeStandbyList()
        $wsStatus = [Win11MemoryCleaner]::PurgeWorkingSets()
        [System.GC]::Collect()
    } catch {
        Write-Host "  [ERROR] Исключение при очистке памяти: $($_.Exception.Message)" -ForegroundColor Red
    }

    $osAfter = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
    $freeAfterMb = if ($osAfter) { [math]::Round($osAfter.FreePhysicalMemory / 1024, 0) } else { 0 }
    $diffMb = [math]::Max(0, ($freeAfterMb - $freeBeforeMb))

    $success = ($standbyStatus -eq 0 -or $wsStatus -eq 0)
    if ($success) {
        Write-Host "  [OK] Standby List и Working Sets успешно очищены (NTSTATUS: 0x$($standbyStatus.ToString('X8')) / 0x$($wsStatus.ToString('X8')))" -ForegroundColor Green
        Write-Host "  [OK] Память до: $freeBeforeMb МБ | После: $freeAfterMb МБ | Освобождено: ~$diffMb МБ" -ForegroundColor Green
    } else {
        Write-Host "  [WARNING] Код возврата NTSTATUS: Standby=0x$($standbyStatus.ToString('X8')), WorkingSet=0x$($wsStatus.ToString('X8'))" -ForegroundColor Yellow
    }

    return [PSCustomObject]@{
        Success       = $success
        FreedMb       = $diffMb
        FreeBeforeMb  = $freeBeforeMb
        FreeAfterMb   = $freeAfterMb
        StandbyStatus = $standbyStatus
        WsStatus      = $wsStatus
    }
}

function Get-MsiModeStatus {
    [CmdletBinding()]
    param()

    $pci = @(Get-PciMsiDevices)
    $gpu = @($pci | Where-Object { $_.Category -eq 'GPU' })
    $net = @($pci | Where-Object { $_.Category -eq 'Network' })
    $gpuOk = ($gpu.Count -gt 0 -and @($gpu | Where-Object { $_.MsiActive }).Count -eq $gpu.Count)
    $netOk = ($net.Count -gt 0 -and @($net | Where-Object { $_.MsiActive }).Count -eq $net.Count)
    $isOptimal = ($gpuOk -and $netOk)
    return [PSCustomObject]@{
        Optimal     = $isOptimal
        GpuMsi      = $gpuOk
        NetworkMsi  = $netOk
        Description = if ($isOptimal) { "MSI High Priority активен (GPU & Сеть)" } else { "Дефолтный режим IRQ (Line-based)" }
    }
}

function Get-CpuGamingSchedulingStatus {
    [CmdletBinding()]
    param()

    $priCtrl = Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl" -ErrorAction SilentlyContinue
    $win32Pri = if ($priCtrl -and $null -ne $priCtrl.PSObject.Properties['Win32PrioritySeparation']) { [int]$priCtrl.Win32PrioritySeparation } else { 2 }
    $pThrottle = Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling" -ErrorAction SilentlyContinue
    $isPtOff = ($pThrottle -and $pThrottle.PSObject.Properties['PowerThrottlingOff'] -and $pThrottle.PowerThrottlingOff -eq 1)
    $isOpt = (($win32Pri -eq 38 -or $win32Pri -eq 40) -and $isPtOff)
    return [PSCustomObject]@{
        Optimal                 = $isOpt
        Win32PrioritySeparation = $win32Pri
        PowerThrottlingOff      = [bool]$isPtOff
        Description             = if ($isOpt) { "Кванты 38 (0x26) + Power Throttling отключен" } else { "Стандартные кванты (Дефолт)" }
    }
}

function Get-UltimatePerformancePlanStatus {
    [CmdletBinding()]
    param()

    $activeSchemeGuid = (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Power\User\PowerSchemes' -ErrorAction SilentlyContinue).ActivePowerScheme
    $activeSchemeName = (powercfg /getactivescheme 2>&1)
    $isUltimate = ($activeSchemeName -like "*Максимальная производительность*" -or $activeSchemeName -like "*Ultimate Performance*" -or $activeSchemeGuid -eq "e9a42b02-d5df-448d-aa00-03f14749eb61")
    return [PSCustomObject]@{
        Active      = $isUltimate
        Optimal     = $isUltimate
        Description = if ($isUltimate) { "Схема 'Максимальная производительность' активна" } else { "Стандартная схема питания" }
    }
}

function Get-SystemResponsivenessStatus {
    [CmdletBinding()]
    param()

    $sysProfile = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" -ErrorAction SilentlyContinue
    $isZero = ($sysProfile -and $sysProfile.PSObject.Properties['SystemResponsiveness'] -and $sysProfile.SystemResponsiveness -eq 0)
    return [PSCustomObject]@{
        Optimal     = [bool]$isZero
        Value       = if ($sysProfile -and $null -ne $sysProfile.PSObject.Properties['SystemResponsiveness']) { [int]$sysProfile.SystemResponsiveness } else { 20 }
        Description = if ($isZero) { "0% резерва (100% мощности процессора играм)" } else { "20% системный резерв (Дефолт)" }
    }
}

Export-ModuleMember -Function Get-PciMsiDevices, Set-GamingMsiMode, Restore-GamingMsiMode, `
                             Set-CpuGamingScheduling, Restore-CpuGamingScheduling, Get-ProcessorPowerSettingsState, `
                             Enable-UltimatePerformancePlan, Restore-ActivePowerScheme, `
                             Set-SystemResponsivenessGaming, Restore-SystemResponsiveness, `
                             Get-VbsStatus, Set-VbsState, Clear-StandbyRamAndWorkingSet, `
                             Get-MsiModeStatus, Get-CpuGamingSchedulingStatus, `
                             Get-UltimatePerformancePlanStatus, Get-SystemResponsivenessStatus
