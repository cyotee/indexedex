// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {console2} from "forge-std/console2.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {TestBase_EtherFiWeETHStandardExchange} from "contracts/test/bases/TestBase_EtherFiWeETHStandardExchange.sol";
import {IVaultRegistryDisableManager} from "contracts/interfaces/IVaultRegistryDisableManager.sol";
import {IVaultRegistryDisableQuery} from "contracts/interfaces/IVaultRegistryDisableQuery.sol";

contract EtherFiNoKill_Test is TestBase_EtherFiWeETHStandardExchange {
    address lp = makeAddr("honestLP");
    address user = makeAddr("postDisableUser");

    function _in(address who, uint256 amt) internal returns (uint256 s) {
        _dealWeth(who, amt);
        vm.startPrank(who);
        hermeticWeth.approve(seVault, amt);s = seIn.exchangeIn(IERC20(address(hermeticWeth)), amt, IERC20(seVault), 0, who, false, block.timestamp + 1);
        vm.stopPrank();
    }

    function test_killSwitchIgnored() public {
        _in(lp, 100 ether);
        IVaultRegistryDisableManager dm = IVaultRegistryDisableManager(address(indexedexManager));
        IVaultRegistryDisableQuery dq = IVaultRegistryDisableQuery(address(indexedexManager));
        vm.startPrank(owner);
        dm.setVaultAddressDisabled(seVault, true);
        dm.setPackageDisabled(address(etherFiSeDFPkg), true);
        vm.stopPrank();
        assertTrue(dq.isDisabled(seVault), "registry says disabled");

        // Inbound exchangeIn after disable (unprivileged user)
        uint256 s = _in(user, 10 ether);
        console2.log("shares minted after disable (exchangeIn)", s);
        assertGt(s, 0, "exchangeIn not blocked");

        // Inbound exchangeOut (exact-out mint) after disable
        _dealWeth(user, 10 ether);
        vm.startPrank(user);
        hermeticWeth.approve(seVault, 10 ether);
        uint256 paid = seOut.exchangeOut(IERC20(address(hermeticWeth)), 10 ether, IERC20(seVault), 1 ether, user, false, block.timestamp + 1);
        vm.stopPrank();
        console2.log("WETH paid for 1e18 shares after disable (exchangeOut)", paid);
        assertGt(paid, 0, "exchangeOut not blocked");

    }
}
