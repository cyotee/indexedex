# Grok execution confirmation — REQ-06

- **Reviewer:** Grok (`ses_ec4128917ffeeVds3Y2p7xrVjp`)
- **Date:** 2026-10-18
- **Plan:** `docs/reviews/apex-req-06-max-redeem/REMEDIATION_PRD.plan.md`
- **Report:** `docs/reviews/apex-req-06-max-redeem/EXECUTION_REPORT.md` exists. It is an untrusted claim.

## Verdict

One test gap remains. The production change matches the ruling.

## Confirmed

- `ReceiptBackedERC4626Target.sol:73-76`: `maxRedeem` calls `_requireFamily()` and returns `ERC20Repo._balanceOf(owner)`.
- `_redeemFitsReceipts` and `_largestRedeemableShares` are gone.
- The named behavior tests expect the share balance. SharedFacet line 183 expects `IERC20(se2).balanceOf(u)`.
- No shortfall branch or receipt cap was added. `previewRedeem`, `maxWithdraw`, `redeem`, and `withdraw` were not given a new cap. `maxWithdraw` still returns `previewRedeem(maxRedeem(owner))`.
- The saved Forge log was not rerun. The report says the directory command failed and the executor stopped.

## Gap

- **Defect class:** Stale test expectation.
- **File and line:** `test/foundry/spec/vaults/standard/erc4626/ReceiptBackedERC4626_SharedFacet.t.sol:182`. The following `withdraw(1)` expectation at lines 185–186 still encodes a maximum of 0.
- **Impact class:** The prescribed directory run cannot pass. After the 100 ether deposit, the unchanged `maxWithdraw` is the preview of the share balance, not a receipt cap of 0.
- **Fix direction:** Expect `maxWithdraw(u)` to equal `previewRedeem` of that share balance, and expect the withdraw rejection to use that maximum. Do not change production. Do not add a shortfall branch or a receipt cap.

I did not run Forge.
