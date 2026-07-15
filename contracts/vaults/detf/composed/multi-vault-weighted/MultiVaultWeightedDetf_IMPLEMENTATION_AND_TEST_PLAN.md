# MultiVaultWeightedDetf — Implementation and Testing Plan

## Purpose

Execute the [PRD](./MultiVaultWeightedDetf_PRD.md): implement a brand-agnostic **Multi–Standard Exchange Weighted DETF** whose Balancer V3 weighted reserve pairs the DETF share token with **one to seven** Standard Exchange vault share tokens, each valued independently (optional per-leg rate providers).

This plan is ordered for incremental delivery. Each phase leaves a green, reviewable slice. Existing DETF families are **behavioral references only** — do not subclass their concrete contracts.

## Status

**PLANNED** — not started. Locked product decisions include PRD locks plus post-PRD clarifications below.

### Locked decisions (do not re-open without PRD revision)

| Topic | Decision |
|-------|----------|
| Reserve composition | DETF + only Standard Exchange vaults (no bare ERC20 legs in v1) |
| Vault count `N` | `1 ≤ N ≤ 7` SE vaults → up to **8** Balancer weighted-pool tokens |
| Packaging | Single parameterized DFPkg; `N` and per-leg config in package args |
| Weights | Fully custom at deploy; sum exactly `1e18`; each `> 0`; **immutable** |
| Rate providers | Optional per vault; legs never collapse even if rateAssets match |
| User mint / redeem assets | Configured **vault shares** only (and DETF). No rateAsset mint on DETF |
| Share ↔ share on DETF | Out of scope — use Balancer / SE Router on reserve pool |
| Single-sided mint shape | Same as single-vault DETF: weighted pool math + fee/bond split + join |
| Bonding / claim | Full bonding + rebasing claim (behavioral parity with peer DETFs) |
| Liveness | Instance is **live only after the first successful `bond(reserve BPT)`** |
| Pre-live mint | **Cannot mint DETF via vault shares until live** (reserve from first BPT bond) |
| Governance | **No owner. Immutable.** All IndexedEx vaults are immutable |
| Nested vaults | Allowed; any `IStandardExchange` including DETF; opaque to contents |
| Pricing | Weighted reserve pool is the pricing engine; synthetic deadband gates mint/burn |
| Codepath | Fresh under `contracts/vaults/detf/composed/multi-vault-weighted/` |
| Naming | Role names only (`rateAsset`, `pairToken`, `underlyingVault`, …) |
| Deploy path | Facets via CREATE3; DFPkg via **Vault Registry / manager** |
| Testing | **Production-first**; full route + condition coverage; underlying pool trades to shift price |
| Mocks | Forbidden for SUT and production SE attachments; allowed only for narrow scenarios (e.g. reentrancy token) |

### Clarifications (post-PRD)

1. **“Live”** means `isReserveLive == true` after first BPT bond. Do not invent a second “bootstrap mode” product concept. Speak in **inert / pre-live** vs **live**.
2. **Pre-live mint gate:** `exchangeIn` / seigniorage mint with `tokenIn = vaultShare[i]` reverts until live. User-facing “mint with vault shares” is post-live only.
3. **First BPT bond establishes the protocol reserve.** Ongoing bonds may include reserve BPT and configured vault shares (as implemented via `acceptedBondTokens()`). Pre-live, vault-share **user mint** is blocked; first-live path is BPT-centric (see §5 Phase 2 for how BPT is obtained).
4. **Claim surface** is defined by the PRD: sell bond NFT → mint rebasing claim; redeem claim via DETF-orchestrated unwind of protocol-owned reserve BPT → vault share path → **any configured `rateAsset[i]`**. Packaging of the claim token (companion DFPkg vs shared `IRebasingClaimToken` consumer) is an implementation detail; redeem routes and conditions are product requirements.
5. **Tests must move price for real:** execute trades on the **underlying pools of the composed SE vaults** so synthetic price can open mint and burn regimes under default thresholds—not only open-threshold deploy tricks (open thresholds remain valid for pure math paths, but price-shift suites are required).

---

## 1. Goals and non-goals

### Goals

1. Implement `MultiVaultWeightedDetf` under `contracts/vaults/detf/composed/multi-vault-weighted/` per the PRD.
2. Support parameterized `N ∈ [1, 7]` production SE vaults with custom immutable weights and optional per-leg rates.
3. Prove **interface opacity**: production DETF talks only to `IStandardExchange` / share ERC-20 / Balancer weighted reserve — no knowledge of underlying DEX/lending types.
4. Full **bond NFT** lifecycle + **rebasing claim** redeemable to any configured rateAsset.
5. Production-first Foundry coverage of **all token routes and conditions**, including underlying pool trades that shift synthetic price for mint and burn.

