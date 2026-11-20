## Description of Changes
<!-- Provide a clear, technical summary of the proposed changes -->

## Motivation & Context
<!-- Why is this change required? What issue does it fix or what optimization does it introduce? -->

## Empirical Proof & Research
<!-- Reference Microsoft documentation, RFCs, CapFrameX benchmarks, or LatencyMon logs -->

## Safety & Rollback Verification
<!-- Every system modification must be backed up and reversible -->
- [ ] Supports `-DryRun` preview mode without side effects.
- [ ] Saves pre-change state via `Save-RegistrySnapshot` or equivalent before applying changes.
- [ ] Verified that rolling back through `Restore-RegistrySnapshot` restores the original key and value.
- [ ] Tested on Windows 11 (specify build: 22H2 / 23H2 / 24H2).
- [ ] Ran automated smoke test suite: `Test-Win11Optimizer.ps1` (0 failures).

## Type of Change
- [ ] Bug fix (non-breaking change which fixes an issue)
- [ ] New optimization / module feature (non-breaking change which adds functionality)
- [ ] Breaking change (fix or feature that alters existing behavior or CLI parameters)
- [ ] Documentation update
