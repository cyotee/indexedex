# Mission: DETF Threshold Modes — P5 Wave 3 plans only (F4 + F5)

**Goal:** Write full **implementation and test plans** for Wave 3 families:

1. **F4** — `ComposedStableCommonDetf`
2. **F5** — `SingleVaultDetf` (**mandatory synthetic migration** for mint/burn gates)

Then update the progress tracker. **Do not implement production Solidity** in this session.

Copy this entire file into a new agent session.

You are a **planning / execution agent for markdown plans only**. Product law is **formal LOCKED** — do not re-open it. Mirror F1 gold plan structure; match **as-shipped** P0/F1 API.

---

## Program context (as of handoff)

| Phase | Status |
|-------|--------|
| **P0–P3** | `done` — core + F1/F2/F3 shipped green; P3 oversight PASS |
| **P4** | `done` — PRD formal **LOCKED 2026-07-28** |
| **P5** | **`todo` → you (plans only this session)** |
| **P5 implement** | **out of scope** — separate exec prompts after plans accepted |
| **P6–P7** | out of scope |

Tracker: `contracts/vaults/detf/DETF_Threshold_Modes_PROGRESS.md` (update as you go).

---

## Read first (in order)

1. `contracts/vaults/detf/DETF_Threshold_Modes_PRD.md` — **LOCKED** + **§16** encoding locks; Wave 3 / F4 / F5 inventory notes
2. `contracts/vaults/detf/DETF_Threshold_Modes_PROGRESS.md` — Wave 3 stubs for F4/F5; program T1–T19 map
3. **Gold plan templates (copy structure, not prose wholesale):**
   - `standardExchange/single/SingleStandardExchangeDETF_Threshold_Modes_IMPLEMENTATION_AND_TEST_PLAN.md` (**primary template**)
   - Optionally skim F2/F3 plans for multi-leg / family-specific sections
4. **Shipped API (do not redesign):**
   - `contracts/vaults/detf/core/DETFThresholdPolicy.sol`
5. **F4 sources to audit (grep-backed current state):**
   - `contracts/vaults/detf/composed/stable/common/` — especially  
     `ComposedStableCommonDetfCommon.sol`, `*ExchangeIn.sol`, `*ExchangeOutQueryFacet.sol`,  
     `*Repo.sol`, `*DFPkg.sol`, `TestBase_ComposedStableCommonDetf.sol`, family PRD if present
6. **F5 sources to audit:**
   - `contracts/vaults/detf/composed/single/` — especially  
     `SingleVaultDetfCommon.sol`, `*ExchangeInTarget.sol`, `*ExchangeOutTarget.sol`,  
     `*InfoTarget.sol`, `*Repo.sol`, `*DFPkg.sol`, TestBase if any, any existing PRD/plans
7. Repo `Agents.md` / `AGENTS.md` — production-first; role names only (`rateAsset`, `pairToken`, …); **no brand-era names** on F5 (`RICH`, `wethRich`, etc.)

---

## Scope (strict)

### In scope

Create **two** plan files (full plans, not stubs):

| Family | Path to create |
|--------|----------------|
| **F4** | `contracts/vaults/detf/composed/stable/common/ComposedStableCommonDetf_Threshold_Modes_IMPLEMENTATION_AND_TEST_PLAN.md` |
| **F5** | `contracts/vaults/detf/composed/single/SingleVaultDetf_Threshold_Modes_IMPLEMENTATION_AND_TEST_PLAN.md` |

Update `DETF_Threshold_Modes_PROGRESS.md`:

- Plan artifacts table: F4/F5 stubs → plan paths + `done` (plan only)
- Wave 3 stub sections: link full plans; status `plan done` / ready for implement
- P5 notes: plans drafted; **implement still `todo`** (do not mark whole P5 `done` until implement waves — or split P5 in tracker into “P5a plans / P5b F4 impl / P5c F5 impl” if clearer)
- Tracker changelog row for this session

### Out of scope

- Production Solidity, TestBase code, forge tests
- F1–F3 rewrites
- F6 NatSpec / F7 Seigniorage audit / P7 AGENTS.md
- Formal PRD re-lock or product law changes
- UI, fee-oracle thresholds, asymmetric modes

---

## Locked product rules (every plan must obey)

