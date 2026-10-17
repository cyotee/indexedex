# MiniMax M3 — REQ-C06 implementation plan, replacement session

- **Label:** replacement session `ses_ebdf718feffemWQNf7wuTpapqX`. I do not recall `ses_ec41255ceffeVhrySLQe8hwwMC`. No peer notes were read. No code edits in this session. No `REMEDIATION_PRD.plan.md`. No Forge. No exploit procedures.
- **Controlling PRD:** `docs/reviews/apex-req-c06-pretransfer-caller-first/REMEDIATION_PRD.md` (DRAFT 2026-10-15), read in full (98 lines).
- **Named interface (read for context only):** `lib/crane/contracts/tokens/ERC5115/IERC5115_StandardizedYield.sol` — not in scope for this item.
- **Scope guardrails:** legacy `contracts/protocols/dexes/uniswap/v4` is the tree being deleted and is out of scope; do not edit. EtherFi (`EtherFiWeETHStandardExchangeOutTarget.sol:61` and `:84`) and Slipstream (`SlipstreamStandardExchangeOutTarget.sol:85`) are recorded-not-edited; do not edit. A false flag does not gain the caller check. The implementer does not split facets. A bare `vm.expectRevert()` is forbidden — every assertion that expects a specific revert must use `ISecurePullErrors.EOAPretransferNotAllowed.selector` or `ISecurePullErrors.TransferDeltaInsufficient(used, available)` (or the abi-encoded equivalent).

---

## 0. Pre-flight (before any edit)

These checks must pass before the implementer opens a file. None are owner decisions; they are repository rules from `CLAUDE.md`.

0.1. **Toolchain.** Confirm `forge --version` reports Foundry **1.5.1**, `solc --version` reports **0.8.35**, `optimizer_runs == 1`, EVM `prague`, `via_ir == false`. Do not relax `via_ir`.

0.2. **Warm artifact cache.** Read `foundry.toml`. Confirm `cache_path = 'cache_forge'` and `out = 'out'`. If a prior green run exists in another worktree or the warm primary repo, copy both directories into the working tree per `CLAUDE.md` §9. Do not delete `out/` or `cache_forge/` mid-program.

0.3. **Cold compile budget.** First `forge build` in a fresh worktree is expected to take 20–40+ minutes. Use a multi-hour timeout. Do not abort.

0.4. **No pending source changes outside this plan.** `git status` must show only the files this plan lists (plus generated artifacts and the two new test files at §3.3 and §3.4). If unrelated modifications exist, stop and report.

0.5. **Tag the baseline.** `git rev-parse HEAD` and record as `REQ-C06 plan baseline`. Used to confirm only the listed files changed.

0.6. **Verify each of the 21 named measurement lines still calls `_pretransferCredit`.** This is a precondition for any edit. The grep that must succeed at the start:

```bash
grep -nE '_pretransferCredit\(' \
    contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/UniswapV4FullSpreadHooklessStandardExchangeVaultOutExecuteTarget.sol \
    contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/UniswapV4FullSpreadPonsFamilyHookOutExecuteTarget.sol \
    contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultOutExecutionDelegate.sol \
    contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeOutTarget.sol \
    contracts/protocols/dexes/camelot/v2/CamelotV2StandardExchangeOutTarget.sol \
    contracts/protocols/staking/rocket-pool/RocketPoolRETHStandardExchangeOutTarget.sol \
    contracts/protocols/staking/lido/LidoWstETHStandardExchangeOutTarget.sol
```

Expected matches (21 total): hookless at lines 94 and 165; Pons at lines 94 and 165; V3 at lines 32 (definition import), 102 (mint function only); V2 at lines 462, 547, 623, 693, 794, 905, 972; Camelot at lines 411, 513, 596, 663, 766; Rocket at lines 60, 82; Lido at lines 64, 85. If any named line does not appear, or a new line appears, stop and report. Do not choose another site.

---

## 1. Source-edit phase (7 production files)

Edit in the order listed. Each step's fix is exactly the document that follows; the implementer does not design. The 7 production files are: hookless, Pons, V3 mint delegate, V2, Camelot, Rocket, Lido. EtherFi, Slipstream, and the deleted V4 legacy tree are NOT touched.

### Step 1 — `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/UniswapV4FullSpreadHooklessStandardExchangeVaultOutExecuteTarget.sol`

`LocalCreditLib` is already imported at line 18. No new import.

**1.1 `_executeZapInMintExactOut` (around line 94, mint branch).** Insert immediately before line 94 (`uint256 credit = pretransferred ? _pretransferCredit(tokenIn, maxAmountIn) : 0;`). The exact new statement:

```solidity
if (pretransferred) {
    LocalCreditLib.requirePretransferCaller(msg.sender);
}
```

The statement at line 94 and everything after it stays in place. The `_requirePrepaidCredit` helper (lines 139-142) is unchanged. The `if (pretransferred)` block at lines 100-103 is unchanged.

**1.2 `_executeDirectOut` (around line 165, direct-out branch).** Insert immediately before line 165 (`frame.credit = prepaid ? _pretransferCredit(tokenIn, maximum) : 0;`). The exact new statement:

```solidity
if (prepaid) {
    LocalCreditLib.requirePretransferCaller(msg.sender);
}
```

The statement at line 165 and everything after it stays in place.

### Step 2 — `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/UniswapV4FullSpreadPonsFamilyHookOutExecuteTarget.sol`

`LocalCreditLib` is already imported at line 18. No new import.

**2.1 `_executeZapInMintExactOut` (around line 94).** Same insert as Step 1.1 (use `if (pretransferred)`).

