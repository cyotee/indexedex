# V4 FullSpread: remaining open items

Date: 2026-09-27. Research-only council round; four independent passes and four same-session combined cross-reviews completed. No implementation, shell, builds, tests or deployments executed in this round. This report does not change product policy.

## Conclusion

No unconditional owner-policy decision blocks authoring the implementation plan. The current PRD is direction-complete, not engineering-specification-complete. Begin with its source-backed formula/route matrix and pursue production-runtime provenance in parallel. Escalate a concrete incompatibility rather than silently relaxing requirements.

Authority: `docs/plans/UNISWAP_V4_STANDARD_EXCHANGE_PROPORTIONAL_ZAP_IN_PRD.md` (Z below), D1–D26 at lines 28–53. Its explicit outstanding-specification list is Z:482–498.

## Remaining work

| Priority | Deliverable | Closure evidence |
|---|---|---|
| 1 | Existing-formula and route matrix | Each family, selector/direction, exact-in/out and idle/blocked state has an applicable helper/domain, fee/rounding model, maintenance inclusion, justified D19 exception and supported/revert behavior; previews and consumers agree. Z:203–233. |
| Parallel verification | Fixed Pons hook/runtime provenance | Establish correspondence of the deployed hook to the chosen source/build and relevant immutable bindings, manager and fee/callback behavior. Address and code presence alone are not runtime equivalence. Label production evidence separately from hermetic evidence. Z:363–387,475. |
| 2 | Numerical and accounting specification | Define caller/holder budgets, post-swap incumbent backing, own-position fees, protocol/hook charges, collection, sleeve allocation, residuals and final snapshots. Specify overflow-safe 25/50/10/1 bp enforcement, zero-leg/rounding handling, permitted solver bounds and normalized maintenance progress ordering. Z:112–201,235–327,418–445. |
| 3 | Two-family component and integration manifest | Exact names/paths, interfaces, facets, delegates, repos, quote services, FactoryServices, selectors, package identities, registry wiring and genuinely hook-independent reuse. Include native/WETH, imports, Multi and SY consumers. No shared Hookless/Pons model dispatcher. Z:350–375,465,474,495. |
| 4 | Acceptance and regression plan, then separately authorized execution | Map all 28 acceptance requirements to production-path checks, including arithmetic boundaries, route rejection before economic actions, quote parity, impostor/historical hooks, repeated repair and full booking. Passing tests are evidence, not security proof. Z:447–480. |
| 5 | Legacy-removal manifest and readiness record | Inventory exact files/references, retain both replacement subtrees, rehome required generic dependencies, preserve historical revisions and regression assertions. Record audit-submission readiness before removal; validate refreshed artifacts and consumers on the final post-removal revision. Z:74–97. |
| Documentation | Reconcile superseded maintained documents | Older co-located policy does not reopen D1–D26. Z:97 assigns reconciliation to a separately authorized documentation task. Preserve historical originals and use revision-qualified citations after removal. |

## Initial positions and cross-review corrections

- **Astra:** No unconditional policy blocker; route matrix first, runtime evidence in parallel. Distinguished formula names from actual search-based implementations.
- **Grok:** Same principal conclusion; emphasized that unapproved additional admission restrictions and historical PRD questions are not automatically current open decisions.
- **MiniMax M3:** No policy blocker; prioritized runtime equivalence. Initially claimed a liquidity helper established combined closed-form support, mischaracterized prepaid-credit subtraction, and described D26 as a codehash pin.
- **Kimi K3:** Initially proposed a residual hookless fee-admission decision. Withdrew that owner question during cross-review, corrected search-based helper classification, and clarified that an editor diagnostic is not an executed build result.

Important corrections adopted by the moderator:

