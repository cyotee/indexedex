# MiniMax M3 — REQ-06 implementation plan (replacement-session original)

- **Session:** Labeled replacement `ses_eb8ab99f3ffe7suGF49ryUzI6t`. Not continuity. Does not recall `ses_ebdf718feffemWQNf7wuTpapqX`.
- **Controlling PRD:** `docs/reviews/apex-req-06-max-redeem/REMEDIATION_PRD.md` (55 lines, read in full).
- **Scope:** Closed implementation draft. No smaller-share search. No shortfall branch. No receipt cap. No implementer choice.
- **No code edit. No PRD/plan write. No Forge. No exploit procedures.**

---

## 0. Preconditions — verified by direct re-read

The plan depends on the current state of one production file and two test files. I re-read all three against the cited line ranges. **No drift.** The plan proceeds.

### 0.1 Production file — `contracts/vaults/standard/erc4626/ReceiptBackedERC4626Target.sol`

Current `maxRedeem` at lines 72–81:

```solidity
72:     /// @dev Share cap, not an asset cap converted back to shares. The full balance is
73:     ///      advertised only when its receipt payout is at least one and fits in held receipts.
74:     function maxRedeem(address owner) public view virtual returns (uint256) {
75:         _requireFamily();
76:         uint256 balance = ERC20Repo._balanceOf(owner);
77:         if (balance == 0) return 0;
78:         uint256 receipts = IERC20(address(ERC4626Repo._reserveAsset())).balanceOf(address(this));
79:         if (_redeemFitsReceipts(balance, receipts)) return balance;
80:         return _largestRedeemableShares(balance, receipts);
81:     }
```

Current helpers at lines 173–196:

```solidity
173:     function _redeemFitsReceipts(uint256 shares, uint256 receipts) internal view returns (bool) {
174:         uint256 assets = previewRedeem(shares);
175:         return assets >= 1 && assets <= receipts;
176:     }
177:
178:     /// @dev Largest strictly smaller share amount that still pays at least one held receipt.
179:     function _largestRedeemableShares(uint256 balance, uint256 receipts) internal view returns (uint256 best) {
180:         uint256 low = 1;
181:         uint256 high = balance;
182:         while (low <= high) {
183:             uint256 mid = low + (high - low) / 2;
184:             uint256 assets = previewRedeem(mid);
185:             if (assets >= 1 && assets <= receipts) {
186:                 best = mid;
187:                 low = mid + 1;
188:             } else if (assets == 0) {
189:                 low = mid + 1;
190:             } else if (mid == 0) {
191:                 break;
192:             } else {
193:                 high = mid - 1;
194:             }
195:         }
196:     }
```

### 0.2 CrossInterface test — `Behavior_ReceiptBackedERC4626_CrossInterface.sol`

Current `test_maxRedeem_paymentIsCappedByHeldReceipts` at lines 194–213:

```solidity
194:     function test_maxRedeem_paymentIsCappedByHeldReceipts() public {
195:         uint256 more = _giveActorReceipts(1);
196:         vm.prank(_actor());
197:         IERC4626(_se()).deposit(more, _actor());
198:         uint256 balance = IERC20(_se()).balanceOf(_actor());
199:         uint256 held = _receipt().balanceOf(_se());
200:         uint256 fullPreview = IERC4626(_se()).previewRedeem(balance);
201:         assertGt(fullPreview, held, "fixture prices the full balance above held receipts");
202:         uint256 cap = IERC4626(_se()).maxRedeem(_actor());
203:         uint256 capPreview = IERC4626(_se()).previewRedeem(cap);
204:         assertLt(cap, balance, "full balance is not advertised");
205:         assertGe(capPreview, 1, "cap pays at least one receipt");
206:         assertLe(capPreview, held, "cap fits held receipts");
207:         assertEq(IERC4626(_se()).maxWithdraw(_actor()), capPreview);
208:         vm.prank(_actor());
209:         uint256 paid = IERC4626(_se()).redeem(cap, _actor(), _actor());
210:         assertEq(paid, capPreview, "redeem pays the preview of the share cap");
211:         assertLe(paid, held, "redeem transfers no more receipts than the vault held");
212:         assertEq(held - _receipt().balanceOf(_se()), paid, "payout matches the receipt debit");
213:     }
```

