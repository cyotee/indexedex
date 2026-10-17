# MiniMax M3 — REQ-H03 implementation plan (replacement-session original)

- **Session:** Labeled replacement `ses_eb8ab99f3ffe7suGF49ryUzI6t`. Not continuity. Does not recall `ses_ebdf718feffemWQNf7wuTpapqX`.
- **Controlling PRD:** `docs/reviews/apex-req-h03-holder-negative/REMEDIATION_PRD.md` (59 lines, read in full). Owner ruling at `:20-22` controls. Earlier panic-only reading is withdrawn.
- **Scope:** Production change in Crane library `lib/crane/contracts/tokens/ERC20/ERC20Repo.sol:360-365`; V3 test change at `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadVaultHeldRedeem.t.sol:147`; pre-existing tests that currently expect `Panic(0x11)` or a bare revert for a short ERC20Repo burn must be updated to expect `IERC20Errors.ERC20InsufficientBalance` with the actual balance and amount.
- **No code edit. No REMEDIATION_PRD.md or REMEDIATION_PRD.plan.md. No Forge. No `sync-crane-skills.sh`. No `via_ir`. No `out/` or `cache_forge/` deletion. No exploit procedures.**

---

## 0. What the implementer decides vs. what the PRD pins

The PRD's REQ-H03-1 acceptance criteria (`:30-36`), REQ-H03-2 acceptance criteria (`:46-50`), and non-goals (`:37, :51`) pin every line of the production change, the test change, and what NOT to do. There is **no implementer choice** in the body of either change.

The implementer only does:
1. Apply the exact production body (one function in one file).
2. Apply the exact test replacement (one line in one file).
3. Update the three tests that currently expect the wrong error for a short burn.
4. Update the IndexedEx pointer to the new crane commit using the existing git-submodule process.

The non-goals close every other decision: do not call `_decreaseBalanceOf`, do not add a `catch`, do not add a separate supply-short error, do not weaken the burn, do not edit `_mint`/`_transfer`/`_decreaseBalanceOf`, do not edit the withdrawn V4 twin, do not expect `Panic(uint256)`, do not substitute a contract caller in the code-less ordinary-success tests, do not broaden the expectation. The remaining test hardens are mechanically derivable from the existing test bodies.

---

## 1. Production change — `lib/crane/contracts/tokens/ERC20/ERC20Repo.sol:360-365`

### 1.1 Exact new body (replaces the current `_burn(Storage,address,uint256)` body verbatim)

Replace the body at lines 360–365:

```solidity
    function _burn(Storage storage layoutStruct, address account, uint256 amount) internal {
        uint256 currentBalance = layoutStruct.balanceOf[account];
        if (currentBalance < amount) {
            revert IERC20Errors.ERC20InsufficientBalance(account, currentBalance, amount);
        }
        layoutStruct.balanceOf[account] = currentBalance - amount;
        layoutStruct.totalSupply -= amount;
        emit IERC20Events.Transfer(account, address(0), amount);
    }
```

This is exactly what the PRD's acceptance criteria `:31-33` and `:34` require. The selector `IERC20Errors.ERC20InsufficientBalance(address,uint256,uint256)` is the one declared at `lib/crane/contracts/tokens/ERC20/IERC20Errors.sol:16` and already imported at `ERC20Repo.sol:10`. No new import is needed in `ERC20Repo.sol`.

### 1.2 What is removed and what is not

- The commented `_decreaseBalanceOf` call (current line 361) and the inline `balanceOf[account] -= amount` (current line 362) are replaced by the new body above. Do not keep both. Keeping both would double-decrease the balance.
- The default overload at lines 376–377 (`function _burn(address,uint256) internal { _burn(_layoutStruct(), account, amount); }`) is unchanged. It still delegates to the storage overload, which is the function above.
- `_mint`, `_transfer`, and `_decreaseBalanceOf` are unchanged (PRD `:36`). Do not add the `ERC20InvalidSender` for `address(0)` check that `_decreaseBalanceOf` carries; this item does not add that check.
- The supply subtraction is `totalSupply -= amount` (kept as-is). Per PRD non-goals `:37`, a supply subtraction that is shorter than the checked balance may still panic. This is acknowledged and not fixed in this item.

