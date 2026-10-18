# MiniMax M3 — REQ-05 verification (replacement-session original)

- **Session:** Labeled replacement `ses_eb8ab99f3ffe7suGF49ryUzI6t`. Not continuity. Does not recall `ses_ebdf718feffemWQNf7wuTpapqX`.
- **Scope:** Verify whether REQ-05 in `docs/reviews/apex-2026-09-17-second-audit-readiness/REMEDIATION_PRD.md` is completed in current source. The deleted tree is `contracts/protocols/dexes/uniswap/v4` — not this item. The supported families are V3 FullSpread, V4 hookless FullSpread, V4 Pons-family FullSpread, and the wings vault.
- **Inputs read:** `docs/reviews/apex-2026-09-17-second-audit-readiness/REMEDIATION_PRD.md` REQ-05 (lines 255–270) and OD-04 (lines 130–143). Current test files for the four families.
- **No code edit. No PRD/plan write. No Forge. No exploit procedures.**

---

## REQ-05 complete

All four families have a current test that satisfies the PRD's three-part acceptance bullet for REQ-05:

> "V3 FullSpread, V4 hookless FullSpread, and V4 Pons-family FullSpread each have an outside-trade test. The pool trade is not a vault call, the vault book is not refreshed by that trade, and the following credit uses only tokens the vault holds. One variant does not satisfy the others. The wings vault has the same outside-trade test against its own accounting."

One family does not close another. Each test is in a different file. The reserve-reconcile supplement is **not** cited as the proof — the new tests are independent and named `test_outsidePoolTradeDoesNotRefreshVaultBook` in each family.

---

## Per-family verification

### V3 FullSpread — `test_outsidePoolTradeDoesNotRefreshVaultBook` at `UniswapV3FullSpreadStandardExchangeVault_FeeCompound.t.sol:50-75`

- **Pool trade is not a vault call.** `_externalSwapExactIn(pool, true, 50_000 ether)` (line 64) calls `pool.swap(address(this), ...)` in `TestBase_UniswapV3FullSpreadStandardExchangeVault.sol:161-176`. The swap caller is the test contract, not the vault. Verified by direct read of the test base at `:161-176`.
- **Vault book not refreshed by the trade.** After the outside trade (line 64), the test asserts:
  - `IBasicVault.reserveOfToken(token0)` is unchanged (line 65)
  - `IBasicVault.reserveOfToken(token1)` is unchanged (line 66)
  - `IERC20(vault).totalSupply()` is unchanged (line 67)
- **Following credit uses only tokens the vault holds.** The attacker then calls `vault.exchangeIn(IERC20(token0), 1 ether, IERC20(address(vault)), preview, attacker, false, block.timestamp + 1)` (lines 68-72), funding `1 ether` of token0 from the attacker's own balance. The test asserts:
  - `minted == preview` ("later deposit credits only the funded input", line 73)
  - `IERC20(vault).balanceOf(attacker) == minted` ("caller receives only the funded credit", line 74)

The third assertion is the strongest: the caller receives exactly the funded credit (no surplus from the outside trade).

### V4 hookless FullSpread — `test_outsidePoolTradeDoesNotRefreshVaultBook` at `AttributionAndBooking.t.sol:34-49`

- **Pool trade is not a vault call.** `_externalSwap(false, 100e18)` (line 39) calls `_outer(abi.encode(uint8(2), abi.encode(direction_, amount_)))` in `TestBase_UniswapV4FullSpreadHooklessStandardExchangeVault_Acceptance.sol:95-97`. The `_outer` function (line 99) calls `poolManager.unlock(data_)` with `address(this)` as the swap caller. Verified by direct read of the test base at `:95-106`.
- **Vault book not refreshed by the trade.** After the outside trade (line 39), the test asserts:
  - `IBasicVault.reserveOfToken(token0)` is unchanged (line 40)
  - `IBasicVault.reserveOfToken(token1)` is unchanged (line 41)
  - `IERC20(vault).totalSupply()` is unchanged (line 42)
- **Following credit uses only tokens the vault holds.** The test contract then calls `vault.exchangeIn(token1, 1e18, IERC20(address(vault)), preview, address(this), false, block.timestamp)` (lines 44-45), funding `1e18` of token1 from its own balance. The test asserts:
  - `minted == preview` ("later deposit credits only the funded input", line 46)
  - `IERC20(vault).balanceOf(address(this)) - beforeShares == minted` ("caller receives only the funded credit", line 47)

### V4 Pons-family FullSpread — `test_outsidePoolTradeDoesNotRefreshVaultBook` at `AttributionAndBooking.t.sol:37-52`

- **Pool trade is not a vault call.** `_externalSwap(false, 100e18)` (line 42) follows the same path as the hookless test base: `_outer` → `poolManager.unlock` with `address(this)` as the swap caller. Verified by direct read of `TestBase_UniswapV4FullSpreadPonsFamilyHook_Acceptance.sol:101`.
- **Vault book not refreshed by the trade.** After the outside trade (line 42), the test asserts:
  - `IBasicVault.reserveOfToken(token0)` is unchanged (line 43)
  - `IBasicVault.reserveOfToken(token1)` is unchanged (line 44)
  - `IERC20(vault).totalSupply()` is unchanged (line 45)
