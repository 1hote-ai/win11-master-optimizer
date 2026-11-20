# NetworkGaming.psm1 - Low-Latency Gaming Network Stack Tuning
# Encoding: UTF-8

Set-StrictMode -Version Latest

Import-Module (Join-Path -Path $PSScriptRoot -ChildPath "Safety.psm1") -ErrorAction SilentlyContinue

function Get-ActiveNetworkInterfaceGuids {
    $guids = [System.Collections.Generic.List[string]]::new()
    $seen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    
    # 1. Попытка через Get-NetAdapter
    try {
        $adapters = Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object { $_.InterfaceGuid }
        foreach ($a in $adapters) {
            if ($seen.Add($a.InterfaceGuid)) {
                $guids.Add($a.InterfaceGuid)
            }
        }
    } catch {}

    # 2. Также ищем через интерфейсы Tcpip в реестре
    $baseKey = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces"
    if (Test-Path $baseKey) {
        $subkeys = Get-ChildItem -Path $baseKey
        foreach ($k in $subkeys) {
            $guid = $k.PSChildName
            if ($guid -match '^\{?[A-F0-9\-]{36}\}?$' -and $seen.Add($guid)) {
                $guids.Add($guid)
            }
        }
    }

    return $guids
}

function Set-GamingNetworkStack {
    [CmdletBinding()]
    param(
        [switch]$DryRun = $false
    )

    Write-Host "`n[Network Optimizer] Оптимизация сетевого стека для снижения пинга и джиттера..." -ForegroundColor Cyan

    $interfaceGuids = Get-ActiveNetworkInterfaceGuids
    $baseKey = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces"

    if ($DryRun) {
        Write-Host "  [DRY-RUN] Будут отключены алгоритм Нейгла (TcpAckFrequency=1, TCPNoDelay=1, TcpDelAckTicks=0) для $($interfaceGuids.Count) интерфейсов." -ForegroundColor DarkGray
        Write-Host "  [DRY-RUN] Будет включен RSS (Receive Side Scaling) и отключены временные метки TCP." -ForegroundColor DarkGray
        return
    }

    # Подготовка бэкапа
    $backupTargets = @()
    foreach ($guid in $interfaceGuids) {
        $path = "$baseKey\$guid"
        $backupTargets += @{ Path = $path; Name = "TcpAckFrequency" }
        $backupTargets += @{ Path = $path; Name = "TCPNoDelay" }
        $backupTargets += @{ Path = $path; Name = "TcpDelAckTicks" }
    }
    $backupTargets += @{ Path = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"; Name = "NetworkThrottlingIndex" }

    Save-RegistrySnapshot -Category "NetworkStack" -RegistryTargets $backupTargets -DryRun:$DryRun | Out-Null

    $tunedInterfaces = 0
    foreach ($guid in $interfaceGuids) {
        $path = "$baseKey\$guid"
        if (Test-Path $path) {
            try {
                # Отключение алгоритма Нейгла и задержек подтверждений пакетов (Nagle's Algorithm)
                Set-ItemProperty -Path $path -Name "TcpAckFrequency" -Value 1 -Type DWord -Force
                Set-ItemProperty -Path $path -Name "TCPNoDelay" -Value 1 -Type DWord -Force
                Set-ItemProperty -Path $path -Name "TcpDelAckTicks" -Value 0 -Type DWord -Force
                $tunedInterfaces++
            } catch {
                Write-Verbose "Could not configure interface $guid : $_"
            }
        }
    }

    Write-Host "  [OK] Алгоритм Нейгла отключен для $tunedInterfaces интерфейсов (пакеты отправляются мгновенно)" -ForegroundColor Green

    # Настройка глобальных параметров TCP через netsh
    try {
        # Receive Side Scaling (RSS) распределяет обработку сетевых прерываний по нескольким ядрам
        netsh int tcp set global rss=enabled 2>&1 | Out-Null
        Write-Host "  [OK] RSS (Receive Side Scaling) включен" -ForegroundColor Green

        # AutoTuningLevel = normal
        netsh int tcp set global autotuninglevel=normal 2>&1 | Out-Null
        Write-Host "  [OK] TCP Window Auto-Tuning установлен в Normal" -ForegroundColor Green

        # Timestamps = disabled (уменьшает оверхед заголовков TCP)
        netsh int tcp set global timestamps=disabled 2>&1 | Out-Null
        Write-Host "  [OK] TCP Timestamps отключены для снижения размера заголовка" -ForegroundColor Green

        # ECN capability = disabled (предотвращает дропы на несовместимых игровых роутерах)
        netsh int tcp set global ecncapability=disabled 2>&1 | Out-Null
        Write-Host "  [OK] ECN Capability отключен (стабильность пинга)" -ForegroundColor Green

        # NetworkThrottlingIndex = 0xFFFFFFFF
        $sysProfile = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
        Set-ItemProperty -Path $sysProfile -Name "NetworkThrottlingIndex" -Value 0xFFFFFFFF -Type DWord -Force
        Write-Host "  [OK] NetworkThrottlingIndex = 0xFFFFFFFF (отключен лимит сетевой пропускной способности)" -ForegroundColor Green
    }
    catch {
        Write-Host "  [WARNING] Ошибка применения netsh команд: $($_.Exception.Message)" -ForegroundColor Yellow
    }

    # Отключение спящих режимов энергосбережения сетевой карты (Energy Efficient Ethernet, ULP, Power Down)
    try {
        $adapters = Get-NetAdapter -Physical -ErrorAction SilentlyContinue
        $targetKeywords = @(
            "EEELinkAdvertisement", "*EEE", "*EnergyEfficientEthernet", "*GreenEthernet",
            "AutoPowerSaveModeEnabled", "ReduceSpeedOnPowerDown", "ULPMode", "SelectiveSuspend", "SipsEnabled"
        )

        foreach ($adapter in $adapters) {
            $props = Get-NetAdapterAdvancedProperty -Name $adapter.Name -ErrorAction SilentlyContinue
            foreach ($p in $props) {
                $isTarget = ($p.RegistryKeyword -in $targetKeywords) -or 
                            ($p.DisplayName -like "*Energy Efficient*") -or 
                            ($p.DisplayName -like "*Зеленый Ethernet*") -or 
                            ($p.DisplayName -like "*Green Ethernet*") -or
                            ($p.DisplayName -like "*Ultra Low Power*")

                if ($isTarget) {
                    $setOk = $false
                    # 1. Попытка через числовой RegistryValue "0" (универсально для всех языков и драйверов Intel/Realtek)
                    try {
                        Set-NetAdapterAdvancedProperty -Name $adapter.Name -RegistryKeyword $p.RegistryKeyword -RegistryValue "0" -ErrorAction Stop
                        $setOk = $true
                    } catch {
                        # 2. Fallback на DisplayValue Off / Disabled
                        foreach ($valName in @("Off", "Disabled", "Откл", "Выкл")) {
                            try {
                                Set-NetAdapterAdvancedProperty -Name $adapter.Name -DisplayName $p.DisplayName -DisplayValue $valName -ErrorAction Stop
                                $setOk = $true
                                break
                            } catch {}
                        }
                    }

                    if ($setOk) {
                        Write-Host "  [OK] Отключен $($p.DisplayName) [$($p.RegistryKeyword)] на адаптере $($adapter.Name) (предотвращение микро-фризов)" -ForegroundColor Green
                    }
                }
            }
        }
    } catch {
        Write-Host "  [WARNING] Ошибка оптимизации расширенных параметров адаптера: $($_.Exception.Message)" -ForegroundColor Yellow
    }

    Write-Host "`n[Network Optimizer] Сетевой стек успешно оптимизирован для киберспортивных игр!" -ForegroundColor Green
}

function Restore-GamingNetworkStack {
    [CmdletBinding()]
    param()

    Write-Host "[Network Optimizer] Откат настроек сети к дефолтным параметрам Windows..." -ForegroundColor Yellow
    
    $restored = Restore-RegistrySnapshot -Category "NetworkStack"

    if (-not $restored.Success) {
        $interfaceGuids = Get-ActiveNetworkInterfaceGuids
        $baseKey = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces"

        foreach ($guid in $interfaceGuids) {
            $path = "$baseKey\$guid"
            if (Test-Path $path) {
                Remove-ItemProperty -Path $path -Name "TcpAckFrequency" -ErrorAction SilentlyContinue
                Remove-ItemProperty -Path $path -Name "TCPNoDelay" -ErrorAction SilentlyContinue
                Remove-ItemProperty -Path $path -Name "TcpDelAckTicks" -ErrorAction SilentlyContinue
            }
        }
    }

    # Сброс параметров TCP
    netsh int tcp set global rss=default 2>&1 | Out-Null
    netsh int tcp set global autotuninglevel=normal 2>&1 | Out-Null
    netsh int tcp set global timestamps=default 2>&1 | Out-Null
    netsh int tcp set global ecncapability=default 2>&1 | Out-Null

    $sysProfile = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
    Set-ItemProperty -Path $sysProfile -Name "NetworkThrottlingIndex" -Value 10 -Type DWord -Force -ErrorAction SilentlyContinue

    # Откат DNS, если был сохранен снимок
    Restore-GamingDns | Out-Null

    Write-Host "[Network Optimizer] Сетевой стек восстановлен до исходных параметров Windows." -ForegroundColor Green
}

function Get-NetworkPowerSavingStatus {
    $results = @()
    try {
        $adapters = Get-NetAdapter -Physical -ErrorAction SilentlyContinue
        foreach ($adapter in $adapters) {
            $props = Get-NetAdapterAdvancedProperty -Name $adapter.Name -ErrorAction SilentlyContinue
            $eee = $props | Where-Object { $_.RegistryKeyword -in @("EEELinkAdvertisement", "*EEE", "*EnergyEfficientEthernet") } | Select-Object -First 1
            $ulp = $props | Where-Object { $_.RegistryKeyword -eq "ULPMode" } | Select-Object -First 1
            $results += [PSCustomObject]@{
                AdapterName = $adapter.Name
                EeeValue    = if ($eee) { $eee.DisplayValue } else { "N/A" }
                EeeOptimal  = if ($eee) { $eee.RegistryValue -eq "0" -or $eee.DisplayValue -in @("Off", "Disabled") } else { $true }
                UlpValue    = if ($ulp) { $ulp.DisplayValue } else { "N/A" }
                UlpOptimal  = if ($ulp) { $ulp.RegistryValue -eq "0" -or $ulp.DisplayValue -in @("Off", "Disabled") } else { $true }
            }
        }
    } catch {}
    return $results
}

function Get-PrimaryActiveNetworkInterface {
    [CmdletBinding()]
    param()

    try {
        $route = Get-NetRoute -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue |
                 Where-Object { $_.NextHop -and $_.NextHop -ne '0.0.0.0' } |
                 Sort-Object RouteMetric |
                 Select-Object -First 1

        if ($route) {
            $adapter = Get-NetAdapter -InterfaceIndex $route.InterfaceIndex -ErrorAction SilentlyContinue
            $ipConfig = Get-NetIPConfiguration -InterfaceIndex $route.InterfaceIndex -ErrorAction SilentlyContinue
            $currentDns = @()
            if ($ipConfig -and $ipConfig.DNSServer) {
                $currentDns = @($ipConfig.DNSServer.ServerAddresses)
            }
            return [PSCustomObject]@{
                InterfaceIndex = [int]$route.InterfaceIndex
                InterfaceAlias = [string]$route.InterfaceAlias
                InterfaceName  = if ($adapter) { [string]$adapter.Name } else { [string]$route.InterfaceAlias }
                Gateway        = [string]$route.NextHop
                CurrentDns     = $currentDns
                InterfaceGuid  = if ($adapter) { [string]$adapter.InterfaceGuid } else { "" }
            }
        }

        # Fallback: поиск активного подключенного адаптера со статусом 'Up'
        $fallbackAdapter = Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq 'Up' } | Select-Object -First 1
        if ($fallbackAdapter) {
            $ipConfig = Get-NetIPConfiguration -InterfaceIndex $fallbackAdapter.InterfaceIndex -ErrorAction SilentlyContinue
            $currentDns = @()
            $gw = ""
            if ($ipConfig) {
                if ($ipConfig.DNSServer) { $currentDns = @($ipConfig.DNSServer.ServerAddresses) }
                if ($ipConfig.IPv4DefaultGateway) { $gw = [string]$ipConfig.IPv4DefaultGateway.NextHop }
            }
            return [PSCustomObject]@{
                InterfaceIndex = [int]$fallbackAdapter.InterfaceIndex
                InterfaceAlias = [string]$fallbackAdapter.Name
                InterfaceName  = [string]$fallbackAdapter.Name
                Gateway        = $gw
                CurrentDns     = $currentDns
                InterfaceGuid  = [string]$fallbackAdapter.InterfaceGuid
            }
        }
    } catch {
        Write-Verbose "Error detecting primary network interface: $_"
    }

    return $null
}

