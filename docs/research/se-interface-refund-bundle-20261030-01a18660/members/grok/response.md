# Member response

## Identity

- Run ID: se-interface-refund-bundle-20261030-01a18660
- Member label: grok
- Profile: research
- Phase: initial independent response
- Owned path: docs/research/se-interface-refund-bundle-20261030-01a18660/members/grok/response.md
- Requested role: council-member
- Requested model and reasoning: xai/grok-4.7:xhigh
- Actual role, model, reasoning, task ID, and session ID: not exposed
- Fresh or continued: fresh. This assignment is the initial independent pass. Native session continuity was not exposed.
- Peers read before submission: no

## Question and targets

- Question: Should the Standard Exchange interface set be redefined so one previewExchange/exchange family covers swaps, deposits, and withdrawals, including a same-token refund when an input cannot be fully consumed, and what exact interface definitions does the council recommend?
- Required targets: `lib/crane/contracts/interfaces/IStandardExchangeIn.sol`, `lib/crane/contracts/interfaces/IStandardExchangeOut.sol`, `lib/crane/contracts/interfaces/IStandardExchangeErrors.sol`, `contracts/interfaces/IStandardExchange.sol`, `contracts/interfaces/IStandardExchangeInMulti.sol`, `contracts/interfaces/IStandardExchangeOutMulti.sol`, `contracts/interfaces/IStandardExchangeMultiAssetLiquidity.sol`, `contracts/vaults/basic/IBasicVault.sol`
- Optional context: `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/PAIRTOKEN_FUNCTIONS_FOR_REVIEW.md` and `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_PRD.md`. Read as context for why a refund question arose. Not treated as interface law.
- Admitted read scope: those required interface files, their immediate error interface (`IStandardExchangeErrors`), and the two optional full-spread notes. No peer responses. No implementations.

## Evidence

