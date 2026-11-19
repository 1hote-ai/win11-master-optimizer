# AppInstaller.psm1 - Modern Winget-based Silent Package Installer
# Encoding: UTF-8

Set-StrictMode -Version Latest

$Script:AppCatalog = @(
    # Essential Utilities
    [PSCustomObject]@{ Category = "Системные Утилиты"; Name = "7-Zip (Архиватор)"; Id = "7zip.7zip"; Description = "Самый быстрый и легкий архиватор" },
    [PSCustomObject]@{ Category = "Системные Утилиты"; Name = "Everything"; Id = "voidtools.Everything"; Description = "Мгновенный поиск файлов по NTFS индексу" },
    [PSCustomObject]@{ Category = "Системные Утилиты"; Name = "Notepad++"; Id = "Notepad++.Notepad++"; Description = "Продвинутый текстовый и кодовый редактор" },
    [PSCustomObject]@{ Category = "Системные Утилиты"; Name = "Revo Uninstaller"; Id = "RevoUninstaller.RevoUninstaller"; Description = "Чистое удаление софта с очисткой хвостов в реестре" },
    [PSCustomObject]@{ Category = "Системные Утилиты"; Name = "Nilesoft Shell"; Id = "Nilesoft.Shell"; Description = "Кастомизация современного контекстного меню Windows 11" },
    [PSCustomObject]@{ Category = "Системные Утилиты"; Name = "Auto Dark Mode"; Id = "ArminOsaj.AutoDarkMode"; Description = "Авто-переключение светлой/темной темы по расписанию" },

    # Gaming & Monitoring
    [PSCustomObject]@{ Category = "Гейминг и Задержка"; Name = "CapFrameX"; Id = "CXWorld.CapFrameX"; Description = "Захват FPS, 0.1% low, оверлей и анализ системной задержки" },
    [PSCustomObject]@{ Category = "Гейминг и Задержка"; Name = "HWiNFO64"; Id = "REALiX.HWiNFO"; Description = "Детальный мониторинг температур, напряжений и сенсоров" },
    [PSCustomObject]@{ Category = "Гейминг и Задержка"; Name = "Process Lasso"; Id = "BitSum.ProcessLasso"; Description = "Управление приоритетами CPU, ProBalance и Core Affinity" },
    [PSCustomObject]@{ Category = "Гейминг и Задержка"; Name = "FanControl"; Id = "Rem0o.FanControl"; Description = "Полный контроль кривых вентиляторов корпуса и кулера" },
    [PSCustomObject]@{ Category = "Гейминг и Задержка"; Name = "LatencyMon"; Id = "Resplendence.LatencyMon"; Description = "Анализ DPC/ISR задержек драйверов в реальном времени" },

    # Game Launchers
    [PSCustomObject]@{ Category = "Игровые Лаунчеры"; Name = "Steam"; Id = "Valve.Steam"; Description = "Основная игровая платформа Valve" },
    [PSCustomObject]@{ Category = "Игровые Лаунчеры"; Name = "Epic Games Launcher"; Id = "EpicGames.EpicGamesLauncher"; Description = "Лаунчер Epic Games Store" },
    [PSCustomObject]@{ Category = "Игровые Лаунчеры"; Name = "EA App"; Id = "ElectronicArts.EADesktop"; Description = "Клиент Electronic Arts" },
    [PSCustomObject]@{ Category = "Игровые Лаунчеры"; Name = "Battle.net"; Id = "Blizzard.BattleNet"; Description = "Лаунчер игр Blizzard" },
    [PSCustomObject]@{ Category = "Игровые Лаунчеры"; Name = "GOG Galaxy"; Id = "GOG.Galaxy"; Description = "Клиент без DRM от CD Projekt" },

    # Communication & Media
    [PSCustomObject]@{ Category = "Связь и Медиа"; Name = "Discord"; Id = "Discord.Discord"; Description = "Голосовой и текстовый чат для геймеров" },
    [PSCustomObject]@{ Category = "Связь и Медиа"; Name = "Telegram Desktop"; Id = "Telegram.TelegramDesktop"; Description = "Быстрый защищенный мессенджер" },
    [PSCustomObject]@{ Category = "Связь и Медиа"; Name = "OBS Studio"; Id = "OBSProject.OBSStudio"; Description = "Запись экрана и стриминг без потери качества" },
    [PSCustomObject]@{ Category = "Связь и Медиа"; Name = "VLC Media Player"; Id = "VideoLAN.VLC"; Description = "Универсальный медиаплеер всех аудио/видео форматов" },
    [PSCustomObject]@{ Category = "Связь и Медиа"; Name = "MPC-HC"; Id = "clsid2.mpc-hc"; Description = "Классический легковесный Media Player Classic" },

    # Browsers
    [PSCustomObject]@{ Category = "Браузеры"; Name = "Brave Browser"; Id = "Brave.Brave"; Description = "Быстрый браузер со встроенной блокировкой рекламы и трекеров" },
    [PSCustomObject]@{ Category = "Браузеры"; Name = "Google Chrome"; Id = "Google.Chrome"; Description = "Официальный веб-браузер Google" },
    [PSCustomObject]@{ Category = "Браузеры"; Name = "Mozilla Firefox"; Id = "Mozilla.Firefox"; Description = "Приватный браузер на движке Gecko" },

    # Runtimes
    [PSCustomObject]@{ Category = "Библиотеки и Runtimes"; Name = "Visual C++ 2015-2022 (x64)"; Id = "Microsoft.VCRedist.2015+.x64"; Description = "Необходимые библиотеки для запуска всех современных игр" },
    [PSCustomObject]@{ Category = "Библиотеки и Runtimes"; Name = "DirectX End-User Runtime"; Id = "Microsoft.DirectX"; Description = "Набор устаревших компонентов DirectX для совместимости со старыми играми" }
)