### Non-goals (this plan)

- Non-SE ERC20 reserve legs (later mixed-ERC20 family).
- DETF-level rateAsset mint zaps; DETF-level vaultShareᵢ ↔ vaultShareⱼ.
- Off-pool multi-asset FX numeraire.
- Cross-chain bridge / dynamic reweight / `N > 7`.
- Subclassing `composed/single`, `composed/stable/common`, or `standardExchange/single` concrete contracts.
- Production mainnet deploy scripts (follow-up after green integration).
- Fixing unrelated debt in peer DETF families unless it blocks this package.

---

## 2. Behavioral references (what to copy vs invent)

| Reference | Take | Do not copy blindly |
|-----------|------|---------------------|
| **`standardExchange/single`** | Primary shape: inert deploy, weighted reserve, synthetic gate, seigniorage mint/burn, bond NFT, FactoryService + registry deploy, **TestBase pattern** against production SE | Fixed two-token pool; first-bond **vault-share** bootstrap (this family is **BPT-first live**); no multi-leg rates |
| **`composed/single`** | Seigniorage split, reserve join/exit helpers, sellNFT → claim, production base tests | Brand-era names; rateAsset mint surface; bridge |
| **`composed/stable/common`** | Multi-vault deploy hygiene; bond NFT vault + rebasing claim companion packages; IntegratedDeploy graph | Stable intermediate pools; multi-hop stable routing; mock ERC20s in some TestBases (**do not repeat mock legs**) |
| **`detf/core/*`** | Reuse libs: `DETFThresholdPolicy`, `DETFUsageFeeLib`, `DETFMintSplitLib`, `DETFBondLifecycleLib`, `DETFBondNFTMathLib`, `DETFBalancerScaleLib`, `DETFSafeTransferLib`, `DETFPreviewLib` | N/A |
| **`detf/reusable/*`** | `DetfFacetFactoryService`, `DetfPkgFactoryService`, `DetfComponentFactoryService` for NFT / claim package helpers | Brand-specific builders |

### Gold TestBases to inherit / compose (production deploy only)

| Base | Path | Use for |
|------|------|---------|
| Core stack | `contracts/test/IndexedexTest.sol` | Manager + fee collector |
| Vault facets | `contracts/vaults/TestBase_VaultComponents.sol` | Shared ERC20/ERC4626/multi-asset facets |
| Balancer SE router | `contracts/protocols/dexes/balancer/v3/routers/TestBase_BalancerV3StandardExchangeRouter.sol` | Local Balancer vault + SE router + sample Aerodrome SE vaults |
| Camelot SE | `contracts/protocols/dexes/camelot/v2/TestBase_CamelotV2StandardExchange.sol` | Hermetic multi-leg SE vaults |
| Aerodrome SE | `contracts/protocols/dexes/aerodrome/v1/TestBase_AerodromeStandardExchange.sol` | Base-oriented SE |
| Aave Stata SE | `contracts/test/bases/TestBase_AaveV3StataStandardExchange.sol` | Lending SE leg |
| Single SE DETF | `contracts/vaults/detf/standardExchange/single/TestBase_SingleStandardExchangeDETF.sol` | Pattern for DETF package deploy + helpers (do not subclass for production; mirror structure) |
| Dual-liquidity (fork) | `test/foundry/fork/base_main/vaults/protocol/uniswap/crossVersion/TestBase_DualLiquidityLinkedCrossVersionUniswapVault.sol` | Nested SE / fork matrix |
| Composed stable integrated | `test/foundry/spec/vaults/detf/composed/stable/common/ComposedStableCommonDetf_IntegratedDeploy.t.sol` | Nested DETF-as-leg pattern (production graph only) |

**Inheritance chain for this family’s TestBase:**

```text
CraneTest
  └── IndexedexTest
        └── TestBase_VaultComponents
              └── TestBase_BalancerV3StandardExchangeRouter   # (or protocol SE bases as mixins)
                    └── TestBase_MultiVaultWeightedDetf        # THIS family
                          └── suites / N-leg adapters
```

Always call parent `setUp()` in correct override order. Facets via `create3Factory`; vault DFPkgs via `indexedexManager.deploy*DFPkg` / registry `deployPkg`.

---

## 3. Naming and layout

### Production source

