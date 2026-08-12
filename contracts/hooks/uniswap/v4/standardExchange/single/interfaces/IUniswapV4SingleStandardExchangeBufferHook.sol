// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {Hooks} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/Hooks.sol";

/**
 * @title IUniswapV4SingleStandardExchangeBufferHook
 * @notice Public surface for Uniswap V4 Single SE Buffer Hook (buffer wrap/unwrap hop only).
 * @dev No wrapZeroForOne() public getter. Previews are SE passthroughs only.
 *      Not a rate provider / CP AMM / LP product.
 */
interface IUniswapV4SingleStandardExchangeBufferHook {
    // --- Bindings ---
    function poolManager() external view returns (IPoolManager);
    function standardExchange() external view returns (address);
    function pairToken() external view returns (address);
    /// @notice SE share token address (always address(SE) in v1).
    function wrapper() external view returns (address);

    // --- Currency / pool helpers (O13) ---
    function currency0() external view returns (address);
    function currency1() external view returns (address);
    function poolFee() external pure returns (uint24);
    function tickSpacingHint() external pure returns (int24);
    function sqrtPriceX96Hint() external pure returns (uint160);

    // --- Previews (SE passthrough) ---
    /// @notice Exact-in wrap: pairToken in → SE out
    function previewWrap(uint256 pairIn) external view returns (uint256 seOut);

    /// @notice Exact-out wrap: SE out → pairToken in required
    function previewWrapExactOut(uint256 seOut) external view returns (uint256 pairIn);

    /// @notice Exact-in unwrap: SE in → pairToken out
    function previewUnwrap(uint256 seIn) external view returns (uint256 pairOut);

    /// @notice Exact-out unwrap: pairToken out → SE in required
    function previewUnwrapExactOut(uint256 pairOut) external view returns (uint256 seIn);

    /// @notice Hook permissions (pure) — matches requiredHookFlags.
    function getHookPermissions() external pure returns (Hooks.Permissions memory);
}
