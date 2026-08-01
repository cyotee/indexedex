# DualLiquidity Linked Cross-Version — Optional Rate Providers Implementation Plan

## Purpose

Refactor `DualLiquidityLinkedCrossVersionUniswapVault` so reserve share legs can be registered **with or without** Balancer Rate Providers, with a product-preferred default of **no rates** (`STANDARD`), while preserving the existing rates-on path as an explicit opt-in.

This plan is ready for execution after concurrent work in this repo is complete. **Do not start implementation until the user signals that the other agent is done.**

## Status

**DONE** — optional rates shipped: default off (STANDARD), opt-in on (WITH_RATE); fork suite green (183/183).

## Background (as-built)

| Fact | Location |
|------|----------|
| Rates are **forced** | `DualLiquidityLinkedCrossVersionUniswapVaultDFPkg._deployLegsAndPool` always `deployRateProvider` ×3 and `_rateTokenConfig` → `TokenType.WITH_RATE` |
| `PkgArgs` has no rate flag | Interface on same file: tokens, pool keys, weights, `optionalSalt` only |
| `PkgInit` requires `rateProviderPkg` | Immutable on package; TestBase always supplies it |
| Repo does **not** store rate provider addresses | Runtime uses Balancer `getPoolTokenRates` via Common helpers |
| PRD assumes rates mandatory | `DualLiquidityLinkedCrossVersionUniswapVault_PRD.md` Reserve Topology |
| Tests assume WITH_RATE | Fork suite under `test/foundry/fork/base_main/vaults/detf/protocols/dexes/balancer/v3/uniswap/v4/crossVersion/v2/` |
| Research context | `research/scenarios/uniswapV2Se/rateProviderCompare/AGENT_RESEARCH_REPORT.md` — rates improve mark fairness; default product preference is often **no rates** |

## Locked product decisions (for this refactor)

Do not re-open without PRD note.

| Topic | Decision |
|-------|----------|
| Granularity | **Homogeneous** all three reserve legs (A, B, pair): all WITH_RATE or all STANDARD. No per-leg mix in v1. |
| Default | **`useRateProviders = false`** (STANDARD, no rate provider wiring). |
| Opt-in | `useRateProviders = true` restores current behavior (deploy 3 SE rate providers + WITH_RATE). |
| Instance immutability | Flag is **deploy-time only**. Wrong choice → abandon instance; ship new args. |
| Runtime facets | Prefer **no** dual codepaths in exchange targets: keep `getPoolTokenRates` (1e18 when STANDARD). |
| Package binary | Keep `rateProviderPkg` on `PkgInit` (non-zero) so one package can deploy both modes; skip instance RP deploy when flag false. |
| CREATE salt | Weighted pool salt **must** include rate policy (tokens alone collide across modes). |
| Tests | Existing suite deploys **default false**. Add/retain an explicit rates-on regression path. |

## Goals

1. Users/deployers can choose rate policy via `PkgArgs`.
2. Default matches product preference: **no Rate Providers**.
3. Existing fork tests green under default.
4. Rates-on path still deployable and covered by at least one test path.
5. PRD + NatSpec updated; no silent behavior change without docs.

## Non-goals

- Per-leg mixed WITH_RATE / STANDARD.
- Changing DualLiquidity route table, fee model (0.3% weighted create fee), or share math.
- Research Mode A residual suite for DualLiquidity (follow-up after this lands).
- Making `rateProviderPkg` optional zero on `PkgInit` (defer; keep required for simplicity).
- Editing production const-prod 5% research fee or Uni V2 SE research harness.

---

## Phase 0 — PRD / NatSpec (docs first)

**Files:**

- `contracts/vaults/detf/protocols/dexes/balancer/v3/uniswap/v4/crossVersion/v2/DualLiquidityLinkedCrossVersionUniswapVault_PRD.md`
- NatSpec on `IDualLiquidityLinkedCrossVersionUniswapVaultDFPkg` / DFPkg contract

**Tasks:**

1. [x] Document optional rates: default **off**; opt-in **on**.
2. [x] Document homogeneous three-leg policy.
3. [x] Update Reserve Topology table: rate providers “when `useRateProviders`”.
4. [x] Note bootstrap: STANDARD fair init uses raw share amounts; WITH_RATE uses live/rate-scaled sizing (existing path).
5. [x] Cross-link research handoff (optional): rates improve mark integrity; not required for package to function.

**Exit:** PRD matches locked decisions above.

---

## Phase 1 — Interface and deploy logic

**Primary file:**