```text
contracts/vaults/detf/composed/multi-vault-weighted/
  MultiVaultWeightedDetf_PRD.md
  MultiVaultWeightedDetf_IMPLEMENTATION_AND_TEST_PLAN.md   # this file
  MultiVaultWeightedDetfRepo.sol
  MultiVaultWeightedDetfCommon.sol
  MultiVaultWeightedDetfExchangeInTarget.sol
  MultiVaultWeightedDetfExchangeInFacet.sol
  MultiVaultWeightedDetfExchangeOutTarget.sol
  MultiVaultWeightedDetfExchangeOutFacet.sol
  MultiVaultWeightedDetfExchangeQueryTarget.sol
  MultiVaultWeightedDetfExchangeQueryFacet.sol
  MultiVaultWeightedDetfInfoTarget.sol
  MultiVaultWeightedDetfInfoFacet.sol
  MultiVaultWeightedDetfBondingTarget.sol
  MultiVaultWeightedDetfBondingFacet.sol
  MultiVaultWeightedDetfClaimTarget.sol          # if claim redeem orchestration is a separate facet
  MultiVaultWeightedDetfClaimFacet.sol           # optional split for size
  MultiVaultWeightedDetfDFPkg.sol                # IMultiVaultWeightedDetfDFPkg: PkgInit/PkgArgs IN interface
  MultiVaultWeightedDetf_Facet_FactoryService.sol
  MultiVaultWeightedDetf_Pkg_FactoryService.sol
  MultiVaultWeightedDetf_Component_FactoryService.sol
  TestBase_MultiVaultWeightedDetf.sol
  # Optional: claim/bond companion only if not reusing protocol packages via Detf*FactoryService
```

**Type names:** full words (`MultiVaultWeightedDetf`, never `MVW` / `SE` in type names).  
**Locals:** `vault_`, `share_`, `rateAsset_` OK for stack.  
**No** product tickers (`RICH`, `RICHIR`, WETH-as-role).

### Tests

```text
test/foundry/spec/vaults/detf/composed/multi-vault-weighted/
  MultiVaultWeightedDetf_Deploy.t.sol
  MultiVaultWeightedDetf_Liveness.t.sol
  MultiVaultWeightedDetf_Mint.t.sol
  MultiVaultWeightedDetf_Burn.t.sol
  MultiVaultWeightedDetf_Bonding.t.sol
  MultiVaultWeightedDetf_Claim.t.sol
  MultiVaultWeightedDetf_Pricing.t.sol
  MultiVaultWeightedDetf_PriceShift.t.sol      # underlying pool trades → mint/burn gates
  MultiVaultWeightedDetf_Guards.t.sol
  MultiVaultWeightedDetf_Routes.t.sol          # full route matrix + rejects
  MultiVaultWeightedDetf_Nested.t.sol
  MultiVaultWeightedDetf_NLegs.t.sol           # N=1..7 deploy / smoke / mint path
  MultiVaultWeightedDetf_Reentrancy.t.sol
  MultiVaultWeightedDetf_*Facet_IFacet_Test.t.sol
  MultiVaultWeightedDetf_Invariants.t.sol      # optional expansion

test/foundry/fork/base_main/vaults/detf/composed/multi-vault-weighted/
  TestBase_MultiVaultWeightedDetf_BaseFork.sol
  MultiVaultWeightedDetf_Fork_*.t.sol          # live SE attachments as needed
```

---

## 4. Testing architecture

### 4.0 Production code only — mocks policy

**Hard rule (AGENTS.md + indexedex-testing + crane-testing):**

| Allowed | Forbidden |
|---------|-----------|
| Real SE vaults via production DFPkgs + TestBases | `MockStandardExchange` for lifecycle / integration |
| Real Balancer weighted pool via `WeightedPoolFactory` | Mocking manager, registry, facets, DFPkg, DETF under test |
| Mintable ERC20 only as **non-SUT** token harness if a protocol port needs controllable balances | Hand-rolled fake multi-asset vaults as “legs” |
| Reentrancy ERC20 / attacker contract for reentrancy suites | `vm.mockCall` on SUT diamond / SE vault under test |
| Crane protocol ports under `lib/crane/.../stubs/` as **real protocol implementations** for hermetic deploy | Treating protocol ports as “mocks” and inventing lighter fakes |

If a hermetic port cannot provide two SE vaults with tradeable underlyings for price-shift tests, use **fork** profile with live pools rather than inventing mock underlyings.

### 4.1 Core TestBase responsibilities

`TestBase_MultiVaultWeightedDetf` must:

