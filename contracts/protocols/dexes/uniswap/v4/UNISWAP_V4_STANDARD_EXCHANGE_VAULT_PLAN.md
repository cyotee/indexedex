# Plan: Uniswap V4 Standard Exchange Vault

## Related product law (local liquid buffer)

**Nested PoolManager lock-safety / local free inventory sleeve** is specified in:

- Product law: [`UNISWAP_V4_STANDARD_EXCHANGE_LOCAL_LIQUID_BUFFER_PRD.md`](./UNISWAP_V4_STANDARD_EXCHANGE_LOCAL_LIQUID_BUFFER_PRD.md)
- Coding plan: [`UNISWAP_V4_STANDARD_EXCHANGE_LOCAL_LIQUID_BUFFER_IMPLEMENTATION_AND_TEST_PLAN.md`](./UNISWAP_V4_STANDARD_EXCHANGE_LOCAL_LIQUID_BUFFER_IMPLEMENTATION_AND_TEST_PLAN.md)

That PRD covers accepting deposits while PoolManager is already unlocked (e.g. V4 hook buffer-last into a V4 SE), reusing fee-oracle `liquidReservePercentage`, and rebalancing the sleeve when the manager is idle. Implement against the PRD + implementation plan; this file remains the original bring-up plan.

## Progress Snapshot

Status as of 2026-04-24:

1. the core Uniswap V4 Standard Exchange vault scaffold is implemented under `contracts/protocols/dexes/uniswap/v4`,
2. the new repos, common execution layer, in/out targets, in/out facets, DFPkg, component factory service, and base test scaffold all compile,
3. Indexedex Manager deployment wiring is implemented and used by the V4 test base,
4. targeted Foundry coverage now exercises facet metadata, DFPkg deployment, direct routes, zap routes, refund behavior, slippage guards, and `pretransferred=true` handling, and
5. the largest remaining gaps are tighter preview fidelity and higher-level protocol-package consumption.

Implemented files in this phase:

1. `UniswapV4PoolManagerAwareRepo.sol`
2. `UniswapV4PoolKeyAwareRepo.sol`
3. `UniswapV4PositionRepo.sol`
4. `UniswapV4StandardExchangeCommon.sol`
5. `UniswapV4StandardExchangeInTarget.sol`
6. `UniswapV4StandardExchangeInFacet.sol`
7. `UniswapV4StandardExchangeOutTarget.sol`
8. `UniswapV4StandardExchangeOutFacet.sol`
9. `UniswapV4StandardExchangeDFPkg.sol`
10. `UniswapV4_Component_FactoryService.sol`
11. `test/bases/TestBase_UniswapV4StandardExchange.sol`

What is working now:

1. the package can initialize a multi-asset V4 vault bound to `IPoolManager + PoolKey`,
2. all currently implemented exact-in and exact-out route families now have executable coverage in the V4 spec slice,
3. the deployed vault now exposes `unlockCallback(bytes)` so `PoolManager.unlock(...)` can complete through the proxy,
4. vault-side V4 settlement now follows the required `sync -> transfer -> settle` pattern and correctly treats negative deltas as debts and positive deltas as credits,
5. zap-in and zap-out execution paths are exercised against a seeded hookless pool, including first-deposit, existing-position, refund, and pretransferred flows,
6. the vault owns a canonical V4 position directly instead of routing through `PositionManager`, and
7. the implementation has already been refactored to remove the compile blockers encountered during bring-up, including the stack-too-deep failures.

What is still incomplete:

1. preview math remains intentionally conservative rather than quoter-grade,
2. higher-level protocol packages do not yet consume the new DFPkg,
3. hook-aware or non-hookless preview semantics are still intentionally deferred, and
4. the V4 route suite could still be widened further with additional negative-path combinations, but the core supported route families now have executable coverage.

## Goal

Implement an IndexedEx vault package that provides the same user-facing shape as the Slipstream vault:

1. direct pool-side exact-in and exact-out swaps,
2. single-sided zap-in from a pool currency to vault shares,
3. single-sided zap-out from vault shares to a pool currency,
4. ERC20 vault shares representing proportional ownership of one managed concentrated-liquidity position, and
5. deterministic CREATE3 deployment through the IndexedEx manager and vault registry.

