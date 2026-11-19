# Diagnostics.psm1 - Diagnostics, Latency Audit, Timer Resolution & Status Check
# Encoding: UTF-8

Set-StrictMode -Version Latest

Import-Module (Join-Path -Path $PSScriptRoot -ChildPath "GamingLatency.psm1") -ErrorAction SilentlyContinue
Import-Module (Join-Path -Path $PSScriptRoot -ChildPath "NetworkGaming.psm1") -ErrorAction SilentlyContinue
Import-Module (Join-Path -Path $PSScriptRoot -ChildPath "SystemUI.psm1") -ErrorAction SilentlyContinue
Import-Module (Join-Path -Path $PSScriptRoot -ChildPath "GpuDisplay.psm1") -ErrorAction SilentlyContinue
Import-Module (Join-Path -Path $PSScriptRoot -ChildPath "Debloat.psm1") -ErrorAction SilentlyContinue

$Script:ReportDir = Join-Path -Path $PSScriptRoot -ChildPath "..\Reports"

function Initialize-DiagnosticsModule {
    if (-not (Test-Path -Path $Script:ReportDir)) {
        New-Item -Path $Script:ReportDir -ItemType Directory -Force | Out-Null
    }
}

# Win32 Timer Resolution через P/Invoke
try {
    $timerTypeDefinition = @"
using System;
using System.Runtime.InteropServices;
public class Win32TimerDiag {
    [DllImport("ntdll.dll", SetLastError = true)]
    public static extern int NtQueryTimerResolution(out uint minResolution, out uint maxResolution, out uint currentResolution);
}
"@
    if (-not ([System.Management.Automation.PSTypeName]'Win32TimerDiag').Type) {
        Add-Type -TypeDefinition $timerTypeDefinition -Language CSharp -ErrorAction SilentlyContinue
    }
} catch {}

function Get-SystemTimerResolution {
    try {
        [uint32]$min = 0; [uint32]$max = 0; [uint32]$cur = 0
        $res = [Win32TimerDiag]::NtQueryTimerResolution([ref]$min, [ref]$max, [ref]$cur)
        if ($res -eq 0) {
            return [PSCustomObject]@{
                MinMs     = [Math]::Round($min / 10000.0, 3)
                MaxMs     = [Math]::Round($max / 10000.0, 3)
                CurrentMs = [Math]::Round($cur / 10000.0, 3)
                Success   = $true
            }
        }
    } catch {}
    return [PSCustomObject]@{ MinMs = 0; MaxMs = 0; CurrentMs = 0; Success = $false }
}

function Get-SystemDpcMetrics {
    try {
        $sample = Get-Counter -Counter '\Processor(_Total)\% DPC Time', '\Processor(_Total)\% Interrupt Time', '\Processor(_Total)\DPCs Queued/sec' -SampleInterval 1 -MaxSamples 1 -ErrorAction Stop
        $dpcPercent = 0.0
        $isrPercent = 0.0
        $dpcsPerSec = 0.0
        foreach ($s in $sample.CounterSamples) {
            if ($s.Path -like "*% dpc time*") { $dpcPercent = [Math]::Round($s.CookedValue, 2) }
            elseif ($s.Path -like "*% interrupt time*") { $isrPercent = [Math]::Round($s.CookedValue, 2) }
            elseif ($s.Path -like "*dpcs queued/sec*") { $dpcsPerSec = [Math]::Round($s.CookedValue, 0) }
        }
        return [PSCustomObject]@{
            DpcPercent = $dpcPercent
            IsrPercent = $isrPercent
            DpcsPerSec = $dpcsPerSec
            Success    = $true
        }
    } catch {
        return [PSCustomObject]@{ DpcPercent = 0.0; IsrPercent = 0.0; DpcsPerSec = 0.0; Success = $false }
    }
}

function Test-NetworkPingLatency {
    [CmdletBinding()]
    param(
        [string[]]$Targets = @("1.1.1.1", "8.8.8.8"),
        [int]$Count = 4
    )

    $results = @()
    foreach ($target in $Targets) {
        $times = @()
        $lost = 0
        for ($i = 0; $i -lt $Count; $i++) {
            $ping = Test-Connection -ComputerName $target -Count 1 -ErrorAction SilentlyContinue
            if ($ping) {
                $times += $ping.ResponseTime
            } else {
                $lost++
            }
            Start-Sleep -Milliseconds 100
        }

        if ($times.Count -gt 0) {
            $measure = $times | Measure-Object -Average -Minimum -Maximum
            $jitter = $measure.Maximum - $measure.Minimum
            $lossPercent = [Math]::Round(($lost / $Count) * 100, 1)

            $results += [PSCustomObject]@{
                Target      = $target
                AvgPingMs   = [Math]::Round($measure.Average, 1)
                MinPingMs   = $measure.Minimum
                MaxPingMs   = $measure.Maximum
                JitterMs    = $jitter
                LossPercent = $lossPercent
            }
        } else {
            $results += [PSCustomObject]@{
                Target      = $target
                AvgPingMs   = -1
                MinPingMs   = -1
                MaxPingMs   = -1
                JitterMs    = -1
                LossPercent = 100
            }
        }
    }
    return $results
}

