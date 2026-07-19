# MultiPairStandardExchangeBufferPool — Implementation and Testing Plan

## Purpose

Execute the [PRD](./MultiPairStandardExchangeBufferPool_PRD.md): implement a **multi-pair weighted Standard Exchange buffer pool** (Balancer V3) that generalizes the single-pair buffer under `constProd/standardExchange/`, with **fixed deploy-time weights**, **up to four distinct `(bufferToken, vault)` pairs**, **full-graph swaps**, and **AMM equivalence** to a normal weighted pool under the PRD freeze protocol.

This plan is ordered for incremental delivery: each phase leaves a green, reviewable slice.

## Status

**IMPLEMENTED** — production package + P=1..4 fixtures; within/cross-pair/share↔share; comparative; adversarial P0 (37 green tests).

| Field | Value |
|-------|--------|
| PRD | `MultiPairStandardExchangeBufferPool_PRD.md` (**LOCKED** L1–L27) |
| Package path | `contracts/protocols/dexes/balancer/v3/pools/weighted/multiPairBuffer/` |
| Behavioral reference | `contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/` |
| Tests root (intended) | `test/foundry/spec/protocols/dexes/balancer/v3/pools/weighted/multiPairBuffer/` |

### Locked decisions (summary from PRD)

| Topic | Decision |
|-------|----------|
| Pairs | `1 ≤ P ≤ 4`; `T = 2P` tokens |
| Token set | `bufferToken[i]` + `vaultShare[i]` per pair |
| Uniqueness | Distinct buffer tokens and vaults/shares (L21) |
| Weights | Fixed deploy-time; sum `1e18`; min ≥ ~1% |
| Routes | Full weighted graph |
| LP | Proportional + unbalanced |
| Equivalence | Match normal weighted pool AMM under **frozen SE underlyings** |
| Economic parity | Not a goal when underlyings trade |
| Init seed | `virtualBuffer[i] =` buffer-leg scaled18 seed (L25) |
| Invariant bounds | WeightedMath 70%–300% (L26), not identity |
| Rate provider | Default SE RP or non-zero override (L27) |
| SE I/O | Preview-aligned pre-seat; best-effort deposit (L24) |
| Naming | `bufferToken` (not TTA) |
| Fee | Pool-wide static only |
| vs single buffer | Parallel products forever |
| Deploy | CREATE3 facets; Vault Registry DFPkg |
| Pool + hooks | **Hook Facet MUST be cut into the pool proxy**; `hooksContract == pool` (never separate hooks contract) |

---

## 1. Goals and non-goals

### Goals

1. Ship production Diamond pool + hooks + CUSTOM liquidity under `weighted/multiPairBuffer/`.
2. Prove **AMM equivalence** vs a real Balancer V3 weighted pool (same tokens, weights, fees, rate providers) with SE underlyings **frozen** (L15–L16).
3. Support **P = 1..4**, full-graph swaps, unbalanced LP, distinct pairs only.
4. Preserve single-buffer security: `NotHookCaller` on CUSTOM, Vault-only hooks, best-effort reconcile.
5. Production-first tests; no mocks of SUT pool / manager / registry / SE vaults under test.
6. **Adversarial suite** per [ADVERSARIAL_TEST_PLAN](./MultiPairStandardExchangeBufferPool_ADVERSARIAL_TEST_PLAN.md) (P0 catalog before “security-ready”).

### Non-goals

- Replacing or subclassing the single-pair `constProd/standardExchange` package.
- Rate-scaled effective weights (single-buffer refinement only).
- DETF seigniorage / bond / claim.
- Mainnet deploy scripts (follow-up after green hermetic suite).
- Economic parity after SE underlying trades.
- Full MEV sandwich reconstruction (adversarial P2; document).

---

## 2. Naming and layout

### Source

