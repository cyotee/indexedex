// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {BalanceDelta, toBalanceDelta} from "@crane/contracts/protocols/dexes/uniswap/v4/types/BalanceDelta.sol";
import {BeforeSwapDelta, toBeforeSwapDelta} from "@crane/contracts/protocols/dexes/uniswap/v4/types/BeforeSwapDelta.sol";
import {ModifyLiquidityParams, SwapParams} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";

contract WeirObserveHook is IHooks {
    struct Call {
        bytes4 selector;
        address sender;
        bytes hookData;
        int256 liquidityDelta;
    }

    IPoolManager public immutable poolManager;
    Call[] public calls;
    Currency public syncCurrency;
    bool public leaveSyncOpen;
    address public reenterTarget;
    bytes public reenterData;

    function setReenter(address target, bytes calldata data) external {
        reenterTarget = target;
        reenterData = data;
    }

    constructor(IPoolManager manager) {
        poolManager = manager;
    }

    function setLeaveSyncOpen(Currency currency, bool enabled) external {
        syncCurrency = currency;
        leaveSyncOpen = enabled;
    }

    function callCount() external view returns (uint256) {
        return calls.length;
    }

    function callAt(uint256 index) external view returns (Call memory) {
        return calls[index];
    }

    function beforeInitialize(address, PoolKey calldata, uint160) external returns (bytes4) {
        return IHooks.beforeInitialize.selector;
    }

    function afterInitialize(address, PoolKey calldata, uint160, int24) external returns (bytes4) {
        return IHooks.afterInitialize.selector;
    }

    function beforeAddLiquidity(address sender, PoolKey calldata, ModifyLiquidityParams calldata params, bytes calldata hookData)
        external
        returns (bytes4)
    {
        calls.push(Call(IHooks.beforeAddLiquidity.selector, sender, hookData, params.liquidityDelta));
        if (reenterTarget != address(0)) {
            (bool ok, bytes memory ret) = reenterTarget.call(reenterData);
            if (!ok) {
                assembly {
                    revert(add(ret, 0x20), mload(ret))
                }
            }
        }
        return IHooks.beforeAddLiquidity.selector;
    }

    function afterAddLiquidity(
        address sender,
        PoolKey calldata,
        ModifyLiquidityParams calldata params,
        BalanceDelta,
        BalanceDelta,
        bytes calldata hookData
    ) external returns (bytes4, BalanceDelta) {
        calls.push(Call(IHooks.afterAddLiquidity.selector, sender, hookData, params.liquidityDelta));
        if (leaveSyncOpen) poolManager.sync(syncCurrency);
        return (IHooks.afterAddLiquidity.selector, toBalanceDelta(0, 0));
    }

    function beforeRemoveLiquidity(address sender, PoolKey calldata, ModifyLiquidityParams calldata params, bytes calldata hookData)
        external
        returns (bytes4)
    {
        calls.push(Call(IHooks.beforeRemoveLiquidity.selector, sender, hookData, params.liquidityDelta));
        return IHooks.beforeRemoveLiquidity.selector;
    }

    function afterRemoveLiquidity(
        address sender,
        PoolKey calldata,
        ModifyLiquidityParams calldata params,
        BalanceDelta,
        BalanceDelta,
        bytes calldata hookData
    ) external returns (bytes4, BalanceDelta) {
        calls.push(Call(IHooks.afterRemoveLiquidity.selector, sender, hookData, params.liquidityDelta));
        return (IHooks.afterRemoveLiquidity.selector, toBalanceDelta(0, 0));
    }

    function beforeSwap(address sender, PoolKey calldata, SwapParams calldata params, bytes calldata hookData)
        external
        returns (bytes4, BeforeSwapDelta, uint24)
    {
        calls.push(Call(IHooks.beforeSwap.selector, sender, hookData, params.amountSpecified));
        return (IHooks.beforeSwap.selector, toBeforeSwapDelta(0, 0), 0);
    }

    function afterSwap(address sender, PoolKey calldata, SwapParams calldata, BalanceDelta, bytes calldata hookData)
        external
        returns (bytes4, int128)
    {
        calls.push(Call(IHooks.afterSwap.selector, sender, hookData, 0));
        return (IHooks.afterSwap.selector, 0);
    }

    function beforeDonate(address, PoolKey calldata, uint256, uint256, bytes calldata) external returns (bytes4) {
        return IHooks.beforeDonate.selector;
    }

    function afterDonate(address, PoolKey calldata, uint256, uint256, bytes calldata) external returns (bytes4) {
        return IHooks.afterDonate.selector;
    }
}
