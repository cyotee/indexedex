# Astra — REQ-06 closed implementation draft

**Replacement-session original.** I am the labeled replacement and do not recall `ses_ec412bcc2ffejKLo7nuoEAqbV0`. No other reviewers' notes were read. The controlling document is `docs/reviews/apex-req-06-max-redeem/REMEDIATION_PRD.md`, read in full. Its owner ruling withdraws receipt-limited redemption-cap searches. This draft is not implementation authorization.

## Scope and preflight

Change only:

1. `contracts/vaults/standard/erc4626/ReceiptBackedERC4626Target.sol`.
2. `test/foundry/spec/vaults/standard/erc4626/behaviors/Behavior_ReceiptBackedERC4626_CrossInterface.sol`.
3. `test/foundry/spec/vaults/standard/erc4626/ReceiptBackedERC4626_SharedFacet.t.sol`.

Direct reads confirm the cited starting state: production **74–81** still calls the two helpers at **173–196**; behavior **202–212** still expects and redeems a reduced cap, and **233** expects zero maxRedeem; SharedFacet **183,187–188** still expects zero maxRedeem and the zero-maximum redeem rejection. No anchor drift was observed.

Before later authorized edits, recheck those exact functions and blocks. If a cited line or surrounding block differs from this starting state, stop and report the file, location and observed difference. Do not choose another site or substitute a new policy. Preserve unrelated existing worktree changes.

## 1. Exact production edit

Replace the two-line capacity-qualified NatSpec at 72–73 with:

```solidity
    /// @dev Returns the owner's full share balance for a supported accounting family.
```

Replace `maxRedeem` with exactly:

```solidity
    function maxRedeem(address owner) public view virtual returns (uint256) {
        _requireFamily();
        return ERC20Repo._balanceOf(owner);
    }
```

Delete both helpers completely:

- `_redeemFitsReceipts(uint256 shares, uint256 receipts)` at original **173–176**.
- `_largestRedeemableShares(uint256 balance, uint256 receipts)` at original **179–196**, including its now-obsolete NatSpec at 178.

Do not retain the old receipts read, zero-preview filter, early balance branch or any search. The direct balance return already handles a zero balance. Do not move receipt-cap logic into another function. Keep `_requireFamily()` and its implementation unchanged.

Scoped searches of `contracts/**/*.sol` and `test/**/*.sol` found the helper names only in this production file's definitions and the existing maxRedeem calls. This supports deleting them together; it is not a compilation result. Keep imports unchanged: `IERC20`, `IERC4626`, the accounting library and error interfaces remain used elsewhere in the target.

Leave `previewRedeem`, `maxWithdraw`, `redeem`, `withdraw`, dispatch, accounting library, share decimals and public selectors unchanged. Add no shortfall branch, receipt check, fallback or new error.

## 2. Exact behavior-test changes

File: `test/foundry/spec/vaults/standard/erc4626/behaviors/Behavior_ReceiptBackedERC4626_CrossInterface.sol`.

### A. Replace the withdrawn reduced-cap test

Replace original **189–213**, including its stale comment and name, with:

```solidity
    /// @dev maxRedeem returns the owner's share balance; maxWithdraw follows its preview.
    function test_maxRedeem_returnsBalanceAfterBackingChange() public {
        uint256 minted = _giveActorReceipts(2);
        vm.prank(_actor());
        IERC4626(_se()).deposit(minted / 2, _actor());
        _mintUnderlying(_se(), minted);
        uint256 more = _giveActorReceipts(1);
        vm.prank(_actor());
        IERC4626(_se()).deposit(more, _actor());
        uint256 balance = IERC20(_se()).balanceOf(_actor());
        assertEq(IERC4626(_se()).maxRedeem(_actor()), balance, "maxRedeem is the owner share balance");
        assertEq(IERC4626(_se()).maxWithdraw(_actor()), IERC4626(_se()).previewRedeem(balance));
    }
```

This preserves the existing setup and replaces the withdrawn cap oracle. Remove the old `held`, `fullPreview`, `cap` and `capPreview` locals; the comparison of full preview with held receipts; all reduced/payable-prefix assertions; and the old capped redemption, payout and receipt-debit assertions through line 212. Those statements depended on the deleted smaller-cap policy. Do not replace them with another shortfall scenario or expected transfer failure. The remaining assertions test the owner-selected balance result and the existing maxWithdraw relationship, without changing production maxWithdraw.

### B. Existing zero-preview fixture: expect the balance, not zero shares

Rename `test_maxRedeem_zeroPreviewIsNotAdvertised` at original 216 to exactly:

```solidity
test_maxRedeem_returnsBalanceWhenPreviewIsZero
```

Replace the preceding comment with:

```solidity
    /// @dev A zero asset preview does not reduce the owner's advertised share balance.
```

Leave the existing setup at **217–232** unchanged. Replace original **233** with:

