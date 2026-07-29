grok# MixedBufferMultiVaultStableDetf — Implementation and Testing Plan

## Purpose

Execute the [PRD](./MixedBufferMultiVaultStableDetf_PRD.md): implement a brand-agnostic **Mixed-Buffer Multi–Standard Exchange Stable DETF** whose Balancer V3 reserve is a production **`MixedBufferMultiVaultStablePool`** (DETF unpaired + one common `bufferToken` + 1..3 SE vault shares).

This plan is ordered for incremental delivery. Drive phases **0→8 end-to-end** and report when green (no required mid-phase review gates). Existing DETF families are **behavioral references only** — do **not** subclass their concrete contracts.

## Status

**IMPLEMENTED** — hermetic Foundry suite green (2026-07-26). Product requirements **LOCKED** (PRD D1–D30). Plan-level implementation choices **P1–P9** locked below.

| Field | Value |
|-------|--------|
| PRD | `MixedBufferMultiVaultStableDetf_PRD.md` (**LOCKED** D1–D30) |
| Package path | `contracts/vaults/detf/composed/stable/mixedBuffer/` |
| Reserve pool | `contracts/protocols/dexes/balancer/v3/pools/stable/mixedBufferMultiVault/` (**IMPLEMENTED**) |
| Behavioral references | Single SE DETF, MultiVaultWeightedDetf, composed stable common (behavior only) |
| Tests root (intended) | `test/foundry/spec/vaults/detf/composed/stable/mixedBuffer/` |

---

## Living progress log

| Date | Note |
|------|------|
| 2026-07-26 | Plan written. Locks P1–P9 from owner Q&A. Pool dependency treated as ready. Nested DETF-as-leg required in v1. User-facing `bond(reserveBpt)` after live **in scope**. |
| 2026-07-26 | **IMPLEMENTED.** Production package under `mixedBuffer/`; 52 hermetic tests green under `test/foundry/spec/vaults/detf/composed/stable/mixedBuffer/`. Agents.md family table updated. |

---

## Locked product decisions (do not re-open without PRD revision)

Summarized from PRD D1–D30:

| Topic | Decision |
|-------|----------|
| True DETF | Diamond **is** share ERC-20; seigniorage vs reserve (not pure pro-rata BPT vault) |
| Opacity | SE + Balancer + MixedBuffer pool views only |
| Governance | Immutable, unowned after deploy |
| Liveness | Inert deploy; live via **special first-bond bootstrap** (multi-asset + proportional DETF self + pool init) |
| Reserve | `MixedBufferMultiVaultStablePool`: \(U=1\), \(N\in[1,3]\), \(T=2+N\in[3,5]\) |
| Pricing | Reserve StableMath only (math balances / `virtualBuffer` / rates — not physical buffer alone) |
| Synthetic gate | FD owned BPT claim on math balances, rate-scaled, ÷ supply; peg **1e18** |
| Thresholds | Defaults **1.05e18 / 0.95e18**; PkgArgs `0` → default |
| Mint `tokenIn` | **`bufferToken` OR any configured `vaultShare[i]`** |
| Burn `tokenOut` | **`bufferToken` only** |
| Share↔share on DETF | Out of scope (`InvalidRoute`) |
| Bonding | Full bond NFT + protocol + fee-recipient NFTs; oracle lock clamp |
| Claim | Rebasing claim; redeem payout **`bufferToken`** (`rateAsset` ≡ buffer) |
| Nested SE | Allowed; opaque |
| Deploy | CREATE3 facets; DFPkg via **Vault Registry / manager** |
| Codepath | Fresh under `composed/stable/mixedBuffer/` |
| Amp | Deployer-set fixed amp; no post-deploy amp admin |
| Rate providers | **No defaults / no auto-deploy.** Optional user RPs on **vault share legs only**. DETF never RP. Buffer never RP (pool M21) |
| Bootstrap permission | **Anyone** (permissionless) |
| Cross-chain / extra unpaired | Out of scope v1 |

---

## Post-PRD clarifications (plan locks P1–P9)

These tighten **implementation / API / test DoD**. Product topology stays D1–D30. Where a plan lock **extends** a PRD default reading, it is marked **EXTENDS**.

| ID | Topic | Decision | Status |
|----|-------|----------|--------|
| **P1** | Bootstrap fee / free DETF | **Match Single SE:** mint proportional DETF into reserve join; bond NFT gets **BPT principal**; also mint seigniorage split free DETF to user / feeTo / protocol. Primary outcome remains bond NFT. | **LOCKED** |
| **P2** | I1 proportional seed | **Rate-scaled peg seed** (formula frozen in §3). | **LOCKED** |
| **P3** | Bond NFT + claim packaging | Reuse **protocol** packages via `Detf*FactoryService` (`DETFNFTVaultDFPkg`, `RebasingClaimTokenDFPkg`). Do **not** subclass composed/stable/common companions. | **LOCKED** |
| **P4** | Ongoing buffer bond | Unbalanced **buffer** join → **BPT** principal; pool hooks fan-out. DETF residual-safe only. | **LOCKED** |
| **P5** | Bootstrap API | Dedicated **`bootstrapFirstBond(...)`** — permissionless, multi-asset, **pre-live only**. | **LOCKED** |
| **P6** | User BPT bond after live | **Yes** — `acceptedBondTokens()` includes **reserve BPT** + buffer + vault shares (**EXTENDS** PRD D21 lean reading). | **LOCKED** |
| **P7** | Live buffer mint | Unbalanced **buffer + DETF self** join; DETF does **not** pick shallowest vault. | **LOCKED** |
| **P8** | Nested DETF matrix | **Nested DETF-as-leg required in v1** (**EXTENDS** optional-later default). | **LOCKED** |
| **P9** | Delivery cadence | Full MultiVaultWeighted-style plan; phases **0→8** end-to-end; report when green. | **LOCKED** |

### Glossary

