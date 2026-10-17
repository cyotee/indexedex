# MiniMax M3 — REQ-V4-01 plan-readiness pass

- **Date:** 2026-10-14
- **Reviewer:** MiniMax M3, independent plan-readiness pass. No peer notes read. No PRD or code was read or written this round except the source files explicitly named in the task. No Forge run. No exploit procedure.
- **Verdict:** **Ready. The PRD closes every implementer choice.** A plan can be written with no further owner decision.

## Sources re-read this round

- `docs/reviews/apex-req-v4-01-internal-settlement/REMEDIATION_PRD.md` (71 lines, full read).
- `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardYieldExecutionTarget.sol` (37 lines, full read).
- `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeInTarget.sol` (119 lines, full read).
- `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeInExecutionDelegate.sol` (35 lines, full read).
- `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeInBase.sol:146-152` (the inherited `_executeZapOutExactIn` declaration only).
- `test/foundry/spec/protocol/dexes/uniswap/v4/UniswapV4StandardExchangeVaultHeldRedeem.t.sol` (existence check; the test file at that path is the legacy V4 vault-held redeem test the PRD names).
- `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeDFPkg.sol:76,100,198,200,311` (the `UniswapV4StandardExchangeInFacet` deployment path).

## Verdict

**Ready. No owner decision is needed before writing the plan.** The PRD's owner ruling at `apex-req-v4-01-internal-settlement/REMEDIATION_PRD.md:9` resolves the only item I had previously flagged: delete `executeNamedHolderRedemption` and also delete the four-argument `executeZapOutExactIn` from the legacy V4 delegate. The PRD's acceptance criteria at `:43-53` and required-repair at `:24-39` close every implementer choice. A plan can be written that names the exact edit order, exact calls, what is deleted, which deployed unit is measured, and which test file to run, with no further owner decision.

The owner did not pick a function name, error name, or line layout that the recorded text does not already select. The PRD at `:29-31` specifies the replacement body verbatim. The PRD at `:38` specifies the second replacement body verbatim. The PRD at `:37` specifies the two deletions. The PRD at `:41` specifies the deployed unit to measure. The PRD at `:66` specifies the test file to re-read and the artifact-refresh command.

## Mechanical closures a plan must state

These are specifications to carry forward, not questions for the owner. The plan must state each so the implementer does not choose.

### 1. Edit order (4 file edits + 1 preservation)

The plan must state this order so the build state at each step is consistent and compilable. The four edits are listed below; the first three are production edits. The fourth file (the InBase) is read-only.

1. **Edit `UniswapV4StandardExchangeInExecutionDelegate.sol` first**: delete `executeNamedHolderRedemption` (lines 13-18) and `executeZapOutExactIn` (lines 27-34). Keep `executeZapInDeposit` (lines 20-25) and the `SELF` immutable and the `DelegateCallRequired` error (lines 9-10). After this edit, the delegate has only `executeZapInDeposit`.
2. **Edit `UniswapV4StandardExchangeInTarget.sol` second**: replace the body of `_delegateExecuteZapOutExactIn` (lines 101-118) with a direct internal call to `_executeZapOutExactIn(tokenOut, sharesBurned, minAmountOut, recipient, address(this))`. Then delete the `_delegateExecuteZapOutExactIn` function (lines 101-118) entirely. Update the call site at line 81: `amountOut = _executeZapOutExactIn(address(tokenOut), actualIn, minAmountOut, recipient, address(this));`. Do not touch `_delegateExecuteZapInDeposit` (lines 89-99) — the deposit `functionDelegateCall` to `executeZapInDeposit` stays.
3. **Edit `UniswapV4StandardYieldExecutionTarget.sol` third**: replace the body of `_settleNamedHolder` (lines 29-33) with `amount_ = _executeZapOutExactIn(tokenOut_, shares_, minimum_, receiver_, holder_);`. Keep the `nonReentrant` modifier on line 27. Keep the `_pokeBoundPoolTwap()` call on line 35. The assembly revert pattern on line 33 is dropped because the direct internal call reverts with a normal Solidity error from `_executeZapOutExactIn`. The `nonReentrant` lock is on the wrapper, not on the inherited call, so the lock is not nested.
4. **Do not edit `UniswapV4StandardExchangeInBase.sol`**. The inherited `_executeZapOutExactIn` (lines 146-152) and `_executeFreeZapOutExactIn` (lines 186-192) already accept `holder_`. No change to the base file is required for this item. The `holder_` parameter was added in the prior RC-01 work.

The four steps are independent. The plan must state this order because step 1 removes a callable function (so the delegate at the InTarget loses the 4-arg function), step 2 removes the InTarget's helper that called it, and step 3 removes the yield target's only call to the 5-arg function. The order is not strictly required for compilation, but is the cleanest sequence: remove the function before removing its last call site. A reverse order would compile, but leaves the project without a working build for the duration of the edits.

