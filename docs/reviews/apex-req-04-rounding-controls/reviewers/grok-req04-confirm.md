# Grok confirmation — REQ-04

- **Reviewer:** Grok (`ses_ec4128917ffeeVds3Y2p7xrVjp`)
- **Date:** 2026-10-16
- **Plan:** `docs/reviews/apex-req-04-rounding-controls/REMEDIATION_PRD.plan.md`
- **PRD:** `docs/reviews/apex-req-04-rounding-controls/REMEDIATION_PRD.md`
- **Untrusted claim:** `EXECUTION_REPORT.md` says the follow-up passed 175 focused rows and 3,642 suite tests. That claim was not treated as proof. A saved log is not an independent rerun.

## Verdict

The amended plan was executed accurately. No gap.

The owner follow-up supersedes the original ban on editing Dual production. The Dual edit that is present is the one that follow-up names.

## What was checked

- Balancer `previewSingleJoinExactInShares` returns 0 when the converted amount is 0 and before the invariant subtraction when the next invariant is not greater. `_entryPreviewDepositSingle` calls `_quoteSingleJoinExactInPreview`. `_joinSingleAssetExactIn` uses that same quote and reverts `ZeroAmount()` before the pull. Strict `singleJoinExactInShares` still reverts on a zero amount.
- Curve `previewSingleJoinExactInShares` returns 0 when input is 0, when `D1 <= D0`, and when `D2 <= D0`. A zero share division returns 0. `_entryPreviewDepositSingle` routes the face quote through `_quoteSingleJoinExactInPreview`. `_joinSingleAssetExactIn` reverts `ZeroAmount()` before the pull. Strict `singleJoinExactInShares` still reverts `MathDomain()` at lines 455 and 463.
- Dual `DepositQuoteLib._swap` returns `(amountIn, 0)` when the sale is 0, before an underlying deposit transition. That is the authorized follow-up edit, not an edit of weighted, single-CP, or orbital production.
- The new preview function appears only in the two quad trees. I did not hash weighted, single-CP, or orbital production. Nothing I read in those families adds this quote.
- All six rounding controls require a successful preview that decodes to 0, then unchanged caller, hook, and booked balances. Weighted expects `MinAmountNotMet(uint256,uint256)` with arguments `1, 0`. Dual, single-CP, and orbital keep `InsufficientTokenOut()` or `ZeroAmount()`. Both quads require exactly `ZeroAmount()`. `previewMatch` and `vm.expectRevert(previewRet)` are gone from those controls.
- Orbital's preview staticcall is `previewDepositSingle(address,uint256)`. Its deposit execution call remains the six-argument form.
- Each share site captures `previewExchangeOut` on that file's face-leg SE before the call and checks `seBefore + mintedBack` against `sharesAfter + expectedDebit`.
- The positive one-unit overrides are `240384615373`, `240384613`, and `1`.
- The excluded non-CP behavior file is not one of the six edited controls.

I did not rerun the suite.

I did not run Forge.