| Item | Source | Class | What was observed |
| --- | --- | --- | --- |
| Owner proposal | `docs/research/se-interface-refund-bundle-20261030-01a18660/brief.md`, Owner proposal | coordinator-supplied | Keep `previewExchange` / `exchange` with modifying suffixes. A vault that cannot consume the full user-provided amount must leave a remainder of that same token, and the interface must return the refunded amount. Integrations are expected to process every underlying. Add `IStandardExchangeBundleInForSingleOut` with `previewExchangeBundleInForSingleOut` and `exchangeBundleInForSingleOut`: `amountsIn` in `vaultTokens()` order, one output token, pretransfer option. Add `IStandardExchangeBundleOut` with `previewExchangeBundleOut` and `exchangeBundleOut`: an array of tokens the user expects to receive, the pay token, pretransfer option. |
| Exact-in surface | `lib/crane/contracts/interfaces/IStandardExchangeIn.sol` | source observation | `previewExchangeIn(IERC20,uint256,IERC20)` returns only `amountOut`. Comment selector `0x89d61912`. `exchangeIn(IERC20,uint256,IERC20,uint256,address,bool,uint256)` returns only `amountOut`. Comment selector `0x05562cc8`. Interface id comment `0x8c8035da`. Pretransfer comment: tokens above the declaration are not refunded. Declared input is processed only when present unbooked input covers it. `InArgs` is declared and unused by the functions. Error `ExchangeInNotAvailable()`. |
| Exact-out surface | `lib/crane/contracts/interfaces/IStandardExchangeOut.sol` | source observation | `previewExchangeOut(IERC20,IERC20,uint256)` returns `amountIn`. Comment selector `0xdb149bc5`. `exchangeOut` returns `amountIn` (amount provided), not a refund. Comment selector `0x612d4427`. Interface id comment `0xba39dfe2`. Notice: exact-output pretransfer refunds only `min(unrecorded balance, maxAmountIn) - used` to `msg.sender`. False-flag exact-output pulls quoted used and refunds nothing. Amounts above `maxAmountIn` are never refunded. Error `ExchangeOutNotAvailable()`. |
| Shared errors | `lib/crane/contracts/interfaces/IStandardExchangeErrors.sol` | source observation | Declares `DeadlineExceeded`, `MaxAmountExceeded`, `MinAmountNotMet`, `InvalidRoute`, `RouteNotSupported`, `AmountOutNotMet`, `UnknownReserve`. Does not declare `EOAPretransferNotAllowed`, a refund error, a length error, or `IncompleteConversion`. |
| Combined interface | `contracts/interfaces/IStandardExchange.sol` | source observation | Inherits In and Out. Declares no functions of its own and no interface id. |
| Many-to-one | `contracts/interfaces/IStandardExchangeInMulti.sol` | source observation | `previewExchangeInManyToOne` / `exchangeInManyToOne` take `address[] tokenIn` plus `uint256[] amountsIn`, not `vaultTokens()` indexes alone. Comment: vault declared order; V4 uses PoolKey order with WETH as the ERC-20 face of a native currency. Returns only `amountOut`. "Tokens above the declaration are not refunded." Does not inherit `IStandardExchangeErrors`. |
| One-to-many | `contracts/interfaces/IStandardExchangeOutMulti.sol` | source observation | `tokenIn` must be vault shares. `tokensOut` are the two unique pool currencies in declared order, again with a WETH face. Exact `amountsOut`. Returns shares burned, not output amounts. Exact-output slack refund is the same side effect as `exchangeOut`, not a named return. |
| Liquidity extension | `contracts/interfaces/IStandardExchangeMultiAssetLiquidity.sol` | source observation | Comment: canonical In/Out remain swap-only; do not merge selectors into In/Out. Uses join/exit/deposit/withdraw names, not `previewExchange` / `exchange`. `previewJoinProportional` returns `(shares, usedAmounts)`. No `pretransferred` flag. No refund return. License `BSL-1.1`. |
| Token order getter | `contracts/vaults/basic/IBasicVault.sol` | source observation | `vaultTokens()` returns `address[]`. Comment: tokens this vault will accept/produce for exchanges. Comment selector `0x9d63848a`. `reserveOfToken` comment selector `0x46f910ac` and `reserves` comment selector `0x75172a8b`. License `BSL-1.1`. The file does not say whether the share is in the returned list. |
| Selector check, local | `cast sig` on the canonical signatures of the functions as written. Local. Not a public query. | static analysis | `previewExchangeIn(address,uint256,address)` = `0x89d61912` (matches the comment). `exchangeIn(address,uint256,address,uint256,address,bool,uint256)` = `0xd02d3063` (does not match comment `0x05562cc8`). `previewExchangeOut(address,address,uint256)` = `0xdb149bc5` (matches). `exchangeOut(address,uint256,address,uint256,address,bool,uint256)` = `0xbbac8477` (does not match comment `0x612d4427`). `vaultTokens()` = `0x69722233` (does not match comment `0x9d63848a`). `reserveOfToken(address)` and `reserves()` match their comments. `IERC20` encodes as `address`. Return types are not part of a Solidity selector. The interface-id comments equal the XOR of the documented selectors, including the two that do not match `cast sig`. |
| Selector lookup | `cast 4byte` against `https://openchain.xyz` for `0x05562cc8`, `0x612d4427`, `0x9d63848a`, `0xd02d3063`, `0xbbac8477`, `0x69722233`. Selectors only. Private source excerpts were not sent. | source observation | Openchain had no match for `0x05562cc8` or `0x612d4427`. It mapped `0x9d63848a` to `tokens()`, `0xd02d3063` to the `exchangeIn` signature as written, `0xbbac8477` to the `exchangeOut` signature as written, and `0x69722233` to `vaultTokens()`. This lookup is not deployed-bytecode proof. |
| New-selector computation | `cast sig`, local, on the recommended signatures below | static analysis | Recorded on each recommended function as `@custom:selector`. Interface ids below are the XOR of that interface's function selectors only, excluding errors. They are not deployed ids. |
| Why the refund question arose | Optional full-spread notes, read in full | source observation | Not interface law. `PAIRTOKEN_FUNCTIONS_FOR_REVIEW.md` says `exchangeIn` / `previewExchangeIn` are the standard exact-input routes and are not PairToken functions. Paired money (`depositPair`, `redeemPair`) exists because the one-token interface cannot express two-token operations. Native pool entry uses `msg.value` on that product function. `vaultTokens()` is reused from `MultiAssetBasicVaultFacet`; reserves are local plus deployed, in that order. `UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_PRD.md` FS-X04 says the selected positive half-swap consumes its entire specified input or reverts `IncompleteConversion`. Addition remainder `J_i` stays booked to shared backing and is not a token refund. FS-UNLOCK says current hooks call `IStandardExchangeIn.exchangeIn` and a new selector would not be called. `exchangeIn` is described as nonpayable on that borrowed path. `exchangeOut` reverts `ExchangeOutNotAvailable` for that family. |
| Public web search | not used | source observation | No documentation search. The only public query is the `cast 4byte` lookup above. |

## Assumptions

- The NatSpec in the required interfaces is the caller contract for those functions. Implementations were not read. A comment may be ahead of or behind code.
- `IERC20` in an external parameter has ABI type `address`. Selector checks used that encoding.
- `vaultTokens()` can be read by a caller. This response does not assume the share is in that list, and it does not assume the list is immutable.
- The owner quote in the brief is the whole proposal this member was given. No later owner message was part of this assignment.
- The optional full-spread notes explain the occasion for the question. They do not override the owner proposal and they are not the interface under review.
- No further public documentation was required to answer from the admitted files.

## Coverage

