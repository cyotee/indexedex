# Remediation PRD — REQ-03 plan execution confirmation

- **Status:** DRAFT
- **Date:** 2026-10-15
- **Review target:** Current IndexedEx working tree, checked against `docs/reviews/apex-req-03-custody-negatives/REMEDIATION_PRD.plan.md`.
- **Controlling specification:** `docs/reviews/apex-req-03-custody-negatives/REMEDIATION_PRD.md`. The plan wins only where it does not conflict with that PRD. No conflict was found in the inspected source.
- **Audit report:** None supplied.
- **Astra participation:** Substantive first pass and substantive cross-review. Session `ses_ec412bcc2ffejKLo7nuoEAqbV0`. Not censored. No resubmission. Cap not used.
- **Other reviewers:** Grok `ses_ec4128917ffeeVds3Y2p7xrVjp`. MiniMax M3 `ses_ec41255ceffeVhrySLQe8hwwMC`. Kimi K3 is the labeled replacement `ses_ec3d04e91ffeJa0is24e2jZv06`. It does not recall `ses_ec41220c2ffeqs5Eha7fPsd54B`. All four cross-reviews completed.
- **Execution evidence:** No reviewer ran Forge in this confirmation. No execution report for this plan was found. A generated scanner file is not a recorded `--check` exit.

Writing this file does not authorize code, test, configuration, or deployment changes.

## Required outcome

None for new source work. The 2026-10-15 log confirmation found that the preserved implementation logs satisfy the plan. REQ-03-X1 is closed by that record. This confirmation did not rerun Forge. The saved log is not an independent rerun. Do not rewrite newly selected tests.

## What matches

Coordinator re-read supports the council on these points. Runtime was not rerun here.

- `recordNestedDeposit` stores `nestedAttempted` and `nestedReason` and returns without an assertion or a revert (`RebasingAwareERC4626_Adversarial.t.sol:26-27`, `:38-42`).
- `test_ADV03_nestedDepositIsLocked_outerDepositCompletes` uses salt `123`, offset `10`, `setBubbleRevert(true)`, the previewed outer deposit, and the surviving `IReentrancyLock.IsLocked` record (`:158-185`). It does not assert recipient shares equal `10e18`.
- `observeNestedDeposit` and `test_ADV03_reentrancyDuringDepositReverts` still expect the wrapped `TransferFromFailed` path and the four no-partial-credit assertions (`:31-36`, `:137-156`).
- The fuzz success half asserts total supply equals the captured supply plus the requested shares (`RebasingAwareERC4626_Fuzz.t.sol:101`). The rejection half and the existing success assertions remain.
- The scanner `roots` tuple is the seventeen listed paths, in the plan's order (`scripts/apex_bare_expectrevert_scan.sh:14-32`). The `custody` tuple and the APEX-marker scan remain.
- The inspected harness still returns when the callback succeeds (`ReentrantERC20Harness.sol:68-71`). This confirmation did not run a repository-wide diff, so it does not attest that every uninspected file is unchanged.

## Closed — REQ-03-X1

The missing-run finding below was the state before the logs were preserved. The 2026-10-15 log round, with four first passes and four cross-reviews, accepts `docs/reviews/apex-req-03-custody-negatives/EXECUTION_REPORT.md` and the files under `evidence/` as satisfaction of Step 4. The first helper invocation crashed before tests. The recorded retry passed 25 tests, 0 failed. The scanner `--check` exit 1 is recorded. Nine sites were already selected and 308 were added. That split does not block closure.

## REQ-03-X1 — The plan's run was not recorded

- **Severity:** Medium. Astra's cross-review keeps this Low: missing proof is not proof the tests failed. Grok, MiniMax's cross-review, and Kimi keep Medium because the plan makes the reported run a done-when condition, and the observation record surviving a finished deposit is a runtime property. This draft uses Medium for the closure claim. It is not a demonstrated source defect.
- **File and line:** `docs/reviews/apex-req-03-custody-negatives/REMEDIATION_PRD.plan.md:149-167` and `:175`. No `EXECUTION_REPORT.md` was found beside that plan.
- **Intended behavior:** The plan. Report the helper `plan` and `test` commands for the two test files, the toolchain, both suite results, the scanner site list, and the nonzero `--check` exit.
- **Broken requirement or invariant:** The completion claim includes Step 4. No located report records those commands or a Forge pass of `test_ADV03_nestedDepositIsLocked_outerDepositCompletes`.
- **Acceptance criteria:**
  - A separately authorized session runs the plan's Step 4 commands and writes the commands, toolchain, and results beside the plan.
  - Both test files pass through `scripts/forge-artifacts.py test` with the two named `--test-root` values and no production path.
  - The plain scanner output lists a site in `ERC4626StandardExchange_Routes.t.sol` and a site in `RebasingAwareERC4626_Accounting.t.sol`.
  - The `--check` exit is recorded. A nonzero exit caused only by existing bare `expectRevert()` calls in newly selected directories is the expected end state. It is not repaired in this item.
  - If a test fails, the report says so and does not change production, the harness, or a selected test to hide the failure.
- **Non-goals:** Do not rewrite newly selected tests. Do not drop a root. Do not hand-edit `docs/audits/apex-2026-09-17-evidence/bare-expectrevert.txt`. Do not treat this confirmation as a Forge rerun.

## Scanner file

`docs/audits/apex-2026-09-17-evidence/bare-expectrevert.txt` lists the two cited files (`:127-128` and `:300-304`). The script writes that same file for both the plain scan and `--check` (`scripts/apex_bare_expectrevert_scan.sh:54-61`). The file has no command, toolchain, or exit status. It is consistent with an expanded scan. It is not the recorded `--check` exit the plan requires, and it is not a Forge pass.

## Dissent

- **Severity of the missing run.** Astra: Low. Grok, MiniMax's cross-review, and Kimi: Medium. This draft records Medium for the closure claim and does not treat it as a source mismatch.
- **What the scanner file proves.** MiniMax's first pass said the file confirms the updated scanner ran. Astra, Grok, and Kimi say it cannot identify the invocation or the exit. MiniMax's cross-review agrees it is not a recorded `--check` exit.

## Non-goals

No source repair from this confirmation. No live-instance change. No claim that this confirmation reran Forge. Do not mark REQ-03 closed in `docs/reviews/apex-remediation-application-2026-10-14/REMEDIATION_PRD.md` until REQ-03-X1 is recorded.
