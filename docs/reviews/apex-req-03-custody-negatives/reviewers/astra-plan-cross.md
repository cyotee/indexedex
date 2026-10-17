# Astra — REQ-03 implementation-plan cross-review

**Status:** One cross-review; recommended closed instructions for coordinator consolidation, not authorization to implement. I read all three supplied originals in full, re-read the controlling R1 criteria, the current rollback fixture and token callback, and `docs/testing/ARTIFACT_BUILDS.md`. No PRD, consolidated plan, code, tests, configuration, or script was edited. My original draft remains preserved.

## Peer dispositions

- **Grok:** Agree with the normal-return callback, explicit `bubbleRevert(true)`, unchanged rollback test, R2 formula, and roots order. Select the stronger preview-based exact outer-success witness below rather than only positive mint plus supply growth. Full `forge build` is supported, but not the command sequence selected for this bounded test-only item.
- **MiniMax:** Reject the R1 construction as drafted. It omits the required explicit true setting, introduces an assembly return, and assumes recipient shares equal the deposited asset quantity. Its statements about the default toggle are contradictory; an unset boolean defaults to false. Offset 10 is passed by the existing deploy call (`RebasingAwareERC4626_Adversarial.t.sol:130`), so share units must not be equated to asset units. A successful Solidity deposit also returns its encoded share amount, not necessarily empty return data. Retain only the conforming R2 formula and roots order.
- **Kimi:** Reject the R1 construction as drafted because it explicitly sets `bubbleRevert(false)` and adds `nestedOk`, contrary to the controlling two-field/true-toggle instructions. Its preview-based success assertions are useful and incorporated below without the extra field. Do not adopt optional step swapping or a menu of run commands.

The current harness already does what the specified callback needs: `ReentrantERC20Harness.sol:68-75` returns when the callback succeeds, irrespective of the true bubble setting. A failing callback is not silently accepted. No assembly return, new harness flag, or harness change is necessary.

## One closed set to adopt

### R1 names, fields, deployment, and behavior

1. **Test name:** `test_ADV03_nestedDepositIsLocked_outerDepositCompletes`, placed immediately after `test_ADV03_reentrancyDuringDepositReverts`.
2. **Fields:** exactly `bool private nestedAttempted;` and `bytes private nestedReason;`, on `RebasingAwareERC4626_Adversarial`. No `nestedOk`, public getter, event, or external recorder.
3. **Callback:** `recordNestedDeposit(address wrapped, address receiver) external`. Keep the existing observer's low-level nested deposit operation; store the returned bytes and set `nestedAttempted = true`; return through the ordinary Solidity function end, without an assertion, revert, or assembly return. Leave `observeNestedDeposit` unchanged.
4. **Fixture:** mirror the existing rollback test's deployment/funding/approval setup. Keep offset 10 and salt **`bytes32(uint256(123))`**, as in current line 130. The new observation and rollback are separate tests with their own setup; a distinct salt is not needed to implement the separate-call requirement. Do not rename or change the rollback test.
5. **Harness setting:** explicitly call `tok.setBubbleRevert(true)` in the observation test. Point that test only at `recordNestedDeposit`. Keep the harness file unchanged.
6. **Reset:** immediately before preparing the observed outer operation, set `nestedAttempted = false` and delete `nestedReason`.

These choices retain my original private-field/test-name/same-fixture direction and select one salt instead of leaving the three drafts' salts as alternatives. They are recommendations for the coordinator to adopt, not a claim of peer consensus.

### Exact outer-success and nested-result witness

Use `depositAssets` for the existing rollback fixture's outer asset amount. Before the call, capture `expectedShares = wrapped.previewDeposit(depositAssets)`, `supplyBefore`, `aliceSharesBefore`, `aliceAssetsBefore`, and `vaultAssetsBefore`. Require `expectedShares > 0`.

Call the ordinary production deposit under Alice's context, capture its result as `minted`, and stop the prank. No outer `expectRevert`, catch, or low-level success substitute is used. Then assert exactly:

```solidity
assertGt(minted, 0);
assertEq(minted, expectedShares);
assertEq(IERC20(address(wrapped)).totalSupply(), supplyBefore + minted);
assertEq(IERC20(address(wrapped)).balanceOf(alice), aliceSharesBefore + minted);
assertEq(tok.balanceOf(alice), aliceAssetsBefore - depositAssets);
assertEq(tok.balanceOf(address(wrapped)), vaultAssetsBefore + depositAssets);
assertTrue(nestedAttempted);
assertEq(nestedReason, abi.encodeWithSelector(IReentrancyLock.IsLocked.selector));
```

