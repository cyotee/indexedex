// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {FundedThresholdAssertions} from "contracts/test/bases/FundedThresholdAssertions.sol";
import {FundedPrimaryRouteAssertions} from "contracts/test/bases/FundedPrimaryRouteAssertions.sol";
import {IVault} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IVault.sol";
import {FundedRewardAssertions} from "contracts/test/bases/FundedRewardAssertions.sol";
import {FundedBondCloseAssertions} from "contracts/test/bases/FundedBondCloseAssertions.sol";
import {FundedBalancerEpochAssertions} from "contracts/test/bases/FundedBalancerEpochAssertions.sol";
import {FundedReserveDonationAssertions} from "contracts/test/bases/FundedReserveDonationAssertions.sol";
import {IComposedStableCommonDetfDFPkg} from "contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/IComposedStableCommonDetfDFPkg.sol";
import {ComposedStableCommonDetfRepo as OpeningRepo} from "contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/ComposedStableCommonDetfRepo.sol";
import {IComposedStableCommonDetfBonding} from "contracts/interfaces/IComposedStableCommonDetfBonding.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {IStandardizedYield} from "@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol";
import {IStakedDETF} from "contracts/interfaces/IStakedDETF.sol";
import {IDetfBondNFT} from "contracts/interfaces/IDetfBondNFT.sol";
import {DETFFundedStakingMath as Math} from "contracts/vaults/detf/common/core/DETFFundedStakingMath.sol";
import {TestBase_FundedComposedDETF} from "contracts/test/bases/TestBase_FundedComposedDETF.sol";
contract ComposedStableFundedStakingTest is TestBase_FundedComposedDETF, FundedReserveDonationAssertions, FundedBalancerEpochAssertions, FundedBondCloseAssertions, FundedRewardAssertions, FundedPrimaryRouteAssertions, FundedThresholdAssertions {
    function test_inertPrimaryRouteRequiresFirstBond() public {
        IERC20 payment_ = IERC20(address(composedStable));
        vm.prank(owner); payment_.transfer(address(this), 1 ether);
        _assertInertRoute(composedDetf, payment_, 1 ether);
    }
    function _deployThresholdPair(uint256 mint_, uint256 burn_) internal override returns (address) { return _deployComposed(mint_, burn_); }

    address internal constant BUYER = address(0xCAB012);
    function _nft() internal view returns (IDetfBondNFT) { return IDetfBondNFT(composedInfo.bondNftVault()); }
    function _staking() internal view returns (IStakedDETF) { return IStakedDETF(composedInfo.rebasingClaimToken()); }
    function _lp() internal view returns (uint256) { return IERC20(composedInfo.reservePool()).balanceOf(address(_nft())); }
    function test_composedImmutableNativeUnitsAndCompleteRoutes() public view {
        _assertFundedEpochConfiguration(composedDetf);
        assertEq(IERC20Metadata(composedDetf).decimals(), 9); assertEq(_staking().decimals(), 9);
        assertEq(IERC20Metadata(composedDetf).symbol(), "DETF");
        IStandardizedYield sy_ = IStandardizedYield(composedInfo.stakingSY());
        assertEq(sy_.yieldToken(), address(_staking())); assertEq(sy_.decimals(), 9);
        assertTrue(sy_.isValidTokenIn(address(dai))); assertTrue(sy_.isValidTokenOut(address(weth)));
        assertTrue(sy_.isValidTokenOut(address(daiUsdcVault))); assertFalse(sy_.isValidTokenIn(address(weth)));
        assertEq(IStandardizedYield(composedInfo.rawSY()).yieldToken(), composedDetf);
        address[] memory facets_ = IDiamondLoupe(composedDetf).facetAddresses();
        for (uint256 i_; i_ < facets_.length; ++i_) assertLe(facets_[i_].code.length, 24_576);
        assertLe(address(composedPkg).code.length, 24_576);
    }
    function test_composedFirstBondFundsPrincipalAndAllReserveCapital() public {
        (uint256 principal_, uint256 g_, uint256 pot_) = composedBonding.previewInitializeReserve(1_000e18, 1_000e18, DEFAULT_MIN_LOCK);
        (uint256 id_, uint256 actual_) = _bootstrapComposed(BUYER);
        assertEq(actual_, principal_); assertEq(g_, 2_000e9);
        assertEq(_nft().positionOf(id_).principal, principal_);
        assertEq(IERC20(composedDetf).totalSupply(), principal_ + g_ + pot_);
        assertGe(_staking().balanceOf(address(_nft())), principal_);
        assertGt(_lp(), 0); assertEq(IERC20(composedDetf).balanceOf(BUYER), 0);
        assertEq(composedInfo.epochAnchor(), block.timestamp);
    }
    function test_composedFirstQuoteIsLinearAndBonusLeavesLiquidityUnchanged() public view {
        (uint256 p_, uint256 g_,) = composedBonding.previewInitializeReserve(1_000e18, 1_000e18, DEFAULT_MIN_LOCK);
        (uint256 twice_, uint256 g2_,) = composedBonding.previewInitializeReserve(2_000e18, 2_000e18, DEFAULT_MIN_LOCK);
        (uint256 longer_, uint256 longG_,) = composedBonding.previewInitializeReserve(1_000e18, 1_000e18, DEFAULT_MAX_LOCK);
        assertEq(twice_, p_ * 2); assertEq(g2_, g_ * 2); assertGt(longer_, p_); assertEq(longG_, g_);
    }
    function test_composedRichOpeningUsesConfiguredPricesAndSeedBasket() public {
        IComposedStableCommonDetfDFPkg.PkgArgs memory args_ = _composedArgs(0, 0, 0);
        args_.openingDetfPrices = [uint256(20e18), uint256(40e18)];
        args_.reserveSeedAmounts = [uint256(100e9), uint256(1_000e18), uint256(2_000e18)];
        vm.prank(owner); address rich_ = composedPkg.deployVault(args_); _useComposed(rich_);
        (uint256[2] memory prices_, uint256[3] memory seeds_) = composedInfo.openingConfiguration();
        assertEq(prices_[0], 20e18); assertEq(prices_[1], 40e18); assertEq(seeds_[0], 100e9);
        (uint256 p_, uint256 g_, uint256 pot_) = composedBonding.previewInitializeReserve(1_000e18, 2_000e18, DEFAULT_MIN_LOCK);
        (uint256 p2_, uint256 g2_,) = composedBonding.previewInitializeReserve(2_000e18, 4_000e18, DEFAULT_MIN_LOCK);
        assertEq(g_, 100e9); assertEq(g2_, 200e9); assertEq(p2_, p_ * 2);
        // Same duration and seigniorage as the default 1:1 launch, with 100 instead of 2000 gross DETF.
        address ordinary_ = _deployComposed(0, 0);
        IComposedStableCommonDetfBonding ordinaryBonding_ = IComposedStableCommonDetfBonding(ordinary_);
        (uint256 ordinaryP_,,) = ordinaryBonding_.previewInitializeReserve(1_000e18, 1_000e18, DEFAULT_MIN_LOCK);
        assertEq(p_ * 20, ordinaryP_);
        vm.startPrank(owner);
        IERC20(address(composedStable)).approve(rich_, 1_000e18); IERC20(address(composedCommon)).approve(rich_, 2_000e18);
        (uint256 id_, uint256 paid_) = composedBonding.initializeReserve(1_000e18, 2_000e18, DEFAULT_MIN_LOCK, BUYER, block.timestamp);
        vm.stopPrank();
        assertEq(paid_, p_); assertEq(_nft().positionOf(id_).principal, p_);
        assertEq(IERC20(rich_).totalSupply(), g_ + p_ + pot_);
        (IERC20[] memory tokens_,,uint256[] memory balances_,) = vault.getPoolTokenInfo(composedInfo.reservePool());
        for (uint256 i_; i_ < tokens_.length; ++i_) {
            if (address(tokens_[i_]) == rich_) assertEq(balances_[i_], 100e9);
            else if (address(tokens_[i_]) == address(composedStable)) assertEq(balances_[i_], 1_000e18);
            else assertEq(balances_[i_], 2_000e18);
        }
    }
    function test_composedOpeningRejectsZeroPriceAndSeedConfiguration() public {
        IComposedStableCommonDetfDFPkg.PkgArgs memory args_ = _composedArgs(0, 0, 0);
        args_.openingDetfPrices[0] = 0;
        vm.prank(owner); vm.expectRevert(IComposedStableCommonDetfDFPkg.InvalidPackageArguments.selector); composedPkg.deployVault(args_);
        args_.openingDetfPrices[0] = 1e18; args_.reserveSeedAmounts[2] = 0;
        vm.prank(owner); vm.expectRevert(IComposedStableCommonDetfDFPkg.InvalidPackageArguments.selector); composedPkg.deployVault(args_);
    }
    function test_composedSeedMismatchRevertsBeforeActivatingOrTakingPayment() public {
        vm.expectRevert(abi.encodeWithSelector(OpeningRepo.InvalidSeedRatio.selector, 999e18, 1_000e18));
        composedBonding.previewInitializeReserve(1_000e18, 999e18, DEFAULT_MIN_LOCK);
        uint256 before_ = IERC20(address(composedStable)).balanceOf(owner);
        vm.startPrank(owner);
        IERC20(address(composedStable)).approve(composedDetf, 1_000e18); IERC20(address(composedCommon)).approve(composedDetf, 999e18);
        vm.expectRevert(abi.encodeWithSelector(OpeningRepo.InvalidSeedRatio.selector, 999e18, 1_000e18));
        composedBonding.initializeReserve(1_000e18, 999e18, DEFAULT_MIN_LOCK, BUYER, block.timestamp);
        vm.stopPrank();
        assertEq(IERC20(address(composedStable)).balanceOf(owner), before_);
        assertFalse(composedInfo.isReserveLive()); assertEq(IERC20(composedDetf).totalSupply(), 0);
    }
    function test_composedHalfwayBondPaysStakingWithoutUsingLP() public {
        (uint256 id_, uint256 p_) = _bootstrapComposed(BUYER); uint256 lp_ = _lp();
        Math.BondPosition memory pos_ = _nft().positionOf(id_); vm.warp(pos_.startTimestamp + pos_.vestingDuration / 2);
        IDetfBondNFT nft_ = _nft(); vm.prank(BUYER); (uint256 principal_, uint256 rewards_) = nft_.claimBond(id_, BUYER);
        assertEq(principal_, p_ / 2); IStakedDETF staking_ = _staking();
        vm.prank(BUYER); staking_.exchangeIn(IERC20(address(staking_)), principal_ + rewards_, IERC20(composedDetf), 0, BUYER, false, block.timestamp);
        assertEq(IERC20(composedDetf).balanceOf(BUYER), principal_ + rewards_); assertEq(_lp(), lp_);
    }
    function test_composedGatedBptMintSwapsWithoutIssuance() public {
        _bootstrapComposed(BUYER);
        uint256 supply_ = IERC20(composedDetf).totalSupply(); uint256 backing_ = _staking().stakingState().accountedBacking;
        IERC20 input_ = IERC20(address(composedStable)); uint256 quote_ = composedIn.previewExchangeIn(input_, 1e18, IERC20(composedDetf));
        vm.startPrank(owner); input_.approve(composedDetf, 1e18);
        assertEq(composedIn.exchangeIn(input_, 1e18, IERC20(composedDetf), quote_, owner, false, block.timestamp), quote_); vm.stopPrank();
        assertGt(quote_, 0); assertEq(IERC20(composedDetf).totalSupply(), supply_); assertEq(_staking().stakingState().accountedBacking, backing_);
    }
    function _claimRaw() internal returns (uint256 p_) {
        (uint256 id_, uint256 principal_) = _bootstrapComposed(BUYER); p_ = principal_;
        vm.warp(block.timestamp + DEFAULT_MIN_LOCK); IDetfBondNFT nft_ = _nft(); IStakedDETF staking_ = _staking();
        vm.prank(BUYER); nft_.claimBond(id_, BUYER);
        vm.prank(BUYER); staking_.exchangeIn(IERC20(address(staking_)), p_, IERC20(composedDetf), p_, BUYER, false, block.timestamp);
    }
    function test_composedGatedBptBurnSwapsWithoutBurning() public {
        uint256 amount_ = _claimRaw() / 1_000; IERC20 out_ = IERC20(address(composedStable));
        uint256 supply_ = IERC20(composedDetf).totalSupply(); uint256 quote_ = composedIn.previewExchangeIn(IERC20(composedDetf), amount_, out_);
        vm.startPrank(BUYER); IERC20(composedDetf).approve(composedDetf, amount_);
        assertEq(composedIn.exchangeIn(IERC20(composedDetf), amount_, out_, quote_, BUYER, false, block.timestamp), quote_); vm.stopPrank();
        assertGt(quote_, 0); assertEq(IERC20(composedDetf).totalSupply(), supply_);
    }
    function test_composedExactOutputBurnsOnlyRequiredOrSwapsRequired() public {
        _claimRaw(); IERC20 out_ = IERC20(address(composedStable));
        uint256 quote_ = composedOut.previewExchangeOut(IERC20(composedDetf), out_, 1e18);
        uint256 before_ = IERC20(composedDetf).balanceOf(BUYER); uint256 supply_ = IERC20(composedDetf).totalSupply();
        vm.startPrank(BUYER); IERC20(composedDetf).approve(composedDetf, quote_ * 2);
        uint256 paid_ = composedOut.exchangeOut(IERC20(composedDetf), quote_ * 2, out_, 1e18, BUYER, false, block.timestamp); vm.stopPrank();
        assertEq(paid_, quote_); assertEq(before_ - IERC20(composedDetf).balanceOf(BUYER), paid_);
        assertEq(out_.balanceOf(BUYER), 1e18); assertEq(IERC20(composedDetf).totalSupply(), supply_);
    }
    function test_composedCatchupConsumesAllBoundaries() public {
        _bootstrapComposed(BUYER); uint256 anchor_ = composedInfo.epochAnchor();
        vm.warp(anchor_ + 25 hours); assertEq(composedInfo.synchronizeRewards(), 0); assertEq(composedInfo.lastExpansionTimestamp(), anchor_ + 24 hours);
        vm.warp(anchor_ + 7 days); assertEq(composedInfo.synchronizeRewards(), 0); assertEq(composedInfo.lastExpansionTimestamp(), anchor_ + 7 days);
    }

    function test_composedDonationsKeepAllProtocolLiquiditySeparateFromFundedStake() public {
        (uint256 id_,) = _bootstrapComposed(BUYER);
        vm.warp(block.timestamp + 25 hours);
        _assertFundedDonation(composedDetf, _nft(), _staking(), IERC20(address(composedStable)), 10 ether, owner, id_);
        _assertFundedDonation(composedDetf, _nft(), _staking(), IERC20(address(composedCommon)), 10 ether, owner, id_);
        deal(address(dai), owner, 10 ether, true);
        _assertFundedDonation(composedDetf, _nft(), _staking(), dai, 10 ether, owner, id_);
        IDetfBondNFT nft_ = _nft(); IStakedDETF staking_ = _staking();
        vm.warp(nft_.positionOf(id_).startTimestamp + DEFAULT_MIN_LOCK / 2);
        vm.prank(BUYER); uint256 vested_ = nft_.claimPrincipal(id_, BUYER);
        vm.prank(BUYER); staking_.exchangeIn(IERC20(address(staking_)), vested_, IERC20(composedDetf), vested_, BUYER, false, block.timestamp);
        vm.warp(block.timestamp + 25 hours);
        _assertFundedDonation(composedDetf, nft_, staking_, IERC20(composedDetf), vested_ / 100, BUYER, id_);
    }

    function test_composedPositiveEpochCatchupFundsOneAggregateWithoutLpChange() public {
        _useComposed(_deployComposed(0, 0, 1e12)); _bootstrapComposed(BUYER);
        IERC20 payment_ = IERC20(address(composedStable));
        vm.startPrank(owner); payment_.approve(composedDetf, 10 ether);
        composedBonding.bond(payment_, 10 ether, DEFAULT_MIN_LOCK, BUYER, block.timestamp);
        vm.stopPrank();
        for (uint256 i_; i_ < 3; ++i_) {
            _donateEpochCapital(_nft(), IERC20(address(composedStable)), 2_000 ether, owner);
            _donateEpochCapital(_nft(), IERC20(address(composedCommon)), 2_000 ether, owner);
        }
        _assertFundedBalancerEpochs(composedDetf, _staking(), _nft(), composedInfo.syntheticDetfEthPrice());
    }

    function test_finalFundedClaimPaysOnlyStakingAndRetiresBond() public {
        (uint256 id_,) = _bootstrapComposed(BUYER);
        IERC20[] memory payments_ = new IERC20[](4);
        payments_[0] = IERC20(address(composedStable)); payments_[1] = IERC20(address(composedCommon));
        payments_[2] = IERC20(address(daiUsdcVault)); payments_[3] = IERC20(address(weth));
        _assertFinalFundedClaim(composedDetf, _nft(), _staking(), id_, BUYER, payments_);
    }
    function test_standingRecipientsExitAndReceiveLaterBondFundingAtExactFloors() public {
        _bootstrapComposed(BUYER);
        IERC20 payment_ = IERC20(address(composedStable));
        IStakedDETF staking_ = _staking(); IDetfBondNFT nft_ = _nft();
        _exitStandingReceiptsAndChangeOracle(composedDetf, staking_, nft_, address(indexedexManager), owner);
        (uint256 principal_,, uint256 pot_) = composedBonding.previewBond(payment_, 10 ether, DEFAULT_MIN_LOCK);
        FundingExpectation memory expected_ = _expectedBondFunding(composedDetf, staking_, nft_, address(indexedexManager), principal_, pot_);
        vm.startPrank(owner); payment_.approve(composedDetf, 10 ether);
        (uint256 id_,) = composedBonding.bond(payment_, 10 ether, DEFAULT_MIN_LOCK, BUYER, block.timestamp);
        vm.stopPrank();
        _assertBondFunding(composedDetf, staking_, nft_, id_, expected_);
    }
    function test_primaryMintJoinsActualPaymentAndFundsImmediateRewards() public {
        _useComposed(_deployComposed(0, 0)); _bootstrapComposed(BUYER);
        for (uint256 i_; i_ < 3; ++i_) {
            _donateEpochCapital(_nft(), IERC20(address(composedStable)), 2_000 ether, owner);
            _donateEpochCapital(_nft(), IERC20(address(composedCommon)), 2_000 ether, owner);
        }
        _assertPrimaryMint(PrimaryContext(composedDetf, _staking(), _nft(), IVault(address(vault)),
            IERC20(address(composedStable)), 10 ether, owner));
    }
    function test_primaryBurnUsesOwnedLpAndPreservesExternalLiquidity() public {
        _useComposed(_deployComposed(100e18, 10e18));
        (uint256 id_,) = _bootstrapComposed(BUYER);
        uint256 principal_ = _claimedBurnPrincipal(composedDetf, _staking(), _nft(), id_, BUYER);
        _assertOwnedLpBurn(PrimaryContext(composedDetf, _staking(), _nft(), IVault(address(vault)),
            IERC20(address(composedStable)), principal_ / 20, BUYER), address(router), address(permit2), owner, 10 ether);
    }
}