```text
contracts/protocols/dexes/balancer/v3/pools/weighted/multiPairBuffer/
  MultiPairStandardExchangeBufferPool_PRD.md
  MultiPairStandardExchangeBufferPool_IMPLEMENTATION_AND_TEST_PLAN.md  # this file
  IMultiPairStandardExchangeBufferPool.sol
  MultiPairStandardExchangeBufferPoolRepo.sol
  MultiPairStandardExchangeBufferPoolCommon.sol
  MultiPairStandardExchangeBufferPoolTarget.sol
  MultiPairStandardExchangeBufferPoolFacet.sol
  MultiPairStandardExchangeBufferHookTarget.sol
  MultiPairStandardExchangeHookFacet.sol
  MultiPairStandardExchangeBufferPoolLiquidityTarget.sol
  MultiPairStandardExchangeBufferPoolLiquidityFacet.sol
  MultiPairStandardExchangeBufferPoolStandardVaultPkg.sol   # PkgInit/PkgArgs on interface
  MultiPairStandardExchangeBufferPool_FactoryService.sol
```

**Type names:** full words (`MultiPair`, `StandardExchange`, `BufferPool`).  
**Roles:** `bufferToken`, `vaultShare`, `standardExchangeVault`, `virtualBuffer`, `hookShareDelta`.  
**Forbidden:** product tickers; `TTA`/`tta` as multi-pair role names.

### Tests

```text
test/foundry/spec/protocols/dexes/balancer/v3/pools/weighted/multiPairBuffer/
  bases/
    TestBase_MultiPairStandardExchangeBufferPool.sol
    TestBase_MultiPairStandardExchangeBufferPool_UniV2.sol   # hermetic SE legs
  comparative/
    bases/TestBase_MultiPairBuffer_Comparative.sol
    MultiPairBuffer_Comparative.spec.t.sol
  behaviors/
    Behavior_Registration.sol
    Behavior_Initialization.sol
    Behavior_Swap_WithinPair.sol
    Behavior_Swap_CrossPair.sol
    Behavior_LP_Proportional.sol
    Behavior_LP_Unbalanced.sol
    Behavior_Uniqueness.sol
    Behavior_Errors.sol
  MultiPairStandardExchangeBufferPool.spec.t.sol
  MultiPairStandardExchangeBufferPool.invariant.t.sol
  Handler_MultiPairStandardExchangeBufferPool.sol
  MultiPairStandardExchangeBufferPoolLiquidityTarget.t.sol
  adversarial/                                          # see ADVERSARIAL_TEST_PLAN.md
    TestBase_MultiPairBuffer_Adversarial.sol
    Adversarial_*.t.sol
```

---

## 3. Math and state (normative for implementers)

### 3.1 Token indexing

- Balancer sorts tokens by address; store `bufferIndex[i]`, `shareIndex[i]` at init.
- Maintain `pairOfToken[t] ∈ {0..P-1}` and `isBufferToken[t]` (or derive by comparing to stored addresses).

### 3.2 Math balance vector \(B_t\)

| Token | Math balance |
|-------|----------------|
| `bufferToken[i]` | `virtualBuffer[i]` (scaled18) |
| `vaultShare[i]` | `derivedShareDepth[i]` = live scaled18 shares ± lift(`hookShareDelta[i]`) |

Weights: immutable `weights[t]`, \(\sum w_t = 1e18\), each \(w_t \ge 1e16\) (1%).

Use Balancer `WeightedMath` for:

- `computeInvariant(weights, B)`
- `onSwap` exact-in / exact-out on \((B_{in}, w_{in}, B_{out}, w_{out})\)
- `computeBalance` for unbalanced LP paths

**Invariant ratio bounds (L26):** `WeightedMath._MIN_INVARIANT_RATIO` (70e16) and `_MAX_INVARIANT_RATIO` (300e16) — same as BV3 `WeightedPool`.

### 3.3 Initialization (L25)

On `onBeforeInitialize(exactAmountsInScaled18, …)`:

```text
for i in 0..P-1:
  virtualBuffer[i] = exactAmountsInScaled18[bufferIndex[i]]
  require virtualBuffer[i] > 0  // or allow 0 only if product explicitly allows; default require > 0 for usable pair
  hookShareDelta[i] = 0
```

