# Unified PRD integration record

Pinned draft: coordinator/PRD-draft.md, pairtoken-unified-prd-draft-r1.
Raw SHA-256: a0e81c4da3444fb617dab1dfa562579055d69d11367935bdb5406dd6df4b77bd.
Intended sole planner-facing publication: handoff/PRD.md, pairtoken-unified-prd-r1.

## Member contributions and adoption

- Astra: adopt opening single-document purpose/provenance, PT-CONFORM-03 evidence framing, C1 zero/nonzero and native-zap terminology correction, local C2 read-order wording with skip-add early return preserved, explicit conditional uncapped-fee rollback, and standalone handoff/limits wording.
- Grok: adopt single working authority, native event/zero and negative receipt scenarios, uniform read traces, no-add zap case, zero-transfer/compound distinctions, and narrowly scoped two-full-word encoding note. Preserve existing ERC-20-specific first sentence of PT-DEP-05 rather than globally replacing measured wording.
- MiniMax: adopt explicit uncapped-rate consequence, full preservation constraints for formulas/IDs/dependencies, native payout wrapper and zero-position compound acceptance cases, and identity separation from archived r2. Keep original numbered sections with an unnumbered product preamble, so numeric references remain valid. Do not add five redundant PT-PRD IDs: purpose/non-goals/provenance are integrated in prose, and conformance evidence has one new PT-CONFORM-03. Do not adopt the proposed on-each-touch earnings phrase: share approvals/transfers and views do not compound.
- Kimi: adopt concise product operations, exact native/ERC-20 terminology, reached-pair sampling rather than universal snapshot semantics, release-evidence/dependency limitations, zero-output native failure and positive-add zero-position compound cases.

## Acceptance consolidation

All original PT-AC-01 through PT-AC-58 are retained byte-for-byte as table rows. Overlapping member suggestions are consolidated into ten new rows, PT-AC-59 through PT-AC-68: nominal native event/refund; zero ERC-20 receipt; negative balance difference; reached idle read order and skip-add; no-add zap with prior tick checks passing; zero-output route distinction; native payout wrapper including zero-value rejection; zero-position compound positive addition; zero-position compound zero addition/swap-only no event; and uncapped-fee conditional rollback. Astra's suggested PT-AC-U identifiers and other members' colliding numerical proposals are normalized to this single unique sequence. No new money-path guard is added.

## Preservation evidence

One-off structural comparison found 175 unique original defined IDs (172 numbered plus 3 BASE IDs), all preserved. Draft has 186 unique IDs: those 175 plus PT-CONFORM-03 and ten new acceptance rows. There are no duplicate definitions, no missing original IDs, 58 original scenarios unchanged, and 68 total scenarios.

The original ABI, exact arithmetic (including all tick coefficients), initialization, ERC-20, event-schema table, error/precedence, absent-behavior and external-dependency sections are unchanged. C1/C2 and fee explanatory paragraphs are directly integrated rather than external normative errata. Parts I-III, section numbering and numeric cross-references are retained. No implementation, tests/builds, Git, new source retrieval or legal analysis was performed.

## Advisory

All four original drafting contributions settled before this draft was written. Each same original task was continued exactly once for the pinned-draft-only advisory pass. Only the authorized raw-file shasum check and reads of that pinned draft are permitted to members. Feedback must be inline-only; coordinator publication is separate. Feedback and resolution remain pending.