**2.2 `_executeDirectOut` (around line 165).** Same insert as Step 1.2 (use `if (prepaid)`).

### Step 3 — `contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultOutExecutionDelegate.sol`

`LocalCreditLib` is already imported at line 7. No new import. **This is the relocate case.**

**3.1 `executeZapInMintExactOut` (lines 99-127).** The PRD requires the V3 mint delegate fix to be a relocate, not an add. Do the following:

- **Remove** the line 109 statement `LocalCreditLib.requirePretransferCaller(msg.sender);` from inside the existing `if (pretransferred)` block at lines 108-112.
- **Insert** after line 101 (`IERC20 token = IERC20(tokenIn);`) and before line 102 (`uint256 credit = pretransferred ? _pretransferCredit(token, maxAmountIn) : 0;`), a new guard block:

```solidity
if (pretransferred) {
    LocalCreditLib.requirePretransferCaller(msg.sender);
}
```

- The later `if (pretransferred)` block at lines 108-112 retains only the credit comparison and the `pullAmount = credit;` assignment:

```solidity
if (pretransferred) {
    if (amountIn > credit) revert ISecurePullErrors.TransferDeltaInsufficient(amountIn, credit);
    pullAmount = credit;
}
```

- The function's `if (sharesOut == 0) revert UniswapV3Exchange_ZeroAmount();` (line 100), the `IERC20 token = IERC20(tokenIn);` (line 101), the `uint256 credit = pretransferred ? _pretransferCredit(token, maxAmountIn) : 0;` (line 102), the `amountIn = _amountInForZapMint(tokenIn, sharesOut, credit);` (line 103), the `if (amountIn > maxAmountIn) revert UniswapV3ExchangeOut_InsufficientInput();` (line 104), the balance snapshot (line 106), the `pullAmount = amountIn;` (line 107), the `uint256 providedAmountIn = _secureTokenTransfer(token, pullAmount, pretransferred);` (line 113), the refund block (lines 115-122), `_collectIfIdle()` (line 124), `_mint` (line 125), and `_syncVaultReserves` (line 126) are all unchanged. The `executeZapOutWithdrawal` function (lines 14-70) is unchanged.

### Step 4 — `contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeOutTarget.sol`

`LocalCreditLib` is NOT imported. Add the import.

**4.1 Import.** In the import block, add one line:

```solidity
import {LocalCreditLib} from "contracts/utils/LocalCreditLib.sol";
```

The import must go in the same import group as the other IndexedEx imports (after line 38 `import {VaultFeeOracleQueryAwareRepo} from "contracts/oracles/fee/VaultFeeOracleQueryAwareRepo.sol";` and before the UniswapV2-specific imports, or in the same Crane utility group — pick the group the file already uses for `ISecurePullErrors.sol` if present). The plan's exact placement: place it on the first line of the IndexedEx `contracts/...` import group, immediately above the existing first IndexedEx import on line 38. The implementer is not given a choice on placement; this is the first IndexedEx import slot.

**4.2 Seven inserts.** For each of the seven lines below, insert the guard block immediately before the `uint256 credit = ...` / `uint256 lpCredit = ...` / `uint256 shareCredit = ...` / `uint256 zapShareCredit = ...` / `uint256 zapCredit = ...` statement on that line. All seven lines use `if (pretransferred)` (none use `prepaid`):

- Line **462** (pass-through swap): insert `if (pretransferred) { LocalCreditLib.requirePretransferCaller(msg.sender); }` immediately before `uint256 credit = pretransferred ? _pretransferCredit(tokenIn, maxAmountIn) : 0;`.
- Line **547** (pass-through zap-out): same shape.
- Line **623** (underlying-pool vault deposit): same shape. The local variable is `lpCredit`.
- Line **693** (underlying-pool vault withdrawal): same shape. The local variable is `shareCredit`, and the token is `IERC20(address(this))`.
- Line **794** (zap-out vault withdrawal): same shape. The local variable is `zapShareCredit`, and the token is `IERC20(address(this))`.
- Line **905** (`_exchangeOut_zapInVaultDeposit`): same shape. The local variable is `zapCredit`.
- Line **972** (`_exchangeOut_passThroughZapIn`): same shape.

**4.3 The guard block is identical at all seven sites:** `if (pretransferred) { LocalCreditLib.requirePretransferCaller(msg.sender); }`. No other line changes. The quote and the `_secureTokenTransfer` / `_secureSelfBurn` calls below each guard are unchanged. The `if (amountIn > maxAmountIn) revert MaxAmountExceeded(maxAmountIn, amountIn);` input-ceiling comparisons at lines 457, 540, 615, 686, 791, 900, 970 stay where they are. The `_refundExactOutCredit` calls at lines 467, 549, 625, 702, 796, 913, 982 are unchanged.

### Step 5 — `contracts/protocols/dexes/camelot/v2/CamelotV2StandardExchangeOutTarget.sol`

`LocalCreditLib` is NOT imported. Add the import.

**5.1 Import.** In the import block, add one line:

```solidity
import {LocalCreditLib} from "contracts/utils/LocalCreditLib.sol";
```

Place it on the first line of the IndexedEx `contracts/...` import group, immediately above the existing first IndexedEx import on line 18 (`import {ConstProdReserveVaultRepo} from ...`). Same group convention as Step 4.1.

**5.2 Five inserts.** For each of the five lines below, insert the guard block immediately before the `_pretransferCredit` assignment. All five lines use `if (pretransferred)`:

- Line **411** (pass-through swap).
- Line **513** (pass-through zap-out).
- Line **596** (underlying-pool vault deposit). The local variable is `lpCredit`.
- Line **663** (underlying-pool vault withdrawal). The local variable is `shareCredit`, and the token is `IERC20(address(this))`.
- Line **766** (zap-out vault withdrawal). The local variable is `zapShareCredit`, and the token is `IERC20(address(this))`.

