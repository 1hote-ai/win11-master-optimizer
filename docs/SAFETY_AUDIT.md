# 🛡 Technical Safety Audit & Reputation Framework

**Document:** Engineering Safety Audit & Integrity Standard  
**Product:** Windows 11 Master Optimizer  
**Classification:** Technical Architecture Standard  

---

## 1. Principles of Anti-Sycophancy & Intellectual Honesty

In the Windows optimization ecosystem, developers frequently market utilities with unscientific claims such as *"100% Safe"*, *"Impossible to break Windows"*, or *"Boost FPS by 300% Guaranteed"*.

**Windows 11 Master Optimizer explicitly rejects this marketing language.**

Modifying kernel quantum scheduling, changing PCI interrupt management, altering TCP stack buffering, and disabling OS services inherently carries risks across divergent hardware architectures and third-party driver stacks.

This document establishes our empirical safety standards, audits all 26+ optimization parameters, classifies their risk tiers, and specifies our failsafe mechanisms.

---

## 2. Risk Classification Matrix

Every function in the suite is assigned to one of four transparent safety tiers:

| Tier | Category | Description | Example Tweaks | Reversibility |
| :--- | :--- | :--- | :--- | :--- |
| **Tier 1** | 🟢 **Safe Baseline** | Universal optimizations that improve responsiveness with zero hardware or software risk. | Classic Context Menu, File Explorer tweaks, Bing search disable, Windows Update GPU driver protection. | 100% Reversible via JSON snapshot in seconds. |
| **Tier 2** | 🔵 **Performance Tuning** | Optimizations with documented latency improvements; safe on all certified modern hardware. | MSI Mode for GPU/NIC, DWM MPO toggle, HAGS, Nagle algorithm disable, Standby RAM purge. | 100% Reversible via snapshot + standard Windows driver reset. |
| **Tier 3** | 🟡 **Advanced System Tweaks** | Modifications that alter security boundaries or resource allocation. **Requires explicit user confirmation; NEVER applied automatically.** | Disabling VBS / HVCI (Virtualization-Based Security), SystemResponsiveness = 0. | Reversible, but requires system reboot and re-enabling DeviceGuard. |
| **Tier 4** | 🟠 **One-Way / Partial Reversal** | Modifications where exact binary state cannot be recovered from registry alone. | Safe UWP app uninstallation (requires re-download from Microsoft Store to reinstall). | Marked with `[IRREVERSIBLE VIA REGISTRY]` notice. |

---

## 3. Detailed Audit of Critical Subsystems

### 3.1. MSI Mode (Message Signaled Interrupts)
- **Mechanism:** Changes legacy line-based interrupts (`IRQ`) to MSI by setting `MSISupported = 1` and `DevicePriority = 3` in `HKLM:\SYSTEM\CurrentControlSet\Enum\<DeviceID>\Device Parameters\Interrupt Management`.
- **Potential Risk:** Applying MSI Mode to incompatible legacy hardware, generic motherboard bridges, or AHCI/NVMe storage controllers without proper vendor INF support can lead to non-bootable systems (`INACCESSIBLE_BOOT_DEVICE`).
- **Mitigation & Safety Filter:**
  1. Devices are strictly filtered to PCI classes: `Display` (GPU), `Net` (Ethernet/Wi-Fi), and `Media` / `Audio`.
  2. All storage controllers, system timers, and PCI root complexes are strictly excluded.
  3. Pre-change snapshots are recorded in `Backups/Backup_MSIMode_<timestamp>.json` prior to any registry write.

### 3.2. Standby RAM Cleaner & WorkingSet Purge
- **Mechanism:** In-memory C# P/Invoke calling `ntdll!NtSetSystemInformation` with command `SystemMemoryListInformation = 80` (`MemoryPurgeStandbyList = 4` and `MemoryEmptyWorkingSets = 2`), accompanied by `SeProfileSingleProcessPrivilege` acquisition.
- **Potential Risk:** Aggressive memory trimming while a write-heavy database or video render is in progress can cause temporary disk pagination spikes.
- **Mitigation & Safety Filter:**
  1. Memory trimming only targets Standby cache pages and idle process working sets.
  2. The function operates 100% in-memory; no external `.exe` or `.dll` binaries are dropped onto disk, avoiding anti-cheat flags.

