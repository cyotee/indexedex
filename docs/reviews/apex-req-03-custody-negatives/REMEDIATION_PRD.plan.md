# Implementation plan — close the remaining REQ-03 custody-test gaps

- **Date:** 2026-10-15
- **Status:** IMPLEMENTED on user instruction, 2026-10-15. Step 4 executed; results and the scanner baseline discrepancy are recorded in [EXECUTION_REPORT.md](./EXECUTION_REPORT.md).
- **Controlling PRD:** [REMEDIATION_PRD.md](./REMEDIATION_PRD.md). Where this plan conflicts with that PRD, the PRD controls.
- **ID:** REQ-03. This plan closes REQ-03-R1, REQ-03-R2, and REQ-03-R3. It does not reopen ownership, the minimality rejection, or the bytecode check.
- **Council:** Astra `ses_ec412bcc2ffejKLo7nuoEAqbV0`, Grok `ses_ec4128917ffeeVds3Y2p7xrVjp`, MiniMax M3 `ses_ec41255ceffeVhrySLQe8hwwMC`, and Kimi K3 replacement `ses_ec3d04e91ffeJa0is24e2jZv06`. Kimi does not recall `ses_ec41220c2ffeqs5Eha7fPsd54B`. Astra answered both turns and was not censored. No Forge run. Consensus is not proof.
- **Drafts:** `reviewers/astra-plan.md`, `reviewers/grok-plan.md`, `reviewers/minimax-plan.md`, `reviewers/kimi-plan.md`, and the four `*-plan-cross.md` files. Those drafts are inputs. This file is the consolidation.

## Objective

Add one observation test that lets the outer deposit finish and then reads a surviving nested-guard record. Keep the existing rollback test. Add one total-supply assertion to the exact-output success half. Append the PRD directory list to the scanner's existing `roots` tuple. Do not change production code. Do not make `--check` pass by rewriting newly selected tests.

## What not to do

- Do not edit production source, including pull wrapping, minting, and the bytecode check at `RebasingAwareStandardYieldTarget.sol:57-59`.
- Do not edit `contracts/test/stubs/ReentrantERC20Harness.sol`. Do not add an event, a second contract, or a harness flag.
- Do not set `bubbleRevert` false. Do not leave it unset in the observation test. Call `tok.setBubbleRevert(true)`.
- Do not add `nestedOk`. Do not end `recordNestedDeposit` with an assembly return. A normal function end is the return.
- Do not assert that recipient shares equal `10e18`. The deploy call passes offset `10`. Shares are not one-for-one with assets.
- Do not change `observeNestedDeposit` or `test_ADV03_reentrancyDuringDepositReverts`. Do not make the outer selector `IsLocked`.
- Do not add a bare `vm.expectRevert()`. Do not replace either ADV03 test with one.
- Do not widen the fuzz domain or rewrite the rejection half.
- Do not add a second scanner list, an external inventory file, or a directory that is not listed. Do not drop a listed directory. Do not sort the tuple.
- Do not rewrite a newly selected test to make `--check` exit 0. A nonzero `--check` caused only by existing bare `expectRevert()` calls in newly selected directories is the expected end state of REQ-03-R3.
- Do not hand-edit `docs/audits/apex-2026-09-17-evidence/bare-expectrevert.txt`.

## Files a later session may edit

1. `test/foundry/spec/protocols/staking/rebasingVault/RebasingAwareERC4626_Adversarial.t.sol`
2. `test/foundry/spec/protocols/staking/rebasingVault/RebasingAwareERC4626_Fuzz.t.sol`
3. `scripts/apex_bare_expectrevert_scan.sh`

## Order

| Step | Work | Why this order |
| --- | --- | --- |
| 1 | Add the observation fields, callback, and test | The rollback test must stay untouched beside it. |
| 2 | Add the success-half total-supply assertion | Separate file. Do it after the adversarial edit so each file is finished once. |
| 3 | Append the listed directories to `roots` | Script-only. Do not use its result to rewrite tests. |
| 4 | Run the named commands and report the scanner's nonzero `--check` | A present assertion is not a pass until that run is reported. |

## Step 1 — observation test

Edit only `RebasingAwareERC4626_Adversarial.t.sol`.

Leave `observeNestedDeposit` at lines 28-33 unchanged, including its final `revert IReentrancyLock.IsLocked()`. Leave `test_ADV03_reentrancyDuringDepositReverts` at lines 128-147 unchanged, including `SafeTransferLib.TransferFromFailed` and the four no-partial-credit assertions.

