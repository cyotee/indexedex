# Mission: DETF Threshold Modes — P3 F3 MixedBufferMultiVaultStableDetf only

**Goal:** Ship product-law **Policy / Open threshold modes** on F3 MixedBuffer MultiVault Stable DETF (trailing `PkgArgs.thresholdMode`, mode-aware synthetic gates, live-coupled info, Open suites T1–T19) without changing buffer-only burn or bootstrap rules. Then mark **P3 `done`** and stop.

Copy this entire file into a new agent session.

You are an **execution agent**. Implement production code and tests for **one phase only**. Do not re-open product decisions. Do not implement F4+ or formal PRD LOCKED.

---

## Program context

| Phase | Status (as of handoff) |
|-------|------------------------|
| **P0** Core `DETFThresholdPolicy` | `done` |
| **P1** F1 SingleStandardExchangeDETF | `done` — gold patterns |
| **P2** F2 MultiVaultWeightedDetf | `done` — oversight accepted; copy patterns |
| **P3** F3 MixedBufferMultiVaultStableDetf | **`todo` → you implement** |
| **P4+** | out of scope |

Tracker: `contracts/vaults/detf/DETF_Threshold_Modes_PROGRESS.md` (update as you go).

---

## Read first (in order)

1. `contracts/vaults/detf/DETF_Threshold_Modes_PRD.md` (product law + **§16**)
2. `contracts/vaults/detf/DETF_Threshold_Modes_PROGRESS.md`
3. `contracts/vaults/detf/composed/stable/mixedBuffer/MixedBufferMultiVaultStableDetf_Threshold_Modes_IMPLEMENTATION_AND_TEST_PLAN.md` (**your plan**)
4. Upstream core (do not redesign): `contracts/vaults/detf/core/DETFThresholdPolicy.sol`
5. **Gold references (patterns only — do not edit unless a compile-break forces a one-line fix):**
   - F1: `contracts/vaults/detf/standardExchange/single/` — DFPkg / Repo / Common / Info / Facet / TestBase
   - F2: `contracts/vaults/detf/composed/multi-vault-weighted/` — same surface on multi-leg
6. F3 sources to edit:
   - `MixedBufferMultiVaultStableDetfDFPkg.sol`
   - `MixedBufferMultiVaultStableDetfRepo.sol`
   - `MixedBufferMultiVaultStableDetfCommon.sol`
   - `MixedBufferMultiVaultStableDetfInfoTarget.sol`
   - `MixedBufferMultiVaultStableDetfExchangeInFacet.sol`
   - `MixedBufferMultiVaultStableDetfExchangeInTarget.sol` / `ExchangeOutTarget.sol` (confirm gates)
   - `MixedBufferMultiVaultStableDetfBondingTarget.sol` (bootstrap stays synthetically ungated)
   - `TestBase_MixedBufferMultiVaultStableDetf.sol`
   - Specs under `test/foundry/spec/vaults/detf/composed/stable/mixedBuffer/**`
7. Repo `Agents.md` / `AGENTS.md` — manager vault-registry deploy; production-first; role names (`rateAsset`, bufferToken, vaultShare, …); no SUT mocks

---

## Scope (strict)

### In scope

- F3 **MixedBufferMultiVaultStableDetf** only: PkgArgs/storage/init/event, mode-aware Common + live-coupled Info, facet selectors, TestBase helpers, Policy regression (esp. PriceShift), Open suites (T1–T19), **fix invalid mint≤burn fixtures**

### Out of scope

- F4 ComposedStableCommon, F5 SingleVaultDetf, claim redeem product rules, UI
- Core lib API changes; F1/F2 rewrites
- Expanding burn outputs beyond **bufferToken** under Open
- Changing MixedBuffer pool math / amplification / bootstrap peg seed
- Fee-oracle thresholds, asymmetric modes
- Formal PRD LOCKED / AGENTS.md (P4/P7)

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

### F1/F2 gold patterns — mirror on F3

| Concern | Pattern as shipped |
|---------|-------------------|
| PkgArgs | Trailing `ThresholdMode thresholdMode` |
| Init | `requireValidThresholdMode` → `resolveAndRequireValidThresholds` → store resolved mint/burn + mode |
| Event | `ThresholdModeSet(mode, mint, burn)` once after storage write (Info interface) |
| Common | `if (!isReserveLive) return false;` then 3-arg lib allow with `_syntheticPrice()` |
| Info | `thresholdMode()` + live-correct `isMintingAllowed` / `isBurningAllowed` |
| Facet | Include `thresholdMode` selector in ExchangeIn facet arrays |
| Always-allow helper | **Product Open:** `_deployOpenModeDetfN` with `thresholdMode: Open`, thresholds `0,0` |

### Critical as-implemented note (F1/F2)

`mint=1` + `burn=type(uint256).max` is **illegal** after `resolveAndRequireValidThresholds` (mint ≤ burn).  
F1/F2 therefore map legacy `_deployOpenThresholdDetf*` names to **product Open** (`Open` + `0,0`), not extreme Policy.

**Do the same on F3** unless you introduce a separate, *valid* Policy fixture for closed-band tests. Never reintroduce `mint ≤ burn` pairs.

---

## Locked product rules (do not re-litigate)

