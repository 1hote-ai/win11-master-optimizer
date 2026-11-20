# Support & Troubleshooting

Welcome to the **Windows 11 Master Optimizer** support guide. If you have questions, encounter an unexpected issue, or need help reverting a setting, follow the instructions below.

---

## 🔍 Self-Service Diagnostics & Quick Fixes

### 1. How do I verify my system status?
Run the built-in 26-point Health Audit to inspect all optimization parameters:
```powershell
powershell -ExecutionPolicy Bypass -File .\Win11Optimizer.ps1 -Mode HealthCheck
```

### 2. How do I immediately revert all changes?
If any optimization conflicts with your specific workflow or hardware:
```powershell
powershell -ExecutionPolicy Bypass -File .\Win11Optimizer.ps1 -Mode Rollback
```
Choose `[7] Full Rollback to Windows Defaults` to re-apply default Windows registry values and reset network configurations.

Alternatively, you can restore from the Windows System Restore Point automatically created during the launch:
1. Press `Win + R`, type `rstrui.exe`, and press **Enter**.
2. Select the restore point labeled `Win11Optimizer_Checkpoint_<timestamp>`.
3. Follow the wizard to return Windows to its pre-optimization state.

### 3. "Access Denied" or UAC Prompt Loops
The script requires Administrator privileges to modify system services, power schemes, and device interrupt affinities:
- Right-click `Start.bat` and select **Run as Administrator**.
- Ensure your user account belongs to the local `Administrators` group.

### 4. Running in Dry-Run Mode
If you want to verify what the script would change without touching your system:
```powershell
powershell -ExecutionPolicy Bypass -File .\Win11Optimizer.ps1 -Mode AutoGaming -DryRun
```

---

## 💬 Community Channels & Issue Reporting

- **Bug Reports:** If a feature does not work as expected or causes an error, submit a [Bug Report](https://github.com/1hote-ai/win11-master-optimizer/issues/new?template=bug_report.yml).
- **Hardware Compatibility:** If your specific GPU, Network Adapter, or Motherboard behaves unexpectedly with MSI Mode or Network tweaks, submit a [Compatibility Issue](https://github.com/1hote-ai/win11-master-optimizer/issues/new?template=compatibility_issue.yml).
- **Performance Feedback:** If you measured before/after benchmarks with CapFrameX, LatencyMon, or PresentMon, share them via [Performance Report](https://github.com/1hote-ai/win11-master-optimizer/issues/new?template=performance_report.yml).
- **Discussions & Q&A:** Join the [GitHub Discussions](https://github.com/1hote-ai/win11-master-optimizer/discussions) tab to discuss latency tuning, mouse polling rates, and game-specific configurations.