Do **not** seed virtuals from the share side alone.

### 3.4 Post-swap math updates (match reference)

After a successful swap of `amountIn` / `amountOut` (scaled18, fee-consistent with Vault):

```text
B[tokenIn]  += amountIn   // via virtualBuffer or derived shares
B[tokenOut] -= amountOut
```

Concretely:

| tokenIn kind | After swap settlement + hooks |
|--------------|-------------------------------|
| buffer | `virtualBuffer[inPair] += amountInScaled18` (set during reconcile after deposit; physical cleared) |
| share | derived depth rises with Vault credit of user shares (delta unchanged unless hook reshuffled that leg) |

| tokenOut kind | After |
|---------------|-------|
| buffer | `virtualBuffer[outPair] -= amountOutScaled18` (in `onAfterSwap` after pre-seat delivery) |
| share | derived depth falls with user taking shares |

### 3.5 Pre-seat when `bufferToken` is out (L24)

Mirrors single-buffer shares→TTA, owned by **out-pair** \(j\):

1. Quote `Y` = TTA/buffer amount Vault will deliver (fee-adjusted weighted out, same as `onSwap`).
2. `S = vault_j.previewExchangeOut(share_j, buffer_j, Y)`; align drain with BV3 rate round-trip helpers.
3. Drain shares of pair \(j\) from Balancer → `exchangeOut` → settle buffer → DONATE buffer into pool → CUSTOM remove shares; adjust `hookShareDelta[j]` so **derived share depth of \(j\)** is unchanged for `onSwap`.
4. Defer `virtualBuffer[j] -= actualOut` to `onAfterSwap`.

Works for **within-pair** (tokenIn = share_j) and **cross-pair** (tokenIn = anything else): pre-seat still uses **pair j’s** share inventory.

### 3.6 Reconcile when `bufferToken` is in (L24)

Mirrors single-buffer TTA→shares best-effort, owned by **in-pair** \(i\):

1. Drain physical `bufferToken_i` amount \(X\) from pool.
2. `exchangeIn` full \(X\) into vault \(i\) → mint \(M\) shares (best-effort; revert if zero/fail).
3. Settle + DONATE \(M\) shares; CUSTOM remove buffer;  
   `virtualBuffer[i] += X_scaled18`;  
   `hookShareDelta[i] += donationRaw` so derived share \(i\) net-zero from donation.

Works when tokenOut is share_i or any other token: deposit always goes to **pair i**.

### 3.7 Share ↔ share (no buffer token)

- No SE I/O.
- Pre-seat/reconcile no-ops.
- Math uses derived share depths only; physical balances move with Vault swap.

### 3.8 LP bookkeeping

**Proportional add/remove:** scale every `virtualBuffer[i]` and `hookShareDelta[i]` by BPT ratio (signed), same spirit as single buffer.

**Unbalanced / single-token (L19):**

- Buffer token in: grow `virtualBuffer[i]` by scaled18 amount contributed; physical residual follows eventual-zero (next buffer-in swap reconcile or explicit future sweep — match single-buffer “eventual zero” comments).
- Share in: leave `hookShareDelta` unchanged so derived depth grows with live balance.
- **DONATION** used by hook reconcile: **no** virtual bump (avoid double-count).

### 3.9 Equivalence identity (tests)

Under L15 freeze and matched init:

\[
B^{\text{buffer}}_t = B^{\text{reference}}_t \ \forall t
\quad\Rightarrow\quad
\text{swap / LP outputs match within tolerance.}
\]

---

## 4. Package / deploy surface

### 4.1 Interface structs (on interface, not contract body)

