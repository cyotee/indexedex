# Kimi K3 — confirmation: REQ-03 plan execution

- **Label:** Replacement-session confirmation, not continuity. I do not recall `ses_ec41220c2ffeqs5Eha7fPsd54B`. No other reviewers' notes were read, including the peer originals present in this round's `reviewers/` directory. The claimed-executed plan (`docs/reviews/apex-req-03-custody-negatives/REMEDIATION_PRD.plan.md`) was read in full; the controlling PRD is its sibling.
- **Date:** 2026-10-14.
- **Question:** confirm or refute the claim that the REQ-03 plan was completed against the current working tree.
- I did not run Forge or any shell command. A present assertion is not a pass; a saved log is not an independent rerun.

## Verdict: source matches but run not recorded

All three source-edit steps match the plan exactly, line by line. Step 4's required recorded run — the `forge-artifacts.py plan`/`test` pass of the two test files, the scanner runs, and the recorded nonzero `--check` exit — has no execution report and no run log anywhere I searched. Under the plan's own done-when ("A present assertion is not a pass until that run is reported", plan `:167`, `:175`), the completion claim is unproven on that bullet.

## Step-by-step confirmation

### Step 1 — observation fields, callback, test (plan `:43-103`) — matches

- Fields at `RebasingAwareERC4626_Adversarial.t.sol:26-27`: `bool internal nestedAttempted; bytes internal nestedReason;` — exactly the plan's declarations (`:51-54`), including the `internal` visibility closed in the plan's dissent (`:183`).
- Callback at `:38-42`: identical to the plan's body (`:59-63`) — same low-level call, success flag discarded, no assertion, no revert, no assembly return, no `nestedOk`.
- `observeNestedDeposit` unchanged in content at `:31-36` (line drift from the inserted fields only); `test_ADV03_reentrancyDuringDepositReverts` unchanged at `:137-156`, still expecting `TransferFromFailed` (`:149`) with the four no-partial-credit assertions (`:152-155`).
- New test `test_ADV03_nestedDepositIsLocked_outerDepositCompletes` at `:158-185`: matches the plan's code block (`:71-98`) — salt `bytes32(uint256(123))` (`:160`), offset `10` (`:160`), `setBubbleRevert(true)` (`:163`, per plan `:18`), field reset (`:164-165`), preview capture (`:167`), the full success witness (`:177-182`), then the nested pin (`:183-184`). No absolute share literal (plan `:20` respected).
- The harness `contracts/test/stubs/ReentrantERC20Harness.sol:58-86` is unchanged from my earlier full read (plan `:17`).

### Step 2 — fuzz success-half total-supply assertion (plan `:105-113`) — matches

`RebasingAwareERC4626_Fuzz.t.sol:101` adds exactly the planned line: `assertEq(IERC20(address(vault)).totalSupply(), supplyBefore + shares, "exact funding increases supply by the quoted shares");`. The rejection half (`:70-84`), snapshot/restore (`:63`, `:85`), bounds (`:58`), and the existing success assertions (`:96-100`) are unchanged.

### Step 3 — scanner roots (plan `:115-141`) — matches

`scripts/apex_bare_expectrevert_scan.sh:14-32` holds the 17-entry `roots` tuple in exactly the plan's order (both Balancer spellings present, `:29-30`). The `custody` tuple (`:33-36`), the APEX-marker scan (`:39-41`), the bare-call regex (`:44`), the report path (`:54`), and the `--check` behavior (`:60-61`) are unchanged.

### Step 4 — commands and recorded results (plan `:143-167`) — not recorded

- No execution report exists for this item: `docs/reviews/apex-req-03-custody-negatives/` contains only `REMEDIATION_PRD.md`, `REMEDIATION_PRD.plan.md`, and `reviewers/` (directory read). A `docs/` search for `EXECUTION_REPORT` / "commands actually run" finds only the REQ-02 report and unrelated documents. No document or log mentions the new test name outside plan and reviewer drafts. No log records a `forge-artifacts.py plan/test` invocation with these test roots.
- The generated `docs/audits/apex-2026-09-17-evidence/bare-expectrevert.txt` exists with 317 sites. It is **consistent** with an expanded-scanner run: it lists sites in directories that only the new roots add (Aerodrome, Balancer under both spellings, Camelot, Uniswap V2, Aave cross-version, EtherFi, Lido, DETF, ERC-4626, Morpho), and it lists the two PRD-cited files at exactly the sites I independently found by grep (`RebasingAwareERC4626_Accounting.t.sol:131,143` at lines 127-128; `ERC4626StandardExchange_Routes.t.sol:332,335,383,409,559` at lines 300-304). It also reports the previously noted bare expectation in `UniswapV3FullSpreadVaultHeldRedeem.t.sol:147` (line 311).
- However, the file carries no command, toolchain, timestamp, count line, or exit status (the count is printed to stdout by the script, `:59`, not written to the file), and the plan forbade hand-editing it (`:26`) — a prohibition, not proof. So it is evidence that a scanner run against the expanded roots likely occurred, and it is **not** an independent rerun and **not** a record of the `--check` exit the plan requires to be reported (`:163-165`).
- No Forge pass of the two test files is recorded anywhere. The plan's done-when bullet "The two test files passed through the helper" (`:175`) is unwitnessed.

## Finding

### F1 — Completion claim lacks the plan-required run record

- **Severity:** Medium — the plan makes the reported run a hard done-when condition (`:167`, `:175`) because these tests deploy production packages from `out/`; an unrecorded claim of completion is exactly the failure mode the run requirement exists to prevent. I assign no higher severity because the source edits themselves verify as exact matches.
- **File and line:** `docs/reviews/apex-req-03-custody-negatives/REMEDIATION_PRD.plan.md:143-167` (the unmet requirement); missing artifact: an execution report beside the plan.
- **Broken requirement:** Step 4 was not reported: no record of `forge-artifacts.py plan`/`test` results for the two test files, no recorded scanner stdout, no recorded nonzero `--check` exit, no toolchain note.
- **Impact class:** Execution evidence / false-closure risk. The observation test in particular has never been shown to pass — its central mechanism (the record surviving a finished outer deposit) is a runtime property that source reading cannot prove.
- **Fix direction:** In a separately authorized session, run the plan's step-4 commands verbatim, write the execution report beside the plan, and preserve the scanner's stdout and the `--check` exit status in it. Do not regenerate or hand-adjust `bare-expectrevert.txt` beyond running the script.
- **Confidence:** High that no report exists (multiple searches); the run itself is unverified, not failed.
- **Fact vs inference:** Fact — the source matches and no report/log was found. Inference — the `bare-expectrevert.txt` content implies a scanner run happened; its provenance and recency are unverifiable without execution.

## Evidence gaps

- I did not run Forge or shell; nothing above is an executed result.
- I could not check git history or timestamps for the edited files or the generated report (no shell).
- Whether `bare-expectrevert.txt` predates or postdates the source edits is unknowable from its content.

I did not run Forge.
