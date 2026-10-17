# Grok — REQ-C06 prepaid caller check before credit measurement

Independent first pass. Controlling text is `docs/reviews/apex-remediation-application-2026-10-14/REMEDIATION_PRD.md` section REQ-C06. The 2026-10-11 draft `docs/reviews/apex-req-c06-pretransfer-caller-first/REMEDIATION_PRD.md` is a claim, not authority. `contracts/protocols/dexes/uniswap/v4` was not inspected and is out of scope.

Severity for every defect below is Low, matching the controlling item. This is diagnostic order. It is not an authorization bypass and it is not REQ-C02.

## Draft claims corrected against current source

Facts:

- The draft says V3 quoted exact-output at `UniswapV3FullSpreadStandardExchangeVaultOutExecuteTarget.sol:81-86` still measures credit before the caller check. Current source at lines 81-84 calls `LocalCreditLib.requirePretransferCaller` and only then `_pretransferCredit`. That claim is stale. Leave that function alone.
- The draft says the V3 exact-output withdrawal delegate already has the required order at lines 30-34. Current source confirms that. Leave it alone.
- The draft says hookless and Pons lines 100-104 still revert the credit error before the caller check. Current source moved that comparison into `_requirePrepaidCredit`, which checks the caller and then compares credit. The remaining defect is the measurement and the plan that consumes it, at lines 94-95 and 165-166. That matches the application PRD, not the draft's early-credit-revert description.
- The draft does not name the V3 mint delegate. The application PRD does. Current source confirms `executeZapInMintExactOut` lines 102-110.
- The draft's "three known sites" is incomplete against the application acceptance sentence, which covers each prepaid branch that measures credit before authentication.

## Grok finding 1 — Hookless mint plan consumes measured credit before the caller check

- **Severity:** Low
- **File and line:** `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/UniswapV4FullSpreadHooklessStandardExchangeVaultOutExecuteTarget.sol:94-101`
- **Intended behavior:** On a pretransfer, `LocalCreditLib.requirePretransferCaller` runs before `_pretransferCredit` and before a quote or plan that consumes that credit. The credit comparison remains and runs after that caller check. A false flag does not receive the caller check.
- **Broken invariant:** Line 94 measures credit when `pretransferred` is true. Line 95 passes that credit into `_amountInForZapMint`, which subtracts it from the reserve used for the mint quote, before `_requirePrepaidCredit` at line 101. The input ceiling at line 96 is not this defect and stays.
- **Impact class:** Diagnostic order. A plan built from measured credit can fail before `EOAPretransferNotAllowed`. No authorization bypass.
- **Fix direction:** In `_executeZapInMintExactOut`, keep the zero-shares revert. Immediately after it, and only when `pretransferred` is true, call `LocalCreditLib.requirePretransferCaller(msg.sender)`. Then keep `credit = pretransferred ? _pretransferCredit(tokenIn, maxAmountIn) : 0`, then `_amountInForZapMint`, then the existing `amountIn > maxAmountIn` ceiling. Keep the later `if (pretransferred) { _requirePrepaidCredit(amountIn, credit); pullAmount = credit; }` block, including the credit comparison inside `_requirePrepaidCredit`. Do not call `requirePretransferCaller` when `pretransferred` is false.
- **Confidence:** High

Facts: lines 94-101 and `_amountInForZapMint` in `UniswapV4FullSpreadHooklessStandardExchangeVaultOutBase.sol:59-70` were read. Inference: a code-less caller can reach the plan's route revert before the caller error. Speculation: none.

## Grok finding 2 — Hookless direct-out plan consumes measured credit before the caller check

