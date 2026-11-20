# Contributing to Windows 11 Master Optimizer

Thank you for your interest in contributing to **Windows 11 Master Optimizer**! This document outlines our engineering standards, contribution process, and guidelines for keeping this project reliable, safe, and transparent.

---

## 🏛 Core Architectural Principles

Before submitting any code, keep our non-negotiable standards in mind:

1. **Zero Snake Oil & Scientific Honesty:**  
   Every tweak, optimization, or diagnostic feature must correspond to a documented Windows subsystem, API, or NT-kernel behavior. We do NOT accept placebo tweaks, random undocumented registry values, or unverified "FPS booster" claims.
2. **Reversibility is Mandatory:**  
   Every modification to the Windows registry or system settings must be paired with an exact rollback mechanism using our `Safety.psm1` JSON snapshot engine.
3. **Hardware & Driver Awareness:**  
   Do not assume every PC runs the same hardware. Verify adapter GUIDs, PCI device classes, and driver states before making system changes.
4. **Zero Closed-Source Binary Bloat:**  
   We do not bundle third-party `.exe` or `.dll` files in the repository. Native Win32 / NT-kernel calls must be achieved via C# P/Invoke compiled in-memory via `Add-Type`.

---

## 🛠 Development Workflow

### 1. Fork and Clone
```bash
git clone https://github.com/<your-username>/win11-master-optimizer.git
cd win11-master-optimizer
git checkout -b feature/your-feature-name
```

### 2. Code Conventions
- Scripts and modules must specify `# Encoding: UTF-8`.
- PowerShell code should use `Set-StrictMode -Version Latest`.
- Functions modifying system state must support `-DryRun` (`[switch]$DryRun = $false`).
- Follow the approved naming conventions: `Get-*`, `Set-*`, `Restore-*`, `Test-*`, `Invoke-*`.
- Keep modules focused within their designated domain (`GamingLatency`, `NetworkGaming`, `GpuDisplay`, `Debloat`, `SystemUI`, `Diagnostics`, `Safety`, `AppInstaller`).

### 3. Verification & Testing
Before opening a Pull Request, run the automated test suite:
```powershell
powershell -ExecutionPolicy Bypass -File .\Test-Win11Optimizer.ps1
```
All assertions must pass with Exit Code `0`. If your feature introduces new functionality, add corresponding assertions to `Test-Win11Optimizer.ps1`.

---

## 📝 Pull Request Guidelines

1. **Title:** Use Conventional Commits formatting:
   - `feat(gpu): add Intel Arc dynamic frame-sync toggle`
   - `fix(network): handle virtual Hyper-V adapters during Nagle configuration`
   - `docs(readme): add troubleshooting section for borderless VRR`
2. **Description:** Explain:
   - What changed.
   - Why this change improves the system or resolves a bug.
   - Empirical proof or benchmarks showing its effectiveness.
   - Testing evidence from running `Test-Win11Optimizer.ps1`.
3. **Safety Checklist:**
   - [ ] Does this change support `-DryRun`?
   - [ ] Does it create a registry snapshot before modifying state?
   - [ ] Has rollback been tested and verified to restore original values?
   - [ ] Does it pass all automated tests with 0 failures?

---

## 💬 Community & Code of Conduct

Be respectful, constructively critical, and technically rigorous. We build open-source tools for the entire Windows enthusiast and gaming community.
