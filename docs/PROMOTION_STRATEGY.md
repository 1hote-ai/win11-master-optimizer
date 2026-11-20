# 🚀 Comprehensive Multi-Channel Promotion Strategy

**Product:** Windows 11 Master Optimizer  
**Core Growth Objective:** Build a trusted, long-term international open-source community around the tool, converting organic video and written traffic into genuine GitHub stars, active testers, Issues, and PR contributors.

---

## PART 1. YOUTUBE SHORTS STRATEGY

YouTube Shorts is the primary visual discovery engine. Competitive gamers and Windows enthusiasts respond to concrete visual comparisons, micro-benchmarks, and transparent terminal workflows.

### 1.1. Twenty Short Video Ideas

| # | Working Title | Core Topic / Hook | Target Pain Point |
| :--- | :--- | :--- | :--- |
| **01** | "Why your mouse feels heavy in CS2" | MSI Mode vs Line-based IRQ interrupts | Input delay, sensor floatiness at high polling rates |
| **02** | "The Windows 11 24H2 AI Recall mystery" | Disabling background Recall snapshots | Privacy and background SSD/NPU churn |
| **03** | "Why Discord makes your game stutter" | DWM Multi-Plane Overlay (MPO) bug | Discord/OBS hardware acceleration stuttering |
| **04** | "The Standby RAM bug Tarkov players hate" | In-memory NT-Kernel `NtSetSystemInformation` | Memory allocation hitches when standby list fills |
| **05** | "Are Windows 'FPS Boost' batch files malware?" | Code comparison: Shady scripts vs Open Source | VirusTotal alerts, broken Windows installations |
| **06** | "How to benchmark your Gaming DNS in 5 seconds" | Anycast DNS benchmark + DoH Switcher | Packet routing jitter, hit registration delay |
| **07** | "Stop Windows Update from nuking your GPU driver"| `ExcludeWUDriversInQualityUpdate` policy | Stable custom driver overwritten by generic Windows update |
| **08** | "What does Win32PrioritySeparation actually do?" | CPU quantum scheduling breakdown | Foreground game thread priority vs background services |
| **09** | "The 7 GB hidden cache on your Windows PC" | Safe shader cache purge (DXCache/GLCache) | Game stutter after graphics driver updates |
| **10** | "How to get the classic context menu in 1 click" | CLSID `{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}` | Slow, double-click Windows 11 context menu |
| **11** | "Why high-polling 4000Hz mice stutter" | USB Selective Suspend and sleep states | USB hub power-saving throttling sensor packets |
| **12** | "Can tweaking Windows get you banned in Valorant?" | Whitelisted Windows APIs vs DLL injection | Vanguard / EAC / BattlEye safety explanation |
| **13** | "The 2-tier rollback safety test" | Simulating full system revert to defaults | Fear of breaking Windows with optimizer |
| **14** | "Is Windows Automatic Maintenance killing your FPS?" | Disabling `MaintenanceDisabled = 1` | Sudden mid-game FPS drops while gaming |
| **15** | "Does disabling VBS actually give you more FPS?" | Honest benchmark: When VBS matters & when it doesn't | Older CPUs vs newer CPUs with MBEC |
| **16** | "The hidden 20% network throttle in Windows" | `NetworkThrottlingIndex = 0xFFFFFFFF` | Windows throttling non-multimedia network packets |
| **17** | "Testing Windows 11 24H2 with 26-point Health Audit" | Live health check score in terminal | Audit verdict and optimization percentage |
| **18** | "Why Borderless Windowed mode stutters without this" | DirectX Windowed AutoPlayMode=1 optimization | Borderless vs Fullscreen Exclusive latency difference |
| **19** | "How to clean debloat Windows 11 without breaking Store" | Safe UWP removal with strict whitelist | Broken Microsoft Store and Xbox app after debloat |
| **20** | "Dry-Run mode: Previewing every registry edit" | `-DryRun` CLI parameter demonstration | Fear of black-box changes |

---

### 1.2. Ten Production-Ready YouTube Shorts Scripts

#### 🎬 Script 1: "Why your mouse feels heavy in CS2 (MSI Mode)"
- **Duration:** 32 seconds
- **Title:** Why Your Gaming Mouse Feels Heavy in Windows 11 🖱️⚡ (MSI Mode Fix)
- **First 2 Seconds (Visual & Audio Hook):**  
  *Camera shows close-up of gaming mouse moving fast on glass pad, with sound of heavy dragging.*  
  **Audio:** *"Ever feel like your mouse is moving through mud even on 1000Hz?"*
