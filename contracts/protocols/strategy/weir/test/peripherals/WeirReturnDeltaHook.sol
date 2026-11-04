// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {Currency, CurrencyLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {BalanceDelta, toBalanceDelta} from "@crane/contracts/protocols/dexes/uniswap/v4/types/BalanceDelta.sol";
import {BeforeSwapDelta, toBeforeSwapDelta} from "@crane/contracts/protocols/dexes/uniswap/v4/types/BeforeSwapDelta.sol";
import {ModifyLiquidityParams, SwapParams} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";
import {IERC20} from "@crane/contracts/external/openzeppelin-contracts-v5/token/ERC20/IERC20.sol";

/// @notice Return-delta hook that settles its own resulting delta inside the callback.
contract WeirReturnDeltaHook is IHooks {
    using CurrencyLibrary for Currency;

    struct Plan {
        bool enabled;
        int128 delta0;
        int128 delta1;
    }

    IPoolManager public immutable poolManager;
    Plan public addPlan;
    Plan public removePlan;
    int128 public seenCaller0;
    int128 public seenFees0;
    int128 public seenHook0;

    constructor(IPoolManager manager) {
        poolManager = manager;
    }

    receive() external payable {}

    function setAddPlan(bool enabled, int128 delta0, int128 delta1) external {
        addPlan = Plan(enabled, delta0, delta1);
    }

    function setRemovePlan(bool enabled, int128 delta0, int128 delta1) external {
        removePlan = Plan(enabled, delta0, delta1);
    }

    function beforeInitialize(address, PoolKey calldata, uint160) external pure returns (bytes4) {
        return IHooks.beforeInitialize.selector;
    }

    function afterInitialize(address, PoolKey calldata, uint160, int24) external pure returns (bytes4) {
        return IHooks.afterInitialize.selector;
    }

    function beforeAddLiquidity(address, PoolKey calldata, ModifyLiquidityParams calldata, bytes calldata)
        external
        pure
        returns (bytes4)
    {
        return IHooks.beforeAddLiquidity.selector;
    }

    function afterAddLiquidity(
        address,
        PoolKey calldata key,
        ModifyLiquidityParams calldata,
        BalanceDelta delta,
        BalanceDelta feesAccrued,
        bytes calldata
    ) external returns (bytes4, BalanceDelta) {
        seenCaller0 = delta.amount0();
        seenFees0 = feesAccrued.amount0();
        if (!addPlan.enabled) return (IHooks.afterAddLiquidity.selector, toBalanceDelta(0, 0));
        BalanceDelta hookDelta = toBalanceDelta(addPlan.delta0, addPlan.delta1);
        seenHook0 = hookDelta.amount0();
        _offset(key, hookDelta);
        return (IHooks.afterAddLiquidity.selector, hookDelta);
    }

    function beforeRemoveLiquidity(address, PoolKey calldata, ModifyLiquidityParams calldata, bytes calldata)
        external
        pure
        returns (bytes4)
    {
        return IHooks.beforeRemoveLiquidity.selector;
    }

    function afterRemoveLiquidity(
        address,
        PoolKey calldata key,
        ModifyLiquidityParams calldata,
        BalanceDelta,
        BalanceDelta,
        bytes calldata
    ) external returns (bytes4, BalanceDelta) {
        if (!removePlan.enabled) return (IHooks.afterRemoveLiquidity.selector, toBalanceDelta(0, 0));
        BalanceDelta hookDelta = toBalanceDelta(removePlan.delta0, removePlan.delta1);
        _offset(key, hookDelta);
        return (IHooks.afterRemoveLiquidity.selector, hookDelta);
    }

    function beforeSwap(address, PoolKey calldata, SwapParams calldata, bytes calldata)
        external
        pure
        returns (bytes4, BeforeSwapDelta, uint24)
    {
        return (IHooks.beforeSwap.selector, toBeforeSwapDelta(0, 0), 0);
    }

    function afterSwap(address, PoolKey calldata, SwapParams calldata, BalanceDelta, bytes calldata)
        external
        pure
        returns (bytes4, int128)
    {
        return (IHooks.afterSwap.selector, 0);
    }

    function beforeDonate(address, PoolKey calldata, uint256, uint256, bytes calldata) external pure returns (bytes4) {
        return IHooks.beforeDonate.selector;
    }

    function afterDonate(address, PoolKey calldata, uint256, uint256, bytes calldata) external pure returns (bytes4) {
        return IHooks.afterDonate.selector;
    }

    function _offset(PoolKey calldata key, BalanceDelta hookDelta) internal {
        _one(key.currency0, hookDelta.amount0());
        _one(key.currency1, hookDelta.amount1());
    }

    function _one(Currency currency, int128 net) internal {
        if (net > 0) {
            poolManager.take(currency, address(this), uint256(uint128(net)));
        } else if (net < 0) {
            uint256 owed = uint256(uint128(-net));
            if (currency.isAddressZero()) {
                poolManager.settle{value: owed}();
            } else {
                poolManager.sync(currency);
                IERC20(Currency.unwrap(currency)).transfer(address(poolManager), owed);
                poolManager.settle();
            }
        }
    }
}
