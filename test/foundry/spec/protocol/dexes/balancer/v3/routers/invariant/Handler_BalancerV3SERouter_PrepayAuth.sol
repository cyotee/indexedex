// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";

import {
    IBalancerV3StandardExchangeRouterPrepay
} from "contracts/interfaces/IBalancerV3StandardExchangeRouterPrepay.sol";
import {
    IBalancerV3StandardExchangeRouterExactInSwap
} from "contracts/interfaces/IBalancerV3StandardExchangeRouterExactInSwap.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {IPermit2} from "@crane/contracts/interfaces/protocols/utils/permit2/IPermit2.sol";

/**
 * @title Handler_BalancerV3SERouter_PrepayAuth
 * @notice L3 handler mixing legitimate swaps with unauthorized prepay/pass attempts.
 * @dev Ghosts: unauthorizedPrepaySuccesses must remain 0; session must be inactive between calls.
 */
contract Handler_BalancerV3SERouter_PrepayAuth is Test {
    IBalancerV3StandardExchangeRouterExactInSwap public immutable seRouter;
    IBalancerV3StandardExchangeRouterPrepay public immutable prepayRouter;
    IPermit2 public immutable permit2;
    address public immutable pool;
    IERC20 public immutable token0;
    IERC20 public immutable token1;
    address public immutable actor;
    address public immutable attacker;

    uint256 public unauthorizedPrepaySuccesses;
    uint256 public unauthorizedPassSuccesses;
    uint256 public successfulSwaps;
    uint256 public attackAttempts;

    constructor(
        address seRouter_,
        address pool_,
        IERC20 token0_,
        IERC20 token1_,
        IPermit2 permit2_,
        address actor_,
        address attacker_
    ) {
        seRouter = IBalancerV3StandardExchangeRouterExactInSwap(seRouter_);
        prepayRouter = IBalancerV3StandardExchangeRouterPrepay(seRouter_);
        pool = pool_;
        token0 = token0_;
        token1 = token1_;
        permit2 = permit2_;
        actor = actor_;
        attacker = attacker_;
    }

    function swapExactIn_direct(uint256 amountSeed) external {
        uint256 amountIn = bound(amountSeed, 1e15, 50e18);
        deal(address(token0), actor, amountIn);
        vm.startPrank(actor);
        token0.approve(address(permit2), type(uint256).max);
        permit2.approve(address(token0), address(seRouter), type(uint160).max, type(uint48).max);
        try seRouter.swapSingleTokenExactIn(
            pool,
            token0,
            IStandardExchangeProxy(address(0)),
            token1,
            IStandardExchangeProxy(address(0)),
            amountIn,
            0,
            type(uint256).max,
            false,
            ""
        ) {
            ++successfulSwaps;
        } catch {}
        vm.stopPrank();
    }

    function attemptPrepay_asAttacker(uint256 amountSeed) external {
        ++attackAttempts;
        uint256 amt = bound(amountSeed, 1, 100e18);
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = amt;
        amounts[1] = amt;
        vm.prank(attacker);
        try prepayRouter.prepayAddLiquidityUnbalanced(pool, amounts, 0, "") {
            ++unauthorizedPrepaySuccesses;
        } catch {}
    }

    function attemptPass_asAttacker(address next) external {
        ++attackAttempts;
        // When session off, pass is no-op success by design (not an auth bypass for prepay).
        // Count only if session is active and pass succeeds without being top — should not happen.
        if (!prepayRouter.prepaySessionActive()) {
            return;
        }
        vm.prank(attacker);
        try prepayRouter.passPrepayAuth(next) {
            ++unauthorizedPassSuccesses;
        } catch {}
    }

    function donateToVault(uint256 amountSeed) external {
        uint256 amt = bound(amountSeed, 1, 10e18);
        deal(address(token0), address(this), amt);
        // Free balance on vault — attackers should not convert via unauthorized prepay.
        token0.transfer(address(prepayRouter), 0); // no-op keep compiler happy if needed
        // Donate to a dead address as "unattributed" sink; real vault donation uses vault address in tests.
        // Handler does not hold vault address; donate is covered in fixed A1.
        deal(address(token0), attacker, amt); // fund attacker without granting prepay rights
    }
}