- **Screen Recording Actions:**  
  1. (0:03 - 0:10) Open Device Manager -> View by Connection -> Show GPU and Network card sharing standard IRQ line.
  2. (0:11 - 0:20) Launch `Win11Optimizer.ps1` -> Select Option `[3] HARDCORE GAMING LATENCY` -> Run `Set-GamingMsiMode`. Terminal displays: `[OK] MSI Mode: ON | Priority: HIGH (3)`.
  3. (0:21 - 0:27) Show LatencyMon graph showing DPC interrupt drop from 1400 µs to 85 µs.
  4. (0:28 - 0:32) Show GitHub repository page with 1-click download link.
- **Voiceover Script:**  
  *"By default, Windows 11 forces your GPU and Network card onto legacy line-based interrupts that share CPU cycles with other devices. This causes DPC latency queues and sensor micro-delays. Windows 11 Master Optimizer migrates your hardware to Message Signaled Interrupts with High Priority in one click. Open source, with instant rollback. Link on GitHub."*
- **Description:**  
  Fix mouse input lag and DPC interrupt queue latency in Windows 11 using MSI Mode. 100% open-source PowerShell suite: https://github.com/1hote-ai/win11-master-optimizer #Windows11 #CS2 #GamingSetup #Latency #PCGaming

---

#### 🎬 Script 2: "The DWM Stutter Bug Discord & OBS create"
- **Duration:** 30 seconds
- **Title:** Fix Stuttering When Discord or OBS is Open (DWM MPO Fix) 🖥️
- **First 2 Seconds (Hook):**  
  *Split screen showing butter-smooth 240Hz game, then sudden screen tearing the second Discord opens on monitor 2.*  
  **Audio:** *"Opening Discord or YouTube while gaming causes micro-stutter. Here's why."*
- **Screen Recording Actions:**  
  1. (0:03 - 0:09) Show Windows DWM Multi-Plane Overlay glitching when video decodes alongside 3D render.
  2. (0:10 - 0:19) Terminal opens: `.\Win11Optimizer.ps1 -Mode GpuOnly`. Show `OverlayTestMode = 5` successfully configured.
  3. (0:20 - 0:26) CapFrameX frametime graph: irregular frametime spikes completely smoothed out.
  4. (0:27 - 0:30) GitHub banner with star button highlighted.
- **Voiceover Script:**  
  *"It's called the MPO bug. Windows Desktop Window Manager tries to render hardware-accelerated video overlays on top of your 3D game, causing GPU desync. Win11 Master Optimizer disables faulty MPO layers while keeping Fullscreen optimizations intact. Get it on GitHub!"*
- **Description:**  
  Stop micro-stuttering in borderless games caused by Discord, OBS, and Chrome hardware acceleration. GitHub repo: https://github.com/1hote-ai/win11-master-optimizer #PCGaming #OBS #TechTips #Windows11

---

#### 🎬 Script 3: "The Standby RAM Leak Tarkov & Rust Players Know"
- **Duration:** 35 seconds
- **Title:** Free Gigabytes of Standby RAM Without Sketchy EXEs 🧠⚡
- **First 2 Seconds (Hook):**  
  *Task Manager Memory tab showing 31.8 GB in Standby cache and 200 MB free.*  
  **Audio:** *"Windows says you have 32 gigs of RAM, but games are hitching? Look at this."*
- **Screen Recording Actions:**  
  1. (0:03 - 0:10) Task Manager Resource Monitor showing massive standby list.
  2. (0:11 - 0:21) Terminal executes: `.\Win11Optimizer.ps1 -Mode RamClean`.
  3. (0:22 - 0:28) Console outputs: `[OK] Standby List & Working Sets purged via NtSetSystemInformation. Memory freed: 14,250 MB`. Task Manager graph plunges down to free space.
  4. (0:29 - 0:35) Code snippet highlighted showing clean C# P/Invoke, zero third-party EXEs.
- **Voiceover Script:**  
  *"Windows caches files in your Standby RAM. But in heavy games like Escape from Tarkov or Rust, allocating new memory forces Windows to clear standby blocks on-the-fly, dropping frames. Instead of downloading sketchy third-party cleaners, our optimizer calls the native NT-Kernel directly from memory. 100% open source."*