**5.3 The guard block is identical at all five sites:** `if (pretransferred) { LocalCreditLib.requirePretransferCaller(msg.sender); }`. No other line changes. The quote and the input-ceiling comparisons (`if (amountIn > maxAmountIn) revert MaxAmountExceeded(...);` at lines 407, 504, 588, 657, 761) stay where they are. The `_secureTokenTransfer` / `_secureSelfBurn` calls and the `_refundExactOutCredit` calls below each guard are unchanged.

### Step 6 — `contracts/protocols/staking/rocket-pool/RocketPoolRETHStandardExchangeOutTarget.sol`

`LocalCreditLib` is NOT imported. Add the import.

**6.1 Import.** In the import block, add one line:

```solidity
import {LocalCreditLib} from "contracts/utils/LocalCreditLib.sol";
```

Place it on the first line of the IndexedEx `contracts/...` import group, immediately above `import {RocketPoolRETHStandardExchangeCommon}` on line 8. Same group convention.

**6.2 Two inserts.** Both lines use `if (pretransferred)`:

- Line **60** (asset→SE mint). Insert `if (pretransferred) { LocalCreditLib.requirePretransferCaller(msg.sender); }` immediately before `uint256 credit = pretransferred ? _pretransferCredit(tokenIn, maxAmountIn) : 0;`.
- Line **82** (asset→asset). Insert the same guard block immediately before the line 82 `uint256 credit = pretransferred ? _pretransferCredit(tokenIn, maxAmountIn) : 0;`.

**6.3 No other line changes.** The `_reserveBeforePretransfer` call at line 62, the `_quoteMintAtReserve` call at line 63, the `_securePull` call at line 65, the `_refundExactOutCredit` call at line 70, the `_bestEffortStakeOverageTowardTarget()` call at line 72, and the `_syncAllExpectedHoldReserves` call at line 74 are unchanged. The line 80 quote, the line 81 input-ceiling check (`if (amountIn > maxAmountIn) revert Slippage();`), the line 83 `_securePull`, the line 86 `_refundExactOutCredit`, and the line 87 `_syncAllExpectedHoldReserves` are unchanged.

### Step 7 — `contracts/protocols/staking/lido/LidoWstETHStandardExchangeOutTarget.sol`

`LocalCreditLib` is NOT imported. Add the import.

**7.1 Import.** Same as Step 6.1. Place on the first line of the IndexedEx `contracts/...` import group, immediately above `import {LidoWstETHStandardExchangeCommon}` on line 8.

**7.2 Two inserts.** Both lines use `if (pretransferred)`:

- Line **64** (asset→SE mint). Insert `if (pretransferred) { LocalCreditLib.requirePretransferCaller(msg.sender); }` immediately before `uint256 credit = pretransferred ? _pretransferCredit(tokenIn, maxAmountIn) : 0;`.
- Line **85** (asset→asset). Insert the same guard block immediately before the line 85 `uint256 credit = pretransferred ? _pretransferCredit(tokenIn, maxAmountIn) : 0;`.

**7.3 No other line changes.** The `_reserveBeforePretransfer` call at line 66, the `_quoteMintAtReserve` call at line 67, the stETH false-flag adjustment at line 68, the `_securePull` call at line 70, the `_refundExactOutCredit` call at line 76, and the `_syncAllExpectedHoldReserves` call at line 77 are unchanged. The line 84 input-ceiling check (`if (amountIn > maxAmountIn) revert Slippage();`), the line 86 `_securePull`, the line 89 `_refundExactOutCredit`, and the line 90 `_syncAllExpectedHoldReserves` are unchanged.

### Step 8 — Stop and report

Run `forge build --skip "test/**" --skip "scripts/**"` after Steps 1-7. If any step's edit does not compile, stop and report which step. Do not continue. If `forge build` succeeds, proceed to §2.

---

## 2. Artifact refresh

Per `CLAUDE.md` §10 and the repository's `scripts/forge-artifacts.py` (which supports `plan` and `test` subcommands with `--test-root`):

```bash
python3 scripts/forge-artifacts.py plan \
    contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/UniswapV4FullSpreadHooklessStandardExchangeVaultOutExecuteTarget.sol \
    contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/UniswapV4FullSpreadPonsFamilyHookOutExecuteTarget.sol \
    contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultOutExecutionDelegate.sol \
    contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeOutTarget.sol \
    contracts/protocols/dexes/camelot/v2/CamelotV2StandardExchangeOutTarget.sol \
    contracts/protocols/staking/rocket-pool/RocketPoolRETHStandardExchangeOutTarget.sol \
    contracts/protocols/staking/lido/LidoWstETHStandardExchangeOutTarget.sol \
    --test-root test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/PretransferCallerLifecycle.t.sol \
    --test-root test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/ApexRecurrenceErrorOrder.t.sol \
    --test-root test/foundry/spec/vaults/standard/exchange/protocols/uniswap/release/v3/ApexRecurrenceErrorOrder.t.sol \
    --test-root test/foundry/spec/protocols/dexes/uniswap/v2/UniswapV2StandardExchange_SecRemediation.t.sol \
    --test-root test/foundry/spec/protocols/dexes/camelot/v2/CamelotV2StandardExchange_SecRemediation.t.sol \
    --test-root test/foundry/spec/protocols/staking/rocket-pool/RocketPoolRETHStandardExchange_C06.t.sol \
    --test-root test/foundry/spec/protocols/staking/lido/LidoWstETHStandardExchange_C06.t.sol
```