function Test-GamingDnsBenchmark {
    [CmdletBinding()]
    param(
        [int]$InterfaceIndex = 0,
        [int]$QuerySamples = 2
    )

    Write-Host "`n[DNS Benchmark] Запуск замера задержки и DoH-шифрования игровых DNS..." -ForegroundColor Cyan

    $activeIf = if ($InterfaceIndex -gt 0) {
        $ad = Get-NetAdapter -InterfaceIndex $InterfaceIndex -ErrorAction SilentlyContinue
        $cfg = Get-NetIPConfiguration -InterfaceIndex $InterfaceIndex -ErrorAction SilentlyContinue
        [PSCustomObject]@{
            InterfaceIndex = $InterfaceIndex
            InterfaceAlias = if ($ad) { $ad.Name } else { "Interface #$InterfaceIndex" }
            CurrentDns = if ($cfg -and $cfg.DNSServer) { @($cfg.DNSServer.ServerAddresses) } else { @() }
        }
    } else {
        Get-PrimaryActiveNetworkInterface
    }

    $currentDnsIp = if ($activeIf -and $activeIf.CurrentDns.Count -gt 0) { $activeIf.CurrentDns[0] } else { $null }

    $providers = [System.Collections.Generic.List[PSCustomObject]]::new()

    $providers.Add([PSCustomObject]@{
        Name        = "Cloudflare (1.1.1.1)"
        Primary     = "1.1.1.1"
        Secondary   = "1.0.0.1"
        DohTemplate = "https://cloudflare-dns.com/dns-query"
        Type        = "Ultra-Fast Anycast / Gaming"
    })
    $providers.Add([PSCustomObject]@{
        Name        = "Quad9 (9.9.9.9)"
        Primary     = "9.9.9.9"
        Secondary   = "149.112.112.112"
        DohTemplate = "https://dns.quad9.net/dns-query"
        Type        = "Security & Privacy / Anycast"
    })
    $providers.Add([PSCustomObject]@{
        Name        = "AdGuard (94.140.14.14)"
        Primary     = "94.140.14.14"
        Secondary   = "94.140.15.15"
        DohTemplate = "https://dns.adguard-dns.com/dns-query"
        Type        = "AdBlock & Anti-Tracking"
    })
    $providers.Add([PSCustomObject]@{
        Name        = "Google (8.8.8.8)"
        Primary     = "8.8.8.8"
        Secondary   = "8.8.4.4"
        DohTemplate = "https://dns.google/dns-query"
        Type        = "Global Anycast / Stable"
    })

    if ($currentDnsIp -and -not ($providers | Where-Object { $_.Primary -eq $currentDnsIp })) {
        $providers.Add([PSCustomObject]@{
            Name        = "Текущий DNS ($currentDnsIp)"
            Primary     = $currentDnsIp
            Secondary   = if ($activeIf.CurrentDns.Count -gt 1) { $activeIf.CurrentDns[1] } else { "" }
            DohTemplate = ""
            Type        = "Текущий / Провайдер / Роутер"
        })
    }

    $testDomains = @("google.com", "cloudflare.com")
    $benchmarkResults = [System.Collections.Generic.List[PSCustomObject]]::new()

    foreach ($p in $providers) {
        Write-Host -NoNewline "  Тестирование $($p.Name)... " -ForegroundColor White

        # 1. ICMP Ping
        $pingMs = -1.0
        try {
            $pings = Test-Connection -ComputerName $p.Primary -Count 2 -ErrorAction SilentlyContinue
            if ($pings) {
                $pingMs = [math]::Round(($pings | Measure-Object -Property ResponseTime -Average).Average, 1)
            }
        } catch {}

        # 2. DNS Query Resolution Latency
        $queryTimes = @()
        foreach ($domain in $testDomains) {
            for ($k = 0; $k -lt $QuerySamples; $k++) {
                try {
                    $sw = [System.Diagnostics.Stopwatch]::StartNew()
                    $resolved = Resolve-DnsName -Name $domain -Server $p.Primary -Type A -QuickTimeout -ErrorAction Stop
                    $sw.Stop()
                    if ($resolved) {
                        $queryTimes += $sw.Elapsed.TotalMilliseconds
                    }
                } catch {}
            }
        }

        $avgQueryMs = if ($queryTimes.Count -gt 0) {
            [math]::Round(($queryTimes | Measure-Object -Average).Average, 1)
        } else {
            -1.0
        }

        $dohSupported = -not [string]::IsNullOrWhiteSpace($p.DohTemplate)
        $score = if ($avgQueryMs -gt 0) { $avgQueryMs } elseif ($pingMs -gt 0) { $pingMs * 1.5 } else { 9999 }

        $statusColor = if ($score -lt 30) { "Green" } elseif ($score -lt 70) { "Yellow" } else { "DarkGray" }
        Write-Host "[DNS: $($avgQueryMs)ms | Ping: $($pingMs)ms | DoH: $($dohSupported)]" -ForegroundColor $statusColor

        $benchmarkResults.Add([PSCustomObject]@{
            Provider      = $p.Name
            Primary       = $p.Primary
            Secondary     = $p.Secondary
            DohTemplate   = $p.DohTemplate
            Type          = $p.Type
            QueryMs       = $avgQueryMs
            PingMs        = $pingMs
            DoHSupported  = $dohSupported
            Score         = $score
        })
    }

    $sorted = $benchmarkResults | Sort-Object Score
    return $sorted
}

