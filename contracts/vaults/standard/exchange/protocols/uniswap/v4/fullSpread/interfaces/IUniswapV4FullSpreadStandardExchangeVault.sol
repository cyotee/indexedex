// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";

// tag::IUniswapV4FullSpreadStandardExchangeVault[]
/// @notice Family surface that is not already on a shared Standard Exchange interface.
interface IUniswapV4FullSpreadStandardExchangeVault {
    event Donation();
    event Compounded();
    event PairDeposited(address indexed caller);
    event PairRedeemed(address indexed caller);

    /// @custom:signature InvalidUnlockedContext()
    error InvalidUnlockedContext();
    /// @custom:signature SettlementMismatch()
    error SettlementMismatch();
    /// @custom:signature ManagerAlreadyUnlocked()
    error ManagerAlreadyUnlocked();
    /// @custom:signature ReentrantOperation()
    error ReentrantOperation();
    /// @custom:signature InvalidRoute()
    error InvalidRoute();
    /// @custom:signature MinLiquidityNotMet()
    error MinLiquidityNotMet();
    /// @custom:signature InvalidRecipient()
    error InvalidRecipient();
    /// @custom:signature EmptyExchange()
    error EmptyExchange();
    /// @custom:signature TokenNotExchangeable()
    error TokenNotExchangeable();

    function donate(address token, uint256 amount, bool pretransferred) external;
    function compound() external;
    function setOperator(address operator, bool status) external returns (bool);
    function setOperatorFor(bytes4 func, address operator, bool status) external returns (bool);
}
// end::IUniswapV4FullSpreadStandardExchangeVault[]

interface IStandardExchangeBundleIn {
    /// @custom:signature AmountsLengthMismatch()
    error AmountsLengthMismatch();
    /// @custom:signature ExchangeBundleInForSingleOutNotAvailable()
    error ExchangeBundleInForSingleOutNotAvailable();
    /// @custom:signature MinAmountNotMetAt(uint256,uint256,uint256)
    error MinAmountNotMetAt(uint256 index, uint256 minAmount, uint256 actualAmount);

    function previewExchangeBundleInForSingleOut(uint256[] calldata amountsIn, address tokenOut)
        external
        view
        returns (uint256 amountOut, uint256[] memory amountsRefunded);

    function exchangeBundleInForSingleOut(
        uint256[] calldata amountsIn,
        address tokenOut,
        uint256 minAmountOut,
        address recipient,
        bool pretransferred,
        uint256 deadline
    ) external returns (uint256 amountOut, uint256[] memory amountsRefunded);
}

interface IStandardExchangeBundleOut {
    /// @custom:signature TokenAmountsLengthMismatch()
    error TokenAmountsLengthMismatch();
    /// @custom:signature DuplicateOutput()
    error DuplicateOutput();
    /// @custom:signature ExchangeBundleOutNotAvailable()
    error ExchangeBundleOutNotAvailable();

    function previewExchangeBundleOut(address tokenIn, uint256 amountIn, address[] calldata tokensOut)
        external
        view
        returns (uint256[] memory amountsOut, uint256 amountRefunded);

    function exchangeBundleOut(
        address tokenIn,
        uint256 amountIn,
        address[] calldata tokensOut,
        uint256[] calldata minAmountsOut,
        address recipient,
        bool pretransferred,
        uint256 deadline
    ) external returns (uint256[] memory amountsOut, uint256 amountRefunded);
}
