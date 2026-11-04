# Grok feedback on the implementor-gaps draft

## Identity

- Member: Grok
- Profile: research
- Run: se-fullspread-implementor-gaps-20261031-01a18660
- Draft ID: se-fullspread-implementor-gaps-20261031-01a18660-r1
- Path: docs/research/se-fullspread-implementor-gaps-20261031-01a18660/coordinator/draft.md
- Raw SHA-256: dcd2d1fd76fa2ebb501a074b1aa55b20d70173d494d104c190eec62ec5f9d0d5
- Check: `shasum -a 256` on that file matched. This is a review of that draft, not a substitute.

This feedback does not answer an owner question. It does not edit the PRD, the draft, or `response.md`. It does not authorize implementation.

## Disposition

The draft does not state every Grok question accurately. The rate-policy rejection, the raw-ETH entry correction, and most of the later questions are stated accurately. Four load-bearing questions are omitted or replaced by a different question. Several others are narrowed so an owner answer would not decide the fork in `members/grok/response.md`.

Questions below are quoted so the omission is visible. They are not answered.

## Stated accurately

- Not a current gap: a later rate policy is not an open implementor choice. That is G9. Do not add a rate question.
- Questions for the owner, question 1: the `MIN_SHARES` representation question. Accurate.
- Question 3: locked spend of local balances. Accurate as the locked-spend half of G3.
- Question 6: whether `PkgInit.poolManager` stays, and which step writes it. Accurate in substance. It drops the limit "already-named," which matters only so the step is not a new procedure.
- Question 9, and Preserved disagreements, Raw ETH entry: user entry is already nonpayable and no extension was added. The open choice is payout. Accurate.
- Question 13: which existing position-amount read and fee-owed read implement the deployed term. Accurate as the first half of G8.
- Question 17: `vaultTokens()` order. Accurate.
- Question 18: inherited domain. Accurate.
- Question 19: incompatible `wrappedNative`. Accurate.
- Question 24: FS-A38. Accurate.
- Question 26: `compound()` caller. Accurate.
- Question 28: deadline. Accurate.
- Question 29: one-token entry swap amount. Accurate. This is A1. Question 22 is not that question.
- Preserved disagreements, other-currency entry credit: Grok closes it from Weir and the accepted refund rule, and the draft does not vote that split closed. That process note is accurate. It is not an answer.

## Omitted load-bearing questions

### Not a current gap

The stale FS-OWN-07 sentence is correctly rejected. The next sentence is not. "Two narrower questions remain: an unknown token, and when the reserve snapshot is written" does not state G8.

Omitted question: do busy `reserves()` and `reserveOfToken()` return the FS-OWN-07 live sum, or the last committed snapshot?

Question 12 does not ask that. It asks when the snapshot is written. Question 11, the unknown-token return, is not a Grok question and is not that residual.

### Questions for the owner, question 12

Omitted question: which views are the busy-vault economic views that revert?

Question 12 asks which views revert while the operation guard is held. FS-A32 says busy. Those are not the same condition. The busy-view question is not asked elsewhere.

### Questions for the owner, question 27

Omitted alternative: on the locked path, if `pretransferred == true` does not revert, does the accepted pull and refund rule apply?

Question 27 asks only whether it reverts. A "no" does not decide the route. The borrowed-path rule is not reopened by restoring the alternative.

### Questions for the owner, question 2

Omitted fork: when a local balance is not the target percentage of that token's owned amount, what must the next deposit, compound, or withdrawal do, including no corrective action?

Question 2 asks after which operations the balance must be brought to target. That assumes enforcement. G3 does not. Question 4 states the compound fork accurately and is not a substitute for this question. Question 3 states locked spend accurately and is not a substitute either.

### Questions for the owner, question 5

Omitted withdrawal forks: on redemption, may the route revert, pull from the position, or leave the target unmet, rather than only pay from local balances or retain the target and reduce the payout?

Question 5 offers two outcomes. "Payout reduced" is not a Grok question. Revert, position pull, and no enforcement are the omitted forks.

### Questions for the owner, question 7

Omitted store: the `wrappedNative` binding may be an already-named package binding, not only a repo.

Question 7 asks which already-named repo stores it. G5 asked which already-named package or repo. The added write-step clause is not a Grok question.

## Inaccurate restatements

These questions are present, but the wording does not decide the fork.

- Question 10 should name the locked omissions: `poolManager`, family-only `poolKey`, `rateAsset`, `getRate`, and `wrappedNative`. The added clause, whether a Position facet exposes `poolKey` or that repo is storage-only, is not a Grok question.
- Question 14 should say "pay only the selected token's pro-rata amount," not "pay only the selected token." The selector half is accurate. The leave-the-rest half is accurate only with the pro-rata limit.
- Question 15 states the donate question. The clauses about the first share deposit and a locked PoolManager are not Grok questions.
- Question 16 must not stay in the owner-question list if the idle recommendation stands. A7 was closed. The recommendation states that close. Asking question 16 reopens it.

## Recommendations that close a gap

- The entry-credit bullet states the close in substance: refund word is unused declared input, the other-currency credit is transferred to the payer, no new return field, not booked without shares, and not an exit payout. It omits two sentences from the closing text: a bundle `amountsRefunded` element cannot carry a credit for a zero declared amount, and the entry route does not revert merely because that credit exists. Those are part of the close, not new owner questions.
- The idle bullet states the close accurately. It conflicts with question 16.
- The preview bullet does not state the close. "Not an entry rule" leaves full unwanted-leg consumption available as an exit-quote rule. The omitted replacement is: "`previewExchangeIn` is the amount-specific executable quote of `exchangeIn`. It does not assume full unwanted-leg consumption. `zapTo` is not installed." That still does not answer the one-token exit question. Question 14 correctly leaves that question open.

## Not Grok questions

Questions 8, 11, 20, 21, 22, 23, and 25 are not questions from `members/grok/response.md`. They are not corrections of a Grok question. Question 21 in particular is not a reopening I asked: the treasury-fee absence was closed, and no fee question was asked. This feedback does not answer any of them.

## Limits

- Hash checked with `shasum -a 256` before review. It matched. No other draft was reviewed.
- Peer responses were not read. The draft's attributions to Astra, MiniMax, and Kimi were not checked against their files.
- No owner question is answered here. No cap, fee, holder, return field, or selector is proposed.
- This feedback does not authorize a PRD edit or an implementation.
