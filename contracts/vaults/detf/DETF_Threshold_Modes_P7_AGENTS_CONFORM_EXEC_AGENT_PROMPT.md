# Mission: DETF Threshold Modes — P7 AGENTS + family PRD conform notes

**Goal:** Close the threshold-modes program with **documentation only**:

1. Update repo **AGENTS.md** / **Agents.md** DETF common expectations so Policy/Open + synthetic gates match formal product law.
2. Add short **“Conforms to `DETF_Threshold_Modes_PRD`”** notes on in-scope family PRDs (and F7 Out pointer where relevant).
3. Mark **P7 `done`** in the progress tracker — program complete for this initiative.

Copy this entire file into a new agent session.

You are a **docs execution agent**. **No production Solidity** unless a NatSpec typo is already broken (prefer zero code). Do not re-open product law. Do not re-implement families.

---

## Program context (as of handoff)

| Phase | Status |
|-------|--------|
| **P0–P5** | `done` — core + F1–F5 Policy/Open (F5 synthetic migration) |
| **P6** | `done` — F6 `IProtocolDETF` NatSpec/`thresholdMode`; **F7 formal Out** (`contracts/vaults/seigniorage/THRESHOLD_MODES_OUT.md`) |
| **P7** | **`todo` → you** — final docs |

Tracker: `contracts/vaults/detf/DETF_Threshold_Modes_PROGRESS.md`  
Product law: `contracts/vaults/detf/DETF_Threshold_Modes_PRD.md` (**LOCKED**)

---

## Read first (in order)

1. `contracts/vaults/detf/DETF_Threshold_Modes_PRD.md` — especially §4 modes, §16, inventory F1–F7, AGENTS update intent
2. `contracts/vaults/detf/DETF_Threshold_Modes_PROGRESS.md` — shipped families + F7 Out
3. Current agent guide: `Agents.md` / `AGENTS.md` (same content on case-insensitive FS — edit the canonical file the repo uses; if both exist as copies, keep them **identical**)
4. `Claude.md` / `CLAUDE.md` only if it embeds DETF threshold bullets that would go stale (usually points at AGENTS — update only if it duplicates threshold law)
5. Family PRDs (add conform one-liner near status / thresholds section):
   - `standardExchange/single/SingleStandardExchangeDETF_PRD.md` (F1)
   - `composed/multi-vault-weighted/MultiVaultWeightedDetf_PRD.md` (F2)
   - `composed/stable/mixedBuffer/MixedBufferMultiVaultStableDetf_PRD.md` (F3)
   - `composed/stable/common/ComposedStableCommonDetf_PRD.md` (F4)
   - F5: no dedicated `*_PRD.md` found at handoff — if still missing, add a **short note** either to `composed/single/UNISWAP_V4_SINGLE_DETF_IMPLEMENTATION_PLAN.md` (status header) **or** create a minimal `SingleVaultDetf_PRD.md` one-paragraph conform + “historical spot gates superseded” **only if** that is lighter than inventing a full PRD (prefer one-liner on existing plan header over a new mega-PRD)
6. F7 Out note already exists: `contracts/vaults/seigniorage/THRESHOLD_MODES_OUT.md` — do not re-open Out; optional cross-link from AGENTS “out of threshold-mode program”

---

## Scope (strict)

### In scope

#### A) AGENTS.md — DETF common expectations

Update **Pricing and mint/burn gates** (and related bullets) so agents learn:

| Topic | Required wording (substance) |
|-------|------------------------------|
| Modes | Deploy-time **`ThresholdMode`**: **Policy** (default) vs **Open** — explicit field; **never** infer Open from `0` thresholds |
| Defaults | `0,0` → **`1.05e18` / `0.95e18`** via core `DETFThresholdPolicy`; stored for getters under both modes |
| Policy gates | Live + synthetic: mint iff `synthetic > mintThreshold`; burn iff `synthetic < burnThreshold`; equality = deadband |
| Open gates | When live, threshold gates always pass; first bond / bootstrap still synthetically ungated as today; Open does **not** change route set (e.g. F3 buffer-only burn) |
| Source of truth | Mode + thresholds from **`PkgArgs` → resolve → instance storage only** — **not** fee oracle |
| Fee oracle | Remains for **fees / bond terms / seigniorage incentive** where peers use it — **split** the current AGENTS line that wrongly bundles “thresholds” under fee oracle |
| Info surface | `thresholdMode()`, live-coupled `isMintingAllowed()` / `isBurningAllowed()` |
| Core lib | Link `contracts/vaults/detf/core/DETFThresholdPolicy.sol` + PRD path |
| Validation | After resolve, mint > burn both modes; invalid mode reverts |
| F7 | Seigniorage package is **Out** of threshold-mode program (peg regime) — point at `THRESHOLD_MODES_OUT.md` |
| Shipped | F1–F5 implement Policy/Open; F6 interface documents it |