| Symbol / role | Meaning |
|---------------|---------|
| `detfToken` | DETF diamond ERC-20 (`address(this)`) |
| `bufferToken` | Single common bufferable ERC-20; equals family **`rateAsset`** |
| `vaultShare[i]` | Share of configured SE vault \(i\) |
| `reservePool` / `reserveBpt` | MixedBuffer MultiVault Stable pool instance / BPT |
| \(N\) | Vault/share count, \(1..3\) |
| \(T\) | Pool token count \(= 2+N \in [3,5]\) |
| Math balances | Unpaired physical + `virtualBuffer` + derived share depths (pool M13/M14) |

---

## 1. Goals and non-goals

### Goals

1. Implement `MixedBufferMultiVaultStableDetf` under `contracts/vaults/detf/composed/stable/mixedBuffer/` per the PRD + P1–P9.
2. Deploy and use a production **`MixedBufferMultiVaultStablePool`** as the reserve (package-owned create preferred — D26).
3. Prove **interface opacity**: production DETF talks only to `IStandardExchange` / share ERC-20 / Balancer / MixedBuffer **views** — no concrete Uni/Aero/Camelot/Aave vault types in production sources.
4. Ship **permissionless multi-asset first-bond bootstrap** that initializes all \(T\) legs non-zero (pool M15), places BPT on a bond NFT, applies Single SE–style seigniorage split (P1), and marks live.
5. Live routes: mint buffer or vaultShare → DETF; burn DETF → buffer only; bond buffer / vaultShare / **reserve BPT**; sell → rebasing claim → redeem **buffer**.
6. Production-first Foundry coverage for **N=1..3**, multi-protocol SE legs, **nested DETF-as-leg (P8)**, default-threshold price-shift, residual, reentrancy.

### Non-goals (this plan)

- Reimplementing MixedBuffer pool routing / virtual buffer / hooks (pool-owned).
- Buffer or DETF rate providers (forbidden by D19 / M21).
- DETF-level vaultShareᵢ ↔ vaultShareⱼ; burn DETF → vaultShare.
- Off-pool multi-asset FX numeraire.
- Cross-chain, post-deploy amp admin, \(U>1\) free unpaired assets.
- Subclassing Single SE / MultiVaultWeighted / composed stable common concrete contracts.
- Production mainnet deploy scripts (follow-up after green integration).
- Fixing unrelated debt in peer DETF families unless it blocks this package.

---

## 2. Behavioral references (what to copy vs invent)

| Reference | Take | Do not copy blindly |
|-----------|------|---------------------|
| **`standardExchange/single`** | Inert deploy; synthetic gates; seigniorage mint split; full bond NFT; FactoryService + registry; **bootstrap fee/free DETF pattern (P1)**; TestBase helpers | Weighted 2-token; burn-to-share; first bond = shares only into weighted join |
| **`composed/multi-vault-weighted`** | Multi-leg repo layout, N-range validation, route matrix / price-shift DoD, nested-leg matrix, plan structure | Weighted math; BPT-first live without multi-asset MixedBuffer init; burn to vault shares |
| **`composed/stable/common`** | Multi-vault hygiene, claim/bond *behavioral* patterns, StableMath quote inspiration | Intermediate dual-pool graph; brand-era paths; **do not subclass** companions (use protocol packages — P3) |
| **`MixedBufferMultiVaultStablePool`** | Layout U/N/T, math balances, `virtualBuffer`, shallowest/deepest views, init all-legs non-zero, STANDARD buffer | DETF must not reimplement fan-out |
| **`detf/core/*`** | `DETFThresholdPolicy`, `DETFUsageFeeLib`, `DETFMintSplitLib`, `DETFBondLifecycleLib`, `DETFBondNFTMathLib`, `DETFBalancerScaleLib`, `DETFSafeTransferLib`, `DETFPreviewLib` | N/A |
| **`detf/reusable/*`** | `DetfFacetFactoryService`, `DetfPkgFactoryService`, `DetfComponentFactoryService` for NFT / claim package helpers | Brand-specific builders |
| **`contracts/vaults/protocol/*`** | `DETFNFTVaultDFPkg`, `RebasingClaimTokenDFPkg` as production companions | Family-local renames of roles |

### Gold TestBases to inherit / compose

| Base | Use for |
|------|---------|
| `CraneTest` → `IndexedexTest` → `TestBase_VaultComponents` | Core stack |
| `TestBase_BalancerV3StandardExchangeRouter` | Local Balancer + SE router patterns |
| MixedBuffer pool TestBase / suite under pool package | Production MixedBuffer pool deploy + init helpers |
| `TestBase_CamelotV2StandardExchange` / Aerodrome / Aave Stata | Hermetic multi-protocol SE legs |
| `TestBase_SingleStandardExchangeDETF` | Pattern for DETF package deploy + bond helpers (mirror, do not subclass for production) |
| DualLiquidity fork TestBase / ComposedStable IntegratedDeploy | Nested DETF-as-leg (P8) |

**Inheritance chain for this family’s TestBase:**

```text
CraneTest
  └── IndexedexTest
        └── TestBase_VaultComponents
              └── (Balancer SE router and/or protocol SE mixins)
                    └── (MixedBuffer pool deploy helpers as needed)
                          └── TestBase_MixedBufferMultiVaultStableDetf   # THIS family
                                └── suites / N-leg / nested adapters
```

Always call parent `setUp()` in correct override order. Facets via `create3Factory`; vault DFPkgs via `indexedexManager.deploy*DFPkg` / registry `deployPkg`.

---

## 3. Naming, layout, and frozen formulas

### 3.1 Production source

