# Optional Rate Providers — Full Implementation Plan

## Purpose

Execute the inventory in [`docs/OPTIONAL_RATE_PROVIDERS_REFACTOR_REPORT.md`](./OPTIONAL_RATE_PROVIDERS_REFACTOR_REPORT.md): stop **enforcing** Standard Exchange Balancer Rate Providers on DETFs, buffer pools, and related vault packages. Rate providers remain **allowed** (opt-in); when none is provided, register reserve/share legs as `TokenType.STANDARD` with zero rate provider and **do not** call `deployRateProvider`.

**Do not implement until this plan is accepted.** Implementation is phased so safety fixes land before large package ABI changes, and so DualLiquidity remains the gold template.

## Status

**PLANNED** — inventory complete; DualLiquidity optional rates **already shipped** (reference implementation). No other family refactored under this plan yet.

## Source documents

| Doc | Role |
|-----|------|
| [`docs/OPTIONAL_RATE_PROVIDERS_REFACTOR_REPORT.md`](./OPTIONAL_RATE_PROVIDERS_REFACTOR_REPORT.md) | Inventory, force sites, priority matrix |
| [`contracts/vaults/detf/protocols/dexes/balancer/v3/uniswap/v4/crossVersion/v2/DualLiquidity_OptionalRateProviders_IMPLEMENTATION_PLAN.md`](../contracts/vaults/detf/protocols/dexes/balancer/v3/uniswap/v4/crossVersion/v2/DualLiquidity_OptionalRateProviders_IMPLEMENTATION_PLAN.md) | **Gold path** (done) |
| [`research/scenarios/uniswapV2Se/rateProviderCompare/AGENT_RESEARCH_REPORT.md`](../research/scenarios/uniswapV2Se/rateProviderCompare/AGENT_RESEARCH_REPORT.md) | Why rates off is product default for most cases |
| Family PRDs | Per-package product truth after edits |

## Locked product decisions (do not re-open without PRD note)

| Topic | Decision |
|-------|----------|
| Product default | **Rates off** (`STANDARD`, no instance RP deploy) for nested SE-share reserves and buffer share legs unless a family PRD marks an exception. |
| Opt-in | Non-zero rate provider / non-zero rate target / explicit `useRateProviders=true` restores `WITH_RATE` + live SE RP. |
| Immutability | Rate policy is **deploy-time only**. Wrong choice → abandon instance. |
| Homogeneity | DualLiquidity remains **homogeneous** three-leg policy. MultiVault keeps **per-leg** optionality (already shipped). |
| Auto-deploy policy | **Stop auto-deploying** RPs when the caller left RP address(es) zero. Exception: MultiVault may keep “non-zero `rateAsset` ⇒ deploy RP” as documented opt-in (Phase 1D); buffer packages **must not** auto-deploy on zero. |
| Buffer pools (product call) | **Option A (locked for this plan):** rates-off is allowed; Vault rate is 1e18; effective weights freeze at baseline (no live SE mark tracking). Document as intentional rates-off product. Option B (rates required forever) is **rejected** for consistency with research default. |
| Runtime | Prefer Vault `getPoolTokenRates` / zero-safe helpers. Never bare `rateProvider.getRate()` without `address != 0` (default `1e18`). Avoid dual exchange-facet codepaths for on/off. |
| Package binary | Keep `rateProviderPkg` on `PkgInit` (required) so one package deploys both modes; skip instance RP deploy when off. |
| CREATE salt | Include rate policy (and/or RP addresses) wherever the same leg tokens can exist in both modes. |
| Deploy path | CREATE3 facets + registry DFPkg path only. No `new` of SUT DFPkg/facets. |
| Tests | Default suite = rates **off**. Each refactored family gets ≥1 rates-on regression (WITH_RATE + non-zero RP + one live path with preview≈execution). |
| Research | Do **not** re-run full Mode A residual matrices as a gate; cite existing research report. |

## Goals

1. No production package **forces** SE rate providers when the deployer did not opt in.
2. Product default is rates **off** across enforcers (P0 families).
3. Opt-in path remains correct and tested.
4. Runtime is safe under STANDARD (no panic on zero RP).
5. PRD/NatSpec/TestBase defaults document the change (no silent flip).
6. DualLiquidity remains green and is not regressed.

## Non-goals

