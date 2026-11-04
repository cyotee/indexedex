# Member feedback

## Identity
- Run ID: apex-012-prd-clarity-20261024
- Member label: grok
- Phase: advisory review
- Owned path: docs/reviews/apex-012-prd-clarity-20261024/members/grok/feedback.md
- Requested role: council-member
- Actual role, model, reasoning, task ID, and session ID: not exposed
- Fresh or continued: continued
- Initial response path: docs/reviews/apex-012-prd-clarity-20261024/members/grok/response.md
- Initial response preserved: yes

## Draft reviewed
- Draft ID: draft-apex-012-prd-clarity-20261024-r1
- Path: docs/reviews/apex-012-prd-clarity-20261024/coordinator/draft.md

## Disposition
requested-changes

The verdict is right: the PRD is not clear enough that two implementers would build the same V3 and V4 Wings accounting. The draft does not invent a replacement ledger, mint, or swap. It does drop forks whose two answers still change the contract after its thirteen questions are answered, and question 2 writes one mint formula in a way that can be read as the proposed design.

## Concerns

1. Question 2 writes `shares * liquidityAdded / liquidityBefore`, summed across core and both wings, as the mint question. Agreed defect 1 correctly keeps three bases: one ratio across the three slots, the minimum slot ratio, or a target-balance ratio. Leading with the sum formula is a design lean, not only a fork. It also skips a funded vault whose wing liquidity is zero. Skipping that slot, reverting, and opening a range are different deposits, and line 24 already forbids the third. Smallest change: ask which of the three bases governs, what a zero-liquidity slot does, which of the liquidity-added sentence and the must-not-increase sentence wins, and that test 3's window must match the winner. Do not leave the sum formula as the only equation in the question.

2. Question 3 asks whether a share includes idle, whether an exit pays `s / S` of idle, and whether the sleeve remains. It does not ask whether unused target after the add is refunded to the depositor or booked as idle. Those two answers change token balances. Smallest change: add that fork to question 3. Do not pick refund or sleeve.

3. Question 8 asks whether harvest may close a converted wing and re-place, and whether deposit and redeem still harvest first. It does not ask what happens to other-token fees if the wing is not closed: leave them uncollected, book them idle, or compound them into liquidity. Compounding changes principal without a sale, so it survives a "no" to close-and-replace. Smallest change: add that disposition to question 8.

4. Question 4 asks the swap amount, the tick read, entry self-fill, and the other-token-only deposit. It does not ask when a three-slot position is "two-sided." A mixed core with single-sided wings is the normal Wings state. Keying off the aggregate and keying off one slot changes whether a swap runs. Smallest change: add that predicate to question 4.

5. Question 10 names `exchangeOut` and not the functions that price it. `depositExactShares`, `redeemExactAssets`, and `requiredInput` still price deposit and redeem from the quote. Answering question 10 for `exchangeOut` alone leaves those three on the old path. `quoteRate(state_)` also still has an ignore-versus-revert fork after projection is forbidden. Smallest change: name those three functions in question 10, and state the `state_` disposition. `liquidationValue` should not stay in the undecided list as if its existence were open. The 012 PRD already allows it to remain when it is not an input to deposit, redeem, or `getRate`. The open item is the executing callers.

6. The verdict says two implementers would share the economic policy and not the contracts. The shared bullets are bans and scope. The ledger, mint, and swap size are the policy, and they are not shared. Smallest change: say they share the prohibitions and the scope rulings, not the accounting equations.

7. Question 12 is a real added question, not a third model. I re-read the cited file. The constant-product sentence is the scope paragraph that requires new V3 and V4 Standard Exchange vaults to use the V2-style constant-product/proportional-ownership model. The 2026-10-15 header above it says other requirements in that document remain in force and names Upper/Lower Wings as a supported V4 consumer. The 012 PRD does not say it supersedes either sentence. Smallest change: cite that header with the scope paragraph, so the question is not only the older sentence. Do not answer it in the draft.

Question 13, locked or unlocked money calls, is a fair added question. I did not raise it. It does not choose revert or proceed. No change.

I am not confirming the draft's attributions to the other three responses. I did not read them. My own blockers are in the agreed-defect list. The disagreement sentence that every extra item is a narrower case of the thirteen is wrong for concerns 1 through 5: those forks remain after the thirteen are answered.

## Limits
This disposition is advisory. It is not a veto and not consensus. `response.md` was not overwritten. The source PRD and the draft were not edited. Peer response files were not read. The only file opened besides the draft and my own response was the remediation PRD cited in question 12, to check that citation. Static reading only. No economic design is proposed here.
