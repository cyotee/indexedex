// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ONE_WAD} from "@crane/contracts/constants/Constants.sol";
import {ReentrancyLockModifiers} from "@crane/contracts/access/reentrancy/ReentrancyLockModifiers.sol";

import {
    IUniswapV4FullSpreadPonsFamilyHookLiquidReserve
} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/interfaces/IUniswapV4FullSpreadPonsFamilyHookLiquidReserve.sol";
import {
    IUniswapV4MultiPoolTwapOracle
} from "contracts/oracles/uniswap/v4/twap/interfaces/IUniswapV4MultiPoolTwapOracle.sol";
import {
    UniswapV4FullSpreadPonsFamilyHookCommon
} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/UniswapV4FullSpreadPonsFamilyHookCommon.sol";

/**
 * @title UniswapV4FullSpreadPonsFamilyHookLiquidReserveTarget
 * @notice Public liquid-sleeve views and permissionless rebalance (D10).
 */
contract UniswapV4FullSpreadPonsFamilyHookLiquidReserveTarget is
    UniswapV4FullSpreadPonsFamilyHookCommon,
    ReentrancyLockModifiers,
    IUniswapV4FullSpreadPonsFamilyHookLiquidReserve
{
    /// @inheritdoc IUniswapV4FullSpreadPonsFamilyHookLiquidReserve
    function canOpenPoolManagerUnlock()
        public
        view
        override(UniswapV4FullSpreadPonsFamilyHookCommon, IUniswapV4FullSpreadPonsFamilyHookLiquidReserve)
        returns (bool)
    {
        return UniswapV4FullSpreadPonsFamilyHookCommon.canOpenPoolManagerUnlock();
    }

    /// @inheritdoc IUniswapV4FullSpreadPonsFamilyHookLiquidReserve
    function twapOracle()
        public
        view
        override(UniswapV4FullSpreadPonsFamilyHookCommon, IUniswapV4FullSpreadPonsFamilyHookLiquidReserve)
        returns (IUniswapV4MultiPoolTwapOracle)
    {
        return UniswapV4FullSpreadPonsFamilyHookCommon.twapOracle();
    }

    /// @inheritdoc IUniswapV4FullSpreadPonsFamilyHookLiquidReserve
    function localReserve(address token) external view returns (uint256) {
        if (token == _token0()) {
            return _localBalance(token);
        }
        if (token == _token1()) {
            return _localBalance(token);
        }
        return 0;
    }

    /// @inheritdoc IUniswapV4FullSpreadPonsFamilyHookLiquidReserve
    function deployedReserve() external view returns (uint256 amount0, uint256 amount1) {
        return _deployedAmounts();
    }

    /// @inheritdoc IUniswapV4FullSpreadPonsFamilyHookLiquidReserve
    function targetLiquidReservePercentage() external view returns (uint256) {
        return _liveLiquidReservePercentage();
    }

    /// @inheritdoc IUniswapV4FullSpreadPonsFamilyHookLiquidReserve
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
     * @inheritdoc IUniswapV4FullSpreadPonsFamilyHookLiquidReserve
     * @dev Reverts when blocked. Idle success when both tokens already within deadband (no unlock).
     *      Does not move ticks. Non-imported deployed book is full-range (D30); sleeve is lock-safe free inventory.
     */
    /// @notice Permissionless sleeve maintenance; pays the caller nothing.
    /// @dev A zero target can leave locked exits without sufficient local reserve.
    function rebalanceLiquidReserve() external nonReentrant operationScope {
        _requireNotDisabled();
        _requireCanOpenPoolManagerUnlock();
        _rebalanceLiquidReserveInternal();
        _pokeBoundPoolTwap();
    }
    function executionProtectionBps() external pure returns (uint16, uint16, uint16, uint16, uint16) {
        return (REBALANCE_IMPACT_BPS, COMPOSITION_IMPACT_BPS, EXECUTION_SHORTFALL_BPS, DEPOSIT_ALIGNMENT_BPS, REPAIR_COMPOSITION_BPS);
    }
}
