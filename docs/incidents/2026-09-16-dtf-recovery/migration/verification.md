# Migration implementation verification - November 13, 2026

Status: bounded integration passed; the independent whole-plan gate rejected completion with B1 indirect/nonisolated claims, B2 held-inventory recovery and B3 verification-record findings. Remediation is in progress. This is not deployment or allocation approval.

## Subject

Cumulative worktree: /Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-30-recovery-receipts.
Base: 1694e68a4bd66dd67d3b5e3f145f1da23074ff48 plus the current uncommitted implementation.
Dedicated locked review snapshot: /Users/cyotee/Projects/indexedex-wt/dtf-migration-final-review-20261113.
The current plan and PRD are preserved alongside this report. Their later owner clarifications govern older acceptance wording.

## Verified checks

| Check | Observed result | Evidence |
| --- | --- | --- |
| Full repository hermetic Solar build and tests | Exit 0; 28,604 passed, 0 failed, 0 skipped across 2,691 suites | Session monitor mon_G5A5QXSX6ZPKZZ28 / bash_154; final summary independently reread |
| Migration hermetic specifications | 199 passed | Current migration specification run; gas producer report in deployment-gas-resumed/report.md records the initial same 199 cases |
| Migration source forks | 165 distinct cases passed; original aggregate had one HTTP 429 setup failure, and that exact case passed separately with reduced concurrency | Parent verification after recovery donation correction; do not describe the aggregate attempt as clean |
| Operator tests | 180 passed, 0 failed | bash_158 test portion; subsequent rehearsal in that command failed donor sizing, not unit tests |
| Claim authenticator diagnostics | No errors | Native LSP on scripts/recovery/dtf-migration/claimed-sy.ts |
| Two independently replayed deployments | All 242 signed transactions succeeded with 32,000,000 gas envelopes | resumed-integration/bounded-final-20261113/transactions.json and constrained-receipts.json |
| Deployment node cleanup | Node exited, port 18561 | resumed-integration/bounded-final-20261113/cleanup.json |
| Complete direct-delegated operator lifecycle | Successful preparation/resume, configuration, activation, partial/final surrender and rollback | resumed-integration/runtime/rehearsal-1794602720815/ |
| Holder transfer does not veto activation | Assets transferred away; activation succeeded; absent-asset surrender reverted unchanged; assets returned without reconfiguration | Same run, claimed-holder-transfer-activation.json |
| Delegated negative authentication | Failed inner source call and multiple source calls rejected for those exact reasons; nonce unchanged | Expanded run rehearsal-1794605887095/claimed-intake-rejections.json |

Preparation gas for the independently replayed instances was 19,746,568 and 19,595,700; final publication used 29,858,973 and 29,297,677. This proves the tested constructions, not arbitrary future argument sizes.

## Correction to earlier evidence interpretation

The gas producer's donation-floor failure was reproducible against its immediate pre-gas snapshot, but not against the actual cumulative base 1694e68a. The parent's clean baseline reproduction passed. Therefore it was treated as an integration regression, not excused as pre-existing. The recovery donation implementation now isolates the selected amount while preserving previously recorded residual inventory. The original regression test was not weakened. The subsequent full hermetic gate and affected fork test passed.

## Completed final bounded integration

Expanded real-source run: resumed-integration/runtime/rehearsal-1794605887095/.
It adds full-original and conserved-remainder relayed EIP-7702 claims, actual signed delegation, source/vault/SY effects, rejecting NFT receivers and final funded surrender. Monitor mon_PA5MYM6H8GY8JEB5 / bash_159 completed with exit 0 and bounded-rehearsal-complete. Its cleanup.json records node exit and runtime removal.

Signer 236 delivered 155,563,510 plus 311,127,073, exactly its full original credit of 466,690,583. Signer 237 delivered 51,854,503 plus 103,709,024, exactly its one-third eligible credit of 155,563,527. Both terminal ledgers have zero remaining units and credit. Their partial records include real late-funding and delegated-receiver rollback transactions. The transfer/activation regression passed again. Operator preparation used 19,746,742 gas and final publication 29,860,017, each within its signed envelope and the 32,000,000 bound.