- Per-leg mix on DualLiquidity.
- Removing `StandardExchangeRateProvider*` packages.
- Composed Stable DETF claim `rateAsset` redesign (not Balancer SE RPs).
- Generic const-prod pool that already takes caller `TokenConfig[]`.
- Production Base market deploy scripts beyond fixing broken `PkgArgs` ABI sites.
- Research Mode A residual marketing suites for DualLiquidity / buffers.
- Making `rateProviderPkg` optional zero on `PkgInit`.
- Changing DualLiquidity route table, fee models, or share math.

---

## Canonical implementation pattern (copy this)

### TokenConfig

```solidity
function _optionalRateTokenConfig(address token_, IRateProvider rateOrZero_)
    internal pure returns (TokenConfig memory cfg_)
{
    bool withRate_ = address(rateOrZero_) != address(0);
    cfg_ = TokenConfig({
        token: OZIERC20(token_),
        tokenType: withRate_ ? TokenType.WITH_RATE : TokenType.STANDARD,
        rateProvider: withRate_ ? rateOrZero_ : IRateProvider(address(0)),
        paysYieldFees: false
    });
}
```

### Deploy branch

```text
if (useRates / rateOrTarget != 0):
  rp = RATE_PROVIDER_PKG.deployRateProvider(...)   // or use pre-supplied rp
else:
  rp = IRateProvider(address(0))                   // never deploy
TokenConfig = _optionalRateTokenConfig(token, rp)
```

### Zero-safe rate read

```solidity
function _tokenRate(TokenInfo memory info_) internal view returns (uint256) {
    if (address(info_.rateProvider) == address(0)) return 1e18;
    return info_.rateProvider.getRate();
}
```

Prefer Balancer Vault rates where already used (buffer commons, DualLiquidity, DETF scale libs).

### Salt

```solidity
bytes32 salt = keccak256(abi.encode(/* tokens... */, useRateProviders / ratePolicy, /* optional rp addrs */));
```

### TestBase hook (DualLiquidity style)

```solidity
function _useRateProviders() internal pure virtual returns (bool) { return false; }
// rates-on suite overrides → true
```

---

## Workstreams overview

| ID | Workstream | Priority | Depends on |
|----|------------|----------|------------|
| W0 | Global locks, shared helper guidance, plan gates | — | — |
| W1 | Runtime safety (Seigniorage bare `getRate`) | P0 safety | — |
| W2 | Single Vault DETF (composed) optional rates | P0 | W0 |
| W3 | Seigniorage DETF optional rates | P0 | W1 |
| W4 | SE Buffer Pool (const-prod) optional rates | P0 | W0 (Option A locked) |
| W5 | MultiPair buffer — stop auto-deploy | P0 | W4 patterns |
| W6 | MixedLeg buffer — stop share auto-deploy | P0 | W4 patterns |
| W7 | CommonBuffer multi — hook STANDARD audit | P1 | W4 patterns |
| W8 | Single SE DETF — docs + TestBase defaults | P1 | — |
| W9 | MultiVault weighted — auto-deploy policy docs | P1 | — |
| W10 | Cross-cutting docs, scripts, verification | P1 | W2–W9 |

**Parallelism:** W2 ∥ W3 after W1; W4 then W5 ∥ W6; W7–W9 anytime after W0. Prefer **one PR per workstream** (or stacked PRs) to keep review/blast radius sane.

**Reference already done:** DualLiquidity — do not re-implement; only avoid regressions.

---

## Phase W0 — Kickoff gates (docs only)

**Tasks:**

1. [ ] Confirm Option A for buffer pools (this plan locks it).
2. [ ] Confirm MultiVault keeps “rateAsset set ⇒ auto-deploy RP” as documented opt-in (no behavior change in W9 except docs unless product flips to never-auto-deploy).
3. [ ] Link this plan from the inventory report status line.
4. [ ] Note in `AGENTS.md` only if DualLiquidity wording is incomplete for *other* families (prefer family PRDs over bloating AGENTS).

**Exit:** Product locks above accepted; implementer proceeds W1+.

---

## Phase W1 — Runtime safety first (Seigniorage)

**Why first:** Optional rates without this will brick underwrite on STANDARD; even rates-on-only code is safer with zero guards.

### Files

| File | Change |
|------|--------|
| `contracts/vaults/seigniorage/SeigniorageDETFUnderwritingTarget.sol` | Replace bare `tokenInfo[i].rateProvider.getRate()` (~L224, ~L381) with zero-safe read (`1e18` if zero). |
| Grep siblings under `contracts/vaults/seigniorage/` | Any other bare `.getRate()` on TokenInfo / stored RP. |

### Tasks

1. [ ] Introduce local helper or use shared pattern:

```solidity
uint256 rate = address(info.rateProvider) == address(0)
    ? FixedPoint.ONE  // or 1e18 matching file style
    : info.rateProvider.getRate();
```

