# Retained attempts and tooling qualifications

No runtime or source-admission failure was hidden. The fresh18571 CLI
completed on its first attempt. Its expected source reverts remain actual
mined receipts and are not failed rehearsal attempts.

| Attempt | Actual result | Correction and retained evidence |
| --- | --- | --- |
| Initial evidence patch adapter | `input is required`; no write | Used the actual `input` parameter; baseline was then created |
| Independent operator track | Subagent nesting limit reached | No child launched; all work remained in this session |
| Initial source/report discovery | Some guessed paths did not exist | Located and read actual phase19 earlier-liquid and phase20 source paths; no guessed file was accepted |
| Build monitor with14400000ms | Tool rejected a timeout above3600000ms; no process launched | Started the warm build with a persistent monitor and no short kill deadline |
| First size inspection | Artifact metadata was already an object, not a JSON string | Measured actual deployed bytecode and read the metadata object directly; no artifact changed |
| Initial specs | E-S literal copied from the brief had an invalid Solidity checksum | Expressed the identical address as `address(bytes20(hex"..."))`; `specs-01.log` retained, complete `specs-02.log` passes |
| First stage helper build | Exit0 but did not refresh concrete script ABI | Explicit Solar build of both stage roots; `stages-01.log` and `stages-02.log` retained |
| Initial operator invocation | 85pass,3fail: new Stage01 tuple missing from stale artifact | Refreshed the actual stage artifacts, without editing tests; final single invocation88pass/0fail. Both logs retained |
| Plain `.raw` input-copy patch | Add-file parser rejected the no-final-newline marker before any write | Captured all30 originals losslessly as base64; decoded original lengths, hashes and newline state checked in the final audit |
| Eval audit launch | Worker does not support `process.chdir()`; audit did not start | Ran the same read-only auditor as a worktree-local Bun CLI |
| Combined strict/audit wrapper | Compiler output was empty; an erroneously encoded shell test exited1 before the audit | `probe-types-02.log` retained; direct audit subsequently exited0 into `audit-01.json`; a separate final strict typecheck supplies an explicit exit gate. No source change |
| Summary-only data access | A helper name was not exposed across eval cells; later ED row lookup used the ER nesting shape; a guessed WS terminal filename did not exist | Corrected in-memory lookups only. No source, runtime or earlier evidence changed; the complete raw audit had already passed |
| Git production diff | PTY opened a pager | Sent `q`, waited for exit0, then used `--no-pager`; no Git write |

Fresh Solidity LSP diagnostics sometimes timed out. Biome is not installed
for JSON LSP diagnostics. No installation or configuration change was made.
The actual Solar builds/tests and strict TypeScript compiler results are
retained instead; compiler/lint warnings were not suppressed.

The input-copy failure made no partial `captured-inputs/` directory. Original
JSON bytes without a terminal newline were never normalized and called raw.
The accepted captures explicitly declare their lossless base64 encoding.
This run has zero prepared-input drift and zero offline ABI reconstruction.
The accepted parent evidence's distinct metadata/reconstruction qualifications
remain unchanged.

The combined-wrapper typo was a shell-control error after the compiler,
not a raw audit failure. The final `audit-01.json` is the unmodified stdout
of the successful direct audit, not a hand-edited verdict.