- **Description:**  
  Purge cached Standby RAM and working sets natively in Windows 11. No sketchy background utilities. GitHub: https://github.com/1hote-ai/win11-master-optimizer #Tarkov #Rust #PCMasterRace #Windows11

---

#### 🎬 Script 4: "Shady 'FPS Boost' Packs vs. Clean Open Source"
- **Duration:** 38 seconds
- **Title:** Why You Should NEVER Download "FPS Boost.bat" Files ⚠️❌
- **First 2 Seconds (Hook):**  
  *Red flashing warning icon over generic "1000% FPS BOOST PACK MAX.RAR" folder.*  
  **Audio:** *"Stop downloading random zip files from YouTube descriptions."*
- **Screen Recording Actions:**  
  1. (0:03 - 0:11) Open shady batch file in Notepad: show broken commands like `"$env:SystemRoot..."` and hardcoded registry deletes with no backup.
  2. (0:12 - 0:22) Contrast with `Win11Optimizer.ps1`: clean PowerShell modules, strict typing, automated Restore Point creation.
  3. (0:23 - 0:30) Show `Backups/` directory with clean JSON snapshots for 1-click rollback.
  4. (0:31 - 0:38) Call to action: "Star the repo on GitHub".
- **Voiceover Script:**  
  *"Most YouTube optimizers are copy-pasted batch scripts from 2012 that break Microsoft Store, corrupt your network stack, and have zero rollback. Win11 Master Optimizer is fully open source. It creates a Windows Restore Point and saves JSON registry snapshots before changing a single byte. Revert anytime in 1 click."*
- **Description:**  
  Protect your Windows 11 installation. Never run opaque batch scripts. Check the code on GitHub: https://github.com/1hote-ai/win11-master-optimizer #CyberSecurity #OpenSource #PCGaming #Windows11

---

#### 🎬 Script 5: "Gaming DNS Benchmark in 5 Seconds"
- **Duration:** 28 seconds
- **Title:** Find the Fastest DNS for Gaming in 1 Click 🌐⚡
- **First 2 Seconds (Hook):**  
  *Terminal pinging DNS servers with real-time green/red latency counters.*  
  **Audio:** *"Is your default ISP DNS adding 30ms of latency to your game servers?"*
- **Screen Recording Actions:**  
  1. (0:03 - 0:09) Run `.\Win11Optimizer.ps1 -Mode DnsBenchmark`.
  2. (0:10 - 0:18) Dynamic table appears: Cloudflare (1.1.1.1) 4.2ms, Quad9 11ms, Google 14ms, Default ISP 42ms.
  3. (0:19 - 0:24) Select 1 -> DNS-over-HTTPS (DoH) encrypted protocol enabled automatically on active Ethernet adapter.
  4. (0:25 - 0:28) GitHub repository URL on screen.
- **Voiceover Script:**  
  *"Stop guessing which DNS is best. Our built-in Gaming DNS Benchmark live-tests Cloudflare, Google, Quad9, and AdGuard. Then switches your active adapter to encrypted DNS-over-HTTPS in one second. Revert to DHCP anytime. Try it on GitHub!"*
- **Description:**  
  Benchmark gaming DNS servers and enable DoH encryption in Windows 11. GitHub: https://github.com/1hote-ai/win11-master-optimizer #Networking #GamingPing #TechTips

---

#### 🎬 Script 6: "Windows 11 24H2 Recall: How to Truly Disable It"
- **Duration:** 30 seconds
- **Title:** How to Completely Disable AI Recall in Windows 11 24H2 🛡️
- **First 2 Seconds (Hook):**  
  *Windows 11 24H2 desktop showing Recall screenshot preview.*  
  **Audio:** *"Windows 11 24H2 takes screenshots of your screen every few seconds."*
- **Screen Recording Actions:**  
  1. (0:03 - 0:08) Show Windows AI Recall component active in DISM.
  2. (0:09 - 0:18) Launch `Win11Optimizer.ps1` -> Select `[6] SMART DEBLOAT` -> Run `Disable-Win11Recall`.
  3. (0:19 - 0:25) Show DISM feature disabled + policy `DisableAIDataAnalysis = 1` applied to both HKLM and HKCU.
  4. (0:26 - 0:30) GitHub repository screen.
- **Voiceover Script:**  
  *"Microsoft's AI Recall monitors everything you do. Our open-source debloat module disables Recall at the core level through Windows Optional Features and enforces system-wide AI data analysis blocks. Zero background churn. Zero bloat. Full source on GitHub."*