- **Severity:** Low
- **File and line:** `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/UniswapV4FullSpreadHooklessStandardExchangeVaultOutExecuteTarget.sol:165-169`
- **Intended behavior:** Same as finding 1. The caller is authenticated before credit is measured and before a plan that consumes that credit.
- **Broken invariant:** Line 165 measures credit when `prepaid` is true. Line 166 builds `_directOutPlan` from `_snapshot`, and `_snapshot` subtracts that credit from free balances, before `_requirePrepaidCredit` at line 169. The `used > maximum` ceiling at line 168 is not this defect and stays.
- **Impact class:** Diagnostic order. A plan built from measured credit runs before `EOAPretransferNotAllowed`. No authorization bypass.
- **Fix direction:** In `_executeDirectOut`, keep the zero-amount revert and the `zeroForOne` assignment. If `prepaid` is true, call `LocalCreditLib.requirePretransferCaller(msg.sender)` before `frame.credit` is assigned. Then keep the credit read, the snapshot, `_directOutPlan`, and `used = frame.plan.swap.amountIn`. Keep the `used > maximum` ceiling where it is. Keep `if (prepaid) _requirePrepaidCredit(used, frame.credit)` so the credit comparison stays. Do not call the caller check when `prepaid` is false.
- **Confidence:** High

Facts: lines 159-169 and `_snapshot` at `UniswapV4FullSpreadHooklessStandardExchangeVaultCommon.sol:985-1007` were read. Inference: the snapshot's credit fields are an input to the plan. Speculation: none.

## Grok finding 3 — Pons mint plan consumes measured credit before the caller check

- **Severity:** Low
- **File and line:** `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/UniswapV4FullSpreadPonsFamilyHookOutExecuteTarget.sol:94-101`
- **Intended behavior:** Same as finding 1. Closing hookless does not close Pons.
- **Broken invariant:** Same order as finding 1. Line 94 measures. Line 95 passes credit into `_amountInForZapMint`, which subtracts it from the reserve, before `_requirePrepaidCredit` at line 101. The ceiling at line 96 stays.
- **Impact class:** Diagnostic order. Not an authorization bypass.
- **Fix direction:** Apply the finding 1 statement order in this file's `_executeZapInMintExactOut`. Use this file's existing revert names. Keep `_requirePrepaidCredit` and its credit comparison. Do not add the caller check on the false flag.
- **Confidence:** High

Facts: lines 86-114 and `UniswapV4FullSpreadPonsFamilyHookOutBase.sol:59-70` were read. Inference: none beyond the shared order. Speculation: none.

## Grok finding 4 — Pons direct-out plan consumes measured credit before the caller check

- **Severity:** Low
- **File and line:** `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/UniswapV4FullSpreadPonsFamilyHookOutExecuteTarget.sol:165-169`
- **Intended behavior:** Same as finding 2. Closing hookless does not close Pons.
- **Broken invariant:** Line 165 measures. Line 166 builds the plan from a snapshot that receives that credit, before `_requirePrepaidCredit` at line 169. The ceiling at line 168 stays.
- **Impact class:** Diagnostic order. Not an authorization bypass.
- **Fix direction:** Apply the finding 2 statement order in this file's `_executeDirectOut`. Keep `_requirePrepaidCredit` and its credit comparison. Do not add the caller check when `prepaid` is false.
- **Confidence:** High

Facts: lines 159-169 were read. The Pons common file defines `_directOutPlan` and `_snapshot` on the same pattern as hookless. Inference: the Pons snapshot consumes the credit argument the same way, because the execute target passes it into `_snapshot` before the caller check. Speculation: none on the execute-target order.

## Grok finding 5 — V3 mint delegate measures and plans before the caller check

- **Severity:** Low
- **File and line:** `contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultOutExecutionDelegate.sol:102-110`
- **Intended behavior:** On this prepaid mint branch, `requirePretransferCaller` runs before `_pretransferCredit` and before `_amountInForZapMint` consumes that credit. The `TransferDeltaInsufficient` comparison stays after the caller check. A false flag does not receive the caller check.
- **Broken invariant:** Line 102 measures when `pretransferred` is true. Line 103 passes that credit into `_amountInForZapMint`, which subtracts it from the reserve, before `requirePretransferCaller` at line 109. The ceiling at line 104 is not this defect and stays. The withdrawal function in this same file already has the required order and is not this defect.
- **Impact class:** Diagnostic order. A plan built from measured credit runs before `EOAPretransferNotAllowed`. Not an authorization bypass.
- **Fix direction:** In `executeZapInMintExactOut` only, keep the zero-shares revert. Move the existing `LocalCreditLib.requirePretransferCaller(msg.sender)` from line 109 to immediately before the credit read, still only when `pretransferred` is true. Then keep the credit read, `_amountInForZapMint`, and the `amountIn > maxAmountIn` ceiling. In the later `if (pretransferred)` block, keep `if (amountIn > credit) revert ISecurePullErrors.TransferDeltaInsufficient(amountIn, credit)` and `pullAmount = credit`. Do not leave a second caller check in that block. Do not add the caller check when `pretransferred` is false. Do not edit `executeZapOutWithdrawal`.
- **Confidence:** High

