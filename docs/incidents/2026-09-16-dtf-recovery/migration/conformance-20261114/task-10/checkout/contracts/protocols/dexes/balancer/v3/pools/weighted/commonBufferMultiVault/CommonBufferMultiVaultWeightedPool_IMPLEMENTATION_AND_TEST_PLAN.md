# CommonBufferMultiVaultWeightedPool — Implementation and Testing Plan

## Purpose

Execute the [PRD](./CommonBufferMultiVaultWeightedPool_PRD.md): implement a **fixed-weight Balancer V3 pool** with:

- **Exactly one** shared `bufferToken` consolidated into **N ≥ 1** Standard Exchange vaults (one-to-many),
- **Optional unpaired** (non-buffered) legs,
- **Always-route** fan-out: deposit to most underweight vault, redeem from most excess vault (not implied by the swap’s share leg),
- **Walk next vault** on SE I/O failure,
- Token count \(T = U + 1 + N\) with \(2 \le T \le 8\).

This plan is ordered for incremental delivery: each phase leaves a green, reviewable slice.

## Status

**IMPLEMENTED** — production package + hermetic tests green (28 tests: U=0 N=1/N=2, unpaired, formula, adversarial P0).

| Field | Value |
|-------|--------|
| PRD | `CommonBufferMultiVaultWeightedPool_PRD.md` (**LOCKED** L1–L29) |
| Package path | `contracts/protocols/dexes/balancer/v3/pools/weighted/commonBufferMultiVault/` |
| Behavioral references | `constProd/standardExchange/`, `weighted/multiPairBuffer/`, `weighted/mixedLegBuffer/` |
| Tests root (intended) | `test/foundry/spec/protocols/dexes/balancer/v3/pools/weighted/commonBufferMultiVault/` |

### Locked decisions (summary from PRD)

| Topic | Decision |
|-------|----------|
| Layout | \(T = U + 1 + N\), \(2 \le T \le 8\); always one buffer; \(N \ge 1\); unpaired optional |
| Curve | Fixed-weight `WeightedMath` (not Stable) |
| Routing | Always most underweight deposit / most excess redeem (L6–L7) |
| Need score | \(d_i / w_i\) (derived share depth / share weight) |
| Ties | Larger \(w_i\), then lowest vault index (L20) |
| Runtime I/O fail | Walk next vault by score; revert only if all fail (L21) |
| Deploy vault check | Accept + produce `bufferToken` via `IStandardVault` config (L8) |
| Init | All legs non-zero; `virtualBuffer` = buffer scaled18 seed (L26) |
| LP | Proportional + unbalanced **add**; **no** buffer-only unbalanced **remove** (L23) |
| Residual | Eventual-zero physical buffer (L25) |
| v1 test bar | Formula + routing + conservation — not naive full-history comparative (L24) |
| Extra underlyings | Vaults may hold tokens beyond buffer if L8 holds (L27) |
| Share rate providers | **Optional, user-only (L17 revised):** `address(0)` ⇒ STANDARD, no auto-deploy SE RP; non-zero ⇒ WITH_RATE + user RP |
| Unpaired rate providers | Optional: `address(0)` ⇒ STANDARD; non-zero ⇒ WITH_RATE |
| Buffer rate provider | Never (always STANDARD) |
| Deploy | CREATE3 facets; Vault Registry DFPkg; hooks on pool diamond |
| Parallel forever | Do not subclass MultiPair / MixedLeg / Single targets |

---

## 1. Goals and non-goals

### Goals

1. Ship production Diamond pool + hooks + CUSTOM liquidity under `weighted/commonBufferMultiVault/`.
2. Support configs: `U=0,N=1` (bridge); `U=0,N≥2` (pure multi-vault); `U>0,N≥1` (mixed unpaired).
3. Implement **always-route** scoring, **L20** ties, **L21** walk, and SE I/O parity with single/multi-pair (preview-aligned pre-seat; best-effort deposit).
4. Prove **formula equivalence**: `onSwap` / invariant / `computeBalance` match `WeightedMath` on the math balance vector.
5. Prove **routing + conservation**: correct ranking/walk; no free BPT; virtual ≥ 0; eventual-zero physical buffer; unpaired never virtualized.
6. Production-first tests; no mocks of SUT pool / manager / registry / SE vaults under test.
7. Adversarial P0: CUSTOM drain, hook access, donation, residual, reentrancy probe (catalog in § Phase 6b).

