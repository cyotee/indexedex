# Plan completion — interrupted review status

Date: 2026-09-27. **Plan completion is not claimed.**

## Requested deliverable

Complete `docs/strategies/ohm-style/netnet-pendle/NETNET_PENDLE_DETF_IMPLEMENTATION_AND_TEST_PLAN.md` in place, replacing G2–G5 future-annex placeholders with concrete correct specifications while retaining genuine external prerequisites. Do not implement code or execute tests.

## Work collected

Four independent original drafts were collected in the preserved researcher sessions. They contain proposed live-B/U share equations, receipt attribution, inner subshare residual handling, exact-output composition, observation history and terminal NFT transitions.

These drafts are **unreviewed attributed evidence**, not adopted specification. Several proposals conflict with each other or the settled requirements. They must not be pasted into the plan merely to remove an open label.

| Researcher | Original | Session |
| --- | --- | --- |
| Astra | [Original](astra-original.md) | `ses_f1c499b6bffe6RiNjZZUSMsP8S` |
| Grok | [Original](grok-original.md) | `ses_f1c4384d7ffeZX74uV9yhIXbVq` |
| MiniMax M3 | [Original](minimax-original.md) | `ses_f1c3f57edffedYs43k2PBvA5xU` |
| Kimi K3 | [Original](kimi-original.md) | `ses_f1c3a8701ffeB4x8S7oRn2JnXK` |

## Interruption

Astra's first combined cross-review attempted an ordinary read of required `CLAUDE.md` and reported:

> Research council: [RC_ATTRIBUTION] active call attribution failed; report the failure, do not bypass it

The session returned its original ID, but the guard failure prevents treating the continuation as completed. No cross-review artifact was written. The remaining three cross-reviews were not invoked. Five task calls occurred: four originals and one failed continuation. No alternate access path, retry, participant substitution or new session was used to bypass the guard.

The guard's underlying cause is unknown. Observable original routing was openai/gpt-6-astra, xai/grok-4.6, minimax/MiniMax-M3 and kimi-code-plan-global/k3; those metadata labels do not override a failed attribution check.

## Concrete matters requiring resumed scrutiny

- Whether finite integer live-B/U shares can satisfy all required exact native-principal and non-dilution conditions, and which rounding is actually permitted by the operative PRD. Astra supplies a mathematical counterexample; it has not yet been cross-reviewed against the exact requirement scope.
- Standing fee/creator reward allocations must not become a share of the entire pre-existing principal. Standing weights and transferable receipt shares are different concepts.
- Aggregate balance surplus cannot by itself prove whether funding was user pretransfer, a force-claim or a donation. Proposed receipt boundaries must preserve the required standard route semantics.
- Inner-share residuals must not silently become donations. Initial geometric issuance is not a min-ratio against zero supply/reserves.
- A sampled rate plus one-unit adjustment is not a proven inverse of an arbitrary configured SY conversion. Weighted inverse, tax inverse and whole-route inverse must not be conflated.
- A new external Pendle SY, all-gift `pendingFor==0` retirement prerequisite, abandoned late-entitlement policy or nonburning replacement lifecycle is not automatically authorized by the selected design.
- An exact-window ring proposal needs its explicit timestamp/coalescing/retention proof and arithmetic bounds; source-style prior-price accumulation alone is not a complete oracle specification.

These are provisional technical review topics, not a new owner questionnaire or a declaration that all requirements are impossible. No numerical estimates, identity claims or proposed formulas in the originals are certified by this status note.

## Files and next permitted action

The implementation plan, PRD and tracker were **not modified by this interrupted completion attempt**. Only the four original Markdown drafts and this partial status were authored. No shell/tests, RPC, browser/JavaScript execution, source/config/instruction changes, transactions or deployments occurred.

The next action requires a subsequent human-authorized continuation after attribution is restored: resume Astra's same session for the interrupted cross-review, then complete the remaining original-session cross-reviews, each receiving only the other three originals. Consolidate accepted material in the existing plan and clearly report any genuinely remaining incompatibility. Stop now; do not claim the plan is finished.