After the plan, run a second pass to build concrete test artifacts:

```bash
python3 scripts/forge-artifacts.py test \
    contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/UniswapV4FullSpreadHooklessStandardExchangeVaultOutExecuteTarget.sol \
    contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/UniswapV4FullSpreadPonsFamilyHookOutExecuteTarget.sol \
    contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultOutExecutionDelegate.sol \
    contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeOutTarget.sol \
    contracts/protocols/dexes/camelot/v2/CamelotV2StandardExchangeOutTarget.sol \
    contracts/protocols/staking/rocket-pool/RocketPoolRETHStandardExchangeOutTarget.sol \
    contracts/protocols/staking/lido/LidoWstETHStandardExchangeOutTarget.sol \
    --test-root test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/PretransferCallerLifecycle.t.sol \
    --test-root test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/ApexRecurrenceErrorOrder.t.sol \
    --test-root test/foundry/spec/vaults/standard/exchange/protocols/uniswap/release/v3/ApexRecurrenceErrorOrder.t.sol \
    --test-root test/foundry/spec/protocols/dexes/uniswap/v2/UniswapV2StandardExchange_SecRemediation.t.sol \
    --test-root test/foundry/spec/protocols/dexes/camelot/v2/CamelotV2StandardExchange_SecRemediation.t.sol \
    --test-root test/foundry/spec/protocols/staking/rocket-pool/RocketPoolRETHStandardExchange_C06.t.sol \
    --test-root test/foundry/spec/protocols/staking/lido/LidoWstETHStandardExchange_C06.t.sol \
    -- -vv
```

Default hermetic profile; `via_ir = false`; do not change `FOUNDRY_TEST` or `FOUNDRY_PROFILE`.

---

## 3. Test-edit phase

The plan names exactly seven test files (one per production file). Five of them are existing tests that already exercise the required pretransfer path. Two of them are new files, beside each family's existing out test, because Rocket and Lido have no existing test that exercises the OutTarget's `exchangeOut` with `pretransferred=true`. The plan names exactly one new file per family and does not invent a second option.

### Step 9 — Five existing tests, no file creation

These five existing tests are named by the plan. The implementer does not write a new test; the test files exist and the assertions are already in place. The fix at §1 makes the existing assertions pass; the implementer is not given a choice on test selection.

| # | Production file | Existing test file | Existing assertion that closes the REQ-C06 acceptance criterion |
|---|---|---|---|
| 1 | hookless OutExecuteTarget | `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/PretransferCallerLifecycle.t.sol` | `test_constructorCallerRejectedWithNoCustodyOrSupplyChange` (line 13) already expects `ISecurePullErrors.EOAPretransferNotAllowed.selector` for a code-less constructor caller. `test_delegatedEoaRequiresNewCreditAndCannotReuseBookedInventory` (line 26) already expects `ISecurePullErrors.TransferDeltaInsufficient.selector` for a code-less EOA with short credit. These are the two REQ-C06 named assertions. The existing tests do not need new code. |
| 2 | Pons OutExecuteTarget | `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/ApexRecurrenceErrorOrder.t.sol` | `test_review_underfundedEoaExactOutObservesCreditError` (line 30) already expects `ISecurePullErrors.EOAPretransferNotAllowed.selector` for a code-less EOA on the direct-out branch (which routes through the line-165 `_executeDirectOut`). `test_review_underfundedContractExactOutObservesCreditError` (line 49) already expects `ISecurePullErrors.TransferDeltaInsufficient(used, 0).selector` for a contract caller with short credit. `test_review_falseFlagEoaExactOutDoesNotUseCallerGuard` (line 86) closes the false-flag criterion. The existing tests do not need new code. |
| 3 | V3 OutExecutionDelegate (mint function only) | `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/release/v3/ApexRecurrenceErrorOrder.t.sol` | `test_review_underfundedEoaExactOutObservesCreditError` (line 59) already exercises `vault.exchangeOut(input, used, IERC20(address(vault)), shares, outsider, true, block.timestamp)` with `tokenOut == address(this)` (the mint route) and expects `ISecurePullErrors.EOAPretransferNotAllowed.selector` for a code-less EOA. `test_review_underfundedContractExactOutObservesCreditError` (line 77) exercises the same route with a contract caller and expects `ISecurePullErrors.TransferDeltaInsufficient(used, 0).selector`. `test_review_falseFlagEoaDirectExactOutDoesNotUseCallerGuard` (line 134) closes the false-flag criterion. The existing tests do not need new code. |
| 4 | V2 OutTarget | `test/foundry/spec/protocols/dexes/uniswap/v2/UniswapV2StandardExchange_SecRemediation.t.sol` | `test_E6_exchangeOut_swap_inflatedMax_pretransferred_noExtraTransfer_noInventorySkim` (line 44) calls `vault_.exchangeOut(..., attacker, true, _deadline())` and expects `ISecurePullErrors.EOAPretransferNotAllowed.selector` for a code-less EOA attacker (line 72). The existing test does not need new code. |
| 5 | Camelot OutTarget | `test/foundry/spec/protocols/dexes/camelot/v2/CamelotV2StandardExchange_SecRemediation.t.sol` | `test_E6_exchangeOut_swap_inflatedMax_pretransferred_noExtraTransfer_noInventorySkim` (line 76) calls `vault.exchangeOut(..., attacker, true, _deadline())` and expects `ISecurePullErrors.EOAPretransferNotAllowed.selector` for a code-less EOA attacker (line 100). The existing test does not need new code. |

**No new assertions are added to these five files.** The implementer does not add a bare `vm.expectRevert()` and does not add a second option. The five tests are the production-proxy tests for the five families.

