# Astra original — REQ-03 execution confirmation

**Date:** 2026-10-15. **Verdict: source matches but run not recorded.**

The three implementation edits match the current consolidated plan. I could not confirm complete execution because I found no relevant execution report or recorded Forge pass for the new observation test and both required suites. The scanner's generated site list exists and includes both required example files, but does not record which invocation produced it or the required `--check` exit status.

This is an independent source/evidence review, not a test run. No peer notes were read. No shell, Forge, deployment, or delegation was used. The assigned report is the only file written.

## Controlling documents and method

Read in full:

- `docs/reviews/apex-req-03-custody-negatives/REMEDIATION_PRD.plan.md` — 186 lines; controls the exact test name, internal fields, fixture, assertions, tuple order, and command sequence.
- Its controlling `REMEDIATION_PRD.md` — 92 lines, including the explicit reference to following the consolidated plan.
- The two named Solidity test files, the scanner script, and `contracts/test/stubs/ReentrantERC20Harness.sol`.

Source compliance is assessed against the consolidated plan, not my earlier draft preferences. In particular, `internal` fields and the plan's helper-based test invocation are the selected requirements.

## Plan-step verification

Abbreviations: `A` = `test/foundry/spec/protocols/staking/rebasingVault/RebasingAwareERC4626_Adversarial.t.sol`; `F` = the sibling `RebasingAwareERC4626_Fuzz.t.sol`; `S` = `scripts/apex_bare_expectrevert_scan.sh`.

| Plan step | Assessment | Current evidence |
|---|---|---|
| Step 1: observation fields and callback | Source matches | `A:26-27` declares exactly the two internal fields. `A:38-42` implements `recordNestedDeposit`, stores the returned reason and attempt flag, and ends normally. No `nestedOk`, callback assertion, or assembly return was added. |
| Step 1: preserve reverting observer and rollback test | Source matches inspected required bodies | `A:31-35` retains the original observer and deliberate revert. `A:137-156` retains the original callback binding, true bubble setting, wrapped-error expectation, and four no-partial-credit checks. These match the pre-edit bodies read earlier in this session; no Git diff or history verification was run. |
| Step 1: new observation test and fixture | Source matches | `A:158-175` has the exact planned name, deployment arguments, funding, callback binding, explicit `setBubbleRevert(true)`, cleared record, preview, baseline reads, and ordinary outer deposit. |
| Step 1: exact completed-settlement/nested-result witness | Source matches | `A:177-184` checks positive preview-matching minted shares, recipient/supply increases, caller/vault asset deltas, attempted callback, and exact `IsLocked` return data. It does not assume shares equal deposited assets. |
| Step 2: total supply on exact-output success | Source matches | `F:101` adds the exact planned assertion/message after the existing success checks at 96-100. The bounds, baseline capture, exact rejection, unchanged-state assertions, and snapshot restoration remain at 57-85. |
| Step 3: roots tuple | Source matches | `S:14-32` contains all seventeen paths in the plan's order, including both Balancer spellings and DETF last. |
| Step 3: retain scanner selection and failure behavior | Source matches | Explicit custody entries remain at `S:33-36`; recursive enumeration and APEX inclusion at 37-41; matching/report output at 42-59; nonzero check behavior at 60-61. |
| Step 4: artifact planning/preparation and both test suites passing | Not recorded in evidence located | Plan `:149-158,163,167,175` requires actual commands/results. No relevant execution report or pass record for the new observation test was found. |
| Step 4: scanner lists the two required files | Output evidence present | `docs/audits/apex-2026-09-17-evidence/bare-expectrevert.txt:127-128` names the custody Accounting test; lines 300-304 name ERC4626 Routes. |
| Step 4: record plain scanner and nonzero `--check` outcomes | Not recorded in evidence located | The generated file has site rows, not invocation metadata or exit status. `S:54-61` writes that same file in both modes. |
| No production or harness edits | No contradiction in inspected source; historical scope unverified | The full harness read retains its existing behavior, particularly `ReentrantERC20Harness.sol:58-79`. An exhaustive working-tree diff was not performed, so no repository-wide unchanged-source attestation is made. |

## Astra-01 — Required execution results are not recorded in the evidence located

- **Severity:** Low; verification/reporting gap, not a demonstrated source or security regression.
- **Requirement:** Plan Step 4 and done-when execution requirement.
- **File and line:** `docs/reviews/apex-req-03-custody-negatives/REMEDIATION_PRD.plan.md:149-167,175`; partial generated evidence at `docs/audits/apex-2026-09-17-evidence/bare-expectrevert.txt:127-128,300-304`.
- **Intended behavior:** Report the named validation commands, toolchain, and results; both test files must pass through the helper, the scanner must list the cited files, and the expected nonzero `--check` exit must be recorded.
- **Observed fact:** The implementation-document directory currently lists only the PRD, plan, and reviewers subdirectory. A direct read of `docs/reviews/apex-req-03-custody-negatives/EXECUTION_REPORT.md` returned file-not-found. Searches of execution/report/validation filenames and relevant logs under `docs/` located no qualifying REQ-03 completion record. Searches for the exact new observation-test name in documentation logs/text returned no matches. Older custody-suite logs were located, but do not establish execution of this new test.
- **Broken requirement / impact class:** The claimed completion lacks the required recorded validation evidence. Present source assertions do not establish a passing runtime result.
- **Inference:** Execution may have occurred outside the evidence located; its absence here does not prove commands were never run. It prevents confirming the complete claim.
- **Fix direction:** In a separately authorized session, provide the actual report/logs if they already exist, or execute the plan's named commands and record their toolchain, outcomes, both suite results, scanner site list, and nonzero check status. Report failures honestly. Do not alter production, weaken assertions, or rewrite newly selected tests to manufacture a clean scanner result.
- **Confidence:** High that source matches and the located site list alone is insufficient; moderate on absence of a report outside the searched locations/naming patterns.

## What the generated scanner file proves—and does not prove

The file exists and contains 317 line-numbered site entries according to the reader. Its contents are consistent with the expanded selection and include the two files specifically required by plan line 163. That is useful evidence of a scanner-output artifact, not merely a source assertion.

However, `S:54-56` writes the same output for the plain scan and for `--check`; the check-only failure occurs later at 60-61. Thus the site file cannot distinguish those invocations, establish their exit status, certify that it was not hand-edited, or prove an artifact refresh/Forge run. It contains no Forge pass record. Existing violations are the expected scope of R3's report, not new defects to repair in this item.

## Search limits and no-defect observations

Documentation searches used execution/report/validation filenames and log/text evidence, plus the named implementation directory and audit evidence tree, without reading reviewer notes. No relevant report was located; this is not a claim that every possible filename or external run record was examined. The missing execution-report path is the only attempted read that failed; all supplied source/plan reads succeeded.

No source mismatch was found in the full adversarial test, fuzz test, scanner, or harness reads. Ownership and the other preserved test controls remain present. No new product work or production fix is proposed. Saved prior logs mentioning the custody suites are not a pass for this implementation, and any future saved log would still not be an independent rerun by this reviewer.

**Final disposition:** confirm the source portion of the completion claim; do not confirm the required executed-and-reported validation portion. There is no unresolved specification question in this review, only missing execution evidence.

I did not run Forge.
