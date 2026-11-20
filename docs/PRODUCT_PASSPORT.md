# 📘 Product Passport: Windows 11 Master Optimizer

**Repository:** [1hote-ai/win11-master-optimizer](https://github.com/1hote-ai/win11-master-optimizer)  
**Current Branch:** `launch/preparation`  
**Target Environments:** Windows 11 (22H2, 23H2, 24H2 Build 26100+)  
**Primary Language / Stack:** PowerShell 5.1 / PowerShell 7.x, C# P/Invoke (`ntdll.dll`, `advapi32.dll`, `kernel32.dll`), Windows CLI APIs (`netsh`, `powercfg`, `winget`, `dism`)

---

## 1. Executive Summary & Product Architecture

**Windows 11 Master Optimizer** is an open-source, non-destructive system tuning and diagnostic suite designed specifically for competitive gamers, system enthusiasts, and power users. Unlike legacy "black box" tweakers and batch scripts, the suite operates on four strict engineering principles:

1. **Deterministic Execution:** No undocumented registry edits or random script executions; every tweak is mapped to a documented Windows subsystem.
2. **Two-Tier Rollback Engine:** Automated System Restore Points combined with per-operation JSON registry snapshots allowing full rollback to factory defaults.
3. **Hardware-Aware Safety:** PCI bus introspection and physical NIC detection prevent applying incompatible parameters to unsupported hardware.
4. **Zero Third-Party Binary Bloat:** Standby RAM cleaning and high-resolution timer queries use native Win32/NT-kernel P/Invoke calls compiled on-the-fly via Roslyn, eliminating external closed-source EXEs or suspicious DLLs.

```
win11-master-optimizer/
├── Win11Optimizer.ps1             # Main Orchestrator (CLI & Interactive TUI)
├── Test-Win11Optimizer.ps1        # Automated Test Suite (42 assertions)
├── Start.bat / Start-Optimizer.bat # Multi-entry Elevation Launchers (UTF-8, UAC)
├── Запустить Оптимизатор.bat      # Native RU Elevation Launcher (UTF-8)
├── Modules/
│   ├── Safety.psm1                # System Restore Points, JSON Snapshots, Rollback
│   ├── GamingLatency.psm1         # MSI Mode, CPU Scheduling, RAM Cleaner, VBS
│   ├── NetworkGaming.psm1         # Nagle Algorithm, RSS, TCP Stack, DNS Benchmark & DoH
│   ├── GpuDisplay.psm1            # MPO, HAGS, DirectX Windowed, HDCP Killer, Cache Clean
│   ├── Debloat.psm1               # 24H2 Recall, Copilot, Bing Search, Telemetry, Safe UWP
│   ├── SystemUI.psm1              # Classic Menu, Explorer Tweaks, USB Power, Maintenance
│   ├── Diagnostics.psm1           # 26-Point Health Audit, Timer Resolution, DPC/ISR, Ping
│   └── AppInstaller.psm1          # Winget Silent Package Manager (25 curated tools)
├── assets/marketing/              # Branding, Banner, Logo, TUI captures & SVGs
├── tools/
│   ├── Build-ReleasePackage.ps1   # Clean release ZIP & SHA-256 generator
│   └── Setup-GitHubLabels.ps1     # GitHub Labels & Topics REST API sync
├── Backups/                       # Granular JSON state snapshots before modifications
└── Reports/                       # Timestamped diagnostic and benchmark audits
```

---

## 2. Technical Passport & Module Specification

| Module | Core Functionality | Low-Level Mechanisms | Rollback Support |
| :--- | :--- | :--- | :--- |
| **`Safety.psm1`** | Failsafe foundation | `Checkpoint-Computer -RestorePointType MODIFY_SETTINGS`, `SystemRestorePointCreationFrequency=0` registry bypass; JSON snapshot serialization with registry types (`DWord`, `QWord`, `String`, `Binary`, `MultiString`) | ✅ Native 2-Tier Rollback |
| **`GamingLatency.psm1`** | Latency reduction & memory cache | PCI bus scanning via `Win32_PnPEntity`, MSI interrupt configuration (`MSISupported=1`, `DevicePriority=3`); `Win32PrioritySeparation=38 (0x26)`; NT kernel P/Invoke `NtSetSystemInformation(80, ref 4)` with `SeProfileSingleProcessPrivilege` | ✅ JSON snapshot + standard Windows scheduling restore |
| **`NetworkGaming.psm1`** | Network latency & DNS tuning | Disables Nagle's algorithm (`TcpAckFrequency=1`, `TCPNoDelay=1`, `TcpDelAckTicks=0`) across active adapter GUIDs; `netsh int tcp set global rss=enabled`; Anycast DNS benchmarking (ICMP + DoH) for Cloudflare, Quad9, Google, AdGuard | ✅ Full netsh reset & registry restore |
| **`GpuDisplay.psm1`** | GPU & render pipeline | DWM Multi-Plane Overlay toggle (`OverlayTestMode=5`); HAGS toggle (`HwSchMode=2`); DirectX borderless window optimization (`AutoPlayMode=1;`); GPU driver protection (`ExcludeWUDriversInQualityUpdate=1`); NVIDIA HDCP DRM toggle (`RMHdcpKeyglobZero=1`); Shader cache purge | ✅ Per-setting JSON rollback |
| **`Debloat.psm1`** | Background overhead reduction | Disables AI Recall in 24H2 (`DisableAIDataAnalysis=1` + optional feature disable); Microsoft Copilot policy disable; Bing Start Menu integration disable; Telemetry services (`DiagTrack`, `dmwappushservice`) stopped & disabled; Safe UWP removal with strict whitelist | ✅ Policy toggle rollback |
| **`SystemUI.psm1`** | UI responsiveness | Classic Windows 10 context menu CLSID toggle (`{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}`); Explorer clean view (file extensions, compact mode, disable search highlights); USB Selective Suspend disable; Windows Automatic Maintenance toggle | ✅ Instant CLSID & Explorer restore |
| **`Diagnostics.psm1`** | Deep system introspection | Native Win32 timer resolution query (`NtQueryTimerResolution`); Live DPC/ISR counter sampling (`\Processor(_Total)\% DPC Time`, `\Processor(_Total)\DPCs Queued/sec`); 26-parameter automated health audit | Read-only diagnostic |
| **`AppInstaller.psm1`** | Streamlined package delivery | Native `winget` wrapper for 25 essential gaming, monitoring, and runtime packages with silent flags (`--silent --accept-package-agreements`) | Standard Windows package uninstaller |

---

## 3. Audit of Technical Remarks & Previous Criticisms

### 3.1. Safety and System Restore Reliability
- **Prior Remark:** Windows 10/11 defaults to throttling restore points to at most once per 24 hours via `SystemRestorePointCreationFrequency`. If a script calls `Checkpoint-Computer` without overriding this, subsequent runs silently fail to create a restore point.
- **Audited Implementation:** `Safety.psm1` captures the initial state of `HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore\SystemRestorePointCreationFrequency` into a JSON snapshot before setting it to `0`, ensuring every optimizer run can generate a valid restore point without permanent side-effects. During rollback, `Restore-SystemRestorePointCreationFrequency` returns the setting to its original value or removes it if it was not present. Furthermore, `Enable-ComputerRestore` ensures system drive protection is enabled, and the fallback JSON snapshot system logs all keys to disk regardless of VSS service health.

### 3.2. Registry Rollback Engine
- **Prior Remark:** Many optimizers save keys but leave newly created subkeys behind on rollback, fail to restore proper types (e.g. converting `QWord` or `Binary` to `String`), or return a single boolean masking partial failures.
- **Audited Implementation:** `Restore-RegistrySnapshot` returns a structured `RollbackResult` (`Success`, `RestoredCount`, `FailedCount`, `TotalCount`, `RestoredItems`, `FailedItems`, `Errors`, `TargetFile`, `Message`) and handles three distinct rollback states:
  1. If key did not exist originally, values are removed and any newly created empty parent keys are safely pruned.
  2. If key existed but value was absent, only the added value property is deleted.
  3. If value existed, its exact registry kind (`DWord`, `QWord`, `Binary`, `MultiString`, `ExpandString`, `String`) is re-applied with the captured original value.
  4. Write Verification: Every restored property is immediately verified via `Get-ItemProperty` to guarantee write success.
  5. Per-Parameter Isolation: Individual errors do not abort the process; all failed entries are recorded in `FailedItems` and cause `Success` to evaluate to `$false`.

### 3.3. MSI Mode (Message Signaled Interrupts)
- **Prior Remark:** Blindly applying MSI Mode to non-PCI devices or storage controllers without testing can cause BSODs (`INACCESSIBLE_BOOT_DEVICE`).
- **Audited Implementation:** `Get-PciMsiDevices` strictly filters devices starting with `PCI\*` and restricts targets to `Display`, `Net`, and `Media` classes. It avoids SATA/NVMe controllers and unknown bridges, setting `DevicePriority=3 (High)` only for safe peripheral controllers.

### 3.4. Standby RAM Cleaner Implementation
- **Prior Remark:** Third-party standby cleaners often require external binaries (e.g. `EmptyStandbyList.exe`), which trigger anticheat flags or antivirus warnings.
- **Audited Implementation:** The RAM cleaner uses C# P/Invoke compiled in-memory via PowerShell's `Add-Type`. It acquires `SeProfileSingleProcessPrivilege` and `SeIncreaseQuotaPrivilege` using `advapi32!AdjustTokenPrivileges` and invokes `ntdll!NtSetSystemInformation` with command `SystemMemoryListInformation (80)`. This is 100% native and operates without temporary binary drops.

### 3.5. Network Tweaks & Nagle's Algorithm
- **Prior Remark:** Applying `TcpAckFrequency=1` and `TCPNoDelay=1` across all interfaces can cause network instability on non-active virtual adapters.
- **Audited Implementation:** The module scans active interface GUIDs via both `Get-NetAdapter` and the Tcpip parameter keys, applying Nagle overrides specifically to active physical and routing interfaces while maintaining backup snapshots for immediate reversion.

---

## 4. Factual Performance Reality & Empirical Boundaries

To uphold our commitment to intellectual honesty and anti-sycophancy:

1. **FPS Boost Reality:** System tweaks do NOT increase the maximum compute throughput (TFLOPS) of a GPU or CPU. A game bound purely by GPU rasterization will not see higher average FPS from registry tweaks. What optimizations DO achieve is **variance reduction**: minimizing frametime spikes, dropping DPC latency queues, and stabilizing 1% and 0.1% low frametimes.
2. **DPC / ISR Latency:** Switching GPU and network adapters from legacy line-based interrupts (shared IRQ lines) to MSI Mode reduces interrupt handling overhead. On multi-core systems, this prevents audio crackles and input hitches during intense network packet storms.
3. **Standby RAM Cleaner:** Does NOT create "new RAM". In Windows 11, the memory manager caches files in the Standby list. While benign in most situations, certain memory-intensive games (e.g., Battlefield, Escape from Tarkov, Rust) have historically suffered from micro-stutters when allocating memory while the standby list is full. Purging it preemptively smooths frame delivery in these specific titles.
4. **VBS / HVCI Tradeoff:** Virtualization-Based Security (VBS) and Hypervisor-Protected Code Integrity (HVCI) protect the Windows kernel from kernel-level exploits. Disabling VBS can yield a 3-10% framerate increase on older or entry-level CPUs, but it reduces hardware-isolated security. The optimizer clearly warns the user and leaves this toggle opt-in.

---

## 5. System Requirements & Compatibility

- **Operating System:** Windows 11 Home, Pro, Enterprise, Education (Version 22H2, 23H2, 24H2 Build 26100+)
- **Architecture:** x86-64 / AMD64 (ARM64 supported in CLI mode, MSI Mode hardware-dependent)
- **PowerShell:** Windows PowerShell 5.1 (Built into Windows) or PowerShell 7.2+
- **Privileges:** Local Administrator rights (Elevated UAC token)
- **Network:** Internet access required for DNS benchmark and Winget package installation; all core optimizer tweaks work 100% offline.
