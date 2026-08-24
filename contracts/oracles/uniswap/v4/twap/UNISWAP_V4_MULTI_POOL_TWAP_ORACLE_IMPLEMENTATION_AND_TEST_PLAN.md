# Implementation & Test Plan: Uniswap V4 multi-pool TWAP oracle

**Status:** Ready for coding (product law frozen)  
**Date:** 2026-08-24  
**Product law (normative):** [`UNISWAP_V4_MULTI_POOL_TWAP_ORACLE_PRD.md`](./UNISWAP_V4_MULTI_POOL_TWAP_ORACLE_PRD.md) (**v1.5**, D1–D46)  
**Package path:** `contracts/oracles/uniswap/v4/twap/`  
**SE wiring path:** `contracts/protocols/dexes/uniswap/v4/`

This document is the **coding plan**. Do not re-open locked PRD decisions without a PRD revision. When product text and this plan conflict, **the PRD wins**.

---

## 0. Mission (one sentence)

Ship a Crane DFPkg that deploys an unowned diamond **instance per PoolManager**; that instance is a permissionless truncated poke TWAP (`update(PoolKey)` primary); frozen Morpho/Aggregator adapters bind one pool so Morpho can call argument-free `price()`; Uni V4 SE vaults fail-open poke their **bound pool after** market-moving ops.

---

## 1. Authority & constraints

| Layer | Role |
|-------|------|
| PRD v1.5 | Product law (D1–D46) |
| **This plan** | Phases, files, APIs, algorithms, test matrix, DoD |
| Crane `crane-architecture` / `crane-deployment` / `crane-testing` | Facet-Target-Repo, CREATE3, LR-7, no `new` SUT |
| `indexedex-testing` / `indexedex-adversarial-testing` | Production-first; TWAP is **not** a vault (no `deployVault`); SE wiring **is** vault-registry |
| `crane-adversarial-testing` ship gate | J1–J3 + F1 required; A0/I/E6 N/A on the oracle instance |

### Hard rules (from PRD + repo)

1. **Never** `new` facets, the TWAP DFPkg, or the oracle instance on the production path. CREATE3 + FactoryService. Instances via `pkg.deployOracle(PkgArgs)`.
2. **Never** register the TWAP package/instance as a vault. Do **not** use `indexedexManager.deployVault` for oracles.
3. **Never** mock PoolManager / TWAP instance / adapters / SE vault as SUT. Real Crane-ported `PoolManager`.
4. **`via_ir` forbidden.** Stack: structs.
5. Primary poke is **one** `update(PoolKey)`. SE never calls `update(PoolKey[])`.
6. DETF mint/burn/expansion **must not** read this oracle.
7. Do not make this a Uniswap V4 hook. Do not revive listing DETF.
8. Token policy: FoT forbidden as IX underlying; native `address(0)` decimals = 18 at adapter create.

### Non-blocking leftovers (do not stall coding)

| Q | Default this plan uses |
|---|------------------------|
| Q1 NatSpec `maxWriteAge` example | **300 seconds** |
| Q2 Buffer-hook writer | Out of v1 |
| Q3 Heartbeat keeper | Out of v1 |
| Q5 Query vs write facet split | **One facet** until bytecode forces a split |
| Q6 Vault extra poke keys | Out of v1 (D44) |

---

## 2. Current state (baseline)

| Area | Today | Required after this work |
|------|-------|--------------------------|
| `contracts/oracles/uniswap/v4/twap/` | PRD + this plan only | DFPkg, instance, adapters, factory, TestBase, specs |
| Uni V4 SE `PkgInit` | Facets + fee oracle + registry + Permit2 + PoolManager + PositionManager | **+ `twapOracle` instance** (immutable). Construct reverts if zero or `poolManager()` mismatch |
| SE vault `PkgArgs` | `{ poolKey, widthMultiplier }` | **Unchanged** (no extra keys, no per-vault oracle) |
| SE market-moving ops | No TWAP side effect | After success: `try/catch twapOracle.update(boundKey)` |
| Morpho `IOracle` | No IndexedEx V4 TWAP adapter | Per-pool frozen monomorph, `price()` no args |
| Launch `Stage_03` | Deploys SE DFPkg against canonical PM | Deploy TWAP package + `deployOracle({canonical PM})` **before** SE DFPkg construct |

