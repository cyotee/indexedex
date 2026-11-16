// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";

import {
    IBalancerV3StandardExchangeRouterPrepay
} from "contracts/interfaces/IBalancerV3StandardExchangeRouterPrepay.sol";
import {
    TestBase_BalancerV3StandardExchangeRouter
} from "contracts/protocols/dexes/balancer/v3/routers/TestBase_BalancerV3StandardExchangeRouter.sol";
import {
    Handler_BalancerV3SERouter_PrepayAuth
} from "test/foundry/spec/protocol/dexes/balancer/v3/routers/invariant/Handler_BalancerV3SERouter_PrepayAuth.sol";

/**
 * @title BalancerV3StandardExchangeRouter_PrepayAuth_Invariant
 * @notice L3 invariants + combined adversarial-weighted handler campaign.
 *
 * @dev I-AUTH-COUNT: unauthorizedPrepaySuccesses == 0
 *      I-SESSION: session inactive and depth 0 between handler calls
 *      Combined: handler mixes swaps + attack attempts (see Handler weights via selector targeting).
 */
contract BalancerV3StandardExchangeRouter_PrepayAuth_Invariant_Test is TestBase_BalancerV3StandardExchangeRouter {
    Handler_BalancerV3SERouter_PrepayAuth internal handler;
    IBalancerV3StandardExchangeRouterPrepay internal prepayRouter;
    address internal attacker;

    function setUp() public override {
        super.setUp();
        prepayRouter = IBalancerV3StandardExchangeRouterPrepay(address(seRouter));
        attacker = makeAddr("attacker");
        (IERC20 t0, IERC20 t1) = _getPoolTokens(daiUsdcPool);
        handler = new Handler_BalancerV3SERouter_PrepayAuth(
            address(seRouter), daiUsdcPool, t0, t1, permit2, alice, attacker
        );

        targetContract(address(handler));
        bytes4[] memory selectors = new bytes4[](4);
        selectors[0] = Handler_BalancerV3SERouter_PrepayAuth.swapExactIn_direct.selector;
        selectors[1] = Handler_BalancerV3SERouter_PrepayAuth.attemptPrepay_asAttacker.selector;
        selectors[2] = Handler_BalancerV3SERouter_PrepayAuth.attemptPass_asAttacker.selector;
        selectors[3] = Handler_BalancerV3SERouter_PrepayAuth.donateToVault.selector;
        targetSelector(FuzzSelector({addr: address(handler), selectors: selectors}));
    }

    /// @dev I-AUTH-COUNT
    function invariant_I_AUTH_COUNT_noUnauthorizedPrepaySuccess() public view {
        assertEq(handler.unauthorizedPrepaySuccesses(), 0, "I-AUTH-COUNT: unauthorized prepay succeeded");
        assertEq(handler.unauthorizedPassSuccesses(), 0, "I-AUTH-COUNT: unauthorized pass while session on");
    }

    /// @dev I-SESSION
    function invariant_I_SESSION_inactiveBetweenCalls() public view {
        assertFalse(prepayRouter.prepaySessionActive(), "I-SESSION: session leaked between handler calls");
        assertEq(prepayRouter.prepayAuthDepth(), 0, "I-SESSION: stack non-empty between handler calls");
    }
}
