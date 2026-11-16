// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IStandardExchangeFrozenQuoteInputs as Frozen} from "contracts/interfaces/IStandardExchangeFrozenQuoteInputs.sol";
import {StandardExchangeConstantProduct as Product} from
    "contracts/vaults/standard/exchange/protocols/uniswap/StandardExchangeConstantProduct.sol";
import {ExchangeInAmount} from "contracts/utils/ExchangeInAmount.sol";
import {UniswapV3FullSpreadStandardExchangeVaultInQueryFacet} from
    "contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultInQueryFacet.sol";
import {UniswapV3FullSpreadStandardExchangeVaultInMultiQueryFacet} from
    "contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultInMultiQueryFacet.sol";

/// @dev Separate immutable identity libraries keep each deployed runtime below EIP-170.
/// These two reviewed facets have no immutables or link references. Their complete
/// compiler-produced runtime, not a caller-provided hash or model tag, is the identity.
library StandardExchangeFrozenV3CaptureIdentity {
    function codeHash() external pure returns (bytes32) {
        return keccak256(type(UniswapV3FullSpreadStandardExchangeVaultInQueryFacet).runtimeCode);
    }
}

library StandardExchangeFrozenV3PreviewIdentity {
    function codeHash() external pure returns (bytes32) {
        return keccak256(type(UniswapV3FullSpreadStandardExchangeVaultInMultiQueryFacet).runtimeCode);
    }
}

/// @notice State-only evaluation of the explicitly admitted ordinary V3 deposit.
library StandardExchangeFrozenQuoteLib {
    error UnrecognizedFrozenImplementation(address captureFacet, address previewFacet);

    function requireRecognized(address captureFacet, address previewFacet) internal view {
        if (captureFacet.codehash != StandardExchangeFrozenV3CaptureIdentity.codeHash()
            || previewFacet.codehash != StandardExchangeFrozenV3PreviewIdentity.codeHash()) {
            revert UnrecognizedFrozenImplementation(captureFacet, previewFacet);
        }
    }

    function requireSupported(Frozen.Inputs memory q) internal pure {
        if (
            q.model != Frozen.Model.UniswapV3PairDeposit
                || q.request.mode != Frozen.Mode.OrdinaryDeposit
                || q.request.tokenOut != q.exchange
                || (q.request.tokenIn != q.token0 && q.request.tokenIn != q.token1)
        ) revert Frozen.UnsupportedFrozenQuote(q.exchange, q.request.tokenIn, q.request.tokenOut, q.request.mode);
    }

    function evaluate(Frozen.Inputs memory q, uint256 amount) internal pure returns (ExchangeInAmount.Result memory r) {
        requireSupported(q);
        if (amount == 0) return r;
        uint256 added0 = q.request.tokenIn == q.token0 ? amount : 0;
        uint256 added1 = q.request.tokenIn == q.token1 ? amount : 0;
        r.amountOut = q.supply == 0
            ? Product._initialShares(added0, added1, q.minimumLiquidity)
            : Product._sharesForDeposit(added0, added1, q.supply, q.reserve0, q.reserve1);
    }
}
