# Astra — REQ-06 requirements check

**Replacement-session original.** I am the labeled replacement and do not recall `ses_ec412bcc2ffejKLo7nuoEAqbV0`. I read `docs/reviews/apex-req-06-max-redeem/REMEDIATION_PRD.md` in full. No other reviewers' notes were read.

**No blocking question. Ready.**

The owner ruling closes the required behavior: after `_requireFamily()`, `maxRedeem(owner)` returns `ERC20Repo._balanceOf(owner)`. The claimable value follows the deployed reserve; no receipt cap, shortfall branch or smaller-share search belongs in this item.

The draft also fixes the implementation and test boundaries:

- Remove `_redeemFitsReceipts` and `_largestRedeemableShares` (lines 28–30).
- Leave `previewRedeem`, `maxWithdraw`, `redeem` and `withdraw` unchanged; add no public selector (line 31).
- Update the named tests to assert the owner's share balance; delete receipt-limited reduced/zero-cap assertions and the specified `redeem(1)` zero-maximum rejection expectation (lines 42–44).
- Preserve the full-balance non-integral-rate test and the separate capacity fixture; do not change `ShortRedeemERC4626` or add a shortfall test (lines 45–47).

The withdrawn receipt-limited design is not a competing requirement. There is no remaining owner choice about capacity, amount selection, fallback behavior or a shortfall scenario. No closure sentence or additional product scope is needed.

This is a requirements-clarity assessment only. It does not verify implementation, compilation, runtime behavior or the owner ruling's economic premises independently. The PRD explicitly withholds implementation authorization and records that runtime remains unverified.

The supplied PRD was present. Only this assigned Markdown report was created. No code, tests, PRD, configuration or instruction file was edited. No delegation, shell, build, test or deployment was performed. Return to the coordinator/human and stop.

I did not run Forge.
