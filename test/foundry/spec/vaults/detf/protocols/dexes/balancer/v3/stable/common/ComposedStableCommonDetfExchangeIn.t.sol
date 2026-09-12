// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IDetfBondNFT} from "contracts/interfaces/IDetfBondNFT.sol";
import {IStakedDETF} from "contracts/interfaces/IStakedDETF.sol";
import {TestBase_ComposedFundedRoutes} from "contracts/test/bases/TestBase_ComposedFundedRoutes.sol";
import {
    ComposedStableCommonDetfRepo as Repo
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/ComposedStableCommonDetfRepo.sol";

contract ComposedStableCommonDetfExchangeIn_Test is TestBase_ComposedFundedRoutes {
    function test_previewExchangeIn_routesSharedTokenToFundedPool() public {
        _live();
        deal(address(dai), alice, 10e18, true);
        uint256 quote_ = composedIn.previewExchangeIn(dai, 10e18, IERC20(composedDetf));
        assertGt(quote_, 0);
        vm.startPrank(alice);
        dai.approve(composedDetf, 10e18);
        uint256 actual_ = composedIn.exchangeIn(dai, 10e18, IERC20(composedDetf), quote_, alice, false, block.timestamp);
        vm.stopPrank();
        assertEq(actual_, quote_);
        assertEq(IERC20(composedDetf).balanceOf(alice), actual_);
        assertEq(dai.balanceOf(alice), 0);
        assertEq(dai.balanceOf(composedDetf), 0);
    }

    function test_exchangeIn_usesFundedReserveAndPaysRecipient() public {
        _buyRaw(alice, 10e18);
        assertGt(_bondNft().lpToken().balanceOf(address(_bondNft())), 0);
    }

    function test_closedPrimaryMint_usesReserveSwapWithoutIssuance() public {
        _live();
        assertFalse(composedInfo.isMintingAllowed());
        uint256 supply_ = IERC20(composedDetf).totalSupply();
        _buyRaw(alice, 10e18);
        assertEq(IERC20(composedDetf).totalSupply(), supply_);
    }

    function test_previewExchangeIn_revertsWhenReservePoolUninitialized() public {
        vm.expectRevert(bytes4(keccak256("ReservePoolNotInitialized()")));
        composedIn.previewExchangeIn(IERC20(address(composedStable)), 1e18, IERC20(composedDetf));
    }
}