Immediately after the contract's opening brace, add:

```solidity
bool internal nestedAttempted;
bytes internal nestedReason;
```

Immediately after `observeNestedDeposit`, add:

```solidity
function recordNestedDeposit(address wrapped, address receiver) external {
    (, bytes memory reason) = wrapped.call(abi.encodeCall(IERC4626.deposit, (uint256(1e18), receiver)));
    nestedAttempted = true;
    nestedReason = reason;
}
```

The low-level call matches the existing observer: same vault, same `1e18` nested amount, same receiver. The success flag is discarded. The callback does not assert and does not revert.

Immediately after `test_ADV03_reentrancyDuringDepositReverts`, add `test_ADV03_nestedDepositIsLocked_outerDepositCompletes`. Use the rollback fixture except for the callback. Salt stays `bytes32(uint256(123))`. Offset stays `10`. Outer amount stays `10e18`. Funding stays `100e18`.

```solidity
function test_ADV03_nestedDepositIsLocked_outerDepositCompletes() public {
    ReentrantERC20Harness tok = new ReentrantERC20Harness("R", "R", 18);
    IERC4626 wrapped = pkg.deployVault(IERC20Metadata(address(tok)), 10, bytes32(uint256(123)));
    tok.mint(alice, 100e18);
    tok.setReenter(address(this), abi.encodeCall(this.recordNestedDeposit, (address(wrapped), alice)));
    tok.setBubbleRevert(true);
    nestedAttempted = false;
    delete nestedReason;
    uint256 depositAssets = 10e18;
    uint256 expectedShares = wrapped.previewDeposit(depositAssets);
    uint256 supplyBefore = IERC20(address(wrapped)).totalSupply();
    uint256 aliceSharesBefore = IERC20(address(wrapped)).balanceOf(alice);
    uint256 aliceAssetsBefore = tok.balanceOf(alice);
    uint256 vaultAssetsBefore = tok.balanceOf(address(wrapped));
    assertGt(expectedShares, 0, "previewed shares");
    vm.startPrank(alice);
    tok.approve(address(wrapped), type(uint256).max);
    uint256 minted = wrapped.deposit(depositAssets, alice);
    vm.stopPrank();
    assertGt(minted, 0, "outer deposit finished");
    assertEq(minted, expectedShares, "outer deposit matches preview");
    assertEq(IERC20(address(wrapped)).balanceOf(alice), aliceSharesBefore + minted, "recipient shares are the outer mint");
    assertEq(IERC20(address(wrapped)).totalSupply(), supplyBefore + minted, "supply grew by the outer mint");
    assertEq(tok.balanceOf(alice), aliceAssetsBefore - depositAssets, "caller paid the outer assets");
    assertEq(tok.balanceOf(address(wrapped)), vaultAssetsBefore + depositAssets, "vault received the outer assets");
    assertTrue(nestedAttempted, "nested deposit was attempted");
    assertEq(nestedReason, abi.encodeWithSelector(IReentrancyLock.IsLocked.selector), "nested guard is IsLocked");
}
```

The locked contract is `wrapped`, the rebasing vault under test. The nested call is a second `deposit` on that same vault. It is not an underlying vault and not a Wings vault.

If this test fails because `nestedReason` is not `IReentrancyLock.IsLocked`, stop and report that result. Do not change production code or the harness to make it pass.

## Step 2 — total supply on exact success

In `RebasingAwareERC4626_Fuzz.t.sol`, after the existing assertion at line 100 and before the function's closing brace, add exactly:

```solidity
assertEq(IERC20(address(vault)).totalSupply(), supplyBefore + shares, "exact funding increases supply by the quoted shares");
```

`supplyBefore` is the value already captured at line 65. `shares` is the requested fuzz amount. The success half runs after `vm.revertToState(snap)` at line 85, so that captured supply is the baseline. Do not move or rewrite lines 57-100. Do not change the fuzz bounds.

## Step 3 — scanner roots

In `scripts/apex_bare_expectrevert_scan.sh`, replace only the `roots` tuple at lines 14-17 with this tuple, in this order. Do not sort it.

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

Leave the `custody` tuple, the APEX-marker scan, the bare-call regex, the report path, and the `--check` exit behavior unchanged. Both Balancer spellings stay. If a listed path is absent, stop and report that path. Do not substitute or drop it.

## Step 4 — commands a later session runs