### 2. Exact calls (verbatim bodies)

The plan must include the verbatim replacement bodies so the implementer does not paraphrase.

- **`_settleNamedHolder` in `UniswapV4StandardYieldExecutionTarget.sol`** (replaces lines 29-35):

  ```solidity
  function _settleNamedHolder(address tokenOut_, uint256 shares_, uint256 minimum_, address receiver_, address holder_)
      private nonReentrant returns (uint256 amount_)
  {
      amount_ = _executeZapOutExactIn(tokenOut_, shares_, minimum_, receiver_, holder_);
      _pokeBoundPoolTwap();
  }
  ```

  The `nonReentrant` modifier stays. The two assignments stay in the order: internal call first, then TWAP poke. Do not copy V3's immediate-return line (V3 does not have the TWAP poke; this is recorded at PRD line 33).

- **The call site in `_exchangeIn` in `UniswapV4StandardExchangeInTarget.sol`** (replaces line 81):

  ```solidity
  amountOut = _executeZapOutExactIn(address(tokenOut), actualIn, minAmountOut, recipient, address(this));
  ```

  The five arguments match the inherited declaration at `UniswapV4StandardExchangeInBase.sol:146-152`: `address tokenOut, uint256 sharesBurned, uint256 minAmountOut, address recipient, address holder_`. The fifth is `address(this)` because the shares were already pulled onto the vault in the prior step (line 80: `_secureShareDelivery(amountIn, pretransferred);`).

- **The deleted `_delegateExecuteZapOutExactIn` function in `UniswapV4StandardExchangeInTarget.sol`** (lines 101-118): the entire function is removed. The import `StandardExchangeInExecutionBase` (line 3) is still needed for `_delegateExecuteZapInDeposit`, so the import stays.

### 3. What is deleted

The plan must list each deletion so the implementer does not leave dead code or remove a function that is still in use.

- **From `UniswapV4StandardExchangeInExecutionDelegate.sol`**: `executeNamedHolderRedemption` (lines 13-18) and `executeZapOutExactIn` (lines 27-34). The owner ruling at PRD line 9 names both. The `SELF` immutable and the `DelegateCallRequired` error stay because `executeZapInDeposit` does not need them (it has no SELF check), but the file is read-only, so they may be removed only if the plan explicitly says so. The PRD does not explicitly say to remove them. The plan should keep them to avoid an extra edit.
- **From `UniswapV4StandardExchangeInTarget.sol`**: `_delegateExecuteZapOutExactIn` (lines 101-118). The function is no longer called after step 2. Its removal is recorded in the PRD at line 38.
- **The deployment delegate `UNISWAP_V4_STANDARD_EXCHANGE_IN_EXECUTION_DELEGATE` is not deleted.** The PRD non-goal at line 58 says "Do not delete the execution delegate. Do not delete `executeZapInDeposit`." The delegate contract remains deployed; only the two functions named above are removed from it.
- **The import of `Address` in `UniswapV4StandardExchangeInTarget.sol`** (line 10) is still used by the deposit `functionDelegateCall` at line 93. The import stays.
- **`executeZapInDeposit` in the delegate is not deleted.** The PRD non-goal at line 58 says "Do not delete `executeZapInDeposit`." It stays.
- **`_delegateExecuteZapInDeposit` in `InTarget.sol`** is not deleted. The deposit `functionDelegateCall` to `executeZapInDeposit` stays.
- **V3 FullSpread, hookless, and Pons copies of similar named functions are not edited.** PRD line 39 says "Do not edit V3 FullSpread, hookless, or Pons." Those files are not in this plan's edit list.
- **`_redeemVaultHeld` and `_standardRoute` in `UniswapV4StandardYieldExecutionTarget.sol`** are not edited. PRD line 36 says "Do not change `_redeemVaultHeld` or `_standardRoute`. They already pass the holder." Lines 11-15 and 17-24 stay as-is.

### 4. Which deployed unit is measured

The plan must state the deployed unit whose runtime is checked after the edits, and the threshold.

- **Unit**: `UniswapV4StandardExchangeInFacet`. This is the deployed facet registered in `UniswapV4StandardExchangeDFPkg.sol:76,100,198,200,311`. The PRD at line 41 names it: "the deployed `UniswapV4StandardExchangeInFacet` runtime exceeds 24,576 bytes after the edit, stop and report the measured size."
- **Threshold**: 24,576 bytes (EIP-170). The PRD at line 41 says "Do not restore the hop, add a self-call, paste the settlement body, or enable `via_ir` to get under the limit."
- **If the unit is oversized**: stop. Do not continue. Do not restart Forge. Report the measured size and the unit's identity. The plan should say: "If the deployed `UniswapV4StandardExchangeInFacet` runtime exceeds 24,576 bytes after the edit, do not restore the hop, do not add a self-call, do not paste the settlement body, do not enable `via_ir`. Stop and report the measured size and the unit's identity."

