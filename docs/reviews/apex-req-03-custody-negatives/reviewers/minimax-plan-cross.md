# MiniMax M3 — REQ-03 plan cross-review

- **Date:** 2026-10-14
- **Reviewer:** MiniMax M3, one cross-review continuation. No peer original used as authority. No peer cross or REMEDIATION_PRD.md or REMEDIATION_PRD.plan.md was read this round. The PRD at `docs/reviews/apex-req-03-custody-negatives/REMEDIATION_PRD.md` and `docs/testing/ARTIFACT_BUILDS.md` were re-read.
- **Question:** agree on one closed set of: test function name, field visibility, salt, success-witness assertions, and the exact commands. Reject specific drafts per the coordinator's guidance.

## Closed set

| Decision | Closed value | Rationale |
|---|---|---|
| Test function name | `test_ADV03_nestedGuardObserved` | Matches the existing `test_ADV03_*` convention at line 128 of `RebasingAwareERC4626_Adversarial.t.sol`. Grok's pick. Concise and follows the family pattern. |
| Field declarations | `bool internal nestedAttempted; bytes internal nestedReason;` | The PRD line 34 names the fields. `internal` is the consensus among the drafts that don't add a rejected field. It keeps the fields test-contract-private without auto-generating getters (which `public` would). |
| Salt | `bytes32(uint256(124))` | Adjacent to the rollback test's salt at line 130 (`bytes32(uint256(123))`). Each test deploys its own vault, so a collision is harmless, but a distinct salt is cleaner. Kimi's pick. |
| `bubbleRevert` setting | `true` (explicit) | Per the PRD line 35. The harness's `_callback` at `ReentrantERC20Harness.sol:68-79` returns when the callback returns normally, regardless of `bubbleRevert`. Setting it explicitly matches the existing rollback test's configuration and is consistent with the PRD's "Keep `bubbleRevert` true" directive. |
| Callback function name | `recordNestedDeposit` | Per the PRD line 34. All three drafts agree. |
| Field types | `bool` and `bytes` | Per the PRD line 34. The first detects whether the callback was reached; the second captures the raw returndata. |
| Success-witness assertions | `minted > 0` AND `minted == expectedShares` AND `totalSupply == supplyBefore + minted` AND `balanceOf(alice) == aliceBefore + minted` AND `nestedAttempted == true` AND `nestedReason == abi.encodeWithSelector(IReentrancyLock.IsLocked.selector)` | See "Success-witness assertions" below. |
| Commands | Four commands, no `forge-artifacts.py` refresh | See "Commands" below. |

## Rejections per the coordinator's guidance

- **Reject Kimi: `tok.setBubbleRevert(false)` at line 62 of Kimi's plan.** The PRD line 35 says "Keep `bubbleRevert` true." Kimi sets it to `false` in the observation test. The harness's `_callback` does not consult `bubbleRevert` when the callback returns normally (which is what the observation callback does), so functionally `false` works. But the PRD directive is explicit. The closed set uses `tok.setBubbleRevert(true)` in the observation test, matching the rollback test's configuration at line 133.

- **Reject Astra: `assembly ("memory-safe") { return(0, 0) }` at line 47 of Astra's plan and at line 46 of my own plan.** The coordinator explicitly rejects any assembly return. A bare function end is equivalent — the function returns nothing, the harness's `_callback` sees `ok = true` and returns without consulting `bubbleRevert`. The assembly form is superfluous. The closed set drops the assembly form.

- **Reject Kimi: `bool internal nestedOk;` at line 31 of Kimi's plan.** The coordinator explicitly rejects adding a `nestedOk` field. The PRD line 34 names only `nestedAttempted` and `nestedReason`. The test can detect a nested success by checking `nestedReason.length > 0` (the returndata is empty on success) or by comparing the full recorded `nestedReason` against the expected `IsLocked` encoding (a successful call's returndata does not match). The closed set uses only the two PRD-named fields.

- **Reject any draft that asserts `balanceOf(alice) == 10e18`.** No draft in the cross-review does this. The coordinator's guard is a future-error check. The deposit is `10e18` assets, but the shares minted equal `previewDeposit(10e18)`, which depends on the vault's share offset (the rollback test passes `bytes32(uint256(123))` as salt and the observation test should pass a distinct salt; the `pkg.deployVault(IERC20Metadata(address(tok)), 10, ...)` call uses `10` as the share-decimal offset). A fixed `balanceOf(alice) == 10e18` would assert that the share asset is 1:1 with the underlying, which is not what the offset 10 means. The recipient shares assertion must be a delta: `balanceOf(alice) == aliceBefore + minted`. The closed set uses the delta form.

