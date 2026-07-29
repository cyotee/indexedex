# Mission: DETF Threshold Modes — P2 F2 MultiVaultWeightedDetf only

You are an **execution agent**. Implement production code and tests for **one phase only**. Do not re-open product decisions. Do not implement F3 MixedBuffer or later waves.

---

## Program context

| Phase | Status (as of handoff) |
|-------|------------------------|
| **P0** Core `DETFThresholdPolicy` | `done` |
| **P1** F1 SingleStandardExchangeDETF | `done` — gold patterns live; copy behavior, not subclass |
| **P2** F2 MultiVaultWeightedDetf | **`todo` → you implement** |
| **P3+** | out of scope |

Tracker: `contracts/vaults/detf/DETF_Threshold_Modes_PROGRESS.md` (update as you go).

---

## Read first (in order)

1. `contracts/vaults/detf/DETF_Threshold_Modes_PRD.md` (product law + **§16**)
2. `contracts/vaults/detf/DETF_Threshold_Modes_PROGRESS.md`
3. `contracts/vaults/detf/composed/multi-vault-weighted/MultiVaultWeightedDetf_Threshold_Modes_IMPLEMENTATION_AND_TEST_PLAN.md` (**your plan**)
4. Upstream core (do not redesign): `contracts/vaults/detf/core/DETFThresholdPolicy.sol`
5. **F1 gold reference (patterns only — do not edit F1 unless a compile-break forces a one-line fix):**
   - `contracts/vaults/detf/standardExchange/single/SingleStandardExchangeDETDFPkg.sol` (resolve/validate/event)
   - `SingleStandardExchangeDETFRepo.sol` / `Common.sol` / `InfoTarget.sol` / `ExchangeInFacet.sol`
   - `TestBase_SingleStandardExchangeDETF.sol` (`_deployOpenModeDetf`, trailing `thresholdMode`)
6. F2 sources to edit:
   - `MultiVaultWeightedDetfDFPkg.sol`
   - `MultiVaultWeightedDetfRepo.sol`
   - `MultiVaultWeightedDetfCommon.sol`
   - `MultiVaultWeightedDetfInfoTarget.sol`
   - `MultiVaultWeightedDetfExchangeInFacet.sol`
   - `MultiVaultWeightedDetfExchangeInTarget.sol` / `ExchangeOutTarget.sol` (confirm gates)
   - `TestBase_MultiVaultWeightedDetf.sol`
   - Specs under `test/foundry/spec/vaults/detf/composed/multi-vault-weighted/**`
7. Repo `Agents.md` / `AGENTS.md` — manager vault-registry deploy; production-first; role names; no SUT mocks

---

## Scope (strict)

### In scope

- F2 **MultiVaultWeightedDetf** only: PkgArgs/storage/init/event, mode-aware Common + live-coupled Info, facet selectors, TestBase helpers, Policy regression, Open suites (T1–T19 as mapped), nested mode independence smoke recommended

### Out of scope

- F3 MixedBuffer, F4+, claim redeem product rules, UI
- Core lib API changes
- F1 rewrites (except fixing nested `PkgArgs` call sites if this TestBase deploys F1 and a field is missing — F1 should already have `thresholdMode`)
- Fee-oracle thresholds, asymmetric modes, cross-instance mode inheritance
- Formal PRD LOCKED / AGENTS.md (later)

---

## Upstream API (do not redesign)

### Core lib (`DETFThresholdPolicy.sol`)

```text
enum ThresholdMode { Policy, Open }   // 0, 1

DEFAULT_MINT_THRESHOLD = 1.05e18
DEFAULT_BURN_THRESHOLD = 0.95e18

resolveAndRequireValidThresholds(mintArg, burnArg)
requireValidThresholdMode(uint8|ThresholdMode)

_isMintingAllowed(ThresholdMode, mintThreshold, price)  // Open → true; Policy strict >
_isBurningAllowed(ThresholdMode, burnThreshold, price)  // Open → true; Policy strict <
// NO live param — family owns live/inert
```

Import: `contracts/vaults/detf/core/DETFThresholdPolicy.sol`

### F1 gold patterns (as shipped) — mirror on F2

| Concern | F1 pattern to copy |
|---------|-------------------|
| PkgArgs | Trailing `ThresholdMode thresholdMode` |
| Init | `requireValidThresholdMode` then `resolveAndRequireValidThresholds`; store resolved mint/burn + mode |
| Event | `ThresholdModeSet(mode, mint, burn)` once after storage write (Info interface) |
| Common | `if (!isReserveLive) return false;` then 3-arg lib allow with `_syntheticPrice()` |
| Info | `thresholdMode()` + live-correct `isMintingAllowed` / `isBurningAllowed` |
| Facet | Include `thresholdMode` selector in ExchangeIn facet arrays |
| Open deploy helper | Named Open helper with `thresholdMode: Open` |
| Dual-path | Plan: keep extreme **Policy** (`mint=1`, `burn=max`) separate from product **Open** |

**F1 note:** F1 TestBase may route `_deployOpenThresholdDetf` → `_deployOpenModeDetf` (Open). For F2, **prefer the F2 plan**: keep `_deployOpenThresholdDetf` / `N` as **Policy extreme dual-path** (T4b/T18) and add **`_deployOpenModeDetfN`** for product Open. Do not conflate them.

