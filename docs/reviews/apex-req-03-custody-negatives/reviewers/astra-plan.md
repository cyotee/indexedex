# Astra independent implementation-plan draft — REQ-03

**Date:** 2026-10-14 review round. **Status:** Draft; does not authorize implementation or execution.

**Controlling PRD:** `docs/reviews/apex-req-03-custody-negatives/REMEDIATION_PRD.md`, re-read in full. It controls over this plan. All four requested current files were read in full. No peer notes or coordinator implementation plan were read. Only this assigned Markdown draft is written.

## Scope and fixed choices

Later implementation edits exactly these three files:

1. `test/foundry/spec/protocols/staking/rebasingVault/RebasingAwareERC4626_Adversarial.t.sol`
2. `test/foundry/spec/protocols/staking/rebasingVault/RebasingAwareERC4626_Fuzz.t.sol`
3. `scripts/apex_bare_expectrevert_scan.sh`

The callback fixture `contracts/test/stubs/ReentrantERC20Harness.sol` is read-only. The existing TestBase/registry deployment remains the deployment path.

R1's two-call design, test-contract record, callback name, and unchanged harness are already prescribed at PRD lines 31-36. R2's exact additional assertion is prescribed at 45-48. R3's inventory, tuple representation, ordering, and expected nonzero scanner result are prescribed at 56-80.

The PRD does not explicitly name the observation test, field visibility/types, reset, or concrete outer-success oracle. This draft fixes those details below, leaving no choice to the later implementer. To make the PRD itself equally explicit, add this sentence:

> Add `test_ADV03_nestedDepositIsLocked_outerDepositCompletes` with private fields `bool nestedAttempted` and `bytes nestedReason`, clear both before its outer call, reuse the existing rollback fixture's funding and deposit quantities, and after the unwrapped successful deposit assert the positive returned shares equal its pre-call preview, the exact corresponding recipient-share and total-supply increases, the exact caller-asset debit and vault-asset credit, `nestedAttempted == true`, and `nestedReason == abi.encodeWithSelector(IReentrancyLock.IsLocked.selector)`.

This is a proposed specification sentence, not a PRD edit. No product decision remains; the concrete instructions in this draft select the remaining mechanical details rather than offering alternatives.

## Ordered implementation

### 1. Preserve the existing rollback and ownership controls

In the adversarial file, leave these bodies unchanged:

- `observeNestedDeposit` at current lines 28-32;
- `test_ADV03_reentrancyDuringDepositReverts` at 128-146, including its `TransferFromFailed` expectation and all four rollback assertions;
- the ownership test at 50-60 and the separate contract-caller control at 113-125.

Do not reuse the reverting observer for the successful observation test. Its record would not survive a reverted outer operation. Do not make the outer rollback error `IsLocked`.

### 2. Add the R1 record and non-reverting callback

At contract scope in `RebasingAwareERC4626_Adversarial`, add exactly:

```solidity
bool private nestedAttempted;
bytes private nestedReason;
```

Add the external callback `recordNestedDeposit(address wrapped, address receiver)` beside the existing observer. Use the same low-level nested deposit call already present at line 29; do not change its target, recipient, or existing fixture quantity. Store the returned bytes in `nestedReason` and set `nestedAttempted = true`. Do not assert or deliberately revert inside this callback. Do not introduce an event, recorder contract, alternate harness, or production selector.

Keep `ReentrantERC20Harness` unchanged and set `bubbleRevert` true. Its current `_callback` returns when the callback succeeds (`ReentrantERC20Harness.sol:68-75`); no toggle-based swallowing or harness edit is needed.

The expected record is the complete ABI-encoded guard error, not just an arbitrary revert or nonempty bytes. A successful nested deposit returns the deposit's normal return data rather than that exact guard-error encoding and must fail the post-call comparison.

### 3. Add the separate observation test and exact outer-success witness

Name the public test:

`test_ADV03_nestedDepositIsLocked_outerDepositCompletes`

Use the same fixture construction, registry package deployment, caller, token funding, approvals, deployment arguments, and outer deposit quantity as the current rollback test at lines 129-141. Point only this new test's callback at `recordNestedDeposit`. Do not refactor or change the existing rollback test to share setup.

Before the outer call:

1. Set `nestedAttempted = false` and `delete nestedReason`.
2. Name the outer deposit quantity `depositAssets`; assign the existing rollback test's outer deposit quantity, not a new test parameter.
3. Read `expectedShares = wrapped.previewDeposit(depositAssets)` before execution and require it to be positive.
4. Capture `supplyBefore`, `aliceSharesBefore`, `aliceAssetsBefore`, and `vaultAssetsBefore` from the newly deployed wrapped vault and its funding token.

Perform the ordinary production `wrapped.deposit(depositAssets, alice)` under Alice's caller context and capture its returned value as `minted`. Use no `expectRevert`, low-level outer call, or catch around this deposit. Restore the caller context before post-call assertions.

The exact outer-success witness is:

```solidity
assertGt(minted, 0);
assertEq(minted, expectedShares);
assertEq(IERC20(address(wrapped)).balanceOf(alice), aliceSharesBefore + minted);
assertEq(IERC20(address(wrapped)).totalSupply(), supplyBefore + minted);
assertEq(tok.balanceOf(alice), aliceAssetsBefore - depositAssets);
assertEq(tok.balanceOf(address(wrapped)), vaultAssetsBefore + depositAssets);
assertTrue(nestedAttempted);
assertEq(nestedReason, abi.encodeWithSelector(IReentrancyLock.IsLocked.selector));
```

