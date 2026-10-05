# Grok replacement original: Aperture PRD requirements review

**Date:** 2026-10-03. **Author:** fresh Grok (`xai/grok-4.7`), retained replacement session. Independent review of `docs/plans/UNISWAP_V4_HOOKLESS_APERTURE_OPTIMAL_SWAP_REFACTOR_PRD.md`. No peer artifacts read. The target PRD was not edited. Not consensus. No test or gas claim.

Scalar entry and exit, whole-book ownership, sleeve, protections, Pons separation, and blocked local cover are settled. This review does not reopen them. The PRD already states the right split: Aperture-style walk plus a different whole-book quadratic, math first, no hidden search fallback.

## Findings

| Pri | Class | Where | Issue | Suggested clause |
|---|---|---|---|---|
| P0 | Editorial, blocks a bad Gate M | §8:217; §8:235; §9:251 | "Baseline regression checks pass" and "consumer success" can import already-failing Orbital/DETF suites into Gate M, or make a gas win the pass rule. | Add under Gate M: "Baseline proof is a diff showing production money and quote paths are unchanged, plus compile of those units. Full consumer suites are Stage 2. A Stage 2 fail is a new or worsened result against the frozen baseline on the same corpus. A pre-existing consumer failure is reported, not assigned to this refactor. Gas is reported. A reduction is not required. A previously passing nested case that now exceeds the existing 31M/32M cap is a fail. Raising those caps is not a fix." |
| P0 | Engineering, not an owner question | §6:118–133; §6:145 | `phi` is "protocol fraction of gross input," while `f` is the combined swap fee. Implementers can set `phi` to protocol pips/1e6. Those are not equal. `ProtocolFeeLibrary.sol:35–46` is `protocol + lp - floor(protocol*lp/1e6)`. | Add: "`f` is that combined pip fee over 1e6. `phi` is protocol tokens taken per gross input after the core split, not the raw protocol-fee field. Stage 1 must derive both from the core and must reject a transcription that treats the explanatory formulas as already Q96-certified. Token1 `beta`/`gamma` are checked against `SqrtPriceMath`, not assumed." |
| P0 | Editorial | §10:270–271; A11:73 | A sizing view "can technically run" while unlocked. That sentence invites a callback to compute `x` and then swap. | Replace with: "While the manager is unlocked, quote and execution stay on the existing local-admission formulas. The analytic planner is idle-only. A view that reads pool state during an unlock does not authorize `swap` or `modifyLiquidity`." |
| P1 | Engineering | §7.1:162; §7.2:168–171 | "Start from 64" can be read as one budget for discovery, certification, and every quote. A root outside the committed segment is not classified. | Add: "Discovery, word reads, and the one certification forward pass have separate counters. The initial discovery ceiling is 64 core steps and a separate bitmap-word ceiling set in the plan before the corpus freeze. Hitting either ceiling is a work-limit reject, not a second solve. A root outside the committed segment is a certification failure. One candidate only. A rounding stencil is not Stage 1 scope; if the corpus shows it is required, stop and return to the owner." |
| P1 | Engineering | §8:202–203; §8:212 | Stage 1 must model placement without calling the vault. Gate M can be misread as requiring `_executePlacement`. | Add: "Stage 1 placement is a pure replica checked against PoolManager deltas in a harness. It must not call Hookless facets. Gate M 'match V4 core settlement' means that harness, not a production deposit." |
| P1 | Editorial | A13:75; §12:298–300 | An implementer may delete `_maintenance` from redeem quotes while "removing searches." | Add: "Replacing `_composition` does not remove `_maintenance` from redeem or external-exchange quotes. Those calls stay until a separate D18–D19 amendment." |
| P2 | Engineering | §8:195; §11:284 | License choice is required but the default is easy to miss. | Add: "Default is a clean-room implementation of the equations in this PRD. Copying Aperture source is forbidden unless a recorded license review clears that exact pin and its dependencies. Gate M fails closed if the diff contains that source without the review." |

No coefficient width, file name, or routine harness layout is sent to the owner. Those belong in the implementation plan, as §14 already says.

## Stage 1 and Gate M

The isolation boundary at §8:202 is sound: no `_composition` dispatch, facet, quote, or storage change in Stage 1. Real PoolManager settlement can be tested from a harness. That does not require the diamond.

Gate M is too easy to inflate. "Nontrivial" success (§8:209) and "applicable regression checks" (§8:217) are the leak. The P0 clause above is the smallest fix. Exhaustive coverage of every pool shape is not required. A frozen corpus with both directions, a nonzero sleeve, prior fees, protocol fee on and off, at least one word-boundary step, and at least one external tick cross is enough to show a useful integer domain. Universal rejection fails the gate, as §8:214 already says. A one-step-only library must not pass, as §8:210 says. That matches A3. Do not reopen it.

Failure and re-entry are mostly right. A16 stops Stage 2. §7.3 case 2 returns to the human rather than silently shrinking the domain. Case 3 correctly forbids treating the old bisection as the oracle. Add one sentence so those rules meet: a frozen positive case that the new library rejects is not a Gate M pass, even if the reject is "safe." Re-entry is a new Gate M report on the changed library revision. Stage 2 may not start on a report for a different revision. §8:223 already says material math changes reopen Gate M. Keep that.

## Liveness, traversal, and gas

A3, A4, and §7.2 are the right policy: monotone discovery, one analytic candidate, exact check, no bisection fallback, no idle CP, no NAV. A rounding stencil is an owner amendment if it ever appears. It is not a Stage 1 option.

The old planner may be used only to label case 2 and case 3. It must not be the expected-value generator. §9:253 already says that. Preserve it.

The 64-step figure is a starting envelope, not a proof, and not one bucket for every counter. The P1 counting clause is sufficient. Do not ask the owner for the integer.

There is no performance objective to "demonstrate" beyond the report in §8:233–235. Delete the implication that a speedup is required. Nested 31M/32M checks belong in Stage 2, and only as regressions against a frozen baseline. Maintenance and the three Orbital searches stay in the measurement report and outside this library's success condition. A13 and §3:52–53 already say that. The P0 clause stops them becoming acceptance blockers.

## Preservation

D1–D31 dispositions in §12 match the settled economics. Full range, no wings, no idle CP, no exact-in refund, and no new inverse are explicit. Aperture's global sqrt limit and refund-all behavior are rejected at §5:100 and §11:281. V4 negative exact-input is required at §11:276. Protocol fee with zero hooks is required at §11:278. Good.

The unlocked-view sentence is the one preservation trap. The replacement in the table closes it. Pons is protected by A14 if generic Crane math is not given a Hookless fee branch. The plan should say family-specific η stays in the Hookless library, not in a shared Crane fee helper. That is engineering, and it follows A14.

## Owner questions

**None that should block the implementation plan.**

The only later owner contact already specified is §7.3: if the frozen positive corpus contains a protected deposit the analytic candidate misses, do not shrink the domain inside Gate M. Return with the counterexamples. Recommended default, if that happens: Stage 2 stays blocked; do not add a search stencil; do not adopt NAV or idle CP. Consequence of ignoring that default: the refactor changes who can deposit, which A1 and A16 forbid.

License default, not a question: clean-room. Consequence of copying first: Gate M cannot pass on the license row.

## Readiness

The PRD is fit for an implementation plan after the P0 clauses. It is not fit for Stage 2, and it does not claim to be. The plan must still freeze the corpus, the two work counters, the `f`/`phi` derivation, the integer root policy, and the clean-room record before Gate M is attempted. Those are plan deliverables, not new product choices.

**Stop. This review does not amend the target PRD and does not authorize implementation.**