The vault must be built for Uniswap V4 using the Crane V4 port under `lib/daosys/lib/crane/contracts/protocols/dexes/uniswap/v4`.

## Why V4 Is Different

This implementation cannot be a direct copy of Slipstream.

Key differences:

1. there is no pool contract address to bind against; V4 pools are identified by `PoolKey` and `PoolId` inside the singleton `PoolManager`,
2. all state-changing V4 operations must execute inside `PoolManager.unlock(...)` and settle flash-accounting deltas before the callback returns,
3. a liquidity position is identified by `owner + tickLower + tickUpper + salt`, not by a pool-local NFT or LP ERC20,
4. a StandardExchange vault should own the canonical V4 position directly instead of routing through the V4 `PositionManager` at runtime, and
5. preview/quote support is harder because the current Crane V4 port includes state libraries and router logic but not a ready-made quoter contract.

Because of those differences, this vault should look closer to the Slipstream design than to the Uniswap V2 or Aerodrome V1 packages, but it must use V4-native execution and state access patterns.

## Recommended Scope

Initial implementation scope:

1. support one managed V4 position per vault,
2. bind the vault to one `PoolKey` plus one `IPoolManager`,
3. support hookless or execution-compatible pools first,
4. support exact-in and exact-out on the two pool currencies only,
5. support one-sided share mint and burn routes,
6. defer active rebalancing and multi-position strategies,
7. defer hook-specific quote guarantees until the basic hookless path is stable.

Explicit non-goals for v1:

1. multiple simultaneous positions,
2. onchain automated rebalancing,
3. generic hook introspection or hook delta support in previews,
4. ERC4626 semantics.

## Core Design Decisions

### 1. Use Multi-Asset Vault Facets, Not ERC4626

Do not model this as an ERC4626 vault.

Reason:

1. a V4 position is not a single ERC20 reserve asset,
2. the vault owns a position defined by `PoolKey + tickLower + tickUpper + salt`, and
3. user shares represent proportional ownership of a two-currency CL position.

The package should therefore mirror the Slipstream facet mix:

1. `ERC20Facet`
2. `ERC5267Facet`
3. `ERC2612Facet`
4. `MultiAssetBasicVaultFacet`
5. `MultiAssetStandardVaultFacet`
6. `UniswapV4StandardExchangeInFacet`
7. `UniswapV4StandardExchangeOutFacet`

### 2. Store Full Pool Identity, Not a Pool Address

The vault should persist:

1. `IPoolManager poolManager`
2. `PoolKey poolKey`
3. `PoolId poolId`
4. `bytes32 positionSalt`
5. `uint24 widthMultiplier`
6. canonical managed ticks and current liquidity

Reason:

1. V4 pool state lives inside `PoolManager`,
2. the same currencies can have multiple fee/tickSpacing/hook combinations, and
3. the vault cannot reconstruct the correct pool from token addresses alone.

### 3. Runtime Execution Should Call PoolManager Directly

The vault should implement or inherit an `IUnlockCallback`-compatible execution surface and call `poolManager.unlock(...)` itself.

Do not use `PositionManager` for core vault operations.

Reason:

1. the vault should own the position directly,
2. the user-facing ownership token is the vault ERC20 share token, not a V4 ERC721,
3. routing through `PositionManager` would add unnecessary tokenization and indirection,
4. the direct `PoolManager` path is the real V4 primitive the vault needs for swap and modify-liquidity flows.

`PositionManager` remains useful as a reference and may be used in tests or bootstrap helpers.

### 4. Use Deterministic Position Salt

Use a deterministic salt, recommended default:

1. `bytes32(0)` if one position per vault is strictly enforced, or
2. `keccak256(abi.encode(address(this), "main"))` if explicit uniqueness is preferred.

Store it in repo state rather than recomputing ad hoc.

## Proposed Files

New IndexedEx files to create:

1. `contracts/protocols/dexes/uniswap/v4/UniswapV4PoolManagerAwareRepo.sol`
2. `contracts/protocols/dexes/uniswap/v4/UniswapV4PoolKeyAwareRepo.sol`
3. `contracts/protocols/dexes/uniswap/v4/UniswapV4PositionRepo.sol`
4. `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeCommon.sol`
5. `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeInTarget.sol`
6. `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeInFacet.sol`
7. `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeOutTarget.sol`
8. `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeOutFacet.sol`
9. `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeDFPkg.sol`
10. `contracts/protocols/dexes/uniswap/v4/UniswapV4_Component_FactoryService.sol`
11. `contracts/protocols/dexes/uniswap/v4/test/bases/TestBase_UniswapV4StandardExchange.sol`

Likely support files outside the directory:

1. manager deployment surface updates so IndexedEx can deploy the new DFPkg through the same pattern used by the existing standard-exchange packages,
2. protocol vault package wiring where DETF or other protocol vaults may want a V4 standard exchange vault,
3. Foundry tests under `test/foundry/spec/protocol/dexes/uniswap/v4/...` or the existing IndexedEx test mirror.

Optional reusable helper files if preview complexity justifies them:

1. `contracts/protocols/dexes/uniswap/v4/UniswapV4QuoteService.sol`
2. `contracts/protocols/dexes/uniswap/v4/UniswapV4UnlockCallbackBase.sol`

## Repo Layout And Storage Plan

### UniswapV4PoolManagerAwareRepo

Responsibilities:

1. store the bound `IPoolManager`,
2. expose `_initialize(poolManager_)`,
3. expose `_poolManager()`.

### UniswapV4PoolKeyAwareRepo

Responsibilities:

1. store the full `PoolKey`,
2. store cached `PoolId`,
3. expose `currency0`, `currency1`, `fee`, `tickSpacing`, `hooks` through accessors when convenient.

### UniswapV4PositionRepo

Responsibilities:

1. store `tickLower`, `tickUpper`, `liquidity`, `positionSalt`, and `positionCreated`,
2. store `widthMultiplier`,
3. optionally cache `lastSqrtPriceX96`, `lastTick`, and timestamp for preview invalidation,
4. provide helpers to compute the canonical position key using Crane V4 `Position.calculatePositionKey(...)` or equivalent library flow.

This repo should mirror the current Slipstream vault repo conceptually, but it must include salt as part of position identity.

## Package Interface Plan

`IUniswapV4StandardExchangeDFPkg` should expose:

1. `PkgInit` with the required facets plus `IVaultFeeOracleQuery`, `IVaultRegistryDeployment`, `IPermit2`, and `IPoolManager`,
2. `PkgArgs` carrying `PoolKey` and `widthMultiplier`,
3. `deployVault(PoolKey memory poolKey, uint24 widthMultiplier)`.

Do not use a single `reserveAsset` field the way the V2 and Aerodrome V1 packages do.

`initAccount(...)` must fully initialize vault state. At minimum it should:

1. derive a readable name from `currency0/currency1/fee/tickSpacing`,
2. initialize `ERC20Repo`,
3. initialize `EIP712Repo`,
4. initialize `StandardVaultRepo`,
5. initialize `VaultFeeOracleQueryAwareRepo`,
6. initialize `Permit2AwareRepo`,
7. initialize `UniswapV4PoolManagerAwareRepo`,
8. initialize `UniswapV4PoolKeyAwareRepo`, and
9. initialize `UniswapV4PositionRepo` with the width multiplier and salt.

This is mandatory. The Slipstream sketch currently leaves this step empty, and the V4 package should not repeat that mistake.

## Execution Model

### Unlock Callback Wrapper

The common target should provide a small internal unlock orchestration layer.

Recommended pattern:

1. external route function validates args and transfers user funds to the vault when needed,
2. target encodes an operation struct,
3. target calls `poolManager.unlock(encodedOperation)`,
4. `unlockCallback` decodes and dispatches to one internal handler,
5. handler performs one or more `swap` and `modifyLiquidity` calls,
6. handler settles debts and takes credits before returning,
7. external function decodes the result and finalizes ERC20 share mint or burn.

Suggested internal operation enum:

1. `SwapExactIn`
2. `SwapExactOut`
3. `ZapIn`
4. `ZapOut`
5. `CollectFeesOnly`

### Delta Settlement

Every unlock handler must explicitly manage flash-accounting deltas.

For each affected currency:

1. if the vault owes the `PoolManager`, call `sync(currency)` then `settle()` or `settleFor(...)`,
2. if the `PoolManager` owes the vault, call `take(currency, address(this), amount)`,
3. ensure `NonzeroDeltaCount` would be zero at callback return.

The plan should assume that settlement helper functions are part of `UniswapV4StandardExchangeCommon.sol`.

## Preview Strategy

Preview support is part of the `IStandardExchangeIn` and `IStandardExchangeOut` UX, so this cannot be skipped.

Recommended phased approach:

### Phase 1 preview target

Support exact previews for hookless pools only.

Implementation options in preferred order:

1. add a reusable V4 quote helper that simulates swap math from `StateLibrary`, `TickBitmap`, `TickMath`, and `SwapMath`,
2. if that is too large for the first pass, create an IndexedEx-local quoter that mirrors the standard V4 quoter pattern through revert-return or controlled unlock simulation,
3. keep zap previews conservative and explicit if swap-side preview remains partial during early bring-up.

Important note:

1. hook-modified swaps and dynamic-fee hooks should be out of guaranteed preview scope for the first version,
2. execution may still support such pools if settlement works, but preview parity should be declared unsupported until the quote layer is hook-aware.

## Route Matrix

The route surface should intentionally mirror Slipstream.

### Exact-In Routes

1. `currency0 -> currency1`
2. `currency1 -> currency0`
3. `currency0 -> vault shares`
4. `currency1 -> vault shares`

### Exact-Out Routes

1. `currency0 -> currency1`
2. `currency1 -> currency0`
3. `vault shares -> currency0`
4. `vault shares -> currency1`

Unsupported routes:

1. `vault shares -> vault shares`
2. same-asset no-op routes
3. arbitrary intermediate tokens outside the pool currencies

## Route Workflows

### Route A: Exact-In Direct Swap `currency0 -> currency1`

Workflow:

1. `previewExchangeIn` quotes exact output using the V4 quote layer,
2. `exchangeIn` pulls `currency0` from the user or validates pretransfer,
3. vault enters `PoolManager.unlock`,
4. unlock handler calls `poolManager.swap(poolKey, SwapParams(...))` with negative `amountSpecified`,
5. vault settles input debt in `currency0`,
6. vault takes output credit in `currency1`,
7. callback returns output amount,
8. external function transfers `currency1` to the recipient,
9. enforce `minAmountOut` on the final amount.

### Route B: Exact-Out Direct Swap `currency0 -> currency1`

Workflow:

1. `previewExchangeOut` quotes exact input required,
2. `exchangeOut` checks quoted input against `maxAmountIn`,
3. vault pulls or validates input funds,
4. vault enters unlock,
5. handler executes positive `amountSpecified` exact-output swap,
6. handler settles actual input debt and takes exact output credit,
7. callback returns actual input used,
8. external function refunds pretransferred excess if applicable,
9. external function transfers the exact `currency1` output to the recipient.

### Route C: Zap-In `currency0 -> vault shares`

Recommended workflow:

1. preview path estimates the optimal split between currencies for the current tick range,
2. vault calculates the position tick band if the position has not yet been created,
3. vault pulls the user’s single-sided input,
4. vault enters unlock,
5. handler performs an internal cleanup swap so vault ends with the required `currency0/currency1` mix,
6. handler calls `modifyLiquidity` with positive `liquidityDelta`,
7. handler settles both currencies with `PoolManager`,
8. handler records new liquidity and any fee accrual,
9. external function mints vault shares based on actual principal value added relative to total vault value.

Important rule:

The vault must never estimate a split and then pull a second token from the user. The zap route is single-sided by definition.

### Route D: Zap-Out `vault shares -> currency0`

Recommended workflow:

1. preview path computes shares needed for the desired output,
2. external function validates the user share balance,
3. vault enters unlock,
4. handler calls `modifyLiquidity` with negative `liquidityDelta`,
5. handler takes both currency credits from the `PoolManager`,
6. if the withdrawn bundle is not fully one-sided, handler executes a cleanup swap into the requested output currency,
7. handler settles any intermediate debt,
8. callback returns final one-sided output,
9. external function burns user shares using the actual liquidity/share entitlement,
10. external function transfers final output currency to the recipient and enforces min-output semantics.

Important rule:

The final transferred output must be measured after the cleanup swap, not before it.

## Share Accounting Plan

Use the Slipstream economic model, adapted to V4 state.

Minting shares:

1. if `totalSupply == 0`, mint shares from actual principal value added using a simple normalized initial convention,
2. otherwise use total vault value before the deposit and actual principal value contributed,
3. include accrued fees in total vault value so incumbents are not diluted incorrectly.

Burning shares:

1. determine the proportional liquidity and accrued value represented by the shares,
2. remove that liquidity,
3. settle final output,
4. burn shares only after actual entitlement is known.

Use the same consistency principles as the existing constant-product and Slipstream vaults, but base valuations on V4 position state from `StateLibrary` and V4 math helpers.

## Tick Range Plan

For the first deposit:

1. read current tick from `StateLibrary.getSlot0(...)`,
2. compute half-width from `widthMultiplier * tickSpacing`,
3. snap both bounds to valid multiples of `tickSpacing`,
4. clamp to V4 tick bounds,
5. persist canonical `tickLower` and `tickUpper`.

Do not store unsnapped ticks.

## Testing Plan

### Base Test Infrastructure

Create `TestBase_UniswapV4StandardExchange.sol` with:

1. PoolManager deployment,
2. optional PositionManager deployment for reference operations,
3. helper to build a hookless `PoolKey`,
4. helper to initialize a pool and seed external liquidity,
5. helper to deploy the vault package through IndexedEx manager,
6. helper to deploy a vault bound to one pool key.

Progress:

1. the base test file has been created under `contracts/protocols/dexes/uniswap/v4/test/bases/TestBase_UniswapV4StandardExchange.sol`,
2. it already deploys the PoolManager and the V4 facets/package scaffold needed for local bring-up, and
3. it still needs to be extended so tests exercise the final Indexedex Manager deployment helper rather than only the local package scaffolding.

### Required Test Categories

1. facet metadata tests for both new facets,
2. package deployment and `initAccount` state wiring tests,
3. direct exact-in swap success tests for both directions,
4. direct exact-out swap success tests for both directions,
5. zap-in tests for both input currencies,
6. zap-out tests for both output currencies,
7. preview-vs-execution parity for hookless pools,
8. deadline and slippage failure tests,
9. flash-accounting settlement safety tests,
10. first-deposit tick-range creation tests,
11. fee accrual and fee-aware share pricing tests,
12. unsupported route revert tests.

### Suggested Initial Test Files

1. `test/foundry/spec/protocol/dexes/uniswap/v4/UniswapV4StandardExchangeDFPkg_Deploy.t.sol`
2. `test/foundry/spec/protocol/dexes/uniswap/v4/UniswapV4StandardExchange_In.t.sol`
3. `test/foundry/spec/protocol/dexes/uniswap/v4/UniswapV4StandardExchange_Out.t.sol`
4. `test/foundry/spec/protocol/dexes/uniswap/v4/UniswapV4StandardExchange_Previews.t.sol`

Recommended test rollout order:

1. start with facet metadata tests for the in/out facets using the existing `TestBase_IFacet` pattern already used by Slipstream,
2. add a deploy-and-init spec that verifies `PoolManager`, `PoolKey`, `PoolId`, width multiplier, and position salt wiring,
3. add direct exact-in and exact-out happy-path specs against a seeded hookless pool,
4. add slippage, deadline, unsupported-route, and refund-path negative tests,
5. add zap-in and zap-out tests after the direct routes are stable, and
6. add preview parity assertions only after the preview layer is tightened enough that failures are diagnostic rather than expected.

Minimum first-pass suite for manager wiring:

1. `UniswapV4StandardExchangeInFacet_IFacet_Test.t.sol`
2. `UniswapV4StandardExchangeOutFacet_IFacet_Test.t.sol`
3. `UniswapV4StandardExchangeDFPkg_Deploy.t.sol`
4. `UniswapV4StandardExchangeRoutes_Test.t.sol`

## Implementation Phases

### Phase 1: Scaffolding And State

1. create the V4 directory and repo files,
2. implement aware repos and position repo,
3. implement facet shells and factory service,
4. implement package interface and constructor,
5. implement full `initAccount` wiring,
6. add basic TestBase deployment coverage.