### Step 10 — New Rocket Pool test file

`RocketPoolRETHStandardExchangeOutTarget.sol` has no existing test that exercises `seOut.exchangeOut` with `pretransferred=true`. The plan names exactly one new test file beside the existing out test.

**10.1 File path.** `test/foundry/spec/protocols/staking/rocket-pool/RocketPoolRETHStandardExchange_C06.t.sol`. It lives beside `RocketPoolRETHStandardExchange_Core.t.sol` in the same directory. This is the only new file for Rocket; do not write a second.

**10.2 Inheritance.** Inherit `TestBase_RocketPoolRETHStandardExchange` (the existing test base for the family). Do not invent a new base. The base provides `seOut`, `seIn`, `seVault`, `hermeticWeth`, `hermeticReth`, `hermeticPool`, `hermeticRegistry`, `hermeticSettings`. Use `seOut.exchangeOut` directly; do not redeclare the fixture.

**10.3 Required imports.** The new file imports:
- `TestBase_RocketPoolRETHStandardExchange` (the base above).
- `IStandardExchangeOut` from `@crane/contracts/interfaces/IStandardExchangeOut.sol`.
- `IERC20` from `@crane/contracts/interfaces/IERC20.sol`.
- `ISecurePullErrors` from `contracts/interfaces/ISecurePullErrors.sol`.
- `AtomicPretransferCaller` from `contracts/test/stubs/AtomicPretransferCaller.sol`.

**10.4 Three required test functions.** The plan names exactly three. They close the three REQ-C06 acceptance criteria for the Rocket family. The naming is fixed; the implementer does not invent alternatives.

```solidity
// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {AtomicPretransferCaller} from "contracts/test/stubs/AtomicPretransferCaller.sol";
import {TestBase_RocketPoolRETHStandardExchange} from
    "contracts/test/bases/TestBase_RocketPoolRETHStandardExchange.sol";

/// @notice REQ-C06: code-less and contract-caller pretransfer on the Rocket OutTarget mint and asset-to-asset branches.
contract RocketPoolRETHStandardExchange_C06 is TestBase_RocketPoolRETHStandardExchange {
    /// @notice Code-less EOA + pretransferred=true + short credit reverts EOAPretransferNotAllowed before measurement.
    /// @dev Exercises the line-60 measurement in the asset→SE mint branch.
    function test_C06_exchangeOut_mint_codelessEoaPretransferShortCreditRevertsCallerError() public {
        // Seed enough inventory for a quote to return a positive value.
        _seedVaultInventory(10 ether, 10 ether);
        IERC20 input = IERC20(address(hermeticWeth));
        uint256 sharesOut = IERC20(seVault).totalSupply() / 100;
        require(sharesOut > 0, "sharesOut");
        uint256 used = seOut.previewExchangeOut(input, IERC20(seVault), sharesOut);
        require(used > 0, "used");
        address eoa = makeAddr("rocketC06Eoa");
        assertEq(eoa.code.length, 0, "EOA required");
        uint256 supplyBefore = IERC20(seVault).totalSupply();
        uint256 inputBefore = input.balanceOf(seVault);
        vm.prank(eoa);
        vm.expectRevert(ISecurePullErrors.EOAPretransferNotAllowed.selector);
        seOut.exchangeOut(input, used, IERC20(seVault), sharesOut, eoa, true, block.timestamp + 1 hours);
        assertEq(IERC20(seVault).totalSupply(), supplyBefore, "no mint");
        assertEq(input.balanceOf(seVault), inputBefore, "no credit consumed");
    }

    /// @notice Code-less EOA + pretransferred=true + short credit on the asset→asset branch.
    /// @dev Exercises the line-82 measurement in the asset→asset branch.
    function test_C06_exchangeOut_assetToAsset_codelessEoaPretransferShortCreditRevertsCallerError() public {
        _seedVaultInventory(10 ether, 10 ether);
        IERC20 wethIn = IERC20(address(hermeticWeth));
        IERC20 rethOut = IERC20(address(hermeticReth));
        // Use the asset→asset branch (weth→reth) which calls _pretransferCredit at line 82.
        uint256 outAmt = 1 ether;
        uint256 used = seOut.previewExchangeOut(wethIn, rethOut, outAmt);
        require(used > 0, "used");
        address eoa = makeAddr("rocketC06AssetEoa");
        assertEq(eoa.code.length, 0, "EOA required");
        uint256 wethBefore = wethIn.balanceOf(seVault);
        uint256 rethBefore = rethOut.balanceOf(seVault);
        vm.prank(eoa);
        vm.expectRevert(ISecurePullErrors.EOAPretransferNotAllowed.selector);
        seOut.exchangeOut(wethIn, used, rethOut, outAmt, eoa, true, block.timestamp + 1 hours);
        assertEq(wethIn.balanceOf(seVault), wethBefore, "no credit consumed");
        assertEq(rethOut.balanceOf(seVault), rethBefore, "no output paid");
    }

    /// @notice False flag does not acquire the caller check.
    /// @dev EOA with sufficient allowance pulls normally; the new caller check is wrapped in `if (pretransferred)`.
    function test_C06_exchangeOut_mint_falseFlagEoaPulls() public {
        _seedVaultInventory(10 ether, 10 ether);
        IERC20 input = IERC20(address(hermeticWeth));
        uint256 sharesOut = IERC20(seVault).totalSupply() / 100;
        require(sharesOut > 0, "sharesOut");
        uint256 used = seOut.previewExchangeOut(input, IERC20(seVault), sharesOut);
        require(used > 0, "used");
        address eoa = makeAddr("rocketC06FalseFlag");
        assertEq(eoa.code.length, 0, "EOA required");
        // Fund the EOA and approve directly. The vault pulls from msg.sender under false flag.
        deal(address(hermeticWeth), eoa, used);
        vm.startPrank(eoa);
        IERC20(address(hermeticWeth)).approve(seVault, used);
        // The false flag must not revert EOAPretransferNotAllowed. The call succeeds.
        seOut.exchangeOut(input, used, IERC20(seVault), sharesOut, eoa, false, block.timestamp + 1 hours);
        vm.stopPrank();
        assertGt(IERC20(seVault).balanceOf(eoa), 0, "minted under false flag");
    }
}
```

