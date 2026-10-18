# MiniMax M3 — REQ-05 implementation plan (replacement-session original)

- **Session:** Labeled replacement `ses_eb8ab99f3ffe7suGF49ryUzI6t`. Not continuity. Does not recall `ses_ebdf718feffemWQNf7wuTpapqX`.
- **Controlling PRD:** `docs/reviews/apex-req-05-outside-trade/REMEDIATION_PRD.md` (read in full). V3 LocalBook stays unchanged; the three new-block sites are hookless, Pons, and wings.
- **Scope:** Test-only additions. No production change. No deleted-V4 restoration. No EOA. No `minted == preview`-as-proof. One Forge command for the three files.
- **No code edit. No PRD/plan write. No Forge. No exploit procedures.**

---

## 0. Preconditions — verified by direct re-read

The plan depends on the current state of three test files. I re-read all three against the cited line ranges. **No drift.** The plan proceeds.

### 0.1 Hookless file — `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/AttributionAndBooking.t.sol`

Current `test_outsidePoolTradeDoesNotRefreshVaultBook` at lines 34–49:

```solidity
34:     function test_outsidePoolTradeDoesNotRefreshVaultBook() public {
35:         _bootstrap();
36:         uint256 book0 = IBasicVault(address(vault)).reserveOfToken(address(token0));
37:         uint256 book1 = IBasicVault(address(vault)).reserveOfToken(address(token1));
38:         uint256 supply = IERC20(address(vault)).totalSupply();
39:         _externalSwap(false, 100e18);
40:         assertEq(IBasicVault(address(vault)).reserveOfToken(address(token0)), book0, "outside trade leaves token0 book unchanged");
41:         assertEq(IBasicVault(address(vault)).reserveOfToken(address(token1)), book1, "outside trade leaves token1 book unchanged");
42:         assertEq(IERC20(address(vault)).totalSupply(), supply, "outside trade mints no shares");
43:         uint256 beforeShares = IERC20(address(vault)).balanceOf(address(this));
44:         uint256 preview = vault.previewExchangeIn(token1, 1e18, IERC20(address(vault)));
45:         uint256 minted = vault.exchangeIn(token1, 1e18, IERC20(address(vault)), preview, address(this), false, block.timestamp);
46:         assertEq(minted, preview, "later deposit credits only the funded input");
47:         assertEq(IERC20(address(vault)).balanceOf(address(this)) - beforeShares, minted, "caller receives only the funded credit");
48:         _assertBooked();
49:     }
```

The new block inserts after line 42 and before line 43. The existing minted==preview and balance-diff assertions at lines 46–47 stay as they are; the user does not ask me to remove them. The new block is a separate physical-credit assertion.

### 0.2 Pons file — `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/AttributionAndBooking.t.sol`

Current `test_outsidePoolTradeDoesNotRefreshVaultBook` at lines 37–52:

```solidity
37:     function test_outsidePoolTradeDoesNotRefreshVaultBook() public {
38:         _bootstrap();
39:         uint256 book0 = IBasicVault(address(vault)).reserveOfToken(address(token0));
40:         uint256 book1 = IBasicVault(address(vault)).reserveOfToken(address(token1));
41:         uint256 supply = IERC20(address(vault)).totalSupply();
42:         _externalSwap(false, 100e18);
43:         assertEq(IBasicVault(address(vault)).reserveOfToken(address(token0)), book0, "outside trade leaves token0 book unchanged");
44:         assertEq(IBasicVault(address(vault)).reserveOfToken(address(token1)), book1, "outside trade leaves token1 book unchanged");
45:         assertEq(IERC20(address(vault)).totalSupply(), supply, "outside trade mints no shares");
46:         uint256 beforeShares = IERC20(address(vault)).balanceOf(address(this));
47:         uint256 preview = vault.previewExchangeIn(token1, 1e18, IERC20(address(vault)));
48:         uint256 minted = vault.exchangeIn(token1, 1e18, IERC20(address(vault)), preview, address(this), false, block.timestamp);
49:         assertEq(minted, preview, "later deposit credits only the funded input");
50:         assertEq(IERC20(address(vault)).balanceOf(address(this)) - beforeShares, minted, "caller receives only the funded credit");
51:         _assertBooked();
52:     }
```

