# Member feedback

## Identity

- Run ID: apex-012-prd-clarity-20261024
- Member label: minimax
- Phase: advisory review
- Owned path: docs/reviews/apex-012-prd-clarity-20261024/members/minimax/feedback.md
- Requested role: council-member
- Actual role, model, reasoning, task ID, and session ID: not exposed
- Fresh or continued: continued
- Initial response path: docs/reviews/apex-012-prd-clarity-20261024/members/minimax/response.md
- Initial response preserved: yes

## Draft reviewed

- Draft ID: draft-apex-012-prd-clarity-20261024-r1
- Path: docs/reviews/apex-012-prd-clarity-20261024/coordinator/draft.md

## Disposition

support-with-reservations

## Concerns

**Check result first.** Of the ten contract-changing requirements questions in my initial response, nine are carried into the draft's thirteen questions with their substance intact (mint basis, idle/sleeve, counter equations, entry swap, locked pool, exit execution, transition and quote surfaces, V3 family, harvest mutations). The tenth — the projected-state contract of `quoteRate` — survives only as a disposition question inside the draft's Q10 ("does it execute or report the new accounting, or is it a labeled non-executing preview?"), which asks for a disposition but not for the projected-versus-static choice I flagged; that choice changes what the function returns for a supplied state. I do not read this as a drop, but the final artifact will need it stated. The draft adds five contract-changing questions I did not raise (uncollected fees, first deposit, other surfaces, the older constant-product mandate, and the same locked-pool point from the defect side), all of which I checked against the PRD and the V4 sources and none of which I dispute.

I also checked for an invented economic design and found none. The draft states the verdict, the agreed gaps, the divergence alternatives, the already-decided owner rulings, and the limits; it does not propose a mechanism, a formula, or a replacement model. The one place where wording could be read as a design assertion is the rebalance item (C3 below), and there the draft is quoting the PRD's own two sentences rather than adding a position.

**C1 — The V3 `slot0` conflict from my D8 is not carried, and it is a contract-changing question, not only a wording one.**
- What the draft got wrong or dropped: PRD l. 18 forbids `slot0` on the V3 deposit/redeem path ("On V3 that ban includes `slot0` and a simulated swap through the current book"), while l. 53 requires the exit to split the slice into its two token amounts "at the current tick". On V3 the slice composition cannot be computed without reading the pool's current tick, so under a literal reading of l. 18 the V3 exit as specified is unimplementable, and under the charitable reading (the ban targets valuation, not composition reads) it is implementable. Those two answers produce different V3 contracts. The draft's Q4 asks whether the *entry* size may be computed from the current tick on both families; that is adjacent but is the entry side, not the redeem-side split that l. 53 mandates.
- Smallest change: add one question to the list — "May the V3 redeem path read the pool's current tick to split the removed slice into target and other, given that l. 18 forbids `slot0` on the V3 money path and l. 53 requires the current tick?" — and, if the coordinator prefers to keep thirteen, fold it into Q5 as a second sentence.

**C2 — The LP-fee half of the counter question was dropped.**
- What the draft got wrong or dropped: the draft's Q1 asks whether a deposit is credited gross or net of target spent in the entry swap, and how an exit is debited. It does not ask whether the credit for a swap the vault executed includes the LP fee the vault earns on its own trade in that same transaction. In Uniswap V4 the fee is taken from the swap input and credited to the pool's LPs, and the vault is an LP in that pool, so the fee accrues to the vault's own positions rather than arriving as swap output. The two answers produce two different counter values and therefore two different `getRate` values after any entry or exit.
- Smallest change: extend Q1 with one clause — "and does the credit for a swap the vault executed include the LP fee that the vault earns on that same swap?" — or fold it into Q1's "one equation per operation" closing line.

