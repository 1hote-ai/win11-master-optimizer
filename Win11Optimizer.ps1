# Win11Optimizer.ps1 - Master All-in-One Windows 11 Optimizer Suite
# Encoding: UTF-8

[CmdletBinding()]
param(
    [ValidateSet("Interactive", "AutoGaming", "SafeDebloat", "LowLatency", "NetworkOnly", "GpuOnly", "DnsBenchmark", "RamClean", "Diagnostics", "HealthCheck", "Check", "Rollback")]
    [string]$Mode = "Interactive",
    [switch]$DryRun = $false,
    [switch]$NoRestorePoint = $false
)

# 1. Проверка прав Администратора и автоматический перезапуск с UAC
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "[Elevation] Запуск с повышенными привилегиями Администратора..." -ForegroundColor Yellow
    $argList = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    if ($Mode -ne "Interactive") { $argList += " -Mode $Mode" }
    if ($DryRun) { $argList += " -DryRun" }
    if ($NoRestorePoint) { $argList += " -NoRestorePoint" }

    Start-Process powershell -Verb RunAs -ArgumentList $argList
    exit
}

# 2. Настройка кодировки консоли
try {
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    [Console]::InputEncoding  = [System.Text.Encoding]::UTF8
    $Host.UI.RawUI.WindowTitle = "Windows 11 Master Optimizer Suite | Шеф Edition"
} catch {}

# 3. Импорт модулей
$moduleDir = Join-Path -Path $PSScriptRoot -ChildPath "Modules"
Import-Module (Join-Path -Path $moduleDir -ChildPath "Safety.psm1") -Force
Import-Module (Join-Path -Path $moduleDir -ChildPath "GamingLatency.psm1") -Force
Import-Module (Join-Path -Path $moduleDir -ChildPath "NetworkGaming.psm1") -Force
Import-Module (Join-Path -Path $moduleDir -ChildPath "GpuDisplay.psm1") -Force
Import-Module (Join-Path -Path $moduleDir -ChildPath "Debloat.psm1") -Force
Import-Module (Join-Path -Path $moduleDir -ChildPath "SystemUI.psm1") -Force
Import-Module (Join-Path -Path $moduleDir -ChildPath "AppInstaller.psm1") -Force
Import-Module (Join-Path -Path $moduleDir -ChildPath "Diagnostics.psm1") -Force

function Show-Header {
    Write-Host "==========================================================================" -ForegroundColor Cyan
    Write-Host "       WINDOWS 11 ALL-IN-ONE HARDCORE OPTIMIZER & LATENCY SUITE           " -ForegroundColor White
    Write-Host "             Разработано специально для Вас, Шеф!                         " -ForegroundColor DarkCyan
    Write-Host "==========================================================================" -ForegroundColor Cyan
    Write-Host "  ОС: Windows 11 (24H2 Ready) | Статус: Администратор | Безопасность: Вкл " -ForegroundColor DarkGray
    Write-Host "--------------------------------------------------------------------------" -ForegroundColor DarkGray
}

function Invoke-AutoGamingPreset {
    param([switch]$DryRun = $false)

    Write-Host "`n>>> ЗАПУСК ПОЛНОГО КОМПЛЕКСА 'ИГРОВОЙ СУПЕР-БУСТ' <<<" -ForegroundColor Green
    Write-Host "Этот пресет выполнит: Точку восстановления -> Низкую задержку -> Очистку RAM -> GPU & MPO/HAGS -> Сеть -> Респонсивность -> GameDVR -> UI" -ForegroundColor White

    if (-not $NoRestorePoint -and -not $DryRun) {
        New-OptimizerRestorePoint -Description "AutoGamingPreset" | Out-Null
    }

    # 1. Hardcore Gaming Latency & Standby RAM Purge
    Set-GamingMsiMode -DryRun:$DryRun
    Set-CpuGamingScheduling -DryRun:$DryRun
    Set-SystemResponsivenessGaming -DryRun:$DryRun
    Clear-StandbyRamAndWorkingSet -DryRun:$DryRun | Out-Null

    # 2. GPU, Display, MPO, HAGS & DirectX Optimizations
    Invoke-FullGpuDisplayOptimization -DryRun:$DryRun

    # 3. Network Gaming Stack
    Set-GamingNetworkStack -DryRun:$DryRun

    # 4. GameDVR & Explorer UI
    Set-GameDvrOptimized -DryRun:$DryRun
    Set-FileExplorerTweaks -DryRun:$DryRun -NoRestart
    Disable-UsbPowerSaving -DryRun:$DryRun

    # 5. Classic Context Menu
    Set-ClassicContextMenu -Enable $true -DryRun:$DryRun

    Write-Host "`n==========================================================================" -ForegroundColor Green
    Write-Host "  ИГРОВОЙ БУСТ УСПЕШНО ПРИМЕНЕН!" -ForegroundColor White
    Write-Host "  Рекомендуется перезагрузить компьютер для активации MSI Mode, квантов CPU и HAGS." -ForegroundColor Yellow
    Write-Host "==========================================================================" -ForegroundColor Green
}