**Nested:** Outer F2 and nested F1 each have independent `thresholdMode` — no inheritance.

---

## Locked product rules (do not re-litigate)

- Explicit `ThresholdMode`; never infer Open from zeros or extreme Policy
- `0,0` → defaults; **`0` never means Open**
- Both modes: after resolve reject `mintThreshold <= burnThreshold`
- Gates always **synthetic** (`_syntheticPrice()`); live in family
- MUST: `thresholdMode()`, live-coupled `isMintingAllowed()`, `isBurningAllowed()`
- `ThresholdModeSet` once at init, resolved values
- Trailing `PkgArgs.thresholdMode`
- Multi-leg: N=1..3+ coverage where tests already parameterize N; no off-pool FX ledger
- First bond / `initializeReserve` paths stay **synthetically ungated**
- Production-first; role names only

---

## Implementation checklist (F2 plan §§4–12)

1. **Repo** — `ThresholdMode thresholdMode` on Storage + InitParams; `_initialize` stores it.
2. **PkgArgs** — trailing `thresholdMode` after `mintThreshold` / `burnThreshold` on `IMultiVaultWeightedDetfDFPkg.PkgArgs` (+ DeployConfig if any).
3. **Init** — validate mode → resolve/require pair → persist → emit `ThresholdModeSet` once.
4. **Common** — live short-circuit + 3-arg allow helpers (drop local default constants when safe).
5. **Info + Facet** — `thresholdMode()`; selector arrays in `MultiVaultWeightedDetfExchangeInFacet` (both listings).
6. **Execution** — confirm mint/burn: live require then mode-aware allow.
7. **TestBase**
   - `_buildPkgArgs` / all struct literals: set `thresholdMode` (default Policy)
   - Prefer `_deployDetfN(..., ThresholdMode mode)` overload with Policy default
   - Keep `_deployOpenThresholdDetf` / `N` as Policy + 1/max (document dual-path)
   - Add `_deployOpenModeDetfN(n)` with `thresholdMode: Open`, thresholds `0,0` (or custom for T19)
   - Nested SSE / outer helpers: explicit modes on both packages
8. **Tests** — Policy + multi-leg regression green; new Open suite file recommended:  
   `test/foundry/spec/vaults/detf/composed/multi-vault-weighted/MultiVaultWeightedDetf_ThresholdMode.t.sol`  
   Map T1–T19 per plan §9; nested outer Open / inner Policy (or reverse) smoke recommended.
9. **Grep** `PkgArgs({` and `mintThreshold:` under multi-vault-weighted contracts + tests (+ any fork that builds F2 args).
10. **PROGRESS.md** — P2 → `done` when DoD met.

Rollout order: Repo → DFPkg → Common → Info/Facet → TestBase → Policy regression → Open suite → nested smoke (§11).

---

## Process

1. Set **P2** to `in_progress` in `DETF_Threshold_Modes_PROGRESS.md` (date + note). Leave P0/P1 `done`.
2. Implement per F2 plan; product questions → PRD §16 / F2 plan only.
3. Compile iteratively as every F2 `PkgArgs` gains trailing `thresholdMode`.
4. Verify:

```bash
# Upstream smoke (optional but recommended)
forge test --match-path 'test/foundry/spec/vaults/detf/core/DETFThresholdPolicy.t.sol' -vv

# F2 primary gate
forge test --match-path 'test/foundry/spec/vaults/detf/composed/multi-vault-weighted/**' -vv

forge build
```

5. When F2 **definition of done** (plan §12 + tracker P2 checklist) is complete, mark **P2 `done`** (date + brief notes). Leave P3+ `todo`.
6. **Stop.** Do not start F3 / P3 / formal LOCKED.

---

## Success / definition of done

- [ ] Trailing `thresholdMode` on F2 PkgArgs; storage; resolve/validate; event once
- [ ] Mode-aware gates + `_syntheticPrice()`; live in family/info
- [ ] `thresholdMode()` + accurate `is*Allowed`
- [ ] Facet selectors updated
- [ ] Policy + dual-path extreme tests green
- [ ] Open suites for T3, T10–T13b, T17–T19 (+ T1/T4/T8/T11/T18 as mapped)
- [ ] Nested mode independence smoke (recommended)
- [ ] `forge test --match-path 'test/foundry/spec/vaults/detf/composed/multi-vault-weighted/**'` green
- [ ] `DETF_Threshold_Modes_PROGRESS.md` P2 → `done`

Tests you claim green must actually have been run.

---

## Risks to watch

| Risk | Action |
|------|--------|
| Conflating extreme Policy with Open | Separate helpers; T18 asserts mode Policy |
| Nested F1 `PkgArgs` missing mode | Use shipped F1 trailing field; modes independent |
| Multi-leg TestBase overloads | Default Policy overload minimizes churn |
| Info live coupling | Update Info/Liveness assertions like F1 |
| Double-emit `ThresholdModeSet` | Once after storage write |
| Mocking SUT | Forbidden |

---

## Handoff

When done, report:

1. P2 status in tracker  
2. Verify commands + pass/fail  
3. Open suite path(s)  
4. Any deviation from plan (must still satisfy PRD §16)  

Do **not** start P3 (F3 MixedBuffer). Oversight will gate the next phase.