These are defensive assertion specifications, not a standalone callback implementation or call payload. The positive return and exact deltas establish completed outer settlement; the surviving record establishes the nested guard result. Absence of the callback, a different nested error, or nested success must not be interpreted as acceptance.

### 4. Add only R2's successful total-supply assertion

In `RebasingAwareERC4626_Fuzz.t.sol`, keep the complete rejection half, snapshot restoration, fuzz bounds, and existing success assertions at current lines 57-100 unchanged.

Immediately after the existing successful recipient-share assertion at line 97, add:

```solidity
assertEq(
    IERC20(address(vault)).totalSupply(),
    supplyBefore + shares,
    "exact funding mints only the requested supply"
);
```

Use the existing `supplyBefore` captured at line 65 and the already-bounded `shares` parameter. No new snapshot, mint calculation, production change, or fuzz-domain expansion is required.

### 5. Extend R3's existing roots tuple in exactly this order

Replace only the `roots` tuple at `scripts/apex_bare_expectrevert_scan.sh:14-17` with these seventeen entries; the first two retain their current order:

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

Leave `custody`, the APEX-marker inclusion, recursive `*.sol` enumeration, deduplication, comment/literal stripping, line reporting, output path, and `--check` failure behavior unchanged (`:18-46`). Do not add a parallel list, manifest, discovery heuristic, or path spelling correction. If a listed path is absent at implementation time, stop and report that fact; do not substitute or silently drop it.

### 6. Verification commands for the separately authorized session

Run from the repository root, in this order. These commands are planned, not executed by this review.

First review the scoped diff and check shell syntax:

```sh
git diff --check
git diff -- test/foundry/spec/protocols/staking/rebasingVault/RebasingAwareERC4626_Adversarial.t.sol test/foundry/spec/protocols/staking/rebasingVault/RebasingAwareERC4626_Fuzz.t.sol scripts/apex_bare_expectrevert_scan.sh
bash -n scripts/apex_bare_expectrevert_scan.sh
```

Inspect artifact selection, then refresh runtime artifacts and execute both complete affected test suites:

```sh
python3 scripts/forge-artifacts.py plan \
  --test-root test/foundry/spec/protocols/staking/rebasingVault/RebasingAwareERC4626_Adversarial.t.sol \
  --test-root test/foundry/spec/protocols/staking/rebasingVault/RebasingAwareERC4626_Fuzz.t.sol

python3 scripts/forge-artifacts.py test \
  --test-root test/foundry/spec/protocols/staking/rebasingVault/RebasingAwareERC4626_Adversarial.t.sol \
  --test-root test/foundry/spec/protocols/staking/rebasingVault/RebasingAwareERC4626_Fuzz.t.sol \
  -- -vv
```

`docs/testing/ARTIFACT_BUILDS.md:14-22,30-43` describes the build-before-test workflow. The helper accepts optional source arguments and repeatable test roots (`scripts/forge-artifacts.py:390-414`); there is no edited production source to pass here. Run with the existing default hermetic configuration. Do not change profiles, configured test paths, fuzz settings, or `via_ir`. Retain existing artifacts/cache and wait for compilation to finish.

Finally run the scanner and record its actual exit status without masking failure:

```sh
bash scripts/apex_bare_expectrevert_scan.sh --check
```

This command writes the scanner's existing report at `docs/audits/apex-2026-09-17-evidence/bare-expectrevert.txt` (`scanner:39-41`). That generated evidence update is expected; do not hand-edit it to manufacture a clean result. Inspect the output and record newly selected existing violations. A nonzero result due to those violations is the PRD-specified end state, not a reason to alter selection or repair additional tests. A syntax error, missing-file problem, or failed Solidity test is not that expected outcome and must be reported separately.

Repeat `git diff --check` after verification. Report actual commands, results, toolchain, any failures, and the distinction between the two-suite runtime result and the scanner's expected violations. Do not claim all selected D16 tests were executed merely because they were scanned.

## What not to do

- No production source, bytecode guard, lock, transfer wrapper, package, or registry change.
- No harness change, replacement SUT, external observation recorder, or event-based record.
- No assertion/revert inside `recordNestedDeposit`; its observation is checked after successful outer settlement.
- No change to the existing reverting observer or rollback test; no outer `IsLocked` expectation.
- No bare or broader `expectRevert()` and no suppression of failed test assertions.
- No ownership-test rewrite, extra fuzz scenario, or fuzz-domain change.
- No scanner inventory additions, removals, second list, external manifest, marker change, or output-format redesign.
- No rewriting newly selected tests to make `--check` pass; no removing directories to achieve a clean report.
- No deployment, live-instance action, configuration edit, cache deletion, or broad audit expansion.

## Done when

1. The named observation test uses the prescribed two private fields and non-reverting callback, and checks the exact successful outer settlement plus exact nested guard result after the call.
2. The unchanged rollback test still checks the wrapped failure and no partial credit.
3. The minimality success half contains the exact total-supply assertion while its existing assertions remain intact.
4. The scanner's existing roots tuple contains the seventeen paths in the prescribed order; all other selection/detection behavior remains intact.
5. Both affected Solidity suites have reported results following artifact preparation, and the scanner's output/status is reported honestly, including expected existing violations.
6. No edits beyond the three authorized implementation files and normal generated verification artifacts were used to obtain acceptance.

No implementer choice remains in this draft. The proposed PRD sentence above makes the few remaining unnamed test details explicit if the coordinator requires the PRD itself, rather than this plan, to carry them.

I did not run Forge.