function Invoke-FullRollback {
    Write-Host "`n>>> МАСТЕР ОТКАТА И ВОССТАНОВЛЕНИЯ <<<" -ForegroundColor Yellow
    Write-Host "Выберите действие:" -ForegroundColor White
    Write-Host "  [1] Откатить настройки MSI Mode" -ForegroundColor White
    Write-Host "  [2] Откатить оптимизацию процессора (CPU Scheduling / Power Throttling)" -ForegroundColor White
    Write-Host "  [3] Откатить настройки сети (Nagle, TCP Stack)" -ForegroundColor White
    Write-Host "  [4] Откатить настройки GPU и дисплея (MPO, HAGS, HDCP, DirectX)" -ForegroundColor White
    Write-Host "  [5] Откатить настройки приватности и Debloat (Copilot, Bing, Telemetry)" -ForegroundColor White
    Write-Host "  [6] Откатить настройки интерфейса (Проводник, GameDVR, Меню, Maintenance)" -ForegroundColor White
    Write-Host "  [7] ПОЛНЫЙ ОТКАТ ВСЕХ ОПТИМИЗАЦИЙ К ЗАВОДСКИМ ДЕФОЛТАМ WINDOWS" -ForegroundColor Yellow
    Write-Host "  [0] Отмена" -ForegroundColor Gray
    Write-Host ""
    $rChoice = Read-Host "Действие"

    switch ($rChoice) {
        "1" { Restore-GamingMsiMode }
        "2" { Restore-CpuGamingScheduling; Restore-SystemResponsiveness }
        "3" { Restore-GamingNetworkStack; Restore-GamingDns | Out-Null }
        "4" { Restore-AllGpuDisplaySettings }
        "5" { Restore-DebloatSettings }
        "6" { Restore-SystemUISettings; Restore-WindowsAutomaticMaintenance }
        "7" {
            Restore-GamingMsiMode
            Restore-CpuGamingScheduling
            Restore-SystemResponsiveness
            Restore-GamingNetworkStack
            Restore-AllGpuDisplaySettings
            Restore-DebloatSettings
            Restore-SystemUISettings
            Restore-WindowsAutomaticMaintenance
            Restore-GamingDns | Out-Null
            Write-Host "`n[OK] Все параметры сброшены до стандартных значений Windows 11." -ForegroundColor Green
        }
        default { Write-Host "Отмена операции отката." -ForegroundColor Gray }
    }
}

# Обработка неинтерактивных режимов CLI
if ($Mode -ne "Interactive") {
    switch ($Mode) {
        "AutoGaming"   { Invoke-AutoGamingPreset -DryRun:$DryRun }
        "SafeDebloat"  {
            if (-not $NoRestorePoint -and -not $DryRun) { New-OptimizerRestorePoint -Description "Debloat" | Out-Null }
            Disable-Win11Recall -DryRun:$DryRun
            Disable-Win11Copilot -DryRun:$DryRun
            Disable-BingSearchAndCortana -DryRun:$DryRun
            Disable-WidgetsAndNews -DryRun:$DryRun
            Disable-TelemetryAndDiagnostics -DryRun:$DryRun
            Remove-SafeBloatwareApps -DryRun:$DryRun
        }
        "LowLatency"   {
            if (-not $NoRestorePoint -and -not $DryRun) { New-OptimizerRestorePoint -Description "LowLatency" | Out-Null }
            Set-GamingMsiMode -DryRun:$DryRun
            Set-CpuGamingScheduling -DryRun:$DryRun
            Set-SystemResponsivenessGaming -DryRun:$DryRun
            Clear-StandbyRamAndWorkingSet -DryRun:$DryRun
        }
        "NetworkOnly"  {
            if (-not $NoRestorePoint -and -not $DryRun) { New-OptimizerRestorePoint -Description "Network" | Out-Null }
            Set-GamingNetworkStack -DryRun:$DryRun
        }
        "GpuOnly"      {
            if (-not $NoRestorePoint -and -not $DryRun) { New-OptimizerRestorePoint -Description "GpuDisplay" | Out-Null }
            Invoke-FullGpuDisplayOptimization -DryRun:$DryRun
        }
        "DnsBenchmark" {
            Test-GamingDnsBenchmark
        }
        "RamClean"     {
            Clear-StandbyRamAndWorkingSet -DryRun:$DryRun
        }
        "Diagnostics"  { Show-DiagnosticsDashboard }
        "HealthCheck"  { Show-OptimizationHealthCheck | Out-Null }
        "Check"        { Show-OptimizationHealthCheck | Out-Null }
        "Rollback"     { Invoke-FullRollback }
    }
    exit
}

