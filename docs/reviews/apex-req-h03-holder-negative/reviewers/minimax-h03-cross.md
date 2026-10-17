# MiniMax M3 — REQ-H03 cross-review (replacement session)

- **Session:** Labeled replacement `ses_eb8ab99f3ffe7suGF49ryUzI6t`. Not continuity. Does not recall `ses_ebdf718feffemWQNf7wuTpapqX`.
- **Scope:** One defensive cross-review of the REQ-H03 originals. The coordinator flagged that my original left the implementer a failing test or an unauthorized production edit. I confirm or refute the line numbers the coordinator cited, agree/dissent/refute on the peers' answers, and close the open instruction in one sentence.
- **Method:** Read the three peer originals (`astra-h03.md`, `grok-h03.md`, `kimi-h03.md`). Re-load the source paths the coordinator cited and the paths my own original read. The peers' quoted line numbers are untrusted; I verified them.
- **Forge:** Not run. No code edit. No peer notes read during the independent first pass; read here only because this is a cross-review.

---

## 1. Coordinator-cited lines — confirmed by direct read

The coordinator's note is correct. Verified by direct re-read:

| Coordinator-cited line | Content (verbatim) | Confirmed |
|---|---|---|
| `UniswapV3FullSpreadStandardYieldExecutionTarget.sol:22` | `_settleNamedHolder(address(tokenOut_), shares_, minimum_, receiver_, holder_);` after `_holder_ = msg.sender` in the V3 FullSpread override `_standardRoute` | Yes |
| `UniswapV3FullSpreadStandardExchangeVaultInBase.sol:236` | `ERC20Repo._burn(holder_, sharesBurned);` in the **sleeve** branch of `_executeZapOutExactIn` | Yes |
| `UniswapV3FullSpreadStandardExchangeVaultInBase.sol:257` | `ERC20Repo._burn(holder_, sharesBurned);` in the **free** branch of `_executeFreeZapOutExactIn` | Yes |
| `ERC20Repo.sol:361` | `// _decreaseBalanceOf(layoutStruct, account, amount);` (commented out) | Yes |
| `ERC20Repo.sol:362` | `layoutStruct.balanceOf[account] -= amount;` (the inline checked subtraction that fires when `_decreaseBalanceOf` is bypassed) | Yes |
| `BasicVaultCommon._secureSelfBurn` is not this route | The V3 FullSpread override on `_standardRoute` short-circuits to `_settleNamedHolder` → `_executeZapOutExactIn` for the self-share input on `internal_=false`. `_exchangeIn` / `_secureSelfBurn` is only reached on the base `NativeStandardYieldTarget` path or when the V3 override delegates up. This test's path does not reach `_secureSelfBurn`. | Yes |
| Solidity 0.8 checked subtraction panics with code `0x11` | Confirmed against the Solidity language docs (Context7 lookup of `/argotorg/solidity` control-structures, "Error handling and checked arithmetic"). The `Panic(uint256)` error carries the panic code as its single `uint256` argument. `0x11` is "arithmetic underflow or overflow outside of an `unchecked` block." | Yes |

The coordinator's facts are accurate. My original read was also accurate on these line numbers. The disagreement is about what the production **actually raises** for this test's path, not about the line numbers.

---

## 2. Headline — agreement with Astra and Grok, dissent from Kimi, retraction of my own first pass

### 2.1 What each peer says

| Reviewer | Production error the test must expect | Test change |
|---|---|---|
| Astra | `Panic(uint256)` with `0x11` (current behavior) | `vm.expectRevert(abi.encodeWithSignature("Panic(uint256)", uint256(0x11)));` at `:147`. No new import. |
| Grok | `Panic(uint256)` with `0x11` (current behavior) | Same as Astra. No new import. |
| Kimi | `IERC20Errors.ERC20InsufficientBalance(holder, 0, 1)` (the named error) | `vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, holder, 0, 1));` at `:147`. Add `import {IERC20Errors} from "@crane/contracts/tokens/ERC20/IERC20Errors.sol";`. |
| Mine (first pass) | `IERC20Errors.ERC20InsufficientBalance(holder, 0, 1)` (the named error), with a recorded "production gap" footnote | Same as Kimi. |

### 2.2 The trace that decides the question

The test path is `redeem(recipient, 1, token0, 0, false)` from `holder = v3Short` (0 vault shares). The path is:

