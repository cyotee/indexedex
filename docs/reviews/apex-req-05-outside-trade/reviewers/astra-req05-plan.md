# Astra — REQ-05 implementation draft

**Replacement-session original.** I am the labeled replacement and do not recall `ses_ec412bcc2ffejKLo7nuoEAqbV0`. No other reviewers' notes were read for this draft. Controlling text: `docs/reviews/apex-req-05-outside-trade/REMEDIATION_PRD.md`, read in full. Its owner ruling supersedes my earlier wings-only recommendation. This draft does not authorize implementation.

## Closed scope

Strengthen the existing `test_outsidePoolTradeDoesNotRefreshVaultBook` in exactly these three files, under `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/`:

1. `v4/fullSpread/hookless/AttributionAndBooking.t.sol`.
2. `v4/fullSpread/ponsFamilyV2Hook/AttributionAndBooking.t.sol`.
3. `v4/upperLowerWings/UniswapV4UpperLowerWingsStandardExchangeVaultMoney.t.sol`.

Leave `v3/UniswapV3FullSpreadLocalBook.t.sol` unchanged. Cite its existing outside-trade credit assertions at 68–75 and helper at 114–136 as V3 coverage. Do not add a duplicate V3 test, edit production, change fixtures, restore deleted V4 or cite reserve reconciliation as the credit proof.

## Preflight and fixed token/caller choices

Current direct reads show the cited tests still match: hookless **34–49**, Pons **37–52**, wings **26–40**. Each snapshots both books and supply, performs the existing outside pool trade, asserts unchanged books/supply, then runs a funded preview-parity continuation. No drift was observed. At implementation time, stop and report if any cited sequence differs; do not relocate the edit or choose another token/route.

| Family | Named input token | Vault | Caller and recipient | Fixed transfer |
|---|---|---|---|---|
| Hookless | `token0` | `address(vault)` | Test contract, `address(this)` | `7 ether` |
| Pons | `token0` | `address(vault)` | Test contract, `address(this)` | `7 ether` |
| Wings | `token0`, the target of `wings0` | `address(wings0)` | Test contract, `address(this)` | `7 * 10 ** uint256(token0.decimals())` |

**Wings decimal fact:** its base creates one 6-decimal and one 18-decimal token, then sorts them (`TestBase_UniswapV4UpperLowerWingsStandardExchangeVault.sol:35–38`). Consequently `token0` is not statically guaranteed to have 18 decimals. The expression above follows controlling PRD line 36 exactly: seven whole token units, equal to `7 ether` for the 18-decimal token and seven million raw units for the 6-decimal token. Do not blindly use `7 ether` for a 6-decimal fixture or select the opposing token. This is a deterministic rule, not an implementer choice. Hookless and Pons acceptance bases default both tokens to 18 decimals at their lines 32–33.

The test contract is an allowed bytecode-bearing caller. Do not use `vm.prank`, an EOA, a new caller contract or the pool-trading actor for the credit request. Keep the outside swap itself unchanged.

## Exact edits

### 1. Capture custody before the existing outside trade

In each test, immediately after its existing `uint256 supply = ...totalSupply();` and before the outside swap, add:

For hookless and Pons:

```solidity
uint256 heldBeforeTrade = token0.balanceOf(address(vault));
```

For wings:

```solidity
uint256 heldBeforeTrade = token0.balanceOf(address(wings0));
```

This anchors the known unbooked custody independently of pool movement. The existing `book0` and `supply` snapshots remain in use.

### 2. Hookless and Pons: insert the same bounded assertion block

Immediately after the existing “outside trade mints no shares” assertion (old hookless line **42**, Pons line **45**), insert this scoped block in each file:

```solidity
{
    assertGt(address(this).code.length, 0, "credit caller has bytecode");
    assertGe(heldBeforeTrade, book0, "held balance covers the book");
    uint256 unbookedBefore = heldBeforeTrade - book0;
    assertEq(token0.balanceOf(address(vault)), heldBeforeTrade, "outside trade does not add held tokens");
    assertTrue(token0.transfer(address(vault), 7 ether));
    uint256 held = token0.balanceOf(address(vault));
    uint256 booked = IBasicVault(address(vault)).reserveOfToken(address(token0));
    assertEq(booked, book0, "transfer does not refresh the book");
    uint256 credit = held - booked;
    assertEq(credit, unbookedBefore + 7 ether, "credit is only held excess plus transfer");
    vm.expectRevert(
        abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, credit + 1, credit)
    );
    vault.exchangeIn(token0, credit + 1, IERC20(address(vault)), 0, address(this), true, block.timestamp);
    assertEq(token0.balanceOf(address(vault)), held, "rejection preserves held tokens");
    assertEq(IBasicVault(address(vault)).reserveOfToken(address(token0)), booked, "rejection preserves book");
    assertEq(IERC20(address(vault)).totalSupply(), supply, "rejection preserves supply");
}
```