function Write-OptimizerMenuItem {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Number,
        [Parameter(Mandatory = $true)]
        [string]$Title,
        [Parameter(Mandatory = $true)]
        [bool]$IsActive,
        [string]$ActiveTag = "[АКТИВНО]",
        [string]$InactiveTag = "[НЕ АКТИВНО]",
        [int]$PadWidth = 58
    )

    $tag = if ($IsActive) { $ActiveTag } else { $InactiveTag }
    $check = if ($IsActive) { "[✓]" } else { "[ ]" }
    $color = if ($IsActive) { "Green" } else { "DarkGray" }
    $fullTitle = "$check [$Number] $Title"
    if ($fullTitle.Length -lt $PadWidth) {
        $fullTitle = $fullTitle.PadRight($PadWidth)
    }

    Write-Host "  $fullTitle  $tag" -ForegroundColor $color
}

function Show-HardcoreGamingMenu {
    while ($true) {
        Clear-Host
        Write-Host "==========================================================================" -ForegroundColor Cyan
        Write-Host "            ЖЁСТКАЯ ОПТИМИЗАЦИЯ И НИЗКАЯ ЗАДЕРЖКА (LOW LATENCY)           " -ForegroundColor White
        Write-Host "==========================================================================" -ForegroundColor Cyan

        $msiStat = Get-MsiModeStatus
        $cpuStat = Get-CpuGamingSchedulingStatus
        $pwrStat = Get-UltimatePerformancePlanStatus
        $sysStat = Get-SystemResponsivenessStatus
        $vbsStat = Get-VbsStatus
        $isVbsOptimal = (-not $vbsStat.VbsActive)

        $osMem = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
        $freeMemMb = if ($osMem) { [math]::Round($osMem.FreePhysicalMemory / 1024, 0) } else { 0 }

        Write-OptimizerMenuItem -Number "1" -Title "Настроить MSI Mode для GPU, Сети и Звука (High Priority)" `
            -IsActive $msiStat.Optimal -ActiveTag "[АКТИВНО ($($msiStat.Description))]" -InactiveTag "[НЕ АКТИВНО (Дефолт IRQ)]"

        Write-OptimizerMenuItem -Number "2" -Title "Отключить Power Throttling и настроить кванты CPU" `
            -IsActive $cpuStat.Optimal -ActiveTag "[АКТИВНО ($($cpuStat.Description))]" -InactiveTag "[НЕ АКТИВНО (Win32Pri=$($cpuStat.Win32PrioritySeparation))]"

        Write-OptimizerMenuItem -Number "3" -Title "Активировать схему 'Максимальная производительность'" `
            -IsActive $pwrStat.Optimal -ActiveTag "[АКТИВНО (Ultimate Performance)]" -InactiveTag "[НЕ АКТИВНО (Дефолт схема)]"

        Write-OptimizerMenuItem -Number "4" -Title "Настроить SystemResponsiveness (0% резерва, 100% играм)" `
            -IsActive $sysStat.Optimal -ActiveTag "[АКТИВНО (0% резерва)]" -InactiveTag "[НЕ АКТИВНО ($($sysStat.Value)% резерв)]"

        Write-Host "  [⚡] [5] Очистить Standby RAM кэш и Working Sets (Свободно: $freeMemMb МБ)" -ForegroundColor Cyan

        Write-OptimizerMenuItem -Number "6" -Title "Переключить изоляцию ядра (VBS / HVCI) [С предупреждением]" `
            -IsActive $isVbsOptimal -ActiveTag "[ВЫКЛЮЧЕНА (Оптимально +FPS)]" -InactiveTag "[ВКЛЮЧЕНА (Защита ядра)]"

        Write-Host ""
        Write-Host "  [🚀] [7] Применить ВСЕ твики низкой задержки разом" -ForegroundColor Green
        Write-Host "  [0]  Назад в главное меню" -ForegroundColor Gray
        Write-Host ""

        $llChoice = Read-Host "Шеф, выберите действие"
        if ($llChoice -eq "0" -or [string]::IsNullOrWhiteSpace($llChoice)) { break }

        switch ($llChoice) {
            "1" {
                New-OptimizerRestorePoint -Description "MSIMode" | Out-Null
                Set-GamingMsiMode
            }
            "2" {
                New-OptimizerRestorePoint -Description "CpuScheduling" | Out-Null
                Set-CpuGamingScheduling
            }
            "3" {
                Enable-UltimatePerformancePlan
            }
            "4" {
                New-OptimizerRestorePoint -Description "SystemResponsiveness" | Out-Null
                Set-SystemResponsivenessGaming
            }
            "5" {
                Clear-StandbyRamAndWorkingSet | Out-Null
            }
            "6" {
                $curVbs = Get-VbsStatus
                $enableVbs = -not $curVbs.VbsActive
                Set-VbsState -Enable $enableVbs
            }
            "7" {
                New-OptimizerRestorePoint -Description "HardcoreLowLatency" | Out-Null
                Set-GamingMsiMode
                Set-CpuGamingScheduling
                Enable-UltimatePerformancePlan
                Set-SystemResponsivenessGaming
                Clear-StandbyRamAndWorkingSet | Out-Null
            }
            default {
                Write-Host "Неверный выбор." -ForegroundColor Yellow
            }
        }
        Write-Host "`nНажмите Enter для возврата в меню..."; Read-Host | Out-Null
    }
}

