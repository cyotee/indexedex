# Optional Rate Providers — Inventory & Refactor Report

**Date:** 2026-07-21  
**Context:** Research (`research/scenarios/uniswapV2Se/rateProviderCompare/`) found Standard Exchange rate providers improve nested mark integrity under Uni demand, but are **not beneficial for most product use cases** (LP $ under Uni-only demand is rate-agnostic; rates off freezes mid and can open residual lag that is often fee-drowned). Product preference: **allow** a rate provider when the deployer opts in; **do not force** deploy or `TokenType.WITH_RATE` when none is provided.

**Goal of this report:** Identify every pool / DETF / vault package that **enforces** rate-provider usage so follow-on work can make rates **optional** (set if provided, STANDARD + zero RP if not).

**Out of scope here:** Implementing the refactors (except DualLiquidity, already shipped). Research residual Mode A for DualLiquidity. Changing Balancer Vault behavior.

**Implementation plan (how to execute):** [`docs/OPTIONAL_RATE_PROVIDERS_IMPLEMENTATION_PLAN.md`](./OPTIONAL_RATE_PROVIDERS_IMPLEMENTATION_PLAN.md) — detailed phases W0–W10. Do not implement until that plan is accepted.

---

## 1. Summary matrix

| Component | Path | Enforces RP today? | Default | Runtime safe if STANDARD? | Priority |
|-----------|------|--------------------|---------|---------------------------|----------|
| DualLiquidity Linked Cross-Version | `contracts/vaults/detf/protocols/dexes/balancer/v3/uniswap/v4/crossVersion/v2/` | **No** (optional via `useRateProviders`) | **off** | Yes (`getPoolTokenRates` → 1e18) | **Done** |
| Single SE DETF | `contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/` | **No** (opt-in via non-zero `rateTarget`) | on if `rateTarget` set | Yes (Common guards zeros) | Low (docs/default only) |
| Multi-vault weighted DETF | `contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/` | **No** (per-leg optional; auto-deploy only when `rateAsset` set) | unrated if both zero | Yes | Low (clarify auto-deploy policy) |
| Single Vault DETF (composed) | `contracts/vaults/detf/composed/single/` | **Yes** — always deploy RP + WITH_RATE | forced on | Mostly (some paths guard zeros) | **P0** |
| Seigniorage DETF | `contracts/vaults/seigniorage/` | **Yes** — always deploy RP + WITH_RATE | forced on | **No** — underwriting calls `.getRate()` without zero check | **P0** |
| SE Buffer Pool (const-prod) | `.../constProd/standardExchange/` | **Yes** — always deploy RP + WITH_RATE; hook **requires** WITH_RATE | forced on | **Product-coupled** (rate drives effective weights) | **P0** (design decision) |
| Multi-pair SE Buffer | `.../weighted/multiPairBuffer/` | **Yes** — zero `rateProviders[i]` → auto-deploy + WITH_RATE | forced on | Product-coupled (same pattern) | **P0** |
| Mixed-leg weighted buffer | `.../weighted/mixedLegBuffer/` | **Partial** — share legs auto-deploy if zero; unpaired already optional | share forced | Product-coupled for share legs | **P0** |
| Common-buffer multi-vault | `.../weighted/commonBufferMultiVault/` | **No** — never auto-deploy; `_optionalRateTokenConfig` | off if zero | Yes if hooks tolerate STANDARD | Low (verify hooks) |
| Generic const-prod pool pkg | `.../constProd/BalancerV3ConstantProductPoolStandardVaultPkg.sol` | **No** — caller supplies `TokenConfig[]` | caller | N/A | None |
| Composed Stable DETF | `.../detf/composed/stable/common/` | **N/A** — uses `rateAsset` for claim/mint settlement, not Balancer SE RPs on reserve | N/A | N/A | None (not this problem) |
| SE Rate Provider packages | `.../rateProviders/standardExchange/` | N/A (infra only) | N/A | N/A | Keep as opt-in tooling |