```solidity
interface IMultiPairStandardExchangeBufferPoolPkg is IDiamondFactoryPackage, IStandardVaultPkg {
    struct PkgInit {
        // shared BV3 + vault facets (mirror single buffer pkg)
        IFacet basicVaultFacet;
        IFacet standardVaultFacet;
        IFacet balancerV3VaultAwareFacet;
        IFacet betterBalancerV3PoolTokenFacet;
        IFacet defaultPoolInfoFacet;
        IFacet standardSwapFeePercentageBoundsFacet;
        IFacet unbalancedLiquidityInvariantRatioBoundsFacet; // expose weighted bounds if needed
        IFacet balancerV3AuthenticationFacet;
        IFacet bufferPoolFacet;
        IFacet poolLiquidityFacet;
        IFacet hookFacet;
        IVaultRegistryDeployment vaultRegistry;
        IVaultFeeOracleQuery vaultFeeOracle;
        IVault balancerV3Vault;
        IDiamondPackageCallBackFactory diamondFactory;
        IStandardExchangeRateProviderDFPkg rateProviderPkg;
    }

    struct PkgArgs {
        uint8 pairCount; // 1..4
        IERC20[] bufferTokens;
        IStandardExchange[] standardExchangeVaults;
        IRateProvider[] rateProviders; // address(0) => deploy default
        uint256[] weights;             // length T=2P, Balancer token order OR pair-major order — pick one and document
        // optional: swapFeePercentage override; 0 => package default
    }

    function deployPool(bytes memory pkgArgs) external returns (address pool);
}
```

**Weight ordering decision for implementers:** Prefer **weights aligned to Balancer address-sorted token order** after `_buildTokenConfigs`, computed in `updatePkg`/`initAccount` from a pair-major input only if conversion is deterministic and tested. Document the chosen convention in NatSpec on `PkgArgs`.

### 4.2 Validation (deploy / init)

- `pairCount ∈ [1,4]`; array lengths match.
- L21 uniqueness: distinct buffers, distinct vaults/shares, unique pool token addresses.
- Each `bufferToken[i] ∈ vault[i].tokens()` (or SE surface equivalent).
- `vaultShare[i] = address(vault[i])` when vault-as-share.
- Weights: length `2P`, each ≥ 1e16, sum == 1e18.
- Rate provider: non-zero override or deploy default (L27).

### 4.3 Registration

- TokenConfig: buffer = STANDARD; share = WITH_RATE + RP.
- LiquidityManagement: unbalanced **enabled**; custom add/remove **enabled**; donation **enabled**.
- **Hook Facet MUST be included in the pool proxy** `facetCuts` (full `IHooks` surface).
- **`hooksContract = pool proxy`** at Balancer registration — **never** a separate hooks contract (PRD L5).
- Static swap fee: pool-wide default (e.g. 5e16 / 0.05% peer) unless PkgArgs override.

### 4.4 FactoryService

Mirror `StandardExchangeBufferPool_FactoryService`: CREATE3 deploy facets; `indexedexManager.deploy*DFPkg(PkgInit)`.

---

## 5. Phased implementation

> Checkbox tasks for agents. Commit after each green phase when implementing.

### Phase 0 — Scaffold (no behavior)

- [ ] **P0.1** Create interface + errors + view surface (`IMultiPairStandardExchangeBufferPool`).
- [ ] **P0.2** Repo storage layout (append-only after first ship; document slot).
- [ ] **P0.3** Empty Facet/Target/Hook/Liquidity stubs with IFacet metadata. **Hook Facet is part of the pool diamond facet set** (not a separate deployable hooks proxy).
- [ ] **P0.4** DFPkg skeleton: `PkgInit`/`PkgArgs` on interface; facetCuts **including hookFacet**; `processArgs` registry-only; `postDeploy` sets `hooksContract = proxy`.
- [ ] **P0.5** FactoryService skeleton.
- [ ] **P0.6** `forge build` includes new files.

### Phase 1 — Registration + init

- [ ] **P1.1** `onRegister` validations (L21, token types, LM flags, factory, `pool == address(this)`).
- [ ] **P1.2** `initAccount` / `updatePkg` / `postDeploy` register with Balancer Vault; assert `hooksContract == pool` and pool supports `IHooks` selectors on the same address.
- [ ] **P1.2b** Negative: registration must not accept/configure an external hooks address (package always wires self).
- [ ] **P1.3** `onBeforeInitialize`: L25 virtual seeds; `hookShareDelta = 0`.
- [ ] **P1.4** TestBase: deploy P=1 and P=2 hermetic UniV2 (or Camelot) SE legs; assert registration + init.
- [ ] **P1.5** Uniqueness negative tests (duplicate buffer, duplicate vault).

