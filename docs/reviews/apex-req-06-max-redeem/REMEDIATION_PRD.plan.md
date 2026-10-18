# Implementation plan — REQ-06 maxRedeem

- **Date:** 2026-10-17
- **Status:** Executed, including the follow-up. Closed 2026-10-18. Confirmation: `docs/reviews/apex-req-06-execution-confirmation/REMEDIATION_PRD.md`. Writing this plan did not authorize implementation.
- **Controlling PRD:** [REMEDIATION_PRD.md](./REMEDIATION_PRD.md). Where this plan conflicts with that PRD, the PRD controls.
- **ID:** REQ-06.
- **Council:** Astra replacement `ses_ebdc505a9ffeLLIq4HBAh44TYi` does not recall `ses_ec412bcc2ffejKLo7nuoEAqbV0`. Grok `ses_ec4128917ffeeVds3Y2p7xrVjp`. MiniMax replacement `ses_eb8ab99f3ffe7suGF49ryUzI6t` does not recall `ses_ebdf718feffemWQNf7wuTpapqX`. Kimi replacement `ses_ec3d04e91ffeJa0is24e2jZv06` does not recall `ses_ec41220c2ffeqs5Eha7fPsd54B`. Astra was not censored. No Forge run. Consensus is not proof.

## What to do

`maxRedeem` returns the account's share balance. Delete the smaller-share search.

## What not to do

- Do not search for a smaller share amount.
- Do not add a shortfall branch or a receipt cap.
- Do not change `previewRedeem`, `maxWithdraw`, `redeem`, or `withdraw`.
- Do not add a public selector.
- Do not change `ShortRedeemERC4626` or `APEX_D46_CapacityFixtures.t.sol`.
- Do not enable `via_ir`. Do not delete `out/` or `cache_forge/`.

## Step 1 — production

File: `contracts/vaults/standard/erc4626/ReceiptBackedERC4626Target.sol`.

Stop if `maxRedeem` is not the current search at lines 74–81, or if the two helpers at lines 173–196 are gone.

Replace the comment and function with:

```solidity
    /// @dev Returns the owner's share balance.
    function maxRedeem(address owner) public view virtual returns (uint256) {
        _requireFamily();
        return ERC20Repo._balanceOf(owner);
    }
```

Delete `_redeemFitsReceipts` and `_largestRedeemableShares`.

## Step 2 — tests

### Receipt-limited behavior test

File: `test/foundry/spec/vaults/standard/erc4626/behaviors/Behavior_ReceiptBackedERC4626_CrossInterface.sol`.

In `test_maxRedeem_capsWhenHeldReceiptsCannotPayFullBalance`, keep the fixture through the `fullPreview > held` assertion. Replace the cap computation, the smaller-than-balance assertions, and the `redeem(cap)` block, including any assertion that uses `paid`, with:

```solidity
        assertEq(IERC4626(_se()).maxRedeem(_actor()), balance, "maxRedeem is the share balance");
        assertEq(IERC4626(_se()).maxWithdraw(_actor()), fullPreview, "maxWithdraw follows that balance");
```

### Zero-preview behavior test

In `test_maxRedeem_zeroPreviewIsNotAdvertised`, replace the `maxRedeem` assertion that expects 0 with:

```solidity
        assertEq(IERC4626(_se()).maxRedeem(_actor()), balance, "maxRedeem is the share balance");
```

Leave the `maxWithdraw` assertion.

### Shared facet

File: `test/foundry/spec/vaults/standard/erc4626/ReceiptBackedERC4626_SharedFacet.t.sol`.

The account deposits 100 ether before the assertion. Replace the `maxRedeem` assertion that expects 0 with:

```solidity
        assertEq(IERC4626(se2).maxRedeem(u), IERC20(se2).balanceOf(u), "maxRedeem is the share balance");
```

Delete the `redeem(1)` expectation of `ERC4626ExceededMaxRedeem` with a maximum of 0, and that call. Leave the `maxWithdraw` assertion and the `withdraw(1)` expectation.

Leave `test_maxRedeem_fullBalancePayableAtNonIntegralRate`.

## Step 3 — one command

From the IndexedEx root:

```bash
python3 scripts/forge-artifacts.py test \
  contracts/vaults/standard/erc4626/ReceiptBackedERC4626Target.sol \
  --test-root test/foundry/spec/vaults/standard/erc4626 \
  -- -vv
```

Run the whole directory. If a test fails, stop and report it. Do not add a search, a cap, or a shortfall branch to make it pass.

Record the result in `EXECUTION_REPORT.md`. A saved log is not an independent reviewer rerun.

## Follow-up — stale withdrawal assertion

The production edit is present. `ReceiptBackedERC4626_SharedFacet.t.sol:182` still expects `maxWithdraw` to be 0. That assertion is wrong. `maxWithdraw` is `previewRedeem` of the share balance.

In `test_R14_18_localOnlyBacking_zeroReceiptExitCapacity_exactReverts`, replace lines 182–186 with:

```solidity
        uint256 shares = IERC20(se2).balanceOf(u);
        uint256 advertised = IERC4626(se2).previewRedeem(shares);
        assertEq(IERC4626(se2).maxRedeem(u), shares, "maxRedeem is the share balance");
        assertEq(IERC4626(se2).maxWithdraw(u), advertised, "maxWithdraw follows that balance");
        vm.expectRevert(abi.encodeWithSelector(
            IERC4626Errors.ERC4626ExceededMaxWithdraw.selector, u, advertised + 1, advertised
        ));
        IERC4626(se2).withdraw(advertised + 1, u, u);
```

Do not hardcode the observed preview. Do not add a receipt cap or a shortfall branch. Re-run the same Forge command. If it returns different bytes, stop and report them.

## Done when

- `maxRedeem` returns the share balance.
- The two search helpers are gone.
- The named tests expect that balance.
- No other production function changed.
- The one Forge command has been run and its result recorded.
