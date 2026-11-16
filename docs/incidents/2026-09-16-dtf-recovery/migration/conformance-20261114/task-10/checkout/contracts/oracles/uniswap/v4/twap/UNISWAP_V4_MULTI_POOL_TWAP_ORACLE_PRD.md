# PRD: Uniswap V4 multi-pool TWAP oracle

**Name:** Uniswap V4 multi-pool poke TWAP oracle  
**Date:** 2026-08-24  
**Status:** **Draft v1.5 — product law for planning** (no implementation yet)  
**Package path:** `contracts/oracles/uniswap/v4/twap/`  
**Package kind:** Crane **Diamond Factory Package**. CREATE3 facets + package once; each `deploy(PkgArgs)` mints a **diamond proxy instance** bound to one PoolManager. **Not** a Uniswap V4 hook. **Not** a vault (do not `deployVault`). **Not** the Vault Fee Oracle.

**Related (do not conflate):**

| Artifact | Role |
|----------|------|
| This PRD | Product law for the DFPkg, instances, Morpho / AggregatorV3 adapters, and SE vault poke wiring |
| [`UNISWAP_V4_MULTI_POOL_TWAP_ORACLE_IMPLEMENTATION_AND_TEST_PLAN.md`](./UNISWAP_V4_MULTI_POOL_TWAP_ORACLE_IMPLEMENTATION_AND_TEST_PLAN.md) | Coding phases, file list, algorithms, test matrix DoD. **PRD wins** on product conflicts. |
| [`UNISWAP_V4_STANDARD_EXCHANGE_LOCAL_LIQUID_BUFFER_PRD.md`](../../../protocols/dexes/uniswap/v4/UNISWAP_V4_STANDARD_EXCHANGE_LOCAL_LIQUID_BUFFER_PRD.md) | V4 SE sleeve / PoolManager lock. This oracle **pokes on SE ops**; it does not change sleeve math. |
| Uni V4 hook DFPkgs (`contracts/hooks/uniswap/v4/**`) | Those hooks are **pool** hooks. This oracle is **external**. Do not merge them. |
| Vault Fee Oracle (`contracts/oracles/fee/`) | Usage / liquid-% fees. **Not** a price feed. Lives on the manager diamond; this product is a **separate instance per manager**. |
| Morpho Blue `IOracle` | Consumer shape for lending markets. Adapters implement it. |
| Deleted listing-family DETF / `UniV4DetfListingOracleLib` | Dead code. **Do not revive** the listing DETF. |
| Uniswap V3 `observe()` | Behavioral reference for accumulators. V4 PoolManager has **no** observations. |
| GeomeanOracle / TruncGeoOracle / `V3StyleOracleHook` | Hook-based. Useless for pools that already have a hook. |
| pons v2 meme hook | Fee hook only. Graduated V4 pools have **no** TWAP. This oracle is the on-chain path for those pools. |
| Rate-provider DFPkgs | Behavioral peer for “package deploys many small diamonds from `PkgArgs`.” Do **not** subclass. |

**Authority:**

| Layer | Role |
|-------|------|
| **This PRD (v1.5)** | Product law |
| Implementation and test plan | Coding phases, file map, DoD |
| [`docs/agent/INDEXEDEX_AGENT_LAW.md`](../../../../docs/agent/INDEXEDEX_AGENT_LAW.md) | Token policy, Crane deploy, production-first tests, DETF mint/burn **not** using this feed |
| Crane `crane-architecture` / `crane-deployment` | Facet-Target-Repo, `PkgInit`/`PkgArgs` **on the interface**, CREATE3, shared `DiamondPackageCallBackFactory` |
| Morpho `IOracle` + `MorphoChainlinkOracleV2` | External consumer contracts; we adapt, we do not fork Morpho |

---

## 0. Terminology (normative)

| Term | Meaning |
|------|---------|
| **Package** | `IUniswapV4MultiPoolTwapOracleDFPkg`. CREATE3 once per chain (facets + package bytecode). |
| **Instance / proxy** | Diamond deployed by `package.deploy(PkgArgs)`. This is the multi-pool TWAP oracle **for one PoolManager**. |
| **PoolManager** | `PkgArgs.poolManager`. Uniswap V4-compatible singleton whose `slot0` this instance reads. |
| **Compatible manager** | A contract this package can read with Uniswap V4 `StateLibrary.getSlot0` (same storage layout as `IPoolManager`). Includes Uniswap V4 and storage-compatible forks / V4-based DEXes. |
| **Sibling package** | A later DFPkg that reuses ring math but a **different reader**, for a DEX that is not StateLibrary-compatible. Out of v1 code; this PRD requires the instance model so that sibling is possible. |
| **PoolKey / PoolId** | Uniswap V4 identity: `(currency0, currency1, fee, tickSpacing, hooks)`. `PoolId = keccak256(abi.encode(PoolKey))`. |
| **Poke / update** | A state-changing call that takes **one** `PoolKey`, reads that pool’s slot0 on the bound manager, and writes at most one observation for that pool in the current block. Primary write path. Batch `update(PoolKey[])` is optional keeper sugar, not the SE path. |
| **Observation** | One ring slot: timestamp, tick cumulative, previous recorded tick, initialized flag. No seconds-per-liquidity in v1. |
| **Ring / cardinality** | Per-pool circular buffer on **that instance**. Starts at 1. Grows when someone pays `increaseCardinalityNext`. Cap **65535**. |
| **Truncation** | Per write (and per observe interpolation), recorded tick may move at most `MAX_ABS_TICK_MOVE = 9116` from the previous recorded tick. |
| **Consult** | Arithmetic-mean tick over a lookback, from two `observe` points. Same idea as V3 `OracleLibrary.consult`. |
| **Adapter** | Separate **monomorph** (not a Diamond) that freezes **one oracle instance**, pool, direction, window, and freshness, then exposes Morpho `IOracle` and/or AggregatorV3. |
| **Write age** | `block.timestamp - lastObservation.timestamp` for a pool **on that instance**. Adapters **revert** when this exceeds `maxWriteAge`. |
| **Bound pool** | The `PoolKey` a Uniswap V4 SE vault already stores. v1 SE pokes **only** this key. |
| **Foreign pool** | Any initialized pool on the instance’s manager that is not this vault’s bound pool. Includes pons v2 graduated pools. Tracked by permissionless `update` (keepers, liquidators, routers), **not** by vault `PkgArgs`. |
| **Market-moving SE entry** | Zap-in, zap-out, direct swap, rebalance, successful position import, `rebalanceLiquidReserve`. Not ERC-20 `transfer` / `approve` / `permit`. Not previews. |