- `contracts/vaults/detf/protocols/dexes/balancer/v3/uniswap/v4/crossVersion/v2/DualLiquidityLinkedCrossVersionUniswapVaultDFPkg.sol`

### 1.1 `PkgArgs`

Add:

```solidity
/// @dev If true, deploy SE rate providers for all three legs and register TokenType.WITH_RATE.
///      If false (default product preference), register STANDARD with zero rate provider.
bool useRateProviders;
```

Place after weights / before `optionalSalt` (or next to salt) consistently; update all ABI-encode call sites.

### 1.2 Deploy config stash (if needed)

If `postDeploy` only reads `DeployConfig` storage:

1. [x] Add `useRateProviders` to `DeployConfig` (or pass via existing stash path from `initAccount` / `processArgs`).
2. [x] Ensure both `initAccount` and `postDeploy` agree.

### 1.3 TokenConfig builder

Replace hard-coded WITH_RATE helper with:

```text
_legTokenConfig(address token, IRateProvider rateOrZero, bool useRates)
  → WITH_RATE + rate if useRates
  → STANDARD + address(0) if !useRates
```

### 1.4 `_deployLegsAndPool`

```text
deploy legs (always)
if useRateProviders:
  rateA/B/pair = RATE_PROVIDER_PKG.deployRateProvider(...)
else:
  rateA/B/pair = IRateProvider(address(0))
_createReservePool(cfg, d, useRateProviders)
```

### 1.5 Weighted pool salt

**Current (insufficient):**

```solidity
bytes32 salt = keccak256(abi.encode(cfgs[0].token, cfgs[1].token, cfgs[2].token));
```

**Required:** include policy, e.g.:

```solidity
bytes32 salt = keccak256(abi.encode(
    cfgs[0].token, cfgs[1].token, cfgs[2].token,
    useRateProviders,
    address(cfgs[0].rateProvider),
    address(cfgs[1].rateProvider),
    address(cfgs[2].rateProvider)
));
```

Or simpler: `abi.encode(token0, token1, token2, useRateProviders)` if tokens alone + flag is enough uniqueness.

### 1.6 Factory / component services

Search and update any helpers that construct `PkgArgs` or document package API:

- `DualLiquidityLinkedCrossVersionUniswapVault_*FactoryService.sol` (if they encode args)
- Deploy scripts under `scripts/` that deploy this vault (if any)

**Exit:** Package compiles; rates-off and rates-on deploys produce distinct pool salts and correct TokenConfig.

---

## Phase 2 — Existing tests → default **off**

**Root:**

- `test/foundry/fork/base_main/vaults/detf/protocols/dexes/balancer/v3/uniswap/v4/crossVersion/v2/`

**Key files (non-exhaustive; search for `PkgArgs` / `deployVault`):**

- `TestBase_DualLiquidityLinkedCrossVersionUniswapVault.sol`
- `DualLiquidityLinkedCrossVersionUniswapVault_*.t.sol` (Redemptions, AssetRedemptions, FactoryService, Permit2, etc.)

### 2.1 TestBase

1. [x] Wherever `PkgArgs` is filled for the SUT instance, set `useRateProviders: false` (product default).
2. [x] Keep deploying `rateProviderPkg` in package `PkgInit` (package still supports opt-in).
3. [x] Bootstrap / init amounts: verify still valid for STANDARD (raw share legs). Adjust only if init fails or mid is nonsensical.

### 2.2 Suite-wide

1. [x] `rg "PkgArgs|useRateProviders|deployVault" test/foundry/fork/base_main/vaults/detf/protocols/dexes/balancer/v3/uniswap/v4/crossVersion/v2`
2. [x] Every production SUT deploy uses **false** unless in rates-on matrix (Phase 3).
3. [x] Soften comments that assert “WITH_RATE” as the only mode; keep **preview == execution** asserts (should hold with rates = 1e18).

### 2.3 Run

```bash
FOUNDRY_PROFILE=default forge test \
  --match-path 'test/foundry/fork/base_main/vaults/detf/protocols/dexes/balancer/v3/uniswap/v4/crossVersion/v2/**' \
  -vv
```

(Use project’s usual fork env / RPC as already required by this suite.)

**Exit:** Full crossVersion fork suite green under rates **off**.

---

## Phase 3 — Rates-on regression coverage

Preserve prior behavior so WITH_RATE path does not rot.

**Options (pick one):**

