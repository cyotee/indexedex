# MiniMax M3 — REQ-03 execution confirmation original

- **Date:** 2026-10-14
- **Reviewer:** MiniMax M3, independent execution confirmation. No peer notes read. No execution run, shell, or Forge invocation. Source presence verified by line read; `bare-expectrevert.txt` content read; execution-report files searched in `docs/`.
- **Question:** Confirm or refute that the REQ-03 plan at `docs/reviews/apex-req-03-custody-negatives/REMEDIATION_PRD.plan.md` was completed against the current source.
- **Verdict:** **source matches but run not recorded.**

## Sources re-read this round

- `docs/reviews/apex-req-03-custody-negatives/REMEDIATION_PRD.plan.md` (186 lines, full read).
- `test/foundry/spec/protocols/staking/rebasingVault/RebasingAwareERC4626_Adversarial.t.sol` (263 lines, scanned at fields/callbacks/tests; full reads of the relevant sections).
- `test/foundry/spec/protocols/staking/rebasingVault/RebasingAwareERC4626_Fuzz.t.sol` (221 lines, full read of `testFuzz_FUZZ02_exactOutMinimals` at 57-102).
- `scripts/apex_bare_expectrevert_scan.sh` (62 lines, full read).
- `contracts/test/stubs/ReentrantERC20Harness.sol` (86 lines, full read).
- `docs/audits/apex-2026-09-17-evidence/bare-expectrevert.txt` (317 lines, full read).
- `docs/reviews/apex-req-03-custody-negatives/` and its subdirectories searched for an execution report. No `EXEC*` file or saved log was found.

## Step-by-step verification against the plan

### Step 1 — observation test (R1)

The plan requires fields, a callback, and a test added to `RebasingAwareERC4626_Adversarial.t.sol`, leaving `observeNestedDeposit` and `test_ADV03_reentrancyDuringDepositReverts` unchanged.