The `_seedVaultInventory` and `deal` helpers are inherited from the test base. `deal` is the forge-std cheatcode for setting an EOA's token balance; it is in scope for the Rocket test base. If the inherited `_seedVaultInventory` does not exist in the test base, the implementer uses the same seeding the existing `Adversarial_RocketPoolRETH_P0.t.sol` uses (`_fundSleeve` and the `seIn.exchangeIn` for inventory). The implementer does not invent a new seeding routine.

**10.5 No bare `vm.expectRevert()`.** Every revert assertion above uses `ISecurePullErrors.EOAPretransferNotAllowed.selector` or `ISecurePullErrors.TransferDeltaInsufficient(used, 0).selector`. The plan does not allow a bare `expectRevert`.

### Step 11 — New Lido test file

`LidoWstETHStandardExchangeOutTarget.sol` has no existing test that exercises `seOut.exchangeOut` with `pretransferred=true`. The plan names exactly one new test file beside the existing out test.

**11.1 File path.** `test/foundry/spec/protocols/staking/lido/LidoWstETHStandardExchange_C06.t.sol`. It lives beside `LidoWstETHStandardExchange_Core.t.sol` in the same directory. This is the only new file for Lido; do not write a second.

**11.2 Inheritance.** Inherit `TestBase_LidoWstETHStandardExchange` (the existing test base for the family). Do not invent a new base. The base provides `seOut`, `seIn`, `seVault`, `hermeticWeth`, `hermeticStEth`, `hermeticWstEth`, `hermeticQueue`.

**11.3 Required imports.** The new file imports:
- `TestBase_LidoWstETHStandardExchange` (the base above).
- `IStandardExchangeOut` from `@crane/contracts/interfaces/IStandardExchangeOut.sol`.
- `IERC20` from `@crane/contracts/interfaces/IERC20.sol`.
- `ISecurePullErrors` from `contracts/interfaces/ISecurePullErrors.sol`.
- `AtomicPretransferCaller` from `contracts/test/stubs/AtomicPretransferCaller.sol`.

**11.4 Three required test functions.** Same shape as Step 10.4, with Lido-specific paths.

```solidity
// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {AtomicPretransferCaller} from "contracts/test/stubs/AtomicPretransferCaller.sol";
import {TestBase_LidoWstETHStandardExchange} from
    "contracts/test/bases/TestBase_LidoWstETHStandardExchange.sol";

/// @notice REQ-C06: code-less and contract-caller pretransfer on the Lido OutTarget mint and asset-to-asset branches.
contract LidoWstETHStandardExchange_C06 is TestBase_LidoWstETHStandardExchange {
    /// @notice Code-less EOA + pretransferred=true + short credit reverts EOAPretransferNotAllowed before measurement.
    /// @dev Exercises the line-64 measurement in the asset→SE mint branch.
    function test_C06_exchangeOut_mint_codelessEoaPretransferShortCreditRevertsCallerError() public {
        // Seed enough inventory for a quote to return a positive value.
        _seedInventoryForOut(10 ether);
        IERC20 input = IERC20(address(hermeticWeth));
        uint256 sharesOut = IERC20(seVault).totalSupply() / 100;
        require(sharesOut > 0, "sharesOut");
        uint256 used = seOut.previewExchangeOut(input, IERC20(seVault), sharesOut);
        require(used > 0, "used");
        address eoa = makeAddr("lidoC06Eoa");
        assertEq(eoa.code.length, 0, "EOA required");
        uint256 supplyBefore = IERC20(seVault).totalSupply();
        uint256 inputBefore = input.balanceOf(seVault);
        vm.prank(eoa);
        vm.expectRevert(ISecurePullErrors.EOAPretransferNotAllowed.selector);
        seOut.exchangeOut(input, used, IERC20(seVault), sharesOut, eoa, true, block.timestamp + 1 hours);
        assertEq(IERC20(seVault).totalSupply(), supplyBefore, "no mint");
        assertEq(input.balanceOf(seVault), inputBefore, "no credit consumed");
    }

    /// @notice Code-less EOA + pretransferred=true + short credit on the asset→asset branch.
    /// @dev Exercises the line-85 measurement in the asset→asset branch.
    function test_C06_exchangeOut_assetToAsset_codelessEoaPretransferShortCreditRevertsCallerError() public {
        _seedInventoryForOut(10 ether);
        IERC20 wethIn = IERC20(address(hermeticWeth));
        IERC20 stethOut = IERC20(address(hermeticStEth));
        // Use the asset→asset branch (weth→steth) which calls _pretransferCredit at line 85.
        uint256 outAmt = 1 ether;
        uint256 used = seOut.previewExchangeOut(wethIn, stethOut, outAmt);
        require(used > 0, "used");
        address eoa = makeAddr("lidoC06AssetEoa");
        assertEq(eoa.code.length, 0, "EOA required");
        uint256 wethBefore = wethIn.balanceOf(seVault);
        uint256 stethBefore = stethOut.balanceOf(seVault);
        vm.prank(eoa);
        vm.expectRevert(ISecurePullErrors.EOAPretransferNotAllowed.selector);
        seOut.exchangeOut(wethIn, used, stethOut, outAmt, eoa, true, block.timestamp + 1 hours);
        assertEq(wethIn.balanceOf(seVault), wethBefore, "no credit consumed");
        assertEq(stethOut.balanceOf(seVault), stethBefore, "no output paid");
    }

    /// @notice False flag does not acquire the caller check.
    /// @dev EOA with sufficient allowance pulls normally; the new caller check is wrapped in `if (pretransferred)`.
    function test_C06_exchangeOut_mint_falseFlagEoaPulls() public {
        _seedInventoryForOut(10 ether);
        IERC20 input = IERC20(address(hermeticWeth));
        uint256 sharesOut = IERC20(seVault).totalSupply() / 100;
        require(sharesOut > 0, "sharesOut");
        uint256 used = seOut.previewExchangeOut(input, IERC20(seVault), sharesOut);
        require(used > 0, "used");
        address eoa = makeAddr("lidoC06FalseFlag");
        assertEq(eoa.code.length, 0, "EOA required");
        deal(address(hermeticWeth), eoa, used);
        vm.startPrank(eoa);
        IERC20(address(hermeticWeth)).approve(seVault, used);
        seOut.exchangeOut(input, used, IERC20(seVault), sharesOut, eoa, false, block.timestamp + 1 hours);
        vm.stopPrank();
        assertGt(IERC20(seVault).balanceOf(eoa), 0, "minted under false flag");
    }

    /// @dev Internal helper: seed the vault with enough WETH and SE to produce a positive quote on the mint branch.
    /// The Lido test base already exposes inventory helpers; the implementer reuses the same seeding pattern
    /// the existing Core test uses (`_fundSleeve` and an `exchangeIn` from the test contract).
    function _seedInventoryForOut(uint256 wethAmount) internal {
        // Mirror the existing Lido Core test's seeding: a true-flag exchangeIn from the test contract
        // (which has bytecode) deposits the WETH and mints the SE. The deposit path uses the InTarget
        // whose caller check is unchanged by this PRD.
        deal(address(hermeticWeth), address(this), wethAmount);
        IERC20(address(hermeticWeth)).approve(seVault, wethAmount);
        seIn.exchangeIn(IERC20(address(hermeticWeth)), wethAmount, IERC20(seVault), 0, address(this), false, block.timestamp + 1 hours);
    }
}
```

