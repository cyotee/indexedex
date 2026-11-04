# Standard Exchange refund and bundle interfaces

Revision **se-interface-refund-bundle-20261030-01a18660-final**, with an owner lock recorded after the council. The council text below is preserved. The owner lock overrides it where they conflict. This is not an implementation, and it does not change the full-spread PRD.

## Owner lock

The owner accepted the recommended definition, with one change: drop `WithRefund` from the names, and put the refund return on the existing `previewExchangeIn` and `exchangeIn`. That is an in-place return change. It is not a new sibling. Every other Standard Exchange vault must be updated to the new return ABI. That migration is acknowledged and not started here.

The parameter lists do not change, so the selectors do not change. `previewExchangeIn(address,uint256,address)` remains `0x89d61912`. `exchangeIn(address,uint256,address,uint256,address,bool,uint256)` remains `0xd02d3063`. The ERC-165 id of `IStandardExchangeIn` also stays, because it is the XOR of those selectors. Callers and implementations must still be updated, because the return data is wider. ERC-165 cannot tell the old return width from the new one.

`IStandardExchangeInWithRefund`, `previewExchangeInWithRefund`, `exchangeInWithRefund`, and `ExchangeInWithRefundNotAvailable` are not part of the accepted definition. The existing `ExchangeInNotAvailable` remains the unavailable error.

The accepted scalar functions are:

```solidity
function previewExchangeIn(IERC20 tokenIn, uint256 amountIn, IERC20 tokenOut)
    external
    view
    returns (uint256 amountOut, uint256 amountRefunded);

function exchangeIn(
    IERC20 tokenIn,
    uint256 amountIn,
    IERC20 tokenOut,
    uint256 minAmountOut,
    address recipient,
    bool pretransferred,
    uint256 deadline
) external returns (uint256 amountOut, uint256 amountRefunded);
```

The bundle interfaces below are accepted as written. `exchangeOut` is not given a refund return.

## Question

Should the Standard Exchange interface set be redefined so one `previewExchange` / `exchange` family covers swaps, deposits, and withdrawals, including a same-token refund when a declared input cannot be fully consumed, and what interfaces should it expose?

## Participation

| Member | Requested route | Original | Advisory |
| --- | --- | --- | --- |
| Astra | `chatgpt-subscription/gpt-6-astra:high` | `st_01a18fa1` | SUPPORT WITH CORRECTIONS |
| Grok | `xai/grok-4.7:xhigh` | `st_01a18fa2` | SUPPORT WITH CORRECTIONS |
| MiniMax | `minimax/MiniMax-M3` | `st_01a18fa3` | SUPPORT WITH CORRECTIONS |
| Kimi | `kimi-coding/k3.1-pro:high` | `st_01a18fa4` | REQUEST CHANGES |

Coordinator mode was invoking-agent. The coordinator is not a fifth vote. Kimi's request to change the current return ABI and to add an exact-out refund surface was not adopted.

## Answer

Yes. Redefine the integration surface by addition. Do not edit `exchangeIn` or `exchangeOut`.

A return-type change does not change a Solidity selector. It does change the ABI return contract. A new caller that expects a refund word cannot safely call an old implementation that returns only the original value. Some old callers can still read an unchanged first word from a longer result, so the problem is not that every existing decoder fails. New names make the refund capability explicit. ERC-165 cannot tell the two return widths apart if they share a selector.

Swaps, deposits, and withdrawals use the same family. The route is the token identity:

- Underlying for another underlying is a swap.
- Underlying, or a bundle of underlyings, for the share is a deposit.
- Share for an underlying, or for a named set of underlyings, is a withdrawal.

The share may be `tokenIn` or `tokenOut` even when it is absent from `vaultTokens()`. A vault may reject a route. A vault that must fully consume does not implement `IStandardExchangeInWithRefund`. A vault that implements both the old and new exact-in functions must not partial-fill the old one. `exchangeInManyToOne` stays full-keep or revert.

`IStandardExchangeMultiAssetLiquidity` stays beside this family. Its `usedAmounts` is not a refund. `IStandardExchange` is not extended. No new aggregate is added. An aggregate that only inherits other interfaces has no usable ERC-165 id of its own and must not be advertised as one.

## Refund rule

For each declared input on the new exact-in functions, declared amount equals amount consumed plus amount refunded. Consumed includes an input-denominated fee actually charged. Idle unconsumed input is not consumption. There is no third bucket inside the declaration.

