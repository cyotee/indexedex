# Implementation plan — REQ-03 custody-negatives PRD

- **Date:** 2026-10-14
- **Status:** DRAFT. Writing this plan does not authorize code, test, config, or script edits. A later session must be explicitly asked to implement it. The owner has already searched the inventory and recorded the rules; this plan does not re-decide any of them.
- **Controlling PRD:** `docs/reviews/apex-req-03-custody-negatives/REMEDIATION_PRD.md` (91 lines, re-read in full this round). The completeness review at line 11 records that no implementer decision remains after the 2026-10-14 owner rulings. The dissent at line 87 records that the two remaining mechanism choices (observation record carrier, scanner carrier) are now specified in REQ-03-R1 and REQ-03-R3.

## Re-reads this round

- `test/foundry/spec/protocols/staking/rebasingVault/RebasingAwareERC4626_Adversarial.t.sol` (full read, 225 lines; `observeNestedDeposit` at 28-33, `test_ADV03_reentrancyDuringDepositReverts` at 128-147).
- `test/foundry/spec/protocols/staking/rebasingVault/RebasingAwareERC4626_Fuzz.t.sol` (full read, 220 lines; `testFuzz_FUZZ02_exactOutMinimals` at 57-101, success half at 85-100).
- `contracts/test/stubs/ReentrantERC20Harness.sol` (full read, 86 lines).
- `scripts/apex_bare_expectrevert_scan.sh` (full read, 47 lines).
- `contracts/protocols/staking/rebasingVault/TestBase_RebasingAwareERC4626.sol` (scoped read; `setUp` at 43-89, `_deployVault` at 90-94).

## No choice remains

The PRD is complete. Every previously-open question is closed. The implementer has the callback name, the field names, the success-witness shape, the total-supply assertion, the scanner tuple order, and the exact rules for what not to do. The plan below names, orders, and prescribes each step. No sentence needs to be added to the PRD.