Exit criteria:

1. package deploys through IndexedEx manager,
2. pool manager and pool key are stored correctly,
3. facets expose the expected interfaces and selectors.

Progress update:

1. the repos, targets, facets, package, and local component factory service are implemented,
2. `initAccount(...)` wiring is no longer a placeholder and now initializes the V4-specific repos,
3. the local compile step has passed, and
4. the remaining work in this phase is to expose the package deployment through the Indexedex Manager surface so tests and protocol packages can use the same deployment entrypoint as the other exchange DFPkgs.

### Phase 2: Direct Swap Routes

1. implement unlock callback orchestration,
2. implement settlement helpers,
3. implement exact-in and exact-out direct token routes,
4. implement initial hookless preview support,
5. add direct swap tests.

Exit criteria:

1. direct swap routes pass exact-in and exact-out tests,
2. previews are within tolerance for hookless pools,
3. no unsettled deltas remain after callbacks.

Progress update:

1. the direct route scaffolding and unlock orchestration exist,
2. settlement helpers are implemented in the common V4 layer,
3. compile-time issues in the route targets have been resolved, and
4. behavioral validation is still pending until the dedicated Foundry route specs land.

### Phase 3: Zap Routes And Share Accounting

1. implement first-deposit tick-band creation,
2. implement liquidity-add zap-in routes,
3. implement liquidity-remove zap-out routes,
4. implement fee-aware total-value accounting,
5. add share mint/burn tests and parity tests.

Exit criteria:

1. one-sided share mint and burn routes work in both directions,
2. actual shares minted and burned are consistent with vault value,
3. final transfer amounts are measured post-swap and post-settlement.

Progress update:

1. zap-in and zap-out execution skeletons are present,
2. the code has already been refactored once to keep these flows under the stack limit without enabling `viaIR`,
3. a seeded hookless pool route test now exercises direct exact-in swaps in both directions through the deployed vault, and
4. share-accounting behavior still needs dedicated zap-focused tests before this phase can be considered complete.

### Phase 4: Integration Hardening

1. add protocol package wiring if needed,
2. add more realistic seeded-pool tests,
3. validate behavior against at least one initialized V4 pool with nontrivial liquidity,
4. document any hook restrictions explicitly.

Exit criteria:

1. the vault is deployable through normal IndexedEx flows,
2. tests cover all supported routes,
3. limitations are explicit rather than implicit.

### Phase 4A: Indexedex Manager Wiring

Status: completed for the V4 package deployment path used by the current test base.

Completed work:

1. the Uniswap V4 component factory service now supports a manager-facing `deployUniswapV4StandardExchangeDFPkg(...)` helper,
2. the helper naming was adjusted to avoid overload ambiguity with `IVaultRegistryDeployment`,
3. `TestBase_UniswapV4StandardExchange.sol` now deploys the package through `indexedexManager`, and
4. the deploy spec verifies that the manager-deployed package can deploy and initialize a vault via `deployVault(PoolKey,uint24)`.

Primary code surfaces to touch:

1. `contracts/protocols/dexes/uniswap/v4/UniswapV4_Component_FactoryService.sol`
2. the Indexedex Manager deployment surface and any supporting interface declarations that expose `deploy...DFPkg(...)` helpers,
3. `contracts/protocols/dexes/uniswap/v4/test/bases/TestBase_UniswapV4StandardExchange.sol`, and
4. any protocol package init structs that need to consume the new DFPkg later.

Validation for this step:

1. a targeted deploy spec asserts manager-driven package deployment succeeds,
2. a vault deployment assertion passes through the returned DFPkg, and
3. the focused V4 spec slice currently passes with the manager-connected path in place.

### Phase 4B: Foundry Test Execution Plan

Status: in progress.

Concrete plan:

1. add facet metadata tests first because they are cheap and verify the public surface is wired correctly,
2. add a deployment test that mirrors the existing standard-exchange deploy patterns and validates full `initAccount(...)` state,
3. add one direct-swap route spec for each direction before expanding into zap flows,
4. add exact-out refund and slippage guard tests using the same negative-test style already present in the repo for other exchange vaults,
5. add zap-in and zap-out tests only after the direct route assertions are stable,
6. add preview parity tests last and scope them to hookless pools,
7. if a regression appears in settlement behavior, add one dedicated assertion that no callback leaves outstanding deltas or trapped balances.

