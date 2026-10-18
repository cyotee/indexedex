# Kimi K3 — RC-08 follow-up: requirements for naming the two blank reverts (replacement-session original)

- **Label:** Replacement-session original, not continuity. I do not recall `ses_ec41220c2ffeqs5Eha7fPsd54B`. No peer notes were read. Controlling text: `docs/reviews/apex-2026-09-17-remediation-council/REMEDIATION_PRD.md` RC-08 (`:173-186`, read fresh this round — no guard denial). All cited code read in current source this round. Nothing was edited. I did not run Forge.
- **Date:** 2026-10-18.

## The two blank reverts, verified

Both are the same law — the vault's actual LP-token balance must equal the booked LP reserve exactly:

1. `UniswapV2StandardExchangeOutTarget.sol:879-881` — zap-IN, after loading the strategy-vault state (`A0: unbooked reserve LP cannot be absorbed by zap-in mint`):
   ```solidity
   if (indexSource.pool.balanceOf(address(this)) != vault.vaultLpReserve) {
       revert();
   }
   ```
2. `UniswapV2StandardExchangeOutTarget.sol:1007` — zap-OUT exact-out, after the payout and the credit refund:
   ```solidity
   if (indexSource.pool.balanceOf(address(this)) != vault2.vaultLpReserve) revert();
   ```

Both compare with `!=`: the requirement is **equality** — held LP must match the booked reserve exactly. This is not the less-than check.

## Is there an existing error that means this? No.

The obvious neighbor is `UniswapV2LpBacking.InsufficientLPBacking(uint256 held, uint256 required)` (same file, `:1015`, raised by `requireHeld` at `:1017-1018`). It does **not** mean inequality: it fires only when `held < required`, its name asserts a shortfall, and the RC-08 fix deliberately kept the `<` comparison. A held-above-book case is exactly what the equality law must reject and `InsufficientLPBacking` must not. Reusing it would teach "insufficient" for an excess — wrong meaning. The assignment's condition for reuse is not met.

The rest of the repo's mismatch errors were swept (30 declarations, all read by name and argument list): `PoolLiquidityFundingMismatch` and `ReserveSwapFundingMismatch` are funding-check errors in other families; `AssetTransferMismatch` is a three-argument transfer-accounting error in the rebasing vault; `SettlementMismatch` and `AccountingMismatch` carry no values; the `ArrayLengthMismatch`/`WeightLengthMismatch`/`*TokenMismatch` family is structural, not custody. None names this comparison. A new error is required.

## The one new error (closed: name, arguments, order, comparison)

Declared in the existing `UniswapV2LpBacking` library at the bottom of `UniswapV2StandardExchangeOutTarget.sol` (immediately after `InsufficientLPBacking`, keeping the LP-backing law in one place):

```solidity
    /// @custom:signature LpBackingMismatch(uint256,uint256)
    error LpBackingMismatch(uint256 held, uint256 booked);
```

- **Name:** `LpBackingMismatch` — a mismatch of the LP backing law, not a shortfall.
- **Arguments in order:** `held` first, `booked` second — matching the file's existing convention ("Held is reported first", `:1011`).
- **The exact comparison that reverts it:** `held != booked` — the equality must hold; any difference in either direction reverts. The comparison is not weakened to `<`.

The two site replacements, verbatim:

- At `:879-881`:
  ```solidity
  if (indexSource.pool.balanceOf(address(this)) != vault.vaultLpReserve) {
      revert UniswapV2LpBacking.LpBackingMismatch(indexSource.pool.balanceOf(address(this)), vault.vaultLpReserve);
  }
  ```
- At `:1007`:
  ```solidity
  if (indexSource.pool.balanceOf(address(this)) != vault2.vaultLpReserve) revert UniswapV2LpBacking.LpBackingMismatch(indexSource.pool.balanceOf(address(this)), vault2.vaultLpReserve);
  ```

## Requirements carried from RC-08, restated as acceptance for this edit

- The transaction rolls back on mismatch; booked LP is not spent (both sites revert before any payout or booking change they guard).
- The comparison is untouched: `!=`, both directions reject.
- Existing successful zap-in and zap-out routes still pass; the change is revert-data only.
- A test asserts the named error with both values on a real mismatch path, per RC-08's evidence rules (production trigger, no mocked storage; if no supported route can produce the mismatch, record the attempted preconditions and assert the check itself reverts the named error — the existing evidence law).

## Boundaries

One new error, one meaning, two sites, no other file, no weakened comparison, no other implementer choice. Source-verified this round; no Forge run by me.

**LpBackingMismatch(uint256 held, uint256 booked)**

I did not run Forge.