### Non-goals

- Replacing or subclassing MultiPair / MixedLeg / single SE buffer packages.
- Implied-leg vault selection (explicitly rejected by L6).
- Naive full-history comparative parity vs a reference weighted pool after fan-out (L24).
- Buffer-only unbalanced remove (L23).
- **Auto-deploying default Standard Exchange rate providers** when user passes `address(0)` (L17) — unlike MultiPair/single buffer package defaults.
- DETF seigniorage / bond / claim; special router; mainnet deploy scripts (follow-up).
- Rate-scaled multi-token effective weights; Stable/Gyro curves.
- Shared pure lib extraction from peers (optional later once this package is stable).

---

## 2. Naming and layout

### Source

```text
contracts/protocols/dexes/balancer/v3/pools/weighted/commonBufferMultiVault/
  CommonBufferMultiVaultWeightedPool_PRD.md
  CommonBufferMultiVaultWeightedPool_IMPLEMENTATION_AND_TEST_PLAN.md  # this file
  ICommonBufferMultiVaultWeightedPool.sol
  CommonBufferMultiVaultWeightedPoolRepo.sol
  CommonBufferMultiVaultWeightedPoolCommon.sol
  CommonBufferMultiVaultWeightedPoolTarget.sol
  CommonBufferMultiVaultWeightedPoolFacet.sol
  CommonBufferMultiVaultWeightedPoolHookTarget.sol
  CommonBufferMultiVaultWeightedPoolHookFacet.sol
  CommonBufferMultiVaultWeightedPoolLiquidityTarget.sol
  CommonBufferMultiVaultWeightedPoolLiquidityFacet.sol
  CommonBufferMultiVaultWeightedPoolStandardVaultPkg.sol   # PkgInit/PkgArgs on interface
  CommonBufferMultiVaultWeightedPool_FactoryService.sol
  # optional later:
  # CommonBufferMultiVaultWeightedPool_ADVERSARIAL_TEST_PLAN.md
```

**Type names:** full words (`CommonBuffer`, `MultiVault`, `WeightedPool`).  
**Roles:** `bufferToken`, `unpairedToken`, `standardExchangeVault`, `vaultShare`, `virtualBuffer`, `hookShareDelta`.  
**Forbidden:** product tickers; `TTA`/`tta` as role names; brand names; `WETH` as a generic role.

### Tests

```text
test/foundry/spec/protocols/dexes/balancer/v3/pools/weighted/commonBufferMultiVault/
  bases/
    TestBase_CommonBufferMultiVaultWeightedPool.sol
    TestBase_CommonBufferMultiVault_UniV2.sol          # hermetic SE legs
  behaviors/
    Behavior_Registration.sol
    Behavior_Initialization.sol
    Behavior_Routing.sol                              # scores, ties, walk order
    Behavior_Swap_BufferShare.sol
    Behavior_Swap_ShareShare.sol
    Behavior_Swap_Unpaired.sol
    Behavior_LP_Proportional.sol
    Behavior_LP_Unbalanced.sol                        # buffer add OK; buffer-only remove reverts
    Behavior_Validation.sol                           # L8, uniqueness, counts
    Behavior_Errors.sol
  CommonBufferMultiVaultWeightedPool.spec.t.sol
  CommonBufferMultiVaultWeightedPool.invariant.t.sol
  Handler_CommonBufferMultiVaultWeightedPool.sol
  CommonBufferMultiVaultWeightedPoolLiquidityTarget.t.sol
  formula/
    CommonBufferMultiVault_FormulaEquivalence.t.sol   # WeightedMath parity on math vector
  adversarial/
    TestBase_CommonBufferMultiVault_Adversarial.sol
    Adversarial_CustomDrain.t.sol
    Adversarial_Donation.t.sol
    Adversarial_ResidualBuffer.t.sol
    Adversarial_Reentrancy.t.sol
```