```text
contracts/vaults/detf/composed/stable/mixedBuffer/
  MixedBufferMultiVaultStableDetf_PRD.md
  MixedBufferMultiVaultStableDetf_IMPLEMENTATION_AND_TEST_PLAN.md   # this file
  MixedBufferMultiVaultStableDetfRepo.sol
  MixedBufferMultiVaultStableDetfCommon.sol
  MixedBufferMultiVaultStableDetfExchangeInTarget.sol
  MixedBufferMultiVaultStableDetfExchangeInFacet.sol
  MixedBufferMultiVaultStableDetfExchangeInQueryTarget.sol   # or shared query target
  MixedBufferMultiVaultStableDetfExchangeInQueryFacet.sol
  MixedBufferMultiVaultStableDetfExchangeOutTarget.sol
  MixedBufferMultiVaultStableDetfExchangeOutFacet.sol
  MixedBufferMultiVaultStableDetfExchangeOutQueryTarget.sol
  MixedBufferMultiVaultStableDetfExchangeOutQueryFacet.sol
  MixedBufferMultiVaultStableDetfBondingTarget.sol
  MixedBufferMultiVaultStableDetfBondingFacet.sol
  MixedBufferMultiVaultStableDetfInfoTarget.sol
  MixedBufferMultiVaultStableDetfInfoFacet.sol
  MixedBufferMultiVaultStableDetfClaimTarget.sol              # optional size split for claim redeem
  MixedBufferMultiVaultStableDetfClaimFacet.sol
  MixedBufferMultiVaultStableDetfDFPkg.sol                    # I…DFPkg: PkgInit/PkgArgs IN interface
  MixedBufferMultiVaultStableDetf_Facet_FactoryService.sol
  MixedBufferMultiVaultStableDetf_Pkg_FactoryService.sol
  MixedBufferMultiVaultStableDetf_Component_FactoryService.sol
  TestBase_MixedBufferMultiVaultStableDetf.sol
  interfaces/IMixedBufferMultiVaultStableDetf.sol            # optional slim surface
  interfaces/IMixedBufferMultiVaultStableDetfDFPkg.sol       # PkgInit / PkgArgs only
```

**Type names:** full words (`MixedBufferMultiVaultStableDetf`, never `MBMV` / `SE` in types).  
**Locals:** `seVault_`, `share_`, `buffer_`, `bpt_` OK for stack.  
**No** product tickers / `WETH`/`USDC` as role names.

### 3.2 Tests

```text
test/foundry/spec/vaults/detf/composed/stable/mixedBuffer/
  MixedBufferMultiVaultStableDetf_Deploy.t.sol
  MixedBufferMultiVaultStableDetf_Liveness.t.sol
  MixedBufferMultiVaultStableDetf_Bootstrap.t.sol
  MixedBufferMultiVaultStableDetf_Mint.t.sol
  MixedBufferMultiVaultStableDetf_Burn.t.sol
  MixedBufferMultiVaultStableDetf_Bonding.t.sol
  MixedBufferMultiVaultStableDetf_Claim.t.sol
  MixedBufferMultiVaultStableDetf_Pricing.t.sol
  MixedBufferMultiVaultStableDetf_PriceShift.t.sol
  MixedBufferMultiVaultStableDetf_Guards.t.sol
  MixedBufferMultiVaultStableDetf_Routes.t.sol
  MixedBufferMultiVaultStableDetf_Nested.t.sol
  MixedBufferMultiVaultStableDetf_NLegs.t.sol
  MixedBufferMultiVaultStableDetf_RateProviders.t.sol
  MixedBufferMultiVaultStableDetf_Reentrancy.t.sol
  MixedBufferMultiVaultStableDetf_*Facet_IFacet_Test.t.sol
  MixedBufferMultiVaultStableDetf_Invariants.t.sol          # optional expansion after P0 lifecycle

test/foundry/fork/base_main/vaults/detf/composed/stable/mixedBuffer/
  TestBase_MixedBufferMultiVaultStableDetf_BaseFork.sol
  MixedBufferMultiVaultStableDetf_Fork_*.t.sol
```

### 3.3 PkgArgs / PkgInit (conceptual — freeze in interface)

```solidity
// On IMixedBufferMultiVaultStableDetfDFPkg (Crane: structs on interface, not contract)
struct PkgInit {
    // facets + shared vault facets
    // feeOracle, vaultRegistry, balancerV3Vault, diamondFactory
    // MixedBuffer pool pkg (IMixedBufferMultiVaultStablePoolPkg)
    // bond NFT vault pkg (protocol DETFNFTVault)
    // rebasing claim pkg (protocol RebasingClaimToken)
    // optional: SE router / Permit2 if exit paths require router settle
    // rate provider pkg ref (user may supply share RPs; package does NOT auto-deploy defaults)
}

struct PkgArgs {
    string name;
    string symbol;
    IERC20 bufferToken;
    IStandardExchange[] standardExchangeVaults; // length N in 1..3
    IRateProvider[] vaultShareRateProviders;    // length == N; address(0) => STANDARD
    uint256 amplificationParameter;             // fixed amp for MixedBuffer pool create
    uint256 mintThreshold;                      // 0 => 1.05e18
    uint256 burnThreshold;                      // 0 => 0.95e18
}
```

**Validation (minimum):**

- \(1 \le N \le 3\); distinct vaults / shares  
- Each vault `IStandardVault` accepts **and** produces `bufferToken`  
- Amp in StableMath min/max (same bounds as pool package)  
- `vaultShareRateProviders.length == N`  
- Reject any non-zero buffer RP if ever exposed  
- No RP for DETF unpaired leg  

### 3.4 Frozen formula — proportional DETF self seed (**P2 / I1**)

**Goal:** On bootstrap, user supplies **all non-DETF legs** non-zero. DETF mints a **self-leg** amount so the MixedBuffer init sits on a **stable peg** in rate-scaled buffer units (not an open seigniorage mint of free-float DETF as the primary outcome).

**Definitions (all amounts in raw token units unless noted):**

- Let \(b\) = user `bufferToken` amount.  
- Let \(s_i\) = user `vaultShare[i]` amount for \(i \in [0,N)\).  
- Let \(r_i\) = share rate for leg \(i\) (from user RP if `WITH_RATE`, else \(1\text{e}18\)).  
- Buffer is always STANDARD (rate \(1\text{e}18\)).  
- DETF unpaired is STANDARD (rate \(1\text{e}18\)).

**Rate-scaled notional in abstract buffer units (1e18 scale):**

\[
\tilde{b} = b \cdot 10^{18-\delta_b} \quad\text{(scale to 18 decimals if needed; use DETFBalancerScaleLib peer patterns)}
\]

\[
\tilde{s}_i = s_i \cdot \frac{r_i}{1\text{e}18} \cdot 10^{18-\delta_{s_i}}
\]