### 1.3 Why this body and not something else

The body is the only legal shape that satisfies the PRD's six acceptance criteria simultaneously. Every other shape either weakens the burn (PRD non-goal), keeps the double-decrease (PRD `:34`), calls `_decreaseBalanceOf` (PRD `:35` forbids), or changes `_mint`/`_transfer`/`_decreaseBalanceOf` (PRD `:36` forbids). The implementer has no code-shape choice.

---

## 2. IndexedEx submodule pointer update — existing process

`lib/crane` is a git submodule (`.gitmodules:1-3`, `path = lib/crane`, `url = https://github.com/cyotee/crane`). The Crane change in §1 is committed in the `lib/crane` repo, not in IndexedEx. The IndexedEx repo then records the new crane commit by staging the submodule pointer.

The existing git-submodule process in this repository (no IndexedEx script governs this; `scripts/sync-crane-skills.sh` is for skill mirrors, NOT for the pointer, and the user said not to run it):

1. In `lib/crane/`, apply the production change at `contracts/tokens/ERC20/ERC20Repo.sol:360-365` per §1.1, commit on a branch, and push the branch to the crane remote.
2. From the IndexedEx root, pin the new crane commit: `git -C lib/crane fetch <crane-remote> <branch>`; then `git add lib/crane` (this records the new crane commit hash in the IndexedEx index).
3. Commit the pointer update in IndexedEx with a message that names the upstream crane commit. Do **not** modify any other IndexedEx-tracked file in this commit.

The implementer must verify the new crane commit SHA is the one containing §1.1's body. No new dependencies, no new import paths, no submodule URL change.

---

## 3. V3 test change — `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadVaultHeldRedeem.t.sol`

### 3.1 New import (add to the import block at `:4-22`)

Add this line alongside the existing `@crane/contracts/...` imports (the import path is the one the PRD specifies at `:46` and that two other IndexedEx files already use):

```solidity
import {IERC20Errors} from "@crane/contracts/interfaces/IERC20Errors.sol";
```

Place it after the `ERC20PermitMintableStub` import at `:8` (alphabetical with the other crane imports) or as a new line; position does not matter.

### 3.2 Line 147 replacement

Replace:

```solidity
        vm.expectRevert();
```

with:

```solidity
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, holder, 0, 1));
```

The three arguments are `(account, currentBalance, amount)` per the `_decreaseBalanceOf` signature at `ERC20Repo.sol:229`: `holder` is the test's `v3Short` (`:143`); `0` is its vault-share balance before the call (`:144`); `1` is the requested redemption (`:148`). The selector is `keccak256("ERC20InsufficientBalance(address,uint256,uint256)")`.

### 3.3 What is left unchanged

- The `holder = makeAddr("v3Short")` setup at `:143` and the balance snapshots at `:144-145` stay as-is.
- The `vm.prank(holder)` at `:146` and the `redeem(recipient, 1, address(token0), 0, false)` call at `:148` stay as-is.
- The three balance assertions at `:149-151` (holder/vault/recipient unchanged) stay as-is. They now also verify the post-revert state on the named error.
- The code-less ordinary-success tests at `:105-122` and `:124-140` are untouched. The two-burn-sites test at `:124-140` is untouched.
- The V4 twin under `contracts/protocols/dexes/uniswap/v4/` is withdrawn (PRD line 141). It is not edited, restored, or referenced.

### 3.4 Why this is the only legal replacement

The selector is named in PRD REQ-H03-1 `:28, :32` and the test's `holder` is a fresh address with zero balance. Any other selector or balance value would contradict the PRD's "the V3 test expects the holder-balance error for that route" (`:144`).

