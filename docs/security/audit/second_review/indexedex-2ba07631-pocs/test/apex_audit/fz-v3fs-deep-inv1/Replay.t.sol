// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {console2} from "forge-std/console2.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {V3FSFixture} from "./V3FSFixtureCopy.sol";

interface IRate { function exchangeRate() external view returns (uint256); }

contract ReplayDeepInv1 is V3FSFixture {
    function setUp() public override {
        super.setUp();
        h.setSandwichMask(0xf8);
        h.setHonestJoinAtBookRatio(false);
    }

    function _log(string memory tag) internal view {
        (uint256 r0, uint256 r1) = h.book();
        console2.log("=== after", tag);
        console2.log("  profit", h.attackerProfit());
        console2.log("  allowance", h.atkAllowance());
        console2.log("  skewAllowTot", h.skewAllowanceTotal());
        console2.log("  atkVal", h.valueOf(address(h.atk())));
        console2.log("  passiveVal", h.valueOf(address(h.passive())));
        console2.log("  hon0/1/2", h.valueOf(address(h.hon(0))), h.valueOf(address(h.hon(1))), h.valueOf(address(h.hon(2))));
        console2.log("  book r0/r1", r0, r1);
        console2.log("  S / atkSh", IERC20(address(vault)).totalSupply(), IERC20(address(vault)).balanceOf(address(h.atk())));
        console2.log("  rate", IRate(address(vault)).exchangeRate());
        console2.log("  atk t0/t1", IERC20(pool.token0()).balanceOf(address(h.atk())), IERC20(pool.token1()).balanceOf(address(h.atk())));
        console2.log("  pendingDon / unexplPL", h.pendingDonation() ? 1 : 0, h.unexplainedPassiveLoss());
    }

    function test_replay() public {
        _log("genesis");
        h.a_dualDeposit(9116, 65536, true); _log("1 a_dualDeposit");
        h.a_singleDeposit(3597075808, 1598653050, false, 20); _log("2 a_singleDeposit");
        h.a_singleDeposit(11391, 4294967295, false, 5343); _log("3 a_singleDeposit");
        h.a_donate(3429, 12791); _log("4 a_donate");
        h.h_dualDeposit(17, 1000000000000000000000000); _log("5 h_dualDeposit");
        h.a_syDeposit(10000, 2000); _log("6 a_syDeposit");
        h.a_syRedeemInternal(23446, 507); _log("7 a_syRedeemInternal");
        h.a_mintExactOut(264337247292056892107557765863231274529764461761558680744927113126014301973, 1424754830932723113572014995355094734951284697228594985502, true, 169182039051130134); _log("8 a_mintExactOut");
        h.a_mintExactOut(51551, 8556181810076920434953, false, 444720070199188493); _log("9 a_mintExactOut");
        h.a_sandwich(297, true, 4194304, 6772108004893480073632, 11082); _log("10 a_sandwich");
        console2.log("lastSub", uint256(h.lastSub()));
        (bool ok, int256 p, uint256 al) = h.checkNoFreeValue();
        console2.log("INV1 ok", ok);
        console2.log("profit-allow", p - int256(al));
    }
}