\[
\tilde{E}_{\text{nonDETF}} = \tilde{b} + \sum_{i=0}^{N-1} \tilde{s}_i
\]

**Peg seed (locked):** mint DETF self-leg raw amount \(d\) such that its rate-scaled notional equals the **average** non-DETF rate-scaled notional across the \(1+N\) non-DETF legs (so init balances are balanced at peg across all \(T = 2+N\) tokens when DETF also contributes one equal slice):

\[
\tilde{d} = \frac{\tilde{E}_{\text{nonDETF}}}{1+N}
\]

\[
d = \text{unscale}(\tilde{d})\ \text{to DETF decimals (typically 18)}
\]

**Equivalence check for tests:** after init, math balances (DETF physical, `virtualBuffer`, derived share depths rate-scaled) are within a **documented wei tolerance** of equal notional at amp-fixed stable start. Prefer exact equality under identical decimals + all STANDARD RPs; allow ≤ few-wei when rate scaling forces rounding.

**Rejected alternatives (do not implement unless PRD revision):**

- DETF seed = sum of non-DETF notionals (overweights DETF vs buffer+shares)  
- Amp-iterative invariant solve as primary path (may be used later as a diagnostic assert only)

**Seigniorage on bootstrap (**P1**):** treat gross DETF related to the join as:

1. Mint \(d\) to `address(this)` for the unpaired join leg.  
2. Initialize / join reserve with all \(T\) amounts → `bptOut`.  
3. Apply `DETFMintSplitLib` / `DETFUsageFeeLib` **on the seigniorage incentive applied to rate-scaled input notional of user-supplied non-DETF assets** (peer Single SE: split of the quoted DETF amount). Implementation detail: use the same split structure as Single SE first bond — free DETF slices to user / feeTo / protocol **in addition to** \(d\) joined into the pool, **or** split a gross quote where pool join uses full gross and user free DETF is the user slice (match Single SE BondingTarget exactly in spirit).  
4. Bond NFT principal = **`bptOut`** (BPT units).  
5. Set `isReserveLive = true`.

NatSpec on `bootstrapFirstBond` must state: primary outcome is bond NFT with BPT principal; free DETF is seigniorage side effect.

### 3.5 Synthetic price (D6)

```text
ownedBpt = reserveBpt.balanceOf(this) + reserveBpt.balanceOf(bondNftVault)  // peer inclusion
// Prefer pool math balances:
//   unpaired DETF physical scaled
//   virtualBuffer (not physical buffer raw alone)
//   derived share depths / rate-scaled share math balances
claimValue_bufferUnits = sum_i (ownedBpt * mathBalance_i / bptSupply)  // rate-scaled into buffer units
synthetic = claimValue_bufferUnits / DETF.totalSupply   // abstract 1e18 peg
// supply == 0 or ownedBpt == 0: define per peer (bootstrap ungated; views return peg or 0 — freeze in Common + tests)
```

Gates: mint iff `synthetic > mintThreshold`; burn iff `synthetic < burnThreshold`; deadband neither. Bootstrap first bond **ungated** by synthetic.

---

## 4. Testing architecture

### 4.0 Production code only — mocks policy

| Allowed | Forbidden |
|---------|-----------|
| Real SE vaults via production DFPkgs + TestBases | `MockStandardExchange` for lifecycle / integration |
| Real MixedBuffer pool via production pool DFPkg | Mocking manager, registry, facets, DFPkg, DETF, MixedBuffer under test |
| Mintable ERC20 only as **non-SUT** funding harness | Fake multi-asset vaults as legs |
| Reentrancy ERC20 as configured **vault share** for attack tests only | `vm.mockCall` on SUT diamond / SE vault under test |
| Crane protocol ports (`*/stubs/`) as real hermetic implementations | Treating ports as mocks and inventing lighter fakes |

### 4.1 Core TestBase responsibilities

`TestBase_MixedBufferMultiVaultStableDetf` must:

1. Deploy shared vault components + DETF facets via CREATE3 FactoryServices.  
2. Deploy / bind production **MixedBuffer pool pkg** (or let DETF DFPkg own create).  
3. Deploy bond NFT vault + rebasing claim via **protocol** packages (`DetfComponentFactoryService` / manager registry).  
4. Deploy `MixedBufferMultiVaultStableDetfDFPkg` via registry; instance via `indexedexManager.deployVault`.  
5. Provide production SE vault legs that all accept+produce a shared `bufferToken` (default: N=1 and N=2 from Camelot/Aerodrome hermetic ports with same buffer).  
6. Helpers (names indicative):

| Helper | Role |
|--------|------|
| `_deployDetf(N, buffer, vaults, shareRPs, amp, thresholds)` | Registry deploy inert |
| `_fundBuffer(to, amount)` / `_fundVaultShares(leg, to, amount)` | Production funding |
| `_bootstrapFirstBond(user, bufferAmt, shareAmts[], lock)` | Permissionless first bond → live |
| `_assertInert()` / `_assertLive()` | Liveness |
| `_mintDetfFromBuffer` / `_mintDetfFromVaultShare` | Live mint |
| `_burnDetfToBuffer` | Live burn |
| `_bondBuffer` / `_bondVaultShare` / `_bondReserveBpt` | Ongoing bond |
| `_shiftUnderlyingPrice(leg, dir, amt)` | Real trades on SE underlying |
| `_assertNoFreeInventory(instance)` | Residual: free shares / free DETF / free buffer ≈ 0 (BPT on diamond intentional) |
| `_syntheticPrice()` / `_openThresholdDetf` | Pricing helpers (open thresholds not a substitute for price-shift) |
| `_deployNestedDetfLeg()` | Production nested DETF as one share leg (P8) |

### 4.2 Suite layers

| Layer | What | Profile |
|-------|------|---------|
| **L0** | Pure math: peg seed formula, threshold, scale (no vault) | default |
| **L1** | Full DETF + N production SE vaults + production MixedBuffer | default |
| **L2** | Nested DETF as one leg (Single SE DETF / DualLiquidity / ComposedStable) | default and/or fork |
| **L3** | Base fork multi-leg | `FOUNDRY_PROFILE=fork` |
| **L4** | Invariants, reentrancy, residual, non-dilution | on L1/L2 |

