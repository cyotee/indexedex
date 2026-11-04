# Kimi member response

## Identity

- Council member: Kimi
- Requested Native selection: `kimi-coding/k3.1-pro:high`, global route
- Actual Native identity metadata: not exposed
- Profile: research

## Question and targets

Should the Standard Exchange interface set be redefined so the `previewExchange` / `exchange` family covers swaps, deposits, and withdrawals, including same-token refunds of unconsumed input, and what exact Solidity interface definitions should it have?

Required targets read from the repository:

- `lib/crane/contracts/interfaces/IStandardExchangeIn.sol`
- `lib/crane/contracts/interfaces/IStandardExchangeOut.sol`
- `lib/crane/contracts/interfaces/IStandardExchangeErrors.sol`
- `contracts/interfaces/IStandardExchange.sol`
- `contracts/interfaces/IStandardExchangeInMulti.sol`
- `contracts/interfaces/IStandardExchangeOutMulti.sol`
- `contracts/interfaces/IStandardExchangeMultiAssetLiquidity.sol`
- `contracts/vaults/basic/IBasicVault.sol`

The optional full-spread function review and PRD were also read as context, not as interface law.

## Evidence

1. `IStandardExchangeIn.previewExchangeIn` and `exchangeIn` currently return only `amountOut`. The exact-input pretransfer contract processes the declared `amountIn`, does not refund tokens above that declaration, and warns that transfer-and-consume must be atomic.
2. `IStandardExchangeOut.previewExchangeOut` returns the required `amountIn`; `exchangeOut` returns actual `amountIn`. Its exact-output pretransfer path already refunds unused declared input to `msg.sender`, capped by `maxAmountIn`, while the false-flag path pulls only the amount used.
3. `IStandardExchangeInMulti` already expresses many-to-one exchange with explicit token and amount arrays. Its pretransfer text likewise excludes tokens above the declaration from refunds. `IStandardExchangeOutMulti` already expresses one-to-many exact-output exchange with both `tokensOut` and `amountsOut`.
4. Both current multi interfaces use the vault's declared token order and document WETH as the ERC-20 face of a native currency for V4. `IBasicVault.vaultTokens()` supplies the canonical address ordering needed by an implicit-order bundle input.
5. `IStandardExchangeMultiAssetLiquidity` explicitly says canonical In/Out are swap-only and must not have liquidity selectors merged into them. It also contains specialized proportional, unbalanced, and single-asset join/exit operations that are not interchangeable with the proposed bundle exact-in and exact-out routes.
6. The full-spread context shows why unconsumed input and preview disclosure matter, but its product-specific remainder accounting is not a general Standard Exchange interface rule.
7. Solidity function selectors exclude return types. Adding a refund return to existing `exchangeIn` or `exchangeOut` parameters would preserve their selectors, but would still be a breaking interface/ABI revision for implementers and callers. Adding `maxAmountIn` to `previewExchangeOut` would change that preview's selector.

## Assumptions

- This response recommends a coordinated next interface revision; it does not treat compatibility shims as part of the final target surface.
- A vault share can be an `IERC20` input or output, allowing deposits and withdrawals to use the same exchange semantics as swaps.
- `vaultTokens()` is available through the host vault and is the authoritative underlying-token order.
- No implementation, consumer migration, gas measurement, or protocol-specific feasibility result is assumed.

## Coverage

The conclusions address all requested decisions:

- exact Solidity for canonical In/Out and both owner-named bundle interfaces;
- replacement, extension, or beside-current disposition for each function;
- addresses and amounts for bundle outputs;
- refund semantics for execution and non-transferring previews;
- overlap with both current Multi interfaces;
- continued separation of `IStandardExchangeMultiAssetLiquidity`;
- native-currency representation;
- `vaultTokens()` ordering;
- pretransfer and refund-recipient behavior; and
- selector and compatibility consequences.

## Conclusions

### 1. Recommended model

Yes: redefine the Standard Exchange set around one route model. `tokenIn` / `tokenOut` identity distinguishes a swap from a deposit or withdrawal instead of requiring protocol-specific method names. Single-token entry and exit use In/Out; bundle entry and exit use the two new bundle interfaces. Specialized proportional and unbalanced liquidity operations remain separate.