**TestBase inheritance (intended):**  
`CraneTest` → `IndexedexTest` → vault components / Balancer SE router stack → SE buffer TestBase peers (`TestBase_StandardExchangeBufferPool` or MixedLeg/MultiPair gold bases) → `TestBase_CommonBufferMultiVaultWeightedPool`.

---

## 3. Math, routing, and state (normative for implementers)

### 3.1 Token kinds and indexing

After Balancer address-sort, store:

```text
unpairedCount U, vaultCount N
unpairedIndex[j], bufferIndex, shareIndex[i]
```

Resolution helper (public view):

```text
resolveTokenIndex(t) -> (TokenKind kind, uint256 legIndex)
  Unpaired | Buffer | Share
```

### 3.2 Math balance vector \(B_t\)

| Kind | Math balance |
|------|----------------|
| Unpaired `j` | `balancesLiveScaled18[unpairedIndex[j]]` (physical only) |
| Buffer | `virtualBuffer` (scaled18) — **single** common virtual |
| Share `i` | `derivedShareDepth[i]` = live scaled18 shares ± lift(`hookShareDelta[i]`) |

Weights: immutable `weights[t]`, \(\sum w = 1e18\), each \(w \ge 1e16\).

Use Balancer `WeightedMath` for invariant, `onSwap`, `computeBalance`.

**Invariant ratio bounds:** normal weighted pool min/max (70e16 / 300e16) — same as MultiPair/MixedLeg, not identity.

### 3.3 Need score and ranking (L7, L20)

For each vault `i`:

\[
s_i = \frac{d_i}{w_i}
\quad\text{where } d_i = \text{derivedShareDepth}(i),\ w_i = \text{weight}(\text{shareIndex}[i])
\]

**Deposit order** (most needed first): ascending \(s_i\); ties → **larger \(w_i\)**, then **lower \(i\)**.  
**Redeem order** (most excess first): descending \(s_i\); ties → **larger \(w_i\)**, then **lower \(i\)**.

Implement pure helpers (testable without SE I/O):

```text
_score(i, balancesLiveScaled18) -> uint256   // d_i * 1e18 / w_i or mulDiv; document zero-weight impossible by L9
_rankDeposit(balances) -> uint8[N] ordered
_rankRedeem(balances)  -> uint8[N] ordered
mostNeededVault() / mostExcessVault()        // public views using live Vault balances
```

**Division:** use `Math.mulDiv` carefully; if \(w_i = 0\) should already be impossible. Prefer score in 1e18-scaled fixed point: `mulDiv(d_i, 1e18, w_i)`.

### 3.4 Always-route + walk (L6, L21)

**Never** select vault from the swap’s share token index.

When buffer must leave the pool (pre-seat for buffer out):

```text
ranks = rankRedeem(liveBalances)
for v in ranks:
  try pre-seat from vault v (preview-aligned exchangeOut)
  if success: record pendingPreSeat vault + S; break
if none succeeded: revert PreSeatRedemptionFailed / AllVaultsExhausted
```

When buffer must enter vaults (reconcile for buffer in, or buffer-only LP add):

```text
ranks = rankDeposit(liveBalances)
for v in ranks:
  try exchangeIn full physical buffer amount into vault v
  if success: DONATE shares, CUSTOM remove buffer, update virtual + hookShareDelta[v]; break
if none succeeded: revert PostSwapDepositFailed / AllVaultsExhausted
```

**Gas:** walk at most `N` attempts; N ≤ 7.

### 3.5 Initialization (L26)

On `onBeforeInitialize(exactAmountsInScaled18, …)`:

```text
require every unpaired, buffer, and share seed > 0
virtualBuffer = exactAmountsInScaled18[bufferIndex]
for i in 0..N-1: hookShareDelta[i] = 0
```

### 3.6 Post-swap math updates

After successful swap (fee-consistent with Vault):

```text
B[tokenIn]  += amountInScaled18   // via virtual / derived / physical unpaired
B[tokenOut] -= amountOutScaled18
```

| tokenIn kind | After hooks |
|--------------|-------------|
| buffer | `virtualBuffer += amountInScaled18` during reconcile (physical cleared → eventual-zero) |
| share | derived depth follows live ± delta; deposit walk may mint into **different** vault \(i^\*\) — deltas must restore **math** vector consistency for **all** share legs touched by reshape |
| unpaired | physical only |