| Target | Required or optional | Status | Reason |
| --- | --- | --- | --- |
| `lib/crane/contracts/interfaces/IStandardExchangeIn.sol` | required | examined | Read in full before recommending definitions. |
| `lib/crane/contracts/interfaces/IStandardExchangeOut.sol` | required | examined | Read in full before recommending definitions. |
| `lib/crane/contracts/interfaces/IStandardExchangeErrors.sol` | required | examined | Read in full. It is the immediate error interface. |
| `contracts/interfaces/IStandardExchange.sol` | required | examined | Read in full. |
| `contracts/interfaces/IStandardExchangeInMulti.sol` | required | examined | Read in full. |
| `contracts/interfaces/IStandardExchangeOutMulti.sol` | required | examined | Read in full. |
| `contracts/interfaces/IStandardExchangeMultiAssetLiquidity.sol` | required | examined | Read in full. |
| `contracts/vaults/basic/IBasicVault.sol` | required | examined | Read in full. |
| `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/PAIRTOKEN_FUNCTIONS_FOR_REVIEW.md` | optional | examined | Read in full. Used only as occasion context. |
| `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_PRD.md` | optional | examined | Read in full. Used only as occasion context. |
| Implementations, hooks, stage-one PairToken PRD, deployed bytecode | not admitted | not examined | Outside the admitted read scope. |

## Conclusions

What the sources show, separate from what this member infers:

The current set is not one integration surface. Crane `IStandardExchangeIn` / `IStandardExchangeOut` are single-token exact-in and exact-out. `IStandardExchange` only adds those two together. IndexedEx `IStandardExchangeInMulti` is caller-ordered many-to-one and does not refund surplus above the declaration. `IStandardExchangeOutMulti` is share-in, two-currency, exact-out. `IStandardExchangeMultiAssetLiquidity` uses different names and says its selectors must not be merged into In/Out. `vaultTokens()` is the order source the owner named, and it returns addresses.

Exact-in success today returns only `amountOut`. The pretransfer comment says tokens above the declaration are not refunded. Exact-out already sends unused input to `msg.sender` as a side effect and returns the used amount, not a named refund. A named same-token remainder for "could not keep the declared input" is not on any current function.

Return types are not part of a Solidity selector. Adding a return would not change `exchangeIn`'s selector. It would still change the returndata and the success meaning. The `@custom:selector` comments on `exchangeIn`, `exchangeOut`, and `vaultTokens()` do not match `cast sig` of the signatures in those files. Those comments are not a safe source of ABI hex. This recommendation does not copy them.

Agreement is not available. Peers were not read. This is not a council consensus.

### Answer

Yes. Redefine the Standard Exchange set so one `previewExchange` / `exchange` family is the integration surface for swaps, deposits, and withdrawals, and so a same-token refund is a named return when a declared input is not fully kept.

Do that by adding interfaces beside the current functions. Do not replace a current function. Do not extend a current function with another parameter or return. Do not merge `IStandardExchangeMultiAssetLiquidity` into In/Out.

Deposits and withdrawals are routes on that family. `tokenOut` equal to the share is a deposit. `tokenIn` equal to the share is a withdrawal. Neither side equal to the share is a swap. They are not new verbs.

### Recommendations for the ambiguities the brief named

Each item below is a recommendation. None of them is the owner's decision.

1. Bundle-out "array of tokens they expect to receive" means addresses, not amounts, and not both as inputs. The owner said "array of amountsIn" for bundle-in and "array of tokens" for bundle-out. Those are different words. Addresses alone cannot state a pay quantity, so `amountIn` of `tokenIn` is added. The mutating function also takes `minAmountsOut`, aligned to `tokensOut`, because every current exchange enforces a floor in the call. Preview does not take the floors. It returns the quoted `amountsOut`. This function is exact-in on the pay token, not exact-out. The non-adopted exact-out reading is under "Not adopted".

2. The refund return does not change current `exchangeIn` or `exchangeOut`. It does not extend them. New suffixes sit beside them. A return-only change would not be a selector break, but it would be a behavior break. Old Solidity callers ignore extra returndata, so they would treat a partial keep as a full consume. Current hooks call `exchangeIn`. The optional full-spread note says a new selector would not be called, and FS-X04 still requires that selector's selected swap to consume its input or revert. Leaving `exchangeIn` alone preserves both. The new functions are how a vault reports a remainder.

3. `IStandardExchangeInMulti` and `IStandardExchangeOutMulti` stay as they are. The new bundle interfaces sit beside them. They do not replace them. Do not add refund returns to the existing multi functions. `exchangeInManyToOne` remains full-keep-or-revert, and surplus above its declaration remains unrefunded. `exchangeOutOneToMany` remains share-in, two-currency, exact-out, with slack refund as a side effect. A vault may implement both. For the same declared inputs, the old function must not partial-fill. The new function may.

4. `IStandardExchangeMultiAssetLiquidity` is not merged, not extended, and not given refund returns. Its "do not merge selectors into In/Out" sentence stands for join, exit, deposit, and withdraw. It does not, on this recommendation, ban a share address on a `previewExchange` / `exchange` route. The owner's stated intent is that the exchange family is the architecture integration surface. The liquidity extension remains the product hook ABI. `usedAmounts` is a consumption report, not a refund. Do not treat it as one.

5. Native ETH is not `address(0)` on the new functions, and the new functions are not payable. The multi-route comments already use an ERC-20 face for V4 native currency. The standard refund is that ERC-20 face, which is the token the standard function accepted. Raw ETH and `msg.value` stay on product functions such as the full-spread paired entry. Those functions are outside this redefinition. `address(0)` on a new function reverts `TokenNotExchangeable`.

