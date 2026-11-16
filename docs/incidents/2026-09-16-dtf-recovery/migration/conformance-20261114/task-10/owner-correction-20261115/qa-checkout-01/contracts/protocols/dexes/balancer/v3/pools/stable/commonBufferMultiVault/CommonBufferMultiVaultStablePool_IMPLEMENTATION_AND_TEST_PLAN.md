# CommonBufferMultiVaultStablePool — Implementation and Testing Plan

## Purpose

Execute the [PRD](./CommonBufferMultiVaultStablePool_PRD.md): implement a **Balancer V3 Stable pool** with:

- **Exactly one** shared `bufferToken` consolidated into **N ∈ [1, 3]** Standard Exchange vaults,
- **No unpaired** legs,
- **Always-route** fan-out: deposit to **shallowest** vault (lowest derived depth \(d_i\)), redeem from **deepest** (highest \(d_i\)),
- **Walk next vault** on SE I/O failure,
- **Optional user-only** share rate providers,
- Fixed deploy-time **amplification** (no post-deploy amp updates),
- Token count \(T = 1 + N\) with \(2 \le T \le 4\).

This plan is ordered for incremental delivery: each phase leaves a green, reviewable slice.

## Status

**IMPLEMENTED** — PRD **LOCKED** (S1–S27). Hermetic suite green (N=1..3, formula, routing, adversarial P0).

| Field | Value |
|-------|--------|
| PRD | `CommonBufferMultiVaultStablePool_PRD.md` (**LOCKED** S1–S27) |
| Package path | `contracts/protocols/dexes/balancer/v3/pools/stable/commonBufferMultiVault/` |
| Behavioral references | `weighted/commonBufferMultiVault/`, `constProd/standardExchange/`, Crane `pool-stable/` |
| Tests root (intended) | `test/foundry/spec/protocols/dexes/balancer/v3/pools/stable/commonBufferMultiVault/` |

### Locked decisions (summary from PRD)

| Topic | Decision |
|-------|----------|
| Layout | \(T = 1 + N\), \(1 \le N \le 3\); no unpaired |
| Curve | StableMath + fixed deploy amp |
| Routing | Always shallowest deposit / deepest redeem |
| Need score | \(d_i\) only (no weights) |
| Ties | Lowest vault index |
| Runtime I/O fail | Walk next by depth; revert if all fail |
| Deploy vault check | Accept + produce via `IStandardVault` |
| Init | All legs non-zero; virtualBuffer = buffer seed |
| LP | Prop + unbalanced add; no buffer-only remove |
| Residual | Eventual-zero physical buffer |
| Share RPs | Optional user-only; no auto-deploy SE RP |
| Pre-seat quote | **StableMath** (not WeightedMath) |
| Parallel forever | Do not subclass weighted CommonBuffer targets |

---

## 1. Goals and non-goals

### Goals

1. Ship production Diamond pool + hooks + CUSTOM liquidity under `stable/commonBufferMultiVault/`.
2. Support configs: `N=1` (bridge); `N=2`; `N=3` (max).
3. Implement always-route depth ranking, S12 ties, S11 walk, SE I/O parity with CommonBuffer peers.
4. Prove **formula equivalence**: `onSwap` / invariant / `computeBalance` match `StableMath` on the math balance vector + amp.
5. Prove **routing + conservation**: correct ranking/walk; no free BPT; virtual ≥ 0; eventual-zero physical buffer.
6. Production-first tests; no mocks of SUT pool / manager / registry / SE vaults under test.
7. Adversarial P0: CUSTOM drain, donation, residual, reentrancy.

### Non-goals

- Replacing or subclassing weighted CommonBuffer / MultiPair / MixedLeg / single SE buffer.
- Implied-leg vault selection.
- Naive full-history comparative parity vs a reference stable pool after fan-out.
- Buffer-only unbalanced remove.
- Auto-deploying default SE RPs when user passes `address(0)`.
- Unpaired legs; routing weights; gradual amp updates; DETF; special router; mainnet scripts.

---

## 2. Naming and layout

### Source

```text
contracts/protocols/dexes/balancer/v3/pools/stable/commonBufferMultiVault/
  CommonBufferMultiVaultStablePool_PRD.md
  CommonBufferMultiVaultStablePool_IMPLEMENTATION_AND_TEST_PLAN.md  # this file
  ICommonBufferMultiVaultStablePool.sol
  CommonBufferMultiVaultStablePoolRepo.sol
  CommonBufferMultiVaultStablePoolCommon.sol
  CommonBufferMultiVaultStablePoolTarget.sol
  CommonBufferMultiVaultStablePoolFacet.sol
  CommonBufferMultiVaultStablePoolHookTarget.sol
  CommonBufferMultiVaultStablePoolHookFacet.sol
  CommonBufferMultiVaultStablePoolLiquidityTarget.sol
  CommonBufferMultiVaultStablePoolLiquidityFacet.sol
  CommonBufferMultiVaultStablePoolStandardVaultPkg.sol
  CommonBufferMultiVaultStablePool_FactoryService.sol
```