### 3.3. DWM Multi-Plane Overlay (MPO)
- **Mechanism:** Sets `OverlayTestMode = 5` in `HKLM:\SOFTWARE\Microsoft\Windows\Dwm`.
- **Potential Risk:** On specific older multi-monitor setups with mismatched refresh rates (e.g., 60 Hz + 144 Hz) and integrated graphics, disabling MPO may increase DWM compositor CPU load by ~1%.
- **Empirical Benefit:** Completely eliminates driver-level display corruption, black screens, and stuttering when hardware-accelerated Discord, OBS, or Chromium runs in the background of a game.

### 3.4. VBS / HVCI (Virtualization-Based Security)
- **Mechanism:** Toggles `EnableVirtualizationBasedSecurity` and `HypervisorEnforcedCodeIntegrity` in `HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard`.
- **Tradeoff Warning:** Disabling VBS provides a 3–15% framerate uplift on older CPUs (pre-10th gen Intel, Zen 1/2 AMD) by eliminating hypervisor page-table translations. However, it removes hardware isolation protecting kernel code from malicious drivers.
- **Strict Rule:** **This tweak is NEVER included in `AutoGaming` or default presets.** It exists solely as an isolated, opt-in choice in the Low Latency submenu with explicit warnings.

### 3.5. Safe UWP Debloat & Bloatware Removal
- **Mechanism:** Invokes `Get-AppxPackage` and `Remove-AppxPackage`.
- **Potential Risk:** Blind debloaters often remove the Microsoft Store, Xbox identity providers, or core calculator/notepad components, breaking subsequent Windows Updates or Xbox Game Pass titles.
- **Mitigation & Strict Whitelist:**
  - `Debloat.psm1` enforces a strict hardcoded whitelist protecting: `Microsoft.WindowsStore`, `Microsoft.StorePurchaseApp`, `Microsoft.XboxApp`, `Microsoft.GamingApp`, `Microsoft.XboxIdentityProvider`, `Microsoft.WindowsCalculator`, `Microsoft.WindowsNotepad`, `Microsoft.Paint`, `Microsoft.WindowsTerminal`, `Microsoft.ScreenSketch`, and `Microsoft.SecHealthUI`.

### 3.6. Granular Rollback Engine & Side-Effect Remediation
- **Mechanism:** `Modules/Safety.psm1` implements `Restore-RegistrySnapshot` returning a structured `RollbackResult` object.
- **Fail-Safe Integrity:**
  - **Per-Parameter Isolation:** Every registry value is processed inside an independent exception barrier. A permission or path failure on parameter $N$ does not abort the restoration of parameter $N+1$.
  - **Write Verification:** Immediately following `Set-ItemProperty`, `Get-ItemProperty` confirms that the property exists and matches.
  - **Strict Status Semantics:** If any entry fails, `Success` is unconditionally set to `$false`, and all failed entries are collected in `FailedItems` with detailed exception messages.
  - **Zero Side-Effects for System Restore Frequency:** When creating a restore point, Windows imposes a 24-hour throttle via `SystemRestorePointCreationFrequency`. The optimizer captures the pre-existing state of this key before setting it to 0. During rollback, `Restore-SystemRestorePointCreationFrequency` returns it to its original value or removes it if it was not originally present.
  - **Automated Backup Rotation:** `Invoke-BackupRotation` prunes snapshots beyond the 50 most recent files, preventing unbounded disk accumulation.

### 3.7. Exact Subsystem State Restoration Framework
To eliminate discrepancies between declared reversibility and actual system state restoration, the optimizer replaces hardcoded defaults with exact state capture and restoration across 6 critical subsystems:
1. **Power Schemes (Powercfg):** Captures initial active power scheme GUID, processor power management subgroup GUID, and exact AC and DC values for `CPMINCORES`, `PERFEPP`, `PROCTHROTTLEMIN`, and `PERFBOOSTMODE`. On rollback, restores the user's exact prior values and re-activates their original power plan (instead of assuming standard balanced defaults).
2. **Global TCP Stack (Netsh):** Queries and snapshots active `rss`, `autotuninglevel`, `timestamps`, and `ecncapability` settings via `netsh int tcp show global`. On rollback, restores each parameter to its exact captured value, verifying restoration and reporting any parameter that fails to apply.
3. **Windows Services:** Snapshots initial `StartupType` and `Status` (`Running` vs `Stopped`) for telemetry services (`DiagTrack`, `dmwappushservice`). On rollback, restores the original startup configuration without forcing stopped services into a running state.
4. **Scheduled Tasks:** Queries and snapshots initial task state (`Ready`, `Running`, `Disabled`). On rollback, re-enables only tasks that were originally active; tasks that were already disabled prior to optimization remain untouched.
5. **Network Adapters (EEE / ULP / Green Ethernet):** Captures individual physical network adapter advanced properties (`EEELinkAdvertisement`, `*EEE`, `*EnergyEfficientEthernet`, `ULPMode`, `*GreenEthernet`) along with their native driver values. Restores each property individually during rollback.
6. **USB Power Management:** Captures active scheme AC/DC values for USB Selective Suspend and WMI `MSPower_DeviceEnable` hub states. On rollback, restores the exact captured state.

