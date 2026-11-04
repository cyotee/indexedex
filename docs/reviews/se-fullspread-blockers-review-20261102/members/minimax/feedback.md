# MiniMax advisory feedback — draft-se-fullspread-blockers-review-20261102-r1

## Identity

| Field | Value |
| --- | --- |
| Member | minimax |
| Profile | review |
| Phase | advisory feedback on the coordinator draft |
| Draft | `docs/reviews/se-fullspread-blockers-review-20261102/coordinator/draft.md`, ID `draft-se-fullspread-blockers-review-20261102-r1` |
| Fingerprint | not computed. I did not compute or verify a hash, per the instruction. I opened the draft at that exact path. |
| Peer feedback read | none |
| Files written | `docs/reviews/se-fullspread-blockers-review-20261102/members/minimax/feedback.md` only |

## Disposition

**support-with-reservations.**

The draft's conclusion is right and its structure is right. It states the file's verdict accurately ("not ready to be the sole instruction for rewriting the PRD"), it preserves the disagreements rather than flattening them, it separates the PRD sentences that must not stay standing from the defects in the locks, and it records that the 32-byte consumer list and the full PRD invalidation list are not complete. I adopt the draft as the basis for the final report subject to the four corrections below and the three omitted minors. None of my reservations asks the owner to answer a product question, and none reverses a draft finding.

## Does the draft state my findings accurately?

Nine of my twelve findings are carried accurately and completely. Three are carried with a narrowing I cannot accept.

| My finding | Draft section | Accurate | Note |
| --- | --- | --- | --- |
| F1 `reserves()` composition | D3 | Partly | D3 carries the local-term half. The uncollected-fees half is dropped (C1). |
| F2 locks do not name the PRD sentences they invalidate | "PRD sentences a rewriter must not leave standing" | Partly | The table is right; the file-level fix is reassigned to the coordinator (C3). |
| F3 genesis credit stated two ways | D1 | Yes | One transcription slip in the fix direction (C5). |
| F4 fee scope across routes and previews | D11 | Yes | Correctly separates the fee-scope defect from the consumer-list defect. |
| F5 "the scarcer token" undefined | D5 | Yes | D5's impact reading of the scale-free ratio is sharper than mine in D9; I agree with it. |
| F6 booking the held balance vs the pretransfer credit | D4 | Yes | Correctly attributes the booking collision to me and the shortfall to Astra. |
| F7 `Compounded()` emission condition | D10 | Yes | Correctly framed as one emission rule per outcome. |
| F8 share unit still a choice | D9 | Yes | D9 states the external-unit consequence more sharply than I did. |
| F9 booking block has no identifier | D17 | Yes | |
| F10 quote pricing source still an implementor choice | D12 | Partly | The coverage table narrows my position to "the result only" (C2). |
| F11 64-byte consumer list still required | D16 | Yes | Correctly separates the deferral from a contradiction inside B-08. |
| F12 stale audit framing | D17 | Yes | The retitle and the 039 expectation are both there. |

The draft's "Preserved disagreements" table also states my positions correctly on the donation-versus-booking-rule interaction, the genesis cross-lock, and the quote engine. I did not support D2 as drafted, and the draft says so rather than implying agreement. That is the right call and I want it kept.

## Corrections by draft section

### C1. D3 — the fee-owed question is not required to be decided

**Section.** D3 (Requirement, Impact, Fix direction) and the "PRD sentences a rewriter must not leave standing" table, FS-OWN-07 row.

**Correction.** D3's requirement is "one return value for `reserves()` and `reserveOfToken` after the sleeve is gone", and its fix direction asks only what the local term contains and whether the snapshot sentence is deleted. The second half of the same conflict is not in the requirement: the booking section says "`reserves()` does not include the booked remainder or uncollected fees", while PRD FS-OWN-07 says the deployed term includes "fees owed to this position in that token and not yet collected". The invalidation table lists only FS-OWN-07's local-plus-deployed phrase, so its fee-owed clause is not marked as a sentence that may not stay standing.

**Why it matters.** A rewriter who follows the draft resolves the local term, keeps FS-OWN-07's fee-owed clause, and also applies the booking rule. The two answers differ by the whole fee accrual on the position, in a user-facing view. The draft's D3 does not require the question to be answered, so the draft does not close the finding as written.

**Advice.** Extend D3's requirement to name the fee-owed question explicitly as inside or outside the reserve, and add FS-OWN-07's fee-owed clause to the invalidation table. I am not answering it.

### C2. D12 and the N-04 coverage row — the draft narrows my finding, and its own condition is already met

**Section.** D12 (Fix direction) and "Coverage adopted from responses", row "N-04 | defect on the result only | Astra, Grok, MiniMax | D12. Kimi's mechanism position is preserved."

**Correction.** Two parts. First, D12's fix direction says "Do not require the owner to pick the V4 quoter versus an analytic planner unless that choice changes the result", but the choice does change the result: a quoter simulates a path and a planner computes, so the quoted amount and the gas differ, and the PRD's own FS-A31 caps a preview at 5,000,000 gas while B-07 exposes the Quoter as one of the seven stored components. D12's condition is therefore already triggered, and the draft has not discharged the finding it names. Second, the coverage row labels N-04 "defect on the result only", which does not match the draft's own "Preserved disagreements" row, which says "MiniMax treats the pricing source as still an implementor choice". The draft contradicts itself between those two tables.

