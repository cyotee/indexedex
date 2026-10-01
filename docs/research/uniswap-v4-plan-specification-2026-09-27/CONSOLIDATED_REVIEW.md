# Council consolidation — seven-item implementation specification

Date: 2026-09-27. Four independent original continuations plus four same-session cross-reviews completed. Research/documents only; no code, shell, tests, deployment or deletion.

## Final deliverables

- `docs/plans/UNISWAP_V4_STANDARD_EXCHANGE_PROPORTIONAL_ZAP_IN_PRD.md`: D27–D31 record the owner's delegation, accepted Pons evidence, exact preview/in-kind parity requirement and old-PRD deprecation.
- `docs/plans/UNISWAP_V4_FULLSPREAD_IMPLEMENTATION_AND_TEST_PLAN.md`: moderator-owned route/state/family matrix, formulas/domains, accounting, numerical metrics, solver bounds, component/reuse map, acceptance suites and execution phases.
- `docs/plans/UNISWAP_V4_FULLSPREAD_REMOVAL_MANIFEST.md`: finite 80-Solidity/6-document retirement set, preservation exclusions, consumer rehoming and readiness gate. Six code-linked historical documents are deprecated as current V4 law; their on-disk historical originals were not edited.

These replace the preceding open-items report's recommendations for another runtime-equivalence gate and old-PRD reconciliation. Those historical reports remain intact; they are not current authority.

## Initial positions and corrections

| Member | Original contribution | Cross-review outcome / consolidation |
|---|---|---|
| Astra | Source-based matrix, exact accounting, closed placement subset, separate family/component map, exact manifest | Supplied integer counterexample to radical inverse; corrected placement certificate to terminal thresholds, order and error ABI. Most arithmetic adopted. Final vector-route rejection not adopted. |
| Grok | Compact formula/matrix and component/removal proposal, initially radical inverse and broad maintenance omission | Withdrew radical and mint-before-placement; accepted source-domain/placement certificate. Vector-route preservation adopted. Eight-probe budget not adopted. |
| MiniMax M3 | Broad accounting/test inventory and Pons evidence acceptance | Several source equations, counts, pretransfer assertions and parity claims were incorrect or insufficiently evidenced. Not used to override directly read source/Astra/Grok corrections. |
| Kimi K3 | Extensive proposed new derivations, components, consumer and parity analysis | Withdrew tick-walking-as-closed-form and broad joint solve, but retained inverse/certificate proposals not adopted. Consumer/reuse/test concerns informed consolidation. |

### Concrete adjudications

- Adopt the existing blocked exact-share-mint inverse, not that inverse as an idle composed-mint substitute.
- Do not adopt radical-plus-two-checks or correction-loop inverse for integer two-leg redemption. CP:98–128 and the 100/100 book, 1000 supply, output=1 counterexample establish why two checks fail.
- Exact-output external swaps use the explicit one-core-step domain and complete placement certificate. Tick walking remains bounded forward evaluation for exact-input, not a claimed combined closed form.
- Credit before fee collection; composition then allocation then mint. Current Native SY code already uses false-pretransfer SE delegation/context; no speculative generic SY fix is authorized.
- Pons charge is a sum of two separate floors on the unspecified leg; global rate defaults do not replace launch snapshots.
- Fixed 32 refinements/64 core steps are work budgets, not root-precision guarantees. Final arithmetic/protection checks decide success. Wide progress comparisons require enough width for rational cross-products, not merely X/Y individually.
- **Remaining dissent resolved by moderator selection:** for the sole vector-output interface, follow Grok's route-preservation interpretation and omit optional holder maintenance when its certificate is unavailable. Astra's final review would reject that idle branch instead. The plan states this choice explicitly; no unanimity is claimed, and no choice is left hidden for the implementer.

## Evidence and limits

Source review plus canonical instructions, not executed validation. The moderator directly read CP, baseline funding/exit/bootstrap helpers, Native SY, hook charging and complete directory manifests. Relevant file/line citations and external-source access dates are in the plan and original reports. Compiler baseline is 0.8.35/optimizer1/no via-IR; no compilation or binary equivalence was established. Official Pons documentation and graduated-pool usage are sufficient by owner instruction.

A broad glob encountered unrelated dangling entries under Crane's mirrored skills/LayerZero paths. It supplied no authoritative file inventory; direct bounded directory reads supplied the manifest instead. No permission workaround or researcher substitution occurred.

Confidence: high on source corrections, policy recording and manifests; medium on end-to-end arithmetic implementation and bounded-solver practical coverage pending the defined tests. Test failures must produce a fix/specification correction, not an unadvertised inverse or relaxed ownership rule. Consensus and passing tests are not proof of safety.

## Continuity and artifacts

| Member | Retained session | Original / review in this directory |
|---|---|---|
| Astra | `ses_f1c5107bfffefDJanl5lU29WfQ` | `ASTRA_ORIGINAL.md` / `ASTRA_CROSS_REVIEW.md` |
| Grok | `ses_f1c4d2922ffewPe5TNJvLvwfiy` | `GROK_ORIGINAL.md` / `GROK_CROSS_REVIEW.md` |
| MiniMax M3 | `ses_f1c42bd1cffeeUULWzxjga1tEf` | `MINIMAX_ORIGINAL.md` / `MINIMAX_CROSS_REVIEW.md` |
| Kimi K3 | `ses_f1c40272fffegWv5fAQexS8el4` | `KIMI_ORIGINAL.md` / `KIMI_CROSS_REVIEW.md` |

Originals were shared intact only after all four independent passes, and no cross-review was given another member's cross-review. Final plan supersedes conflicting researcher proposals while originals remain preserved.

## Human checkpoint / implementation handoff

Specification work is complete for this bounded round. A separately authorized implementation agent should follow the plan and tests; this report does not execute them. Later, record both replacements' audit-submission readiness before finite legacy removal and validate the post-removal revision. No live migration or registry action is authorized. Stop here.
