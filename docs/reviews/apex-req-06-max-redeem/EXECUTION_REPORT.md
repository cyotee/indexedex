# REQ-06 execution report

- Date: 2026-10-18.
- Status: Planned edits and authorized test follow-up applied; whole-directory validation passed. Initial failure history is retained below.
- Authorization: User requested execution of [REMEDIATION_PRD.plan.md](./REMEDIATION_PRD.plan.md).
- Controlling requirement: [REMEDIATION_PRD.md](./REMEDIATION_PRD.md).

The source matched the plan's preconditions: `maxRedeem` contained the receipt-cap search and both search helpers were present.

`ReceiptBackedERC4626Target.maxRedeem` now calls `_requireFamily()` and returns `ERC20Repo._balanceOf(owner)`. Deleted `_redeemFitsReceipts` and `_largestRedeemableShares`. No other production function or public selector changed; no receipt cap, smaller-share search, or shortfall branch was added.

Updated the receipt-limited and zero-preview behavior assertions to expect the share balance, and removed the receipt-limited cap redemption block. Updated their comments to describe the new assertions while retaining the test names. The shared-facet assertion now expects the account's share balance, and its `redeem(1)`/`ERC4626ExceededMaxRedeem` expectation was deleted. Retained the `maxWithdraw` assertions, `withdraw(1)` expectation, and `test_maxRedeem_fullBalancePayableAtNonIntegralRate` as instructed. `ShortRedeemERC4626` and `APEX_D46_CapacityFixtures.t.sol` were not changed.

Executed the prescribed whole-directory command from the repository root:

```bash
python3 scripts/forge-artifacts.py test \
  contracts/vaults/standard/erc4626/ReceiptBackedERC4626Target.sol \
  --test-root test/foundry/spec/vaults/standard/erc4626 \
  -- -vv
```

The initial sandboxed attempt compiled production artifacts and tests successfully, then Forge crashed before test execution with `Attempted to create a NULL object` in macOS `system-configuration`/proxy initialization (command exit 250). See [initial attempt log](./forge-validation.log).

With sandbox escalation approved, repeated the same command outside the sandbox. It completed with exit 1: **173 passed, 2 failed, 0 skipped; 175 tests across 22 suites**. See [initial validation log](./forge-validation-initial-unsandboxed.log). These logs are executor evidence, not an independent reviewer rerun.

Both failures are `test_R14_18_localOnlyBacking_zeroReceiptExitCapacity_exactReverts`, in:

- `ReceiptBackedERC4626_SharedFacet_Test`.
- `ReceiptBackedERC4626_APEX_Recurrence`, which inherits the shared-facet test.

The retained assertion at `test/foundry/spec/vaults/standard/erc4626/ReceiptBackedERC4626_SharedFacet.t.sol:182` expects `maxWithdraw(u) == 0`; execution returns `99900099900099900099`. The unchanged `maxWithdraw` implementation returns `previewRedeem(maxRedeem(owner))`, so returning the full share balance from `maxRedeem` changes its result for this fixture. This assertion precedes the updated shared-facet `maxRedeem` assertion, so the latter was not reached in these failing tests.

The receipt-limited, zero-preview, and unchanged non-integral-rate `maxRedeem` behavior tests passed in both the generic ERC4626 and Stata suites. The directory's lifecycle invariant suite also passed.

The initial execution stopped further remediation after the failure, as required by step 3. No additional test rerun or code change was made in that execution to address it. The retained zero-`maxWithdraw` expectation required a follow-up decision, recorded below. The build cache and artifacts were retained, `via_ir` was not enabled, and unrelated existing workspace changes were preserved. `git diff --check` passed.

## Follow-up to the retained zero maxWithdraw assertion

On 2026-10-18, the user authorized replacing only the stale assertion block in `ReceiptBackedERC4626_SharedFacet.t.sol:test_R14_18_localOnlyBacking_zeroReceiptExitCapacity_exactReverts`.

Applied the supplied block: read the account's shares, derive `advertised` from `previewRedeem(shares)`, assert `maxRedeem == shares` and `maxWithdraw == advertised`, then verify that withdrawing `advertised + 1` returns the exact ABI-encoded `ERC4626ExceededMaxWithdraw(u, advertised + 1, advertised)` error. No preview amount is hardcoded. This follow-up changed no production file and no other `maxRedeem` test; it added no search, cap, or shortfall branch.

Reran the prescribed command above from the IndexedEx root, using the previously approved sandbox escalation. The command completed with exit 0. Exact Forge summary:

```text
Ran 22 test suites in 116.56s (123.51s CPU time): 175 tests passed, 0 failed, 0 skipped (175 total tests)
```

The corrected assertion passed both in `ReceiptBackedERC4626_SharedFacet_Test` and in the inheriting `ReceiptBackedERC4626_APEX_Recurrence` suite. The lifecycle invariant passed with 256 runs, 16,384 calls, and zero reverts. No failing assertion or unexpected returned error bytes were reported. `git diff --check` passed.

See the [follow-up validation log](./forge-validation-unsandboxed.log). The earlier failing run remains in the [initial validation log](./forge-validation-initial-unsandboxed.log). This is executor validation, not an independent reviewer rerun.