function Set-GamingDns {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [ValidateSet("Cloudflare", "Quad9", "AdGuard", "Google")]
        [string]$Provider = "Cloudflare",
        [Parameter(Mandatory = $false)]
        [int]$InterfaceIndex = 0,
        [switch]$EnableDoh = $true,
        [switch]$DryRun = $false
    )

    $activeIf = if ($InterfaceIndex -gt 0) {
        $ad = Get-NetAdapter -InterfaceIndex $InterfaceIndex -ErrorAction SilentlyContinue
        [PSCustomObject]@{
            InterfaceIndex = $InterfaceIndex
            InterfaceAlias = if ($ad) { $ad.Name } else { "Interface #$InterfaceIndex" }
            InterfaceGuid  = if ($ad) { $ad.InterfaceGuid } else { "" }
        }
    } else {
        Get-PrimaryActiveNetworkInterface
    }

    if (-not $activeIf) {
        Write-Host "  [ERROR] Не удалось определить активный сетевой адаптер." -ForegroundColor Red
        return $false
    }

    $dnsConfig = switch ($Provider) {
        "Cloudflare" {
            @{
                Name        = "Cloudflare DNS"
                Primary     = "1.1.1.1"
                Secondary   = "1.0.0.1"
                DohTemplate = "https://cloudflare-dns.com/dns-query"
            }
        }
        "Quad9" {
            @{
                Name        = "Quad9 DNS"
                Primary     = "9.9.9.9"
                Secondary   = "149.112.112.112"
                DohTemplate = "https://dns.quad9.net/dns-query"
            }
        }
        "AdGuard" {
            @{
                Name        = "AdGuard DNS (AdBlock)"
                Primary     = "94.140.14.14"
                Secondary   = "94.140.15.15"
                DohTemplate = "https://dns.adguard-dns.com/dns-query"
            }
        }
        "Google" {
            @{
                Name        = "Google Public DNS"
                Primary     = "8.8.8.8"
                Secondary   = "8.8.4.4"
                DohTemplate = "https://dns.google/dns-query"
            }
        }
    }

    Write-Host "`n[DNS Switcher] Установка $($dnsConfig.Name) на адаптер '$($activeIf.InterfaceAlias)'..." -ForegroundColor Cyan

    if ($DryRun) {
        Write-Host "  [DRY-RUN] Будет применен DNS: $($dnsConfig.Primary), $($dnsConfig.Secondary) (DoH: $EnableDoh)" -ForegroundColor DarkGray
        return $true
    }

    # Снимок настроек DNS в реестре
    if (-not [string]::IsNullOrWhiteSpace($activeIf.InterfaceGuid)) {
        $path = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces\$($activeIf.InterfaceGuid)"
        $targets = @(
            @{ Path = $path; Name = "NameServer" },
            @{ Path = $path; Name = "DhcpNameServer" }
        )
        Save-RegistrySnapshot -Category "DnsSettings" -RegistryTargets $targets -DryRun:$DryRun | Out-Null
    }

    try {
        # 1. Регистрация DoH шаблона в Windows 11
        if ($EnableDoh -and (Get-Command Set-DnsClientDohServerAddress -ErrorAction SilentlyContinue)) {
            $servers = @($dnsConfig.Primary, $dnsConfig.Secondary)
            foreach ($srv in $servers) {
                try {
                    $existingDoh = Get-DnsClientDohServerAddress -ServerAddress $srv -ErrorAction SilentlyContinue
                    if (-not $existingDoh) {
                        Add-DnsClientDohServerAddress -ServerAddress $srv -DohTemplate $dnsConfig.DohTemplate -AllowFallbackToUdp $true -AutoUpgrade $true -ErrorAction SilentlyContinue | Out-Null
                    } else {
                        Set-DnsClientDohServerAddress -ServerAddress $srv -AutoUpgrade $true -AllowFallbackToUdp $true -ErrorAction SilentlyContinue | Out-Null
                    }
                } catch {
                    Write-Verbose "DoH registration notice for ${srv}: $_"
                }
            }
            Write-Host "  [OK] DoH (DNS-over-HTTPS) шифрование сконфигурировано в Windows 11" -ForegroundColor Green
        }

        # 2. Назначение адресов DNS серверу интерфейса
        Set-DnsClientServerAddress -InterfaceIndex $activeIf.InterfaceIndex -ServerAddresses @($dnsConfig.Primary, $dnsConfig.Secondary) -ErrorAction Stop
        Write-Host "  [OK] DNS успешно назначен: $($dnsConfig.Primary), $($dnsConfig.Secondary)" -ForegroundColor Green

        # 3. Очистка локального кэша DNS
        Clear-DnsClientCache
        Write-Host "  [OK] Системный DNS кэш очищен (Clear-DnsClientCache)" -ForegroundColor Green
        return $true
    } catch {
        Write-Host "  [ERROR] Ошибка назначения DNS: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Reset-GamingDns {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [int]$InterfaceIndex = 0,
        [switch]$DryRun = $false
    )

    $activeIf = if ($InterfaceIndex -gt 0) {
        $ad = Get-NetAdapter -InterfaceIndex $InterfaceIndex -ErrorAction SilentlyContinue
        [PSCustomObject]@{
            InterfaceIndex = $InterfaceIndex
            InterfaceAlias = if ($ad) { $ad.Name } else { "Interface #$InterfaceIndex" }
        }
    } else {
        Get-PrimaryActiveNetworkInterface
    }

    if (-not $activeIf) {
        Write-Host "  [ERROR] Не удалось определить активный сетевой адаптер." -ForegroundColor Red
        return $false
    }

    Write-Host "`n[DNS Switcher] Сброс DNS адаптера '$($activeIf.InterfaceAlias)' на автоматический (DHCP)..." -ForegroundColor Cyan

    if ($DryRun) {
        Write-Host "  [DRY-RUN] Будет вызван Set-DnsClientServerAddress -ResetServerAddresses для интерфейса $($activeIf.InterfaceIndex)" -ForegroundColor DarkGray
        return $true
    }

    try {
        Set-DnsClientServerAddress -InterfaceIndex $activeIf.InterfaceIndex -ResetServerAddresses -ErrorAction Stop
        Clear-DnsClientCache
        Write-Host "  [OK] DNS сброшен к автоматическому получению по DHCP (дефолт роутера / провайдера)" -ForegroundColor Green
        return $true
    } catch {
        Write-Host "  [ERROR] Ошибка сброса DNS: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Show-DnsBenchmarkAndSwitcherMenu {
    [CmdletBinding()]
    param()

    while ($true) {
        Clear-Host
        $activeIf = Get-PrimaryActiveNetworkInterface
        $currentDnsStr = if ($activeIf -and $activeIf.CurrentDns) { ($activeIf.CurrentDns -join ", ") } else { "Авто (DHCP)" }
        $ifName = if ($activeIf) { "$($activeIf.InterfaceAlias) [Шлюз: $($activeIf.Gateway)]" } else { "Не определен" }

        Write-Host "==========================================================================" -ForegroundColor Cyan
        Write-Host "          GAMING DNS BENCHMARK & DoH ENCRYPTED SWITCHER (WIN 11)          " -ForegroundColor White
        Write-Host "==========================================================================" -ForegroundColor Cyan
        Write-Host "  Активный адаптер: $ifName" -ForegroundColor White
        Write-Host "  Текущий DNS:      $currentDnsStr" -ForegroundColor Yellow
        Write-Host "--------------------------------------------------------------------------" -ForegroundColor DarkGray
        Write-Host "  [1]  ⚡  Запустить LIVE DNS Бенчмарк (сравнение пинга и скорости запросов)" -ForegroundColor Cyan
        Write-Host "  [2]  🚀  Переключить на Cloudflare (1.1.1.1 + DoH) [Ультра-низкий пинг]" -ForegroundColor Green
        Write-Host "  [3]  🛡  Переключить на Quad9 (9.9.9.9 + DoH) [Максимальная безопасность]" -ForegroundColor White
        Write-Host "  [4]  🛑  Переключить на AdGuard (94.140.14.14 + DoH) [Блокировка рекламы]" -ForegroundColor White
        Write-Host "  [5]  🌐  Переключить на Google Public DNS (8.8.8.8 + DoH) [Стабильность]" -ForegroundColor White
        Write-Host "  [6]  🔄  Сбросить DNS на АВТОМАТИЧЕСКИЙ (DHCP роутера)" -ForegroundColor Yellow
        Write-Host "  [7]  ↩️   Откатить DNS из резервной копии (Restore Snapshot)" -ForegroundColor Yellow
        Write-Host "  [0]  ↩️   Назад в сетевое меню" -ForegroundColor Gray
        Write-Host ""
        $choice = Read-Host "Шеф, выберите действие"

        switch ($choice) {
            "1" {
                $results = Test-GamingDnsBenchmark
                Write-Host "`n--- РЕЗУЛЬТАТЫ БЕНЧМАРКА (ОТ САМОГО БЫСТРОГО К МЕДЛЕННОМУ) ---" -ForegroundColor Green
                $rank = 1
                foreach ($r in $results) {
                    $isTop = if ($rank -eq 1) { " [ТОП 1 ДЛЯ ВАС]" } else { "" }
                    $c = if ($rank -eq 1) { "Green" } elseif ($r.Score -lt 50) { "White" } else { "Gray" }
                    Write-Host "  #$rank $($r.Provider)$isTop" -ForegroundColor $c
                    Write-Host "      Запрос DNS: $($r.QueryMs) ms | Ping: $($r.PingMs) ms | DoH: $($r.DoHSupported) | $($r.Type)" -ForegroundColor DarkGray
                    $rank++
                }
                Write-Host "`nНажмите Enter для продолжения..."; Read-Host | Out-Null
            }
            "2" { Set-GamingDns -Provider "Cloudflare"; Write-Host "`nНажмите Enter..."; Read-Host | Out-Null }
            "3" { Set-GamingDns -Provider "Quad9"; Write-Host "`nНажмите Enter..."; Read-Host | Out-Null }
            "4" { Set-GamingDns -Provider "AdGuard"; Write-Host "`nНажмите Enter..."; Read-Host | Out-Null }
            "5" { Set-GamingDns -Provider "Google"; Write-Host "`nНажмите Enter..."; Read-Host | Out-Null }
            "6" { Reset-GamingDns; Write-Host "`nНажмите Enter..."; Read-Host | Out-Null }
            "7" { Restore-GamingDns; Write-Host "`nНажмите Enter..."; Read-Host | Out-Null }
            "0" { break }
        }
    }
}

