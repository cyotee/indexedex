# Mission: DETF Threshold Modes — program complete + optional follow-ons

**Status:** The Threshold Modes program **P0–P7 is complete**. There is **no required next phase**.

This file is an **optional** agent brief for post-program work the human may choose. Do **not** invent a P8 product phase or re-open the PRD.

Copy this entire file into a new agent session **only if** the human selected one of the optional tracks below (or asked for closeout verification). If the human only wanted confirmation the program is done, reply that P0–P7 is complete and stop.

---

## Program dashboard (final)

| Phase | Content | Status |
|-------|---------|--------|
| **P0** | Core `DETFThresholdPolicy` | `done` |
| **P1** | F1 SingleStandardExchangeDETF | `done` |
| **P2** | F2 MultiVaultWeightedDetf | `done` |
| **P3** | F3 MixedBufferMultiVaultStableDetf | `done` |
| **P4** | Formal PRD **LOCKED** | `done` |
| **P5** | F4 + F5 (plans + implement; F5 synthetic migration) | `done` |
| **P6** | F6 `IProtocolDETF` NatSpec/`thresholdMode`; F7 Seigniorage **Out** | `done` |
| **P7** | AGENTS + family PRD conform notes | `done` |

**Canonical tracker:** `contracts/vaults/detf/DETF_Threshold_Modes_PROGRESS.md`  
**Product law:** `contracts/vaults/detf/DETF_Threshold_Modes_PRD.md` (**LOCKED**)  
**F7 Out note:** `contracts/vaults/seigniorage/THRESHOLD_MODES_OUT.md`

**Do not re-litigate product law.** F7 remains Out unless the human opens a new initiative to revive parity.

---

## Role

You are a **post-program** agent. Scope is **only** the track the human named when pasting this file. Default: if unclear, ask which track (A–E) and wait.

---

## Optional tracks (pick one)

### Track A — Closeout verification (oversight-style, read-only preferred)

**Goal:** Confirm P7 DoD and program completeness without new features.

- Skim AGENTS.md Policy/Open + PkgArgs vs fee oracle split
- Confirm F1–F4 PRD conform one-liners + F5 plan-header note + F7 Out
- Spot-check tracker last-updated / P0–P7 all `done`
- Optional smoke (only if human wants evidence):

```bash
forge test --match-path 'test/foundry/spec/vaults/detf/core/DETFThresholdPolicy.t.sol' -vv
# optional family smokes if human requests full matrix
```

- Deliver a short **PASS / PASS WITH NITS** note; do not expand scope

### Track B — Git commit hygiene (threshold-modes only)

**Goal:** Help prepare a **focused** commit/PR for threshold-modes work **if the human requests it**.

- List changed paths under `contracts/vaults/detf/**`, related tests, AGENTS, interfaces, seigniorage Out note
- **Do not** commit unless the human explicitly asks for a commit
- Exclude unrelated dirty tree (frontend, other deploys) unless human includes them
- Suggested commit message theme: `feat(detf): Policy/Open threshold modes (P0–P7)`

### Track C — Frontend / UX for threshold mode (new initiative)

**Goal:** Only if human wants product UI awareness of Policy vs Open.

- Read PRD for user-facing implications (Open has no peg narrative; Policy deadband)
- Scope a **separate** frontend plan under `frontend/` — do not change Solidity
- Use `indexedex-product-voice` if writing customer copy
- Out of original program DoD — treat as new project

### Track D — F7 Seigniorage revival (new initiative)

**Goal:** Only if human **explicitly** wants to reverse formal Out and ship Policy/Open parity.

- Read `THRESHOLD_MODES_OUT.md` + seigniorage package first
- Write a **new** plan (parity redesign of peg economics is non-trivial)
- Do not half-wire mode without tests
- Requires human product confirmation before implement

### Track E — Residual fee-oracle / docs language cleanup elsewhere

**Goal:** Grep remaining docs that claim fee oracle sets mint/burn thresholds; fix **docs only** to match P7 AGENTS law.

```bash
rg -n 'feeOracle.*threshold|threshold.*fee.?oracle|mintThreshold.*oracle' docs contracts --glob '*.md' | head -50
```

- Do not change fee-oracle Solidity behavior unless human expands scope

---

## Out of scope for all tracks (unless human overrides)

- Re-opening §16 encoding locks or inventing new modes
- Mandatory full re-run of F1–F5 matrices without a bug report
- Implementing F7 “just because”
- Silent commits / force-push / broad tree cleanup

---

## Process (any track)

1. Confirm which track (A–E) with the human if not stated.
2. Set nothing in the Threshold Modes tracker to `in_progress` unless the track is a real new initiative (D/C) — then create a **new** tracker/plan, do not reopen P0–P7 as incomplete.
3. Execute only that track.
4. Stop. Report results.

---

## If the human asked “what’s next?” with no track

Reply roughly:

```text
Threshold Modes P0–P7 is complete.
Optional next: A closeout verify | B commit prep | C frontend mode UX |
D F7 revival plan | E residual docs grep.
No automatic implement phase remains.
```

Do **not** invent P8.

---

## Success

- Human knows the program is closed
- Any optional work is scoped, explicit, and does not pretend to be required Threshold Modes phase work
