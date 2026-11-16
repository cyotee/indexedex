# Preserved development failures

No genuine SUT defect was established. All source corrections were confined to
the newly added tests/infrastructure. No old test or production assertion was
changed, skipped or suppressed.

1. Initial diagnostics found the imported alias `Receipt` colliding with
   `StdCheatsSafe.Receipt`. The new files now use `MigrationReceipt`. This was
   a compile-time harness defect, not a runtime result.
2. `native-01.log`: `NotOperator(handler)` during the deterministic market
   prelude. An external `parent.hook()` argument evaluation consumed the
   one-shot owner prank before the fee-oracle call. The hook address is now
   read before setting the prank. No authority was granted or fabricated.
3. `native-02.log`: the deterministic cliff/activation witness passed, but
   invariant discovery failed with `targetSelectors address does not have an
   associated contract`, runs 0/calls 0. The artifact-first root filter did
   not emit the handler artifact. The existing repository invariant pattern
   uses explicit `targetInterface`; the new handler is now a concrete build
   root and has that ABI binding. This zero-action run is not counted as
   invariant coverage. `native-03.log` is the first actual 16/8 native pass.
4. The first fork shell launch exited before creating a test log:
   `zsh:export:1: not valid in this context: Support/Code/User/globalStorage/github.copilot-chat/debugCommand:/Applications/Visual`.
   The double-quoted outer shell expanded a PATH containing spaces. Passing
   the login-shell command as one literal single-quoted argument fixed it.
   No provider or environment source was changed.
5. `legacy-01.log` and `legacy-donation-counterexample-01.log`: the first
   recovery model incorrectly classified all initial parent DTF as protected.
   It asserted that a donation's parent debit could not exceed its selected
   recovery amount. Actual debit 35695137914655 exceeded selected recovery
   35695096910496 by 41004159 native18 units.

   The actual fixture had exactly 1e18 separately booked, protected DTF,
   plus 90371709 spendable protocol-residual DTF from the prior paid reserve
   operation. `UniswapV4DetfMigrationPolicy._beginBudget` subtracts that
   residual from the operation floor; `_donateRecovery` additionally releases
   only the selected recovery. Thus old residual is intentionally spendable,
   not a fresh recovery or protected donation. The new model now records
   these domains separately: `spent <= selected + previousResidual`, exact
   next residual, unchanged protected 1e18, and exact recovery debit. The
   original smaller bound was not product law. No SUT guard was weakened.
   The same successful donation sequence passes in `legacy-02.log` and the
   complete final forks. The earlier files remain named and retained as
   harness counterexamples, not production vulnerabilities.
6. `cleanup.log` stopped at the first new-file whitespace command because
   `git diff --no-index --check /dev/null <new-file>` returned 1 with empty
   output for an added file. The final cleanup records each such exit and
   requires both exit <=1 and empty diagnostic output, while tracked/index
   comparisons still require exit 0. `cleanup-final.log` is the completed
   cleanup gate; the original partial log remains preserved.

Final LSP results are in `execution-evidence.json`. Six files have fresh
no-diagnostic results; two native files timed out waiting for fresh editor
diagnostics. All compile and execute successfully with Solar. JSON Biome
diagnostics are unavailable because Biome is not installed. Evidence JSON was
parsed directly; nothing was installed or configured.

The nested fork-task attempt was refused by the worker nesting limit. A
message to `parent` was also refused because that task handle is not exposed.
No delegated task or delivery is pending. These are tool-routing failures,
not omitted runtime evidence.

Reproduction recipes and all final expanded compiler/test commands are in
`execution-evidence.json`; each raw log also retains the actual artifact-first
commands. The old failures can be reconstructed from the precise harness
differences above. Final invariant seeds are 0x2401 and 0x2402. No final
invariant counterexample exists: each executed 128 calls without unexpected
revert or discard, with fail-on-revert enabled.