- Explicit `ThresholdMode`; never infer Open from zeros or “extreme” numbers
- `0,0` → defaults; **`0` never means Open**
- Both modes: after resolve reject `mintThreshold <= burnThreshold`
- Gates always **synthetic** (`_syntheticPrice()`); live in family
- MUST: `thresholdMode()`, live-coupled `isMintingAllowed()`, `isBurningAllowed()`
- `ThresholdModeSet` once at init, resolved values
- Trailing `PkgArgs.thresholdMode`
- **F3 lock:** Open opens **threshold gates only** — burn remains **buffer-only** (no new burn assets)
- **F3 lock:** `bootstrapFirstBond` / first-bond path stays **synthetically ungated** in both modes
- Production-first; role names only

---

## Implementation checklist (F3 plan §§4–12)

1. **Repo** — `ThresholdMode thresholdMode` on Storage + InitParams; `_initialize` stores it.
2. **PkgArgs** — trailing field after `mintThreshold` / `burnThreshold` on `IMixedBufferMultiVaultStableDetfDFPkg.PkgArgs` (+ DeployConfig if any).
3. **Init** — validate mode → resolve/require pair → persist → emit `ThresholdModeSet` once.
4. **Common** — live short-circuit + 3-arg allow helpers; drop local default constants when safe.
5. **Info + Facet** — `thresholdMode()`; selector arrays in `MixedBufferMultiVaultStableDetfExchangeInFacet` (both listings).
6. **Execution** — mint (buffer→DETF and vaultShare→DETF) and burn (DETF→buffer): live require then mode-aware allow. Confirm Open does **not** add vaultShare burn.
7. **Bootstrap** — leave first bond synthetically ungated.
8. **TestBase**
   - All `PkgArgs` set `thresholdMode` (default Policy)
   - `_deployDetfN` overload with optional mode (Policy default)
   - `_deployOpenModeDetfN(n)` with `thresholdMode: Open`, thresholds `0,0`
   - Map `_deployOpenThresholdDetfN` → Open helper (F1/F2 pattern) or document dual-path carefully
9. **Fixture repair (required before / with validation)**
   - Grep `mintThreshold` / `_deployDetfN(` under mixedBuffer tests
   - Fix Pricing/Guards pairs that become invalid after resolve, especially **`_deployDetfN(1, 1, 1)`** → e.g. mint=`2` or `1.05e18`, burn=`1` (plan §3.4 / §9.3)
10. **Tests** — Policy regression (Deploy, Pricing, **PriceShift T9**, Liveness, Mint/Burn, Guards, Reentrancy); new Open suite recommended:  
    `test/foundry/spec/vaults/detf/composed/stable/mixedBuffer/MixedBufferMultiVaultStableDetf_ThresholdMode.t.sol`  
    Include: Open does **not** allow non-buffer burn (route error, not threshold); T10 inside former deadband; T17 round-trip mint→buffer burn.
11. **PROGRESS.md** — P3 → `done` when DoD met.

Rollout: Repo → DFPkg → Common → Info/Facet → TestBase → **fix invalid pairs** → Policy regression → Open suite (§11).

---

## Process

1. Set **P3** to `in_progress` in `DETF_Threshold_Modes_PROGRESS.md` (date + note). Leave P0–P2 `done`.
2. Implement per F3 plan; product questions → PRD §16 / F3 plan only.
3. Compile iteratively as every F3 `PkgArgs` gains trailing `thresholdMode`.
4. Verify:

```bash
# Upstream smoke (optional)
forge test --match-path 'test/foundry/spec/vaults/detf/core/DETFThresholdPolicy.t.sol' -vv

# F3 primary gate
forge test --match-path 'test/foundry/spec/vaults/detf/composed/stable/mixedBuffer/**' -vv

forge build
```

5. When F3 **definition of done** (plan §12 + tracker P3 checklist) is complete, mark **P3 `done`** (date + brief notes: Open suite path, fixture repairs, test counts). Leave P4+ `todo`.
6. **Stop.** Do not start P4 formal LOCKED, F4, or F5.

---

## Success / definition of done

- [ ] Trailing `thresholdMode`; storage; resolve/validate both modes; event once
- [ ] Mode-aware gates + `_syntheticPrice()`; live in family/info
- [ ] Open does not change burn asset set (buffer-only preserved)
- [ ] Bootstrap/first bond still synthetically ungated
- [ ] Facet selectors include `thresholdMode`
- [ ] Invalid mint≤burn fixtures fixed; T4 green
- [ ] Policy suites green including PriceShift (T9)
- [ ] Open suites T3, T10–T13b, T17–T19 (+ remaining T1–T19 map)
- [ ] `forge test --match-path 'test/foundry/spec/vaults/detf/composed/stable/mixedBuffer/**'` green
- [ ] `DETF_Threshold_Modes_PROGRESS.md` P3 → `done`

Tests you claim green must actually have been run.

---

## Risks to watch

| Risk | Action |
|------|--------|
| Pricing/Guards `mint≤burn` fixtures | Fix before claiming green (plan §9.3) |
| Open wrongly unlocks vaultShare burn | Assert still route-rejects |
| Conflating always-allow with extreme Policy | Use product Open helper (F1/F2) |
| Double-emit `ThresholdModeSet` | Once after storage write |
| PriceShift (T9) regression under defaults | Keep real pool skew path green |
| Mocking SUT | Forbidden |

---

## Handoff

When done, report:

1. P3 status in tracker  
2. Verify commands + pass/fail counts  
3. Open suite path + fixture repairs  
4. Any deviation from plan (must still satisfy PRD §16 + buffer-only burn)  

Do **not** start P4 (formal LOCKED) or Wave 3 families. Oversight will gate the next phase.
