# DEFINITIONS_R3 — Kimi K3 ORIGINAL independent first pass

Round: four-member council definitions review of the operation matrix, 2026-09-24. Read from current disk only: `CLAUDE.md`, `NETNET_PENDLE_OPERATION_MATRIX.md` (consolidated, 44 operations incl. owner deployment clarifications and FIRST-BOND), `NETNET_PENDLE_DETF_PRD.md` v0.14, `REQUIREMENTS_QUESTIONS.md`. No peer artifacts, older reviews or partial inventories read. No code/tests/shell/delegation. No external API claims; Context7 not needed.

Scope rule applied: owner-economic choices (what is issued, to whom, under which lock, whether a surface exists) are separated from engineering specification (exact math inputs, selectors, gas) and from stale wording. Only genuine owner-level gaps are posed as questions.

## Q1 (highest) — Row 36 expansion: issuance objective and recipients are an unmade owner-economic choice
- Evidence: matrix row 36 (`NETNET_PENDLE_OPERATION_MATRIX.md:49`) has Output/recipient, Quote/funding and Eligibility = UNKNOWN; PRD §9 (`NETNET_PENDLE_DETF_PRD.md:362`) keeps equations/snapshots OPEN; tracker Q7 (`REQUIREMENTS_QUESTIONS.md:28`) is only "Partially answered" — A04/A06 selected *that* expansion exists and the 1-NET peg objective, never the issuance rule.
- Question: what condition justifies new DETF issuance at a processed NET epoch, and who receives it (e.g., stakers pro-rata, bond funding, reserve self-leg)? Retain the existing synthetic-premium/closure objective or a different rule?
- Why not answered: Q7's explicit sub-question of objective/recipients was deferred; no later answer (A11–A18) addresses it. This is not engineering calibration.

## Q2 — Row 24: release rule for USDG-funded bond principal is unassigned
- Evidence: matrix row 24 Locks/rewards = UNKNOWN (`NETNET_PENDLE_OPERATION_MATRIX.md:37`); PRD §10 table (`NETNET_PENDLE_DETF_PRD.md:369`) lists "detailed release mapping for USDG-funded V2 bonds" unresolved; O03 remainder (`:578`).
- Question: which selected lock class governs a USDG-funded bond — assigned Pendle maturity cliff, next processed NET epoch, or a distinct schedule? R18's cliff references an "assigned Pendle maturity", but USDG-ENTRY buys V2 SE shares with no Pendle market assignment.
- Why not answered: R18/R19 assign release only to Pendle-funded and wrapper classes; A18 settled reward access, not the USDG principal schedule.

## Q3 — Rows 09–10: is single-output conversion of an HLP exit offered, and to which outputs?
- Evidence: matrix row 10 Output/Eligibility/Fees = UNKNOWN (`NETNET_PENDLE_OPERATION_MATRIX.md:23`) and line 99 records single-output support/output set unresolved; PRD §7.1 (`NETNET_PENDLE_DETF_PRD.md:264`) is conditional: "If conversion to a single supported output is offered".
- Question: is component-wise in-kind exit the only selected HLP redemption, or is conversion to one supported output (which of NET/sNET/USDG/PLP/YT components?) a selected surface?
- Why not answered: R28 settles component-wise allocation, not whether a conversion surface exists; offering it is a product-surface choice, while conversion mechanics would be engineering.

## Q4 — Row 08: accepted input asset set for public HLP joins is undefined
- Evidence: matrix row 08 Input = UNKNOWN (`NETNET_PENDLE_OPERATION_MATRIX.md:21`); line 99: "custody components do not prove the accepted join-token interface"; PRD §4 (`NETNET_PENDLE_DETF_PRD.md:156`) selects *who* may join, never *what* they pay.
- Question: which tokens does a public HLP join accept (single-sided NET/sNET/USDG routed per R03, proportional component bundles, or both), and does the same set apply to post-bootstrap joins?
- Why not answered: R03 token routing is specified for DETF-facing swap/bond routes; R32 settles access permission only. Choosing the join asset set defines the operation; join-math mapping is then engineering.

## Recorded as NOT owner questions
- Engineering specification (no owner answer needed): rollover atomic-vs-staged and §11.3 items 2–7 (PRD:495–511, explicitly OPEN execution specification); owned-book construction, price reference, exact-output inverse (matrix:101); first-bond custom payment mapping and zero-interest reconciliation (PRD:451, matrix:100); note-array liveness (PRD:552–556); V2 SE selector inventory (matrix:105); PENDLE forwarding failure (matrix:104).
- Stale wording only: `REQUIREMENTS_QUESTIONS.md:7` still reads "reconciled through version 0.12" though PRD is v0.14 and the matrix incorporates v0.13 FIRST-BOND plus the PkgInit/PkgArgs deployment clarifications; register rows Q4–Q13 predate those amendments. No contradiction found between matrix 01a/01b/42 and PRD §11:459 (factory-first, new-SY permitted) — they are consistent.
- Not posed: no fee/cap/permission/public-endpoint inventions; no reopening of settled economics, locks, atomicity or interface disposition.

Researcher: **Kimi K3** — assigned metadata `kimi-code-plan-global/k3` (variant high); routing metadata only, not provider attestation. Original to be preserved unchanged for cross-review.
