# Grok plan — REQ-03 custody negatives

- **Date:** 2026-10-15
- **PRD:** `docs/reviews/apex-req-03-custody-negatives/REMEDIATION_PRD.md`, re-read in full this turn.
- **This file is a plan.** It does not authorize the edits. A later session must be explicitly asked to implement it.
- **Files a later session may edit:** `test/foundry/spec/protocols/staking/rebasingVault/RebasingAwareERC4626_Adversarial.t.sol`, `test/foundry/spec/protocols/staking/rebasingVault/RebasingAwareERC4626_Fuzz.t.sol`, and `scripts/apex_bare_expectrevert_scan.sh`.
- **Files it must not edit:** every production contract, `contracts/test/stubs/ReentrantERC20Harness.sol`, every newly selected test, and this PRD.

## Choices the PRD still leaves

Three choices remain. The steps below already use the closing sentences. A later session follows those steps and does not pick again.

1. **REQ-03-R1 test name.** Line 34 says "the observation test" and names `recordNestedDeposit`. It does not name the test function.
   - **Sentence to add:** The observation test function is `test_ADV03_nestedGuardObserved` in `RebasingAwareERC4626_Adversarial.t.sol`, placed immediately after `test_ADV03_reentrancyDuringDepositReverts`.
2. **REQ-03-R1 field declarations.** Line 34 names `nestedAttempted` and `nestedReason`. It does not declare the types or visibility.
   - **Sentence to add:** On `RebasingAwareERC4626_Adversarial`, declare `bool internal nestedAttempted` and `bytes internal nestedReason`.
3. **REQ-03-R1 finish witness.** Line 34 says the outer deposit finishes, then the test asserts the two fields. It does not say which assertion proves the deposit finished. A zero return would leave supply unchanged and still reach the field assertions if the callback returned.
   - **Sentence to add:** In `test_ADV03_nestedGuardObserved`, bind `uint256 minted = wrapped.deposit(10e18, alice)` and assert `minted > 0` and `IERC20(address(wrapped)).totalSupply() == supplyBefore + minted` with the message `outer deposit finished`. Do not put `vm.expectRevert` on that call. Assert `nestedAttempted` and `nestedReason` only after that witness.

No other choice remains. The callback name, the low-level `deposit` call, `bubbleRevert == true`, the rollback test, the total-supply formula, and the `roots` tuple order are already in the PRD.

## Do not

- Do not change production code, including pull wrapping, minting, and the bytecode check at `RebasingAwareStandardYieldTarget.sol:57-59`.
- Do not edit `ReentrantERC20Harness`. Do not add a harness flag, event, or second contract for the record.
- Do not make the outer selector `IsLocked`. Do not mock the vault.
- Do not add a bare `vm.expectRevert()`. Do not replace either ADV03 test with one.
- Do not revert inside `recordNestedDeposit`. Do not assert inside it. The rollback callback `observeNestedDeposit` keeps its revert.
- Do not point `test_ADV03_reentrancyDuringDepositReverts` at `recordNestedDeposit`.
- Do not change the fuzz bounds, the rejection half, or the four existing success assertions in `testFuzz_FUZZ02_exactOutMinimals`.
- Do not add a second scanner list, an external inventory file, or a directory that is not listed. Do not drop a listed directory.
- Do not rewrite a newly selected test, or any other test, to make `--check` exit 0. A nonzero `--check` caused only by existing bare `expectRevert()` calls in newly selected directories is the expected end state of REQ-03-R3.
- Do not edit the scanner comment, the `custody` tuple, or the APEX-marker scan.

## Step 1 — REQ-03-R1 observation test

Edit only `RebasingAwareERC4626_Adversarial.t.sol`.

Leave `observeNestedDeposit` at lines 26-33 unchanged, including its final `revert IReentrancyLock.IsLocked()`. Leave `test_ADV03_reentrancyDuringDepositReverts` at lines 128-147 unchanged, including `SafeTransferLib.TransferFromFailed` and the four no-partial-credit assertions.

Immediately after the contract's opening brace, add:

```solidity
bool internal nestedAttempted;
bytes internal nestedReason;
```

Immediately after `observeNestedDeposit`, add this callback. It keeps that function's low-level call and amount. It discards the success flag so the callback has no assertion and no revert.

