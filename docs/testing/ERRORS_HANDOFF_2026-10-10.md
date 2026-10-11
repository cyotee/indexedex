# Error-fixing handoff — 2026-10-10

## Current status

- **All 1,522 original failing tests have passing evidence across the completed passes.**
- **All 30 additional R23 failures are fixed.**
- **All 15 active failures in the subsequent list (R24) are fixed** with test corrections. Fresh affected-suite validation: **301 passes / 0 failures across 9 suites**. See [third-pass report](ERRORS_THIRD_PASS_2026-10-10.md) and [per-test evidence](ERRORS_THIRD_PASS_EVIDENCE_2026-10-10.json).
- **The 17 previously deferred Balancer-hosted DETF failures are now fixed**, following explicit owner authorization (15 R02 + 2 R16). Latest validation: **875 tests passed / 0 failures across 87 suites**. See [fix report](BALANCER_DETF_REMAINING_ERRORS_FIXES_2026-10-10.md) and [per-test evidence](BALANCER_DETF_REMAINING_ERRORS_EVIDENCE_2026-10-10.json).
- Prior Balancer SE validation: **2,041 passing tests / 0 remaining failures across 231 suites**, reconciled from the broad run and its targeted follow-ups.
- All eight prior Balancer SE invariant campaigns pass: 256 runs / 16,384 calls each / zero reverts.
- Combined second-pass evidence: **9,100 distinct passing tests**. Earlier passes are retained unless superseded; this is not a fresh whole-repository run.
- Production artifacts build. All seven R23 runtime components fit EIP-170; the preceding funding pass checked 37 components.
- No active Forge process from this task. No changes committed, pushed or deployed.

## Fixed and verified

| Group | Area | Cases passing |
|---|---|---:|
| R01 | Native SY redemption fixtures | 25 |
| R02 | Zero-return preview expectations | 29 |
| R03 | FullSpread pricing/settlement assertions and rate contexts | 7 |
| R04 | BPT minimum deposit and preview rounding | 12 |
| R05 | Whole-supply rate providers | 8 |
| R06 | Selector coverage | 1 |
| R07 | Retained dust and later sweep fixture | 1 |
| R08 | Consumed-credit error precedence | 1 |
| R09 | Original weighted Permit2 truncation cases | 2 |
| R10 | Taxed staking funding | 3 |
| R11 | Morpho maxRedeem boundary | 1 |
| R12 | Aave capacity rounding | 1 |
| R13 | Partial investment / full reserve deployment | 3 |
| R14 | Camelot caller-separation fixture | 1 |
| R15 | Minimum vault-share deposits | 3 |
| R16 | Composed Balancer DETF exact-output entry validation | 2 |
| R17 | Runtime bytecode limits and redemption reuse | 16 |
| R18 | DETF residual/funded lifecycle cascade | 1389 |
| R19 | Orbital rounded partial intake | 10 |
| R20 | Later-bond residual deployment | 2 |
| R21 | Invariant campaigns and deterministic action witnesses | 2 |
| R22 | Reentrancy positive controls | 3 |

| R23 | Full-supply Balancer BPT valuation and bounded native liquidation | 30 newly exposed failures |

Additional funding fixes are complete: Curve Quad checked Permit2 amounts and exact receipts; Orbital exact receipts for direct, allowance, signature, flexible and single-asset deposit paths. All ten dedicated regressions and the 3,738-test affected batch pass.

The Balancer follow-up covers the plain constant-product SE, six native buffer families, the standalone external-BPT adapter, projected quotes, consumer matrices and native SY. Live previews, projected previews and execution share a native liquidation planner. Whole-supply valuation remains in the SE; the generic rate provider remains protocol-agnostic. Successful execution still matches its quote exactly.

The broad run exposed 96 setup failures caused by missing CREATE3 factory arguments in six transition-facet helpers; all are fixed and verified. Twelve decimal A/B reserve assertions now compare the reference pool against the exact representable virtual reserve; quote/execution checks were not relaxed. Forty-eight new regression cases pass.