### 4.3 Full route and condition matrix (required for v1)

#### A. Deploy / config

| Case | Expect |
|------|--------|
| \(N=0\) or \(N>3\) | `InvalidVaultCount` (or family equivalent) |
| Duplicate vault / share | `DuplicateVault` |
| Vault does not accept+produce buffer | Deploy revert |
| Amp out of range | Deploy revert |
| Share RP array length ≠ N | Deploy revert |
| Non-zero buffer RP if exposed | Deploy reject |
| Valid N=1,2,3 | Inert; MixedBuffer registered with tokens sorted; amp stored; **pool not initialized** |
| Immutable / unowned | No owner; no diamondCut authority |

#### B. Liveness / bootstrap

| Case | Expect |
|------|--------|
| Pre-live mint buffer→DETF | Revert (`ReservePoolNotInitialized` / not live) |
| Pre-live mint vaultShare→DETF | Revert |
| Pre-live burn | Revert |
| Pre-live ongoing single-asset bond | Revert |
| Pre-live `bond(BPT)` | Revert (no BPT yet / not live) |
| `bootstrapFirstBond` missing a non-zero share leg | Revert (M15 all legs non-zero) |
| `bootstrapFirstBond` zero buffer | Revert |
| Permissionless bootstrap by non-owner | Succeeds |
| Bootstrap: proportional DETF seed + init + bond NFT + live | `isReserveLive=true`; BPT principal on NFT; free DETF per P1 |
| Second bootstrap after live | Revert |
| Bootstrap ungated by synthetic | Succeeds near peg |

#### C. Exchange routes (post-live)

| Route | Expect |
|-------|--------|
| `bufferToken → DETF` exact-in | Seigniorage mint; unbalanced join; preview ≈ execution |
| `vaultShare[i] → DETF` exact-in for each \(i\) | Same |
| `DETF → bufferToken` exact-in | Burn + exit toward buffer; preview ≈ execution |
| `DETF → vaultShare[i]` | **`InvalidRoute`** |
| `vaultShare[i] → vaultShare[j]` on DETF | **`InvalidRoute`** |
| Unconfigured token | `InvalidRoute` / not configured |
| Zero amount / expired deadline | Guard reverts |
| Mint when synthetic ≤ mintThreshold | `MintingNotAllowed` |
| Burn when synthetic ≥ burnThreshold | `BurningNotAllowed` |
| Share WITH_RATE vs STANDARD | Both mint paths work; rates enter quotes |

#### D. Price shift (required)

Using **real trades** on underlying pools of composed SE vaults:

| Case | Expect |
|------|--------|
| Open mint regime under defaults | Mint succeeds |
| Open burn regime under defaults | Burn to buffer succeeds |
| Deadband after bootstrap near peg | Neither under defaults (or gates match formula) |
| Skew one SE leg only | Synthetic moves; quotes update |

Document in test comments which pool is traded and why synthetic moves. Prefer SE `exchangeIn` / production DEX swap on the vault’s underlying.

#### E. Bonding

| Case | Expect |
|------|--------|
| `acceptedBondTokens()` | **buffer ∪ vaultShare[i] ∪ reserveBpt** after live (P6) |
| Bond lock `< min` | Revert |
| Bond lock `> max` | Clamp; succeeds |
| Bond buffer after live | Unbalanced buffer join → BPT principal |
| Bond vaultShare after live | Join share leg → BPT principal |
| Bond reserve BPT after live | NFT principal in BPT units |
| `sellPositionToProtocol` | Protocol NFT + rebasing claim mint |

#### F. Claim redemption

| Case | Expect |
|------|--------|
| Redeem claim → **`bufferToken` only** | Unwind protocol BPT → buffer (pool may pre-seat deepest) |
| Redeem without burning claim shares | Impossible / reverts |
| Insufficient protocol principal | Clean revert |

#### G. Composition / opacity / RP

| Case | Expect |
|------|--------|
| Nested DETF as `underlyingVaults[k]` | Outer mint/burn/bond with nested shares; nested still serves direct users (**P8 required**) |
| Production DETF sources | No imports of concrete protocol vault types |
| Zero share RP | Share leg STANDARD |
| Non-zero share RP | Share leg WITH_RATE wired |
| DETF / buffer | Never WITH_RATE |

#### H. N-range

| Case | Expect |
|------|--------|
| N=1 full lifecycle | Bootstrap, mint buffer+share, burn buffer, bond all accepted, claim |
| N=2 multi-protocol | Full lifecycle preferred |
| N=3 smoke | Deploy + bootstrap + at least one mint + one bond + residual |
| Facet `IFacet` metadata | Every facet |

#### I. Hardening

| Case | Expect |
|------|--------|
| Reentrancy via hostile share ERC20 | `IsLocked` / safe revert; control path OK |
| Residual inventory | Zero free buffer / shares / free DETF after success |
| Non-dilution | Existing holders’ claim non-decreasing on mint (fees accounted) |
| Preview == execution | Closed-form paths exact when possible (≤ few-wei only if documented for multi-leg proportional exit) |

---

## 5. Implementation phases

### Phase 0 — Scaffold and package skeleton

**Deliverables**

- [x] `IMixedBufferMultiVaultStableDetfDFPkg` with `PkgInit` / `PkgArgs` **inside the interface**.  
- [x] Skeleton Repo, Common, Facets, DFPkg compiling under default profile.  
- [x] Facet + Pkg + Component FactoryServices (CREATE3 facets; registry DFPkg).  
- [x] Spec deploy test: package deploys with **N=1 production SE vault** + production MixedBuffer wiring path; no diamond owner on instance.

**Exit:**  
`forge test --match-path 'test/foundry/spec/vaults/detf/composed/stable/mixedBuffer/*Deploy*'` green.

---

### Phase 1 — Repo, MixedBuffer reserve wiring, pricing, inert deploy

**Deliverables**

