# Task 13 repair attempt 1

Disposition: product failure remains unresolved; task 13 is incomplete. The required operator command remains exit 1 with 240 passed and 1 failed. No build, test, recorder, RPC or rehearsal was rerun.

## Approved-bytecode investigation

The unchanged test at scripts/recovery/dtf-migration/claimed-sy-witness.test.ts:92 compares deployed runtime bytecode to its imported claimWitnessCodeHash. Following that import to claimed-sy-witness.ts:11 gives the full existing expected value:

0x4ae06bcb278766df6529bcd60e05453fee6c853f6536b9f18d2a4d0dac8fd899

The current artifact hashes to 0x33a0fe038a5d441aa3d9fe48b841bcfc0d0f00f0b085e44b9c41b9b0a7aab2bc. Its metadata source hash matches the current Solidity source, with Solar 0.8.38 commit e7a91fc7, optimizer enabled/runs 1, Osaka EVM and IPFS metadata. These observations reproduce the existing inequality locally; they do not establish why the approved pin was originally different.

The retained task-7 witness-build.log records the artifact helper rejecting the witness script as having no selected artifact build roots, exit 2. witness-build-2.log records a direct Solar build of the witness source, exit 0; the retained operator/dependent checks still failed the pin comparison. The source comment specifies Solar and optimizer_runs=1 but supplies no complete approved alternate compiler input or settings bound to the expected hash. Two complete historical claimed-SY compiler audits were parsed beyond grep prefix limits; neither contained a witness or expected-pin record. The current historical source copies are not treated as authority for an unrecorded alternate build.

No reproducible approved-bytecode recipe matching the existing pin was established from this bounded evidence. The branch is stopped as requested. This is not a claim that a matching build is impossible. No settings sweep, compiler substitution, source rewrite, artifact substitution, pin retune, or test edit was attempted. approved-bytecode-investigation.json retains source hashes, exact build-log quotations, metadata, search limits and the claim correction derivation.

## Additive command provenance

command-provenance.json quotes the existing exact argv, code and signal from sidecars for the production build, full hermetic test, all-K fork helper, operator typecheck and full operator tests. Every row hashes the existing raw log, sidecar and recorder log, and quotes the corroborating CHECK_END line. The outer fork command is distinguished from the inner Forge commands. Shell invocations remain shell argv; no unrecorded expanded child argv is asserted.

For the helper typecheck, the new record quotes the command string at invocation-inventory.json /commands/operator/2 and the separate HELPER_TYPECHECK_EXIT=0 line. The empty original helper stdout log remains empty. A contemporaneous native argv receipt is absent, and strict original raw-log argv/exit acceptance remains unmet. This supplement binds the existing separate records; it does not create historical stdout or claim a new execution. All original numbered logs, sidecars, reports, verifier files and the original evidence index remain unchanged.

## Claim preservation and correction

The original task-13-done.json was copied before replacement to .omo/ulw-execute/dtf-conformance/task-13-done-attempt-1.json. Both original bytes and the copy are 8737 bytes with SHA-256 d73967ecccfc8a498c9322464bd37e2ddc9ee4c56630aaa5efb07885ac644cbd. The original expectedPin transcription omitted f653. The replacement uses the value obtained from the actual test import and its source definition, without changing either file. The claim remains completed:false and lists met and unmet items separately.

## Met

- Original claim archived byte-for-byte before replacement.
- Existing command argv/exit receipts quoted and bound in an additive provenance record.
- Expected-pin claim transcription corrected from the unchanged test/source relationship.
- Bounded approved-bytecode investigation recorded, with no speculative recipe presented as established.
- Original passing build/hermetic/fork counts and the failing operator result remain qualified historical evidence.

## Unmet

- Product repair and required full operator exit 0: the hash equality still fails, with no approved matching build recipe established.
- Strict historical raw-log command-bearing provenance: absent invocation headers were not manufactured; the helper still lacks a contemporaneous native argv receipt.
- Task 10 complete rehearsal and dependent task 12 real portable owner-purchase/donation lifecycle proofs: absent and not substituted by synthetic receipts. The task-10 donor block concerns admissible evidence bound through its authority bundle, not global scarcity.
- Task 13 conjunctive acceptance. A still-red operator command remains incomplete.

No plan checkbox change, commit, delegation, public transaction, financial allocation, task-10 rehearsal, witness-pin change, test weakening, or artifact write occurred. Biome LSP remains unavailable; local JSON parsing, hash comparisons and receipt joins provide the evidence checks.
