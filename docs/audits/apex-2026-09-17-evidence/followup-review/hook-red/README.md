# Hook regression red evidence

These are **reconstructed pre-review accounting sources**, not an original saved source snapshot. Only this review's native-custody availability and identity-book additions were reversed; earlier dirty D60 changes were retained. `reconstruction-manifest.json` records current fixed and reconstructed SHA-256 values; original pre-edit file hashes are unavailable. The test files are unchanged copies of the current fixed-tree regressions.

The isolated checkout is `/tmp/apex-review-accounting-red-run`. Shared checkout sources, artifacts and cache were not modified. Separate artifact/cache file inodes are recorded in `artifact-isolation.json`.

Both production artifact compilation (388 files) and test compilation (120 files) succeeded. The initial sandboxed invocation then stopped in Foundry's macOS system-proxy/reqwest initialization with `Attempted to create a NULL object`, before test execution. The exact generated test command was retried outside the sandbox; compilation was skipped because those artifacts were already rebuilt.

Final result: **6 suites; 9 tests failed; 0 passed; exit 1**, as required for red regression evidence. `summary.json` lists each named assertion and original failure output. No RPC or live-chain operation was requested.

- `command.txt` / `run.json`: full artifact rebuild plus test selection.
- `hook-accounting-red.log`: successful compiler output and initial environment panic.
- `retry-command.txt` / `retry-run.json`: exact retry command and completion.
- `hook-accounting-red-unsandboxed.log`: final executed regression evidence.
- `reconstruct.py`, `run.py`, `retry.py`, `summarize.py`: reconstruction and execution scripts.
