# Verifier attempts and tool limits

Session/tool summaries below are not wire bytes.

- No producer, frozen input, project source/config or existing sealed artifact was edited. Writes are only under verification/.
- First five syntax children exited0. Two unused imports were removed after explicit LSP hints; a distinct final-validation label and expected command count were added. Final five syntax children exited0 before the one live observer.
- Explicit older-route comparisons were subsequently added to proof.mjs. That final proof actually executed once with exit 0 and is bound by proof-01.command.json. Observer never imported it and was not rerun.
- One read-only eval metadata display referenced undefined local E; a later report template referenced undefined SOURCE. Neither started an RPC, child or file write. The metadata was displayed with a literal address and the report was generated with the defined path.
- Some large archive displays were truncated. Complete raw-file reads and parsed JSON, not display excerpts, supplied source/input/ABI/raw checks. Focused later displays inspected selected bindings and implementations.
- Explicit fresh diagnostics were clean for intake/observe. Later fresh diagnostics for proof/record/finalize timed out and are not counted as passes. Actual Node syntax and Bun behavioral execution are the script checks; no whole-project check, install or configuration workaround was run.
- One observer completed 268 reads at block 113279837 with four exact retained source errors. There were no retries/provider changes, phase29 actions, traces/ranges, Forge/fullsuite, signing or live writes.

- The first report publication call used the wrong apply_patch argument key and was rejected before any write; the corrected call uses input.

