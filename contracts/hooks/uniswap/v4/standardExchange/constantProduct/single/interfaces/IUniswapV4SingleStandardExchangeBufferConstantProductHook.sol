// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IUniswapV4SeBufferHook} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol";
import {IDetfReserveQuote} from "contracts/hooks/uniswap/v4/interfaces/IDetfReserveQuote.sol";

/**
 * @title IUniswapV4SingleStandardExchangeBufferConstantProductHook
 * @notice Single SE + rawToken CP buffer hook. DETF-facing ABI is IUniswapV4SeBufferHook + IDetfReserveQuote.
 * @dev Family deposit/withdraw names remain so existing CP DETF still type-checks until Stage 07.
 */
interface IUniswapV4SingleStandardExchangeBufferConstantProductHook is
    IUniswapV4SeBufferHook,
    IDetfReserveQuote
{
    event Deposit(
        address indexed sender,
        address indexed to,
        uint256 amount0,
        uint256 amount1,
        uint256 used0,
        uint256 used1,
        uint256 lpAmount
    );

    event DepositSingle(
        address indexed sender,
        address indexed to,
        address tokenIn,
        uint256 amountIn,
        uint256 lpAmount
    );

    event Withdraw(
        address indexed sender,
        address indexed to,
        uint256 lpAmount,
        uint256 amount0,
        uint256 amount1
    );

    event WithdrawSingle(
        address indexed sender,
        address indexed to,
        uint256 lpAmount,
        address tokenOut,
        uint256 amountOut
    );

    /// @notice B6 proportional deposit with SE vault shares for the buffered leg.
    event DepositSeShares(
        address indexed sender,
        address indexed to,
        uint256 amountRaw,
        uint256 amountSe,
        uint256 usedRaw,
        uint256 usedSe,
        uint256 lpAmount
    );

    /// @notice B6 proportional withdraw paying rawToken + SE vault shares (no unwrap).
    event WithdrawSeShares(
        address indexed sender,
        address indexed to,
        uint256 lpAmount,
        uint256 amountRaw,
        uint256 amountSe
    );

    event ZapSwap(
        address indexed sender,
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOut
    );

    // --- Bindings ---
    function poolManager() external view returns (address);
    function feeOracle() external view returns (address);
    function permit2() external view returns (address);
    function standardExchange() external view returns (address);
    function pairToken() external view returns (address);
    function rawToken() external view returns (address);
    function currency0() external view returns (address);
    function currency1() external view returns (address);

    // --- Reserves ---
    function rawReserve() external view returns (uint256);
    function seClaimSupply() external view returns (uint256);
    function reserveCurrency0() external view returns (uint256);
    function reserveCurrency1() external view returns (uint256);
    function isZapEligible() external view returns (bool);

    // --- Fees ---
    function tradingFeePercent() external view returns (uint256);
    function tradingFeeDenominator() external view returns (uint256);
    function dexSwapFeeAndFeeTo() external view returns (address feeTo, uint256 dexFeeWad);
    function kLast() external view returns (uint256);

    // --- Liquidity ---
    function deposit(uint256 amount0, uint256 amount1, address to, uint256 minLpAmount, uint256 deadline)
        external
        returns (uint256 lpAmount, uint256 used0, uint256 used1);

    function depositSingle(address tokenIn, uint256 amountIn, address to, uint256 minLpAmount, uint256 deadline)
        external
        returns (uint256 lpAmount);

    function depositWithPermit2Signature(
        uint256 amount0,
        uint256 amount1,
        address to,
        uint256 minLpAmount,
        uint256 deadline,
        bytes calldata permit2Data
    ) external returns (uint256 lpAmount, uint256 used0, uint256 used1);

    function depositWithPermit2Allowance(
        uint256 amount0,
        uint256 amount1,
        address to,
        uint256 minLpAmount,
        uint256 deadline
    ) external returns (uint256 lpAmount, uint256 used0, uint256 used1);

    function depositSingleWithPermit2Signature(
        address tokenIn,
        uint256 amountIn,
        address to,
        uint256 minLpAmount,
        uint256 deadline,
        bytes calldata permit2Data
    ) external returns (uint256 lpAmount);

    function depositSingleWithPermit2Allowance(
        address tokenIn,
        uint256 amountIn,
        address to,
        uint256 minLpAmount,
        uint256 deadline
    ) external returns (uint256 lpAmount);

    function withdraw(uint256 lpAmount, address to, uint256 minAmount0, uint256 minAmount1, uint256 deadline)
        external
        returns (uint256 amount0, uint256 amount1);

    function withdrawSingle(uint256 lpAmount, address tokenOut, address to, uint256 minAmountOut, uint256 deadline)
        external
        returns (uint256 amountOut);

    /// @notice B6: proportional deposit with face rawToken + SE vault shares for the buffered leg.
    /// @dev No pair→SE buffer; SE shares enter inventory directly. Book uses claim of SE shares.
    function depositWithSeShares(
        uint256 amountRaw,
        uint256 amountSe,
        address to,
        uint256 minLpAmount,
        uint256 deadline
    ) external returns (uint256 lpAmount, uint256 usedRaw, uint256 usedSe);

    /// @notice B6: proportional withdraw paying face rawToken + SE vault shares (no SE unwrap).
    function withdrawSeShares(
        uint256 lpAmount,
        address to,
        uint256 minAmountRaw,
        uint256 minAmountSe,
        uint256 deadline
    ) external returns (uint256 amountRaw, uint256 amountSe);

    // --- Previews ---
    function previewDeposit(uint256 amount0, uint256 amount1)
        external
        view
        returns (uint256 lpAmount, uint256 used0, uint256 used1);

    function previewDepositSingle(address tokenIn, uint256 amountIn) external view returns (uint256 lpAmount);

    function previewZapSplit(address tokenIn, uint256 amountIn)
        external
        view
        returns (uint256 amountToSwap, uint256 amountOtherOut, uint256 amountKeptIn);

    function previewWithdraw(uint256 lpAmount) external view returns (uint256 amount0, uint256 amount1);

    function previewWithdrawSingle(uint256 lpAmount, address tokenOut) external view returns (uint256 amountOut);

    function previewDepositWithSeShares(uint256 amountRaw, uint256 amountSe)
        external
        view
        returns (uint256 lpAmount, uint256 usedRaw, uint256 usedSe);

    function previewWithdrawSeShares(uint256 lpAmount)
        external
        view
        returns (uint256 amountRaw, uint256 amountSe);

    function previewSwapExactIn(bool zeroForOne, uint256 amountIn) external view returns (uint256 amountOut);

    function previewSwapExactOut(bool zeroForOne, uint256 amountOut) external view returns (uint256 amountIn);

    // LP ERC-20, IBasicVault, IStandardVault: shared diamond facets (ERC20 / MultiAsset Basic+Standard).
    // Do not redeclare them here — use IERC20 / IBasicVault / IStandardVault on the proxy.
    // ownerSwapExactIn/Out and isLive come from IUniswapV4SeBufferHook.
}
