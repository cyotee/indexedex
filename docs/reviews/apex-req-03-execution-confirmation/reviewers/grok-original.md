# Grok original — REQ-03 execution confirmation

- **Date:** 2026-10-15
- **Plan:** `docs/reviews/apex-req-03-custody-negatives/REMEDIATION_PRD.plan.md`, read in full. Not edited.
- **Claim:** Another agent completed that plan.
- **Verdict:** source matches but run not recorded.
- The claim is refuted as completion. Steps 1-3 are in the current source. Step 4 is not recorded. A present assertion is not a pass. This is not an independent rerun.

## Step 1 — observation test

Source matches. Current lines shifted because the new fields and callback were inserted. The bodies match the plan.

- Fields are `bool internal nestedAttempted` and `bytes internal nestedReason` immediately after the contract opening brace (`RebasingAwareERC4626_Adversarial.t.sol:26-27`). Plan lines 51-54.
- `recordNestedDeposit` is the plan body: same low-level `deposit` of `1e18`, success flag discarded, two stores, normal return (`:38-42`). Plan lines 58-64. No assembly return. No `nestedOk`.
- `observeNestedDeposit` still asserts, then reverts `IsLocked` (`:31-35`). Plan lines 47 and 21. Body unchanged from the pre-insert function.
- `test_ADV03_reentrancyDuringDepositReverts` still points at `observeNestedDeposit`, sets `bubbleRevert` true, expects `TransferFromFailed`, and keeps the four no-partial-credit assertions (`:137-155`). Plan lines 47 and 21.
- `test_ADV03_nestedDepositIsLocked_outerDepositCompletes` is the plan function (`:158-185`). Plan lines 70-98. Salt is `bytes32(uint256(123))`. Offset is `10`. Funding is `100e18`. Outer amount is `10e18`. `tok.setBubbleRevert(true)` is at `:163`. The recipient assertion is `aliceSharesBefore + minted`, not `10e18`.

## Step 2 — total supply

Source matches. After the existing success assertions, `RebasingAwareERC4626_Fuzz.t.sol:101` is:

`assertEq(IERC20(address(vault)).totalSupply(), supplyBefore + shares, "exact funding increases supply by the quoted shares");`

`supplyBefore` is still captured at `:65`. The rejection half and the four prior success assertions at `:96-100` remain. Plan lines 107-113.

## Step 3 — scanner roots

Source matches. `scripts/apex_bare_expectrevert_scan.sh:14-32` is the seventeen-path tuple in the plan's order, including both Balancer spellings. Plan lines 119-138. The `custody` tuple remains at `:33-36`. The APEX-marker scan remains at `:39-41`. The report path remains at `:54`. `--check` still exits 1 when sites exist (`:60-61`).

`ReentrantERC20Harness.sol:68-78` still returns when the callback call succeeds and bubbles only when that call fails and `bubbleRevert` is true. No new flag is in that path.

## Step 4 — recorded run

Missing. The plan requires the helper `plan` and `test` commands, both scanner commands, the toolchain, every result, and the nonzero `--check` exit (`REMEDIATION_PRD.plan.md:149-175`). Done-when requires the two test files to have passed through the helper and the nonzero exit to be recorded.

Searched `docs/` for an execution report of those commands. There is no `EXECUTION_REPORT.md` under `docs/reviews/apex-req-03-custody-negatives/` or `docs/reviews/apex-req-03-execution-confirmation/`. The plan file itself still says it does not authorize the edits and ends with "I did not run Forge" (`:4`, `:186`). Mentions of `forge-artifacts.py test` in `docs/reviews` are the plan and earlier plan drafts, not a result log. No Forge pass is recorded.

`docs/audits/apex-2026-09-17-evidence/bare-expectrevert.txt` exists. It lists `RebasingAwareERC4626_Accounting.t.sol:131` and `:143` (`bare-expectrevert.txt:127-128`) and five sites in `ERC4626StandardExchange_Routes.t.sol` (`:300-304`). That is the scanner's output path, and those two files are the cited selection check. It is not evidence of the required scanner run. It has no command, no exit code, no toolchain, and no Forge result. A file at that path is not a recorded `--check` exit and is not an independent rerun.

- **Severity:** Medium for the completion claim. Not a source mismatch.
- **Broken requirement:** Plan step 4 and the last two done-when bullets. A present assertion is not a pass until the named run is reported.
- **Impact class:** Unverified execution. The source can still fail the helper, and the nonzero `--check` exit is not recorded.
- **Fix direction:** A later session runs the plan's command block and writes the commands, toolchain, helper result, scanner site list, and `--check` exit. Do not rewrite a selected test or drop a root to make `--check` exit 0.

I did not run Forge.
