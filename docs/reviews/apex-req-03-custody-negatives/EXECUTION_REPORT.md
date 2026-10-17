# REQ-03 execution report

Step 4 was executed on 2026-10-15 under the user's instruction to execute [the plan](./REMEDIATION_PRD.plan.md). Both selected suites passed: **25 tests, 0 failures, 0 skipped**. The scanner's plain invocation exited **0** and its `--check` invocation exited **1**, reporting 317 existing bare revert expectations. Both required example files appear in the output.

The implementation session initially left the logs and command/exit-status record in `/tmp`, without a repository link. This report corrects that reporting omission identified by [REQ-03-X1](../apex-req-03-execution-confirmation/REMEDIATION_PRD.md). The original logs are now preserved under [`evidence/`](./evidence/validation.txt). These are the actual implementation-session results, not a new Forge run or an independent review. Exit statuses were returned by the command tool and recorded in the [validation record](./evidence/validation.txt); the redirected stdout/stderr logs do not themselves contain process exit statuses.

## Commands and results

Commands ran from the repository root. The helper received no production source argument. Output was redirected to the log files now linked below.

| Command | Exit | Result and evidence |
| --- | --- | --- |
| `git diff --check` | 0 | Passed before testing and on final verification. No output. |
| `bash -n scripts/apex_bare_expectrevert_scan.sh` | 0 | Shell syntax passed. No output. |
| Helper `plan`, with both test roots shown below | 0 | 29 build roots, 218 sources in import closure, 29 runtime artifact IDs. [Log](./evidence/artifact-plan.txt). |
| Helper `test`, with both test roots and `-- -vv` | 250 initially; 0 on retry | Initial invocation compiled both test files successfully, then Forge crashed before tests. Approved retry outside the sandbox passed both suites. [Initial log](./evidence/forge-test.txt), [passing retry](./evidence/forge-test-retry.txt). |
| `bash scripts/apex_bare_expectrevert_scan.sh` | 0 | 317 bare expectations in 3,161 selected files. [Full stdout](./evidence/scanner.txt). |
| `bash scripts/apex_bare_expectrevert_scan.sh --check` | 1 | Same 317 sites; the nonzero exit was preserved. [Full stdout](./evidence/scanner-check.txt). |

The exact helper commands were:

```bash
python3 scripts/forge-artifacts.py plan \
  --test-root test/foundry/spec/protocols/staking/rebasingVault/RebasingAwareERC4626_Adversarial.t.sol \
  --test-root test/foundry/spec/protocols/staking/rebasingVault/RebasingAwareERC4626_Fuzz.t.sol
python3 scripts/forge-artifacts.py test \
  --test-root test/foundry/spec/protocols/staking/rebasingVault/RebasingAwareERC4626_Adversarial.t.sol \
  --test-root test/foundry/spec/protocols/staking/rebasingVault/RebasingAwareERC4626_Fuzz.t.sol \
  -- -vv
```

## Toolchain and test outcome

- Forge **1.5.1-stable**, commit `b0a9dd9ceda36f63e2326ce530c10e6916f4b8a2`.
- Solc **0.8.35**, optimizer enabled with one run, `via_ir = false`.
- Default Foundry profile; `FOUNDRY_PROFILE` unset. Fuzz tests used **16 runs each**.
- Python **3.10.5**; GNU Bash **3.2.57(1)-release**.
- Existing populated `out/` and `cache_forge/` retained. No profile or configured source/test path changes.

The initial helper invocation found runtime artifacts current, compiled the two test files successfully in 14.72 seconds, and then Forge panicked in macOS `system-configuration` at `dynamic_store.rs:154`: `Attempted to create a NULL object.` No test outcome was claimed from that invocation. The identical command was retried with approved permission outside the sandbox; both build and test compilation reused the current cache.

The passing retry ran 13 adversarial tests and 12 fuzz tests. It includes `test_ADV03_nestedDepositIsLocked_outerDepositCompletes`, the unchanged `test_ADV03_reentrancyDuringDepositReverts`, and `testFuzz_FUZZ02_exactOutMinimals` with its new total-supply assertion.

## Scanner outcome and discrepancy

Both scanner invocations produced identical stdout. The script regenerated the [canonical site list](../../audits/apex-2026-09-17-evidence/bare-expectrevert.txt); it was not hand-edited. The preserved logs above include the complete site list and the summary count.

The required sites are:

- `test/foundry/spec/vaults/standard/erc4626/ERC4626StandardExchange_Routes.t.sol`: lines **332, 335, 383, 409, 559**.
- `test/foundry/spec/protocols/staking/rebasingVault/RebasingAwareERC4626_Accounting.t.sol`: lines **131, 143**.

There is one difference from the plan's anticipated baseline: **9** bare assertions were already selected by the original scanner; expanding the roots added **308**, for **317** total. A supplemental verification initially assumed zero original findings and failed that assumption. The corrected comparison confirmed all 9 old sites remain selected, and every file containing a reported site is unchanged from HEAD. Thus the check's nonzero exit is due to existing bare calls, but not exclusively calls in newly selected directories. No roots, regex, tests, or exit behavior were changed to force a clean result.

## Scope verification

The new callback and observation test match the plan. The original observer and rollback test remain byte-for-byte unchanged. The fuzz file contains only the required supply assertion addition. All seventeen roots exist in the required order; the scanner edit changes only that tuple. No production or harness edits were made for this task. Unrelated changes already present in the workspace were preserved. This report does not claim the complete repository test suite passed or that the scanner is clean.
