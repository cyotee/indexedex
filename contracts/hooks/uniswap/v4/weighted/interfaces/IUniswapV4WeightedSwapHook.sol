// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";

/**
 * @title IUniswapV4WeightedSwapHook
 * @notice Public surface for n-asset (2–8) Balancer Weighted V4 hook + LP ERC-20.
 * @dev O3 ABI pin. rootK = V (full product invariant). No BaseHook inheritance.
 */
interface IUniswapV4WeightedSwapHook {
    enum KLastMode {
        FullProduct,
        PartialInterim
    }

    event LiquidityJoined(address indexed sender, address indexed to, uint256 shares, uint256[] amounts);
    event LiquidityExited(address indexed sender, address indexed to, uint256 shares, uint256[] amounts);
    event ProtocolFeeMinted(address indexed feeTo, uint256 shares);
    event Swap(
        address indexed sender,
        address indexed tokenIn,
        address indexed tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        uint256 feeWad
    );

    function poolManager() external view returns (IPoolManager);
    function feeOracle() external view returns (IVaultFeeOracleQuery);
    function numTokens() external view returns (uint8);
    function tokens() external view returns (address[] memory);
    function token(uint256 index) external view returns (address);
    function getNormalizedWeights() external view returns (uint256[] memory);
    function rateProvider(uint256 index) external view returns (address);
    function effectiveRate(uint256 index) external view returns (uint256);
    /// @dev Also available via IBasicVault.reserves (MultiAssetBasicVaultFacet). Same selector.
    function reserves() external view returns (uint256[] memory);
    function reserveOf(address token) external view returns (uint256);
    function dexSwapFee() external view returns (uint256);
    function usageFee() external view returns (uint256);
    function feeTo() external view returns (address);
    function kLast() external view returns (uint256);
    function kLastMode() external view returns (KLastMode);
    function isFullBook() external view returns (bool);
    function permit2() external pure returns (address);
    /// @notice Process-only pair-door tick spacing (not part of salt identity).
    function pairPoolTickSpacing() external view returns (int24);
    /// @notice Process-only pair-door init sqrtPriceX96 (not part of salt identity).
    function pairPoolSqrtPriceX96() external view returns (uint160);

    function previewSwapExactIn(address tokenIn, address tokenOut, uint256 amountIn)
        external
        view
        returns (uint256 amountOut);

    function previewSwapExactOut(address tokenIn, address tokenOut, uint256 amountOut)
        external
        view
        returns (uint256 amountIn);

    function previewJoinProportional(uint256[] calldata amounts)
        external
        view
        returns (uint256 shares, uint256[] memory usedAmounts);

    function previewJoinSingleAssetExactIn(address tokenIn, uint256 amountIn)
        external
        view
        returns (uint256 shares);

    function previewJoinSingleAssetExactOut(address tokenIn, uint256 sharesOut)
        external
        view
        returns (uint256 amountIn);

    function previewJoinUnbalanced(uint256[] calldata amounts) external view returns (uint256 shares);

    function previewExitProportional(uint256 shares) external view returns (uint256[] memory amounts);

    function previewExitSingleAssetExactIn(address tokenOut, uint256 sharesIn)
        external
        view
        returns (uint256 amountOut);

    function previewExitSingleAssetExactOut(address tokenOut, uint256 amountOut)
        external
        view
        returns (uint256 sharesIn);

    function joinProportional(
        uint256[] calldata amounts,
        address to,
        uint256 sharesMin,
        uint256 deadline,
        bytes calldata permit2Data
    ) external returns (uint256 shares, uint256[] memory usedAmounts);

    function joinSingleAssetExactIn(
        address tokenIn,
        uint256 amountIn,
        address to,
        uint256 sharesMin,
        uint256 deadline,
        bytes calldata permit2Data
    ) external returns (uint256 shares);

    function joinSingleAssetExactOut(
        address tokenIn,
        uint256 sharesOut,
        address to,
        uint256 amountInMax,
        uint256 deadline,
        bytes calldata permit2Data
    ) external returns (uint256 amountIn);

    function joinUnbalanced(
        uint256[] calldata amounts,
        address to,
        uint256 sharesMin,
        uint256 deadline,
        bytes calldata permit2Data
    ) external returns (uint256 shares);

    function exitProportional(uint256 shares, address to, uint256[] calldata amountsMin, uint256 deadline)
        external
        returns (uint256[] memory amounts);

    function exitSingleAssetExactIn(
        address tokenOut,
        uint256 sharesIn,
        address to,
        uint256 amountOutMin,
        uint256 deadline
    ) external returns (uint256 amountOut);

    function exitSingleAssetExactOut(
        address tokenOut,
        uint256 amountOut,
        address to,
        uint256 sharesInMax,
        uint256 deadline
    ) external returns (uint256 sharesIn);
}