This proves completion with the actual share conversion rather than a one-share-per-asset assumption. The exact guard-error encoding differs from normal deposit return data, so no extra success-status field is introduced. The separate existing rollback test retains its wrapped error and no-partial-credit assertions.

### R2 and R3

Add the following immediately after the existing recipient-share success assertion in `testFuzz_FUZZ02_exactOutMinimals`:

```solidity
assertEq(IERC20(address(vault)).totalSupply(), supplyBefore + shares,
    "exact funding mints only the requested supply");
```

Preserve its rejection half, snapshot restoration, bounds, and other success assertions. The captured supply is read after the snapshot is created, not before it as MiniMax states; it is still the correct same-state baseline.

All drafts give the same seventeen-entry roots order. Adopt it exactly: existing hook root; existing Uniswap exchange root; ERC-4626; Morpho Blue; rebasing custody; Rocket; Lido; EtherFi; Aave v3.6; Aave cross-version; Uniswap V2; Camelot V2; Aerodrome V1; Slipstream; singular `protocol/dexes/balancer/v3`; plural `protocols/dexes/balancer/v3`; DETF. Use the complete paths verbatim from PRD lines 58-73. Append to the existing `roots` tuple only. Do not sort, introduce another list, or change the marker/custody/detection/output logic.

## Exact verification sequence selected

**Select consumer-only artifact preparation followed by the two complete affected suites.** This supersedes the alternative commands in my original draft for consolidation purposes. There are no edited production sources to pass as changed-source arguments. Nevertheless, the tests deploy runtime artifacts, so checking/preparing those dependencies is useful. `ARTIFACT_BUILDS.md:30-41` expressly permits consumer-only preparation and says the consumer itself is compiled by the subsequent test run. Repeatable `--consumer` is supported at `scripts/forge-artifacts.py:392`.

Run these commands individually, in this order, from the repository root in the existing default hermetic configuration, only in the later authorized implementation session:

```sh
git diff --check
bash -n scripts/apex_bare_expectrevert_scan.sh

python3 scripts/forge-artifacts.py build \
  --consumer test/foundry/spec/protocols/staking/rebasingVault/RebasingAwareERC4626_Adversarial.t.sol \
  --consumer test/foundry/spec/protocols/staking/rebasingVault/RebasingAwareERC4626_Fuzz.t.sol

forge test --match-path test/foundry/spec/protocols/staking/rebasingVault/RebasingAwareERC4626_Adversarial.t.sol -vv
forge test --match-path test/foundry/spec/protocols/staking/rebasingVault/RebasingAwareERC4626_Fuzz.t.sol -vv

bash scripts/apex_bare_expectrevert_scan.sh
bash scripts/apex_bare_expectrevert_scan.sh --check

git diff --check
```

Stop and report compiler or Solidity test failures; do not broaden scope to repair production. Run the scanner commands separately so their outcomes are recorded distinctly. Its non-check invocation should produce the site report; its `--check` invocation is expected to reject existing selected bare expectations. Record that nonzero status, then perform the final diff check. Do not hide it with a shell success fallback or call it a passing scanner gate.

A nonzero result caused by correctly detected existing violations is allowed by the PRD; a syntax/I/O/tool failure is not equivalent. Inspect the actual report for the two cited newly selected files instead of imposing an unsupported strictly increasing aggregate-count criterion. Do not rewrite selected tests, remove roots, or weaken matching to obtain zero exit status. The scanner's normal generated evidence file is not to be hand-edited.

No optional broader-suite commands, alternate salt, alternate record carrier, extra field, false toggle, assembly return, or asset-denominated share assertion is retained in this closed recommendation. No production/harness/configuration change is authorized. Preserve artifacts and cache; do not enable `via_ir`, change fuzz settings, or deploy.

## Remaining dissent

The rejected MiniMax and Kimi R1 details conflict with explicit owner constraints, not merely style preferences. The acceptable Grok design is narrowed to the exact names/private fields and preview-based witness selected here. The command alternatives are resolved by the documented consumer-only refresh. No further implementation choice is left in this recommendation; adoption belongs to the coordinator. No execution or passing result is claimed.

I did not run Forge.