| tokenOut kind | After hooks |
|---------------|-------------|
| buffer | `virtualBuffer -= amountOutScaled18` after pre-seat delivery |
| share | derived depth falls as user takes shares |
| unpaired | physical only |

**Critical always-route bookkeeping:**  
When deposit walk mints shares into vault \(i^\* \neq\) tokenOut share, the hook must still leave the **AMM math vector** equal to post-swap WeightedMath balances. Pattern (mirror MultiPair reconcile intent, generalized):

1. User swap settles against math balances (virtual + derived).  
2. Physical SE reshape (redeem/deposit + DONATE + CUSTOM) adjusts **raw** inventory.  
3. `hookShareDelta` on **touched** vaults offsets reshape so **derived** depths match the intended post-swap math balances.  
4. Non-touched share legs’ derived depths unchanged.

Document the exact delta updates in NatSpec when implementing Phase 3; unit tests assert math vector after buffer↔share and buffer↔unpaired.

### 3.7 Pre-seat (buffer out) — L22 + L21

Generalize single-buffer shares→buffer for **chosen** vault \(v\) from redeem ranking:

1. Quote buffer amount Vault will deliver \(Y\) (fee-adjusted weighted out).  
2. `S = vault_v.previewExchangeOut(share_v, bufferToken, Y)`; BV3 rate round-trip helpers for drain size.  
3. Drain shares of \(v\) from Balancer → `exchangeOut` → settle buffer → DONATE buffer → CUSTOM remove shares; set `hookShareDelta[v]` so derived depth of \(v\) is correct for `onSwap`.  
4. Defer `virtualBuffer -= actualOut` to `onAfterSwap`.  
5. On failure of \(v\), clear partial side effects if any (prefer atomic try or check preview before mutating), then walk next rank.

### 3.8 Reconcile (buffer in) — L22 + L21

1. Drain physical `bufferToken` amount \(X\) from pool.  
2. Walk deposit ranking: `exchangeIn` full \(X\) into vault \(v\) → mint \(M\) shares.  
3. DONATE \(M\); CUSTOM remove buffer;  
   `virtualBuffer += X_scaled18`;  
   adjust `hookShareDelta[v]` so derived depth of \(v\) matches math intent (net-zero free depth from donation).  
4. If all vaults fail → revert.

### 3.9 Paths with no buffer I/O

- Share ↔ share  
- Unpaired ↔ share  
- Unpaired ↔ unpaired  

No SE calls; math uses derived/physical balances only.

### 3.10 LP bookkeeping

**Proportional add/remove:** scale `virtualBuffer` and every `hookShareDelta[i]` by BPT ratio (signed). Unpaired physical handled by Balancer.

**Unbalanced add (L12):**

- Buffer-only add: after Balancer settlement, **reconcile** physical buffer via deposit walk (\(i^\*\)); grow virtual accordingly.  
- Share-only / unpaired-only: no buffer fan-out; derived/physical grow with live balances.  
- **DONATION** from hook reconcile: **no** extra virtual bump (avoid double-count).

**Unbalanced remove (L23):**

- If remove is **buffer-only** (only buffer token out, unbalanced): **revert** with dedicated error e.g. `BufferOnlyRemoveDisallowed`.  
- Proportional remove: allowed (scales virtual + deltas).  
- Share-side or unpaired unbalanced remove: allowed per Balancer + peer patterns.

### 3.11 Eventual-zero physical buffer (L25)

After successful swap/LP paths that involve buffer, assert physical `bufferToken` balance of pool ≈ 0 (allow documented ≤ few-wei if BV3 round-trip forces dust; prefer exact zero).

---

## 4. Package / deploy surface

### 4.1 Interface structs (on interface, not contract body)

