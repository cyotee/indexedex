// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {FundedThresholdAssertions} from "contracts/test/bases/FundedThresholdAssertions.sol";
import {FundedPrimaryRouteAssertions} from "contracts/test/bases/FundedPrimaryRouteAssertions.sol";
import {IVault} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IVault.sol";
import {FundedRewardAssertions} from "contracts/test/bases/FundedRewardAssertions.sol";
import {FundedBondCloseAssertions} from "contracts/test/bases/FundedBondCloseAssertions.sol";
import {FundedBalancerEpochAssertions} from "contracts/test/bases/FundedBalancerEpochAssertions.sol";
import {FundedReserveDonationAssertions} from "contracts/test/bases/FundedReserveDonationAssertions.sol";

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardizedYield} from "@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol";
import {VaultSwapParams, SwapKind} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/VaultTypes.sol";
import {IStakedDETF} from "contracts/interfaces/IStakedDETF.sol";
import {IStandardExchange} from "contracts/interfaces/IStandardExchange.sol";
import {IRateProvider} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRateProvider.sol";
import {IDetfBondNFT} from "contracts/interfaces/IDetfBondNFT.sol";
import {DETFFundedStakingMath as StakingMath} from "contracts/vaults/detf/common/core/DETFFundedStakingMath.sol";
import {DETFBalancerReserveSwapTarget} from "contracts/vaults/detf/protocols/dexes/balancer/v3/common/DETFBalancerReserveSwapTarget.sol";
import {ISingleStandardExchangeDETDFPkg} from "contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/ISingleStandardExchangeDETDFPkg.sol";
import {ISingleStandardExchangeDETFInfo} from "contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/ISingleStandardExchangeDETFInfo.sol";
import {ISingleStandardExchangeDETFBonding} from "contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/ISingleStandardExchangeDETFBonding.sol";
import {TestBase_SingleStandardExchangeDETF, ILegacySingleStandardExchangeDETFInfo, ILegacySingleStandardExchangeDETFBonding} from "contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/TestBase_SingleStandardExchangeDETF.sol";