function Restore-GamingDns {
    [CmdletBinding()]
    param()

    Write-Host "[DNS Switcher] Откат настроек DNS к исходному состоянию..." -ForegroundColor Yellow
    $restored = Restore-RegistrySnapshot -Category "DnsSettings"
    if ($restored.Success) {
        Clear-DnsClientCache
        Write-Host "  [OK] Настройки DNS успешно восстановлены из снимка реестра." -ForegroundColor Green
        return $true
    } else {
        return (Reset-GamingDns)
    }
}

function Get-NagleStatus {
    [CmdletBinding()]
    param()

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
    return [PSCustomObject]@{
        Disabled    = $hasNagleDisabled
        Optimal     = $hasNagleDisabled
        Description = if ($hasNagleDisabled) { "Отключен (TcpAckFrequency=1, TCPNoDelay=1)" } else { "Включен (Пакеты буферизуются)" }
    }
}

function Get-NetworkGamingStackStatus {
    [CmdletBinding()]
    param()

    $sysProfile = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" -ErrorAction SilentlyContinue
    $isThrottlingOff = ($sysProfile -and $sysProfile.PSObject.Properties['NetworkThrottlingIndex'] -and $sysProfile.NetworkThrottlingIndex -eq 0xFFFFFFFF)
    return [PSCustomObject]@{
        Optimal     = [bool]$isThrottlingOff
        Description = if ($isThrottlingOff) { "NetworkThrottlingIndex=0xFFFFFFFF (Троттлинг снят)" } else { "Стандартный сетевой троттлинг" }
    }
}

