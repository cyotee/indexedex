# F1 evidence-bookkeeping closure

Date: 2026-11-12. **Disposition: confirmed. F1 is closed.**

The additive correction admits the same corrected-source candidate for the
separate nine-file formatting commit. It does not accept an immutable formatting
delivery: D2 in `../format-commit/verification.md` remains unresolved because
the follow-up commit and receipt are absent. No commit is created by this closure.
The original needs-fix reports, including their historical conclusions, remain
unchanged; this additive record closes only their carried F1.

## Exact correction and raw log verification

The complete `report.md` in this directory and
`../format-commit/verification.md`, plus all four additive correction files,
were read. Recursive comparison of the original and replacement validation JSON
finds exactly two changed leaf fields:

| Field | Preserved original | Corrected raw bytes |
| --- | ---: | ---: |
| checks[0].bytes (specs) | 229420 | 269164 |
| checks[1].bytes (forks) | 180237 | 218681 |

The raw replacement text is also exactly the original text with only those two
numeric replacements. Names, summaries, execution authority, exit codes,
diagnostics and all other fields are unchanged. Independent raw reads reproduce:

- `specs.log`: 269164 bytes; SHA-256
  `f6897050e0874ac4b4605a5462740f60fab7083b066923a24dc2804f8075a11b`.
- `forks.log`: 218681 bytes; SHA-256
  `2b97a1c267c97c0591f1e3b4ccf03b4a007956dd48c454a3ff40e0843be78051`.

Decoded UTF-16 code-unit lengths are respectively 229420 and 180237, confirming
the original bookkeeping cause rather than truncated or replaced logs.

## Seals and unchanged candidate binding

The original validation SHA-256 is
`bd2b881003fe1d3e6124f58e4b4bf75d6f88d44fd742ad1ff8a7c0f273bd6b70`;
the original correction seal SHA-256 is
`d0c49aac0d178f589d626a8639ce9790db92abcebc5eb6a287543057a3885934`.
Both equal the additive correction references and prior independent bindings.
All 411 original seal entries were independently rehashed with raw byte lengths;
none is missing or changed. The three additive seal entries match raw sizes and
SHA-256 hashes, and directory membership is exactly those entries plus the seal.
The replacement validation SHA-256 is
`6b933633e858b16e29d47dd5d865b3c584dc8a6e043997133759aac25bfb2609`.
The seal intentionally excludes itself; its raw identity is recorded in supporting
evidence rather than claimed to be self-sealed.

All 40 source paths still match the prior independent audit in raw hash, size
and mode; all ten artifacts and 628 compiled-source raw hashes also match that
audit. Its report and audit-bindings hashes still match its retained closure.
The original EOF-only static proof is reused, not reconstructed as new behavior.
Current HEAD remains `9c227900b280713305d4a1a1d1cdc3d8d273f23d` on
`work/dtf-migration-phase-16-claim-vault`. Current status retains exactly the
nine unstaged source corrections. The index has no staged delta. The current
original-parent-to-working-tree whitespace gate exits 0. All Git invocations
used `GIT_MASTER=1`; their exact commands and outputs are retained in the
supporting JSON.

## Reused verification and limits

The original independent passed source/runtime checks remain applicable because
the candidate inputs and sealed witnesses retain their identities. Reused proof
includes root's 130 specs, 81 forks, 64 operator tests, both operator stages,
strict types and actual fixed18566 CLI execution; the prior independent current
artifact/runtime matches, signed completions and all three interrupted/resumed
canonical receipt comparisons are retained. These are existing reviewed
execution results, not new process exits or a new runtime verification.
No suite, deployment, runtime or receipt-decoder replay was performed.

The original D1 immutable-commit finding and separate D2 delivery finding are not
closed here. Exact legacy deployed-source equivalence remains unproved.
Workstation/archive dependencies, synthetic and unapproved operational inputs,
other source categories, full-category/full-plan/hermetic/portable-full-F3 limits
and the recorded 44,099,850-gas parent deployment versus the historical
32-million limit remain. No target-gas or public-execution acceptance is given.

## Supporting evidence and isolation

`f1-closure-evidence.json` records exact JSON delta, raw log identities, seal
verification, prior-report hashes, candidate binding checks, current Git results
and a preservation baseline for all 1418 pre-existing claim-vault evidence files.
Its SHA-256 is
`10d598360b2f5cd59b764cf64953164e987fa68aa97df698a26637cf7c789e61`.

Only this new closure and its supporting JSON are authored. Existing reports and
original sealed format-correction evidence are preserved. No source edit,
staging, commit, installation, configuration change, held09, retrieval or public
action occurred. No runtime, background process, monitor or subscription was
started; there is no owned operation pending.
JSON LSP diagnostics are unavailable because `biome` is not installed.
No installation or configuration change was attempted; the supporting JSON is
validated by direct parsing and raw hash comparison.

**F1: confirmed and closed. Corrected-source candidate: admitted for the separate
nine-file formatting commit. Immutable formatting delivery: not yet accepted.**