2. [ ] Apply to pool-init underwrite path and preview path.
3. [ ] Unit/fork smoke: existing seigniorage suite still green under **current** forced WITH_RATE (no product flip yet).

### Tests (W1 only)

```bash
FOUNDRY_PROFILE=default forge test --match-path 'test/foundry/spec/protocol/vaults/seigniorage/**' -vv
# if fork env available:
FOUNDRY_PROFILE=fork forge test --match-path 'test/foundry/fork/base_main/seigniorage/**' -vv
```

**Exit:** No bare zero-RP panic sites in seigniorage underwriting; suites green on pre-optional code.

---

## Phase W2 — Single Vault DETF (composed) — **ENFORCER → optional**

### Background (as-built)

| Fact | Location |
|------|----------|
| Always deploy RP | `SingleVaultDetfDFPkg._deployOwnedComposition` → `RATE_PROVIDER_PKG.deployRateProvider(underlyingVault, RATE_ASSET)` |
| Always WITH_RATE | `_createReservePool` low-weight leg hard-coded `TokenType.WITH_RATE` |
| Package-level rate asset | `PkgInit.rateAsset` / immutable `RATE_ASSET` — not instance opt-out today |
| Runtime | `SingleVaultDetfCommon` mostly zero-guards TokenInfo RP; Repo stores `vaultRateProvider` |

### Locked API for this family

Prefer DualLiquidity-style **explicit bool** (clearer than overloading package `RATE_ASSET`):

```solidity
// PkgArgs (instance)
bool useRateProviders; // default false product preference
```

When `useRateProviders == true`:

- Require package `RATE_ASSET` non-zero (existing package init).
- Deploy SE RP for underlying vault share denominated in `RATE_ASSET`.
- Register vault share leg `WITH_RATE`.

When `false`:

- Skip `deployRateProvider`.
- Store `vaultRateProvider = address(0)`.
- Register vault share leg `STANDARD`.
- DETF self leg remains `STANDARD`.

### Files to touch

| Path | Change |
|------|--------|
| `contracts/vaults/detf/composed/single/SingleVaultDetfDFPkg.sol` | `PkgArgs.useRateProviders`; DeployConfig stash if needed; branch deploy + `_createReservePool` / `_optionalRateTokenConfig`; NatSpec |
| `contracts/vaults/detf/composed/single/SingleVaultDetfCommon.sol` | Audit all rate reads; ensure `_tokenRate` / synthetic price paths treat zero RP as 1e18 (already mostly OK) |
| `contracts/vaults/detf/composed/single/SingleVaultDetfRepo.sol` | Allow zero `vaultRateProvider` in init |
| Family PRD (if present under composed/single or docs) | Optional rates, default off |
| `test/foundry/spec/vaults/detf/composed/single/**` | Default `useRateProviders: false`; all `PkgArgs` encode sites |
| New: `.../SingleVaultDetf_RatesOn.t.sol` (or thin override on ProductionBase) | Rates-on regression |
| Factory/service/helpers that encode `PkgArgs` | Update ABI field order |

### Implementation steps

1. [ ] **PRD/NatSpec first** — optional rates; default off; opt-in restores WITH_RATE.
2. [ ] Add `useRateProviders` to `PkgArgs` (after existing fields, before any salt if present; document order).
3. [ ] Stash flag into deploy config if `postDeploy` does not re-decode args.
4. [ ] Branch `_deployOwnedComposition`:
   - `if (useRateProviders) { vaultRateProvider = deployRateProvider(...); }`
   - else leave zero.
5. [ ] Replace hard-coded WITH_RATE in `_createReservePool` with `_optionalRateTokenConfig(underlyingVault, vaultRateProvider)`.
6. [ ] If 80/20 factory create identity depends only on tokens, ensure two policies do not collide if both can be deployed for same underlying (include policy in any package-controlled salt / name if applicable).
7. [ ] Grep all `PkgArgs({` / encode sites for this family; set `false` by default.
8. [ ] Soften WITH_RATE-only comments in tests.
9. [ ] Rates-on regression: override hook true → assert pool TokenInfo WITH_RATE + non-zero RP → one mint/bond or deposit preview≈execution.
10. [ ] Run family suite green rates-off.

### Verification (W2)

```bash
FOUNDRY_PROFILE=default forge build
FOUNDRY_PROFILE=default forge test --match-path 'test/foundry/spec/vaults/detf/composed/single/**' -vv
```

Asserts:

- Rates-off: vault share `TokenType.STANDARD`, RP address 0, no RP deploy.
- Rates-on regression: WITH_RATE + non-zero RP.
- Info surface `vaultRateProvider()` returns zero when off.

**Exit:** Single Vault DETF deployable both modes; default off; suite green.

---

## Phase W3 — Seigniorage DETF — **ENFORCER → optional**

### Background (as-built)

| Fact | Location |
|------|----------|
| Always deploy RP | `SeigniorageDETFDFPkg.postDeploy` → `RESERVE_VAULT_RATE_PROVIDER_PKG.deployRateProvider(reserveVault, rateTarget)` |
| Always WITH_RATE | Low-weight reserve vault leg hard-coded |
| PkgArgs | Has `reserveVault` + `reserveVaultRateTarget`; commented historical `reserveVaultRateProvider` |
| Runtime | W1 zero-safe underwriting |

### Locked API

```solidity
// PkgArgs
bool useRateProviders; // default false
// keep reserveVaultRateTarget for rates-on denomination + other product wiring
```

Semantics:

- `useRateProviders == false` → STANDARD reserve-vault leg; skip RP deploy; underwriting uses rate 1e18.
- `useRateProviders == true` → require non-zero `reserveVaultRateTarget`; deploy RP; WITH_RATE.

Alternative (acceptable if implementer prefers parity with commented field): optional `IRateProvider reserveVaultRateProvider` where non-zero means use supplied RP and WITH_RATE, zero means STANDARD without deploy. Prefer **bool + target** for consistency with DualLiquidity / Single Vault DETF.

### Files

| Path | Change |
|------|--------|
| `contracts/vaults/seigniorage/SeigniorageDETFDFPkg.sol` | Flag; branch postDeploy TokenConfig; NatSpec |
| `contracts/vaults/seigniorage/SeigniorageDETFUnderwritingTarget.sol` | Already W1; re-verify under STANDARD init math |
| Other seigniorage targets | Grep `getRate` / rate provider assumptions |
| `test/foundry/spec/protocol/vaults/seigniorage/**` | Default off |
| `test/foundry/fork/base_main/seigniorage/**` | Default off; `TestBase_SeigniorageDETF_Fork` |
| New rates-on regression file or hook | WITH_RATE + underwrite path |
| `Seigniorage_Component_FactoryService` / scripts encoding PkgArgs | Update |

### Implementation steps

1. [ ] PRD / NatSpec for seigniorage optional rates.
2. [ ] Add `useRateProviders` to `PkgArgs`; update all encode sites.
3. [ ] Branch pool create in `postDeploy`:
   - off → STANDARD + zero RP
   - on → deploy RP + WITH_RATE
4. [ ] Confirm underwrite **pool initialization** math is correct when rate is 1e18 (rated balances = raw).
5. [ ] Confirm exchange routes do not assume WITH_RATE-only scaling.
6. [ ] Default TestBase/fork off; rates-on regression.
7. [ ] Run spec + fork seigniorage suites.

### Verification (W3)

```bash
FOUNDRY_PROFILE=default forge test --match-path 'test/foundry/spec/protocol/vaults/seigniorage/**' -vv
FOUNDRY_PROFILE=fork forge test --match-path 'test/foundry/fork/base_main/seigniorage/**' -vv
```

**Exit:** Seigniorage default STANDARD; rates-on still underwrites; W1 guards proven under both modes.

---

## Phase W4 — Standard Exchange Buffer Pool (const-prod) — **ENFORCER → optional (Option A)**

### Background (as-built)

| Fact | Location |
|------|----------|
| Always deploy | `updatePkg` + `initAccount` both call `deployRateProvider(seVault, tta)` |
| Always WITH_RATE | `_buildTokenConfigs` share leg |
| PkgArgs | Only `tta` + `standardExchangeVault` |
| Hook gate | `onRegister` requires share `WITH_RATE` and RP match repo |
| Math | Effective weights from Vault rate vs `baselineRate` |

### Product implication (Option A)

Rates-off:

- Share leg STANDARD; Vault reports rate **1e18**.
- `baselineRate` at init ≈ 1e18 → effective weights stay **50/50** (frozen mid).
- Buffer no longer tracks SE share mark vs TTA via rates — **documented product tradeoff**.

### Locked API

```solidity
struct PkgArgs {
    IERC20 tta;
    IStandardExchange standardExchangeVault;
    /// @dev Zero = rates off (STANDARD). Non-zero = use this provider (WITH_RATE).
    ///      If zero and useRateProviders true, package deploys SE RP for (vault, tta).
    IRateProvider rateProvider; // optional pre-built
    bool useRateProviders;      // default false
}
```