- **Description:**  
  Cleanly disable Microsoft Recall and Copilot in Windows 11 24H2. 100% open source: https://github.com/1hote-ai/win11-master-optimizer #Windows11 #Privacy #Debloat #TechTips

---

#### 🎬 Script 7: "Stop Windows Update From Replacing GPU Drivers"
- **Duration:** 28 seconds
- **Title:** Stop Windows Update from Ruining Your GPU Driver! 🎮🛑
- **First 2 Seconds (Hook):**  
  *Windows Update pop-up: 'Installing Display Driver...' over a game crash screen.*  
  **Audio:** *"Ever tuned a perfect graphics driver, only for Windows Update to silently overwrite it?"*
- **Screen Recording Actions:**  
  1. (0:03 - 0:08) Show Windows Update history installing an outdated OEM display driver.
  2. (0:09 - 0:18) Optimizer runs: `Set-WindowsUpdateDriverProtection` -> `ExcludeWUDriversInQualityUpdate = 1` set in policies.
  3. (0:19 - 0:24) Windows Update checked: security patches work, graphics drivers untouched.
  4. (0:25 - 0:28) GitHub link display.
- **Voiceover Script:**  
  *"Windows Update loves replacing custom Nvidia or AMD drivers with generic buggy versions. Win11 Master Optimizer sets driver exclusion policies with one click: you keep security updates, but Windows Update can never touch your GPU driver again. Grab it on GitHub."*
- **Description:**  
  Lock your stable GPU drivers from being overwritten by Windows Update. GitHub: https://github.com/1hote-ai/win11-master-optimizer #Nvidia #AMD #PCGaming #TechHacks

---

#### 🎬 Script 8: "The 26-Point Windows 11 Health Audit"
- **Duration:** 33 seconds
- **Title:** Audit Your Windows 11 Gaming Health in 10 Seconds 🩺💻
- **First 2 Seconds (Hook):**  
  *Terminal text scrolling rapidly, landing on a high-tech cyan/green audit report card.*  
  **Audio:** *"Is your Windows 11 properly configured for competitive gaming? Let's check."*
- **Screen Recording Actions:**  
  1. (0:03 - 0:10) Run `.\Win11Optimizer.ps1 -Mode HealthCheck`.
  2. (0:11 - 0:22) Watch 26 parameters get audited live: MSI mode, CPU quantums, DWM MPO, Nagle, timer resolution, VBS status.
  3. (0:23 - 0:28) Audit summary: `OPTIMIZATION SCORE: 58% [!] 11 Actions Recommended`. Press `1` to optimize all.
  4. (0:29 - 0:33) Score transitions to `100% [✓] Optimal`. GitHub link CTA.
- **Voiceover Script:**  
  *"Stop wondering if your PC has the right settings. Our automated 26-point Health Audit scans your GPU, network stack, CPU scheduling, and DWM in seconds. It shows exactly what's suboptimal and fixes it with full rollback safety. Check your score on GitHub!"*
- **Description:**  
  Run an instant 26-point health audit on your Windows 11 gaming PC. GitHub: https://github.com/1hote-ai/win11-master-optimizer #Windows11 #GamerSetup #TechTok

---

#### 🎬 Script 9: "The Hidden 7GB Shader Cache That Causes Stutter"
- **Duration:** 30 seconds
- **Title:** Why You Should Clear Your DirectX & Nvidia Shader Cache 🧹📁
- **First 2 Seconds (Hook):**  
  *Folder showing 4,800 files taking up 8.4 GB inside AppData\Local\NVIDIA\DXCache.*  
  **Audio:** *"Updated your graphics driver recently? You might have gigabytes of corrupted shader cache."*
- **Screen Recording Actions:**  
  1. (0:03 - 0:08) Show micro-stutters during camera turns in Cyberpunk / CS2.
  2. (0:09 - 0:19) Run `Clear-ShaderCacheAndTemp` inside the optimizer. Terminal scans NVIDIA DXCache, GLCache, Direct3D, and Temp.
  3. (0:20 - 0:25) Console displays: `[OK] Cleaned 4,912 files (~7.82 GB freed)`.
  4. (0:26 - 0:30) Smooth 1% low frametimes graph shown. GitHub link.