- [x] `MixedBufferMultiVaultStableDetfRepo` storage (role-named only):
  - `bufferToken`, `underlyingVaults[]`, `vaultShares[]`, `vaultCount`
  - `vaultShareRateProviders[]`
  - `reservePool`, token indexes (`detfIndex`, `bufferIndex`, `shareIndex[i]`)
  - `amplificationParameter` (mirror / read-through as needed)
  - `mintThreshold`, `burnThreshold`
  - `isReserveLive`
  - `feeOracle`, `bondNftVault`, `protocolNftId`, `rebasingClaimToken`
- [x] Validation on init (N, distinct, accept+produce buffer, amp, RP lengths).  
- [x] DFPkg `postDeploy`:
  1. ERC-20 facet stack for DETF.  
  2. Deploy MixedBuffer pool via pool pkg:  
     `unpairedCount=1`, `unpairedTokens=[detfToken]`, `unpairedRateProviders=[0]`,  
     `bufferToken`, vaults, share RPs only, deployer amp.  
  3. Persist indexes, thresholds, aware repos.  
  4. Deploy full bond NFT vault (principal asset = reserve BPT) via protocol package.  
  5. Wire rebasing claim package (`rateAsset` / payout boundary = `bufferToken`).  
  6. Multi-asset basic vault token list: DETF + buffer + vault shares + reserve BPT.  
  7. **No owner** left on instance; **inert** (pool not initialized).  
- [x] Common: load math balances from MixedBuffer views; synthetic; `DETFThresholdPolicy` helpers.  
- [x] Info views: layout, vaults, buffer, amp, thresholds, synthetic, mint/burn allowed, live, accepted bond tokens.

**Tests**

- [x] Deploy inert N=1,2; pool token count \(T=2+N\); buffer STANDARD; DETF STANDARD.  
- [x] Invalid config reverts.  
- [x] Synthetic readable; mint/burn/ongoing bond blocked while inert.

**Exit:** Inert multi-leg instances with MixedBuffer registered, bond/claim wired, no mint until bootstrap.

---

### Phase 2 — `bootstrapFirstBond` → live; bonding surface

**Product + plan rules**

- Live **only** after successful **`bootstrapFirstBond`**.  
- Pre-live: normal mint/burn/ongoing bond revert.  
- Bootstrap: permissionless (D29); multi-asset non-DETF legs; proportional DETF seed (**§3.4**); init reserve (M15); bond NFT; seigniorage split (**P1**); live.  
- After live: `acceptedBondTokens()` = **buffer ∪ vaultShare[i] ∪ reserveBpt** (**P6**).

**API (normative for this plan)**

```solidity
function bootstrapFirstBond(
    uint256 bufferAmount,
    uint256[] calldata vaultShareAmounts, // length == N; all > 0
    uint256 lockDuration,
    address recipient,                     // bond NFT + free DETF recipient (0 => msg.sender)
    uint256 deadline
) external returns (uint256 tokenId, uint256 bptPrincipal, uint256 freeDetfToUser);
```

**Deliverables**

- [x] `bootstrapFirstBond` implementation in Bonding facet/target.  
- [x] Pull buffer + all shares; compute \(d\) via §3.4; mint/join/init; residual clean.  
- [x] Bond lock clamp via `DETFBondNFTMathLib` / fee oracle terms.  
- [x] Bond NFT create via `DETFBondLifecycleLib`.  
- [x] Protocol / fee-recipient NFT wiring as peer DETFs.  
- [x] Ongoing `bond(tokenIn, amount, lock, …)` for buffer, vaultShare, reserve BPT after live.  
- [x] `sellPositionToProtocol` → principal to protocol NFT → `mintFromNFTSale` on claim.

**Tests**

- [x] Permissionless bootstrap by third party.  
- [x] Missing/zero leg reverts; double bootstrap reverts.  
- [x] Peg-seed formula unit tests + hermetic bootstrap balance checks.  
- [x] Free DETF / feeTo / protocol slices asserted (P1).  
- [x] Lock min/max clamp.  
- [x] Post-live bond buffer, share, BPT.

**Exit:** First bootstrap makes instance live; seigniorage mint correctly still gated by synthetic after live.

---

### Phase 3 — ExchangeIn mint (buffer / vaultShare → DETF)

**Deliverables**

- [x] Require live + mint threshold.  
- [x] `tokenIn ∈ {bufferToken} ∪ {vaultShare[i]}`.  
- [x] Quote DETF out via **StableMath-aware** helpers using **math balances** + amp + fees + share rates (not physical buffer alone).  
- [x] Seigniorage incentive on input notional (rate-scaled) before curve quote; fee split; join:
  - Buffer path (**P7**): unbalanced buffer + DETF self as required.  
  - Share path: unbalanced share + DETF self as required.  
- [x] `previewExchangeIn` shares quote path with execution.  
- [x] Residual clean.

**Tests**

- [x] Mint from buffer and from **each** vault share (N=1 and N=2).  
- [x] Preview == execution (exact preferred).  
- [x] Mint reverts inert / unsupported routes / threshold closed.  
- [x] Fee / protocol slice destinations.  
- [x] Non-dilution on existing holders.

**Exit:** Multi-input seigniorage mint proven on production SE + MixedBuffer.

---

### Phase 4 — Burn / ExchangeOut (DETF → buffer only)

**Deliverables**

- [x] Require live + burn threshold.  
- [x] `tokenOut = bufferToken` only; share outs → `InvalidRoute`.  
- [x] Exit reserve toward buffer (pool may pre-seat deepest vault — DETF does not reimplement).  
- [x] Preview matches execution.  
- [x] Residual clean.

**Tests**

- [x] Burn to buffer.  
- [x] Burn to vaultShare reverts `InvalidRoute`.  
- [x] Threshold guards.  
- [x] Residual assertions.

**Exit:** Full mint/burn lifecycle (buffer mint + share mint + buffer burn).

---

### Phase 5 — Price-shift suites (default thresholds)

**Deliverables**

- [x] Helpers that **trade underlying pools** of composed SE vaults.  
- [x] Suites using **default** mint/burn thresholds (1.05 / 0.95):
  - After bootstrap near peg: deadband.  
  - After mint-side skew: mint succeeds.  
  - After burn-side skew: burn to buffer succeeds.  