1. `NativeStandardYieldTarget.redeem` (`:30-45`) → `internalBalance_=false` → `_standardRoute(...)`.
2. The V3 FullSpread override of `_standardRoute` at `UniswapV3FullSpreadStandardYieldExecutionTarget.sol:18-30`: the `if (address(in_) != address(this) || internal_)` guard is **false** (the input is the self-share, `internal_=false`), so the override runs: `received_ = _settleNamedHolder(address(out_), amount_, minimum_, receiver_, msg.sender);` — **`holder_ = msg.sender = v3Short`**.
3. `_settleNamedHolder` → `_executeZapOutExactIn(tokenOut, 1, 0, recipient, v3Short)`.
4. `_executeZapOutExactIn` at `InBase.sol:212-243` checks `canOpenBoundPoolOps()` (true after `_seedExternalLiquidity` in setUp), so the free branch is taken: `_executeFreeZapOutExactIn(...)` at `:245-261`.
5. Inside `_executeFreeZapOutExactIn`: `_collectManagedFees()` succeeds; `_idleZapOutCore(...)` runs against the vault's own book (the proportional fractions and pool swap execute on the vault's position and free balance, not the holder's); the slippage check passes (`minAmountOut = 0`); then `ERC20Repo._burn(holder_=v3Short, sharesBurned=1)` at `:257`.
6. `ERC20Repo._burn(address,uint256)` at `:376-377` delegates to the storage overload at `:360-365`:
   ```solidity
   function _burn(Storage storage layoutStruct, address account, uint256 amount) internal {
       // _decreaseBalanceOf(layoutStruct, account, amount);
       layoutStruct.balanceOf[account] -= amount;
       layoutStruct.totalSupply -= amount;
       emit IERC20Events.Transfer(account, address(0), amount);
   }
   ```
   The commented-out `_decreaseBalanceOf` is **not** called. The inline `balanceOf[account] -= amount` is a checked subtraction in Solidity 0.8.x. With `account = v3Short` and `balanceOf[v3Short] = 0`, the expression `0 - 1` reverts with `Panic(uint256)` carrying the panic code `0x11`.

The exact revert data the test will see is the four-byte selector `Panic(uint256)` followed by the 32-byte ABI-encoded `uint256(0x11)`. The full expected revert data is `abi.encodeWithSignature("Panic(uint256)", uint256(0x11))`.

### 2.3 Where Kimi is wrong

Kimi's trace takes the path through `BasicVaultCommon._secureSelfBurn` at `contracts/vaults/basic/BasicVaultCommon.sol:151-155`. That helper is reached from the base `NativeStandardYieldTarget._standardRoute` → `_exchangeIn` path, not the V3 FullSpread override. The V3 FullSpread override at `UniswapV3FullSpreadStandardYieldExecutionTarget.sol:18-30` short-circuits the base path for the self-share input and calls `_settleNamedHolder` instead. The test's holder-balance call site is `ERC20Repo._burn(v3Short, 1)` at `InBase.sol:257`, which is the storage-overload `_burn` at `ERC20Repo.sol:360-365` with the inline checked subtraction — **not** the `_decreaseBalanceOf` helper at `:222-232` that Kimi names.

Kimi's two precedent citations also do not establish the path:
- `TestBase_FullSpreadG5GuardClosure.sol:360` uses `IERC20Errors.ERC20InsufficientBalance` for a *different* test family (G5 guard closure) that goes through the base `BasicVaultCommon._secureSelfBurn` route. That test is not the V3 FullSpread `redeem` test.
- `TestBase_ERC20.sol:64,127` are crane's base ERC20 tests, not the V3 FullSpread path under REQ-H03.

The named error Kimi names **is** the error that `_decreaseBalanceOf` would emit, and it is the error that the current `_burn` is **supposed to emit** per the standard ERC20 pattern. But the current `_burn` is buggy: it bypasses `_decreaseBalanceOf` and falls through to a checked subtraction that reverts with `Panic(0x11)` instead. The bug is real; the test path does not reach the function Kimi names.

### 2.4 Where Astra and Grok are right

Both trace the path through the V3 FullSpread override and end at `ERC20Repo._burn` with the inline checked subtraction. Both name `Panic(uint256)` with `0x11`. The fact is exactly what the coordinator's note states: the inline `balanceOf[account] -= amount` on a zero balance produces a `Panic(0x11)` because Solidity 0.8.x's checked arithmetic does not allow `0 - 1` to underflow.

