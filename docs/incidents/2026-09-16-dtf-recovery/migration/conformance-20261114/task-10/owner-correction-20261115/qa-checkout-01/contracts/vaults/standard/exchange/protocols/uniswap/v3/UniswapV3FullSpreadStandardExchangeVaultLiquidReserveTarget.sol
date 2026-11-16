// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ONE_WAD} from "@crane/contracts/constants/Constants.sol";
import {ReentrancyLockModifiers} from "@crane/contracts/access/reentrancy/ReentrancyLockModifiers.sol";

import {
    IUniswapV3FullSpreadStandardExchangeVaultLiquidReserve
} from "contracts/vaults/standard/exchange/protocols/uniswap/v3/interfaces/IUniswapV3FullSpreadStandardExchangeVaultLiquidReserve.sol";
import {
    UniswapV3FullSpreadStandardExchangeVaultCommon
} from "contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultCommon.sol";

/**
 * @title UniswapV3FullSpreadStandardExchangeVaultLiquidReserveTarget
 * @notice Public liquid-sleeve views and permissionless rebalance (D10).
 */
contract UniswapV3FullSpreadStandardExchangeVaultLiquidReserveTarget is
    UniswapV3FullSpreadStandardExchangeVaultCommon,
    ReentrancyLockModifiers,
    IUniswapV3FullSpreadStandardExchangeVaultLiquidReserve
{
    /// @inheritdoc IUniswapV3FullSpreadStandardExchangeVaultLiquidReserve
    function canOpenBoundPoolOps()
        public
        view
        override(UniswapV3FullSpreadStandardExchangeVaultCommon, IUniswapV3FullSpreadStandardExchangeVaultLiquidReserve)
        returns (bool)
    {
        return UniswapV3FullSpreadStandardExchangeVaultCommon.canOpenBoundPoolOps();
    }

    /// @inheritdoc IUniswapV3FullSpreadStandardExchangeVaultLiquidReserve
    function localReserve(address token) external view returns (uint256) {
        if (token == _token0() || token == _token1()) {
            return IERC20(token).balanceOf(address(this));
        }
        return 0;
    }

    /// @inheritdoc IUniswapV3FullSpreadStandardExchangeVaultLiquidReserve
    function deployedReserve() external view returns (uint256 amount0, uint256 amount1) {
        return _deployedAmounts();
    }

    /// @inheritdoc IUniswapV3FullSpreadStandardExchangeVaultLiquidReserve
    function targetLiquidReservePercentage() external view returns (uint256) {
        return _liveLiquidReservePercentage();
    }

    /// @inheritdoc IUniswapV3FullSpreadStandardExchangeVaultLiquidReserve
    function actualLiquidReservePercentage(address token) external view returns (uint256) {
        (uint256 free0, uint256 free1) = _freeBalances();
        (uint256 dep0, uint256 dep1) = _deployedAmounts();
        if (token == _token0()) {
            uint256 total = free0 + dep0;
            if (total == 0) return 0;
            return (free0 * ONE_WAD) / total;
        }
        if (token == _token1()) {
            uint256 total = free1 + dep1;
            if (total == 0) return 0;
            return (free1 * ONE_WAD) / total;
        }
        return 0;
    }

    /**
     * @inheritdoc IUniswapV3FullSpreadStandardExchangeVaultLiquidReserve
     * @dev Reverts when the bound pool is locked. Idle success when both tokens already within deadband.
     */
    /// @notice Permissionless sleeve maintenance; pays the caller nothing.
    /// @dev A zero target can leave locked exits without sufficient local reserve.
    function rebalanceLiquidReserve() external nonReentrant {
        _requireNotDisabled();
        _requireCanOpenBoundPoolOps();
        _rebalanceLiquidReserveInternal();
    }
}
