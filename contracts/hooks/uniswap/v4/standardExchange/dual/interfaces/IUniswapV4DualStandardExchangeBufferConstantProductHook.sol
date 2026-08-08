// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/**
 * @title IUniswapV4DualStandardExchangeBufferConstantProductHook
 * @notice Dual SE buffer + constant-product pricing hook (pair-token pool).
 * @dev LP ERC-20 is the same contract. Liquidity amount0/amount1 = pool currency0/currency1.
 *      Product law: UNISWAP_V4_DUAL_STANDARD_EXCHANGE_BUFFER_CONSTANT_PRODUCT_HOOK_PRD.md v3.12.
 *      B6: depositFlexible / withdrawFlexible accept pair token and/or SE vault share per leg.
 *      M3: diamond also cuts IStandardExchangeIn / IStandardExchangeOut for pair0↔pair1 book swaps.
 */
interface IUniswapV4DualStandardExchangeBufferConstantProductHook {
    event Deposit(
        address indexed sender,
        address indexed to,
        uint256 amount0,
        uint256 amount1,
        uint256 lpAmount
    );

    event DepositSingle(
        address indexed sender,
        address indexed to,
        address tokenIn,
        uint256 amountIn,
        uint256 lpAmount
    );

    event DepositFlexible(
        address indexed sender,
        address indexed to,
        uint256 amount0,
        bool amount0IsSeShare,
        uint256 amount1,
        bool amount1IsSeShare,
        uint256 used0,
        uint256 used1,
        uint256 lpAmount
    );

    event Withdraw(
        address indexed sender,
        address indexed to,
        uint256 lpAmount,
        uint256 amount0,
        uint256 amount1
    );

    event WithdrawFlexible(
        address indexed sender,
        address indexed to,
        uint256 lpAmount,
        bool receiveSeShare0,
        bool receiveSeShare1,
        uint256 amount0,
        uint256 amount1
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
    function standardExchange0() external view returns (address);
    function standardExchange1() external view returns (address);
    function token0() external view returns (address);
    function token1() external view returns (address);
    function currency0() external view returns (address);
    function currency1() external view returns (address);

    // --- Claims ---
    function claimSupply0() external view returns (uint256);
    function claimSupply1() external view returns (uint256);
    function claimSupplyCurrency0() external view returns (uint256);
    function claimSupplyCurrency1() external view returns (uint256);

    // --- Fees / kLast ---
    function tradingFeePercent() external view returns (uint256);
    function tradingFeeDenominator() external view returns (uint256);
    function dexSwapFee() external view returns (uint256);
    function feeTo() external view returns (address);
    function kLast() external view returns (uint256);

    // --- Liquidity ---
    function deposit(
        uint256 amount0,
        uint256 amount1,
        address to,
        uint256 minLpAmount,
        uint256 deadline
    ) external returns (uint256 lpAmount, uint256 used0, uint256 used1);

    function depositSingle(
        address tokenIn,
        uint256 amountIn,
        address to,
        uint256 minLpAmount,
        uint256 deadline
    ) external returns (uint256 lpAmount);

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

    function withdraw(
        uint256 lpAmount,
        address to,
        uint256 minAmount0,
        uint256 minAmount1,
        uint256 deadline
    ) external returns (uint256 amount0, uint256 amount1);

    /// @notice B6: proportional deposit with pair token and/or SE vault share per pool leg.
    /// @dev amount*IsSeShare selects SE for that currency (seFor(currency*)) vs pair token.
    function depositFlexible(
        uint256 amount0,
        bool amount0IsSeShare,
        uint256 amount1,
        bool amount1IsSeShare,
        address to,
        uint256 minLpAmount,
        uint256 deadline
    ) external returns (uint256 lpAmount, uint256 used0, uint256 used1);

    /// @notice B6: proportional withdraw paying pair tokens and/or SE vault shares per pool leg.
    function withdrawFlexible(
        uint256 lpAmount,
        address to,
        bool receiveSeShare0,
        bool receiveSeShare1,
        uint256 minAmount0,
        uint256 minAmount1,
        uint256 deadline
    ) external returns (uint256 amount0, uint256 amount1);

    // --- Previews ---
    function previewDeposit(uint256 amount0, uint256 amount1)
        external
        view
        returns (uint256 lpAmount, uint256 used0, uint256 used1);

    function previewDepositSingle(address tokenIn, uint256 amountIn)
        external
        view
        returns (uint256 lpAmount);

    function previewZapSplit(address tokenIn, uint256 amountIn)
        external
        view
        returns (uint256 amountToSwap, uint256 amountOtherOut, uint256 amountKeptIn);

    function previewWithdraw(uint256 lpAmount)
        external
        view
        returns (uint256 amount0, uint256 amount1);

    function previewDepositFlexible(
        uint256 amount0,
        bool amount0IsSeShare,
        uint256 amount1,
        bool amount1IsSeShare
    ) external view returns (uint256 lpAmount, uint256 used0, uint256 used1);

    function previewWithdrawFlexible(uint256 lpAmount, bool receiveSeShare0, bool receiveSeShare1)
        external
        view
        returns (uint256 amount0, uint256 amount1);

    function previewSwapExactIn(bool zeroForOne, uint256 amountIn)
        external
        view
        returns (uint256 amountOut);

    function previewSwapExactOut(bool zeroForOne, uint256 amountOut)
        external
        view
        returns (uint256 amountIn);
}
