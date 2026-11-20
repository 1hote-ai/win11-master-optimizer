# SystemUI.psm1 - Windows 11 UI, Explorer, GameDVR, Photo Viewer & USB Power
# Encoding: UTF-8

Set-StrictMode -Version Latest

Import-Module (Join-Path -Path $PSScriptRoot -ChildPath "Safety.psm1") -ErrorAction SilentlyContinue

function Restart-ExplorerGraceful {
    Write-Host "  -> Перезапуск Проводника (explorer.exe) для применения изменений..." -ForegroundColor Cyan
    Stop-Process -Name "explorer" -Force -ErrorAction SilentlyContinue
    Start-Sleep -Milliseconds 800
    if (-not (Get-Process -Name "explorer" -ErrorAction SilentlyContinue)) {
        Start-Process "explorer.exe"
    }
}

function Set-ClassicContextMenu {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [bool]$Enable,
        [switch]$DryRun = $false,
        [switch]$NoRestart = $false
    )

    $clsidKey = "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}"
    $inprocKey = "$clsidKey\InprocServer32"

    if ($DryRun) {
        $state = if ($Enable) { "Включение классического" } else { "Восстановление современного Win11" }
        Write-Host "  [DRY-RUN] $state меню проводника." -ForegroundColor DarkGray
        return
    }

    try {
        if ($Enable) {
            if (-not (Test-Path $clsidKey)) { New-Item -Path $clsidKey -Force | Out-Null }
            if (-not (Test-Path $inprocKey)) { New-Item -Path $inprocKey -Force | Out-Null }
            Set-Item -Path $inprocKey -Value "" -Force | Out-Null
            Write-Host "  [OK] Классическое контекстное меню Windows 10 активировано!" -ForegroundColor Green
        } else {
            if (Test-Path $clsidKey) {
                Remove-Item -Path $clsidKey -Recurse -Force -ErrorAction SilentlyContinue
            }
            Write-Host "  [OK] Стандартное контекстное меню Windows 11 возвращено!" -ForegroundColor Green
        }

        if (-not $NoRestart) {
            Restart-ExplorerGraceful
        }
    }
    catch {
        Write-Host "  [ERROR] Ошибка настройки контекстного меню: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Set-FileExplorerTweaks {
    [CmdletBinding()]
    param(
        [switch]$DryRun = $false,
        [switch]$NoRestart = $false
    )

    Write-Host "`n[Explorer Tweaks] Применение оптимальных настроек Проводника и панели задач..." -ForegroundColor Cyan

    if ($DryRun) {
        Write-Host "  [DRY-RUN] Будут включены: расширения файлов, компактный вид (UseCompactMode), открытие 'Этот компьютер'." -ForegroundColor DarkGray
        Write-Host "  [DRY-RUN] Будут отключены: спам недавних файлов, спам выделений поиска (Search Highlights), раздел 'Главная' и блок 'Рекомендуем' в Пуске." -ForegroundColor DarkGray
        Write-Host "  [DRY-RUN] Будет отключено автоматическое обслуживание Windows (MaintenanceDisabled = 1)." -ForegroundColor DarkGray
        return
    }

    $targets = @(
        @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; Name = "HideFileExt" },
        @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; Name = "Hidden" },
        @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; Name = "LaunchTo" },
        @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; Name = "UseCompactMode" },
        @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; Name = "TaskbarAnimations" },
        @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer"; Name = "ShowRecent" },
        @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer"; Name = "ShowFrequent" },
        @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\SearchSettings"; Name = "IsSearchHighlightsEnabled" },
        @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search"; Name = "EnableDynamicContentInWSB" },
        @{ Path = "HKCU:\Software\Classes\CLSID\{e88865ea-0e1c-4e20-9aa6-edcd0212c87c}"; Name = "System.IsPinnedToNameSpaceTree" },
        @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer"; Name = "HideRecommendedSection" },
        @{ Path = "HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device\Education"; Name = "IsEducationEnvironment" },
        @{ Path = "HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device\Start"; Name = "HideRecommendedSection" },
        @{ Path = "HKLM:\SOFTWARE\Classes\CLSID\{f874310e-b6b7-47dc-bc84-b9e6b38f5903}"; Name = "System.IsPinnedToNameSpaceTree" },
        @{ Path = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\Maintenance"; Name = "MaintenanceDisabled" },
        @{ Path = "HKCU:\Control Panel\Desktop"; Name = "MenuShowDelay" }
    )
    Save-RegistrySnapshot -Category "ExplorerUI" -RegistryTargets $targets -DryRun:$DryRun | Out-Null

    try {
        $advKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
        $expKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer"

        # 1. Всегда показывать расширения файлов (.exe, .txt, .zip)
        Set-ItemProperty -Path $advKey -Name "HideFileExt" -Value 0 -Type DWord -Force
        Write-Host "  [OK] Отображение расширений файлов включено" -ForegroundColor Green

        # 2. Показывать скрытые файлы и папки
        Set-ItemProperty -Path $advKey -Name "Hidden" -Value 1 -Type DWord -Force
        Write-Host "  [OK] Отображение скрытых файлов включено" -ForegroundColor Green

        # 3. Открывать Проводник на 'Этот компьютер' вместо 'Главная/Home'
        Set-ItemProperty -Path $advKey -Name "LaunchTo" -Value 1 -Type DWord -Force
        Write-Host "  [OK] Проводник по умолчанию открывает 'Этот компьютер'" -ForegroundColor Green

        # 4. Компактный режим отображения папок (Compact View)
        Set-ItemProperty -Path $advKey -Name "UseCompactMode" -Value 1 -Type DWord -Force
        Write-Host "  [OK] Компактный вид папок (Compact View) включен" -ForegroundColor Green

        # 5. Мгновенная отзывчивость меню и отключение анимаций панели задач
        Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "MenuShowDelay" -Value "0" -Type String -Force
        Set-ItemProperty -Path $advKey -Name "TaskbarAnimations" -Value 0 -Type DWord -Force
        Write-Host "  [OK] Задержка меню снижена до 0 мс (максимальная отзывчивость UI)" -ForegroundColor Green

        # 6. Отключение спама картинок и трендов в поиске (Search Highlights)
        $searchSettingsKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\SearchSettings"
        if (-not (Test-Path $searchSettingsKey)) { New-Item -Path $searchSettingsKey -Force | Out-Null }
        Set-ItemProperty -Path $searchSettingsKey -Name "IsSearchHighlightsEnabled" -Value 0 -Type DWord -Force

        $wsPolKey = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search"
        if (-not (Test-Path $wsPolKey)) { New-Item -Path $wsPolKey -Force | Out-Null }
        Set-ItemProperty -Path $wsPolKey -Name "EnableDynamicContentInWSB" -Value 0 -Type DWord -Force
        Write-Host "  [OK] Спам выделений и рекламы в поиске панели задач (Search Highlights) отключен" -ForegroundColor Green

        # 7. Отключение недавних файлов и папок в панели быстрого доступа
        Set-ItemProperty -Path $expKey -Name "ShowRecent" -Value 0 -Type DWord -Force
        Set-ItemProperty -Path $expKey -Name "ShowFrequent" -Value 0 -Type DWord -Force
        Write-Host "  [OK] Спам недавних файлов в быстром доступе отключен" -ForegroundColor Green

        # 8. Скрытие раздела Галерея в навигации Проводника
        $galleryClsid = "HKCU:\Software\Classes\CLSID\{e88865ea-0e1c-4e20-9aa6-edcd0212c87c}"
        if (-not (Test-Path $galleryClsid)) { New-Item -Path $galleryClsid -Force | Out-Null }
        Set-ItemProperty -Path $galleryClsid -Name "System.IsPinnedToNameSpaceTree" -Value 0 -Type DWord -Force
        Write-Host "  [OK] Раздел 'Галерея' скрыт из панели навигации" -ForegroundColor Green

        # 9. Скрытие раздела 'Главная' (Home) в навигации Проводника
        $homeClsid = "{f874310e-b6b7-47dc-bc84-b9e6b38f5903}"
        $homeClsidKey = "HKLM:\SOFTWARE\Classes\CLSID\$homeClsid"
        if (-not (Test-Path $homeClsidKey)) { New-Item -Path $homeClsidKey -Force | Out-Null }
        Set-ItemProperty -Path $homeClsidKey -Name "System.IsPinnedToNameSpaceTree" -Value 0 -Type DWord -Force
        $nsHome1 = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Desktop\NameSpace\$homeClsid"
        $nsHome2 = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Desktop\NameSpace_36354489\$homeClsid"
        if (Test-Path $nsHome1) { Remove-Item -Path $nsHome1 -Force -ErrorAction SilentlyContinue }
        if (Test-Path $nsHome2) { Remove-Item -Path $nsHome2 -Force -ErrorAction SilentlyContinue }
        Write-Host "  [OK] Раздел 'Главная' (Home) скрыт из панели навигации Проводника" -ForegroundColor Green

        # 10. Полное скрытие раздела 'Рекомендуем' в меню Пуск (для Win11 Pro, Home и Enterprise)
        $startPolicies = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer"
        if (-not (Test-Path $startPolicies)) { New-Item -Path $startPolicies -Force | Out-Null }
        Set-ItemProperty -Path $startPolicies -Name "HideRecommendedSection" -Value 1 -Type DWord -Force

        $eduKey = "HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device\Education"
        if (-not (Test-Path $eduKey)) { New-Item -Path $eduKey -Force | Out-Null }
        Set-ItemProperty -Path $eduKey -Name "IsEducationEnvironment" -Value 1 -Type DWord -Force

        $pmStartKey = "HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device\Start"
        if (-not (Test-Path $pmStartKey)) { New-Item -Path $pmStartKey -Force | Out-Null }
        Set-ItemProperty -Path $pmStartKey -Name "HideRecommendedSection" -Value 1 -Type DWord -Force
        Write-Host "  [OK] Блок 'Рекомендуем' в меню Пуск скрыт (активирован обход для Windows 11 Home/Pro)" -ForegroundColor Green

        # 11. Отключение автоматического обслуживания во время работы/игр
        $maintKey = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\Maintenance"
        if (-not (Test-Path $maintKey)) { New-Item -Path $maintKey -Force | Out-Null }
        Set-ItemProperty -Path $maintKey -Name "MaintenanceDisabled" -Value 1 -Type DWord -Force
        Write-Host "  [OK] Автоматическое обслуживание Windows отключено (устранена фоновая дефрагментация/сканирование)" -ForegroundColor Green

        if (-not $NoRestart) {
            Restart-ExplorerGraceful
        }
    }
    catch {
        Write-Host "  [ERROR] Ошибка настройки Проводника: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Set-GameDvrOptimized {
    [CmdletBinding()]
    param([switch]$DryRun = $false)

    Write-Host "`n[GameDVR / Game Bar] Оптимизация игрового режима без поломки протоколов..." -ForegroundColor Cyan

    if ($DryRun) {
        Write-Host "  [DRY-RUN] Будет отключена фоновая запись GameDVR и активирован режим честного полноэкранного FSE." -ForegroundColor DarkGray
        return
    }

    $targets = @(
        @{ Path = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR"; Name = "AppCaptureEnabled" },
        @{ Path = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR"; Name = "NoWinKeys" },
        @{ Path = "HKCU:\System\GameConfigStore"; Name = "GameDVR_Enabled" },
        @{ Path = "HKCU:\System\GameConfigStore"; Name = "GameDVR_FSEBehaviorMode" },
        @{ Path = "HKCU:\System\GameConfigStore"; Name = "GameDVR_HonorUserFSEBehaviorMode" },
        @{ Path = "HKCU:\System\GameConfigStore"; Name = "GameDVR_DXGIHonorFSEWindowsCompatible" },
        @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR"; Name = "AllowGameDVR" }
    )
    Save-RegistrySnapshot -Category "GameDVR" -RegistryTargets $targets -DryRun:$DryRun | Out-Null

    try {
        $gDvr = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR"
        if (-not (Test-Path $gDvr)) { New-Item -Path $gDvr -Force | Out-Null }
        Set-ItemProperty -Path $gDvr -Name "AppCaptureEnabled" -Value 0 -Type DWord -Force
        Set-ItemProperty -Path $gDvr -Name "NoWinKeys" -Value 1 -Type DWord -Force

        $gcs = "HKCU:\System\GameConfigStore"
        if (-not (Test-Path $gcs)) { New-Item -Path $gcs -Force | Out-Null }
        Set-ItemProperty -Path $gcs -Name "GameDVR_Enabled" -Value 0 -Type DWord -Force
        Set-ItemProperty -Path $gcs -Name "GameDVR_FSEBehaviorMode" -Value 2 -Type DWord -Force
        Set-ItemProperty -Path $gcs -Name "GameDVR_HonorUserFSEBehaviorMode" -Value 1 -Type DWord -Force
        Set-ItemProperty -Path $gcs -Name "GameDVR_DXGIHonorFSEWindowsCompatible" -Value 1 -Type DWord -Force

        $polDvr = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR"
        if (-not (Test-Path $polDvr)) { New-Item -Path $polDvr -Force | Out-Null }
        Set-ItemProperty -Path $polDvr -Name "AllowGameDVR" -Value 0 -Type DWord -Force

        Write-Host "  [OK] Фоновая запись GameDVR отключена (устранены просадки FPS и инпут-лаг)" -ForegroundColor Green
        Write-Host "  [OK] Режим полноэкранной оптимизации FSE выставлен в честный нативный режим" -ForegroundColor Green
    }
    catch {
        Write-Host "  [ERROR] Ошибка настройки GameDVR: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Enable-ClassicWindowsPhotoViewer {
    [CmdletBinding()]
    param([switch]$DryRun = $false)

    Write-Host "`n[Photo Viewer] Активация классического быстрого 'Просмотра фотографий Windows'..." -ForegroundColor Cyan

    if ($DryRun) {
        Write-Host "  [DRY-RUN] Будут добавлены ассоциации для быстрого просмотра фото через photoviewer.dll." -ForegroundColor DarkGray
        return
    }

    try {
        $associations = @(".jpg", ".jpeg", ".png", ".bmp", ".tif", ".tiff", ".gif", ".ico")
        $baseKey = "HKLM:\SOFTWARE\Microsoft\Windows Photo Viewer\Capabilities\FileAssociations"
        if (-not (Test-Path $baseKey)) { New-Item -Path $baseKey -Force | Out-Null }

        foreach ($ext in $associations) {
            Set-ItemProperty -Path $baseKey -Name $ext -Value "PhotoViewer.FileAssoc.Tiff" -Type String -Force
        }

        # Регистрация оболочки open command
        $shellCmd = "HKCR:\Applications\photoviewer.dll\shell\open\command"
        if (-not (Test-Path $shellCmd)) { New-Item -Path $shellCmd -Force | Out-Null }
        Set-Item -Path $shellCmd -Value '%SystemRoot%\System32\rundll32.exe "%ProgramFiles%\Windows Photo Viewer\PhotoViewer.dll", ImageView_Fullscreen %1' -Force | Out-Null

        Write-Host "  [OK] Классический 'Просмотр фотографий Windows' успешно добавлен в контекстное меню 'Открыть с помощью'!" -ForegroundColor Green
    }
    catch {
        Write-Host "  [ERROR] Ошибка активации Photo Viewer: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Disable-UsbPowerSaving {
    [CmdletBinding()]
    param([switch]$DryRun = $false)

    Write-Host "`n[USB Optimizer] Отключение энергосбережения USB (предотвращение лагов мыши/клавиатуры)..." -ForegroundColor Cyan

    if ($DryRun) {
        Write-Host "  [DRY-RUN] Будет отключен USB Selective Suspend в powercfg и энергосбережение USB хабов." -ForegroundColor DarkGray
        return
    }

    try {
        # 1. Отключение USB Selective Suspend через powercfg для текущей схемы (AC и DC)
        powercfg -setacvalueindex SCHEME_CURRENT 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0 2>&1 | Out-Null
        powercfg -setdcvalueindex SCHEME_CURRENT 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0 2>&1 | Out-Null
        powercfg -setactive SCHEME_CURRENT 2>&1 | Out-Null
        Write-Host "  [OK] USB Selective Suspend отключен в схеме электропитания" -ForegroundColor Green

        # 2. Отключение энергосбережения в WMI MSPower_DeviceEnable
        $powerMgmt = Get-CimInstance -ClassName MSPower_DeviceEnable -Namespace root\wmi -ErrorAction SilentlyContinue
        if ($powerMgmt) {
            foreach ($p in $powerMgmt) {
                Set-CimInstance -InputObject $p -Property @{ Enable = $false } -ErrorAction SilentlyContinue | Out-Null
            }
            Write-Host "  [OK] Энергосбережение отключено на уровне WMI контроллеров" -ForegroundColor Green
        }
    }
    catch {
        Write-Host "  [ERROR] Ошибка отключения спящих режимов USB: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Disable-WindowsAutomaticMaintenance {
    [CmdletBinding()]
    param(
        [switch]$DryRun = $false
    )

    Write-Host "`n[Maintenance] Отключение автоматического фонового обслуживания Windows..." -ForegroundColor Cyan

    $mPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\Maintenance"

    if ($DryRun) {
        Write-Host "  [DRY-RUN] Будет установлено MaintenanceDisabled = 1 в $mPath" -ForegroundColor DarkGray
        return
    }

    $targets = @(
        @{ Path = $mPath; Name = "MaintenanceDisabled" }
    )
    Save-RegistrySnapshot -Category "Maintenance" -RegistryTargets $targets -DryRun:$DryRun | Out-Null

    try {
        if (-not (Test-Path -Path $mPath)) {
            New-Item -Path $mPath -Force | Out-Null
        }
        Set-ItemProperty -Path $mPath -Name "MaintenanceDisabled" -Value 1 -Type DWord -Force
        Write-Host "  [OK] Автоматическое обслуживание Windows отключено (предотвращает внезапный троттлинг во время игр)." -ForegroundColor Green
    } catch {
        Write-Host "  [ERROR] Ошибка отключения обслуживания: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Restore-WindowsAutomaticMaintenance {
    [CmdletBinding()]
    param()

    Write-Host "[Maintenance] Откат настройки автоматического обслуживания..." -ForegroundColor Yellow
    $restored = Restore-RegistrySnapshot -Category "Maintenance"
    if (-not $restored.Success) {
        Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\Maintenance" -Name "MaintenanceDisabled" -ErrorAction SilentlyContinue
        Write-Host "[Maintenance] MaintenanceDisabled удален (дефолт Windows)." -ForegroundColor Green
    }
}

function Set-ExplorerHomeVisibility {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        $Hide = $true,
        [switch]$DryRun = $false,
        [switch]$NoRestart = $false
    )

    $shouldHide = if ($Hide -is [bool]) { $Hide } else { [bool]::Parse($Hide.ToString()) }
    $actionText = if ($shouldHide) { "Скрытие раздела 'Главная' (Home)" } else { "Отображение раздела 'Главная' (Home)" }
    Write-Host "`n[Explorer UI] $actionText в панели навигации Проводника..." -ForegroundColor Cyan

    $homeClsid = "{f874310e-b6b7-47dc-bc84-b9e6b38f5903}"
    $clsidKey = "HKLM:\SOFTWARE\Classes\CLSID\$homeClsid"
    $ns1 = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Desktop\NameSpace\$homeClsid"
    $ns2 = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Desktop\NameSpace_36354489\$homeClsid"

    if ($DryRun) {
        Write-Host "  [DRY-RUN] Будет установлено System.IsPinnedToNameSpaceTree = $(if ($shouldHide) { 0 } else { 1 })" -ForegroundColor DarkGray
        return
    }

    $targets = @(
        @{ Path = $clsidKey; Name = "System.IsPinnedToNameSpaceTree" }
    )
    Save-RegistrySnapshot -Category "ExplorerHome" -RegistryTargets $targets -DryRun:$DryRun | Out-Null

    try {
        if ($shouldHide) {
            if (-not (Test-Path $clsidKey)) { New-Item -Path $clsidKey -Force | Out-Null }
            Set-ItemProperty -Path $clsidKey -Name "System.IsPinnedToNameSpaceTree" -Value 0 -Type DWord -Force

            if (Test-Path $ns1) { Remove-Item -Path $ns1 -Force -ErrorAction SilentlyContinue }
            if (Test-Path $ns2) { Remove-Item -Path $ns2 -Force -ErrorAction SilentlyContinue }
            Write-Host "  [OK] Раздел 'Главная' скрыт из Проводника." -ForegroundColor Green
        } else {
            if (Test-Path $clsidKey) {
                Set-ItemProperty -Path $clsidKey -Name "System.IsPinnedToNameSpaceTree" -Value 1 -Type DWord -Force
            }
            if (-not (Test-Path $ns1)) {
                New-Item -Path $ns1 -Force | Out-Null
                Set-Item -Path $ns1 -Value "CLSID_MSGraphHomeFolder" -Force | Out-Null
            }
            $parentNs2 = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Desktop\NameSpace_36354489"
            if (-not (Test-Path $ns2)) {
                if (-not (Test-Path $parentNs2)) { New-Item -Path $parentNs2 -Force | Out-Null }
                New-Item -Path $ns2 -Force | Out-Null
                Set-Item -Path $ns2 -Value "CLSID_MSGraphHomeFolder" -Force | Out-Null
            }
            Write-Host "  [OK] Раздел 'Главная' восстановлен в Проводнике." -ForegroundColor Green
        }

        if (-not $NoRestart) {
            Restart-ExplorerGraceful
        }
    } catch {
        Write-Host "  [ERROR] Ошибка изменения видимости раздела 'Главная': $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Restore-SystemUISettings {
    [CmdletBinding()]
    param()

    Write-Host "[SystemUI] Откат настроек Проводника и GameDVR к дефолту..." -ForegroundColor Yellow
    Restore-RegistrySnapshot -Category "ExplorerUI"
    $resDVR = Restore-RegistrySnapshot -Category "GameDVR"
    Restore-RegistrySnapshot -Category "Maintenance"
    Restore-RegistrySnapshot -Category "ExplorerHome"

    # Восстановление дефолтов GameDVR только если снимок не сработал
    if (-not $resDVR.Success) {
        $gcs = "HKCU:\System\GameConfigStore"
        Set-ItemProperty -Path $gcs -Name "GameDVR_Enabled" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
    }
    
    # Сброс контекстного меню на стандартное Win11
    Set-ClassicContextMenu -Enable $false -NoRestart

    # Восстановление USB Selective Suspend в схеме питания (дефолт = 1 / включен)
    powercfg -setacvalueindex SCHEME_CURRENT 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 1 2>&1 | Out-Null
    powercfg -setdcvalueindex SCHEME_CURRENT 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 1 2>&1 | Out-Null
    powercfg -setactive SCHEME_CURRENT 2>&1 | Out-Null

    # Восстановление раздела Главная
    Set-ExplorerHomeVisibility -Hide $false -NoRestart -ErrorAction SilentlyContinue

    # Снятие блокировок меню Пуск и обслуживания, если снимок отсутствовал
    Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer" -Name "HideRecommendedSection" -ErrorAction SilentlyContinue
    Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device\Start" -Name "HideRecommendedSection" -ErrorAction SilentlyContinue
    Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device\Education" -Name "IsEducationEnvironment" -ErrorAction SilentlyContinue
    Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\Maintenance" -Name "MaintenanceDisabled" -ErrorAction SilentlyContinue

    Restart-ExplorerGraceful
    Write-Host "[SystemUI] Настройки интерфейса успешно восстановлены." -ForegroundColor Green
}

function Get-UsbPowerSavingStatus {
    [CmdletBinding()]
    param()

    $isOptimal = $false
    try {
        $active = (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Power\User\PowerSchemes" -ErrorAction SilentlyContinue).ActivePowerScheme
        if ($active) {
            $usbKey = "HKLM:\SYSTEM\CurrentControlSet\Control\Power\User\PowerSchemes\$active\2a737441-1930-4402-8d77-b2bebba308a3\48e6b7a6-50f5-4782-a5d4-53bb8f07e226"
            $p = Get-ItemProperty -Path $usbKey -ErrorAction SilentlyContinue
            if ($p -and $null -ne $p.PSObject.Properties['ACSettingIndex'] -and $p.ACSettingIndex -eq 0) {
                $isOptimal = $true
            }
        }
        if (-not $isOptimal) {
            $wmi = Get-CimInstance -ClassName MSPower_DeviceEnable -Namespace root\wmi -ErrorAction SilentlyContinue
            if ($wmi -and @($wmi | Where-Object { $_.Enable -eq $true }).Count -eq 0) {
                $isOptimal = $true
            }
        }
    } catch {}

    return [PSCustomObject]@{
        Disabled    = $isOptimal
        Optimal     = $isOptimal
        Description = if ($isOptimal) { "Отключено (Спящий режим USB выключен, защита от лагов)" } else { "Включено (USB засыпает)" }
    }
}

function Get-ClassicContextMenuStatus {
    [CmdletBinding()]
    param()

    $isClassic = Test-Path "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32"
    return [PSCustomObject]@{
        Enabled     = $isClassic
        Optimal     = $isClassic
        Description = if ($isClassic) { "Классическое (Win10 Style)" } else { "Стандартное (Win11)" }
    }
}

function Get-FileExplorerTweaksStatus {
    [CmdletBinding()]
    param()

    $adv = Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -ErrorAction SilentlyContinue
    $isOpt = ($adv -and $adv.PSObject.Properties['HideFileExt'] -and $adv.HideFileExt -eq 0 -and $adv.PSObject.Properties['UseCompactMode'] -and $adv.UseCompactMode -eq 1)
    return [PSCustomObject]@{
        Optimal     = [bool]$isOpt
        Description = if ($isOpt) { "Оптимизирован (Компактный вид, расширения включены)" } else { "Стандартный (Дефолт)" }
    }
}

function Get-GameDvrStatus {
    [CmdletBinding()]
    param()

    $gcs = Get-ItemProperty "HKCU:\System\GameConfigStore" -ErrorAction SilentlyContinue
    $isOff = ($gcs -and $gcs.PSObject.Properties['GameDVR_Enabled'] -and $gcs.GameDVR_Enabled -eq 0)
    return [PSCustomObject]@{
        Disabled    = [bool]$isOff
        Optimal     = [bool]$isOff
        Description = if ($isOff) { "Фоновая запись отключена (FSE нативный режим)" } else { "Фоновая запись активна (Дефолт)" }
    }
}

function Get-ClassicWindowsPhotoViewerStatus {
    [CmdletBinding()]
    param()

    $baseKey = "HKLM:\SOFTWARE\Microsoft\Windows Photo Viewer\Capabilities\FileAssociations"
    $p = Get-ItemProperty -Path $baseKey -ErrorAction SilentlyContinue
    $isOpt = ($p -and $p.PSObject.Properties['.jpg'] -and $p.'.jpg' -eq "PhotoViewer.FileAssoc.Tiff")
    return [PSCustomObject]@{
        Enabled     = [bool]$isOpt
        Optimal     = [bool]$isOpt
        Description = if ($isOpt) { "Активирован (PhotoViewer.dll)" } else { "Стандартный (UWP Photos)" }
    }
}

function Get-WindowsAutomaticMaintenanceStatus {
    [CmdletBinding()]
    param()

    $maint = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\Maintenance" -ErrorAction SilentlyContinue
    $isOff = ($maint -and $maint.PSObject.Properties['MaintenanceDisabled'] -and $maint.MaintenanceDisabled -eq 1)
    return [PSCustomObject]@{
        Disabled    = [bool]$isOff
        Optimal     = [bool]$isOff
        Description = if ($isOff) { "Отключено (Предотвращает внезапный троттлинг)" } else { "Включено (Дефолт)" }
    }
}

function Get-ExplorerHomeVisibilityStatus {
    [CmdletBinding()]
    param()

    $homeClsidKey = "HKLM:\SOFTWARE\Classes\CLSID\{f874310e-b6b7-47dc-bc84-b9e6b38f5903}"
    $nsHome1Exists = Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Desktop\NameSpace\{f874310e-b6b7-47dc-bc84-b9e6b38f5903}"
    $isHidden = $false
    if (Test-Path $homeClsidKey) {
        $prop = Get-ItemProperty -Path $homeClsidKey -ErrorAction SilentlyContinue
        if ($prop -and $null -ne $prop.PSObject.Properties['System.IsPinnedToNameSpaceTree']) {
            $isHidden = ($prop.'System.IsPinnedToNameSpaceTree' -eq 0 -and -not $nsHome1Exists)
        }
    }
    return [PSCustomObject]@{
        Hidden      = [bool]$isHidden
        Optimal     = [bool]$isHidden
        Description = if ($isHidden) { "Скрыт (Чистое дерево навигации)" } else { "Отображается (Дефолт)" }
    }
}

Export-ModuleMember -Function Set-ClassicContextMenu, Set-FileExplorerTweaks, `
                             Set-GameDvrOptimized, Enable-ClassicWindowsPhotoViewer, `
                             Disable-UsbPowerSaving, Disable-WindowsAutomaticMaintenance, `
                             Restore-WindowsAutomaticMaintenance, Set-ExplorerHomeVisibility, `
                             Restore-SystemUISettings, Restart-ExplorerGraceful, `
                             Get-UsbPowerSavingStatus, Get-ClassicContextMenuStatus, `
                             Get-FileExplorerTweaksStatus, Get-GameDvrStatus, `
                             Get-ClassicWindowsPhotoViewerStatus, Get-WindowsAutomaticMaintenanceStatus, `
                             Get-ExplorerHomeVisibilityStatus