function Get-SystemOptimizationAudit {
    $audit = [System.Collections.Generic.List[PSCustomObject]]::new()

    # 1. MSI Mode на GPU
    $gpu = Get-PciMsiDevices | Where-Object { $_.Category -eq 'GPU' } | Select-Object -First 1
    $audit.Add([PSCustomObject]@{
        Category       = "Низкая Задержка"
        Setting        = "MSI Mode (GPU)"
        Status         = if ($gpu -and $gpu.MsiActive) { "ВКЛЮЧЕНО" } else { "ВЫКЛЮЧЕНО" }
        Details        = if ($gpu) { "$($gpu.Name) [Приоритет: $($gpu.PriorityText)]" } else { "GPU не найден" }
        Optimal        = [bool]($gpu -and $gpu.MsiActive)
        FixMenu        = "Главное меню -> Пункт [3] (Жёсткая оптимизация) -> [1] или Пункт [2] (Супер-буст)"
        Recommendation = "Перевести видеокарту в режим MSI с высоким приоритетом для устранения задержек очереди IRQ."
    })

    # 2. MSI Mode на Сети
    $nic = Get-PciMsiDevices | Where-Object { $_.Category -eq 'Network' } | Select-Object -First 1
    $audit.Add([PSCustomObject]@{
        Category       = "Низкая Задержка"
        Setting        = "MSI Mode (Сетевая карта)"
        Status         = if ($nic -and $nic.MsiActive) { "ВКЛЮЧЕНО" } else { "ВЫКЛЮЧЕНО" }
        Details        = if ($nic) { "$($nic.Name) [Приоритет: $($nic.PriorityText)]" } else { "Сетевая карта не найдена" }
        Optimal        = [bool]($nic -and $nic.MsiActive)
        FixMenu        = "Главное меню -> Пункт [3] (Жёсткая оптимизация) -> [1] или Пункт [2] (Супер-буст)"
        Recommendation = "Включить MSI Mode для сетевой карты для ускоренной обработки пакетов."
    })

    # 3. MSI Mode на Звуковых картах
    $audios = @(Get-PciMsiDevices | Where-Object { $_.Category -eq 'Audio' })
    $audioActive = $false
    $audioDetails = "Аудиоустройства не найдены"
    if ($audios.Count -gt 0) {
        $msiCount = @($audios | Where-Object { $_.MsiActive }).Count
        $audioActive = ($msiCount -eq $audios.Count)
        $audioDetails = "$($audios.Count) устройств (MSI активен у $msiCount): " + (($audios | ForEach-Object { "$($_.Name) [MSI:$($_.MsiActive)]" }) -join "; ")
    }
    $audit.Add([PSCustomObject]@{
        Category       = "Низкая Задержка"
        Setting        = "MSI Mode (Звуковые карты)"
        Status         = if ($audioActive) { "ВКЛЮЧЕНО" } else { "ВЫКЛЮЧЕНО / ЧАСТИЧНО" }
        Details        = $audioDetails
        Optimal        = [bool]$audioActive
        FixMenu        = "Главное меню -> Пункт [3] (Жёсткая оптимизация) -> [1] или Пункт [2] (Супер-буст)"
        Recommendation = "Перевести контроллеры звука в MSI Mode для предотвращения щелчков звука и DPC лагов."
    })

    # 4. Алгоритм Нейгла (Nagle's Algorithm)
    $hasNagleDisabled = $false
    $tcpInterfaces = Get-ChildItem "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces" -ErrorAction SilentlyContinue
    if ($tcpInterfaces) {
        foreach ($k in $tcpInterfaces) {
            $p = Get-ItemProperty $k.PSPath -ErrorAction SilentlyContinue
            if ($p -and $p.PSObject.Properties['TcpAckFrequency'] -and $p.TcpAckFrequency -eq 1 -and $p.PSObject.Properties['TCPNoDelay'] -and $p.TCPNoDelay -eq 1) {
                $hasNagleDisabled = $true
                break
            }
        }
    }
    $audit.Add([PSCustomObject]@{
        Category       = "Сетевой Стек"
        Setting        = "Алгоритм Нейгла (TcpAckFrequency/TCPNoDelay)"
        Status         = if ($hasNagleDisabled) { "ОТКЛЮЧЕН (Оптимизировано)" } else { "АКТИВЕН (Дефолт)" }
        Details        = if ($hasNagleDisabled) { "Мгновенная отправка пакетов без задержек" } else { "Пакеты буферизуются Windows" }
        Optimal        = [bool]$hasNagleDisabled
        FixMenu        = "Главное меню -> Пункт [4] (Игровой сетевой стек) или Пункт [2] (Супер-буст)"
        Recommendation = "Отключить буферизацию пакетов TCP для мгновенного отклика в онлайн-шутерах."
    })

    # 5. NetworkThrottlingIndex
    $sysProfile = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" -ErrorAction SilentlyContinue
    $isNetThrottlingOff = ($sysProfile -and $sysProfile.PSObject.Properties['NetworkThrottlingIndex'] -and $sysProfile.NetworkThrottlingIndex -eq 0xFFFFFFFF)
    $audit.Add([PSCustomObject]@{
        Category       = "Сетевой Стек"
        Setting        = "NetworkThrottlingIndex"
        Status         = if ($isNetThrottlingOff) { "ОТКЛЮЧЕН (0xFFFFFFFF)" } else { "АКТИВЕН" }
        Details        = "Ограничение скорости сетевых пакетов при мультимедиа"
        Optimal        = [bool]$isNetThrottlingOff
        FixMenu        = "Главное меню -> Пункт [4] (Игровой сетевой стек) или Пункт [2] (Супер-буст)"
        Recommendation = "Снять встроенный сетевой троттлинг Windows 11 (значение 0xFFFFFFFF)."
    })

    # 6. Энергосбережение сети (Energy Efficient Ethernet / Green Ethernet)
    $eeeOptimal = $true
    try {
        $netPower = @(Get-NetworkPowerSavingStatus)
        if ($netPower.Count -gt 0) {
            $badCount = @($netPower | Where-Object { -not $_.EeeOptimal -or -not $_.UlpOptimal }).Count
            if ($badCount -gt 0) {
                $eeeOptimal = $false
            }
        }
    } catch {}
    $audit.Add([PSCustomObject]@{
        Category       = "Сетевой Стек"
        Setting        = "Энергосбережение сети (EEE/ULP/Green Ethernet)"
        Status         = if ($eeeOptimal) { "ОТКЛЮЧЕНО (Оптимально)" } else { "ВКЛЮЧЕНО (Задержки)" }
        Details        = "Отключение спящих режимов предотвращает микрофризы и джиттер"
        Optimal        = [bool]$eeeOptimal
        FixMenu        = "Главное меню -> Пункт [4] (Игровой сетевой стек) или Пункт [2] (Супер-буст)"
        Recommendation = "Отключить энергосберегающие режимы Ethernet (EEE/ULP) во избежание джиттера."
    })

    # 7. SystemResponsiveness
    $isSysRespZero = ($sysProfile -and $sysProfile.PSObject.Properties['SystemResponsiveness'] -and $sysProfile.SystemResponsiveness -eq 0)
    $audit.Add([PSCustomObject]@{
        Category       = "Системный Профиль"
        Setting        = "SystemResponsiveness"
        Status         = if ($isSysRespZero) { "0% (100% ресурсов играм)" } else { "20% (Windows дефолт)" }
        Details        = "Резервация мощности процессора под системные задачи"
        Optimal        = [bool]$isSysRespZero
        FixMenu        = "Главное меню -> Пункт [3] -> [4] или Пункт [2] (Супер-буст)"
        Recommendation = "Выставить 0% системного резерва, отдав 100% мощности процессора игре."
    })

    # 8. Win32PrioritySeparation
    $priCtrl = Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl" -ErrorAction SilentlyContinue
    $win32Pri = if ($priCtrl -and $priCtrl.PSObject.Properties['Win32PrioritySeparation']) { [int]$priCtrl.Win32PrioritySeparation } else { 2 }
    $isWin32Optimal = ($win32Pri -eq 38 -or $win32Pri -eq 40)
    $audit.Add([PSCustomObject]@{
        Category       = "Процессор"
        Setting        = "Win32PrioritySeparation"
        Status         = "$win32Pri $(if ($win32Pri -eq 38) { '(0x26 Gaming Foreground)' } elseif ($win32Pri -eq 2) { '(Дефолт)' } else { '' })"
        Details        = "Квантование времени процессора для активного окна"
        Optimal        = [bool]$isWin32Optimal
        FixMenu        = "Главное меню -> Пункт [3] -> [2] или Пункт [2] (Супер-буст)"
        Recommendation = "Выставить кванты 38 (0x26) для наивысшего приоритета активного игрового процесса."
    })

    # 9. Power Throttling
    $pThrottle = Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling" -ErrorAction SilentlyContinue
    $isPowerThrottlingOff = ($pThrottle -and $pThrottle.PSObject.Properties['PowerThrottlingOff'] -and $pThrottle.PowerThrottlingOff -eq 1)
    $audit.Add([PSCustomObject]@{
        Category       = "Процессор"
        Setting        = "Power Throttling"
        Status         = if ($isPowerThrottlingOff) { "ОТКЛЮЧЕН" } else { "АКТИВЕН (Windows дефолт)" }
        Details        = "Снижение частот для фоновых процессов и игр"
        Optimal        = [bool]$isPowerThrottlingOff
        FixMenu        = "Главное меню -> Пункт [3] -> [2] или Пункт [2] (Супер-буст)"
        Recommendation = "Отключить троттлинг ядер и потоков для предотвращения просадок тактовой частоты."
    })

    # 10. VBS / HVCI
    $vbs = Get-VbsStatus
    $audit.Add([PSCustomObject]@{
        Category       = "Безопасность/FPS"
        Setting        = "Изоляция ядра (VBS / HVCI)"
        Status         = if ($vbs.VbsActive) { "ВКЛЮЧЕНА (Защита)" } else { "ВЫКЛЮЧЕНА (+FPS)" }
        Details        = if ($vbs.VbsActive) { "Замедляет игры на 5-15% на некоторых CPU" } else { "Максимальная производительность" }
        Optimal        = [bool](-not $vbs.VbsActive)
        FixMenu        = "Главное меню -> Пункт [3] (Жёсткая оптимизация) -> [6] (Изоляция ядра)"
        Recommendation = "Отключить VBS/HVCI для прироста 5-15% FPS (по желанию, снижает защиту ядра)."
    })

    # 11. GameDVR
    $gcs = Get-ItemProperty "HKCU:\System\GameConfigStore" -ErrorAction SilentlyContinue
    $isGameDvrOff = ($gcs -and $gcs.PSObject.Properties['GameDVR_Enabled'] -and $gcs.GameDVR_Enabled -eq 0)
    $audit.Add([PSCustomObject]@{
        Category       = "Гейминг"
        Setting        = "GameDVR Фоновая Запись"
        Status         = if ($isGameDvrOff) { "ОТКЛЮЧЕНА" } else { "АКТИВНА" }
        Details        = "Устраняет микрофризы и дропы FPS"
        Optimal        = [bool]$isGameDvrOff
        FixMenu        = "Главное меню -> Пункт [7] (Интерфейс) -> [3] или Пункт [2] (Супер-буст)"
        Recommendation = "Отключить скрытую фоновую видеозапись GameDVR для устранения микрофризов."
    })

    # 12. Copilot
    $copilot = Get-ItemProperty "HKCU:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot" -ErrorAction SilentlyContinue
    $isCopilotOff = ($copilot -and $copilot.PSObject.Properties['TurnOffWindowsCopilot'] -and $copilot.TurnOffWindowsCopilot -eq 1)
    $audit.Add([PSCustomObject]@{
        Category       = "Debloat"
        Setting        = "Microsoft Copilot"
        Status         = if ($isCopilotOff) { "ОТКЛЮЧЕН" } else { "АКТИВЕН" }
        Details        = "AI ассистент и фоновые процессы"
        Optimal        = [bool]$isCopilotOff
        FixMenu        = "Главное меню -> Пункт [6] (Debloat) -> [2] или Пункт [6] -> [7] (Полный Debloat)"
        Recommendation = "Отключить Windows Copilot и фоновые процессы AI для освобождения оперативной памяти."
    })

    # 13. Поиск Bing в Меню Пуск
    $bSearch = Get-ItemProperty "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" -ErrorAction SilentlyContinue
    $isBingOff = ($bSearch -and $bSearch.PSObject.Properties['BingSearchEnabled'] -and $bSearch.BingSearchEnabled -eq 0)
    $audit.Add([PSCustomObject]@{
        Category       = "Debloat"
        Setting        = "Веб-поиск Bing в меню Пуск"
        Status         = if ($isBingOff) { "ОТКЛЮЧЕН" } else { "АКТИВЕН" }
        Details        = "Поиск ищет только локальные файлы без задержек"
        Optimal        = [bool]$isBingOff
        FixMenu        = "Главное меню -> Пункт [6] (Debloat) -> [3] или Пункт [6] -> [7] (Полный Debloat)"
        Recommendation = "Отключить веб-поиск Bing для мгновенного отклика меню Пуск без отправки запросов в сеть."
    })

    # 14. Телеметрия DiagTrack
    $diagTrack = Get-Service -Name "DiagTrack" -ErrorAction SilentlyContinue
    $isTelemetryOff = ($diagTrack -and ($diagTrack.StartType -eq 'Disabled' -or $diagTrack.Status -ne 'Running'))
    $audit.Add([PSCustomObject]@{
        Category       = "Приватность"
        Setting        = "Служба Телеметрии (DiagTrack)"
        Status         = if ($isTelemetryOff) { "ОТКЛЮЧЕНА" } else { "РАБОТАЕТ" }
        Details        = "Фоновая отправка диагностических логов"
        Optimal        = [bool]$isTelemetryOff
        FixMenu        = "Главное меню -> Пункт [6] (Debloat) -> [5] или Пункт [6] -> [7] (Полный Debloat)"
        Recommendation = "Отключить службу сбора телеметрии для снятия фоновой нагрузки с диска и процессора."
    })

    # 15. Классическое контекстное меню
    $isClassicMenu = Test-Path "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32"
    $audit.Add([PSCustomObject]@{
        Category       = "Интерфейс"
        Setting        = "Классическое Контекстное Меню"
        Status         = if ($isClassicMenu) { "АКТИВНО (Win10 Style)" } else { "СТАНДАРТНОЕ (Win11)" }
        Details        = "Полное контекстное меню без 'Показать дополнительные параметры'"
        Optimal        = [bool]$isClassicMenu
        FixMenu        = "Главное меню -> Пункт [7] (Интерфейс) -> [1] или Пункт [2] (Супер-буст)"
        Recommendation = "Включить классическое меню проводника без медленного скрытого клика 'Дополнительно'."
    })

    # 16. Компактный вид Проводника (Compact View)
    $adv = Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -ErrorAction SilentlyContinue
    $isCompact = ($adv -and $adv.PSObject.Properties['UseCompactMode'] -and $adv.UseCompactMode -eq 1)
    $audit.Add([PSCustomObject]@{
        Category       = "Интерфейс"
        Setting        = "Компактный вид папок (Compact View)"
        Status         = if ($isCompact) { "ВКЛЮЧЕНО" } else { "СТАНДАРТНЫЙ" }
        Details        = "Уменьшенные отступы в Проводнике для быстрого доступа"
        Optimal        = [bool]$isCompact
        FixMenu        = "Главное меню -> Пункт [7] (Интерфейс) -> [2] или Пункт [2] (Супер-буст)"
        Recommendation = "Включить компактный вид папок для быстрого и удобного обзора файлов."
    })

    # 17. Скрытие спама картинок в поиске (Search Highlights)
    $sh = Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\SearchSettings" -ErrorAction SilentlyContinue
    $isShOff = ($sh -and $sh.PSObject.Properties['IsSearchHighlightsEnabled'] -and $sh.IsSearchHighlightsEnabled -eq 0)
    $audit.Add([PSCustomObject]@{
        Category       = "Интерфейс"
        Setting        = "Спам выделений поиска (Search Highlights)"
        Status         = if ($isShOff) { "ОТКЛЮЧЕН" } else { "АКТИВЕН" }
        Details        = "Убирает веб-картинки и анимации из строки поиска панели задач"
        Optimal        = [bool]$isShOff
        FixMenu        = "Главное меню -> Пункт [7] (Интерфейс) -> [2] или Пункт [2] (Супер-буст)"
        Recommendation = "Отключить загрузку веб-картинок и рекламы в поле поиска на панели задач."
    })

    # 18. MPO (Multi-Plane Overlay)
    $mpoStatus = Get-MpoStatus
    $audit.Add([PSCustomObject]@{
        Category       = "GPU и Дисплей"
        Setting        = "MPO (Multi-Plane Overlay)"
        Status         = if ($mpoStatus.Disabled) { "ОТКЛЮЧЕН (Оптимально)" } else { "ВКЛЮЧЕН (Дефолт)" }
        Details        = $mpoStatus.Description
        Optimal        = [bool]$mpoStatus.Disabled
        FixMenu        = "Главное меню -> Пункт [5] (GPU и Дисплей) -> [1] или Пункт [2] (Супер-буст)"
        Recommendation = "Отключить MPO (OverlayTestMode=5) для устранения микро-статтеров и мерцаний в OBS/Discord/играх."
    })

    # 19. HAGS (Hardware-Accelerated GPU Scheduling)
    $hagsStatus = Get-HagsStatus
    $audit.Add([PSCustomObject]@{
        Category       = "GPU и Дисплей"
        Setting        = "Планирование GPU (HAGS)"
        Status         = if ($hagsStatus.Enabled) { "ВКЛЮЧЕН (Оптимально)" } else { "ВЫКЛЮЧЕН / ДЕФОЛТ" }
        Details        = $hagsStatus.Description
        Optimal        = [bool]$hagsStatus.Enabled
        FixMenu        = "Главное меню -> Пункт [5] (GPU и Дисплей) -> [2] или Пункт [2] (Супер-буст)"
        Recommendation = "Включить аппаратное ускорение HAGS для минимальной задержки отрисовки и DLSS 3 Frame Gen."
    })

    # 20. Оптимизации для оконных игр DirectX
    $dxPref = Get-ItemProperty "HKCU:\Software\Microsoft\DirectX\UserGpuPreferences" -ErrorAction SilentlyContinue
    $isDxOpt = ($dxPref -and $dxPref.PSObject.Properties['DirectXUserGlobalSettings'] -and ($dxPref.DirectXUserGlobalSettings -like "*AutoPlayMode=1*"))
    $audit.Add([PSCustomObject]@{
        Category       = "GPU и Дисплей"
        Setting        = "Оконные оптимизации DirectX"
        Status         = if ($isDxOpt) { "ВКЛЮЧЕНО (AutoPlayMode=1)" } else { "ВЫКЛЮЧЕНО" }
        Details        = "Снижение задержки ввода и поддержка VRR/G-Sync в Borderless окне"
        Optimal        = [bool]$isDxOpt
        FixMenu        = "Главное меню -> Пункт [5] (GPU и Дисплей) -> [3] или Пункт [2] (Супер-буст)"
        Recommendation = "Включить 'Оптимизации для игр в оконном режиме' DirectX для ультра-низкого инпут-лага."
    })

    # 21. Защита видеодрайвера от Windows Update
    $wuDrv = Get-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" -ErrorAction SilentlyContinue
    $isWuDrvOff = ($wuDrv -and $wuDrv.PSObject.Properties['ExcludeWUDriversInQualityUpdate'] -and $wuDrv.ExcludeWUDriversInQualityUpdate -eq 1)
    $audit.Add([PSCustomObject]@{
        Category       = "GPU и Дисплей"
        Setting        = "Защита видеодрайвера от Windows Update"
        Status         = if ($isWuDrvOff) { "ЗАЩИЩЕН (ExcludeWUDrivers=1)" } else { "НЕ ЗАЩИЩЕН" }
        Details        = "Предотвращает внезапную замену стабильного кастомного видеодрайвера"
        Optimal        = [bool]$isWuDrvOff
        FixMenu        = "Главное меню -> Пункт [5] (GPU и Дисплей) -> [4] или Пункт [2] (Супер-буст)"
        Recommendation = "Заблокировать автоматическую замену видеодрайвера через Центр обновлений Windows."
    })

    # 22. Игровой DNS и DoH
    $activeNet = Get-PrimaryActiveNetworkInterface
    $curDnsList = if ($activeNet -and $activeNet.CurrentDns) { @($activeNet.CurrentDns) } else { @() }
    $fastDnsServers = @("1.1.1.1", "1.0.0.1", "9.9.9.9", "149.112.112.112", "94.140.14.14", "94.140.15.15", "8.8.8.8", "8.8.4.4")
    $isFastDns = (@($curDnsList).Count -gt 0 -and @($curDnsList | Where-Object { $_ -in $fastDnsServers }).Count -gt 0)
    $dnsProviderLabel = if ($isFastDns) {
        if ($curDnsList -contains "1.1.1.1" -or $curDnsList -contains "1.0.0.1") { "Cloudflare (1.1.1.1)" }
        elseif ($curDnsList -contains "9.9.9.9" -or $curDnsList -contains "149.112.112.112") { "Quad9 (9.9.9.9)" }
        elseif ($curDnsList -contains "94.140.14.14" -or $curDnsList -contains "94.140.15.15") { "AdGuard (94.140.14.14)" }
        else { "Google (8.8.8.8)" }
    } else {
        if (@($curDnsList).Count -gt 0) { "Провайдер / Роутер ($($curDnsList -join ', '))" } else { "Авто (DHCP)" }
    }
    $audit.Add([PSCustomObject]@{
        Category       = "Сетевой Стек"
        Setting        = "Игровой DNS и шифрование DoH"
        Status         = if ($isFastDns) { "ОПТИМИЗИРОВАН ($dnsProviderLabel)" } else { "СТАНДАРТНЫЙ ($dnsProviderLabel)" }
        Details        = "Быстрый Anycast DNS снижает пинг и время подключения к игровым серверам"
        Optimal        = [bool]$isFastDns
        FixMenu        = "Главное меню -> Пункт [4] (Игровой сетевой стек) -> [3] (DNS Switcher)"
        Recommendation = "Установить быстрый игровой DNS (Cloudflare, Quad9, AdGuard) с поддержкой DoH."
    })

    # 23. Автоматическое обслуживание Windows
    $maint = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\Maintenance" -ErrorAction SilentlyContinue
    $isMaintOff = ($maint -and $maint.PSObject.Properties['MaintenanceDisabled'] -and $maint.MaintenanceDisabled -eq 1)
    $audit.Add([PSCustomObject]@{
        Category       = "Системный Профиль"
        Setting        = "Автоматическое обслуживание Windows"
        Status         = if ($isMaintOff) { "ОТКЛЮЧЕНО (Оптимально)" } else { "АКТИВНО (Дефолт)" }
        Details        = "Отключение предотвращает фоновую нагрузку на CPU и SSD во время игр"
        Optimal        = [bool]$isMaintOff
        FixMenu        = "Главное меню -> Пункт [7] (Интерфейс и система) -> [6] или Пункт [2] (Супер-буст)"
        Recommendation = "Отключить автоматическое обслуживание во избежание внезапных просадок FPS."
    })

    # 24. Скрытие блока 'Рекомендуем' в меню Пуск
    $pmStart = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device\Start" -ErrorAction SilentlyContinue
    $isRecHidden = ($pmStart -and $pmStart.PSObject.Properties['HideRecommendedSection'] -and $pmStart.HideRecommendedSection -eq 1)
    $audit.Add([PSCustomObject]@{
        Category       = "Интерфейс"
        Setting        = "Блок 'Рекомендуем' в меню Пуск"
        Status         = if ($isRecHidden) { "СКРЫТ (Оптимально)" } else { "ОТОБРАЖАЕТСЯ" }
        Details        = "Убирает спам недавно открытых файлов и предложений из меню Пуск"
        Optimal        = [bool]$isRecHidden
        FixMenu        = "Главное меню -> Пункт [7] (Интерфейс и система) -> [2] или Пункт [2] (Супер-буст)"
        Recommendation = "Скрыть пустой блок рекомендаций для чистого и отзывчивого меню Пуск."
    })

    # 25. NVIDIA HDCP DRM Killer
    $nvGpus = @(Get-NvidiaDisplayAdapterKeys)
    $hasNvGpu = ($nvGpus.Count -gt 0)
    $isHdcpDisabled = $false
    if ($hasNvGpu) {
        $p = Get-ItemProperty -Path $nvGpus[0].RegistryPath -ErrorAction SilentlyContinue
        if ($p -and $p.PSObject.Properties['RMHdcpKeyglobZero'] -and $p.RMHdcpKeyglobZero -eq 1) {
            $isHdcpDisabled = $true
        }
    }
    $audit.Add([PSCustomObject]@{
        Category       = "GPU и Дисплей"
        Setting        = "NVIDIA HDCP DRM (RMHdcpKeyglobZero)"
        Status         = if (-not $hasNvGpu) { "Н/Д (GPU не NVIDIA)" } elseif ($isHdcpDisabled) { "ОТКЛЮЧЕН (Оптимально)" } else { "АКТИВЕН (Дефолт)" }
        Details        = if (-not $hasNvGpu) { "Применяется только для видеокарт NVIDIA" } elseif ($isHdcpDisabled) { "Устранены задержки HDCP рукопожатий" } else { "Фоновые DRM рукопожатия GPU активны" }
        Optimal        = [bool](-not $hasNvGpu -or $isHdcpDisabled)
        FixMenu        = "Главное меню -> Пункт [5] (GPU и Дисплей) -> [5] или Пункт [2] (Супер-буст)"
        Recommendation = "Отключить HDCP DRM для устранения периодических микро-задержек видеокарты в играх."
    })

    # 26. Раздел 'Главная' (Home) в Проводнике
    $homeKey = Get-ItemProperty "HKLM:\SOFTWARE\Classes\CLSID\{f874310e-b6b7-47dc-bc84-b9e6b38f5903}" -ErrorAction SilentlyContinue
    $nsHome1Exists = Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Desktop\NameSpace\{f874310e-b6b7-47dc-bc84-b9e6b38f5903}"
    $isHomeHidden = ($homeKey -and $homeKey.PSObject.Properties['System.IsPinnedToNameSpaceTree'] -and $homeKey.'System.IsPinnedToNameSpaceTree' -eq 0 -and -not $nsHome1Exists)
    $audit.Add([PSCustomObject]@{
        Category       = "Интерфейс"
        Setting        = "Раздел 'Главная' (Home) в Проводнике"
        Status         = if ($isHomeHidden) { "СКРЫТ (Оптимально)" } else { "ОТОБРАЖАЕТСЯ" }
        Details        = "Очищает дерево навигации Проводника от лишних системных папок"
        Optimal        = [bool]$isHomeHidden
        FixMenu        = "Главное меню -> Пункт [7] (Интерфейс и система) -> [7] или [2] (Супер-буст)"
        Recommendation = "Скрыть раздел 'Главная' из Проводника для чистого классического интерфейса."
    })

    # 27. Энергосбережение USB (Selective Suspend)
    $usbStatus = Get-UsbPowerSavingStatus
    $audit.Add([PSCustomObject]@{
        Category       = "Интерфейс и Оборудование"
        Setting        = "Энергосбережение USB (Selective Suspend)"
        Status         = if ($usbStatus.Disabled) { "ОТКЛЮЧЕНО (Оптимально)" } else { "ВКЛЮЧЕНО (Дефолт)" }
        Details        = $usbStatus.Description
        Optimal        = [bool]$usbStatus.Disabled
        FixMenu        = "Главное меню -> Пункт [7] (Интерфейс и система) -> [5] или Пункт [2] (Супер-буст)"
        Recommendation = "Отключить спящие режимы USB для предотвращения микро-лагов и задержек мыши/клавиатуры."
    })

    return $audit
}

