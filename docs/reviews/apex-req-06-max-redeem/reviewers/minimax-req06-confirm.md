# MiniMax M3 — REQ-06 execution confirmation (replacement-session original)

- **Session:** Labeled replacement `ses_eb8ab99f3ffe7suGF49ryUzI6t`. Not continuity. Does not recall `ses_ebdf718feffemWQNf7wuTpapqX`.
- **Scope:** Confirm whether `docs/reviews/apex-req-06-max-redeem/REMEDIATION_PRD.plan.md` was executed accurately against current source. Treat the execution report as an untrusted claim.
- **Inputs read:** `REMEDIATION_PRD.plan.md` (98 lines, full), `REMEDIATION_PRD.md` (55 lines, full), `EXECUTION_REPORT.md` (36 lines, full, untrusted), current source at `ReceiptBackedERC4626Target.sol:72-196` and at the named test line ranges.
- **No code edit. No PRD/plan write. No Forge.**

---

## Verdict — Implementation gap remains.

The plan was applied correctly per its instructions, but the plan's instructions left a test-oracle gap. The `maxWithdraw` assertion at `ReceiptBackedERC4626_SharedFacet.t.sol:182` is no longer correct under the new `maxRedeem` behavior. The execution correctly stopped at the plan's failure gate.

---

## Report status

`EXECUTION_REPORT.md` exists (not missing), 36 lines, treated as untrusted claim.

The report at `:3` says "Planned edits applied; validation failed. Stopped at the plan's failure gate." The report at `:25` says "173 passed, 2 failed, 0 skipped; 175 tests across 22 suites." The two failures are `test_R14_18_localOnlyBacking_zeroReceiptExitCapacity_exactReverts` in two test files.

The report at `:32` explains: "The retained assertion at `test/foundry/spec/vaults/standard/erc4626/ReceiptBackedERC4626_SharedFacet.t.sol:182` expects `maxWithdraw(u) == 0`; execution returns `99900099900099900099`. The unchanged `maxWithdraw` implementation returns `previewRedeem(maxRedeem(owner))`, so returning the full share balance from `maxRedeem` changes its result for this fixture."

This is the gap.

---

## Evidence by criterion

### 1. `maxRedeem` returns `ERC20Repo._balanceOf(owner)` after `_requireFamily()`

**Status:** Confirmed in source.

Current `ReceiptBackedERC4626Target.sol:72-81`:

```solidity
72:     /// @dev Returns the owner's share balance.
73:     function maxRedeem(address owner) public view virtual returns (uint256) {
74:         _requireFamily();
75:         return ERC20Repo._balanceOf(owner);
76:     }
```

The body is `return ERC20Repo._balanceOf(owner);` after `_requireFamily()`. No conditional, no receipt check, no smaller-share search, no shortfall branch. Matches the plan's Step 1.

### 2. The two search helpers are gone

**Status:** Confirmed in source.

`_redeemFitsReceipts` (was at lines 173-176) is gone. `_largestRedeemableShares` (was at lines 178-196) is gone. The current source at lines 173+ jumps from the function `maxRedeem` to the next function `_requireFamily`. The two helpers are deleted wholesale.

### 3. The named tests expect the share balance

**Status:** Partially confirmed. **Gap remains.**

The three maxRedeem assertions were updated correctly:

- **`Behavior_ReceiptBackedERC4626_CrossInterface.sol:185`:** `assertEq(IERC4626(_se()).maxRedeem(_actor()), balance, "payable full balance is the share cap");` — expects the share balance. ✓
- **`Behavior_ReceiptBackedERC4626_CrossInterface.sol:224`:** `assertEq(IERC4626(_se()).maxRedeem(_actor()), balance, "maxRedeem is the share balance");` — expects the share balance. ✓
- **`ReceiptBackedERC4626_SharedFacet.t.sol:183`:** `assertEq(IERC4626(se2).maxRedeem(u), IERC20(se2).balanceOf(u), "maxRedeem is the share balance");` — expects the share balance. ✓

The `maxWithdraw` assertion at `ReceiptBackedERC4626_SharedFacet.t.sol:182` was **not** updated:

```solidity
182:         assertEq(IERC4626(se2).maxWithdraw(u), 0, "zero receipt-exit capacity");
```

This assertion expects `maxWithdraw(u) == 0`, but under the new `maxRedeem` behavior, `maxWithdraw(u) = previewRedeem(maxRedeem(u)) = previewRedeem(IERC20(se2).balanceOf(u))`. Since the user holds shares (from the deposit at line 179), the preview is non-zero (the actual value is `99900099900099900099` per the execution report at `:32`). The assertion is now wrong.

This is the gap. The plan explicitly said "Leave the `maxWithdraw` assertion" (Step 2, SharedFacet section), but the plan's instruction was incorrect because the new `maxRedeem` changes the result of `maxWithdraw`. The implementer correctly applied the plan's instructions, which resulted in the test failure.

### 4. No shortfall branch or receipt cap was added

**Status:** Confirmed.

The execution report at `:10` says: "No other production function or public selector changed; no receipt cap, smaller-share search, or shortfall branch was added."

The current source at `ReceiptBackedERC4626Target.sol:72-81` shows the simple `return ERC20Repo._balanceOf(owner);` body. No conditional, no search, no cap, no shortfall branch.

### 5. `previewRedeem`, `maxWithdraw`, `redeem`, and `withdraw` were not given a new cap

**Status:** Confirmed (for `previewRedeem`, `redeem`, `withdraw`); **gap for `maxWithdraw`**.

