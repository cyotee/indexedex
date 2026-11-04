// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {IUnlockCallback} from
    "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/callback/IUnlockCallback.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {SwapParams} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";
import {
    TestBase_UniswapV4StandardExchangeBalancerQuadStableBufferHook
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/TestBase_UniswapV4StandardExchangeBalancerQuadStableBufferHook.sol";

/**
 * @notice APEX-2026-006 — `beforeSwap` on the balancer quad-stable buffer hook is the only
 *         hook entrypoint in its file without `_onlyPoolManager()`. Its siblings
 *         `beforeAddLiquidity`, `beforeRemoveLiquidity` and `beforeDonate` all have it, and
 *         11 of the 12 hooks in the codebase guard `beforeSwap`.
 *
 *         Two questions, measured rather than asserted:
 *           A) does a direct EOA call get anywhere?  (expected: no — `_take`/`_settle` are
 *              `onlyWhenUnlocked` on the PoolManager, so the frame reverts atomically)
 *           B) does it get anywhere from inside an ATTACKER-OPENED unlock context?
 *              `PoolManager.unlock()` is permissionless, so this is reachable by anyone.
 */
contract BeforeSwapUnlockAttacker is IUnlockCallback {
    IPoolManager public immutable pm;
    address public immutable hook;
    bool public callSucceeded;
    bytes public returnedOrRevert;

    constructor(IPoolManager pm_, address hook_) { pm = pm_; hook = hook_; }

    function attack(PoolKey memory key, SwapParams memory params) external {
        pm.unlock(abi.encode(key, params));
    }

    function unlockCallback(bytes calldata data) external returns (bytes memory) {
        require(msg.sender == address(pm), "only pm");
        (PoolKey memory key, SwapParams memory params) = abi.decode(data, (PoolKey, SwapParams));
        (bool ok, bytes memory ret) = hook.call(
            abi.encodeWithSelector(IHooks.beforeSwap.selector, address(this), key, params, bytes(""))
        );
        callSucceeded = ok;
        returnedOrRevert = ret;
        // Deliberately do not settle: we only need to learn whether the hook accepted the
        // call. Revert so no state is committed either way.
        revert("probe-complete");
    }
}

contract ApexUnguardedBeforeSwap is TestBase_UniswapV4StandardExchangeBalancerQuadStableBufferHook {
    address internal attacker = address(0xA77ACC);

    function setUp() public override {
        super.setUp();
        _seedFullBook(10_000 ether);
    }

    function _params() internal pure returns (SwapParams memory) {
        return SwapParams({
            zeroForOne: true,
            amountSpecified: -int256(1 ether),
            sqrtPriceLimitX96: 0
        });
    }

    /// @notice A) direct EOA call — should not get through the PoolManager lock.
    function test_apex006_directCallFromEoa() public {
        vm.prank(attacker);
        (bool ok, bytes memory ret) = hook.call(
            abi.encodeWithSelector(IHooks.beforeSwap.selector, attacker, poolKey01, _params(), bytes(""))
        );
        emit log_named_string("direct call succeeded", ok ? "YES" : "no");
        if (!ok) emit log_named_bytes("revert data", ret);
        assertFalse(ok, "direct EOA call must not succeed");
        emit log_string("=> guard absent, but PoolManager lock stops a naive direct call");
    }

    /// @notice B) the path that matters: attacker opens their own unlock, then calls in.
    function test_apex006_callFromAttackerOpenedUnlock() public {
        BeforeSwapUnlockAttacker atk = new BeforeSwapUnlockAttacker(pm, hook);
        vm.prank(attacker);
        try atk.attack(poolKey01, _params()) {
            emit log_string("unlock returned without revert (unexpected for a probe)");
        } catch {
            // expected: the probe reverts to avoid committing state
        }
        bool ok = atk.callSucceeded();
        emit log_named_string("beforeSwap accepted inside attacker unlock", ok ? "YES" : "no");
        if (!ok) emit log_named_bytes("revert data", atk.returnedOrRevert());

        if (ok) {
            emit log_string("CONFIRMED: unguarded beforeSwap is callable by an arbitrary actor");
            emit log_string("           inside a permissionless unlock context.");
        } else {
            emit log_string("NOT REACHABLE: some other check rejected the call");
        }
    }
}