function Test-WingetAvailability {
    try {
        $ver = & winget --version 2>&1
        if ($LASTEXITCODE -eq 0 -and $ver) {
            return @{ Available = $true; Version = $ver.Trim() }
        }
    } catch {}
    return @{ Available = $false; Version = $null }
}

function Get-AppCatalog {
    return $Script:AppCatalog
}

function Install-PackageSilent {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$PackageId,
        [Parameter(Mandatory = $false)]
        [string]$PackageName = "",
        [switch]$DryRun = $false
    )

    $displayName = if ($PackageName) { "$PackageName ($PackageId)" } else { $PackageId }
    Write-Host "  -> Установка пакета: $displayName..." -ForegroundColor Cyan

    if ($DryRun) {
        Write-Host "     [DRY-RUN] Команда: winget install --id $PackageId --silent --accept-package-agreements --accept-source-agreements" -ForegroundColor DarkGray
        return $true
    }

    try {
        $p = Start-Process -FilePath "winget" -ArgumentList "install --id $PackageId --silent --accept-package-agreements --accept-source-agreements" -NoNewWindow -Wait -PassThru
        if ($p.ExitCode -eq 0) {
            Write-Host "     [OK] Успешно установлено!" -ForegroundColor Green
            return $true
        } elseif ($p.ExitCode -eq -1978335189) { # Already installed
            Write-Host "     [OK] Пакет уже установлен в системе." -ForegroundColor Green
            return $true
        } else {
            Write-Host "     [WARNING] Winget вернул код завершения: $($p.ExitCode)" -ForegroundColor Yellow
            return $false
        }
    }
    catch {
        Write-Host "     [ERROR] Сбой запуска winget: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Install-GamingEssentialsPreset {
    [CmdletBinding()]
    param([switch]$DryRun = $false)

    $wingetStatus = Test-WingetAvailability
    if (-not $wingetStatus.Available) {
        Write-Host "[ERROR] Утилита winget не обнаружена. Установите Desktop App Installer из Microsoft Store." -ForegroundColor Red
        return
    }

    Write-Host "`n========================================================" -ForegroundColor Cyan
    Write-Host "   УСТАНОВКА НАБОРА GAMING ESSENTIALS (ТИХИЙ РЕЖИМ)" -ForegroundColor White
    Write-Host "========================================================" -ForegroundColor Cyan

    $essentialIds = @(
        "7zip.7zip",
        "voidtools.Everything",
        "Rem0o.FanControl",
        "CXWorld.CapFrameX",
        "REALiX.HWiNFO",
        "BitSum.ProcessLasso",
        "Microsoft.VCRedist.2015+.x64"
    )

    foreach ($id in $essentialIds) {
        $app = $Script:AppCatalog | Where-Object { $_.Id -eq $id } | Select-Object -First 1
        $name = if ($app) { $app.Name } else { $id }
        Install-PackageSilent -PackageId $id -PackageName $name -DryRun:$DryRun
    }

    Write-Host "`n[App Installer] Установка набора завершена!" -ForegroundColor Green
}