1. Deploy shared vault components + DETF facets via CREATE3 FactoryServices.
2. Deploy bond NFT vault package via **manager registry** (`DetfComponentFactoryService` / `deployDETFNFTVaultDFPkg` pattern from Single SE DETF TestBase).
3. Deploy rate provider package (production `StandardExchangeRateProviderDFPkg`) for each rated leg.
4. Deploy `MultiVaultWeightedDetfDFPkg` via registry; deploy instance via `indexedexManager.deployVault`.
5. Provide **production** SE vault legs (default: two Aerodrome/Camelot SE vaults from existing router/protocol TestBases with **distinct** underlying pools where possible).
6. Helpers (names indicative):
   - `_deployDetf(N, vaults, weights, rateConfig, thresholds)`
   - `_fundVaultShares(legIndex, to, amount)` — deposit into production SE vault
   - `_obtainReserveBpt(user, amounts)` — initialize/join weighted reserve (self-leg mint as required for join only)
   - `_firstBondBpt(user, bptAmount)` — first `bond(BPT)` → live
   - `_assertInert()` / `_assertLive()`
   - `_mintDetfFromVaultShare(leg, user, amount)` / `_burnDetfToVaultShare(...)`
   - `_shiftUnderlyingPrice(legIndex, direction, amount)` — **trade on underlying pool** of that SE vault
   - `_assertNoFreeInventory(instance)` — residual vault shares / free DETF / rateAssets on diamond ≈ 0 (BPT on diamond intentional)
   - `_openThresholdDetf(...)` — optional helper for pure math paths (not a substitute for price-shift suites)

### 4.2 Suite layers

| Layer | What | Profile |
|-------|------|---------|
| **L0** | Pure math on `detf/core` + multi-leg weight validation (no vault) | default |
| **L1** | Full DETF + N production SE vaults (local hermetic ports) | default |
| **L2** | Nested DETF as one leg (outer multi-weighted; inner Single SE DETF or DualLiquidity / ComposedStable) | default and/or fork |
| **L3** | Base fork multi-leg (Uni V4 SE + Aerodrome SE, etc.) | `FOUNDRY_PROFILE=fork` |
| **L4** | Invariants, reentrancy attacker, residual, non-dilution | on L1/L2 |

### 4.3 Full token-route and condition matrix (required for v1)

#### A. Deploy / config

| Case | Expect |
|------|--------|
| `N=0` or `N>7` | `InvalidVaultCount` |
| Weights sum ≠ `1e18` or zero weight | `InvalidWeights` |
| Duplicate vault | `DuplicateVault` |
| Provider set without rateAsset ∈ vault `tokens()` | `InvalidRateConfig` |
| Zero provider + nonzero rateAsset (or inconsistent) | `InvalidRateConfig` |
| Valid N=1..7 deploy | Inert instance; reserve pool created with `1+N` tokens; weights/rates stored |
| Immutable / unowned | No owner; no diamond-cut authority on instance |

#### B. Liveness

| Case | Expect |
|------|--------|
| Pre-live mint vaultShare→DETF | Revert (`ReservePoolNotInitialized` / not live) |
| Pre-live burn DETF→vaultShare | Revert |
| Pre-live bond vault share (if rejected by design) | Revert or documented only if allowed solely as BPT-building path — **user mint remains blocked** |
| Obtain BPT + first `bond(BPT)` | Bond NFT; `isReserveLive=true` |
| Second BPT bond after live | Succeeds (ongoing) |
| Mint still threshold-gated after live | Default 1.05 / 0.95 deadband |

#### C. Exchange routes (post-live)

| Route | Expect |
|-------|--------|
| `vaultShare[i] → DETF` exact-in | Seigniorage mint; join; preview ≈ execution |
| `DETF → vaultShare[i]` exact-in | Burn + exit; preview ≈ execution |
| All legs `i ∈ [0, N)` mint and burn | Works for each configured leg |
| `rateAsset[i] → DETF` as mint `tokenIn` | **Reject** |
| `vaultShare[i] → vaultShare[j]` on DETF | **Reject** |
| Unconfigured token | `VaultShareNotConfigured` / `UnsupportedRoute` |
| Zero amount / expired deadline | Guard reverts |
| Mint when synthetic ≤ mintThreshold | `MintingNotAllowed` |
| Burn when synthetic ≥ burnThreshold | `BurningNotAllowed` |
| Mixed rated + unrated legs | Both legs mint/burn; unrated rate = 1e18 |

#### D. Price shift (required — not optional)

Using **real trades** on underlying pools of composed SE vaults (via production routers / SE vault exchange paths / protocol ports):

