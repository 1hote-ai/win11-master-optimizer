# Debloat.psm1 - Modern Windows 11 Debloat (Recall, Copilot, Bing, Telemetry, Safe UWP)
# Encoding: UTF-8

Set-StrictMode -Version Latest

Import-Module (Join-Path -Path $PSScriptRoot -ChildPath "Safety.psm1") -ErrorAction SilentlyContinue

$Script:SafeUwpBlacklist = @(
    "Microsoft.BingNews",
    "Microsoft.BingWeather",
    "Microsoft.BingFinance",
    "Microsoft.BingSports",
    "Microsoft.MicrosoftSolitaireCollection",
    "Microsoft.GetHelp",
    "Microsoft.Getstarted",
    "Microsoft.WindowsFeedbackHub",
    "Clipchamp.Clipchamp",
    "Microsoft.MicrosoftOfficeHub",
    "Microsoft.Todos",
    "Microsoft.549981C3F5F10", # Cortana
    "Microsoft.PowerAutomateDesktop",
    "Microsoft.People",
    "Microsoft.YourPhone", # Связь с телефоном (опционально)
    "Microsoft.WindowsMaps",
    "Microsoft.ZuneVideo",
    "Microsoft.OutlookForWindows",
    "MicrosoftTeams"
)

$Script:StrictUwpWhitelist = @(
    "Microsoft.WindowsStore",
    "Microsoft.StorePurchaseApp",
    "Microsoft.DesktopAppInstaller",
    "Microsoft.GamingApp",
    "Microsoft.XboxApp",
    "Microsoft.XboxIdentityProvider",
    "Microsoft.XboxGamingOverlay",
    "Microsoft.XboxSpeechToTextOverlay",
    "Microsoft.XboxLive",
    "Microsoft.Xbox.TCUI",
    "Microsoft.WindowsCalculator",
    "Microsoft.WindowsNotepad",
    "Microsoft.Paint",
    "Microsoft.WindowsTerminal",
    "Microsoft.ScreenSketch", # Ножницы
    "Microsoft.SecHealthUI"   # Безопасность Windows
)

