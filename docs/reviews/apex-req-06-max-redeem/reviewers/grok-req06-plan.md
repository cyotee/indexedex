# Grok plan draft — REQ-06

- **Reviewer:** Grok (`ses_ec4128917ffeeVds3Y2p7xrVjp`)
- **Date:** 2026-10-17
- **Controlling text:** `docs/reviews/apex-req-06-max-redeem/REMEDIATION_PRD.md`

This draft does not authorize an edit. No implementer choice. No smaller-share search. No shortfall branch. No receipt cap.

## Stop first

Stop and report if `ReceiptBackedERC4626Target.sol:74-81` is not the receipt search, or if `_redeemFitsReceipts` and `_largestRedeemableShares` are not at lines 173–196. Stop if the named test lines no longer expect a reduced or zero `maxRedeem`.

## Production

Replace the comment and `maxRedeem` at lines 72–81 with:

```solidity
    /// @dev The account's share balance. No receipt cap.
    function maxRedeem(address owner) public view virtual returns (uint256) {
        _requireFamily();
        return ERC20Repo._balanceOf(owner);
    }
```

Delete `_redeemFitsReceipts` and `_largestRedeemableShares`, including their comments, at lines 173–196. Do not change `previewRedeem`, `maxWithdraw`, `redeem`, or `withdraw`. Do not add a selector.

## Tests

In `Behavior_ReceiptBackedERC4626_CrossInterface.sol`, replace lines 202–211 with:

```solidity
        assertEq(IERC4626(_se()).maxRedeem(_actor()), balance, "maxRedeem is the share balance");
```

Replace line 233 with:

```solidity
        assertEq(IERC4626(_se()).maxRedeem(_actor()), balance, "maxRedeem is the share balance");
```

Leave `test_maxRedeem_fullBalancePayableAtNonIntegralRate`.

In `ReceiptBackedERC4626_SharedFacet.t.sol`, replace line 183 with:

```solidity
        assertEq(IERC4626(se2).maxRedeem(u), IERC20(se2).balanceOf(u), "maxRedeem is the share balance");
```

Delete lines 187–188, the `redeem(1)` expectation of `ERC4626ExceededMaxRedeem` with a maximum of 0, and that call. Leave the `withdraw(1)` expectation.

Leave `APEX_D46_CapacityFixtures.t.sol:83`. Do not change `ShortRedeemERC4626`. Do not add a shortfall test.

## Command

```bash
python3 scripts/forge-artifacts.py test contracts/vaults/standard/erc4626/ReceiptBackedERC4626Target.sol --test-root test/foundry/spec/vaults/standard/erc4626/behaviors/ReceiptBackedERC4626_CrossInterface.t.sol --test-root test/foundry/spec/vaults/standard/erc4626/ReceiptBackedERC4626_SharedFacet.t.sol -- -vv
```

If a remaining assertion reverts with different bytes, stop and report them. Do not add a receipt cap.

I did not run Forge.
