// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ONE_WAD} from "@crane/contracts/constants/Constants.sol";
import {ReentrancyLockModifiers} from "@crane/contracts/access/reentrancy/ReentrancyLockModifiers.sol";

import {
    IUniswapV3StandardExchangeLiquidReserve
} from "contracts/protocols/dexes/uniswap/v3/interfaces/IUniswapV3StandardExchangeLiquidReserve.sol";
import {
    UniswapV3StandardExchangeCommon
} from "contracts/protocols/dexes/uniswap/v3/UniswapV3StandardExchangeCommon.sol";

/**
 * @title UniswapV3StandardExchangeLiquidReserveTarget
 * @notice Public liquid-sleeve views and permissionless rebalance (D10).
 */
contract UniswapV3StandardExchangeLiquidReserveTarget is
    UniswapV3StandardExchangeCommon,
    ReentrancyLockModifiers,
    IUniswapV3StandardExchangeLiquidReserve
{
    /// @inheritdoc IUniswapV3StandardExchangeLiquidReserve
    function canOpenBoundPoolOps()
        public
        view
        override(UniswapV3StandardExchangeCommon, IUniswapV3StandardExchangeLiquidReserve)
        returns (bool)
    {
        return UniswapV3StandardExchangeCommon.canOpenBoundPoolOps();
    }

    /// @inheritdoc IUniswapV3StandardExchangeLiquidReserve
    function localReserve(address token) external view returns (uint256) {
        if (token == _token0() || token == _token1()) {
            return IERC20(token).balanceOf(address(this));
        }
        return 0;
    }

    /// @inheritdoc IUniswapV3StandardExchangeLiquidReserve
    function deployedReserve() external view returns (uint256 amount0, uint256 amount1) {
        return _deployedAmounts();
    }

    /// @inheritdoc IUniswapV3StandardExchangeLiquidReserve
    function targetLiquidReservePercentage() external view returns (uint256) {
        return _liveLiquidReservePercentage();
    }

    /// @inheritdoc IUniswapV3StandardExchangeLiquidReserve
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
     * @inheritdoc IUniswapV3StandardExchangeLiquidReserve
     * @dev Reverts when the bound pool is locked. Idle success when both tokens already within deadband.
     */
    function rebalanceLiquidReserve() external nonReentrant {
        _requireNotDisabled();
        _requireCanOpenBoundPoolOps();
        _rebalanceLiquidReserveInternal();
    }
}