6. `vaultTokens()` order is the only legal order for bundle-in `amountsIn` and `amountsRefunded`. That function takes no parallel address array. It is not the legal order for bundle-out `tokensOut`. Bundle-out order is the caller's array. InMulti's "PoolKey order" is not the bundle-in order rule, even if a vault's `vaultTokens()` happens to match it.

7. Preview returns the refund as a number and does not transfer. The number is a quote of the unkept declared input, assuming the declaration is available. It is not a balance read and not a prediction of surplus above the declaration. Execution may return a different refund. `minAmountOut` or `minAmountsOut` is the binding protection. The execution return is the actual refund. Callers must not require bit-exact preview equality. Requiring it would recreate the precision problem the refund exists to allow.

### Further recommendations the definitions depend on

These were not in the owner's sentence. They are recommendations.

8. Add `IStandardExchangeInWithRefund` beside `IStandardExchangeIn`. The owner required a standard-wide refund return and named only the bundle functions. A single-asset caller should not have to build a `vaultTokens()`-sized array to reach the refund rule. The sibling keeps `exchangeIn`'s parameter list and adds the refund return under a new name. A vault that must fully consume, including a vault that still reverts `IncompleteConversion` on `exchangeIn`, does not implement the sibling.

9. On the new functions, every declared wei is either kept or included in the refund. No third bucket inside the declaration. `amountRefunded <= amountIn`, and the same per index for bundle-in. A fee, if any, is part of the kept amount. Refunded wei is the same token the caller declared, is transferred to `msg.sender`, and is not also credited as a deposit. It is not the full-spread `J_i` booking. Surplus above the declaration is still not refunded and is not part of the returned refund.

10. The pull path pulls the declared amount, then transfers the refund of that same token to `msg.sender`. Pull-only-the-consumed-amount is not compliance. The owner asked for a remainder of the token the user provided, then a refund. A zero refund needs no transfer. The pretransfer path uses `bool pretransferred`, not a second function. It keeps the current pretransfer conditions: integrating-contract flag, atomic transfer and consume, no bytecode reverts `EOAPretransferNotAllowed()`, unrecorded balance may be taken by the next contract caller, booked backing is not pretransfer credit, the declaration is processed only when present unbooked input covers it, a short declaration reverts, and booked inventory does not fill a shortfall. This definition adds no new shortfall error. That revert name was not in the admitted error interface.

11. `recipient` receives only the output token or tokens. The refund goes to `msg.sender`. The integrating caller is the party that must process the refund. That matches the current exact-out refund target and the owner's premise that the provider of the token can process it. No separate refund-recipient argument.

12. Do not add the new functions to `IStandardExchange` or to `IStandardExchangeIn`. A grab-bag interface would imply every vault implements every route and would change the combined type. Each new interface has its own id. A vault advertises what it implements.

13. Do not add these errors to `IStandardExchangeErrors`. A sibling error interface holds the errors shared by the new functions. The current error interface stays as written.

14. The new functions do not restrict why a vault refunds. Gas is a sufficient occasion. It is not a parameter and not the only legal cause. A vault that kept the full declaration returns zero.

15. `tokenIn == tokenOut`, or a nonzero bundle-in slot whose `vaultTokens()` entry equals `tokenOut`, or a bundle-out list that contains `tokenIn`, reverts `InvalidRoute` for that pair. That is not a refund. The share may be `tokenIn` or `tokenOut` even when it is absent from `vaultTokens()`.

16. No new events. No unused args structs. No operation enum. No aggregator interface. License for the new exchange interfaces is `AGPL-3.0-or-later`, matching In/Out and the multi interfaces, not the BSL liquidity file. Recommended paths are in the code comments. Moving the bundle interfaces into Crane later would be a placement change, not a signature change.

17. `deadline`, `recipient`, and the min floors are included because every current mutating exchange has them. The owner named the pretransfer option and did not name these. Their order follows `exchangeIn`: economic inputs, floors, `recipient`, `pretransferred`, `deadline`.

18. A zero slot in bundle-in is not provided. It does not require that `vaultTokens()` entry to be exchangeable. A nonzero slot for `address(0)`, or for a token that vault will not exchange, reverts `TokenNotExchangeable`. All-zero input, empty `vaultTokens()` with an empty amounts array, `amountIn == 0`, and empty `tokensOut` revert `EmptyExchange()`. `minAmountsOut` may contain zeros, but its length must equal `tokensOut.length`. An omitted floors array is not "no floors."

19. Bundle-out pays only `tokensOut`, in the caller's order. It does not pay a surprise token. `amountsOut` aligns to `tokensOut`. `amountsRefunded` aligns to `vaultTokens()`, not to a caller-supplied token list. `tokensOut` has no interface-level maximum and is not fixed at two. A vault that cannot pay the requested set reverts `RouteNotSupported` or `ExchangeBundleOutNotAvailable`. Uniqueness is required. Duplicates revert `DuplicateOutput`.

20. File placement: `IStandardExchangeRefundErrors` and `IStandardExchangeInWithRefund` beside the Crane single-asset interfaces. The two bundle interfaces beside the IndexedEx multi interfaces, because their order rule cites `vaultTokens()` and the multi extensions already live there. They do not inherit `IBasicVault`, so reserve selectors do not enter the exchange interface id.