The new block inserts after line 45 and before line 46. Same pattern.

### 0.3 Wings file — `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/UniswapV4UpperLowerWingsStandardExchangeVaultMoney.t.sol`

Current `test_outsidePoolTradeDoesNotRefreshVaultBook` at lines 26–40:

```solidity
26:     function test_outsidePoolTradeDoesNotRefreshVaultBook() public {
27:         _bootstrap(wings0);
28:         (bytes memory state,) = IStandardExchangeTransitionQuote(address(wings0)).quoteState(address(token0), address(0));
29:         assertGt(state.length, 0, "wings vault still quotes a snapshot");
30:         uint256 book0 = IBasicVault(address(wings0)).reserveOfToken(address(token0));
31:         uint256 book1 = IBasicVault(address(wings0)).reserveOfToken(address(token1));
32:         uint256 supply = IERC20(address(wings0)).totalSupply();
33:         trader.swapTo(key, false, 1e18, TickMath.getSqrtPriceAtTick(200));
34:         assertEq(IBasicVault(address(wings0)).reserveOfToken(address(token0)), book0, "outside trade leaves token0 book unchanged");
35:         assertEq(IBasicVault(address(wings0)).reserveOfToken(address(token1)), book1, "outside trade leaves token1 book unchanged");
36:         assertEq(IERC20(address(wings0)).totalSupply(), supply, "outside trade mints no shares");
37:         uint256 preview = IStandardExchangeIn(address(wings0)).previewExchangeIn(token0, 1e12, IERC20(address(wings0)));
38:         uint256 minted = IStandardExchangeIn(address(wings0)).exchangeIn(token0, 1e12, IERC20(address(wings0)), preview, address(this), false, block.timestamp);
39:         assertEq(minted, preview, "later deposit credits only the funded input");
40:     }
```

The new block inserts after line 36 and before line 37. The existing minted==preview assertion at line 39 stays; the user does not ask me to remove it.

---

## 1. What the new block does

The user instructs:

> "after the existing outside-trade book assertions, transfer 7 ether of one named token to the vault, assert credit equals balance minus book, and expect TransferDeltaInsufficient(credit + 1, credit) on a true-flag exchangeIn from a caller that has bytecode."

Per family:

- **Token:** `token0` (named). The test bases already set up `token0` with a large balance; the existing tests use `token0` for outside trades and `token1` for the post-trade credit. The new block uses `token0` so the credit flow is independent of the existing `token1` credit at line 44/47.
- **Caller:** `address(this)` (the test contract). The test contract is a Solidity contract and therefore has bytecode. This satisfies "a caller that has bytecode" and "do not use an EOA." No new contract is introduced.
- **Amount:** `7e18` (7 ether). The token has 18 decimals in all three test setups.
- **Three assertions in sequence:**
  1. `credit == balance - book` after the pretransferred `exchangeIn` settles, where `balance = IERC20(token0).balanceOf(address(vault))` and `book = IBasicVault(vault).reserveOfToken(token0)`. This is the physical-credit boundary: the credit minted to the caller equals the unbooked tokens the vault received. `minted == preview` is **not** the proof.
  2. A `true-flag` `exchangeIn` (the `pretransferred` boolean parameter set to `true`) with `amount = credit + 1` is expected to revert with `TransferDeltaInsufficient(credit + 1, credit)`. The caller has bytecode and therefore fails the share-balance check before any other boundary.
  3. The caller has `credit` shares (from the prior pretransferred `exchangeIn`); requesting `credit + 1` exceeds the balance.

This is a physical-credit boundary proof, distinct from the `minted == preview` proof the existing tests use. The existing assertions stay; the new block is a separate check.