Every route should report unconsumed declared input in the same token face supplied by the caller. For exact-input routes, this changes the meaning from strict full consumption to declared-input-with-refund. For exact-output routes, it names the already relevant difference between maximum and actual input.

The following are recommendations resolving owner ambiguities, not statements of an owner decision:

1. **Refund accounting.** For single exact-input, `amountIn == consumedAmountIn + amountInRefund`. For bundle exact-input, the same invariant holds independently at every index. For exact-output, `maxAmountIn == amountIn + amountInRefund`. `amountInRefund` always means unconsumed declared input, whether execution returns it or simply never pulls it.
2. **Recipients.** Output tokens go to `recipient`; refunds go to the funding caller, `msg.sender`. This matches current exact-output pretransfer behavior and avoids sending a refund to an output recipient that did not fund the call.
3. **Pretransfer.** Preserve atomic transfer-and-consume, unbooked-balance, and declared-amount rules. Only declared input participates in refund accounting; unrelated or excess balance above the declaration is neither consumed nor swept into a refund. With `pretransferred == false`, an implementation may pull only consumed input, so the refund return can denote input that remained with the caller rather than a literal transfer.
4. **Previews.** A preview transfers nothing and returns the refund expected from the same route and state. Exact-output previews must accept `maxAmountIn` so they can return `maxAmountIn - quotedAmountIn` without inventing a maximum.
5. **Bundle output shape.** `tokensOut` and `amountsOut` are both required. Addresses alone cannot express an exact-output exchange. Equal-length arrays specify each exact output; execution pays all of them or reverts.
6. **Ordering.** Bundle-in `amountsIn` must have exactly `vaultTokens().length` entries and use that order, with zero allowed for an unused input. Bundle-out `tokensOut` is a nonempty, unique subset in relative `vaultTokens()` order, with matching `amountsOut`; this preserves the owner's explicit output-token choice while removing arbitrary orderings.
7. **Native currency.** Use ERC-20 faces throughout these interfaces, including the wrapper address exposed by `vaultTokens()` for native-backed pools. Do not use `address(0)` as a second native sentinel and do not make these methods payable. Raw ETH wrapping and unwrapping belongs at an adapter boundary. A refund therefore uses exactly the same ERC-20 face as the corresponding input.
8. **Migration.** Replace the overlapping current routes in the coordinated target revision rather than maintaining two permanently canonical refund policies. Legacy Multi functions may sit beside the new functions temporarily for migration, but are not part of the recommended final aggregate.

### 2. Canonical exact-input interface

**Disposition:** `previewExchangeIn` replaces the current preview, and `exchangeIn` replaces the current execution function. Their parameters and selectors remain unchanged; their return ABI changes. This is a replacement, not an overload or a compatible extension.

```solidity
// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeErrors} from "./IStandardExchangeErrors.sol";

interface IStandardExchangeIn is IStandardExchangeErrors {
    struct InArgs {
        IERC20 tokenIn;
        uint256 amountIn;
        IERC20 tokenOut;
        uint256 minAmountOut;
        address recipient;
        bool pretransferred;
        uint256 deadline;
    }

    error ExchangeInNotAvailable();

    function previewExchangeIn(
        IERC20 tokenIn,
        uint256 amountIn,
        IERC20 tokenOut
    ) external view returns (uint256 amountOut, uint256 amountInRefund);

    function exchangeIn(
        IERC20 tokenIn,
        uint256 amountIn,
        IERC20 tokenOut,
        uint256 minAmountOut,
        address recipient,
        bool pretransferred,
        uint256 deadline
    ) external returns (uint256 amountOut, uint256 amountInRefund);
}
```

### 3. Canonical exact-output interface

**Disposition:** `previewExchangeOut` replaces the current preview and has a new selector because it adds `maxAmountIn`. `exchangeOut` replaces the current execution function with unchanged parameters and selector but changed return ABI. These are replacements, not overloads in the target revision.

