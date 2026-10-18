# Grok follow-up confirmation — REQ-06

- **Reviewer:** Grok (`ses_ec4128917ffeeVds3Y2p7xrVjp`)
- **Date:** 2026-10-18
- **Plan:** `docs/reviews/apex-req-06-max-redeem/REMEDIATION_PRD.plan.md`
- **Report:** `docs/reviews/apex-req-06-max-redeem/EXECUTION_REPORT.md` exists and records the follow-up. It is an untrusted claim.

## Verdict

No implementation gap.

## Confirmed

- `ReceiptBackedERC4626Target.sol:73-76`: `maxRedeem` calls `_requireFamily()` and returns `ERC20Repo._balanceOf(owner)`.
- `_redeemFitsReceipts` and `_largestRedeemableShares` are gone.
- The named behavior tests expect the share balance at `Behavior_ReceiptBackedERC4626_CrossInterface.sol:202` and `:224`.
- `ReceiptBackedERC4626_SharedFacet.t.sol:182-189` no longer expects `maxWithdraw` to be 0. It reads `shares`, sets `advertised` from `previewRedeem(shares)`, expects `maxRedeem` and `maxWithdraw` to match those values, and expects `withdraw(advertised + 1)` to revert `ERC4626ExceededMaxWithdraw` with that maximum. No preview amount is hardcoded.
- No receipt cap, smaller-share search, or shortfall branch was added. `previewRedeem`, `maxWithdraw`, `redeem`, and `withdraw` were not given a new cap. `maxWithdraw` still returns `previewRedeem(maxRedeem(owner))`.

The report claims the same directory command later exited 0 with 175 passes. That log was not rerun.

I did not run Forge.
