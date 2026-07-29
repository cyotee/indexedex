# Mission: DETF Threshold Modes — P5b F4 ComposedStableCommonDetf implement only

**Goal:** Ship product-law **Policy / Open threshold modes** on **F4 ComposedStableCommonDetf** (trailing `PkgArgs.thresholdMode`, mode-aware synthetic gates, live-coupled info, Open suites T1–T19). Then mark **P5b `done`** in the tracker and **stop**.

Copy this entire file into a new agent session.

You are an **execution agent**. Implement production code and tests for **one sub-phase only**. Do not re-open product decisions. Do not implement F5 (P5c), F6, F7, or AGENTS.md.

---

## Program context (as of handoff)

| Phase | Status |
|-------|--------|
| **P0–P4** | `done` — core + F1–F3 shipped; PRD formal **LOCKED 2026-07-28** |
| **P5a** F4 + F5 plans | `done` |
| **P5b** F4 ComposedStableCommonDetf **implement** | **`todo` → you** |
| **P5c** F5 SingleVaultDetf implement | out of scope (after P5b) |
| **P6–P7** | out of scope |

Tracker: `contracts/vaults/detf/DETF_Threshold_Modes_PROGRESS.md` (update as you go).

**Whole P5 is `done` only when P5b + P5c are both green.** You complete **P5b only**.

---

## Read first (in order)

1. `contracts/vaults/detf/DETF_Threshold_Modes_PRD.md` — formal **LOCKED** + **§16**
2. `contracts/vaults/detf/DETF_Threshold_Modes_PROGRESS.md`
3. **Your plan (normative for this session):**  
   `contracts/vaults/detf/composed/stable/common/ComposedStableCommonDetf_Threshold_Modes_IMPLEMENTATION_AND_TEST_PLAN.md`
4. Upstream core (do not redesign): `contracts/vaults/detf/core/DETFThresholdPolicy.sol`
5. **Gold references (patterns only — do not rewrite F1–F3 unless a compile-break forces a one-line nested PkgArgs fix):**
   - F1: `contracts/vaults/detf/standardExchange/single/` — DFPkg / Repo / Common / Info / Facet / TestBase
   - F3 Open helper pattern if useful: product Open = `thresholdMode: Open` + thresholds `0,0`
6. **F4 sources to edit (plan touch list — re-grep as you go):**
   - `ComposedStableCommonDetfDFPkg.sol` — trailing mode, resolve/validate, emit once
   - `ComposedStableCommonDetfRepo.sol` — storage + init + getters
   - `ComposedStableCommonDetfCommon.sol` — mode-aware + **live-coupled** `_is*Allowed`
   - `ComposedStableCommonDetfExchangeIn.sol` — all mint/burn gate sites (incl. preview)
   - `ComposedStableCommonDetfExchangeOutQueryFacet.sol` — all burn gate sites (preview + execute)
   - Pricing / info facet surface for MUST views (`thresholdMode`, thresholds, `is*Allowed`) — plan §4.4
   - `ComposedStableCommonDetf_Component_FactoryService.sol` — PricingConfig / `buildPkgArgs`
   - `TestBase_ComposedStableCommonDetf.sol` / `TestBase_ComposedStableCommonDetf_Components.sol`
   - Specs under `test/foundry/spec/vaults/detf/composed/stable/common/**`
   - Grep nested / F1 matrix `PkgArgs` that construct this family
7. Repo `Agents.md` / `AGENTS.md` — registry deploy, production-first, role names only; no SUT mocks

---

## Scope (strict)

### In scope

- **F4 ComposedStableCommonDetf only:** PkgArgs/storage/init/event, mode-aware Common + live-coupled Info, facet selectors, FactoryService, TestBase helpers, Policy regression, Open suites (T1–T19), fix fixtures that break under resolve (`burn=0` → default burn, not Open)
- Update PROGRESS: P5b → `done` when DoD met; leave P5c `todo`; keep whole P5 `in_progress` until P5c finishes (or note clearly)

### Out of scope

- **F5 SingleVaultDetf** (spot→synthetic migration) — P5c
- F1–F3 product rewrites (nested PkgArgs trailing field updates OK if they fail compile)
- Claim redeem economics, MixedBuffer F3, F6/F7, AGENTS.md / family PRD conform (P7)
- Core lib API redesign
- UI, fee-oracle thresholds, asymmetric modes

---

## Locked product rules (do not re-litigate)

- Explicit `ThresholdMode { Policy, Open }`; **never** infer Open from `0` thresholds
- `0,0` → `1.05e18` / `0.95e18`; **`0` never means Open**
- After resolve: both modes reject `mintThreshold <= burnThreshold`
- Gates always **synthetic** — F4 already uses `_syntheticDetfEthPrice()`; **keep it** (no spot)
- Live check in **family** (plan: pool initialized / totalSupply probe shared with `_requireReservePoolInitialized`); core lib has **no `live` param**
- MUST: `thresholdMode()`, live-coupled `isMintingAllowed()`, `isBurningAllowed()`
- Event: `ThresholdModeSet(mode, mint, burn)` once at init, **resolved** values
- `PkgArgs`: append `thresholdMode` as **trailing** field (**after `routes`** per F4 plan §4.1)
- Keep Policy/gated tests; add Open suites; dual-path always-allow → product **Open** (as F1–F3)
- Production-first; role names only