---

## 3. Target architecture

```text
CREATE3  UniswapV4TwapOracleFactoryService
  ├─ twapOracleFacet
  ├─ UniswapV4MultiPoolTwapOracleDFPkg     (not a vault)
  └─ UniswapV4TwapAdapterFactory

deployOracle({ poolManager: PM })  →  instance (diamond, unowned)
  update(PoolKey)                  →  ring[PoolId]
  observe / consult                →  raw (no freshness)
  update(PoolKey[])                →  optional keeper only

UniswapV4TwapMorphoOracle          →  IOracle.price()          (one pool)
UniswapV4TwapAggregatorV3Adapter   →  latestRoundData()        (one pool)

Uni V4 SE DFPkg PkgInit.twapOracle = instance
  every vault.initAccount copies it
  after market-moving op: update(boundKey) fail-open
```

### 3.1 Module split

| Module | Responsibility |
|--------|----------------|
| **Lib** `UniswapV4TruncatedTwapOracleLib` | Truncate, write, observe interpolation, consult. Copy V3 Oracle math; do **not** depend on `v4-periphery` trunc-oracle at runtime |
| **Repo** `UniswapV4MultiPoolTwapOracleRepo` | Per-`PoolId` ring + `ObservationState` + stored `PoolKey` |
| **AwareRepo** | Bound `IPoolManager` (new ERC1967 slot **or** reuse `UniswapV4PoolManagerAwareRepo` — different proxy, no slot collision with SE) |
| **Target / Facet** | `update`, batch, grow, observe, consult, views. **One facet** (Q5) |
| **DFPkg** | `PkgInit`/`PkgArgs` on **interface**. `deployOracle` idempotent. `postDeploy` unown |
| **Adapters** | Monomorphs. Not diamonds |
| **Adapter factory** | CREATE3-deployed once. Permissionless `create*`. Config-hash salt (D42) |
| **SE Common** | `_pokeBoundPoolTwap()` helper |
| **FactoryService** | CREATE3 facet + DFPkg + adapter factory; `vm.label` |

### 3.2 Instance facets (unowned)

Do **not** cut `DiamondCut` or Ownable onto the TWAP instance. Factory base cuts (ERC165, loupe, ERC8109, post-deploy hook then removed) + **TWAP facet only**.

Unowned predicate (H24 / F1):

- Loupe has no `diamondCut` selector, **or** `diamondCut` reverts as unknown selector.
- No `owner()` that returns a live admin. Prefer no Ownable facet.

`postDeploy(account)`: confirm `poolManager()` matches args; do not deploy adapters here.

---

## 4. File map

All new production under `contracts/oracles/uniswap/v4/twap/` unless noted.

| Path | Role |
|------|------|
| `interfaces/IUniswapV4MultiPoolTwapOracle.sol` | Instance surface, `Observation`, `ObservationState`, errors, events |
| `interfaces/IUniswapV4MultiPoolTwapOracleDFPkg.sol` | **`PkgInit` / `PkgArgs` / `deployOracle`** |
| `aware/UniswapV4TwapOraclePoolManagerAwareRepo.sol` | Bound manager. ERC1967 `DEFAULT_SLOT` form |
| `libraries/UniswapV4TruncatedTwapOracleLib.sol` | Ring math |
| `UniswapV4MultiPoolTwapOracleRepo.sol` | Storage |
| `UniswapV4MultiPoolTwapOracleTarget.sol` | Logic |
| `UniswapV4MultiPoolTwapOracleFacet.sol` | `IFacet`; **every** Target selector in `facetFuncs` (J) |
| `UniswapV4MultiPoolTwapOracleDFPkg.sol` | Package |
| `UniswapV4TwapMorphoOracle.sol` | Morpho `IOracle` monomorph |
| `UniswapV4TwapAggregatorV3Adapter.sol` | AggregatorV3 monomorph |
| `UniswapV4TwapAdapterFactory.sol` | Shared adapter factory |
| `UniswapV4TwapOracleFactoryService.sol` | CREATE3 helpers |
| `contracts/test/bases/TestBase_UniswapV4MultiPoolTwapOracle.sol` | Gold TestBase |
| `test/foundry/spec/oracles/uniswap/v4/twap/` | Hermetic specs |
| `test/foundry/spec/oracles/uniswap/v4/twap/adversarial/` | J/F1/gap/cross-instance |
| `test/foundry/fork/**/oracles/` | Optional 4663 |

