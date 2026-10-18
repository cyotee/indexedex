# Kimi K3 — RC-08 named error: plan review (replacement-session original)

- **Label:** Replacement-session original, not continuity. I do not recall `ses_ec41220c2ffeqs5Eha7fPsd54B`. No peer notes were read. Controlling PRD: `docs/reviews/apex-rc-08-named-error/REMEDIATION_PRD.md` (43 lines, read in full). The owner chose `LPReserveMismatch(uint256 held, uint256 booked)` on 2026-10-18; that name is not reopened. Nothing was edited. I did not run Forge.
- **Date:** 2026-10-18.

## Preconditions (re-verified this round)

- `UniswapV2StandardExchangeOutTarget.sol:879-881` and `:1007` still carry the blank `revert()` on `pool.balanceOf(address(this)) != vaultLpReserve`. `UniswapV2LpBacking` (`:1011-1020`) holds `InsufficientLPBacking(held, required)` for the `<` check — untouched by this plan.
- `vaultLpReserve` has **no public getter** (family-wide grep); it is a `UniV2StrategyVault` struct field loaded from `ConstProdReserveVaultRepo`, written from `_lastTotalAssets()` on booking (`Common.sol:139`). In a fresh vault it is 0.

## Closed plan steps

**Step 1 — declaration.** In `UniswapV2StandardExchangeOutTarget.sol`, inside the existing `UniswapV2LpBacking` library immediately after the `InsufficientLPBacking` declaration (`:1013-1015`), add:

```solidity
    /// @custom:signature LPReserveMismatch(uint256,uint256)
    error LPReserveMismatch(uint256 held, uint256 booked);
```

**Step 2 — zap-in site (`:879-881`).** Replace the blank revert with:

```solidity
        if (indexSource.pool.balanceOf(address(this)) != vault.vaultLpReserve) {
            revert UniswapV2LpBacking.LPReserveMismatch(indexSource.pool.balanceOf(address(this)), vault.vaultLpReserve);
        }
```

**Step 3 — zap-out site (`:1007`).** Replace with:

```solidity
        if (indexSource.pool.balanceOf(address(this)) != vault2.vaultLpReserve) revert UniswapV2LpBacking.LPReserveMismatch(indexSource.pool.balanceOf(address(this)), vault2.vaultLpReserve);
```

The comparison stays `!=` in both; `InsufficientLPBacking` and its `<` check are untouched.

**Step 4 — the existing blank-revert test.** One exists: `test/foundry/spec/protocol/dexes/uniswap/v2/UniswapV2StandardExchange_SecRemediation.t.sol:425` — `vm.expectRevert(bytes(""));` in `test_A0_donateLp_thenZapInDeposit_cannotRedeemDonation` (`:408-433`): the donated LP sits unbooked (held = `donate_`, asserted at `:418`; booked = 0, fresh vault with supply 0 asserted at `:419`). Replace `:425` with:

```solidity
        vm.expectRevert(abi.encodeWithSelector(UniswapV2LpBacking.LPReserveMismatch.selector, donate_, uint256(0)));
```

Add `import {UniswapV2LpBacking} from "contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeOutTarget.sol";` to that test file. The decimals twin (`decimals/UniswapV2StandardExchange_SecRemediation_Decimals.sol:100`) uses a bare `vm.expectRevert()` on the same path — it passes unchanged either way; do not edit it. The other bare reverts in the family (InOutInvariant, SlippageProtection, VaultDeposit and twins) are on other errors and are untouched.

**Step 5 — the zap-out site has no existing test; one new test file:** `test/foundry/spec/protocol/dexes/uniswap/v2/UniswapV2StandardExchange_LpReserveMismatch.t.sol`, on the existing V2 test base. It attempts the zap-out mismatch on a production path: bootstrap the vault, donate LP so held exceeds booked, then attempt a minimal exact-out zap-out and expect:

```solidity
        vm.expectRevert(abi.encodeWithSelector(UniswapV2LpBacking.LPReserveMismatch.selector, lp_.balanceOf(address(vault_)), booked_));
```

with `booked_` captured from the fixture before the call. Per RC-08's recorded evidence law (September PRD `:183-184`): the zap-out check re-reads the vault state after the payout, so an honest route may keep held == booked and this attempt may revert earlier or not at all — if the run shows different bytes or no revert, the implementer stops, records the attempted preconditions and the actual bytes, and does not weaken the assertion or mock storage; the zap-in A0 path (Step 4) is the production-triggered proof of the named check.

**Step 6 — one command** (production edit is the positional; successful zap routes must stay green):

```bash
python3 scripts/forge-artifacts.py test \
  contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeOutTarget.sol \
  --test-root test/foundry/spec/protocol/dexes/uniswap/v2/UniswapV2StandardExchange_SecRemediation.t.sol \
  --test-root test/foundry/spec/protocol/dexes/uniswap/v2/UniswapV2StandardExchange_LpReserveMismatch.t.sol \
  --test-root test/foundry/spec/protocol/dexes/uniswap/v2/UniswapV2StandardExchangeOut_PassThrough.t.sol \
  -- -vv
```

## Stop rules

If any cited line (`:879-881`, `:1007`, `UniswapV2LpBacking` at `:1011-1020`, `SecRemediation.t.sol:425`) has drifted, or a run shows bytes other than `LPReserveMismatch(held, booked)` at a named site, stop and report the file, line, and actual bytes. Do not weaken `held != booked`, do not reuse `InsufficientLPBacking`, do not rename anything else.

I did not run Forge.
