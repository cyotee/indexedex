# Mission: DETF Threshold Modes — implementation plans + progress tracker

Copy this entire file (or from “Role” downward) into a new agent session.

## Role

You are a planning agent for IndexedEx. Your job is to write **implementation and test plans only** (markdown). Do **not** implement production Solidity or change contracts in this session unless a plan file explicitly needs a tiny non-code clarification.

## Canonical product law (do not re-litigate)

Read and treat as normative:

- `contracts/vaults/detf/DETF_Threshold_Modes_PRD.md` (**PRODUCT LAW LOCKED** + **§16 Pre-plan encoding locks**)

Especially lock:

- Explicit `enum ThresholdMode { Policy, Open }` (Policy=0 default, Open=1)
- Source of truth: **PkgArgs → resolve → instance storage only** (never fee oracle)
- `0,0` thresholds → `1.05e18` / `0.95e18`; **`0` never means Open**
- Extreme Policy thresholds remain legal (tests); product Open requires `mode=Open`
- After resolve: Policy **and Open** reject if `mintThreshold <= burnThreshold`
- Gates always use **synthetic** price; strict `>` / `<` (equality = deadband)
- Live check in family; pure mode/price helpers in `detf/core` lib
- Open + live: both mint and burn allowed (fees + impact); Open must not advertise a peg
- First bond remains synthetically ungated in both modes
- MUST expose + test: `thresholdMode()`, `isMintingAllowed()`, `isBurningAllowed()`
- Emit `ThresholdModeSet(mode, mintThreshold, burnThreshold)` once at init
- Keep existing Policy/gated tests; **add** Open suites; dual-path extremes OK until Open helpers land
- Formal PRD LOCKED requires accepted plans for **F1 + F2 + F3**

Also read before planning:

- Repo `Agents.md` / `AGENTS.md` (DETF common expectations, CREATE3, registry deploy, production-first testing)
- Existing gold family artifacts under:
  - `contracts/vaults/detf/standardExchange/single/`
  - `contracts/vaults/detf/composed/multi-vault-weighted/`
  - `contracts/vaults/detf/composed/stable/mixedBuffer/`
- Current pure lib: `contracts/vaults/detf/core/DETFThresholdPolicy.sol`
- PRD **§16 Pre-plan encoding locks** (ABI field order, lib ownership, Open validation, event ABI, plan checklist)

## Pre-plan encoding locks (apply in every plan)

Mirror PRD §16. Do not invent alternatives.

1. **PkgArgs:** append `ThresholdMode thresholdMode` as a **trailing** field (same convention every family). Do not invent per-family field order.
2. **Core lib owns:** `ThresholdMode`, default constants, `resolveThresholds`, mode-aware `isMintingAllowed` / `isBurningAllowed` (no `live` param).
3. **Open resolve:** still resolve `0 → defaults` and store thresholds for getters; gates ignore them when Open.
4. **Validation:** both modes reject if `mintThreshold <= burnThreshold` after resolve; invalid mode (`> Open`) reverts at init.
5. **Event (canonical):**

```solidity
event ThresholdModeSet(
    ThresholdMode mode,
    uint256 mintThreshold,
    uint256 burnThreshold
);
```

Emit once from the path that writes storage at init/postDeploy. Payload uses **resolved** thresholds.

## Deliverables (create these files)

### A) Overall progress tracker (source of truth for execution agents)

Create:

`contracts/vaults/detf/DETF_Threshold_Modes_PROGRESS.md`

Requirements for the tracker:

- Status legend: `todo | in_progress | blocked | done | deferred`
- Program phases with checkboxes and owners/notes columns
- Link every plan file and map §5 test IDs (T1–T19) at program level
- Explicit “definition of done” per phase
- Execution agents must **update this file** as they finish work (not invent a second tracker)

Suggested phase structure:

| Phase | Content | Status |
|-------|---------|--------|
| P0 | Core lib plan + implement + pure unit tests | |
| P1 | F1 SingleStandardExchangeDETF plan + implement + green tests | |
| P2 | F2 MultiVaultWeightedDetf plan + implement + green tests | |
| P3 | F3 MixedBufferMultiVaultStableDetf plan + implement + green tests | |
| P4 | Formal PRD status → LOCKED (after F1–F3 plans accepted + implementation waves per PRD) | |
| P5 | F4 / F5 (+ synthetic migration for F5) | |
| P6 | F6 interface NatSpec / F7 audit parity-or-Out | |
| P7 | AGENTS.md one-liner + family PRD “conforms to …” notes | |

Include:

- Dependency graph (lib → F1 → F2/F3 parallelizable after lib API fixed)
- Risks / blockers section
- “How execution agents update progress” instructions (edit status + date + PR/commit note)

