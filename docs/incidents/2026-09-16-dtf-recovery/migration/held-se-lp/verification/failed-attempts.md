# Independent verification attempts

The required build, complete specs/forks, both stages, strict operator types,
single operator-test invocation, fresh pinned CLI and raw observer all passed
on their first independent executions. Expected signed reverts are retained
operations, not failed rehearsals.

The first owned audit passed strict types and then exited 1 at
`raw-checks.ts:164`, comparing the decoded instance arguments with the original
manifest. Ethers `Result.toObject(true)` displayed empty ABI arrays as `{}`,
where the original manifest correctly contained `[]`. The assertion was:
`AssertionError: Expected values to be strictly equal`, operator `strictEqual`,
code `ERR_ASSERTION`. Differing fields were `bondRoutes`, `burnRoutes`,
`donateRoutes`, `mintRoutes`, and `openingPairPerDetfWad`. All other displayed
fields matched. `audit-01.json` remains the empty stdout of that failed run.
The complete terminal failure is retained in session `bash_9`.

Only the owned probe changed: the replacement compares complete
`encodeFunctionData("deployVault", [originalManifest.deployment])` bytes to the
actual signed deployment calldata. This preserves empty arrays and checks all
arguments without display normalization. No candidate source, producer
evidence, transaction, or raw witness was changed or replayed.

Initial process inspection used `ps` on the already absent producer PID41253
and consequently returned exit1 with no output; the later explicit conditional
records `RECORDED_PRODUCER_PID_ABSENT`. No listener existed before this verifier
started its own fresh node.

Bash LSP is unavailable (`bash-language-server` not installed). No installation
or configuration change is authorized. Shell syntax is checked by `/bin/zsh -n`.
Producer checksum, stale-stage, observer/input-capture, metadata and shell
failures remain untouched in the producer's sealed `failed-attempts.md`.
