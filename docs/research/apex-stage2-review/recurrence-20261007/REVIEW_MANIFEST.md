# APEX repository-wide recurrence verification

Stage 1 is complete and accepted. The owner explicitly instructed agents not to ask again. The report in `../accepted-20261007/` is preserved as the first inspection wave.

On 2026-10-07 the owner required full repository review for recurrence of APEX mistakes in current, new and changed code; verification of all gaps in this session; and identification of all problems/regressions. Source inspection, local builds, tests, necessary verification harnesses and evidence generation are authorized. This supersedes inspection-only restrictions for this continuation. Production fixes, deployments and automatic remediation planning remain outside scope. Existing user edits and historical evidence are preserved.

The parallel plan continues with the same reviewers: vaults owns V3/V4 FullSpread and Wings; credit/lending owns custody, lending, receipts, AMM and staking; hooks owns buffer hooks, Balancer, providers and matrix domains. Coordinator owns remaining DETF/router/manager surfaces, policy reconciliation, source identity, build/test orchestration and consolidation. Shared `out/` and `cache_forge/` writes are serialized by the coordinator.

Capture source hashes before build/run; retain exact commands, tool versions, exit status and logs. Record verification additions as source drift. Production source remains unchanged by reviewers. Historical passes do not constitute current runtime evidence. Classify deprecated implementations explicitly. Distinguish legal matrix domains from executed cases and failures from setup limitations or authority conflicts.

Status: IN_PROGRESS.
