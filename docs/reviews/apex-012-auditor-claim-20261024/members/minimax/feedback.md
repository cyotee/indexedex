# Identity

- Run ID: `apex-012-auditor-claim-20261024`
- Member label: `minimax`
- Profile: `review`
- Phase: advisory feedback on draft `draft-apex-012-auditor-claim-20261024-r1`
- Owned path: `docs/reviews/apex-012-auditor-claim-20261024/members/minimax/feedback.md`
- Requested role: `council-member` (advisory review of the draft)
- Requested model: `minimax/MiniMax-M3`
- Peers read before submission: no
- Response file status: `members/minimax/response.md` left unmodified

Identity details beyond the fields above were not given to me and are not asserted here.

# Draft reviewed

`draft-apex-012-auditor-claim-20261024-r1`, at `docs/reviews/apex-012-auditor-claim-20261024/coordinator/draft.md` (the only artifact in the run carrying that Draft ID). The draft has sections "The claim, as the report states it", "The proposed fix, as the auditor states it", "Against the owner's clarification", and "Limits".

Reference material used for the check: the admitted report section `docs/security/audit/second_review/IndexedEx_DiffReview_aca16198-2ba07631.md` APEX-2026-012, report lines R:L268 to R:L326, and my own `members/minimax/response.md`. Citation convention below: `R:L###` = report line; `D` = the draft.

# Disposition

**The draft does not misstate the auditor's claim.** Every factual assertion I checked against R:L268-R:L326 matches the report, and the draft correctly refuses the framing the owner warned about.

Checked and correct:

- Pricing: `Money._deposit`/`_redeem` take the share price from `LiquidationQuote.quote()`, reading live `slot0`, `getLiquidity` and the tick bitmap, subtracting only the vault's own liquidity, and simulating the sale of the vault's opposing inventory into that depth (D, "The claim..."; R:L272, R:L284-R289). `issue = S*credit/V` and `entitlement = shares*V/S` (R:L280).
- The sequence: unlock, take D, deposit at V0 with harvest/place skipped, add unsettled full-range liquidity, redeem at V1 paid from the local sleeve, remove, repay D, keep `paid - D` (D; R:L295-R300). `profit = D*(V1 - V0 - D)/(V0 + D)` (R:L288).
- Numbers as stated: 70,634,405,953 called 7.1% of a 1e12 vault with zero capital; settled variant 74,704,386,253 called 7.5% of TVL, paying through `_fund` with no sleeve cap, using flash-loanable depth (D; R:L272, R:L302, R:L317). "Incumbent holders lose what the attacker gains" and "`HolderValueLoss` ... compares two quotes of the same inflated state" (D; R:L290, R:L317).
- Claim type: permitted calls, not an invalid selector or a reverted call; the attack satisfies the tested SEC-08 bound while the owner ruling does not waive SEC-08; the claim is that a permitted sequence changes the quote and the vault accounts the changed quote as share value (D; R:L319, R:L280). This is the right classification and it is the one the report supports.
- The two-channel point: "The heading names two inputs to one quote: temporary liquidity, and an in-session price move" and "That is a separate channel from adding and removing liquidity" (D). This matches the heading and the Impact paragraph, and it keeps the owner's "spot price is not intrinsically the problem" framing intact rather than adopting it as the report's claim (R:L268, R:L317).
- Fix fidelity: the `isUnlocked` revert plus the same guard on `getRate()`, `liquidationValue()` and the preview functions, and the report's own "only partly fixes the issue, because settled depth and flash-loaned spot moves still work" (D; R:L321). The remaining five items are paraphrased in the right order and with the right content (D; R:L322-R326). The draft correctly says it does not adopt them.

My disagreements are about omissions and about one of the draft's own "broader than the clarification" arguments, not about what the report says.

# Concerns

## C1. The draft's third "broader" point is the weakest and should be restated (or dropped)

The draft lists three places where the report is broader than the owner's clarification: the spot-move channel, unsettled depth inside one unlock, and "It prices both sides of the round trip: the deposit mints against `V0`, and the redeem pays against `V1`. The clarification speaks of the withdrawal amount" (D, "Against the owner's clarification").

The first two hold. The third does not, as written. The owner's clarification - "a shareholder could manipulate the amount they could withdraw by changing liquidity in the underlying reserve pool" - already implies the two-sided sequence: a shareholder who withdraws more than entitled must have shares minted earlier and then redeem them against a manipulated quote, which is exactly steps 3-5 of the report's in-unlock variant (R:L295-R298). The report prices both sides because the profit formula needs both sides, not because the clarification omits one. Restate this point as what it actually is - the report quantifies the effect and the attacker's advantage, where the clarification only asserts the possibility of manipulating a withdrawal amount - or drop it. Leaving it as a third "broader" item invites a reviewer to think the report covers ground the clarification never mentioned, when the substantive gap is elsewhere.