| Case | How | Expect |
|------|-----|--------|
| Open mint regime | Skew underlyings so synthetic **> mintThreshold** (default 1.05e18) | `isMintingAllowed`; mint succeeds |
| Open burn regime | Skew underlyings so synthetic **< burnThreshold** (default 0.95e18) | `isBurningAllowed`; burn succeeds |
| Deadband | After first bond near peg | Neither mint nor burn under defaults (or assert gates match formula) |
| Multi-leg asymmetric skew | Trade only one leg’s underlying | Synthetic moves; leg-specific mint/burn quotes change consistently |

Helpers should prefer:

1. SE vault `exchangeIn` / underlying DEX swap on the **production** pool that prices that vault’s share rate or reserve composition.
2. For Aerodrome/Camelot SE legs: swap the underlying pair that the SE vault holds.
3. For nested DETF legs: trade nested reserve or nested underlying as exposed by that family’s production APIs.

Document in test comments which pool is traded and why synthetic moves.

#### E. Bonding

| Case | Expect |
|------|--------|
| `acceptedBondTokens()` includes reserve BPT + vault shares (post-live policy) | Matches PRD |
| Bond lock `< min` | Revert |
| Bond lock `> max` | Clamp; still succeeds |
| Bond vault share after live | NFT + seigniorage split per peer math |
| Bond BPT after live | NFT principal in BPT units |
| `sellNFT` / sell to protocol | Principal to protocol NFT; mint rebasing claim |

#### F. Claim redemption

| Case | Expect |
|------|--------|
| Redeem claim → `rateAsset[i]` for each **rated** leg | Unwind protocol BPT → share path → SE `exchangeIn` to rateAsset |
| Redeem to unrated leg’s nonexistent rateAsset | Revert |
| Redeem with insufficient protocol principal | Revert cleanly |
| Multiple rateAssets (disparate + same asset two legs) | User-selectable payout; legs remain distinct |

#### G. Composition / opacity

| Case | Expect |
|------|--------|
| Nested DETF as `underlyingVaults[k]` | Outer mint/burn with nested shares; nested still serves direct users |
| Production DETF sources | No imports of concrete Uni/Aero/Camelot/Aave vault types |
| Same rateAsset, two vaults | Two reserve tokens; two providers (or unrated); no merge |

#### H. N-range

| Case | Expect |
|------|--------|
| N=1 smoke | Behavioral parity-ish with single-vault weighted mint shape |
| N=2 disparate rateAssets | Full mint/burn/claim |
| N=2 same rateAsset | Distinct legs |
| N=3..7 | Deploy + metadata + at least one mint and one bond path; size/gas watch |
| Facet `IFacet` metadata | Every facet |

#### I. Hardening

| Case | Expect |
|------|--------|
| Reentrancy on share transfer / exchange | Attacker harness reverts; control path OK |
| Residual inventory | Zero free vault shares / free DETF / rateAssets after success |
| Non-dilution | Existing holders’ claim non-decreasing on mint (fee destinations accounted) |
| Preview == execution | Closed-form paths within 1 wei |

---

## 5. Implementation phases

### Phase 0 — Scaffold and package skeleton

**Deliverables**

- [ ] `IMultiVaultWeightedDetfDFPkg` with `PkgInit` / `PkgArgs` **inside the interface** (Crane rule).
- [ ] Conceptual `PkgArgs`:
  - `name`, `symbol`
  - `vaults: address[]` length `1..7`
  - `weightDetf` + `weights[]` **or** `weights[N+1]` summing to `1e18`
  - `rateProviders[]`, `rateAssets[]` (zero = unrated)
  - `mintThreshold`, `burnThreshold` (0 → defaults `1.05e18` / `0.95e18`)
  - companion refs via `PkgInit` immutables: fee oracle, registry, Balancer vault, weighted pool factory, SE router, rate provider pkg, bond NFT vault pkg, claim token pkg (as needed), diamond factory
- [ ] Skeleton Repo, Common, Facets, DFPkg compiling.
- [ ] Facet + Pkg + Component FactoryServices (CREATE3 facets; registry DFPkg).
- [ ] Spec deploy test: package deploys with **N=1 or N=2 production SE vaults**; no diamond owner on instance.

**Exit:** `forge test --match-path test/foundry/spec/vaults/detf/composed/multi-vault-weighted/*Deploy*` green.

---

### Phase 1 — Repo, multi-leg reserve, pricing, inert deploy

**Deliverables**

- [ ] `MultiVaultWeightedDetfRepo` storage (role-named only):
  - `underlyingVaults[]`, `vaultShares[]`, `vaultCount`
  - `weightDetf`, `weights[]` (or packed)
  - `rateProviders[]`, `rateAssets[]`
  - `reservePool`, token indexes (`detfIndex`, `vaultShareIndex[i]`)
  - `mintThreshold`, `burnThreshold`
  - `isReserveLive`
  - `feeOracle`, `bondNftVault`, `protocolNftId`, `rebasingClaimToken` (as needed)