---

## 2. The exact new block — per file

The new block is identical in shape across the three files. The differences are: the `IBasicVault(vault).reserveOfToken(token0)` call vs `IBasicVault(wings0).reserveOfToken(token0)`, and the `vault` vs `wings0` target. The token, amount, caller, and assertion strings are identical.

### 2.1 Hookless file

Insert after line 42 and before line 43:

```solidity
        // Physical-credit boundary: contract caller (address(this) has bytecode)
        // transfers 7 ether of token0 to the vault, is credited exactly the
        // unbooked amount the vault now holds, and cannot redeem more than
        // credited. minted == preview is NOT the proof.
        IERC20(token0).transfer(address(vault), 7e18);
        uint256 beforeCallerShares = IERC20(address(vault)).balanceOf(address(this));
        uint256 beforeBalanceToken0 = IERC20(token0).balanceOf(address(vault));
        uint256 beforeReserveToken0 = IBasicVault(address(vault)).reserveOfToken(address(token0));
        vault.exchangeIn(token0, 7e18, IERC20(address(vault)), 0, address(this), true, block.timestamp);
        uint256 credit = IERC20(address(vault)).balanceOf(address(this)) - beforeCallerShares;
        assertEq(credit, beforeBalanceToken0 - beforeReserveToken0, "credit equals balance minus book");
        vm.expectRevert(abi.encodeWithSelector(
            ISecurePullErrors.TransferDeltaInsufficient.selector,
            credit + 1,
            credit
        ));
        vault.exchangeIn(token0, credit + 1, IERC20(address(vault)), 0, address(this), true, block.timestamp);
```

### 2.2 Pons file

Insert after line 45 and before line 46:

```solidity
        // Physical-credit boundary: contract caller (address(this) has bytecode)
        // transfers 7 ether of token0 to the vault, is credited exactly the
        // unbooked amount the vault now holds, and cannot redeem more than
        // credited. minted == preview is NOT the proof.
        IERC20(token0).transfer(address(vault), 7e18);
        uint256 beforeCallerShares = IERC20(address(vault)).balanceOf(address(this));
        uint256 beforeBalanceToken0 = IERC20(token0).balanceOf(address(vault));
        uint256 beforeReserveToken0 = IBasicVault(address(vault)).reserveOfToken(address(token0));
        vault.exchangeIn(token0, 7e18, IERC20(address(vault)), 0, address(this), true, block.timestamp);
        uint256 credit = IERC20(address(vault)).balanceOf(address(this)) - beforeCallerShares;
        assertEq(credit, beforeBalanceToken0 - beforeReserveToken0, "credit equals balance minus book");
        vm.expectRevert(abi.encodeWithSelector(
            ISecurePullErrors.TransferDeltaInsufficient.selector,
            credit + 1,
            credit
        ));
        vault.exchangeIn(token0, credit + 1, IERC20(address(vault)), 0, address(this), true, block.timestamp);
```

### 2.3 Wings file

Insert after line 36 and before line 37:

```solidity
        // Physical-credit boundary: contract caller (address(this) has bytecode)
        // transfers 7 ether of token0 to the wings vault, is credited exactly
        // the unbooked amount the wings vault now holds, and cannot redeem more
        // than credited. minted == preview is NOT the proof.
        IERC20(token0).transfer(address(wings0), 7e18);
        uint256 beforeCallerShares = IERC20(address(wings0)).balanceOf(address(this));
        uint256 beforeBalanceToken0 = IERC20(token0).balanceOf(address(wings0));
        uint256 beforeReserveToken0 = IBasicVault(address(wings0)).reserveOfToken(address(token0));
        IStandardExchangeIn(address(wings0)).exchangeIn(token0, 7e18, IERC20(address(wings0)), 0, address(this), true, block.timestamp);
        uint256 credit = IERC20(address(wings0)).balanceOf(address(this)) - beforeCallerShares;
        assertEq(credit, beforeBalanceToken0 - beforeReserveToken0, "credit equals balance minus book");
        vm.expectRevert(abi.encodeWithSelector(
            ISecurePullErrors.TransferDeltaInsufficient.selector,
            credit + 1,
            credit
        ));
        IStandardExchangeIn(address(wings0)).exchangeIn(token0, credit + 1, IERC20(address(wings0)), 0, address(this), true, block.timestamp);
```