The `_seedInventoryForOut` helper mirrors the Lido Core test's seeding pattern (a true-flag pull is not used; the seeding uses the false-flag pull to avoid the pretransfer code path entirely). The implementer may reuse an existing seeding helper from the test base if one exists; otherwise the helper above is the canonical form. The implementer does not invent a second option.

**11.5 No bare `vm.expectRevert()`.** Same as Step 10.5.

### Step 12 — Test-edit summary

The total test-file set is exactly seven files, named in §3 (Steps 9, 10.1, 11.1). Five are existing files; two are new files. The plan does not name a second new file for any family. The plan does not modify any test file other than by creating the two new ones. The implementer does not add a third test file, does not split a test file, and does not write a bare `vm.expectRevert()`.

---

## 4. Verification phase

Run after §1, §2, §3.

### Step 13 — Per-family test runs

```bash
forge test --match-path test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/PretransferCallerLifecycle.t.sol -vvv
forge test --match-path test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/ApexRecurrenceErrorOrder.t.sol -vvv
forge test --match-path test/foundry/spec/vaults/standard/exchange/protocols/uniswap/release/v3/ApexRecurrenceErrorOrder.t.sol -vvv
forge test --match-path test/foundry/spec/protocols/dexes/uniswap/v2/UniswapV2StandardExchange_SecRemediation.t.sol -vvv
forge test --match-path test/foundry/spec/protocols/dexes/camelot/v2/CamelotV2StandardExchange_SecRemediation.t.sol -vvv
forge test --match-path test/foundry/spec/protocols/staking/rocket-pool/RocketPoolRETHStandardExchange_C06.t.sol -vvv
forge test --match-path test/foundry/spec/protocols/staking/lido/LidoWstETHStandardExchange_C06.t.sol -vvv
```

Pass criteria per family:
- Hookless: the EOA + true flag + short credit assertion in `PretransferCallerLifecycle.t.sol` reverts `EOAPretransferNotAllowed` (the existing test already asserts this; the fix at §1 makes it pass on the line-94 measurement). The contract-caller + short credit assertion reverts `TransferDeltaInsufficient`.
- Pons: same as hookless, on the Pons OutExecuteTarget (line-94 and line-165). The false-flag assertion at `ApexRecurrenceErrorOrder.t.sol:86` passes (no caller check under false flag).
- V3: the mint-route assertions at `ApexRecurrenceErrorOrder.t.sol:59` and `:77` pass on the V3 mint delegate. The relocate at §3 makes the EOA + true flag + short credit call revert `EOAPretransferNotAllowed` from the new line-101 guard before the measurement at line 102.
- V2: the EOA + true flag + short credit assertion at `SecRemediation.t.sol:72` reverts `EOAPretransferNotAllowed` from the new line-461 guard before the measurement at line 462.
- Camelot: the EOA + true flag + short credit assertion at `SecRemediation.t.sol:100` reverts `EOAPretransferNotAllowed` from the new line-410 guard before the measurement at line 411.
- Rocket: the three assertions in the new `RocketPoolRETHStandardExchange_C06.t.sol` pass.
- Lido: the three assertions in the new `LidoWstETHStandardExchange_C06.t.sol` pass.

### Step 14 — Full hermetic sweep

```bash
forge test -vvv
```

