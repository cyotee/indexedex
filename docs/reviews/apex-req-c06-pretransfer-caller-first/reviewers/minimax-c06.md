# MiniMax M3 — REQ-C06 pretransfer caller-first review, replacement-session original

- **Label:** replacement session. I do not recall `ses_ec41255ceffeVhrySLQe8hwwMC`. No peer notes were read. No code edits. No `REMEDIATION_PRD.md`. No Forge. No exploit procedures, payloads, or attack parameters.
- **Controlling current requirement:** `docs/reviews/apex-remediation-application-2026-10-14/REMEDIATION_PRD.md` section REQ-C06. The 2026-10-11 draft `docs/reviews/apex-req-c06-pretransfer-caller-first/REMEDIATION_PRD.md` is the underlying claim; the older Stage-2 text in `docs/reviews/apex-stage2-remediation-confirmation-2026-10-11/REMEDIATION_PRD.md` REQ-C06 is older still and is **not** authoritative.
- **Scope guardrails:** `contracts/protocols/dexes/uniswap/v4` is the legacy V4 being deleted by a separate agent and is out of scope. `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/{hookless,ponsFamilyV2Hook}` is the V4 FullSpread family and is **in** scope (it is the same path the current PRD names). No file list is invented. The named known sites are the PRD's; I searched the rest of the production tree for the same early-credit-revert pattern and cite what I found.
- **Defect definition (per the controlling PRD):** on a pretransfer branch, the caller authentication `LocalCreditLib.requirePretransferCaller(msg.sender)` must run before `_pretransferCredit(...)` and before any quote or plan that consumes that measured credit. A code-less caller with short credit must revert `EOAPretransferNotAllowed` (not `TransferDeltaInsufficient`). A contract caller with short credit still reverts `TransferDeltaInsufficient`. A `pretransferred=false` (false-flag) path does not gain this caller check. An input-ceiling comparison that does not consume measured credit is not this defect.

---

## 1. Files examined and the pattern I checked for

For every in-scope production call of `_pretransferCredit`, I traced the surrounding statement order against the controlling definition. The pattern I look for is the three-line shape:

```solidity
if (pretransferred) {
    LocalCreditLib.requirePretransferCaller(msg.sender); // REQUIRED BEFORE measurement
    uint256 credit = _pretransferCredit(token, maximum); // measurement
    if (somePlanThatUsesCredit) revert TransferDeltaInsufficient(...); // plan / short-credit revert
}
```

A call site is **in scope for this defect** if (a) it is on a pretransfer branch and (b) a measurement (`_pretransferCredit`) or a quote / plan that consumes that measurement runs before `LocalCreditLib.requirePretransferCaller`. A site is **out of scope for this defect** if the external `_pretransferCredit` is only an informational read used for refund math and the actual short-credit revert happens inside a `_secureTokenTransfer` / `_securePull` / `_secureSelfBurn` / `_creditOutInbound` / `_receiveExactIn` that already checks the caller first.

Production call sites of `_pretransferCredit` (from the repository-wide grep on `*.sol` under `contracts/`):

- `contracts/protocols/staking/rocket-pool/RocketPoolRETHStandardExchangeOutTarget.sol:60, 82`
- `contracts/protocols/staking/lido/LidoWstETHStandardExchangeOutTarget.sol:64, 85`
- `contracts/protocols/staking/etherfi/EtherFiWeETHStandardExchangeOutTarget.sol:61, 84`
- `contracts/protocols/dexes/camelot/v2/CamelotV2StandardExchangeOutTarget.sol:411, 513, 596, 663, 766`
- `contracts/protocols/dexes/aerodrome/slipstream/SlipstreamStandardExchangeOutTarget.sol:85`
- `contracts/protocols/dexes/aerodrome/v1/AerodromeStandardExchangeOutExecuteTarget.sol:291, 397, 489`
- `contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeOutTarget.sol:462, 547, 623, 693, 794, 905, 972`
- `contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeCommon.sol:494` (definition only)
- `contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultOutExecutionDelegate.sol:32, 102`
- `contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultOutMultiTarget.sol:40`
- `contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultOutExecuteTarget.sol:83`
- `contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultCommon.sol:909` (definition only)
- `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/UniswapV4FullSpreadPonsFamilyHookOutExecutionDelegate.sol:37`
- `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/UniswapV4FullSpreadPonsFamilyHookOutExecuteTarget.sol:94, 165`
- `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/UniswapV4FullSpreadPonsFamilyHookOutMultiTarget.sol:46`
- `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/UniswapV4FullSpreadPonsFamilyHookCommon.sol:945` (definition only)
- `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/UniswapV4FullSpreadHooklessStandardExchangeVaultOutExecutionDelegate.sol:37`
- `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/UniswapV4FullSpreadHooklessStandardExchangeVaultOutExecuteTarget.sol:94, 165`
- `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/UniswapV4FullSpreadHooklessStandardExchangeVaultOutMultiTarget.sol:46`
- `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/UniswapV4FullSpreadHooklessStandardExchangeVaultCommon.sol:945` (definition only)