**V4 lock naming:** `update` / `observe` **do not** call `poolManager.unlock`. They only `getSlot0` (view extSLOAD). Pokes are legal while PoolManager is in-session.

**Hook naming pitfall:** This product is **not** a Uniswap V4 hook. It cannot be set as `PoolKey.hooks`.

**Instance vs package pitfall:** Morpho adapters store the **oracle instance** address, never the TWAP DFPkg. Uni V4 SE **vaults** get the instance from the SE **package** `PkgInit` immutable (architecture bootstrap), not from per-vault `PkgArgs`.

---

## 1. Problem statement

### 1.1 What V4 does not give us

Uniswap V2/V3 wrote a tick accumulator into every pool. V4 removed that. `PoolManager` exposes **spot** (`getSlot0` → `sqrtPriceX96`, `tick`) and nothing else.

A V4 pool only has a TWAP if its **hook** records observations, or an **external** contract records them.

IndexedEx and pons fail the hook path for the pools that matter:

- **pons v2** graduated pools use the meme hook (fees only). No `observe`.
- **IndexedEx Uni V4 SE / buffer-hook pools** already occupy the single hook slot.
- Hook address is part of `PoolKey`. A second pool with a TWAP hook does not see locked pons / SE liquidity.

There is no production, hook-independent, multi-pool Uniswap V4 TWAP oracle to consume.

### 1.2 Why a package of instances, not one global contract

A chain can have:

- The canonical Uniswap V4 `PoolManager`
- A later V4 PoolManager (migration, app-specific singleton)
- A **compatible** DEX that copies the V4 manager layout (same `StateLibrary.getSlot0`)

Binding PoolManager in a constructor on a single CREATE3 implementation freezes “the” manager for that bytecode. Deploying another oracle for a second manager would mean another implementation deploy and a fork of wiring.

Crane already solves this: **one package, many proxies**. `PkgArgs` carries the manager. `calcSalt` makes the instance address a function of that manager. A second compatible manager is another `deploy` call, not a new product.

A DEX that is **not** StateLibrary-compatible is a **sibling package** (same ring facets if practical, different reader repo). The instance model is what makes that a second package rather than a messy constructor flag.

### 1.3 Product requirement (one sentence)

Ship a Crane DFPkg that deploys an unowned diamond instance per `PkgArgs.poolManager`; that instance is a permissionless truncated poke TWAP for every pool on that manager. IndexedEx architecture deploys the instance for the canonical Uniswap V4 PoolManager and freezes it on the Uni V4 SE **package** (`PkgInit`), so every SE vault proxy pokes that same instance. Morpho/Aggregator adapters freeze one instance and fail closed on stale writes.

---

## 2. Goals

1. **DFPkg instances:** Facets + package CREATE3 once. Each `deploy(PkgArgs)` returns a diamond bound to **that** `poolManager`.
2. **Hook-independent:** Record TWAP for any initialized pool on the bound manager, including pons, IndexedEx, Bunni, or `hooks = 0`.
3. **One instance, many pools:** `PoolId`-keyed rings **on that instance**. Several integrations share it. Another manager gets another instance.
4. **Permissionless write:** Primary: `update(PoolKey)` by anyone (one pool, one poke). At most one write per pool per block **per instance**. Optional: `update(PoolKey[])` for external keepers who want one tx over many pools. SE never batches.
5. **Truncated geomean:** V3-style tick cumulative, clamp 9116 ticks.
6. **Consumer-chosen window:** `observe` on the instance. Adapters freeze one window.
7. **Freshness as a consumer policy:** Instance `observe` stays raw. Adapters **must** enforce `maxWriteAge`.
8. **Morpho-ready:** Immutable **per-pool** adapters. Each adapter freezes one oracle instance + one `PoolKey` + window + direction + freshness, then exposes Morpho `IOracle.price()` with **no arguments**. AggregatorV3 is the same idea for `MorphoChainlinkOracleV2`.
9. **SE vault writer:** IndexedEx architecture deploys the canonical TWAP instance, then the Uni V4 SE **DFPkg** holds that instance as a `PkgInit` immutable and writes it into every new SE vault. **After** a successful **market-moving** SE entry, the vault fail-open pokes its **bound pool** only. Vault `PkgArgs` does **not** choose the oracle or extra keys.
10. **Frozen instance trust:** After `postDeploy`, the instance is **unowned** (no `diamondCut`, no `setPoolManager`). New math = **new package version** + new instances. New manager = same package, new instance.
11. **Production-first tests:** Real PoolManager. Real DFPkg deploy path. Two managers → two instances. No `new` facet/package/instance as SUT. `via_ir` forbidden.

### 2.1 Non-goals (v1)

1. Making this a Uniswap V4 hook, or changing pons / IndexedEx hook flags.
2. An owner-upgradeable oracle instance, operator pool allowlist, or `setPoolManager` after deploy.
3. A single global CREATE3 implementation with PoolManager in the constructor (v1.0 mistake; superseded).
4. Registering instances as **vaults** (`deployVault` / vault-registry vault records). This is an oracle package, not a vault product.
5. Seconds-per-liquidity / TWAL.
6. Using this feed for DETF **mint/burn/expansion gates**.
7. Reviving the deleted listing-family DETF.
8. Chainlink / Pyth / Chronicle aggregation inside this contract.
9. One instance spanning two PoolManagers or two chains.
10. Paying keepers from the protocol.
11. Guaranteeing Morpho-grade safety on a thin launch pool.
12. Native ETH as an SE **sleeve** concern. Native as a **pool currency** **is** in scope.
13. Hook-callback writer inside IndexedEx buffer hooks (follow-on).
14. Off-chain indexers as the trust root.
15. A generic “any DEX” reader plugin in v1 `PkgArgs`. Incompatible storage is a **sibling DFPkg**, not a flag.
16. Vault-configured extra poke keys (`PkgArgs.twapExtraPoolKeys`). v1 SE pokes the bound pool only. Foreign pools are permissionless on the instance. Extra keys are a follow-on.

---

## 3. Design decisions (LOCKED for planning)

