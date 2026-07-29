# Mission: DETF Threshold Modes — P1 F1 SingleStandardExchangeDETF only

You are an **execution agent**. Implement production code and tests for **one phase only**. Do not re-open product decisions. Do not implement F2/F3 or change the core lib API.

---

## Read first (in order)

1. `contracts/vaults/detf/DETF_Threshold_Modes_PRD.md` (product law + **§16** encoding locks)
2. `contracts/vaults/detf/DETF_Threshold_Modes_PROGRESS.md` (single execution tracker — **update as you go**)
3. `contracts/vaults/detf/standardExchange/single/SingleStandardExchangeDETF_Threshold_Modes_IMPLEMENTATION_AND_TEST_PLAN.md` (**this is your plan**)
4. Upstream core (shipped — **do not redesign**):
   - `contracts/vaults/detf/core/DETFThresholdPolicy.sol`
   - Pure unit tests: `test/foundry/spec/vaults/detf/core/DETFThresholdPolicy.t.sol` (P0 already `done`)
5. Family sources (edit these):
   - `SingleStandardExchangeDETDFPkg.sol`
   - `SingleStandardExchangeDETFRepo.sol`
   - `SingleStandardExchangeDETFCommon.sol`
   - `SingleStandardExchangeDETFInfoTarget.sol`
   - `SingleStandardExchangeDETFExchangeInFacet.sol`
   - `SingleStandardExchangeDETFExchangeInTarget.sol` / `ExchangeOutTarget.sol` (confirm gates only)
   - `TestBase_SingleStandardExchangeDETF.sol`
6. Repo `Agents.md` / `AGENTS.md` — CREATE3 + manager vault-registry path; **production-first**; role names only (`rateAsset`, `pairToken`, …); no mocks of SUT DETF / manager / registry / fee oracle / SE vaults

---

## Scope (strict)

### In scope

- F1 **SingleStandardExchangeDETF** package + Common/Info/gates + facet selectors + TestBase + Policy regression + Open suites (T1–T19 as mapped in the F1 plan)

### Out of scope

- F2 MultiVaultWeightedDetf, F3 MixedBuffer, F4+, claim redeem, UI
- Core lib redesign (P0 is done)
- Fee-oracle threshold control, asymmetric modes, seigniorage split changes by mode
- Preview path adding new gate reverts (keep ungated preview math; T12 = preview==execution when **allowed**)
- AGENTS.md / formal PRD LOCKED (later phases)

---

## Upstream API (do not redesign) — as implemented in P0

Import path: `contracts/vaults/detf/core/DETFThresholdPolicy.sol`

```text
enum ThresholdMode { Policy, Open }   // Policy=0, Open=1

error InvalidThresholdPair(uint256 mintThreshold, uint256 burnThreshold);
error InvalidThresholdMode(uint8 mode);

DEFAULT_MINT_THRESHOLD = 1.05e18
DEFAULT_BURN_THRESHOLD = 0.95e18

resolveThresholds(mintArg, burnArg) → (mint, burn)   // 0 → defaults; does NOT validate pair
isValidThresholdMode(uint8|ThresholdMode)
isValidThresholdPair(mint, burn)                     // mint > burn
resolveAndRequireValidThresholds(mintArg, burnArg)   // resolve then revert InvalidThresholdPair if mint <= burn
requireValidThresholdMode(uint8|ThresholdMode)

// Mode-aware (primary) — NO live param; Open short-circuits true; Policy strict > / <
_isMintingAllowed(ThresholdMode mode, uint256 mintThreshold, uint256 price)
_isBurningAllowed(ThresholdMode mode, uint256 burnThreshold, uint256 price)
_isOpenMode(ThresholdMode mode)

// 2-arg Policy wrappers (legacy unported families) — F1 should use 3-arg form
_isMintingAllowed(uint256 threshold, uint256 price)
_isBurningAllowed(uint256 threshold, uint256 price)
```

**Live / inert is family-only** — never add `live` to the core lib.

---

## Locked product rules (do not re-litigate)

- Explicit `ThresholdMode`; **never** infer Open from `0` thresholds or extreme Policy (`mint=1`, `burn=max`)
- `0,0` → `1.05e18` / `0.95e18`; **`0` never means Open**
- After resolve: **both** Policy and Open reject `mintThreshold <= burnThreshold` (`InvalidThresholdPair`)
- Gates always **synthetic** (`_syntheticPrice()`); live check in **family**, not core lib
- MUST expose: `thresholdMode()`, `isMintingAllowed()`, `isBurningAllowed()` — Info views **live-coupled** (inert ⇒ both false; PRD §4.5)
- Event once at init: `ThresholdModeSet(mode, mint, burn)` with **resolved** values
- `PkgArgs`: append `thresholdMode` as **trailing** field only
- Keep Policy/gated suites; keep `_deployOpenThresholdDetf` as **extreme Policy dual-path** (T4b/T18); add `_deployOpenModeDetf` with `thresholdMode: Open`
- Production-first; role names only

---

## Implementation checklist (follow F1 plan §§4–12)