- [x] At least N=2 multi-protocol or multi-pool skew path.

**Exit:** Green price-shift tests prove gates under real market movement (documented).

---

### Phase 6 — Rebasing claim + redeem to buffer

**Deliverables**

- [x] Wire production `IRebasingClaimToken` (`RebasingClaimTokenDFPkg` via `Detf*FactoryService`) — **role names only**.  
- [x] On NFT sale: mint claim via lifecycle lib / peer path.  
- [x] Redeem orchestration:
  1. Burn claim shares atomically with unwind.  
  2. Unwind protocol-owned reserve BPT.  
  3. Exit toward **`bufferToken`**.  
  4. Transfer buffer to recipient.  
- [x] Never treat claim amounts as free BPT authority without burning claim shares.

**Tests**

- [x] Bond → sell → claim mint.  
- [x] Redeem → buffer; residual clean.  
- [x] Insufficient principal reverts cleanly.

**Exit:** Full bond → sell → claim → buffer redeem on production legs.

---

### Phase 7 — Nested DETF leg + N-range + matrix expansion (**P8**)

**Deliverables**

- [x] Nested production DETF (prefer **SingleStandardExchangeDETF** hermetic; DualLiquidity fork and/or ComposedStable as capacity allows) as one `underlyingVaults[k]` whose share is a MixedBuffer share leg and whose rateAsset/processing is compatible with the outer `bufferToken` **or** document a nested provider that uses nested DETF token as share with appropriate rate config.  
  - Preferred nested shape: outer buffer = nested rate asset / common cash so accept+produce buffer still holds.  
  - If nested DETF cannot accept outer buffer as SE asset, use nested DETF **share** as a vaultShare leg only if the nested diamond is a valid SE that accepts+produces the outer buffer — otherwise choose DualLiquidity / protocol SE that shares buffer.  
- [x] N=3 deploy smoke + bootstrap + one mint + one bond.  
- [x] Multi-protocol N=2 (e.g. Camelot + Aerodrome) hermetic when buffer can be shared (same ERC20).  
- [x] Fork matrix rows as capacity allows.  
- [x] Opacity review: no concrete protocol imports in production mixedBuffer DETF sources.

**Tests**

- [x] Nested mint/burn outer; inner still works (P8).  
- [x] N=3 smoke + size watch (`forge build --sizes` if tight).  
- [x] RP matrix: all STANDARD shares; one WITH_RATE share; mixed.

**Exit:** Composition, nested, and max-N smoke green.

---

### Phase 8 — Hardening and docs

**Deliverables**

- [x] Reentrancy suite (hostile ERC20 as **configured vault share** only; SUT remains production DETF).  
- [x] Facet `IFacet` tests for every facet.  
- [x] Optional invariant / sequence expansion.  
- [x] PRD checklist sync; status → **IMPLEMENTED** when done.  
- [x] `Agents.md` family table pointer: when to use **mixedBuffer stable** vs weighted multi-vault vs single SE.  
- [x] Update this plan progress log + checkboxes.

**Exit:** Hardening green; docs updated.

---

## 6. Implementation order (file-level)

1. Interface + DFPkg + factories + inert deploy (registry path, production SE + MixedBuffer).  
2. Repo + Common (storage, synthetic on math balances, residual, join/exit primitives, peg seed pure helpers).  
3. Bond NFT + claim wire + **`bootstrapFirstBond`** → live (P1/P2/P5).  
4. Ongoing bond buffer / share / BPT (P4/P6).  
5. ExchangeIn mint + query (buffer + shares).  
6. ExchangeOut burn + residual (buffer only).  
7. Info facet.  
8. Price-shift helpers + suites under default thresholds.  
9. Claim sell + redeem to buffer.  
10. Nested DETF leg + N=3 + multi-protocol matrix.  
11. Reentrancy, IFacet metadata, Agents.md, PRD checklist.

**Reuse** `contracts/vaults/detf/core/*` and `reusable/*` wherever possible.  
**Do not** subclass peer family contracts.  
**Do not** reimplement MixedBuffer pool routing.

---

## 7. Package / deploy path checklist

```solidity
// Facets — CREATE3 only
facet = create3Factory.deployMixedBufferMultiVaultStableDetfExchangeInFacet(); // via FactoryService

// DFPkg — registry only
vm.prank(owner);
pkg = indexedexManager.deployMixedBufferMultiVaultStableDetfDFPkg(pkgInit);
// or typed manager helper / deployPkg

// Instance
vm.prank(owner);
detf = indexedexManager.deployVault(IStandardVaultPkg(address(pkg)), abi.encode(args));

// Liveness — anyone
MixedBufferMultiVaultStableDetf(detf).bootstrapFirstBond(bufferAmt, shareAmts, lock, recipient, deadline);
```

**Anti-patterns (never):**

```solidity
new MixedBufferMultiVaultStableDetfDFPkg(...);
diamondPackageFactory.deploy(IDiamondFactoryPackage(vaultPkg), args); // bypass registry for vault DFPkg
MockStandardExchange se = new MockStandardExchange(...);
// auto-deploy default rate providers for share legs
// buffer or DETF WITH_RATE
```

---

## 8. Facet surface (expected)

| Component | Responsibilities |
|-----------|------------------|
| `…Repo` | Storage + init validation + live flag |
| `…Common` | Synthetic (math balances), StableMath quotes, join/exit, residual, lock clamp, peg seed, mint split helpers |
| `…ExchangeIn*` | Mint buffer/share → DETF + preview |
| `…ExchangeOut*` | Burn DETF → buffer + preview |
| `…Bonding*` | `bootstrapFirstBond` + ongoing bond buffer/share/BPT + sell → claim |
| `…Claim*` (optional split) | Claim redeem orchestration to buffer |
| `…Info*` | Layout, synthetic, gates, accepted bond tokens, vaults, amp |
| `…DFPkg` + FactoryServices | Crane CREATE3 + Vault Registry |

Exact facet split may adjust for contract size; preserve interface clarity and IFacet metadata tests.

---

