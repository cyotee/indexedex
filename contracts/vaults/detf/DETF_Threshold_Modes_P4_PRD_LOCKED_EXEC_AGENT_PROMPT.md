# Mission: DETF Threshold Modes — P4 Formal PRD LOCKED only

**Goal:** Promote `DETF_Threshold_Modes_PRD.md` from product-law lock to formal status **LOCKED** now that Wave 2 implement gates (P0 core + F1 + F2 + F3) are green and oversight-accepted. Update the progress tracker. Then **stop**.

Copy this entire file into a new agent session.

You are an **execution agent** for **docs / status only**. Do **not** implement production Solidity, new family wiring, F4/F5 plans (unless a one-line PRD inventory cross-link is already required by § below), or AGENTS.md product-voice rewrites (that is **P7**).

---

## Program context (as of 2026-07-28)

| Phase | Status | Evidence |
|-------|--------|----------|
| **P0** Core `DETFThresholdPolicy` | `done` | Enum/defaults/resolve/mode-aware allow; pure unit suite green |
| **P1** F1 SingleStandardExchangeDETF | `done` | Trailing mode, live-coupled gates, Open suite; 81/81 single/** |
| **P2** F2 MultiVaultWeightedDetf | `done` | Same surface; 97/97 multi-vault-weighted/**; oversight accepted |
| **P3** F3 MixedBufferMultiVaultStableDetf | `done` | Same surface; **oversight re-verify 72/72** mixedBuffer/** on 2026-07-28 |
| **P4** Formal PRD → **LOCKED** | **`todo` → you** | Docs only |
| **P5–P7** | out of scope | F4/F5 plans + implement; F6/F7; AGENTS conform notes |

Tracker: `contracts/vaults/detf/DETF_Threshold_Modes_PROGRESS.md` (update as you go).

**Oversight gate:** P3 was **PASS** (code surface + forge 72/72). You may proceed without re-litigating F3.

---

## Read first (in order)

1. `contracts/vaults/detf/DETF_Threshold_Modes_PRD.md` — especially **Status** header, §6 waves, §7 family inventory, §12 acceptance / formal LOCKED language, **changelog** at bottom, **§16** (encoding locks — leave normative text alone unless a factual “shipped” inventory row needs updating)
2. `contracts/vaults/detf/DETF_Threshold_Modes_PROGRESS.md` — P4 definition of done
3. Optional skim (do not edit unless inventory tables require a “shipped” flag):
   - `core/DETFThresholdPolicy_Threshold_Modes_IMPLEMENTATION_AND_TEST_PLAN.md`
   - F1 / F2 / F3 `*_Threshold_Modes_IMPLEMENTATION_AND_TEST_PLAN.md`
4. Repo `Agents.md` / `AGENTS.md` — **read only** for voice; **do not** update common DETF expectations here (P7)

---

## Scope (strict)

### In scope

1. **PRD status header** → formal **LOCKED** (date + short rationale: plans accepted **and** P0–P3 implement waves green).
2. **PRD field table** (`Status` row) aligned with formal LOCKED (remove “requires F2/F3 plans only” phrasing that is now stale).
3. **PRD body** places that still say “formal LOCKED after F1+F2+F3 **plans** only” without noting implement completion — update to past tense / locked with evidence, **without** reopening product law.
4. **PRD changelog** entry for formal LOCKED (date, what gated it: P0 lib + F1/F2/F3 threshold-mode shipping).
5. **Optional inventory hygiene (docs only):** where §7 / inventory tables list F1–F3 “Open formalized?” or plan-required language, mark F1–F3 as **Yes / shipped** (or equivalent) if that column exists. Do **not** invent new product rows for F4–F7.
6. **PROGRESS.md:** set **P4** → `done` with date + note; leave P5–P7 `todo`; update “Last updated” and tracker changelog.

### Out of scope

- Any Solidity / TestBase / forge suite changes
- F4 ComposedStableCommon / F5 SingleVaultDetf **implementation**
- Drafting full F4/F5 implementation plans (that is a **P5 prep** task — only create stubs if PRD already points at missing plan paths and a one-line “plan deferred Wave 3” note is needed; **prefer not** creating new plan files in P4)
- F6 NatSpec, F7 Seigniorage audit, AGENTS.md / family PRD “conforms to …” (P6/P7)
- Re-opening §16 encoding locks, thresholds, Open economics, burn-asset rules
- Frontend / deploy scripts / commits / PRs unless the human explicitly asks later

---

## Locked product reminders (do not re-litigate)

- Explicit `ThresholdMode { Policy, Open }`; **never** infer Open from `0` thresholds
- `0,0` → `1.05e18` / `0.95e18`; **`0` never means Open**
- After resolve: both modes reject `mintThreshold <= burnThreshold`
- Gates always **synthetic**; live check in **family**, not core lib
- MUST info: `thresholdMode()`, live-coupled `isMintingAllowed()` / `isBurningAllowed()`
- Event: `ThresholdModeSet(mode, mint, burn)` once at init, **resolved** values
- `PkgArgs`: trailing `thresholdMode`
- Formal LOCKED does **not** mean F4–F7 are shipped — only that product law + Wave 2 (core + F1–F3) is accepted for implementation reference

---

## Process

1. Set **P4** to `in_progress` in `DETF_Threshold_Modes_PROGRESS.md` (date + “docs formal LOCKED”).
2. Edit `DETF_Threshold_Modes_PRD.md`:
   - Status line → e.g. **`LOCKED — 2026-07-28`** (use today’s date when you run).
   - Clarify: product law was locked 2026-07-27; formal LOCKED now that F1+F2+F3 threshold-mode **plans** and **implementation waves (P0–P3)** are complete and green.
   - Update any stale “do not implement until…” gate language so it no longer blocks implementors of **already-shipped** families; keep Wave 3+ (F4/F5) as later work.
   - Add changelog row.
   - Touch inventory/acceptance sections only as needed for consistency.
3. Do **not** change §16 normative encoding text unless you find a pure typo; if §16 references “plan agent only,” leave locks intact.
4. Mark P4 **`done`** in PROGRESS (checklist: PRD header LOCKED + changelog). Update program phases table + tracker changelog.
5. **Stop.** Do not start P5 (F4/F5 plans or code).

---

## Exact verify commands

Docs phase — no forge required for DoD. Optional sanity (must stay green if run):

```bash
# Optional smoke only — not required to claim P4 done
forge test --match-path 'test/foundry/spec/vaults/detf/core/DETFThresholdPolicy.t.sol' -vv
```

**Do not** spend the session re-running full F1/F2/F3 matrices unless you accidentally touch Solidity (you must not).

**Manual checklist (you must complete):**

- [ ] PRD top **Status** says formal **LOCKED** with date
- [ ] PRD status table / “Status of this PRD” section consistent
- [ ] Changelog entry present
- [ ] No accidental product-law edits (diff review: status + inventory tense + changelog only)
- [ ] PROGRESS P4 `done`; P5–P7 still `todo`
- [ ] Suggested next phase note: **P5** = draft F4 + F5 plans (Wave 3), not code yet

---

## Success / definition of done

From tracker P4:

- [x] F1 + F2 + F3 threshold-mode plans accepted  
- [x] Core + F1 + F2 + F3 implemented green (P0–P3)  
- [ ] **PRD header status → formal LOCKED; changelog entry** ← you  
- [ ] PROGRESS.md P4 `done` with date/notes  

When done, leave a short handoff note in the tracker changelog, e.g.:

> P4 formal LOCKED. Next: P5 draft F4 + F5 threshold-mode plans (then implement).

---

## Handoff

- **Do not start P5** (F4/F5 plan drafting or implementation) in this session.
- Do not rewrite `Agents.md` (P7).
- If the human wants a commit, that is a separate request — not required for P4 DoD.

---

## Upstream shipped API (for any inventory wording — do not redesign)

```text
// contracts/vaults/detf/core/DETFThresholdPolicy.sol
enum ThresholdMode { Policy, Open }  // 0, 1
DEFAULT_MINT_THRESHOLD = 1.05e18
DEFAULT_BURN_THRESHOLD = 0.95e18
resolveAndRequireValidThresholds / requireValidThresholdMode
_isMintingAllowed / _isBurningAllowed (mode-aware; no live param; Open short-circuit)
// 2-arg Policy wrappers retained for unported families

// F1 / F2 / F3 (as shipped)
PkgArgs trailing thresholdMode
Storage + init resolve/validate + ThresholdModeSet once (resolved mint/burn)
Common: live-coupled then lib mode-aware allow + synthetic price
Info: thresholdMode(), isMintingAllowed(), isBurningAllowed()
TestBase: _deployOpenMode* / dual-path product Open; extreme Policy mint>burn pairs
```

Families still **not** under formal Wave-2 ship: F4 ComposedStableCommon, F5 SingleVaultDetf (synthetic migration), F6 IProtocolDETF NatSpec, F7 Seigniorage audit.