| ID | Decision | Choice |
|----|----------|--------|
| **D1** | Shape | **DFPkg + diamond instance per `PkgArgs.poolManager`**. Facet-Target-Repo. Adapters are separate monomorphs. Never `new` facets, package, or instance in production. |
| **D2** | Structs | `PkgInit` and `PkgArgs` live on **`IUniswapV4MultiPoolTwapOracleDFPkg`**, not the package contract. |
| **D3** | Binding | `PkgArgs.poolManager` is the only manager binding. Written in `initAccount` / `postDeploy` into an AwareRepo. **No** constructor-bound manager on facets. `address(0)` reverts at `processArgs`. |
| **D4** | Compatibility (v1 reader) | Instance reads `StateLibrary.getSlot0(IPoolManager(poolManager), poolId)`. **Compatible** = Uniswap V4 PoolManager storage layout. A second V4-compatible DEX manager uses **this package** with a different `PkgArgs.poolManager`. |
| **D5** | Incompatible DEX | **New sibling DFPkg** (new reader repo). Do not add a reader enum/strategy to v1 `PkgArgs`. |
| **D6** | Instance salt | `calcSalt(pkgArgs) = keccak256(abi.encode(pkgArgs.poolManager))` (plus package identity as the factory already namespaces by package). Same package + same manager → same predicted address. |
| **D7** | Duplicate deploy | Package helper `deployOracle(args)` is **permissionless**. If `calcAddress` already has code, **return existing** instance. Do not revert the happy retry. |
| **D8** | Instance ownership | `postDeploy` **unowns** / renounces diamond owner so production instances cannot `diamondCut` or retarget the manager. Flawed instance → abandon; deploy another. |
| **D9** | Not a vault | Do **not** register the TWAP DFPkg or instances on the vault registry. Do **not** use `indexedexManager.deployVault` for oracles. Deploy: CREATE3 facets/package, then `pkg.deployOracle(PkgArgs)` via the package’s immutable `DiamondPackageCallBackFactory`. |
| **D10** | Pool set | **Permissionless** on each instance. First successful `update` for a `PoolId` initializes that instance’s ring. No allowlist. |
| **D11** | Missing / uninitialized pool | `update` **does not revert**. If `sqrtPriceX96 == 0` (pool not created or not initialized): **do not write** the ring; return `written = false`. `observe` / `consult` / adapter `price()` treat that pool as **price 0**. Do **not** record Uniswap **tick 0** (that is a 1:1 price, not zero). |
| **D12** | Key in / id out | **Primary poke** is `update(PoolKey)` — the full V4 key `(currency0, currency1, fee, tickSpacing, hooks)`, not a bare `bytes32`. The instance hashes it to `PoolId`, reads slot0, stores the key on first write. Views (`observe`, `consult`, `getState`, `writeAge`) take `PoolId`. |
| **D13** | Write cadence | At most **one observation per pool per block per instance**. Second `update` in the same block returns `written = false` and does not revert. |
| **D14** | Accumulator | `tickCumulative += int56(recordedTick) * int56(delta)`. **No** liquidity cumulative in v1. |
| **D15** | Truncation | **On**, package-wide, immutable. `MAX_ABS_TICK_MOVE = 9116`. Clamp vs `prevTick` on `update` and observe interpolation. |
| **D16** | Observe interpolation | View `observe` interpolates the tail using current slot0 tick, **then truncated** vs `prevTick`. |
| **D17** | Ring storage | `mapping(PoolId => mapping(uint16 => Observation))` plus per-pool `ObservationState`. **Do not** allocate `Observation[65535]` per pool. |
| **D18** | Cardinality | Start **1** on first real write. Permissionless `increaseCardinalityNext`, **including before first write** (D45). Max 65535. |
| **D19** | Window | Instance does **not** freeze a TWAP length. Adapters freeze one `secondsAgo > 0`. |
| **D20** | Freshness | Instance `observe` does **not** revert on old writes. Adapters: if the pool has **never had a real write** (uninitialized / missing), `price()` returns **0** and does **not** apply `maxWriteAge`. After the first real write, adapters **must** revert `StaleObservation` if write age `> maxWriteAge`. `maxWriteAge == 0` invalid at adapter deploy. |
| **D21** | Recommended `maxWriteAge` | Document **120–600 seconds** for lending adapters. Example NatSpec **300**. Not an instance constant. |
| **D22** | Unlock | Oracle **never** calls `unlock`. |
| **D23** | Tokens | Instance holds **no tokens**. Token policy applies to adapters used as Morpho/SE underlyings. |
| **D24** | Native currency | **In scope.** `currency0 == address(0)` valid. Native decimals = **18** at adapter create (no `decimals()` call on `address(0)`). |
| **D25** | Adapter target | Adapters take the **instance** address (`IUniswapV4MultiPoolTwapOracle`). They must not take the DFPkg. |
| **D26** | Morpho adapter | One **monomorph per market feed**. Immutable: instance, **one** `PoolKey`, `secondsAgo`, `collateralIsCurrency0`, `maxWriteAge`, **collateral/loan decimals snapshotted at create** (D43). Implements Morpho `IOracle.price()` with **no arguments** — Morpho’s market stores the adapter address and calls `price()`. `price()` never calls `decimals()` and never `update`s. |
| **D27** | AggregatorV3 adapter | Immutable: instance, pool, `secondsAgo`, `invert`, `maxWriteAge`, `decimals() = 18`. Stale revert. Feed for `MorphoChainlinkOracleV2`. No extra caller salt (D42). |
| **D28** | Adapter factory | Shared **CREATE3** factory (once per chain). Permissionless `create*(instance, ...)`. Salt = config hash only (D42). Same config → same address; retry returns existing. **No** extra caller `salt` argument. |
| **D29** | SE oracle wiring | Uni V4 SE **DFPkg** `PkgInit` includes `IUniswapV4MultiPoolTwapOracle twapOracle` (canonical instance for the PoolManager that package serves). Package stores it as an **immutable**. Every new SE vault proxy receives that instance in `initAccount`. SE vault **`PkgArgs` does not** take `twapOracle`. SE package construct reverts if `twapOracle == address(0)` **or** `twapOracle.poolManager() != pkgInit.poolManager`. |
| **D30** | SE poke failure | **Fail-open** `try/catch` on `update`. Emit `TwapOracleUpdateFailed`. Do not brick the vault. |
| **D31** | SE poke set | **After** a successful **market-moving** SE entry (D41), fail-open poke of the **bound pool** only. No `PkgArgs.twapExtraPoolKeys` in v1 (D44). ERC-20 `transfer` / `approve` / `permit` and previews do **not** poke. |
| **D39** | SE manager match | Architecture deploys the TWAP instance for the canonical Uniswap V4 PoolManager **before** constructing the Uni V4 SE DFPkg, and passes that instance in SE `PkgInit`. Construct-time check: `twapOracle.poolManager() == pkgInit.poolManager`. At SE `deployVault` / `processArgs`, **revert** if `twapOracle.poolManager() !=` the vault’s PoolManager (same package immutable). A second compatible manager needs a **second SE DFPkg** whose `PkgInit` holds the other TWAP instance. |
| **D32** | DETF gates | **Forbidden consumer** for mint/burn/expansion. |
| **D33** | Testing | Production-first. SUT = DFPkg-deployed instance + adapters + SE wiring. Real PoolManager. No `vm.mockCall` on SUT. |
| **D34** | Role names | `currency0` / `currency1` on the oracle; adapter `collateral` / `loan` only on Morpho adapter. |
| **D35** | Reentrancy | `update` only reads slot0 and writes own storage. No `nonReentrant` in v1. |
| **D36** | Batch update | **Not the primary path.** Optional `update(PoolKey[] keys)` for external keepers / liquidators who want one tx over many pools. Per-key same as `update(PoolKey)`. Missing/uninitialized keys return `false` and **do not** revert the batch. A hard revert on one key still reverts the batch. **SE never calls the batch.** SE fail-open is `try/catch` around **one** `update(boundKey)`. |
| **D40** | Zero vs tick 0 | “Price 0” means Morpho/Aggregator **numeric 0** (no borrowable collateral). It is **not** `tick = 0`. Never `write` a synthetic min-tick or tick 0 to stand in for a missing pool. |
| **D37** | Consult | `consult(poolId, secondsAgo) → int24`. Revert if `secondsAgo == 0`. V3 toward-zero division. |
| **D38** | Loupe / J | Instance is a Diamond: **J1–J3 required** (`facetFuncs` ⊆ cuts ⊆ proxy loupe + callable). |
| **D41** | SE poke timing | Poke runs **after** the user op succeeds (post-trade tick if this vault is the first writer in the block). If the user op reverts, the poke does not persist. |
| **D42** | Adapter salt | CREATE3 salt = `keccak256(abi.encode(instance, key, secondsAgo, direction, maxWriteAge))` where `direction` is `collateralIsCurrency0` (Morpho) or `invert` (AggregatorV3). Factory namespaces Morpho vs Aggregator by create function / init code. No extra caller salt. |
| **D43** | Adapter decimals | Snapshot `IERC20Metadata.decimals()` at adapter **create**. `address(0)` → **18** without a call. Missing/reverting `decimals` → `DecimalsQueryFailed` at create. Morpho `price()` is wei/wei × 1e36 and does **not** re-apply those decimals (Uniswap ticks are already wei). `price()` / `latestRoundData` never call `decimals()`. |
| **D44** | No extra keys (v1) | Uni V4 SE vault `PkgArgs` stays `{ poolKey, widthMultiplier }`. **Do not** add `twapExtraPoolKeys`. Foreign pools: permissionless `update` on the instance. |
| **D45** | Cardinality pre-grow | `increaseCardinalityNext` on a **never-written** `PoolId` is allowed. Stores `cardinalityNext` only. **Does not** write an observation or a fake tick. Default `cardinalityNext` before any grow is **1** (what first write would set). `next <= current cardinalityNext` reverts `CardinalityNextTooLow`. First successful `update` writes slot 0 with `cardinality = 1` and **keeps** the stored `cardinalityNext`. Observe/consult still return price 0 until that first real write. |
| **D46** | Primary poke | The product write is **one** `update(PoolKey)`. That is what SE vaults, keepers, and liquidators call. Batch exists only so an external updater can loop many keys in one tx. Do not design SE, adapters, or tests around batch as the happy path. |