The exact call is the existing family's `vault.exchangeIn` with `token0` input and vault-share output, measured `credit + 1` input, zero minimum, `address(this)` recipient, true flag and current timestamp. Existing imports already supply all types and the error interface; add no imports or helpers.

### 3. Wings: insert its corresponding target-token assertion block

Immediately after the existing supply assertion at old line **36**, insert:

```solidity
{
    assertGt(address(this).code.length, 0, "credit caller has bytecode");
    assertGe(heldBeforeTrade, book0, "held balance covers the book");
    uint256 unbookedBefore = heldBeforeTrade - book0;
    assertEq(token0.balanceOf(address(wings0)), heldBeforeTrade, "outside trade does not add held tokens");
    uint256 transferAmount = 7 * 10 ** uint256(token0.decimals());
    assertTrue(token0.transfer(address(wings0), transferAmount));
    uint256 held = token0.balanceOf(address(wings0));
    uint256 booked = IBasicVault(address(wings0)).reserveOfToken(address(token0));
    assertEq(booked, book0, "transfer does not refresh the book");
    uint256 credit = held - booked;
    assertEq(credit, unbookedBefore + transferAmount, "credit is only held excess plus transfer");
    vm.expectRevert(
        abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, credit + 1, credit)
    );
    IStandardExchangeIn(address(wings0)).exchangeIn(
        token0, credit + 1, IERC20(address(wings0)), 0, address(this), true, block.timestamp
    );
    assertEq(token0.balanceOf(address(wings0)), held, "rejection preserves held tokens");
    assertEq(IBasicVault(address(wings0)).reserveOfToken(address(token0)), booked, "rejection preserves book");
    assertEq(IERC20(address(wings0)).totalSupply(), supply, "rejection preserves supply");
}
```

All required interfaces are already imported. The inherited `token0` is the mintable token type exposing `decimals()`, and `wings0` is deployed with `token0` as target at base line 49.

### 4. Preserve the remaining controls

Keep the current funded deposit, preview equality, recipient-share checks and booking assertions after the new block. They are supplementary, not the held-credit proof. Keep the direct-pool-trade and both unchanged-book assertions exactly as they are. The new rejection must be the first attempted credit-consuming vault operation after the outside-trade assertions and explicit token transfer; insert no sync, rebalance or successful deposit before it.

The transferred tokens remain held after the rejected call; capture the rollback baseline **after** that transfer as the blocks do. Do not assert rollback to the pre-transfer custody balance. Do not use a generic revert, selector-only acceptance, catch or preview-derived expected credit.

## One validation command for a later authorized implementation

From IndexedEx root, using its default hermetic profile:

```bash
python3 scripts/forge-artifacts.py test \
  --test-root test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/AttributionAndBooking.t.sol \
  --test-root test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/AttributionAndBooking.t.sol \
  --test-root test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/UniswapV4UpperLowerWingsStandardExchangeVaultMoney.t.sol \
  -- -vv
```

No production positional source is supplied because this is test-only. The repository artifact-aware helper uses the three test roots as runtime-artifact consumers before running the whole files. This is the single prescribed validation command, not a command run by this reviewer. No test-name filter, separate V3 run or production edit is part of this draft. Preserve `out/` and `cache_forge/`; do not enable `via_ir` or change profiles/source paths.

If a preflight anchor, decimal/type assumption, exact credit assertion, revert payload or existing continuation fails, stop and report the file, assertion and actual result. Do not broaden the expected error, change transfer amounts, switch tokens/callers, alter production, add another test file or reinterpret preview parity as proof. Runtime/compilation are unverified in this review.

## Completion and evidence boundaries

The incremental source diff must touch only these three test functions. Each must keep a real non-vault pool trade and book invariance, then independently calculate held excess, preserve that excess across the outside trade, add the fixed token transfer, require the exact short-delivery error and assert unchanged post-transfer custody/book/supply on rejection. V3 LocalBook remains unchanged and cited. Record the later authorized run's result without representing a saved log as an independent rerun or a guarantee about unreviewed routes.

This is the owner-selected stronger proof for all four families, not a claim that current production grants unearned credit. Earlier Astra requirements findings remain historical; their narrower repair scope is superseded by this PRD.

Files examined: controlling PRD in full; the three current test ranges/imports; hookless and Pons base decimal declarations; wings base setup and target selection. No cited test-site drift was observed. The mixed-decimal wings fixture was explicitly resolved above. The assigned output was absent before writing. No peer notes were opened. Repository testing guidance and artifact workflow were read directly earlier in this session.

Only this assigned Markdown draft was created. No code, test, PRD, final implementation plan, configuration or instructions were edited. No delegation, shell, build, test or deployment was performed. Return to the coordinator/human and stop.

I did not run Forge.
