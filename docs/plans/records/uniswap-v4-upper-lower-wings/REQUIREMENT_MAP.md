# Requirement map — implementation in progress

Source authority: PRD v0.4 owner rulings, then v0.3 addendum and named execution plan. File suffixes below use the full product prefix in W/T from SCOPE_MANIFEST.md. Partial math coverage is not a passed product security requirement.

## Current implementation map

The historical foundation table below is retained as checkpoint evidence. This
section supersedes its implementation-status descriptions. No release gate is
claimed complete; test additions in the active run remain unverified until that
run exits successfully.

| Requirements | Current production | Tests and remaining coverage |
| --- | --- | --- |
| A1, V1–V2, SEC-13, RV-1 | LiquidationQuote; Common; Query | Real removal/sale parity, all-own/no-depth, partial fill, overlaps, fees, directional ticks, bounded-work rejection pass. Maximum outer consumer gas pending. |
| A2, V3–V4, RV-2, RV-6 | Accounting; Money; DFPkg | Target-only issue, first-depositor residuals, positive-value floor, exact-output ceilings, both orientations pass. Manipulation/JIT matrix pending. |
| A3, G1–G3, RV-4 | Geometry; Inventory; Harvest | Strict wing placement, actual tick capacity, converted-principal harvest, fees-only negative, projection/execution parity pass. Extended lifecycle invariants newly added. |
| C1–C4, SEC-01–04 | Repo; Money; In/Out targets | Pull, bounded contract push, no-transfer/replay negatives, exact-output refund liability and donation separation pass. Trade-before-fake-push and victim-cycle variants remain. |
| C5–C7, SEC-06–07 | Inventory; ExecutionDelegate; Harvest; Money | Fee growth/modular arithmetic, real callerDelta settlement, owned slots and custody pass. Hostile-token and stateful suites newly added. |
| V5–V6, SEC-14, RV-3 | Money ordered funding; Accounting; Quote swap-cost bound | Fixed entitlement and terminal exit pass. Partial-exit rounding witness preserved; dynamic cost-bound fix under active validation. Full stage-order/overshoot suite pending. |
| S1–S3, SEC-16, RV-5 | Oracle-backed Harvest sleeve; Money blocked path | Local-only nested deposit/covered exit, insufficient-cover rollback, effective-zero one-unit floor pass. Economic/transition context tests newly added. |
| A4, SEC-15, RV-7 | RebalancePlanner/Target | Actual core growth, oracle deficit restoration, repeated no-reward/loss-limited maintenance pass. Sandwich and extreme-fee progress bounds remain. |
| SEC-05, SEC-09 | Common callback commitment; ExecutionDelegate; Money guards | Wrong-manager/payload and late minimum rollback pass. Token callback, pause/blacklist, outbound FoT and negative-rebase tests newly added. |
| SEC-10 | Money inbound disable; shared SY delegation | Disabled inbound and continuing scalar exit implemented/tested; disabled SY path expansion pending. |
| SEC-11–12 | Immutable DFPkg, deterministic slots, narrow facet selectors | Registry/proxy/deployment rejection tests pass; expanded selector expectations, permit replay/domain and source-preservation checks in progress. |
| A5, SEC-08 | Canonical liquidation accounting and bounded execution | Depth-removal overmint, unrestored-depth, price round trip, JIT rebalance and blocked-entry witnesses passed. O1 permits proportional recovery; the old zero-profit assertion was rejected. Broader JIT/DETF matrix remains open. |
| S4, RV-8, PRD 9–10 | In/Out, SY, Transition, Economic facets | Scalar/SY tests pass; first sequential transition tests pass; projected partial-core exits, rate/sleeve views newly added. |
| PRD 12 | Real consumer fixtures | Weighted samples, Orbital, both quads, single/dual CP and a funded Wings DETF bond passed. Exhaustive masks and mixed-family permutations remain pending. |
| PRD 13–15 | Artifact builds and finite iteration limits | Artifact-size gate, estimated outer gas under 90% of 16,777,216, and FullSpread/Pons parity controls passed. Live chain receipts and an independent audit remain open. |