## 9. Error catalog (indicative — freeze names in Repo)

Prefer family-local errors; map peer names only when identical semantics:

| Condition | Suggested error |
|-----------|-----------------|
| Not live / pool not init | `ReservePoolNotInitialized` |
| Unsupported token pair | `InvalidRoute` |
| N out of range | `InvalidVaultCount` |
| Duplicate vault | `DuplicateVault` |
| Vault missing buffer | `BufferTokenNotInVault` |
| Bad amp | `InvalidAmplification` |
| Bad RP config | `InvalidRateConfig` |
| Mint gate | `MintingNotAllowed` |
| Burn gate | `BurningNotAllowed` |
| Bootstrap after live | `AlreadyLive` |
| Bootstrap incomplete legs | `InvalidBootstrapAmounts` |
| Lock too short | peer bond lock error |

---

## 10. Acceptance criteria

### Product

- [x] Fresh path under `detf/composed/stable/mixedBuffer/` only.  
- [x] Role names only; no product tickers / brand roles.  
- [x] Immutable unowned instance.  
- [x] Live only after permissionless multi-asset `bootstrapFirstBond`.  
- [x] Mint: buffer or vaultShare → DETF; burn: DETF → buffer only.  
- [x] Bond: buffer, vaultShare, **reserve BPT** after live; claim redeem → buffer.  
- [x] Nested SE/DETF legs work; production sources opaque to protocol types.  
- [x] No buffer/DETF rate providers; optional share RPs only.

### Quality

- [x] Preview == execution on closed-form paths.  
- [x] No residual free inventory after success paths.  
- [x] Non-dilution on mint for existing holders (fees accounted).  
- [x] Synthetic gates match `DETFThresholdPolicy` + math-balance valuation.  
- [x] Peg seed formula §3.4 covered by hermetic tests.  
- [x] **No SUT/SE/MixedBuffer mocks** in lifecycle tests; reentrancy harness only where needed.

### Test matrix (v1 done when all required rows green)

| Area | Required |
|------|----------|
| Deploy guards + N=1..3 deploy | Yes |
| Bootstrap permissionless + peg seed + live | Yes |
| Pre-live guards | Yes |
| Mint buffer + each vaultShare; preview==exec | Yes |
| Burn buffer only; share burn `InvalidRoute` | Yes |
| Default-threshold price-shift | Yes |
| Bond buffer / share / BPT; lock clamp | Yes |
| Sell → claim → redeem buffer | Yes |
| RP STANDARD / WITH_RATE share matrix | Yes |
| Nested DETF-as-leg (P8) | Yes |
| Residual + reentrancy P0 | Yes |
| IFacet metadata | Yes |
| Fork multi-protocol expansion | Best-effort after hermetic green |

---

## 11. Risks and mitigations (plan-owned)

| Risk | Mitigation |
|------|------------|
| Peg seed wrong → bad init | §3.4 freeze + pure + hermetic balance tests |
| Synthetic uses physical buffer | Common must use `virtualBuffer` / math balances only |
| Bootstrap multi-asset UX / arg mistakes | Dedicated `bootstrapFirstBond`; strict all-legs non-zero |
| Nested DETF cannot share outer buffer | Nested provider must satisfy accept+produce buffer; otherwise use DualLiquidity/protocol SE that does |
| Contract size | Split Claim / Query facets; reuse core libs |
| Confusion with Single SE burn-to-share | Route tests assert buffer-only burn |
| Pool always-route surprises | Residual policy only; no DETF re-routing |

---

## 12. Document control

| Item | Value |
|------|--------|
| Plan path | `contracts/vaults/detf/composed/stable/mixedBuffer/MixedBufferMultiVaultStableDetf_IMPLEMENTATION_AND_TEST_PLAN.md` |
| PRD | `MixedBufferMultiVaultStableDetf_PRD.md` |
| Pool PRD / plan | `…/mixedBufferMultiVault/MixedBufferMultiVaultStablePool_*.md` |
| Status | **IMPLEMENTED** — hermetic suite green 2026-07-26 |

### Implementation checklist (roll-up)

- [x] PRD requirements locked (D1–D30)  
- [x] Implementation + test plan (incl. I1 / P2 formula, P1–P9)  
- [x] Repo + Common  
- [x] DFPkg: MixedBuffer pool + inert DETF + bond + claim  
- [x] `bootstrapFirstBond` (permissionless)  
- [x] Mint buffer / share → DETF  
- [x] Burn DETF → buffer  
- [x] Ongoing bond buffer / share / BPT; sell → claim → redeem buffer  
- [x] Price-shift under default thresholds  
- [x] Production-first matrix N=1..3 + nested DETF  
- [x] Adversarial P0 reentrancy  
- [x] AGENTS.md family table pointer  

---

## Appendix A — Owner / plan Q&A encoding

| Answer | Encoding |
|--------|----------|
| Match Single SE bootstrap fee/free DETF | **P1** |
| Rate-scaled peg seed | **P2** / §3.4 |
| Protocol bond + claim via Detf*FactoryService | **P3** |
| Unbalanced buffer bond → BPT | **P4** |
| Dedicated `bootstrapFirstBond` | **P5** |
| Allow `bond(reserveBpt)` after live | **P6** (extends D21 lean) |
| Unbalanced buffer + DETF self mint join | **P7** |
| Nested DETF-as-leg in v1 | **P8** |
| Full plan, drive end-to-end | **P9** |

## Appendix B — Comparison (implementation focus)

| Dimension | Single SE DETF | MultiVault Weighted | **This family** |
|-----------|----------------|---------------------|-----------------|
| Reserve | Weighted 2-token | Weighted 2..8 | **MixedBuffer Stable 3..5** |
| Live path | First bond shares | First bond BPT (multi-leg join) | **`bootstrapFirstBond` multi-asset + proportional DETF + init** |
| Mint in | vault share (+ allowlist) | vault shares | **buffer + vault shares** |
| Burn out | vault share (+ allowlist) | vault shares | **buffer only** |
| Bond inputs | shares | BPT + shares | **buffer + shares + BPT** |
| Nested in v1 | matrix | planned | **required (P8)** |
