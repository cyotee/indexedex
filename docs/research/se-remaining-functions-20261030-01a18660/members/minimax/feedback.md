# MiniMax member feedback — advisory on the frozen draft

## Identity

- Run ID: `se-remaining-functions-20261030-01a18660`
- Member label: `minimax`
- Phase: advisory review
- Owned path: `docs/research/se-remaining-functions-20261030-01a18660/members/minimax/feedback.md`
- Requested role: council member, advisory pass on the frozen draft
- Actual role, model, reasoning, task ID, and session ID: council member; provider `minimax`, model `MiniMax-M3` (runtime-exposed); reasoning level `high` as exposed by the runtime, and the brief's "adaptive thinking" setting is not separately exposed; task ID `st_01a192c0` (the run record and this child session directory agree on it); a per-member session identifier is not exposed
- Fresh or continued: continued — this is the same session that wrote my initial response
- Initial response path: `docs/research/se-remaining-functions-20261030-01a18660/members/minimax/response.md`
- Initial response preserved: yes — written in this run and not edited by this pass

## Draft under review

- Draft ID: `se-remaining-functions-20261030-01a18660-r1`
- Path: `docs/research/se-remaining-functions-20261030-01a18660/coordinator/draft.md`
- Fingerprint supplied by the coordinator: `694cdf6054d69b261f498825808e9a8c2f6dd1108b2a9ec0d732a3aa17520e15`
- Fingerprint independently computed: `694cdf6054d69b261f498825808e9a8c2f6dd1108b2a9ec0d732a3aa17520e15` — computed with `shasum -a 256` over the raw file, matching the supplied value
- Draft bytes opened: yes — 4749 bytes, 69 lines, read in full; the draft's own identity lines match the draft ID and path above

## Disposition

- Disposition: `requested-changes`
- This file replaces a missing initial response: no

Why this disposition, and what it is not:

- The draft states the substance of my original correctly on all five functions. The keep/drop/map dispositions I recorded are all present and correctly attributed: keep `previewZapCredit`; drop the `previewWithdrawalMode` selector and map the paired exit to `previewExchangeBundleOut` and the single-token exit to `previewExchangeIn`; drop both cap getters while keeping both caps as configuration and enforcement; drop the family `wrappedNative` getter because `vaultTokens()` already exposes the face. The draft's three "all four originals agree" statements match my original's conclusions.
- I request changes for two reasons, both about the record rather than the decisions. One cell of the disagreement table asserts something about my position that is not what I wrote, and one downstream consequence of a settled item is missing from the draft, which will produce inherited rows that are false as written when the PRD is updated.
- I do not resolve the two preserved splits, and I ask the coordinator not to read my disposition as a vote on either. `previewZapCredit` and the two cap getters remain open in the draft, and my concerns below do not argue for closing them.
- This advisory neither replaces my original response nor authorizes implementation.

## Concerns

