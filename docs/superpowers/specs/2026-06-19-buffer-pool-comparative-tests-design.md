# Standard Exchange Buffer Pool — Comparative Tests Design

**Date:** 2026-06-19
**Status:** Approved (design) — implementation pending
**Author:** brainstorming session

## Living progress log

> Keep this section updated as implementation proceeds so work can resume after a failure.
> Mark each task `[x]` when complete; add notes/commit SHAs inline.

- [ ] T1 — New comparative test base `TestBase_StandardExchangeBufferPool_Comparative`
- [ ] T2 — Reference const-prod pool deployment (shared rate provider, matched live reserves)
- [ ] T3 — Fee equalization between both pools
- [ ] T4 — Helpers: `tradeUnderlyingV2`, reference-pool swap, live-balance reads, snapshot isolation
- [ ] T5 — Behavior library `Behavior_StandardExchangeBufferPool_Comparative`
- [ ] T6 — Spec runner with the 6 comparative test cases
- [ ] T7 — `forge build` clean
- [ ] T8 — `forge test` for the comparative spec green

**Notes / resume point:** _(none yet)_

---

## 1. Goal & equivalence thesis

The Standard Exchange Buffer Pool (`contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/`)
holds two tokens `(TTA, shares)` registered in the Balancer V3 Vault, scales the shares side via
`StandardExchangeRateProvider`, and tracks `virtualTTA` / `hookSharesDelta` to **simulate** a real
constant-product pool while consolidating all liquidity inside the SE vault (the hook deposits the
opposing token into the vault).

These comparative tests prove that a **real `BalancerV3ConstantProductPool` of the same two tokens
`(TTA, shares)`**, registered with the **same rate provider** on the shares side, produces:

- the **same swap outputs** (both directions, EXACT_IN), and
- the **same spot price**,

both **at the initial rate** and **after the underlying Uniswap V2 pool is traded** to move the rate
the rate provider reports.

This is the equivalence the buffer pool's `virtualTTA` / `hookSharesDelta` accounting is designed to
maintain. The comparative suite is the missing direct A/B confirmation.

## 2. Decisions (locked)

| Topic | Decision |
| --- | --- |
| Reference pool | `BalancerV3ConstantProductPool` of `(TTA, shares)` with the **same `seRateProvider`** on the shares side (`TokenType.WITH_RATE`). |
| Init matching | **Match effective (live) reserves**: reference raw TTA = buffer pool `virtualTTA`; reference raw shares = buffer pool raw shares. Same rate provider ⇒ identical scaled shares-side balances. |
| Equality standard | **Near-exact, fees equalized**: same swap fee on both pools (target 0, fallback to shared min bound), assert within small absolute + relative tolerance. |
| Coverage | Swaps both directions EXACT_IN (at initial rate and after rate change) + spot-price/`getRate` after the V2 trade. |
| Underlying | Build on the existing **Uniswap V2** SE-vault variant. |

## 3. Harness reuse

Build on `test/foundry/spec/protocols/dexes/balancer/v3/pools/constProd/standardExchange/uniswapV2/bases/TestBase_StandardExchangeBufferPool_UniswapV2.sol`.

It already wires: UniV2 factory/router stubs, a DAI/USDC V2 pair (`uniV2DaiUsdcPair`, `uniV2Router`),
the SE vault (`seVault`, `tta` = DAI, `ttb` = USDC, `shares`), the rate provider (`seRateProvider`),
and the initialized buffer pool (`bufferPool`).

The parent `TestBase_StandardExchangeBufferPool`:
- already **imports** `BalancerV3ConstantProductPool_FactoryService` (using-directive on `ICreate3FactoryProxy`),
- already deploys the six shared BV3 pool facets in `_deployBufferPoolFacets()`:
  `balancerV3VaultAwareFacet`, `betterBalancerV3PoolTokenFacet`, `defaultPoolInfoFacet`,
  `standardSwapFeePercentageBoundsFacet`, `unbalancedLiquidityInvariantRatioBoundsFacet`,
  `balancerV3AuthenticationFacet`.

