# Orbital raw-liquidity baseline

**Date:** 2026-10-04  
**Worktree:** `/Users/cyotee/Development/projects-defi/daosys/lib/indexedex`  
**HEAD:** `92cdf89a6fefd9c2ff4f04f74bdade1a7d379f5b` (`fix/uniswap-se-v2-delivery`)  
**Crane submodule:** `b35609951b4951a3c107e267e22844a50c4dc043` (`lib/crane`, `heads/main`)  
**Forge:** 1.5.1-stable (`b0a9dd9ceda36f63e2326ce530c10e6916f4b8a2`)  
**Compiler:** solc 0.8.35, optimizer on, `optimizer_runs = 1`, `via_ir = false` (`foundry.toml`)  
**Artifacts:** `out`, `cache_forge`. Not deleted.

## Inherited dirty state (not this task)

The checkout was already dirty. This task did not reset, stash, or revert those paths. Overlapping files this task also edits:

- `UniswapV4StandardExchangeOrbitalBufferHookCommon.sol` — inherited planned-zap settlement (`sharesJ`/`sharesK`, `_executePlannedOrQuotedSwap`, quote-skipping buffer/unwrap). Preserved.
- `UniswapV4StandardExchangeOrbitalBufferHookExitQuoteLib.sol` — inherited `redeemShares` / `sharesJ` / `sharesK` plumbing. Preserved.

Other dirty paths (Hookless analytic, fee-accrual test base, Pons, CraneFactoryArtifactSeed, deleted v4 SE specs, and unrelated docs) were not edited by this task.

## Pre-change ownership formulas (source trace, not a gas denominator)

Subsequent full-book joins used rated effective WAD:

`m = min floor(toWad(previewClaimIn(face_i)) * S / E_i)`

`previewClaimIn` substituted the face amount when the share preview was zero, then rated the shares. Flexible full-book mapped used input by scaling the offered amount against that rated used WAD. Zap terminal admission after `_depositSales` / `_depositOutputs` used the same rated `fullBookShares` against projected `effective`.

Proportional exits were already `floor(burn * rawInventory / S)`. The exit still calls `_recomputeL2`, `_snapshotKLastIfFeeOn`, and `_syncVaultReserves`, which read rates.

Partial sphere-NAV was not a raw ratio. See the OD-1 note.

## Gas denominator

A matched pre-change suite was **not** completed before the accounting edit. The dirty tree already contained uncommitted zap-settlement edits, so HEAD is not a clean denominator either. Post-change measurements are recorded in the validation note. They are not a before/after speedup claim. A10 is not accepted from this file.
