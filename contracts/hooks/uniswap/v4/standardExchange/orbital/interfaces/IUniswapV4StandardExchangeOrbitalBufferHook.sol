// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";

/**
 * @title IUniswapV4StandardExchangeOrbitalBufferHook
 * @notice Public product surface: 3-asset sphere on effective reserves, optional SE per leg, zap-in, SE In/Out.
 * @dev LP ERC-20 + EIP-2612 + vault discovery via shared diamond facets (not redeclared here).
 *      Canonical SE In/Out selectors live on IStandardExchangeIn / IStandardExchangeOut.
 */
interface IUniswapV4StandardExchangeOrbitalBufferHook {
    enum KLastMode {
        FullProduct,
        SumInterim
    }

    event LiquidityAdded(
        address indexed provider,
        address indexed to,
        uint256 shares,
        uint256 amount0,
        uint256 amount1,
        uint256 amount2
    );
    event LiquidityRemoved(
        address indexed provider,
        address indexed to,
        uint256 shares,
        uint256 amount0,
        uint256 amount1,
        uint256 amount2
    );
    event DepositSingle(
        address indexed sender,
        address indexed to,
        address tokenIn,
        uint256 amountIn,
        uint256 shares
    );
    event ZapSwap(
        address indexed sender,
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOut
    );
    event Swap(
        address indexed sender,
        address indexed tokenIn,
        address indexed tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        uint256 feeWad
    );
    event ProtocolFeeMinted(address indexed feeTo, uint256 shares);

    /// @notice B6: multipath deposit with pair token and/or SE vault share per leg.
    event DepositFlexible(
        address indexed provider,
        address indexed to,
        uint256 amount0,
        bool amount0IsSeShare,
        uint256 amount1,
        bool amount1IsSeShare,
        uint256 amount2,
        bool amount2IsSeShare,
        uint256 used0,
        uint256 used1,
        uint256 used2,
        uint256 shares
    );

    /// @notice B6: multipath withdraw paying pair tokens and/or SE vault shares per leg.
    event WithdrawFlexible(
        address indexed provider,
        address indexed to,
        uint256 shares,
        bool receiveSeShare0,
        bool receiveSeShare1,
        bool receiveSeShare2,
        uint256 amount0,
        uint256 amount1,
        uint256 amount2
    );

    function poolManager() external view returns (IPoolManager);
    function feeOracle() external view returns (IVaultFeeOracleQuery);
    function token0() external view returns (address);
    function token1() external view returns (address);
    function token2() external view returns (address);
    function standardExchange(uint8 i) external view returns (address);
    function rateProvider(uint8 i) external view returns (address);
    function isBuffered(uint8 i) external view returns (bool);
    function permit2() external view returns (address);

    function rawReserve(uint8 i) external view returns (uint256);
    function seBalance(uint8 i) external view returns (uint256);
    function seClaim(uint8 i) external view returns (uint256);
    function effectiveReserve(uint8 i) external view returns (uint256);
    function effectiveReserves() external view returns (uint256 e0, uint256 e1, uint256 e2);

    function radius() external view returns (uint256);
    function lSquared() external view returns (uint256);
    function dexSwapFee() external view returns (uint256);
    function usageFee() external view returns (uint256);
    function feeTo() external view returns (address);
    function kLast() external view returns (uint256);
    function kLastMode() external view returns (KLastMode);

    function pairPoolTickSpacing() external view returns (int24);
    function pairPoolSqrtPriceX96() external view returns (uint160);

    function isZapEligible() external view returns (bool);

    function previewAddLiquidity(uint256 a0Max, uint256 a1Max, uint256 a2Max)
        external
        view
        returns (uint256 shares, uint256 a0, uint256 a1, uint256 a2);

    function previewRemoveLiquidity(uint256 shares)
        external
        view
        returns (uint256 a0, uint256 a1, uint256 a2);

    function previewDepositSingle(address tokenIn, uint256 amountIn)
        external
        view
        returns (uint256 shares);

    function previewZapSplit(address tokenIn, uint256 amountIn)
        external
        view
        returns (uint256 saleJ, uint256 saleK, uint256 residualIn, uint256 outJ, uint256 outK);

    function previewSwapExactIn(address tokenIn, address tokenOut, uint256 amountIn)
        external
        view
        returns (uint256 amountOut);

    function previewSwapExactOut(address tokenIn, address tokenOut, uint256 amountOut)
        external
        view
        returns (uint256 amountIn);

    /// @notice D89 / D30: owner exact-in on the sphere book. Internal settlement (no nested unlock).
    function ownerSwapExactIn(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 minAmountOut,
        uint256 deadline
    ) external returns (uint256 amountOut);

    /// @notice D89 / D30: owner exact-out on the sphere book. Internal settlement (no nested unlock).
    function ownerSwapExactOut(
        address tokenIn,
        address tokenOut,
        uint256 amountOut,
        uint256 maxAmountIn,
        uint256 deadline
    ) external returns (uint256 amountIn);

    /// @param permit2Data empty => SafeERC20 transferFrom only; non-empty => Permit2 packing
    function addLiquidity(
        uint256 a0Max,
        uint256 a1Max,
        uint256 a2Max,
        address to,
        uint256 sharesMin,
        uint256 deadline,
        bytes calldata permit2Data
    ) external returns (uint256 shares, uint256 a0, uint256 a1, uint256 a2);

    function depositSingle(
        address tokenIn,
        uint256 amountIn,
        address to,
        uint256 sharesMin,
        uint256 deadline,
        bytes calldata permit2Data
    ) external returns (uint256 shares);

    function removeLiquidity(
        uint256 shares,
        address to,
        uint256 a0Min,
        uint256 a1Min,
        uint256 a2Min,
        uint256 deadline
    ) external returns (uint256 a0, uint256 a1, uint256 a2);

    /// @notice B6: multipath deposit with pair token and/or SE vault share per pool-order leg.
    /// @dev amount*IsSeShare selects SE for that leg vs pair token. Raw legs must pass false.
    function depositFlexible(
        uint256 amount0,
        bool amount0IsSeShare,
        uint256 amount1,
        bool amount1IsSeShare,
        uint256 amount2,
        bool amount2IsSeShare,
        address to,
        uint256 sharesMin,
        uint256 deadline
    ) external returns (uint256 shares, uint256 used0, uint256 used1, uint256 used2);

    /// @notice B6: multipath withdraw paying pair tokens and/or SE vault shares per pool-order leg.
    function withdrawFlexible(
        uint256 shares,
        address to,
        bool receiveSeShare0,
        bool receiveSeShare1,
        bool receiveSeShare2,
        uint256 a0Min,
        uint256 a1Min,
        uint256 a2Min,
        uint256 deadline
    ) external returns (uint256 a0, uint256 a1, uint256 a2);

    function previewDepositFlexible(
        uint256 amount0,
        bool amount0IsSeShare,
        uint256 amount1,
        bool amount1IsSeShare,
        uint256 amount2,
        bool amount2IsSeShare
    ) external view returns (uint256 shares, uint256 used0, uint256 used1, uint256 used2);

    function previewWithdrawFlexible(
        uint256 shares,
        bool receiveSeShare0,
        bool receiveSeShare1,
        bool receiveSeShare2
    ) external view returns (uint256 a0, uint256 a1, uint256 a2);
}