---

## Upstream API (do not redesign)

```text
// contracts/vaults/detf/core/DETFThresholdPolicy.sol
enum ThresholdMode { Policy, Open }   // 0, 1

DEFAULT_MINT_THRESHOLD = 1.05e18
DEFAULT_BURN_THRESHOLD = 0.95e18

resolveAndRequireValidThresholds(mintArg, burnArg)
requireValidThresholdMode(uint8|ThresholdMode)

_isMintingAllowed(ThresholdMode, mintThreshold, price)  // Open → true; Policy strict >
_isBurningAllowed(ThresholdMode, burnThreshold, price)  // Open → true; Policy strict <
// 2-arg Policy wrappers still exist — migrate F4 call sites to 3-arg + mode
```

### F1–F3 gold patterns to mirror on F4

| Concern | Pattern as shipped |
|---------|-------------------|
| PkgArgs | Trailing `ThresholdMode thresholdMode` |
| Init | `requireValidThresholdMode` → `resolveAndRequireValidThresholds` → store resolved mint/burn + mode |
| Event | `ThresholdModeSet` once after storage write |
| Common | `if (!live) return false;` then 3-arg lib allow with synthetic price |
| Info | `thresholdMode()` + live-correct `is*Allowed` |
| Facet | Include new selectors in function arrays |
| Always-allow helper | **Product Open:** `_deployOpenMode*` with `thresholdMode: Open`, thresholds `0,0` |

### Critical as-implemented note (F1–F3)

`mint=1` + `burn=type(uint256).max` is **illegal** after pair validation (mint ≤ burn is false only if mint > burn — wait: mint=1 and burn=max means mint < burn, so **invalid**).  
Map legacy “always allow” helpers to **product Open** (`Open` + `0,0`), not extreme Policy with illegal pairs.

### F4-specific plan notes (do not skip)

1. **Already synthetic** — do not change price engine; only mode + resolve + live on info helpers.
2. **Gate sites on multiple facets** — ExchangeIn **and** ExchangeOutQueryFacet (preview + execute). Exhaustive §3.1 table in plan.
3. **Preview already gates** on F4 — keep parity after mode wiring (T12 when allowed).
4. **Today `burnThreshold: 0`** in IntegratedDeploy / Deploy tests does **not** mean Open; after resolve it becomes `0.95e18`. Remap fixtures that intended always-burn to product Open.
5. **Live** is family pool-initialized concept, not necessarily `isReserveLive` flag — extract non-reverting live probe for views; do not invent a second liveness ledger.
6. **Nested modes independent** when this DETF is an SE leg.

---

## Process

1. Set **P5b** to `in_progress` in `DETF_Threshold_Modes_PROGRESS.md` (date + note). Keep P5 whole-phase `in_progress` until P5c done.
2. Implement exactly per F4 plan (order in plan §10 is recommended).
3. Fix all `PkgArgs` / PricingConfig literals for trailing `thresholdMode`.
4. Add TestBase Open helpers + Open suite mapped to T1–T19 (concrete names in plan §9).
5. Run and keep green:

```bash
forge test --match-path 'test/foundry/spec/vaults/detf/composed/stable/common/**' -vv
```

Also fix/run any F1 matrix or nested paths that construct ComposedStable `PkgArgs` if they break compile or fail.

6. When plan §11 definition of done is met, mark **P5b `done`** (date + test counts). Leave **P5c `todo`**. Do **not** mark whole P5 `done`.
7. **Stop.** Do not start F5 / P5c.

---

## Exact verify commands

```bash
forge test --match-path 'test/foundry/spec/vaults/detf/composed/stable/common/**' -vv
forge build
```

Optional if you touch nested F1 matrix constructors:

```bash
# only if those files encode ComposedStable PkgArgs
forge test --match-path 'test/foundry/spec/vaults/detf/standardExchange/single/**ComposedStable*' -vv
```

---

## Success / definition of done

Plan checklist §11, including:

- [ ] Trailing `thresholdMode` after `routes`
- [ ] Resolve/validate both modes; `ThresholdModeSet` once resolved
- [ ] Mode-aware gates + `_syntheticDetfEthPrice()`; live in family/info
- [ ] All ExchangeIn **and** ExchangeOut/query gate sites covered
- [ ] MUST info surface + facet selectors
- [ ] FactoryService / TestBase Open helpers
- [ ] Policy suites green; Open suites T1–T19 mapped
- [ ] Production-first; role names only
- [ ] Verify command green (report pass count)
- [ ] PROGRESS P5b `done`; P5c still `todo`

---

## Handoff

- **Do not start P5c (F5 SingleVaultDetf)** in this session.
- Suggested next after oversight: `DETF_Threshold_Modes_P5C_F5_EXEC_AGENT_PROMPT.md` (to be written by oversight).
- Tracker changelog example:

> P5b F4 done: trailing thresholdMode, live-coupled mode-aware gates, Open suite; N/N common/** green. P5c F5 still todo.