### Beside, replace, or extend

| Function | Relation to the current surface |
| --- | --- |
| `previewExchangeIn`, `exchangeIn` | Unchanged. Not replaced. Not extended. |
| `previewExchangeOut`, `exchangeOut` | Unchanged. Not replaced. Not extended. Exact-out slack stays a side effect to `msg.sender`. |
| `previewExchangeInManyToOne`, `exchangeInManyToOne` | Unchanged. Not replaced. Not extended. |
| `previewExchangeOutOneToMany`, `exchangeOutOneToMany` | Unchanged. Not replaced. Not extended. |
| Every `IStandardExchangeMultiAssetLiquidity` function | Unchanged. Not merged. Not extended. |
| `vaultTokens` | Unchanged. The bundle-in order rule reads it. It does not gain a refund return. |
| `previewExchangeInWithRefund`, `exchangeInWithRefund` | New. Sit beside `previewExchangeIn` / `exchangeIn`. |
| `previewExchangeBundleInForSingleOut`, `exchangeBundleInForSingleOut` | New. Sit beside `previewExchangeInManyToOne` / `exchangeInManyToOne`. |
| `previewExchangeBundleOut`, `exchangeBundleOut` | New. Sit beside `previewExchangeOut` / `exchangeOut` and beside `previewExchangeOutOneToMany` / `exchangeOutOneToMany`. |
| `IStandardExchangeRefundErrors` | New. Sits beside `IStandardExchangeErrors`. Does not extend it. |

Route reading, not new verbs:

| Operation | Function | How the route is told |
| --- | --- | --- |
| Swap, exact-in, full keep or revert | existing `exchangeIn` | `tokenIn` and `tokenOut` are exchange tokens |
| Swap, exact-in, partial keep allowed | `exchangeInWithRefund` | same parameter shape |
| Swap, exact-out | existing `exchangeOut` | unchanged |
| Deposit, one underlying | `exchangeIn` or `exchangeInWithRefund` | `tokenOut` is the share |
| Deposit, many underlyings | `exchangeBundleInForSingleOut` | `amountsIn` in `vaultTokens()` order, `tokenOut` is the share |
| Withdrawal, exact underlying out | existing `exchangeOut` | `tokenIn` is the share |
| Withdrawal, exact-in shares, one output | `exchangeInWithRefund` | `tokenIn` is the share |
| Withdrawal, exact-in shares, named outputs | `exchangeBundleOut` | `tokenIn` is the share, `tokensOut` are the expected tokens |
| Many-to-one swap | `exchangeBundleInForSingleOut` | `tokenOut` is one underlying |
| One-to-many swap | `exchangeBundleOut` | `tokenIn` is one underlying |
| Caller-ordered many-to-one, no partial keep | existing `exchangeInManyToOne` | not the refund route |
| Share to two currencies, exact-out | existing `exchangeOutOneToMany` | not the refund route |
| Proportional join or exit | existing liquidity extension | not this family |

### Not adopted

- Replacing or extending `exchangeIn` / `exchangeOut` so the same selectors return a refund. Rejected because old callers would miss the extra returndata and current hook callers would inherit partial-keep behavior.
- Reading bundle-out as exact-out with both addresses and amounts as inputs. If a later decision wants that shape, it needs a different suffix, such as `previewExchangeBundleOutExact(address,address[],uint256[])` and an exchange that takes `maxAmountIn`. Its refund would be exact-out slack, which `exchangeOut` already performs unnamed. This response does not define that interface. `exchangeOutOneToMany` remains the share-to-two exact-out route.
- Reading bundle-out as amounts-only in `vaultTokens()` order. The owner did not say that, and a subset payout would then be a zero-filled full list with no token names.
- An exact-out `WithRefund` sibling. The used amount is already the `exchangeOut` return. A second number would blur slack and partial keep.
- `address(0)`, `payable`, or a native refund on these functions.
- Folding `depositPair`, `redeemPair`, `donate`, or `compound` into these signatures. Those are product functions. This redefinition does not delete them.
- An order-hash argument, a gas argument, a refund recipient, or a stability guarantee on `vaultTokens()`.
- Editing the full-spread PRD, the function-review file, or the stale selector comments. Not this pass.

### Recommended definitions

The names the owner gave are unchanged. Every parameter, return, error, path, and NatSpec rule the owner did not state is a recommendation. Selectors were computed in this pass with local `cast sig` of the canonical signatures. `IERC20` is `address` in those signatures. Recompute the hex if a signature changes. Do not copy the stale comment hex from the current files.

