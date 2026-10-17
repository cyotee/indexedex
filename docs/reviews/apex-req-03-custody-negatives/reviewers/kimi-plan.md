# Kimi K3 — plan draft: REQ-03 custody negatives

- **Label:** Replacement-session plan draft, not continuity. I do not recall `ses_ec41220c2ffeqs5Eha7fPsd54B`. No other reviewers' notes were read for this draft. This is not the consolidated `REMEDIATION_PRD.plan.md`, which I did not write.
- **Date:** 2026-10-14.
- **Status:** DRAFT. Writing this plan does not authorize code, test, config, or script edits. A later session must be explicitly asked to implement it.
- **Controlling document:** `docs/reviews/apex-req-03-custody-negatives/REMEDIATION_PRD.md` (re-read in full; 87 lines, including the 2026-10-14 owner rulings). Where this draft conflicts with that PRD, the PRD controls.
- **Remaining implementer choice:** **None.** The owner rulings at PRD `:30` and `:54` close the two decisions I raised in my question turn (proof channel for R1; inventory source for R3). Every selection below is dictated by the PRD's acceptance criteria or is mechanical against current code. If the implementer believes a choice remains, stop and report it rather than choosing.
- I did not run Forge.

## Order

| Step | Work | Files |
| --- | --- | --- |
| 1 | Add the R1 observation callback and observation test | `test/foundry/spec/protocols/staking/rebasingVault/RebasingAwareERC4626_Adversarial.t.sol` |
| 2 | Add the R2 total-supply assertion | `test/foundry/spec/protocols/staking/rebasingVault/RebasingAwareERC4626_Fuzz.t.sol` |
| 3 | Extend the scanner's `roots` tuple with the 15 listed directories | `scripts/apex_bare_expectrevert_scan.sh` |
| 4 | Run the two test files and the scanner; report | commands below |

Test-only steps first because they need no script change; the scanner step is independent and may swap with them. Do not edit the rollback test, production code, or the harness in any step.

## Step 1 — REQ-03-R1: observation callback and observation test

Current state (re-read this session): `observeNestedDeposit` (`RebasingAwareERC4626_Adversarial.t.sol:28-33`) asserts inside the callback and deliberately reverts `IsLocked` at `:32`; the rollback test `test_ADV03_reentrancyDuringDepositReverts` (`:128-147`) keeps that shape and is **not edited**. The harness (`contracts/test/stubs/ReentrantERC20Harness.sol:58-79`) moves tokens, then calls the reenter target (`:63-64`, `:68-79`); when the callback returns normally, `transferFrom` returns true and the outer deposit finishes. That is the owner-ruled shape (PRD `:30`, `:32-34`).

### 1a. Field declarations on the test contract

Add to `RebasingAwareERC4626_Adversarial` (beside the existing observer):

```solidity
bool internal nestedAttempted;
bool internal nestedOk;
bytes internal nestedReason;
```

### 1b. The observation callback

Add a new function; do not modify `observeNestedDeposit`:

```solidity
/// @dev Observation leg of ADV03. Records the nested result and returns, so the record
///      survives: the outer deposit finishes and the test reads the record after the call.
///      The test contract is deliberately not funded with the harness token, so a missing
///      guard cannot produce a nested success here.
function recordNestedDeposit(address wrapped, address receiver) external {
    (bool ok, bytes memory reason) = wrapped.call(abi.encodeCall(IERC4626.deposit, (uint256(1e18), receiver)));
    nestedAttempted = true;
    nestedOk = ok;
    nestedReason = reason;
}
```

### 1c. The observation test

Function name: `test_ADV03_observation_nestedDepositRejectedIsLocked`. Mirror the rollback test's fixture (`:129-132` of the current file) exactly, apart from the callback, the bubble toggle, and a distinct vault salt:

```solidity
function test_ADV03_observation_nestedDepositRejectedIsLocked() public {
    ReentrantERC20Harness tok = new ReentrantERC20Harness("R", "R", 18);
    IERC4626 wrapped = pkg.deployVault(IERC20Metadata(address(tok)), 10, bytes32(uint256(124)));
    tok.mint(alice, 100e18);
    tok.setReenter(address(this), abi.encodeCall(this.recordNestedDeposit, (address(wrapped), alice)));
    tok.setBubbleRevert(false);
    uint256 supplyBefore = IERC20(address(wrapped)).totalSupply();
    uint256 aliceBefore = IERC20(address(wrapped)).balanceOf(alice);
    uint256 expectedShares = wrapped.previewDeposit(10e18);
    vm.startPrank(alice);
    tok.approve(address(wrapped), type(uint256).max);
    uint256 sharesOut = wrapped.deposit(10e18, alice);
    vm.stopPrank();

    // Exact success witness that the outer deposit finished:
    assertEq(sharesOut, expectedShares, "outer deposit finished with its previewed shares");
    assertEq(IERC20(address(wrapped)).totalSupply(), supplyBefore + sharesOut, "supply grew only by the outer mint");
    assertEq(IERC20(address(wrapped)).balanceOf(alice), aliceBefore + sharesOut, "recipient shares are the outer mint only");

    // The nested pin, read after the call, outside any wrapped frame:
    assertTrue(nestedAttempted, "nested deposit attempted during the pull");
    assertFalse(nestedOk, "nested deposit rejected");
    assertEq(nestedReason, abi.encodeWithSelector(IReentrancyLock.IsLocked.selector), "nested rejection is IsLocked");
}
```

Properties, per PRD `:32-33`: the production deposit path and production lock are used; the vault is not mocked; the record is read after the finished call; a wrong nested error fails the last assertion; a nested success fails `assertFalse(nestedOk)`; an absent callback fails `assertTrue(nestedAttempted)`. The distinct salt `bytes32(uint256(124))` avoids any doubt about colliding with the rollback test's `:130` salt within shared fixtures; each test deploys its own wrapped vault either way.