function Show-AppInstallerMenu {
    $wingetStatus = Test-WingetAvailability
    if (-not $wingetStatus.Available) {
        Write-Host "[ERROR] Winget не найден. Пакетная установка недоступна." -ForegroundColor Red
        Pause
        return
    }

    while ($true) {
        Clear-Host
        Write-Host "========================================================" -ForegroundColor Cyan
        Write-Host "         МЕНЕДЖЕР ПАКЕТОВ И ПРИЛОЖЕНИЙ (WINGET)        " -ForegroundColor White
        Write-Host "         Замена 170+ устаревших ссылок Max.mov          " -ForegroundColor Gray
        Write-Host "========================================================" -ForegroundColor Cyan
        Write-Host " Winget версия: $($wingetStatus.Version)" -ForegroundColor DarkGray
        Write-Host ""

        $currentCategory = ""
        for ($i = 0; $i -lt $Script:AppCatalog.Count; $i++) {
            $item = $Script:AppCatalog[$i]
            if ($item.Category -ne $currentCategory) {
                $currentCategory = $item.Category
                Write-Host "`n  --- $currentCategory ---" -ForegroundColor Yellow
            }
            $num = ($i + 1).ToString().PadLeft(2, ' ')
            Write-Host "  [$num] $($item.Name.PadRight(28)) - $($item.Description)" -ForegroundColor White
        }

        Write-Host "`n  --------------------------------------------------------" -ForegroundColor DarkGray
        Write-Host "  [G]  Установить весь игровой пакет (Gaming Essentials)" -ForegroundColor Green
        Write-Host "  [U]  Установить весь набор системных утилит" -ForegroundColor Green
        Write-Host "  [R]  Установить все игровые Runtimes (VC++ и DirectX)" -ForegroundColor Green
        Write-Host "  [0]  Вернуться в главное меню" -ForegroundColor Gray
        Write-Host ""
        $choice = Read-Host "Выберите номер приложения или действие"

        if ($choice -eq "0" -or [string]::IsNullOrWhiteSpace($choice)) {
            break
        }
        elseif ($choice -ieq "G") {
            Install-GamingEssentialsPreset
            Write-Host "`nНажмите Enter для продолжения..."; Read-Host | Out-Null
        }
        elseif ($choice -ieq "U") {
            $utilApps = $Script:AppCatalog | Where-Object { $_.Category -eq "Системные Утилиты" }
            foreach ($u in $utilApps) {
                Install-PackageSilent -PackageId $u.Id -PackageName $u.Name
            }
            Write-Host "`nНажмите Enter для продолжения..."; Read-Host | Out-Null
        }
        elseif ($choice -ieq "R") {
            $runtimeApps = $Script:AppCatalog | Where-Object { $_.Category -eq "Библиотеки и Runtimes" }
            foreach ($r in $runtimeApps) {
                Install-PackageSilent -PackageId $r.Id -PackageName $r.Name
            }
            Write-Host "`nНажмите Enter для продолжения..."; Read-Host | Out-Null
        }
        else {
            $index = 0
            if ([int]::TryParse($choice, [ref]$index) -and $index -ge 1 -and $index -le $Script:AppCatalog.Count) {
                $selected = $Script:AppCatalog[$index - 1]
                Install-PackageSilent -PackageId $selected.Id -PackageName $selected.Name
                Write-Host "`nНажмите Enter для продолжения..."; Read-Host | Out-Null
            }
        }
    }
}

Export-ModuleMember -Function Test-WingetAvailability, Get-AppCatalog, Install-PackageSilent, `
                             Install-GamingEssentialsPreset, Show-AppInstallerMenu