## Dissent from each peer

### Astra

Agree on the test concept and the no-production-change rule. Dissent on:
- Assembly return (rejected above).
- `private` field visibility (Grok and Kimi pick `internal`; both are valid, but `internal` is the consensus).
- The added post-success asset-delta assertions (`tok.balanceOf(alice) == aliceAssetsBefore - depositAssets`, `tok.balanceOf(address(wrapped)) == vaultAssetsBefore + depositAssets`). These are not required by the PRD; they are extra defensive checks. The closed set keeps them optional; the implementer may include them or not. The core success witness is the deposit return value, the total supply, the recipient shares, and the nested record.
- Use of `forge-artifacts.py plan` and `forge-artifacts.py test`. This item edits no production source; the lighter command set is appropriate. See "Commands" below.

### Grok

Agree on most. Dissent on:
- `bytes32(uint256(123))` (reuses the rollback test's salt). The closed set uses `bytes32(uint256(124))` to keep the two salts adjacent and distinct.
- No asset-delta assertions. Grok's success witness has only the total supply and the nested record. The closed set adds the recipient-shares delta as a standard outer-success witness. The asset-delta assertions are optional.
- No `forge build` in the command sequence. Grok's command sequence starts with `forge build`. The closed set includes it for clarity; `forge test` will compile anyway, so this is a no-op.

### Kimi

Agree on most. Dissent on:
- `tok.setBubbleRevert(false)` at line 62. Rejected above. The closed set uses `true`.
- `bool internal nestedOk;` at line 31. Rejected above. The closed set uses only the two PRD-named fields.
- The `assertFalse(nestedOk, ...)` assertion. Removed because `nestedOk` is not in the closed set.
- No `forge build` in the command sequence. Same as Grok; the closed set includes it.

## Success-witness assertions

The PRD AC 2 (line 34) requires:
1. "the callback records that the nested deposit was attempted and rejected with `IReentrancyLock.IsLocked`"
2. "returns without an assertion and without a revert"
3. "the outer deposit finishes"
4. "the test asserts `nestedAttempted` and asserts `nestedReason` equals `abi.encodeWithSelector(IReentrancyLock.IsLocked.selector)`"
5. "A wrong nested error, or a nested success, fails this test"

The "outer deposit finished" part of (3) needs a concrete oracle. The closed set uses four assertions, in order:

1. `uint256 minted = wrapped.deposit(10e18, alice);` — captures the deposit's return value. The call itself returning without reverting proves the outer deposit finished.
2. `assertGt(minted, 0, "outer deposit finished");` — proves the deposit returned a positive share count.
3. `assertEq(minted, expectedShares, "outer deposit matches preview");` — where `expectedShares = wrapped.previewDeposit(10e18)` captured before the call. Proves the return value matches the previewed mint.
4. `assertEq(IERC20(address(wrapped)).totalSupply(), supplyBefore + minted, "outer deposit increased supply by its mint");` — proves the deposit's effect on supply. Together with (2) and (3), this is the exact outer-success witness: the deposit returned a positive value matching its preview, and the total supply increased by exactly that amount.
5. `assertEq(IERC20(address(wrapped)).balanceOf(alice), aliceBefore + minted, "recipient shares are the outer mint only");` — where `aliceBefore` is captured before the call. Proves the recipient's share balance increased by exactly the outer mint. This is a delta, not a fixed `10e18`.

The nested record assertions, after the outer-success witness:
6. `assertTrue(nestedAttempted, "nested deposit attempted during the pull");` — proves the callback ran.
7. `assertEq(nestedReason, abi.encodeWithSelector(IReentrancyLock.IsLocked.selector), "nested guard is IsLocked");` — proves the nested guard rejected with the named error. A nested success would leave `nestedReason` empty (the `wrapped.deposit` call returns `bytes("")` on success), and this assertion would fail. A wrong nested error would leave `nestedReason` as that wrong error's encoding, and this assertion would fail.

The seven assertions together satisfy PRD AC 2's "the test reads that record after the call. A wrong nested error, or a nested success, fails this test." The "outer deposit finished" part of AC 2 is satisfied by assertions 1-5: the deposit returns a positive value matching its preview, and the supply and recipient balance change by exactly that amount. The "nested record" part is satisfied by assertions 6-7.

The implementer may add optional asset-delta assertions (e.g., `tok.balanceOf(alice) == aliceAssetsBefore - depositAssets` and `tok.balanceOf(address(wrapped)) == vaultAssetsBefore + depositAssets`) for additional defense, matching Astra's draft. These are not required by the PRD; the closed set does not mandate them.

## Commands

The PRD edits no production source. R1 and R2 are test-only edits; R3 is a script edit. The repo's `docs/testing/ARTIFACT_BUILDS.md` says the `forge-artifacts.py` helper is "for edited production sources" and "also allows a consumer-only refresh" (optional). The helper's primary purpose is to refresh artifacts when production creation bytecode changes, so `FactoryServices` read the correct bytecode. For test-only edits, `forge test` compiles and runs the test contracts as needed; no helper is required.

The lighter command set is:

```sh
# Compile the test contracts.
forge build

# Run R1: observation test in the adversarial file. The file also runs the
# unchanged rollback test and all other tests in the file.
forge test --match-path test/foundry/spec/protocols/staking/rebasingVault/RebasingAwareERC4626_Adversarial.t.sol -vvv

# Run R2: fuzz test success half total-supply assertion.
forge test --match-path test/foundry/spec/protocols/staking/rebasingVault/RebasingAwareERC4626_Fuzz.t.sol -vvv

# Run R3: scanner without --check to see the full site list and confirm the
# two cited escape files (ERC4626StandardExchange_Routes.t.sol and
# RebasingAwareERC4626_Accounting.t.sol) are now selected.
bash scripts/apex_bare_expectrevert_scan.sh

# Run R3: scanner with --check. Per PRD AC 2, this is expected to exit
# nonzero because the newly selected directories contain existing bare
# expectRevert() calls. Record the exit code; do not rewrite the tests.
bash scripts/apex_bare_expectrevert_scan.sh --check
```

Why this command set:

- `forge build` is included for clarity. `forge test` triggers a build anyway, so this is a no-op if the build is current. The implementer may skip it; the rest of the sequence works without it.
- Two `forge test --match-path` commands run each affected test file in full, including the unchanged tests. This is simpler than running individual tests and gives a regression signal on the whole file. The closed set picks whole-file runs over per-test runs.
- Two `bash scripts/apex_bare_expectrevert_scan.sh` commands run the scanner once without `--check` (to see the output) and once with `--check` (to record the expected nonzero exit). The PRD AC 2 says a nonzero `--check` is the expected end state; the implementer records the exit and the site list.
- No `forge-artifacts.py` is run. The PRD's R1 and R2 are test-only edits; R3 is a script edit. No production creation bytecode changes. The helper is for production source edits. The lighter set is appropriate.

Why not Astra's command set:

- Astra runs `python3 scripts/forge-artifacts.py plan` then `python3 scripts/forge-artifacts.py test`. The `plan` subcommand is for inspecting artifact selection. The `test` subcommand refreshes artifacts and runs tests. For test-only edits, neither is required. Astra's draft notes "there is no edited production source to pass here," which acknowledges the helper is not strictly needed.
- The lighter set is simpler, faster, and matches the repo's "after every production edit, refresh artifacts" workflow — this item has no production edit.

## What not to do

The PRD's non-goals (lines 37, 48, 81, 89) are explicit. The cross-review endorses the consensus:

- No production source change. No bytecode guard change. No pull wrap change. No minting change.
- No harness change. No harness flag, event, or second contract for the record.
- No bare `expectRevert()` anywhere. No replacement of either ADV03 test.
- No outer `IsLocked` expectation on the rollback test.
- No fuzz domain widening. No fuzz assertion rewrite.
- No scanner inventory additions, removals, second list, external manifest, or marker change.
- No rewriting newly selected tests to make `--check` pass. The nonzero `--check` exit is the expected end state.

## Unresolved dissent

None. The closed set is complete. The implementer has a single set of choices for the test function name, field declarations, salt, success-witness assertions, and command sequence. The rejected drafts (assembly return, `nestedOk` field, `bubbleRevert = false`) are excluded by the coordinator's guidance.

I did not run Forge.