function Show-NetworkMenu {
    while ($true) {
        Clear-Host
        Write-Host "==========================================================================" -ForegroundColor Cyan
        Write-Host "                       ОПТИМИЗАЦИЯ СЕТЕВОГО СТЕКА                         " -ForegroundColor White
        Write-Host "==========================================================================" -ForegroundColor Cyan

        $nagleStat = Get-NagleStatus
        $netStackStat = Get-NetworkGamingStackStatus
        $dnsStat = Get-GamingDnsStatus

        Write-OptimizerMenuItem -Number "1" -Title "Отключить алгоритм Нейгла (TcpAckFrequency=1, TCPNoDelay=1)" `
            -IsActive $nagleStat.Optimal -ActiveTag "[ОТКЛЮЧЕН (Оптимально)]" -InactiveTag "[АКТИВЕН (Дефолт задержки)]"

        Write-OptimizerMenuItem -Number "2" -Title "Настроить RSS, timestamps и NetworkThrottlingIndex" `
            -IsActive $netStackStat.Optimal -ActiveTag "[АКТИВНО (0xFFFFFFFF троттлинг снят)]" -InactiveTag "[НЕ АКТИВНО (Дефолт троттлинг)]"

        Write-OptimizerMenuItem -Number "3" -Title "Gaming DNS Benchmark & DoH Switcher (Cloudflare/Quad9/AdGuard)" `
            -IsActive $dnsStat.Optimal -ActiveTag "[ОПТИМИЗИРОВАН ($($dnsStat.ProviderLabel))]" -InactiveTag "[СТАНДАРТНЫЙ ($($dnsStat.ProviderLabel))]"

        Write-Host ""
        Write-Host "  [🔄] [4] Сбросить / Откатить DNS (DHCP роутера или резервная копия)" -ForegroundColor Yellow
        Write-Host "  [🚀] [5] Применить ПОЛНЫЙ сетевой комплекс" -ForegroundColor Green
        Write-Host "  [0]  Назад в главное меню" -ForegroundColor Gray
        Write-Host ""

        $netChoice = Read-Host "Шеф, выберите действие"
        if ($netChoice -eq "0" -or [string]::IsNullOrWhiteSpace($netChoice)) { break }

        switch ($netChoice) {
            "1" {
                New-OptimizerRestorePoint -Description "NetworkStack" | Out-Null
                Set-GamingNetworkStack
            }
            "2" {
                New-OptimizerRestorePoint -Description "NetworkStack" | Out-Null
                Set-GamingNetworkStack
            }
            "3" {
                Show-DnsBenchmarkAndSwitcherMenu
            }
            "4" {
                Restore-GamingDns | Out-Null
            }
            "5" {
                New-OptimizerRestorePoint -Description "NetworkStack" | Out-Null
                Set-GamingNetworkStack
            }
            default {
                Write-Host "Неверный выбор." -ForegroundColor Yellow
            }
        }
        Write-Host "`nНажмите Enter для возврата в меню..."; Read-Host | Out-Null
    }
}

