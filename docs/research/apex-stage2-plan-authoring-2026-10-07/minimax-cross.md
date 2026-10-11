# MiniMax M3 — Stage 2 plan-authoring cross-review

**Sources:** `astra-original.md`, `grok-original.md`, `kimi-original.md` (verbatim); `docs/plans/APEX_STAGE2_REVIEW_PRD.md` (Q). My own `minimax-original.md`. No cross artifacts.

## Consensus (all four)

Six-to-eight-step sequence (gate → snapshot manifest → ledger prep → assignment manifest → concurrent first-pass waves → freeze originals → bounded combined-original cross-review → consolidation → AC mapping → owner stop); owner gate + separate launch authorization; no silent synchronous fallback; real concurrency = overlapping substantive reviews, not sequential calls labeled parallel; **all originals frozen before any peer-text share**; combined-original cross-review (relevant peer originals together, never earlier cross-review opinions); preserved orthogonal schemas (criterion/audit-item/matrix ledgers, inspection result distinct from execution-evidence state, severity distinct from readiness); no shell, no invented hashes, no fabricated timing; no arbitrary agent count or model quota; inspection-only with no test authoring or execution; `BLOCKED_AT_LAUNCH` / `PARTIAL_REPORT` / `INSPECTION_COMPLETE` semantics preserved; `MISSING` execution evidence ≠ `UNINSPECTED` coverage (blocks closure claim, not inspection); drift invalidates affected rows with rebaseline or finish against immutable snapshot, never merge across trees; `STAGE1_OPEN` / `STAGE1_REGRESSION` retain original IDs; no impersonation, no silent identity restart, no manufactured OD-09, no automatic remediation PRD.

## Corrections to my original

1. **Withdraw Wave A–D specifics.** My phases 2 enumerated concrete wave composition (provenance+matrix first; FullSpread family; Wings+AMM; Hooks+Balancer+DETF+cross-cutting). Peers correctly defer wave composition to the authorized runtime's real overlap limit (Grok §3, Kimi Step 4, Astra §4). The PRD uses "bounded waves" without forcing composition. **Correction:** replace my specific wave letters with the principle "matrix identity first, then FullSpread family, then remaining groups" as coordinator guidance, not a fixed schedule.

2. **Per-row initial field state.** Grok §2 and Kimi Step 2 explicitly set `owner_and_review_state=UNINSPECTED` and `inspection_result=NOT_ASSESSED` on every new ledger row before fan-out, with `execution_evidence` independent. My Phase 1 wrote skeletons without these defaults. **Correction:** add the explicit pre-fan-out defaults so a row only leaves `UNINSPECTED` after a real read.

3. **Default output root.** Only Grok §1.5 named the PRD §8.1 default `docs/research/apex-stage2-review/<snapshot-label>/`. My original did not. **Correction:** confirm that root and the PRD's "if that profile requires a different root, record the substitution" rule.

4. **Cross-review chain contamination.** Kimi Step 5 and Astra §5 are most explicit ("never earlier cross-reviews"; "Cross-review never consumes peer cross-reviews"). My cross-review description is implicit. **Correction:** add the explicit prohibition that cross-reviewers never see other reviewers' cross outputs.

5. **Prompt hygiene.** Grok §3, Astra §5, and Kimi Step 3 all forbid "search for peer outputs" or "peer reading during first pass via discovery searches." My prompt template omits this. **Correction:** add "no artifact-discovery searches for peer outputs" to the first-pass prompt.

## Unresolved dissent

None material after corrections. Mild: wave sizing is runtime-dependent; peers and corrected mine agree to leave it unspecified.

## Confidence

High on consensus and the five concrete corrections; the plan now aligns with PRD §3–§9, §11, and §12 without scope drift.