Facts: lines 20-110 and `UniswapV3FullSpreadStandardExchangeVaultOutBase.sol:43-51` were read. Inference: the subtraction of measured credit is a consuming plan. Speculation: none.

## Grok finding 6 — Staking mint quotes consume measured credit before the caller check

- **Severity:** Low
- **File and line:** `contracts/protocols/staking/lido/LidoWstETHStandardExchangeOutTarget.sol:64-70`; `contracts/protocols/staking/rocket-pool/RocketPoolRETHStandardExchangeOutTarget.sol:60-65`; `contracts/protocols/staking/etherfi/EtherFiWeETHStandardExchangeOutTarget.sol:61-67`
- **Intended behavior:** The application acceptance sentence covers each prepaid branch that measures credit before authentication. The caller check runs before `_pretransferCredit` and before a quote that consumes that credit. The later credit comparison stays. A false flag does not receive this check. The application file list did not name these three files; current source does.
- **Broken invariant:** Each mint branch measures credit, passes it to `_reserveBeforePretransfer`, and quotes the mint input from that adjusted reserve before `_securePull`. `_securePull` checks the caller only after that quote. The following `amountIn > maxAmountIn` ceiling stays; it is not separately this defect. One family does not close another.
- **Impact class:** Diagnostic order. A quote built from measured credit runs before `EOAPretransferNotAllowed`. Not an authorization bypass.
- **Fix direction:** In each file's asset-to-share mint branch only, if `pretransferred` is true, call `LocalCreditLib.requirePretransferCaller(msg.sender)` immediately before that branch's `_pretransferCredit` call. Then keep the credit read, `_reserveBeforePretransfer`, the mint quote, and the existing maximum ceiling in that order. Leave Lido's `stETH` false-flag adjustment and EtherFi's `eETH` false-flag adjustment where they are. Keep `_securePull` and its existing caller check and credit comparison. Do not add the caller check when `pretransferred` is false. Do not edit the share-redeem branches; they do not call `_pretransferCredit`.
- **Confidence:** High

Facts: the three mint windows and `_reserveBeforePretransfer` at `LidoWstETHStandardExchangeCommon.sol:286-293` were read. Rocket and EtherFi call the same helper name before `_securePull`. Inference: those two helpers also remove the measured credit from the pre-deposit reserve, because the call sites pass `credit` into a function whose Lido copy does that and whose comments describe the same removal. Speculation: none on the call order, which was read.

## Grok finding 7 — Measurement runs before the caller check where no plan consumes it

- **Severity:** Low
- **File and line:**
  - `contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeOutTarget.sol:462`, `:547`, `:623`, `:693`, `:794`, `:905`, `:972`
  - `contracts/protocols/dexes/camelot/v2/CamelotV2StandardExchangeOutTarget.sol:411`, `:513`, `:596`, `:663`, `:766`
  - `contracts/protocols/staking/lido/LidoWstETHStandardExchangeOutTarget.sol:85`
  - `contracts/protocols/staking/rocket-pool/RocketPoolRETHStandardExchangeOutTarget.sol:82`
  - `contracts/protocols/staking/etherfi/EtherFiWeETHStandardExchangeOutTarget.sol:84`
