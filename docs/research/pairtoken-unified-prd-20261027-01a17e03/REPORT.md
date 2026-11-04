# Unified Pair Token PRD council report

## Result

Published one complete working PRD at handoff/PRD.md, identity pairtoken-unified-prd-r1. It replaces the old requirements-plus-proposed-errata handoff as the document to work from, without editing those archives. No companion report is needed to understand its requirements.

Final raw-file SHA-256: 1824df69b7f64cc15252a7ae877d3b3f762773db5bfc4f091591eb1af8a7f6d2.

## Participation

Coordinator: invoking gpt-6.1-sol, not an additional member vote. Owner/root: 01a17e03-97a1-7db4-a05a-162ee50c6ff4. Existing ordinary council-member sessions were continued under the same Native-admitted providers/models. Initial drafting contributions and advisory feedback are preserved independently under members/.

| Member | Native resolved route | Task | Drafting contribution | Advisory disposition |
| --- | --- | --- | --- | --- |
| Astra | chatgpt-subscription/gpt-6-astra:high, high | st_01a17e09 | Completed | Approve with one Low summary concern, resolved |
| Grok | xai/grok-4.7:xhigh, xhigh | st_01a17e0a | Completed | Approve |
| MiniMax | minimax/MiniMax-M3 | st_01a17e0b | Completed | Approve with four narrow editorial/identity concerns, resolved |
| Kimi | kimi-coding/k3.1-pro:high, high | st_01a17e0c | Completed | Approve |

All four ran in process mode. Provider-internal attestation and MiniMax adaptive-effort telemetry are unavailable; configured adaptive behavior and route admission were previously verified in this session. No model substitution, additional member, missing feedback treated as approval, or second advisory round occurred. All feedback was inline-only after exact raw-file hash verification and pinned-file-only reading, with originals preserved.

## Content and resolution

The complete original specification is carried forward, not summarized: 175 original defined IDs and all 58 original scenarios, exact ABI/constants/math/coefficient tables, operation/check ordering, events/errors, non-goals and dependency limits. C1 native/ERC-20 receipt/event terminology, C2 reached idle-pair read order, native-zap consistency, and explicit uncapped-fee consequence are integrated directly. PT-CONFORM-03 and ten new acceptance scenarios make the evidence and clarification cases explicit.

The final has 186 defined IDs and 68 scenarios. Astra's callback-summary correction and MiniMax's addition-inventory, final-state, normative-scope and mapping-precedence corrections are integrated. Literal self-embedding of the final full-file digest was not adopted; the computed digest is recorded externally as optional integrity metadata. See coordinator/resolution.md for every concern and its disposition.

## Limits

This is a source-informed, council-authored documentation consolidation. It does not implement the Pair Token or an IndexedEx adaptation, prove runtime equivalence, fill unsupplied dependency internals, authorize deployment, or certify legal clearance/source nonexposure. No project tests/builds or new source research were performed. Final edits are coordinator resolutions after review; the revised final is not described as a newly reviewed draft.

