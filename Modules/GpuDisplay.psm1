# GpuDisplay.psm1 - GPU, Display, MPO, HAGS, HDCP & Shader Cache Optimization
# Encoding: UTF-8

Set-StrictMode -Version Latest

Import-Module (Join-Path -Path $PSScriptRoot -ChildPath "Safety.psm1") -ErrorAction SilentlyContinue

function Get-NvidiaDisplayAdapterKeys {
    [CmdletBinding()]
    param()

    $results = [System.Collections.Generic.List[PSCustomObject]]::new()
    $classKey = "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}"

    if (-not (Test-Path -Path $classKey)) {
        return $results
    }

    try {
        $subKeys = Get-ChildItem -Path $classKey -ErrorAction SilentlyContinue | Where-Object { $_.PSChildName -match '^\d{4}$' }
        foreach ($subKey in $subKeys) {
            $props = Get-ItemProperty -Path $subKey.PSPath -ErrorAction SilentlyContinue
            if ($props) {
                $provider = if ($props.PSObject.Properties['ProviderName']) { [string]$props.ProviderName } else { "" }
                $desc     = if ($props.PSObject.Properties['DriverDesc']) { [string]$props.DriverDesc } else { "" }
                $hwId     = if ($props.PSObject.Properties['MatchingDeviceId']) { [string]$props.MatchingDeviceId } else { "" }

                if ($provider -like "*NVIDIA*" -or $desc -like "*NVIDIA*" -or $hwId -like "*ven_10de*") {
                    $results.Add([PSCustomObject]@{
                        SubKeyName       = $subKey.PSChildName
                        RegistryPath     = "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}\$($subKey.PSChildName)"
                        DriverDesc       = $desc
                        ProviderName     = $provider
                        MatchingDeviceId = $hwId
                    })
                }
            }
        }
    } catch {
        Write-Verbose "Error enumerating GPU display adapters: $_"
    }

    return $results
}

function Get-MpoStatus {
    [CmdletBinding()]
    param()

    $dwmKey = "HKLM:\SOFTWARE\Microsoft\Windows\Dwm"
    $mode = $null
    if (Test-Path -Path $dwmKey) {
        $p = Get-ItemProperty -Path $dwmKey -ErrorAction SilentlyContinue
        if ($p -and $null -ne $p.PSObject.Properties['OverlayTestMode']) {
            $mode = [int]$p.OverlayTestMode
        }
    }

    $isDisabled = ($mode -eq 5)
    return [PSCustomObject]@{
        Disabled    = $isDisabled
        Value       = $mode
        Description = if ($isDisabled) { "Отключен (OverlayTestMode=5, нет мерцаний/статтеров)" } else { "Включен (Windows дефолт)" }
    }
}

function Set-MpoState {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [bool]$Disable = $true,
        [switch]$DryRun = $false
    )

    $actionText = if ($Disable) { "Отключение MPO (OverlayTestMode=5)" } else { "Включение MPO (дефолт Windows)" }
    Write-Host "`n[MPO Optimizer] $actionText для устранения мерцаний и микро-фризов..." -ForegroundColor Cyan

    $dwmPath = "HKLM:\SOFTWARE\Microsoft\Windows\Dwm"

    if ($DryRun) {
        Write-Host "  [DRY-RUN] Будет установлено OverlayTestMode = $(if ($Disable) { 5 } else { 0 }) в $dwmPath" -ForegroundColor DarkGray
        return
    }

    $targets = @(
        @{ Path = $dwmPath; Name = "OverlayTestMode" }
    )
    Save-RegistrySnapshot -Category "MpoSetting" -RegistryTargets $targets -DryRun:$DryRun | Out-Null

    try {
        if (-not (Test-Path -Path $dwmPath)) {
            New-Item -Path $dwmPath -Force | Out-Null
        }

        if ($Disable) {
            Set-ItemProperty -Path $dwmPath -Name "OverlayTestMode" -Value 5 -Type DWord -Force
            Write-Host "  [OK] MPO отключен (OverlayTestMode = 5). Устранены конфликты GPU планировщика с Discord, OBS и браузерами." -ForegroundColor Green
        } else {
            Remove-ItemProperty -Path $dwmPath -Name "OverlayTestMode" -ErrorAction SilentlyContinue
            Write-Host "  [OK] MPO возвращен к стандартному режиму Windows." -ForegroundColor Green
        }
    } catch {
        Write-Host "  [ERROR] Ошибка изменения параметра MPO: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Restore-MpoState {
    [CmdletBinding()]
    param()

    Write-Host "[MPO Optimizer] Откат настройки MPO к исходному состоянию..." -ForegroundColor Yellow
    $restored = Restore-RegistrySnapshot -Category "MpoSetting"
    if (-not $restored.Success) {
        Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\Dwm" -Name "OverlayTestMode" -ErrorAction SilentlyContinue
        Write-Host "[MPO Optimizer] Ключ OverlayTestMode удален (дефолт Windows)." -ForegroundColor Green
    }
}