The pull path pulls the declared amount from `msg.sender`, then transfers the unkept amount of that same token to `msg.sender`. The pretransfer path transfers that unkept amount back to `msg.sender`. A zero refund transfers nothing. Pulling only the consumed amount is not the rule. Refunded wei are not credited as a deposit. Output goes to `recipient`. Failure to deliver a required output or refund reverts the whole call.

`pretransferred` has the same meaning as on current `exchangeIn`. It is an integrating-contract flag. Transfer and consume must be atomic. A caller with no bytecode reverts `EOAPretransferNotAllowed()`, which the current comments name and this recommendation does not redeclare. Booked holder backing is not pretransfer credit. The declaration is processed only when present unbooked input covers it. A short declaration reverts. Surplus above the declaration is not consumed and not refunded. Its existence alone does not revert. Booked inventory does not fill a shortfall.

A preview returns a refund quote. It does not transfer, and it does not read a balance. It assumes the declaration is available. Execution may refund a different amount. `minAmountOut` and `minAmountsOut` bind. Bit-exact preview equality is not required.

These functions are not payable. The caller passes the wrapped ERC-20 face. They do not accept `address(0)` and do not wrap it. `address(0)` reverts `TokenNotExchangeable`. Raw ETH stays on product functions outside this redefinition.

## Recommended interfaces

Selectors below were computed with local `cast sig` of these signatures. `IERC20` is `address` in that hash. Interface ids are the XOR of the two function selectors in each interface, excluding errors. Recheck them with `type(I).interfaceId` before any ERC-165 registration. Do not copy the stale selector comments on the current files.