- [ ] Validation on init: N range, unique vaults, weights, rate config.
- [ ] DFPkg `postDeploy`:
  - Deploy per-leg rate providers where configured (`StandardExchangeRateProviderDFPkg` pattern from Single SE DETF).
  - Create Balancer V3 **WeightedPool** with `1+N` tokens via `WeightedPoolFactory` (supports up to 8 tokens, arbitrary weights — Crane port).
  - Sort tokens as Balancer requires; store indexes.
  - DETF leg `STANDARD`; vault legs `WITH_RATE` or `STANDARD`.
  - Deploy bond NFT vault (reserve BPT as principal asset) via production NFT DFPkg.
  - Wire multi-asset basic vault token list: DETF + all vault shares + reserve BPT.
  - **No owner** left on instance.
- [ ] Common: synthetic price generalized to N vault legs:

  ```text
  ownedBpt = BPT.balanceOf(this) + BPT.balanceOf(bondNftVault)  // as peer single SE
  for each pool balance b_i scaled by rate_i:
    totalValue += ownedBpt * b_i / bptSupply
  synthetic = totalValue / DETF.totalSupply   // 1e18 peg when supply=0 or no BPT
  ```

- [ ] Threshold helpers via `DETFThresholdPolicy`.
- [ ] Info views: vaults, weights, rates, reserve, thresholds, synthetic, mint/burn allowed, live flag.

**Tests**

- [ ] Deploy inert N=1,2; pool token count and weights.
- [ ] Invalid config reverts.
- [ ] Synthetic readable; mint/burn blocked while inert.

**Exit:** Inert multi-leg instances with pool + rates wired; no mint until live.

---

### Phase 2 — First BPT bond → live; bonding surface

**Product rules**

- Live **only** after first successful bond of **reserve BPT**.
- User seigniorage mint with vault shares remains **blocked** until live.

**How the first reserve BPT is obtained (implementation design)**

Balancer cannot issue BPT without a join that includes the DETF self-leg. Pre-live user mint is forbidden, so first liquidity must **not** be the open seigniorage mint path. Implement one coherent path (document in NatSpec):

1. **Preferred (aligns with Single SE “first bond builds reserve” mechanics, BPT principal):**  
   Pre-live `bond` **with vault shares** (and, for multi-leg first join, the caller supplies the required multi-leg share amounts **or** the path accepts a primary leg + quotes others — see note) is **not** user mint; it:
   - mints DETF **only into the reserve join** (self-leg),
   - joins weighted pool → BPT to DETF,
   - creates bond NFT with **BPT principal**,
   - sets `isReserveLive`.  
   This still satisfies “live after first bonding of BPT” (principal is BPT).

2. **Also accept** `bond(reserve BPT)` when BPT already exists (e.g. second user after pool init, or external join helper that only mints self-leg for join without free DETF to user).

3. **Do not** set live on pool init alone without a BPT bond.

**Multi-leg first join amounts:** for N>1, first join must supply all vault legs in weight-consistent amounts (or unbalanced join per Balancer rules). Implementation may:

- Require proportional multi-asset transfer on first bond, or
- Provide a production helper that quotes weight-matched vault-share amounts from a primary leg deposit, still using real joins (no mocks).

Pick one approach in code and lock tests to it; prefer explicit multi-asset pull for clarity in v1.

**Deliverables**

- [ ] `acceptedBondTokens()`: reserve BPT always; vault shares once live (and pre-live only as part of the BPT-building bond path if using design (1)).
- [ ] Bond lock clamp via `DETFBondNFTMathLib` / fee oracle terms.
- [ ] Bond NFT create via `DETFBondLifecycleLib`.
- [ ] Protocol / fee NFT wiring as peer DETFs.
- [ ] `sellPositionToProtocol` / `sellNFT` → principal to protocol NFT → `mintFromNFTSale` on rebasing claim.

**Tests**

- [ ] Inert until first BPT bond; first bond goes live.
- [ ] Mint vaultShare→DETF still reverts pre-live even if pool has liquidity without live flag (if that state is reachable).
- [ ] Lock min/max clamp.
- [ ] Post-live BPT and vault-share bonds.

**Exit:** First BPT bond makes instance live; seigniorage mint still correctly gated.

---

### Phase 3 — ExchangeIn mint (vault shares → DETF)

**Deliverables**