function Get-HagsStatus {
    [CmdletBinding()]
    param()

    $gfxKey = "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers"
    $mode = $null
    if (Test-Path -Path $gfxKey) {
        $p = Get-ItemProperty -Path $gfxKey -ErrorAction SilentlyContinue
        if ($p -and $null -ne $p.PSObject.Properties['HwSchMode']) {
            $mode = [int]$p.HwSchMode
        }
    }

    $isEnabled = ($mode -eq 2)
    return [PSCustomObject]@{
        Enabled     = $isEnabled
        Value       = $mode
        Description = if ($isEnabled) { "Включен (HwSchMode=2, DLSS 3 Frame Gen готов)" } else { "Выключен/Дефолт (HwSchMode=$mode)" }
    }
}

function Set-HagsState {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [bool]$Enable = $true,
        [switch]$DryRun = $false
    )

    $actionText = if ($Enable) { "Включение HAGS (Hardware-Accelerated GPU Scheduling)" } else { "Отключение HAGS" }
    Write-Host "`n[HAGS Optimizer] $actionText..." -ForegroundColor Cyan

    $gfxPath = "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers"
    $val = if ($Enable) { 2 } else { 1 }

    if ($DryRun) {
        Write-Host "  [DRY-RUN] Будет установлено HwSchMode = $val в $gfxPath" -ForegroundColor DarkGray
        return
    }

    $targets = @(
        @{ Path = $gfxPath; Name = "HwSchMode" }
    )
    Save-RegistrySnapshot -Category "HagsSetting" -RegistryTargets $targets -DryRun:$DryRun | Out-Null

    try {
        if (-not (Test-Path -Path $gfxPath)) {
            New-Item -Path $gfxPath -Force | Out-Null
        }
        Set-ItemProperty -Path $gfxPath -Name "HwSchMode" -Value $val -Type DWord -Force
        $statusMsg = if ($Enable) { "включен (HwSchMode = 2, поддержка генерации кадров DLSS 3/FSR)" } else { "отключен (HwSchMode = 1)" }
        Write-Host "  [OK] HAGS $statusMsg. Изменения вступят в силу после перезагрузки." -ForegroundColor Green
    } catch {
        Write-Host "  [ERROR] Ошибка изменения параметра HAGS: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Restore-HagsState {
    [CmdletBinding()]
    param()

    Write-Host "[HAGS Optimizer] Откат настройки HAGS к исходному состоянию..." -ForegroundColor Yellow
    $restored = Restore-RegistrySnapshot -Category "HagsSetting"
    if (-not $restored.Success) {
        Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" -Name "HwSchMode" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
        Write-Host "[HAGS Optimizer] HwSchMode выставлен в 1 (дефолт)." -ForegroundColor Green
    }
}