### 2.5 Where my own first pass was wrong

My first pass named `ERC20InsufficientBalance(holder, 0, 1)` and recorded a "production gap" footnote saying the current production raises `Panic(0x11)` instead. That left the implementer with two open choices:
1. Edit the test to expect `ERC20InsufficientBalance` and watch it fail because production raises `Panic(0x11)`, or
2. Edit production to restore the `_decreaseBalanceOf` call in `_burn` so the named error fires.

The PRD's "Do not weaken the production burn" non-goal and "Do not treat this gap as evidence that the current holder argument is wrong" do not authorize a production edit in this review session. REQ-H03 is scoped as a test-oracle item. The implementer therefore had no authorized path to a green test. **I retract my first pass's named error.** The coordinator's note is correct; I close the open instruction below.

---

## 3. One closed instruction (replaces my first pass)

The production error that the test must expect, exactly:

> **`Panic(uint256)` carrying the panic code `0x11`**, encoded as `abi.encodeWithSignature("Panic(uint256)", uint256(0x11))`.

The exact test change (one line, no new import):

> Replace `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadVaultHeldRedeem.t.sol:147` `vm.expectRevert();` with `vm.expectRevert(abi.encodeWithSignature("Panic(uint256)", uint256(0x11)));`.

Everything else in the file is unchanged. The `holder`, `vault`, and `recipient` balance assertions at `:149-151` remain and now mean the production raised `Panic(0x11)` with no state change. The code-less ordinary-success test at `:105-122` and the two-burn-sites test at `:124-140` are untouched, per the PRD's third acceptance bullet. The V4 twin is withdrawn and is not edited.

The production code is **not** edited in this item. The production gap (commented-out `_decreaseBalanceOf` in `ERC20Repo._burn`) is recorded in §4 as a separate item outside REQ-H03's scope. The implementer is not authorized to "fix" the production burn under REQ-H03; if a later authorized item restores the `_decreaseBalanceOf` call and the production then raises `ERC20InsufficientBalance` instead, REQ-H03's expectation would need to be re-stated at that time. That is a future-PRD question, not an REQ-H03 question.

---

## 4. Items I am not asserting