function Show-GpuMenu {
    while ($true) {
        Clear-Host
        Write-Host "==========================================================================" -ForegroundColor Cyan
        Write-Host "                 GPU, ДИСПЛЕЙ И КЭШ ШЕЙДЕРОВ (LOW INPUT LAG)              " -ForegroundColor White
        Write-Host "==========================================================================" -ForegroundColor Cyan

        $curMpo = Get-MpoStatus
        $curHags = Get-HagsStatus
        $curDx = Get-DirectXWindowedStatus
        $curWu = Get-WindowsUpdateDriverProtectionStatus
        $curHdcp = Get-NvidiaHdcpStatus

        Write-OptimizerMenuItem -Number "1" -Title "Переключить MPO (OverlayTestMode=5) для устранения микро-фризов" `
            -IsActive $curMpo.Disabled -ActiveTag "[ОТКЛЮЧЕН (Оптимально)]" -InactiveTag "[ВКЛЮЧЕН (Дефолт)]"

        Write-OptimizerMenuItem -Number "2" -Title "Переключить HAGS (Hardware-Accelerated GPU Scheduling)" `
            -IsActive $curHags.Enabled -ActiveTag "[ВКЛЮЧЕН (Оптимально DLSS 3)]" -InactiveTag "[ВЫКЛЮЧЕН (Дефолт)]"

        Write-OptimizerMenuItem -Number "3" -Title "Переключить оконные оптимизации DirectX (AutoPlayMode=1)" `
            -IsActive $curDx.Optimal -ActiveTag "[ВКЛЮЧЕНО (AutoPlayMode=1)]" -InactiveTag "[ВЫКЛЮЧЕНО (Дефолт)]"

        Write-OptimizerMenuItem -Number "4" -Title "Переключить защиту видеодрайвера от Windows Update" `
            -IsActive $curWu.Protected -ActiveTag "[ЗАЩИЩЕН (ExcludeWU=1)]" -InactiveTag "[НЕ ЗАЩИЩЕН (Дефолт)]"

        Write-OptimizerMenuItem -Number "5" -Title "Переключить NVIDIA HDCP DRM (RMHdcpKeyglobZero)" `
            -IsActive $curHdcp.Optimal -ActiveTag "[DRM ОТКЛЮЧЕН (Оптимально)]" -InactiveTag $(if (-not $curHdcp.IsNvidia) { "[Н/Д (GPU не NVIDIA)]" } else { "[DRM АКТИВЕН (Дефолт)]" })

        Write-Host ""
        Write-Host "  [⚡] [6] Очистить кэш шейдеров DirectX/OpenGL и TEMP (Освобождение диска)" -ForegroundColor Cyan
        Write-Host "  [🚀] [7] Применить ВСЕ оптимизации GPU и дисплея разом" -ForegroundColor Green
        Write-Host "  [🔄] [8] Откатить ВСЕ параметры GPU и дисплея к дефолтам" -ForegroundColor Yellow
        Write-Host "  [0]  Назад в главное меню" -ForegroundColor Gray
        Write-Host ""

        $gpuChoice = Read-Host "Шеф, выберите действие"
        if ($gpuChoice -eq "0" -or [string]::IsNullOrWhiteSpace($gpuChoice)) { break }

        switch ($gpuChoice) {
            "1" {
                Set-MpoState -Disable (-not $curMpo.Disabled)
            }
            "2" {
                Set-HagsState -Enable (-not $curHags.Enabled)
            }
            "3" {
                Set-DirectXWindowedOptimization -Enable (-not $curDx.Optimal)
            }
            "4" {
                Set-WindowsUpdateDriverProtection -Enable (-not $curWu.Protected)
            }
            "5" {
                Set-NvidiaHdcpDisable -Disable (-not $curHdcp.Disabled)
            }
            "6" {
                Clear-ShaderCacheAndTemp | Out-Null
            }
            "7" {
                New-OptimizerRestorePoint -Description "FullGpuDisplay" | Out-Null
                Invoke-FullGpuDisplayOptimization
            }
            "8" {
                Restore-AllGpuDisplaySettings
            }
            default {
                Write-Host "Неверный выбор." -ForegroundColor Yellow
            }
        }
        Write-Host "`nНажмите Enter для возврата в меню..."; Read-Host | Out-Null
    }
}

