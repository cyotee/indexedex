// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {IStandardExchangeErrors} from "contracts/interfaces/IStandardExchangeErrors.sol";
import {UniswapV4FullSpreadHooklessStandardExchangeVaultRouteTypes as Types} from "./UniswapV4FullSpreadHooklessStandardExchangeVaultRouteTypes.sol";
import {UniswapV4FullSpreadHooklessStandardExchangeVaultInventoryMath as Inventory} from "./UniswapV4FullSpreadHooklessStandardExchangeVaultInventoryMath.sol";
import {UniswapV4FullSpreadHooklessStandardExchangeVaultTransitionPlanner as Planner} from "./UniswapV4FullSpreadHooklessStandardExchangeVaultTransitionPlanner.sol";


import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {LocalCreditLib} from "contracts/utils/LocalCreditLib.sol";
import {MultiAssetBasicVaultRepo} from "contracts/vaults/basic/MultiAssetBasicVaultRepo.sol";
import {
    UniswapV4FullSpreadHooklessStandardExchangeVaultOutBase
} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/UniswapV4FullSpreadHooklessStandardExchangeVaultOutBase.sol";

contract UniswapV4FullSpreadHooklessStandardExchangeVaultOutMultiTarget is UniswapV4FullSpreadHooklessStandardExchangeVaultOutBase {
    struct DualExitLocal {
        uint256 amount0;
        uint256 amount1;
        uint256 totalShares;
        uint256 sharesToBurn;
        uint256 delivered;
        Types.Placement placement;
    }

    function exchangeOutOneToMany(
        IERC20 tokenIn,
        uint256 maxAmountIn,
        address[] calldata tokensOut,
        uint256[] calldata amountsOut,
        address recipient,
        bool pretransferred,
        uint256 deadline
    ) external nonReentrant operationScope returns (uint256 amountIn) {
        if (deadline < block.timestamp) revert UniswapV4ExchangeOut_DeadlineExceeded();
        if (address(tokenIn) != address(this) || !_isDualPoolCurrencies(tokensOut) || !_dualAmountsPositive(amountsOut)) {
            revert IStandardExchangeOut.ExchangeOutNotAvailable();
        }
        DualExitLocal memory quoted = _quoteDualExit(tokenIn, maxAmountIn, tokensOut, amountsOut);
        uint256 pullAmount = quoted.sharesToBurn;
        if (pretransferred) {
            pullAmount = _pretransferCredit(IERC20(address(this)), maxAmountIn);
            if (quoted.sharesToBurn > pullAmount) {
                revert ISecurePullErrors.TransferDeltaInsufficient(quoted.sharesToBurn, pullAmount);
            }
        }
        uint256 delivered = _secureShareDelivery(pullAmount, pretransferred);
        DualExitLocal memory state = _quoteDualExit(tokenIn, maxAmountIn, tokensOut, amountsOut);
        _requireDelivered(state.sharesToBurn, delivered);
        state.delivered = delivered;
        if (!canOpenPoolManagerUnlock()) {
            _payBlockedDualExit(state, recipient, pretransferred);
            _pokeBoundPoolTwap();
            return state.sharesToBurn;
        }
        _payIdleDualExit(state, recipient, pretransferred);
        _pokeBoundPoolTwap();
        return state.sharesToBurn;
    }

    function _quoteDualExit(IERC20 tokenIn, uint256 maxAmountIn, address[] calldata tokensOut, uint256[] calldata amountsOut)
        internal view returns (DualExitLocal memory state)
    {
        if (address(tokenIn) != address(this) || !_isDualPoolCurrencies(tokensOut) || !_dualAmountsPositive(amountsOut))
            revert IStandardExchangeOut.ExchangeOutNotAvailable();
        state.amount0 = amountsOut[0]; state.amount1 = amountsOut[1];
        state.totalShares = IERC20(address(this)).totalSupply();
        (state.sharesToBurn, state.placement) = _dualExitPlan(_snapshot(0, 0), state.amount0, state.amount1);
        if (state.sharesToBurn > maxAmountIn) revert UniswapV4ExchangeOut_InsufficientInput();
    }

    function _payBlockedDualExit(DualExitLocal memory state, address recipient, bool pretransferred) internal {
        uint256 free0 = _localBalance(_token0());
        uint256 free1 = _localBalance(_token1());
        if (free0 < state.amount0) {
            revert UniswapV4Exchange_InsufficientLocalReserve(_token0(), state.amount0, free0);
        }
        if (free1 < state.amount1) {
            revert UniswapV4Exchange_InsufficientLocalReserve(_token1(), state.amount1, free1);
        }
        ERC20Repo._burn(address(this), state.sharesToBurn);
        if (pretransferred) {
            _refundUnusedShares(state.delivered, state.sharesToBurn, msg.sender);
        }
        _transferCurrency(_token0(), recipient, state.amount0);
        _transferCurrency(_token1(), recipient, state.amount1);
        _syncVaultReserves();
    }

    function _payIdleDualExit(DualExitLocal memory state, address recipient, bool pretransferred) internal {
        _commitExecutionPlan(keccak256(abi.encode(state, _snapshot(0, 0))), state.amount0, state.amount1);
        _collectManagedFeesIfIdle();
        // D3: idle dual exit uses PoolManager even if the sleeve would cover.
        _burnCenterLiquidityForShares(state.sharesToBurn, state.totalShares);
        uint256 bal0 = _localBalance(_token0());
        uint256 bal1 = _localBalance(_token1());
        if (bal0 < state.amount0) {
            revert UniswapV4Exchange_InsufficientOutput();
        }
        if (bal1 < state.amount1) {
            revert UniswapV4Exchange_InsufficientOutput();
        }
        ERC20Repo._burn(address(this), state.sharesToBurn);
        if (pretransferred) {
            _refundUnusedShares(state.delivered, state.sharesToBurn, msg.sender);
        }
        _transferCurrency(_token0(), recipient, state.amount0);
        _transferCurrency(_token1(), recipient, state.amount1);
        _syncVaultReserves();
        if (state.placement.certified) {
            _commitExecutionPlan(keccak256(abi.encode(state.placement)), 0, 0);
            _executePlacement(state.placement);
            _verifyState(state.placement.afterState);
        }
        _syncVaultReserves();
    }
}
