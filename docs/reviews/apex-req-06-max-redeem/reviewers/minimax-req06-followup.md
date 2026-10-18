# MiniMax M3 — REQ-06 follow-up execution confirmation (replacement-session original)

- **Session:** Labeled replacement `ses_eb8ab99f3ffe7suGF49ryUzI6t`. Not continuity. Does not recall `ses_ebdf718feffemWQNf7wuTpapqX`.
- **Scope:** Confirm whether REQ-06 is now complete, including the follow-up in `REMEDIATION_PRD.plan.md`. Treat the execution report as an untrusted claim.
- **Inputs read:** `REMEDIATION_PRD.plan.md` (98 lines, full), `REMEDIATION_PRD.md` (55 lines, full), `EXECUTION_REPORT.md` (52 lines, full, untrusted), current source at `ReceiptBackedERC4626Target.sol:65-174` and the named test ranges.
- **No code edit. No PRD/plan write. No Forge.**

---

## Report status

`EXECUTION_REPORT.md` exists (not missing), 52 lines, treated as untrusted claim. The report at `:4` says "Planned edits and authorized test follow-up applied; whole-directory validation passed." The follow-up is recorded at `:38-52`.

---

## Verdict — No implementation gap

All six user-specified criteria are satisfied in current source. The test follow-up was applied correctly. The run result at `:47` is "175 tests passed, 0 failed, 0 skipped (175 total tests)" with exit 0.

---

## Evidence by criterion

### 1. `maxRedeem` returns `ERC20Repo._balanceOf(owner)` after `_requireFamily()`

**Status:** Confirmed at `ReceiptBackedERC4626Target.sol:72-76`:

```solidity
72:     /// @dev Returns the owner's share balance.
73:     function maxRedeem(address owner) public view virtual returns (uint256) {
74:         _requireFamily();
75:         return ERC20Repo._balanceOf(owner);
76:     }
```

The body is `return ERC20Repo._balanceOf(owner);` after `_requireFamily()`. No conditional, no receipt check, no smaller-share search, no shortfall branch.

### 2. The two search helpers are gone

**Status:** Confirmed by `grep -n "_redeemFitsReceipts\|_largestRedeemableShares" ReceiptBackedERC4626Target.sol` returning no matches. Both helpers are deleted wholesale.

### 3. The named behavior tests expect the share balance

**Status:** Confirmed.

- **`Behavior_ReceiptBackedERC4626_CrossInterface.sol:202`:** `assertEq(IERC4626(_se()).maxRedeem(_actor()), balance, "maxRedeem is the share balance");` ✓
- **`Behavior_ReceiptBackedERC4626_CrossInterface.sol:203`:** `assertEq(IERC4626(_se()).maxWithdraw(_actor()), fullPreview, "maxWithdraw follows that balance");` ✓
- **`Behavior_ReceiptBackedERC4626_CrossInterface.sol:224`:** `assertEq(IERC4626(_se()).maxRedeem(_actor()), balance, "maxRedeem is the share balance");` ✓

All three `maxRedeem` assertions expect the share balance. The `maxWithdraw` assertion at `:203` expects the preview of the share balance.

### 4. SharedFacet no longer expects `maxWithdraw` to be 0

**Status:** Confirmed at `ReceiptBackedERC4626_SharedFacet.t.sol:167-191`:

```solidity
167:     /// @dev Local-only backing (no receipts) gives zero receipt-exit capacity, with the exact reverts.
168:     function test_R14_18_localOnlyBacking_zeroReceiptExitCapacity_exactReverts() public {
169:         SimpleMintableERC20 u2 = new SimpleMintableERC20("Capped Underlying", "CUND");
170:         CappedPausableERC4626 capped = new CappedPausableERC4626(u2);
171:         vm.prank(owner);
172:         address se2 = genericPkg.deployVault(IERC4626(address(capped)));
173:
174:         capped.setPaused(true); // wraps book all underlying locally; no receipts acquired
175:         address u = address(0xCA11);
176:         u2.mint(u, 1_000 ether);
177:         vm.startPrank(u);
178:         u2.approve(se2, type(uint256).max);
179:         IStandardExchangeIn(se2).exchangeIn(IERC20(address(u2)), 100 ether, IERC20(se2), 0, u, false, block.timestamp);
180:
181:         assertEq(IERC20(address(capped)).balanceOf(se2), 0, "no receipts: local-only backing");
182:         uint256 shares = IERC20(se2).balanceOf(u);
183:         uint256 advertised = IERC4626(se2).previewRedeem(shares);
184:         assertEq(IERC4626(se2).maxRedeem(u), shares, "maxRedeem is the share balance");
185:         assertEq(IERC4626(se2).maxWithdraw(u), advertised, "maxWithdraw follows that balance");
186:         vm.expectRevert(abi.encodeWithSelector(
187:             IERC4626Errors.ERC4626ExceededMaxWithdraw.selector, u, advertised + 1, advertised
188:         ));
189:         IERC4626(se2).withdraw(advertised + 1, u, u);
190:         vm.stopPrank();
191:     }
```

