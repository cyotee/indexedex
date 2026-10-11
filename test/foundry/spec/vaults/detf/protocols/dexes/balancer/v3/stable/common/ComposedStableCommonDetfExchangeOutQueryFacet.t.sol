// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {AtomicPretransferCaller} from "contracts/test/stubs/AtomicPretransferCaller.sol";
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

    function test_previewExchangeOut_returnsZeroForUnsupportedTokenIn() public {
        assertEq(composedOut.previewExchangeOut(dai, weth, 1e15), 0);
        _live();
        assertEq(composedOut.previewExchangeOut(dai, weth, 1e15), 0);
    }

    function test_previewExchangeOut_returnsZeroForUnsupportedTokenOut() public {
        assertEq(composedOut.previewExchangeOut(IERC20(composedDetf), IERC20(address(0xBAD)), 1e15), 0);
        _live();
        assertEq(composedOut.previewExchangeOut(IERC20(composedDetf), IERC20(address(0xBAD)), 1e15), 0);
    }

    function test_previewExchangeOut_returnsZeroWhenReservePoolUninitialized() public {
        assertFalse(composedInfo.isReserveLive());
        assertEq(composedOut.previewExchangeOut(IERC20(composedDetf), weth, 1e15), 0);
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
        _buyRaw(alice, 10e18);
        _assertRejectedBeforeFunding(IERC20(composedDetf), IERC20(address(0xBAD)),
            abi.encodeWithSignature("InvalidRoute(address,address)", composedDetf, address(0xBAD)));
    }

    function test_exchangeOut_revertsForUnsupportedTokenIn() public {
        _live();
        _assertRejectedBeforeFunding(dai, weth,
            abi.encodeWithSignature("InvalidRoute(address,address)", address(dai), address(weth)));
    }

    function test_exchangeOut_rejectsUnsupportedDirectConversions() public {
        _buyRaw(alice, 10e18);
        IERC20 raw_ = IERC20(composedDetf);
        IERC20 staking_ = IERC20(address(_staked()));
        _assertRejectedBeforeFunding(raw_, raw_, abi.encodeWithSignature("InvalidRoute(address,address)", raw_, raw_));
        _assertRejectedBeforeFunding(staking_, staking_, abi.encodeWithSignature("InvalidRoute(address,address)", staking_, staking_));
        _assertRejectedBeforeFunding(dai, staking_, abi.encodeWithSignature("InvalidRoute(address,address)", dai, staking_));
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
        assertFalse(composedInfo.isReserveLive());
        _assertRejectedBeforeFunding(IERC20(composedDetf), weth, abi.encodeWithSignature("ReservePoolNotInitialized()"));
        _assertRejectedBeforeFunding(IERC20(address(_staked())), weth, abi.encodeWithSignature("ReservePoolNotInitialized()"));
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
    /// @notice Invalid requests must fail before either a pull or prepayment lookup.
    function _assertRejectedBeforeFunding(IERC20 in_, IERC20 out_, bytes memory error_) internal {
        bytes32 before_ = _custodyState(in_);
        vm.expectCall(address(in_), abi.encodeWithSelector(IERC20.transferFrom.selector), uint64(0));
        for (uint256 flag_; flag_ < 2; ++flag_) {
            vm.expectRevert(error_);
            composedOut.exchangeOut(in_, 1e18, out_, 1e15, bob, flag_ == 1, block.timestamp);
            assertEq(_custodyState(in_), before_, "rejection preserves custody and supply");
        }
    }

    function _custodyState(IERC20 in_) internal view returns (bytes32) {
        return keccak256(abi.encode(
            in_.balanceOf(address(this)), in_.balanceOf(alice), in_.balanceOf(composedDetf),
            IERC20(composedDetf).balanceOf(bob), IERC20(composedDetf).totalSupply(),
            weth.balanceOf(bob), _staked().totalSupply(), _bondNft().lpToken().balanceOf(address(_bondNft()))
        ));
    }

    /// @notice Direct conversions bypass reserve liveness but still require funded input.
    function test_exchangeOut_directStakingBeforeActivation_reachesFundingCheck() public {
        assertFalse(composedInfo.isReserveLive());
        IERC20 raw_ = IERC20(composedDetf);
        IERC20 staking_ = IERC20(address(_staked()));
        assertEq(composedOut.previewExchangeOut(raw_, staking_, 1), 1);
        assertEq(composedOut.previewExchangeOut(staking_, raw_, 1), 1);
        vm.expectRevert(bytes4(keccak256("TransferFromFailed()")));
        composedOut.exchangeOut(raw_, 1, staking_, 1, bob, false, block.timestamp);
        vm.expectRevert(bytes4(keccak256("TransferFromFailed()")));
        composedOut.exchangeOut(staking_, 1, raw_, 1, bob, false, block.timestamp);
    }

    function test_exchangeOut_directStakingRoundTrip_pull() public { _directStakingRoundTrip(false); }
    function test_exchangeOut_directStakingRoundTrip_prepaid() public { _directStakingRoundTrip(true); }

    function _directStakingRoundTrip(bool prepaid_) internal {
        uint256 rawBefore_ = _buyRaw(alice, 10e18);
        uint256 amount_ = rawBefore_ / 4;
        IERC20 raw_ = IERC20(composedDetf);
        IERC20 staking_ = IERC20(address(_staked()));
        uint256 supply_ = raw_.totalSupply();
        uint256 stakedBefore_ = staking_.balanceOf(alice);
        uint256 bobBefore_ = raw_.balanceOf(bob);
        AtomicPretransferCaller caller_ = new AtomicPretransferCaller();
        vm.prank(alice);
        raw_.approve(address(caller_), amount_);
        _fundAndConvert(caller_, raw_, staking_, amount_, alice, prepaid_);
        assertEq(raw_.balanceOf(alice), rawBefore_ - amount_);
        assertEq(staking_.balanceOf(alice), stakedBefore_ + amount_);
        vm.prank(alice);
        staking_.approve(address(caller_), amount_);
        _fundAndConvert(caller_, staking_, raw_, amount_, bob, prepaid_);
        assertEq(staking_.balanceOf(alice), stakedBefore_);
        assertEq(raw_.balanceOf(bob), bobBefore_ + amount_);
        assertEq(raw_.totalSupply(), supply_, "direct conversion does not issue DETF");
        assertEq(raw_.balanceOf(address(caller_)), 0);
        assertEq(staking_.balanceOf(address(caller_)), 0);
    }

    function _fundAndConvert(AtomicPretransferCaller caller_, IERC20 in_, IERC20 out_, uint256 amount_, address to_, bool prepaid_) internal {
        assertEq(composedOut.previewExchangeOut(in_, out_, amount_), amount_);
        bytes memory data_ = abi.encodeCall(IStandardExchangeOut.exchangeOut,
            (in_, amount_, out_, amount_, to_, prepaid_, block.timestamp));
        bytes memory result_ = prepaid_
            ? caller_.consumePretransfer(in_, alice, composedDetf, amount_, data_)
            : caller_.consumePull(in_, alice, composedDetf, amount_, data_);
        assertEq(abi.decode(result_, (uint256)), amount_, "direct quote matches execution");
    }
}
