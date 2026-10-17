# MiniMax M3 — REQ-03 execution cross-review

- **Date:** 2026-10-14
- **Reviewer:** MiniMax M3, one cross-review continuation. No peer original used as authority. No REMEDIATION_PRD.md or code was read or written this round. The three peer originals were re-read. The plan, PRD, source files, and `bare-expectrevert.txt` were re-read in my own original this round.
- **Question:** agree or dissent on (1) source matches, (2) the Forge run is not recorded, (3) `bare-expectrevert.txt` is not a recorded `--check` exit. If you dissent on severity, say Low or Medium and why.

## Verdict

**Agree on all three substantive points.** Source matches, the Forge run is not recorded, and `bare-expectrevert.txt` is not a recorded `--check` exit. **Dissent on severity: I record Medium, the same as Grok and Kimi. I do not agree with Astra's Low.**

## (1) Source matches

**Agree with all three peers.** All three plan steps (R1 fields/callback/test, R2 total-supply assertion, R3 scanner roots) are present in the current source. The existing rollback test, rejection half, harness, custody tuple, APEX-marker scan, bare-call regex, report path, and `--check` behavior are unchanged as the plan requires. No `nestedOk` field, no `assembly` return in the observation callback, no `bubbleRevert = false`, no production change, no harness change. The 13 assertions in the observation test, the 1 new fuzz assertion, and the 17-entry `roots` tuple are all present at the cited line numbers.

This is not a question; the three peers agree, and the source re-reads confirm it.

## (2) Forge run not recorded

**Agree with all three peers.** The plan's Step 4 (plan lines 149-167) requires:
- `git diff --check` and `bash -n scripts/apex_bare_expectrevert_scan.sh` (static checks)
- `python3 scripts/forge-artifacts.py plan` and `python3 scripts/forge-artifacts.py test` (artifact build and test execution)
- `bash scripts/apex_bare_expectrevert_scan.sh` and `bash scripts/apex_bare_expectrevert_scan.sh --check` (scanner run)
- Reporting the commands, toolchain, and every result

None of this is recorded. There is no `EXECUTION_REPORT.md` in `docs/reviews/apex-req-03-custody-negatives/` or in `docs/reviews/apex-req-03-execution-confirmation/`. No saved log. No test result file. The plan's done-when bullet at line 175 — "The two test files passed through the helper" — is unwitnessed.

The three peers agree. My own original reaches the same verdict.

## (3) `bare-expectrevert.txt` is not a recorded `--check` exit

**Agree with all three peers.** The file `docs/audits/apex-2026-09-17-evidence/bare-expectrevert.txt` exists (317 lines) and lists the two PRD-cited escape files (`ERC4626StandardExchange_Routes.t.sol:332,335,383,409,559` at output lines 300-304; `RebasingAwareERC4626_Accounting.t.sol:131,143` at output lines 127-128). It is consistent with an expanded-scanner run. But:

- The script at `apex_bare_expectrevert_scan.sh:54-56` writes the same file for both the plain scan and the `--check` scan. The two invocations cannot be distinguished from the file alone.
- The count line is printed to stdout at line 59, not written to the file. The file has no count.
- The file has no command, toolchain, timestamp, or exit status. The plan forbids hand-editing it (plan line 26).
- The plan's done-when bullet at line 175 — "The nonzero `--check` exit is recorded and was not 'fixed' by rewriting tests" — is unwitnessed.

The file is evidence of a scanner output, not a recorded `--check` run. The three peers agree. My own original reaches the same verdict.

## Severity: Medium

**I record Medium.** I agree with Grok and Kimi. **I dissent from Astra's Low.**

Astra's reasoning (paraphrased): "Low; verification/reporting gap, not a demonstrated source or security regression." I disagree with the framing on two grounds.

**First, the plan makes the run a hard done-when condition, not a soft verification check.** Plan line 175 — the plan's own done-when list — requires: "The two test files passed through the helper. The scanner report lists the two cited files. The nonzero `--check` exit is recorded and was not 'fixed' by rewriting tests." Plan line 167 — also from the plan body — says: "A present assertion is not a pass until that run is reported." The plan does not treat the run as optional. It treats the run as a gate. A failed gate is not a "verification/reporting gap"; it is a missed gate.

**Second, the missing run is not equivalent to "no source regression."** Astra's framing — "not a demonstrated source or security regression" — is correct that no source code is broken. But the question in this round is not whether the source is broken. The question is whether the plan was completed. The claim "another agent completed the plan" is unproven on the run bullet. A claim of completion that fails a hard done-when bullet is Medium, not Low, because the completion claim itself is weakened — the plan author required this evidence to distinguish a completed plan from a half-completed plan.

Kimi's framing (paraphrased): "the plan makes the reported run a hard done-when condition; an unrecorded claim of completion is exactly the failure mode the run requirement exists to prevent. I assign no higher severity because the source edits themselves verify as exact matches." This is the correct framing. The run is a gate, not a nicety. The source matches are partial credit, not full completion.

Grok's framing (paraphrased): "Medium for the completion claim. Not a source mismatch. ... A present assertion is not a pass until the named run is reported." This is the correct framing. The completion claim is unproven; the source is not the completion.

The run's absence means: (a) the new observation test has never been shown to pass — its central mechanism (the record surviving a finished outer deposit) is a runtime property that source reading cannot prove; (b) the new fuzz total-supply assertion has never been shown to pass under fuzz; (c) the `--check` exit status has never been recorded, so the plan's "do not rewrite selected tests to make `--check` pass" rule has no enforcement record. Each of these is a Medium-severity gap in the completion claim, not a Low-severity verification detail.

The fix direction is the same as all three peers: a later session runs the plan's Step 4 commands, writes the report beside the plan (or in the execution-confirmation directory), and records the toolchain, the helper result, the scanner site list, and the `--check` exit. Do not rewrite a selected test. Do not hand-adjust `bare-expectrevert.txt` beyond running the script.

I record Medium. Astra's Low understates the failure mode. The plan's own language ("not a pass until that run is reported") places the run at the completion gate, not at a verification nicety.

## Material peer claims not re-read

- I did not re-read the source files this round; my own original re-read them and the line numbers match what the three peers cite. The agreement is on content, not just on cited line numbers.
- I did not search `docs/` for further evidence of an execution report. The three peers and my own original searched the same locations. If a report exists in a filename or location none of us searched, it is outside the scope of this round.

I did not run Forge.