function Show-DebloatMenu {
    while ($true) {
        Clear-Host
        Write-Host "==========================================================================" -ForegroundColor Cyan
        Write-Host "                         SMART MODERN DEBLOAT                             " -ForegroundColor White
        Write-Host "==========================================================================" -ForegroundColor Cyan

        $recallStat = Get-RecallStatus
        $copilotStat = Get-CopilotStatus
        $bingStat = Get-BingSearchStatus
        $widgetsStat = Get-WidgetsStatus
        $telemetryStat = Get-TelemetryStatus
        $bloatStat = Get-BloatwareStatus

        Write-OptimizerMenuItem -Number "1" -Title "Отключить AI Recall (Windows 11 24H2)" `
            -IsActive $recallStat.Disabled -ActiveTag "[ОТКЛЮЧЕН (Оптимально)]" -InactiveTag "[АКТИВЕН (Дефолт)]"

        Write-OptimizerMenuItem -Number "2" -Title "Отключить Microsoft Copilot" `
            -IsActive $copilotStat.Disabled -ActiveTag "[ОТКЛЮЧЕН (Оптимально)]" -InactiveTag "[АКТИВЕН (Дефолт)]"

        Write-OptimizerMenuItem -Number "3" -Title "Отключить веб-поиск Bing и спам в меню Пуск" `
            -IsActive $bingStat.Disabled -ActiveTag "[ОТКЛЮЧЕН (Оптимально)]" -InactiveTag "[АКТИВЕН (Дефолт)]"

        Write-OptimizerMenuItem -Number "4" -Title "Отключить виджеты и новости на панели задач" `
            -IsActive $widgetsStat.Disabled -ActiveTag "[ОТКЛЮЧЕНЫ (Оптимально)]" -InactiveTag "[АКТИВНЫ (Дефолт)]"

        Write-OptimizerMenuItem -Number "5" -Title "Отключить фоновую телеметрию и сбор данных (DiagTrack)" `
            -IsActive $telemetryStat.Disabled -ActiveTag "[ОТКЛЮЧЕНА (Оптимально)]" -InactiveTag "[АКТИВНА (Дефолт)]"

        Write-OptimizerMenuItem -Number "6" -Title "Безопасно удалить предустановленный UWP-мусор (Store/Xbox целы)" `
            -IsActive $bloatStat.Clean -ActiveTag "[ОЧИЩЕНО (Мусор не найден)]" -InactiveTag "[НЕ ОЧИЩЕНО (Найдено: $($bloatStat.Count))]"

        Write-Host ""
        Write-Host "  [🚀] [7] Выполнить ПОЛНЫЙ безопасный Debloat" -ForegroundColor Green
        Write-Host "  [0]  Назад в главное меню" -ForegroundColor Gray
        Write-Host ""

        $debChoice = Read-Host "Шеф, выберите действие"
        if ($debChoice -eq "0" -or [string]::IsNullOrWhiteSpace($debChoice)) { break }

        switch ($debChoice) {
            "1" { Disable-Win11Recall }
            "2" { Disable-Win11Copilot }
            "3" { Disable-BingSearchAndCortana }
            "4" { Disable-WidgetsAndNews }
            "5" { Disable-TelemetryAndDiagnostics }
            "6" { Remove-SafeBloatwareApps }
            "7" {
                New-OptimizerRestorePoint -Description "FullDebloat" | Out-Null
                Disable-Win11Recall
                Disable-Win11Copilot
                Disable-BingSearchAndCortana
                Disable-WidgetsAndNews
                Disable-TelemetryAndDiagnostics
                Remove-SafeBloatwareApps
            }
            default {
                Write-Host "Неверный выбор." -ForegroundColor Yellow
            }
        }
        Write-Host "`nНажмите Enter для возврата в меню..."; Read-Host | Out-Null
    }
}