So the comparative work is **additive only** — no production contracts change, and the reference pool
reuses the same `bv3Vault`, `diamondPackageFactory`, shared facets, `seRateProvider`, and `shares` token.

## 4. New test base — `TestBase_StandardExchangeBufferPool_Comparative`

Path: `test/foundry/spec/protocols/dexes/balancer/v3/pools/constProd/standardExchange/comparative/bases/TestBase_StandardExchangeBufferPool_Comparative.sol`

`abstract contract TestBase_StandardExchangeBufferPool_Comparative is TestBase_StandardExchangeBufferPool_UniswapV2`.

New state:
- `IFacet internal balancerV3ConstProdPoolFacet;`
- `IBalancerV3ConstantProductPoolStandardVaultPkg internal refPoolPkg;`
- `address public referencePool;`

Override `setUp()` to call `super.setUp()` then `_deployReferencePool()`.

### 4.1 `_deployReferencePool()`

1. Deploy the const-prod pool facet via
   `create3Factory.deployBalancerV3ConstantProductPoolFacet()`.
2. Build the const-prod `PkgInit` (reuse already-deployed shared facets + `bv3Vault` +
   `diamondPackageFactory`; `poolFeeManager` = a manager address such as `owner`/`indexedexManager`).
   Deploy the package via `BalancerV3ConstantProductPool_FactoryService.deployBalancerV3ConstantProductPoolStandardVaultPkg(...)`.
   - NOTE: the **indexedex** `BalancerV3ConstantProductPoolStandardVaultPkg` PkgInit shape differs from
     the crane DFPkg shown above — confirm the exact `PkgInit` struct in
     `contracts/protocols/dexes/balancer/v3/pools/constProd/BalancerV3ConstantProductPoolStandardVaultPkg.sol`
     at implementation time and match its fields.
3. Build `TokenConfig[2]`:
   - TTA (DAI): `TokenType.STANDARD`, `rateProvider = address(0)`, `paysYieldFees = false`.
   - shares (`address(seVault)`): `TokenType.WITH_RATE`, `rateProvider = seRateProvider`, `paysYieldFees = false`.
   - The DFPkg sorts token configs internally; the registration order is canonical.
4. `referencePool = refPoolPkg.deployPool(tokenConfigs, address(0));` (no hook on the reference pool).
   `vm.label`, `approveForPool(IERC20(referencePool))`.
5. **Equalize fees** (see §6).
6. **Initialize with matched live reserves** (see §5).

## 5. Matched initialization (effective/live reserves)

Buffer pool effective live balances after init:
- TTA side = `IStandardExchangeBufferPool(bufferPool).virtualTTA()`.
- shares side (raw) = buffer pool's raw shares balance; the Vault scales it by the rate.

Read the buffer pool's post-init state, then initialize the reference pool so its **live** balances
match:
- reference raw TTA = `virtualTTA` (TTA is `STANDARD`, rate = 1 ⇒ raw = live).
- reference raw shares = buffer pool raw shares (WITH_RATE, same provider ⇒ scaled identically).

Source of buffer pool raw balances: `bv3Vault.getPoolTokenInfo(bufferPool)` raw balances, indexed via
`IStandardExchangeBufferPool.ttaIndex()` / `sharesIndex()`. (Fallback to the known `INITIAL_SHARES_RAW`
seed if a direct read is awkward.)

Init flow mirrors the parent `_initPool()`:
- mint DAI to alice = reference raw TTA; acquire SE shares = reference raw shares
  (via the existing V2 addLiquidity → SE deposit path / `mintShares`).
- approvals for DAI + shares to router/permit2 already set in setUp for all users.
- `router.initialize(referencePool, poolTokens, amounts, 0, false, "")` with `amounts` indexed by the
  reference pool's token order.

Add `test_compare_init_liveBalancesMatch`: assert `bv3Vault.getCurrentLiveBalances(bufferPool)` equals
`getCurrentLiveBalances(referencePool)` within tolerance.

## 6. Fee equalization

The const-prod DFPkg registers with a non-zero static swap fee; the buffer pool has its own. To compare
the **curves**, set both pools to the **same** static swap-fee percentage.