function Set-DirectXWindowedOptimization {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [bool]$Enable = $true,
        [switch]$DryRun = $false
    )

    $actionText = if ($Enable) { "Включение оптимизаций для оконных игр DirectX (AutoPlayMode=1)" } else { "Отключение оконных оптимизаций" }
    Write-Host "`n[DirectX Optimizer] $actionText..." -ForegroundColor Cyan

    $dxPath = "HKCU:\Software\Microsoft\DirectX\UserGpuPreferences"

    if ($DryRun) {
        Write-Host "  [DRY-RUN] Будет установлено DirectXUserGlobalSettings = '$(if ($Enable) { 'AutoPlayMode=1;' } else { 'AutoPlayMode=0;' })' в $dxPath" -ForegroundColor DarkGray
        return
    }

    $targets = @(
        @{ Path = $dxPath; Name = "DirectXUserGlobalSettings" }
    )
    Save-RegistrySnapshot -Category "DirectXWindowed" -RegistryTargets $targets -DryRun:$DryRun | Out-Null

    try {
        if (-not (Test-Path -Path $dxPath)) {
            New-Item -Path $dxPath -Force | Out-Null
        }

        if ($Enable) {
            Set-ItemProperty -Path $dxPath -Name "DirectXUserGlobalSettings" -Value "AutoPlayMode=1;" -Type String -Force
            Write-Host "  [OK] Оптимизации для оконных игр DirectX включены (снижение задержки и поддержка VRR в borderless окне)." -ForegroundColor Green
        } else {
            Remove-ItemProperty -Path $dxPath -Name "DirectXUserGlobalSettings" -ErrorAction SilentlyContinue
            Write-Host "  [OK] Настройки DirectX возвращены по умолчанию." -ForegroundColor Green
        }
    } catch {
        Write-Host "  [ERROR] Ошибка настройки DirectX: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Restore-DirectXWindowedOptimization {
    [CmdletBinding()]
    param()

    Write-Host "[DirectX Optimizer] Откат оконных оптимизаций DirectX..." -ForegroundColor Yellow
    $restored = Restore-RegistrySnapshot -Category "DirectXWindowed"
    if (-not $restored.Success) {
        Remove-ItemProperty -Path "HKCU:\Software\Microsoft\DirectX\UserGpuPreferences" -Name "DirectXUserGlobalSettings" -ErrorAction SilentlyContinue
        Write-Host "[DirectX Optimizer] Параметр DirectXUserGlobalSettings удален." -ForegroundColor Green
    }
}

function Set-WindowsUpdateDriverProtection {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [bool]$Enable = $true,
        [switch]$DryRun = $false
    )

    $actionText = if ($Enable) { "Блокировка автоматической замены видеодрайвера через Windows Update" } else { "Разрешение обновления драйверов через Windows Update" }
    Write-Host "`n[Driver Safety] $actionText..." -ForegroundColor Cyan

    $wuPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
    $val = if ($Enable) { 1 } else { 0 }

    if ($DryRun) {
        Write-Host "  [DRY-RUN] Будет установлено ExcludeWUDriversInQualityUpdate = $val в $wuPath" -ForegroundColor DarkGray
        return
    }

    $targets = @(
        @{ Path = $wuPath; Name = "ExcludeWUDriversInQualityUpdate" }
    )
    Save-RegistrySnapshot -Category "WUDriverProtection" -RegistryTargets $targets -DryRun:$DryRun | Out-Null

    try {
        if (-not (Test-Path -Path $wuPath)) {
            New-Item -Path $wuPath -Force | Out-Null
        }
        Set-ItemProperty -Path $wuPath -Name "ExcludeWUDriversInQualityUpdate" -Value $val -Type DWord -Force
        $msg = if ($Enable) { "активирована (Windows Update больше не перезапишет ваши кастомные драйверы GPU)" } else { "отключена" }
        Write-Host "  [OK] Защита драйверов GPU $msg." -ForegroundColor Green
    } catch {
        Write-Host "  [ERROR] Ошибка настройки защиты драйверов: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Restore-WindowsUpdateDriverProtection {
    [CmdletBinding()]
    param()

    Write-Host "[Driver Safety] Откат защиты драйверов Windows Update..." -ForegroundColor Yellow
    $restored = Restore-RegistrySnapshot -Category "WUDriverProtection"
    if (-not $restored.Success) {
        Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" -Name "ExcludeWUDriversInQualityUpdate" -ErrorAction SilentlyContinue
        Write-Host "[Driver Safety] ExcludeWUDriversInQualityUpdate удален." -ForegroundColor Green
    }
}