| ID | Draft location | Concern | Requested change |
| --- | --- | --- | --- |
| MM-F1 | Preserved disagreements, row `Where the native face is named`, third column ("Grok's refusal to put it on the Position Repo is not answered by the other three.") | This is not accurate about my original. I did answer the Position Repo question and gave a reason: the Position Repo holds the state of one position in one pool, namely the pool key and the ticks, and a wrapper address is neither position state nor pool state. I also named the alternative home for a future runtime protocol-component read: the Protocol Aware pair under FS-OWN-01, alongside the PoolManager and the Universal Router. The cell's assertion holds for Astra and Kimi, not for me. | Replace the third column with the actual position, for example: "Grok and MiniMax: do not move it onto the Position Repo; MiniMax adds that the Position Repo holds the pool key and the ticks, that a wrapper address is neither position state nor pool state, and that the Protocol Aware pair under FS-OWN-01 is the home for a runtime protocol-component read if one is ever wanted." The open question stays map versus drop, which the cell already calls wording. |
| MM-F2 | Preserved disagreements, row `previewZapCredit`, second and third columns | My keep is stated conditionally in my original, and the condition is not in the table. I wrote that the keep flips to drop if the owner rules that a booked no-share residual is "idle unconsumed input" under the accepted refund rule and therefore must be refunded instead of booked, because then `amountRefunded` becomes the residual disclosure and the selector becomes redundant. I also wrote that in that case the `credit0`/`credit1` words still have no home on any accepted surface and would have to be dropped as well, and that FS-X04's booking rule would change. The table's single open item, "whether the diagnostic split is required before a residual policy exists", does not carry the second open item. | Add the conditional to my recorded position and split the open item in two: (a) whether the diagnostic split is required before a residual policy exists, and (b) whether the credit words have a home at all, because the accepted refund return carries the residual only if the residual becomes a refund, and it carries the credit words in neither case. |
| MM-F3 | Proposed text, `previewWithdrawalMode` paragraph; Coverage adopted from responses, row `previewWithdrawalMode` | The draft omits a consequence my original named, and it is the one that matters for the PRD update that follows this review. Dropping the selector leaves three inherited statements false as written: stage-one PRD S1-EXIT-01, "Expose the selected mode and reason in `previewWithdrawalMode` and emit `WithdrawalMaintenanceSelected(mode, reason)` on successful withdrawals" (line 663); inherited row S1-A61, "mode/reason in preview, event, and execution agree"; and inherited row S1-A63, "Paired mode and single-token ETH mode are unambiguous in the mode-query ABI". S1-A63's clause has no remaining home once the `paired` boolean and the `address(0)` sentinel convention go with the selector. The draft's phrase "Dropping the selector does not remove the internal maintenance choice" is true but does not cover this. | Add the re-point requirement to the draft, so the report carries it into the PRD update: S1-EXIT-01's preview sentence, S1-A61, and S1-A63 must be re-worded against the event and the execution plan, and the mode-query ABI clause needs a home or an explicit withdrawal. Change the coverage row's "Conflict or gap" cell from the map-versus-drop wording to this re-point requirement, since map versus drop is not a gap. |
| MM-F4 | Evidence gaps, first bullet | The bullet is accurate but narrow, and it understates what the gap is. My original already disclosed that the residual behaviour I describe comes from the current PairToken implementation rather than a locked full-spread policy. The sharper point is that the open item is a conflict with an *accepted* artifact: the refund rule in `docs/research/se-interface-refund-bundle-20261030-01a18660/REPORT.md` says a declared input has exactly two buckets, "declared amount equals amount consumed plus amount refunded" and "Idle unconsumed input is not consumption", while the inherited zap accounting books `J_i` with no extra shares for the entrant (S1-ACC-07, FS-X04). That is the reason the preview question cannot be settled by reasoning about the surface, and it is an owner decision about the residual's economics. | Extend the bullet to name the conflict with the accepted refund rule, and add the fact that makes the distinction non-trivial: on the zap route `amountRefunded` is zero by construction, because the declared input is pulled whole and the rounding remainder is booked rather than refunded. Without that fact the Proposed text's statement that the refund does not replace the split reads as a type distinction only, and it also bears on the drop-mapping position in the table. |
| MM-F5 | Preserved disagreements, row `maxZapBps` and `maxZapTickMove` getters, second column | The cell records my position's disposition correctly but only the weaker of my grounds, "No accepted standard getter exists to map them onto". My original's decisive ground was actionability: `maxZapBps` is a ratio whose denominators are the pre-entry-swap input-side basket reserve for the zap and the active pool reserve for the compound cap, and neither is a public getter, so the bps value alone cannot produce a correct maximum deposit and a caller must simulate the quote regardless. I also recorded that no inherited acceptance row calls either getter, that S1-A14 and S1-A23 test the caps' behaviour instead, and that the cap stays in `PkgArgs`, is validated by `InvalidZapLimits`, and is enforced by `ZapTooLarge` and `ZapMovesPrice`. | Extend my recorded position with the actionability ground and the caps' continued role, so the open question is framed as "does a named consumer need a number it cannot otherwise obtain" rather than "is there a standard getter to map onto". The 2-2 split stays open; this is a correction to the stated ground, not a position change. |
| MM-F6 | Proposed text, `previewWithdrawalMode` paragraph, second sentence ("For a single-token exit, the accepted quote is `previewExchangeIn`") | The mapping is stated without argument roles, and `previewExchangeIn` is ambiguous without them, since the share may be either `tokenIn` or `tokenOut` on this route family. My original named them: the paired exit is `previewExchangeBundleOut(tokenIn = share, amountIn = shares, tokensOut = [C0, C1])` and the single-token exit is `previewExchangeIn(tokenIn = share, amountIn = shares, tokenOut)`. | Name the argument roles in the Proposed text so the report is unambiguous for whoever implements the family. |
| MM-F7 | Draft identity, "Fingerprint: not computed" | The draft's identity section leaves the fingerprint uncomputed while the coordinator supplied a SHA-256 to the reviewers, which I independently confirmed against the raw file. The draft therefore has no recorded stable identity for the advisory pass. | Record the fingerprint in the draft's identity section, together with the fact that reviewer-side verification was performed against the raw file. Procedural only; it changes no member's position. |

## What was not adopted from others

- Peer responses read: not read
- Peer feedback read: not read
- Unread members treated as support: no

The draft attributes positions to Astra, Grok, and Kimi. I did not read their files, so I adopt nothing from them and cannot verify the draft's unanimity claims. Where I quote a peer's recorded position, I quote the draft's own cell, not the peer's original. My concerns concern the accuracy of the record of my own original and the completeness of the downstream consequences; they are not an assessment of the other three responses.

## Limits

- Advisory only. The coordinator decides acceptance, rejection, or deferral.
- This file grants no implementation authority, does not lock the PRD or the function-review file, and does not amend the draft or any accepted report.
- No test, build, simulation, or deployment was run for this pass. The only command used was the authorized `shasum -a 256` over the draft's raw bytes; the stage-one PRD was re-read narrowly to confirm three inherited row texts quoted in the concerns table.
- Peer originals and peer feedback were not read, so the draft's claims about unanimity and its attributions to the other three members are outside my verification.
- This advisory neither replaces my original response nor authorizes implementation, and I request no further round.
- Inherited parent permissions are not evidence of confinement.