function Show-OptimizationHealthCheck {
    Initialize-DiagnosticsModule

    Clear-Host
    Write-Host "==========================================================================" -ForegroundColor Cyan
    Write-Host "       ПРОВЕРКА ТЕКУЩЕЙ ОПТИМИЗАЦИИ КОМПЬЮТЕРА (HEALTH-CHECK)             " -ForegroundColor White
    Write-Host "             Разработано специально для Вас, Шеф!                         " -ForegroundColor DarkCyan
    Write-Host "==========================================================================" -ForegroundColor Cyan

    # Общая информация о системе
    $os = Get-CimInstance Win32_OperatingSystem
    $cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
    $gpu = Get-CimInstance Win32_VideoController | Select-Object -First 1
    $powerPlan = (powercfg /getactivescheme 2>&1) -replace ".*GUID.*:\s*", ""

    Write-Host "  ОС:            " -NoNewline -ForegroundColor DarkGray; Write-Host "$($os.Caption) ($($os.Version))" -ForegroundColor White
    Write-Host "  Процессор:     " -NoNewline -ForegroundColor DarkGray; Write-Host "$($cpu.Name)" -ForegroundColor White
    Write-Host "  Видеокарта:    " -NoNewline -ForegroundColor DarkGray; Write-Host "$($gpu.Name)" -ForegroundColor White
    Write-Host "  Схема Питания: " -NoNewline -ForegroundColor DarkGray; Write-Host "$powerPlan" -ForegroundColor White

    # Live DPC & Interrupt Metrics
    $dpc = Get-SystemDpcMetrics
    if ($dpc.Success) {
        $dpcStatus = if ($dpc.DpcPercent -lt 1.0) { "[В норме]" } else { "[Повышена]" }
        $dpcColor = if ($dpc.DpcPercent -lt 1.0) { "Green" } else { "Yellow" }
        Write-Host "  DPC/ISR Задержка: " -NoNewline -ForegroundColor DarkGray
        Write-Host "% DPC Time: $($dpc.DpcPercent)% | Interrupts: $($dpc.IsrPercent)% | DPCs/сек: $($dpc.DpcsPerSec) " -NoNewline -ForegroundColor White
        Write-Host "$dpcStatus" -ForegroundColor $dpcColor
    }

    # Таймер Windows
    $timer = Get-SystemTimerResolution
    if ($timer.Success) {
        $timerColor = if ($timer.CurrentMs -le 1.0) { "Green" } else { "Yellow" }
        Write-Host "  Таймер Windows:   " -NoNewline -ForegroundColor DarkGray
        Write-Host "$($timer.CurrentMs) ms " -NoNewline -ForegroundColor $timerColor
        Write-Host "(Min: $($timer.MinMs) ms, Max: $($timer.MaxMs) ms)" -ForegroundColor DarkGray
    }

    $audit = Get-SystemOptimizationAudit
    $optimalItems = @($audit | Where-Object { $_.Optimal })
    $neededItems  = @($audit | Where-Object { -not $_.Optimal })

    # 1. Список нормальных параметров
    Write-Host "`n--------------------------------------------------------------------------" -ForegroundColor DarkGray
    Write-Host "  🟢  ЭТИ НАСТРОЙКИ СЕЙЧАС В НОРМЕ ($($optimalItems.Count) из $($audit.Count))" -ForegroundColor Green
    Write-Host "--------------------------------------------------------------------------" -ForegroundColor DarkGray

    if ($optimalItems.Count -eq 0) {
        Write-Host "  (Пока ни одна ключевая оптимизация не активна)" -ForegroundColor Gray
    } else {
        foreach ($item in $optimalItems) {
            Write-Host "  [✓] " -NoNewline -ForegroundColor Green
            Write-Host "$($item.Setting): " -NoNewline -ForegroundColor White
            Write-Host "$($item.Status)" -ForegroundColor Green
            Write-Host "      Детали: $($item.Details)" -ForegroundColor DarkGray
        }
    }

    # 2. Список параметров, которые нужно выполнить
    Write-Host "`n--------------------------------------------------------------------------" -ForegroundColor DarkGray
    Write-Host "  🔴  ЭТИ НАСТРОЙКИ НУЖНО ВЫПОЛНИТЬ ($($neededItems.Count) параметров)" -ForegroundColor Yellow
    Write-Host "--------------------------------------------------------------------------" -ForegroundColor DarkGray

    if ($neededItems.Count -eq 0) {
        Write-Host "  🎉 Превосходно, Шеф! Все ключевые игровые оптимизации уже применены!" -ForegroundColor Green
    } else {
        foreach ($item in $neededItems) {
            Write-Host "  [!] " -NoNewline -ForegroundColor Yellow
            Write-Host "$($item.Setting): " -NoNewline -ForegroundColor White
            Write-Host "$($item.Status)" -ForegroundColor Red
            Write-Host "      Рекомендация: $($item.Recommendation)" -ForegroundColor Gray
            Write-Host "      👉 Где исправить: $($item.FixMenu)" -ForegroundColor Cyan
        }
    }

    # Прогресс-бар и оценка
    $score = [Math]::Round(($optimalItems.Count / $audit.Count) * 100, 0)
    $barFilled = [Math]::Floor($score / 5)
    $barEmpty = 20 - $barFilled
    $barStr = ("█" * $barFilled) + ("░" * $barEmpty)

    $verdict = if ($score -ge 85) { "ОТЛИЧНО (ПК полностью настроен для соревновательного гейминга)" }
               elseif ($score -ge 50) { "ХОРОШО (Часть настроек уже готова, но есть резерв для снижения задержек)" }
               else { "ТРЕБУЕТСЯ ОПТИМИЗАЦИЯ (Система работает на стандартных замедляющих дефолтах)" }
    $verdictColor = if ($score -ge 85) { "Green" } elseif ($score -ge 50) { "Yellow" } else { "Red" }

    Write-Host "`n==========================================================================" -ForegroundColor Cyan
    Write-Host "  УРОВЕНЬ ОПТИМИЗАЦИИ: $score%  [$barStr]" -ForegroundColor $verdictColor
    Write-Host "  ВЕРДИКТ: $verdict" -ForegroundColor White
    Write-Host "==========================================================================" -ForegroundColor Cyan

    Write-Host ""
    if ($neededItems.Count -gt 0) {
        Write-Host "  [1] 🚀 Применить недостающие оптимизации прямо сейчас (Игровой супер-буст)" -ForegroundColor Green
    }
    Write-Host "  [S] 💾 Сохранить подробный текстовый отчет аудита" -ForegroundColor White
    Write-Host "  [Enter] ↩️  Вернуться в главное меню" -ForegroundColor Gray
    Write-Host ""

    $action = ""
    try {
        if (-not [Console]::IsInputRedirected) {
            $action = Read-Host "Шеф, выберите действие"
        }
    } catch {}

    if ($action -eq "1" -and $neededItems.Count -gt 0) {
        return "ApplySuperBoost"
    } elseif ($action -ieq "S") {
        $timestamp = (Get-Date).ToString("yyyyMMdd_HHmmss")
        $reportPath = Join-Path -Path $Script:ReportDir -ChildPath "SystemAudit_$timestamp.txt"
        
        $sb = [System.Text.StringBuilder]::new()
        [void]$sb.AppendLine("=== WIN11 OPTIMIZER SYSTEM HEALTH-CHECK REPORT ===")
        [void]$sb.AppendLine("Date: $(Get-Date)")
        [void]$sb.AppendLine("OS: $($os.Caption) ($($os.Version))")
        [void]$sb.AppendLine("CPU: $($cpu.Name)")
        [void]$sb.AppendLine("GPU: $($gpu.Name)")
        [void]$sb.AppendLine("Power Plan: $powerPlan")
        [void]$sb.AppendLine("Timer: Current=$($timer.CurrentMs)ms Min=$($timer.MinMs)ms Max=$($timer.MaxMs)ms")
        if ($dpc.Success) {
            [void]$sb.AppendLine("DPC/ISR: DpcTime=$($dpc.DpcPercent)% InterruptTime=$($dpc.IsrPercent)% DpcsQueuedSec=$($dpc.DpcsPerSec)")
        }
        [void]$sb.AppendLine("Score: $score% ($($optimalItems.Count) / $($audit.Count))")
        [void]$sb.AppendLine("Verdict: $verdict")
        [void]$sb.AppendLine("`n--- НАСТРОЙКИ В НОРМЕ ---")
        foreach ($item in $optimalItems) {
            [void]$sb.AppendLine("[OK] $($item.Setting): $($item.Status) - $($item.Details)")
        }
        [void]$sb.AppendLine("`n--- НАСТРОЙКИ, ТРЕБУЮЩИЕ ВЫПОЛНЕНИЯ ---")
        foreach ($item in $neededItems) {
            [void]$sb.AppendLine("[NEED] $($item.Setting): $($item.Status)")
            [void]$sb.AppendLine("       Рекомендация: $($item.Recommendation)")
            [void]$sb.AppendLine("       Где исправить: $($item.FixMenu)")
        }

        [System.IO.File]::WriteAllText($reportPath, $sb.ToString(), [System.Text.Encoding]::UTF8)
        Write-Host "`n[OK] Отчет сохранен: $reportPath" -ForegroundColor Green
        Start-Sleep -Seconds 2
    }
    return "Menu"
}