**C3 — Defect 8 states a flat contradiction where the PRD admits a reconciling reading, and it lacks a checkable locator.**
- What the draft got wrong or dropped: the draft asserts "Both sentences cannot stand" between "no function may sell the other token" (l. 66) and "This PRD does not change rebalance" (l. 74). The premise is factually right — the current V4 Wings rebalance executes a real swap (`UniswapV4UpperLowerWingsStandardExchangeVaultRebalanceTarget._reshape` l. 33, the `Common.Kind.Swap` operation at l. 41, sized by `RebalancePlanner.bestSwap` l. 11) — but the PRD's Non-goals bullet "No harvest, rebalance, or keeper call that sells the position's other token" can be read as "no such call is introduced" rather than "no such call may exist", and under that reading the two sentences reconcile and there is no contradiction at all. The final artifact will assert the contradiction as fact; an owner can rebut it with intent rather than with evidence, which would cost the document more than the wording is worth.
- Smallest change: keep the item, restate it as a reading question ("does the sell ban in l. 66 cover the existing rebalance swap, or only the entry/exit/harvest paths, given the Non-goals bullet?"), and add the two source locators so the claim is checkable. The draft's own Q9 already asks the question in this form; defect 8 and question 9 should use the same wording.

**C4 — Two minor omissions, both one-clause fixes.**
- What the draft got wrong or dropped: first, the exit's settle order is never named: PRD l. 53 removes liquidity, l. 54 swaps, l. 55 pays, l. 56 burns the shares, and the draft's Q5 does not say whether the share burn happens before or after the swap. That order is observable in V4, where the pool callback runs while the vault is mid-operation, so it changes what the callback sees. Second, the draft's Q8 asks whether harvest may close a converted wing and re-place inventory, but not whether such a close and re-place changes `settledTarget` or any holder's share fraction; the PRD's test 9 constrains the fee credit but not the re-placement, and the current V4 harvest does close and re-place (`Harvest.harvest` l. 118, `Harvest.close` l. 136, `Harvest.place` l. 147).
- Smallest change: add to Q5 "and in what order are the shares burned relative to the swap", and add to Q8 "and does a close and re-place change `settledTarget` or any holder's fraction".

**C5 — One locator in the draft is confirmed exactly; no change needed, recorded so the final artifact keeps it.**
- The draft's re-reading of the shared remediation PRD is correct: `contracts/vaults/standard/exchange/protocols/uniswap/UNISWAP_V3_V4_STANDARD_EXCHANGE_REMEDIATION_PRD.md` line 13 does require "the same V2-style constant-product/proportional-ownership model" for both new families, and the APEX-2026-012 PRD never mentions that document. The draft's caution that the conflict is real but is "not a reason to invent a third model" is the right posture. Keep the line-13 citation.

**C6 — The draft's surface inventory in Q10 is accurate; recorded so it is not dropped in the final artifact.**
- I verified each named surface exists in the V4 Wings family: `exchangeOut` at `UniswapV4UpperLowerWingsStandardExchangeVaultOutTarget.sol` l. 8, whose exact-output branch routes through `Money.redeemExactAssets` (l. 18) and whose input price comes from `Money.requiredInput` (l. 12), which is the banned quote path; `exchangeIn` at `UniswapV4UpperLowerWingsStandardExchangeVaultInTarget.sol` l. 10; `exchangeRate` at `UniswapV4UpperLowerWingsStandardExchangeVaultSYTarget.sol` l. 30; `quoteRate` at `UniswapV4UpperLowerWingsStandardExchangeVaultEconomicTarget.sol` l. 32; `liquidationValue` in `interfaces/IUniswapV4UpperLowerWingsStandardExchangeVault.sol`. The draft's observation that exact-output `exchangeOut` does not match "redeem `s` shares with a minimum target out" unless one of them is restated is correct and specific. No change needed.

## Limits

- Advisory only. This is not a veto, not consensus, and not a vote on the PRD; the coordinator's final artifact is theirs to write.
- I read only the draft, my own initial response, and the PRD plus the V4 Wings sources needed to check the draft's locators. I did not re-read peer responses, and I did not read the run record's later entries.
- Every source locator I cite above was re-checked against the files in this pass. No contract was compiled, no test was run, no script was simulated, and no deployment, install, commit, or file edit outside this owned feedback path occurred.
- The draft's statement that all four members recorded the same blockers is outside what I can verify; I confirm only that my own initial response supports the items attributed to minimax.
- C1 and C2 are the only items I assess as a dropped contract-changing question. C3 and C4 are precision and framing, not new findings. If the coordinator judges C1 to be covered by the draft's Q4 wording, that judgment is reasonable, and the only thing I would still ask for is that the l. 18 versus l. 53 conflict be visible in the final artifact in some form.