function Disable-Win11Recall {
    [CmdletBinding()]
    param([switch]$DryRun = $false)

    Write-Host "`n[Debloat] Отключение функции AI Recall (Windows 11 24H2)..." -ForegroundColor Cyan

    if ($DryRun) {
        Write-Host "  [DRY-RUN] Будет установлена политика DisableAIDataAnalysis = 1 и проверен DISM/OptionalFeature Recall." -ForegroundColor DarkGray
        return
    }

    $targets = @(
        @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI"; Name = "DisableAIDataAnalysis" },
        @{ Path = "HKCU:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI"; Name = "DisableAIDataAnalysis" }
    )
    Save-RegistrySnapshot -Category "Recall" -RegistryTargets $targets -DryRun:$DryRun | Out-Null

    try {
        # 1. Отключение компонента Recall через Windows Optional Feature
        $recallOpt = Get-WindowsOptionalFeature -Online -FeatureName "Recall" -ErrorAction SilentlyContinue
        if ($recallOpt -and $recallOpt.State -eq 'Enabled') {
            Disable-WindowsOptionalFeature -Online -FeatureName "Recall" -NoRestart -ErrorAction SilentlyContinue | Out-Null
            Write-Host "  [OK] Функция Recall успешно отключена через Optional Features" -ForegroundColor Green
        }

        # 2. Политики отключения анализа AI данных
        $keys = @("HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI", "HKCU:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI")
        foreach ($k in $keys) {
            if (-not (Test-Path $k)) { New-Item -Path $k -Force | Out-Null }
            Set-ItemProperty -Path $k -Name "DisableAIDataAnalysis" -Value 1 -Type DWord -Force
        }
        Write-Host "  [OK] Политика запрета AI слежки Recall активирована" -ForegroundColor Green
    } catch {
        Write-Host "  [ERROR] Ошибка отключения Recall: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Disable-Win11Copilot {
    [CmdletBinding()]
    param([switch]$DryRun = $false)

    Write-Host "`n[Debloat] Отключение Microsoft Copilot..." -ForegroundColor Cyan

    if ($DryRun) {
        Write-Host "  [DRY-RUN] Будет установлен TurnOffWindowsCopilot = 1 и ShowCopilotButton = 0" -ForegroundColor DarkGray
        return
    }

    $targets = @(
        @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot"; Name = "TurnOffWindowsCopilot" },
        @{ Path = "HKCU:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot"; Name = "TurnOffWindowsCopilot" },
        @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; Name = "ShowCopilotButton" }
    )
    Save-RegistrySnapshot -Category "Copilot" -RegistryTargets $targets -DryRun:$DryRun | Out-Null

    try {
        $copilotPolicies = @("HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot", "HKCU:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot")
        foreach ($p in $copilotPolicies) {
            if (-not (Test-Path $p)) { New-Item -Path $p -Force | Out-Null }
            Set-ItemProperty -Path $p -Name "TurnOffWindowsCopilot" -Value 1 -Type DWord -Force
        }

        $advKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
        Set-ItemProperty -Path $advKey -Name "ShowCopilotButton" -Value 0 -Type DWord -Force

        Write-Host "  [OK] Copilot полностью отключен и убран с панели задач" -ForegroundColor Green
    } catch {
        Write-Host "  [ERROR] Ошибка отключения Copilot: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Disable-BingSearchAndCortana {
    [CmdletBinding()]
    param([switch]$DryRun = $false)

    Write-Host "`n[Debloat] Отключение поиска Bing и рекламы в меню Пуск..." -ForegroundColor Cyan

    if ($DryRun) {
        Write-Host "  [DRY-RUN] Будет отключен веб-поиск Bing и предложения рекламы в Пуске." -ForegroundColor DarkGray
        return
    }

    $targets = @(
        @{ Path = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search"; Name = "BingSearchEnabled" },
        @{ Path = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search"; Name = "CortanaConsent" },
        @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search"; Name = "SearchboxTaskbarMode" },
        @{ Path = "HKCU:\SOFTWARE\Policies\Microsoft\Windows\Explorer"; Name = "DisableSearchBoxSuggestions" },
        @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search"; Name = "DisableWebSearch" },
        @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search"; Name = "ConnectedSearchUseWeb" },
        @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search"; Name = "AllowCortana" }
    )
    Save-RegistrySnapshot -Category "BingSearch" -RegistryTargets $targets -DryRun:$DryRun | Out-Null

    try {
        # Поиск Windows
        $searchCU = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search"
        if (-not (Test-Path $searchCU)) { New-Item -Path $searchCU -Force | Out-Null }
        Set-ItemProperty -Path $searchCU -Name "BingSearchEnabled" -Value 0 -Type DWord -Force
        Set-ItemProperty -Path $searchCU -Name "CortanaConsent" -Value 0 -Type DWord -Force

        # Отключение предложений поиска
        $expPol = "HKCU:\SOFTWARE\Policies\Microsoft\Windows\Explorer"
        if (-not (Test-Path $expPol)) { New-Item -Path $expPol -Force | Out-Null }
        Set-ItemProperty -Path $expPol -Name "DisableSearchBoxSuggestions" -Value 1 -Type DWord -Force

        # Политики HKLM Windows Search
        $wsKey = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search"
        if (-not (Test-Path $wsKey)) { New-Item -Path $wsKey -Force | Out-Null }
        Set-ItemProperty -Path $wsKey -Name "DisableWebSearch" -Value 1 -Type DWord -Force
        Set-ItemProperty -Path $wsKey -Name "ConnectedSearchUseWeb" -Value 0 -Type DWord -Force
        Set-ItemProperty -Path $wsKey -Name "AllowCortana" -Value 0 -Type DWord -Force

        # Скрытие иконки поиска / поискового спама на панели задач
        Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" -Name "SearchboxTaskbarMode" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue

        Write-Host "  [OK] Веб-поиск Bing отключен (поиск в Пуск теперь ищет только локальные файлы без лагов сети)" -ForegroundColor Green
    } catch {
        Write-Host "  [ERROR] Ошибка отключения Bing Search: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Disable-WidgetsAndNews {
    [CmdletBinding()]
    param([switch]$DryRun = $false)

    Write-Host "`n[Debloat] Отключение виджетов и новостной ленты на панели задач..." -ForegroundColor Cyan

    if ($DryRun) {
        Write-Host "  [DRY-RUN] Будут отключены NewsAndInterests и виджеты панели задач." -ForegroundColor DarkGray
        return
    }

    $targets = @(
        @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Dsh"; Name = "AllowNewsAndInterests" },
        @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; Name = "TaskbarDa" }
    )
    Save-RegistrySnapshot -Category "Widgets" -RegistryTargets $targets -DryRun:$DryRun | Out-Null

    try {
        $dsh = "HKLM:\SOFTWARE\Policies\Microsoft\Dsh"
        if (-not (Test-Path $dsh)) { New-Item -Path $dsh -Force | Out-Null }
        Set-ItemProperty -Path $dsh -Name "AllowNewsAndInterests" -Value 0 -Type DWord -Force

        $adv = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
        Set-ItemProperty -Path $adv -Name "TaskbarDa" -Value 0 -Type DWord -Force

        Write-Host "  [OK] Виджеты и новости на панели задач отключены" -ForegroundColor Green
    } catch {
        Write-Host "  [ERROR] Ошибка отключения виджетов: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Disable-TelemetryAndDiagnostics {
    [CmdletBinding()]
    param([switch]$DryRun = $false)

    Write-Host "`n[Debloat] Отключение телеметрии и сбора диагностических данных..." -ForegroundColor Cyan

    if ($DryRun) {
        Write-Host "  [DRY-RUN] Будут отключены службы DiagTrack, dmwappushservice и телеметрические задачи." -ForegroundColor DarkGray
        return
    }

    $targets = @(
        @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection"; Name = "AllowTelemetry" },
        @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection"; Name = "DoNotShowFeedbackNotifications" },
        @{ Path = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Privacy"; Name = "TailoredExperiencesWithDiagnosticDataEnabled" },
        @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo"; Name = "Enabled" }
    )
    Save-RegistrySnapshot -Category "Telemetry" -RegistryTargets $targets -DryRun:$DryRun | Out-Null

    try {
        # Реестровые политики
        $dcKey = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection"
        if (-not (Test-Path $dcKey)) { New-Item -Path $dcKey -Force | Out-Null }
        Set-ItemProperty -Path $dcKey -Name "AllowTelemetry" -Value 0 -Type DWord -Force
        Set-ItemProperty -Path $dcKey -Name "DoNotShowFeedbackNotifications" -Value 1 -Type DWord -Force

        $privKey = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Privacy"
        if (-not (Test-Path $privKey)) { New-Item -Path $privKey -Force | Out-Null }
        Set-ItemProperty -Path $privKey -Name "TailoredExperiencesWithDiagnosticDataEnabled" -Value 0 -Type DWord -Force

        # Отключение рекламного идентификатора
        $adKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo"
        if (-not (Test-Path $adKey)) { New-Item -Path $adKey -Force | Out-Null }
        Set-ItemProperty -Path $adKey -Name "Enabled" -Value 0 -Type DWord -Force

        # Остановка и отключение телеметрических служб
        $telemetryServices = @("DiagTrack", "dmwappushservice")
        foreach ($srvName in $telemetryServices) {
            $srv = Get-Service -Name $srvName -ErrorAction SilentlyContinue
            if ($srv) {
                Stop-Service -Name $srvName -Force -ErrorAction SilentlyContinue
                Set-Service -Name $srvName -StartupType Disabled -ErrorAction SilentlyContinue
                Write-Host "  [OK] Служба $srvName отключена" -ForegroundColor Green
            }
        }

        # Отключение запланированных задач сбора телеметрии
        $tasksToDisable = @(
            "\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser",
            "\Microsoft\Windows\Application Experience\ProgramDataUpdater",
            "\Microsoft\Windows\Customer Experience Improvement Program\Consolidator",
            "\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip",
            "\Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector"
        )

        foreach ($t in $tasksToDisable) {
            Disable-ScheduledTask -TaskPath (Split-Path $t -Parent) -TaskName (Split-Path $t -Leaf) -ErrorAction SilentlyContinue | Out-Null
        }

        Write-Host "  [OK] Телеметрия и фоновый сбор данных успешно заблокированы" -ForegroundColor Green
    } catch {
        Write-Host "  [ERROR] Ошибка отключения телеметрии: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Get-InstalledBloatwareApps {
    $foundBloat = [System.Collections.Generic.List[PSObject]]::new()
    $installed = Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue

    foreach ($app in $installed) {
        $appName = $app.Name

        # Проверка вайтлиста (жесткая неприкосновенность)
        $isWhitelisted = $false
        foreach ($white in $Script:StrictUwpWhitelist) {
            if ($appName -eq $white -or $appName -like "*$white*") {
                $isWhitelisted = $true
                break
            }
        }
        if ($isWhitelisted) { continue }

        # Проверка блэклиста
        foreach ($black in $Script:SafeUwpBlacklist) {
            if ($appName -like "*$black*") {
                $foundBloat.Add([PSCustomObject]@{
                    Name           = $app.Name
                    PackageFullName= $app.PackageFullName
                    Publisher      = $app.PublisherId
                })
                break
            }
        }
    }

    return $foundBloat
}

function Remove-SafeBloatwareApps {
    [CmdletBinding()]
    param([switch]$DryRun = $false)

    Write-Host "`n[UWP Debloat] Поиск и безопасное удаление предустановленного UWP-мусора..." -ForegroundColor Cyan
    Write-Host "  [INFO] Microsoft Store, Xbox, Калькулятор, Блокнот и Ножницы полностью сохранены!" -ForegroundColor DarkCyan

    $bloat = Get-InstalledBloatwareApps

    if (-not $bloat -or $bloat.Count -eq 0) {
        Write-Host "  [OK] Предустановленный мусор не обнаружен (система уже чиста)." -ForegroundColor Green
        return
    }

    Write-Host "  Обнаружено приложений для безопасной очистки: $($bloat.Count)" -ForegroundColor Yellow

    if ($DryRun) {
        foreach ($app in $bloat) {
            Write-Host "  [DRY-RUN] Будет удалено: $($app.Name)" -ForegroundColor DarkGray
        }
        return
    }

    $removedCount = 0
    foreach ($app in $bloat) {
        Write-Host "  -> Удаление: $($app.Name)..." -NoNewline
        try {
            Remove-AppxPackage -Package $app.PackageFullName -AllUsers -ErrorAction Stop
            # Также удаляем из профиля инициализации новых пользователей (Provisioned)
            Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -eq $app.Name } | Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Out-Null
            Write-Host " [УДАЛЕНО]" -ForegroundColor Green
            $removedCount++
        }
        catch {
            Write-Host " [ПРОПУЩЕНО: $($_.Exception.Message)]" -ForegroundColor Yellow
        }
    }

    Write-Host "`n[UWP Debloat] Удалено $removedCount приложений без повреждения Store или системных компонентов." -ForegroundColor Green
}

function Restore-DebloatSettings {
    [CmdletBinding()]
    param()

    Write-Host "[Debloat] Откат параметров приватности и системных служб к дефолту..." -ForegroundColor Yellow

    Restore-RegistrySnapshot -Category "Recall"
    Restore-RegistrySnapshot -Category "Copilot"
    Restore-RegistrySnapshot -Category "BingSearch"
    Restore-RegistrySnapshot -Category "Widgets"
    Restore-RegistrySnapshot -Category "Telemetry"

    # Включение служб телеметрии обратно
    $telemetryServices = @("DiagTrack", "dmwappushservice")
    foreach ($srvName in $telemetryServices) {
        Set-Service -Name $srvName -StartupType Automatic -ErrorAction SilentlyContinue
        Start-Service -Name $srvName -ErrorAction SilentlyContinue
    }

    # Повторное включение запланированных задач телеметрии
    $tasksToEnable = @(
        "\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser",
        "\Microsoft\Windows\Application Experience\ProgramDataUpdater",
        "\Microsoft\Windows\Customer Experience Improvement Program\Consolidator",
        "\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip",
        "\Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector"
    )
    foreach ($t in $tasksToEnable) {
        Enable-ScheduledTask -TaskPath (Split-Path $t -Parent) -TaskName (Split-Path $t -Leaf) -ErrorAction SilentlyContinue | Out-Null
    }

    Write-Host "[Debloat] Параметры телеметрии, служб и интерфейса возвращены к значениям по умолчанию." -ForegroundColor Green
}

Export-ModuleMember -Function Disable-Win11Recall, Disable-Win11Copilot, `
                             Disable-BingSearchAndCortana, Disable-WidgetsAndNews, `
                             Disable-TelemetryAndDiagnostics, Get-InstalledBloatwareApps, `
                             Remove-SafeBloatwareApps, Restore-DebloatSettings