The PRD's named sites (`UniswapV4FullSpreadHooklessStandardExchangeVaultOutExecuteTarget.sol:94-101` and `:165-169`; `UniswapV4FullSpreadPonsFamilyHookOutExecuteTarget.sol` same order; `UniswapV3FullSpreadStandardExchangeVaultOutExecutionDelegate.sol:102-110` `executeZapInMintExactOut`; `UniswapV3FullSpreadStandardExchangeVaultOutExecuteTarget.sol:81-84` `_executeQuotedSwapOut` cited as already correct) are all represented in the production list above. The full list is what the PRD asks me to search.

---

## 2. Defects (production sites that measure credit or run a plan that consumes it before the caller check)

### 2.1 Finding F1 — V4 FullSpread hookless `_executeZapInMintExactOut`

- **Severity:** Low (matches the controlling PRD's `REQ-C06` severity).
- **File and line:** `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/UniswapV4FullSpreadHooklessStandardExchangeVaultOutExecuteTarget.sol:94-103` (within `_executeZapInMintExactOut`, lines 86-114).
- **Intended behavior (controlling PRD, `## REQ-C06`):** "On each prepaid branch that measures credit before authentication, `requirePretransferCaller` runs before `_pretransferCredit` and before a quote or plan that consumes that credit." A code-less pretransfer caller with short credit must revert `EOAPretransferNotAllowed` (not `TransferDeltaInsufficient`).
- **Broken requirement or invariant:** The order is currently:

  ```solidity
  // 93
  if (sharesOut == 0) revert UniswapV4Exchange_ZeroAmount();
  // 94
  uint256 credit = pretransferred ? _pretransferCredit(tokenIn, maxAmountIn) : 0;
  // 95
  amountIn = _amountInForZapMint(address(tokenIn), sharesOut, credit);
  // 96
  if (amountIn > maxAmountIn) revert UniswapV4ExchangeOut_InsufficientInput();
  // 98
  uint256 inboundBefore = tokenIn.balanceOf(address(this));
  uint256 pullAmount = amountIn;
  // 100-103
  if (pretransferred) {
      _requirePrepaidCredit(amountIn, credit);
      pullAmount = credit;
  }
  ```

  `_pretransferCredit(tokenIn, maxAmountIn)` (line 94) measures the credit, then `_amountInForZapMint(address(tokenIn), sharesOut, credit)` (line 95) builds a plan that consumes the measured credit, then `_requirePrepaidCredit(amountIn, credit)` (line 101) — the only place the caller is checked in this pretransfer block — runs. `_requirePrepaidCredit` (lines 139-142) calls `LocalCreditLib.requirePretransferCaller(msg.sender)` first and then reverts with `TransferDeltaInsufficient` if `used > credit`. A code-less caller therefore reaches the caller check, not the credit check, only if the code gets to line 101; on the current order the measurement at line 94 and the plan at line 95 have already run, and the input-ceiling check on line 96 has already run, before that authentication. The required order is "caller first, then measurement, then plan, then credit check."
- **Impact class:** Diagnostic order defect, exactly as the controlling PRD describes. "Partial application. It is diagnostic order, not an authorization bypass, and not REQ-C02." (PRD, REQ-C06 broken-requirement text.) The acceptance criterion the PRD puts in writing is that a code-less pretransfer caller with short credit reverts `EOAPretransferNotAllowed` and the credit error is not the one reached. On the current order, the code-less caller does eventually reach `EOAPretransferNotAllowed` (line 140 inside `_requirePrepaidCredit`), but only after line 94's measurement and line 95's plan, which the PRD explicitly forbids.
- **Fix direction (no implementer choice):** at the top of the `if (pretransferred)` block, before the `uint256 credit = pretransferred ? _pretransferCredit(tokenIn, maxAmountIn) : 0;` line, add `LocalCreditLib.requirePretransferCaller(msg.sender);`. The new statement order inside `_executeZapInMintExactOut` is:

  1. `if (sharesOut == 0) revert UniswapV4Exchange_ZeroAmount();` (line 93, unchanged).
  2. `if (pretransferred) { LocalCreditLib.requirePretransferCaller(msg.sender); }` (new).
  3. `uint256 credit = pretransferred ? _pretransferCredit(tokenIn, maxAmountIn) : 0;` (line 94, position unchanged).
  4. `amountIn = _amountInForZapMint(address(tokenIn), sharesOut, credit);` (line 95, position unchanged).
  5. `if (amountIn > maxAmountIn) revert UniswapV4ExchangeOut_InsufficientInput();` (line 96, position unchanged).
  6. The `if (pretransferred) { _requirePrepaidCredit(amountIn, credit); pullAmount = credit; }` block (lines 100-103) is preserved; the redundant caller check inside `_requirePrepaidCredit` is harmless because the new check above already authenticated, and the comparison `if (used > credit) revert ISecurePullErrors.TransferDeltaInsufficient(used, credit);` at line 141 stays. The existing credit comparison stays.
  7. The `pretransferred=false` path is not reached by the new `LocalCreditLib.requirePretransferCaller` call. A false flag does not gain this caller check.

  Do not remove `_requirePrepaidCredit`. Do not change the input-ceiling check on line 96. Do not change the `_secureTokenTransfer` call on line 104. Do not change the `_refundExcess` call on line 108. Do not change `_mint` on line 112 or `_syncVaultReserves` on line 113. The existing helper `_requirePrepaidCredit(uint256 used, uint256 credit)` keeps both its lines (caller check + credit comparison); the new caller check above is the one that places the diagnostic in the required position. The fix is a strictly additive statement at the top of the pretransfer branch; no signature, no selector, no event, no error changes.
- **Confidence:** high. The current statement order in lines 86-114 is read from the source file directly, and the fix direction is a literal positional change with no other surface movement.

### 2.2 Finding F2 — V4 FullSpread hookless `_executeDirectOut`

- **Severity:** Low.
- **File and line:** `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/UniswapV4FullSpreadHooklessStandardExchangeVaultOutExecuteTarget.sol:165-169` (within `_executeDirectOut`, lines 159-186).
- **Intended behavior:** Same as F1, on the direct-swap exact-out branch.
- **Broken requirement or invariant:** The order is currently:

  ```solidity
  // 162
  if (amountOut == 0) revert UniswapV4Exchange_ZeroAmount();
  DirectOutFrame memory frame;
  frame.zeroForOne = address(tokenIn) == _token0();
  // 165
  frame.credit = prepaid ? _pretransferCredit(tokenIn, maximum) : 0;
  // 166
  frame.plan = _directOutPlan(_snapshot(frame.zeroForOne ? frame.credit : 0, frame.zeroForOne ? 0 : frame.credit), frame.zeroForOne, amountOut);
  used = frame.plan.swap.amountIn;
  if (used > maximum) revert UniswapV4ExchangeOut_InsufficientInput();
  // 169
  if (prepaid) _requirePrepaidCredit(used, frame.credit);
  ```

  `frame.credit` is measured on line 165, fed into `_directOutPlan` (which calls `_snapshot(credit, credit)`) on line 166, and only then is `_requirePrepaidCredit(used, frame.credit)` called on line 169. The caller check inside `_requirePrepaidCredit` is the only authentication on this branch. A code-less prepaid caller with short `used` reaches the credit error inside `_requirePrepaidCredit` only after both the credit measurement and the plan have run.
- **Impact class:** Diagnostic order defect, same class as F1.
- **Fix direction (no implementer choice):** at the top of the pretransfer branch (immediately after `frame.zeroForOne = address(tokenIn) == _token0();` and before the `frame.credit = ...` line), add `if (prepaid) { LocalCreditLib.requirePretransferCaller(msg.sender); }`. The new order inside `_executeDirectOut` is:

  1. `if (amountOut == 0) revert UniswapV4Exchange_ZeroAmount();` (line 162, unchanged).
  2. `DirectOutFrame memory frame;` (unchanged).
  3. `frame.zeroForOne = address(tokenIn) == _token0();` (unchanged).
  4. `if (prepaid) { LocalCreditLib.requirePretransferCaller(msg.sender); }` (new).
  5. `frame.credit = prepaid ? _pretransferCredit(tokenIn, maximum) : 0;` (line 165, position unchanged).
  6. `frame.plan = _directOutPlan(_snapshot(...), frame.zeroForOne, amountOut);` (line 166, position unchanged).
  7. `used = frame.plan.swap.amountIn;` (line 167, position unchanged).
  8. `if (used > maximum) revert UniswapV4ExchangeOut_InsufficientInput();` (line 168, position unchanged).
  9. The `if (prepaid) _requirePrepaidCredit(used, frame.credit);` call on line 169 is preserved; the helper's existing caller check and credit comparison stay. The new call above places the diagnostic in the required position.
  10. The `prepaid=false` path is not reached by the new caller check.

  Do not remove `_requirePrepaidCredit`. Do not change `_commitExecutionPlan`, `_collectManagedFeesIfIdle`, `_executePlannedSwap`, `_transferCurrency`, `_refundExcess`, the second `_commitExecutionPlan`, `_executePlacement`, `_verifyState`, or `_syncVaultReserves` calls. The fix is a strictly additive statement at the top of the pretransfer branch. No signature, no selector, no event, no error changes.
- **Confidence:** high.

### 2.3 Finding F3 — V4 FullSpread Pons-family `_executeZapInMintExactOut`

- **Severity:** Low.
- **File and line:** `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/UniswapV4FullSpreadPonsFamilyHookOutExecuteTarget.sol:94-103` (within `_executeZapInMintExactOut`, lines 86-114).
- **Intended behavior:** Same as F1, on the Pons-family facet.
- **Broken requirement or invariant:** The Pons-family file is a structural copy of the hookless `_executeZapInMintExactOut` (verified by reading lines 86-114 of the Pons file: identical statement order, identical `_requirePrepaidCredit` helper, identical default `payable=false`). The defect is the same: measurement (line 94) and plan (line 95) run before the caller check (line 101 via `_requirePrepaidCredit`).
- **Impact class:** Same as F1.
- **Fix direction (no implementer choice):** identical to F1. At the top of the `if (pretransferred)` block, before line 94, add `if (pretransferred) { LocalCreditLib.requirePretransferCaller(msg.sender); }`. Keep `_requirePrepaidCredit` on line 101 intact (it is harmless on top of the new check and its credit comparison is required to stay). The new call does not reach the `pretransferred=false` path. The Pons-family `_requirePrepaidCredit` helper at lines 139-142 is unchanged. No signature, no selector, no event, no error changes.
- **Confidence:** high.

### 2.4 Finding F4 — V4 FullSpread Pons-family `_executeDirectOut`

- **Severity:** Low.
- **File and line:** `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/UniswapV4FullSpreadPonsFamilyHookOutExecuteTarget.sol:165-169` (within `_executeDirectOut`, lines 159-186).
- **Intended behavior:** Same as F2, on the Pons-family facet.
- **Broken requirement or invariant:** Same as F2. The Pons-family `_executeDirectOut` is a structural copy of the hookless `_executeDirectOut` (identical statement order, identical helper usage, identical default `payable=false`).
- **Impact class:** Same as F2.
- **Fix direction (no implementer choice):** identical to F2. At the top of the pretransfer branch (after `frame.zeroForOne = address(tokenIn) == _token0();` and before the `frame.credit = ...` line), add `if (prepaid) { LocalCreditLib.requirePretransferCaller(msg.sender); }`. Keep `_requirePrepaidCredit(used, frame.credit)` on line 169 intact. The new call does not reach the `prepaid=false` path. No signature, no selector, no event, no error changes.
- **Confidence:** high.

### 2.5 Finding F5 — V3 FullSpread mint delegate `executeZapInMintExactOut`

- **Severity:** Low.
- **File and line:** `contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultOutExecutionDelegate.sol:102-110` (within `executeZapInMintExactOut`, lines 93-127).
- **Intended behavior:** Same as F1. The PRD explicitly names this site.
- **Broken requirement or invariant:** The order is currently:

  ```solidity
  // 100
  if (sharesOut == 0) revert UniswapV3Exchange_ZeroAmount();
  IERC20 token = IERC20(tokenIn);
  // 102
  uint256 credit = pretransferred ? _pretransferCredit(token, maxAmountIn) : 0;
  // 103
  amountIn = _amountInForZapMint(tokenIn, sharesOut, credit);
  // 104
  if (amountIn > maxAmountIn) revert UniswapV3ExchangeOut_InsufficientInput();

  uint256 inboundBefore = token.balanceOf(address(this));
  uint256 pullAmount = amountIn;
  // 108-112
  if (pretransferred) {
      LocalCreditLib.requirePretransferCaller(msg.sender);
      if (amountIn > credit) revert ISecurePullErrors.TransferDeltaInsufficient(amountIn, credit);
      pullAmount = credit;
  }
  ```

  Measurement (line 102) and plan (line 103) run before the caller check (line 109). The credit check (line 110) runs after the caller check, but the controller's wording puts the requirement on the position of `requirePretransferCaller` itself: it must run before the measurement, not after the plan. The V3 quoted exact-output branch at `UniswapV3FullSpreadStandardExchangeVaultOutExecuteTarget.sol:81-84` already has the required order (caller check on line 82, measurement on line 83, credit check on line 84), so the V3 mint delegate is the only V3 file out of order.
- **Impact class:** Diagnostic order defect, same as F1.
- **Fix direction (no implementer choice):** at the top of the `if (pretransferred)` block, before the `uint256 credit = pretransferred ? _pretransferCredit(token, maxAmountIn) : 0;` line on 102, add `LocalCreditLib.requirePretransferCaller(msg.sender);`. The new order inside `executeZapInMintExactOut` is:

  1. `if (sharesOut == 0) revert UniswapV3Exchange_ZeroAmount();` (line 100, unchanged).
  2. `IERC20 token = IERC20(tokenIn);` (line 101, unchanged).
  3. `LocalCreditLib.requirePretransferCaller(msg.sender);` (new, placed before the conditional measurement on line 102; the call is unconditional on this branch only because line 102 already wraps the measurement in `if (pretransferred)`).
  4. `uint256 credit = pretransferred ? _pretransferCredit(token, maxAmountIn) : 0;` (line 102, position unchanged).
  5. `amountIn = _amountInForZapMint(tokenIn, sharesOut, credit);` (line 103, position unchanged).
  6. `if (amountIn > maxAmountIn) revert UniswapV3ExchangeOut_InsufficientInput();` (line 104, position unchanged).
  7. The existing `if (pretransferred) { LocalCreditLib.requirePretransferCaller(msg.sender); if (amountIn > credit) revert ISecurePullErrors.TransferDeltaInsufficient(amountIn, credit); pullAmount = credit; }` block (lines 108-112) is preserved. The new caller check above is the one that places the diagnostic in the required position; the existing call inside the `if (pretransferred)` block is now redundant but harmless.
  8. The `pretransferred=false` path does not reach the new caller check.

  Do not remove the existing `LocalCreditLib.requirePretransferCaller(msg.sender);` call on line 109. Do not change the credit comparison on line 110. Do not change `_secureTokenTransfer` on line 113, the `if (pretransferred) inboundBefore -= providedAmountIn;` adjustment, `_requireDelivered` on line 115, the refund arithmetic on lines 116-122, `_collectIfIdle` on line 124, `_mint` on line 125, or `_syncVaultReserves` on line 126. The fix is a strictly additive single statement at the documented position. No signature, no selector, no event, no error changes.
- **Confidence:** high.

---

## 3. Cited and left alone (production sites already in the required order)

The PRD explicitly cites one such site and the implementation note requires the implementer to record any additional already-correct path it found. The following are in the required order; do not edit any of them.

| Site | Current order | Why cited and left alone |
|---|---|---|
| `UniswapV3FullSpreadStandardExchangeVaultOutExecuteTarget.sol:81-84` (`_executeQuotedSwapOut`) | line 82 caller check, line 83 measurement, line 84 credit check | PRD explicit cite (lines 81-84 already check the caller before measurement). |
| `UniswapV3FullSpreadStandardExchangeVaultOutMultiTarget.sol:38-44` (`exchangeOutOneToMany`) | line 39 caller check, line 40 measurement, line 41-43 credit check | Same `_quoteDualExit` / pretransfer pattern as the V3 quoted exact-output; the call order in the `if (pretransferred)` block is correct. |
| `UniswapV3FullSpreadStandardExchangeVaultOutExecutionDelegate.sol:30-36` (`executeZapOutWithdrawal`) | line 31 caller check, line 32 measurement, line 33-35 credit check | Caller check is first in the pretransfer block. |
| `UniswapV4FullSpreadHooklessStandardExchangeVaultOutExecutionDelegate.sol:35-39` (`executeZapOutWithdrawal`) | line 36 caller check, line 37 measurement, line 38 credit check | Caller check is first in the pretransfer block. |
| `UniswapV4FullSpreadPonsFamilyHookOutExecutionDelegate.sol:35-39` (`executeZapOutWithdrawal`) | line 36 caller check, line 37 measurement, line 38 credit check | Same as hookless twin. |
| `UniswapV4FullSpreadHooklessStandardExchangeVaultOutMultiTarget.sol:44-50` (`exchangeOutOneToMany`) | line 45 caller check, line 46 measurement, line 47-49 credit check | Caller check is first in the pretransfer block. |
| `UniswapV4FullSpreadPonsFamilyHookOutMultiTarget.sol:44-50` (`exchangeOutOneToMany`) | line 45 caller check, line 46 measurement, line 47-49 credit check | Same as hookless twin. |
| `UniswapV4FullSpreadHooklessStandardExchangeVaultCommon.sol:945` / `UniswapV4FullSpreadPonsFamilyHookCommon.sol:945` / `UniswapV3FullSpreadStandardExchangeVaultCommon.sol:909` | `_pretransferCredit` definitions, all `view`. | Definition sites; not call sites. |
| `UniswapV4FullSpreadHooklessStandardExchangeVaultCommon.sol:864-885` (`_secureTokenTransfer`) | line 868 caller check, line 869-873 credit check | The shared secure-pull already does the right order; the hookless and Pons-family mint/direct branches fail only because they measure before calling the secure pull. |
| `UniswapV3FullSpreadStandardExchangeVaultCommon.sol:864-885` (`_secureTokenTransfer`) | line 868 caller check, line 869-873 credit check | Same; the V3 quoted exact-output is correctly ordered. The V3 mint delegate (Finding F5) is the only V3 file out of order. |
| `UniswapV2StandardExchangeCommon.sol:450-478` (`_secureTokenTransfer`) | line 457 caller check, line 458-463 credit check | Caller check first; external `_pretransferCredit` at lines 462, 547, 623, 693, 794, 905, 972 is informational and consumed by `_refundExactOutCredit` (not by the short-credit revert). The input-ceiling check at lines 457, 540, 615, 686, 791, 900, 970 is `quote > max` (not `credit`), which the PRD non-goal explicitly excludes. |
| `CamelotV2StandardExchangeCommon.sol:189-217` (`_secureTokenTransfer`) | line 196 caller check, line 197-202 credit check | Caller check first; external `_pretransferCredit` at lines 411, 513, 596, 663, 766 is informational (refund math via `_refundExactOutCredit`). The input-ceiling check at lines 407, 504, 588, 657, 761 is `quote > max`. |
| `CamelotV2StandardExchangeCommon.sol:219-231` (`_secureSelfBurn`) | line 225 caller check, line 226-228 credit check | Caller check first. |
| `LidoWstETHStandardExchangeCommon.sol:493-508` (`_securePull`) | line 495 caller check, line 496-499 credit check | Caller check first; external `_pretransferCredit` at lines 64, 85 is informational (`_reserveBeforePretransfer` consumes it, but the short-credit revert is inside `_securePull`). |
| `EtherFiWeETHStandardExchangeCommon.sol:504-521` (`_securePull`) | line 506 caller check, line 507-510 credit check | Caller check first; external `_pretransferCredit` at lines 61, 84 is informational. |
| `RocketPoolRETHStandardExchangeCommon.sol:352-371` (`_securePull`) | line 357 caller check, line 358-361 credit check | Caller check first; external `_pretransferCredit` at lines 60, 82 is informational. |
| `AaveV3StataStandardExchangeCommon.sol:265, 294` (`_secureSelfBurn` / `_secureTokenTransfer`) | caller check first, then credit check | Both helper secure-pulls are correctly ordered; Aave V3 OutTarget's external `_pretransferCredit` (none, per grep; Aave uses `LocalCreditLib.budget` directly inline at lines 75-82, 120-126) is informational and the credit revert is inside the secure-pull. |
| `AaveV3StataStandardExchangeOutTarget.sol:75-82, 120-126` | caller check on line 77, 122; credit check follows; informational credit measured inline | The pretransfer branch at lines 75-82 is `if (prepaid_) { LocalCreditLib.requirePretransferCaller(msg.sender); credit_ = LocalCreditLib.budget(...); if (spent_ > credit_) revert ...; }`. Caller check is first; the controller's "credit measurement" is the `LocalCreditLib.budget` call after the authentication, not a separate view call. |
| `AerodromeStandardExchangeOutExecuteTarget.sol:285-300` (`_creditOutInbound`) | line 290 caller check, line 291 measurement, line 292-294 credit check | Caller check first. |
| `AerodromeStandardExchangeOutExecuteTarget.sol:390-420` (`_execRoute6`) | line 396 caller check, line 397 measurement | Caller check first. |
| `AerodromeStandardExchangeOutExecuteTarget.sol:481-500` (`_execUnderlyingPoolVaultDeposit`) | line 488 caller check, line 489 measurement, line 494-496 short-credit check | Caller check first; the `if (amountIn_ > credited_) revert ISecurePullErrors.TransferDeltaInsufficient(amountIn_, credited_);` is the only place the short-credit error fires, and it sits on line 496 inside the post-compounding pretransfer block, after the caller's authentication on line 488. |
| `SlipstreamStandardExchangeCommon.sol:505-517` (`_secureTokenTransfer`) | line 509 caller check, line 510-515 credit check | Caller check first; the only `SlipstreamStandardExchangeOutTarget.sol` pretransfer call at line 85 is informational (refund math). |
| `UniswapV2StandardExchangeOutTarget.sol` (all 7 call sites, lines 462, 547, 623, 693, 794, 905, 972) | All external `_pretransferCredit` calls are informational; the short-credit revert is inside `_secureTokenTransfer` / `_secureSelfBurn` which already check the caller first. | All seven sites are out of scope for this defect per the PRD non-goal on input-ceiling checks. |
| `MorphoBlueStandardExchangeCommon.sol:182-204` (`_securePull`) | line 198 caller check, line 199-202 credit check | Caller check first; the Morpho OutTarget's external `_pretransferCredit` / `LocalCreditLib.budget` calls (line 312, 124) are inside `if (pretransferred)` blocks that already check the caller first. |
| `BalancerV3SinglePoolStandardExchange.sol:162-171` and `:236-252` | line 164, 238 caller check; credit follow-up | Caller check first on the pretransfer branches; the short-credit revert is at line 167 and line 241. |
| `NativeStandardYieldTarget.sol:36-42` (`redeem`) | line 37 caller check, line 38 share-held check | SY redeem; not a Standard Exchange pretransfer credit measurement. |

The above table is the PRD's "cited and left alone" set. No edits in this list.

---

## 4. Other production sites I checked that are not this defect

The PRD's search instruction is "Search every production call of `_pretransferCredit`." The above table covers every call site under the listed files. None of those sites measures pretransfer credit or runs a plan that consumes that credit before the caller check. The only in-scope defects are the five functions listed in §2.

I did not find any additional in-scope production site that the PRD missed. The four defects are concentrated in two V4 FullSpread facets (hookless, Pons-family), each in two functions, and one V3 mint delegate. The cited-correct sites and the "secure-pull already in order" sites account for the rest.

---

## 5. Acceptance evidence the PRD requires

The PRD's `## REQ-C06` acceptance criteria are satisfied by the F1–F5 fixes when applied. The expected per-criterion evidence:

1. `requirePretransferCaller` runs before `_pretransferCredit` and before the consuming plan on each prepaid branch that measures credit before authentication — **fixed by F1, F2, F3, F4, F5**. After the change, the call sites in §2 each have the form:
   - V4 hookless `_executeZapInMintExactOut`: `if (pretransferred) { LocalCreditLib.requirePretransferCaller(msg.sender); }` immediately before `uint256 credit = pretransferred ? _pretransferCredit(tokenIn, maxAmountIn) : 0;`.
   - V4 hookless `_executeDirectOut`: `if (prepaid) { LocalCreditLib.requirePretransferCaller(msg.sender); }` immediately before `frame.credit = prepaid ? _pretransferCredit(tokenIn, maximum) : 0;`.
   - V4 Pons `_executeZapInMintExactOut` / `_executeDirectOut`: identical.
   - V3 mint delegate `executeZapInMintExactOut`: `LocalCreditLib.requirePretransferCaller(msg.sender);` immediately before `uint256 credit = pretransferred ? _pretransferCredit(token, maxAmountIn) : 0;`.
2. A code-less caller with short credit still reverts `EOAPretransferNotAllowed` — **preserved**. The new caller check fires before measurement; the code-less caller reverts at the new statement, no measurement, no plan, no short-credit revert. The existing `_requirePrepaidCredit` (V4 hookless/Pons) and inline `LocalCreditLib.requirePretransferCaller` (V3 mint delegate) checks become redundant but harmless.
3. A contract caller allowed to pretransfer with short credit still reverts `TransferDeltaInsufficient` — **preserved**. The contract caller passes the new caller check at the top, the measurement runs, the plan runs, the input-ceiling check runs, and the existing `if (used > credit) revert ISecurePullErrors.TransferDeltaInsufficient(used, credit);` inside `_requirePrepaidCredit` (V4) or the inline `if (amountIn > credit) revert ...;` (V3) fires. The credit error is the one reached; no tokens move.
4. A false-flag path does not gain this caller check — **preserved**. All five new statements are wrapped in the existing `if (pretransferred)` / `if (prepaid)` conditional. The `pretransferred=false` path is not reached.
5. V3 quoted exact-output, which already has the required order, is cited and left alone — **preserved**. The F5 fix is only on `executeZapInMintExactOut` in the V3 OutExecutionDelegate. `_executeQuotedSwapOut` in `UniswapV3FullSpreadStandardExchangeVaultOutExecuteTarget.sol:81-84` is unchanged.

---

## 6. Non-goals (do not do)

- Do not split facets. The owner ruled against facet splits in this item.
- Do not delete `_requirePrepaidCredit`, `_secureTokenTransfer`, `_securePull`, `_secureSelfBurn`, `_creditOutInbound`, `_receiveExactIn`, the input-ceiling checks, the refund math, or the disable / deadline / `_requireNotDisabled` / `_pokeBoundPoolTwap` calls in any of the listed files.
- Do not introduce a `catch` to absorb the new caller check.
- Do not change the `LocalCreditLib.requirePretransferCaller` body or the error it reverts with (`ISecurePullErrors.EOAPretransferNotAllowed`).
- Do not edit `contracts/protocols/dexes/uniswap/v4` (the legacy V4 being deleted by another agent). The V4 FullSpread hookless and Pons-family under `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/` are in scope; the legacy under `contracts/protocols/dexes/uniswap/v4/` is not.
- Do not edit the V3 quoted exact-output branch (`UniswapV3FullSpreadStandardExchangeVaultOutExecuteTarget.sol:81-84`).
- Do not edit the V3 OutMultiTarget, the V3 OutExecutionDelegate's `executeZapOutWithdrawal`, the V4 FullSpread hookless and Pons OutExecutionDelegate's `executeZapOutWithdrawal`, or the V4 FullSpread hookless and Pons OutMultiTarget. These are the cited-correct sites and must stay.
- Do not add a new `catch`, do not catch a reverter, do not log a reverter.
- Do not change the quote math, the input maximum, the slippage check, the settlement output check, or the `_mint` / `_burn` / `_syncVaultReserves` calls in any of the five functions.
- Do not change any other family's pretransfer flow. The other families (Camelot V2, Lido, EtherFi, Rocket Pool, Aave, Aerodrome V1, Slipstream, Uniswap V2, Morpho, Balancer, Native SY) are not in scope for this defect per the PRD non-goal on input-ceiling checks.
- Do not deploy or upgrade live instances. The PRD does not authorize live deployment.
- Do not claim a passing suite proves the fix. The PRD requires the production path; source presence is not a passing test. The implementer must run the affected production-path tests on the production proxy and report commands and toolchain.

---

## 7. Original findings (F1–F5)

F1 — V4 FullSpread hookless `_executeZapInMintExactOut` measures pretransfer credit at line 94 and builds a plan that consumes the measured credit at line 95 before the caller check at line 101. Fix: insert `if (pretransferred) { LocalCreditLib.requirePretransferCaller(msg.sender); }` immediately before line 94; keep the existing credit comparison inside `_requirePrepaidCredit`; do not change any other line.

F2 — V4 FullSpread hookless `_executeDirectOut` measures `frame.credit` at line 165 and builds a plan that consumes the measured credit at line 166 before the caller check at line 169. Fix: insert `if (prepaid) { LocalCreditLib.requirePretransferCaller(msg.sender); }` immediately before line 165; keep the existing credit comparison inside `_requirePrepaidCredit`; do not change any other line.

F3 — V4 FullSpread Pons-family `_executeZapInMintExactOut` is a structural copy of F1 with the same defect and the same fix.

F4 — V4 FullSpread Pons-family `_executeDirectOut` is a structural copy of F2 with the same defect and the same fix.

F5 — V3 FullSpread mint delegate `executeZapInMintExactOut` measures pretransfer credit at line 102 and builds a plan that consumes the measured credit at line 103 before the caller check at line 109. Fix: insert `LocalCreditLib.requirePretransferCaller(msg.sender);` immediately before line 102; keep the existing `LocalCreditLib.requirePretransferCaller(msg.sender);` call on line 109 (now redundant); keep the existing credit comparison on line 110; do not change any other line.

All five fixes are strictly additive single statements at the documented positions. None changes a signature, selector, event, error, helper, or external call signature. The cited-correct sites and the out-of-scope legacy V4 package are unchanged.

I did not run Forge.