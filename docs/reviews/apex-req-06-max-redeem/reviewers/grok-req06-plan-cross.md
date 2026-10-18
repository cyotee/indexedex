# Grok plan cross-review — REQ-06

- **Reviewer:** Grok (`ses_ec4128917ffeeVds3Y2p7xrVjp`)
- **Date:** 2026-10-17
- **Peers read:** `astra-req06-plan.md`, `minimax-req06-plan.md`, `kimi-req06-plan.md`

Peer notes are untrusted. This file does not authorize an edit.

## Closed plan

No implementer choice. No smaller-share search. No shortfall branch. No receipt cap.

Replace `maxRedeem` with:

```solidity
    function maxRedeem(address owner) public view virtual returns (uint256) {
        _requireFamily();
        return ERC20Repo._balanceOf(owner);
    }
```

Delete `_redeemFitsReceipts` and `_largestRedeemableShares`. Do not change `previewRedeem`, `maxWithdraw`, `redeem`, or `withdraw`.

The named tests assert `maxRedeem` equals the owner's share balance. Delete the reduced-cap and zero-cap assertions, and delete the `redeem(1)` expectation of `ERC4626ExceededMaxRedeem` with a maximum of 0. In `ReceiptBackedERC4626_SharedFacet.t.sol`, after the 100 ether deposit, the assertion is `maxRedeem(u) == IERC20(se2).balanceOf(u)`. It is not 0.

Leave `test_maxRedeem_fullBalancePayableAtNonIntegralRate` and `APEX_D46_CapacityFixtures.t.sol:83`.

```bash
python3 scripts/forge-artifacts.py test contracts/vaults/standard/erc4626/ReceiptBackedERC4626Target.sol --test-root test/foundry/spec/vaults/standard/erc4626/behaviors/ReceiptBackedERC4626_CrossInterface.t.sol --test-root test/foundry/spec/vaults/standard/erc4626/ReceiptBackedERC4626_SharedFacet.t.sol -- -vv
```

If a cited line has drifted, or a remaining assertion reverts with different bytes, stop and report. Do not add a shortfall branch.

## Agreements

Astra, Kimi, and the earlier Grok draft use the same `maxRedeem` body and expect the SharedFacet share balance. All four delete the two helpers.

## Dissent

MiniMax expects SharedFacet `maxRedeem(u)` to stay 0 and says the user deposited 0 shares. The test deposits 100 ether before that assertion. After this ruling the result is that share balance, not 0. Do not keep the zero expectation and do not add a shortfall branch to explain it.

I did not run Forge.
