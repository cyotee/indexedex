# Unified PRD council resolution

Final working document: handoff/PRD.md, identity pairtoken-unified-prd-r1.
Final raw SHA-256: 1824df69b7f64cc15252a7ae877d3b3f762773db5bfc4f091591eb1af8a7f6d2.
Pinned reviewed draft: coordinator/PRD-draft.md, pairtoken-unified-prd-draft-r1.
Pinned raw SHA-256: a0e81c4da3444fb617dab1dfa562579055d69d11367935bdb5406dd6df4b77bd.

All four independent authoring contributions and all four advisory dispositions settled. The coordinator assembled the complete baseline and integrated member-authored changes. Final editorial changes below are coordinator resolutions after the single advisory pass, not a new member-approved draft or an additional review round.

## Drafting integration

See coordinator/integration.md for the complete authorship accounting. Astra, Grok, MiniMax and Kimi independently proposed concrete prose and acceptance cases. All agreed on one new unified identity, preserving all original identifiers and 58 scenarios, direct integration of C1/C2 and the uncapped-fee explanation, unchanged source-equivalent economics, complete in-document dependency limits and no companion errata requirement. Overlapping acceptance proposals were combined into ten uniquely numbered additional cases. All four originals are preserved verbatim, not replaced by advisory feedback.

## Advisory results

| Member | Disposition | Concerns | Resolution |
| --- | --- | --- | --- |
| Astra | Approve with concerns | Low: opening summary overstates that collection/reinvestment occur only at public money-operation checkpoints; manager-authorized unarmed callbacks remain possible | Adopted its replacement. The summary now distinguishes two deposit/two redemption compounding checkpoints and permissionless compound from manager-authorized callback operations under PT-CB-01 through PT-CB-07. No armed-request restriction is implied. |
| Grok | Approve | None | Preserve its approval and static/legal/process limits. |
| Kimi | Approve | None | Preserve its approval and static/legal/process limits. |
| MiniMax | Approve with concerns | Four narrow identity/authority concerns | Resolved individually below. |

### MiniMax C-1: complete addition inventory

Adopted. The opening now explicitly identifies PT-CONFORM-03 as the one new non-acceptance requirement identifier and PT-AC-59 through PT-AC-68 as the ten added scenarios. All original identifiers and PT-AC-01 through PT-AC-58 remain.

### MiniMax C-2: final publication state and integrity closure

Adopted publication-state and identity closure. The handoff no longer says awaiting review or draft-not-final. It identifies its publication state and the retained reviewed draft, and says final wording incorporates coordinator resolutions rather than claiming a newly reviewed final. The original pinned draft remains byte-identical.

The literal request to put the final file's own full-file SHA-256 inside that same file was not adopted. Instead, the actual digest was computed after publication and is recorded here, in coordinator/publication.md and in RUN.md. No self-referential placeholder or altered-file hash is presented as the final digest. This integrity record is optional analyst-side verification metadata; it is not a second normative input or needed to understand the PRD.

### MiniMax C-3: normative identifier space

Adopted the lower-redundancy option. PT-CONFORM-03 now states that tagged PT-* requirements and acceptance scenarios, including subordinate paragraphs and tables, form the complete normative set. Untagged purpose/scope/provenance prose is explanatory and creates no independent behavioral obligation. Tagged requirements govern any summary mismatch. No redundant PT-PRD identifier family is introduced.

### MiniMax C-4: mapping modality

Adopted. PT-CONFORM-02 explicitly points to PT-CONFORM-03 as the mandatory and more complete form of the same mapping/evidence obligation for conformance claims, not a separate weaker alternative. Its planning-input and unknown-dependency rules remain intact. No money-path behavior changes.

## Verification and boundaries

The final must preserve all 175 originally defined IDs (172 numbered plus three BASE IDs), all original 58 acceptance rows, the original ABI/constants/math/coefficient tables, initialization/ERC-20/error/absence/dependency sections, and all route-specific operation checkpoints. The final includes 186 defined IDs and 68 acceptance scenarios. Verification results are recorded separately after publication; those checks are structural/integrity checks, not project tests or runtime proof.

The original r2 remains raw SHA-256 8060c1e3d6ec225f761de647ca29c12536712d1d9188a6600a694d72d44ea848. The previous council and errata archives were not edited. No source retrieval, code implementation, tests/builds, Git, live settings, wallet operation or deployment occurred in this consolidation task. Source-exposure and legal limits remain in the one PRD; no new guarantee or legal conclusion is added.

No advisory concern remains unresolved. No extra round is requested or needed. All member feedback was inline only; the coordinator archived the exact returned text.

