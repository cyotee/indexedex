// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";

/**
 * @title IUniswapV4CurveQuadStableSwapHook
 * @notice Public surface for the 4-asset StableSwap V4 hook + LP ERC-20.
 */
interface IUniswapV4CurveQuadStableSwapHook {
    function poolManager() external view returns (IPoolManager);
    function token0() external view returns (address);
    function token1() external view returns (address);
    function token2() external view returns (address);
    function token3() external view returns (address);
    function tokens() external view returns (address[4] memory);

    function lpFeePips() external view returns (uint24);
    function baseAmp() external view returns (uint256);
    function getCurrentAmp() external view returns (uint256);

    function rateProvider(uint256 index) external view returns (address);
    function rateProviders() external view returns (address[4] memory);

    function reserveOf(address token) external view returns (uint256);
    /// @dev Multi-asset book legs: use `reserveOf(token)` / shared vault `reserves()` (uint256[]).
    ///      Product fixed array was removed to avoid diamond selector collision with MultiAssetBasicVaultFacet.
    function effectiveRate(uint256 index) external view returns (uint256);

    function previewAddLiquidity(uint256[4] calldata amounts)
        external
        view
        returns (uint256 shares, uint256[4] memory actualAmounts);

    function previewRemoveLiquidity(uint256 shares) external view returns (uint256[4] memory amounts);

    function previewZapIn(uint256[4] calldata amounts)
        external
        view
        returns (uint256 shares, uint256[4] memory amountsUsed);

    function previewSwapExactIn(address tokenIn, address tokenOut, uint256 amountIn)
        external
        view
        returns (uint256 amountOut);

    function previewSwapExactOut(address tokenIn, address tokenOut, uint256 amountOut)
        external
        view
        returns (uint256 amountIn);

    function addLiquidity(
        uint256[4] calldata amounts,
        uint256[4] calldata minAmounts,
        address to,
        uint256 sharesMin
    ) external returns (uint256 shares, uint256[4] memory actualAmounts);

    function zapIn(uint256[4] calldata amounts, address to, uint256 sharesMin)
        external
        returns (uint256 shares, uint256[4] memory amountsUsed);

    function removeLiquidity(uint256 shares, address to, uint256[4] calldata minAmounts)
        external
        returns (uint256[4] memory amounts);
}