- **`previewRedeem` (`:101-103`):** unchanged. The current source shows the same `convertToAssets(shares)` call. ✓
- **`maxWithdraw` (`:67-70`):** unchanged. The current source still shows `_requireFamily(); return previewRedeem(maxRedeem(owner));`. ✓ No new cap was added. ✓
- **`redeem` (`:153-171`):** unchanged. The current source shows the same redeem logic. ✓
- **`withdraw` (`:133-151`):** unchanged. The current source shows the same withdraw logic. ✓

The `maxWithdraw` function was not given a new cap, but its return value changed indirectly because `maxRedeem` changed. The PRD's non-goal at `:31` says "Do not change `previewRedeem`, `maxWithdraw`, `redeem`, or `withdraw`." This was followed — the functions were not changed. The indirect effect on `maxWithdraw`'s return value is not a code change to `maxWithdraw`; it's a consequence of the `maxRedeem` change.

The issue is that the test assertion at `SharedFacet.t.sol:182` expects the old `maxWithdraw(u) == 0` behavior, which no longer holds because `maxRedeem` changed.

---

## Findings

### Confirm-REQ06-1 — Production change is correct

- **Severity:** N/A (confirmation, not a defect).
- **File and line:** `ReceiptBackedERC4626Target.sol:72-81` (maxRedeem body); `:173-196` (two helpers deleted).
- **Verification:** `maxRedeem` returns `ERC20Repo._balanceOf(owner)` after `_requireFamily()`. The two search helpers are gone. No receipt cap, smaller-share search, or shortfall branch.
- **Impact class:** Confirmation. No production defect.
- **Confidence:** High on source state (direct read).

### Confirm-REQ06-2 — Test gap: `maxWithdraw` assertion at `SharedFacet.t.sol:182`

- **Defect class:** Test-oracle gap.
- **File and line:** `test/foundry/spec/vaults/standard/erc4626/ReceiptBackedERC4626_SharedFacet.t.sol:182`.
- **Broken requirement:** The plan explicitly said to leave the `maxWithdraw` assertion unchanged. Under the new `maxRedeem` behavior (returns the full share balance), `maxWithdraw(u) = previewRedeem(maxRedeem(u))` is non-zero. The assertion at `:182` expects `0`, but the actual return is `99900099900099900099` per the execution report.
- **Impact class:** Test failure. The test `test_R14_18_localOnlyBacking_zeroReceiptExitCapacity_exactReverts` fails in two test files: `ReceiptBackedERC4626_SharedFacet_Test` and `ReceiptBackedERC4626_APEX_Recurrence` (which inherits the shared-facet test). The execution correctly stopped at the plan's failure gate.
- **Fix direction:** Update the `maxWithdraw` assertion at `SharedFacet.t.sol:182` to expect the correct value after the new `maxRedeem`. The correct value is `previewRedeem(IERC20(se2).balanceOf(u))` = `99900099900099900099`. Specifically:

  ```solidity
  assertEq(
      IERC4626(se2).maxWithdraw(u),
      IERC4626(se2).previewRedeem(IERC20(se2).balanceOf(u)),
      "maxWithdraw follows previewRedeem of the share balance"
  );
  ```

  Alternatively, the assertion could expect the literal value:
  ```solidity
  assertEq(IERC4626(se2).maxWithdraw(u), uint256(99900099900099900099), "maxWithdraw follows the new full-balance preview");
  ```

  The implementer should verify the literal value at execution time. The PRD's freeze on `maxWithdraw` (do not change the function) is preserved; only the test assertion is updated.

### Confirm-REQ06-3 — Runtime gap

- **Defect class:** Test failure at validation.
- **File and line:** `test_R14_18_localOnlyBacking_zeroReceiptExitCapacity_exactReverts` in `ReceiptBackedERC4626_SharedFacet_Test` and `ReceiptBackedERC4626_APEX_Recurrence`.
- **Impact class:** 2 failed out of 175 tests. The execution correctly stopped at the plan's failure gate.
- **Fix direction:** Address the test gap per Confirm-REQ06-2. After the fix, re-run the prescribed command to confirm all tests pass.

---

## Items I am not asserting

- I am not asserting the runtime result beyond the execution report's claim of 173 passed, 2 failed, 0 skipped. The saved log is not an independent rerun.
- I am not asserting whether the plan's instruction to "Leave the `maxWithdraw` assertion" was correct. The plan was applied per its instructions. The test gap is a consequence of the plan's instruction, not a production defect.
- I am not asserting whether `IERC20(se2).balanceOf(u)` after the deposit at `SharedFacet.t.sol:179` equals exactly `99900099900099900099`. The execution report's claim of `99900099900099900099` is the observed value. The implementer verifies at execution time.

---

## Files examined (this confirmation)

- `docs/reviews/apex-req-06-max-redeem/REMEDIATION_PRD.plan.md` — read in full (98 lines).
- `docs/reviews/apex-req-06-max-redeem/REMEDIATION_PRD.md` — re-read in full (55 lines) for the controlling criteria.
- `docs/reviews/apex-req-06-max-redeem/EXECUTION_REPORT.md` — read in full (36 lines). Treated as untrusted claim.
- `contracts/vaults/standard/erc4626/ReceiptBackedERC4626Target.sol` — re-read at `:72-196` to verify the production change.
- `test/foundry/spec/vaults/standard/erc4626/behaviors/Behavior_ReceiptBackedERC4626_CrossInterface.sol` — re-read at `:180-226` to verify the test changes.
- `test/foundry/spec/vaults/standard/erc4626/ReceiptBackedERC4626_SharedFacet.t.sol` — re-read at `:160-200` to verify the test changes.

No Forge / build / test was executed. No code was edited.

---

I did not run Forge.