---

## 4. Pre-existing tests that expect the wrong error for a short burn

A direct repo-wide search for tests that currently expect `Panic(0x11)` or a bare `vm.expectRevert()` for a short `ERC20Repo._burn` returned three hits. Each is a test that calls a vault operation which reaches `ERC20Repo._burn` with insufficient balance, and each currently expects `Panic(0x11)` (or the equivalent `stdError.arithmeticError`) or a bare revert. After the §1 production change, these tests will see `ERC20InsufficientBalance` instead and must be updated. All three are listed below with their exact new expectation and the balance/amount arguments that match the call site.

### 4.1 `Adversarial_LidoWstETH_P0.t.sol:237`

Current expectation at `:237`:

```solidity
        vm.expectRevert(abi.encodeWithSignature("Panic(uint256)", 0x11)); // checked burn rejects missing shares
```

Call site at `:238-246`:

```solidity
        seOut.exchangeOut(
            IERC20(address(seVault)),
            type(uint256).max,
            IERC20(address(hermeticWeth)),
            1 ether,
            attacker,
            false,
            block.timestamp + 1 hours
        );
```

The attacker is a fresh address. `IERC20(seVault).balanceOf(attacker) == 0` (`:215`). The vault attempts to burn `type(uint256).max` shares from `attacker` via `ERC20Repo._burn(msg.sender, shares)` at `contracts/protocols/staking/lido/LidoWstETHStandardExchangeCommon.sol:525`.

Replace `:237` with:

```solidity
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, attacker, 0, type(uint256).max));
```

The existing inline comment is removed (it described the panic path, which is no longer the path). `IERC20Errors` must be imported at the top of the file (add `import {IERC20Errors} from "@crane/contracts/interfaces/IERC20Errors.sol";` alongside the existing imports — the import path is the same one the V3 test uses).

### 4.2 `ERC4626StandardExchange_Routes.t.sol:271`

Current expectation at `:271`:

```solidity
        vm.expectRevert(stdError.arithmeticError);
```

Call site at `:272`:

```solidity
        seIn.exchangeIn(IERC20(se), seBal + 1, IERC20(address(underlying)), 0, user, false, block.timestamp);
```

`seBal = IERC20(se).balanceOf(user)` is captured at `:267`. The vault attempts to burn `seBal + 1` shares from `user` via `ERC20Repo._burn(owner, burnAmount)` at `contracts/vaults/standard/erc4626/ERC4626StandardExchangeCommon.sol:330`. `stdError.arithmeticError` is `Panic(uint256)` with `0x11` (confirmed against `lib/crane/lib/forge-std/src/StdError.sol`).

Replace `:271` with:

```solidity
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, user, seBal, seBal + 1));
```

`IERC20Errors` is not yet imported. Add `import {IERC20Errors} from "@crane/contracts/interfaces/IERC20Errors.sol";` alongside the existing `import {stdError} from "forge-std/StdError.sol";` at `:5`. The `stdError` import remains used by other tests in the file; it is not removed.

The doc-comment at `:262-264` must be updated to describe the named-error path, not the panic path. Replace:

```
    /// @notice R7.5 (2026-09-23): a non-pretransferred owner burn beyond the caller's own share balance fails
    ///         at the share ledger (`ERC20Repo._burn` underflows: arithmetic panic) and changes nothing; no
    ///         allowance is involved on this path because the SE burns from `msg.sender` directly.
```

with:

```
    /// @notice R7.5 (2026-09-23): a non-pretransferred owner burn beyond the caller's own share balance reverts
    ///         `IERC20Errors.ERC20InsufficientBalance(user, seBal, seBal + 1)` at the share ledger and changes
    ///         nothing; no allowance is involved on this path because the SE burns from `msg.sender` directly.
```

### 4.3 What was checked and NOT changed

