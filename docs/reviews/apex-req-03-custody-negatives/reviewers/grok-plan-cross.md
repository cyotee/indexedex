# Grok plan cross-review — REQ-03

- **Date:** 2026-10-15
- **Peers:** `astra-plan.md`, `minimax-plan.md`, `kimi-plan.md`. Untrusted. Not edited.
- **PRD:** `docs/reviews/apex-req-03-custody-negatives/REMEDIATION_PRD.md` lines 31-36. Not edited.
- **Rejected shapes:** `bubbleRevert` false, an assembly return, a `nestedOk` field, and recipient shares asserted equal to `10e18`.

## Rejected

- **Kimi.** `test_ADV03_observation_nestedDepositRejectedIsLocked` calls `tok.setBubbleRevert(false)`. The PRD says keep `bubbleRevert` true and point only the observation test at `recordNestedDeposit`. The harness default is false, so this call is the opposite of the ruling. The same draft adds `bool internal nestedOk` and asserts it. The PRD names two fields, `nestedAttempted` and `nestedReason`. A nested success already fails the reason equality. Do not add `nestedOk`.
- **MiniMax.** `recordNestedDeposit` ends in `assembly ("memory-safe") { return(0, 0) }`. The PRD says the callback returns without an assertion and without a revert. A normal function end does that. Do not add an assembly return. The same draft never calls `setBubbleRevert(true)` on the observation harness, then says a later maintainer may add it. That leaves the PRD sentence optional. The observation test must call `tok.setBubbleRevert(true)`.
- **MiniMax.** `assertEq(IERC20(address(wrapped)).balanceOf(alice), 10e18)` treats the outer deposit amount as the share amount. The fixture deploys with offset `10` (`RebasingAwareERC4626_Adversarial.t.sol:130`). Do not assert recipient shares equal `10e18`.
- **MiniMax.** The test name is left open, and the draft allows renaming `test_ADV03_reentrancyDuringDepositReverts`. Do not rename the rollback test.

The roots tuple is the same in all three drafts. That part is agreed and is not reopened. The R2 formula `supplyBefore + shares` is agreed. Use Astra's message, `exact funding mints only the requested supply`, immediately after the recipient-share assertion at `RebasingAwareERC4626_Fuzz.t.sol:97`.

## Closed set

Use this set. Do not mix it with the rejected drafts.

- **Test function:** `test_ADV03_nestedDepositIsLocked_outerDepositCompletes`
- **Fields:** `bool private nestedAttempted` and `bytes private nestedReason`. Not `public`. Not `internal`. No third field.
- **Callback:** `recordNestedDeposit` uses the same low-level `deposit` call as `observeNestedDeposit`, writes the two fields, and returns. No assertion, no revert, no assembly return.
- **Salt:** `bytes32(uint256(123))`, the rollback fixture's salt. Each Foundry test has its own state, so `124` and `234` are not required. Do not pick another salt.
- **Harness:** `tok.setBubbleRevert(true)` in the observation test. The rollback test stays on `observeNestedDeposit`.
- **Success witness,** after `uint256 minted = wrapped.deposit(depositAssets, alice)`, with `depositAssets` equal to the rollback test's `10e18` and `expectedShares` taken from `wrapped.previewDeposit(depositAssets)` before the call:

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

Clear both fields before the outer call. Do not wrap that deposit in `expectRevert`.

## Commands

One sequence, from the repo root. No production path. No `FOUNDRY_PROFILE=fork`.

```sh
python3 scripts/forge-artifacts.py plan \
  --test-root test/foundry/spec/protocols/staking/rebasingVault/RebasingAwareERC4626_Adversarial.t.sol \
  --test-root test/foundry/spec/protocols/staking/rebasingVault/RebasingAwareERC4626_Fuzz.t.sol

python3 scripts/forge-artifacts.py test \
  --test-root test/foundry/spec/protocols/staking/rebasingVault/RebasingAwareERC4626_Adversarial.t.sol \
  --test-root test/foundry/spec/protocols/staking/rebasingVault/RebasingAwareERC4626_Fuzz.t.sol \
  -- -vv

scripts/apex_bare_expectrevert_scan.sh
scripts/apex_bare_expectrevert_scan.sh --check
```

`docs/testing/ARTIFACT_BUILDS.md:5-12` tells the helper to take every edited production source. This item edits none, so no production path is passed. Lines 36-38 allow a consumer refresh without edited sources. `scripts/forge-artifacts.py:390` takes sources as optional, and `test_plan` at lines 353-354 adds each `--test-root` as a consumer before `graph.plan`. The `test` action is therefore the consumer-only refresh and the two-file run in one command. `plan` only prints that selection.

Kimi's bare `forge test` skips that refresh. MiniMax's `forge build` is not the artifact-loader helper. Neither is the sequence.

Both Solidity files must pass, including the unchanged rollback test. The scanner must list `ERC4626StandardExchange_Routes.t.sol` and `RebasingAwareERC4626_Accounting.t.sol`. `--check` may exit nonzero because those existing bare calls are now selected. Record that exit. Do not rewrite those tests or drop a directory to make it exit 0.

## Correction

`grok-plan.md` named `test_ADV03_nestedGuardObserved`, `internal` fields, salt `123`, and a supply-only witness, and it used bare `forge test`. The name, visibility, witness, and commands in that note are withdrawn. Salt `123` stays. The supply-only witness is replaced by the preview and delta assertions above. It did not assert shares equal `10e18`.

I did not run Forge.
