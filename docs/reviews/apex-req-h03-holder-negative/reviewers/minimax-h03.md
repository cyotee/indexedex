# MiniMax M3 — REQ-H03 (RES-H03) first pass (replacement-session original)

- **Session:** Labeled replacement `ses_eb8ab99f3ffe7suGF49ryUzI6t`. Not continuity. Does not recall `ses_ebdf718feffemWQNf7wuTpapqX`.
- **Scope:** REQ-H03 only. Controlling text: `docs/reviews/apex-remediation-application-2026-10-14/REMEDIATION_PRD.md` section "REQ-H03 — Insufficient-holder negatives accept any revert" (lines 138–148 of that PRD).
- **Files read for this answer:** the PRD section; `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadVaultHeldRedeem.t.sol` at `:142-152`; the production redeem path `contracts/vaults/standard/sy/NativeStandardYieldTarget.sol:30-45`; the V3 FullSpread override `contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardYieldExecutionTarget.sol:18-30`; `_executeZapOutExactIn` at `contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultInBase.sol:212-243`; the holder-burn site `lib/crane/contracts/tokens/ERC20/ERC20Repo.sol:360-378`; the named-error site `lib/crane/contracts/tokens/ERC20/ERC20Repo.sol:222-232` (`_decreaseBalanceOf`).
- **Forge:** Not run. No code edit. No peer notes read.

---

## Headline — No blocking question

The production error that insufficient holder balance must raise is **`IERC20Errors.ERC20InsufficientBalance(address,uint256,uint256)`** with arguments `(holder, 0, 1)`. The exact test change is fully determined by the current source and the PRD acceptance criteria. No owner question remains.

---

## Evidence

### 1. The error the production must raise

`ERC20Repo._decreaseBalanceOf(Storage, address account, uint256 amount)` at `lib/crane/contracts/tokens/ERC20/ERC20Repo.sol:222-232` is the canonical, named-error site for an insufficient-balance burn in this codebase. It reads:

```solidity
function _decreaseBalanceOf(Storage storage layoutStruct, address account, uint256 amount) internal {
    if (account == address(0)) {
        revert IERC20Errors.ERC20InvalidSender(account);
    }
    uint256 currentBalance = layoutStruct.balanceOf[account];
    if (currentBalance < amount) {
        revert IERC20Errors.ERC20InsufficientBalance(account, currentBalance, amount);
    }
    layoutStruct.balanceOf[account] = currentBalance - amount;
}
```

The selector is `keccak256("ERC20InsufficientBalance(address,uint256,uint256)")` (OpenZeppelin-standard). For the test path:
- `account` = `holder` (the `v3Short` address; vault share balance = 0)
- `currentBalance` = 0
- `amount` = 1 (the requested redemption)

So the error the production must raise is:

> **`IERC20Errors.ERC20InsufficientBalance(holder, 0, 1)`**

### 2. Why this is the right error for the test path

The redeem path on `internalBalance_=false` flows:

1. `IStandardizedYield(address(vault)).redeem(recipient, 1, address(token0), 0, false)` — caller is `holder` (`v3Short`).
2. `NativeStandardYieldTarget.redeem` at `contracts/vaults/standard/sy/NativeStandardYieldTarget.sol:30-45` → `else { amount_ = _standardRoute(...) }`.
3. V3 FullSpread override at `UniswapV3FullSpreadStandardYieldExecutionTarget.sol:18-24`:
   ```solidity
   function _standardRoute(IERC20 in_, uint256 amount_, IERC20 out_, uint256 minimum_, address receiver_, bool internal_)
       internal override returns (uint256 received_)
   {
       if (address(in_) != address(this) || internal_) return super._standardRoute(...);
       received_ = _settleNamedHolder(address(out_), amount_, minimum_, receiver_, msg.sender);
       if (received_ < minimum_) revert Errors.SYMinimumNotMet(minimum_, received_);
   }
   ```
   `holder_ = msg.sender = v3Short`.
4. `_settleNamedHolder` → `_executeZapOutExactIn(tokenOut, shares_=1, minAmountOut=0, recipient, holder_=v3Short)` at `UniswapV3FullSpreadStandardExchangeVaultInBase.sol:212`.
5. Pool is unlocked after `_seedExternalLiquidity` in setUp, so `canOpenBoundPoolOps()` is true; path is `_executeFreeZapOutExactIn(...)` at `:245-261`.
6. `_collectManagedFees()` succeeds, `_idleZapOutCore` succeeds (vault has a position and free balance; the proportional fractions and pool swap execute against the vault's own book, not the holder's), the slippage check passes (`minAmountOut = 0`), and then `ERC20Repo._burn(holder_=v3Short, sharesBurned=1)` at line 257 is the site that reverts because `v3Short` holds zero shares.