The first review snapshot includes the source ABI extraction, relayed claim authentication, intake negatives and transfer/activation regression. The independent whole-plan gate st_01a1d6de returned REJECT; its complete report is final-gate-review-20261113.md. Subsequent remediation is not covered by that frozen snapshot.

## Recovered execution provenance

The missing first-gate execution records are now archived under final-verification-recovered/. README.md reconciles every command and exit, including the exact HTTP 429 case and its successful isolated retry. execution-records.json retains original transcript events and complete expanded launch commands; source-snapshot.json preserves all 64 reviewed task-specific source replacements/additions against base 1694e68a, with complete bytes and SHA-256 fingerprints. compiled-recovery-inputs.json and source-bindings.json record all 117 matching compiled recovery dependencies.

Original truncation notices remain explicit: this recovery did not invent missing stdout or repeat an unchanged full suite. The 180 passing operator tests occurred before a later rehearsal failure in the same shell command; the corrected final rehearsal separately exited zero. The later TypeScript/fixture changes are not retroactively attributed to the earlier hermetic Forge run. These records address B3's missing provenance; B1/B2 and final remediation verification remain open.

## Operational and historical boundaries

- No public deployment, funding, issuance, activation or legacy-governance transaction was sent.
- Local synthetic original contributions and excluded-weight partitions demonstrate code behavior, not financial eligibility.
- Weighted NFT 3 retains separate WETH and DTF contributions, separately frozen quotes and two funded compensation bonds on one atomic eligible surrender.
- Conserved TokenStaking remainder credit is the full-original quote multiplied by eligible/original weight, not a nonlinear re-quote of reduced contributions.
- Current source authentication additionally supports authenticated indirect, nonisolated claims using exact transaction-prefix state. The historical indirect EntryPoint claim at block 71862410 remains unadmitted because its required evidence is unavailable. Its historical trace was not retried, and no RPC tier/provider was changed.
- Disabled or owner-restricted legacy conversion stays custody-and-hold unless a genuine callable route has been demonstrated. No successful liquidation is inferred from custody alone.
- Historical source evidence, failed runs, review worktrees and warm artifacts remain retained. Cleanup and full-plan closure have not been marked complete.

## Remediation verification, current source

The rows above describe the preserved first review, not the final remediation tree. The current source snapshot is final-source-20261113.json, SHA-256 b994f59fb0a1c074e3373728e1b4af06f30790e6b47032f9198c8136e32e3bbe, containing 91 source/configuration/requirements files. The complete command recorder is resumed-integration/record-verification.ts. Each run retains environment.json, results.json and full per-command logs with command/exit receipts.

| Current check | Result | Evidence |
| --- | --- | --- |
| Full hermetic build and tests | Exit 0; 28,604 passed, zero failed/skipped, 2,691 suites | final-hermetic-r2-20261113/results.json and 04.log |
| Operator strict TypeScript and unit tests | Exit 0; 194 passed, zero failed | final-operator-20261113/results.json and 03.log/04.log |
| Full reward-only operator rehearsal | Exit 0; complete lifecycle, retained matured principal and NFTs | final-reward-operator-20261113.log and resumed-integration/runtime/rehearsal-1794614635102/ |
| Retained old bonds across later reward harvests | Weighted NFTs 4/26 principal 281387179/56299 and claimedPrincipal 0 unchanged; earlier NFT 3 originalShares 562524912595035608166 unchanged; all owners unchanged | Same run, reward-harvest-retention.json |
| Earlier repeated reward income | Recorded reward amount increases from 124873542679524901 to 125668871186465288 after genuine external income; not merely elapsed time | Same retention record, including local prerequisite transaction receipts |
| Rehearsal teardown | Node exited and disposable runtime removed; evidence retained | Same run, cleanup.json |

The earlier receipt, liquid ED, SE and weighted LP recovery additions and sole earlier-physical-LP permanent-custody disposition are detailed in recovery-route-disposition.md. Final aggregate forks, the updated two-instance gas envelope witness and a fresh independent review remain pending. The source-bound first REJECT is preserved and is not overwritten by these passing checks.