- [ ] Require live + mint threshold.
- [ ] `tokenIn` must be configured `vaultShare[i]` only (reject rateAssets and other vault shares as `tokenOut` pairs on DETF).
- [ ] Quote DETF from **weighted multi-asset pool math** (generalize Single SE `_quoteDetfOutForVaultShares` to N legs: exact-in on vault leg i vs DETF leg using live balances, weights, rates, swap fee — `BalancerV3WeightedPoolQuote` or equivalent).
- [ ] Seigniorage split (`DETFUsageFeeLib` / mint split peer pattern).
- [ ] Mint DETF; join unbalanced / single-sided as peer single SE.
- [ ] `previewExchangeIn` matches execution on closed-form path.

**Tests**

- [ ] Mint each leg after live with open threshold.
- [ ] Preview ≈ execution.
- [ ] Mint reverts inert; reverts unsupported routes.
- [ ] Fee / protocol slice destinations (assert balances).
- [ ] Non-dilution on existing holders.

**Exit:** Multi-leg seigniorage mint proven on production SE vaults.

---

### Phase 4 — Burn / ExchangeOut (DETF → vault shares)

**Deliverables**

- [ ] Require live + burn threshold.
- [ ] `tokenOut` = configured vault share only.
- [ ] Exit reserve toward target leg; burn DETF; residual clean.
- [ ] Preview matches execution.

**Tests**

- [ ] Burn to each leg.
- [ ] Threshold guards.
- [ ] Residual inventory assertions.

**Exit:** Full mint/burn lifecycle multi-leg.

---

### Phase 5 — Price-shift suites (default thresholds)

**Deliverables**

- [ ] Test helpers that **trade underlying pools** of composed vaults.
- [ ] Suites using **default** mint/burn thresholds (1.05 / 0.95), not only open-threshold deploys:
  - After first bond near peg: assert deadband behavior.
  - After underlying skew mint-side: mint succeeds under defaults.
  - After underlying skew burn-side: burn succeeds under defaults.
- [ ] N=2 disparate and same-rateAsset legs both covered for at least one price-shift path.

**Exit:** Documented, green price-shift tests prove gates under real market movement.

---

### Phase 6 — Rebasing claim + redeem to any rateAsset

**Deliverables**

- [ ] Wire production `IRebasingClaimToken` package (`RebasingClaimTokenDFPkg` / composed stable rebasing package patterns via `Detf*FactoryService`) with **role names only**.
- [ ] On NFT sale: mint claim via `DETFBondLifecycleLib._sellPositionToRebasingClaim` (or peer).
- [ ] Redeem orchestration on DETF (or claim token callback into DETF):
  1. Burn claim shares / pull claim.
  2. Unwind protocol-owned reserve BPT as needed.
  3. Exit toward chosen vault share `i`.
  4. SE vault `exchangeIn` share → `rateAsset[i]`.
  5. Transfer rateAsset to recipient.
- [ ] User selects `rateAsset` / leg; unsupported unrated choice reverts.
- [ ] **Note:** existing `IRebasingClaimToken` may expose a single `rateAsset()` view for pricing; multi-asset payout is **DETF-orchestrated** per PRD — do not force a product-branded second token. If interface needs a multi-asset redeem entrypoint on the DETF, add a role-named function (e.g. `redeemClaim(uint256 amount, IERC20 rateAssetOut, ...)`).

**Tests**

- [ ] Sell → claim mint.
- [ ] Redeem to each configured rateAsset (N=2 disparate).
- [ ] Same rateAsset two legs: redeem path still identifies a valid rated leg.
- [ ] Reject unconfigured / unrated payout choice.

**Exit:** Full bond → sell → claim → multi-rateAsset redeem on production legs.

---

### Phase 7 — Nested DETF leg + N-range + matrix expansion

**Deliverables**

- [ ] Nested production DETF (SingleStandardExchangeDETF or DualLiquidity / ComposedStable) as one `underlyingVaults[k]`.
- [ ] N=3..7 deploy smoke + one mint + one bond.
- [ ] Fork matrix rows as capacity allows (Uni V4 SE + Aerodrome SE, etc.).
- [ ] Opacity review: no concrete protocol imports in production multi-weighted sources.

**Tests**

- [ ] Nested mint/burn outer; inner still works.
- [ ] N=7 deploy + size check (`forge build --sizes` / package size).

**Exit:** Composition and max-N smoke green.

---

### Phase 8 — Hardening and docs

**Deliverables**

- [ ] Reentrancy suite (attacker share token or reenter on transferFrom — **SUT remains production DETF**).
- [ ] Facet `IFacet` tests for every facet.
- [ ] Invariant / sequence tests (optional expansion).
- [ ] PRD checklist sync; status → IMPLEMENTED when done.
- [ ] Agents.md / CODEBASE_MAP pointer: when to use Weighted multi-vault vs Stable multi-vault.