| Option | Approach |
|--------|----------|
| **A (recommended)** | Thin test contract or TestBase hook `useRateProviders = true` + 1–2 high-value tests (e.g. leg-share redeem preview==exec, factory deploy smoke). |
| **B** | Parameterized TestBase boolean + two setup paths; run critical tests twice (heavier fork cost). |

Minimum:

1. [x] Deploy with `useRateProviders: true`.
2. [x] Assert pool token info: three legs `TokenType.WITH_RATE` and non-zero rate providers.
3. [x] At least one deposit/redeem preview == execution path that previously assumed WITH_RATE.

**Exit:** CI covers both modes; default path is off.

---

## Phase 4 — Docs and agent pointers

1. [x] Update package PRD status note for optional rates.
2. [x] If `AGENTS.md` or `docs/` mention DualLiquidity rates as always-on, align wording.
3. [x] Optional: one-line in `research/scenarios/uniswapV2Se/rateProviderCompare/AGENT_RESEARCH_REPORT.md` open questions → DualLiquidity optional rates shipped for follow-up residual research (only after this lands).

**Exit:** Humans/agents can discover default and opt-in without reading Solidity.

---

## Phase 5 — Verification checklist (executor)

Run before claiming done:

1. [x] `git grep useRateProviders` — all `PkgArgs` constructions set or intentionally default.
2. [x] Compile under `FOUNDRY_PROFILE=default` (no via_ir).
3. [x] Fork suite crossVersion: green, default **false**.
4. [x] Rates-on regression: green.
5. [x] Manual or test assert: same legs + `useRateProviders true` vs `false` produce **different** reserve pool addresses (salt).
6. [x] No forced `deployRateProvider` when flag false (trace or unit assert rate provider addresses zero in TokenConfig).
7. [x] CREATE3/registry path still used (no `new` DFPkg/facets in tests).

---

## Implementation order (execute in sequence)

```text
Phase 0  PRD
Phase 1  PkgArgs + DFPkg deploy/TokenConfig/salt (+ factory call sites)
Phase 2  TestBase + existing tests → useRateProviders: false; full suite green
Phase 3  Rates-on regression
Phase 4  Docs / pointers
Phase 5  Verification checklist
```

---

## Risk register

| Risk | Mitigation |
|------|------------|
| Stack-too-deep in DFPkg postDeploy | Keep branching small; reuse existing split helpers; do not expand Derived unless needed |
| Pool salt collision rates on/off | Always encode policy into salt |
| Bootstrap broken under STANDARD | Re-check first deposit / pool init amounts in TestBase |
| Preview ≠ execution after switch | Keep ScalingHelpers path; assert in suite |
| Concurrent agent conflicts | Wait for user “other agent done”; rebase/merge carefully; avoid editing files they own if still hot |
| Accidental default true | Explicit `false` in TestBase; PRD says false |

---

## File touch list (expected)

| Path | Change |
|------|--------|
| `.../DualLiquidityLinkedCrossVersionUniswapVaultDFPkg.sol` | PkgArgs, DeployConfig, deploy branch, TokenConfig, salt |
| `.../DualLiquidityLinkedCrossVersionUniswapVault_PRD.md` | Optional rates, default off |
| `.../DualLiquidity_*FactoryService.sol` | Only if they construct PkgArgs / docs |
| `test/foundry/fork/.../crossVersion/TestBase_*.sol` | `useRateProviders: false` |
| `test/foundry/fork/.../crossVersion/*.t.sol` | Defaults + optional rates-on file |
| This plan | Checkboxes flipped during execution |

---

## Out of scope follow-ups (after this refactor)

1. DualLiquidity research Mode A residual (rates on vs off) for marketing docs.  
2. Deploy-script configs for production Base instances (explicit flag per market).  
3. Fee-as-threshold UX on DualLiquidity closer (if any) — separate PRD.

---

## Execution gate

```text
[x] User confirms other agent work is finished / branch is free
[x] Implementer reads this plan + current DFPkg + TestBase
[x] Execute phases 0→5
[x] Report: suite command + pass, default flag confirmed, rates-on regression path named
```
**Report:** `FOUNDRY_PROFILE=fork forge test --match-path 'test/foundry/fork/base_main/vaults/detf/protocols/dexes/balancer/v3/uniswap/v4/crossVersion/v2/**' -vv` → **183 passed, 0 failed**. Default `_useRateProviders()=false`. Rates-on regression: `DualLiquidityLinkedCrossVersionUniswapVault_RatesOn.t.sol`.

---

*Plan authored for handoff. Prefer editing this file’s checkboxes during implementation rather than spawning a second plan.*