---

## 4. Package surface (normative)

`PkgInit` and `PkgArgs` **must** be on the interface.

```solidity
interface IUniswapV4MultiPoolTwapOracleDFPkg is IDiamondFactoryPackage {
    struct PkgInit {
        IFacet twapOracleFacet; // split query/write facets if stack/size needs it
        IDiamondPackageCallBackFactory diamondFactory;
    }

    struct PkgArgs {
        address poolManager; // Uniswap V4-compatible PoolManager (D4)
    }

    function deployOracle(PkgArgs calldata args)
        external
        returns (IUniswapV4MultiPoolTwapOracle oracle);
}
```

`processArgs` / `initAccount`:

1. Revert `ZeroPoolManager` if `poolManager == address(0)`.
2. Bind AwareRepo `_poolManager = IPoolManager(args.poolManager)`.
3. Do **not** call `unlock` or write observations at init.

`postDeploy(account)`:

1. Confirm `IUniswapV4MultiPoolTwapOracle(account).poolManager() == args.poolManager`.
2. **Unown** the diamond (no remaining owner / no live `diamondCut` from a product owner).
3. Do not deploy adapters here.

`deployOracle`:

1. `predicted = diamondFactory.calcAddress(this, abi.encode(args))`.
2. If `predicted.code.length > 0`, return `IUniswapV4MultiPoolTwapOracle(predicted)`.
3. Else `diamondFactory.deploy(this, abi.encode(args))`.

FactoryService deploys **facets + package** via CREATE3 (`PkgInit`). It does **not** bake a PoolManager into the package. Instances are created later, including in tests and launch stages, with the manager for that environment.

```text
CREATE3 facets + DFPkg          (once)
        │
        ├─ deployOracle({ poolManager: Uniswap V4 PM })
        │       → instance A  (all pools on that PM)
        ├─ deployOracle({ poolManager: other V4-compatible PM })
        │       → instance B
        └─ sibling DFPkg (future, different reader)
                → instance C for an incompatible DEX
```

---

## 5. Why poke rather than a hook

```text
V4-compatible PoolManager  (Uniswap V4 or storage-compatible fork)
    │  getSlot0
    ▼
TWAP oracle instance (diamond, PkgArgs.poolManager)
    │  permissionless update
    │  Uni V4 SE vault ops (fail-open)
    │  keepers / liquidators / routers
    ├── observe / consult
    ├── Morpho IOracle adapter  → that instance
    └── AggregatorV3 adapter    → that instance
```

A hook oracle would be a different `PoolKey`. This PRD refuses that.

Poke security is **write cadence + truncation + adapter maxWriteAge**. See §10.

---

## 6. Behavioral specification

### 6.1 Instance: `IUniswapV4MultiPoolTwapOracle`

`poolManager()` returns the AwareRepo value from `PkgArgs` (immutable for the life of the instance).

#### `update(PoolKey calldata key) → bool written`

**Primary poke.** Pass one V4 `PoolKey`. The instance hashes it to `PoolId`, reads slot0, writes at most one ring slot. Callers do not pass a window, direction, or price.

