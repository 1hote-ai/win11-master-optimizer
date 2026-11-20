# Security Policy

## Supported Versions

Windows 11 Master Optimizer targets modern releases of Microsoft Windows 11. Security updates and bug fixes are applied to the active branch and releases:

| Version | Supported | Notes |
| :--- | :--- | :--- |
| Windows 11 24H2 (Build 26100+) | ✅ Fully Supported | Native Recall & Copilot policy overrides |
| Windows 11 23H2 (Build 22631) | ✅ Fully Supported | Primary stable baseline |
| Windows 11 22H2 (Build 22621) | ✅ Fully Supported | Supported |
| Windows 10 (All Builds) | ⚠️ Partial Support | Core latency tweaks work; 24H2 debloat skipped |
| Windows Server / LTSC | ⚠️ Experimental | Not officially validated |

---

## Reporting a Vulnerability or Critical System Issue

If you discover a security vulnerability, an unintended privilege escalation risk, or a scenario where the optimizer could cause an unrecoverable system crash (e.g. BSOD boot loops, corrupted BCD, network adapter de-provisioning):

1. **Do NOT open a public GitHub issue immediately.**
2. Send a detailed report to the security maintainers via GitHub Private Vulnerability Reporting on [1hote-ai/win11-master-optimizer/security/advisories](https://github.com/1hote-ai/win11-master-optimizer/security/advisories) or directly contact the repository owner.
3. Include:
   - Your Windows build version (`winver` output).
   - Exact hardware specification (CPU, Motherboard, GPU, NIC).
   - Step-by-step reproduction steps.
   - Any generated logs from `Reports/` or `Backups/`.

We commit to acknowledging your report within 48 hours and providing a prioritized patch or workaround.

---

## Security Architecture Principles

- **No Network Exfiltration:** The optimizer never transmits telemetry, hardware identifiers, or system telemetry to any remote server. The only external network calls occur during the user-initiated DNS benchmark (`Test-Connection`) or `winget` package installations.
- **In-Memory Compilation Only:** All C# P/Invoke code (such as `NtSetSystemInformation` and `NtQueryTimerResolution`) is compiled in-memory via Roslyn; no temporary unverified `.dll` or `.exe` files are dropped on disk.
- **Explicit Privilege Boundary:** Administrator privileges are explicitly verified via UAC token introspection before modifying any protected system branch (`HKLM`).