### Phase 2 — Pool math (no hooks SE I/O yet optional unit harness)

- [ ] **P2.1** `Common`: vault rate/scale lift; derived share depth; BV3 donation/remove round-trips (generalize single-buffer helpers to multi-index).
- [ ] **P2.2** `Target`: `computeInvariant`, `computeBalance`, `onSwap` over math vector + fixed weights.
- [ ] **P2.3** Unit tests: invariant positive; swap directions on mocked balances **only if** isolated pure harness; prefer deployed pool with simple LP seed.

### Phase 3 — Within-pair swaps (full hooks)

- [ ] **P3.1** Pre-seat for buffer out (pair-local).
- [ ] **P3.2** Reconcile for buffer in (best-effort deposit).
- [ ] **P3.3** Router prepay auth pass/restore if present (parity single buffer).
- [ ] **P3.4** Behavior tests: both directions EXACT_IN; preview≈execution where possible; eventual-zero physical buffer.
- [ ] **P3.5** Failure paths: pre-seat fail, deposit fail, exhausted virtual buffer / shares.

### Phase 4 — Cross-pair + share↔share

- [ ] **P4.1** Cross-pair: buffer_i → share_j, share_j → buffer_i, buffer_i → buffer_k, share_i → share_j.
- [ ] **P4.2** Ensure non-involved legs’ math balances unchanged except the two swap legs.
- [ ] **P4.3** Full-graph matrix tests for P=2 (all ordered pairs of tokens).

### Phase 5 — LP

- [ ] **P5.1** Proportional add/remove virtual scaling.
- [ ] **P5.2** Unbalanced add: buffer-only and share-only paths; DONATION no-op for virtuals.
- [ ] **P5.3** CUSTOM liquidity `NotHookCaller` smoke (full catalog in adversarial track).

### Phase 5b — Adversarial track (required for security gate)

> Full catalog, P0/P1 priorities, and file layout:  
> **[MultiPairStandardExchangeBufferPool_ADVERSARIAL_TEST_PLAN.md](./MultiPairStandardExchangeBufferPool_ADVERSARIAL_TEST_PLAN.md)**  
> Method: `crane-adversarial-testing` + `indexedex-adversarial-testing`.

- [ ] **Adv-0** Scaffold `adversarial/` TestBase + plan checkboxes.
- [ ] **Adv-1 P0** D1–D4 CUSTOM drain + hook access; F1/F3 deploy/hooks-in-proxy; A3 donation; E7 eventual-zero.
- [ ] **Adv-2 P0** E1–E4 failed paths + cross-pair isolation; C1 reentrancy probe.
- [ ] **Adv-3 P1** A1–A2/A5, B1 rate move bounds, G1–G2 SE grief, H* atomicity.
- [ ] **Adv-4** `forge test --match-path '.../multiPairBuffer/adversarial/**'` green; deferred IDs in NatSpec.

### Phase 6 — Comparative equivalence (required)

- [ ] **P6.1** Deploy reference BV3 weighted pool (project weighted DFPkg or Crane `WeightedPoolFactory` in hermetic/fork fixture) with **same** TokenConfig, weights, fee, rate providers.
- [ ] **P6.2** Match init live balances (L25): reference physical buffer = buffer virtuals; raw shares equal.
- [ ] **P6.3** **Freeze** SE underlyings (no V2/CL trades on vault reserves).
- [ ] **P6.4** Assert EXACT_IN swaps (full graph sample) buffer ≈ reference (abs + rel tolerance; equalize fees).
- [ ] **P6.5** Assert spot / invariant-adjacent reads if exposed.
- [ ] **P6.6** Optional: proportional LP parity under freeze.
- [ ] **P6.7** Document that rate-moving underlying trades **break** numerical parity (L14) — optional separate stress suite without reference asserts.