**Legend:** P0 = product still forces rates; change required for “optional by default.”

---

## 2. Desired end-state pattern (canonical)

Reuse the DualLiquidity / Single SE DETF / CommonBuffer pattern:

1. **Deploy-time only** — rate policy immutable after instance deploy.
2. **If rate provider address is non-zero** (or explicit flag / non-zero rate target): register `TokenType.WITH_RATE` and wire that provider.
3. **If not provided:** register `TokenType.STANDARD`, `rateProvider = address(0)`; **do not** call `deployRateProvider`.
4. **TokenConfig helper** (shared style):

```text
_legTokenConfig(token, rateOrZero):
  if address(rateOrZero) != 0 → WITH_RATE + rateOrZero
  else → STANDARD + address(0)
```

5. **CREATE salt** must include rate policy (and/or RP addresses) whenever the same leg tokens can deploy in both modes (DualLiquidity already does this).
6. **Runtime:** prefer Vault `getPoolTokenRates` / zero-safe reads; never call `rateProvider.getRate()` without an address check (treat missing as `1e18`).
7. **Package binary:** `rateProviderPkg` on `PkgInit` may remain required so one package can deploy rates-on instances; skip instance RP deploy when off.
8. **Hooks / buffer math:** if a product *depends* on live SE rates for pricing (buffer pools), either:
   - **A)** Support STANDARD with rate=1e18 (weights freeze at baseline — document as rates-off product), or  
   - **B)** Keep rates required for that product family only and document the exception.

Research suggests default product preference is **A for nested weighted DETF reserves**; buffer pools need an explicit product call (see §4).

---

## 3. Component deep-dives

### 3.1 DualLiquidity Linked Cross-Version — **DONE**

| Item | Detail |
|------|--------|
| Package | `DualLiquidityLinkedCrossVersionUniswapVaultDFPkg.sol` |
| Policy | `PkgArgs.useRateProviders` (bool); default **false** in TestBase via `_useRateProviders()` |
| Deploy | RPs deployed only if true; salt encodes policy |
| Runtime | Exchange facets use Balancer rates (1e18 under STANDARD) |
| Tests | Default suite rates-off; `DualLiquidityLinkedCrossVersionUniswapVault_RatesOn.t.sol` regression |
| Plan | `DualLiquidity_OptionalRateProviders_IMPLEMENTATION_PLAN.md` |

**Action:** none for enforcement; optional follow-up residual research rates-on vs off.

---

### 3.2 Single Standard Exchange DETF — **already optional**

| Item | Detail |
|------|--------|
| Package | `SingleStandardExchangeDETDFPkg.sol` |
| Opt-in | Non-zero `PkgArgs.rateTarget` → `deployRateProvider` + WITH_RATE share leg |
| Opt-out | `rateTarget == address(0)` → STANDARD share leg, no RP (`_createRateProviderAndPool`) |
| TokenConfig | `_buildTokenConfigs` branches on `address(rateProvider_) != 0` |
| Runtime | `SingleStandardExchangeDETFCommon` zero-guards rate reads |

**Gap vs product default:** PRD (`SingleStandardExchangeDETF_PRD.md`) still describes rate provider as normative deploy step and WITH_RATE as the share leg type. Tests / deploy scripts often always pass a non-zero `rateTarget`.

**Actions:**

1. Update PRD: default recommendation **rates off** (`rateTarget = 0`); rates on is opt-in for nested mark integrity.
2. Point gold TestBase / matrix deploys at rates-off unless testing rates-on.
3. No DFPkg logic change required for optionality (already correct).

---

### 3.3 Multi-vault weighted DETF — **already optional (per leg)**