---

## 3. Why the three files are handled together

The PRD's REQ-05 acceptance criterion (`:264-266`) requires each of V3 FullSpread, V4 hookless FullSpread, V4 Pons-family FullSpread, and the wings vault to have an outside-trade test with the same three-part shape. V3 LocalBook is excluded by the user. The new block is the same shape across hookless, Pons, and wings, with the only difference being the `vault`/`wings0` reference.

---

## 4. One Forge command for the three files

From the IndexedEx root, hermetic profile, no `via_ir`, warm `out/` and `cache_forge/` preserved:

```bash
python3 scripts/forge-artifacts.py test \
  test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/AttributionAndBooking.t.sol \
  test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/AttributionAndBooking.t.sol \
  test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/UniswapV4UpperLowerWingsStandardExchangeVaultMoney.t.sol \
  -- -vv
```

Run the whole files. Do not filter to one test name. The wings file's `_bootstrap(wings0)` requires `wings0` to be deployed; the existing setUp handles this. V3 LocalBook is not in the command per the user's instruction.

Stop conditions:
- If any cited line (`:42` hookless, `:45` Pons, `:36` wings) no longer matches, stop and report.
- If `credit` is not equal to `balance - book` (or if the share-balance check on `credit + 1` returns a different selector), stop and report the actual bytes. The PRD does not authorize a catch, a weaken, or a production change.
- If the three test roots compile and pass the new block, the PRD's physical-credit boundary is satisfied for these three families. The existing assertions and the new block are both required.

---

## 5. What this plan does NOT do

- No V3 LocalBook change. Per the user.
- No production change. Per the PRD non-goal `:268`.
- No restoration of the deleted legacy V4 package. Per the PRD non-goal `:268` and the user's instruction.
- No `minted == preview`-as-proof. The new block uses `credit == balance - book` as the proof.
- No EOA caller. The caller is `address(this)`, which is a Solidity contract and has bytecode.
- No allowance for a different token. `token0` is named.
- No allowance for a different amount. `7e18` is named.
- No allowance for a different caller. `address(this)` is named.
- No `catch`. No allowance for a missing assertion. The plan is closed.

---

## 6. Items I am not asserting

- I am not asserting that the wings vault's `exchangeIn` with `pretransferred=true` from `address(this)` (a bytecode caller) reaches the share-balance check without first reverting with `EOAPretransferNotAllowed`. The user's instruction is the expected error is `TransferDeltaInsufficient(credit + 1, credit)`. The implementer verifies the production behavior. If the wings vault's pretransfer check runs first, the expected selector differs; the plan records the actual bytes and stops.
- I am not asserting that `token0` in each test base has at least `7e18` of free balance for `address(this)`. The test bases set up large token amounts for the test contract; the implementer verifies the exact balance and tops up if needed.
- I am not asserting that the three files compile or that the new block passes. No Forge run. Source read only.

---

## 7. Files examined (this plan)

- `docs/reviews/apex-req-05-outside-trade/REMEDIATION_PRD.md` — read in full.
- `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/AttributionAndBooking.t.sol` — re-read at `:30-54` to verify the pre-edit anchors.
- `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/AttributionAndBooking.t.sol` — re-read at `:33-57` to verify the pre-edit anchors.
- `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/UniswapV4UpperLowerWingsStandardExchangeVaultMoney.t.sol` — re-read at `:22-46` to verify the pre-edit anchors.

No other reviewer files were read. No Forge / build / test was executed. No code was edited.

---

I did not run Forge.