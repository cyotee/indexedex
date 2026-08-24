// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ONE_WAD} from "@crane/contracts/constants/Constants.sol";
import {ReentrancyLockModifiers} from "@crane/contracts/access/reentrancy/ReentrancyLockModifiers.sol";

import {
    IUniswapV4StandardExchangeLiquidReserve
} from "contracts/protocols/dexes/uniswap/v4/interfaces/IUniswapV4StandardExchangeLiquidReserve.sol";
import {
    IUniswapV4MultiPoolTwapOracle
} from "contracts/oracles/uniswap/v4/twap/interfaces/IUniswapV4MultiPoolTwapOracle.sol";
import {
    UniswapV4StandardExchangeCommon
} from "contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeCommon.sol";

/**
 * @title UniswapV4StandardExchangeLiquidReserveTarget
 * @notice Public liquid-sleeve views and permissionless rebalance (D10).
 */
contract UniswapV4StandardExchangeLiquidReserveTarget is
    UniswapV4StandardExchangeCommon,
    ReentrancyLockModifiers,
    IUniswapV4StandardExchangeLiquidReserve
{
    /// @inheritdoc IUniswapV4StandardExchangeLiquidReserve
    function canOpenPoolManagerUnlock()
        public
        view
        override(UniswapV4StandardExchangeCommon, IUniswapV4StandardExchangeLiquidReserve)
        returns (bool)
    {
        return UniswapV4StandardExchangeCommon.canOpenPoolManagerUnlock();
    }

    /// @inheritdoc IUniswapV4StandardExchangeLiquidReserve
    function twapOracle()
        public
        view
        override(UniswapV4StandardExchangeCommon, IUniswapV4StandardExchangeLiquidReserve)
        returns (IUniswapV4MultiPoolTwapOracle)
    {
        return UniswapV4StandardExchangeCommon.twapOracle();
    }

    /// @inheritdoc IUniswapV4StandardExchangeLiquidReserve
    function localReserve(address token) external view returns (uint256) {
        if (token == _token0()) {
            return IERC20(token).balanceOf(address(this));
        }
        if (token == _token1()) {
            return IERC20(token).balanceOf(address(this));
        }
        return 0;
    }

    /// @inheritdoc IUniswapV4StandardExchangeLiquidReserve
    function deployedReserve() external view returns (uint256 amount0, uint256 amount1) {
        return _deployedAmounts();
    }

    /// @inheritdoc IUniswapV4StandardExchangeLiquidReserve
    function targetLiquidReservePercentage() external view returns (uint256) {
        return _liveLiquidReservePercentage();
    }

    /// @inheritdoc IUniswapV4StandardExchangeLiquidReserve
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
     * @inheritdoc IUniswapV4StandardExchangeLiquidReserve
     * @dev Reverts when blocked. Idle success when both tokens already within deadband (no unlock).
     *      Does not move ticks. Non-imported deployed book is full-range (D30); sleeve is lock-safe free inventory.
     */
    function rebalanceLiquidReserve() external nonReentrant {
        _requireNotDisabled();
        _requireCanOpenPoolManagerUnlock();
        _rebalanceLiquidReserveInternal();
        _pokeBoundPoolTwap();
    }
}