function Show-InterfaceMenu {
    while ($true) {
        Clear-Host
        Write-Host "==========================================================================" -ForegroundColor Cyan
        Write-Host "                     ИНТЕРФЕЙС И СИСТЕМНЫЕ ТВКИ                           " -ForegroundColor White
        Write-Host "==========================================================================" -ForegroundColor Cyan

        $classicStat = Get-ClassicContextMenuStatus
        $expStat = Get-FileExplorerTweaksStatus
        $gDvrStat = Get-GameDvrStatus
        $photoStat = Get-ClassicWindowsPhotoViewerStatus
        $usbStat = Get-UsbPowerSavingStatus
        $maintStat = Get-WindowsAutomaticMaintenanceStatus
        $homeStat = Get-ExplorerHomeVisibilityStatus

        Write-OptimizerMenuItem -Number "1" -Title "Переключить контекстное меню (Классическое Win10 / Новое Win11)" `
            -IsActive $classicStat.Enabled -ActiveTag "[АКТИВНО (Win10 Style)]" -InactiveTag "[НЕ АКТИВНО (Win11 Дефолт)]"

        Write-OptimizerMenuItem -Number "2" -Title "Настроить Проводник (расширения, скрытые файлы, компактный вид)" `
            -IsActive $expStat.Optimal -ActiveTag "[АКТИВНО (Компактный + расширения)]" -InactiveTag "[НЕ АКТИВНО (Дефолт)]"

        Write-OptimizerMenuItem -Number "3" -Title "Оптимизировать GameDVR (отключить фоновую запись, FSE mode)" `
            -IsActive $gDvrStat.Disabled -ActiveTag "[АКТИВНО (Запись отключена / FSE)]" -InactiveTag "[НЕ АКТИВНО (Дефолт)]"

        Write-OptimizerMenuItem -Number "4" -Title "Активировать классический Просмотр Фотографий Windows" `
            -IsActive $photoStat.Enabled -ActiveTag "[АКТИВНО (PhotoViewer.dll)]" -InactiveTag "[НЕ АКТИВНО (Дефолт UWP)]"

        Write-OptimizerMenuItem -Number "5" -Title "Отключить энергосбережение USB (защита от лагов мыши)" `
            -IsActive $usbStat.Disabled -ActiveTag "[АКТИВНО (Спящий режим USB выключен)]" -InactiveTag "[НЕ АКТИВНО (USB засыпает)]"

        Write-OptimizerMenuItem -Number "6" -Title "Отключить автоматическое обслуживание Windows (Maintenance)" `
            -IsActive $maintStat.Disabled -ActiveTag "[АКТИВНО (Обслуживание отключено)]" -InactiveTag "[НЕ АКТИВНО (Дефолт)]"

        Write-OptimizerMenuItem -Number "7" -Title "Скрыть/показать раздел 'Главная' (Home) в Проводнике" `
            -IsActive $homeStat.Hidden -ActiveTag "[АКТИВНО (Раздел скрыт)]" -InactiveTag "[НЕ АКТИВНО (Отображается)]"

        Write-Host ""
        Write-Host "  [🚀] [8] Применить ВСЕ твики интерфейса" -ForegroundColor Green
        Write-Host "  [0]  Назад в главное меню" -ForegroundColor Gray
        Write-Host ""

        $uiChoice = Read-Host "Шеф, выберите действие"
        if ($uiChoice -eq "0" -or [string]::IsNullOrWhiteSpace($uiChoice)) { break }

        switch ($uiChoice) {
            "1" {
                Set-ClassicContextMenu -Enable (-not $classicStat.Enabled)
            }
            "2" {
                Set-FileExplorerTweaks
            }
            "3" {
                Set-GameDvrOptimized
            }
            "4" {
                Enable-ClassicWindowsPhotoViewer
            }
            "5" {
                Disable-UsbPowerSaving
            }
            "6" {
                Disable-WindowsAutomaticMaintenance
            }
            "7" {
                Set-ExplorerHomeVisibility -Hide (-not $homeStat.Hidden)
            }
            "8" {
                New-OptimizerRestorePoint -Description "SystemUI" | Out-Null
                Set-FileExplorerTweaks -NoRestart
                Set-GameDvrOptimized
                Enable-ClassicWindowsPhotoViewer
                Disable-UsbPowerSaving
                Disable-WindowsAutomaticMaintenance
                Set-ClassicContextMenu -Enable $true
            }
            default {
                Write-Host "Неверный выбор." -ForegroundColor Yellow
            }
        }
        Write-Host "`nНажмите Enter для возврата в меню..."; Read-Host | Out-Null
    }
}

