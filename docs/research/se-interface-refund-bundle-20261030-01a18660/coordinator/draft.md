# Coordinator draft

## Draft identity

- Draft ID: se-interface-refund-bundle-20261030-01a18660-r1
- Path: docs/research/se-interface-refund-bundle-20261030-01a18660/coordinator/draft.md
- Run ID: se-interface-refund-bundle-20261030-01a18660
- Status: pending advisory review. This file is not the final.
- Fingerprint: not computed in this file. Recorded in RUN.md only if an authorized hash is taken before review.
- Sources: members/astra/response.md, members/grok/response.md, members/minimax/response.md, members/kimi/response.md. All four settled before this draft.

## Participation

- Council kind: full
- Requested members: astra, grok, minimax, kimi
- Substantive initial responses: astra, grok, minimax, kimi
- Missing initial responses: none
- Result label: full
- Coordinator mode: invoking-agent
- Coordinator is an independent vote: no

## Question

Should the Standard Exchange interface set be redefined so one previewExchange/exchange family covers swaps, deposits, and withdrawals, including a same-token refund when an input cannot be fully consumed, and what exact interface definitions does the council recommend?

## Proposed text

Yes. Redefine the integration surface by addition. Do not change the current `exchangeIn` or `exchangeOut` functions. A return-type change would not change their selectors. Solidity selectors exclude return types. It would still break callers that decode the old returndata, and current hooks call the old functions. Kimi recommended that break. This draft does not adopt it.

Swaps, deposits, and withdrawals stay one family. The route is the token identity. An underlying paid for another underlying is a swap. An underlying, or a bundle of underlyings, paid for the share is a deposit. The share paid for an underlying, or for a named set of underlyings, is a withdrawal. A vault may reject a route. It does not need a separate deposit or withdraw verb for the routes these functions can express.

`IStandardExchangeMultiAssetLiquidity` stays beside this family. Do not merge its join and exit selectors into these interfaces. `IBasicVault.vaultTokens()` stays the order source for bundle input. It is not given a refund return.

The owner named `IStandardExchangeBundleInForSingleOut` and `IStandardExchangeBundleOut`. Those names are kept. Every parameter the owner did not name is a coordinator choice, not an owner decision.

Coordinator choices on the ambiguities:

- "Array of tokens they expect to receive" means output addresses, in the caller's order. Amounts of those tokens are returns, not inputs. This is exact-in. MiniMax and Kimi read the same sentence as exact-out, with amounts as inputs. That reading is not adopted here. `exchangeOutOneToMany` remains the current exact-out many route.
- The refund return is on the new functions only. It is not added to the current functions.
- `amountsIn` follows `vaultTokens()` order. The caller does not pass a parallel input-token array.
- The external face is ERC-20. `address(0)` is not a native refund on these functions. A native underlying uses its wrapped face, as the current multi comments already say.
- A preview returns the refund quote and does not transfer.
- Output goes to `recipient`. The same-token refund goes to `msg.sender`.
- `pretransferred` is included, with `recipient`, floors, and `deadline`, in the same order as `exchangeIn`. The owner named only the pretransfer option. The other arguments are a coordinator choice so the new calls are usable beside the current ones.

Refund identity, for the new exact-in functions: declared input equals amount kept plus amount refunded, per token. The refund is unkept declared input of the token the user provided. Surplus above the declaration is not refunded. A preview's refund is a quote, not a balance read.

