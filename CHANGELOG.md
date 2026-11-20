# Changelog

All notable changes to **Windows 11 Master Optimizer** will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [v0.1.0-beta] - 2026-11-20

### Added
- **Core Architecture:**
  - Complete 8-module architecture separating safety, latency, network, GPU, debloat, UI, diagnostics, and app installations.
  - Interactive Text User Interface (TUI) with real-time status indicators (`[✓] Optimal` / `[ ] Action Required`).
  - Full Command-Line Interface (CLI) support with `-Mode` parameters (`AutoGaming`, `HealthCheck`, `RamClean`, `DnsBenchmark`, `GpuOnly`, `LowLatency`, `SafeDebloat`, `Rollback`).
  - Universal `-DryRun` switch for previewing all registry and command alterations without writing to disk or registry.
- **Safety & Rollback Engine (`Safety.psm1`):**
  - Granular `RollbackResult` structured object (`Success`, `RestoredCount`, `FailedCount`, `TotalCount`, `RestoredItems`, `FailedItems`, `Errors`, `TargetFile`, `Message`) replacing primitive booleans.
  - Strict per-parameter isolation: every registry parameter is restored independently; write verification confirms property existence; partial failures are explicitly logged and cause `Success = $false`.
  - Windows System Restore Point creation with pre-snapshot of `SystemRestorePointCreationFrequency` (eliminating permanent registry alteration; restored or removed via `Restore-SystemRestorePointCreationFrequency`).
  - Automated backup rotation (`Invoke-BackupRotation`) preserving the 50 most recent snapshots and pruning stale backups.
  - Granular JSON registry snapshot engine capturing key presence, value presence, original values, and exact .NET registry value kinds (`DWord`, `QWord`, `Binary`, `MultiString`, `ExpandString`, `String`).
  - Pruning of empty newly created subkeys upon snapshot rollback.
  - Official MIT License formalization (`LICENSE`) with copyright 2026 1hote-ai.
- **Gaming Latency & Memory (`GamingLatency.psm1`):**
  - Native in-memory NT-kernel Standby RAM Cleaner using `ntdll!NtSetSystemInformation(80, ref 4)` and `advapi32!AdjustTokenPrivileges` (`SeProfileSingleProcessPrivilege`).
  - Automated PCI device scanning and MSI Mode (Message Signaled Interrupts) migration for GPU, Network, and Audio devices with `DevicePriority = 3 (High)`.
  - CPU Scheduling quantum optimization (`Win32PrioritySeparation = 38 (0x26)`), Power Throttling disable, and Core Parking unpark (`CPMINCORES = 100`, `PERFEPP = 0`).
  - SystemResponsiveness set to 0 (100% CPU priority for gaming processes).
  - VBS / HVCI kernel isolation status detection and safe toggle.
- **GPU & Display Tuning (`GpuDisplay.psm1`):**
  - DWM Multi-Plane Overlay (MPO) toggle (`OverlayTestMode = 5`) to resolve borderless gaming and video streaming micro-stutters.
  - Hardware-Accelerated GPU Scheduling (HAGS) toggle (`HwSchMode = 2`).
  - DirectX borderless window optimization (`AutoPlayMode = 1;`).
  - Windows Update GPU driver replacement protection (`ExcludeWUDriversInQualityUpdate = 1`).
  - Dynamic NVIDIA HDCP DRM handshake killer (`RMHdcpKeyglobZero = 1`).
  - Multi-path shader cache and temporary file cleanup (NVIDIA DXCache/GLCache, Direct3D D3DSCache, AMD DxCache, Windows Temp).
- **Competitive Network Stack (`NetworkGaming.psm1`):**
  - Active network adapter enumeration and Nagle's algorithm disable (`TcpAckFrequency = 1`, `TCPNoDelay = 1`, `TcpDelAckTicks = 0`).
  - Receive Side Scaling (RSS) enablement, TCP Window Auto-Tuning normal, and timestamp header overhead elimination.
  - Live Anycast DNS Benchmark testing query latency and ICMP ping against Cloudflare, Quad9, Google, and AdGuard.
  - 1-Click DNS-over-HTTPS (DoH) switcher and instant DHCP reset.
  - Energy Efficient Ethernet (EEE) and Green Ethernet power-saving disable.
- **Debloat & 24H2 Compatibility (`Debloat.psm1`):**
  - Windows 11 24H2 AI Recall disable (`DisableAIDataAnalysis = 1` + DISM feature disable).
  - Microsoft Copilot policy removal and taskbar button hide.
  - Bing search and web suggestions removal from Start Menu.
  - Widgets and MSN News feed disable.
  - Telemetry service disable (`DiagTrack`, `dmwappushservice`).
  - Safe UWP bloatware removal with strict whitelist preserving Microsoft Store, Xbox, Calculator, Notepad, Paint, Snipping Tool, Terminal, and Windows Security.
- **System UI & Diagnostics (`SystemUI.psm1`, `Diagnostics.psm1`):**
  - Windows 10 classic context menu CLSID toggle (`{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}`).
  - File Explorer enhancements (show extensions, compact mode, open This PC, disable Search Highlights).
  - USB Selective Suspend disable for gaming mice (1000–8000 Hz).
  - Windows Automatic Maintenance disable during gaming sessions.
  - 26-point System Health Audit engine with optimization percentage calculation and fix recommendations.
  - Native Win32 timer resolution measurement (`NtQueryTimerResolution`).
  - Real-time DPC / ISR counter metrics sampling.
- **App Installer (`AppInstaller.psm1`):**
  - Silent Winget package installer with 25 curated tools across utilities, gaming latency, launchers, communication, and runtimes.
- **Launchers & Testing:**
  - Modernized `Start.bat`, `Start-Optimizer.bat`, and `Запустить Оптимизатор.bat` with UTF-8 encoding (`chcp 65001`) and robust relative path resolution.
  - Automated smoke and integrity test suite (`Test-Win11Optimizer.ps1`) covering 42 assertions with exit code 0 validation.

---

## [0.0.1-alpha] - 2026-11-19
- Initial legacy prototype and preliminary module split.