/// @notice Single-SE family integration through production manager, reserve pool and child packages.
contract SingleSEFundedStakingTest is TestBase_SingleStandardExchangeDETF, FundedReserveDonationAssertions, FundedBalancerEpochAssertions, FundedBondCloseAssertions, FundedRewardAssertions, FundedPrimaryRouteAssertions, FundedThresholdAssertions {
    function test_inertPrimaryRouteRequiresFirstBond() public {
        uint256 amount_ = _fundSeShares(address(this), 1 ether);
        _assertInertRoute(detf, IERC20(address(seVault)), amount_);
    }
    function _deployThresholdPair(uint256 mint_, uint256 burn_) internal override returns (address) { return _deployPolicyThresholds(mint_, burn_); }

    address internal constant BONDER = address(0xB0D);
    address internal constant TRADER = address(0xADE);

    function _staking() internal view returns (IStakedDETF) { return IStakedDETF(detfInfo.rebasingClaimToken()); }
    function _nft() internal view returns (IDetfBondNFT) { return IDetfBondNFT(detfInfo.bondNftVault()); }

    function test_rateProviderNormalizesNineDecimalStakingSubject() public {
        _bootstrapViaFirstBond(BONDER, 1_000 ether);
        IStakedDETF staking_ = _staking();
        IRateProvider provider_ = rateProviderPkg.deployRateProvider(
            IStandardExchange(address(staking_)), IERC20(address(staking_)), IERC20(detf)
        );
        assertEq(provider_.getRate(), 1e18, "one sDETF redeems for one DETF");
    }

    function test_nativeUnitsAndFundedSYDeployment() public view {
        _assertFundedEpochConfiguration(detf);
        assertEq(IERC20Metadata(detf).decimals(), 9);
        assertEq(_staking().decimals(), 9);
        assertEq(_staking().totalSupply(), 0);
        assertEq(detfInfo.epochAnchor(), 0);
        assertEq(IERC20Metadata(detfInfo.rawSY()).decimals(), 9);
        assertEq(IERC20Metadata(detfInfo.stakingSY()).decimals(), 9);
        assertEq(IStandardizedYield(detfInfo.rawSY()).yieldToken(), detf);
        assertEq(IStandardizedYield(detfInfo.stakingSY()).yieldToken(), address(_staking()));
        address facet_ = IDiamondLoupe(detf).facetAddress(IStandardExchangeIn.exchangeIn.selector);
        assertLe(facet_.code.length, 24_576, "production exchange facet remains deployable");
        assertLe(IDiamondLoupe(detf).facetAddress(ISingleStandardExchangeDETFBonding.bond.selector).code.length, 24_576);
    }

    function test_deploymentRequiresTheFundedStakingPackage() public {
        _expectRevertDeployPkgWithZeroClaim();
    }

    function test_firstBondFundsQuotedPrincipalSeparatelyFromProtocolLiquidity() public {
        uint256 shares_ = _fundSeShares(BONDER, 1_000 ether);
        (uint256 principal_, uint256 liquidity_, uint256 pot_) = detfBonding.previewBond(seShare, shares_, DEFAULT_MIN_LOCK);
        vm.startPrank(BONDER);
        seShare.approve(detf, shares_);
        (uint256 id_, uint256 lp_) = detfBonding.bond(seShare, shares_, DEFAULT_MIN_LOCK, BONDER, false, block.timestamp);
        vm.stopPrank();
        assertEq(_nft().positionOf(id_).principal, principal_);
        assertEq(liquidity_, shares_ * 4 / 1e9, "retained 80/20 weight-only liquidity seed");
        assertEq(IERC20(detf).totalSupply(), principal_ + liquidity_ + pot_);
        assertEq(IERC20(detf).balanceOf(BONDER), 0);
        assertEq(detfInfo.epochAnchor(), block.timestamp);
        assertGt(lp_, 0);
        assertGe(IERC20(detfInfo.reservePool()).balanceOf(address(_nft())), lp_);
        assertEq(IERC20(detf).balanceOf(address(_staking())), _staking().stakingState().accountedBacking);
        assertGe(_staking().balanceOf(address(_nft())), principal_);
    }

    function test_firstBondDurationChangesOnlyPurchasedQuote() public {
        uint256 shares_ = _fundSeShares(BONDER, 1_000 ether);
        (uint256 short_, uint256 joinShort_,) = detfBonding.previewBond(seShare, shares_, DEFAULT_MIN_LOCK);
        (uint256 long_, uint256 joinLong_,) = detfBonding.previewBond(seShare, shares_, DEFAULT_MAX_LOCK);
        assertGt(long_, short_, "longer lock buys discounted principal");
        assertEq(joinLong_, joinShort_, "only actual payment enters liquidity");
    }

    function test_halfwayClaimPaysStakingWithoutWithdrawingReserveLp() public {
        (uint256 id_,) = _bootstrapViaFirstBond(BONDER, 1_000 ether);
        IDetfBondNFT nft_ = _nft();
        StakingMath.BondPosition memory p_ = nft_.positionOf(id_);
        uint256 lp_ = IERC20(detfInfo.reservePool()).balanceOf(address(nft_));
        vm.warp(p_.startTimestamp + p_.vestingDuration / 2);
        vm.prank(BONDER);
        (uint256 principal_, uint256 rewards_) = nft_.claimBond(id_, BONDER);
        assertEq(principal_, p_.principal / 2);
        assertEq(_staking().balanceOf(BONDER), principal_ + rewards_);
        assertEq(IERC20(detfInfo.reservePool()).balanceOf(address(nft_)), lp_);
        IStakedDETF staking_ = _staking();
        vm.prank(BONDER);
        staking_.exchangeIn(IERC20(address(staking_)), principal_ + rewards_, IERC20(detf), 0, BONDER, false, block.timestamp);
        assertEq(IERC20(detf).balanceOf(BONDER), principal_ + rewards_);
    }

    function _wideDeadband() internal {
        detf = _deployPolicyThresholds(1e30, 1);
        detfInfo = ILegacySingleStandardExchangeDETFInfo(detf);
        detfBonding = ILegacySingleStandardExchangeDETFBonding(detf);
        detfExchangeIn = IStandardExchangeIn(detf);
        _bootstrapViaFirstBond(BONDER, 1_000 ether);
    }

    function test_gatedMintSwapsWithoutIssuanceOrSeigniorage() public {
        _wideDeadband();
        assertFalse(detfInfo.isMintingAllowed());
        uint256 shares_ = _fundSeShares(TRADER, 10 ether);
        uint256 quote_ = detfExchangeIn.previewExchangeIn(seShare, shares_, IERC20(detf));
        uint256 supply_ = IERC20(detf).totalSupply();
        uint256 backing_ = _staking().stakingState().accountedBacking;
        vm.startPrank(TRADER);
        seShare.approve(detf, shares_);
        uint256 paid_ = detfExchangeIn.exchangeIn(seShare, shares_, IERC20(detf), quote_, TRADER, false, block.timestamp);
        vm.stopPrank();
        assertEq(paid_, quote_);
        assertGt(paid_, 0);
        assertEq(IERC20(detf).totalSupply(), supply_);
        assertEq(_staking().stakingState().accountedBacking, backing_);
    }

    function test_gatedBurnSwapsWithoutBurningSupply() public {
        _wideDeadband();
        uint256 shares_ = _fundSeShares(TRADER, 10 ether);
        vm.startPrank(TRADER);
        seShare.approve(detf, shares_);
        uint256 bought_ = detfExchangeIn.exchangeIn(seShare, shares_, IERC20(detf), 0, TRADER, false, block.timestamp);
        uint256 supply_ = IERC20(detf).totalSupply();
        IERC20(detf).approve(detf, bought_);
        uint256 quote_ = detfExchangeIn.previewExchangeIn(IERC20(detf), bought_, seShare);
        uint256 paid_ = detfExchangeIn.exchangeIn(IERC20(detf), bought_, seShare, quote_, TRADER, false, block.timestamp);
        vm.stopPrank();
        assertEq(paid_, quote_);
        assertGt(paid_, 0);
        assertEq(IERC20(detf).totalSupply(), supply_);
    }

    function test_ineligibleCatchupConsumesAllCompletedBoundaries() public {
        _wideDeadband();
        uint256 anchor_ = detfInfo.epochAnchor();
        vm.warp(anchor_ + 25 hours);
        assertEq(detfInfo.synchronizeRewards(), 0);
        assertEq(detfInfo.lastExpansionTimestamp(), anchor_ + 24 hours);
        vm.warp(anchor_ + 7 days + 1 hours);
        assertEq(detfInfo.synchronizeRewards(), 0);
        assertEq(detfInfo.lastExpansionTimestamp(), anchor_ + 7 days);
    }

    function test_reserveCallbackCannotBeCalledOutsideAuthorizedSwap() public {
        VaultSwapParams memory p_ = VaultSwapParams({
            kind: SwapKind.EXACT_IN, pool: detfInfo.reservePool(), tokenIn: seShare, tokenOut: IERC20(detf),
            amountGivenRaw: 1, limitRaw: 0, userData: ""
        });
        vm.expectRevert(DETFBalancerReserveSwapTarget.UnauthorizedReserveSwap.selector);
        DETFBalancerReserveSwapTarget(detf).executeReserveSwap(p_);
        vm.prank(address(vault));
        vm.expectRevert(DETFBalancerReserveSwapTarget.UnauthorizedReserveSwap.selector);
        DETFBalancerReserveSwapTarget(detf).executeReserveSwap(p_);
    }

    function test_singleDonationsUseActualJoinQuoteWithoutStakingIssuance() public {
        (uint256 id_,) = _bootstrapViaFirstBond(BONDER, 1_000 ether);
        uint256 shares_ = _fundSeShares(TRADER, 10 ether);
        vm.warp(block.timestamp + 25 hours);
        _assertFundedDonation(detf, _nft(), _staking(), seShare, shares_, TRADER, id_);
        IDetfBondNFT nft_ = _nft(); IStakedDETF staking_ = _staking();
        vm.warp(nft_.positionOf(id_).startTimestamp + DEFAULT_MIN_LOCK / 2);
        vm.prank(BONDER); uint256 vested_ = nft_.claimPrincipal(id_, BONDER);
        vm.prank(BONDER); staking_.exchangeIn(IERC20(address(staking_)), vested_, IERC20(detf), vested_, BONDER, false, block.timestamp);
        vm.warp(block.timestamp + 25 hours);
        _assertFundedDonation(detf, nft_, staking_, IERC20(detf), vested_ / 100, BONDER, id_);
    }

    function test_singlePositiveEpochCatchupFundsOneAggregateWithoutLpChange() public {
        ISingleStandardExchangeDETDFPkg.PkgArgs memory args_ = _defaultArgs();
        args_.expansionClosureRatePerSecond = 1e12;
        detf = _deployWithArgs(args_); detfInfo = ILegacySingleStandardExchangeDETFInfo(detf); detfBonding = ILegacySingleStandardExchangeDETFBonding(detf);
        _bootstrapViaFirstBond(BONDER, 1_000 ether);
        _bootstrapViaFirstBond(BONDER, 10 ether);
        uint256 shares_ = _fundSeShares(TRADER, 50_000 ether);
        _donateEpochCapital(_nft(), seShare, shares_, TRADER);
        _assertFundedBalancerEpochs(detf, _staking(), _nft(), detfInfo.syntheticPrice());
    }

    function test_finalFundedClaimPaysOnlyStakingAndRetiresBond() public {
        detf = _deployPolicyThresholds(100e18, 0.1e18);
        detfInfo = ILegacySingleStandardExchangeDETFInfo(detf);
        detfBonding = ILegacySingleStandardExchangeDETFBonding(detf);
        (uint256 id_,) = _bootstrapViaFirstBond(BONDER, 1_000 ether);
        IERC20[] memory payments_ = new IERC20[](1); payments_[0] = seShare;
        _assertFinalFundedClaim(detf, _nft(), _staking(), id_, BONDER, payments_);
    }
    function test_standingRecipientsExitAndReceiveLaterBondFundingAtExactFloors() public {
        _bootstrapViaFirstBond(BONDER, 1_000 ether);
        uint256 amount_ = _fundSeShares(TRADER, 10 ether);
        IStakedDETF staking_ = _staking(); IDetfBondNFT nft_ = _nft();
        _exitStandingReceiptsAndChangeOracle(detf, staking_, nft_, address(indexedexManager), owner);
        (uint256 principal_,, uint256 pot_) = detfBonding.previewBond(seShare, amount_, DEFAULT_MIN_LOCK);
        FundingExpectation memory expected_ = _expectedBondFunding(detf, staking_, nft_, address(indexedexManager), principal_, pot_);
        vm.startPrank(TRADER); seShare.approve(detf, amount_);
        (uint256 id_,) = detfBonding.bond(seShare, amount_, DEFAULT_MIN_LOCK, TRADER, false, block.timestamp);
        vm.stopPrank();
        _assertBondFunding(detf, staking_, nft_, id_, expected_);
    }
    function test_primaryMintJoinsActualPaymentAndFundsImmediateRewards() public {
        _bootstrapViaFirstBond(BONDER, 1_000 ether);
        uint256 donation_ = _fundSeShares(TRADER, 50_000 ether);
        _donateEpochCapital(_nft(), seShare, donation_, TRADER);
        uint256 amount_ = _fundSeShares(TRADER, 10 ether);
        _assertPrimaryMint(PrimaryContext(detf, _staking(), _nft(), IVault(address(vault)), seShare, amount_, TRADER));
    }
    function test_primaryBurnUsesOwnedLpAndPreservesExternalLiquidity() public {
        detf = _deployPolicyThresholds(100e18, 10e18);
        detfInfo = ILegacySingleStandardExchangeDETFInfo(detf); detfBonding = ILegacySingleStandardExchangeDETFBonding(detf);
        (uint256 id_,) = _bootstrapViaFirstBond(BONDER, 1_000 ether);
        uint256 principal_ = _claimedBurnPrincipal(detf, _staking(), _nft(), id_, BONDER);
        uint256 externalPayment_ = _fundSeShares(TRADER, 10 ether);
        _assertOwnedLpBurn(PrimaryContext(detf, _staking(), _nft(), IVault(address(vault)), seShare, principal_ / 20, BONDER),
            address(router), address(permit2), TRADER, externalPayment_);
    }
}