### 4.1 Uni V4 SE files to edit (same implementation pass, Phase C)

| Path | Change |
|------|--------|
| `UniswapV4StandardExchangeDFPkg.sol` | `PkgInit.twapOracle`; immutable; construct checks; `initAccount` writes AwareRepo |
| `UniswapV4_Component_FactoryService.sol` | `buildArgs*` takes `twapOracle` |
| `UniswapV4StandardExchangeCommon.sol` | `_pokeBoundPoolTwap()`; `twapOracle()` view if not on a dedicated query |
| In / Out / Multi / LiquidReserve / PositionImport **Targets** | Call poke **after** successful user op (and tail-rebalance when that path runs one) |
| Query facets | **Do not** poke |
| `interfaces/` if a vault query for `twapOracle()` is new | `function twapOracle() external view returns (IUniswapV4MultiPoolTwapOracle)` |
| `aware/UniswapV4TwapOracleAwareRepo.sol` (new, under twap/ or v4/) | Vault storage of instance address |

### 4.2 Call sites that construct SE `PkgInit` (must compile)

Grep-driven; at least:

- `contracts/protocols/dexes/uniswap/v4/test/bases/TestBase_UniswapV4StandardExchange.sol`
- `test/foundry/spec/protocol/dexes/uniswap/v4/UniswapV4StandardExchange_FullRangeBook.t.sol`
- `test/foundry/spec/protocol/dexes/uniswap/v4/adversarial/Adversarial_UniswapV4SE_E6ImpA0.t.sol`
- `scripts/foundry/anvil_robinhood_main/Stage_03_UniV4Packages.sol`
- `scripts/foundry/anvil_robinhood_testnet/Phase_05_Stage_02_UniswapV4TwapOracle.sol` (canonical instance)
- `scripts/foundry/anvil_robinhood_testnet/Phase_05_Stage_03_UniswapV4StandardExchangePkg.sol` (`PkgInit.twapOracle` from 05-02)
- `scripts/foundry/local_testing/anvil_single/Script_12_DeployScenario3Overlay.s.sol`

Pattern: 46630 launch deploys the canonical instance in Phase 05 Stage 02, then Phase 05 Stage 03 passes it into SE `PkgInit.twapOracle`. Other call sites deploy a TWAP instance for that environment’s PoolManager, then pass it into `buildArgs*` / `pkgInit.twapOracle`.

---

## 5. Concrete APIs

### 5.1 Package (`IUniswapV4MultiPoolTwapOracleDFPkg`)

```solidity
struct PkgInit {
    IFacet twapOracleFacet;
    IDiamondPackageCallBackFactory diamondFactory;
}

struct PkgArgs {
    address poolManager;
}

function deployOracle(PkgArgs calldata args) external returns (IUniswapV4MultiPoolTwapOracle oracle);
```

`calcSalt(pkgArgs) = keccak256(abi.encode(PkgArgs.poolManager))` (D6). Factory already namespaces by package.

`processArgs`: revert `ZeroPoolManager` if `poolManager == address(0)`.

`initAccount`: bind AwareRepo; do **not** `unlock`; do **not** write observations.

`deployOracle`:

