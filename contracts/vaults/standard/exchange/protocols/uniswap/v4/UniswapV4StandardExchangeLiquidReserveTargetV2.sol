// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ONE_WAD} from "@crane/contracts/constants/Constants.sol";
import {ReentrancyLockModifiers} from "@crane/contracts/access/reentrancy/ReentrancyLockModifiers.sol";

import {
    IUniswapV4StandardExchangeLiquidReserveV2
} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/interfaces/IUniswapV4StandardExchangeLiquidReserveV2.sol";
import {
    IUniswapV4MultiPoolTwapOracle
} from "contracts/oracles/uniswap/v4/twap/interfaces/IUniswapV4MultiPoolTwapOracle.sol";
import {
    UniswapV4StandardExchangeCommonV2
} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/UniswapV4StandardExchangeCommonV2.sol";

/**
 * @title UniswapV4StandardExchangeLiquidReserveTargetV2
 * @notice Public liquid-sleeve views and permissionless rebalance (D10).
 */
contract UniswapV4StandardExchangeLiquidReserveTargetV2 is
    UniswapV4StandardExchangeCommonV2,
    ReentrancyLockModifiers,
    IUniswapV4StandardExchangeLiquidReserveV2
{
    /// @inheritdoc IUniswapV4StandardExchangeLiquidReserveV2
    function canOpenPoolManagerUnlock()
        public
        view
        override(UniswapV4StandardExchangeCommonV2, IUniswapV4StandardExchangeLiquidReserveV2)
        returns (bool)
    {
        return UniswapV4StandardExchangeCommonV2.canOpenPoolManagerUnlock();
    }

    /// @inheritdoc IUniswapV4StandardExchangeLiquidReserveV2
    function twapOracle()
        public
        view
        override(UniswapV4StandardExchangeCommonV2, IUniswapV4StandardExchangeLiquidReserveV2)
        returns (IUniswapV4MultiPoolTwapOracle)
    {
        return UniswapV4StandardExchangeCommonV2.twapOracle();
    }

    /// @inheritdoc IUniswapV4StandardExchangeLiquidReserveV2
    function localReserve(address token) external view returns (uint256) {
        if (token == _token0()) {
            return IERC20(token).balanceOf(address(this));
        }
        if (token == _token1()) {
            return IERC20(token).balanceOf(address(this));
        }
        return 0;
    }

    /// @inheritdoc IUniswapV4StandardExchangeLiquidReserveV2
    function deployedReserve() external view returns (uint256 amount0, uint256 amount1) {
        return _deployedAmounts();
    }

    /// @inheritdoc IUniswapV4StandardExchangeLiquidReserveV2
    function targetLiquidReservePercentage() external view returns (uint256) {
        return _liveLiquidReservePercentage();
    }

    /// @inheritdoc IUniswapV4StandardExchangeLiquidReserveV2
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
     * @inheritdoc IUniswapV4StandardExchangeLiquidReserveV2
     * @dev Reverts when blocked. Idle success when both tokens already within deadband (no unlock).
     *      Does not move ticks. Non-imported deployed book is full-range (D30); sleeve is lock-safe free inventory.
     */
    function rebalanceLiquidReserve() external nonReentrant inputOperation {
        _requireNotDisabled();
        _requireCanOpenPoolManagerUnlock();
        _rebalanceLiquidReserveInternal();
        _pokeBoundPoolTwap();
    }
}