**Type names:** full words (`CommonBuffer`, `MultiVault`, `StablePool`).  
**Roles:** `bufferToken`, `standardExchangeVault`, `vaultShare` / `shareToken`, `virtualBuffer`, `hookShareDelta`, `amplificationParameter`.  
**Forbidden:** product tickers; brand names; `WETH` as a generic role; `weights` storage/API.

### Tests

```text
test/foundry/spec/protocols/dexes/balancer/v3/pools/stable/commonBufferMultiVault/
  bases/
    TestBase_CommonBufferMultiVaultStablePool.sol
    TestBase_CommonBufferMultiVaultStable_UniV2.sol   # hermetic SE legs
  behaviors/
    Behavior_Registration.sol
    Behavior_Initialization.sol
    Behavior_Routing.sol
    Behavior_Swap_BufferShare.sol
    Behavior_Swap_ShareShare.sol
    Behavior_LP_Proportional.sol
    Behavior_LP_Unbalanced.sol
    Behavior_Validation.sol
    Behavior_Errors.sol
  CommonBufferMultiVaultStablePool.spec.t.sol
  CommonBufferMultiVaultStablePool.invariant.t.sol
  Handler_CommonBufferMultiVaultStablePool.sol
  formula/
    CommonBufferMultiVaultStable_FormulaEquivalence.t.sol
  adversarial/
    TestBase_CommonBufferMultiVaultStable_Adversarial.sol
    Adversarial_CustomDrain.t.sol
    Adversarial_Donation.t.sol
    Adversarial_ResidualBuffer.t.sol
    Adversarial_Reentrancy.t.sol
```

**TestBase inheritance (intended):**  
`CraneTest` → `IndexedexTest` → vault components / Balancer SE stack → SE protocol TestBase → `TestBase_CommonBufferMultiVaultStablePool`.

---

## 3. Math, routing, and state (normative for implementers)

### 3.1 Token kinds and indexing

After Balancer address-sort, store:

```text
vaultCount N, tokenCount T = 1 + N
bufferIndex, shareIndex[i]
```

`TokenKind { Buffer, Share }` — no Unpaired.

### 3.2 Derived share depth

Same construction as weighted CommonBuffer:

```text
actual = balancesLiveScaled18[shareIndex[i]]
if hookShareDelta[i] <= 0:
  depth = actual + liftToScaled18Rated(|delta|, shareIndex[i])
else:
  depth = max(0, actual - liftToScaled18Rated(delta, shareIndex[i]))
```

### 3.3 Math balances for StableMath

```text
balances[bufferIndex] = virtualBuffer
balances[shareIndex[i]] = derivedShareDepth(i, balancesLiveScaled18)
```

### 3.4 Ranking

```text
score(i) = derivedShareDepth(i)
deposit preference: lower score first; ties → lower index
redeem preference:  higher score first; ties → lower index
```

### 3.5 Amplification

- Store amp with AMP_PRECISION multiplier (Crane Stable pattern).
- v1: startValue == endValue; no start/stop update functions on public surface (or leave unimplemented/revert).
- `onSwap` / invariant / computeBalance read **current** amp (constant when not updating).

### 3.6 Pre-seat quote

```text
// EXACT_IN path sketch
feeAmount = amountGiven * staticSwapFee / 1e18  (ceil as peer)
amountAfterFee = amountGiven - feeAmount
invariant = StableMath.computeInvariant(amp, mathBalances)
yOut = StableMath.computeOutGivenExactIn(amp, mathBalances, indexIn, indexOut, amountAfterFee, invariant)
// for buffer-out pre-seat, indexOut == bufferIndex; yOut is scaled18 buffer needed
```

Do **not** call WeightedMath.

### 3.7 SE I/O (peer shape)

- Pre-seat: `previewExchangeOut` → drain shares via vault custom remove / hook path → `exchangeOut`.
- Reconcile: pull physical buffer → `exchangeIn` into ranked vault → donate minted shares + adjust `hookShareDelta`.
- External-self `try/catch` pattern from CommonBuffer HookTarget for walk without poisoning whole tx until all fail.

---

## 4. Implementation phases

### Phase 0 — Docs ✅

- [x] PRD locked  
- [x] This implementation plan  
- [x] Adversarial P0 covered in suite (catalog doc optional)

### Phase 1 — Interface + Repo + Common ✅

**Deliverables:**

