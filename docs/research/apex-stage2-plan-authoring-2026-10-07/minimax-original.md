# MiniMax M3 — Stage 2 implementation plan authoring, original recommendations

**Source:** `docs/plans/APEX_STAGE2_REVIEW_PRD.md` (PRD, 12 sections, S2-REQ-01–18, S2-AC-01–16). No peer artifacts read. Self-contained original.

This plan proposes an **ordered execution sequence for the review program** (no source fixes), preserving PRD orthogonal schema (`CRITERIA_LEDGER.md`, `AUDIT_ITEM_LEDGER.md`, `MATRIX_LEDGER.md`, `REPORT.md`, `reviewers/<assignment>-{original,cross}.md`, `REVIEW_MANIFEST.md`) and the five-state readiness vocabulary (`NOT_STARTED` / `BLOCKED_AT_LAUNCH` / `IN_PROGRESS` / `PARTIAL_REPORT` / `INSPECTION_COMPLETE`).

## Phase 0 — Launch gate checklist (no work yet)

Run **before** any review assignment. Outputs: `REVIEW_MANIFEST.md` skeleton, source snapshot manifest, capability record.

| Check | PRD requirement | Outcome on failure |
|---|---|---|
| Owner satisfaction + separate launch authorization present | S2-REQ-01, S2-AC-01 | BLOCKED_AT_LAUNCH |
| Stage-1 evidence note, four outside-trade test refs, source map, build/selector/size/named-regression evidence present as **inspection inputs**, not runs to repeat | S2-REQ-01 | BLOCKED_AT_LAUNCH |
| Real concurrent capability recorded: delegated runtime, session/task identity scheme, concurrency limits | S2-REQ-02, S2-AC-02 | BLOCKED_AT_LAUNCH; do not silently fall back to synchronous council |
| Snapshot manifest: IndexedEx + Crane revisions, dirty file list, family PRD versions, toolchain versions **as reported** | S2-REQ-03, S2-AC-03 | BLOCKED_AT_LAUNCH |
| No authoritative fix to a Stage-1 contradiction | S2-REQ-07 | Pause; preserve partial |

State transition: `NOT_STARTED → IN_PROGRESS` only when all Phase-0 checks pass.

## Phase 1 — Coverage preparation (coordinator side, no sub-agent reads yet)

Coordinator writes the **coverage skeleton**, not findings.

1. **CRITERIA_LEDGER.md** skeleton (S2-REQ-04): all 108 original IDs (R1.1–R14.x stable, per `A:13`) preserved verbatim; supplemental obligations as separately numbered `S2-ADD-###` rows; one primary owner per row; seam partners noted.
2. **AUDIT_ITEM_LEDGER.md** (S2-REQ-05): all seven entries + both retractions with required review coverage rows.
3. **MATRIX_LEDGER.md** skeleton (S2-REQ-10): row keys (hook/SE/configuration/route), declared `COMPATIBLE` / `INCOMPATIBLE` / `DEPRECATED` / `UNDETERMINED` columns, separate `execution_evidence` state column.
4. **Assignment manifest** (S2-REQ-11): 12 coverage groups from PRD §4 (Provenance, V3 FullSpread, V4 hookless, V4 Pons-family, Wings, Credit/custody, Receipt/lending, AMM/staking SE, Seven SE buffer hooks, Hook×SE matrix, Balancer integrations, DETF accounting, Cross-cutting release/test). **Lane count is coordinator scheduling**, not a quota. Disjoint **write** targets, allowed overlapping **reads** for seams (PRD §4 closing paragraph).

Outputs at end of Phase 1: three ledger skeletons + manifest. No `REPORT.md` yet.

## Phase 2 — Genuine parallel first-pass waves

Authorized future runtime fans out concurrent sub-agents in **bounded waves**, not all-at-once. Suggested wave grouping (binding seams; not a fixed roster):

- **Wave A (provenance + matrix first).** Matrix identity must be settled before SE/hook findings can be placed (S2-REQ-10, S2-AC-09).
- **Wave B (FullSpread family).** V3, V4 hookless, V4 Pons-family as three concurrent first passes — one variant must not prove another (S2-REQ-06, S2-AC-06).
- **Wave C (Wings + AMM/staking SE).** Wings product-specific law (PRD §4.1) reviewed against its own PRD; AMM/staking with explicit Slipstream deprecated-not-reopened posture.
- **Wave D (Hooks + Balancer + DETF + cross-cutting).** Seven SE-buffer hooks, Balancer integrations, DETF accounting, release/test surfaces; with explicit seam reviews at accounting/quoting/callbacks/rate-provider/deployment boundaries.