### Phase 7 — Invariants + P=4 smoke

- [ ] **P7.1** Handler: random full-graph swaps + LP; virtual non-negative; eventual-zero buffers; no free BPT mint.
- [ ] **P7.2** P=4 deploy smoke (four distinct SE legs or mix hermetic tokens/vaults).
- [ ] **P7.3** Gas snapshot notes (optional).

### Phase 8 — Docs / polish

- [ ] **P8.1** NatSpec + AsciiDoc include-tags if repo convention requires.
- [ ] **P8.2** CODEBASE_MAP / Agents path note if needed.
- [ ] **P8.3** Mark this plan **IMPLEMENTED** when phases green.

---

## 6. Testing policy

| Rule | Detail |
|------|--------|
| Production-first | Real DFPkg, facets, manager path, SE vaults |
| No SUT mocks | Pool diamond, registry, manager, fee oracle, SE under test |
| Comparative freeze | L15 mandatory for parity asserts |
| Rate stress | Real underlying trades only in non-comparative suites |
| Naming | `bufferToken` in tests and helpers |
| Profiles | Hermetic default; fork optional for extra SE types |

### Minimum acceptance matrix

| Case | Pass criterion |
|------|----------------|
| Deploy P=1..4 | Init + register |
| Reject non-distinct pairs | Revert |
| Within-pair both directions | Success; eventual-zero buffer |
| Cross-pair sample | Success; math legs update correctly |
| Share↔share | Success; no SE I/O |
| Comparative under freeze | ≈ reference weighted |
| NotHookCaller | Drain reverts |
| Unbalanced LP | Virtuals consistent |
| Invariant fuzz | No broken virtuals / free mint |
| **Adversarial P0** | All P0 IDs in ADVERSARIAL_TEST_PLAN (D1 drain class, donation, residual, cross-pair, reentrancy probe) |

---

## 7. Risk register

| Risk | Mitigation |
|------|------------|
| Cross-pair pre-seat drains wrong inventory | Always pre-seat **out-pair** shares; unit-test cross matrix |
| Stack-too-deep in hooks | Extract helpers; viaIR already project-wide |
| Weight order bugs | One canonical ordering; fuzz deploy validation |
| Comparative false fails from rate drift | Freeze underlyings; never assert parity after underlying trades |
| Unbalanced LP double-count with DONATION | Kind-aware `onAfterAddLiquidity` like single buffer |
| Gas with P=4 + multi exchangeOut | Benchmark; document limits |

---

## 8. Reference file map (single buffer → multi)

| Single buffer | Multi-pair analogue |
|---------------|---------------------|
| `IStandardExchangeBufferPool` | `IMultiPairStandardExchangeBufferPool` |
| `StandardExchangeBufferPoolRepo` | `MultiPair…Repo` (arrays / per-pair fields) |
| `StandardExchangeBufferPoolCommon` | Multi-index lift/derived |
| `StandardExchangeBufferPoolTarget` | Fixed multi weights + math vector |
| `StandardExchangeBufferHookTarget` | Pair-resolved pre-seat/reconcile |
| `…LiquidityTarget` | Same `NotHookCaller` gate |
| `…StandardVaultPkg` | PkgArgs multi-pair + weighted bounds |
| Comparative design | Phase 6 (weighted reference, freeze) |

---

## 9. Out of scope follow-ups

- Shared pure lib extraction used by single buffer (only after multi is stable).
- Mainnet `scripts/foundry` staging.
- Dynamic fees / effective weights.
- `P > 4`.

---

## Document control

| Item | Value |
|------|--------|
| Plan path | `…/multiPairBuffer/MultiPairStandardExchangeBufferPool_IMPLEMENTATION_AND_TEST_PLAN.md` |
| PRD | `./MultiPairStandardExchangeBufferPool_PRD.md` |
| Adversarial plan | `./MultiPairStandardExchangeBufferPool_ADVERSARIAL_TEST_PLAN.md` |
| Created | 2026-07-18 |
| Status | PLAN READY — not started |