| Item | Detail |
|------|--------|
| Package | `MultiVaultWeightedDetfDFPkg.sol` |
| Opt-in | Non-zero `rateProviders[i]` **or** non-zero `rateAssets[i]` (auto-deploy RP when asset set and provider zero) |
| Opt-out | Both zero → unrated / STANDARD |
| Validation | Provider without rateAsset reverts `InvalidRateConfig` |
| Runtime | Common zero-guards |
| PRD | Explicitly optional per vault |

**Subtle enforcement:** providing only `rateAsset[i]` **forces** RP deploy (`_deployRateProviders`). That is “opt-in by rateAsset,” not “force always,” but differs from pure “RP address optional.”

**Actions:**

1. Document auto-deploy: “non-zero `rateAsset` implies rates on.”
2. Optional API simplification: only accept pre-deployed `rateProviders[i]`; never auto-deploy (stricter “provided or not”).
3. Defaults in TestBase already can zero both — keep default unrated.

---

### 3.4 Single Vault DETF (composed / Uni V4 leg) — **ENFORCES**

| Item | Detail |
|------|--------|
| Package | `SingleVaultDetfDFPkg.sol` |
| Enforce site | `_deployOwnedComposition`: always `RATE_PROVIDER_PKG.deployRateProvider(underlyingVault, RATE_ASSET)` |
| TokenConfig | `_createReservePool`: vault share leg hard-coded `TokenType.WITH_RATE` |
| Package init | `RATE_ASSET` immutable on package (not per-instance opt-out) |
| Runtime | Some helpers guard `vaultRateProvider != 0`; pool still registered WITH_RATE |

**Refactor plan:**

1. Add deploy-time opt-in, e.g. `PkgArgs.useRateProviders` **or** allow zero `rateAsset` meaning STANDARD.
2. Branch `_deployOwnedComposition` / `_createReservePool` like DualLiquidity / Single SE DETF.
3. Ensure 80/20 factory create accepts STANDARD low-weight leg.
4. Salt / pool identity: include rate policy if multiple modes share same underlying market.
5. Update PRD + TestBase default **off**.
6. Rates-on regression: one path with WITH_RATE + non-zero RP + mint/bond preview path.

**Files:**

- `SingleVaultDetfDFPkg.sol`
- `SingleVaultDetfCommon.sol` / Repo (verify no bare `.getRate()`)
- PRD / TestBases under composed single + any Protocol DETF deploy scripts

---

### 3.5 Seigniorage DETF — **ENFORCES** (+ unsafe runtime)

| Item | Detail |
|------|--------|
| Package | `SeigniorageDETFDFPkg.sol` |
| Enforce site | `postDeploy`: always `RESERVE_VAULT_RATE_PROVIDER_PKG.deployRateProvider(reserveVault, rateTarget)` |
| TokenConfig | Low-weight reserve vault leg hard-coded `WITH_RATE` |
| Commented API | `PkgArgs` once had `// IRateProvider reserveVaultRateProvider` — never finished optional path |
| Runtime **bug risk** | `SeigniorageDETFUnderwritingTarget.sol` L224, L381: `tokenInfo[...].rateProvider.getRate()` **without** zero check — will panic if STANDARD |

**Refactor plan:**

1. Add `PkgArgs.useRateProviders` (default false) **or** optional pre-supplied `reserveVaultRateProvider` + skip deploy when zero.
2. TokenConfig: WITH_RATE only when provider non-zero.
3. **Must** fix underwriting init/preview paths to:

```solidity
uint256 rate = address(info.rateProvider) == address(0)
    ? FixedPoint.ONE
    : info.rateProvider.getRate();
```

4. Grep seigniorage targets for any other bare `.getRate()`.
5. PRD / tests: default off; rates-on regression for underwrite bootstrap.

**Files:**

- `SeigniorageDETFDFPkg.sol`
- `SeigniorageDETFUnderwritingTarget.sol` (and siblings)
- Fork/spec seigniorage TestBases

---

### 3.6 Standard Exchange Buffer Pool (const-prod) — **ENFORCES** (product-coupled)

