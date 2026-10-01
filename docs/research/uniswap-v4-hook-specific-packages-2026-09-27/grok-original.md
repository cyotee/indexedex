# Grok — Hook-specific FullSpread vault packages

**Date:** 2026-09-27. **Reviewer:** Grok (xai/grok-4.7). Independent pass. No peer artifacts read. No code or PRD edits.

**Proposal:** one hookless package and one Pons package now; later, one package per compatible hook. Reuse facet sets where the execution model matches. This may replace PRD D14's deployer-assurance / no-whitelist rule for admission. It does not reopen D17–D19 (combined exact-output stays unsupported), D20 (25/50/10/1 bp), or D21 (progress and sleeve deadband).

**Recommendation:** Yes. Split admission and quote policy into two packages. Do not keep one FullSpread package that accepts any hook and falls back to a vanilla quote. Do not clone every facet. Share the facets whose bytecode does not embed a hook model. Pin Pons V2 by address plus reviewed codehash and the same PoolManager. Do not treat "Pons family" as one hook.

## Why one package cannot close the quote hole

`UniswapV4FullSpreadStandardExchangeVaultQuoteService.sol` 44–57 treats `hooks == address(0)` as exact, models one Pons flag mask by calling `launches(bytes32)`, and **returns the vanilla amount for every other hook**. That last branch is the arbitrary-hook quote. Package split removes it only if each package rejects every other hook at init and the quote facet has no silent fallback.

`initAccount` stores the key and does not check hooks (`UniswapV4FullSpreadStandardExchangeVaultDFPkg.sol` 271–286). `processArgs` only checks the registry caller and TWAP/PoolManager (`257–264`).

## Identity

A pool id is `keccak256` of the whole `PoolKey`, including `hooks` (`lib/crane/contracts/protocols/dexes/uniswap/v4/types/PoolId.sol` 15–20). Context7 `/uniswap/v4-core`, accessed 2026-09-27, states the same: https://context7.com/uniswap/v4-core/llms.txt. A different hook is a different pool. Flag bits are not an implementation id.

Pons V2 is `PonsV2MemeHook`, constructed with one `IPoolManager` (`PonsV2MemeHook.sol` 160–165; `BaseHook` 19–20). Permissions are `beforeInitialize`, `afterSwap`, and `afterSwapReturnDelta` only (`184–200`). That matches the quote mask `BEFORE_INITIALIZE_FLAG | AFTER_SWAP_FLAG | AFTER_SWAP_RETURNS_DELTA_FLAG` (`QuoteService.sol` 24–26). Pons v1 has no this hook. A later V2 revision with different `afterSwap` math is a new package, even if the name stays Pons.

**Pin:** package immutable `expectedHook` must equal `poolKey.hooks`, `hook.poolManager()` must equal the package `POOL_MANAGER` (`DFPkg.sol` 113–120 already binds TWAP to that manager), and `hook.codehash` must equal the reviewed `PonsV2MemeHook` runtime hash. Address alone misses a replaced implementation at a mined address. Codehash alone accepts another deployment with the same bytecode and a different owner or fee escrow, because those are storage (`PonsV2MemeHook.sol` 171–177). Both checks are required.

## What can be shared

Package constructor immutables are the facet addresses plus oracle, registry, Permit2, PoolManager, PositionManager, and WETH (`DFPkg.sol` 71–125). Facets are CREATE3 by type name (`FactoryService` deploy helpers). Two packages may cut the same facet addresses.

Instance address is `keccak256(abi.encode(pkg, pkg.calcSalt(pkgArgs)))` (`DiamondPackageCallBackFactory.sol` 201–206). The same PoolKey on two packages does not collide. Package CREATE3 salt is the type-name hash passed to `deployPkg` (`FactoryService.sol` 180–183). A second package needs its own contract name and salt. Reusing facet bytecode does not reuse the package address.

Share ERC20, vault-view, liquid-reserve, and PoolManager execution facets. They already call `swap` / `modifyLiquidity` with empty hook data (`Common.sol` 973–986). Pons `_afterSwap` ignores hook data (`PonsV2MemeHook.sol` 480). A future hook that requires hook data cannot reuse that execution facet.