```solidity
// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeErrors} from "@crane/contracts/interfaces/IStandardExchangeErrors.sol";

/// @notice Errors for the refund-returning siblings. Sits beside IStandardExchangeErrors. Does not extend it.
interface IStandardExchangeRefundErrors {
    /// @notice Zero scalar input, all-zero bundle input, empty output list, or empty amounts with empty vaultTokens().
    error EmptyExchange();

    /// @notice address(0), or a token this vault will not exchange on this call.
    error TokenNotExchangeable(address token);
}

/// @notice Existing exact-in interface. Owner lock: same selectors, wider return.
/// @dev The interface id does not change, because the selectors do not change. Do not advertise 0x676ec907.
interface IStandardExchangeIn is IStandardExchangeErrors, IStandardExchangeRefundErrors {
    error ExchangeInNotAvailable();

    /// @notice Quote an exact-in exchange that may keep less than amountIn of tokenIn.
    /// @return amountOut Quoted tokenOut.
    /// @return amountRefunded Quoted unkept tokenIn. Not a balance read. Execution may differ.
    /// @custom:signature previewExchangeIn(address,uint256,address)
    /// @custom:selector 0x89d61912
    function previewExchangeIn(IERC20 tokenIn, uint256 amountIn, IERC20 tokenOut)
        external
        view
        returns (uint256 amountOut, uint256 amountRefunded);

    /// @notice Keep what the route can consume. Refund unkept declared tokenIn to msg.sender.
    /// @dev amountIn equals consumed plus amountRefunded. recipient receives only tokenOut.
    ///      tokenIn == tokenOut reverts InvalidRoute. amountIn == 0 reverts EmptyExchange.
    ///      address(0) reverts TokenNotExchangeable. A zero recipient, or the vault as recipient, reverts.
    ///      Owner lock: this replaces the current one-word return. The selector does not change.
    /// @custom:signature exchangeIn(address,uint256,address,uint256,address,bool,uint256)
    /// @custom:selector 0xd02d3063
    function exchangeIn(
        IERC20 tokenIn,
        uint256 amountIn,
        IERC20 tokenOut,
        uint256 minAmountOut,
        address recipient,
        bool pretransferred,
        uint256 deadline
    ) external returns (uint256 amountOut, uint256 amountRefunded);
}

/// @notice Many declared inputs, one output. Sits beside IStandardExchangeInMulti. Does not replace it.
/// @custom:interfaceid 0x2576ed1a
interface IStandardExchangeBundleInForSingleOut is IStandardExchangeErrors, IStandardExchangeRefundErrors {
    error AmountsLengthMismatch(uint256 amountsLength, uint256 vaultTokensLength);
    error ExchangeBundleInForSingleOutNotAvailable();

    /// @notice amountsIn and amountsRefunded use vaultTokens() order. No parallel token array.
    /// @custom:signature previewExchangeBundleInForSingleOut(uint256[],address)
    /// @custom:selector 0xc2fe8c7c
    function previewExchangeBundleInForSingleOut(uint256[] calldata amountsIn, address tokenOut)
        external
        view
        returns (uint256 amountOut, uint256[] memory amountsRefunded);

    /// @notice Per index, amountsIn[i] equals consumed plus amountsRefunded[i].
    /// @dev Length must equal vaultTokens().length. A zero slot is not provided and does not require
    ///      that token to be exchangeable. A nonzero slot whose token equals tokenOut reverts InvalidRoute.
    ///      A vault that exposes this positional interface must keep vaultTokens() membership and order stable.
    ///      That stability is a conformance requirement, not an existing Basic Vault guarantee.
    /// @custom:signature exchangeBundleInForSingleOut(uint256[],address,uint256,address,bool,uint256)
    /// @custom:selector 0xe7886166
    function exchangeBundleInForSingleOut(
        uint256[] calldata amountsIn,
        address tokenOut,
        uint256 minAmountOut,
        address recipient,
        bool pretransferred,
        uint256 deadline
    ) external returns (uint256 amountOut, uint256[] memory amountsRefunded);
}

/// @notice One declared pay token, caller-named output addresses, exact-in. Sits beside exchangeOut and exchangeOutOneToMany.
/// @custom:interfaceid 0xb40c1ba3
interface IStandardExchangeBundleOut is IStandardExchangeErrors, IStandardExchangeRefundErrors {
    error TokenAmountsLengthMismatch(uint256 tokensLength, uint256 amountsLength);
    error DuplicateOutput(address token);
    /// @notice index is the caller's tokensOut index, not a vaultTokens() index.
    error MinAmountNotMetAt(uint256 index, uint256 minAmount, uint256 actualAmount);
    error ExchangeBundleOutNotAvailable();

    /// @notice tokensOut are addresses in the caller's order. amountsOut are quoted receipts, not inputs.
    /// @custom:signature previewExchangeBundleOut(address,uint256,address[])
    /// @custom:selector 0xa5952fc2
    function previewExchangeBundleOut(address tokenIn, uint256 amountIn, address[] calldata tokensOut)
        external
        view
        returns (uint256[] memory amountsOut, uint256 amountRefunded);

    /// @notice minAmountsOut are floors, aligned to tokensOut, and are inputs only on this function.
    /// @dev This is exact-in. Exact output amounts are not inputs. The vault pays only tokensOut, in caller
    ///      order, and does not pay a surprise token. A zero floor is allowed. An omitted floors array is not
    ///      "no floors." tokenIn appearing in tokensOut reverts InvalidRoute. tokensOut is not fixed at two.
    ///      A subset is allowed only when the route can settle it without an unrequested output.
    /// @custom:signature exchangeBundleOut(address,uint256,address[],uint256[],address,bool,uint256)
    /// @custom:selector 0x11993461
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

## What stays unchanged

| Current surface | Final |
| --- | --- |
| `previewExchangeIn`, `exchangeIn` | Owner lock: same parameters and selectors. Return ABI becomes `(amountOut, amountRefunded)`. All other vaults must be updated. Not started here. |
| `previewExchangeOut`, `exchangeOut` | Unchanged. Not replaced. Not extended. |
| `previewExchangeInManyToOne`, `exchangeInManyToOne` | Unchanged. Not replaced. |
| `previewExchangeOutOneToMany`, `exchangeOutOneToMany` | Unchanged. The current exact-out many route. |
| `IStandardExchangeMultiAssetLiquidity` | Unchanged. Not merged. |
| `IStandardExchange` | Unchanged. |
| `vaultTokens` | Unchanged. Bundle-in order reads it. |

## Dissent not adopted

- Kimi would change the current `exchangeIn` and `exchangeOut` return ABI in place, and would make the owner-named `exchangeBundleOut` exact-out. Not adopted.
- Astra and MiniMax would add a named exact-out refund sibling. Not adopted. Exact-out slack stays the current side effect to `msg.sender`. The used amount remains `exchangeOut`'s return.
- MiniMax and Kimi would give the name `exchangeBundleOut` to an exact-out function that takes output amounts as inputs. Not adopted. A later exact-out bundle needs a different suffix. This report does not define one.
- MiniMax and Kimi wanted a new or extended aggregate. Not adopted, for the ERC-165 reason above.

## Limits

No implementation, test, hook inspection, or gas measurement was run. This report does not prove that every vault can produce a same-token remainder inside a gas limit. It does not amend the full-spread PRD. It does not authorize code changes.