```solidity
// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeErrors} from "@crane/contracts/interfaces/IStandardExchangeErrors.sol";

interface IStandardExchangeRefundErrors {
    error EmptyExchange();
    error TokenNotExchangeable(address token);
}

interface IStandardExchangeInWithRefund is IStandardExchangeErrors, IStandardExchangeRefundErrors {
    error ExchangeInWithRefundNotAvailable();

    function previewExchangeInWithRefund(IERC20 tokenIn, uint256 amountIn, IERC20 tokenOut)
        external
        view
        returns (uint256 amountOut, uint256 amountRefunded);

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

interface IStandardExchangeBundleInForSingleOut is IStandardExchangeErrors, IStandardExchangeRefundErrors {
    error AmountsLengthMismatch(uint256 amountsLength, uint256 vaultTokensLength);
    error ExchangeBundleInForSingleOutNotAvailable();

    function previewExchangeBundleInForSingleOut(uint256[] calldata amountsIn, address tokenOut)
        external
        view
        returns (uint256 amountOut, uint256[] memory amountsRefunded);

    function exchangeBundleInForSingleOut(
        uint256[] calldata amountsIn,
        address tokenOut,
        uint256 minAmountOut,
        address recipient,
        bool pretransferred,
        uint256 deadline
    ) external returns (uint256 amountOut, uint256[] memory amountsRefunded);
}

interface IStandardExchangeBundleOut is IStandardExchangeErrors, IStandardExchangeRefundErrors {
    error TokenAmountsLengthMismatch(uint256 tokensLength, uint256 amountsLength);
    error DuplicateOutput(address token);
    error MinAmountNotMetAt(uint256 index, uint256 minAmount, uint256 actualAmount);
    error ExchangeBundleOutNotAvailable();

    function previewExchangeBundleOut(address tokenIn, uint256 amountIn, address[] calldata tokensOut)
        external
        view
        returns (uint256[] memory amountsOut, uint256 amountRefunded);

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

`amountsIn` and `amountsRefunded` use `vaultTokens()` order. `amountsOut` and `minAmountsOut` use the caller's `tokensOut` order. These functions are not payable. `tokenIn == tokenOut` is not a route.

Current functions stay as they are:

| Current function | This draft |
| --- | --- |
| `previewExchangeIn`, `exchangeIn` | Unchanged. Not replaced. |
| `previewExchangeOut`, `exchangeOut` | Unchanged. Not replaced. |
| `previewExchangeInManyToOne`, `exchangeInManyToOne` | Unchanged. Not replaced. |
| `previewExchangeOutOneToMany`, `exchangeOutOneToMany` | Unchanged. Not replaced. |
| `IStandardExchangeMultiAssetLiquidity` | Unchanged. Not merged. |
| `IStandardExchange` | Unchanged. It does not inherit the new interfaces. |
| `vaultTokens` | Unchanged. |

## Preserved disagreements

| Topic | Positions | Not resolved in this draft |
| --- | --- | --- |
| Change current return ABI | Kimi: replace `exchangeIn` and `exchangeOut` returns in place. Astra, Grok, MiniMax: sit beside. | Adopted beside. Kimi's replacement is not adopted. |
| Selector versus ABI | MiniMax said a return change is a selector change. Astra and Grok said selectors exclude return types. | The selector claim is rejected. The ABI break is real. That is why the current functions are not edited. |
| Exact-out named refund | Astra: `IStandardExchangeOutWithRefund`, fully funded `maxAmountIn`, returns used and refunded. MiniMax: `exchangeOutWithRefund` on the refundable interface. Grok: do not add it. The used amount is already `exchangeOut`'s return. | Not adopted. Exact-out slack stays the current side effect. |
| Bundle-out shape | Astra and Grok: exact-in, output addresses in, amounts out, refund of unkept pay. MiniMax and Kimi: exact-out, output addresses and amounts in, refund of unused maximum. Astra also defined a separate `IStandardExchangeBundleOutExactOut`. | Exact-in adopted for the owner-named `exchangeBundleOut`. Exact-out bundle is not given that name. |
| Aggregate | MiniMax: new `IStandardExchangeFull`. Kimi: extend `IStandardExchange`. Astra: scalar `IStandardExchangeWithRefund` only, bundles advertised separately. Grok: no new aggregate. | No new aggregate in the proposed text. A product implements the leaves it supports. |
| Error set | Astra adds `EOAPretransferNotAllowed` and several bundle errors to the new error interface. Grok leaves `EOAPretransferNotAllowed` where the current comments name it and does not redeclare it. | The proposed text uses the smaller error set. It does not invent a new shortfall error. |
| `IERC20` versus `address` on bundle outputs | Astra uses `IERC20 tokenOut` on bundle-in. Grok and the proposed text use `address` on the bundle arrays and bundle-in output. | `address` adopted for the bundle token arguments so a wrapped native face and a share can be passed without an extra cast rule. This is a coordinator choice. |

## Evidence gaps

- No implementation, hook caller, or gas measurement was run. The claim that a same-token remainder is always feasible inside the gas limit is not established.
- `EOAPretransferNotAllowed` is named by current interface comments and was not declared in the admitted `IStandardExchangeErrors` file. This draft does not move that error.
- Selector comments on the current files were reported stale by Grok and MiniMax. This draft does not copy those hex values and does not edit the files.
- Optional full-spread notes explain why the question arose. They are not interface law. This draft does not amend that PRD.

## Coverage adopted from responses

| Target | Status | Adopted from | Conflict or gap |
| --- | --- | --- | --- |
| Current In, Out, multi, liquidity, and basic vault interfaces | Examined by all four | All four | Kimi would edit In and Out. Not adopted. |
| Refund of the user-provided token | Examined | Astra, Grok, MiniMax, Kimi | Same identity: unkept declared input. Placement differs. |
| `IStandardExchangeBundleInForSingleOut` | Examined | All four | Signature family agrees: `amountsIn` in `vaultTokens()` order, one output, pretransfer, refund vector. |
| `IStandardExchangeBundleOut` | Examined | All four | Exact-in versus exact-out disagreement, preserved above. |
| Native ETH | Examined as comments on the multi interfaces | Grok, Astra, MiniMax | Wrapped face adopted. No payable functions in the proposed text. |

## Limits

- Static reading of the admitted interfaces and the four originals. No runtime proof.
- This draft does not claim permission confinement.
- Original response files were read and are preserved.
- No project code, configuration, or Git action is authorized by this draft.
- This draft is not member-approved text. Advisory feedback has not been read.