- **Voiceover Script:**  
  *"When games update or you change GPU drivers, old compiled shaders don't always get deleted. They accumulate into gigabytes of stale cache, causing shader re-compilation stutter. Win11 Master Optimizer safely cleans all DirectX, OpenGL, and temp caches in seconds. Star it on GitHub!"*
- **Description:**  
  Purge corrupt DirectX and Nvidia shader cache to fix game hitching. GitHub: https://github.com/1hote-ai/win11-master-optimizer #ShaderCache #PCGaming #TechTips

---

#### 🎬 Script 10: "Can You Undo Everything? The Rollback Engine"
- **Duration:** 32 seconds
- **Title:** The Only Windows Optimizer You Can 100% Undo 🔄🛡️
- **First 2 Seconds (Hook):**  
  *Hands typing on mechanical keyboard, pressing 'Rollback to Windows Defaults'.*  
  **Audio:** *"What happens if an optimizer ruins your Windows installation?"*
- **Screen Recording Actions:**  
  1. (0:03 - 0:09) Show traditional tweakers having zero undo options.
  2. (0:10 - 0:20) Launch `.\Win11Optimizer.ps1 -Mode Rollback`. Select `[7] Full Rollback to Windows Defaults`.
  3. (0:21 - 0:27) Show JSON snapshots reading original states and restoring every single registry key and network adapter to factory settings.
  4. (0:28 - 0:32) GitHub repository banner with 'Verified Safe' badge.
- **Voiceover Script:**  
  *"Most optimizers change hundreds of keys and leave you stranded. We built a 2-tier rollback engine. Before touching anything, it creates an official Windows Restore Point and JSON snapshots of every single value. Click rollback, and your system returns exactly to stock Windows defaults. Trust the source on GitHub."*
- **Description:**  
  Experience safe, completely reversible Windows 11 optimization. GitHub: https://github.com/1hote-ai/win11-master-optimizer #Windows11 #TechTok #OpenSource

---

## PART 2. TIKTOK STRATEGY

TikTok audiences value authenticity, "behind-the-scenes" development stories, and direct interaction with the developer.

### 2.1. Content Pillars
1. **Dev Logs & Building in Public (30%):** Sharing the engineering challenges of reverse-engineering Windows 11 24H2, writing P/Invoke in PowerShell, and dissecting Microsoft NT-kernel APIs.
2. **"Myth Busters" Series (35%):** Taking popular gamer urban legends (e.g., "Timer Resolution placebo", "Deleting System32", "ParkControl scam") and testing them scientifically.
3. **Feature Spotlights & Micro-Tutorials (20%):** Step-by-step guides on single topics (e.g., how to check your timer resolution with `NtQueryTimerResolution`).
4. **Community Reactions & QA (15%):** Stitching comments and answering questions like *"Does this work on laptops?"* or *"Will Vanguard ban me?"*.

### 2.2. Production Formats
- **Face + Screen Split:** Creator wearing headset explaining the bottleneck while screen recording shows the actual terminal code.
- **Interactive Stitches:** Stitching viral clips of people giving terrible Windows advice and demonstrating the correct, scientific solution.
- **Audio Trend Integration:** Subtly incorporating trending high-tech synthwave audio tracks at low volume under clear voiceovers.

---

## PART 3. REDDIT OUTREACH STRATEGY

Reddit communities demand high technical substance and will ban self-promoters who drop generic spam links. The key is to **lead with genuine educational value, code snippets, and benchmark data**.

### 3.1. Subreddit Rules & Etiquette Analysis

| Subreddit | Self-Promotion Rules & Limits | Safe Approach |
| :--- | :--- | :--- |
| **r/Windows11** | Strictly no spam / low-effort self-promo. Open-source utilities welcome if source code is provided and discussion is technical. | Post as a "Show & Tell / Open Source Tool" detailing how 24H2 Recall and MPO were addressed via documented registry policies. |
| **r/opensource** | Must be 100% open-source with approved license. Commercial promotions prohibited. | Focus on architectural modularity, native NT-kernel P/Invoke implementation, and the 2-tier rollback mechanism. |
| **r/pcmasterrace** | OC (Original Content) flair required. Must provide direct value to users without monetized paywalls. | Post benchmark data comparing DPC latency before and after MSI Mode / Nagle tuning with CapFrameX charts. |
| **r/Competitiveoverwatch & r/cs2** | Sensitive to game integrity and anti-cheat policies. | Emphasize anti-cheat safety, zero DLL hooking, and empirical 1% Low frametime stability. |

---

### 3.2. Ready-to-Post Reddit Publications