**Simplification allowed:** only `bool useRateProviders` and always deploy when true (no pre-built RP field), matching DualLiquidity. Prefer that if stack pressure is high:

```solidity
bool useRateProviders; // false → STANDARD, no deploy; true → deployRateProvider(se, tta) + WITH_RATE
```

### Files

| Path | Change |
|------|--------|
| `.../StandardExchangeBufferPoolStandardVaultPkg.sol` | PkgArgs; stop forced deploy; optional TokenConfig; salt/identity if any |
| `.../StandardExchangeBufferHookTarget.sol` | `onRegister`: accept STANDARD+zero **or** WITH_RATE+matching RP |
| `.../StandardExchangeBufferPoolCommon.sol` | Confirm `RateProviderZero` only on actual 0; STANDARD path OK |
| `.../StandardExchangeBufferPoolRepo.sol` | Allow zero RP in storage if stored |
| PRD / design docs for buffer pool | Optional rates, frozen mid under off |
| Spec tests under `test/foundry/spec/protocols/dexes/balancer/v3/pools/constProd/standardExchange/**` (and related) | Default off; rates-on regression |
| Research fixtures that assume forced R+ | Document / optional flag — **do not** break research unless updating those scenarios separately |

### Implementation steps

1. [ ] PRD: Option A language (rates-off freezes mid at 1e18).
2. [ ] Extend `PkgArgs` with `useRateProviders` (and optional pre-supplied RP if desired).
3. [ ] `updatePkg` / `initAccount`:
   - if rates on: deploy or use supplied RP; WITH_RATE
   - if rates off: `rp = 0`; STANDARD; still init repo fields with zero RP
4. [ ] Hook `onRegister` logic:

```text
share STANDARD && rp==0  → OK (rates off)
share WITH_RATE && rp==repo.rp → OK (rates on)
else → reject
```

5. [ ] Init hook `onBeforeInitialize`: still seeds `baselineRate` from Vault (1e18 when STANDARD).
6. [ ] Salt / CREATE3 instance uniqueness: include rate policy in any salt that currently is only (tta, seVault).
7. [ ] Tests: rates-off deploy + initialize + swap/join smoke; rates-on regression; assert no auto-deploy when false.

### Verification (W4)

```bash
FOUNDRY_PROFILE=default forge test --match-path 'test/foundry/spec/protocols/dexes/balancer/v3/pools/constProd/**' -vv
# plus any buffer-specific match-contract names used in CI
```

**Exit:** Buffer pool deploys rates-off; hook accepts STANDARD; rates-on still tracks SE rate.

---

## Phase W5 — MultiPair SE Buffer — stop auto-deploy

### Background

`_preparePairsFull`: `if (rateProviders[i] == 0) rps[i] = deployRateProvider(...)` then always WITH_RATE.

### Locked behavior after change

| `rateProviders[i]` | Behavior |
|--------------------|----------|
| non-zero | Use it; share leg WITH_RATE |
| zero | **Do not deploy**; share leg STANDARD |

Same as CommonBuffer L17: *user-supplied only (may be zero)*.

### Files

| Path | Change |
|------|--------|
| `.../multiPairBuffer/MultiPairStandardExchangeBufferPoolStandardVaultPkg.sol` | Remove auto-deploy branch; optional TokenConfig for shares |
| `.../MultiPairStandardExchangeBufferHookTarget.sol` | Accept STANDARD shares (per index) |
| `.../MultiPairStandardExchangeBufferPoolCommon.sol` | Rate reads via Vault; STANDARD → 1e18 |
| PRD + `test/foundry/spec/.../multiPairBuffer/**` | Defaults + rates-on regression (supply RPs) |

### Steps

1. [ ] Delete auto-deploy; wire `_optionalRateTokenConfig(shares[i], rateProviders[i])`.
2. [ ] Hook: for each share index, allow STANDARD+0 or WITH_RATE+rp.
3. [ ] Update tests that relied on “pass zero and get a free RP” to either pass explicit RPs (rates-on) or assert STANDARD (default).
4. [ ] Suite green.

**Exit:** Zero RP array slots mean rates-off for that pair; no silent deploy.

---

## Phase W6 — MixedLeg weighted buffer — stop share auto-deploy

### Background

- Share legs: zero `pairRateProviders[i]` → auto-deploy + WITH_RATE.
- Unpaired: already optional via `_unpairedTokenConfig`.

### Locked behavior

Share legs use the same optional TokenConfig as unpaired; **no** auto-deploy.