```solidity
interface ICommonBufferMultiVaultWeightedPoolPkg is IDiamondFactoryPackage, IStandardVaultPkg {
    struct PkgInit {
        IFacet basicVaultFacet;
        IFacet standardVaultFacet;
        IFacet balancerV3VaultAwareFacet;
        IFacet betterBalancerV3PoolTokenFacet;
        IFacet defaultPoolInfoFacet;
        IFacet standardSwapFeePercentageBoundsFacet;
        IFacet unbalancedLiquidityInvariantRatioBoundsFacet;
        IFacet balancerV3AuthenticationFacet;
        IFacet bufferPoolFacet;
        IFacet poolLiquidityFacet;
        IFacet hookFacet;
        IVaultRegistryDeployment vaultRegistry;
        IVaultFeeOracleQuery vaultFeeOracle;
        IVault balancerV3Vault;
        IDiamondPackageCallBackFactory diamondFactory;
        // Optional: may omit if package never deploys RPs (L17). Keep only if useful for
        // out-of-band helper deploys; processArgs MUST NOT auto-deploy when user passes address(0).
        IStandardExchangeRateProviderDFPkg rateProviderPkg;
    }

    struct PkgArgs {
        uint8 unpairedCount;
        IERC20[] unpairedTokens;
        IRateProvider[] unpairedRateProviders; // 0 => STANDARD; non-zero => WITH_RATE + RP

        IERC20 bufferToken;
        uint8 vaultCount; // >= 1; unpairedCount + 1 + vaultCount in [2, 8]
        IStandardExchange[] standardExchangeVaults;
        // vaultShareRateProviders: 0 => STANDARD (NO default SE RP deploy); non-zero => WITH_RATE + user RP
        IRateProvider[] vaultShareRateProviders;

        // length == T = unpairedCount + 1 + vaultCount; Balancer address-sorted order
        uint256[] weights;
        // optional: swapFeePercentage; 0 => package default
    }

    function deployPool(PkgArgs calldata args) external returns (address pool);
}
```

**Weight ordering:** weights **must** be in Balancer address-sorted final token order. Document and test; reject wrong length/sum.

### 4.2 Validation (deploy / `processArgs` / register)

| Check | Rule |
|-------|------|
| Counts | `vaultCount ≥ 1`; `2 ≤ U + 1 + N ≤ 8`; array lengths match |
| Uniqueness | Distinct vaults/shares; unique pool token addresses; unpaired ≠ buffer ≠ any share |
| L8 accept+produce | For each vault: `IStandardVault(vault).vaultConfig().tokens` (or project equivalent) **contains** `bufferToken`. Reject if missing. |
| Vault-as-share | `vaultShare[i] = address(vault[i])` when SE uses vault-as-share (match peers) |
| Weights | length T; each ≥ 1e16; sum == 1e18 |
| Rate providers | Share: 0 ⇒ STANDARD (**no** auto-deploy SE RP); non-zero ⇒ WITH_RATE + user RP. Unpaired: same. Buffer: never RP (L17) |

**Implementation note for L8:** If `vaultConfig().tokens` is the canonical list of tokens the vault accepts/produces, membership is sufficient. Prefer a small helper `_vaultAcceptsAndProducesBuffer(vault, bufferToken)` used by pkg + tests. If multi-asset vaults list underlyings there, L27 is satisfied as long as buffer is present.

### 4.3 Registration

- TokenConfig: unpaired STANDARD/WITH_RATE per user RP; buffer STANDARD; each share STANDARD if RP zero else WITH_RATE + user RP (**never** auto-deploy default SE RP).  
- LiquidityManagement: unbalanced **enabled** (buffer-only remove enforced in hooks, not by disabling all unbalanced); custom add/remove **enabled**; donation **enabled**.  
- **Hook Facet MUST be in pool proxy** `facetCuts`; **`hooksContract = pool`**.  
- Static swap fee: pool-wide default (peer e.g. 0.05%) unless override.

### 4.4 FactoryService

Mirror MultiPair / MixedLeg / single buffer:

- CREATE3 facet deploys via `create3Factory`  
- `indexedexManager.deployCommonBufferMultiVaultWeightedPoolDFPkg(PkgInit)` (or typed name) via vault registry  

Never `new` facets/DFPkgs.

---

## 5. Phased implementation

> Checkbox tasks for agents. Prefer green tests after each phase when implementing.

### Phase 0 — Scaffold (no behavior)