1. `id = key.toId()`.
2. `(sqrtPriceX96, tick, ,) = StateLibrary.getSlot0(poolManager, id)`.
3. If `sqrtPriceX96 == 0` (missing or uninitialized pool): **do not write**. Return `false`. No event.
4. If no real observation yet: initialize observation `[0]` at `block.timestamp` with `tickCumulative = 0`, `prevTick = tick` (no truncation; no previous recorded tick), `cardinality = 1`, `cardinalityNext = max(1, stored cardinalityNext)` (D45: keep a pre-grow), store `key`. Return `true`.
5. If last observation timestamp `== uint32(block.timestamp)`: return `false`.
6. Truncate `tick` vs `state.prevTick` into `[prevTick - 9116, prevTick + 9116]`.
7. Write next ring slot; emit `ObservationWritten`.
8. Return `true`.

`uint32` timestamps: same 2106 issue as V3. Accept.

#### `update(PoolKey[] calldata keys) → bool[] written`

**Optional keeper helper, not the primary path** (D36, D46). Same per-key rules as `update(PoolKey)`. Missing pools return `false` and continue. A hard revert on one key still reverts the batch. SE vaults **must not** call this.

#### `increaseCardinalityNext(PoolId id, uint16 next)`

Permissionless. V3 grow target (`next` must be greater than current `cardinalityNext`; cap 65535) **except** V3’s “must already be initialized” gate: a never-written `PoolId` may pre-grow (D45).

1. Current `cardinalityNext` is **1** if the pool has never been grown and never written, else the stored value.
2. If `next <= current` or `next == 0`: revert `CardinalityNextTooLow`.
3. If `next > 65535`: revert (same cap as V3).
4. Store `cardinalityNext = next`. **Do not** write an observation, tick 0, or `tickCumulative`.
5. Emit `CardinalityNextIncreased`.
6. Observe/consult/adapters still treat the pool as **never written** (price 0) until the first real `update`.

Mapping storage (D17): do **not** pre-touch 65535 slots the way V3 `grow` writes `blockTimestamp = 1`. Cardinality grows on later writes when `index == cardinality - 1` (V3 `write` bump to `cardinalityNext`).

#### `observe(PoolId id, uint32[] secondsAgos) → int56[] tickCumulatives` / `consult`

V3-shaped `observe`. **No** seconds-per-liquidity return. Interpolates the tail with truncated current slot0 tick (D16).

If the pool has **never had a real write** (never initialized on the manager, only skipped updates, or **only pre-grown**): `observe` returns **zero** `tickCumulatives`; `consult` returns **0**. Do **not** revert `UnknownPool` / `PoolNotInitialized`.

If a real ring exists: window older than oldest still reverts `TargetPredatesOldestObservation`; tail interpolated with truncated **current** slot0 tick; `consult` forbids `secondsAgo == 0`. If slot0 is zero **after** a real write (should not happen on V4), interpolate as price 0 for the tail only; do not rewrite history.

**No** write-age revert on the instance.

#### Views

| View | Returns |
|------|---------|
| `poolManager()` | Bound manager from `PkgArgs` |
| `MAX_ABS_TICK_MOVE()` | `9116` |
| `getPoolKey(PoolId)` | Stored key |
| `getState(PoolId)` | index, cardinality, cardinalityNext, prevTick, lastTimestamp |
| `getObservation(PoolId, uint16 index)` | Observation |
| `writeAge(PoolId)` | `block.timestamp - lastTimestamp` (0 if unknown) |

### 6.2 Truncation

```text
recordedTick = currentTick
if recordedTick > prevTick + 9116: recordedTick = prevTick + 9116
if recordedTick < prevTick - 9116: recordedTick = prevTick - 9116
```

Apply on `update` and observe-time tail interpolation.

### 6.3 Morpho `IOracle` adapter

Morpho Blue’s oracle interface is **unargumented**:

```solidity
function price() external view returns (uint256);
```

A Morpho market stores **one** oracle address and calls `price()` with no pool, no window, no tokens. So this adapter is a **small frozen contract per feed**: one TWAP **instance** + one `PoolKey` + one lookback + one collateral/loan direction + one `maxWriteAge`. Deploying it does **not** poke. Morpho never talks to the multi-pool diamond.

A second pool, a second window, or the inverted pair is a **different adapter** (different CREATE3 address).

| Arg | Rule |
|-----|------|
| `oracle` | **Instance** (`IUniswapV4MultiPoolTwapOracle`) |
| `key` | **One** PoolKey on **that** instance’s manager |
| `secondsAgo` | `> 0` |
| `collateralIsCurrency0` | Collateral vs loan currency |
| `maxWriteAge` | `> 0` |
| Decimals | Snapshotted at create (D43). Native `address(0)` = 18. |

`price()` is **view**:

1. If the instance has **no real write** for this pool: return **0**. Skip `maxWriteAge`.
2. Else if `writeAge > maxWriteAge`: revert `StaleObservation`.
3. Else `consult` → arithmetic-mean tick. If `collateralIsCurrency0 == false`, quote `currency1` as collateral vs `currency0` as loan (token direction in `getQuoteAtTick`; do **not** also negate the tick).
4. Morpho 1e36 is **wei/wei** (`loan_wei = coll_wei * price / 1e36`, Morpho `IOracle` NatSpec). Uniswap ticks are already wei/wei, so `price = getQuoteAtTick(tick, 1e18, collateral, loan) * 1e18`. Tick 0 → `1e36` for **any** decimal pair (H10, H19). Do **not** apply `10^(36 + loanDecimals - collDecimals)` on top of the tick (that is Chainlink human scale). Uncovered window after a real write reverts (`TargetPredatesOldestObservation` or adapter wrap). `consult == 0` is **not** “never written.”

Do **not** `update` inside `price()`. Liquidators poke the instance first in the same tx. Adapter must revert if `oracle.poolManager()` is zero (miswired). `price()` must **not** call `decimals()`.

### 6.4 AggregatorV3 adapter

Same window. Feed `decimals() = 18` (not token decimals). `invert` selects currency direction. Token decimals are **not** applied here; `MorphoChainlinkOracleV2` takes `baseTokenDecimals` / `quoteTokenDecimals` separately.

No real write: `latestAnswer = 0`, `updatedAt = 0` (**LOCKED** so consumers can see “never”). `latestRoundData` → `(0, 0, 0, 0, 0)`.

After a real write: `updatedAt` = last write timestamp; `latestRoundData` → `(1, answer, updatedAt, updatedAt, 1)` (`roundId` does not increment per poke; this feed is a consult, not Chainlink rounds). Stale / uncovered window reverts. `getRoundData` is not a historical ring; if implemented, it matches `latestRoundData` only for `roundId == 1` after a real write, else reverts.

### 6.5 Adapter factory

Shared CREATE3 contract, not per instance:

```text
createMorphoOracle(oracleInstance, key, secondsAgo, collateralIsCurrency0, maxWriteAge)
createAggregatorV3(oracleInstance, key, secondsAgo, invert, maxWriteAge)
```