Pass criteria:
- All seven named test files pass.
- No `via_ir` was used.
- No self-call to `deposit(...)` or `exchangeOut(...)` on the legacy V4 proxy (legacy V4 is out of scope and not touched; the V4 FullSpread hookless and Pons families do not change call shape).
- Other families' Pendle surfaces are intact (Rocket, Lido, EtherFi, V2, Camelot, Aave, Morpho, Balancer, Native SY are not touched by §1; their existing test suites still pass without edits).

### Step 15 — Stop conditions

- If `forge build` at Step 8 fails, stop and report the file and line of the compile error. Do not continue.
- If any of the §0.6 `grep` expected lines is missing or a new line appears, stop and report. Do not choose another site.
- If any of the seven named test files fails to compile, stop and report. Do not choose a different test file.
- If any of the per-family assertions at Step 13 fails, stop and report the family, the test, and the line. Do not relax the assertion, do not change the selector, and do not switch to a bare `vm.expectRevert()`.
- If a named line no longer assigns `_pretransferCredit` (per the PRD `:27` stop rule), stop and report. Do not choose another site.

---

## 5. Acceptance evidence roll-up

After Step 14 passes, write a single Markdown file `docs/reviews/apex-req-c06-pretransfer-caller-first/implementation_report.md` containing:

1. The toolchain output (`forge --version`, `solc --version`, `optimizer_runs`, `via_ir == false`).
2. The git diff stats. The diff must show exactly the seven production files in §1 and the two new test files in §3 (Steps 10 and 11), plus generated artifacts.
3. The pass/fail summary of every `forge test` invocation at §2 and §4.
4. The per-family confirmation that the EOA + true flag + short credit → `EOAPretransferNotAllowed` assertion passes, and the contract + true flag + short credit → `TransferDeltaInsufficient` assertion passes where asserted.
5. The confirmation that the ten caller-first sites, both EtherFi sites, the Slipstream site, and the deleted legacy V4 tree are unchanged (per the PRD `:77`).
6. The confirmation that no family has a new test file beyond the two named in §3.

The implementation report is the closure artifact. The plan terminates here.

---

## 6. Non-goals (do not do)

- Do not split facets. The owner ruled against facet splits in this item.
- Do not edit `EtherFiWeETHStandardExchangeOutTarget.sol` (EtherFi is recorded, not edited).
- Do not edit `SlipstreamStandardExchangeOutTarget.sol` (Slipstream is recorded, not edited).
- Do not edit `contracts/protocols/dexes/uniswap/v4` (the legacy tree is being deleted by a separate agent; it is not in this item).
- Do not add a second new test file per family. The plan names exactly one new file for Rocket and exactly one for Lido. No more.
- Do not add a bare `vm.expectRevert()`. Every revert assertion must use `ISecurePullErrors.EOAPretransferNotAllowed.selector` or `ISecurePullErrors.TransferDeltaInsufficient(used, available).selector` (or the abi-encoded equivalent).
- Do not introduce a `catch` to absorb the new caller check.
- Do not move the input-ceiling comparisons, the quote, the refund, the settlement, or the disable/deadline checks.
- Do not remove the existing credit comparison in any helper (`_requirePrepaidCredit`, `_secureTokenTransfer`, `_securePull`, `_secureSelfBurn`).
- Do not change `LocalCreditLib.requirePretransferCaller` or the `ISecurePullErrors.EOAPretransferNotAllowed` error selector.
- Do not enable `via_ir`.
- Do not change Foundry version, `solc` version, `optimizer_runs`, EVM target, or `via_ir` policy.
- Do not deploy or upgrade live instances.
- Do not change quote math, refund math, or settlement.
- Do not change the ten caller-first sites, both EtherFi sites, the Slipstream site, or the deleted legacy V4 tree.
- Do not run Forge before the plan is complete and the artifacts are refreshed.

---

## 7. Plan-draft self-checks

The implementer must verify, before opening any file:

- The PRD at `docs/reviews/apex-req-c06-pretransfer-caller-first/REMEDIATION_PRD.md` is still DRAFT 2026-10-15 (read in full, 98 lines).
- A fresh `git status` shows only the seven production files in §1, the two new test files in §3 (Steps 10.1 and 11.1), and generated artifacts.
- A warm `cache_forge/` and `out/` per CLAUDE.md §9.
- Foundry 1.5.1 and solc 0.8.35.
- The seven test files named in §3 exist or are created by this plan.
- The 21 lines named in §0.6 all still call `_pretransferCredit`.

If any of these is missing, the plan cannot start cleanly.

---

## 8. Plan summary

- **7 production files** change (§1, Steps 1-7): hookless, Pons, V3 mint delegate (relocate), V2, Camelot, Rocket, Lido.
- **3 new imports** added (Steps 4.1, 5.1, 6.1, 7.1 — V2, Camelot, Rocket, Lido each get one new `LocalCreditLib` import).
- **20 inserts** of `if (pretransferred) { LocalCreditLib.requirePretransferCaller(msg.sender); }` and **2 inserts** of `if (prepaid) { LocalCreditLib.requirePretransferCaller(msg.sender); }` (hookless and Pons direct-out).
- **1 relocate** in V3 mint delegate: move the line-109 caller check to before line 102.
- **5 existing test files** named in Step 9. No new code in those files.
- **2 new test files** (Steps 10.1 and 11.1) with exactly 3 test functions each.
- **0 facet splits**, **0 deletions**, **0 shared SY changes**, **0 EtherFi changes**, **0 Slipstream changes**, **0 legacy V4 changes**.
- **No implementer choice.** The plan names the exact lines, the exact inserts, the exact imports, the exact test files, the exact assertions, and the exact stop conditions.

I did not run Forge.