**Advice.** Make D12 state either that the engine choice changes the quoted amount and the gas, and therefore needs an owner lock or an explicit plan owner, or that the quoted amount is engine-independent, which nothing in the file establishes. Then correct the coverage row so it matches the disagreements row. Separately, D12 does not carry the third limb of N-04's own question, deployment tick-spacing acceptance; FS-OWN-22 answers it, so the draft should either cite that answer or record the limb as still open.

### C3. "PRD sentences a rewriter must not leave standing" — the file itself stays incomplete

**Section.** "PRD sentences a rewriter must not leave standing" and "Evidence gaps", third bullet.

**Correction.** My F2 was that the locks' own "PRD:" lines name only some of the PRD sentences they invalidate, so the blockers file, not only the coordinator, carries an incomplete rewrite instruction. The draft reallocates the work: the table is the coordinator's, the draft says so, and "A complete pass still has to read every PRD sentence the locks touch". That is a fair division of labor for this run and the draft is honest that its table is partial. What is missing is a revision item against the file itself.

**Why it matters.** If the blockers file is the artifact that gets revised after this council, and its per-lock "PRD:" lines are left as they are, the next pass repeats the same exhaustive search that produced this table, and the file remains less than a complete rewrite instruction even after the revision. The draft records the gap as coordinator work only.

**Advice.** Add to the final report one of two items: extend each lock's "PRD:" line to the sentences it invalidates, or add one blanket removal rule in "How to use this file" naming the classes of sentences the sleeve drop, the auto-compound removal, and the fee netting delete. If the coordinator intends to own the enumeration instead, say that in the final report so the file is not read as complete.

### C4. "Consistent enough to copy" and D-list — three minor findings from my response are not carried

**Section.** The D1–D17 list and the "Coverage adopted from responses" rows for B-05, B-06, and B-07.

**Correction.** Three of my minor findings are absent, and the B-05 coverage row is therefore incomplete.

- **M1, B-05 zero-supply revert has no error identity.** The lock says `donate` "reverts when `totalSupply` is zero" with no error named, and the PRD's error list is otherwise closed, so two implementors declare two different errors for one condition. The coverage row for B-05 says "MiniMax did not treat B-05 as a defect"; that is true of the D2 interaction but not of the error identity.
- **M2, B-07 names a repo but wires the package by facet.** The lock takes "that facet as a package input" and writes the seven addresses into "the Uniswap V4 Protocol Aware Repo". If the repo is a separate contract, initialization needs a path to it, which is a second package input or a linked component and changes the manifest FS-PKG-01 enumerates; if the facet owns the slot, the manifest differs. D15 settles the "second copy" reading and the `StateView` rule but not how initialization reaches the repo.
- **M3, `previewExchangeOut` returns a bare `uint256`, so its zero reads as a quote.** The shared interface declares `previewExchangeOut(...) returns (uint256 amountIn)`, so the locked "returns zero" means zero input required to obtain amountOut, which a caller cannot distinguish from a real quote. The invalidation table covers the FS-A09 revert sentence but not the sentinel semantics.

**Advice.** Record M1, M2, and M3 as minor copyability items, or state that they are deliberately out of scope for the final report. All three are one-sentence additions and none asks an owner decision.

### C5. D1 — transcription slip in the fix direction

**Section.** D1, Fix direction, final sentence.

**Correction.** The sentence reads "Later deposits keep `added liquidity * totalSupply / existing liquidity`". B-10's formula is `added liquidity * totalShares / existing liquidity`, and B-01 uses `grossShares`. The fix direction is meant to be copyable prose, and `totalSupply` points a rewriter at the wrong variable in a formula that is the point of the sentence.

**Advice.** Correct the variable name.

## What I do not dispute

- The draft's "Proposed text" verdict and its two-part framing: the locks agree with each other, and the defects are cross-lock naming and leftover observable choices. That matches my response.
- D1, D4, D5, D9, D10, D11, D16, D17 and the invalidation table's substance.
- The "Not a defect" list, including that a lock differing from the current PRD is not a defect, and that N-01, N-06, and N-07 need no owner decision.
- The preserved-disagreement treatment. In particular, keep the row that records that MiniMax's coverage did not treat the donation-versus-booking-rule interaction as a defect, and keep D2's framing that the booking rule governs the combined balance.
- The Evidence gaps section, including that the consumer list and the invalidation table are partial.
- D8's handling of the `feeTo()` identity and D14's handling of the WETH package input. I did not raise either, and the draft's framing is right: the sentence cannot be copied as written, and the owner's intent is not rejected.

## Limits

- I read only the coordinator draft at the path named above, in this pass, and I did not open the blockers file, the PRD, the directive, any peer response, or any peer feedback. Line references to the blockers file and the PRD are from my own initial pass earlier in this conversation.
- I did not compute or verify any fingerprint or hash, and I did not review a different draft.
- I did not run Forge, tests, installs, deployments, or Git, and I edited no file other than this one.
- I did not answer any open product question: the share scale, the scarcer-token formula, the `feeTo()` identity, the failed-quote result, and the fee-owed composition of `reserves()` remain for the owner.
- This feedback is advisory. It does not replace the draft, does not authorize implementation, and does not authorize a PRD edit.