1. `predicted = diamondFactory.calcAddress(this, abi.encode(args))`
2. If `predicted.code.length > 0`, return it (no `OracleDeployed` event)
3. Else `diamondFactory.deploy(this, abi.encode(args))`, emit `OracleDeployed`

Permissionless (D7, H30).

### 5.2 Instance

```solidity
function poolManager() external view returns (address);
function MAX_ABS_TICK_MOVE() external pure returns (int24); // 9116

function update(PoolKey calldata key) external returns (bool written);
function update(PoolKey[] calldata keys) external returns (bool[] written); // keeper only

function increaseCardinalityNext(PoolId id, uint16 next) external;

function observe(PoolId id, uint32[] calldata secondsAgos)
    external view returns (int56[] memory tickCumulatives);
function consult(PoolId id, uint32 secondsAgo) external view returns (int24 arithmeticMeanTick);

function getPoolKey(PoolId id) external view returns (PoolKey memory);
function getState(PoolId id) external view returns (uint16 index, uint16 cardinality, uint16 cardinalityNext, int24 prevTick, uint32 lastTimestamp);
function getObservation(PoolId id, uint16 index) external view returns (Observation memory);
function writeAge(PoolId id) external view returns (uint256);
```

`Observation`: `{ uint32 blockTimestamp; int56 tickCumulative; int24 prevTick; bool initialized; }` — no seconds-per-liquidity.

### 5.3 Morpho adapter

Constructor / factory args: `(instance, key, secondsAgo, collateralIsCurrency0, maxWriteAge)`.

Reverts at create: `ZeroOracle`, `ZeroSecondsAgo`, `ZeroMaxWriteAge`, `DecimalsQueryFailed`, `oracle.poolManager() == 0`.

```solidity
function price() external view returns (uint256); // Morpho IOracle — no arguments
```

### 5.4 AggregatorV3 adapter

Constructor args: `(instance, key, secondsAgo, invert, maxWriteAge)`.

- `decimals() = 18` (feed decimals, not token decimals)
- Never written: `latestAnswer = 0`, `latestRoundData → (0,0,0,0,0)`, `updatedAt = 0`
- After real write: `latestRoundData → (1, answer, updatedAt, updatedAt, 1)`
- Stale / uncovered window reverts
- `getRoundData`: only `roundId == 1` after a real write, else revert. Not a historical ring.

### 5.5 Adapter factory

```solidity
function createMorphoOracle(
    IUniswapV4MultiPoolTwapOracle oracle,
    PoolKey calldata key,
    uint32 secondsAgo,
    bool collateralIsCurrency0,
    uint32 maxWriteAge
) external returns (address);

function createAggregatorV3(
    IUniswapV4MultiPoolTwapOracle oracle,
    PoolKey calldata key,
    uint32 secondsAgo,
    bool invert,
    uint32 maxWriteAge
) external returns (address);
```

**No** extra caller salt (D42).

Salt Morpho = `keccak256(abi.encode(oracle, key, secondsAgo, collateralIsCurrency0, maxWriteAge))`.  
Salt Aggregator = `keccak256(abi.encode(oracle, key, secondsAgo, invert, maxWriteAge))` plus factory namespaces the two create paths (different init code / prefix) so they cannot collide.

Factory is CREATE3-deployed once. Adapters: deploy from this factory with that salt. If `predicted.code.length > 0`, return existing.

### 5.6 SE poke helper

```solidity
function twapOracle() public view returns (IUniswapV4MultiPoolTwapOracle);

function _pokeBoundPoolTwap() internal {
    PoolKey memory key = /* vault bound key */;
    try twapOracle().update(key) returns (bool) {}
    catch (bytes memory reason) {
        emit TwapOracleUpdateFailed(PoolId.unwrap(key.toId()), reason);
    }
}
```

Must be an **external call** to the oracle instance (not a self-call) so `try/catch` works.

Call **after** the user op (and tail-rebalance when present) on:

| Path | File (expected) | Poke? |
|------|-----------------|-------|
| Direct swap | `UniswapV4StandardExchangeInTarget.exchangeIn` token0↔token1 | Yes |
| Zap-in | `exchangeIn` / InBase deposit | Yes |
| Zap-out via `exchangeIn` shares→token | same | Yes |
| `exchangeOut` | OutExecuteTarget | Yes |
| `exchangeInManyToOne` / `exchangeOutOneToMany` | Multi targets | Yes |
| `rebalanceLiquidReserve` | LiquidReserveTarget | Yes, after rebalance body |
| Successful `importPosition` | PositionImportTarget | Yes |
| Query / preview | *Query* | **No** |
| ERC-20 `transfer` / `approve` / `permit` | ERC20 facets | **No** |
| Revert / disable early-out | any | **No** (tx reverts anyway) |

Poke **also when interaction-blocked** (sleeve path). `update` does not need `unlock`.

---

## 6. Algorithms (normative with the PRD)

### 6.1 Truncation (D15)

```text
recordedTick = currentTick
if recordedTick > prevTick + 9116: recordedTick = prevTick + 9116
if recordedTick < prevTick - 9116: recordedTick = prevTick - 9116
```

Apply on `update` after the first write, and on observe-time **tail** interpolation vs `state.prevTick`. First write uses raw slot0 tick (no prev).

### 6.2 `update(PoolKey)` (D11–D14, D45)

1. `id = key.toId()`
2. `(sqrtPriceX96, tick,,) = StateLibrary.getSlot0(poolManager, id)` — **never** `unlock`
3. If `sqrtPriceX96 == 0`: return `false`. No write, no event, do **not** write tick 0
4. If no initialized observation: write `[0]` at `block.timestamp` with `tickCumulative = 0`, `prevTick = tick`, `cardinality = 1`, `cardinalityNext = max(1, stored cardinalityNext)`, store `key`. Emit `ObservationWritten`. Return `true`
5. If last observation `blockTimestamp == uint32(block.timestamp)`: return `false`
6. Truncate `tick` vs `prevTick`
7. `delta = now - last.timestamp` (uint32 wrap as V3)
8. `tickCumulative = last.tickCumulative + int56(recordedTick) * int56(delta)`
9. If `cardinalityNext > cardinality && index == cardinality - 1`: `cardinality = cardinalityNext` (V3 bump)
10. `index = (index + 1) % cardinality`; write slot; update `prevTick`; emit; return `true`

Ring storage: `mapping(PoolId => mapping(uint16 => Observation))`. **Do not** allocate `Observation[65535]`.

### 6.3 `increaseCardinalityNext` (D45)

- Current `cardinalityNext` is **1** if never grown and never written, else stored
- `next <= current` or `next == 0` → `CardinalityNextTooLow`
- `next > 65535` → revert
- Store `cardinalityNext`; **do not** write an observation
- Emit `CardinalityNextIncreased`
- Observe/consult/adapters still **price 0** until first real `update`
- Do **not** pre-touch slots (V3 `blockTimestamp = 1` loop is for the static array)

### 6.4 `observe` / `consult`

Copy Uniswap V3 `Oracle.observe` / `OracleLibrary.consult` **without** seconds-per-liquidity.

- Never written (incl. pre-grow only): `observe` → zero cumulatives; `consult` → `0`. Do not revert `UnknownPool`
- `consult(secondsAgo == 0)` → `InvalidSecondsAgo`
- Window older than oldest after a real write → `TargetPredatesOldestObservation(oldest, target)`
- Tail interpolation uses **truncated** current slot0 tick vs `prevTick`
- Consult remainder: match V3 `OracleLibrary.consult` (Solidity `/` toward zero, then decrement if negative remainder so the mean **floors**). D37 “toward-zero” names the `/`; keep the V3 floor fix
- Instance does **not** revert on write age

### 6.5 Morpho `price()` (D26, D43)

Never written → `0` (skip `maxWriteAge`).  
After a write, `writeAge > maxWriteAge` → `StaleObservation`.  
Uncovered window → revert (do not return 0).  
`consult == 0` is **not** “never written.”