```solidity
// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeErrors} from "./IStandardExchangeErrors.sol";

interface IStandardExchangeOut is IStandardExchangeErrors {
    struct OutArgs {
        IERC20 tokenIn;
        uint256 maxAmountIn;
        IERC20 tokenOut;
        uint256 amountOut;
        address recipient;
        bool pretransferred;
        uint256 deadline;
    }

    error ExchangeOutNotAvailable();

    function previewExchangeOut(
        IERC20 tokenIn,
        uint256 maxAmountIn,
        IERC20 tokenOut,
        uint256 amountOut
    ) external view returns (uint256 amountIn, uint256 amountInRefund);

    function exchangeOut(
        IERC20 tokenIn,
        uint256 maxAmountIn,
        IERC20 tokenOut,
        uint256 amountOut,
        address recipient,
        bool pretransferred,
        uint256 deadline
    ) external returns (uint256 amountIn, uint256 amountInRefund);
}
```

### 4. Bundle input for one output

**Disposition:** these functions replace `previewExchangeInManyToOne` and `exchangeInManyToOne` in the target revision. They are new functions in a new interface, with new names and selectors, not extensions of `IStandardExchangeInMulti`. During migration only, the old and new interfaces can sit beside each other. Removing the explicit `tokenIn` array is intentional: the complete `vaultTokens()` order is the only legal input order.

`amountsInRefund` uses that same order. The actual consumed amount at index `i` is `amountsIn[i] - amountsInRefund[i]`.

```solidity
// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeErrors} from "./IStandardExchangeErrors.sol";

interface IStandardExchangeBundleInForSingleOut is IStandardExchangeErrors {
    error ExchangeBundleInForSingleOutNotAvailable();

    function previewExchangeBundleInForSingleOut(
        uint256[] calldata amountsIn,
        IERC20 tokenOut
    ) external view returns (uint256 amountOut, uint256[] memory amountsInRefund);

    function exchangeBundleInForSingleOut(
        uint256[] calldata amountsIn,
        IERC20 tokenOut,
        uint256 minAmountOut,
        address recipient,
        bool pretransferred,
        uint256 deadline
    ) external returns (uint256 amountOut, uint256[] memory amountsInRefund);
}
```

### 5. Bundle exact output

**Disposition:** these functions replace `previewExchangeOutOneToMany` and `exchangeOutOneToMany` in the target revision. They are new functions in a new interface, with new selectors, and may sit beside `IStandardExchangeOutMulti` only during migration. They do not replace proportional exits.

The preview's added `maxAmountIn` is required for a refund quote. Execution returns actual shares or other input consumed as `amountIn`, with the unconsumed maximum returned separately as `amountInRefund`.

```solidity
// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeErrors} from "./IStandardExchangeErrors.sol";

interface IStandardExchangeBundleOut is IStandardExchangeErrors {
    error ExchangeBundleOutNotAvailable();

    function previewExchangeBundleOut(
        IERC20 tokenIn,
        uint256 maxAmountIn,
        address[] calldata tokensOut,
        uint256[] calldata amountsOut
    ) external view returns (uint256 amountIn, uint256 amountInRefund);

    function exchangeBundleOut(
        IERC20 tokenIn,
        uint256 maxAmountIn,
        address[] calldata tokensOut,
        uint256[] calldata amountsOut,
        address recipient,
        bool pretransferred,
        uint256 deadline
    ) external returns (uint256 amountIn, uint256 amountInRefund);
}
```

### 6. Aggregate and liquidity extension

**Disposition:** extend the aggregate `IStandardExchange` to include both bundle interfaces. This extends the aggregate's inheritance, while the function-level dispositions above remain replacements for the overlapping routes.

```solidity
// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.0;

import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IStandardExchangeBundleInForSingleOut} from "./IStandardExchangeBundleInForSingleOut.sol";
import {IStandardExchangeBundleOut} from "./IStandardExchangeBundleOut.sol";

interface IStandardExchange is
    IStandardExchangeIn,
    IStandardExchangeOut,
    IStandardExchangeBundleInForSingleOut,
    IStandardExchangeBundleOut
{}
```

**Disposition:** leave every function in `IStandardExchangeMultiAssetLiquidity` beside this family, unchanged. Do not merge its join/exit selectors into In/Out or the bundle interfaces. Canonical exchange routes can represent share entry and exit without absorbing specialized proportional or unbalanced liquidity operations. `IBasicVault` also remains unchanged.

## Limits

This is an interface research recommendation only. It does not implement or authorize implementation, establish owner approval, audit consumers, prove that every protocol can quote or execute these routes within gas limits, or define a migration schedule. No tests, builds, Git operations, peer-response reads, or project-code edits were performed.
