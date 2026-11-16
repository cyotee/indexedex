# Runner verification findings

These are independently observed harness boundaries, not permission to edit
producers or alter migration policy. Exact invocations precede execution in
the corresponding `*.command.json`; raw failures are in `*.stderr.log` and
`*.stdout.log`.

## Output redirection is not portable

- Weighted original exits 1: `Output outside weighted evidence boundary`.
  Source: `scripts/recovery/dtf-migration/phase01/weighted/probe.mjs:18-21`.
- Earlier-CP original exits 1: `Output must be in the owned evidence directory`.
  Source: `scripts/recovery/dtf-migration/phase01/earlier-cp/probe.mjs:42-45`.
- Other-sources original exits 2 and records an UNPROVEN harness result:
  `Output must be inside the owned evidence directory`. Its finally block still
  persists to the rejected output path. The path in this test is authorized
  verification evidence, so no producer was overwritten.
  Source: `scripts/recovery/dtf-migration/phase01/other-sources/probe.mjs:477,619`.
- Attribution has no output-option parser and hardcodes its producer directory
  at `evidence/attribution/witness.mjs:11`; the verification TMPDIR fails its
  line 16 assertion before writes. Running its documented successful invocation
  unchanged would overwrite producer evidence, so that was not done.

The path-only copies permit isolated observation without changing producer files.
The first copy-construction patch added one terminal newline. The initial
`path-only-copy-audit.json` hashes describe the transformed text before that
newline; `receipt-audit.json.copies` records actual executable hashes and verifies
that the extra newline is the only additional change. Transport retries are
separately identified in `transport-retry-audit.json`.

## Report generation is not input admission or readiness

- Float `1.5`, leading-zero `00`, and exponent `1e3` in a declared quantity
  column exit 2, print the exact malformed token, and create no fresh output.
- Duplicate CSV header and unterminated quote exit 1 without output.
- Clean-fingerprint blank/zero control exits 0; exactly the blank is UNKNOWN.
- Clean-fingerprint `quantity_raw=-1` exits 0. The parser intentionally accepts
  signed integers (`reconcile.mjs:11,230`). This is not an unsigned operational
  allocation validator; signed historical gons deltas can be legitimate.
- An unlisted CSV containing `1.5` exits 0: discovery hashes it but does not
  parse it (`reconcile.mjs:964-1009`). Only declared tables receive the numeric
  scan. The report retains UNPROVEN category rows rather than inventing support.
- A valid run followed by malformed input using the same output path exits 2
  but leaves the earlier successful JSON unchanged. `stale-output.json` is
  byte-identical to `malformed-blank-zero.json`; no new `.partial` exists.
  Consumers must bind completion, exit status, input fingerprint and invocation,
  not use file existence as a success signal.
- The first synthetic fixture patch added a terminal blank line after the
  manifest's digest had been calculated. Those original fixture runs faithfully
  report fingerprint drift. `negative-clean` and `blank-zero-clean` independently
  repeat the permissive/UNKNOWN results with matching fingerprints. Original
  fixtures and outputs were retained, not silently repaired.

The real reconciliation is byte-identical to the producer's 1,626,442-byte file.
It still contains two frozen Markdown fingerprint failures and unresolved
provenance. `WROTE` means report creation, not acceptance of issuance inputs.

## PASS token and rollback interpretation

The weighted replay prints `WEIGHTED_PROBE_PASS` while retaining one FAIL and
two UNPROVEN checks. Its `required` list at lines 509-514 selects source
capabilities; it does not gate all required migration behavior or all DTF
harvest checks. The report clearly acknowledges this, so the report is not a
false claim of E1/E2 completion. A consumer using only exit 0 would be wrong.

The attribution counterexample PASS proves a failure of balance-only attribution,
not E2 closure. Wrapper and descendant examples are arithmetic counterexamples,
not deployed nullifier/rejection tests. No actual activation is executed.

Weighted and earlier-CP use Anvil snapshots for case isolation. That reset is
not an EVM transaction rollback. Separately, failed mined transfers/claims do
preserve source state. Other-sources' deliberate outer-revert helper tests a
successful inner source call followed by transaction rollback, but does not
fund a Migration bond or prove user command of an impersonated infrastructure
holder. None of these may be called integrated surrender-plus-bond verification.

Producer cleanup sometimes treats any failed fetch as a closed endpoint.
Independent final cleanup requires TCP ECONNREFUSED, absent recorded PIDs and
ENOENT read-backs for owned runtime directories instead.

## Tooling limits

The first workspace audit failed because Git tried to traverse the linked
`lib/crane` submodule. Its exact error remains in `workspace-before.stderr.log`.
The corrected read-only command uses `--ignore-submodules=all`, fingerprints
tracked files, and records the Crane symlink rather than modifying it.
No Git configuration or submodule change was made.

Fresh diagnostics timed out or reported missing Biome/basedpyright. No packages
were installed into shared dependencies. Executable probe results are runtime
evidence, not a claimed clean static-typecheck or Foundry test run.

The original command wrapper isolated TMPDIR, HOME, npm, Bun-install, XDG and
Foundry caches, but did not explicitly override inherited NODE_COMPILE_CACHE.
The session environment exposed `/var/folders/8f/582y7l_125s9pbmjpdydnk_r0000gn/T/node-compile-cache`.
Whether the five `node --check` calls wrote that shared cache was not measured.
It was not deleted. The wrapper now explicitly isolates Node compile and Bun
transpiler cache paths for future use; completed probe results were not rerun or
relabeled. The final cleanup read-back explicitly isolated both variables.

A concurrently authorized recovery verifier ran the existing cleanup utility
and removed the original verification runtime root before this session's own
cleanup launcher started. `cleanup-attempt-failed.log` preserves the resulting
mkdtemp ENOENT. Recovery artifacts are retained untouched. The original verifier
then independently checked all recorded resources in
`cleanup-independent-readback.json`: 45 PIDs absent, six TCP refusals, 42
directories absent including its fresh final read-back root.
