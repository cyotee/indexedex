// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {IStandardizedYield} from "@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol";
import {IDetfBondNFT} from "contracts/interfaces/IDetfBondNFT.sol";
import {IStakedDETF} from "contracts/interfaces/IStakedDETF.sol";
import {DETFFundedStakingMath as Math} from "contracts/vaults/detf/common/core/DETFFundedStakingMath.sol";
import {TestBase_MixedBufferMultiVaultStableDetf_Decimals} from "contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/TestBase_MixedBufferMultiVaultStableDetf_Decimals.sol";

/// @notice All eight actual decimal books share one compiled lifecycle and real package fixture.
contract MixedBufferFundedDecimalBooksTest is TestBase_MixedBufferMultiVaultStableDetf_Decimals {
    uint8 private pairPrecision = 18;
    uint8 private ratePrecision = 18;
    uint8 private restPrecision = 18;

    function _pairDecimals() internal view override returns (uint8) { return pairPrecision; }
    function _rateDecimals() internal view override returns (uint8) { return ratePrecision; }
    function _restDecimals() internal view override returns (uint8) { return restPrecision; }

    function test_mixedFundedLifecycleAcrossAllEightDecimalBooks() public {
        uint8[3][8] memory books_ = [
            [uint8(6), 6, 6], [uint8(9), 9, 9], [uint8(6), 9, 18], [uint8(6), 18, 18],
            [uint8(9), 6, 18], [uint8(9), 18, 18], [uint8(18), 6, 18], [uint8(18), 9, 18]
        ];
        for (uint256 i_; i_ < books_.length; ++i_) {
            uint256 snapshot_ = vm.snapshotState();
            pairPrecision = books_[i_][0]; ratePrecision = books_[i_][1]; restPrecision = books_[i_][2];
            _initializeMixedFixtureLegs();
            _useDetf(_deployDetfN(3, type(uint256).max, 1));
            _exerciseFundedDecimalBook();
            assertTrue(vm.revertToState(snapshot_));
        }
    }

    function _exerciseFundedDecimalBook() private {
        assertEq(IERC20Metadata(detf).decimals(), 9);
        assertEq(pairToken.decimals(), pairPrecision);
        assertEq(rateAsset.decimals(), ratePrecision);
        assertEq(restToken.decimals(), restPrecision);
        IStakedDETF staking_ = IStakedDETF(detfInfo.rebasingClaimToken());
        assertEq(staking_.decimals(), 9);
        uint256 capital_ = _from18(address(pairToken), 1_000 ether);
        (uint256 id_, uint256 lp_, uint256 principal_) = _bootstrapFirstBond(detf, alice, capital_, 1_000 ether);
        IDetfBondNFT nft_ = _bondNftVault(detf);
        assertGt(principal_, 0);
        assertEq(nft_.positionOf(id_).principal, principal_);
        assertEq(nft_.lpToken().balanceOf(address(nft_)), lp_);
        assertGe(staking_.balanceOf(address(nft_)), principal_);
        assertFalse(detfInfo.isMintingAllowed());
        assertFalse(detfInfo.isBurningAllowed());

        uint256 supply_ = IERC20(detf).totalSupply();
        uint256 backing_ = staking_.stakingState().accountedBacking;
        uint256 bought_ = _mintDetfFromBuffer(detf, bob, _from18(address(pairToken), 10 ether));
        assertGt(bought_, 0);
        assertGt(_burnDetfToBuffer(detf, bob, bought_ / 2), 0);
        assertEq(IERC20(detf).totalSupply(), supply_, "both closed gates execute supply-neutral reserve swaps");
        assertEq(staking_.stakingState().accountedBacking, backing_);
        _exerciseDecimalSYs();
        _exerciseDecimalClaim(nft_, staking_, id_, principal_);
    }

    function _exerciseDecimalSYs() private {
        address[2] memory wrappers_ = [detfInfo.rawSY(), detfInfo.stakingSY()];
        uint256 payment_ = _from18(address(pairToken), 5 ether);
        for (uint256 i_; i_ < wrappers_.length; ++i_) {
            IStandardizedYield sy_ = IStandardizedYield(wrappers_[i_]);
            assertEq(sy_.decimals(), 9);
            assertEq(sy_.yieldToken(), i_ == 0 ? detf : detfInfo.rebasingClaimToken());
            uint256 quote_ = sy_.previewDeposit(address(pairToken), payment_);
            assertGt(quote_, 0);
            _fundBuffer(bob, payment_);
            vm.startPrank(bob);
            pairToken.approve(address(sy_), payment_);
            uint256 minted_ = sy_.deposit(bob, address(pairToken), payment_, quote_);
            assertEq(minted_, quote_);
            uint256 output_ = sy_.previewRedeem(address(pairToken), minted_);
            uint256 before_ = pairToken.balanceOf(bob);
            assertEq(sy_.redeem(bob, minted_, address(pairToken), output_, false), output_);
            vm.stopPrank();
            assertGt(output_, 0);
            assertEq(pairToken.balanceOf(bob), before_ + output_);
            assertEq(sy_.balanceOf(bob), 0);
        }
    }

    function _exerciseDecimalClaim(IDetfBondNFT nft_, IStakedDETF staking_, uint256 id_, uint256 principal_) private {
        Math.BondPosition memory position_ = nft_.positionOf(id_);
        vm.warp(position_.startTimestamp + position_.vestingDuration / 2);
        uint256 lp_ = nft_.lpToken().balanceOf(address(nft_));
        uint256 raw_ = IERC20(detf).balanceOf(alice);
        uint256 backing_ = staking_.stakingState().accountedBacking;
        vm.prank(alice);
        (uint256 paid_, uint256 rewards_) = nft_.claimBond(id_, alice);
        assertEq(paid_, principal_ / 2);
        assertEq(staking_.balanceOf(alice), paid_ + rewards_);
        vm.prank(alice);
        assertEq(staking_.exchangeIn(IERC20(address(staking_)), paid_ + rewards_, IERC20(detf),
            paid_ + rewards_, alice, false, block.timestamp), paid_ + rewards_);
        assertEq(IERC20(detf).balanceOf(alice), raw_ + paid_ + rewards_);
        assertEq(staking_.stakingState().accountedBacking, backing_ - paid_ - rewards_);
        assertEq(nft_.lpToken().balanceOf(address(nft_)), lp_);
    }
}
