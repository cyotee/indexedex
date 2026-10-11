// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {TestBase_UniswapV4StandardExchangeBalancerQuadStableBufferHook as TestBase} from
    "contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/TestBase_UniswapV4StandardExchangeBalancerQuadStableBufferHook.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {IUnlockCallback} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/callback/IUnlockCallback.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {SwapParams} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";

/// @dev Attacker caller only. PoolManager and hook are real production deployments.
contract BalancerQuadUnlockCaller is IUnlockCallback {
    IPoolManager internal immutable manager;

    constructor(IPoolManager manager_) { manager = manager_; }

    function attempt(address hook, PoolKey memory key) external returns (bytes memory) {
        return manager.unlock(abi.encode(hook, key));
    }

    function unlockCallback(bytes calldata data) external returns (bytes memory) {
        require(msg.sender == address(manager), "manager");
        (address hook, PoolKey memory key) = abi.decode(data, (address, PoolKey));
        SwapParams memory params = SwapParams({zeroForOne: true, amountSpecified: -1e18, sqrtPriceLimitX96: 0});
        (bool ok, bytes memory result) = hook.call(abi.encodeCall(IHooks.beforeSwap,
            (address(this), key, params, bytes(""))));
        return abi.encode(ok, result);
    }
}

contract UniswapV4StandardExchangeBalancerQuadStableBufferHook_Recurrence is TestBase {
    function test_recurrence_R10_attackerUnlockDoesNotGrantHookAuthority() public {
        _firstMintEqual(200 ether);
        uint256 supply = IERC20(hook).totalSupply();
        uint256 reserve0 = quad.nativeReserve(0);
        uint256 reserve1 = quad.nativeReserve(1);
        BalancerQuadUnlockCaller caller = new BalancerQuadUnlockCaller(IPoolManager(address(pm)));
        (bool ok, bytes memory result) = abi.decode(caller.attempt(hook, poolKey01), (bool, bytes));
        assertFalse(ok);
        assertEq(result, abi.encodeWithSignature("NotPoolManager()"));
        assertEq(IERC20(hook).totalSupply(), supply);
        assertEq(quad.nativeReserve(0), reserve0);
        assertEq(quad.nativeReserve(1), reserve1);
        assertGt(quad.previewSwapExactIn(address(token0), address(token1), 1 ether), 0,
            "funded route remains live after rejected attacker call");
        uint256 outputBefore = token1.balanceOf(user);
        _swapExactIn(address(token0), address(token1), 1 ether);
        assertGt(token1.balanceOf(user), outputBefore, "actual authorized manager callback succeeds");
    }
}