Keep existing DETF sections (opacity, role names, inert→live, routes, bond/claim, testing) **intact** except where they contradict the above.

**Suggested minimal AGENTS edit locations:**

1. Governance bullet that currently says fees/bond/**thresholds** all via fee oracle → fees/bond terms via oracle; **mint/burn thresholds + mode via PkgArgs**.
2. **Pricing and mint/burn gates** subsection → Policy/Open paragraph + synthetic always.
3. Optional short “Normative PRD” bullet under DETF section linking `DETF_Threshold_Modes_PRD.md`.

#### B) Family PRD conform notes

For each in-scope family PRD (F1–F4 at minimum), add near the top or threshold section:

```markdown
**Threshold modes:** Conforms to [`DETF_Threshold_Modes_PRD.md`](../../DETF_Threshold_Modes_PRD.md) (formal LOCKED) — deploy-time Policy (default ±5% synthetic deadband) vs Open; gates always synthetic; trailing `PkgArgs.thresholdMode`.
```

Adjust relative links per file depth. Do **not** rewrite entire family PRDs.

**F3 add-on:** Open does not unlock non-buffer burn.  
**F5 note:** synthetic gates required (spot gates superseded).  
**F7:** already Out — no “conforms” claim; may add “See THRESHOLD_MODES_OUT.md — not under Policy/Open program.”

#### C) Tracker + program close

- Mark **P7 `done`** with date.
- Last updated / suggested execution order: program complete.
- Changelog: P7 done; threshold-modes program closed for P0–P7.
- Optional: PRD footer “implementation status” already mentions P7 — one-line “P7 complete” if easy.

### Out of scope

- Solidity / tests / forge
- Re-opening F7 to Parity
- Frontend copy, marketing, indexedex-product-voice pages (unless AGENTS only)
- Large family PRD rewrites or new feature plans
- Crane skill rewrites

---

## Locked product reminders (docs must match)

- Explicit `ThresholdMode { Policy, Open }`
- `0` never means Open; `0,0` → defaults
- Gates always synthetic; live in family
- Fee oracle does **not** set mode/thresholds
- F7 Out; DualLiquidity / SE vaults remain out of this PRD

---

## Process

1. Set P7 `in_progress` in PROGRESS.
2. Edit AGENTS.md (and Agents.md if separate copy) carefully — minimal diff, high accuracy.
3. Add conform one-liners to F1–F4 PRDs (+ F5 note as above).
4. Cross-check Claude.md does not contradict (usually no edit).
5. Mark P7 `done`; program complete note in tracker changelog.
6. **Stop.** No further program phases unless human opens a new initiative.

---

## Exact verify

Docs only:

```bash
# Ensure you did not touch Solidity by accident
git diff --stat -- ':(exclude)*.md' ':(exclude)*.MD' | head -20
# Should be empty / no .sol if you stayed in scope
```

Optional read-back: skim AGENTS “Pricing and mint/burn gates” for Policy/Open + PkgArgs source of truth.

No forge required.

---

## Success / definition of done

- [ ] AGENTS DETF section teaches Policy/Open + synthetic + PkgArgs source of truth; fee oracle no longer owns mint/burn thresholds
- [ ] F1–F4 family PRDs have “conforms to DETF_Threshold_Modes_PRD” one-liner (F5 covered by plan note if no PRD)
- [ ] F7 not falsely claimed as conforming; Out link ok
- [ ] PROGRESS P7 `done`; changelog; last updated reflects program complete
- [ ] No product re-litigation; no Solidity

---

## Handoff

This is the **final** phase of the DETF Threshold Modes program as defined in the tracker.

After P7: no automatic next implementor prompt unless the human starts a new program (e.g. frontend mode UX, F7 revival, or fee-oracle language cleanup elsewhere).

Tracker changelog example:

> P7 done: AGENTS Policy/Open + synthetic gates; family PRD conform notes F1–F4 (+ F5 note); F7 remains Out. **Threshold Modes program P0–P7 complete.**