The test:
- Captures `shares` dynamically from `balanceOf(u)` (line 182).
- Derives `advertised` from `previewRedeem(shares)` (line 183). No hardcoded preview amount.
- Asserts `maxRedeem(u) == shares` (line 184) and `maxWithdraw(u) == advertised` (line 185).
- Expects the `ERC4626ExceededMaxWithdraw` error with arguments `(u, advertised + 1, advertised)` (lines 186-188). No hardcoded amount.
- Withdraws `advertised + 1` (line 189). No hardcoded amount.

The preview amount is NOT hardcoded — it's computed from `previewRedeem(shares)` where `shares` is the user's actual balance.

### 5. No receipt cap, smaller-share search, or shortfall branch was added

**Status:** Confirmed.

The `maxRedeem` body is `return ERC20Repo._balanceOf(owner);` with no conditional, no search, no cap, no shortfall branch. A repo-wide search for `_redeemFitsReceipts` or `_largestRedeemableShares` returns no matches in `ReceiptBackedERC4626Target.sol`. The execution report at `:10` confirms: "No other production function or public selector changed; no receipt cap, smaller-share search, or shortfall branch was added."

### 6. `previewRedeem`, `maxWithdraw`, `redeem`, and `withdraw` were not given a new cap

**Status:** Confirmed.

- **`maxWithdraw` (`:67-70`):** unchanged. `return previewRedeem(maxRedeem(owner));` — no new cap.
- **`previewRedeem` (`:96-98`):** unchanged. `return convertToAssets(shares);` — no new cap.
- **`withdraw` (`:128-146`):** unchanged. The max check at line 137-140 uses `maxWithdraw(owner)`, which is `previewRedeem(maxRedeem(owner))`. No new cap was added to `withdraw` itself.
- **`redeem` (`:148-166`):** unchanged. The max check at line 157-160 uses `maxRedeem(owner)`. No new cap was added to `redeem` itself.

The four neighbors are frozen. The indirect effect on `maxWithdraw`'s return value is a consequence of the `maxRedeem` change, not a code change to `maxWithdraw` itself.

---

## Run result

The execution report at `:44-50` states:

```
Reran the prescribed command above from the IndexedEx root, using the previously approved sandbox escalation. The command completed with exit 0. Exact Forge summary:

Ran 22 test suites in 116.56s (123.51s CPU time): 175 tests passed, 0 failed, 0 skipped (175 total tests)

The corrected assertion passed both in `ReceiptBackedERC4626_SharedFacet_Test` and in the inheriting `ReceiptBackedERC4626_APEX_Recurrence` suite. The lifecycle invariant passed with 256 runs, 16,384 calls, and zero reverts. No failing assertion or unexpected returned error bytes were reported. `git diff --check` passed.
```

The saved log is not an independent rerun, but the report records 175/0/0 and the corrected assertion passed in both the SharedFacet test and the inheriting Recurrence suite. The source state is consistent with a green run.

---

## Findings

### Confirm-REQ06-FU-1 — Source execution is complete

- **Severity:** N/A (confirmation, not a defect).
- **File and line:** `ReceiptBackedERC4626Target.sol:72-76` (maxRedeem body); `ReceiptBackedERC4626_SharedFacet.t.sol:167-191` (follow-up fix); `Behavior_ReceiptBackedERC4626_CrossInterface.sol:202-204, 224` (behavior tests).
- **Verification:** All six user-specified criteria are satisfied. The maxRedeem returns the share balance; the two search helpers are gone; the named tests expect the share balance; SharedFacet no longer expects maxWithdraw to be 0 (it expects `previewRedeem(shares)` and the withdrawal reverts with `advertised + 1`); no receipt cap, smaller-share search, or shortfall branch was added; the four neighbors are frozen.
- **Impact class:** Confirmation. No source defect.
- **Confidence:** High on source state (direct read). Not rerun.

---

## Items I am not asserting

- I am not asserting the runtime result beyond the execution report's claim of 175 passed, 0 failed, 0 skipped. The saved log is not an independent rerun.
- I am not asserting whether the follow-up test fix is exactly what the user asked for beyond the six criteria. The user specified the criteria; the follow-up matches all six.
- I am not asserting whether the implementation is "final" in a broader audit sense. This confirmation is limited to the six user-specified criteria.

---

## Files examined (this confirmation)

- `docs/reviews/apex-req-06-max-redeem/REMEDIATION_PRD.plan.md` — read in full (98 lines).
- `docs/reviews/apex-req-06-max-redeem/REMEDIATION_PRD.md` — re-read in full (55 lines) for the controlling criteria.
- `docs/reviews/apex-req-06-max-redeem/EXECUTION_REPORT.md` — read in full (52 lines). Treated as untrusted claim.
- `contracts/vaults/standard/erc4626/ReceiptBackedERC4626Target.sol` — re-read at `:65-174` to verify the production change.
- `test/foundry/spec/vaults/standard/erc4626/ReceiptBackedERC4626_SharedFacet.t.sol` — re-read at `:160-219` to verify the follow-up test fix.
- `test/foundry/spec/vaults/standard/erc4626/behaviors/Behavior_ReceiptBackedERC4626_CrossInterface.sol` — re-read at `:200-239` to verify the behavior test fixes.

No Forge / build / test was executed. No code was edited.

---

I did not run Forge.