- [ ] **P0.1** `ICommonBufferMultiVaultWeightedPool`: errors, `TokenKind`, views (`unpairedCount`, `vaultCount`, `bufferToken`, vaults/shares, `virtualBuffer`, `hookShareDelta`, `weight`, `resolveTokenIndex`, `mostNeededVault`, `mostExcessVault`, `depthPerWeight`).
- [ ] **P0.2** Repo storage layout (document slot string; append-only after first ship).
- [ ] **P0.3** Facet/Target/Hook/Liquidity stubs + IFacet metadata. Hook facet in diamond set.
- [ ] **P0.4** DFPkg skeleton: `PkgInit`/`PkgArgs` on interface; facetCuts include `hookFacet`; `postDeploy` `hooksContract = proxy`.
- [ ] **P0.5** FactoryService skeleton.
- [ ] **P0.6** `forge build` includes new files.

### Phase 1 — Registration + init + validation

- [ ] **P1.1** Deploy validation: counts, uniqueness, weights, L8 `IStandardVault` membership.
- [ ] **P1.2** `onRegister`: token types, LM flags, factory, `pool == address(this)`, layout matches stored config.
- [ ] **P1.3** `initAccount` / `updatePkg` / `postDeploy` register with Balancer; assert hooks on self.
- [ ] **P1.4** `onBeforeInitialize`: L26 all non-zero seeds; set `virtualBuffer`; zero deltas.
- [ ] **P1.5** TestBase: deploy **U=0,N=1** hermetic SE; register + init green.
- [ ] **P1.6** Negatives: N=0 reject; T>8 reject; T<2 reject; duplicate vault; unpaired==buffer; vault missing buffer in config; zero weight; bad weight sum; zero init seed.

### Phase 2 — Math + routing pure logic

- [ ] **P2.1** Common: rate lift, derived share depth, math balance vector (unpaired + virtual + derived), BV3 round-trips.
- [ ] **P2.2** Target: `computeInvariant`, `computeBalance`, `onSwap` via WeightedMath.
- [ ] **P2.3** Routing: score, rank deposit/redeem, L20 tie-break, public views.
- [ ] **P2.4** Tests: formula unit on seeded pool; routing unit with controlled depths/weights (may use real pool state after init); tie cases (equal score, different weights).

### Phase 3 — Buffer hooks (U=0, N=1 first)

- [ ] **P3.1** Pre-seat buffer out (single vault walk trivial).
- [ ] **P3.2** Reconcile buffer in (best-effort deposit).
- [ ] **P3.3** Router prepay auth pass/restore if peer single buffer requires it.
- [ ] **P3.4** Swaps buffer↔share both EXACT_IN directions; preview≈execution where closed-form; eventual-zero physical buffer.
- [ ] **P3.5** Failures: pre-seat fail, deposit fail (N=1 ⇒ immediate revert after walk).

### Phase 4 — Multi-vault always-route + walk (U=0, N≥2)

- [ ] **P4.1** Deposit always targets most underweight (assert vault inventory / delta movement), even when tokenOut is a different share.
- [ ] **P4.2** Redeem always sources most excess for buffer out.
- [ ] **P4.3** Share↔share: no SE I/O.
- [ ] **P4.4** Walk: force top vault pre-seat to fail (e.g. empty share inventory on that leg while second has inventory) → second succeeds; all fail → revert.
- [ ] **P4.5** Full-graph sample for N=2 and N=3 (all token pairs EXACT_IN smoke).
- [ ] **P4.6** Math-vector conservation after always-route reshape (assert derived depths + virtual match WeightedMath post-trade intent).

### Phase 5 — Unpaired legs (U>0)

- [ ] **P5.1** Deploy U=2,N=1 and U=2,N=2 layouts.
- [ ] **P5.2** Swaps unpaired↔buffer, unpaired↔share, unpaired↔unpaired.
- [ ] **P5.3** Optional unpaired WITH_RATE (non-zero RP) smoke; hermetic defaults use `address(0)` (STANDARD).
- [ ] **P5.3b** Share legs with `vaultShareRateProviders[i] == 0` register as STANDARD; with non-zero user RP register as WITH_RATE; assert package does **not** deploy an SE RP when arg is zero.
- [ ] **P5.4** Unpaired never receives virtual accounting; physical only.

### Phase 6 — LP