| Item | Detail |
|------|--------|
| Package | `StandardExchangeBufferPoolStandardVaultPkg.sol` |
| Enforce | `updatePkg` + `initAccount` always `deployRateProvider(seVault, tta)`; `_buildTokenConfigs` always WITH_RATE on shares |
| `PkgArgs` | Only `tta` + `standardExchangeVault` — **no** rate field |
| Repo | Stores `rateProvider` as core layout field |
| Hook | `onRegister` **returns false** unless share leg is `WITH_RATE` and RP matches repo (`StandardExchangeBufferHookTarget`) |
| Math | Effective weights from Vault rate vs `baselineRate`; product identity is rate-tracking |

**Product decision required before code change:**

| Option | Behavior when rates off |
|--------|-------------------------|
| **A (recommended if following research default)** | Allow STANDARD share leg; Vault rate = 1e18; weights stay at baseline (frozen mid). Document loss of rate-tracking. |
| **B** | Keep buffer pool rates-required as a deliberate exception (document; not “most use cases”). |

If **A**:

1. `PkgArgs`: add optional `IRateProvider rateProvider` (zero = off) and/or `bool useRateProviders`.
2. Stop auto-deploy when zero; only deploy when flag true or optional pre-built RP wanted.
3. `_buildTokenConfigs` → optional helper (see CommonBuffer).
4. Hook `onRegister`: accept STANDARD with zero RP **or** WITH_RATE with matching RP.
5. `_vaultSharesRateAndScale`: already uses Vault rates; STANDARD yields 1e18 — ensure `RateProviderZero` only on actual 0 (Balancer should not report 0 for STANDARD).
6. Baseline rate at init: still capture Vault rate (1e18).
7. Salt/identity: include rate policy.
8. Tests: rates-off deploy + join/swap smoke; rates-on regression.

**Files:**

- `StandardExchangeBufferPoolStandardVaultPkg.sol`
- `StandardExchangeBufferHookTarget.sol`
- `StandardExchangeBufferPoolCommon.sol` / Repo / Facets
- PRD / comparative research fixtures that assume R+

---

### 3.7 Multi-pair SE Buffer Pool — **ENFORCES** (auto-deploy)

| Item | Detail |
|------|--------|
| Package | `MultiPairStandardExchangeBufferPoolStandardVaultPkg.sol` |
| Enforce | `_preparePairsFull`: if `rateProviders[i] == 0` → **auto** `deployRateProvider` |
| TokenConfig | Share legs always `WITH_RATE` |
| Hook | Requires WITH_RATE on share indices (`MultiPairStandardExchangeBufferHookTarget`) |

**Refactor:** same as §3.6 — treat zero as intentional STANDARD (do **not** auto-deploy). Align with CommonBuffer L17 comment: *“never auto-deploy SE RP; use user-supplied only.”*

**Files:** package, hook target, Common, PRD, tests.

---

### 3.8 Mixed-leg weighted buffer — **partial enforce**

| Item | Detail |
|------|--------|
| Package | `MixedLegWeightedBufferPoolStandardVaultPkg.sol` |
| Share legs | Zero `pairRateProviders[i]` → **auto-deploy** + WITH_RATE |
| Unpaired legs | Already optional via `_unpairedTokenConfig` |
| Hook | Requires WITH_RATE on share legs |

**Refactor:** stop share-leg auto-deploy; use optional TokenConfig for share legs (mirror unpaired). Hook accept STANDARD shares.

---

### 3.9 Common-buffer multi-vault weighted — **already optional**

| Item | Detail |
|------|--------|
| Package | `CommonBufferMultiVaultWeightedPoolStandardVaultPkg.sol` |
| Policy | `_fillSharesAndRps`: *“L17: never auto-deploy SE RP; use user-supplied only (may be zero).”* |
| TokenConfig | `_optionalRateTokenConfig` |
| Hook | `CommonBufferMultiVaultWeightedPoolHookTarget` still checks WITH_RATE for some indices — **verify** registration still succeeds with STANDARD share legs |