- Explicit `ThresholdMode { Policy, Open }`; **never** infer Open from `0` thresholds or extreme Policy
- `0,0` → `1.05e18` / `0.95e18`; **`0` never means Open**
- After resolve: **both modes** reject `mintThreshold <= burnThreshold`
- Gates always **synthetic / FD**; strict `>` mint / `<` burn (equality = deadband)
- Live check in **family**; core lib has **no `live` param**; Open short-circuit in lib only
- MUST: `thresholdMode()`, live-coupled `isMintingAllowed()`, `isBurningAllowed()`
- Event: `ThresholdModeSet(mode, mint, burn)` once at init with **resolved** values
- `PkgArgs`: append `thresholdMode` as **trailing** field
- Keep Policy/gated tests; add Open suites; dual-path extremes OK but document vs product Open
- Production-first: no mocks of SUT DETF/manager/registry/fee oracle/SE vaults
- Role names only

---

## Upstream API (as shipped — do not redesign)

```text
// contracts/vaults/detf/core/DETFThresholdPolicy.sol
enum ThresholdMode { Policy, Open }   // 0, 1

DEFAULT_MINT_THRESHOLD = 1.05e18
DEFAULT_BURN_THRESHOLD = 0.95e18

resolveAndRequireValidThresholds(mintArg, burnArg)
requireValidThresholdMode(uint8|ThresholdMode)

_isMintingAllowed(ThresholdMode, mintThreshold, price)  // Open → true; Policy strict >
_isBurningAllowed(ThresholdMode, burnThreshold, price)  // Open → true; Policy strict <
// 2-arg Policy wrappers retained for unported call sites during migration

// Family pattern (F1–F3 as shipped)
PkgArgs trailing thresholdMode
init: requireValidThresholdMode + resolveAndRequireValidThresholds
store mode + resolved mint/burn; emit ThresholdModeSet once
Common: if (!live) return false; else lib mode-aware allow(synthetic)
Info + facet selectors include thresholdMode()
TestBase: _deployOpenMode* with mode=Open + 0,0; dual-path always-allow → product Open
// illegal after validation: mint=1 / burn=max as "open" Policy pair
```

---

## Family-specific planning requirements

### F4 — ComposedStableCommonDetf

**Path:** `contracts/vaults/detf/composed/stable/common/`

**Known current state (re-audit with grep; fix if stale):**

- Already uses **synthetic** `_syntheticDetfEthPrice()` for gates (good — no spot migration)
- Common still calls **2-arg** Policy-only lib helpers (no mode)
- No trailing `thresholdMode` / event / live-coupled info (verify)
- Gates in ExchangeIn **and** ExchangeOut query facet — plan must audit **all** mint/burn gate call sites

**Plan must cover:**

1. Trailing `PkgArgs.thresholdMode` + storage + resolve/validate + `ThresholdModeSet`
2. Mode-aware Common using lib 3-arg helpers + **live** in family/info
3. Facet selector arrays for `thresholdMode` (and any split In/Out/Query packages)
4. Nested attachment notes: when this DETF is an SE leg under F1 matrix, outer/inner modes independent
5. Test map T1–T19 → concrete files/helpers under existing composed-stable suites / TestBase
6. Touch list + init order + definition of done + suggested forge match-path
7. Non-goals: claim redeem product rules; MixedBuffer F3; brand renames unrelated to thresholds

**Suggested verify (for later implementor — put in plan DoD):**

```bash
forge test --match-path 'test/foundry/spec/vaults/detf/composed/stable/common/**' -vv
# also any F1 matrix paths that deploy ComposedStable as a leg, if they construct PkgArgs
```

### F5 — SingleVaultDetf (**synthetic migration is mandatory**)

**Path:** `contracts/vaults/detf/composed/single/`

**Known current state (re-audit with grep; fix if stale):**

- Mint/burn gates and Info use **`_calcReserveSpotPrice()`** — **violates product law** (gates must be synthetic)
- Thresholds exist; no `thresholdMode`; 2-arg policy path likely
- Brand-era names must **not** re-enter in new plan text or proposed APIs

**Plan must cover:**

