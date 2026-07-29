# Mission: DETF Threshold Modes — P5c F5 SingleVaultDetf implement only

**Goal:** Ship product-law **Policy / Open threshold modes** on **F5 SingleVaultDetf**, including the **mandatory synthetic migration** (gates + `is*Allowed` must stop using reserve spot). Then mark **P5c `done`** and **whole P5 `done`** in the tracker. **Stop** after that.

Copy this entire file into a new agent session.

You are an **execution agent**. Implement production code and tests for **one sub-phase only**. Do not re-open product decisions. Do not implement F6/F7 or AGENTS.md (P6/P7).

---

## Program context (as of handoff)

| Phase | Status |
|-------|--------|
| **P0–P4** | `done` — core + F1–F3 shipped; PRD formal **LOCKED 2026-07-28** |
| **P5a** F4 + F5 plans | `done` |
| **P5b** F4 ComposedStableCommon implement | `done` (2026-07-28; common/** **116/116** claimed) |
| **P5c** F5 SingleVaultDetf **implement** | **`todo` → you** |
| **P6–P7** | out of scope |

Tracker: `contracts/vaults/detf/DETF_Threshold_Modes_PROGRESS.md` (update as you go).

**Whole P5 becomes `done` only when P5c DoD is met.** You complete **P5c** and then mark **P5** complete.

---

## Read first (in order)

1. `contracts/vaults/detf/DETF_Threshold_Modes_PRD.md` — formal **LOCKED** + **§16**
2. `contracts/vaults/detf/DETF_Threshold_Modes_PROGRESS.md`
3. **Your plan (normative for this session):**  
   `contracts/vaults/detf/composed/single/SingleVaultDetf_Threshold_Modes_IMPLEMENTATION_AND_TEST_PLAN.md`
4. Upstream core (do not redesign): `contracts/vaults/detf/core/DETFThresholdPolicy.sol`
5. **Gold references (patterns only):**
   - F1: `contracts/vaults/detf/standardExchange/single/` — DFPkg / Repo / Common / Info / Facet / TestBase
   - F4 (just shipped): `contracts/vaults/detf/composed/stable/common/` — mode wiring if helpful
6. **F5 sources to edit (re-grep; plan §3 / §6 / §10):**
   - `SingleVaultDetfCommon.sol` — `_calcSyntheticPrice` for gates; mode-aware + live `_is*Allowed`; optional keep `_calcReserveSpotPrice` **non-gate only**
   - `SingleVaultDetfExchangeInTarget.sol` / `ExchangeOutTarget.sol` / `ExchangeInQueryTarget.sol` — **all** gate call sites off spot
   - `SingleVaultDetfInfoTarget.sol` / `InfoFacet.sol` — `thresholdMode()`, live-coupled is*, selectors
   - `SingleVaultDetfRepo.sol` — storage mode + thresholds from args
   - `SingleVaultDetfDFPkg.sol` — PkgArgs mint/burn/mode; remove hardcode `1005e15`/`995e15`; resolve/validate; `ThresholdModeSet`
   - `SingleVaultDetf_*_FactoryService.sol` / `buildPkgArgs` if present
   - Specs under `test/foundry/spec/vaults/detf/composed/single/**` (+ adversarial/fuzz)
   - Grep fork/matrix paths that construct SingleVaultDetf `PkgArgs`
7. Repo `Agents.md` / `AGENTS.md` — production-first; **role names only** (`rateAsset`, `pairToken`, …); **no** brand-era API names on new surfaces

---

## Scope (strict)

### In scope

1. **Synthetic migration first:** every mint/burn **gate** and **`is*Allowed`** path uses `_calcSyntheticPrice()` (not `_calcReserveSpotPrice()`).
2. Trailing `PkgArgs.thresholdMode` + configurable `mintThreshold` / `burnThreshold` (resolve `0,0` → product defaults).
3. Mode-aware lib 3-arg helpers; live in family; `ThresholdModeSet` once resolved.
4. Info + facet selectors; TestBase/deploy helpers; Open suites T1–T19; rewrite spot-based gate tests.
5. PROGRESS: P5c `done` + whole **P5 `done`** when green.

### Out of scope

- F4 rewrites; F1–F3 product changes (nested PkgArgs trailing field OK if compile-break)
- Claim redeem redesign, bridge/superchain product, full brand rename of package
- F6 IProtocolDETF NatSpec program, F7 Seigniorage, P7 AGENTS / family PRD one-liners
- Core lib redesign; inventing a new FX numeraire ledger
- UI / fee-oracle thresholds / asymmetric modes

---

## Locked product rules (do not re-litigate)

- Explicit `ThresholdMode { Policy, Open }`; **never** infer Open from `0` thresholds
- `0,0` → `1.05e18` / `0.95e18`; **`0` never means Open**
- After resolve: both modes reject `mintThreshold <= burnThreshold`
- Gates always **synthetic / FD** — **spot is illegal for gates** (this family’s main bug)
- Live check in **family**; core lib has **no `live` param**; Open short-circuit **only in lib**
- MUST: `thresholdMode()`, live-coupled `isMintingAllowed()`, `isBurningAllowed()`
- Event: `ThresholdModeSet(mode, mint, burn)` once at init, **resolved** values
- `PkgArgs`: append `thresholdMode` as **trailing** field (after mint/burn thresholds per plan)
- Keep/rewrite Policy suites under **synthetic**; add Open suites; dual-path always-allow → product **Open**
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
// 2-arg Policy wrappers still exist — migrate F5 call sites to 3-arg + mode
```

### F1–F4 gold patterns

| Concern | Pattern as shipped |
|---------|-------------------|
| PkgArgs | Trailing `ThresholdMode thresholdMode` |
| Init | `requireValidThresholdMode` → `resolveAndRequireValidThresholds` → store |
| Event | `ThresholdModeSet` once with **resolved** mint/burn |
| Common | `if (!live/initialized) return false;` then 3-arg lib + **synthetic** price |
| Info | `thresholdMode()` + live-correct `is*Allowed` |
| Always-allow | Product **Open** (`Open` + `0,0`), not illegal mint≤burn Policy pairs |

### Critical as-implemented note

`mint=1` + `burn=type(uint256).max` is **invalid** after pair validation (mint ≯ burn). Map legacy always-allow helpers to **product Open**.

---

## F5-critical requirements (do not skip)

### 1) Synthetic migration (mandatory, plan §3.1)

**Before:** gates + `is*Allowed` use `_calcReserveSpotPrice()`.  
**After:** all those sites use `_calcSyntheticPrice()` + mode-aware allow.

Call sites that **must** leave spot (re-verify with grep):

| File | Path |
|------|------|
| `SingleVaultDetfExchangeInTarget.sol` | mint + burn branches |
| `SingleVaultDetfExchangeOutTarget.sol` | burn |
| `SingleVaultDetfExchangeInQueryTarget.sol` | preview in/out gates (keep gate-on-preview parity) |
| `SingleVaultDetfInfoTarget.sol` | `isMintingAllowed` / `isBurningAllowed` |
| Common helpers | 3-arg mode + live; synthetic inside or via callers |

**DoD check:** `rg '_calcReserveSpotPrice' contracts/vaults/detf/composed/single/` must show **zero** hits on gate / is*Allowed paths (non-gate diagnostic use only is optional).

**Do not invent a new synthetic formula** — use existing `_calcSyntheticPrice()`. Error payloads for `MintingNotAllowed` / `BurningNotAllowed` should report **synthetic** price (even if local vars were named `reserveSpotPrice` — rename locals).

### 2) PkgArgs thresholds (today hardcoded)

- Expose `mintThreshold` / `burnThreshold` on `PkgArgs` (plan), remove hardcode `1005e15` / `995e15` (±0.5%).
- Product default after `0,0` is **±5%** (`1.05e18` / `0.95e18`), not the old ±0.5% band.
- Deploy tests that `assertEq(..., 1005e15)` **must** update.

### 3) Tests to rewrite (plan §3.1.4 / §9.1)

- `SingleVaultDetfExchangeIn_MintWithWeth.t.sol` (and peers): drive **synthetic** regime, not spot
- Deploy threshold assertions → product defaults or explicit custom Policy band
- IFacet Info tests: add `thresholdMode` selector
- Fuzz/adversarial: trailing mode + synthetic gates
- T9: move synthetic via real underlying/reserve trades when possible

### 4) Role names

- New helpers/APIs: `rateAsset`, `pairToken`, etc.
- Existing filenames like `*MintWithWeth.t.sol` may remain; **do not** add new brand-era APIs

---

## Process

1. Set **P5c** to `in_progress` in PROGRESS (date + note). Whole P5 stays `in_progress` until you finish.
2. Implement per plan §10 — **synthetic migration first**, then mode wiring.
3. Fix all PkgArgs / FactoryService / test literals for thresholds + trailing mode.
4. Open suite + helpers (`_deployOpenMode*` with `Open` + `0,0`).
5. Run and keep green:

```bash
forge test --match-path 'test/foundry/spec/vaults/detf/composed/single/**' -vv
forge build
```

Also fix any fork/matrix paths that construct SingleVaultDetf `PkgArgs` if they break.

6. Grep self-check: no gate path still on spot.
7. When plan §11 DoD is met:
   - Mark **P5c `done`** (date + pass counts)
   - Mark whole **P5 `done`**
   - Update F5 Wave 3 implement status + program T1–T19 F5 column if you touch that table
8. **Stop.** Do not start P6/P7.

---

## Exact verify commands

```bash
forge test --match-path 'test/foundry/spec/vaults/detf/composed/single/**' -vv
forge build

# Gate migration self-check (must not find spot on gate paths)
rg -n '_calcReserveSpotPrice' contracts/vaults/detf/composed/single/
rg -n 'thresholdMode|ThresholdModeSet' contracts/vaults/detf/composed/single/
```

---

## Success / definition of done

Plan §11, including:

- [ ] **Zero** mint/burn gate or `is*Allowed` uses of `_calcReserveSpotPrice()`
- [ ] Trailing `thresholdMode` + mint/burn on PkgArgs; hardcode ±0.5% removed
- [ ] Resolve/validate; `ThresholdModeSet` once resolved
- [ ] Mode-aware 3-arg lib; live in family; Open short-circuit only in lib
- [ ] Info `thresholdMode` + live-coupled is*; facet selectors
- [ ] Spot-based tests rewritten; Policy + Open suites green; T1–T19 mapped
- [ ] Production-first; role names only
- [ ] Verify command green (report pass count)
- [ ] PROGRESS: P5c `done` + **P5 `done`**

---

## Handoff

- **Do not start P6** (F6 NatSpec / F7 Seigniorage audit) unless the human explicitly asks in a new prompt.
- After oversight accepts P5c, next program work is **P6** (or P7 docs if human reorders).
- Tracker changelog example:

> P5c F5 done: synthetic migration + trailing thresholdMode + Open suite; N/N composed/single/** green. Whole P5 done. Next: P6 F6/F7.