| Plan requirement | Found at | Status |
|---|---|---|
| Field `bool internal nestedAttempted;` | `RebasingAwareERC4626_Adversarial.t.sol:26` | Present |
| Field `bytes internal nestedReason;` | `RebasingAwareERC4626_Adversarial.t.sol:27` | Present |
| `observeNestedDeposit` unchanged at the plan's pre-edit lines 28-33 | `RebasingAwareERC4626_Adversarial.t.sol:31-36` | Body unchanged; lines shifted by 3 (fields+callback inserted before) |
| Callback `recordNestedDeposit` uses `wrapped.call(abi.encodeCall(IERC4626.deposit, (uint256(1e18), receiver)))`, sets `nestedAttempted = true`, stores `nestedReason`, no `nestedOk` field, no `assembly` return, no assertion, no revert | `RebasingAwareERC4626_Adversarial.t.sol:38-42` | Present, matches the plan's text exactly |
| Observation test `test_ADV03_nestedDepositIsLocked_outerDepositCompletes` uses salt `bytes32(uint256(123))`, `setBubbleRevert(true)`, `nestedAttempted = false` and `delete nestedReason` before the call, captures `expectedShares`, `supplyBefore`, `aliceSharesBefore`, `aliceAssetsBefore`, `vaultAssetsBefore`, performs `wrapped.deposit(depositAssets, alice)`, asserts `minted > 0`, `minted == expectedShares`, `balanceOf(alice) == aliceSharesBefore + minted`, `totalSupply == supplyBefore + minted`, `tok.balanceOf(alice) == aliceAssetsBefore - depositAssets`, `tok.balanceOf(wrapped) == vaultAssetsBefore + depositAssets`, `nestedAttempted == true`, `nestedReason == abi.encodeWithSelector(IReentrancyLock.IsLocked.selector)` | `RebasingAwareERC4626_Adversarial.t.sol:158-185` | All 13 assertions present, in the plan's order, with the plan's messages |
| `test_ADV03_reentrancyDuringDepositReverts` unchanged at the plan's pre-edit lines 128-147 | `RebasingAwareERC4626_Adversarial.t.sol:137-156` | Body unchanged; lines shifted by 9 (fields+callback+test inserted before). `expectRevert(TransferFromFailed)` at line 149, four no-partial-credit assertions at lines 152-155. |
| `bubbleRevert` not set to `false` in the observation test | `RebasingAwareERC4626_Adversarial.t.sol:163` (`tok.setBubbleRevert(true);`) | True is set, as the plan and PRD require |
| `nestedOk` not added | grep `nestedOk` in `RebasingAwareERC4626_Adversarial.t.sol` returns 0 matches | Absent |
| No `assembly` return in the callback | grep `assembly` in `RebasingAwareERC4626_Adversarial.t.sol` returns 0 matches (the harness's `assembly` at `ReentrantERC20Harness.sol:73-75` is in a file the plan does not edit and is not the observation callback) | Absent in the observation callback |

R1 source step: **executed**.

### Step 2 — total supply on exact success (R2)

The plan requires one new assertion in the success half of `testFuzz_FUZZ02_exactOutMinimals` in `RebasingAwareERC4626_Fuzz.t.sol`, after the existing line 100 and before the function's closing brace.

| Plan requirement | Found at | Status |
|---|---|---|
| New `assertEq(IERC20(address(vault)).totalSupply(), supplyBefore + shares, "exact funding increases supply by the quoted shares");` after the existing successful recipient-share assertion at line 100 and before the function's closing brace | `RebasingAwareERC4626_Fuzz.t.sol:101` | Present, exact text matches |
| Existing rejection half (lines 70-84) and existing success-half assertions (lines 96-100) unchanged | `RebasingAwareERC4626_Fuzz.t.sol:70-84, 96-100` | Unchanged; `supplyBefore` captured at line 65 and used at line 101; the new assertion is after the existing `reserveOfToken` assertion at line 100 |
| Fuzz domain and `vm.assume` unchanged | `RebasingAwareERC4626_Fuzz.t.sol:58, 62` | `bound(shares, 1e10, 50e18)` and `vm.assume(need > 1 && need < 1_000e18)` unchanged |

R2 source step: **executed**.

### Step 3 — scanner roots (R3)

The plan requires replacing the `roots` tuple at lines 14-17 with 17 entries, in the listed order, and leaving the `custody` tuple, APEX-marker scan, bare-call regex, report path, and `--check` behavior unchanged.

| Plan requirement | Found at | Status |
|---|---|---|
| 17-entry `roots` tuple in the listed order | `apex_bare_expectrevert_scan.sh:14-32` | 17 entries, in the exact order specified by the plan (lines 121-138 of the plan) |
| `custody` tuple unchanged | `apex_bare_expectrevert_scan.sh:33-36` | Unchanged: the two named custody files at lines 34-35, covered by the new `protocols/staking/rebasingVault` root at line 19 |
| APEX-marker scan unchanged | `apex_bare_expectrevert_scan.sh:39-41` | Unchanged: same `rglob("*.sol")` and same `APEX` regex |
| Bare-call regex unchanged | `apex_bare_expectrevert_scan.sh:44` | Unchanged: `re.compile(r"\bvm\s*\.\s*expectRevert\s*\(\s*\)")` |
| Report path unchanged | `apex_bare_expectrevert_scan.sh:54-56` | Unchanged: `docs/audits/apex-2026-09-17-evidence/bare-expectrevert.txt` |
| `--check` exit behavior unchanged | `apex_bare_expectrevert_scan.sh:60-61` | Unchanged: `raise SystemExit(1)` when sites exist and `--check` was passed |
| No second selection list or external inventory file | `apex_bare_expectrevert_scan.sh:14-32` | Only the existing `roots` tuple is extended |
| No directories added or dropped beyond the plan list | `apex_bare_expectrevert_scan.sh:14-32` | Tuple matches the plan's 17 entries exactly |
| No sorting of the tuple | `apex_bare_expectrevert_scan.sh:14-32` | Order matches the plan's listed order, not alphabetical |

R3 source step: **executed**.

### Harness

The plan says "Do not edit `contracts/test/stubs/ReentrantERC20Harness.sol`."

| Plan requirement | Found at | Status |
|---|---|---|
| Harness `setReenter`, `setBubbleRevert`, `_callback` unchanged | `ReentrantERC20Harness.sol:33, 42, 68-79` | All three present with the same signatures and bodies as the prior review reads. The `assembly` at line 73-75 is in the harness's `_callback` (unchanged from the prior state), not in the observation callback. |

Harness: **unchanged** as required.

## Run evidence

The plan's Step 4 (commands a later session runs) requires:
1. `git diff --check` and `bash -n scripts/apex_bare_expectrevert_scan.sh` (static checks).
2. `python3 scripts/forge-artifacts.py plan` and `python3 scripts/forge-artifacts.py test` (artifact build and test execution).
3. `bash scripts/apex_bare_expectrevert_scan.sh` and `bash scripts/apex_bare_expectrevert_scan.sh --check` (scanner run).

### Scanner run — recorded as a generated output file

The file `docs/audits/apex-2026-09-17-evidence/bare-expectrevert.txt` exists (317 lines). It is the scanner's output file (line 54-56 of the script writes to it). The plan requires the scanner report to list sites in:
- `test/foundry/spec/vaults/standard/erc4626/ERC4626StandardExchange_Routes.t.sol`
- `test/foundry/spec/protocols/staking/rebasingVault/RebasingAwareERC4626_Accounting.t.sol`

Both files appear in the output:
- `ERC4626StandardExchange_Routes.t.sol:332, 335, 383, 409, 559` — 5 sites, lines 300-304 of the output.
- `RebasingAwareERC4626_Accounting.t.sol:131, 143` — 2 sites, lines 127-128 of the output.

This confirms the scanner was run with the updated `roots` tuple (the 15 new directories were included). The plan's "the plain scanner run must list a site in [those two files]" requirement is satisfied by the file's content.

The `bare-expectrevert.txt` is a generated output, not a command log. It does not record the command that produced it, the exit status, the toolchain, or the timestamp. The plan says "Report the commands actually run, the toolchain, and every result" — the file alone does not constitute a report. A present scanner output is not a recorded scanner run.

### Forge pass — NOT recorded

The plan requires running `python3 scripts/forge-artifacts.py test ... -- -vv` (or equivalent) on the two test files, and recording the result. A recorded result would be a log file, execution report, or test result summary.

Searched:
- `docs/reviews/apex-req-03-custody-negatives/` — no `EXEC*` file, no `evidence/` subdirectory, no saved log.
- `docs/reviews/apex-req-03-custody-negatives/reviewers/` — 28 reviewer files, no execution log.
- `docs/reviews/apex-req-03-execution-confirmation/` — `reviewers/` with 3 reviewer originals (Astra, Grok, Kimi); no execution evidence.
- `docs/audits/apex-2026-09-17-evidence/` — `bare-expectrevert.txt` (scanner output); no test logs.

There is **no record of a Forge test run** on the two test files. The plan's Step 4 explicitly requires:
- "The helper's `test` action must pass both test files." — not recorded.
- "Report the commands actually run, the toolchain, and every result. A present assertion is not a pass until that run is reported." — not recorded.

The `bare-expectrevert.txt` records that the scanner was run; it does not record that the test files passed. A saved log, if found, is not an independent rerun — the user notes that. No saved log was found.

## Verdict

**source matches but run not recorded.**

- Source: all three plan steps (R1 fields/callback/test, R2 total-supply assertion, R3 scanner roots) are present in the current source. The existing rollback test, rejection half, harness, custody tuple, APEX-marker scan, bare-call regex, report path, and `--check` behavior are unchanged as the plan requires. No `nestedOk` field, no `assembly` return in the observation callback, no `bubbleRevert = false`, no production change, no harness change.
- Scanner run: the generated `bare-expectrevert.txt` shows the two cited escape files were selected by the updated `roots` tuple. This is evidence the scanner was run with the updated selection rule. The run is recorded as an output file only, not as a command log.
- Forge pass: not recorded. No execution report, no saved log, no test result file. The plan's Step 4 static checks (`git diff --check`, `bash -n scripts/apex_bare_expectrevert_scan.sh`), artifact plan/test runs, and result reporting are not documented.

The claimed completion of the plan is partially verified: the source-side edits are confirmed; the execution side (Forge test pass) is unverified because no run report exists. The agent's claim that the plan was completed is **true for source edits, unconfirmed for execution**.

## Severity-tagged gaps (if any)

The plan's done-when list requires both source edits and recorded run results. Source edits are present. Run results are not recorded. This is a process gap, not a code defect: the test files were edited, the scanner was run, but neither result was reported in a way the plan asked for. Severity: Low — the edits are verifiable by source read; the run is missing only as a report. Fix direction: a later session runs the plan's Step 4 commands, captures stdout/stderr to a saved log, and writes an execution report recording the test pass counts, the scanner's full output, and the `--check` exit status. The report belongs in `docs/reviews/apex-req-03-custody-negatives/` (for example, `EXECUTION_REPORT.md` and `evidence/forge-test.log`, `evidence/scanner.log`).

I did not run Forge.