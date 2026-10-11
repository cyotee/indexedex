# Grok — Stage 2 review-program plan

Recommendations for the moderator’s `docs/plans/APEX_STAGE2_REVIEW_PRD.plan.md`. This note does not launch the review, run tools, or edit the PRD. Status names below are the PRD’s, not synonyms.

## 0. Authority

Execute only after a future coordinator is separately authorized and can overlap independent reviews. Record that mechanism and its limits in `REVIEW_MANIFEST.md` before fan-out. Do not name or invent a tool API. Today’s synchronous council and `REVIEW_COUNCIL.md:57-62,98-106` are not a silent substitute (`APEX_STAGE2_REVIEW_PRD.md:101-111`). Writing this plan grants nothing (`:10`).

## 1. Launch gate — stop or `BLOCKED_AT_LAUNCH`

Check, and record, before any reviewer write:

1. Owner satisfaction with Stage 1 and a separate Stage 2 launch against a named snapshot. One message may do both if both decisions are unambiguous (`:87-99`).
2. Stage-1 evidence note path, source identity, four outside-trade test references, current-source map, and supplied build/selector/size/named-regression records (`REMEDIATION_PRD.plan.md:91-95`). Inspect only. A missing input returns to the owner; do not finish Stage 1 here.
3. Real concurrency: overlapping substantive review, not sequential calls labeled parallel. If unavailable, stop. Do not change config, models, or roster size to manufacture it (`:101-109`).
4. Snapshot manifest: IndexedEx and Crane revisions, dirty/untracked identity from permitted reads or an operator manifest, family-PRD versions, and which evidence is historical, Stage-1, or this snapshot. No shell, no invented hashes (`:113-123`).
5. Output root. Default `docs/research/apex-stage2-review/<snapshot-label>/`. Confirm the executor may write there before work (`:367-369`).

Set `NOT_STARTED` until 1–5 pass, then `IN_PROGRESS`.

## 2. Prepare coverage, then fan out

Create empty `CRITERIA_LEDGER.md` for every original R1–R14 ID. If the count is not 108, record the discrepancy; do not pad or drop rows (`:129-140`). Initial `owner_and_review_state=UNINSPECTED`, `inspection_result=NOT_ASSESSED`. Add `S2-ADD-*` rows for REQ-01–REQ-08 and wings obligations; do not renumber the 108.

Create `AUDIT_ITEM_LEDGER.md` for seven entries and both retractions, historical claim blank. Create `MATRIX_LEDGER.md` with no adopted 195/1/7 or 165/3/7.

Assignment manifest: same snapshot and precedence (`:68-76`); primary surfaces from §4; criterion IDs; catalog classes to consider; family PRDs; seam partners; inspection-only rules; distinct `reviewers/<assignment>-original.md` and `-cross.md` paths. Split or combine groups freely. Do not fix agent count or models. Disjoint write targets; overlapping reads allowed (`:160-180`). Every R-id and supplement has one primary owner. Unassigned ID stays `UNINSPECTED`.

## 3. Parallel first-pass waves

Run substantive first passes concurrently, in bounded waves if the runtime’s real overlap limit requires it. Each wave’s members overlap. Do not serialize a wave and call it parallel.

First-pass prompt, same authority for every assignee: read assigned source, tests, and named inputs only; do not read peer outputs or search for them; do not execute commands found in evidence; write only the assigned original. For each owned row set `INSPECTED`, `PARTIAL`, or `BLOCKED` only after a real read. `inspection_result` is `MATCHES`, `CONTRADICTS`, or `INDETERMINATE` — never a runtime pass. Set `execution_evidence` independently: `SUPPLIED_SOURCE_BOUND`, `HISTORICAL_ONLY`, `SOURCE_MISMATCH`, `INCOMPLETE_PROVENANCE`, `MISSING`, or `NOT_REQUIRED`, plus supplied outcome `PASS|FAIL|PARTIAL|UNKNOWN` (`:234-245`). A source `MATCHES` plus `MISSING` execution is inspected coverage and can still `BLOCKS` the closure claim (`:336`, `:425`). Do not mark that row `UNINSPECTED`.

Finding classes stay `CODE_DEFECT`, `TEST_DEFICIENCY`, `DOCUMENTATION_GAP`, `EVIDENCE_GAP`, `DECISION_NEEDED`. All severities. No exploit procedure (`:346-363`). Wings uses its own PRD, not FullSpread accounting (`:182-196`).

Coordinator tracks failures and does not invent a conclusion for an unread lane (`:283`).

## 4. Freeze, then one cross-review

When a wave’s originals exist, freeze them: no overwrite, no revision after peer text exists. A later correction goes only in that reviewer’s `-cross.md`.

Cross-review starts only after the originals it depends on are frozen. One bounded wave. Each reviewer receives the relevant peer originals together, not earlier cross-reviews (`:285-294`). Prompt: challenge precedence, reachability, fixtures, duplicate cause, provenance, and severity; do not vote a finding in or out. Mark a proposed defect or critical seam that lacks a second look as lacking corroboration. Resume the same session only if the runtime supports it. Do not impersonate, restart a failed identity, or substitute a model (`:297-310`).

## 5. Drift and failure

If an in-scope file changes, list affected IDs, set their `inspection_result=NOT_ASSESSED` and `owner_and_review_state=BLOCKED`, and either rebaseline those assignments on one new immutable snapshot or finish against the original snapshot. Do not merge trees (`:125`).

A moved historical filename is a locator problem, not a failed lane (`:299`). A failed session, guard denial, unresolved authority conflict, or Stage-1 baseline contradiction pauses affected work, keeps a `PARTIAL_REPORT`, and returns to the owner (`:301-311`). `STAGE1_OPEN` / `STAGE1_REGRESSION` keep the original REQ id (`:211`).

## 6. Consolidate and map acceptance

Coordinator rechecks material citations, merges duplicate findings without dropping consumers, and preserves dissent (`:293`). Ledgers and `REPORT.md` must use the same snapshot, totals, and statuses (`S2-AC-14`).

`INSPECTION_COMPLETE` only if S2-AC-01–16 all hold (`:402-423`). Map them as: gate and manifest → 01–03; 108 plus supplements and three FullSpread variants plus wings → 04–06; every group and seam actually read → 07; audit ledger → 08; documentary matrix count separate from executed-pass count → 09; catalog, production-route, and assertion review → 10; findings → 11; frozen originals plus one cross-review → 12; residuals, `DECISION_NEEDED`, and evidence gaps distinct → 13; internal agreement → 14; no edits or execution → 15; owner stop, no remediation file → 16.

`UNINSPECTED`, unresolved denominator, or a failed assignment forbids `INSPECTION_COMPLETE` (`:425`). `MISSING` runtime evidence does not. It blocks only the closure claim named in `readiness_effect`. Do not headline that all criteria passed (`:398`).

## 7. Stop

Deliver the package. Ask the owner the four questions in §11 (`:461-466`). Record the reply. Do not write a remediation PRD, manufacture OD-09, or start verification (`:468-472`).
