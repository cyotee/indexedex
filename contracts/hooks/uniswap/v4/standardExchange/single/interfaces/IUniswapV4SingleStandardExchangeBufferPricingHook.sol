// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";

/**
 * @title IUniswapV4SingleStandardExchangeBufferPricingHook
 * @notice Public surface for Uniswap V4 buffer/pricing hook bound to one SE + underlying.
 * @dev No wrapZeroForOne() public getter (D70/D73). Previews are SE passthroughs only.
 */
interface IUniswapV4SingleStandardExchangeBufferPricingHook {
    function poolManager() external view returns (IPoolManager);
    function standardExchange() external view returns (address);
    function underlying() external view returns (address);
    /// @notice SE share token address (always address(SE) in v1).
    function wrapper() external view returns (address);

    /// @notice Exact-in wrap: underlying in → SE out
    function previewWrap(uint256 underlyingIn) external view returns (uint256 seOut);

    /// @notice Exact-out wrap: SE out → underlying in required
    function previewWrapExactOut(uint256 seOut) external view returns (uint256 underlyingIn);

    /// @notice Exact-in unwrap: SE in → underlying out
    function previewUnwrap(uint256 seIn) external view returns (uint256 underlyingOut);

    /// @notice Exact-out unwrap: underlying out → SE in required
    function previewUnwrapExactOut(uint256 underlyingOut) external view returns (uint256 seIn);
}