R24 fixes: five buffered-output reference cases now include SE share rounding and exact delivery; three residual cases validate fallback deployment or fully booked retention; seven V3 selector cases distinguish the implementation-only delegate getter while asserting its absence on the proxy. Five test sources changed; no production changes.

## Not fixed

**None of the listed failures remain unresolved.** The 17 Balancer-hosted DETF cases were explicitly brought into scope and are fixed. Historical pass counts above are retained evidence, not a fresh whole-repository result.

## Resume

1. The requested 17-case Balancer DETF follow-up is complete. Use the [latest fix report](BALANCER_DETF_REMAINING_ERRORS_FIXES_2026-10-10.md) and its evidence for this scope.
2. Use the [latest remaining-errors report](ERRORS_THIRD_PASS_2026-10-10.md) for R24 and the [Balancer implementation report](BALANCER_SE_LIQUIDATION_IMPLEMENTATION_PLAN_2026-10-10.md) and [durable per-test evidence](ERRORS_SECOND_PASS_EVIDENCE_2026-10-10.json) for completed work.
3. Preserve unrelated workspace edits, task snapshots and completed logs. Use new run names for further changes.
4. After production edits, use the artifact-first workflow and one Forge writer at a time. Do not kill slow compilation.

## Decisions to preserve

- Rates quote the entire supply, including projected supply, through the SE abstraction.
- BPT SEs may quote native liquidation beyond underlying execution limits. Actual Vault/router execution retains those limits and reverts atomically.
- Use native single-asset withdrawals and at most nine planned native steps; no proportional-withdrawal/swap route was added.
- Deposits unable to mint one vault-share unit or BPT revert with a minimum error.
- Representable ownership of undeployable dust stays locally booked; withdraw locally first and sweep later when deployable.
- Deploy eligible reserves except documented sleeves.
- Unattainable alignment reverts; preserve holder protection and exact quote/execution parity.
- Fee-on-transfer underlyings are forbidden.
- The 17 Balancer-hosted DETF fixes are owner-authorized and complete. A broader family redesign was not part of this fix pass.

## Evidence and workspace

- [Implementation report](ERRORS_SECOND_PASS_2026-10-10.md), [diagnosis](ERRORS_DIAGNOSIS_2026-10-09.md), [original implementation plan](ERRORS_IMPLEMENTATION_PLAN_2026-10-09.md).
- [Durable per-test evidence](ERRORS_SECOND_PASS_EVIDENCE_2026-10-10.json) preserves the funding follow-up and adds final Balancer suite results, hashes and runtime sizes.
- [Final Balancer validation](../../.scratch/errors-second-pass-2026-10-09/r23-final-validation.json): 231 suites, final source hashes and runtime sizes.
- Broad: `r23-liquidation-broad.log` — 1,072 passes / 96 setup failures; all eight invariants pass.
- Factory follow-up: `r23-liquidation-factory.log` — 957 passes / 12 decimal-reference failures; all setup failures resolved.
- Decimal follow-up: `r23-liquidation-decimals.log` — 48 passes / 0 failures; remaining assertions resolved.
- Logs and matching command/source-hash JSONs are under `.scratch/errors-second-pass-2026-10-09/`.
- R23 snapshots and its 25-file change manifest: `.scratch/r23-authorized-2026-10-10/`.
- Combined earlier edits: `.scratch/errors-second-pass-2026-10-09/changes.json`, `added-paths.json`, `before/`, `pass.diff`. The workspace also contains extensive pre-existing edits.
- Reconciliation retains earlier results unless superseded and includes only completed runs. `setUp` failures are represented in run summaries; final per-suite reconciliation verifies all affected fixtures succeeded.
- Runtime headroom remains tight in unrelated V4 input delegates and Aerodrome query components; preserve the existing size gates.
- No full-repository green run or audit-ready status is claimed.
