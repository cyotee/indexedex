// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {IUnlockCallback} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/callback/IUnlockCallback.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {BalanceDelta} from "@crane/contracts/protocols/dexes/uniswap/v4/types/BalanceDelta.sol";
import {ModifyLiquidityParams, SwapParams} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {StandardExchangeConstantProduct as ConstantProduct} from "../../../../../StandardExchangeConstantProduct.sol";
import {UniswapV4FullSpreadHooklessStandardExchangeVaultRouteTypes as Types} from "../../UniswapV4FullSpreadHooklessStandardExchangeVaultRouteTypes.sol";
import {UniswapV4FullSpreadHooklessStandardExchangeVaultTransitionPlanner as Planner} from "../../UniswapV4FullSpreadHooklessStandardExchangeVaultTransitionPlanner.sol";

/// @notice Test-only settlement. Not a facet, package, or vault dispatch target.
contract UniswapV4FullSpreadHooklessStandardExchangeVaultAnalyticExecutor is IUnlockCallback {
    struct Settlement {
        BalanceDelta swapDelta;
        BalanceDelta feeDelta;
        BalanceDelta placementDelta;
        uint256 shares;
        uint256[2] contribution;
    }

    IPoolManager public manager;
    PoolKey public key;
    int24 public lower;
    int24 public upper;
    bool internal callbackActive;

    function bind(IPoolManager manager_, PoolKey memory key_, int24 lower_, int24 upper_) external {
        manager = manager_;
        key = key_;
        lower = lower_;
        upper = upper_;
    }

    function open(int256 liquidity_) external returns (BalanceDelta) {
        return _unlock(abi.encode(uint8(0), liquidity_, int256(0), false));
    }

    /// @dev Exact-input V4 amountSpecified is negative. Expected numbers are not taken from `_plan`.
    function settle(uint256 swapIn_, bool zeroForOne_, Types.Snapshot memory state_, uint256 credit_)
        external returns (Settlement memory settlement_)
    {
        settlement_.swapDelta = _unlock(abi.encode(uint8(1), int256(0), -int256(swapIn_), zeroForOne_));
        settlement_.feeDelta = _unlock(abi.encode(uint8(0), int256(0), int256(0), false));
        uint256 input = zeroForOne_ ? 0 : 1;
        int128 inputDelta = zeroForOne_ ? settlement_.swapDelta.amount0() : settlement_.swapDelta.amount1();
        int128 outputDelta = zeroForOne_ ? settlement_.swapDelta.amount1() : settlement_.swapDelta.amount0();
        settlement_.contribution[input] = credit_ - uint256(uint128(-inputDelta));
        settlement_.contribution[1 - input] = uint256(uint128(outputDelta));
        state_.book.free[input] += settlement_.contribution[input];
        state_.book.free[1 - input] += settlement_.contribution[1 - input];
        Types.Placement memory placement = Planner._safePlacement(state_);
        settlement_.placementDelta = _unlock(abi.encode(uint8(0), placement.liquidityDelta, int256(0), false));
        for (uint256 i; i < 2; ++i) {
            if (placement.liquidityDelta > 0) settlement_.contribution[i] -= placement.roundingLoss[i];
        }
        settlement_.shares = ConstantProduct._sharesForDeposit(
            settlement_.contribution[0], settlement_.contribution[1], state_.book.supply,
            state_.book.free[0] + state_.book.deployed[0], state_.book.free[1] + state_.book.deployed[1]
        );
    }

    function unlockCallback(bytes calldata data_) external returns (bytes memory) {
        require(msg.sender == address(manager) && callbackActive, "unexpected callback");
        (uint8 kind, int256 liquidity, int256 amount, bool zeroForOne) = abi.decode(data_, (uint8, int256, int256, bool));
        BalanceDelta delta;
        if (kind == 0) {
            (delta,) = manager.modifyLiquidity(key, ModifyLiquidityParams(lower, upper, liquidity, bytes32(0)), "");
        } else {
            delta = manager.swap(key, SwapParams(zeroForOne, amount, zeroForOne ? TickMath.MIN_SQRT_PRICE + 1 : TickMath.MAX_SQRT_PRICE - 1), "");
        }
        _settle(key.currency0, delta.amount0());
        _settle(key.currency1, delta.amount1());
        return abi.encode(delta);
    }

    function _unlock(bytes memory data_) internal returns (BalanceDelta delta_) {
        callbackActive = true;
        delta_ = abi.decode(manager.unlock(data_), (BalanceDelta));
        callbackActive = false;
    }

    function _settle(Currency currency_, int128 delta_) internal {
        if (delta_ < 0) {
            manager.sync(currency_);
            IERC20(Currency.unwrap(currency_)).transfer(address(manager), uint128(-delta_));
            manager.settle();
        } else if (delta_ > 0) manager.take(currency_, address(this), uint128(delta_));
    }
}
