// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

/// @notice Additional accounting and maintenance surface of newly deployed V3 vaults.
interface IUniswapV3FullSpreadStandardExchangeVault {
    event Donation();
    event Compounded();
    event PairDeposited(address indexed caller);
    event PairRedeemed(address indexed caller);

    error MinLiquidityNotMet();
    error SettlementMismatch();
    error InvalidRecipient();
    error EmptyExchange();
    error TokenNotExchangeable();

    function donate(address token, uint256 amount, bool pretransferred) external;
    function compound() external;
    function setOperator(address operator, bool status) external returns (bool);
    function setOperatorFor(bytes4 func, address operator, bool status) external returns (bool);
}