#### 📝 Reddit Post 1: Open Source Show & Tell (r/opensource & r/Windows11)
**Title:** `I built an open-source, fully reversible Windows 11 latency & diagnostic suite with native NT-kernel RAM purging (Zero snake oil / 24H2 ready)`

**Body:**
```markdown
Hey everyone,

Like many of you who play competitive games or produce audio on Windows 11, I’ve spent years looking at "gaming optimizers." The vast majority of them fall into two awful categories:
1. Shady `.bat` scripts full of broken syntax that delete core components and offer zero rollback.
2. Closed-source `.exe` utilities packed with bundled crapware or triggering false-positive alerts on VirusTotal.

A few months ago, we set out to build an engineering-grade alternative: **Windows 11 Master Optimizer**.

### What makes this different?
1. **100% Auditable Code:** Everything is written in modular PowerShell 5.1/7 with in-memory C# P/Invoke. No temporary binaries dropped on disk.
2. **Two-Tier Rollback Engine:** Before touching a single key, it overrides the Windows 24-hour throttle to generate a System Restore Point (`Checkpoint-Computer`) and saves JSON snapshots of every original registry value and type (`DWord`, `QWord`, `Binary`, etc.). Reverting everything to stock Windows defaults takes 1 click.
3. **Native NT-Kernel Memory Purging:** Instead of bundling suspicious utilities like `EmptyStandbyList.exe`, it acquires `SeProfileSingleProcessPrivilege` and calls `ntdll!NtSetSystemInformation` directly in memory to purge the cached Standby list.
4. **Hardware-Aware MSI Mode:** It interrogates the PCI bus and migrates GPU, Network, and Audio controllers to Message Signaled Interrupts with High Priority (`DevicePriority = 3`), eliminating shared line IRQ bottlenecks.
5. **Windows 11 24H2 Ready:** Disables Microsoft Recall (`DisableAIDataAnalysis = 1` + DISM optional feature), removes Copilot from the taskbar, and stops background MSN widgets.
6. **26-Point Health Audit & Dry-Run Mode:** Supports `-DryRun` so you can inspect every planned change before applying anything.

The project is completely free, transparent, and tested with a 34-assertion automated test suite.

GitHub Repository: https://github.com/1hote-ai/win11-master-optimizer

I’d love your critical feedback on our rollback implementation and suggestions for additional kernel diagnostics. Feel free to roast the code or submit issues!
```

---

#### 📝 Reddit Post 2: Technical Deep Dive (r/pcmasterrace)
**Title:** `Why typical "FPS Boost" scripts are placebo, and what actually reduces frametime spikes in Windows 11 (DPC latency, MPO, and MSI Mode)`

**Body:**
```markdown
There’s a massive misconception in the PC gaming community that tweaking the Windows registry can magically give you +50% average FPS. It won’t. If your GPU is rasterizing Cyberpunk 2077 at 99% load, changing a registry key won't give your GPU more compute units.

However, where Windows optimization **genuinely matters** is **frametime consistency and 1% / 0.1% lows**:

### 1. The DPC Interrupt Bottleneck (MSI Mode)
Traditional PCI devices use line-based interrupts (`IRQ`). Multiple devices (like your Realtek network card and GPU) can share the same interrupt line, causing Deferred Procedure Call (DPC) queue spikes when you download packets while rendering frames. Migrating both to Message Signaled Interrupts (`MSISupported = 1`) allows the hardware to write interrupts directly to CPU memory addresses, reducing interrupt queues from >1000 µs down to sub-100 µs.

### 2. The DWM Multi-Plane Overlay (MPO) Desync
If you run Discord, OBS, or Chrome on a secondary monitor, Windows DWM tries to render hardware-accelerated planes alongside your borderless game. Driver desync causes micro-stutters. Setting `OverlayTestMode = 5` in DWM fixes this without sacrificing Fullscreen optimizations.

### 3. Nagle's Algorithm in Modern Gaming
Windows defaults to buffering outgoing small TCP packets via Nagle's algorithm (`TcpAckFrequency` and `TcpDelAckTicks`). In competitive titles using TCP sockets, this introduces unnecessary network buffer delays.

We automated all of these verified tweaks (along with automatic restore points and JSON rollbacks) into our open-source project:
👉 https://github.com/1hote-ai/win11-master-optimizer

Full benchmark methodology and CapFrameX testing instructions are included in the repository docs.
```
