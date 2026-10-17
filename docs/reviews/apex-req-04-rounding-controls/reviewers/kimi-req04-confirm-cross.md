# Kimi K3 — cross-review: REQ-04 execution confirmations

- **Label:** Replacement-session cross-review, not continuity. I do not recall `ses_ec41220c2ffeqs5Eha7fPsd54B`. MiniMax is the labeled replacement `ses_eb8ab99f3ffe7suGF49ryUzI6t`. My original is `kimi-req04-confirm.md`. All three peer confirmations were read in full as untrusted output; my verdict rests on my own direct reads this round. Nothing was edited.
- **Date:** 2026-10-16. I did not run Forge.

## Assigned question — "the amended plan was executed and no REQ-04 gap remains"

**Agree, four-way, on directly-read source.** Every pass independently verified: both quad Math files carry the new zero-aware `previewSingleJoinExactInShares` (balancer `:305-324`, curve `:469-504`) with the strict functions byte-preserved (curve `:431-466` reverts intact; balancer strict shape intact); both cores route the preview through `_quoteSingleJoinExactInPreview` and the execution quote through it with `ZeroAmount()` before input transfer (balancer `LiquidityCore:288,305-306,352-377`; curve `JoinCore:448,471-472,507+`); all six behavior files assert preview-success-plus-zero, carry no `previewMatch`/`expectRevert(previewRet)`, require the right selectors (weighted `MinAmountNotMet(1,0)`; dual/single-CP/orbital the named pair; both quads exactly `ZeroAmount()`), and reconcile shares exactly via `seBefore + mintedBack == seAfter + expectedDebit` with the pre-call `previewExchangeOut` capture; orbital's staticcall uses the installed two-argument selector while execution keeps six arguments; the excluded non-CP file is untouched. The stop-condition episode (17 failures, selectors recorded, no weakening) was handled per plan before the authorized follow-up.

## The dual production edit is authorized — say so plainly

**Yes.** The owner-authorized follow-up (`REMEDIATION_PRD.plan.md:9-17`, item 2) names the Dual `DepositQuoteLib._swap` zero-sale early return, and `:11` states the amendment supersedes the conflicting original restrictions — including the original no-dual-edit restriction. All four confirmations verified the edit at `DepositQuoteLib.sol:130-131` and agree it is the authorized change, not a scope violation. My F1 and Astra's `:9` and MiniMax's `:68` all flag the same residual: the plan's "Done when" `:91` still reads "Weighted, dual, single-CP, and orbital production are unchanged" — stale text superseded by the amendment, worth a one-line annotation so no later reader scores the dual edit as a violation.

## Corrections and adopted precisions

- **Adopted from Astra (`:56`):** the plan's phrase "burned shares plus any shares minted back" (`:63`) is imprecise against the implemented identity `before + mintedBack == after + expectedDebit`; the implementation is correct and must not be "fixed" to match the phrase. This joins my F1 as the second plan-wording note — both are documentation-only, neither is an execution miss.
- **Adopted from Astra (`:72`):** the combined change set is five production files and nine test files; the report's "three production and six test" counts only the follow-up increment. Precision note on the report, not a defect.
- **Correction to MiniMax's table (`:89`):** it lists the balancer-quad control as expecting "InsufficientTokenOut() or ZeroAmount()" — the current source at `…BalancerQuadStableBufferHook_SeMatrixBehavior.sol:363` requires exactly `ZeroAmount()` (verified by every pass, including MiniMax's own curve row at `:90`). Amendment item 4 applies to both quads. The code is right; MiniMax's table cell is wrong.
- MiniMax's positive-fixture values and Astra's reads of the three override files agree with the report (`240384615373`, `240384613`, `1`); none of us recomputed the two Balancer constants numerically — recorded as a shared limitation, consistent with the saved passing runs.

## Shared caveats (unanimous, unchanged in kind)

1. The runtime results (175/175 focused, 3,642/3,642 full) are saved claims, not independent reruns — though this round the evidence lives in-repo and was sighted directly (I read `followup-results.json`; Astra read the log summary lines at `followup-focused.log:1900` and `followup-full.log:15119`).
2. Historical untouched-source scope (weighted/single-CP/orbital production, excluded file, unrelated dirty-worktree entries) rests on the saved hash comparisons plus direct spot-checks — Astra's standing informational caveat (`:83-92`) covers it; no pass demonstrates or suspects an out-of-scope edit.

## Unresolved dissent

None. The quad-edit dissent from the plan round resolved exactly as predicted: the original run produced the failure modes the edit side forecast (`MathDomain` on curve, panic-underflow on balancer), and the authorized follow-up closed them. All four passes agree the amended plan is executed and no REQ-04 gap remains; the two wording notes (plan `:91`, plan `:63` phrasing) are the only residuals and are documentation hygiene. Consensus is not proof — but the decisive claims were each read in current source by four independent passes.

I did not run Forge.