Do not share a quote facet that contains the line `if (!supported) return amount`. Hookless quote code must revert if `hooks != address(0)`. Pons quote code must revert unless the pinned hook and `launches` checks pass. A shared facet with a storage policy is possible, but a forgotten fallback recreates the current bug. Prefer two quote facets.

## Pons fees are per pool, not one package constant

`LaunchInfo` snapshots `creatorTaxBps` and `hookFeeBps` at `registerPool` (`PonsV2MemeHook.sol` 48–66, 357–400). `AlreadyRegistered` blocks a second write. `afterSwap` charges those snapshotted bps on the unspecified leg (`493–504`). `setHookFeeBps` (`251–254`) changes only the global default for future registrations, not existing `launches[poolId]`.

The quote must keep reading `launches(poolId)`, not the global `hookFeeBps`. Layout assumed by `QuoteService.sol` 31–41 is 13 words, with word 7 = `creatorTaxBps` and word 10 = `hookFeeBps`. That matches the current struct. A field insertion is a new hook version and a new package.

Owner-mutable sweep splits (`protocolFeeShareBps`, `buybackBurnBps`) do not change the swapper's bps. They are not a quote input. Unregistered pools return no delta (`492`). The package must reject an unregistered pool id.

Pool LP fee is still separate. The Pons test constant is `PONS_V2_POOL_FEE = 0` (`TestBase_UniswapV4StandardExchange_PonsV2.sol` 66). Static-LP rejection of `fee == 0x800000` remains a structural check on both packages. It is not a substitute for the hook pin.

## Runtime safety

Both packages:

- Reject a mismatched hook in `processArgs` and again in `initAccount`, before token approvals (`DFPkg.sol` 291–292).
- Keep measured fills, D20 caps, and D21 stop rules.
- Keep D19: combined exact-output-plus-rebalance reverts `InvalidRoute` on preview and execution. Package split does not restore it.
- Do not add an admin function that appends hook addresses. That would recreate discretionary admission.

Hookless package: `hooks == address(0)` only. No `launches` call.

Pons package: pinned hook, same PoolManager, reviewed codehash, flag mask, registered launch, 13-word decode, `hookFeeBps + creatorTaxBps <= 2000`. Quote adjustment is those two floored bps, not a vanilla amount. Execution still checks the 10 bp shortfall against that quote. If `afterSwap` diverges, the transaction reverts. It does not widen the model.

## Tests

Production registry path. No mock package.

- Hookless init reverts on the Pons hook and on any nonzero hook. Pons init reverts on `address(0)`, a flag-matched impostor, a wrong codehash, and a hook bound to another PoolManager.
- Two packages register under different CREATE3 salts and can cut the same non-quote facet address.
- Same PoolKey through both packages gets two addresses (`DiamondPackageCallBackFactory.sol` 206). The chosen duplicate-pool rule is tested.
- Pons quote uses `launches` bps. Changing global `hookFeeBps` after registration does not change the quote.
- Direct quotes still include live protocol fee via `UniswapV4Quoter`. Hookless quote does not call `launches`.
- D17 route still reverts `InvalidRoute`. D20/D21 tests stay on both packages.

## Owner decisions

1. **Adopt the split.** Recommended yes. This supersedes D14 for these packages: unsupported hooks are rejected, not accepted on deployer assurance.
2. **Pin Pons by address and codehash and PoolManager.** Recommended yes. Name-only or flag-only is not enough.
3. **One FullSpread vault per PoolId across these packages.** Recommended yes, so two packages cannot both book the same pool. Not forced by CREATE2. Needs an explicit rule.
4. **No later admin hook list.** Recommended yes. A new hook is a new package.

No other product rule needs to move. Dynamic-fee rejection can ride along as structural validation. It is not the hook-package decision.

## Caveats

Flag equality is not bytecode equality. Per-pool Pons bps are immutable after registration in this source; a revised hook that writes `launches` later is out of model. Shared execution facets assume empty hook data. Quote-facet sharing is the main way this design fails. Existing FullSpread instances are not migrated.

**Confidence:** high on salt separation, Pons snapshot versus global setter, and the vanilla fallback. Medium on whether every future hook can reuse execution facets. No tests were run.

**Saved:** `docs/research/uniswap-v4-hook-specific-packages-2026-09-27/grok-original.md`