Proposed command sequence:

```bash
forge test --match-path test/foundry/spec/protocol/dexes/uniswap/v4/UniswapV4StandardExchangeInFacet_IFacet_Test.t.sol
forge test --match-path test/foundry/spec/protocol/dexes/uniswap/v4/UniswapV4StandardExchangeOutFacet_IFacet_Test.t.sol
forge test --match-path test/foundry/spec/protocol/dexes/uniswap/v4/UniswapV4StandardExchangeDFPkg_Deploy.t.sol
forge test --match-path test/foundry/spec/protocol/dexes/uniswap/v4/UniswapV4StandardExchangeRoutes_Test.t.sol
```

If route coverage expands into separate files, follow with:

```bash
forge test --match-path test/foundry/spec/protocol/dexes/uniswap/v4/UniswapV4StandardExchange_In.t.sol
forge test --match-path test/foundry/spec/protocol/dexes/uniswap/v4/UniswapV4StandardExchange_Out.t.sol
forge test --match-path test/foundry/spec/protocol/dexes/uniswap/v4/UniswapV4StandardExchange_Previews.t.sol
```

Progress update:

1. both `IFacet` metadata suites are implemented and passing,
2. the DFPkg deployment suite is implemented and passing,
3. `UniswapV4StandardExchangeRoutes_Test.t.sol` now covers direct exact-in execution in both directions against a seeded hookless pool,
4. the same route suite now covers direct exact-out execution in both directions, low-max-input reverts, and excess-input refunds,
5. the same route suite now covers zap-in share minting for both pool currencies, both first-deposit and existing-position paths, `pretransferred=true`, and min-shares reverts, and
6. the same route suite now covers zap-out share burns to both pool currencies, low-max-share reverts, and `pretransferred=true` share withdrawals.

Important implementation hardening completed during this phase:

1. the V4 exact-out path no longer assumes the preview estimate is the exact spend amount,
2. the vault now spends up to `maxAmountIn`, measures actual input consumed from balances, and refunds unused input, and
3. the simple direct exact-out preview adds a conservative one-unit buffer so it does not underestimate the real swap debt in the current hookless path, and
4. the share-input zap-out path now handles `pretransferred=true` correctly by burning vault-held shares and refunding any unused pretransferred shares.

## Open Questions

These should be answered before or during Phase 1:

1. should v1 support only hookless pools, or any pool whose hooks do not return deltas?
2. should the vault store hook data defaults, or require empty hook data for now?
3. should exact previews be hard-disabled for hook pools in v1?
4. should first-deposit tick bands use symmetric width around current tick only, or accept caller-supplied bands in a later version?
5. should the vault expose fee collection as an explicit maintenance call, or collect lazily on all zap routes?

## Validation Commands

Minimum validation during implementation:

```bash
forge build
forge test --match-path test/foundry/spec/protocol/dexes/uniswap/v4/...
forge test --match-contract UniswapV4StandardExchangeDFPkg_Deploy
```

If the implementation touches manager deployment surfaces or protocol vaults, add the smallest affected higher-level suite after the targeted V4 tests pass.

## Success Criteria

This plan is complete when the resulting vault:

1. deploys as a normal IndexedEx DFPkg through the manager,
2. binds cleanly to a V4 `PoolKey`,
3. owns and manages one canonical V4 liquidity position,
4. supports the four exact-in/exact-out route families listed above,
5. performs correct V4 unlock and settlement accounting,
6. prices shares against actual vault value including fees, and
7. has targeted Foundry coverage for deployment, swaps, zaps, previews, and revert conditions.

## Immediate Next Steps

Ordered next actions from the current state:

1. add direct exact-out execution tests in both directions against the seeded hookless pool,
1. decide whether preview parity needs a dedicated helper or should remain intentionally conservative for v1,
2. widen from the V4 slice to the smallest higher-level protocol package integrations that should consume this DFPkg,
3. add any additional negative-path combinations only where they expose new behavior rather than duplicating current coverage, and
4. document hookless-first limitations explicitly anywhere this package is surfaced to higher-level vault flows.