function Set-NvidiaHdcpDisable {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [bool]$Disable = $true,
        [switch]$DryRun = $false
    )

    Write-Host "`n[NVIDIA HDCP DRM Killer] Поиск установленных видеокарт NVIDIA..." -ForegroundColor Cyan
    $nvidiaGpus = @(Get-NvidiaDisplayAdapterKeys)

    if ($nvidiaGpus.Count -eq 0) {
        Write-Host "  [INFO] Видеокарты NVIDIA не обнаружены (пропуск настройки HDCP DRM)." -ForegroundColor Gray
        return
    }

    if ($DryRun) {
        foreach ($gpu in $nvidiaGpus) {
            Write-Host "  [DRY-RUN] На видеокарте '$($gpu.DriverDesc)' ($($gpu.SubKeyName)) будет установлено RMHdcpKeyglobZero = $(if ($Disable) { 1 } else { 0 })" -ForegroundColor DarkGray
        }
        return
    }

    $targets = @()
    foreach ($gpu in $nvidiaGpus) {
        $targets += @{ Path = $gpu.RegistryPath; Name = "RMHdcpKeyglobZero" }
    }
    Save-RegistrySnapshot -Category "NvidiaHdcp" -RegistryTargets $targets -DryRun:$DryRun | Out-Null

    $applied = 0
    foreach ($gpu in $nvidiaGpus) {
        try {
            if ($Disable) {
                Set-ItemProperty -Path $gpu.RegistryPath -Name "RMHdcpKeyglobZero" -Value 1 -Type DWord -Force
                Write-Host "  [OK] HDCP DRM рукопожатия отключены для '$($gpu.DriverDesc)' (снижение инпут-лага и задержек D3D)" -ForegroundColor Green
            } else {
                Remove-ItemProperty -Path $gpu.RegistryPath -Name "RMHdcpKeyglobZero" -ErrorAction SilentlyContinue
                Write-Host "  [OK] HDCP DRM восстановлен для '$($gpu.DriverDesc)'" -ForegroundColor Green
            }
            $applied++
        } catch {
            Write-Host "  [ERROR] Ошибка настройки HDCP для $($gpu.SubKeyName): $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}

function Restore-NvidiaHdcp {
    [CmdletBinding()]
    param()

    Write-Host "[NVIDIA HDCP] Откат настройки HDCP DRM к дефолту..." -ForegroundColor Yellow
    $restored = Restore-RegistrySnapshot -Category "NvidiaHdcp"
    if (-not $restored.Success) {
        $nvidiaGpus = @(Get-NvidiaDisplayAdapterKeys)
        foreach ($gpu in $nvidiaGpus) {
            Remove-ItemProperty -Path $gpu.RegistryPath -Name "RMHdcpKeyglobZero" -ErrorAction SilentlyContinue
        }
        Write-Host "[NVIDIA HDCP] Параметр RMHdcpKeyglobZero очищен." -ForegroundColor Green
    }
}

function Clear-ShaderCacheAndTemp {
    [CmdletBinding()]
    param(
        [switch]$DryRun = $false
    )

    Write-Host "`n[Shader Cache & Clean] Очистка поврежденного кэша шейдеров DirectX/OpenGL и временных файлов..." -ForegroundColor Cyan

    $localAppData = [System.Environment]::GetFolderPath([System.Environment+SpecialFolder]::LocalApplicationData)
    $tempDir = [System.IO.Path]::GetTempPath()
    $wuDownload = "C:\Windows\SoftwareDistribution\Download"

    $targets = @(
        @{ Name = "NVIDIA DirectX Shader Cache"; Path = (Join-Path $localAppData "NVIDIA\DXCache") },
        @{ Name = "NVIDIA OpenGL Shader Cache";  Path = (Join-Path $localAppData "NVIDIA\GLCache") },
        @{ Name = "Direct3D Shader Cache";       Path = (Join-Path $localAppData "D3DSCache") },
        @{ Name = "AMD DirectX Shader Cache";    Path = (Join-Path $localAppData "AMD\DxCache") },
        @{ Name = "Пользовательский TEMP";        Path = $tempDir },
        @{ Name = "Кэш загрузок Windows Update"; Path = $wuDownload }
    )

    $totalCleaned = 0
    $totalFreedBytes = [long]0

    foreach ($tgt in $targets) {
        $p = $tgt.Path
        if (-not (Test-Path -Path $p)) {
            continue
        }

        Write-Host "  -> Сканирование: $($tgt.Name)..." -ForegroundColor White

        $files = @(Get-ChildItem -Path $p -Recurse -File -Force -ErrorAction SilentlyContinue)
        $dirBytes = [long]0
        foreach ($f in $files) {
            $dirBytes += $f.Length
        }
        $dirMb = [math]::Round($dirBytes / 1MB, 2)

        if ($DryRun) {
            Write-Host "     [DRY-RUN] Будет очищено: $($files.Count) файлов (~$dirMb МБ)" -ForegroundColor DarkGray
            $totalCleaned += $files.Count
            $totalFreedBytes += $dirBytes
            continue
        }

        $cleanedHere = 0
        $freedHere = [long]0

        foreach ($f in $files) {
            try {
                $len = $f.Length
                Remove-Item -Path $f.FullName -Force -ErrorAction Stop
                $cleanedHere++
                $freedHere += $len
            } catch {
                # Файл может быть заблокирован текущей запущенной игрой или explorer
            }
        }

        $freedMb = [math]::Round($freedHere / 1MB, 2)
        Write-Host "     [OK] Очищено: $cleanedHere файлов (~$freedMb МБ)" -ForegroundColor Green
        $totalCleaned += $cleanedHere
        $totalFreedBytes += $freedHere

        # Удаление пустых подпапок в кэше
        try {
            Get-ChildItem -Path $p -Recurse -Directory -Force -ErrorAction SilentlyContinue |
                Sort-Object -Property FullName -Descending |
                Where-Object { -not (Get-ChildItem -Path $_.FullName -Force -ErrorAction SilentlyContinue) } |
                Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
        } catch {}
    }

    $totalFreedMb = [math]::Round($totalFreedBytes / 1MB, 2)
    Write-Host "`n[Shader Cache & Clean] Всего очищено: $totalCleaned файлов, освобождено ~$totalFreedMb МБ дискового пространства!" -ForegroundColor Green

    return [PSCustomObject]@{
        TotalFiles = $totalCleaned
        TotalFreedMb = $totalFreedMb
    }
}

function Invoke-FullGpuDisplayOptimization {
    [CmdletBinding()]
    param(
        [switch]$DryRun = $false
    )

    Write-Host "`n>>> ПРИМЕНЕНИЕ КОМПЛЕКСА ОПТИМИЗАЦИЙ GPU И ДИСПЛЕЯ <<<" -ForegroundColor Green
    Set-MpoState -Disable $true -DryRun:$DryRun
    Set-HagsState -Enable $true -DryRun:$DryRun
    Set-DirectXWindowedOptimization -Enable $true -DryRun:$DryRun
    Set-WindowsUpdateDriverProtection -Enable $true -DryRun:$DryRun
    Set-NvidiaHdcpDisable -Disable $true -DryRun:$DryRun
    Write-Host "`n[OK] Все параметры GPU и дисплея оптимизированы!" -ForegroundColor Green
}

function Restore-AllGpuDisplaySettings {
    [CmdletBinding()]
    param()

    Write-Host "`n>>> ОТКАТ ВСЕХ ПАРАМЕТРОВ GPU И ДИСПЛЕЯ К ЗАВОДСКИМ ДЕФОЛТАМ <<<" -ForegroundColor Yellow
    Restore-MpoState
    Restore-HagsState
    Restore-DirectXWindowedOptimization
    Restore-WindowsUpdateDriverProtection
    Restore-NvidiaHdcp
    Write-Host "`n[OK] Настройки GPU и дисплея полностью возвращены к дефолтным значениям Windows." -ForegroundColor Green
}

function Get-DirectXWindowedStatus {
    [CmdletBinding()]
    param()

    $dxProp = (Get-ItemProperty "HKCU:\Software\Microsoft\DirectX\UserGpuPreferences" -ErrorAction SilentlyContinue)
    $curDx = ($dxProp -and $dxProp.PSObject.Properties['DirectXUserGlobalSettings'] -and ($dxProp.DirectXUserGlobalSettings -like "*AutoPlayMode=1*"))
    return [PSCustomObject]@{
        Optimal     = [bool]$curDx
        Description = if ($curDx) { "Включено (AutoPlayMode=1, низкий инпут-лаг)" } else { "Выключено (Дефолт)" }
    }
}

function Get-WindowsUpdateDriverProtectionStatus {
    [CmdletBinding()]
    param()

    $wuProp = (Get-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" -ErrorAction SilentlyContinue)
    $curWu = ($wuProp -and $wuProp.PSObject.Properties['ExcludeWUDriversInQualityUpdate'] -and $wuProp.ExcludeWUDriversInQualityUpdate -eq 1)
    return [PSCustomObject]@{
        Protected   = [bool]$curWu
        Optimal     = [bool]$curWu
        Description = if ($curWu) { "Защищен (ExcludeWUDrivers=1)" } else { "Не защищен (Дефолт)" }
    }
}

function Get-NvidiaHdcpStatus {
    [CmdletBinding()]
    param()

    $nvKeys = @(Get-NvidiaDisplayAdapterKeys)
    $hasNv = ($nvKeys.Count -gt 0)
    $curHdcp = $false
    if ($hasNv) {
        $p = Get-ItemProperty -Path $nvKeys[0].RegistryPath -ErrorAction SilentlyContinue
        if ($p -and $p.PSObject.Properties['RMHdcpKeyglobZero'] -and $p.RMHdcpKeyglobZero -eq 1) {
            $curHdcp = $true
        }
    }
    $isOpt = (-not $hasNv -or $curHdcp)
    $desc = if (-not $hasNv) { "Н/Д (GPU не NVIDIA)" } elseif ($curHdcp) { "DRM отключен (RMHdcpKeyglobZero=1)" } else { "DRM активен (Дефолт)" }
    return [PSCustomObject]@{
        Optimal     = $isOpt
        Disabled    = $curHdcp
        IsNvidia    = $hasNv
        Description = $desc
    }
}

Export-ModuleMember -Function Get-NvidiaDisplayAdapterKeys, `
                             Get-MpoStatus, Set-MpoState, Restore-MpoState, `
                             Get-HagsStatus, Set-HagsState, Restore-HagsState, `
                             Set-DirectXWindowedOptimization, Restore-DirectXWindowedOptimization, `
                             Set-WindowsUpdateDriverProtection, Restore-WindowsUpdateDriverProtection, `
                             Set-NvidiaHdcpDisable, Restore-NvidiaHdcp, `
                             Clear-ShaderCacheAndTemp, `
                             Invoke-FullGpuDisplayOptimization, Restore-AllGpuDisplaySettings, `
                             Get-DirectXWindowedStatus, Get-WindowsUpdateDriverProtectionStatus, `
                             Get-NvidiaHdcpStatus