1. **Repo** — append `ThresholdMode thresholdMode` to storage; extend `_initialize` to accept and store mode (append param; document signature).
2. **PkgArgs** — trailing `ThresholdMode thresholdMode` on `ISingleStandardExchangeDETDFPkg.PkgArgs` (and DeployConfig if used).
3. **Init** (`initAccount` / `_initFamilyRepo`):
   - `requireValidThresholdMode(args.thresholdMode)`
   - `(mint, burn) = resolveAndRequireValidThresholds(args.mintThreshold, args.burnThreshold)`
   - Persist resolved mint/burn + mode
   - Emit `ThresholdModeSet` **once** after storage write (resolved values)
4. **Common** — rewrite `_isMintingAllowed` / `_isBurningAllowed`:
   - if `!isReserveLive` → `false`
   - else 3-arg `DETFThresholdPolicy._is*(s.thresholdMode, s.*Threshold, _syntheticPrice())`
   - Prefer core `DEFAULT_*`; drop local default constants when safe
5. **Info** — add `thresholdMode()`; keep mint/burn threshold getters; ensure `is*Allowed` use live-coupled Common helpers
6. **Facet selectors** — include `thresholdMode` in `SingleStandardExchangeDETFExchangeInFacet` arrays (both listings if duplicated); bump lengths
7. **Execution gates** — confirm `exchangeIn` / `_burnDetfExactIn` still: `_requireReserveLive` then mode-aware allow → `MintingNotAllowed` / `BurningNotAllowed`. First bond remains **not** synthetically gated
8. **TestBase**
   - All `PkgArgs({...})` set `thresholdMode` (zero/Policy default for existing paths)
   - Keep `_deployOpenThresholdDetf` as Policy + mint=1 / burn=max; NatSpec: extreme Policy, not product Open
   - Add `_deployOpenModeDetf` with `thresholdMode: Open`
9. **Tests** — Policy regression green; Open suite (recommended new file `SingleStandardExchangeDETF_ThresholdMode.t.sol`); fix Info tests for live coupling; grep/fix all `PkgArgs({` / `mintThreshold:` under F1 specs + fork matrices that construct this package’s args
10. **PROGRESS.md** — update P1 through `done` when DoD met

Rollout order inside F1 is in the plan §11 — follow it.

---

## Process

1. Set **P1** to `in_progress` in `DETF_Threshold_Modes_PROGRESS.md` (date + short note). Leave P0 `done`.
2. Implement exactly per the F1 plan. Product questions → answer from PRD §16 / F1 plan; do not invent modes or ABI layouts.
3. Compile iteratively: every `PkgArgs` struct literal must include trailing `thresholdMode`.
4. Run and keep green:

```bash
# Upstream still green (smoke)
forge test --match-path 'test/foundry/spec/vaults/detf/core/DETFThresholdPolicy.t.sol' -vv

# F1 primary gate
forge test --match-path 'test/foundry/spec/vaults/detf/standardExchange/single/**' -vv

# Compile whole tree when PkgArgs/facet changes ripple
forge build
```

5. When F1 **definition of done** (plan §12 + tracker P1 checklist) is met, mark **P1 `done`** in the progress tracker (date + brief notes: files, Open suite path, test command result). Leave P2+ as `todo`.
6. **Stop.** Do not start F2/F3/P4.

---

## Success / definition of done

From the F1 plan and tracker:

- [ ] Trailing `PkgArgs.thresholdMode`
- [ ] Storage + init resolve/validate both modes; invalid pair/mode revert
- [ ] `ThresholdModeSet` once with resolved thresholds
- [ ] Mode-aware gates + `_syntheticPrice()`; live in family
- [ ] `thresholdMode()` + live-correct `isMintingAllowed` / `isBurningAllowed`
- [ ] Facet selectors include `thresholdMode`
- [ ] Existing Policy + extreme dual-path tests green
- [ ] Open suites cover T3, T8/T11 Open, T10, T12–T13b, T17–T19 (and full T1–T19 map or N/A with reason)
- [ ] `forge test --match-path 'test/foundry/spec/vaults/detf/standardExchange/single/**'` green
- [ ] `DETF_Threshold_Modes_PROGRESS.md` P1 → `done`

Tests you claim green must actually have been run.

---

## Risks to watch

| Risk | Action |
|------|--------|
| Info tests assume `is*Allowed == synth ? threshold` without live | Update after live coupling |
| Many `PkgArgs` call sites (specs + fork) | Grep `PkgArgs({` and `mintThreshold:` |
| Double-emit of `ThresholdModeSet` | Emit once after storage write |
| Confusing extreme Policy with Open | Dual-path helper stays Policy; new Open helper only |
| Mocking SUT | Forbidden — use gold TestBase + real SE path |

---

## Handoff

When done, report briefly:

1. P1 status in tracker
2. Verify command(s) run + pass/fail
3. Notable deviations from plan (must still satisfy PRD §16)
4. Open suite file path(s)

Do **not** start P2 (F2) or P3 (F3). Oversight will gate the next phase.