Do not edit `test_ADV03_reentrancyDuringDepositReverts` (`:128-147`) or `observeNestedDeposit` (`:28-33`). The rollback test keeps its `TransferFromFailed` outer expectation and its no-partial-credit assertions (PRD `:34`).

## Step 2 — REQ-03-R2: one total-supply assertion in the success half

In `RebasingAwareERC4626_Fuzz.t.sol`, after the existing `:97` (`assertEq(... balanceOf(alice), shares, ...)`), add exactly:

```solidity
assertEq(IERC20(address(vault)).totalSupply(), supplyBefore + shares, "exact funding mints exactly the quoted shares");
```

`supplyBefore` is already captured at `:65`, and the success half runs from the snapshot taken at `:63` and restored at `:85`, so the captured value is the correct baseline. Do not touch the rejection half (`:70-84`), the fuzz bounds (`:58`), or any other assertion (PRD `:44-45`).

## Step 3 — REQ-03-R3: extend `roots` in the PRD's listed order

In `scripts/apex_bare_expectrevert_scan.sh:14-17`, extend the `roots` tuple — existing two entries first, then the fifteen directories in the PRD's listed order (`:56-71`). Exact resulting tuple:

```python
roots = (
    Path("test/foundry/spec/hooks/uniswap/v4/standardExchange"),
    Path("test/foundry/spec/vaults/standard/exchange/protocols/uniswap"),
    Path("test/foundry/spec/vaults/standard/erc4626"),
    Path("test/foundry/spec/vaults/standard/exchange/protocols/morpho/blue"),
    Path("test/foundry/spec/protocols/staking/rebasingVault"),
    Path("test/foundry/spec/protocol/staking/rocket-pool"),
    Path("test/foundry/spec/protocol/staking/lido"),
    Path("test/foundry/spec/protocol/staking/etherfi"),
    Path("test/foundry/spec/protocol/lending/aave/v3.6"),
    Path("test/foundry/spec/protocol/lending/aave/cross-version"),
    Path("test/foundry/spec/protocol/dexes/uniswap/v2"),
    Path("test/foundry/spec/protocol/dexes/camelot/v2"),
    Path("test/foundry/spec/protocol/dexes/aerodrome/v1"),
    Path("test/foundry/spec/protocols/dexes/aerodrome/slipstream"),
    Path("test/foundry/spec/protocol/dexes/balancer/v3"),
    Path("test/foundry/spec/protocols/dexes/balancer/v3"),
    Path("test/foundry/spec/vaults/detf"),
)
```

Nothing else in the script changes: the `custody` tuple (`:18-21`) stays even though the rebasingVault root now covers those two files (PRD `:75`: they stay selected); the APEX-marker filter (`:24-26`) stays; the matching, output, and `--check` logic (`:27-46`) stays. Do not add or drop a directory (PRD `:77`).

Expected result, stated now so it is not "fixed" later: the expanded scan will report the known bare sites, including `ERC4626StandardExchange_Routes.t.sol` and `RebasingAwareERC4626_Accounting.t.sol` (PRD `:52`), so a `--check` run exits nonzero. That is the correct end state of this item; rewriting those tests is a later item (PRD `:76`).

## Step 4 — commands to run

This item edits tests and a script only; no production creation bytecode changes, so no `forge-artifacts.py` refresh is required. From the repository root:

```sh
forge test --match-path test/foundry/spec/protocols/staking/rebasingVault/RebasingAwareERC4626_Adversarial.t.sol -vvv
forge test --match-path test/foundry/spec/protocols/staking/rebasingVault/RebasingAwareERC4626_Fuzz.t.sol -vvv
scripts/apex_bare_expectrevert_scan.sh
```

Then verify `docs/audits/apex-2026-09-17-evidence/bare-expectrevert.txt` lists the two files named in PRD `:52`. Also run `scripts/apex_bare_expectrevert_scan.sh --check` once to record its (expected nonzero) exit and the full reported site list in the implementation report; do not treat that nonzero exit as a failure of this item, and do not make it pass by editing the newly selected tests. If a listed directory is missing at run time, stop and report it; do not drop or substitute it (PRD `:77`). Report the commands actually run, the toolchain, and every test result.

## What not to do

- No production change of any kind: not the pull wrap (`RebasingAwareERC4626Common.sol:274-278`), not the bytecode check (`RebasingAwareStandardYieldTarget.sol:57-59`), not minting, not the harness (`contracts/test/stubs/ReentrantERC20Harness.sol` stays byte-identical — the existing toggles suffice).
- No bare `expectRevert()` anywhere, new or replacement.
- Do not change the rollback test or `observeNestedDeposit`; do not make any outer selector `IsLocked`; do not require one call both to revert and to leave a record.
- Do not widen the fuzz domain or alter any existing assertion.
- Do not rewrite, pin, or delete tests in the newly selected scanner directories to make `--check` pass; do not weaken the scanner's selection to hide their bare sites.
- Do not invent or grep-derive scanner inventory entries beyond the PRD's list.
- Do not deploy, migrate, or touch live instances.

## Done when

- The observation test exists under the name above, passes on the current production guard, and its nested-error assertion is read from surviving state after a finished outer deposit; the rollback test is byte-identical to today.
- The fuzz success half contains the single new total-supply assertion and nothing else changed.
- The scanner's `roots` tuple matches the 17-entry list above; the scanner run lists the two PRD-cited files; the expected `--check` exit and site list are in the report.
- The implementation report names the commands actually run and their results.

I did not run Forge.