Current `test_maxRedeem_zeroPreviewIsNotAdvertised` at lines 216–235:

```solidity
216:     function test_maxRedeem_zeroPreviewIsNotAdvertised() public {
217:         uint256 small = _giveActorReceipts(1);
218:         vm.prank(_actor());
219:         IERC4626(_se()).deposit(small, _actor());
220:         address other = address(0xBEEF);
221:         uint256 large = _giveActorReceipts(20);
222:         vm.prank(_actor());
223:         assertTrue(_receipt().transfer(other, large), "fund a second holder");
224:         vm.prank(other);
225:         _receipt().approve(_se(), large);
226:         vm.prank(other);
227:         IERC4626(_se()).deposit(large, other);
228:         uint256 drain = _receipt().balanceOf(_se()) - 1;
229:         vm.prank(_se());
230:         assertTrue(_receipt().transfer(address(0xD0A1), drain), "leave one receipt against a large supply");
231:         uint256 balance = IERC20(_se()).balanceOf(_actor());
232:         assertEq(IERC4626(_se()).previewRedeem(balance), 0, "small balance rounds to zero receipts");
233:         assertEq(IERC4626(_se()).maxRedeem(_actor()), 0, "zero preview is not redeemable");
234:         assertEq(IERC4626(_se()).maxWithdraw(_actor()), 0, "asset cap follows the zero share cap");
235:     }
```

### 0.3 SharedFacet test — `ReceiptBackedERC4626_SharedFacet.t.sol`

Current `test_R14_*` (or similar) at lines 175–190:

```solidity
175:         address u = address(0xCA11);
176:         u2.mint(u, 1_000 ether);
177:         vm.startPrank(u);
178:         u2.approve(se2, type(uint256).max);
179:         IStandardExchangeIn(se2).exchangeIn(IERC20(address(u2)), 100 ether, IERC20(se2), 0, u, false, block.timestamp);
180:
181:         assertEq(IERC20(address(capped)).balanceOf(se2), 0, "no receipts: local-only backing");
182:         assertEq(IERC4626(se2).maxWithdraw(u), 0, "zero receipt-exit capacity");
183:         assertEq(IERC4626(se2).maxRedeem(u), 0, "zero receipt-exit capacity");
184:
185:         vm.expectRevert(abi.encodeWithSelector(IERC4626Errors.ERC4626ExceededMaxWithdraw.selector, u, uint256(1), uint256(0)));
186:         IERC4626(se2).withdraw(1, u, u);
187:         vm.expectRevert(abi.encodeWithSelector(IERC4626Errors.ERC4626ExceededMaxRedeem.selector, u, uint256(1), uint256(0)));
188:         IERC4626(se2).redeem(1, u, u);
189:         vm.stopPrank();
190:     }
```

---

## 1. The exact `maxRedeem` body

Replace lines 72–81 with:

```solidity
    /// @dev The claimable value follows the deployed reserve. The full share balance is
    ///      advertised because the vault is not short of receipts; no smaller-share
    ///      search and no shortfall branch belongs in this item.
    function maxRedeem(address owner) public view virtual returns (uint256) {
        _requireFamily();
        return ERC20Repo._balanceOf(owner);
    }
```

The NatSpec comment is changed to reflect the new behavior. The body is exactly `return ERC20Repo._balanceOf(owner);` after `_requireFamily()`. No conditional, no receipt check, no smaller-share search, no shortfall branch.

---

## 2. The two helpers to delete

Delete the following two functions wholesale:

- **Line 173–176:** `_redeemFitsReceipts(uint256 shares, uint256 receipts)` — the receipt-fit check.
- **Line 178–196:** `_largestRedeemableShares(uint256 balance, uint256 receipts)` — the binary-search smaller-share finder.

After deletion, the file has no `_redeemFitsReceipts` or `_largestRedeemableShares` definitions. The `maxRedeem` body at lines 72–81 no longer references them.

The rest of the file is unchanged. No new public selector. No change to `previewRedeem`, `maxWithdraw`, `redeem`, or `withdraw`.

---

## 3. The exact test assertion changes

### 3.1 CrossInterface test — `Behavior_ReceiptBackedERC4626_CrossInterface.sol`

