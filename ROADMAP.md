# Product Roadmap: Windows 11 Master Optimizer

This document outlines the strategic engineering and feature roadmap for **Windows 11 Master Optimizer** over the upcoming releases.

---

## 🎯 Release Horizons

### Phase 1: Foundation, Hardening & Beta Launch (v0.1.0-beta) — *Current Status: Ready*
- [x] Complete 8-module architecture decoupling safety, tuning, network, GPU, debloat, and diagnostics.
- [x] In-memory NT-kernel Standby RAM Cleaner using `NtSetSystemInformation` and `SeProfileSingleProcessPrivilege`.
- [x] Two-tier failsafe rollback engine (System Restore Points + granular JSON snapshots).
- [x] Full support for Windows 11 24H2 (Build 26100+) including Recall and Copilot debloat.
- [x] 34-assertion automated smoke test suite (`Test-Win11Optimizer.ps1`).
- [x] Anycast DNS benchmark and 1-click DoH switcher.
- [x] Professional international documentation (EN & RU), branding assets, and CI templates.

### Phase 2: Community Feedback & Diagnostics Telemetry (v0.2.0) — *Target: Month 2*
- [ ] **HTML & JSON Audit Export:** Enable 1-click generation of visual HTML diagnostic reports detailing before/after settings and latency metrics.
- [ ] **Automated LatencyMon Integration:** Automatically trigger pre-optimization and post-optimization LatencyMon traces and capture DPC spikes per driver (e.g. `nvlddmkm.sys`, `ndis.sys`).
- [ ] **AMD & Intel GPU Enhancements:** Custom profile tuners for AMD Radeon (ULPS toggle, Anti-Lag 2 verification) and Intel Arc GPUs.
- [ ] **Interactive CLI Profile Builder:** Allow users to export custom optimization profiles (e.g., `esports-minimal`, `streamer-safe`, `workstation-balanced`).
- [ ] **PowerShell Gallery Publishing:** Package the module suite for 1-click install via `Install-Module Win11MasterOptimizer`.

### Phase 3: Benchmark Suite & Ecosystem Integration (v1.0.0) — *Target: Month 3*
- [ ] **Automated Benchmark Runner:** Headless benchmark harness tracking frametime variance and 1% Low FPS across standardized synthetic runs (CapFrameX CLI / PresentMon API).
- [ ] **Game-Specific Presets:** Tailored optimization profiles tested on live game engines:
  - *Counter-Strike 2* (Sub-tick network queue priority, MSI Net High).
  - *Valorant* (Vanguard-compliant scheduler tuning, VBS safety).
  - *Apex Legends / Warzone* (DirectX windowed optimizations, Standby RAM purge).
- [ ] **Localization Expansion:** Community-driven translations (Spanish, German, Japanese, Chinese).
- [ ] **GUI Companion (WPF / WinUI 3):** Optional lightweight modern interface built on top of the PowerShell CLI engine, maintaining zero-bloat principles.

---

## 💡 Submitting Roadmap Ideas

Have a feature proposal? Submit a [Feature Request](https://github.com/1hote-ai/win11-master-optimizer/issues/new?template=feature_request.yml) on GitHub. All proposals must demonstrate empirical latency or frametime benefits and include a defined rollback strategy.