- I am not asserting the runtime result. The test will produce `Panic(0x11)` on a current-tree Forge run; I do not rerun.
- I am not asserting the production gap is benign. The commented-out `_decreaseBalanceOf` in `ERC20Repo._burn` is a real divergence from the standard ERC20 error pattern. It is **not** in scope for REQ-H03 per the PRD's non-goals; it is recorded here as a finding for a future separate PRD, not as a defect to fix in this round.
- I am not asserting that `Panic(0x11)` is the only possible `Panic` code at this site. A different arithmetic failure in the same `_burn` body (e.g., `totalSupply` underflow if the holder's burn somehow drove `totalSupply` below zero) could also produce `0x11`. The test's current `minAmountOut = 0` and the `_idleZapOutCore` math bound that risk: the supply subtraction is the second statement and fires only after a successful holder subtraction. A future test hardening could re-verify the call stack or the panic origin, but REQ-H03 does not require it.

---

## 5. Findings (cross-review)

### Cross-H03-1 — First pass retracted; closed instruction replaces it

- **Severity:** N/A (retraction of a first pass; not a new defect).
- **File and line:** `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadVaultHeldRedeem.t.sol:147`; the burn site at `UniswapV3FullSpreadStandardExchangeVaultInBase.sol:257`; the storage-overload `_burn` at `lib/crane/contracts/tokens/ERC20/ERC20Repo.sol:360-365`.
- **Intended behavior (PRD `:142, 144`):** "The V3 test expects the holder-balance error for that route. Holder, vault, and recipient balances are unchanged."
- **Broken invariant:** The test currently uses bare `vm.expectRevert()` and accepts any revert. The exact holder-balance failure on the current path is `Panic(0x11)`, not `ERC20InsufficientBalance`, because the V3 FullSpread `_standardRoute` override bypasses the base path's `_decreaseBalanceOf` and the `_burn` storage overload at `ERC20Repo.sol:360-365` does an inline checked subtraction.
- **Impact class:** Test-oracle specificity. Not a demonstrated production holder-selection defect. Not an asset-loss claim.
- **Fix direction:** Replace `:147`'s `vm.expectRevert();` with `vm.expectRevert(abi.encodeWithSignature("Panic(uint256)", uint256(0x11)));`. No import. No production edit. No `catch`. No V4 twin edit. The V4 twin is withdrawn (PRD line 141).
- **Confidence:** High on the source trace and on the Solidity 0.8.x checked-arithmetic semantics. Runtime not independently exercised.

### Cross-H03-2 — Production gap recorded, not in REQ-H03 scope

- **Severity:** Informational. Outside REQ-H03.
- **File and line:** `lib/crane/contracts/tokens/ERC20/ERC20Repo.sol:361-362`.
- **Intended behavior (standard ERC20 pattern):** `_decreaseBalanceOf` is the named-error site for insufficient balance; `_burn` should call it.
- **Broken invariant:** The `_decreaseBalanceOf` call at `ERC20Repo.sol:361` is commented out, and `_burn` does an inline `balanceOf[account] -= amount` that reverts with `Panic(0x11)` on a zero balance. Two existing precedents (`TestBase_FullSpreadG5GuardClosure.sol:360` and `TestBase_ERC20.sol`) already expect `ERC20InsufficientBalance` for the routes that reach `_decreaseBalanceOf`. The V3 FullSpread `redeem(...,false)` path does not reach `_decreaseBalanceOf` because the V3 override short-circuits the base `_standardRoute` to `_settleNamedHolder` → `_executeZapOutExactIn` → `ERC20Repo._burn` directly.
- **Impact class:** Documentation/code divergence from the standard ERC20 error pattern. Not in REQ-H03 scope per the PRD's "Do not weaken the production burn" and "Do not treat this gap as evidence that the current holder argument is wrong" non-goals.
- **Fix direction:** A future, separately-scoped PRD may restore the `_decreaseBalanceOf` call in `_burn` and re-state the test expectation. That is **not** authorized by REQ-H03 and is not asserted as a defect to fix in this round.
- **Confidence:** High on the source divergence; no opinion on whether the divergence is intentional or accidental.

---

## 6. Dissent and unresolved items

**Dissent from Kimi (and from my own first pass):** The error is `Panic(uint256)` with `0x11`, not `IERC20Errors.ERC20InsufficientBalance`. Kimi's trace through `BasicVaultCommon._secureSelfBurn` is not this test's path; the V3 FullSpread override short-circuits to `_settleNamedHolder` → `_executeZapOutExactIn`, and the burn at `InBase.sol:257` hits `ERC20Repo._burn` directly, whose storage overload at `ERC20Repo.sol:360-365` has the `_decreaseBalanceOf` call commented out.

**Agreement with Astra and Grok:** the production error for this test is `Panic(0x11)`. The exact test change is a one-line replacement at `:147`. No new import. No production edit. No V4 twin edit.

**Unresolved item:** the production gap at `ERC20Repo.sol:361` is recorded but is outside REQ-H03's scope. A future PRD may re-state the expectation if the production is fixed.

---

## 7. Files examined (this cross-review)

- `docs/reviews/apex-req-h03-holder-negative/reviewers/astra-h03.md` — read in full.
- `docs/reviews/apex-req-h03-holder-negative/reviewers/grok-h03.md` — read in full.
- `docs/reviews/apex-req-h03-holder-negative/reviewers/kimi-h03.md` — read in full.
- `docs/reviews/apex-req-h03-holder-negative/reviewers/minimax-h03.md` — re-read for self-consistency. Not treated as a peer.
- `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadVaultHeldRedeem.t.sol` — re-read at `:1-23` (imports), `:142-152` (the named test), and full file for the surrounding tests.
- `contracts/vaults/standard/sy/NativeStandardYieldTarget.sol:30-45` — the SY redeem entrypoint, to confirm the V3 override short-circuits it.
- `contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardYieldExecutionTarget.sol:18-30` — the V3 FullSpread override, to confirm `holder_ = msg.sender`.
- `contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultInBase.sol:212-261` — `_executeZapOutExactIn` and `_executeFreeZapOutExactIn`, to confirm the burn site at `:257`.
- `lib/crane/contracts/tokens/ERC20/ERC20Repo.sol:214-244, 360-378` — `_decreaseBalanceOf` and `_burn` storage overload, to confirm the commented-out call at `:361` and the inline `-=` at `:362`.
- `lib/crane/contracts/interfaces/IERC20Errors.sol` — the named-error site, to confirm the import path used by precedents.

No Forge / build / test was executed. No code was edited.

---

I did not run Forge.