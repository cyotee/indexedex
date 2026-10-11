# Astra — combined authoring cross-review

Read the three current originals together; no peer cross-reviews. **G/M/K** below denote `grok-original.md`, `minimax-original.md`, and `kimi-original.md` in this directory. **R/P** denote the controlling readiness PRD/plan under `docs/reviews/apex-2026-09-17-second-audit-readiness/`.

## Consensus to retain

All originals support the broad 108-criterion reconciliation, current matrix, changed/new vaults, inspection-only review, all-severity reporting, separate launch after owner satisfaction, genuine future concurrency, and report-first/owner-discussion-before-remediation boundary. Keep my proposed lanes as scheduling suggestions, not required reviewer counts/models. Require actual overlapping reviews and attribution; unavailable capability blocks launch without authorizing configuration changes. **[G:9–15; M:68–77; K:5–12]**

## Concrete corrections

1. **Separate three truth domains.** Kimi's criterion `CONFIRMED/REFUTED` and MiniMax's similar schema are ambiguous: confirming an acceptance property is opposite to confirming a vulnerability. Use independent fields:
   - criterion applicability: applicable / superseded / inapplicable, with authority;
   - inspection result: matches / contradicts / indeterminate;
   - execution evidence: source-bound supplied evidence / historical-only / missing / mismatched—not executed by Stage 2.
   Audit allegations separately receive supported / refuted / unresolved with rationale. An inspection match cannot establish runtime closure. **[K:32; M:30–54; G:46]** This also sharpens my original generic “conclusion” field.

2. **Matrix counts need two dimensions.** Retain my declared-design disposition versus runtime-evidence distinction. Count all enumerated current combinations by declared compatibility, with denominator/configurations; separately summarize supplied passing-run evidence. Never call a source recount an executed compatibility pass. Missing rows remain explicit, not omitted from the denominator. **[G:15; K:23–24,36; R:317–320]**

3. **Do not shrink coverage.** MiniMax's R3–R14 completion gate omits R1/R2 despite its 108-row requirement. Its rate-provider “D48 only” misses current OD-02/REQ-07. Crane NatSpec is reviewable evidence, not excluded merely because editing is prohibited. Inspect all seven hook families, including single-CP distinctly; discover exact current paths rather than treating proposed shorthand as verified inventory. Kimi's “four vault variants and wings” should be **three FullSpread variants plus wings**. **[M:19,23,26,54,60; K:37; R:185]**

4. **Cross-lane reads must overlap where needed.** Reject Grok's strictly disjoint file sets: independent ownership is useful, but shared-credit, quote, callback, and deployment dependencies need explicit seam review, not coordinator-only inference. **[G:19]** No new features are authorized by tracing those dependencies.

5. **No severity or blocker shortcuts.** MiniMax's Medium+ remediation-candidate threshold contradicts all-severity review. Grok's automatic nonblocking `UNDECIDED` is unsafe: unresolved applicability can block readiness. Neither every Low mismatch nor every missing optional artifact automatically blocks readiness; record the specific acceptance dependency. Missing required runtime evidence may block readiness without being a bug. **[M:54,66; G:50]**

## Remaining distinctions

No automatic remediation input filter or mandatory OD-09: the owner decides subsequent scope. A report can be delivered with missing reviews, but must say **incomplete**, not completed broad coverage. Separate report delivery, review completion, and readiness. Proposed future report roots require that coordinator's explicit permissions; current council permissions do not transfer. No substantive scope dissent remains beyond these corrected schema/gate choices.
