# Remediation PRD — REQ-06 maxRedeem is the share balance

- **Status:** DRAFT
- **Date:** 2026-10-17
- **ID:** REQ-06
- **Review target:** `contracts/vaults/standard/erc4626/ReceiptBackedERC4626Target.sol:74-81`
- **Inputs:** Owner ruling, 2026-10-17. The September receipt-limited search is withdrawn.
- **Astra participation:** Not sent. This is an owner ruling.
- **Runtime:** No Forge run.

Writing this PRD does not authorize implementation.

## Required outcome

`maxRedeem(account)` returns that account's share balance. Nothing else.

## Owner ruling

The claimable value already follows the deployed reserve. The vault is not short of receipts. There is no smaller-share search and no shortfall case to handle. `maxRedeem` is the account's balance.

## REQ-06-1 — Return the share balance

- **Severity:** Low
- **File and line:** `contracts/vaults/standard/erc4626/ReceiptBackedERC4626Target.sol:74-81`. The helpers at `:173-196` exist only for the withdrawn search.
- **Intended behavior:** After `_requireFamily()`, return `ERC20Repo._balanceOf(owner)`.
- **Broken requirement or invariant:** The function still searches for a smaller share amount when the preview does not fit in held receipts.
- **Acceptance criteria:**
  - Replace that search with `return ERC20Repo._balanceOf(owner);`.
  - Delete `_redeemFitsReceipts` and `_largestRedeemableShares`.
  - Do not add a receipt check, a shortfall branch, or a smaller-share search anywhere in this item.
- **Non-goals:** Do not change `previewRedeem`, `maxWithdraw`, `redeem`, or `withdraw`. Do not add a public selector.

## REQ-06-2 — Tests expect the balance

- **Severity:** Low
- **File and line:**
  - `test/foundry/spec/vaults/standard/erc4626/behaviors/Behavior_ReceiptBackedERC4626_CrossInterface.sol:202-211` and `:233`.
  - `test/foundry/spec/vaults/standard/erc4626/ReceiptBackedERC4626_SharedFacet.t.sol:183` and `:187-188`.
- **Intended behavior:** `maxRedeem` equals the account's share balance.
- **Broken requirement or invariant:** Tests still expect a reduced cap or zero because of receipt capacity.
- **Acceptance criteria:**
  - Assert `maxRedeem` equals the owner's share balance in those tests.
  - Delete assertions that the result is smaller than the balance or zero because receipts are limited.
  - Delete the `redeem(1)` expectation of `ERC4626ExceededMaxRedeem` with a maximum of 0.
  - Leave `test_maxRedeem_fullBalancePayableAtNonIntegralRate`. It already expects the balance.
  - Leave `APEX_D46_CapacityFixtures.t.sol:83`. That is a different contract.
- **Non-goals:** Do not add a shortfall test. Do not change `ShortRedeemERC4626`.

## Dissent

The earlier draft of this PRD treated a short receipt balance as a remaining failure. That was wrong. The owner rejected it.

## Unverified

This review did not run Forge.