function Show-DiagnosticsDashboard {
    Initialize-DiagnosticsModule

    Clear-Host
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host "        ДИАГНОСТИЧЕСКАЯ ПАНЕЛЬ И АУДИТ СИСТЕМЫ (WINDOWS 11)     " -ForegroundColor White
    Write-Host "================================================================" -ForegroundColor Cyan

    # Общая информация о системе
    $os = Get-CimInstance Win32_OperatingSystem
    $cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
    $gpu = Get-CimInstance Win32_VideoController | Select-Object -First 1
    $powerPlan = (powercfg /getactivescheme 2>&1) -replace ".*GUID.*:\s*", ""

    Write-Host "  ОС:            " -NoNewline -ForegroundColor DarkGray; Write-Host "$($os.Caption) ($($os.Version))" -ForegroundColor White
    Write-Host "  Процессор:     " -NoNewline -ForegroundColor DarkGray; Write-Host "$($cpu.Name) ($($cpu.NumberOfLogicalProcessors) ядер)" -ForegroundColor White
    Write-Host "  Видеокарта:    " -NoNewline -ForegroundColor DarkGray; Write-Host "$($gpu.Name)" -ForegroundColor White
    Write-Host "  Схема Питания: " -NoNewline -ForegroundColor DarkGray; Write-Host "$powerPlan" -ForegroundColor White

    # Таймер Windows
    $timer = Get-SystemTimerResolution
    if ($timer.Success) {
        $timerColor = if ($timer.CurrentMs -le 1.0) { "Green" } else { "Yellow" }
        Write-Host "  Таймер Windows: " -NoNewline -ForegroundColor DarkGray
        Write-Host "$($timer.CurrentMs) ms " -NoNewline -ForegroundColor $timerColor
        Write-Host "(Min: $($timer.MinMs) ms, Max: $($timer.MaxMs) ms)" -ForegroundColor DarkGray
    }

    # Live DPC & Interrupt Metrics
    $dpc = Get-SystemDpcMetrics
    if ($dpc.Success) {
        $dpcColor = if ($dpc.DpcPercent -lt 1.0) { "Green" } else { "Yellow" }
        Write-Host "  DPC/ISR задержка:" -NoNewline -ForegroundColor DarkGray
        Write-Host " % DPC Time: $($dpc.DpcPercent)% | Interrupts: $($dpc.IsrPercent)% | DPCs/сек: $($dpc.DpcsPerSec)" -ForegroundColor $dpcColor
    }

    Write-Host "`n----------------------------------------------------------------" -ForegroundColor DarkGray
    Write-Host "                    СТАТУС ВСЕХ ОПТИМИЗАЦИЙ                     " -ForegroundColor Cyan
    Write-Host "----------------------------------------------------------------" -ForegroundColor DarkGray

    $audit = Get-SystemOptimizationAudit
    $optimalCount = 0

    foreach ($item in $audit) {
        $badge = if ($item.Optimal) { "[✓]" } else { "[!]" }
        $color = if ($item.Optimal) { "Green" } else { "Yellow" }
        if ($item.Optimal) { $optimalCount++ }

        Write-Host " $badge $($item.Setting.PadRight(42)) " -NoNewline -ForegroundColor $color
        Write-Host "$($item.Status)" -ForegroundColor White
    }

    $totalCount = $audit.Count
    $score = [Math]::Round(($optimalCount / $totalCount) * 100, 0)
    Write-Host "`n----------------------------------------------------------------" -ForegroundColor DarkGray
    Write-Host " ИТОГОВЫЙ ИНДЕКС ОПТИМИЗАЦИИ: $score% ($optimalCount из $totalCount пунктов оптимизировано)" -ForegroundColor $(if ($score -ge 80) { "Green" } elseif ($score -ge 50) { "Yellow" } else { "Red" })

    # Сетевой тест
    Write-Host "`n[Сетевой Тест] Замер задержки и джиттера к DNS-серверам..." -ForegroundColor Cyan
    $pings = Test-NetworkPingLatency -Targets @("1.1.1.1", "8.8.8.8") -Count 3
    foreach ($p in $pings) {
        Write-Host "  -> $($p.Target): Средний пинг = $($p.AvgPingMs) ms | Джиттер = $($p.JitterMs) ms | Потери = $($p.LossPercent)%" -ForegroundColor $(if ($p.AvgPingMs -lt 30) { "Green" } else { "Yellow" })
    }

    Write-Host "`n[S] Сохранить полный отчет в текстовый файл" -ForegroundColor White
    Write-Host "[Enter] Вернуться в главное меню" -ForegroundColor Gray
    $action = ""
    try {
        if (-not [Console]::IsInputRedirected) {
            $action = Read-Host "Действие"
        }
    } catch {}
    if ($action -ieq "S") {
        $timestamp = (Get-Date).ToString("yyyyMMdd_HHmmss")
        $reportPath = Join-Path -Path $Script:ReportDir -ChildPath "SystemAudit_$timestamp.txt"
        
        $sb = [System.Text.StringBuilder]::new()
        [void]$sb.AppendLine("=== WIN11 OPTIMIZER SYSTEM AUDIT REPORT ===")
        [void]$sb.AppendLine("Date: $(Get-Date)")
        [void]$sb.AppendLine("OS: $($os.Caption) ($($os.Version))")
        [void]$sb.AppendLine("CPU: $($cpu.Name)")
        [void]$sb.AppendLine("GPU: $($gpu.Name)")
        [void]$sb.AppendLine("Power Plan: $powerPlan")
        [void]$sb.AppendLine("Timer: Current=$($timer.CurrentMs)ms Min=$($timer.MinMs)ms Max=$($timer.MaxMs)ms")
        if ($dpc.Success) {
            [void]$sb.AppendLine("DPC/ISR: DpcTime=$($dpc.DpcPercent)% InterruptTime=$($dpc.IsrPercent)% DpcsQueuedSec=$($dpc.DpcsPerSec)")
        }
        [void]$sb.AppendLine("Score: $score% ($optimalCount / $totalCount)")
        [void]$sb.AppendLine("`n--- OPTIMIZATION CHECKLIST ---")
        foreach ($item in $audit) {
            [void]$sb.AppendLine("$($item.Setting): $($item.Status) [$($item.Details)]")
        }
        [void]$sb.AppendLine("`n--- NETWORK LATENCY ---")
        foreach ($p in $pings) {
            [void]$sb.AppendLine("$($p.Target): Avg=$($p.AvgPingMs)ms Min=$($p.MinPingMs)ms Max=$($p.MaxPingMs)ms Jitter=$($p.JitterMs)ms Loss=$($p.LossPercent)%")
        }

        [System.IO.File]::WriteAllText($reportPath, $sb.ToString(), [System.Text.Encoding]::UTF8)
        Write-Host "[OK] Отчет сохранен: $reportPath" -ForegroundColor Green
        Start-Sleep -Seconds 2
    }
}

Export-ModuleMember -Function Get-SystemTimerResolution, Get-SystemDpcMetrics, Test-NetworkPingLatency, `
                             Get-SystemOptimizationAudit, Show-DiagnosticsDashboard, Show-OptimizationHealthCheck