## Historical foundation checkpoint (superseded)

| Requirement | Source | Evidence / remaining work | Status |
| --- | --- | --- | --- |
| A1 | Pending | Plan phases 2–9; SPECIFICATION_DECISIONS.md | NOT IMPLEMENTED |
| A2 | No production issuance | reference/AccountingReference.t.sol; ACCOUNTING_AND_RECOVERY.md | POLICY RESOLVED by O1–O4; implementation/proofs pending |
| A3 | Pending | Plan phases 2–9; SPECIFICATION_DECISIONS.md | NOT IMPLEMENTED |
| A4 | Pending | Plan phases 2–9; SPECIFICATION_DECISIONS.md | NOT IMPLEMENTED |
| A5 | Pending | Plan phases 2–9; SPECIFICATION_DECISIONS.md | NOT IMPLEMENTED |
| G1 | Geometry.sol | Geometry.t.sol: exact/negative/extreme bounds and independent boundary search | PURE HELPER PASS; placement/execution pending |
| G2 | Pending | Plan phases 2–9; SPECIFICATION_DECISIONS.md | NOT IMPLEMENTED |
| G3 | Inventory.sol | Inventory.t.sol: principal eligibility only; close/settle/reopen and harvest not implemented | PARTIAL |
| C1 | Pending | Plan phases 2–9; SPECIFICATION_DECISIONS.md | NOT IMPLEMENTED |
| C2 | Pending | Plan phases 2–9; SPECIFICATION_DECISIONS.md | NOT IMPLEMENTED |
| C3 | Pending | Plan phases 2–9; SPECIFICATION_DECISIONS.md | NOT IMPLEMENTED |
| C4 | Pending | Plan phases 2–9; SPECIFICATION_DECISIONS.md | NOT IMPLEMENTED |
| C5 | Inventory.sol | Inventory.t.sol: pure principal/fee arithmetic only; live custody and lifecycle pending | PARTIAL |
| C6 | Pending | Plan phases 2–9; SPECIFICATION_DECISIONS.md | NOT IMPLEMENTED |
| C7 | Inventory.sol | Inventory.t.sol: pure principal/fee arithmetic only; live custody and lifecycle pending | PARTIAL |
| V1 | Pending | Plan phases 2–9; SPECIFICATION_DECISIONS.md | NOT IMPLEMENTED |
| V2 | Pending | Plan phases 2–9; SPECIFICATION_DECISIONS.md | NOT IMPLEMENTED |
| V3 | No production issuance | reference/AccountingReference.t.sol; ACCOUNTING_AND_RECOVERY.md | POLICY RESOLVED by O1–O4; implementation/proofs pending |
| V4 | No production issuance | reference/AccountingReference.t.sol; ACCOUNTING_AND_RECOVERY.md | POLICY RESOLVED by O1–O4; implementation/proofs pending |
| V5 | Pending | Plan phases 2–9; SPECIFICATION_DECISIONS.md | NOT IMPLEMENTED |
| V6 | Pending | Plan phases 2–9; SPECIFICATION_DECISIONS.md | NOT IMPLEMENTED |
| S1 / O5 | Accounting.sol | Sleeve.t.sol: real oracle and exact ratio, 5 tests passed; placement lifecycle pending | HELPER PASS |
| S2 | Pending | Plan phases 2–9; SPECIFICATION_DECISIONS.md | NOT IMPLEMENTED |
| S3 | Pending | Plan phases 2–9; SPECIFICATION_DECISIONS.md | NOT IMPLEMENTED |
| S4 | Pending | Availability and useful supported domains remain unproven | NOT IMPLEMENTED |
| SEC-01 | Pending | Plan phases 2–9; SPECIFICATION_DECISIONS.md | NOT IMPLEMENTED |
| SEC-02 | Pending | Plan phases 2–9; SPECIFICATION_DECISIONS.md | NOT IMPLEMENTED |
| SEC-03 | Pending | Plan phases 2–9; SPECIFICATION_DECISIONS.md | NOT IMPLEMENTED |
| SEC-04 | Pending | Plan phases 2–9; SPECIFICATION_DECISIONS.md | NOT IMPLEMENTED |
| SEC-05 | Pending | Plan phases 2–9; SPECIFICATION_DECISIONS.md | NOT IMPLEMENTED |
| SEC-06 | Inventory.sol | Inventory.t.sol: pure principal/fee arithmetic only; live custody and lifecycle pending | PARTIAL |
| SEC-07 | Inventory.sol | Inventory.t.sol: pure principal/fee arithmetic only; live custody and lifecycle pending | PARTIAL |
| SEC-08 | No production issuance | reference/AccountingReference.t.sol; ACCOUNTING_AND_RECOVERY.md | POLICY RESOLVED by O1–O4; implementation/proofs pending |
| SEC-09 | Pending | Plan phases 2–9; SPECIFICATION_DECISIONS.md | NOT IMPLEMENTED |
| SEC-10 | Pending | Plan phases 2–9; SPECIFICATION_DECISIONS.md | NOT IMPLEMENTED |
| SEC-11 | Pending | Plan phases 2–9; SPECIFICATION_DECISIONS.md | NOT IMPLEMENTED |
| SEC-12 | Pending | Plan phases 2–9; SPECIFICATION_DECISIONS.md | NOT IMPLEMENTED |
| SEC-13 | Pending | Plan phases 2–9; SPECIFICATION_DECISIONS.md | NOT IMPLEMENTED |
| SEC-14 | Pending | Plan phases 2–9; SPECIFICATION_DECISIONS.md | NOT IMPLEMENTED |
| SEC-15 | Pending | Plan phases 2–9; SPECIFICATION_DECISIONS.md | NOT IMPLEMENTED |
| SEC-16 | Pending | Plan phases 2–9; SPECIFICATION_DECISIONS.md | NOT IMPLEMENTED |
| RV-1 | Pending | Plan phases 2–9; SPECIFICATION_DECISIONS.md | NOT IMPLEMENTED |
| RV-2 | No production issuance | reference/AccountingReference.t.sol; ACCOUNTING_AND_RECOVERY.md | POLICY RESOLVED by O1–O4; implementation/proofs pending |
| RV-3 | Pending | Plan phases 2–9; SPECIFICATION_DECISIONS.md | NOT IMPLEMENTED |
| RV-4 | No lifecycle yet | PRD A3 resolves scheduling; execution/parity still pending | DECIDED; not implemented |
| RV-5 | Pending | Plan phases 2–9; SPECIFICATION_DECISIONS.md | NOT IMPLEMENTED |
| RV-6 | No production issuance | reference/AccountingReference.t.sol; ACCOUNTING_AND_RECOVERY.md | POLICY RESOLVED by O1–O4; implementation/proofs pending |
| RV-7 | Pending | Plan phases 2–9; SPECIFICATION_DECISIONS.md | NOT IMPLEMENTED |
| RV-8 | Pending | Plan phases 2–9; SPECIFICATION_DECISIONS.md | NOT IMPLEMENTED |

## Cross-cutting requirements

| PRD section | State |
| --- | --- |
| 1–3 independent family, preservation, immutable identity | New root only; package and registry identity pending |
| 4 custody F/D/E/R and projected state | Pure principal/fee observations only; stateful accounting pending |
| 7A withdrawal priority | Not implemented; Gate B |
| 9 public routes and quotes | Not implemented; surface policy pending |
| 10 composability/native SY | Not implemented |
| 12 exhaustive consumer configurations | Not generated; current suite path inventory is navigation only, not coverage |
| 13 outer gas and runtime sizes | No deployed product/outer receipt; Gate C |
| 14 release checks | Not satisfied |
| 15 acceptance checklist | No release checkbox claimed complete |

O1–O6 override the former owner-choice gates. O2 remains a testable engineering invariant. A1 overrides complete-input-only rejection in V2/RV-1. A3 overrides optional harvest language in G3/RV-4. A4 fixes the payer of rebalance trading costs; it does not set a numeric loss allowance.