```solidity
// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.0;

/**
 * @title IStandardExchangeRefundErrors
 * @notice Errors shared by the refund-returning exchange siblings.
 * @dev Recommended file: lib/crane/contracts/interfaces/IStandardExchangeRefundErrors.sol
 *      Sits beside IStandardExchangeErrors. Does not extend it.
 *      No function selectors, so no useful ERC-165 id.
 */
interface IStandardExchangeRefundErrors {
    /// @dev Declared input is empty, or the vault token list and the amounts array are both empty.
    /// @custom:signature EmptyExchange()
    /// @custom:selector 0x376d67d2
    error EmptyExchange();

    /// @dev `token` is address(0), or this vault will not exchange it on this function.
    /// @custom:signature TokenNotExchangeable(address)
    /// @custom:selector 0xe1bd736f
    error TokenNotExchangeable(address token);
}
```

```solidity
// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeErrors} from "./IStandardExchangeErrors.sol";
import {IStandardExchangeRefundErrors} from "./IStandardExchangeRefundErrors.sol";

/**
 * @title IStandardExchangeInWithRefund
 * @notice Exact-in sibling of IStandardExchangeIn. Sits beside exchangeIn. Does not replace it.
 * @dev Recommended file: lib/crane/contracts/interfaces/IStandardExchangeInWithRefund.sol
 *      A vault that must fully consume does not implement this interface.
 * @custom:interfaceid 0x676ec907
 */
interface IStandardExchangeInWithRefund is IStandardExchangeErrors, IStandardExchangeRefundErrors {
    /// @custom:signature ExchangeInWithRefundNotAvailable()
    /// @custom:selector 0xc0108c6f
    error ExchangeInWithRefundNotAvailable();

    /**
     * @notice Quote an exact-in exchange that may keep less than `amountIn` of `tokenIn`.
     * @dev Does not transfer. `amountRefunded` is a quote of unkept declared `tokenIn`,
     *      assuming the declaration is available. It is not a balance read.
     *      Execution may differ. `minAmountOut` on the exchange is the binding output check.
     * @param tokenIn Token the caller would provide.
     * @param amountIn Declared amount of `tokenIn`.
     * @param tokenOut Token the caller would receive.
     * @return amountOut Quoted `tokenOut`.
     * @return amountRefunded Quoted unkept `tokenIn`. Zero means a full keep.
     * @custom:signature previewExchangeInWithRefund(address,uint256,address)
     * @custom:selector 0xc2bbe93f
     */
    function previewExchangeInWithRefund(IERC20 tokenIn, uint256 amountIn, IERC20 tokenOut)
        external
        view
        returns (uint256 amountOut, uint256 amountRefunded);

    /**
     * @notice Exact-in exchange. Unkept declared input is refunded as `tokenIn` to `msg.sender`.
     * @dev `amountIn == amountKept + amountRefunded`. Refunded wei are not kept and are not credited
     *      as a deposit. A fee, if any, is part of `amountKept`. Surplus above the declaration is
     *      not refunded and is not part of `amountRefunded`. `recipient` receives only `tokenOut`.
     *      A zero refund transfers nothing. Not payable.
     *      `address(0)` reverts `TokenNotExchangeable`. `tokenIn == tokenOut` reverts `InvalidRoute`.
     *      `amountIn == 0` reverts `EmptyExchange`. Unsupported route reverts `RouteNotSupported`
     *      or `ExchangeInWithRefundNotAvailable`. Output floor uses `MinAmountNotMet`.
     *      Deadline uses `DeadlineExceeded`. This definition does not change that comparison.
     *      Pull path pulls `amountIn`, then transfers `amountRefunded` of `tokenIn` to `msg.sender`.
     *      `pretransferred` is an integrating-contract flag only. Transfer and consume must be atomic.
     *      Staged use is at integrator risk. Callers with no bytecode revert `EOAPretransferNotAllowed()`,
     *      which the current In/Out comments name and `IStandardExchangeErrors` does not declare.
     *      Unrecorded balance across transactions may be consumed by the next contract caller.
     *      Booked holder backing is never pretransfer credit. The declaration is processed only when
     *      present unbooked input covers it. A short declaration reverts. This interface adds no
     *      shortfall error. Booked inventory does not fill a shortfall.
     * @param minAmountOut Minimum `tokenOut` the caller will accept. Binding even if the preview refund differs.
     * @param recipient Receives `tokenOut` only.
     * @param pretransferred Integrating-contract flag. See @dev.
     * @return amountOut `tokenOut` received by `recipient`.
     * @return amountRefunded Unkept declared `tokenIn` refunded to `msg.sender`.
     * @custom:signature exchangeInWithRefund(address,uint256,address,uint256,address,bool,uint256)
     * @custom:selector 0xa5d52038
     */
    function exchangeInWithRefund(
        IERC20 tokenIn,
        uint256 amountIn,
        IERC20 tokenOut,
        uint256 minAmountOut,
        address recipient,
        bool pretransferred,
        uint256 deadline
    ) external returns (uint256 amountOut, uint256 amountRefunded);
}
```

