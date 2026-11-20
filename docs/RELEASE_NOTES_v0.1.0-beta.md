# 📦 Release Notes: Windows 11 Master Optimizer v0.1.0-beta

**Tag:** `v0.1.0-beta`  
**Status:** Public Beta Pre-Release (Community Testing Phase)  
**Target OS:** Windows 11 (22H2, 23H2, 24H2 Build 26100+)  
**Publishing Status:** Staged for Approval (Per Rule 12, awaiting Шеф's confirmation before remote GitHub release)

---

## 🌟 Highlights of this Release

Welcome to the first public beta of **Windows 11 Master Optimizer**! This release marks the transition from an experimental script into an open-source, modular optimization and latency diagnostic suite engineered specifically for competitive gamers and power users.

### 🛡️ Why This is Different
- **Two-Tier Rollback Engine:** Automatic creation of Windows System Restore Points (`Checkpoint-Computer`) and granular JSON registry snapshots before any modification. You can return 100% to factory Windows 11 defaults in 1 click.
- **Native NT-Kernel Memory Purge:** Standby RAM cleaning and high-resolution timer diagnostics use native Win32/NT-kernel P/Invoke (`NtSetSystemInformation`, `NtQueryTimerResolution`), dropping zero closed-source binaries onto your disk.
- **Hardware-Aware MSI Mode:** PCI bus enumeration ensures high-priority Message Signaled Interrupts are assigned safely to GPU, Network, and Audio controllers without risking storage controller BSODs.
- **Windows 11 24H2 Ready:** Clean disabling of AI Recall (`DisableAIDataAnalysis = 1` + DISM optional feature), Copilot taskbar removal, and MSN widgets.
- **Zero Snake Oil:** Every tweak is mathematically grounded in documented Windows subsystems. No fake "+500% FPS" claims.

---

## 📋 What's Included

### 1. Core Modules
- `Modules/Safety.psm1`: System Restore Points, JSON state snapshots, and granular rollback engine.
- `Modules/GamingLatency.psm1`: MSI Mode, CPU Scheduling quantums (`Win32PrioritySeparation = 38`), Standby RAM cleaner, VBS toggle.
- `Modules/NetworkGaming.psm1`: Nagle's algorithm disable, RSS, TCP stack tuning, Anycast DNS benchmark & DoH switcher.
- `Modules/GpuDisplay.psm1`: DWM MPO toggle (`OverlayTestMode = 5`), HAGS, DirectX windowed optimizations, GPU driver protection, shader cache clean.
- `Modules/Debloat.psm1`: Windows 11 24H2 Recall, Copilot, Bing Start search, Telemetry disable, Safe UWP bloatware removal with strict whitelist.
- `Modules/SystemUI.psm1`: Windows 10 classic context menu, Explorer enhancements, USB Selective Suspend disable, Automatic Maintenance toggle.
- `Modules/Diagnostics.psm1`: 26-point System Health Audit, Win32 timer resolution query, live DPC/ISR sampling.
- `Modules/AppInstaller.psm1`: Native `winget` silent package installer with 25 curated essentials.

### 2. Multi-Entry Launchers
- `Start.bat` & `Start-Optimizer.bat`: Multi-entry launchers supporting UTF-8 (`chcp 65001`), UAC automatic elevation, and relative path resolution.

### 3. Automated Test Suite
- `Test-Win11Optimizer.ps1`: Automated test harness running 42 assertions verifying module loading, snapshot creation, granular rollback integrity, hardware enumeration, and dry-run execution with Exit Code 0.

---

## 🖥️ System Requirements & Prerequisites

- **Operating System:** Windows 11 Home, Pro, Enterprise, Education (22H2, 23H2, 24H2 Build 26100+)
- **PowerShell:** Windows PowerShell 5.1 (Built into Windows 11) or PowerShell 7.2+
- **Privileges:** Administrator privileges (Elevated UAC token)
- **Architecture:** x86-64 / AMD64

---

## ⚠️ Known Limitations & Beta Notices

- **HVCI / VBS Opt-In:** Virtualization-Based Security (VBS) lowers latency on older CPUs, but reduces kernel memory isolation. This setting is strictly opt-in and NOT included in automated presets.
- **UWP App Reinstallation:** Uninstalled UWP bloatware cannot be restored purely via registry rollback; reinstallation requires downloading the app from the Microsoft Store.
- **Reboot Required:** MSI Mode, CPU quantums, and HAGS require a system reboot for the Windows kernel to re-initialize hardware interrupt vectors.

---

## 🔒 Verification & Checksums

Release archives built via `tools/Build-ReleasePackage.ps1` include automated SHA-256 checksums to verify package integrity:

| Asset Name | Size | SHA-256 Checksum |
| :--- | :--- | :--- |
| `win11-master-optimizer-v0.1.0-beta.zip` | 177.34 KB | `607B12DF27076FD91581ECA27EABDFD82BC29E516BF22B9DAAB82911E30C8A4C` |

*To verify checksum in PowerShell:*
```powershell
Get-FileHash -Path .\dist\win11-master-optimizer-v0.1.0-beta.zip -Algorithm SHA256
```