1. D26 fixes an **address**, not a mandatory codehash check. A codehash observation alone does not establish source correspondence. Exact build comparison must account for compiler settings and immutable substitutions; do not compare vault-package runtime with hook runtime.
2. `LiquidityAmounts.getLiquidityForAmounts` accepts already-known price/range/token budgets (`lib/crane/contracts/protocols/dexes/uniswap/v4/libraries/LiquidityAmounts.sol:48–77`, directly read by moderator). It does not establish a complete operation-plus-maintenance inverse. Single-unlock execution is not a mathematical proof of a closed form.
3. An unadopted candidate is not a mandatory repair/adoption task. No current build failure or passing test is established by this round; editor diagnostics and earlier execution claims are not fresh execution evidence.
4. Preserve deterministic structural validation (Z:381). Local `Hooks.sol:124–128` disallows zero-hook dynamic-fee keys; `Pool.sol:315–320` rejects exact-output swaps at a total 100% swap fee. These facts do not authorize a blanket product-level fee ban or disabling unrelated funded/no-swap operations. The plan must classify each route's domain and appropriate failure without inventing a new policy.
5. Prepaid-input subtraction from total backing is not itself evidence of credit scaling. Demonstrate a concrete attribution error before requiring a change.

## Unresolved dissent and limits

- **Priority:** MiniMax prefers runtime verification first; Astra, Grok and Kimi prioritize the matrix for plan authorship with provenance in parallel. Moderator adopts parallel tracks: matrix is the planning critical path; production claims remain gated on runtime evidence.
- **Combined closed form:** MiniMax's cross-review still claims support in principle from deterministic swap/placement in one unlock. Astra, Grok and Kimi reject that inference without the end-to-end derivation. Moderator does not adopt it; actual eligibility is unresolved until the matrix provides evidence.
- **Fee handling:** MiniMax treats blanket 100%-fee rejection as an engineering default; that is not unanimous and is not adopted. Kimi's final phrase “hook-identity-only admission” also must not erase existing structural PoolKey validation.
- MiniMax's cross-review labels some positions “4/4” despite contrary original positions. Those labels are not accepted as consensus evidence.
- Exact route coverage, deployed-source equivalence, execution bounds and audit readiness are unproven. No speculative formula nonexistence claim is made.

## Evidence and version scope

The moderator directly read current CLAUDE.md, Z, the canonical IndexedEx hook-package skill, council protocol and the three source sections cited above. Researchers inspected additional canonical skills, family PRDs and math sources; their attributed original and review files preserve those citations. Hook-diamond deployment guidance does not imply these externally hooked SE vaults are themselves hook diamonds. Current CLAUDE.md supersedes older skill profile advice.

This is a repository requirements/source review, not new external API research. Official address provenance is recorded in Z:365,507 from https://docs.ponsfamily.com/v2 (prior access 2026-09-27); that page was not re-fetched this round. Z:526 records Solidity 0.8.35, optimizer runs 1 and via-IR disabled; no compiler execution or deployed compiler equivalence was independently established here. Target chain is 4663. The current-stack hook address remains the settled `ROBINHOOD_MAIN.PONS_V2_MEME_HOOK` binding.

Confidence: high on policy closure and the categories of remaining work; medium on eventual route coverage; no assertion of runtime equivalence or implementation readiness.

## Preserved artifacts and continuity

All paths below are under `docs/research/uniswap-v4-open-items-2026-09-27/`. Originals were preserved and supplied as complete peer artifacts only after all independent passes completed; each review received the other three originals, not earlier cross-reviews.

| Researcher | Session | Original | Cross-review |
|---|---|---|---|
| Astra | `ses_f1c5107bfffefDJanl5lU29WfQ` | `ASTRA_ORIGINAL.md` | `ASTRA_CROSS_REVIEW.md` |
| Grok | `ses_f1c4d2922ffewPe5TNJvLvwfiy` | `GROK_ORIGINAL.md` | `GROK_CROSS_REVIEW.md` |
| MiniMax M3 | `ses_f1c42bd1cffeeUULWzxjga1tEf` | `MINIMAX_ORIGINAL.md` | `MINIMAX_CROSS_REVIEW.md` |
| Kimi K3 | `ses_f1c40272fffegWv5fAQexS8el4` | `KIMI_ORIGINAL.md` | `KIMI_CROSS_REVIEW.md` |

## Human checkpoint and implementation handoff

Recommended next authorized documentation task: produce the decision-complete implementation/test plan, beginning with the existing-formula route matrix and a precise production-provenance verification work package. Do not execute that plan during research. No new owner questionnaire is needed unless the investigation exposes a concrete conflict with approved policy.

Later, record the human audit-submission readiness determination before gated legacy removal. That is neither completed security audit nor authorization to deploy, migrate or retarget a live registry. A separately authorized implementation agent owns code, validation execution and gated removal; this council round stops here.