```solidity
// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.0;

import {IStandardExchangeErrors} from "@crane/contracts/interfaces/IStandardExchangeErrors.sol";
import {IStandardExchangeRefundErrors} from "@crane/contracts/interfaces/IStandardExchangeRefundErrors.sol";

/**
 * @title IStandardExchangeBundleInForSingleOut
 * @notice Many declared inputs, one output, same-token refunds of whatever was not kept.
 * @dev Recommended file: contracts/interfaces/IStandardExchangeBundleInForSingleOut.sol
 *      Sits beside IStandardExchangeInMulti. Does not replace exchangeInManyToOne.
 *      `amountsIn` and `amountsRefunded` use vaultTokens() order only. No tokenIn array.
 *      Does not inherit IBasicVault.
 * @custom:interfaceid 0x2576ed1a
 */
interface IStandardExchangeBundleInForSingleOut is IStandardExchangeErrors, IStandardExchangeRefundErrors {
    /// @custom:signature AmountsLengthMismatch(uint256,uint256)
    /// @custom:selector 0xe8833e3f
    error AmountsLengthMismatch(uint256 amountsLength, uint256 vaultTokensLength);

    /// @custom:signature ExchangeBundleInForSingleOutNotAvailable()
    /// @custom:selector 0x90864aaf
    error ExchangeBundleInForSingleOutNotAvailable();

    /**
     * @notice Quote a bundle exact-in exchange into one token.
     * @dev Does not transfer. `amountsRefunded[i]` is quoted unkept `vaultTokens()[i]`.
     *      Length equals `vaultTokens().length`. Execution may differ. A zero input quotes a zero refund.
     * @param amountsIn Declared inputs in `vaultTokens()` order. Length must match that list.
     * @param tokenOut The single token to receive. May be the share even if the share is not in `vaultTokens()`.
     * @return amountOut Quoted `tokenOut`.
     * @return amountsRefunded Quoted unkept inputs, `vaultTokens()` order.
     * @custom:signature previewExchangeBundleInForSingleOut(uint256[],address)
     * @custom:selector 0xc2fe8c7c
     */
    function previewExchangeBundleInForSingleOut(uint256[] calldata amountsIn, address tokenOut)
        external
        view
        returns (uint256 amountOut, uint256[] memory amountsRefunded);

    /**
     * @notice Exchange `amountsIn` for one token. Unkept declared input is refunded in that same token.
     * @dev Per index, `amountsIn[i] == amountKept[i] + amountsRefunded[i]`. Refunded wei of
     *      `vaultTokens()[i]` go to `msg.sender`, not to `recipient`, and are not credited as a deposit.
     *      Surplus above a slot's declaration is not refunded. A zero slot is not provided and does not
     *      require that token to be exchangeable. A nonzero `address(0)` slot, or any other token this
     *      vault will not exchange, reverts `TokenNotExchangeable`. A nonzero slot whose token equals
     *      `tokenOut` reverts `InvalidRoute`. Length mismatch reverts `AmountsLengthMismatch`.
     *      All-zero `amountsIn`, or an empty list paired with empty `vaultTokens()`, reverts `EmptyExchange`.
     *      Pull path pulls each declared slot, then transfers each nonzero refund to `msg.sender`.
     *      `pretransferred` uses the same integrating-contract rule as `exchangeInWithRefund`, applied
     *      independently to each nonzero slot. A short slot reverts. No new shortfall error.
     *      `recipient` receives only `tokenOut`. Not payable. No parallel token array and no PoolKey-order argument.
     * @param minAmountOut Binding floor for `tokenOut`.
     * @return amountOut `tokenOut` received by `recipient`.
     * @return amountsRefunded Actual unkept inputs, `vaultTokens()` order, length equal to that list.
     * @custom:signature exchangeBundleInForSingleOut(uint256[],address,uint256,address,bool,uint256)
     * @custom:selector 0xe7886166
     */
    function exchangeBundleInForSingleOut(
        uint256[] calldata amountsIn,
        address tokenOut,
        uint256 minAmountOut,
        address recipient,
        bool pretransferred,
        uint256 deadline
    ) external returns (uint256 amountOut, uint256[] memory amountsRefunded);
}
```

