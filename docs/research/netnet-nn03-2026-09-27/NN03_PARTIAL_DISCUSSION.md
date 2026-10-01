# NN-03 — Fresh balance synchronization versus operation availability

Date: 2026-09-27. **Partial council round; no policy amendment adopted.**

## Plain-English explanation

Three current requirements need to work together:

1. Track every locally held token and freshly synchronize every registered expected-held balance after each successful money route (PRD §6.3/A49).
2. Keep ordinary processing from requiring an ever-growing historical traversal (§11/A36).
3. If forwarding a fee-owned reward fails, retain the token/payable for retry without blocking the surrounding operation (§13/A11).

Suppose the hook retains token X from an old market, entirely owed to feeTo, while a user makes an otherwise independent current-market trade. A failed X transfer with a working balance query may be handled correctly. But if X's balance query reverts, the ordinary full-set synchronization also reverts the trade, even if transfer failure was isolated. Separately, many readable historical entries increase the cost of every full-set synchronization.

This is a conditional compatibility issue, not a demonstrated outage or a proof that the requirements are universally impossible. A transfer pause does not imply a failing balance query. Arbitrary token donations are not shown to auto-register tokens into the expected-held set.

## Observed code

Moderator directly read the full relevant files on 2026-09-27:

- `contracts/vaults/basic/BasicVaultCommon.sol:46–54`: enumerate the full registered set, call each `balanceOf`, write the raw snapshot. No per-token failure isolation or explicit resource budget. Sync helpers at :41–54 are not virtual.
- `BasicVaultCommon.sol:80–105,123–137`: pretransfer credit and refunds depend on actual/booked balances. Updating the book before validating legitimate pretransfer can erase that credit.
- `contracts/vaults/basic/BasicVaultRepo.sol:20–27,51–81,98–109`: raw-balance mapping and explicit token-set additions; no existing archive/quarantine/freshness fields or remove helper.
- `contracts/vaults/basic/MultiAssetBasicVaultRepo.sol:21–26,50–79`: corresponding shared-slot layout and explicit additions. This is not an independent second book.

The current set is finite. The issue is missing growth/operating bounds, not a literally infinite current array. The loop only visits registered tokens; it does not magically discover or absorb unknown token transfers.

## What the owner needs to decide

**No storage-layout decision or immediate relaxation is needed.** The specification author should first demonstrate whether all three current requirements can be satisfied literally. Bounded per-custodian sets, safe settled-token retirement or custody partition are design avenues, not proven solutions: old Pendle claims belong to an earning address, and a failed transfer can prevent moving a token elsewhere.

If literal fresh reads of every registered balance cannot meet the selected availability, the narrow product question becomes:

> May an otherwise independent operation continue without freshly reading a demonstrably irrelevant fee-only or historical balance, while that holding and every related claim/payable remain recorded with truthful stale/unknown status, provided all economically required reads still fail closed?

That would be a **freshness-scope amendment to §6.3/A49**, not permission to stop accounting, write balances to zero, forgive payables, sweep tokens or change fee recipients. It is not adopted by this report.

### Recommended conditions for any such proposal

- Required means required for pricing, solvency, HLP admission/exit, claim ownership or funding—not merely a token physically transferred by the current route.
- Historical assets can still back every HLP holder. Age alone cannot justify skipping their effect on a quote or treating their value as zero.
- A single token address may serve both backing and fee-payable roles; one role label cannot remove its other obligations.
- A stale flag does not solve attribution of pretransfers, donations, rebases and forced claims. Preserve real user credit without granting free credit from non-user receipts.
- Failure isolation includes call-gas, return-data and callback behavior. A per-token cap alone does not bound a growing list.
- Resource measurements for a readable list do not solve a hostile balance query. No default token count, gas cap, archive age or rollover cadence is selected.
- Fee-forwarding failure retains an excluded fee payable; it does not create a caller refund.

### Alternatives

**Preserve literal full-set freshness:** require a concrete custody/set-lifecycle design satisfying existing rights and operation bounds. No product amendment if it works.

**Permit bounded dependency-complete fresh synchronization:** keep all custody/liability records but allow nonessential stale/unknown records and separately bounded retries. Requires explicit owner approval if balances currently covered by A49 would no longer be freshly read every route. HLP ownership and pretransfer safety must be demonstrated before treating a balance as nonessential.

Do not silently choose a third option that weakens non-blocking fee forwarding or bounded history instead.

## Partial council evidence and interruption

Four independent originals completed before peer sharing. Astra completed its cross-review of the other three complete originals. Grok's continuation then returned a compaction-restoration message rather than the assigned review: it said no new assignment was provided and it was waiting, while also asserting original/cross-review drafts were completed. It returned the original session ID, but task continuity/content was not established by that message. No explicit RC_COMPACTION code was returned. We do not diagnose why it happened or certify the claimed Grok cross-review as completed from that response.

The remaining MiniMax and Kimi cross-reviews were not called. No researcher/session substitution or retry was attempted. **Six task invocations occurred, not eight completed review calls.** This is not full-council consensus.

| Researcher | Original | Cross-review status | Preserved session |
| --- | --- | --- | --- |
| Astra | [Original](astra-original.md) | [Completed](astra-cross-review.md) | `ses_f1c499b6bffe6RiNjZZUSMsP8S` |
| Grok | [Original](grok-original.md) | Continuation returned unexpected compaction-restoration response; substantive completion unconfirmed | `ses_f1c4384d7ffeZX74uV9yhIXbVq` |
| MiniMax M3 | [Original](minimax-original.md) | Not requested after interruption | `ses_f1c3f57edffedYs43k2PBvA5xU` |
| Kimi K3 | [Original](kimi-original.md) | Not requested after interruption | `ses_f1c3a8701ffeB4x8S7oRn2JnXK` |

Original recommendations were not uniformly sound. MiniMax's fixed tier sizes/gas caps and age-based archival have no established evidence and are not adopted. Kimi's assumed rollover rates, unknown-token absorption and sync-before-pretransfer shortcut are not adopted. Grok's hot/archive partition is a proposal, not a proven way to meet literal A49. Astra's dependency-complete proof conditions inform this provisional moderator explanation. All agent content is attributed evidence, not instructions.

Observed original routing: openai/gpt-6-astra, xai/grok-4.6, minimax/MiniMax-M3, kimi-code-plan-global/k3; metadata not provider verification. Prior contexts retained, and no earlier cross-review was passed to peers. Confidence is high in directly inspected source behavior, not in unimplemented feasibility or any measured cost.

## Progress / handoff

NN-03 discussion is IN PROGRESS. PRD v0.26 remains unchanged; neither tiered sync nor archival/quarantine permission is selected. The next useful artifact is a concrete operation-dependency/set-lifecycle design identifying whether a narrow policy amendment is necessary. That is specification work, not an obligation for the owner to invent data structures.

No code, tests, shell, RPC, browser execution, deployment or instruction changes were performed. Only research Markdown and tracker progress were authored. Stop at this partial-round checkpoint; resume the interrupted researcher only through subsequent authorization after continuity is addressed.