- [x] `ICommonBufferMultiVaultStablePool.sol` — errors, views, TokenKind, routing views, amp views  
- [x] `…Repo.sol` — storage slot namespaced to this product; layout + amp + virtuals + deltas  
- [x] `…Common.sol` — rates lift, derived depth, math balances, rank deposit/redeem  

### Phase 2 — Target + Facet (StableMath) ✅

- [x] `…Target.sol` — StableMath `onSwap` / invariant / `computeBalance`  
- [x] `…Facet.sol` — IFacet + shallowest/deepest/derived depth/amp views  
- [x] Formula equivalence suite green

### Phase 3 — Liquidity + CUSTOM ✅

- [x] Liquidity Target/Facet; `NotHookCaller` tests green

### Phase 4 — HookTarget register + init ✅

- [x] Register/init seed virtualBuffer; N=1 smoke green

### Phase 5 — HookTarget swap + LP SE I/O ✅

- [x] Pre-seat/reconcile walk; StableMath quote; LP; eventual-zero; N=2 fan-out ≠ leg

### Phase 6 — DFPkg + FactoryService ✅

- [x] StandardVault DFPkg (`PkgInit`/`PkgArgs` on interface); S9 checks; CREATE3 + registry path; N=1..3

### Phase 7 — Gold TestBase + suite ✅

- [x] TestBase + spec (N=1/2/3) + formula + adversarial P0 hermetic suite green (37 tests)

### Phase 8 — Polish ✅

- [x] Role names; forge fmt; Stable invariant ratios 60e16/500e16

---

## 5. DFPkg sketch (normative constraints)

```solidity
interface ICommonBufferMultiVaultStablePoolPkg is IDiamondFactoryPackage, IStandardVaultPkg {
    struct PkgInit {
        // facets: basicVault, standardVault, vaultAware, poolToken, poolInfo,
        // swapFeeBounds, unbalancedLiquidityInvariantRatioBounds (Stable ratios),
        // authentication, poolFacet, liquidityFacet, hookFacet
        // vaultRegistry, feeOracle, balancerV3Vault, diamondFactory
        // rateProviderPkg — present but never auto-used on zero args
    }

    struct PkgArgs {
        IERC20 bufferToken;
        uint8 vaultCount; // 1..3
        IStandardExchange[] standardExchangeVaults;
        IRateProvider[] vaultShareRateProviders; // 0 => STANDARD
        uint256 amplificationParameter;
    }
}
```

**Invariant ratio bounds facet:** must expose StableMath `MIN_INVARIANT_RATIO` / `MAX_INVARIANT_RATIO` (60e16 / 500e16), not weighted standard bounds. Prefer a shared stable-bounds facet if one exists; otherwise package-local facet copying Crane stable constants.

---

## 6. Porting checklist from weighted CommonBuffer

| Weighted CommonBuffer piece | Action |
|-----------------------------|--------|
| Unpaired loops / TokenKind.Unpaired | **Delete** |
| `weights[]` / `_weight` / InvalidWeights | **Delete** |
| `_score = d * 1e18 / w` | **Replace** with `d` only |
| Tie-break larger weight | **Replace** with index only |
| WeightedMath onSwap / quote | **Replace** with StableMath + amp |
| Unbalanced ratio bounds | **Replace** with Stable ratios |
| Optional RP policy | **Keep** (same S4/L17 spirit) |
| Virtual buffer + hookShareDelta | **Keep** |
| Always-route walk SE I/O | **Keep** (shallowest/deepest naming) |
| Buffer-only remove disallowed | **Keep** |
| Eventual-zero | **Keep** |
| DFPkg registry path | **Keep** |
| Subclass weighted contracts | **Forbidden** |

---

## 7. Risks during implementation

| Risk | Mitigation |
|------|------------|
| Accidental WeightedMath import in quote | Code review + formula tests use StableMath |
| Amp slot collision with Crane stable repo | Package-owned STORAGE_SLOT string unique to this product |
| Stack-too-deep in hooks | Extract helpers; viaIR if needed |
| Rate=0 on WITH_RATE | Revert RateProviderZero like peer |
| N=1 edge ranking | Single-element order always |

---

## 8. Definition of done

1. PRD S1–S27 implemented.  
2. Deploy path: CREATE3 facets + manager `deploy*DFPkg` + instance via registry.  
3. Hermetic tests green for N=1,2,3 covering routing, swaps, LP, formula, adversarial P0.  
4. No mocks of SUT; real SE vaults from protocol TestBases.  
5. NatSpec + role naming compliance.  
6. `forge fmt` clean on package + tests.

---

## Document control

| Item | Value |
|------|--------|
| Plan path | `./CommonBufferMultiVaultStablePool_IMPLEMENTATION_AND_TEST_PLAN.md` |
| PRD | `./CommonBufferMultiVaultStablePool_PRD.md` |
| Status | **IMPLEMENTED** (hermetic suite green) |