1. **Migration section first:** replace spot price in **all** mint/burn **gate** and **is*Allowed** paths with the family’s correct **synthetic / FD** price helper (name the existing or to-be-shared function; if missing, specify how to compute analog to F1 `_syntheticPrice()` without inventing a second FX ledger)
2. Same Policy/Open product surface as F1 after migration
3. Explicit list of call sites that currently use spot for gates vs any call sites that may keep spot for **non-gate** display (if any — default: gates + is*Allowed must be synthetic; document)
4. Trailing `thresholdMode`, resolve/validate, event, facets, TestBase helpers
5. T1–T19 map; note which existing tests assert spot-based gate behavior and must be rewritten
6. Production-first; role names (`rateAsset`, `pairToken`, `underlyingVault`, …)
7. Definition of done: synthetic migration + mode wiring + Open suites + Policy regression green

**Suggested verify (for later implementor):**

```bash
forge test --match-path 'test/foundry/spec/vaults/detf/composed/single/**' -vv
# plus any fork/matrix paths that construct SingleVaultDetf PkgArgs
```

---

## Required structure of each plan file

Mirror F1 plan sections (adapt titles as needed):

1. Normative refs (PRD LOCKED + §16, PROGRESS, core lib, gold F1 plan, family PRD/paths)
2. Goals / non-goals (family only)
3. **Current state audit** (grep-backed tables: gate sites, PkgArgs, storage, facets, extreme-threshold tests)
4. API / storage diff (`PkgArgs` trailing mode, Repo, event, Info)
5. Core lib integration (snippets matching **shipped** signatures)
6. Touch list (files)
7. Init / validation sequence
8. TestBase helpers (`_deployOpenMode*`, Policy extremes, dual-path notes)
9. **Test map T1–T19** → concrete test names / files
10. Implementation order
11. Definition of done (checkboxes)
12. Out of scope
13. Family PRD conform note pointer (actual PRD edit is **P7** — one-liner only)

**F5 extra section:** “Synthetic migration” (before or as §3.5) with before/after price function table.

---

## Process

1. Set P5 to `in_progress` in PROGRESS (note: **plans only**).
2. Grep-audit F4 and F5 current gate/PkgArgs/info/test sites; write accurate “today” tables (do not copy F1 audit blindly).
3. Write F4 plan file complete.
4. Write F5 plan file complete (synthetic migration first-class).
5. Update PROGRESS plan artifacts + Wave 3 stubs + changelog. Leave implement phases `todo`.
6. **Stop.** Do not implement packages. Do not start P6/P7.

---

## Exact verify for *this* session

No forge required for plan-only DoD. Self-check:

- [ ] Both plan files exist at the paths above
- [ ] Each plan has T1–T19 map + DoD + touch list + §16 trailing mode
- [ ] F5 plan has mandatory synthetic migration section and lists spot→synthetic call sites
- [ ] F4 plan audits ExchangeIn **and** query/out gate sites
- [ ] Plans reference shipped lib API (not invented names)
- [ ] PROGRESS updated; whole-program P5 not falsely marked implement-complete
- [ ] No Solidity diffs in this session (unless a typo-only comment you accidentally touch — prefer zero)

Optional: `git status` / `git diff --stat` should show **markdown only**.

---

## Success / definition of done (this session)

| Item | Done when |
|------|-----------|
| F4 plan | Full `ComposedStableCommonDetf_Threshold_Modes_IMPLEMENTATION_AND_TEST_PLAN.md` ready for an implementor |
| F5 plan | Full `SingleVaultDetf_Threshold_Modes_IMPLEMENTATION_AND_TEST_PLAN.md` ready for an implementor, synthetic migration specified |
| Tracker | Artifacts + Wave 3 stubs + changelog updated; next note = implement F4 then F5 (or parallel if human overrides) |

Handoff line for tracker changelog (example):

> P5 plans done (F4 + F5). Next: implement F4 ComposedStableCommon, then F5 SingleVaultDetf (synthetic migration).

---

## Handoff

- **Do not implement F4/F5 code** in this session.
- After oversight accepts plans, human will request separate **P5 F4 implement** / **P5 F5 implement** prompts.
- Prefer sequential implement: **F4 first** (already synthetic; closer to F1), then **F5** (migration risk).

---

## Risks to flag in the plans (not to re-litigate)

| Risk | Plan response |
|------|----------------|
| F5 spot gates vs product law | Mandatory migration; tests rewritten |
| F4 multi-facet gate sites | Exhaustive call-site table |
| Nested F1 matrix PkgArgs | Note trailing mode field updates when F4 ships |
| mint=1/burn=max dual-path | Map to product Open after validation (as F1–F3) |
| Brand-era names on F5 | Forbidden in plan language and proposed APIs |
| Scope creep into F6/F7 | Explicit non-goals |
