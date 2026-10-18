# Astra — RC-05 single-CP refund review

**Replacement-session original.** I am the labeled replacement and do not recall `ses_ec412bcc2ffejKLo7nuoEAqbV0`. This is an independent first pass. No other reviewers' notes were read. The controlling RC-05 text in `docs/reviews/apex-2026-09-17-remediation-council/REMEDIATION_PRD.md:133–144` was freshly read successfully; no guard denial occurred.

## Verdict

**Close RC-05.** No second public/external `exchangeOut` implementing the reported unbounded `maxAmountIn - amountIn` true-flag refund remains in the inspected single-CP hook family. The specifically cited abstract HookTarget no longer defines `exchangeOut`. The remaining SE entry uses the guarded credit/refund path.

This conclusion rests on source absence and the surviving call chain, **not** on the old function being absent from an installed diamond cut. No production fix or owner choice between deletion and delegation is needed for the current finding.

## Source inventory

Searched all Solidity files under:

`contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/`

The searches covered `function exchangeOut`, all `exchangeOut` references, maximum-minus-input refund expressions, `_exchangeOut`, refund helpers, `credit - used`, token transfers to the caller, `LocalCreditLib.budget`, and `requirePretransferCaller`.

### Original abstract target: reported implementation is absent

File: `UniswapV4SingleStandardExchangeBufferConstantProductHookTarget.sol` in that family directory.

- **49:** remains an abstract contract inheriting `IHooks`.
- The file-wide `exchangeOut` search finds only an **outbound dependency call at 349**, not an entrypoint definition.
- Direct read of **690–784** confirms the SE section now ends with `previewExchangeOut` at **714–721** and `_routeZeroForOne` at **723–728**, followed by deposit functions. The historical line range no longer contains the reported refund implementation.
- No `maxAmountIn - amountIn` refund was found there.

The target still contains other operations, including liquidity deposit refunds of unused input. Their existence is not a second public exact-output SE implementation and is not counted as the reported RC-05 defect. This review does not broaden RC-05 into an audit of every abstract-target operation.

### Surviving SE entry: bounded refund and caller check

File: `UniswapV4SingleStandardExchangeBufferConstantProductHookSeTarget.sol`.

- **750–761:** the only `exchangeOut` definition found in the scoped family dispatches to the liquidity route or `_swapExchangeOut`.
- **763–778:** `_swapExchangeOut` is nonReentrant, quotes required input, rejects `amountIn > maxAmountIn`, and invokes `_pullExactOutInput`.
- **872–890:** `_securePull` checks an exact transfer delta on the false flag; on the true flag it invokes `LocalCreditLib.requirePretransferCaller(msg.sender)` at **885**, then rejects use above unbooked availability.
- **894–902:** `_unbookedBalance` subtracts the applicable raw/identity-leg book through `LocalCreditLib.available`; it does not substitute the whole booked balance as caller credit.
- **907–913:** `_pullExactOutInput` returns without refund for false-flag input. For true-flag input it calculates `credit = LocalCreditLib.budget(_unbookedBalance(token), maxAmountIn)` and refunds only `credit - used` when positive.

`contracts/utils/LocalCreditLib.sol:14–26`, read in full, defines availability as the positive balance-minus-book excess, budget as the lesser of availability and the declared maximum, and rejects a pretransfer caller without bytecode.

The two necessary input bounds are present across the call chain: required input does not exceed the declared maximum, and the secure pull does not allow it above unbooked availability. The resulting refund is bounded by actual credit. It is not the removed declared-maximum refund.

### Liquidity-route branch: not a hidden copy of the old refund

The dispatch at SeTarget **759** uses `contracts/hooks/uniswap/v4/libs/UniswapV4BufferHookLiquidityRouteLib.sol`. Its `exchangeOut` at **87–102** is internal. It checks the quoted maximum and, for prepaid input, checks the caller then rejects with the existing insufficient-credit error at **94–95**. The ordinary route delegates with the quoted bound and checks the returned input. It contains no true-flag maximum-minus-used refund. Therefore this imported branch does not recreate the RC-05 source pattern.

### Facet exposure is corroboration, not the closure argument

`facets/UniswapV4SingleStandardExchangeBufferConstantProductHookSeFacet.sol:18–20` inherits the SE target; **85–86** lists its preview and `exchangeOut` selectors. That is consistent with the guarded implementation being exposed. It is not used to excuse an unsafe duplicate remaining elsewhere: the family-wide definition/reference search established that the cited abstract duplicate is absent.

Dependency `IStandardExchangeOut(...).exchangeOut` calls in HookTarget **349**, SeTarget **438**, WithdrawTarget **312**, and DepositCommon **344** are outgoing calls, not additional public entrypoint definitions. Owner-only exact-output swap at SeTarget **822–837** uses a false-flag secure pull and is not the reported prepaid refund entry.

## Facts, inference and limits

**Confirmed:** the named abstract target contains no exchangeOut definition; the family search finds one surviving SE entry; its swap path has both the bytecode caller check and LocalCreditLib budgeted refund; the imported liquidity branch does not implement the prohibited refund.

**Inference:** the September claim is refuted against the current family source. The absent unsafe function satisfies RC-05's source-removal acceptance criterion without requiring another repair.

**Unverified:** historical implementation at filing, when removal occurred, prior/current deployed cuts and runtime execution. No claim is made that an immutable instance was upgraded or that every unrelated route is defect-free. No Forge run or test pass is claimed. The supplied requirement allows source deletion as resolution; a missing execution run does not recreate a deleted function.

## Files examined without a scoped defect

- `UniswapV4SingleStandardExchangeBufferConstantProductHookTarget.sol` — definition/reference searches and the former entry section.
- `UniswapV4SingleStandardExchangeBufferConstantProductHookSeTarget.sol:750–921` — surviving entry, dispatch, bound checks, pull and refund helpers.
- `facets/UniswapV4SingleStandardExchangeBufferConstantProductHookSeFacet.sol:1–100` — inheritance and selector exposure.
- `contracts/hooks/uniswap/v4/libs/UniswapV4BufferHookLiquidityRouteLib.sol:80–109` — imported exact-output dispatch.
- `contracts/utils/LocalCreditLib.sol` — complete credit and caller-check helper.
- Controlling RC-05 PRD section; scoped family source searches as listed above.

All supplied inputs were present. The assigned output was absent before writing. Only this assigned Markdown report was created. No code, tests, PRD, original review, configuration or instructions were edited. No delegation, shell, build, test, chain read or deployment was performed. Return to the coordinator/human and stop.

Close RC-05
I did not run Forge.