If a step below is not literally covered by the PRD, it is a coding detail within the closed acceptance criteria (e.g., the new test function's name, the exact field declarations in the test contract, the exact assertion text in the success half). The PRD's non-goals and the "the implementer does not decide" rulings block any alternative that would re-open a closed choice.

## R1 — Observation test: separate call, callback records and returns, rollback test stays

### Step 1 — Add the `nestedAttempted` and `nestedReason` state fields to the test contract

In `RebasingAwareERC4626_Adversarial.t.sol`, add two state variables to the contract body (alongside the existing test contract's state at line 25):

```solidity
bool public nestedAttempted;
bytes public nestedReason;
```

The PRD AC 2 (line 34) specifies these field names. They are the test-contract storage that the observation callback writes and the observation test reads. They are not used by the existing rollback test.

### Step 2 — Add the `recordNestedDeposit` callback

In `RebasingAwareERC4626_Adversarial.t.sol`, add a new external function alongside the existing `observeNestedDeposit` (line 28-33). The new callback uses the same low-level nested `deposit` call as `observeNestedDeposit` but does not assert or revert:

```solidity
/// @dev Observation callback for the separate observation test. Catches the inner
///      deposit revert, records the result on the test contract, and returns.
///      Lets the outer deposit finish. The test reads `nestedAttempted` and
///      `nestedReason` after the outer call and asserts IsLocked.
function recordNestedDeposit(address wrapped, address receiver) external {
    (bool ok, bytes memory reason) = wrapped.call(
        abi.encodeCall(IERC4626.deposit, (uint256(1e18), receiver))
    );
    nestedAttempted = true;
    nestedReason = reason;
    assembly ("memory-safe") {
        // Explicit return; no revert, no assertion.
        return(0, 0)
    }
}
```

Notes:

- `nestedAttempted = true` is set unconditionally so that a nested success (where `ok` is true and `reason` is empty) still records that the callback was reached. The observation test then asserts the recorded reason is `IsLocked`; a successful nested deposit leaves `nestedReason` empty, which fails the `assertEq` and surfaces the "nested success" failure mode the PRD calls out at line 34.
- `nestedReason` is the raw returndata from the failed call. When the nested call reverts with `IsLocked`, `reason` is exactly `abi.encodeWithSelector(IReentrancyLock.IsLocked.selector)`. When the nested call reverts with a different reason, the assertion fails. When the nested call succeeds, `reason` is empty, the assertion fails.
- No `try/catch` is used; the low-level `call` already returns `(ok, reason)`. The harness's `_callback` sees `ok = true` because the callback function returned normally; `transferFrom` then succeeds; the outer deposit continues.
- The callback uses `assembly ("memory-safe") { return(0, 0) }` to make the "returns without an assertion and without a revert" intent explicit. A bare function end would do the same; the assembly form is the convention used in `ReentrantERC20Harness.sol:73-76` and is the safest Solidity-0.8 idiom for "return nothing, no other code path."

### Step 3 — Add the observation test

In `RebasingAwareERC4626_Adversarial.t.sol`, add a new test function alongside `test_ADV03_reentrancyDuringDepositReverts` (line 128-147). The new test deploys its own `ReentrantERC20Harness` and vault, points the harness at `recordNestedDeposit`, and asserts the recorded result after the outer deposit finishes. The PRD does not specify the test function name; following the existing `test_ADV03_*` convention, the natural name is `test_ADV03_observation_nestedGuardPin`. The harness configuration mirrors the rollback test's, except the reenter target is `recordNestedDeposit` instead of `observeNestedDeposit`:

```solidity
/// @notice REQ-03-R1 observation: a separate call from the rollback test.
///         The callback records the nested attempt and reason on the test
///         contract, then returns. The outer deposit finishes. The test
///         reads the record and asserts IsLocked. A wrong nested error or
///         a nested success fails this test.
function test_ADV03_observation_nestedGuardPin() public {
    ReentrantERC20Harness tok = new ReentrantERC20Harness("R", "R", 18);
    IERC4626 wrapped = pkg.deployVault(IERC20Metadata(address(tok)), 10, bytes32(uint256(234)));
    tok.mint(alice, 100e18);
    tok.setReenter(address(this), abi.encodeCall(this.recordNestedDeposit, (address(wrapped), alice)));
    // bubbleRevert stays at its default (true). It is irrelevant here because
    // recordNestedDeposit returns normally, so the harness's _callback sees
    // ok = true and transferFrom returns success.
    uint256 supplyBefore = IERC20(address(wrapped)).totalSupply();
    vm.startPrank(alice);
    tok.approve(address(wrapped), type(uint256).max);
    wrapped.deposit(10e18, alice);
    vm.stopPrank();
    // Outer deposit finished. The storage writes from recordNestedDeposit
    // are not rolled back because the outer call succeeded.
    assertTrue(nestedAttempted, "callback was reached");
    assertEq(
        nestedReason,
        abi.encodeWithSelector(IReentrancyLock.IsLocked.selector),
        "nested guard is IsLocked"
    );
    // The outer deposit succeeded; nested attempt was rejected; nothing minted
    // to the nested target and the supply only changed by the outer deposit.
    assertGt(IERC20(address(wrapped)).totalSupply(), supplyBefore, "outer deposit minted");
    assertEq(IERC20(address(wrapped)).balanceOf(alice), 10e18, "alice received outer-deposit shares");
}
```

Notes:

- The observation test creates its own `ReentrantERC20Harness` and vault, just as the rollback test does at line 129-130. This keeps the two tests independent.
- `bubbleRevert` is not set in the observation test. The default value in the constructor is the zero value `false`. The PRD says "Keep `bubbleRevert` true" at line 35; this is a constraint on the existing rollback test's configuration (which already sets it to `true` at line 133) and a statement that the observation test does not need to set it. The observation test does not set `bubbleRevert` because it does not matter: the callback returns normally, so `_callback` sees `ok = true` and returns without consulting `bubbleRevert`. If a future maintainer prefers the explicit form, the line `tok.setBubbleRevert(true);` may be added; the behavior is identical.
- The success witness that the outer deposit finished has three parts: (a) the `wrapped.deposit` call returns without reverting; (b) `nestedAttempted == true` (the callback was reached and wrote to storage); (c) `nestedReason` is the expected `IsLocked` selector. Together, (a) proves the outer call succeeded, (b) proves the callback fired, and (c) proves the nested guard rejected with the named error. All three are required by the PRD AC 2.
- The post-state assertions at the end of the test (`totalSupply > supplyBefore`, `alice balance == 10e18`) are the outer-deposit success checks. They are not the nested-pin; they verify that the outer deposit did what the test said it would. The PRD does not require these specific assertions, but they are the natural sanity checks for "the outer deposit finished" and follow the pattern of the rollback test's no-partial-credit assertions at line 143-146.
- The test function name `test_ADV03_observation_nestedGuardPin` follows the existing `test_ADV<number>_*` convention at line 35, 50, 63, 76, 91, 103, 113, 128, 149, 162, 205, 217. The PRD does not specify the test function name; the implementer can pick an equivalent. If the existing rollback test is renamed to disambiguate (e.g., `test_ADV03_rollback_nestedGuardReverts`), the observation test takes the simpler `test_ADV03_nestedGuardPin` name. The PRD does not require a rename.

### Step 4 — Leave the existing rollback test unchanged

The PRD AC 3 (line 36) says: "The existing rollback test stays. Its outer call still reverts `TransferFromFailed`, and its no-partial-credit assertions for supply, recipient shares, vault assets, and reserve stay. That test does not have to carry the nested-error pin."

The existing `test_ADV03_reentrancyDuringDepositReverts` at line 128-147 is unchanged. It continues to use `observeNestedDeposit` (line 28-33) and `bubbleRevert = true` (line 133). The no-partial-credit assertions at lines 143-146 stay.

## R2 — Total supply assertion on success

### Step 5 — Add one assertion to the success half of `testFuzz_FUZZ02_exactOutMinimals`

In `RebasingAwareERC4626_Fuzz.t.sol`, the success half of `testFuzz_FUZZ02_exactOutMinimals` is at lines 85-100. The PRD AC 1 (line 46) says: "After the successful exact-output call, total supply equals the captured supply plus the requested shares."

Add one `assertEq` line to the success half. `supplyBefore` is captured at line 65 and `shares` is the fuzz input. The natural placement is alongside the existing success-half assertions at line 100. The exact line to add, immediately after the existing line 100:

```solidity
assertEq(IERC20(address(vault)).totalSupply(), supplyBefore + shares, "exact funding mints the quoted shares to total supply");
```

Notes:

- The existing rejection half at line 81 already asserts `totalSupply == supplyBefore` on rejection. The new success-half assertion is the symmetric positive check.
- `supplyBefore` is captured before the `vm.snapshotState()` at line 63. The `vm.revertToState(snap)` at line 85 restores the captured state, so `supplyBefore` remains valid for the success half.
- The success half's other four assertions at lines 97-100 (recipient shares, caller assets, vault assets, reserve) stay.
- The fuzz domain at line 58 (`uint96(bound(shares, 1e10, 50e18))`) and the `vm.assume` at line 62 stay.
- The fuzz invariant `> shares + supplyBefore` is bounded by the test's `bound` constraint and `vm.assume`, so the addition does not overflow.

## R3 — Scanner: extend the existing `roots` tuple in the listed order

### Step 6 — Extend `roots` in `scripts/apex_bare_expectrevert_scan.sh`

The current script at lines 14-17 has:

```python
roots = (
    Path("test/foundry/spec/hooks/uniswap/v4/standardExchange"),
    Path("test/foundry/spec/vaults/standard/exchange/protocols/uniswap"),
)
```

The PRD AC 1 (line 75) says: "Add each directory on this list that is not already in `roots` to the existing `roots` tuple in `scripts/apex_bare_expectrevert_scan.sh`, in the listed order. Do not add a second selection list or an external inventory file. Leave the `custody` tuple and the APEX-marker scan unchanged."

The new `roots` tuple, in the exact listed order at PRD lines 58-73:

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

Notes:

- The two already-selected roots at the top of the tuple (lines 1-2) stay. The 15 new directories are appended in the order given by the PRD (lines 59-73).
- The `custody` tuple at lines 18-21 stays unchanged. The two named custody files (`RebasingAwareERC4626_Adversarial.t.sol` and `RebasingAwareERC4626_Fuzz.t.sol`) are covered by the new `protocols/staking/rebasingVault` root (line 61 of the PRD), so they are still selected. The explicit `custody` tuple remains as a safety belt.
- The APEX-marker scan at lines 24-26 stays unchanged.
- The script's `--check` behavior at lines 45-46 stays unchanged.
- The PRD says "Do not add a second selection list or an external inventory file." The implementer extends the existing `roots` tuple; no new tuple, no external file.

### Step 7 — Verify the new selection matches the PRD's acceptance criteria

The PRD AC 2 (line 78) says "`ERC4626StandardExchange_Routes.t.sol` and `RebasingAwareERC4626_Accounting.t.sol` are selected because their directories are on the list." The new `roots` tuple covers both:

- `ERC4626StandardExchange_Routes.t.sol` is at `test/foundry/spec/vaults/standard/erc4626/`, which is now the third root. The file is selected.
- `RebasingAwareERC4626_Accounting.t.sol` is at `test/foundry/spec/protocols/staking/rebasingVault/`, which is now the fifth root. The file is selected.

The implementer does not need to add anything else to satisfy this AC; the existing `roots` tuple change covers it.

## Commands to run

The implementer runs these commands in order from the repository root. R1 and R2 are test-only edits; R3 is a script edit. The PRD does not require an artifact refresh for test or script edits, but running `forge build` first is safe and verifies the test contracts still compile.

### Test execution for R1

```sh
forge build
forge test --match-path test/foundry/spec/protocols/staking/rebasingVault/RebasingAwareERC4626_Adversarial.t.sol -vvv
```

Expected: `test_ADV03_reentrancyDuringDepositReverts` (rollback) passes unchanged. `test_ADV03_observation_nestedGuardPin` (new observation) passes. All other tests in the file pass.

If `test_ADV03_observation_nestedGuardPin` fails because the inner deposit reverts with a reason other than `IsLocked`, the test's `assertEq(nestedReason, abi.encodeWithSelector(IReentrancyLock.IsLocked.selector), "nested guard is IsLocked")` fails. This is the "wrong nested error" failure mode the PRD calls out at line 34. The implementer reports it; they do not patch the production guard.

### Test execution for R2

```sh
forge test --match-path test/foundry/spec/protocols/staking/rebasingVault/RebasingAwareERC4626_Fuzz.t.sol -vvv
```

Expected: `testFuzz_FUZZ02_exactOutMinimals` passes with the new total-supply assertion in the success half. All other tests in the file pass.

### Scanner execution for R3

```sh
bash scripts/apex_bare_expectrevert_scan.sh
bash scripts/apex_bare_expectrevert_scan.sh --check
```

Expected: the script's first line ("APEX R2.4: N bare expectations in M files") reports a higher `N` than the pre-edit run, because newly selected directories contain bare `expectRevert()` calls. Per PRD AC 2 (line 76): "A nonzero `--check` result caused only by existing bare `expectRevert()` calls in newly selected directories is the expected end state of this item. Do not rewrite those tests here, and do not drop a directory to make the check pass."

The `--check` invocation is expected to exit with code 1. The implementer records the count of newly-found bare `expectRevert()` calls and reports it; they do not rewrite the tests.

### Optional: full-suite regression

If the implementer wants a broader regression after the three edits:

```sh
forge test --match-path test/foundry/spec/protocols/staking/rebasingVault/ -vvv
forge test --match-path test/foundry/spec/hooks/uniswap/v4/standardExchange/ -vvv
forge test --match-path test/foundry/spec/vaults/standard/ -vvv
```

The PRD does not require these. They are additional confidence checks, not acceptance gates.

## What not to do

The PRD non-goals at line 37 (R1), line 48 (R2), line 81 (R3), and line 89 (whole draft) are explicit:

- **No production change.** Do not edit `RebasingAwareERC4626Common.sol`, `RebasingAwareAwareStandardYieldTarget.sol`, or any other production source. The PRD AC 1 (line 33) says "The production deposit path is still used. The vault is not mocked."
- **No harness change.** Do not edit `ReentrantERC20Harness.sol`. The PRD AC 3 (line 35) says "Reuse `ReentrantERC20Harness` unchanged." The harness is a non-SUT stub; modifying it would expand scope and re-open a closed choice.
- **No bare `expectRevert()`.** Do not replace either test with a bare `expectRevert()`. The PRD R1 non-goal (line 37) says "Do not replace either test with a bare `expectRevert()`."
- **No rewriting newly selected tests to make `--check` pass.** The PRD R3 AC 2 (line 76) says "A nonzero `--check` result caused only by existing bare `expectRevert()` calls in newly selected directories is the expected end state of this item. Do not rewrite those tests here, and do not drop a directory to make the check pass." The implementer records the new bare-`expectRevert()` findings; they do not fix them.
- **No weaker bytecode check.** The PRD R3 non-goal (line 81) and the whole-draft non-goal (line 89) say the production bytecode check stays unchanged. Do not weaken `RebasingAwareStandardYieldTarget.sol:57-59` or any other guard.
- **No second selection list or external inventory file.** The PRD R3 AC 1 (line 75) says "Do not add a second selection list or an external inventory file." The implementer extends the existing `roots` tuple.
- **No broader fuzz domain.** The PRD R2 non-goal (line 48) says "Do not widen the fuzz domain." The implementer adds one assertion to the existing test, not new fuzz inputs.
- **No live-instance change.** The whole-draft non-goal (line 89) says "No live-instance change."
- **No making the outer selector `IsLocked` on the rollback test.** The PRD R1 non-goal (line 37) says "Do not make the outer selector `IsLocked`." The rollback test's outer `expectRevert(TransferFromFailed)` at line 140 stays.
- **No requiring one call both to revert and to leave a readable record.** The PRD R1 non-goal (line 37) says "Do not require one call both to revert and to leave a readable record." The two tests are separate; each does one thing.
- **No Forge run in this plan-writing session.** The plan is written without execution. The implementer runs the commands above in the implementation session and reports results.

## Order

| Step | Work | Files | Why this order |
|---|---|---|---|
| 1 | Add `nestedAttempted` and `nestedReason` fields to the test contract | `RebasingAwareERC4626_Adversarial.t.sol` | The fields must exist before the callback or the test can write/read them |
| 2 | Add `recordNestedDeposit` callback | `RebasingAwareERC4626_Adversarial.t.sol` | The callback depends on the fields from step 1 |
| 3 | Add `test_ADV03_observation_nestedGuardPin` | `RebasingAwareERC4626_Adversarial.t.sol` | The test depends on the fields from step 1 and the callback from step 2 |
| 4 | (no edit) leave the rollback test unchanged | `RebasingAwareERC4626_Adversarial.t.sol` | The PRD requires the rollback test to stay |
| 5 | Add one `assertEq` line to the success half | `RebasingAwareERC4626_Fuzz.t.sol` | R2 is a separate requirement; do it after R1 so the implementer focuses on one file at a time |
| 6 | Extend the `roots` tuple in the listed order | `scripts/apex_bare_expectrevert_scan.sh` | R3 is a separate requirement; do it after R1 and R2 so the test edits compile and run before the scanner change |
| 7 | Run `forge build`, then the three `forge test` invocations, then the two `bash scripts/...` invocations | n/a | Acceptance verification |

The order within R1 (steps 1-3) is structural: fields, callback, test. The order between R1, R2, R3 is by file independence: R1 touches `Adversarial.t.sol`; R2 touches `Fuzz.t.sol`; R3 touches the scanner. They can be done in any order. The plan sequences R1 → R2 → R3 for clarity.

## Done when

- **R1:** `RebasingAwareERC4626_Adversarial.t.sol` has two new state fields, a new `recordNestedDeposit` callback, and a new `test_ADV03_observation_nestedGuardPin` test. The existing `observeNestedDeposit` and `test_ADV03_reentrancyDuringDepositReverts` are unchanged. The new test passes; the existing test passes. No production change. No harness change.
- **R2:** `RebasingAwareERC4626_Fuzz.t.sol` has one new `assertEq` line in the success half of `testFuzz_FUZZ02_exactOutMinimals`. The test passes. The fuzz domain is unchanged.
- **R3:** `scripts/apex_bare_expectrevert_scan.sh` has the `roots` tuple extended in the listed order. The scanner's first run shows a higher bare-`expectRevert()` count than before. The `--check` exit code is 1. The `custody` tuple and the APEX-marker scan are unchanged.
- **Whole draft:** No production change. No weaker bytecode check. No broader `expectRevert()`. No live-instance change. The implementer reports the commands actually run, the toolchain, and any test that did not pass.

I did not run Forge.