- [ ] **P6.1** Proportional add/remove: scale virtual + all deltas.
- [ ] **P6.2** Unbalanced buffer **add** → deposit walk + virtual grow.
- [ ] **P6.3** Unbalanced buffer-only **remove** → **revert** `BufferOnlyRemoveDisallowed` (L23).
- [ ] **P6.4** Share-side / unpaired unbalanced add/remove smoke.
- [ ] **P6.5** DONATION no free BPT / no double virtual.

### Phase 6b — Adversarial P0 (security gate)

Method: `crane-adversarial-testing` + `indexedex-adversarial-testing`. Optional: extract full ADVERSARIAL_TEST_PLAN.md if catalog grows.

| ID | Case | Pass |
|----|------|------|
| D1 | CUSTOM remove as external router | `NotHookCaller` |
| D2 | CUSTOM add as external | `NotHookCaller` |
| A3 | Donation does not mint free BPT / free virtual | balances consistent |
| E7 | Eventual-zero physical buffer after happy swaps | ≈0 |
| F3 | hooksContract == pool; no external hooks | register assert |
| C1 | Reentrancy via hostile ERC20 as share (if peer pattern fits) | `IsLocked` / safe |
| W1 | Walk exhausts all vaults | hard revert, no partial free mint |
| R1 | Buffer-only unbalanced remove | revert L23 |

- [ ] **Adv-0** Scaffold adversarial TestBase.  
- [ ] **Adv-1** D1/D2, A3, E7, F3, W1, R1 green.  
- [ ] **Adv-2** C1 if feasible with real SE share token hostility constraints; else document deferral.

### Phase 7 — Formula suite + invariants + max-T smoke

- [ ] **P7.1** Formula equivalence suite: for fixed math vector, pool `onSwap`/invariant match pure WeightedMath (L24).
- [ ] **P7.2** Handler/invariant: random full-graph swaps + LP (respect L23); virtual ≥ 0; eventual-zero buffer; no free BPT.
- [ ] **P7.3** Max layout smokes: `U=0,N=7` and `U=5,N=2` (T=8) deploy + single swap.
- [ ] **P7.4** Optional rate stress: trade SE underlyings; assert hooks/safety only — **no** reference parity (L19).
- [ ] **P7.5** Gas notes for N=7 walk worst-case (optional snapshot).

### Phase 8 — Docs / polish

- [ ] **P8.1** NatSpec on routing, walk, L23, L8.  
- [ ] **P8.2** PRD log: mark implementation progress; this plan status → **IMPLEMENTED** when phases green.  
- [ ] **P8.3** CODEBASE_MAP / Agents note only if required by project convention.

---

## 6. Testing policy

| Rule | Detail |
|------|--------|
| Production-first | Real DFPkg, facets, manager registry path, real SE vaults |
| No SUT mocks | Pool diamond, registry, manager, fee oracle, SE under test |
| Protocol ports OK | Crane hermetic Uni/Aero/Camelot ports — not “mocks” |
| Harness OK | Mintable ERC20 funding; reentrancy ERC20 only for attack tests as share |
| Formula (L24) | Required; pure WeightedMath comparison on math vector |
| Naive comparative history | Not required (always-route breaks naive reference) |
| Naming | Role names in tests (`bufferToken`, not brands) |
| Profiles | Hermetic default; fork optional for extra SE types |

### Minimum acceptance matrix

| Case | Pass criterion |
|------|----------------|
| Deploy U=0 N=1 | Register + init |
| Deploy U=0 N=2..3 | Multi-vault routing works |
| Deploy U=2 N=1 | Unpaired + buffer + vault |
| Reject bad layout / L8 / uniqueness | Revert |
| Buffer↔share | Success; eventual-zero buffer; math conservation |
| Always-route | Deposit/redeem vault matches score order (not swap share leg) |
| Walk | Second vault used when first cannot I/O |
| Share↔share / unpaired paths | Success; no erroneous SE I/O |
| Proportional LP | Virtual + deltas scale |
| Buffer-only remove | Revert (L23) |
| Formula suite | Matches WeightedMath |
| NotHookCaller | CUSTOM drain reverts |
| Invariant fuzz | No broken virtuals / free mint |
| Adversarial P0 | D1/D2, A3, E7, F3, W1, R1 |

