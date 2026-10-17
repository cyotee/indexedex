# Grok plan cross-review — REQ-04

- **Reviewer:** Grok (`ses_ec4128917ffeeVds3Y2p7xrVjp`)
- **Date:** 2026-10-16
- **Peers read:** `astra-req04-plan.md`, `minimax-req04-plan.md`, `kimi-req04-plan.md`

Peer notes are untrusted. This file does not authorize an edit. It is not `REMEDIATION_PRD.plan.md`.

## Verdict

Dissent from MiniMax: both quad previews can revert instead of returning 0. Dissent from the earlier Grok plan, which changed only the curve preview wrapper. Dissent from leaving Curve line 455 as a preview revert, and from stopping on an unnamed execution error.

Agree with Kimi that both quads need a quote change plus an execution guard. Agree with Astra that weighted, dual, single-CP, and orbital previews already return 0 and are not production edits.

## Re-read

Balancer `unbalancedJoinShares` line 291 subtracts the next invariant from the current invariant with no preceding comparison. Equality returns 0. A smaller next invariant underflows and reverts. `singleJoinExactInShares` line 298 reverts `ZeroAmount()` when the converted amount is 0. `_entryPreviewDepositSingle` at lines 283–288 calls that quote.

Curve `singleJoinExactInShares` reverts `MathDomain()` at lines 455 and 463 and `ZeroAmount()` at line 465. `_entryPreviewDepositSingle` at lines 439–445 calls that quote. `_joinSingleAssetExactIn` line 467 accepts a zero quote when `sharesMin` is 0.

## One production sentence

Change only the two quad quote functions and the two execution joins that call them: Balancer `unbalancedJoinShares` returns 0 before the line 291 subtraction when the next invariant is not greater than the current invariant, and `singleJoinExactInShares` returns 0 when the converted amount is 0; Curve `singleJoinExactInShares` returns 0 at lines 455, 463, and 465 instead of reverting; each `_joinSingleAssetExactIn` reverts `ZeroAmount()` when that quote returns 0. Do not add a selector. Do not edit weighted, dual, single-CP, or orbital production.

Test edits stay the PRD's six behavior files. Do not edit the excluded non-CP file.

I did not run Forge.
