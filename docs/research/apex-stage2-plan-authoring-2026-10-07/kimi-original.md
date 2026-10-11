# Kimi K3 original — recommended Stage 2 review-program execution plan

Independent first pass, 2026-10-07. Read: `docs/plans/APEX_STAGE2_REVIEW_PRD.md` (the controlling PRD, cited as **PRD §n / S2-REQ-nn / S2-AC-nn**), `CLAUDE.md`, Stage-1 PRD/plan. No peer artifacts read. These are recommendations for the moderator's `docs/plans/APEX_STAGE2_REVIEW_PRD.plan.md`; not that file. I preserve the PRD's own schema and status names throughout.

## 1. Plan header and authority
Mirror the Stage-1 plan posture: Status "ready for a separately authorized execution session"; controlling PRD named; "writing this plan does not launch the review, grant concurrency, or authorize execution" (PRD:10, :472). State the plan orchestrates a **review program** — no source fixes, test execution, or test authoring anywhere in its steps (S2-AC-15).

## 2. Ordered work order

**Step 0 — Launch gate checklist (S2-REQ-01/02; S2-AC-01/02).** Verify and record: owner Stage-1 satisfaction; separate Stage-2 launch request naming the snapshot label and confirming the coordinator's permitted write roots (S2-REQ-14); Stage-1 evidence note with source identity; the four outside-trade test references; current-source map and build/selector/size/named-regression evidence; and the runtime's **actual** delegation mechanism with its limits — recorded, not invented (S2-REQ-02:103-109). Done when: `REVIEW_MANIFEST.md` exists with authorization and capability sections filled from real metadata. Missing item → state `BLOCKED_AT_LAUNCH`, return to owner; do not proceed, reconfigure, or substitute a synchronous roster.

**Step 1 — Snapshot manifest (S2-REQ-03; S2-AC-03).** Record IndexedEx/Crane revisions, operator-supplied dirty-file/content identity, family-document versions, and the three-way evidence partition (historical / Stage-1 / Stage-2 snapshot). HEAD alone is insufficient; do not run shell or invent hashes — request missing identity and block. Publish the freeze rule: in-scope drift invalidates affected rows and triggers an explicit rebaseline request or completion against an immutable snapshot; never merge findings across trees (PRD:125).

**Step 2 — Ledger preparation (S2-REQ-04/05/10).** Before fan-out, the coordinator drafts: `CRITERIA_LEDGER.md` with all 108 original R1–R14 IDs (count reconciliation recorded, never forced; supplements as `S2-ADD-001…` without renumbering); `AUDIT_ITEM_LEDGER.md` skeleton for the seven entries plus both retractions; `MATRIX_LEDGER.md` skeleton with defined denominator and configuration-variant treatment. Pre-assign one primary coverage owner and seam partners per row (PRD:137, :180).

**Step 3 — Assignment manifest and prompt template (S2-REQ-11).** Each assignment carries: the same snapshot and authority hierarchy (PRD:70-77); primary surfaces plus original/supplemental criterion IDs and catalog classes; required family PRDs and shared-dependency reads; explicit inspection-only permissions (no execution, no fixes, no peer reading during first pass, including via discovery searches); distinct `reviewers/<assignment>-original.md` / `-cross.md` write targets; required §7 schemas; completion criteria; and stop conditions (S2-REQ-13). Overlapping reads allowed; write targets and primary responsibilities disjoint (PRD:180).

**Step 4 — Concurrent first-pass waves (S2-REQ-02/11).** Launch substantive independent first passes with real overlap in the authorized runtime; bounded waves are acceptable (PRD:106). Record reviewer/session identity, assigned coverage, and actual start/end scheduler events — no fabricated timing. Coordinator tracks coverage and failures but never fills an unread lane with an invented conclusion. **Freeze rule:** each original is preserved at its assigned path before any peer text is shared (PRD:281). Done when: every assignment has a frozen original or a recorded failure.

**Step 5 — One bounded combined-original cross-review (S2-REQ-12; S2-AC-12).** Resume the same reviewer sessions where supported; give each reviewer the relevant peer **originals together** (especially seam partners), never a chain of earlier cross-reviews. Challenge list: precedence, reachability, fixture assumptions, duplicates, provenance, severity — not voting. Every proposed defect and every critical shared seam gets a second inspection or an explicit "lacks corroboration" mark. Output: `reviewers/<assignment>-cross.md`; dissent preserved. No repeat-until-green loop; replacements only per the runtime protocol and owner authorization (PRD:290, :295).

**Step 6 — Consolidation (S2-REQ-14/15).** Coordinator rechecks material citations, merges duplicate manifestations without losing affected consumers, and fills the three ledgers plus `REPORT.md` with the exact §7 fields and §8 contents — including the mandatory statement that Stage 2 ran no builds/tests/forks/chain checks, and the four-conclusion separation (PRD §1.1). Consistency check: ledgers and report agree on totals, source identity, statuses (S2-AC-14).

**Step 7 — Completion assessment (S2-REQ-16/17).** Map each S2-AC-01…16 to its evidence row by row. Assign the report state: `INSPECTION_COMPLETE` only when all applicable ACs hold; otherwise `PARTIAL_REPORT` with the missing work enumerated. Readiness effects follow S2-REQ-17 — never severity alone; each blocker names the unsupported requirement and what could resolve it. Missing runtime evidence may coexist with `INSPECTION_COMPLETE`; unknown source coverage may not (PRD:425).

**Step 8 — Owner stop (PRD §11).** Deliver the report with the four checkpoint questions; record the owner's response (date, report/snapshot reference, requested action); do not manufacture a numbered OD. No remediation PRD, verification session, or implementation follows automatically (S2-AC-16).

## 3. Failure and drift handling (cross-cutting, S2-REQ-13)
Distinguish moved paths (re-locate, don't fail the lane) from failed reviewer sessions (record, never impersonate or silently restart). Stage-1 contradictions → `STAGE1_OPEN`/`STAGE1_REGRESSION` with original IDs retained; pause affected work for owner decision; preserve partial report (S2-REQ-07). Authority conflicts → `DECISION_NEEDED`, not an invented ruling (PRD:77).

## 4. Plan pitfalls to encode
Do not serialize sequential calls and label them parallel; do not treat missing runtime evidence as unread coverage; do not renumber the 108; do not let the coordinator absorb reviewer authorship; do not invent runtime tool APIs — the plan references "the runtime's recorded delegation mechanism," nothing more specific; do not weaken a criterion to finish (PRD:310).

## 5. Confidence
High on step ordering, freeze-before-share, and AC mapping; medium on wave sizing (runtime-dependent, deliberately unspecified).