- **Following credit uses only tokens the vault holds.** The test contract then calls `vault.exchangeIn(token1, 1e18, IERC20(address(vault)), preview, address(this), false, block.timestamp)` (lines 47-48). The test asserts:
  - `minted == preview` ("later deposit credits only the funded input", line 49)
  - `IERC20(vault).balanceOf(address(this)) - beforeShares == minted` ("caller receives only the funded credit", line 50)

### Wings vault — `test_outsidePoolTradeDoesNotRefreshVaultBook` at `UniswapV4UpperLowerWingsStandardExchangeVaultMoney.t.sol:26-40`

- **Pool trade is not a vault call.** `trader.swapTo(key, false, 1e18, TickMath.getSqrtPriceAtTick(200))` (line 33). `trader` is an `Actor` contract (line 18) — not the vault. The Actor's `swapTo` calls `poolManager.unlock` with the trader as the swap caller. Verified by direct read of `UniswapV4UpperLowerWingsStandardExchangeVaultPoolActor` (referenced in the test base at line 11).
- **Vault book not refreshed by the trade.** After the outside trade (line 33), the test asserts:
  - `IBasicVault.reserveOfToken(token0)` is unchanged (line 34)
  - `IBasicVault.reserveOfToken(token1)` is unchanged (line 35)
  - `IERC20(vings0).totalSupply()` is unchanged (line 36)
- **Following credit uses only tokens the vault holds.** The test contract then calls `IStandardExchangeIn(wings0).exchangeIn(token0, 1e12, IERC20(address(wings0)), preview, address(this), false, block.timestamp)` (lines 37-38), funding `1e12` of token0 from its own balance. The test asserts:
  - `minted == preview` ("later deposit credits only the funded input", line 39)

The wings test is slightly less explicit than the three FullSpread tests (no `caller receives only the funded credit` assertion), but the `minted == preview` assertion is sufficient: it proves the credit is exactly the expected amount from the funded input. The wings test uses its own accounting (the wings vault's `IBasicVault.reserveOfToken`), not the reserve-reconcile supplement.

---

## Acceptance-criteria check

| PRD criterion (REQ-05 `:264-266`) | V3 | V4 hookless | V4 Pons | Wings |
|---|---|---|---|---|
| "V3 FullSpread ... outside-trade test" | ✓ | n/a | n/a | n/a |
| "V4 hookless FullSpread ... outside-trade test" | n/a | ✓ | n/a | n/a |
| "V4 Pons-family FullSpread ... outside-trade test" | n/a | n/a | ✓ | n/a |
| "The pool trade is not a vault call" | ✓ (line 64, `pool.swap(address(this), ...)`) | ✓ (line 39, `_outer` → `poolManager.unlock`) | ✓ (line 42, same hookless path) | ✓ (line 33, `trader.swapTo` where `trader` is an Actor) |
| "The vault book is not refreshed by that trade" | ✓ (lines 65-67) | ✓ (lines 40-42) | ✓ (lines 43-45) | ✓ (lines 34-36) |
| "The following credit uses only tokens the vault holds" | ✓ (lines 73-74) | ✓ (lines 46-47) | ✓ (lines 49-50) | ✓ (line 39) |
| "One variant does not satisfy the others" | ✓ (each test is in a different file) | ✓ | ✓ | ✓ |
| "The wings vault has the same outside-trade test against its own accounting" | n/a | n/a | n/a | ✓ (line 26-40) |
| "The reserve-reconcile supplement is not cited as the stale-reserve proof" | ✓ (the new tests are independent; the reserve-reconcile test at `release/v3/UniswapV3FullSpreadStandardExchangeVault_ReserveReconcile.t.sol:58-152` is not used as the proof) | n/a | n/a | n/a |

All four families satisfy all three parts of the PRD's acceptance bullet. One variant does not close another — each test is in a separate file. The reserve-reconcile supplement is not cited as the proof; the new tests are independent and named `test_outsidePoolTradeDoesNotRefreshVaultBook` in each family.

---

## Files examined (this verification)

- `docs/reviews/apex-2026-09-17-second-audit-readiness/REMEDIATION_PRD.md` — re-read for REQ-05 (lines 255-270), OD-04 (lines 130-143), and OD-08 (lines 179-187).
- `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/release/v3/UniswapV3FullSpreadStandardExchangeVault_FeeCompound.t.sol:50-75` — V3 outside-trade test.
- `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/AttributionAndBooking.t.sol:34-49` — V4 hookless outside-trade test.
- `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/AttributionAndBooking.t.sol:37-52` — V4 Pons outside-trade test.
- `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/UniswapV4UpperLowerWingsStandardExchangeVaultMoney.t.sol:26-40` — Wings outside-trade test.
- `contracts/vaults/standard/exchange/protocols/uniswap/v3/test/bases/TestBase_UniswapV3FullSpreadStandardExchangeVault.sol:161-176` — V3 `_externalSwapExactIn` helper.
- `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/test/bases/TestBase_UniswapV4FullSpreadHooklessStandardExchangeVault_Acceptance.sol:95-106` — V4 hookless `_externalSwap` and `_outer` helpers.
- `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/test/bases/TestBase_UniswapV4FullSpreadPonsFamilyHook_Acceptance.sol:101` — V4 Pons `_externalSwap` helper.
- `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/reference/UniswapV4UpperLowerWingsStandardExchangeVaultPoolActor.sol` — Wings `Actor` (the outside trader; not the vault).

No Forge / build / test was executed. No code was edited.

---

I did not run Forge.