- **Intended behavior:** `requirePretransferCaller` runs before `_pretransferCredit` on each prepaid branch. The existing credit comparison stays after that check. A false flag does not receive the caller check.
- **Broken invariant:** Each listed line calls `_pretransferCredit` when the prepaid flag is true, and only a later `_secureTokenTransfer`, `_secureSelfBurn`, or `_securePull` calls `requirePretransferCaller`. The quote and the maximum ceiling above those lines do not consume the measured credit. They are not this defect and stay. The credit comparison inside the later helper, and inside `_refundExactOutCredit`, already runs after the caller check.
- **Impact class:** Diagnostic order only. On these branches a code-less caller already reaches `EOAPretransferNotAllowed` before `TransferDeltaInsufficient`, because the next authenticated pull checks the caller before its credit comparison. The view measurement still runs first, which the acceptance sentence forbids. Not an authorization bypass.
- **Fix direction:** Immediately before each listed `_pretransferCredit` call, and only when that branch's prepaid flag is true, call `LocalCreditLib.requirePretransferCaller(msg.sender)`. Keep the credit read. Keep the following `_secureTokenTransfer`, `_secureSelfBurn`, or `_securePull`, including its existing caller check and credit comparison. Keep `_refundExactOutCredit`. Do not move the preceding maximum ceiling. Do not add the caller check when the flag is false.
- **Confidence:** High

Facts: each listed call was read, as were the following secure-pull helpers. Inference: none. Speculation: none.

## Recorded, not a repair

`contracts/protocols/dexes/aerodrome/slipstream/SlipstreamStandardExchangeOutTarget.sol:85` measures credit before `_secureTokenTransfer`, which then checks the caller. The controlling non-goal says do not restore Slipstream. Record this line. Do not edit that tree.

## Sites that already check the caller first — leave alone

- `UniswapV3FullSpreadStandardExchangeVaultOutExecuteTarget.sol:81-84`, quoted exact-output. Cited by the application PRD. Do not edit.
- `UniswapV3FullSpreadStandardExchangeVaultOutExecutionDelegate.sol:30-32`, withdrawal only. Do not edit this function while fixing finding 5.
- `UniswapV3FullSpreadStandardExchangeVaultOutMultiTarget.sol:39-40`
- `UniswapV4FullSpreadHooklessStandardExchangeVaultOutExecutionDelegate.sol:36-37`
- `UniswapV4FullSpreadPonsFamilyHookOutExecutionDelegate.sol:36-37`
- `UniswapV4FullSpreadHooklessStandardExchangeVaultOutMultiTarget.sol:45-46`
- `UniswapV4FullSpreadPonsFamilyHookOutMultiTarget.sol:45-46`
- `AerodromeStandardExchangeOutExecuteTarget.sol:290-291`, `:396-397`, and `:488-489`
- The `_secureTokenTransfer`, `_securePull`, and `_secureSelfBurn` helpers that call `requirePretransferCaller` before their available-balance comparison. Do not reorder those helpers. The defects are the callers that measure first.

The maximum ceilings that sit before a caller check and do not consume measured credit are not defects. Do not move them as this repair.

## Files examined with no defect in this item

- `UniswapV3FullSpreadStandardExchangeVaultOutExecuteTarget.sol` quoted path
- `UniswapV3FullSpreadStandardExchangeVaultOutMultiTarget.sol`
- `UniswapV4FullSpreadHooklessStandardExchangeVaultOutExecutionDelegate.sol`
- `UniswapV4FullSpreadHooklessStandardExchangeVaultOutMultiTarget.sol`
- `UniswapV4FullSpreadPonsFamilyHookOutExecutionDelegate.sol`
- `UniswapV4FullSpreadPonsFamilyHookOutMultiTarget.sol`
- `AerodromeStandardExchangeOutExecuteTarget.sol` prepaid credit sites
- `UniswapV3FullSpreadStandardExchangeVaultCommon.sol` `_secureTokenTransfer`
- `UniswapV4FullSpreadHooklessStandardExchangeVaultCommon.sol` `_secureTokenTransfer`
- `UniswapV4FullSpreadPonsFamilyHookCommon.sol` caller check before its credit helper definition
- `UniswapV2StandardExchangeCommon.sol`, `CamelotV2StandardExchangeCommon.sol`, `AerodromeStandardExchangeCommon.sol`, and the three staking commons, for the helpers that already check the caller before the credit comparison

I did not run Forge.