Tick: `consult(id, secondsAgo)`. Direction is token swap in `getQuoteAtTick` (`collateral` / `loan` from `collateralIsCurrency0`). Do **not** also negate the tick.

Scale (tick 0 → `1e36` for any decimal pair; Morpho wei/wei `IOracle`):

```text
quoteAmount = getQuoteAtTick(tick, uint128(1e18), coll, loan)
price       = quoteAmount * 1e18
```

`coll` / `loan` addresses from the frozen `PoolKey` and `collateralIsCurrency0`. Native `address(0)` decimals = 18, snapshotted at create. `price()` never calls `decimals()` and never `update`s.

Use Crane `TickMath` + `FullMath` (already in the monorepo). Do not add a new AMM math dialect.

### 6.6 “Never written” predicate

Use **no initialized observation** (`cardinality == 0` **or** `!observations[0].initialized`), **not** `writeAge == 0` (a same-block just-written observation also has age 0).

---

## 7. Deploy path

```text
CraneTest / launch
  FactoryService CREATE3
    → facet, DFPkg(PkgInit{facet, diamondFactory}), adapter factory
  twapPkg.deployOracle({ poolManager: PM })     // permissionless, idempotent
  SE DFPkg construct with PkgInit.twapOracle
  SE.deployVault via vault registry            // copies instance
  adapterFactory.createMorphoOracle(instance, key, ...)
```

TWAP DFPkg: **Crane** `create3Factory.deployPackageWithArgs` / FactoryService. **Not** `indexedexManager.deploy*DFPkg` unless a later discovery nicety; PRD D9 forbids vault-registry **vault** records.

SE DFPkg: still `indexedexManager.deployUniswapV4StandardExchangeDFPkg` (vault package).

Hermetic PoolManager: `new PoolManager(...)` in TestBase is the **Crane port**, allowed (not a mock SUT). Then `poolManager.initialize(key, sqrtPriceX96)` for fixtures.

Second manager (H21): second `new PoolManager`, second `deployOracle`.

---

## 8. Phases

Do not start Phase B until Phase A declaration + H20/H22–H26/H23/H24 are green. Do not start Phase C until the instance `update`/`observe`/`consult` matrix (H1–H9, H18, H31) is green.

### Phase A — Oracle package (instance)

1. Interfaces, errors, events
2. Lib + Repo + AwareRepo + Target + Facet (`facetFuncs` from Target)
3. DFPkg + FactoryService
4. `TestBase_UniswapV4MultiPoolTwapOracle`: FactoryService → `deployOracle` against real PM
5. Tests: H20, H22, H23, H24, H25, H26, H30

**Exit:** unowned instance; J1–J3; `deployOracle` idempotent; zero PM reverts.

### Phase B — Ring behavior

H1–H9, H18, H31. Truncation, same-block skip, interpolation, oldest-window revert, native currency pool, pre-grow, `update` during outer `unlock`.

Batch `update(PoolKey[])`: one keeper test (missing key returns false, does not revert). **Not** the happy-path fixture.

### Phase C — Adapters

Morpho + AggregatorV3 + factory. H10–H13, H19, H32.

### Phase D — SE wiring

PkgInit + construct checks + vault poke + TestBase/launch call sites. H14–H17, H27–H29.

Existing SE specs must still compile and keep their own DoD. Poke fail-open must not change share math.

### Phase E — Adversarial + optional fork

Adv-gap, poke-then-read, multi-block, card-1, wrong-dir, Adv-cross-instance, J, F1.

Fork 4663 optional: poke a pons v2 pool, consult vs spot directionally.

### Phase F — Launch stage

`Stage_03` (and testnet peer): CREATE3 TWAP package, `deployOracle(canonical PM)`, pass instance into SE `PkgInit`. No keeper bot.

---

## 9. TestBase

```text
CraneTest
  └── IndexedexTest
        └── TestBase_UniswapV4MultiPoolTwapOracle
              ├── spec/*.t.sol
              └── adversarial/*.t.sol
```