### Files

| Path | Change |
|------|--------|
| `.../mixedLegBuffer/MixedLegWeightedBufferPoolStandardVaultPkg.sol` | `_fillPairSharesAndRps` remove deploy; optional share TokenConfig |
| `.../MixedLegWeightedBufferPoolHookTarget.sol` | Accept STANDARD share legs |
| PRD + `test/foundry/spec/.../mixedLegBuffer/**` | Defaults + rates-on regression |

### Steps

1. [ ] Mirror MultiPair / CommonBuffer optional pattern for pair share legs.
2. [ ] Hook relaxation for share indices.
3. [ ] Tests update for zero-vs-supplied RP.
4. [ ] Suite green.

**Exit:** MixedLeg share rates fully optional; unpaired unchanged.

---

## Phase W7 — CommonBuffer multi-vault — audit only (+ fix if needed)

### Background

Already never auto-deploys; uses `_optionalRateTokenConfig`. Hook may still hard-require WITH_RATE on some legs.

### Files

| Path | Task |
|------|------|
| `.../CommonBufferMultiVaultWeightedPoolHookTarget.sol` | Read `onRegister`; if WITH_RATE forced on share legs, relax to optional pattern |
| Spec suite `test/foundry/spec/.../commonBufferMultiVault/**` | Add rates-off assert if missing |

### Steps

1. [ ] Audit hook gates vs STANDARD share/unpaired.
2. [ ] Fix only if registration rejects valid rates-off configs.
3. [ ] One test: deploy with all zero RPs → STANDARD; optional rates-on with supplied RPs.

**Exit:** Confirmed optional end-to-end; no silent WITH_RATE requirement.

---

## Phase W8 — Single SE DETF — docs + defaults (no deploy logic change)

### Background

Logic already optional via `rateTarget == 0`. PRD and tests still bias rates-on.

### Files

| Path | Change |
|------|--------|
| `contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/SingleStandardExchangeDETF_PRD.md` | Default **off** (`rateTarget = 0`); rates on is opt-in for mark integrity |
| `contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/TestBase_SingleStandardExchangeDETF.sol` (and matrix TestBases) | Prefer `rateTarget: address(0)` for default instances |
| Rates-on regression | Existing nested/matrix cases that need rates keep non-zero `rateTarget` — name them as rates-on |
| NatSpec on `PkgArgs.rateTarget` | “Zero = STANDARD share leg; non-zero = deploy SE RP denominated in target” |

### Steps

1. [ ] PRD wording pass.
2. [ ] TestBase default `rateTarget = 0` **only if** suite still green under STANDARD (preview==execution, synthetic gates).
3. [ ] If suite depends on WITH_RATE for nested DETF abstract 1:1 paths, document which matrix rows stay rates-on and why.
4. [ ] No DFPkg code change unless a bug is found.

**Exit:** Humans/agents discover default off; CI still green; rates-on paths explicit.

---

## Phase W9 — MultiVault weighted — policy docs (+ optional API tighten)

### Background

Per-leg optional already. Auto-deploy when `rateAsset[i] != 0` and `rateProviders[i] == 0`.

### Locked for this plan

**Keep auto-deploy-on-rateAsset** (documented opt-in). Do not force all legs rated.

### Tasks

1. [ ] PRD already optional — add explicit sentence: “Setting `rateAsset[i]` without `rateProviders[i]` deploys an SE RP; both zero = STANDARD.”
2. [ ] NatSpec on `PkgArgs.rateProviders` / `rateAssets` match PRD.
3. [ ] TestBase default remains unrated (zeros) unless testing rates.
4. [ ] **Optional follow-up (out of scope unless product asks):** remove auto-deploy entirely (rateAsset alone insufficient; must pass RP). Not required for “do not enforce.”

**Exit:** Docs unambiguous; no forced all-leg rates.

---

## Phase W10 — Cross-cutting docs, scripts, final verification

### Docs / pointers

1. [ ] Update inventory report status → **IN PROGRESS / DONE** as phases land.
2. [ ] This plan checkboxes flipped per phase.
3. [ ] Research report open questions: note buffer/DETF optional rates when shipped (one-liners only).
4. [ ] `docs/LAUNCH_PLAN.md` / deploy notes only if they claim rates always-on for these products.

### Scripts

Search and fix encode sites:

```bash
rg -n "useRateProviders|rateTarget|rateProviders|deployRateProvider|PkgArgs" \
  scripts/ contracts/ test/ \
  --glob '*SingleVault*' --glob '*Seigniorage*' --glob '*Buffer*' --glob '*MultiPair*' --glob '*MixedLeg*'
```

