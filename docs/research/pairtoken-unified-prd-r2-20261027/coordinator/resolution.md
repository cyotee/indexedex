# Coordinator resolution

## Draft

- Draft ID: pairtoken-unified-prd-draft-r2
- Path: docs/research/pairtoken-unified-prd-r2-20261027/coordinator/draft.md
- Raw SHA-256 at advisory send: b8e85f71b0453afafd3f733ba0019b9ae1eaf7d26bc9c3adfaffb25532ffcf96
- Draft bytes changed after review: no

## Advisory dispositions

| Member | Disposition | Concerns |
| --- | --- | --- |
| Astra | support | none |
| Grok | support-with-reservations | G1, delete the undefined gas qualifier |
| MiniMax | support | none blocking; publication-state header noted as a coordinator step |
| Kimi | support | none |

Absence was not treated as approval. No further round was requested or started.

## Concern outcomes

### G1 - adopted in the published file only

The published PRD deletes "subject to EVM call-gas rules" from PT-BAL-05 and PT-BAL-06. The qualifier was not in the authorized sentence and the PRD does not define it. The remaining sentences still require remaining-gas forwarding and reject a 2300-gas stipend. This deletion is a coordinator revision. It is not member-approved text. The pinned draft keeps the qualifier.

### Publication header - coordinator step

The published file states that it is the published working PRD and that final wording deleted the undefined gas qualifier. The requirements body is otherwise the reviewed draft. MiniMax noted this header change and did not ask for a requirements edit.

### Other observations - no change

Astra, Kimi, and MiniMax supported the seven integrations. MiniMax's notes on L1, L3, and the gas qualifier did not request edits. No new acceptance row was added. No requirement identifier was added or removed.

## Published file

- Path: docs/research/pairtoken-unified-prd-r2-20261027/handoff/PRD.md
- Identity: pairtoken-unified-prd-r2
- Raw SHA-256: 088ba325456c1ce4a93cbe0fc9625e1119352dbb8b209455460322b11d052d8d
- r1 was not edited. Its raw SHA-256 remains 1824df69b7f64cc15252a7ae877d3b3f762773db5bfc4f091591eb1af8a7f6d2.