SE poke tests inherit `TestBase_UniswapV4StandardExchange` **after** that base deploys a TWAP instance and puts it in `PkgInit`.

Helpers on the TWAP TestBase (expected):

- `_deployOracle(IPoolManager pm) → instance`
- `_initPool(pm, key, sqrtPrice)` 
- `_swapToTick(...)` via PM unlock (real swap, not `vm.store` of slot0)
- `_warp(seconds)`
- `_poke(key)` / assert `written`

**Forbidden:** `new UniswapV4MultiPoolTwapOracleFacet()`, `new UniswapV4MultiPoolTwapOracleDFPkg`, `vm.mockCall` on instance/adapters/PM as SUT.

---

## 10. Test matrix (DoD)

IDs match PRD §11. Exact asserts (LR-7). Typed `vm.expectRevert`.

### 10.1 Hermetic

| ID | Assert |
|----|--------|
| H1 | First real `update` writes card=1, `tickCumulative=0`, stores key, `written=true` |
| H2 | Warp + second poke; `consult(window)` matches truncated accumulator |
| H3 | Second `update` same block → `written=false`, ring unchanged |
| H4 | Dump >9116 ticks then poke: recorded tick = `prev ± 9116` |
| H5 | After a real write, `consult` older than oldest reverts `TargetPredatesOldestObservation` |
| H6 | `increaseCardinalityNext` then later writes grow cardinality (V3 bump) |
| H7 | Native `currency0 == address(0)` pool pokes and consults |
| H8 | Never-written (and pre-grow-only) `observe`/`consult`/`price()` = 0, no revert |
| H9 | Uninitialized pool `update` → `false`, no ring |
| H10 | Morpho `price()` at tick 0, 18/18 = `1e36` |
| H11 | `collateralIsCurrency0 == false` inverts vs H10 |
| H12 | After a write, warp past `maxWriteAge` → `StaleObservation`; poke then `price()` succeeds |
| H13 / H32 | Adapter factory idempotent; different instance or `secondsAgo` → different address |
| H14 | Vault `twapOracle()` equals SE `PkgInit`; zap pokes bound pool |
| H15 | Poke after user op: if zap moved tick and this tx is the first writer, observation matches **post-trade** truncated tick |
| H16 | Oracle `update` reverts (e.g. out-of-gas via a hostile instance in a dedicated fixture **or** `vm.mockCallRevert` on the **oracle address only** as a non-SUT failure injector for the SE catch) → SE op still succeeds, `TwapOracleUpdateFailed` |
| H17 | `transfer`/`approve` do not poke; SE zap does not poke a second key; EOA `update(foreignKey)` writes |
| H18 | `update` while `TransientStateLibrary.isUnlocked(pm)` (outer unlock harness) succeeds |
| H19 | Non-18 decimals snapshot; native 18; missing `decimals` → `DecimalsQueryFailed` at **create** |
| H20 | No `new` facet/DFPkg/instance on TestBase happy path |
| H21 | Two PMs → two instances; poke A does not write B |
| H22 | `deployOracle` twice same args → same address |
| H23 | `poolManager=0` → `ZeroPoolManager` |
| H24 | After deploy, unowned; `diamondCut` reverts |
| H25 | `Behavior_IFacet` + `Behavior_IDiamondFactoryPackage` |
| H26 | J1–J3: Target selectors ⊆ facetFuncs ⊆ cuts ⊆ loupe + callable on **proxy** |
| H27 | Every vault from the package: `vault.twapOracle() == pkgInit.twapOracle` and PM match |
| H28 | `deployVault` / processArgs reverts if oracle PM ≠ vault PM (defense; package immutable should already match) |
| H29 | SE DFPkg construct reverts on `twapOracle==0` or PM mismatch |
| H30 | Arbitrary EOA `deployOracle` succeeds |
| H31 | Pre-grow stores `cardinalityNext`, consult still 0; first `update` keeps that `cardinalityNext` |