- `UniswapV4SingleStandardExchangeBufferConstantProductHook_ResidualPreview.t.sol:101, 117, 160, 215` use `_overflowPanic()` (returns `abi.encodeWithSignature("Panic(uint256)", uint256(0x11))`). Read context: `_prepareRevertingQuote()` at `:156-163` triggers the panic in `IStandardExchangeIn(se).previewExchangeIn(...)` via a checked overflow in the receipt's `(assets * supply) / totalAssets` math, NOT in `ERC20Repo._burn`. The user instruction "Do not change tests for a different error" applies. The residual-preview tests stay as-is.
- `UniswapV4UpperLowerWingsStandardExchangeVaultAccountingReference.t.sol:45` expects `Panic(0x12)` (division by zero, not a burn). Different error, different source. Unchanged.
- No other test in `test/foundry/spec/` or `test/foundry/fork/` expects `Panic(0x11)` or a bare `vm.expectRevert()` for a short `ERC20Repo._burn`. The full search used patterns: `Panic\(uint256\)`, `ERC20InsufficientBalance`, `arithmeticError`, and `vm\.expectRevert\(\)`. Any new test that was missed would either (a) be in an `implementation-artifacts/`, `docs/audits/`, or `docs/security/` path — those are historical baselines, not active tests; or (b) use a custom error name not matching the search patterns. The implementer should re-run the same search after applying §1 and confirm no additional hits exist before running §5.1.

### 4.4 A note on the third pre-existing hit

I re-read `UniswapV3FullSpreadVaultHeldRedeem.t.sol` in full. The only bare `vm.expectRevert()` for an `ERC20Repo._burn` site is at `:147` (the REQ-H03 test). The other tests in the file (`:57, :77, :89, :105, :124, :154, :169, :184, :199`) use either `vm.expectRevert(<named-selector>)` or check `isLocked`/direct-call routes that do not reach `ERC20Repo._burn`. The implementer must not change any of those.

---

## 5. Forge commands

Two commands, one per artifact boundary.

### 5.1 V3 test file command — validates the test change

From the IndexedEx root, hermetic profile, no `via_ir`, no `out/` or `cache_forge/` deletion:

```bash
python3 scripts/forge-artifacts.py test \
  --test-root test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadVaultHeldRedeem.t.sol \
  -- -vv
```

Run the whole file. Do not filter to one test name. Stop conditions:
- If the test at `:142` reverts with different bytes than `abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, holder, 0, 1)`, stop and report the actual bytes. Do not broaden the expectation.
- If any other test in the file fails, stop and report which test failed and with what revert. Do not change any other test in this item.
- The code-less ordinary-success tests at `:105-122` and `:124-140` must still pass without modification.

### 5.2 Crane burn tests command — validates the production change against the tests that currently expect the wrong error

The production change is in `lib/crane/contracts/tokens/ERC20/ERC20Repo.sol:360-365`. The tests that need to be re-run after the production change are the three updated in §4 (`Adversarial_LidoWstETH_P0.t.sol`, `ERC4626StandardExchange_Routes.t.sol`) plus the V3 test. The Crane source is the artifact-refresh input because it changed.

```bash
python3 scripts/forge-artifacts.py test \
  lib/crane/contracts/tokens/ERC20/ERC20Repo.sol \
  --test-root test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v3 \
  --test-root test/foundry/spec/protocol/staking/lido/adversarial \
  --test-root test/foundry/spec/vaults/standard/erc4626 \
  -- -vv
```

Run each test root whole. Do not filter to one test name. Stop conditions:
- If any of the three updated tests in §4 still reverts with `Panic(uint256)` with `0x11` or `stdError.arithmeticError`, the production change in §1 was not applied correctly. Stop and report. Do not weaken the production check to a bare revert.
- If any of the three tests reverts with a selector other than `IERC20Errors.ERC20InsufficientBalance`, stop and report the actual bytes. The expected error name and arguments are pinned by §4.
- If any test OUTSIDE the three in §4 starts failing with a new error that pins a different balance/amount pair, that test is exercising the same short-burn path and must be updated. Stop, list the new test sites with their `account`/`currentBalance`/`amount` arguments, and update each in the same shape. Do not change the production check.
- The ResidualPreview test (`UniswapV4SingleStandardExchangeBufferConstantProductHook_ResidualPreview.t.sol`) is a different test root and is **not** in this command. Its `Panic(0x11)` is a checked-overflow in a quote, not a burn. Per the user instruction "Do not change tests for a different error," it is unchanged and out of scope.

