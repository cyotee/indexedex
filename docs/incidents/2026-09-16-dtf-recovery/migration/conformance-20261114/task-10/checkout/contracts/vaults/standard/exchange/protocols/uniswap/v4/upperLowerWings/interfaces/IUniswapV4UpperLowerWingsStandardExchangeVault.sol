// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {UniswapV4UpperLowerWingsStandardExchangeVaultLiquidationQuote as Quote} from "../UniswapV4UpperLowerWingsStandardExchangeVaultLiquidationQuote.sol";

/// @notice Immutable pool identity and economic observations of the Wings family.
interface IUniswapV4UpperLowerWingsStandardExchangeVault {
    error NotInitialized();
    error AlreadyInitialized();
    error ReentrantOperation();
    error UnauthorizedCallback();
    error InvalidPoolKey();
    error InvalidTarget();
    error InsufficientLocalTarget(uint256 requested, uint256 available);
    function poolManager() external view returns (IPoolManager);
    function poolKey() external view returns (PoolKey memory);
    function targetToken() external view returns (address);
    function liquidationValue() external view returns (Quote.Result memory);
    function localReserves() external view returns (uint256 amount0, uint256 amount1);
    function position(uint8 slot) external view returns (int24 lower, int24 upper, uint128 liquidity, bytes32 salt);
}
