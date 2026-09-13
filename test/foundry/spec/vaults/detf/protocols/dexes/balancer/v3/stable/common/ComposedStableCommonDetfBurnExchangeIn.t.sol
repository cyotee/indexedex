// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IDetfBondNFT} from "contracts/interfaces/IDetfBondNFT.sol";
import {IStakedDETF} from "contracts/interfaces/IStakedDETF.sol";
import {TestBase_ComposedFundedRoutes} from "contracts/test/bases/TestBase_ComposedFundedRoutes.sol";
import {
    ComposedStableCommonDetfRepo as Repo
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/ComposedStableCommonDetfRepo.sol";

contract ComposedStableCommonDetfBurnExchangeIn_Test is TestBase_ComposedFundedRoutes {
    function test_previewExchangeIn_selectsFundedEligibleExit() public {
        uint256 raw_ = _buyRaw(alice, 10e18);
        uint256 quote_ = composedIn.previewExchangeIn(IERC20(composedDetf), raw_ / 2, weth);
        assertGt(quote_, 0);
        uint256 before_ = weth.balanceOf(alice);
        vm.startPrank(alice);
        IERC20(composedDetf).approve(composedDetf, raw_ / 2);
        uint256 paid_ =
            composedIn.exchangeIn(IERC20(composedDetf), raw_ / 2, weth, quote_, alice, false, block.timestamp);
        vm.stopPrank();
        assertEq(paid_, quote_);
        assertEq(weth.balanceOf(alice), before_ + paid_);
        assertEq(IERC20(composedDetf).balanceOf(alice), raw_ - raw_ / 2);
    }

    function test_closedPrimaryBurn_swapsExistingDetfWithoutBurningSupply() public {
        uint256 raw_ = _buyRaw(alice, 10e18);
        assertFalse(composedInfo.isBurningAllowed());
        uint256 supply_ = IERC20(composedDetf).totalSupply();
        vm.startPrank(alice);
        IERC20(composedDetf).approve(composedDetf, raw_ / 2);
        uint256 paid_ = composedIn.exchangeIn(
            IERC20(composedDetf), raw_ / 2, IERC20(address(composedStable)), 0, alice, false, block.timestamp
        );
        vm.stopPrank();
        assertGt(paid_, 0);
        assertEq(IERC20(composedDetf).totalSupply(), supply_);
        assertEq(IERC20(composedDetf).balanceOf(composedDetf), 0);
    }
}
