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
            Clear-Host
            Write-Host "==========================================================================" -ForegroundColor Cyan
            Write-Host "            ЖЁСТКАЯ ОПТИМИЗАЦИЯ И НИЗКАЯ ЗАДЕРЖКА (LOW LATENCY)           " -ForegroundColor White
            Write-Host "==========================================================================" -ForegroundColor Cyan
            Write-Host "  [1] Настроить MSI Mode для GPU, Сети и Звука (High Priority)" -ForegroundColor White
            Write-Host "  [2] Отключить Power Throttling и настроить кванты CPU (Win32Priority)" -ForegroundColor White
            Write-Host "  [3] Активировать схему питания 'Максимальная производительность' (Ultimate)" -ForegroundColor White
            Write-Host "  [4] Настроить SystemResponsiveness (0% резерва, 100% играм)" -ForegroundColor White
            Write-Host "  [5] Очистить Standby RAM кэш и Working Sets (мгновенное освобождение ОЗУ)" -ForegroundColor Cyan
            Write-Host "  [6] Переключить изоляцию ядра (VBS / HVCI) [С предупреждением]" -ForegroundColor White
            Write-Host "  [7] Применить ВСЕ твики низкой задержки разом" -ForegroundColor Green
            Write-Host "  [0] Назад" -ForegroundColor Gray
            Write-Host ""
            $llChoice = Read-Host "Действие"
            if ($llChoice -eq "1") {
                New-OptimizerRestorePoint -Description "MSIMode" | Out-Null
                Set-GamingMsiMode
            } elseif ($llChoice -eq "2") {
                New-OptimizerRestorePoint -Description "CpuScheduling" | Out-Null
                Set-CpuGamingScheduling
            } elseif ($llChoice -eq "3") {
                Enable-UltimatePerformancePlan
            } elseif ($llChoice -eq "4") {
                New-OptimizerRestorePoint -Description "SystemResponsiveness" | Out-Null
                Set-SystemResponsivenessGaming
            } elseif ($llChoice -eq "5") {
                Clear-StandbyRamAndWorkingSet | Out-Null
            } elseif ($llChoice -eq "6") {
                $curVbs = Get-VbsStatus
                $enableVbs = -not $curVbs.VbsActive
                Set-VbsState -Enable $enableVbs
            } elseif ($llChoice -eq "7") {
                New-OptimizerRestorePoint -Description "HardcoreLowLatency" | Out-Null
                Set-GamingMsiMode
                Set-CpuGamingScheduling
                Enable-UltimatePerformancePlan
                Set-SystemResponsivenessGaming
                Clear-StandbyRamAndWorkingSet | Out-Null
            }
            Write-Host "`nНажмите Enter для возврата в меню..."; Read-Host | Out-Null
        }
        "4" {
            Clear-Host
            Write-Host "==========================================================================" -ForegroundColor Cyan
            Write-Host "                       ОПТИМИЗАЦИЯ СЕТЕВОГО СТЕКА                         " -ForegroundColor White
            Write-Host "==========================================================================" -ForegroundColor Cyan
            Write-Host "  [1] Отключить алгоритм Нейгла (TcpAckFrequency=1, TCPNoDelay=1)" -ForegroundColor White
            Write-Host "  [2] Настроить RSS, отключить timestamps и ECN (минимизация джиттера)" -ForegroundColor White
            Write-Host "  [3] Gaming DNS Benchmark & DoH Switcher (Cloudflare, Quad9, AdGuard, Google)" -ForegroundColor Cyan
            Write-Host "  [4] Сбросить / Откатить DNS (DHCP роутера или резервная копия)" -ForegroundColor Yellow
            Write-Host "  [5] Применить ПОЛНЫЙ сетевой комплекс" -ForegroundColor Green
            Write-Host "  [0] Назад" -ForegroundColor Gray
            Write-Host ""
            $netChoice = Read-Host "Действие"
            if ($netChoice -eq "1" -or $netChoice -eq "2" -or $netChoice -eq "5") {
                New-OptimizerRestorePoint -Description "NetworkStack" | Out-Null
                Set-GamingNetworkStack
            } elseif ($netChoice -eq "3") {
                Show-DnsBenchmarkAndSwitcherMenu
            } elseif ($netChoice -eq "4") {
                Restore-GamingDns | Out-Null
            }
            Write-Host "`nНажмите Enter для возврата в меню..."; Read-Host | Out-Null
        }
        "5" {
            Clear-Host
            $curMpo = Get-MpoStatus
            $curHags = Get-HagsStatus
            $dxProp = (Get-ItemProperty "HKCU:\Software\Microsoft\DirectX\UserGpuPreferences" -ErrorAction SilentlyContinue)
            $curDx = ($dxProp -and $dxProp.PSObject.Properties['DirectXUserGlobalSettings'] -and ($dxProp.DirectXUserGlobalSettings -like "*AutoPlayMode=1*"))
            $wuProp = (Get-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" -ErrorAction SilentlyContinue)
            $curWu = ($wuProp -and $wuProp.PSObject.Properties['ExcludeWUDriversInQualityUpdate'] -and $wuProp.ExcludeWUDriversInQualityUpdate -eq 1)
            $nvKeys = @(Get-NvidiaDisplayAdapterKeys)
            $curHdcp = $false
            if ($nvKeys.Count -gt 0) {
                $p = Get-ItemProperty -Path $nvKeys[0].RegistryPath -ErrorAction SilentlyContinue
                if ($p -and $p.PSObject.Properties['RMHdcpKeyglobZero'] -and $p.RMHdcpKeyglobZero -eq 1) { $curHdcp = $true }
            }

            $mpoTag  = if ($curMpo.Disabled) { "[ОТКЛЮЧЕН (Оптимально)]" } else { "[ВКЛЮЧЕН (Дефолт)]" }
            $hagsTag = if ($curHags.Enabled) { "[ВКЛЮЧЕН (Оптимально)]" } else { "[ВЫКЛЮЧЕН]" }
            $dxTag   = if ($curDx) { "[ВКЛЮЧЕНО (AutoPlayMode=1)]" } else { "[ВЫКЛЮЧЕНО]" }
            $wuTag   = if ($curWu) { "[ЗАЩИЩЕН (ExcludeWU=1)]" } else { "[НЕ ЗАЩИЩЕН]" }
            $hdcpTag = if ($nvKeys.Count -eq 0) { "[Н/Д (GPU не NVIDIA)]" } elseif ($curHdcp) { "[DRM ОТКЛЮЧЕН (Оптимально)]" } else { "[DRM АКТИВЕН]" }

            Write-Host "==========================================================================" -ForegroundColor Cyan
            Write-Host "                 GPU, ДИСПЛЕЙ И КЭШ ШЕЙДЕРОВ (LOW INPUT LAG)              " -ForegroundColor White
            Write-Host "==========================================================================" -ForegroundColor Cyan
            Write-Host "  [1] Переключить MPO (OverlayTestMode=5)                $mpoTag" -ForegroundColor White
            Write-Host "  [2] Переключить HAGS (Hardware GPU Scheduling)         $hagsTag" -ForegroundColor White
            Write-Host "  [3] Переключить оконные оптимизации DirectX            $dxTag" -ForegroundColor White
            Write-Host "  [4] Переключить защиту видеодрайвера Windows Update    $wuTag" -ForegroundColor White
            Write-Host "  [5] Переключить NVIDIA HDCP DRM (RMHdcpKeyglobZero)    $hdcpTag" -ForegroundColor White
            Write-Host "  [6] Очистить кэш шейдеров DirectX/OpenGL и TEMP        (Освобождение диска)" -ForegroundColor Cyan
            Write-Host "  [7] Применить ВСЕ оптимизации GPU и дисплея разом" -ForegroundColor Green
            Write-Host "  [8] Откатить ВСЕ параметры GPU и дисплея к дефолтам" -ForegroundColor Yellow
            Write-Host "  [0] Назад" -ForegroundColor Gray
            Write-Host ""
            $gpuChoice = Read-Host "Действие"
            if ($gpuChoice -eq "1") {
                Set-MpoState -Disable (-not $curMpo.Disabled)
            } elseif ($gpuChoice -eq "2") {
                Set-HagsState -Enable (-not $curHags.Enabled)
            } elseif ($gpuChoice -eq "3") {
                Set-DirectXWindowedOptimization -Enable (-not $curDx)
            } elseif ($gpuChoice -eq "4") {
                Set-WindowsUpdateDriverProtection -Enable (-not $curWu)
            } elseif ($gpuChoice -eq "5") {
                Set-NvidiaHdcpDisable -Disable (-not $curHdcp)
            } elseif ($gpuChoice -eq "6") {
                Clear-ShaderCacheAndTemp | Out-Null
            } elseif ($gpuChoice -eq "7") {
                New-OptimizerRestorePoint -Description "FullGpuDisplay" | Out-Null
                Invoke-FullGpuDisplayOptimization
            } elseif ($gpuChoice -eq "8") {
                Restore-AllGpuDisplaySettings
            }
            Write-Host "`nНажмите Enter для возврата в меню..."; Read-Host | Out-Null
        }
        "6" {
            Clear-Host
            Write-Host "==========================================================================" -ForegroundColor Cyan
            Write-Host "                         SMART MODERN DEBLOAT                             " -ForegroundColor White
            Write-Host "==========================================================================" -ForegroundColor Cyan
            Write-Host "  [1] Отключить AI Recall (Windows 11 24H2)" -ForegroundColor White
            Write-Host "  [2] Отключить Microsoft Copilot" -ForegroundColor White
            Write-Host "  [3] Отключить веб-поиск Bing и спам в меню Пуск" -ForegroundColor White
            Write-Host "  [4] Отключить виджеты и новости на панели задач" -ForegroundColor White
            Write-Host "  [5] Отключить фоновую телеметрию и сбор данных (DiagTrack)" -ForegroundColor White
            Write-Host "  [6] Безопасно удалить предустановленный UWP-мусор (Store/Xbox целы)" -ForegroundColor White
            Write-Host "  [7] Выполнить ПОЛНЫЙ безопасный Debloat" -ForegroundColor Green
            Write-Host "  [0] Назад" -ForegroundColor Gray
            Write-Host ""
            $debChoice = Read-Host "Действие"
            if ($debChoice -eq "1") { Disable-Win11Recall }
            elseif ($debChoice -eq "2") { Disable-Win11Copilot }
            elseif ($debChoice -eq "3") { Disable-BingSearchAndCortana }
            elseif ($debChoice -eq "4") { Disable-WidgetsAndNews }
            elseif ($debChoice -eq "5") { Disable-TelemetryAndDiagnostics }
            elseif ($debChoice -eq "6") { Remove-SafeBloatwareApps }
            elseif ($debChoice -eq "7") {
                New-OptimizerRestorePoint -Description "FullDebloat" | Out-Null
                Disable-Win11Recall
                Disable-Win11Copilot
                Disable-BingSearchAndCortana
                Disable-WidgetsAndNews
                Disable-TelemetryAndDiagnostics
                Remove-SafeBloatwareApps
            }
            Write-Host "`nНажмите Enter для возврата в меню..."; Read-Host | Out-Null
        }
        "7" {
            Clear-Host
            Write-Host "==========================================================================" -ForegroundColor Cyan
            Write-Host "                     ИНТЕРФЕЙС И СИСТЕМНЫЕ ТВКИ                           " -ForegroundColor White
            Write-Host "==========================================================================" -ForegroundColor Cyan
            Write-Host "  [1] Переключить контекстное меню (Классическое Win10 / Новое Win11)" -ForegroundColor White
            Write-Host "  [2] Настроить Проводник (расширения, скрытые файлы, убрать галерею/рекомендации)" -ForegroundColor White
            Write-Host "  [3] Оптимизировать GameDVR (отключить фоновую запись, FSE mode)" -ForegroundColor White
            Write-Host "  [4] Активировать классический Просмотр Фотографий Windows" -ForegroundColor White
            Write-Host "  [5] Отключить энергосбережение USB (защита от лагов мыши)" -ForegroundColor White
            Write-Host "  [6] Отключить автоматическое обслуживание Windows (Maintenance)" -ForegroundColor White
            Write-Host "  [7] Скрыть/показать раздел 'Главная' (Home) в Проводнике" -ForegroundColor White
            Write-Host "  [8] Применить ВСЕ твики интерфейса" -ForegroundColor Green
            Write-Host "  [0] Назад" -ForegroundColor Gray
            Write-Host ""
            $uiChoice = Read-Host "Действие"
            if ($uiChoice -eq "1") {
                $isClassic = Test-Path "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32"
                Set-ClassicContextMenu -Enable (-not $isClassic)
            } elseif ($uiChoice -eq "2") {
                Set-FileExplorerTweaks
            } elseif ($uiChoice -eq "3") {
                Set-GameDvrOptimized
            } elseif ($uiChoice -eq "4") {
                Enable-ClassicWindowsPhotoViewer
            } elseif ($uiChoice -eq "5") {
                Disable-UsbPowerSaving
            } elseif ($uiChoice -eq "6") {
                Disable-WindowsAutomaticMaintenance
            } elseif ($uiChoice -eq "7") {
                $homeClsidKey = "HKLM:\SOFTWARE\Classes\CLSID\{f874310e-b6b7-47dc-bc84-b9e6b38f5903}"
                $isPinned = 1
                if (Test-Path $homeClsidKey) {
                    $prop = Get-ItemProperty -Path $homeClsidKey -ErrorAction SilentlyContinue
                    if ($prop -and $null -ne $prop.PSObject.Properties['System.IsPinnedToNameSpaceTree']) {
                        $isPinned = [int]$prop.'System.IsPinnedToNameSpaceTree'
                    }
                }
                Set-ExplorerHomeVisibility -Hide ($isPinned -eq 1)
            } elseif ($uiChoice -eq "8") {
                New-OptimizerRestorePoint -Description "SystemUI" | Out-Null
                Set-FileExplorerTweaks -NoRestart
                Set-GameDvrOptimized
                Enable-ClassicWindowsPhotoViewer
                Disable-UsbPowerSaving
                Disable-WindowsAutomaticMaintenance
                Set-ClassicContextMenu -Enable $true
            }
            Write-Host "`nНажмите Enter для возврата в меню..."; Read-Host | Out-Null
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