```solidity
// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.0;

import {IStandardExchangeErrors} from "@crane/contracts/interfaces/IStandardExchangeErrors.sol";
import {IStandardExchangeRefundErrors} from "@crane/contracts/interfaces/IStandardExchangeRefundErrors.sol";

/**
 * @title IStandardExchangeBundleOut
 * @notice One declared pay token, a caller-named set of output tokens, same-token refund of unkept pay.
 * @dev Recommended file: contracts/interfaces/IStandardExchangeBundleOut.sol
 *      Sits beside exchangeOut and exchangeOutOneToMany. Does not replace either.
 *      Exact-in on `tokenIn`. Not exact-out. `tokensOut` are addresses, not amounts.
 *      Their order is the caller's order, not vaultTokens() order.
 * @custom:interfaceid 0xb40c1ba3
 */
interface IStandardExchangeBundleOut is IStandardExchangeErrors, IStandardExchangeRefundErrors {
    /// @custom:signature TokenAmountsLengthMismatch(uint256,uint256)
    /// @custom:selector 0x6920d3fd
    error TokenAmountsLengthMismatch(uint256 tokensLength, uint256 amountsLength);

    /// @custom:signature DuplicateOutput(address)
    /// @custom:selector 0x62577ce9
    error DuplicateOutput(address token);

    /// @dev `index` is the index in the caller's `tokensOut`, not a vaultTokens() index.
    /// @custom:signature MinAmountNotMetAt(uint256,uint256,uint256)
    /// @custom:selector 0x9c0f5295
    error MinAmountNotMetAt(uint256 index, uint256 minAmount, uint256 actualAmount);

    /// @custom:signature ExchangeBundleOutNotAvailable()
    /// @custom:selector 0x71bc7174
    error ExchangeBundleOutNotAvailable();

    /**
     * @notice Quote an exact-in payment of `amountIn` of `tokenIn` against the named output tokens.
     * @dev Does not transfer. `amountsOut` aligns to `tokensOut`. `amountRefunded` is quoted unkept
     *      `tokenIn`. Execution may differ. Floors are not inputs to the preview.
     * @param tokenIn Token the caller would pay. May be the share.
     * @param amountIn Declared amount of `tokenIn`.
     * @param tokensOut Tokens the caller expects to receive. Addresses only. Caller order.
     * @return amountsOut Quoted receipts, aligned to `tokensOut`.
     * @return amountRefunded Quoted unkept `tokenIn`.
     * @custom:signature previewExchangeBundleOut(address,uint256,address[])
     * @custom:selector 0xa5952fc2
     */
    function previewExchangeBundleOut(address tokenIn, uint256 amountIn, address[] calldata tokensOut)
        external
        view
        returns (uint256[] memory amountsOut, uint256 amountRefunded);

    /**
     * @notice Pay a declared amount of one token and receive the named tokens. Refund unkept pay to `msg.sender`.
     * @dev `amountIn == amountKept + amountRefunded` in `tokenIn`. The vault pays only `tokensOut`,
     *      in caller order, to `recipient`. It does not pay a surprise token. `amountsOut` aligns to
     *      `tokensOut`. A floor may be zero. Length mismatch reverts `TokenAmountsLengthMismatch`.
     *      Empty `tokensOut` or `amountIn == 0` reverts `EmptyExchange`. A duplicate reverts
     *      `DuplicateOutput`. `tokenIn` appearing in `tokensOut` reverts `InvalidRoute`.
     *      `address(0)` reverts `TokenNotExchangeable`. A set this vault cannot pay reverts
     *      `RouteNotSupported` or `ExchangeBundleOutNotAvailable`. A missed floor reverts
     *      `MinAmountNotMetAt`. There is no interface-level cap of two outputs.
     *      Pull and pretransfer follow `exchangeInWithRefund`: pull the declaration, then transfer
     *      the same-token refund to `msg.sender`. Surplus above `amountIn` is not refunded.
     *      Not payable. Not an exact-out function. `exchangeOutOneToMany` remains the share-to-two
     *      exact-out route.
     * @param minAmountsOut Floors aligned to `tokensOut`. Not optional by omission.
     * @return amountsOut Actual receipts, aligned to `tokensOut`.
     * @return amountRefunded Unkept declared `tokenIn` refunded to `msg.sender`.
     * @custom:signature exchangeBundleOut(address,uint256,address[],uint256[],address,bool,uint256)
     * @custom:selector 0x11993461
     */
    function exchangeBundleOut(
        address tokenIn,
        uint256 amountIn,
        address[] calldata tokensOut,
        uint256[] calldata minAmountsOut,
        address recipient,
        bool pretransferred,
        uint256 deadline
    ) external returns (uint256[] memory amountsOut, uint256 amountRefunded);
}
```

`IStandardExchange` stays `IStandardExchangeIn` plus `IStandardExchangeOut`. No new inheritance. No new functions.

## Limits

- Runtime or extraction proof: none. No implementation was executed. `cast sig` is a local hash of the signatures as written, not proof of deployed selectors. The openchain lookup is not repo bytecode. Live files can change after this read. This was not an atomic snapshot.
- Not examined: implementations of these interfaces, hook source, the stage-one PairToken PRD inherited by the full-spread note, the declaration site of `EOAPretransferNotAllowed`, deployed bytecode, and peer responses. The shortfall revert name used by current `exchangeIn` was not in the admitted error file, so no new shortfall error was invented.
- Selector comments: `exchangeIn` `0x05562cc8`, `exchangeOut` `0x612d4427`, and `vaultTokens()` `0x9d63848a` do not match `cast sig` of the functions as written. The interface-id comments match those documented selectors, not the cast selectors. Do not treat the comments as the ABI. This response does not edit them.
- Fee-on-transfer tokens, rebasing tokens, and a `vaultTokens()` list that changes between preview and exchange are unspecified. The refund identity is declared accounting, not a raw balance-delta identity.
- Optional full-spread FS-X04 and `J_i` are product context. This recommendation does not override them and does not authorize a hook change. Current hooks will not call the new selectors.
- Public query: `cast 4byte` to `https://openchain.xyz` for the six selectors named in Evidence. Private source excerpts were not sent. No other public query was used.
- Assignment boundary: this response does not authorize implementation, tests, installs, Git, or edits outside the owned path.
- Permission boundary: inherited parent permissions were accepted for the session. This file does not prove confinement.