```solidity
        assertEq(IERC4626(_se()).maxRedeem(_actor()), balance, "maxRedeem is the owner share balance");
```

Retain the existing maxWithdraw-zero assertion at 234, changing only its explanation to:

```solidity
        assertEq(IERC4626(_se()).maxWithdraw(_actor()), 0, "asset preview remains zero");
```

This updates an already named fixture as instructed; it adds no shortfall test or special production treatment. Do not remove or modify `test_maxRedeem_fullBalancePayableAtNonIntegralRate` at **171–187**, including its setup and assertions. Leave all other behavior tests unchanged. No new imports are needed.

## 3. Exact SharedFacet changes

File: `test/foundry/spec/vaults/standard/erc4626/ReceiptBackedERC4626_SharedFacet.t.sol`.

Rename the existing function at original 168 to `test_R14_18_localOnlyBacking_maxRedeemEqualsBalance`, and replace its preceding comment with:

```solidity
    /// @dev maxRedeem advertises the owner's shares independently of the asset preview.
```

Replace original **183** with:

```solidity
        assertEq(IERC4626(se2).maxRedeem(u), IERC20(se2).balanceOf(u), "maxRedeem is the owner share balance");
```

Delete exactly the old **187–188** pair: the `ERC4626ExceededMaxRedeem` expectation with maximum zero and its `redeem(1, u, u)` call. Preserve the existing fixture setup, receipt-balance assertion, maxWithdraw assertion, withdraw rejection and `vm.stopPrank()`. Do not replace the deleted call with a different error expectation or a new redemption scenario.

No other SharedFacet test changes. No imports are needed; existing error types remain used by the retained withdrawal check and other tests.

## 4. Explicit exclusions

- Keep `test/foundry/spec/vaults/standard/erc4626/APEX_D46_CapacityFixtures.t.sol` unchanged, especially line **83**. Direct read confirms that assertion concerns the separate `ShortRedeemERC4626` instance constructed at 82, not the shared target under repair.
- Do not change `ShortRedeemERC4626`, its behavior, or any other contract to force these tests green.
- Do not add a receipt cap, smaller-share search, shortfall branch or shortfall test anywhere in this item.
- No new public selector, fixture redesign, new test file, deployment, submodule change or skill synchronization.

## 5. One validation command for later authorized execution

From the IndexedEx root, default hermetic profile:

```bash
python3 scripts/forge-artifacts.py test \
  contracts/vaults/standard/erc4626/ReceiptBackedERC4626Target.sol \
  --test-root test/foundry/spec/vaults/standard/erc4626/behaviors/ReceiptBackedERC4626_CrossInterface.t.sol \
  --test-root test/foundry/spec/vaults/standard/erc4626/ReceiptBackedERC4626_SharedFacet.t.sol \
  --test-root test/foundry/spec/vaults/standard/erc4626/APEX_D46_CapacityFixtures.t.sol \
  -- -vv
```

The concrete CrossInterface host file—not just the abstract behavior—is selected. Direct read of its **15–17,51–53** confirms separate generic ERC-4626 and Aave Stata consumers inherit the behavior, so both dispatch families run. The unchanged capacity fixture is included as a preservation check, not an edit target.

The edited production source is supplied for the repository's required artifact refresh before runtime tests; deployment helpers can otherwise load stale bytecode. Run whole files with no test-name filter. Preserve `out/` and `cache_forge/`; do not enable `via_ir`, change source/test paths or select a fork profile. Allow actual compilation/test completion. This command is prescribed, not executed in this review.

If compilation, any retained assertion, or any changed assertion fails, stop and report the failing site and observed result. Do not infer a new owner shortfall requirement, restore the search, change maxWithdraw/previewRedeem/redeem/withdraw, weaken an assertion or expand scope to make the command pass.

## Acceptance and evidence

The scoped diff must contain only the maxRedeem simplification, removal of the two helpers and directly associated obsolete commentary, and the specified two test-file updates. Verify the excluded functions/tests remain unchanged and helper references are absent from current Solidity source. The later authorized execution must record the actual validation result; a saved log is not an independent reviewer rerun. No runtime outcome is established here.

Files examined: controlling PRD in full; target **1–240**; behavior **150–269**; SharedFacet **140–218**; the concrete CrossInterface host file in full; capacity fixture **65–87**; scoped Solidity helper-reference and behavior-inheritance searches. No peer artifacts were opened. The cited pre-edit ranges match the PRD; no separate audit report was supplied or assumed. The assigned output was absent before writing. Repository routing, canonical testing guidance and the artifact-aware workflow were read directly earlier in this session.

Only this assigned Markdown draft was created. No code, test, controlling PRD, final implementation plan, configuration or instruction file was edited. No delegation, shell, build, test or deployment was performed. Return to the coordinator/human and stop.

I did not run Forge.