**No** extra caller `salt`. CREATE3 salt = config hash (D42). Config includes **instance address**. Same pool on instance A vs instance B are different adapters.

Retry returns existing adapter. Decimals snapshot and `DecimalsQueryFailed` happen at create (D43).

### 6.6 Uni V4 SE vault writer (architecture)

IndexedEx bootstrap order:

1. CREATE3 TWAP facets + DFPkg.
2. `twapPkg.deployOracle({ poolManager: canonicalUniswapV4PoolManager })` → **canonical instance**.
3. CREATE3 Uni V4 SE DFPkg with `PkgInit.twapOracle = canonical instance` (immutable on the package).
4. Every `SE.deployVault(...)` copies that immutable onto the vault diamond.

On **every successful market-moving** SE entry (zap-in, zap-out, direct swap, rebalance, successful position import, `rebalanceLiquidReserve`), **after** the user op (and tail-rebalance when that op runs one) completes:

```text
twapOracle.update(boundKey)   // single-pool poke; never update(PoolKey[])
```

That call is **external** (the package-wired instance) so `try/catch` works. Catch all reverts; emit `TwapOracleUpdateFailed`; do not revert the SE op. `written = false` (same-block skip, missing pool) is **not** a revert and does **not** emit `TwapOracleUpdateFailed`.

Poke **also when interaction-blocked** (sleeve path). `update` does not need PoolManager unlock. Previews **do not** poke. ERC-20 `transfer` / `approve` / `permit` **do not** poke.

SE DFPkg constructor **reverts** if `twapOracle == address(0)` or `twapOracle.poolManager() != pkgInit.poolManager`. `processArgs` / vault init **reverts** if `twapOracle.poolManager() != vault.poolManager()`. There is no per-vault opt-out and no extra-key list. Foreign pools are poked by keepers / other callers on the same instance.

### 6.7 Keepers

v1 does not ship a keeper network. Writers: anyone calling `update(PoolKey)`; SE side effect on the **bound pool** after market-moving ops; off-chain heartbeat at `maxWriteAge / 2` for **foreign** pools and idle bound pools. Keepers who watch many pools **may** use `update(PoolKey[])` in one tx. Stale adapters freeze Morpho borrow/withdrawCollateral/liquidate until a poke. The adapter `price()` call itself does not poke.

---

## 7. Errors and events (normative intent)

### 7.1 Package / instance errors

| Error | When |
|-------|------|
| `ZeroPoolManager` | `PkgArgs.poolManager == 0` |
| `TargetPredatesOldestObservation(oldest, target)` | Window longer than history **after** a real write exists |
| `CardinalityNextTooLow` | grow target not greater than current `cardinalityNext` (default **1** if never grown) |
| `InvalidSecondsAgo` | consult with 0 |
| `PoolKeyMismatch` | stored key vs id diverges |

### 7.2 Adapter errors

| Error | When |
|-------|------|
| `StaleObservation(age, maxWriteAge)` | Write too old |
| `ZeroMaxWriteAge` / `ZeroSecondsAgo` / `ZeroOracle` | Deploy |
| `DecimalsQueryFailed` | Adapter create: ERC-20 `decimals` missing or reverting. Not used for native `address(0)`. |

### 7.3 Events

| Event | Where |
|-------|-------|
| `ObservationWritten(PoolId id, int24 tick, uint32 timestamp, uint16 index, uint16 cardinality)` | Instance `update` |
| `CardinalityNextIncreased(PoolId id, uint16 old, uint16 new)` | Grow |
| `OracleDeployed(address instance, address poolManager)` | Package `deployOracle` (including return-existing: emit only on actual deploy) |
| `MorphoAdapterCreated(...)` | Adapter factory |
| `AggregatorV3AdapterCreated(...)` | Adapter factory |
| `TwapOracleUpdateFailed(bytes32 poolId, bytes reason)` | SE vault catch |

---

## 8. Surfaces and file impact (expected)

All new production code under `contracts/oracles/uniswap/v4/twap/` unless noted.

| Path (expected) | Role |
|-----------------|------|
| `interfaces/IUniswapV4MultiPoolTwapOracle.sol` | Instance surface; Observation structs |
| `interfaces/IUniswapV4MultiPoolTwapOracleDFPkg.sol` | **`PkgInit` / `PkgArgs` / `deployOracle`** |
| `aware/UniswapV4TwapOraclePoolManagerAwareRepo.sol` | Bound manager (or reuse `UniswapV4PoolManagerAwareRepo` if slot/name fits; do not collide SE vault slots on a shared diamond: **this is a different proxy**, reuse is OK) |
| `libraries/UniswapV4TruncatedTwapOracleLib.sol` | Ring write / observe / truncate. Copy into IX; do not depend on `v4-periphery` `trunc-oracle` branch at runtime |
| `UniswapV4MultiPoolTwapOracleRepo.sol` | Ring storage |
| `UniswapV4MultiPoolTwapOracleTarget.sol` | Logic |
| `UniswapV4MultiPoolTwapOracleFacet.sol` | `IFacet`; **every** Target selector in `facetFuncs` (J) |
| `UniswapV4MultiPoolTwapOracleDFPkg.sol` | Package |
| `UniswapV4TwapMorphoOracle.sol` | Morpho `IOracle` monomorph |
| `UniswapV4TwapAggregatorV3Adapter.sol` | AggregatorV3 monomorph |
| `UniswapV4TwapAdapterFactory.sol` | Shared adapter **CREATE3** factory (config-hash salt, D42) |
| `UniswapV4TwapOracleFactoryService.sol` | CREATE3 facets + DFPkg + adapter factory; `vm.label` |
| Uni V4 SE DFPkg `PkgInit.twapOracle` + vault poke helper (bound pool only, after market ops) | D29–D31, D39, D41, D44 |
| `contracts/test/bases/TestBase_UniswapV4MultiPoolTwapOracle.sol` | Gold TestBase (deploys package, then instance) |
| `test/foundry/spec/oracles/uniswap/v4/twap/` | Hermetic + adversarial |
| `test/foundry/fork/**/oracles/` | Optional 4663 fork |

**Not** a hook DFPkg. Skill `indexedex-uniswap-v4-hook-packages` does not apply except as a negative.

**Not** `indexedexManager.deployVault`. Package registry auto-population via Create3Factory is enough for discovery of the **package**. Instance addresses come from `deployOracle` / `calcAddress`.

---

## 9. Deploy path (normative)