H16 note: prefer a **hostile oracle instance** (wrong facet that reverts `update`) deployed through the same DFPkg path if practical. `vm.mockCallRevert` on the oracle address is allowed **only** as a non-SUT injector for the SE `try/catch` test, never to fake happy-path TWAP math.

### 10.2 Adversarial

| ID | Assert |
|----|--------|
| Adv-gap | Adapter `maxWriteAge` reverts when pokes stop; poke restores |
| poke-then-read | Same tx: dump, `update`, `price()` — truncation vs `prevTick` |
| multi-block | Several truncated steps cannot exceed 9116 × n |
| card-1 | Window longer than time since last overwrite reverts; interpolates the tail only |
| wrong-dir | Morpho invert / Aggregator `invert` not equal to the other direction |
| Adv-cross-instance | Adapter on A; dump+poke B only → A stale or unchanged |
| J1–J3 | Required |
| F1 | Unowned after `postDeploy` |
| A0 / I1 / E6 | **Deferred** — instance holds no inventory. NatSpec on the suite |
| L2 | N/A on instance. FoT still forbidden if this feed is wired as an IX underlying (agent law) |

### 10.3 Out of v1 test scope

Keeper bots, UI, Morpho mainnet listing, DETF threshold wiring, sibling DEX reader, vault extra keys, buffer-hook writer.

---

## 11. SE poke implementation notes

`UniswapV4StandardExchangeInTarget.exchangeIn` has three success `return`s (direct swap, zap-in, zap-out). Add `_pokeBoundPoolTwap()` immediately before each successful return (after amount/share math). Same for Out, Multi, rebalance, import.

Do **not** poke from `_unlockCallback` (reentrancy/lock confusion). Poke after the outer SE function has finished PM work.

Fail-open must not change returned `amountOut` / `sharesOut`.

---

## 12. NatSpec / style

- Crane LR-1 tags on public surface; central values when computing selectors
- Slot names hierarchical, ERC1967 `DEFAULT_SLOT` form on **new** Repos
- Role names: `currency0` / `currency1` on the oracle; `collateral` / `loan` only on Morpho adapter
- Example `maxWriteAge` in adapter NatSpec: **300**
- Suite NatSpec: deferred A0/I/E6/M/O; L2 forbidden-as-underlying

---

## 13. Definition of Done

Ship gate: Crane `implementation-test-dod.md` as applicable, plus:

- [ ] PRD acceptance §14 (1–10)
- [ ] Phase A–D hermetic IDs H1–H32 green on DFPkg path
- [ ] J1–J3 + F1
- [ ] No `new` facet/DFPkg/instance on happy TestBase
- [ ] SE existing specs still compile; poke is fail-open
- [ ] Launch Stage_03 (or documented skip) wires canonical instance before SE package
- [ ] `via_ir` not enabled
- [ ] Adversarial suite NatSpec lists deferred IDs
- [ ] No DETF mint/burn path imports this oracle

```bash
# After a green worktree compile seed (CLAUDE.md): do not kill a long solc
forge test --match-path 'test/foundry/spec/oracles/uniswap/v4/twap/**' -vv
forge test --match-path 'test/foundry/spec/protocol/dexes/uniswap/v4/**' -vv
```

`--match-test` prefixes must not collide with `test_C` / `test_F_` compound suites; prefer `--match-path` / `--match-contract`.

---

## 14. Follow-on (not this plan)

- Buffer-hook writer (PRD non-goal 13)
- Heartbeat keeper at `maxWriteAge / 2`
- Vault extra poke keys
- Sibling DFPkg for non-StateLibrary DEX
- Query/write facet split if size requires

---

## Changelog

| Version | Date | Notes |
|---------|------|-------|
| v1.0 | 2026-08-24 | Coding plan for PRD v1.5. Primary poke `update(PoolKey)`; batch keeper-only; Morpho adapter = frozen `price()`; SE poke after market ops; pre-grow; decimals snapshot. |
