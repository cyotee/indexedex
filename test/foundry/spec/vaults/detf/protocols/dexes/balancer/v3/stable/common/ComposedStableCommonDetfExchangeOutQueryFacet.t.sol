// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IDetfBondNFT} from "contracts/interfaces/IDetfBondNFT.sol";
import {IStakedDETF} from "contracts/interfaces/IStakedDETF.sol";
import {TestBase_ComposedFundedRoutes} from "contracts/test/bases/TestBase_ComposedFundedRoutes.sol";
import {
    ComposedStableCommonDetfRepo as Repo
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/ComposedStableCommonDetfRepo.sol";
import {IStandardExchangeOut} from "contracts/interfaces/IStandardExchangeOut.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";

contract ComposedStableCommonDetfExchangeOutQueryFacet_Test is TestBase_ComposedFundedRoutes {
    function test_claimLiquidity_legacySelectorIsNotExposed() public view {
        assertEq(
            IDiamondLoupe(composedDetf)
                .facetAddress(bytes4(keccak256("claimLiquidity(uint256,address,uint256,address,uint256)"))),
            address(0)
        );
    }

    function test_reserveInventory_cannotBeWithdrawnByCaller() public {
        _live();
        IDetfBondNFT nft_ = _bondNft();
        IERC20 lp_ = nft_.lpToken();
        uint256 before_ = lp_.balanceOf(address(nft_));
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSignature("NotAuthorized(address)", alice));
        nft_.transferHeldToken(lp_, alice, before_);
        assertEq(lp_.balanceOf(address(nft_)), before_);
        assertEq(lp_.balanceOf(alice), 0);
    }

    function test_fundedClaimAndUnstake_preserveReserveOwnership() public {
        uint256 id_ = _buyBond(alice, 10e18);
        _assertBondMaturePreviewEqualsPayment(composedDetf, id_, alice);
        _assertFundedUnstake(composedDetf, alice, _staked().balanceOf(alice));
    }

    function test_previewExchangeOut_selectsFundedEligibleRoute() public {
        _assertExactOut(weth, bob);
    }

    function test_previewExchangeOut_closedPrimaryBurn_keepsReserveRouteAvailable() public {
        _live();
        assertFalse(composedInfo.isBurningAllowed());
        assertGt(composedOut.previewExchangeOut(IERC20(composedDetf), weth, 1e15), 0);
    }

    function test_previewExchangeOut_revertsForUnsupportedTokenIn() public {
        vm.expectRevert(IStandardExchangeOut.ExchangeOutNotAvailable.selector);
        composedOut.previewExchangeOut(dai, weth, 1e15);
    }

    function test_previewExchangeOut_revertsForUnsupportedTokenOut() public {
        vm.expectRevert(abi.encodeWithSignature("InvalidRoute(address,address)", composedDetf, address(0xBAD)));
        composedOut.previewExchangeOut(IERC20(composedDetf), IERC20(address(0xBAD)), 1e15);
    }

    function test_previewExchangeOut_revertsWhenReservePoolUninitialized() public {
        vm.expectRevert(bytes4(keccak256("ReservePoolNotInitialized()")));
        composedOut.previewExchangeOut(IERC20(composedDetf), weth, 1e15);
    }

    function test_exchangeOut_executesSelectedRoute() public {
        _assertExactOut(weth, alice);
    }

    function test_exchangeOut_keepsUnusedDetfInputWithPayer() public {
        _assertExactOut(weth, bob);
    }

    function test_exchangeOut_defaultsRecipientToCaller() public {
        _assertExactOut(weth, address(0));
    }

    function test_exchangeOut_revertsWhenMaxAmountInIsTooLow() public {
        uint256 raw_ = _buyRaw(alice, 10e18);
        uint256 quote_ = composedOut.previewExchangeOut(IERC20(composedDetf), weth, 1e15);
        assertGt(quote_, 0);
        vm.startPrank(alice);
        IERC20(composedDetf).approve(composedDetf, raw_);
        vm.expectRevert(abi.encodeWithSignature("MaxAmountExceeded(uint256,uint256)", quote_ - 1, quote_));
        composedOut.exchangeOut(IERC20(composedDetf), quote_ - 1, weth, 1e15, alice, false, block.timestamp);
        vm.stopPrank();
        assertEq(IERC20(composedDetf).balanceOf(alice), raw_);
    }

    function test_exchangeOut_revertsForUnsupportedTokenOut() public {
        uint256 raw_ = _buyRaw(alice, 10e18);
        vm.expectRevert(abi.encodeWithSignature("InvalidRoute(address,address)", composedDetf, address(0xBAD)));
        composedOut.exchangeOut(IERC20(composedDetf), raw_, IERC20(address(0xBAD)), 1e15, alice, false, block.timestamp);
        assertEq(IERC20(composedDetf).balanceOf(alice), raw_);
    }

    function test_exchangeOut_revertsWhenDeadlineExpired() public {
        vm.expectRevert(
            abi.encodeWithSignature("DeadlineExceeded(uint256,uint256)", block.timestamp - 1, block.timestamp)
        );
        composedOut.exchangeOut(IERC20(composedDetf), 1e9, weth, 1e15, alice, false, block.timestamp - 1);
    }

    function test_exchangeOut_revertsWhenAmountOutIsZero() public {
        vm.expectRevert(bytes4(keccak256("ZeroAmount()")));
        composedOut.exchangeOut(IERC20(composedDetf), 1e9, weth, 0, alice, false, block.timestamp);
    }

    function test_exchangeOut_closedPrimaryBurn_usesReserveSwap() public {
        _live();
        assertFalse(composedInfo.isBurningAllowed());
        uint256 supply_ = IERC20(composedDetf).totalSupply();
        _assertExactOut(weth, alice);
        assertEq(IERC20(composedDetf).totalSupply(), supply_);
    }

    function test_exchangeOut_cannotSpendUnfundedInventory() public {
        _live();
        uint256 supply_ = IERC20(composedDetf).totalSupply();
        uint256 before_ = weth.balanceOf(alice);
        vm.prank(alice);
        vm.expectRevert(bytes4(keccak256("TransferFromFailed()")));
        composedOut.exchangeOut(IERC20(composedDetf), 100e9, weth, 1e15, alice, false, block.timestamp);
        assertEq(IERC20(composedDetf).totalSupply(), supply_);
        assertEq(weth.balanceOf(alice), before_);
    }

    function test_exchangeOut_revertsWhenReservePoolUninitialized() public {
        vm.expectRevert(bytes4(keccak256("ReservePoolNotInitialized()")));
        composedOut.exchangeOut(IERC20(composedDetf), 1e9, weth, 1e15, alice, false, block.timestamp);
    }

    function test_exchangeOut_underlyingExitDeliversExactAmount() public {
        _assertExactOut(IERC20(address(daiUsdcVault)), bob);
    }

    function test_previewExchangeOut_supportsDirectVaultTokenPayout() public {
        _live();
        assertGt(composedOut.previewExchangeOut(IERC20(composedDetf), IERC20(address(composedStable)), 1e15), 0);
    }

    function test_exchangeOut_supportsDirectVaultTokenPayout() public {
        _assertExactOut(IERC20(address(composedStable)), bob);
    }

    function test_exchangeOut_stakedInput_paysExactRawDetf() public {
        uint256 id_ = _buyBond(alice, 10e18);
        _assertBondMaturePreviewEqualsPayment(composedDetf, id_, alice);
        uint256 amount_ = _staked().balanceOf(alice) / 2;
        assertGt(amount_, 0);
        uint256 before_ = _staked().balanceOf(alice);
        vm.startPrank(alice);
        _staked().approve(composedDetf, amount_);
        uint256 paid_ = composedOut.exchangeOut(
            IERC20(address(_staked())), amount_, IERC20(composedDetf), amount_, bob, false, block.timestamp
        );
        vm.stopPrank();
        assertEq(paid_, amount_);
        assertEq(IERC20(composedDetf).balanceOf(bob), amount_);
        assertEq(_staked().balanceOf(alice), before_ - amount_);
    }
}