function Get-GamingDnsStatus {
    [CmdletBinding()]
    param()

    $activeNet = Get-PrimaryActiveNetworkInterface
    $curDnsList = if ($activeNet -and $activeNet.CurrentDns) { @($activeNet.CurrentDns) } else { @() }
    $fastDnsServers = @("1.1.1.1", "1.0.0.1", "9.9.9.9", "149.112.112.112", "94.140.14.14", "94.140.15.15", "8.8.8.8", "8.8.4.4")
    $isFastDns = (@($curDnsList).Count -gt 0 -and @($curDnsList | Where-Object { $_ -in $fastDnsServers }).Count -gt 0)
    $dnsProviderLabel = if ($isFastDns) {
        if ($curDnsList -contains "1.1.1.1" -or $curDnsList -contains "1.0.0.1") { "Cloudflare (1.1.1.1)" }
        elseif ($curDnsList -contains "9.9.9.9" -or $curDnsList -contains "149.112.112.112") { "Quad9 (9.9.9.9)" }
        elseif ($curDnsList -contains "94.140.14.14" -or $curDnsList -contains "94.140.15.15") { "AdGuard" }
        else { "Google (8.8.8.8)" }
    } else {
        if (@($curDnsList).Count -gt 0) { "Провайдер ($($curDnsList -join ', '))" } else { "Авто (DHCP)" }
    }
    return [PSCustomObject]@{
        Optimal       = $isFastDns
        ProviderLabel = $dnsProviderLabel
        Description   = if ($isFastDns) { "Оптимизирован ($dnsProviderLabel)" } else { "Стандартный ($dnsProviderLabel)" }
    }
}

Export-ModuleMember -Function Get-ActiveNetworkInterfaceGuids, Set-GamingNetworkStack, Restore-GamingNetworkStack, `
                             Get-NetworkPowerSavingStatus, Get-PrimaryActiveNetworkInterface, `
                             Test-GamingDnsBenchmark, Set-GamingDns, Reset-GamingDns, Restore-GamingDns, Show-DnsBenchmarkAndSwitcherMenu, `
                             Get-NagleStatus, Get-NetworkGamingStackStatus, Get-GamingDnsStatus
