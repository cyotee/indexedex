// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {
    UniswapV4StandardExchangeOutBase
} from "contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeOutBase.sol";

contract UniswapV4StandardExchangeOutMultiTarget is UniswapV4StandardExchangeOutBase {
    struct DualExitLocal {
        uint256 amount0;
        uint256 amount1;
        uint256 totalShares;
        uint256 sharesToBurn;
        uint256 delivered;
    }

    function exchangeOutOneToMany(
        IERC20 tokenIn,
        uint256 maxAmountIn,
        address[] calldata tokensOut,
        uint256[] calldata amountsOut,
        address recipient,
        bool pretransferred,
        uint256 deadline
    ) external nonReentrant returns (uint256 amountIn) {
        _requireNotDisabled();
        if (deadline < block.timestamp) revert UniswapV4ExchangeOut_DeadlineExceeded();
        DualExitLocal memory state = _quoteDualExit(tokenIn, maxAmountIn, tokensOut, amountsOut);
        state.delivered = _secureShareDelivery(maxAmountIn, pretransferred);
        if (!canOpenPoolManagerUnlock()) {
            _payBlockedDualExit(state, recipient);
            _pokeBoundPoolTwap();
            return state.sharesToBurn;
        }
        _payIdleDualExit(state, recipient);
        _pokeBoundPoolTwap();
        return state.sharesToBurn;
    }

    function _quoteDualExit(
        IERC20 tokenIn,
        uint256 maxAmountIn,
        address[] calldata tokensOut,
        uint256[] calldata amountsOut
    ) internal view returns (DualExitLocal memory state) {
        if (address(tokenIn) != address(this) || !_isDualPoolCurrencies(tokensOut) || !_dualAmountsPositive(amountsOut))
        {
            revert IStandardExchangeOut.ExchangeOutNotAvailable();
        }
        state.amount0 = amountsOut[0];
        state.amount1 = amountsOut[1];
        state.totalShares = IERC20(address(this)).totalSupply();
        (uint256 total0, uint256 total1) = _totalVaultReserves();
        (uint256 s0, uint256 s1) =
            _dualExitShareBurns(state.amount0, state.amount1, total0, total1, state.totalShares);
        if (s0 != s1) {
            revert IStandardExchangeOut.ExchangeOutNotAvailable();
        }
        if (s0 > maxAmountIn) {
            revert UniswapV4ExchangeOut_InsufficientInput();
        }
        state.sharesToBurn = s0;
    }

    function _payBlockedDualExit(DualExitLocal memory state, address recipient) internal {
        uint256 free0 = IERC20(_token0()).balanceOf(address(this));
        uint256 free1 = IERC20(_token1()).balanceOf(address(this));
        if (free0 < state.amount0) {
            revert UniswapV4Exchange_InsufficientLocalReserve(_token0(), state.amount0, free0);
        }
        if (free1 < state.amount1) {
            revert UniswapV4Exchange_InsufficientLocalReserve(_token1(), state.amount1, free1);
        }
        ERC20Repo._burn(address(this), state.sharesToBurn);
        _refundUnusedShares(state.delivered, state.sharesToBurn, msg.sender);
        _transferCurrency(_token0(), recipient, state.amount0);
        _transferCurrency(_token1(), recipient, state.amount1);
        _syncVaultReserves();
    }

    function _payIdleDualExit(DualExitLocal memory state, address recipient) internal {
        // D3: idle dual exit uses PoolManager even if the sleeve would cover.
        _burnCenterLiquidityForShares(state.sharesToBurn, state.totalShares);
        _refreshStoredLiquidity();
        uint256 bal0 = IERC20(_token0()).balanceOf(address(this));
        uint256 bal1 = IERC20(_token1()).balanceOf(address(this));
        if (bal0 < state.amount0) {
            revert UniswapV4Exchange_InsufficientOutput();
        }
        if (bal1 < state.amount1) {
            revert UniswapV4Exchange_InsufficientOutput();
        }
        ERC20Repo._burn(address(this), state.sharesToBurn);
        _refundUnusedShares(state.delivered, state.sharesToBurn, msg.sender);
        _transferCurrency(_token0(), recipient, state.amount0);
        _transferCurrency(_token1(), recipient, state.amount1);
        _syncVaultReserves();
        _rebalanceLiquidReserveBestEffort();
    }
}