# Главный интерактивный цикл TUI
while ($true) {
    Clear-Host
    Show-Header

    Write-Host " ГЛАВНОЕ МЕНЮ ОПТИМИЗАЦИИ:" -ForegroundColor Yellow
    Write-Host "  [1]   🔎  ПРОВЕРИТЬ ОПТИМИЗАЦИЮ ПК (Аудит 24+ настроек [✓] / [!])" -ForegroundColor Cyan
    Write-Host "  [2]   🚀  ИГРОВОЙ СУПЕР-БУСТ (MSI, CPU, GPU, MPO, HAGS, Сеть, RAM, UI)" -ForegroundColor Green
    Write-Host "  [3]   ⚡  ЖЁСТКАЯ ОПТИМИЗАЦИЯ (MSI Mode, CPU Scheduling, RAM Cleaner, VBS)" -ForegroundColor White
    Write-Host "  [4]   🌐  ИГРОВОЙ СЕТЕВОЙ СТЕК (Nagle Off, RSS, DNS Benchmark & DoH Switcher)" -ForegroundColor White
    Write-Host "  [5]   🎮  GPU, ДИСПЛЕЙ И КЭШ ШЕЙДЕРОВ (MPO, HAGS, HDCP, Очистка 7+ ГБ кэша)" -ForegroundColor White
    Write-Host "  [6]   🛡  SMART DEBLOAT (Recall 24H2, Copilot, Bing, Telemetry, Safe UWP)" -ForegroundColor White
    Write-Host "  [7]   🎨  ИНТЕРФЕЙС И СИСТЕМА (Classic Меню, Проводник, Главная, Пуск, Maintenance)" -ForegroundColor White
    Write-Host "  [8]   📦  МЕНЕДЖЕР ПРИЛОЖЕНИЙ WINGET (Замена 170+ устаревших веб-ссылок)" -ForegroundColor White
    Write-Host "  [9]   📊  ДИАГНОСТИКА ЗАДЕРЖЕК (Замер пинга, Live DPC/ISR, таймер Windows)" -ForegroundColor White
    Write-Host "  [10]  🔄  ОТКАТ И ВОССТАНОВЛЕНИЕ (Восстановление исходных параметров Windows)" -ForegroundColor Yellow
    Write-Host "  [0]   🚪  Выход" -ForegroundColor DarkGray
    Write-Host ""
    $mainChoice = Read-Host "Шеф, выберите пункт меню"

    switch ($mainChoice) {
        "1" {
            $checkRes = Show-OptimizationHealthCheck
            if ($checkRes -eq "ApplySuperBoost") {
                Invoke-AutoGamingPreset
            }
            Write-Host "`nНажмите Enter для возврата в меню..."; Read-Host | Out-Null
        }
        "2" {
            Invoke-AutoGamingPreset
            Write-Host "`nНажмите Enter для возврата в меню..."; Read-Host | Out-Null
        }
        "3" {
            Show-HardcoreGamingMenu
        }
        "4" {
            Show-NetworkMenu
        }
        "5" {
            Show-GpuMenu
        }
        "6" {
            Show-DebloatMenu
        }
        "7" {
            Show-InterfaceMenu
        }
        "8" {
            Show-AppInstallerMenu
        }
        "9" {
            Show-DiagnosticsDashboard
        }
        "10" {
            Invoke-FullRollback
            Write-Host "`nНажмите Enter для возврата в меню..."; Read-Host | Out-Null
        }
        "0" {
            Write-Host "`nВыход из оптимизатора. Удачной игры и плавной работы, Шеф!" -ForegroundColor Cyan
            break
        }
        default {
            Write-Host "Неверный выбор. Пожалуйста, введите номер из меню." -ForegroundColor Yellow
            Start-Sleep -Seconds 1
        }
    }
}