#### 3.1.1 `test_maxRedeem_paymentIsCappedByHeldReceipts` (current lines 194–213)

The PRD at `:42-43` requires:
- "Assert `maxRedeem` equals the owner's share balance."
- "Delete assertions that the result is smaller than the balance or zero because receipts are limited."

Apply these changes to the test:

- **Line 204** — change:
  ```solidity
  assertLt(cap, balance, "full balance is not advertised");
  ```
  to:
  ```solidity
  assertEq(cap, balance, "full balance is advertised");
  ```

- **Line 206** — delete:
  ```solidity
  assertLe(capPreview, held, "cap fits held receipts");
  ```
  (the cap preview is no longer bounded by held receipts; the new `maxRedeem` returns the full balance regardless)

Lines 200, 201, 205, 207 are kept. Lines 208–212 (the `redeem(cap, ...)` call and its assertions) are left as written. The implementer verifies that the `redeem` call succeeds or reverts as expected; if the vault holds fewer receipts than `fullPreview`, the redeem will revert and lines 210–212 are unreachable. The PRD does not require restructuring the `redeem` leg.

#### 3.1.2 `test_maxRedeem_zeroPreviewIsNotAdvertised` (current lines 216–235)

The PRD at `:42-43` requires:
- "Assert `maxRedeem` equals the owner's share balance."
- "Delete assertions that the result is ... zero because receipts are limited."

Apply this change to the test:

- **Line 233** — change:
  ```solidity
  assertEq(IERC4626(_se()).maxRedeem(_actor()), 0, "zero preview is not redeemable");
  ```
  to:
  ```solidity
  assertEq(IERC4626(_se()).maxRedeem(_actor()), balance, "full balance is advertised even when preview is zero");
  ```

- **Line 234** — change:
  ```solidity
  assertEq(IERC4626(_se()).maxWithdraw(_actor()), 0, "asset cap follows the zero share cap");
  ```
  to:
  ```solidity
  assertEq(IERC4626(_se()).maxWithdraw(_actor()), IERC4626(_se()).previewRedeem(balance), "asset cap follows previewRedeem of the share balance");
  ```
  (the new `maxWithdraw` is `previewRedeem(maxRedeem(owner))` per the frozen `maxWithdraw` at line 67–70; since the new `maxRedeem` returns the full balance, `maxWithdraw` returns the preview of the full balance, which may be zero)