### 5. Test file to run

The plan must state which test file to run and which test results to verify.

- **Test file**: `test/foundry/spec/protocol/dexes/uniswap/v4/UniswapV4StandardExchangeVaultHeldRedeem.t.sol`. This is the legacy V4 vault-held redeem test the PRD at line 66 says to "re-read."
- **Command**: `forge test --match-path test/foundry/spec/protocol/dexes/uniswap/v4/UniswapV4StandardExchangeVaultHeldRedeem.t.sol -vv`.
- **What to verify**:
  - The test passes (exit 0; all assertions green).
  - The test does not assert the old `delegatecall` to `executeNamedHolderRedemption` (the old hop is gone).
  - The test does not assert the old `executeZapOutExactIn` wrapper on the legacy V4 delegate (the wrapper is deleted).
  - The test does verify the new internal call path: vault-held redemption passes `address(this)`, ordinary redemption passes `msg.sender`, both reach the inherited `_executeZapOutExactIn`, and the `nonReentrant` and `_pokeBoundPoolTwap()` are still in place.
- **Refresh artifacts before forge test**: `python3 scripts/forge-artifacts.py test --source contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeInExecutionDelegate.sol --source contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeInTarget.sol --source contracts/protocols/dexes/uniswap/v4/UniswapV4StandardYieldExecutionTarget.sol --test-root test/foundry/spec/protocol/dexes/uniswap/v4/UniswapV4StandardExchangeVaultHeldRedeem.t.sol -- -vv` (or the equivalent helper invocation per the repo's `docs/testing/ARTIFACT_BUILDS.md` workflow). The helper accepts `sources` as optional and requires `--test-root`. This is a production edit, so the artifact helper's build step is required.

### 6. What to report

The plan must state what to report after the run, so the implementer does not pick a report shape.

- **Toolchain**: Forge version, Solc version, default Foundry profile, `FOUNDRY_PROFILE` unset, `via_ir` false.
- **Helper exit codes**: helper `plan` exit, helper `test` exit, helper `forge test` exit.
- **Forge test results**: pass / fail / skip counts for the legacy V4 vault-held redeem test, and for any other test selected by the helper.
- **Facet size**: the measured runtime of `UniswapV4StandardExchangeInFacet` after the edit, and whether it is under 24,576 bytes.
- **Scanner non-claim**: this PRD does not require a scanner run. The original task did not include a scanner pass; do not add one.
- **A present call is not a pass until that run is reported.** (PRD line 66.)

## What I am not asking

- I am not asking the owner to pick a function name. The PRD at line 26 says "Keep the function name, the arguments, and `nonReentrant`." The function is `_settleNamedHolder`.
- I am not asking the owner to pick an error name. The PRD at line 33 says the direct internal call reverts with a normal Solidity error from `_executeZapOutExactIn`. No new error is introduced.
- I am not asking the owner to pick a line layout. The replacement bodies are specified in the PRD at lines 29-31 and line 38.
- I am not asking the owner to pick the holder for vault-held or ordinary redemption. The PRD at line 48 says "Vault-held redemption still passes `address(this)`. Ordinary redemption still passes `msg.sender`." The V3 model at `UniswapV3FullSpreadStandardYieldExecutionTarget.sol:15,22` implements this.
- I am not asking the owner to pick which deployed unit to measure. The PRD at line 41 says "the deployed `UniswapV4StandardExchangeInFacet` runtime exceeds 24,576 bytes."
- I am not asking the owner to pick the test file. The PRD at line 66 says "Re-read the existing legacy V4 vault-held redeem test." The existing test is at `test/foundry/spec/protocol/dexes/uniswap/v4/UniswapV4StandardExchangeVaultHeldRedeem.t.sol`.
- I am not asking the owner to pick the artifact-refresh command. The PRD at line 66 says "Refresh artifacts before `forge test` with `python3 scripts/forge-artifacts.py`." The repo's `docs/testing/ARTIFACT_BUILDS.md` defines the helper's argument shape.

## Summary

**Ready. No owner decision is needed before writing the plan.** The PRD at `docs/reviews/apex-req-v4-01-internal-settlement/REMEDIATION_PRD.md` closes every implementer choice:

- The edit order is mechanical: delegate first, InTarget second, yield target third, base not edited.
- The exact calls are specified at PRD lines 29-31 and line 38.
- What is deleted is specified at line 37 (two functions in the delegate) and line 38 (one helper in InTarget).
- The deployed unit to measure is `UniswapV4StandardExchangeInFacet`, at PRD line 41.
- The test file to run is `test/foundry/spec/protocol/dexes/uniswap/v4/UniswapV4StandardExchangeVaultHeldRedeem.t.sol`, at PRD line 66.
- The artifact-refresh command is `python3 scripts/forge-artifacts.py`, at PRD line 66.

A plan can be written that names these and has no further implementer choice.

I did not run Forge.