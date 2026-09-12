// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {UniswapV4StandardExchangeBalancerQuadStableBufferHookLiquidityCore} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHookLiquidityCore.sol";

/// @notice Exit execution through the shared reserve accounting.
abstract contract UniswapV4StandardExchangeBalancerQuadStableBufferHookExitTarget is UniswapV4StandardExchangeBalancerQuadStableBufferHookLiquidityCore {
    function exitSingleAssetExactTokenOut(address tokenOut, uint256 amountOut, address to, uint256 sharesInMax, uint256 deadline)
        public  returns (uint256 sharesIn) {
        return _entryExitSingleAssetExactTokenOut(tokenOut, amountOut, to, sharesInMax, deadline);
    }

    function withdrawSingleExactOut(address tokenOut, uint256 amountOut, address to, uint256 sharesInMax, uint256 deadline)
        public  returns (uint256) {
        return _entryWithdrawSingleExactOut(tokenOut, amountOut, to, sharesInMax, deadline);
    }

    function exitProportional(
        uint256 shares,
        address to,
        uint256[] calldata amountsMin,
        uint256 deadline
    ) public  returns (uint256[] memory amounts) {
        return _entryExitProportional(shares, to, amountsMin, deadline);
    }

    function exitSingleAssetExactBptIn(
        address tokenOut,
        uint256 sharesIn,
        address to,
        uint256 amountOutMin,
        uint256 deadline
    ) public  returns (uint256 amountOut) {
        return _entryExitSingleAssetExactBptIn(tokenOut, sharesIn, to, amountOutMin, deadline);
    }

    function withdrawSingle(
        address tokenOut,
        uint256 sharesIn,
        address to,
        uint256 amountOutMin,
        uint256 deadline
    ) public  returns (uint256 amountOut) {
        return _entryWithdrawSingle(tokenOut, sharesIn, to, amountOutMin, deadline);
    }

    function exitProportionalFlexible(uint256 shares, address to, bool[] calldata flags, uint256[] calldata minimum, uint256 deadline)
        external  returns (uint256[] memory amounts) {
        return _entryExitProportionalFlexible(shares, to, flags, minimum, deadline);
    }
    function previewExitSingleAssetExactTokenOut(address tokenOut, uint256 amountOut) public view returns (uint256) {
        return _entryPreviewExitSingleAssetExactTokenOut(tokenOut, amountOut);
    }
    function previewWithdrawSingleExactOut(address tokenOut, uint256 amountOut) public view returns (uint256) {
        return _entryPreviewWithdrawSingleExactOut(tokenOut, amountOut);
    }
    function previewExitProportional(uint256 shares)
        public
        view
        returns (uint256[] memory amounts) {
        return _entryPreviewExitProportional(shares);
    }
    function previewExitSingleAssetExactBptIn(address tokenOut, uint256 sharesIn)
        public
        view
        returns (uint256 amountOut) {
        return _entryPreviewExitSingleAssetExactBptIn(tokenOut, sharesIn);
    }
    function previewWithdrawSingle(address tokenOut, uint256 sharesIn)
        public
        view
        returns (uint256 amountOut) {
        return _entryPreviewWithdrawSingle(tokenOut, sharesIn);
    }
    function previewExitProportionalFlexible(uint256 shares, bool[] calldata flags)
        external view returns (uint256[] memory amounts) {
        return _entryPreviewExitProportionalFlexible(shares, flags);
    }
}