### B) Plans to write now (markdown only)

1. **Core lib**  
   `contracts/vaults/detf/core/DETFThresholdPolicy_Threshold_Modes_IMPLEMENTATION_AND_TEST_PLAN.md`

2. **F1 gold (normative patterns)**  
   `contracts/vaults/detf/standardExchange/single/SingleStandardExchangeDETF_Threshold_Modes_IMPLEMENTATION_AND_TEST_PLAN.md`

3. **F2**  
   `contracts/vaults/detf/composed/multi-vault-weighted/MultiVaultWeightedDetf_Threshold_Modes_IMPLEMENTATION_AND_TEST_PLAN.md`

4. **F3**  
   `contracts/vaults/detf/composed/stable/mixedBuffer/MixedBufferMultiVaultStableDetf_Threshold_Modes_IMPLEMENTATION_AND_TEST_PLAN.md`

Optional stubs only (short, Wave 3/4, no full designs unless easy):

- F4 / F5 / F7 one-pager notes linked from the progress tracker

## Required sections in EVERY family plan

1. **Normative refs** — PRD path + “conforms to product law + §16; no re-litigation”
2. **Goals / non-goals** for that family only
3. **Current state audit** — grep-backed list of gate call sites, info getters, PkgArgs, storage, tests using extreme thresholds
4. **API / storage diff**
   - `PkgArgs` trailing `thresholdMode`
   - Repo storage field
   - Event
   - Info selectors + facet function arrays
5. **Core lib integration** — exact helpers used; live check remains in family
6. **Touch list** — concrete files (Repo, DFPkg, Common, ExchangeIn/Out, Info, Facets, FactoryService if args change, TestBase, specs)
7. **Init / validation** — resolve, mint>burn, invalid mode, event emit site
8. **Synthetic confirmation** — function name used for gates (F5 later: migrate spot → synthetic)
9. **Test map** — PRD §5 IDs T1–T19 → proposed test contract/function names
   - Keep Policy/gated suites
   - Add Open suites
   - Named helpers e.g. `_deployOpenThresholds()`
10. **Production-first rules** — no mocks of SUT DETF/manager/registry/fee oracle/SE vaults; use gold TestBase
11. **Rollout order** inside the family (lib first if needed, then package, then tests)
12. **Definition of done** — checklist execution agents can tick
13. **Out of scope** — claim redeem, UI, fee-oracle thresholds, asymmetric modes

## Core lib plan must define (so families don’t diverge)

- Exact function signatures (names + params + returns)
- Enum location
- Default constants location
- Pure Foundry unit tests (no diamond)
- What families must NOT reimplement

## Constraints

- Crane / IndexedEx: no `new` for production facets/DFPkgs; vault pkgs via manager registry path in tests
- `PkgInit` / `PkgArgs` on **interfaces**, not contracts
- Role names only (rateAsset, pairToken, etc.) — no brand tokens in contracts
- Prefer editing existing plans only by linking; these threshold-mode plans are additive files
- Do not start production implementation in this session

## Process

1. Read PRD (including §16) + gold TestBases / DFPkgs for F1–F3 (actual field names, gate sites).
2. Write **progress tracker first** (skeleton with all phases `todo`).
3. Write **core lib plan**.
4. Write **F1 plan** (richest; becomes pattern reference).
5. Write **F2 and F3 plans** conforming to the same lib API and PkgArgs trailing-field rule.
6. Update the progress tracker: mark plan artifacts `done`, leave implementation phases `todo`.
7. End with a short handoff summary:
   - Files created
   - Suggested execution agent order
   - Any open technical risks found in the audit (not product re-opens)

## Success criteria for THIS session

- [ ] `DETF_Threshold_Modes_PROGRESS.md` exists and is the single execution tracker
- [ ] Core + F1 + F2 + F3 threshold-mode implementation/test plans exist and are executable without product questions
- [ ] Every plan maps T1–T19 (or marks N/A with reason)
- [ ] No production code changes required to “finish” planning
- [ ] Agents later can implement by following plan + updating PROGRESS only

Start now. Prefer concrete file paths and function names from the repo over abstract advice.

---

## Later: execution-agent follow-up (not this session)

```markdown
Read:
1) contracts/vaults/detf/DETF_Threshold_Modes_PRD.md
2) contracts/vaults/detf/DETF_Threshold_Modes_PROGRESS.md
3) The plan file for your assigned phase

Implement only that phase. Production-first tests. Do not re-open product decisions.
After each meaningful milestone, update DETF_Threshold_Modes_PROGRESS.md (status, date, notes).
Stop when the phase definition-of-done checklist is complete and tests you claim are green have been run.
```