```solidity
function recordNestedDeposit(address wrapped, address receiver) external {
    (, bytes memory reason) = wrapped.call(abi.encodeCall(IERC4626.deposit, (uint256(1e18), receiver)));
    nestedAttempted = true;
    nestedReason = reason;
}
```

Immediately after `test_ADV03_reentrancyDuringDepositReverts`, add:

```solidity
function test_ADV03_nestedGuardObserved() public {
    ReentrantERC20Harness tok = new ReentrantERC20Harness("R", "R", 18);
    IERC4626 wrapped = pkg.deployVault(IERC20Metadata(address(tok)), 10, bytes32(uint256(123)));
    tok.mint(alice, 100e18);
    tok.setReenter(address(this), abi.encodeCall(this.recordNestedDeposit, (address(wrapped), alice)));
    tok.setBubbleRevert(true);
    uint256 supplyBefore = IERC20(address(wrapped)).totalSupply();
    vm.startPrank(alice);
    tok.approve(address(wrapped), type(uint256).max);
    uint256 minted = wrapped.deposit(10e18, alice);
    vm.stopPrank();
    assertGt(minted, 0, "outer deposit finished");
    assertEq(IERC20(address(wrapped)).totalSupply(), supplyBefore + minted, "outer deposit finished");
    assertTrue(nestedAttempted, "nested deposit was attempted");
    assertEq(nestedReason, abi.encodeWithSelector(IReentrancyLock.IsLocked.selector), "nested guard is IsLocked");
}
```

`bubbleRevert` stays true. The harness bubbles only when the callback call fails. `recordNestedDeposit` returns, so the outer `deposit` can finish without a harness edit. The locked contract is `wrapped`, the vault under test. The nested call is a second `deposit` on that same vault.

## Step 2 — REQ-03-R2 total supply

Edit only the success half of `testFuzz_FUZZ02_exactOutMinimals`. After the existing assertion at line 100, and before the function's closing brace, add exactly:

```solidity
assertEq(IERC20(address(vault)).totalSupply(), supplyBefore + shares, "exact funding increases supply by the quoted shares");
```

`supplyBefore` is the value already captured at line 65. `shares` is the requested fuzz amount. Do not move or rewrite lines 80-84 or 96-100.

## Step 3 — REQ-03-R3 roots tuple

In `scripts/apex_bare_expectrevert_scan.sh`, replace only the `roots` tuple at lines 14-17 with this tuple, in this order. The first two paths are the roots already selected. The rest follow the PRD list.

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

Leave the `custody` tuple and the APEX-marker loop as they are. Both Balancer spellings stay. Do not sort the tuple.

## Step 4 — commands a later session runs

From the repo root, default Foundry profile. Do not set `FOUNDRY_PROFILE=fork`. Focus with `--match-path` and `--match-test` only.

```bash
forge build
forge test --match-path test/foundry/spec/protocols/staking/rebasingVault/RebasingAwareERC4626_Adversarial.t.sol --match-test test_ADV03_nestedGuardObserved
forge test --match-path test/foundry/spec/protocols/staking/rebasingVault/RebasingAwareERC4626_Adversarial.t.sol --match-test test_ADV03_reentrancyDuringDepositReverts
forge test --match-path test/foundry/spec/protocols/staking/rebasingVault/RebasingAwareERC4626_Fuzz.t.sol --match-test testFuzz_FUZZ02_exactOutMinimals
scripts/apex_bare_expectrevert_scan.sh
scripts/apex_bare_expectrevert_scan.sh --check
```

The two ADV03 commands and the fuzz command must pass. `forge build` must pass. The scanner command without `--check` must print a site in `test/foundry/spec/vaults/standard/erc4626/ERC4626StandardExchange_Routes.t.sol` and a site in `test/foundry/spec/protocols/staking/rebasingVault/RebasingAwareERC4626_Accounting.t.sol`. Those lines show the new roots selected the two cited files.

`--check` is expected to exit nonzero when those existing bare calls are selected. Record that exit. Do not edit a selected test, drop a root, or change the bare-call regex to make it exit 0. The repo's later PR gate remains default-profile `forge test`. That gate does not include making this `--check` clean.

## After the three sentences

A session that implements the steps above has no remaining choice. The three sentences belong in the PRD so that plan is not the only place they exist.

I did not run Forge.