The error the test must identify is the one that fires at step 6, which is `IERC20Errors.ERC20InsufficientBalance(holder, 0, 1)`. An unrelated quote, pool, or route failure is excluded because the test asserts balances are unchanged and the `_idleZapOutCore` body is bounded by `minAmountOut = 0`; no other selector fits.

### 3. The current production gap (recorded, not a finding for REQ-H03)

`ERC20Repo._burn` at `lib/crane/contracts/tokens/ERC20/ERC20Repo.sol:360-365` is the burn site. It currently reads:

```solidity
function _burn(Storage storage layoutStruct, address account, uint256 amount) internal {
    // _decreaseBalanceOf(layoutStruct, account, amount);
    layoutStruct.balanceOf[account] -= amount;
    layoutStruct.totalSupply -= amount;
    emit IERC20Events.Transfer(account, address(0), amount);
}
```

The `_decreaseBalanceOf` call is **commented out**, and the inline `balanceOf[account] -= amount` is a checked subtraction in Solidity 0.8.x. With `account = v3Short` and `balanceOf[v3Short] = 0`, `0 - 1` reverts with the EVM's `Panic(uint256)` panic code `0x11` (17), not the named `IERC20Errors.ERC20InsufficientBalance`.

This is a production-side gap separate from the test-oracle gap the PRD names. REQ-H03 is scoped to the test, and the PRD's "Do not weaken the production burn" non-goal means the implementer must not relax the production check. The implementer is also not authorized to broaden production's catch behavior. **Recording this gap here does not authorize a production edit in this review session.** If the production is to raise `ERC20InsufficientBalance` for an insufficient holder balance, the `_decreaseBalanceOf` call must be restored in `_burn` (i.e., the commented-out line uncommented, and the inline `-=` removed). That is a production edit, not a test edit, and it is a separate item from REQ-H03.

### 4. No owner question remains

The PRD's acceptance criteria determine the test change:
- "The V3 test expects the holder-balance error for that route." → the error is `IERC20Errors.ERC20InsufficientBalance(holder, 0, 1)`.
- "Holder, vault, and recipient balances are unchanged." → the existing balance assertions at `:149-151` remain.
- "The code-less ordinary-success tests remain" → no change to `test_RC01_ordinaryRedeem_burnsCodelessHolder` at `:105-122` or `test_RC01_contractCaller_redeemsOnlyRequestedVaultShares` at `:89-103`.

The non-goals are clear: no `catch`, no production weakening, no substitute contract caller. The V4 twin is withdrawn (PRD line 141); no edit to it.

The implementer does not choose. The test change is a one-line replacement of the bare `vm.expectRevert()` plus an import.

---

## Exact test change

At `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadVaultHeldRedeem.t.sol`:

1. **Add the import** alongside the existing `:13` `ISecurePullErrors` import (alphabetical or as a new line):
   ```solidity
   import {IERC20Errors} from "@crane/contracts/interfaces/IERC20Errors.sol";
   ```
   The path `@crane/contracts/interfaces/IERC20Errors.sol` is the one already used by `DETFFundedStakingRepo.sol:6` and `TestBase_FullSpreadG5GuardClosure.sol:8`.

2. **Replace line 147** (`vm.expectRevert();`) with the named selector. Two equivalent forms; pick one — the second uses the suite's existing pattern of inlining the selector via `abi.encodeWithSelector` to match what the test file already does at `:82` and `:162`:
   ```solidity
   vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, holder, 0, 1));
   ```
   The selector is `keccak256("ERC20InsufficientBalance(address,uint256,uint256)")`. The three arguments are `(account, currentBalance, amount)` per the source definition at `ERC20Repo.sol:229`.

Nothing else changes. Lines `:144-145, :149-151` (the balance snapshots and unchanged-balance assertions) are correct as written; they verify the second and third PRD acceptance bullets. Lines `:143` and `:148` (the holder setup and the redeem call) are correct as written. The other tests in the file are untouched.

---

## Files examined (this answer)

- `docs/reviews/apex-remediation-application-2026-10-14/REMEDIATION_PRD.md` — re-read for the REQ-H03 section (lines 138–148).
- `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadVaultHeldRedeem.t.sol` — re-read at `:1-23` (imports), `:142-152` (the named test).
- `contracts/vaults/standard/sy/NativeStandardYieldTarget.sol:30-45` — the SY redeem entrypoint.
- `contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardYieldExecutionTarget.sol:1-31` — the V3 FullSpread override.
- `contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultInBase.sol:212-261` — `_executeZapOutExactIn` and `_executeFreeZapOutExactIn`.
- `lib/crane/contracts/tokens/ERC20/ERC20Repo.sol:214-244, 360-378` — the named-error site (`_decreaseBalanceOf`) and the burn site (`_burn`).
- `lib/crane/contracts/tokens/ERC20/IERC20Errors.sol` — referenced via the import path used by two other IndexedEx files; not re-loaded.

No other reviewer files were read. No Forge / build / test was executed. No code was edited.

---

I did not run Forge.