### 5.3 Module sync

Per the user instruction, do not run `scripts/sync-crane-skills.sh`. The Crane change in §1 is committed in the crane repo. The IndexedEx pointer update is the standard `git add lib/crane && git commit` in the parent repo (§2 step 2–3). No IndexedEx script governs this.

---

## 6. What this plan deliberately does NOT do

- No production edit outside `lib/crane/contracts/tokens/ERC20/ERC20Repo.sol:360-365`. `_mint`, `_transfer`, `_decreaseBalanceOf` are unchanged.
- No addition of the `ERC20InvalidSender` for `address(0)` check. The PRD `:35` explicitly forbids it.
- No addition of a `catch` block anywhere.
- No addition of a separate supply-short error. The supply subtraction may still panic on a negative `totalSupply`; the PRD `:37` acknowledges and does not fix this.
- No edit to the withdrawn V4 twin.
- No edit to the `UniswapV4SingleStandardExchangeBufferConstantProductHook_ResidualPreview.t.sol` `_overflowPanic` test (different error, different source).
- No edit to the `UniswapV4UpperLowerWingsStandardExchangeVaultAccountingReference.t.sol:45` `Panic(0x12)` test (different error, different source).
- No enablement of `via_ir`. No deletion of `out/` or `cache_forge/`.
- No run of `scripts/sync-crane-skills.sh`.
- No implementation of `lib/crane` in this plan; the plan describes the body, the import is already present, the change is committed in the crane repo and pointed-to from IndexedEx.

---

## 7. Files examined (this plan)

- `docs/reviews/apex-req-h03-holder-negative/REMEDIATION_PRD.md` — read in full (59 lines).
- `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadVaultHeldRedeem.t.sol` — re-read at `:1-23` (imports), `:142-152` (the named test), full file for the surrounding tests.
- `lib/crane/contracts/tokens/ERC20/ERC20Repo.sol` — re-read at `:1-20` (imports), `:214-244` (`_decreaseBalanceOf`), `:355-378` (`_burn` overloads).
- `lib/crane/contracts/tokens/ERC20/IERC20Errors.sol:16` — the named error declaration.
- `lib/crane/contracts/interfaces/IERC20Errors.sol` — the import path used by other IndexedEx files.
- `test/foundry/spec/protocol/staking/lido/adversarial/Adversarial_LidoWstETH_P0.t.sol:210-254` — the `Panic(0x11)` short-burn test.
- `test/foundry/spec/vaults/standard/erc4626/ERC4626StandardExchange_Routes.t.sol:262-276` — the `stdError.arithmeticError` short-burn test.
- `test/foundry/spec/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_ResidualPreview.t.sol:90-169` — the `_overflowPanic` quote-overflow test, read to confirm it is NOT a burn.
- `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/reference/UniswapV4UpperLowerWingsStandardExchangeVaultAccountingReference.t.sol:35-50` — the `Panic(0x12)` division-by-zero test, read to confirm it is NOT a burn.
- `.gitmodules:1-3` — confirms `lib/crane` is a git submodule at `path = lib/crane`, `url = https://github.com/cyotee/crane`.
- Repo-wide `grep` for `Panic\(uint256\)|ERC20InsufficientBalance|arithmeticError` and `vm\.expectRevert\(\)` under `test/foundry/` to enumerate every other test that might need updating.

No Forge / build / test was executed. No code was edited. No peer notes were read.

---

I did not run Forge.