**Actions:**

1. Audit hook `onRegister` for hard WITH_RATE requirements on vault share legs; relax if needed.
2. Confirm tests cover rates-off.
3. No auto-deploy change needed.

---

### 3.10 Generic Balancer const-prod Standard Vault package — **caller-controlled**

`BalancerV3ConstantProductPoolStandardVaultPkg` takes `TokenConfig[]` from the caller. No forced SE RP. **No change.**

---

### 3.11 Composed Stable DETF — **not Balancer SE rate providers**

Uses `rateAsset` for claim / settlement branding, not `StandardExchangeRateProvider` on a weighted reserve of SE shares. **Out of scope** for this optional-RP initiative unless a future design adds SE share legs to a stable pool.

---

### 3.12 Rate provider infrastructure — **keep**

| Package | Role |
|---------|------|
| `StandardExchangeRateProviderDFPkg` | Deploy SE-backed `IRateProvider` diamonds |
| `WrappedStandardExchangeRateProviderDFPkg` | ERC-4626-wrapped variant |
| Factory services | CREATE3 helpers |

These remain **opt-in tooling**. Do not delete. Packages that support rates-on still depend on them in `PkgInit`.

---

## 4. Runtime call sites that assume a non-zero rate provider

Bare or poorly guarded `getRate()` that will break under STANDARD:

| File | Issue | Fix |
|------|-------|-----|
| `SeigniorageDETFUnderwritingTarget.sol` (~L224, ~L381) | `tokenInfo[i].rateProvider.getRate()` always | Default `1e18` if address(0) |
| Buffer pool Commons | Revert `RateProviderZero` if Vault rate is 0 | Keep (real zero is invalid); STANDARD should report 1e18 |
| Buffer hooks | Reject register unless WITH_RATE | Accept STANDARD when rates optional |

**Already safe (patterns to copy):**

- `DETFBalancerScaleLib.sol` — checks `rateProvider != 0`
- `SingleStandardExchangeDETFCommon.sol` — zero → `ONE_WAD`
- `MultiVaultWeightedDetfCommon.sol` — zero → `ONE_WAD`
- `SingleVaultDetfCommon.sol` — partial guards (audit all paths)

---

## 5. Recommended implementation order

```text
Phase 0  Product decisions
         - Buffer pools: rates optional (A) vs required exception (B)
         - MultiVault: keep auto-deploy-on-rateAsset vs never auto-deploy
         - Default product stance: rates OFF unless research/mark integrity requires ON

Phase 1  Safety fixes (even before optionality)
         - Seigniorage underwriting zero-safe getRate()

Phase 2  DETF enforcers → optional
         - SingleVaultDetfDFPkg (+ tests/PRD)
         - SeigniorageDETFDFPkg (+ tests/PRD)

Phase 3  Buffer enforcers (if Phase 0 = A)
         - StandardExchangeBufferPool*
         - MultiPair* (stop auto-deploy)
         - MixedLeg* share legs (stop auto-deploy)
         - Hook onRegister relaxations
         - Confirm CommonBuffer hooks allow STANDARD

Phase 4  Defaults & docs
         - Single SE DETF / MultiVault PRDs: default off language
         - TestBases default to off; keep rates-on regression per family
         - AGENTS.md / research open questions cross-links

Phase 5  Verification per family
         - Compile FOUNDRY_PROFILE=default
         - Family suite green rates-off
         - Rates-on regression: WITH_RATE + non-zero RP + one live path
         - Salt/address distinctness where both modes share leg tokens
```

DualLiquidity is complete and is the **reference implementation** for Phases 2–3.

---

## 6. Concrete code change checklist (by file)

### P0 — must change for optionality