```text
CraneTest / launch script / IndexedEx architecture
  FactoryService CREATE3
    → twapOracleFacet
    → UniswapV4MultiPoolTwapOracleDFPkg(PkgInit { facet, diamondFactory })
    → UniswapV4TwapAdapterFactory
  twapPkg.deployOracle({ poolManager: canonicalV4PM })  → instance A   // permissionless; idempotent
  FactoryService CREATE3 Uni V4 SE DFPkg
    PkgInit { ..., twapOracle: instance A }              // immutable on SE package
  SE.deployVault(vaultPkgArgs)                           // copies instance A onto every vault
  adapterFactory.createMorphoOracle(instanceA, ...)
  // later, another compatible PM:
  twapPkg.deployOracle({ poolManager: pmB })             → instance B
  // new SE package deploy with PkgInit.twapOracle = instance B if vaults should live on pmB
```

Never `new` facet, DFPkg, or instance on the production path.

`via_ir` forbidden. Stack: structs (crane-code-style). NatSpec: Crane LR-1 / central values when implemented.

---

## 10. Security and economic considerations

### 10.1 AMM TWAP

Manipulation cost scales with depth × time × truncation × poke frequency. Thin pons pools are not Chainlink. LLTV is the Morpho control.

### 10.2 Poke-gap interpolation (P0)

Same as v1.0: adapters must `maxWriteAge`; permissionless poke; keepers / heartbeat for **foreign** pools (SE does not poke extras in v1); grow cardinality before relying on a window (pre-grow allowed, D45).

### 10.3 Same-transaction dump

Dump, poke, consume `price()`: truncation vs `prevTick`. Tests must include this path.

### 10.4 Two instances

Observations on instance A **must not** appear on instance B. A Morpho adapter pointed at A cannot be “fixed” by poking B. Tests: two managers, two instances, isolated rings.

### 10.5 Abandoned owner / diamondCut (J + CROPS)

If `postDeploy` leaves an owner, that owner can cut in a lying `observe`. **D8** forbids that. Tests: after deploy, `owner() == 0` (or equivalent unowned predicate); `diamondCut` reverts.

A bug in ring math is a **new package version** and new instances. Morpho markets on the old adapter stay on the old instance.

### 10.6 Cardinality / unbounded pools / stale Morpho / SE fail-open / decimals

Unchanged from v1.0 (per-instance cardinality grief cannot affect another instance).

### 10.7 Compatible-manager footgun

Passing a random ERC-20 as `poolManager` will extSLOAD zeros or revert. `processArgs` only checks non-zero. A junk manager with zero slot0 looks like “missing pool”: pokes no-op, reads return price 0. Do not add an ERC-165 allowlist in v1.

### 10.8 Donation / A0 / I1

N/A on instance (no inventory). Deferred in suite NatSpec. **J1–J3 apply.**

### 10.9 DETF / L3

Mint/burn must not read this oracle (D32).

---

## 11. Testing requirements (DoD for implementation plan)

Gold path: `CraneTest` → `IndexedexTest` → `TestBase_UniswapV4MultiPoolTwapOracle`. FactoryService deploys package; TestBase calls `deployOracle` against a **real** Crane-ported PoolManager.

### 11.1 Hermetic matrix

| ID | Case |
|----|------|
| H1–H7 | First real update, time-warp consult, same-block skip, truncation, oldest-window revert after a real write, cardinality grow **including pre-grow then first write** (D45), native currency |
| H8 | `observe` / `consult` / Morpho `price()` on a never-written pool return **0**, do not revert — including after pre-grow with no `update` |
| H9 | `update` of an uninitialized pool returns `false`, writes nothing, does not revert |
| H10–H13 | Morpho 1e36 at tick 0 (18/18); inverted collateral; stale revert; adapter factory idempotent (**instance** + config hash, **no** extra salt) |
| H14–H16 | SE package `PkgInit` wires instance; vault zap pokes **bound pool after** the user op; poke revert fail-open |
| H17 | SE zap / rebalance does **not** poke a second `PoolKey`; ERC-20 `transfer` / `approve` do **not** poke; a keeper `update` of a foreign pool on the same instance still writes |
| H18 | `update` during outer `unlock` succeeds |
| H19 | Non-18 decimals Morpho scale from **create-time snapshot**; native `address(0)` = 18; missing `decimals` reverts `DecimalsQueryFailed` at adapter create |
| H20 | No `new` facet/DFPkg/instance on TestBase happy path |
| H21 | **Two PoolManagers → two instances**; poke A does not write B |
| H22 | `deployOracle` twice with same `PkgArgs` returns the **same** address |
| H23 | `PkgArgs.poolManager = 0` reverts `ZeroPoolManager` |
| H24 | After deploy, instance is unowned; `diamondCut` reverts |
| H25 | `Behavior_IFacet` + `Behavior_IDiamondFactoryPackage` declaration tests |
| H26 | J1–J3: Target selectors ⊆ facetFuncs ⊆ cuts ⊆ proxy loupe + callable `update`/`observe`/`consult`/`poolManager` |
| H27 | Every vault from the SE package: `vault.twapOracle() == pkgInit.twapOracle` and `twapOracle.poolManager() == vault.poolManager()` |
| H28 | `deployVault` reverts if vault PoolManager ≠ `twapOracle.poolManager()` |
| H29 | SE DFPkg `PkgInit.twapOracle == address(0)` **or** `twapOracle.poolManager() != pkgInit.poolManager` reverts at construct |
| H30 | `deployOracle` from an arbitrary EOA succeeds (permissionless) |
| H31 | `increaseCardinalityNext` on a never-written pool stores `cardinalityNext` and does not create a real write (consult still 0) |
| H32 | Adapter `create*` twice with the same config returns the same address; different instance or `secondsAgo` is a different adapter |

### 11.2 Adversarial / abuse

| ID | Case |
|----|------|
| Adv-gap / poke-then-read / multi-block / card-1 / wrong-dir | Same as v1.0 on an instance |
| Adv-cross-instance | Adapter on A, dump+poke B only: A still stale or unchanged, not B’s tick |
| L2 | N/A on instance. FoT still forbidden if wired as IX underlying. |
| A0/I1/E6 | Deferred (no inventory). |
| J1–J3 | **Required** (D38). |
| F1 | Instance unowned after `postDeploy`. |

### 11.3 Fork

Optional 4663: `deployOracle` against live PoolManager (or bind an already deployed instance), poke a pons v2 pool, consult vs spot directionally.

### 11.4 Out of test scope (v1)

Keeper bots, UI, Morpho mainnet listing, DETF threshold wiring, sibling package for incompatible DEX, vault extra poke keys.

---

## 12. Implementation sketch (not a substitute for the coding plan)