**Exit:** Hardening green; docs updated.

---

## 6. Implementation order (file-level)

1. Interface + DFPkg + factories + inert multi-leg deploy (registry path, production SE legs).  
2. Repo + Common (N-leg storage, synthetic, thresholds, join/exit primitives).  
3. Bond NFT + first BPT bond → live (self-leg mint for join only; no open seigniorage mint).  
4. ExchangeIn mint + query (per-leg vault shares).  
5. ExchangeOut burn + residual.  
6. Info facet.  
7. Price-shift test helpers + suites under default thresholds.  
8. Claim sell + redeem to any rateAsset.  
9. Nested DETF leg + N=3..7 smoke.  
10. Reentrancy, IFacet metadata, docs.  

**Reuse** `contracts/vaults/detf/core/*` and `reusable/*` wherever possible.  
**Do not** subclass peer family contracts.

---

## 7. Package / deploy path checklist

```solidity
// Facets — CREATE3 only
facet = create3Factory.deployMultiVaultWeightedDetfExchangeInFacet(); // via FactoryService

// DFPkg — registry only
vm.prank(owner);
pkg = indexedexManager.deployPkg(pkgInit); // or typed deployMultiVaultWeightedDetfDFPkg

// Instance
vm.prank(owner);
detf = indexedexManager.deployVault(IStandardVaultPkg(address(pkg)), abi.encode(args));
```

Anti-patterns (never):

```solidity
new MultiVaultWeightedDetfDFPkg(...);
diamondPackageFactory.deploy(IDiamondFactoryPackage(vaultPkg), args); // bypass registry for vault DFPkg
MockStandardExchange se = new MockStandardExchange(...);
```

---

## 8. Acceptance criteria

### Product

- [ ] Fresh path under `detf/composed/multi-vault-weighted/` only.
- [ ] No product tickers in production Solidity or normative NatSpec.
- [ ] Role names only for rateAsset / vault / claim.
- [ ] Immutable unowned instance.
- [ ] Live only after first reserve BPT bond; pre-live vault-share mint blocked.
- [ ] User mint/burn only vault shares ↔ DETF; claim redeem to any configured rateAsset.
- [ ] Nested SE/DETF legs work; production sources do not import concrete protocol vault types.

### Quality

- [ ] Preview == execution on closed-form paths.
- [ ] No residual free inventory after success paths.
- [ ] Non-dilution on mint for existing holders (fees accounted).
- [ ] Synthetic gates match `DETFThresholdPolicy` formula.
- [ ] **No SUT/SE mocks** in lifecycle tests; reentrancy harness only where needed.

### Test matrix (v1 done when all required rows green)

| Area | Required |
|------|----------|
| Deploy guards + N=1..7 deploy smoke | Yes |
| Liveness / first BPT bond | Yes |
| Mint/burn each leg (N≥2) | Yes |
| Route rejects (rateAsset mint, share↔share) | Yes |
| Default-threshold price shift via underlying trades (mint + burn) | Yes |
| Bond lock clamp + sell → claim | Yes |
| Claim redeem to each rated rateAsset | Yes |
| Same rateAsset two vaults distinct legs | Yes |
| Nested DETF leg | Yes |
| Reentrancy + residual + IFacet | Yes |
| Fork multi-protocol expansion | Recommended |

---

## 9. Risks and mitigations

| Risk | Mitigation |
|------|------------|
| Stack-too-deep with N=7 | Helper libraries; split targets/facets; avoid viaIR unless last resort |
| First join multi-asset UX complexity | Explicit multi-pull on first BPT-building bond; strong TestBase helpers |
| Synthetic formula multi-rate scaling | Mirror Balancer live balances + rate providers; fuzz small N; parity vs pool |
| Claim multi-rateAsset vs single-rate claim token API | DETF-orchestrated redeem entrypoint; keep claim token as share accounting |
| Price-shift hard in hermetic env | Prefer SE vaults with tradeable underlying ports; fall back to fork for L3 |
| Contract size | Facet split (query / claim); measure early with `forge build --sizes` |
| Accidental mock TestBases from stable family | Copy **Single SE DETF** production TestBase discipline, not MockComposedStable ERC20 patterns |

---

## 10. Revision history

| Date | Change |
|------|--------|
| 2026-07-14 | Initial implementation + full test plan from PRD + locked clarifications (BPT-first live, pre-live mint block, immutable unowned, full routes + underlying price-shift tests, production-first TestBases) |