- [ ] `contracts/vaults/detf/composed/single/SingleVaultDetfDFPkg.sol` — stop always-deploy; optional TokenConfig
- [ ] `contracts/vaults/seigniorage/SeigniorageDETFDFPkg.sol` — stop always-deploy; optional TokenConfig
- [ ] `contracts/vaults/seigniorage/SeigniorageDETFUnderwritingTarget.sol` — zero-safe rate
- [ ] `contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/StandardExchangeBufferPoolStandardVaultPkg.sol` — optional RP args; no force deploy
- [ ] `.../StandardExchangeBufferHookTarget.sol` — register STANDARD
- [ ] `.../multiPairBuffer/MultiPairStandardExchangeBufferPoolStandardVaultPkg.sol` — **remove** auto-deploy on zero
- [ ] `.../multiPairBuffer/MultiPairStandardExchangeBufferHookTarget.sol` — register STANDARD shares
- [ ] `.../mixedLegBuffer/MixedLegWeightedBufferPoolStandardVaultPkg.sol` — **remove** share auto-deploy
- [ ] `.../mixedLegBuffer/MixedLegWeightedBufferPoolHookTarget.sol` — register STANDARD shares

### P1 — docs / defaults / verification

- [ ] `SingleStandardExchangeDETF_PRD.md` + TestBase defaults
- [ ] `MultiVaultWeightedDetf` auto-deploy policy note
- [ ] `CommonBufferMultiVault*HookTarget` STANDARD audit
- [ ] Family PRDs / TestBases / rates-on regression tests
- [ ] Deploy scripts that encode `PkgArgs` for any of the above

### Done / reference

- [x] DualLiquidity `useRateProviders` + salt + RatesOn suite
- [x] Single SE DETF `rateTarget == 0` path
- [x] MultiVault per-leg zeros
- [x] CommonBuffer never auto-deploy + `_optionalRateTokenConfig`

---

## 7. Non-goals / do not break

- Do not remove rate-provider packages or FactoryServices.
- Do not force DualLiquidity back to always-on.
- Do not introduce per-leg mix on DualLiquidity v1 (homogeneous flag remains).
- Do not dual-codepath entire exchange facets for rates on/off — rely on Balancer rates (1e18).
- Do not treat research Mode A residual as a release gate for optionality (follow-up marketing/research).

---

## 8. Acceptance criteria (when a family is “done”)

For each refactored family:

1. Deploy without RP succeeds; pool token info shows STANDARD + zero RP for previously forced legs.
2. Deploy with RP (flag or non-zero arg) restores WITH_RATE + non-zero providers.
3. No `deployRateProvider` when policy off (trace / assert).
4. Preview≈execution (or documented bounds) under default rates-off.
5. CREATE salt / pool address differs for on vs off when same legs.
6. PRD + NatSpec state default off and opt-in on.
7. Production deploy path remains CREATE3 + registry (no `new` DFPkg/facets for SUT).

---

## 9. Quick reference — enforce vs optional (one-liners)

| Family | How rates are forced today | How to opt out after refactor |
|--------|----------------------------|-------------------------------|
| DualLiquidity | — | `useRateProviders: false` (default) |
| Single SE DETF | — (already) | `rateTarget: address(0)` |
| MultiVault weighted | auto-deploy if `rateAsset` set | zero `rateProvider` and `rateAsset` |
| Single Vault DETF | always deploy to package `RATE_ASSET` | add flag / optional rate asset |
| Seigniorage | always deploy | add flag / optional RP |
| SE Buffer (const-prod) | always deploy | optional RP / flag |
| MultiPair buffer | auto-deploy on zero RP array slot | zero means STANDARD (no auto) |
| MixedLeg buffer | auto-deploy share RPs | zero means STANDARD (no auto) |
| CommonBuffer multi | — (already) | zero share/unpaired RP arrays |

---

*Report authored for handoff. Prefer implementing against DualLiquidity as the gold template and buffer-pool product decision before large buffer PRD rewrites.*