---

## 7. Risk register

| Risk | Mitigation |
|------|------------|
| Always-route delta bookkeeping wrong → free depth / stuck inventory | Phase 4 math-vector asserts after every buffer path; invariant handler |
| Walk partial state on failed attempt | Preview-first; no storage commit until success; or full revert per attempt |
| Gas on N=7 full walk | Bound N; cheap score; document worst-case |
| Tie-break mismatch tests vs prod | Single shared pure rank function; unit tests for L20 |
| L8 false positive/negative on vaultConfig.tokens | Align with how SE vaults populate `VaultConfig.tokens`; multi-vault hermetic coverage |
| Confusion with MixedLeg 1:1 pairs | Separate package; NatSpec; no subclass |
| Buffer-only remove sneaks through Balancer unbalanced API | Explicit hook check L23; Behavior + Adv R1 |
| Stack-too-deep in hooks | Extract rank/pre-seat/reconcile helpers; viaIR project-wide |
| Equivalence over-claim | Stick to L24; do not add naive comparative asserts that fail under always-route |

---

## 8. Reference file map (peers → this package)

| Peer | This package analogue |
|------|------------------------|
| MixedLeg unpaired math + resolveTokenIndex | Unpaired legs + TokenKind |
| MultiPair fixed WeightedMath + facets/DFPkg | Weighted math, package skeleton |
| MultiPair virtualBuffer[i] / hookShareDelta[i] | **One** `virtualBuffer` + `hookShareDelta[N]` |
| Single buffer pre-seat / reconcile | Same SE I/O, multi-vault select + walk |
| MultiPair implied pair from token | **Replaced** by always-route ranking (L6) |
| MixedLeg 1:1 buffer per pair | **Replaced** by one common buffer |

**Do not** import or inherit concrete MultiPair/MixedLeg Target/Hook contracts. Pattern reuse only (copy-adapt).

---

## 9. Implementation-only decisions (plan defaults)

These are not PRD product questions; implementers should follow unless a plan revision notes otherwise:

| Topic | Default |
|-------|---------|
| Storage slot | `keccak256("indexedex.protocols.balancer.v3.pools.weighted.commonBufferMultiVault")` |
| Max constants | `MAX_VAULTS = 7`, `MAX_UNPAIRED = 6`, `MAX_TOKENS = 8` |
| Score math | `mulDiv(d_i, 1e18, w_i)` uint256; document overflow impossible under BV3 balance bounds or use checked math |
| Error names | Peer style + `BufferOnlyRemoveDisallowed`, `AllVaultsExhausted` (or equivalent) |
| Weight input order | Balancer address-sorted only |
| Default swap fee | Match MixedLeg/MultiPair package constant |
| Vault share address | `address(standardExchangeVault[i])` when vault-as-share |
| Adversarial plan file | Inline § Phase 6b first; split to `*_ADVERSARIAL_TEST_PLAN.md` if catalog expands |

---

## 10. Out of scope follow-ups

- Shared pure routing/math lib used by MultiPair/MixedLeg (after this package is stable).  
- Mainnet `scripts/foundry` staging.  
- Off-chain co-sim comparative harness (optional stronger than L24).  
- Dynamic fees / governance reweight.  
- Multiple common buffer tokens.

---

## 11. Execution checklist (agent entry)

1. Read PRD L1–L29 + this plan §§3–5.  
2. Read peer packages: single buffer hooks, MultiPair Target/Repo, MixedLeg unpaired resolve + DFPkg validation.  
3. Execute Phase 0 → 8 in order; keep production-first.  
4. Do not mark complete without Phase 6b P0 + Phase 7.1 formula suite green.  
5. Update this plan status to **IMPLEMENTED** and PRD living log when done.

---

## Document control

| Item | Value |
|------|--------|
| Plan path | `…/commonBufferMultiVault/CommonBufferMultiVaultWeightedPool_IMPLEMENTATION_AND_TEST_PLAN.md` |
| PRD | `./CommonBufferMultiVaultWeightedPool_PRD.md` |
| Created | 2026-07-20 |
| Status | **NOT STARTED** |