## C2. The draft drops the report's own scope condition on the headline number

The report qualifies its own impact numbers, and the draft presents them without that qualification. Two statements are omitted:

- "Per-transaction profit is capped by the pre-attack local target sleeve (`Money.sol:167-168`)" (R:L317).
- "As scripted, a Wings vault resolves to a 0% sleeve. That blocks the in-unlock variant (`InsufficientLocalTarget`) but not the settled variant" (R:L319).

This matters for the draft's most quotable sentence - "The stated in-unlock result is 70,634,405,953 raw token0, called 7.1% of a 1e12 vault, with zero capital" (D) - because in the production-scripted configuration the report says that variant does not run at all. A reader of the draft would carry away an unconditional headline the report itself conditions. The settled variant at 7.5% is the one the report says survives (R:L319), and the draft does report that number but not the fact that it is the surviving variant. Recommend one sentence carrying both caps forward.

## C3. The draft drops the scale, repeatability and attacker-set distinction I stated

The owner's clarification is one shareholder influencing the amount they can withdraw. The report claims more, and the draft never puts the two side by side on that axis: the take is 7.1%-7.5% of TVL per transaction, repeatable "once the sleeve refills" (R:L317), taken from the vault's local sleeve by an "unprivileged contract" (R:L272) that is not required to be an existing holder, and it does so with zero capital in the in-unlock variant or roughly 27x TVL of flash-loanable transient capital in the settled variant (R:L272, R:L317). The draft's line "the difference is accounted as a loss to the holders who remain" (D) is true but quiet on who takes the difference and how often. This is a distinct breadth point from the spot channel and from C1, and it is the one that most affects how the finding should be read.

## C4. The spot channel is asserted without its numbers or its cost

The draft says "A second sequence in the same finding moves the spot: swap, deposit, swap back to the original price, redeem. The auditor states a profit on that path as well" (D). The report gives that path figures - 53,661,742,003 at external L 1e12 and 33,284,087,429 at 1e11, with "0.3% swap fees paid" and the price restored exactly (R:L317) - and the fact that the spot path pays fees while the depth path pays none is what separates the two channels in cost terms. Without the numbers the breadth claim reads as an assertion; with them it is a demonstrated second channel that the report's own partial-fix sentence refers to as "flash-loaned spot moves" (R:L321). One clause would fix it.

## C5. The draft omits the finding's severity and deployment status

APEX-2026-012 is Severity High, Status "Latent: not deployed", family V4 UpperLowerWings (R:L270), and the findings index marks it Live: No (R:L74). The draft nowhere states this. For a document whose purpose is to explain the claim, the reader gets no signal about urgency or exposure, and the "not deployed" fact bears directly on the "Latent" framing that the section itself uses.

## C6. Supporting evidence dropped

Two items from the section would strengthen the draft's central assertions at low cost: the no-JIT control returning -1 (R:L317), which is the report's own isolation of the liquidity effect and is the direct evidence that the profit comes from added depth rather than from the round trip per se; and the depth-row variation, 70,634,405,953 at external L 1e12 against 9,777,515,150 (1.0%) at about 25x the vault's liquidity (R:L317), which shows the profit is not a fixed percentage. I verified both against the admitted PoC's own result table when I wrote my response.

## C7. Minor paraphrase losses in the fix section

"The rest of the list is a reference mark, a cap on the depth used in the simulated sale, a loss check against that reference, an optional exit fee, and a round-trip test for added depth" (D) compresses five items correctly, but drops the two operative details of item 1: the reference is a TWAP-bounded mark with a fixed haircut, and the asymmetry is mint at `max(V_live, V_ref)` and redeem at `min(V_live, V_ref)` (R:L322). "A reference mark" alone does not convey that the auditor's proposal is deliberately asymmetric between entry and exit, which is the part that answers the mechanism. Also, "the preview functions" (D) is a fair rendering of `preview`/`requiredInput` (R:L321), but naming both is free.

# Limits

- I reviewed only `coordinator/draft.md` against the admitted report section (R:L268-R326) and my own response. I did not open the peer member files, other findings, the vault sources, the PRD, or `ACCOUNTING_AND_RECOVERY.md`; the SEC-08, PRD l.334 and O1 references appear in the draft as the report states them and I did not verify them in their own documents.
- I ran nothing: no Forge, no tests, no git, no installs, no PoC execution. The numbers quoted here as coming from the report were checked earlier in this run by reading the admitted PoC result table only.
- C1 is my judgement about the strength of an argument in the draft, not a claim that the report says something different; the report's two-sided pricing is stated accurately in the draft and in my response.
- C2 and C3 are omissions from the draft, not misstatements: the draft nowhere asserts a configuration in which the report's own qualifier is contradicted.
- I proposed no vault change, no fix selection, and no redesign. Every measure referenced in C7 is the auditor's, quoted from R:L321-R326.