Normative coding plan: [`UNISWAP_V4_MULTI_POOL_TWAP_ORACLE_IMPLEMENTATION_AND_TEST_PLAN.md`](./UNISWAP_V4_MULTI_POOL_TWAP_ORACLE_IMPLEMENTATION_AND_TEST_PLAN.md).

1. Interface + Repo/Target/Facet + DFPkg + TestBase: H20–H26, H23–H24, then H1–H9, H18, H31.
2. Adapters + shared factory: H10–H13, H19, H32, Adv-*.
3. Uni V4 SE DFPkg `PkgInit` + vault poke: H14–H17, H27–H29. Same implementation pass as the oracle package.
4. FactoryService + 46630 launch **Phase 05 Stage 02** (`Phase_05_Stage_02_UniswapV4TwapOracle`) for the canonical instance, then Phase 05 Stage 03 Uni V4 SE `PkgInit.twapOracle`.
5. Follow-on: buffer-hook writer; sibling DFPkg for non-V4 readers; heartbeat runbook.

---

## 13. Open questions

### Locked (this PRD)

- Shape: **DFPkg, instance per `PkgArgs.poolManager`** (D1–D9). v1.0 constructor singleton is **void**.
- Hook vs poke: **poke**.
- Instance upgrade: **none** (unowned after deploy).
- Truncation: **on, 9116**.
- Adapter freshness: **required maxWriteAge**.
- SE poke: **yes, fail-open**; **after** market-moving ops; **bound pool only**; oracle instance is **SE package `PkgInit` immutable**, not vault `PkgArgs` (D29, D31, D39, D41, D44).
- `deployOracle`: **permissionless** (D7).
- TWAP package: **not** vault-registry (D9).
- DETF mint/burn: **must not use this**.
- Native pool currency: **in scope**; adapter native decimals **18** at create (D24, D43).
- Incompatible DEX: **sibling package**, not a v1 `PkgArgs` reader plugin.
- Adapter factory: **CREATE3**, config-hash salt, **no** extra caller salt (D28, D42).
- Morpho decimals: **snapshot at adapter create** (D43).
- Extra poke keys: **out of v1** (D44).
- Cardinality pre-grow: **allowed** (D45).
- Primary poke: **one** `update(PoolKey)`. Batch is optional keeper sugar; SE never batches (D36, D46).
- Morpho adapter: **one frozen monomorph per feed**; Morpho calls argument-free `price()` (D26).

### Still open (do not block v1 design)

| Q | Note | Default if unspecified at impl |
|---|------|--------------------------------|
| Q1 | Example `maxWriteAge` in NatSpec | **300 seconds** |
| Q2 | Buffer-hook writer | Out of v1 |
| Q3 | Heartbeat keeper script | Ops follow-on |
| Q5 | Whether to split query vs write facets | One facet until size forces a split |
| Q6 | Vault extra poke keys | Out of v1 (D44). Follow-on if a vault must poke foreign pools itself. |

---

## 14. Acceptance criteria (product)

1. CREATE3 package deploys an unowned diamond instance from `PkgArgs.poolManager` without being any pool’s hook.
2. A second compatible PoolManager yields a **second instance** from the **same** package; rings do not mix.
3. Same `PkgArgs` retry returns the existing instance.
4. Anyone can `update` on an instance. Same-block duplicate is a no-op.
5. `observe` / `consult` match accumulator + truncation + interpolation rules.
6. Morpho `IOracle` and AggregatorV3 adapters bind an **instance** and revert when stale or when history cannot cover the window.
7. Canonical TWAP instance is frozen on the Uni V4 SE **package**; every SE vault pokes its **bound pool after** a successful market-moving op and **does not revert** if poke fails. ERC-20 plumbing does not poke. Vault deploy reverts on PoolManager mismatch.
8. Pons-style foreign pools can be tracked by poking their `PoolKey` on the instance bound to that pool’s manager.
9. No DETF threshold code path reads this oracle.
10. Hermetic DoD in §11 green on the DFPkg deploy path, including J1–J3 and unowned-after-deploy.

---

## 15. Summary

Uniswap V4 has no built-in TWAP, and hook oracles cannot sit on pons or IndexedEx SE buffer pools. IndexedEx ships this as a **Crane package**: facets once, a diamond **instance per PoolManager** from `PkgArgs` (permissionless `deployOracle`), permissionless truncated poke rings (**one** `update(PoolKey)` is the write; batch is optional keeper sugar), and frozen Morpho/Aggregator adapters (CREATE3 from config, decimals snapshotted at create) that fail closed on stale writes. Each Morpho adapter is one contract bound to one pool so Morpho can call argument-free `price()`. Architecture deploys the instance for the canonical Uniswap V4 PoolManager and sets it as an immutable on the Uni V4 SE **package**, so every SE vault proxy fail-open pokes its **bound pool after** market-moving ops and cannot be pointed at the wrong manager. Foreign pools are poked on the same instance by keepers, not by vault extra keys. A new compatible manager is another `deployOracle` plus a matching SE package `PkgInit`. A non-compatible DEX is a sibling package, not a flag on this one.

---

## Changelog

| Version | Date | Notes |
|---------|------|-------|
| v1.0 | 2026-08-24 | Initial product law. Poke “singleton” implementation, truncation, adapters, SE fail-open writer. |
| v1.1 | 2026-08-24 | **Supersedes v1.0 deploy shape.** DFPkg + diamond instance per `PkgArgs.poolManager`. Constructor singleton void. Compatible V4 managers share this package; incompatible DEX = sibling package. Instances unowned after `postDeploy`. J1–J3 required. |
| v1.2 | 2026-08-24 | **SE wiring.** Canonical instance is architecture-deployed and frozen on Uni V4 SE **DFPkg `PkgInit`**, copied to every SE vault. No per-vault `twapOracle` arg. `deployOracle` permissionless. Not vault-registry. Vault deploy reverts on PoolManager mismatch. Same implementation pass as adapters + SE poke. |
| v1.3 | 2026-08-24 | Missing/uninitialized pool: poke no-ops (`written = false`); reads return **price 0**. Do not write tick 0. `maxWriteAge` applies only after the first real write. |
| v1.4 | 2026-08-24 | Locked planning answers: SE poke **after** market-moving ops, bound pool only (no extra keys); adapter CREATE3 **config-hash salt** (no extra salt); Morpho decimals **snapshotted at create** (native = 18); `increaseCardinalityNext` **pre-grow** without a fake tick. |
| v1.5 | 2026-08-24 | Primary poke is **one** `update(PoolKey)`. Batch is optional keeper sugar, not the SE path (D46). Morpho adapter is one frozen contract per pool/window/direction so Morpho can call argument-free `IOracle.price()`. |