- Target: `0`.
- The shared `StandardSwapFeePercentageBoundsFacet` enforces min `1e12` (0.0001%); if the Vault rejects
  `0`, set **both** pools to `1e12` (or to the buffer pool's actual configured fee) — the requirement is
  only that both are identical.
- Mechanism: set via the BV3 Vault mock admin path (`setStaticSwapFeePercentage` or the mock's
  equivalent). **OPEN ITEM:** confirm the VaultMock exposes a settable swap fee and whether `0` is
  accepted; resolve during implementation and record here.

## 7. Helpers (on the comparative base)

- `tradeUnderlyingV2(uint256 daiIn)` — mint DAI to a trader, approve `uniV2Router`, swap DAI→USDC on
  `uniV2DaiUsdcPair`. This shifts per-LP value, so `seRateProvider.getRate()` reports a new rate seen by
  **both** pools (they share the provider and the shares token). Provide both directions if useful
  (`tradeUnderlyingV2Reverse`).
- `swapReferenceExactIn(address user, IERC20 tokenIn, IERC20 tokenOut, uint256 amountIn)` — mirrors the
  parent `_doSwapExactIn` against `referencePool`.
- `liveBalances(address pool)` → `(uint256 tta, uint256 shares)` via `bv3Vault.getCurrentLiveBalances`.
- Snapshot isolation: helper to run a swap on one pool, capture output + post-state, then `vm.revertTo`
  so the other pool is swapped from an identical pre-state. Always compare both pools from the **same**
  pre-state.

## 8. Behavior library + spec runner

- `comparative/behaviors/Behavior_StandardExchangeBufferPool_Comparative.sol` — abstract, vault-agnostic
  assertions reading from the base (`_base()` hook pattern, matching existing behavior libraries).
- `comparative/StandardExchangeBufferPool_Comparative.spec.t.sol` — concrete runner inheriting the base +
  behavior, implementing `_base()`.

### Test cases

1. `test_compare_init_liveBalancesMatch` — equal live balances after matched init.
2. `test_compare_swap_TTAtoShares_atInitialRate` — equal EXACT_IN output (within tolerance).
3. `test_compare_swap_sharesToTTA_atInitialRate` — equal EXACT_IN output.
4. `test_compare_swap_TTAtoShares_afterRateChange` — `tradeUnderlyingV2`, then equal output.
5. `test_compare_swap_sharesToTTA_afterRateChange` — `tradeUnderlyingV2`, then equal output.
6. `test_compare_spotPrice_afterRateChange` — both pools report equal marginal price / `getRate`
   after the V2 trade (compare live-balance ratios and/or a tiny probe swap).

Each swap test compares both pools from an identical pre-state using snapshot/revert.

## 9. Equality standard

`assertApproxEqAbs` (a few wei) combined with `assertApproxEqRel` (~`1e-6`) to absorb hook-path rounding
without masking real divergence. Document the chosen tolerances as named constants in the base.

## 10. Open risks / items to resolve during implementation

- **VaultMock swap-fee setter** — confirm it exists and whether `0` is accepted (§6). Record outcome.
- **`getCurrentLiveBalances` on the VaultMock** — confirm exposure; fallback to computing live balances
  from `virtualTTA` + raw shares × rate.
- **Indexedex `BalancerV3ConstantProductPoolStandardVaultPkg.PkgInit` shape** — confirm exact fields vs.
  the crane DFPkg (§4.1 step 2).
- **Snapshot/revert isolation** — ensure no cross-contamination between the two pools' comparisons.
- **Token sort order** — reference pool token order (from DFPkg `_sort()`) may differ from the buffer
  pool's; always index via `ttaIndex()`/`sharesIndex()` (buffer) and `getPoolTokenInfo` (reference).

## 11. Out of scope (this spec)

- EXACT_OUT swaps and LP add/remove proportional comparisons (can be a follow-up spec).
- Aerodrome-backed comparative variant (the V2 variant is the basis per the requirements).
- Fuzz/invariant comparative testing.