**Execution record, 2026-10-15:** All six commands below were run. Both test suites passed (25 tests total) after an approved retry outside the sandbox; the initial invocation compiled successfully but Forge crashed before test execution. The plain scanner exited 0; `--check` exited 1 with 317 existing sites, including both required files. Of those sites, 9 were already selected and 308 were newly selected. See the [command results and toolchain](./EXECUTION_REPORT.md), [passing Forge log](./evidence/forge-test-retry.txt), and [complete scanner output](./evidence/scanner-check.txt). The original logs were preserved from the implementation session; this documentation update did not rerun Forge.

From the repository root, default Foundry profile. Do not set `FOUNDRY_PROFILE=fork`. Do not enable `via_ir`. Do not delete `out/` or `cache_forge/`.

This item edits no production source. The tests still deploy packages whose creation bytecode is read from `out/`. `scripts/forge-artifacts.py` accepts `sources` as optional (`nargs="*"`) and `test` requires `--test-root` (`scripts/forge-artifacts.py:390-402`). Use that helper so the two test files are the consumers. Do not pass a production path.

```bash
git diff --check
bash -n scripts/apex_bare_expectrevert_scan.sh
python3 scripts/forge-artifacts.py plan \
  --test-root test/foundry/spec/protocols/staking/rebasingVault/RebasingAwareERC4626_Adversarial.t.sol \
  --test-root test/foundry/spec/protocols/staking/rebasingVault/RebasingAwareERC4626_Fuzz.t.sol
python3 scripts/forge-artifacts.py test \
  --test-root test/foundry/spec/protocols/staking/rebasingVault/RebasingAwareERC4626_Adversarial.t.sol \
  --test-root test/foundry/spec/protocols/staking/rebasingVault/RebasingAwareERC4626_Fuzz.t.sol \
  -- -vv
bash scripts/apex_bare_expectrevert_scan.sh
bash scripts/apex_bare_expectrevert_scan.sh --check
```

The helper's `test` action must pass both test files. The plain scanner run must list a site in `test/foundry/spec/vaults/standard/erc4626/ERC4626StandardExchange_Routes.t.sol` and a site in `test/foundry/spec/protocols/staking/rebasingVault/RebasingAwareERC4626_Accounting.t.sol`.

`--check` is expected to exit nonzero when those existing bare calls are selected. Record that exit and the site list. Do not edit a selected test, drop a root, or change the regex to make it exit 0. A compiler failure, a Solidity test failure, a missing directory, or a scanner syntax error is not that expected nonzero result. Stop and report it.

Report the commands actually run, the toolchain, and every result. A present assertion is not a pass until that run is reported.

## Done when

- `test_ADV03_nestedDepositIsLocked_outerDepositCompletes` exists, uses `recordNestedDeposit`, keeps `bubbleRevert` true, and asserts the previewed outer mint plus the surviving `IsLocked` record.
- `observeNestedDeposit` and `test_ADV03_reentrancyDuringDepositReverts` are unchanged.
- The fuzz success half asserts `totalSupply == supplyBefore + shares`, and the existing assertions remain.
- The `roots` tuple is the seventeen paths above, in that order. The `custody` tuple and the APEX-marker scan are unchanged.
- The two test files passed through the helper. The scanner report lists the two cited files. The nonzero `--check` exit is recorded and was not "fixed" by rewriting tests.
- No production file and no harness file changed.

## Dissent recorded, not adopted

- MiniMax's plan used an assembly return, left `bubbleRevert` unset, and asserted the recipient balance equals `10e18`. Astra, Grok, and Kimi's cross-review reject all three. The offset argument is `10`.
- Kimi's first plan set `bubbleRevert` false and added `nestedOk`. Kimi's cross-review withdrew both. The PRD names two fields and says keep `bubbleRevert` true.
- MiniMax's cross-review preferred the shorter test name `test_ADV03_nestedGuardObserved`, salt `124`, and optional asset-delta assertions. This plan uses Astra's test name, salt `123`, and the full settlement witness. Those are closed here.
- Astra and Grok's cross-review preferred `private` fields. MiniMax and Kimi preferred `internal`. This plan closes on `internal`. `private` is behaviorally the same in this contract and is not an implementer option.
- MiniMax and Kimi preferred plain `forge test` because no production source changes. This plan uses `forge-artifacts.py` with no production path, because the tests deploy from `out/` and the helper accepts that consumer-only form (`docs/testing/ARTIFACT_BUILDS.md:30-41`, `scripts/forge-artifacts.py:390-402`).

The plan authors did not run Forge. The subsequent implementation session did; see [EXECUTION_REPORT.md](./EXECUTION_REPORT.md) for its results and preserved logs.