### 3.8. Snapshot Security Validation Framework (Strict Allowlist)
To prevent arbitrary registry writes, privilege escalation, or corrupted snapshot injection, `Restore-RegistrySnapshot` enforces strict validation via `Test-RegistrySnapshotEntrySecurity`:
- **Path Traversal & Injection Blocking:** Rejects entries containing traversal sequences (`..`), wildcards (`*`, `?`), null bytes (`\0`), semicolons, or line breaks.
- **Root Whitelisting:** Restricts root hives strictly to `HKLM:\` and `HKCU:\`.
- **Permanent Blacklist of Critical Hives:** Permanently denies access to protected security hives: `HKLM:\SAM`, `HKLM:\SECURITY`, `HKLM:\BCD00000000`, `\Control\Lsa`, `\Control\Session Manager`, `\Services\WinDefend`, `\Services\MpsSvc`, `\Services\LanmanServer`.
- **Strict Allowlist of Exact Paths & Parameter Names:** Rather than allowing wide directory prefixes, every target path is matched against an exact regular expression allowlist, and each matched path has an explicit whitelist of allowed parameter names (e.g., `PriorityControl` only permits `Win32PrioritySeparation`; `Interfaces\{guid}` only permits `TcpAckFrequency`, `TCPNoDelay`, `TcpDelAckTicks`, `NameServer`, `DhcpNameServer`). Any foreign key or unauthorized parameter name triggers an immediate block.
- **Registry Type Whitelist:** Rejects unknown or malicious registry types, permitting only `DWord`, `QWord`, `String`, `ExpandString`, `MultiString`, and `Binary`.
- **Isolated Failure Handling:** Insecure entries trigger `[SECURITY BLOCK]`, are recorded in `FailedItems`, and mark overall `Success = $false` without halting execution.

---

## 4. Comprehensive 73-Feature Classification Table

Every capability in the Windows 11 Master Optimizer suite is classified below with transparent status tags based on empirical testing reality:
- **`UNIT-TESTED`**: Validated in automated test suite using mock/synthetic data or isolated registry test sandbox.
- **`DRY-RUN ONLY`**: Safe execution verified in automated dry-run test suite without modifying system state.
- **`READ-ONLY VERIFIED`**: State, telemetry, hardware, or diagnostic query verified live on Windows without side-effects.
- **`LIVE ROUND-TRIP VERIFIED`**: Empirical live change AND rollback cycle confirmed on Windows with pre/post state comparison.
- **`EXPERIMENTAL`**: Advanced kernel or driver tweak requiring caution or specific vendor hardware (e.g. VBS toggle, HDCP DRM, Standby RAM cleaner).
- **`IRREVERSIBLE`**: Cannot be restored solely via local registry rollback (e.g., UWP app removal requires Microsoft Store reinstall; shader caches rebuild dynamically).
- **`MANUAL TEST REQUIRED`**: Requires interactive user input, physical hardware action, live VSS elevation, or system reboot to observe end-to-end effect.

| # | Subsystem | Feature / Function | Status Tag | Mechanism & Exact Restoration Path |
| :--- | :--- | :--- | :--- | :--- |
| 1 | **Safety** | Admin Privilege Check (`Test-IsAdmin`) | `READ-ONLY VERIFIED` | `WindowsPrincipal.IsInRole(Administrator)`. |
| 2 | **Safety** | System Restore Point (`New-OptimizerRestorePoint`) | `MANUAL TEST REQUIRED` | `Checkpoint-Computer -RestorePointType MODIFY_SETTINGS`. Requires live VSS service, system drive protection and elevation. |
| 3 | **Safety** | Restore Point Frequency (`Restore-SystemRestorePointCreationFrequency`) | `UNIT-TESTED` | Exact snapshot restoration or removal of `SystemRestorePointCreationFrequency`. |
| 4 | **Safety** | Registry Snapshot (`Save-RegistrySnapshot`) | `UNIT-TESTED` | Serializes values with exact types (`DWord`, `QWord`, `String`, `Binary`, etc.). |
| 5 | **Safety** | Granular Registry Rollback (`Restore-RegistrySnapshot`) | `UNIT-TESTED` | Atomic per-entry restoration with subkey pruning and write verification in sandbox. |
| 6 | **Safety** | Security Validator (`Test-RegistrySnapshotEntrySecurity`) | `UNIT-TESTED` | Strict allowlist regex, param whitelist, and negative security attack tests. |
| 7 | **Safety** | State Snapshot Engine (`Save-StateSnapshot`) | `UNIT-TESTED` | Generic JSON snapshotting for powercfg, netsh, services, tasks, adapters. |
| 8 | **Safety** | State Snapshot Retrieval (`Get-LatestStateSnapshot`) | `UNIT-TESTED` | Retrieves latest timestamped JSON state snapshot for exact rollback. |
| 9 | **Safety** | Backup History Inspection (`Get-BackupHistory`) | `READ-ONLY VERIFIED` | Enumerates and parses backup JSON catalog. |
| 10 | **Safety** | Backup Rotation (`Invoke-BackupRotation`) | `UNIT-TESTED` | Retains latest 50 backups, purges older than 30 days. |
| 11 | **GamingLatency** | PCI Bus Introspection (`Get-PciMsiDevices`) | `READ-ONLY VERIFIED` | WMI query filtering `Display`, `Net`, and `Media` PCI devices. |
| 12 | **GamingLatency** | MSI Mode Configuration (`Set-GamingMsiMode`) | `DRY-RUN ONLY` | Sets `MSISupported=1` and `DevicePriority=3 (High)` on GPU/NIC/Audio. |
| 13 | **GamingLatency** | MSI Mode Rollback (`Restore-GamingMsiMode`) | `DRY-RUN ONLY` | Restores original `MSISupported` and `DevicePriority` from snapshot. |
| 14 | **GamingLatency** | Processor Power State Query (`Get-ProcessorPowerSettingsState`) | `READ-ONLY VERIFIED` | Queries active scheme GUID and AC/DC indices for CPMINCORES, PERFEPP. |
| 15 | **GamingLatency** | CPU Scheduling & Core Parking (`Set-CpuGamingScheduling`) | `DRY-RUN ONLY` | Snapshots processor settings; sets `Win32PrioritySeparation=38`, `CPMINCORES=100`, `PERFEPP=0`. |
| 16 | **GamingLatency** | CPU Scheduling Exact Rollback (`Restore-CpuGamingScheduling`) | `UNIT-TESTED` | Restores original AC/DC powercfg values to target scheme GUID and restores original scheme GUID. |
| 17 | **GamingLatency** | Ultimate Performance Plan (`Enable-UltimatePerformancePlan`) | `DRY-RUN ONLY` | Snapshots active scheme GUID; duplicates/activates `e9a42b02-...` scheme. |
| 18 | **GamingLatency** | Active Power Scheme Exact Rollback (`Restore-ActivePowerScheme`) | `UNIT-TESTED` | Re-activates initial power scheme GUID and prunes temporary optimizer duplicate. |
| 19 | **GamingLatency** | System Responsiveness Tuning (`Set-SystemResponsivenessGaming`) | `DRY-RUN ONLY` | Snapshots `SystemProfile`; sets `SystemResponsiveness=0`, `GPU Priority=8`, `Priority=6`. |
| 20 | **GamingLatency** | System Responsiveness Rollback (`Restore-SystemResponsiveness`) | `DRY-RUN ONLY` | Restores original values from `Backup_SystemResponsiveness` snapshot. |
| 21 | **GamingLatency** | VBS / HVCI State Query (`Get-VbsStatus`) | `READ-ONLY VERIFIED` | Queries `EnableVirtualizationBasedSecurity` and `HypervisorEnforcedCodeIntegrity`. |
| 22 | **GamingLatency** | VBS / HVCI Security Toggle (`Set-VbsState`) | `EXPERIMENTAL` | Opt-in toggle; modifies kernel hypervisor security; requires reboot. |
| 23 | **GamingLatency** | Standby RAM & WorkingSet Purge (`Clear-StandbyRamAndWorkingSet`) | `EXPERIMENTAL` | In-memory P/Invoke `NtSetSystemInformation(80, ref 4/2)` with `SeProfileSingleProcessPrivilege`. |
| 24 | **GamingLatency** | MSI Mode Status (`Get-MsiModeStatus`) | `READ-ONLY VERIFIED` | Reads active interrupt state across PCI controllers. |
| 25 | **GamingLatency** | CPU Scheduling Status (`Get-CpuGamingSchedulingStatus`) | `READ-ONLY VERIFIED` | Reads `Win32PrioritySeparation` and compares against 0x26. |
| 26 | **GamingLatency** | Ultimate Performance Status (`Get-UltimatePerformancePlanStatus`) | `READ-ONLY VERIFIED` | Reads active power scheme name and GUID. |
| 27 | **GamingLatency** | System Responsiveness Status (`Get-SystemResponsivenessStatus`) | `READ-ONLY VERIFIED` | Reads `SystemResponsiveness` under `SystemProfile`. |
| 28 | **NetworkGaming** | Active NIC GUID Enumeration (`Get-ActiveNetworkInterfaceGuids`) | `READ-ONLY VERIFIED` | Enumerates routing interfaces and Tcpip parameter keys. |
| 29 | **NetworkGaming** | Global TCP State Query (`Get-NetshTcpGlobalState`) | `READ-ONLY VERIFIED` | Queries and parses RSS, autotuninglevel, timestamps, ecncapability. |
| 30 | **NetworkGaming** | Gaming Network Stack Tuning (`Set-GamingNetworkStack`) | `DRY-RUN ONLY` | Snapshots registry, netsh TCP, and NIC properties; disables Nagle (`TcpAckFrequency=1`, `TCPNoDelay=1`). |
| 31 | **NetworkGaming** | Network Stack Exact Rollback (`Restore-GamingNetworkStack`) | `DRY-RUN ONLY` | Restores Nagle parameters, exact netsh parameters, exact NIC EEE/ULP properties. |
| 32 | **NetworkGaming** | Network Power Saving Status (`Get-NetworkPowerSavingStatus`) | `READ-ONLY VERIFIED` | Inspects EEE, Green Ethernet, and ULP properties across adapters. |
| 33 | **NetworkGaming** | Primary Active NIC Detection (`Get-PrimaryActiveNetworkInterface`) | `READ-ONLY VERIFIED` | Resolves active routing network adapter with valid default gateway. |
| 34 | **NetworkGaming** | Anycast DNS Benchmark Engine (`Test-GamingDnsBenchmark`) | `READ-ONLY VERIFIED` | Probes ICMP latency and HTTPS DoH response times for Cloudflare, Quad9, Google, AdGuard. |
| 35 | **NetworkGaming** | Gaming DNS Configuration (`Set-GamingDns`) | `DRY-RUN ONLY` | Sets primary/secondary DNS servers and configures encrypted DoH templates. |
| 36 | **NetworkGaming** | DNS Reset to DHCP (`Reset-GamingDns`) | `DRY-RUN ONLY` | Resets DNS server addresses to automatic DHCP assignment. |
| 37 | **NetworkGaming** | Gaming DNS Snapshot Rollback (`Restore-GamingDns`) | `DRY-RUN ONLY` | Restores original DNS configuration from snapshot. |
| 38 | **NetworkGaming** | Interactive DNS Switcher Menu (`Show-DnsBenchmarkAndSwitcherMenu`) | `MANUAL TEST REQUIRED` | Interactive console UI for live DNS benchmarking and selection. |
| 39 | **NetworkGaming** | Nagle Algorithm Status (`Get-NagleStatus`) | `READ-ONLY VERIFIED` | Reads `TcpAckFrequency` and `TCPNoDelay` across active interfaces. |
| 40 | **NetworkGaming** | Network Stack Status (`Get-NetworkGamingStackStatus`) | `READ-ONLY VERIFIED` | Reads `NetworkThrottlingIndex` under `SystemProfile`. |
| 41 | **NetworkGaming** | Gaming DNS Status (`Get-GamingDnsStatus`) | `READ-ONLY VERIFIED` | Reads active DNS servers and matches against fast providers. |
| 42 | **GpuDisplay** | NVIDIA Adapter Detection (`Get-NvidiaDisplayAdapterKeys`) | `READ-ONLY VERIFIED` | Enumerates `Class\{4d36e968-...}` display adapters for `ven_10de`. |
| 43 | **GpuDisplay** | DWM MPO Disable (`Disable-MpoOverlay`) | `DRY-RUN ONLY` | Snapshots and sets `OverlayTestMode=5` in `HKLM:\SOFTWARE\Microsoft\Windows\Dwm`. |
| 44 | **GpuDisplay** | DWM MPO Rollback (`Restore-MpoOverlay`) | `DRY-RUN ONLY` | Restores original `OverlayTestMode` or deletes key on rollback. |
| 45 | **GpuDisplay** | Hardware-Accelerated GPU Scheduling (`Enable-Hags`) | `DRY-RUN ONLY` | Snapshots and sets `HwSchMode=2` in `GraphicsDrivers`. |
| 46 | **GpuDisplay** | HAGS Rollback (`Restore-Hags`) | `DRY-RUN ONLY` | Restores original `HwSchMode` value from snapshot. |
| 47 | **GpuDisplay** | DirectX Windowed Optimization (`Enable-DirectXWindowedOptimizations`) | `DRY-RUN ONLY` | Snapshots and sets `DirectXUserGlobalSettings = 'AutoPlayMode=1;'`. |
| 48 | **GpuDisplay** | DirectX Windowed Rollback (`Restore-DirectXWindowedOptimizations`) | `DRY-RUN ONLY` | Restores original `DirectXUserGlobalSettings` from snapshot. |
| 49 | **GpuDisplay** | GPU Driver Windows Update Protection (`Enable-WindowsUpdateDriverProtection`) | `DRY-RUN ONLY` | Snapshots and sets `ExcludeWUDriversInQualityUpdate=1` under Policies. |
| 50 | **GpuDisplay** | GPU Driver Protection Rollback (`Restore-WindowsUpdateDriverProtection`) | `DRY-RUN ONLY` | Restores original driver update policy from snapshot. |
| 51 | **GpuDisplay** | NVIDIA HDCP DRM Killer (`Disable-NvidiaHdcp`) | `EXPERIMENTAL` | Snapshots and sets `RMHdcpKeyglobZero=1` on NVIDIA driver instances. |
| 52 | **GpuDisplay** | NVIDIA HDCP DRM Rollback (`Restore-NvidiaHdcp`) | `DRY-RUN ONLY` | Restores original `RMHdcpKeyglobZero` parameter from snapshot. |
| 53 | **GpuDisplay** | GPU Shader Cache Purge (`Clear-ShaderCaches`) | `IRREVERSIBLE` | Purges DXCache, D3DSCache, NVIDIA GLCache; caches rebuild dynamically during gameplay. |
| 54 | **GpuDisplay** | DWM MPO Status (`Get-MpoStatus`) | `READ-ONLY VERIFIED` | Reads `OverlayTestMode` under DWM. |
| 55 | **GpuDisplay** | HAGS Status (`Get-HagsStatus`) | `READ-ONLY VERIFIED` | Reads `HwSchMode` under GraphicsDrivers. |
| 56 | **GpuDisplay** | DirectX Windowed Status (`Get-DirectXWindowedStatus`) | `READ-ONLY VERIFIED` | Reads `AutoPlayMode` under DirectX UserGpuPreferences. |
| 57 | **GpuDisplay** | Driver Update Protection Status (`Get-WindowsUpdateDriverProtectionStatus`) | `READ-ONLY VERIFIED` | Reads `ExcludeWUDriversInQualityUpdate` policy. |
| 58 | **GpuDisplay** | NVIDIA HDCP Status (`Get-NvidiaHdcpStatus`) | `READ-ONLY VERIFIED` | Reads `RMHdcpKeyglobZero` on active NVIDIA GPUs. |
| 59 | **Debloat** | Telemetry & Diagnostics Disable (`Disable-TelemetryAndDiagnostics`) | `DRY-RUN ONLY` | Snapshots exact service startup/status and task states; disables DiagTrack, dmwappushservice. |
| 60 | **Debloat** | Windows 11 24H2 Recall Disable (`Disable-RecallAndAiFeatures`) | `DRY-RUN ONLY` | Sets `DisableAIDataAnalysis=1` policy and invokes DISM optional feature disable. |
| 61 | **Debloat** | Copilot & Bing Search Disable (`Disable-CopilotAndBingSearch`) | `DRY-RUN ONLY` | Sets `TurnOffWindowsCopilot=1`, `DisableSearchBoxSuggestions=1`, `BingSearchEnabled=0`. |
| 62 | **Debloat** | Widgets Board Disable (`Disable-WidgetsBoard`) | `DRY-RUN ONLY` | Sets `AllowNewsAndInterests=0` policy to purge taskbar MSN widgets. |
| 63 | **Debloat** | Safe Bloatware Uninstaller (`Remove-WindowsBloatware`) | `IRREVERSIBLE` | Removes pre-installed sponsored UWP packages with strict protection whitelist. |
| 64 | **Debloat** | Debloat Settings Exact Rollback (`Restore-DebloatSettings`) | `UNIT-TESTED` | Restores exact registry policies, exact service StartupType/Status, and enables only previously active tasks. |
| 65 | **Debloat** | Recall Status (`Get-RecallStatus`) | `READ-ONLY VERIFIED` | Reads `DisableAIDataAnalysis` policy and DISM Recall state. |
| 66 | **Debloat** | Copilot Status (`Get-CopilotStatus`) | `READ-ONLY VERIFIED` | Reads `TurnOffWindowsCopilot` policy. |
| 67 | **Debloat** | Bing Search Status (`Get-BingSearchStatus`) | `READ-ONLY VERIFIED` | Reads `DisableSearchBoxSuggestions` and `BingSearchEnabled`. |
| 68 | **Debloat** | Widgets Status (`Get-WidgetsStatus`) | `READ-ONLY VERIFIED` | Reads `AllowNewsAndInterests` policy. |
| 69 | **Debloat** | Telemetry Status (`Get-TelemetryStatus`) | `READ-ONLY VERIFIED` | Reads `AllowTelemetry` and checks `DiagTrack` service state. |
| 70 | **Debloat** | Bloatware Status (`Get-BloatwareStatus`) | `READ-ONLY VERIFIED` | Scans installed AppX packages matching bloatware list. |
| 71 | **SystemUI** | Classic Context Menu (`Set-ClassicContextMenu`) | `DRY-RUN ONLY` | Registers CLSID `{86ca1aa0-...}` under `HKCU:\Software\Classes\CLSID`. |
| 72 | **SystemUI** | File Explorer Tweaks (`Set-FileExplorerTweaks`) | `DRY-RUN ONLY` | Sets `HideFileExt=0`, `UseCompactMode=1`, `ShowRecent=0`, disables Search Highlights. |
| 73 | **SystemUI** | GameDVR Optimization (`Set-GameDvrOptimized`) | `DRY-RUN ONLY` | Disables background GameDVR capture while keeping Game Bar and Xbox Live functional. |

---

## 5. Ten Architecture Improvements for Maximum User Trust

1. **Pre-Execution Dry-Run:** Every CLI mode and TUI option supports `-DryRun`, outputting every planned registry key, path, and command without touching system state.
2. **Deterministic Logging:** Every run writes timestamped execution logs to `Reports/` for auditing and technical troubleshooting.
3. **Descriptive Error Handling:** Catch blocks provide actionable error messages (e.g., distinguishing between lack of admin privileges, non-existent registry paths, or missing hardware).
4. **Verified Rollback:** The two-tier rollback engine guarantees return to Windows factory defaults.
5. **Irreversibility Disclosure:** Operations that cannot be reverted strictly via registry rollback (like uninstalled UWP packages) are marked upfront.
6. **Hardware Compatibility Checks:** Hardware state and vendor IDs (such as NVIDIA `ven_10de`) are confirmed before vendor-specific tweaks (HDCP bypass) are executed.
7. **No Auto-Application of Risky Tweaks:** HVCI/VBS stays untouched in standard presets.
8. **Clear Modular Boundaries:** Modules are completely decoupled; users can run network tweaks without touching GPU or UI settings.
9. **Driver Protection:** Prevents Windows Update from silently overwriting manually tuned, stable graphics drivers.
10. **Reproducible Test Suite:** Continuous validation via `Test-Win11Optimizer.ps1` before every release.
