# 🏷️ GitHub Topics & SEO Discovery Strategy

**Project:** Windows 11 Master Optimizer  
**Repository:** [1hote-ai/win11-master-optimizer](https://github.com/1hote-ai/win11-master-optimizer)  
**Classification:** Open-Source Growth & Discoverability Standard  

---

## 1. Executive Summary

GitHub Topics serve as the primary taxonomy and SEO discovery mechanism across GitHub's search engine, Explore feed, and topic aggregation pages. Correct topic selection directly influences:
1. **Repository Discoverability:** Inclusion in topic listing pages (e.g. `github.com/topics/windows-11`).
2. **Algorithmic Recommendations:** Showing the project in "Related repositories" sidebars.
3. **Target Persona Alignment:** Attracting developers, system engineers, competitive gamers, and open-source contributors searching for precise technical solutions.

GitHub allows up to **20 topics** per repository. Each topic must consist of lowercase alphanumeric characters and hyphens (`-`), with a maximum length of 35 characters.

---

## 2. The 20 Recommended GitHub Topics & Relevance Audit

Below is the audited matrix of the 20 most impactful topics selected for **Windows 11 Master Optimizer**:

| # | Topic Tag | Category | Global Search Intent & Relevance Justification |
| :--- | :--- | :--- | :--- |
| **01** | `windows-11` | Primary Platform | **Crucial.** Filters users specifically seeking software built for Windows 11 (22H2, 23H2, 24H2) rather than legacy Windows 7/10 tools. |
| **02** | `windows-optimizer` | Core Domain | **High Intent.** Primary keyword searched by users seeking performance optimization and cleanup utilities on Windows. |
| **03** | `latency` | Performance Metric | **High Value.** Establishes that the tool focuses on input latency, interrupt latency, and responsiveness rather than generic disk cleanup. |
| **04** | `gaming-optimization` | Target Audience | **High Intent.** Ranks repository for competitive gamers searching for stutter fixes, frametime consistency, and input lag reduction. |
| **05** | `dpc-latency` | Technical Niche | **Precision Keyword.** Highly searched by competitive esports players and audio engineers fixing driver DPC spikes and crackles. |
| **06** | `msi-mode` | Hardware Feature | **Technical Niche.** Direct match for users searching for Message Signaled Interrupts configuration for GPUs and network cards. |
| **07** | `powershell` | Technology Stack | **Developer Discovery.** Attracts PowerShell developers and sysadmins looking for clean, auditable PowerShell 5.1/7 code. |
| **08** | `low-latency` | Performance Metric | **Core Positioning.** Aligns with low-latency computing, kernel scheduling, and realtime gaming workflows. |
| **09** | `system-tweaks` | Functional Scope | **Broad Reach.** Discovers users wanting customizable OS settings, explorer tweaks, and context menu restoration. |
| **10** | `open-source` | Trust & Governance | **Trust Signal.** Distinguishes our transparent, auditable repository from closed-source or malware-laden "FPS boosters". |
| **11** | `performance-tuning` | Engineering Domain | **Professional Reach.** Standard terminology used by system builders, benchmarkers, and hardware enthusiasts. |
| **12** | `competitive-gaming` | Target Persona | **Persona Alignment.** Targets esports players in titles like CS2, Valorant, Apex Legends, and Overwatch 2. |
| **13** | `debloat-windows-11` | Feature Domain | **High Trend Volume.** Trending keyword for disabling Windows 11 AI Recall (24H2), Copilot, Bing Start search, and telemetry. |
| **14** | `hags` | Hardware Feature | **Feature Specific.** Attracts users configuring Hardware-Accelerated GPU Scheduling for DLSS 3 and FSR 3 frame generation. |
| **15** | `mpo-fix` | Bug Remediation | **High Pain Point.** Captures users searching for solutions to Multi-Plane Overlay display flicker, black screens, and Discord stutters. |
| **16** | `timer-resolution` | System Kernel | **Technical Feature.** Captures searches for Win32 timer resolution queries (`NtQueryTimerResolution`) and timer tick frequency. |
| **17** | `standby-ram-cleaner`| Memory Management | **High Pain Point.** Direct keyword for gamers experiencing memory allocation hitching in Escape from Tarkov, Rust, and Battlefield. |
| **18** | `dns-over-https` | Networking | **Feature Specific.** Highlights our Anycast DNS benchmark and 1-click encrypted DoH switching capabilities. |
| **19** | `rollback-engine` | Safety & Trust | **Core Differentiator.** Emphasizes our 2-tier failsafe rollback system (System Restore Points + JSON registry snapshots). |
| **20** | `esports-fps` | Niche Community | **Gaming Discovery.** Connects with competitive community hubs seeking frametime stability over placebo boosts. |

---

## 3. Rejected Topics & Elimination Rationale

To ensure maximum ranking efficiency, the following candidate topics were evaluated and deliberately rejected:

- ❌ `fps-boost` / `fps-booster`: High search volume, but attracts low-quality traffic, conveys a spammy "snake oil" image, and triggers skepticism from serious developers.
- ❌ `registry-hacks`: Carries negative connotations of amateur, dangerous registry tampering.
- ❌ `anti-lag`: Ambiguous; often confused with AMD Radeon Anti-Lag driver feature or game mods.
- ❌ `windows10`: Windows 11 Master Optimizer contains 24H2-specific logic (Recall, Copilot); branding it as Windows 10 dilutes our modern focus.

---

## 4. How to Apply Repository Topics

### Method 1: Using GitHub Web UI
1. Navigate to the repository root: `https://github.com/1hote-ai/win11-master-optimizer`.
2. On the right sidebar, click the **⚙️ (Settings cog)** next to **About**.
3. Under **Topics**, paste the 20 approved tags separated by spaces.
4. Click **Save changes**.

### Method 2: Using GitHub CLI (`gh`)
```bash
gh repo edit 1hote-ai/win11-master-optimizer --add-topic "windows-11" --add-topic "windows-optimizer" --add-topic "latency" --add-topic "gaming-optimization" --add-topic "dpc-latency" --add-topic "msi-mode" --add-topic "powershell" --add-topic "low-latency" --add-topic "system-tweaks" --add-topic "open-source" --add-topic "performance-tuning" --add-topic "competitive-gaming" --add-topic "debloat-windows-11" --add-topic "hags" --add-topic "mpo-fix" --add-topic "timer-resolution" --add-topic "standby-ram-cleaner" --add-topic "dns-over-https" --add-topic "rollback-engine" --add-topic "esports-fps"
```

### Method 3: Automated Synchronization Script
The repository provides `tools/Setup-GitHubLabels.ps1` with automated topics sync support via the `-IncludeTopics` flag:
```powershell
powershell -ExecutionPolicy Bypass -File .\tools\Setup-GitHubLabels.ps1 -IncludeTopics -DryRun
```
*(Run without `-DryRun` once approved by the project owner).*