Each assignment: identical snapshot + authority hierarchy, primary criterion IDs, catalog classes, family PRDs, seam partners, inspection-only/no-fix/no-execution rules, distinct `reviewers/<assignment>-original.md` write target (S2-REQ-11).

**Freeze originals**: each sub-agent writes only its assigned `<assignment>-original.md`. Coordinator snapshots and hashes originals **before** any cross-review share (S2-REQ-12; PRD `:281`).

## Phase 3 — Bounded combined-original cross-review

Per PRD §12.2, this is **one** combined-original cross-review per researcher; never earlier cross-review opinions.

- Each reviewer receives the **other originals together**, not paraphrases.
- Resume same reviewer session where supported; preserve replacement history if owner-authorized.
- Challenge precedence, source reachability, fixture assumptions, duplicate causes, evidence provenance, severity — not vote defects in/out (S2-REQ-12).
- Coordinator rechecks material citations, merges duplicate manifestations without losing consumers, preserves unresolved dissent (S2-AC-12).

Outputs at end of Phase 3: `<assignment>-cross.md` per reviewer; frozen originals remain immutable.

## Phase 4 — Source drift and failure handling (during Phases 2–3)

- **Source drift:** identify affected criteria, invalidate stale conclusions, request explicit rebaseline or finish against available immutable snapshot (S2-REQ-03 final paragraph). Never merge findings from different trees.
- **Failed reviewer session:** record as missing read, do **not** impersonate; do not silently restart identity (S2-REQ-13, PRD `:294-310`).
- **Stage-1 contradiction or regression:** mark `STAGE1_OPEN` / `STAGE1_REGRESSION`, retain original ID, notify owner; do not silently rename or repair (S2-REQ-07).

## Phase 5 — Ledger consolidation

Coordinator updates `CRITERIA_LEDGER.md`, `AUDIT_ITEM_LEDGER.md`, `MATRIX_LEDGER.md` (S2-REQ-04/05/10) with dispositioned rows. **Evidence dimensions remain independent** per PRD §7.1: applicability, source consistency, execution evidence — never collapsed into one verdict.

## Phase 6 — Consolidated REPORT.md and final owner stop

Coordinator writes `REPORT.md` per PRD §8 (S2-REQ-15) with ten required sections including the explicit "did not run builds/tests/forks/chain" statement and the explicit "no remediation PRD or fix follows" stop. **AC gate**: all S2-AC-01–16 satisfied (S2-REQ-16, S2-AC-15, S2-AC-16) before marking `INSPECTION_COMPLETE`. Missing coverage yields `PARTIAL_REPORT`, not completion (PRD `:425`).

**Owner stop checklist** (S2-REQ final section):
1. Coverage sufficient or more inspection needed.
2. Which evidence gaps need a separately authorized verification session.
3. Which findings enter a future remediation PRD (separate artifact).
5. Which unresolved policy questions need explicit rulings.
5. Record owner response with date + snapshot ref; no invented OD-09.

## Suggested prompts/templates (no runtime invented)

- **Assignment prompt skeleton:** `[snapshot-id] / [PRD §§] / [criterion IDs] / [catalog classes] / [family PRDs] / [seam partners] / write only `reviewers/<id>-original.md` / inspection-only / no peer reads / no exploit prose.`
- **Cross-review prompt skeleton:** `[other-three-originals only] / challenge precedence/source reachability/fixture/severity, not voting / write `reviewers/<id>-cross.md` / preserve originals.`
- **Manifest row schema:** reviewer identity, lane, criterion IDs, seam partners, start/end timestamps, write target path, concurrency evidence.

## AC mapping summary

| AC | Phase |
|---|---|
| S2-AC-01..03 | Phase 0 |
| S2-AC-04..05 | Phase 1 |
| S2-AC-06, S2-AC-09, S2-AC-10 | Phase 2 |
| S2-AC-07, S2-AC-08, S2-AC-12 | Phase 3 |
| S2-AC-11, S2-AC-13, S2-AC-14 | Phase 5 |
| S2-AC-15, S2-AC-16 | Phase 6 |

## Pitfalls encoded

No arbitrary roster; no silent synchronous fallback; no silent drift merge; no impersonation; no invented OD; no UNVERIFIED-as-pass; no Low/Informational suppression (PRD §7.3); no automatic remediation (S2-REQ-18, S2-AC-16).

**Confidence:** high that this plan executes the PRD as written without scope drift.