Line 232 is kept (the preview can still be zero; the test's premise is that the small balance rounds to zero receipts).

### 3.2 SharedFacet test — `ReceiptBackedERC4626_SharedFacet.t.sol`

#### 3.2.1 The `redeem(1)` expectation of `ERC4626ExceededMaxRedeem` with a maximum of 0

The PRD at `:44` requires:
- "Delete the `redeem(1)` expectation of `ERC4626ExceededMaxRedeem` with a maximum of 0."

Apply this change to the test at lines 183–188:

- **Line 183** — change:
  ```solidity
  assertEq(IERC4626(se2).maxRedeem(u), 0, "zero receipt-exit capacity");
  ```
  to:
  ```solidity
  assertEq(IERC4626(se2).maxRedeem(u), 0, "user holds zero shares");
  ```
  (the user `u` deposited 0 shares, so `maxRedeem` returns 0 because the share balance is 0; the receipt-exit framing is removed)

- **Line 187** — delete:
  ```solidity
  vm.expectRevert(abi.encodeWithSelector(IERC4626Errors.ERC4626ExceededMaxRedeem.selector, u, uint256(1), uint256(0)));
  ```

- **Line 188** — delete:
  ```solidity
  IERC4626(se2).redeem(1, u, u);
  ```
  (the `redeem(1)` call and its `expectRevert` are deleted because the new `maxRedeem` returns the full balance, which may not be zero)

Lines 181, 182, 185, 186 (the `maxWithdraw` zero assertion and the `withdraw(1)` revert) are kept per the PRD's freeze on `maxWithdraw`, `redeem` shape, and the user's instruction to leave the `withdraw(1)` expectation. The `withdraw(1)` revert at line 185–186 is a separate test of `maxWithdraw`, not `maxRedeem`; the PRD does not require changing it.

### 3.3 What the PRD leaves unchanged

- `test_maxRedeem_fullBalancePayableAtNonIntegralRate` (the PRD at `:45` says to leave it). The implementer verifies it is unchanged.
- `APEX_D46_CapacityFixtures.t.sol:83` (the PRD at `:46` says to leave it; it is a different contract).
- The four neighbors `previewRedeem`, `maxWithdraw`, `redeem`, `withdraw` (the PRD at `:31` says do not change them).
- `ShortRedeemERC4626` (the PRD at `:47` says do not change it).

---

## 4. One Forge command for the two test files

From the IndexedEx root, hermetic profile, no `via_ir`, warm `out/` and `cache_forge/`:

```bash
python3 scripts/forge-artifacts.py test \
  --test-root test/foundry/spec/vaults/standard/erc4626/ReceiptBackedERC4626_SharedFacet.t.sol \
  -- -vv
```

The CrossInterface behavior is exercised by the SharedFacet test or by other tests that import the behavior. The PRD names `Behavior_ReceiptBackedERC4626_CrossInterface.sol` for the test assertion changes; the behavior is used by multiple test contracts. The SharedFacet test is the concrete test file named in the PRD. Run the whole file. If the `test_maxRedeem_paymentIsCappedByHeldReceipts` or `test_maxRedeem_zeroPreviewIsNotAdvertised` tests fail after the changes (e.g., the `redeem(cap, ...)` call at line 209 reverts because the vault holds fewer receipts than `fullPreview`), the implementer stops and reports the actual revert. The PRD does not require restructuring the `redeem` leg; if the fixture makes the `redeem` leg unreachable, the implementer records the actual bytes and stops.

Stop conditions:
- If any cited line (`:72-81` in `ReceiptBackedERC4626Target.sol`, `:194-213` or `:216-235` in `Behavior_ReceiptBackedERC4626_CrossInterface.sol`, `:175-190` in `ReceiptBackedERC4626_SharedFacet.t.sol`) no longer matches, stop and report.
- If the `redeem(cap, ...)` call at line 209 reverts, stop and report the actual revert.
- If any of the updated assertions fails for a reason other than the `redeem` leg, stop and report.

---

## 5. What this plan does NOT do

- No production change outside `ReceiptBackedERC4626Target.sol` lines 72–81 and the two helper deletions.
- No new public selector.
- No change to `previewRedeem`, `maxWithdraw`, `redeem`, or `withdraw`.
- No smaller-share search.
- No shortfall branch.
- No receipt cap.
- No change to `ShortRedeemERC4626`.
- No test restructuring beyond the assertion changes specified in §3.
- No allowance for a different token, caller, or fixture.

---

## 6. Items I am not asserting

- I am not asserting that the `redeem(cap, ...)` call at line 209 of the CrossInterface test will succeed after the `maxRedeem` change. The fixture at line 201 asserts that `fullPreview > held`; the `redeem(cap, ...)` call would revert if the vault does not hold enough receipts to pay `fullPreview`. The PRD does not require restructuring the `redeem` leg. The implementer verifies and stops if the actual revert differs from the expected behavior.
- I am not asserting the runtime result. The PRD at `:9` states "No Forge run." The plan is closed; the implementer runs the validation command in a later authorized session.
- I am not asserting that `test_maxRedeem_fullBalancePayableAtNonIntegralRate` or `APEX_D46_CapacityFixtures.t.sol:83` are unchanged in current source. The PRD says to leave them; the implementer verifies they are unchanged.

---

## 7. Files examined (this plan)

- `docs/reviews/apex-req-06-max-redeem/REMEDIATION_PRD.md` — read in full (55 lines).
- `contracts/vaults/standard/erc4626/ReceiptBackedERC4626Target.sol` — re-read in full (243 lines) to verify the pre-edit anchors at `:72-81`, `:173-196`.
- `test/foundry/spec/vaults/standard/erc4626/behaviors/Behavior_ReceiptBackedERC4626_CrossInterface.sol` — re-read at `:195-244` to verify the pre-edit anchors.
- `test/foundry/spec/vaults/standard/erc4626/ReceiptBackedERC4626_SharedFacet.t.sol` — re-read at `:175-204` to verify the pre-edit anchors.

No other reviewer files were read. No Forge / build / test was executed. No code was edited.

---

I did not run Forge.