Update any production/anvil scripts that construct these `PkgArgs` after ABI changes.

### Global greps (definition of “no more enforcement”)

```bash
# Auto-deploy anti-patterns on zero (should be gone from buffer packages)
rg -n "if \(address\(.*[Rr]ate.*\) == address\(0\)\).*deployRateProvider|deployRateProvider" \
  contracts/protocols/dexes/balancer/v3/pools/

# Forced WITH_RATE without branch
rg -n "tokenType:\s*TokenType\.WITH_RATE" contracts/vaults contracts/protocols/dexes/balancer/v3/pools

# Bare getRate on TokenInfo (should be zero-safe)
rg -n "rateProvider\.getRate\(\)" contracts/vaults contracts/protocols/dexes/balancer/v3/pools
```

### Final suite matrix

| Family | Command (indicative) |
|--------|----------------------|
| DualLiquidity (regression) | `FOUNDRY_PROFILE=fork forge test --match-path 'test/foundry/fork/base_main/vaults/detf/protocols/dexes/balancer/v3/uniswap/v4/crossVersion/v2/**' -vv` |
| Single Vault DETF | `FOUNDRY_PROFILE=default forge test --match-path 'test/foundry/spec/vaults/detf/composed/single/**' -vv` |
| Seigniorage | spec + fork paths above |
| Buffer / MultiPair / MixedLeg / CommonBuffer | matching `test/foundry/spec/protocols/dexes/balancer/v3/pools/**` paths |
| Compile | `FOUNDRY_PROFILE=default forge build` (no via_ir) |

### Per-family acceptance criteria (repeat for W2–W7)

1. Rates-off deploy: forced legs `STANDARD` + zero RP; no `deployRateProvider` when off.
2. Rates-on regression: `WITH_RATE` + non-zero RP; one live path preview≈execution (or documented wei bound).
3. Salt/pool address differs for on vs off when same economic legs.
4. CREATE3/registry path retained.
5. PRD + NatSpec state default off / opt-in on.
6. Default TestBase = off.

**Exit (program complete):** All P0 workstreams Done; P1 docs done; greps clean of forced auto-deploy; DualLiquidity still green.

---

## Shared helper extraction (optional, not blocking)

If copy-paste of `_optionalRateTokenConfig` proliferates, consider a tiny internal library e.g.:

`contracts/protocols/dexes/balancer/v3/rateProviders/OptionalRateTokenConfigLib.sol`

**Defer** until ≥2 buffer packages are in-flight in the same PR. Prefer local private helpers first (stack/import simplicity).

---

## Risk register

| Risk | Mitigation |
|------|------------|
| Stack-too-deep in DFPkg postDeploy | Keep branches small; split helpers like DualLiquidity / Single SE DETF |
| Buffer math “broken” under STANDARD | Option A is intentional frozen mid; document; still test join/swap |
| Hook rejects STANDARD after TokenConfig change | Update `onRegister` in same PR as TokenConfig |
| Seigniorage init underwrite wrong at rate=1e18 | W1 + explicit init tests rates-off |
| Test suites assumed free auto-deploy | Update TestBases to pass RPs only in rates-on files |
| ABI break for PkgArgs | Grep all encode sites; fix scripts; note in PR description |
| Concurrent agent edits | One family per PR; DualLiquidity already done — avoid re-touch unless regression |
| Research fixtures force R+ | Leave research paths rates-on explicitly; do not “fix” by flipping research default without a research plan |
| Salt collision rates on/off | Always encode policy into salt where CREATE is package-controlled |

---

## Implementation order (execute in sequence)

```text
W0   Locks / plan acceptance
W1   Seigniorage zero-safe getRate          ← safety, small
W2   Single Vault DETF optional             ← DETF P0
W3   Seigniorage DETF optional              ← DETF P0 (after W1)
W4   SE Buffer const-prod optional          ← buffer P0 + Option A
W5   MultiPair stop auto-deploy
W6   MixedLeg stop share auto-deploy
W7   CommonBuffer hook audit
W8   Single SE DETF docs/defaults
W9   MultiVault docs
W10  Cross greps, scripts, full verification, mark Done
```

**Parallel ok:** W2 ∥ (W1 then W3); after W4: W5 ∥ W6; W8 ∥ W9 anytime.

---

## File touch list (expected)

### Production (P0)

