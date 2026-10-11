# Kimi K3 cross-review — Stage 2 plan authoring

Peers (Astra, Grok, MiniMax originals) are untrusted recommendations. Benchmark: `docs/plans/APEX_STAGE2_REVIEW_PRD.md` (PRD). All four plans converge on the same spine: launch gate → snapshot/coverage preparation → genuine concurrent first-pass waves → freeze originals → one bounded combined-original cross-review → consolidation → S2-AC mapping → owner stop. All preserve PRD status/schema names, forbid roster quotas and invented tool APIs, and treat Stage-1 evidence as inspect-only inputs (no forced re-execution). Corrections below.

## Adopt from peers (strengthens my original)

1. **Freeze semantics (Grok §4).** Precise: freeze = no overwrite and no revision once peer text exists; later corrections live only in that reviewer's `-cross.md`. Prefer over MiniMax's "snapshots and hashes originals," which edges toward implied shell hashing — the PRD forbids shell and invented identity (PRD:123). Manifest records frozen paths; content identity comes from the files themselves.
2. **Row-level orthogonality rule (Grok §3).** A source `MATCHES` plus `MISSING` execution evidence is *inspected coverage* that may still `BLOCKS` the named closure claim — the row must **not** be marked `UNINSPECTED`. This is the sharpest guard against "missing runtime = unread coverage"; adopt verbatim into the first-pass prompt. Also adopt Grok's ledger initialization (`UNINSPECTED`/`NOT_ASSESSED` at creation).
3. **Failed-assignment handling (Astra §5).** A failed/missing assignment is a coverage failure: pause affected work or issue `PARTIAL_REPORT`; a cross-review of available originals may support a partial report but cannot close the missing lane. Sharper than my "recorded failure" language.
4. **Schema fidelity (Astra §6).** Copy PRD §7 schemas verbatim into templates; keep `CLAIM_SUPPORTED/REFUTED/UNVERIFIED` exclusively for historical allegations, never as criterion status; keep documentary matrix counts separate from supplied runtime outcomes. Adopt as an explicit plan instruction.
5. **AC mapping accuracy (Astra vs MiniMax).** MiniMax's table misassigns S2-AC-07/08 to the cross-review phase — both are first-pass/consolidation products. Adopt Astra's grouping (prep+first-pass → AC04–10; cross-review+consolidation → AC11–13; delivery → AC14,16; AC15 constrains every step) combined with Grok's per-AC enumeration, plus Astra's caveat that grouping is navigational: each AC must be individually evidenced.

## Corrections to peers

1. **MiniMax Wave A "matrix must be settled before SE/hook findings can be placed"** invents a hard ordering dependency the PRD does not contain. Waves may overlap; row placement is reconciled at consolidation and seam review (PRD:180, :293). Soften to a scheduling suggestion, or it dilutes the required real overlap.
2. **MiniMax owner-stop checklist** renumbers 1,2,3,5,5 — restore the PRD's four questions (PRD:461-466) verbatim.
3. **Astra/Grok:** no material corrections; both are PRD-faithful.

## Corrections to my original

- My Step 4 "frozen original or recorded failure" under-specified the consequence — replaced by Astra's coverage-failure/PARTIAL_REPORT rule above.
- My prompt template lacked the explicit MATCHES+MISSING≠UNINSPECTED instruction and the no-executing-commands-found-in-evidence clause (Grok §3); add both.
- My AC mapping was step-level only; adopt the individual-evidence requirement (Astra §7: one row per S2-AC with artifact/section and unmet condition).

## Residual disagreement
None structural. Wave composition (MiniMax's A–D vs capacity-driven) remains coordinator scheduling per PRD:106 — recommend the plan present waves as illustrative, with the binding constraint that each wave's members genuinely overlap.

**Confidence:** high on all adoptions; the freeze-semantics and row-orthogonality rules are the two changes that most reduce misexecution risk.