```text
contracts/vaults/detf/composed/single/SingleVaultDetfDFPkg.sol
contracts/vaults/detf/composed/single/SingleVaultDetfCommon.sol  # audit only if needed
contracts/vaults/detf/composed/single/SingleVaultDetfRepo.sol    # allow zero RP
contracts/vaults/seigniorage/SeigniorageDETFDFPkg.sol
contracts/vaults/seigniorage/SeigniorageDETFUnderwritingTarget.sol
contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/StandardExchangeBufferPoolStandardVaultPkg.sol
contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/StandardExchangeBufferHookTarget.sol
contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/StandardExchangeBufferPoolCommon.sol  # if needed
contracts/protocols/dexes/balancer/v3/pools/weighted/multiPairBuffer/MultiPairStandardExchangeBufferPoolStandardVaultPkg.sol
contracts/protocols/dexes/balancer/v3/pools/weighted/multiPairBuffer/MultiPairStandardExchangeBufferHookTarget.sol
contracts/protocols/dexes/balancer/v3/pools/weighted/mixedLegBuffer/MixedLegWeightedBufferPoolStandardVaultPkg.sol
contracts/protocols/dexes/balancer/v3/pools/weighted/mixedLegBuffer/MixedLegWeightedBufferPoolHookTarget.sol
contracts/protocols/dexes/balancer/v3/pools/weighted/commonBufferMultiVault/CommonBufferMultiVaultWeightedPoolHookTarget.sol  # audit
```

### Tests (P0 + P1)

```text
test/foundry/spec/vaults/detf/composed/single/**
test/foundry/spec/protocol/vaults/seigniorage/**
test/foundry/fork/base_main/seigniorage/**
test/foundry/spec/protocols/dexes/balancer/v3/pools/constProd/**
test/foundry/spec/protocols/dexes/balancer/v3/pools/weighted/multiPairBuffer/**
test/foundry/spec/protocols/dexes/balancer/v3/pools/weighted/mixedLegBuffer/**
test/foundry/spec/protocols/dexes/balancer/v3/pools/weighted/commonBufferMultiVault/**
+ new *RatesOn*.t.sol (or TestBase hooks) per family
```

### Docs

```text
docs/OPTIONAL_RATE_PROVIDERS_REFACTOR_REPORT.md   # status updates
docs/OPTIONAL_RATE_PROVIDERS_IMPLEMENTATION_PLAN.md  # this file checkboxes
Family PRDs (Single SE, MultiVault, buffer PRDs, seigniorage if any)
research/.../AGENT_RESEARCH_REPORT.md            # optional one-liner when shipped
```

### Already done (do not re-scope)

```text
contracts/vaults/detf/protocols/dexes/balancer/v3/uniswap/v4/crossVersion/v2/DualLiquidity (removed)CrossVersionUniswapVaultDFPkg.sol
test/.../crossVersion/** including DualLiquidity (removed)CrossVersionUniswapVault_RatesOn.t.sol
```

---

## PR / delivery strategy

| PR | Contents |
|----|----------|
| PR1 | W1 only (seigniorage zero-safe rate) |
| PR2 | W2 Single Vault DETF optional rates |
| PR3 | W3 Seigniorage optional rates |
| PR4 | W4 SE Buffer optional rates |
| PR5 | W5 + W6 MultiPair + MixedLeg stop auto-deploy |
| PR6 | W7–W10 docs, Single SE defaults, MultiVault docs, greps, residual script fixes |

Each PR must include: production change, TestBase default off, rates-on regression (where applicable), PRD/NatSpec, suite command + green evidence.

---

## Executor checklist (before claiming program Done)

1. [ ] Inventory report status = DONE for all P0 rows.
2. [ ] `rg deployRateProvider` in buffer packages: no “if zero then deploy” pattern.
3. [ ] `rg "rateProvider.getRate()"` in vaults/pools: all zero-safe or Vault-mediated.
4. [ ] DualLiquidity fork suite still green (no regression).
5. [ ] Each P0 family: rates-off suite green + rates-on regression green.
6. [ ] Compile `FOUNDRY_PROFILE=default` success.
7. [ ] This plan’s phase checkboxes flipped.

---

## Execution gate

```text
[ ] Product accepts Option A for buffer pools (locked in this plan; reconfirm if disputed)
[ ] Implementer reads inventory report + DualLiquidity gold plan + this plan
[ ] Execute W0→W10 in order (with allowed parallelization)
[ ] Report: per-family suite commands + pass, default flag confirmed, rates-on paths named
```

---

*Plan authored for handoff. Prefer editing this file’s checkboxes during implementation rather than spawning a second plan. Inventory report remains the “what”; this document is the “how.”*
