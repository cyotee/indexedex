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
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IStandardizedYield} from "@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {IStakedDETF} from "contracts/interfaces/IStakedDETF.sol";
import {IDetfBondNFT} from "contracts/interfaces/IDetfBondNFT.sol";
import {DETFFundedStakingMath as Math} from "contracts/vaults/detf/common/core/DETFFundedStakingMath.sol";
import {TestBase_MultiVaultWeightedDetf} from "contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/TestBase_MultiVaultWeightedDetf.sol";
import {IMultiVaultWeightedDetfBonding} from "contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/IMultiVaultWeightedDetfBonding.sol";
import {MultiVaultWeightedDetfDFPkg} from "contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/MultiVaultWeightedDetfDFPkg.sol";
import {IMultiVaultWeightedDetfDFPkg} from "contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/IMultiVaultWeightedDetfDFPkg.sol";

contract MultiWeightedFundedStakingTest is TestBase_MultiVaultWeightedDetf, FundedReserveDonationAssertions, FundedBalancerEpochAssertions, FundedBondCloseAssertions, FundedRewardAssertions, FundedPrimaryRouteAssertions, FundedThresholdAssertions {
    function test_inertPrimaryRouteRequiresFirstBond() public {
        uint256 amount_ = _fundSeSharesLeg(0, address(this), 1 ether);
        _assertInertRoute(detf, seShares[0], amount_);
    }
    function _deployThresholdPair(uint256 mint_, uint256 burn_) internal override returns (address) { return _deployDetfN(1, mint_, burn_, false); }

    address internal constant BUYER = address(0xB010);
    address internal constant TRADER = address(0xADE0);
    function _staking() internal view returns (IStakedDETF) { return IStakedDETF(detfInfo.rebasingClaimToken()); }
    function _nft() internal view returns (IDetfBondNFT) { return IDetfBondNFT(detfInfo.bondNftVault()); }

    function test_multiNativeMetadataAndRegisteredChildSYs() public view {
        _assertFundedEpochConfiguration(detf);
        assertEq(IERC20Metadata(detf).decimals(), 9);
        assertEq(_staking().decimals(), 9);
        assertEq(IStandardizedYield(detfInfo.rawSY()).yieldToken(), detf);
        assertEq(IStandardizedYield(detfInfo.stakingSY()).yieldToken(), address(_staking()));
        assertEq(detfInfo.epochAnchor(), 0);
        address[] memory facets_ = IDiamondLoupe(detf).facetAddresses();
        for (uint256 i; i < facets_.length; ++i) assertLe(facets_[i].code.length, 24_576);
        assertLe(address(multiVaultWeightedDetfPkg).code.length, 24_576);
    }

    function test_twoLegBootstrapFundsSeparatePrincipalAndWeightMatchedLiquidity() public {
        _useDetf(_deployDetfN(2, 0, 0, true));
        uint256[] memory shares_ = _fundBootstrapAmounts(detf, BUYER, 1_000 ether);
        (uint256 principal_, uint256 liquidity_, uint256 pot_) = detfBonding.previewInitializeReserve(shares_, DEFAULT_MIN_LOCK);
        assertEq(liquidity_, (shares_[0] + shares_[1]) / 1e9, "retained 50/50 aggregate liquidity seed");
        vm.prank(BUYER);
        (uint256 id_, uint256 lp_) = detfBonding.initializeReserve(shares_, DEFAULT_MIN_LOCK, BUYER, block.timestamp);
        assertEq(_nft().positionOf(id_).principal, principal_);
        assertEq(IERC20(detf).totalSupply(), principal_ + liquidity_ + pot_);
        assertGe(IERC20(detfInfo.reservePool()).balanceOf(address(_nft())), lp_);
        assertGe(_staking().balanceOf(address(_nft())), principal_);
        assertEq(IERC20(detf).balanceOf(address(_staking())), _staking().stakingState().accountedBacking);
    }

    function test_singleLegBondAndSevenLegBootstrapBothFundEscrow() public {
        uint256 shares_ = _fundSeSharesLeg(0, BUYER, 1_000 ether);
        vm.startPrank(BUYER);
        seShares[0].approve(detf, shares_);
        (uint256 one_,) = detfBonding.bond(seShares[0], shares_, DEFAULT_MIN_LOCK, BUYER, false, block.timestamp);
        vm.stopPrank();
        assertGt(_nft().positionOf(one_).principal, 0);
        _useDetf(_deployDetfN(7, 0, 0, true));
        (uint256 seven_, uint256 lp_) = _bootstrapViaFirstBond(BUYER, 1_000 ether);
        assertEq(detfInfo.vaultCount(), 7);
        assertGt(lp_, 0);
        assertGe(_staking().balanceOf(address(_nft())), _nft().positionOf(seven_).principal);
    }

    function test_multiDurationBonusDoesNotIncreaseLiquidityPayment() public {
        _useDetf(_deployDetfN(2, 0, 0, true));
        uint256[] memory amounts_ = _fundBootstrapAmounts(detf, BUYER, 1_000 ether);
        (uint256 short_, uint256 shortG_,) = detfBonding.previewInitializeReserve(amounts_, DEFAULT_MIN_LOCK);
        (uint256 long_, uint256 longG_,) = detfBonding.previewInitializeReserve(amounts_, DEFAULT_MAX_LOCK);
        assertGt(long_, short_);
        assertEq(longG_, shortG_);
    }

    function test_multiHalfwayClaimAndUnstakeDoNotWithdrawLP() public {
        _useDetf(_deployDetfN(2, 100e18, 0.1e18, true));
        (uint256 id_,) = _bootstrapViaFirstBond(BUYER, 1_000 ether);
        IDetfBondNFT nft_ = _nft();
        Math.BondPosition memory p_ = nft_.positionOf(id_);
        uint256 lp_ = IERC20(detfInfo.reservePool()).balanceOf(address(nft_));
        vm.warp(p_.startTimestamp + p_.vestingDuration / 2);
        vm.prank(BUYER);
        (uint256 principal_, uint256 rewards_) = nft_.claimBond(id_, BUYER);
        assertEq(principal_, p_.principal / 2);
        IStakedDETF staking_ = _staking();
        vm.prank(BUYER);
        staking_.exchangeIn(IERC20(address(staking_)), principal_ + rewards_, IERC20(detf), principal_ + rewards_, BUYER, false, block.timestamp);
        assertEq(IERC20(detf).balanceOf(BUYER), principal_ + rewards_);
        assertEq(IERC20(detfInfo.reservePool()).balanceOf(address(nft_)), lp_);
    }

    function test_multiGatedMintUsesReserveSwapWithoutIssuance() public {
        _useDetf(_deployDetfN(2, 100e18, 0.1e18, true));
        _bootstrapViaFirstBond(BUYER, 1_000 ether);
        assertFalse(detfInfo.isMintingAllowed());
        uint256 shares_ = _fundSeSharesLeg(1, TRADER, 10 ether);
        uint256 supply_ = IERC20(detf).totalSupply();
        uint256 backing_ = _staking().stakingState().accountedBacking;
        uint256 quote_ = detfExchangeIn.previewExchangeIn(seShares[1], shares_, IERC20(detf));
        vm.startPrank(TRADER);
        seShares[1].approve(detf, shares_);
        assertEq(detfExchangeIn.exchangeIn(seShares[1], shares_, IERC20(detf), quote_, TRADER, false, block.timestamp), quote_);
        vm.stopPrank();
        assertGt(quote_, 0);
        assertEq(IERC20(detf).totalSupply(), supply_);
        assertEq(_staking().stakingState().accountedBacking, backing_);
    }

    function test_multiGatedBurnUsesReserveSwapWithoutBurningSupply() public {
        _useDetf(_deployDetfN(2, 100e18, 0.1e18, true));
        (uint256 id_,) = _bootstrapViaFirstBond(BUYER, 1_000 ether);
        IDetfBondNFT nft_ = _nft();
        vm.warp(block.timestamp + DEFAULT_MIN_LOCK);
        vm.prank(BUYER);
        (uint256 principal_, uint256 rewards_) = nft_.claimBond(id_, BUYER);
        IStakedDETF staking_ = _staking();
        vm.prank(BUYER);
        staking_.exchangeIn(IERC20(address(staking_)), principal_ + rewards_, IERC20(detf), 0, BUYER, false, block.timestamp);
        assertFalse(detfInfo.isBurningAllowed());
        uint256 amount_ = principal_ / 100;
        uint256 supply_ = IERC20(detf).totalSupply();
        uint256 quoted_ = detfExchangeIn.previewExchangeIn(IERC20(detf), amount_, seShares[1]);
        vm.startPrank(BUYER);
        IERC20(detf).approve(detf, amount_);
        assertEq(detfExchangeIn.exchangeIn(IERC20(detf), amount_, seShares[1], quoted_, BUYER, false, block.timestamp), quoted_);
        vm.stopPrank();
        assertEq(IERC20(detf).totalSupply(), supply_);
    }

    function test_multiFixedEpochCatchupAdvancesWhenIneligible() public {
        _useDetf(_deployDetfN(2, 100e18, 0.1e18, true));
        _bootstrapViaFirstBond(BUYER, 1_000 ether);
        uint256 anchor_ = detfInfo.epochAnchor();
        vm.warp(anchor_ + 25 hours);
        assertEq(detfInfo.synchronizeRewards(), 0);
        assertEq(detfInfo.lastExpansionTimestamp(), anchor_ + 24 hours);
        vm.warp(anchor_ + 7 days);
        assertEq(detfInfo.synchronizeRewards(), 0);
        assertEq(detfInfo.lastExpansionTimestamp(), anchor_ + 7 days);
    }

    function test_multiDonationsUseActualJoinQuoteWithoutStakingIssuance() public {
        _useDetf(_deployDetfN(2, 100e18, 0.1e18, true));
        (uint256 id_,) = _bootstrapViaFirstBond(BUYER, 1_000 ether);
        uint256 shares_ = _fundSeSharesLeg(1, TRADER, 10 ether);
        vm.warp(block.timestamp + 25 hours);
        _assertFundedDonation(detf, _nft(), _staking(), seShares[1], shares_, TRADER, id_);
        IDetfBondNFT nft_ = _nft(); IStakedDETF staking_ = _staking();
        vm.warp(nft_.positionOf(id_).startTimestamp + DEFAULT_MIN_LOCK / 2);
        vm.prank(BUYER); uint256 vested_ = nft_.claimPrincipal(id_, BUYER);
        vm.prank(BUYER); staking_.exchangeIn(IERC20(address(staking_)), vested_, IERC20(detf), vested_, BUYER, false, block.timestamp);
        vm.warp(block.timestamp + 25 hours);
        _assertFundedDonation(detf, nft_, staking_, IERC20(detf), vested_ / 100, BUYER, id_);
    }

    function test_multiPositiveEpochCatchupFundsOneAggregateWithoutLpChange() public {
        IMultiVaultWeightedDetfDFPkg.PkgArgs memory args_ = _buildPkgArgs(2, 0, 0, true);
        args_.expansionClosureRatePerSecond = 1e12; _useDetf(_deployWithArgs(args_));
        _bootstrapViaFirstBond(BUYER, 1_000 ether);
        uint256 second_ = _fundSeSharesLeg(0, TRADER, 10 ether);
        vm.startPrank(TRADER); seShares[0].approve(detf, second_);
        detfBonding.bond(seShares[0], second_, DEFAULT_MIN_LOCK, TRADER, false, block.timestamp);
        vm.stopPrank();
        for (uint8 i_; i_ < 2; ++i_) {
            uint256 shares_ = _fundSeSharesLeg(i_, TRADER, 5_000 ether);
            _donateEpochCapital(_nft(), seShares[i_], shares_, TRADER);
        }
        _assertFundedBalancerEpochs(detf, _staking(), _nft(), detfInfo.syntheticPrice());
    }

    function test_finalFundedClaimPaysOnlyStakingAndRetiresBond() public {
        _useDetf(_deployDetfN(2, 100e18, 0.1e18, true));
        (uint256 id_,) = _bootstrapViaFirstBond(BUYER, 1_000 ether);
        IERC20[] memory payments_ = new IERC20[](2);
        payments_[0] = seShares[0]; payments_[1] = seShares[1];
        _assertFinalFundedClaim(detf, _nft(), _staking(), id_, BUYER, payments_);
    }
    function test_standingRecipientsExitAndReceiveLaterBondFundingAtExactFloors() public {
        _bootstrapViaFirstBond(BUYER, 1_000 ether);
        uint256 amount_ = _fundSeSharesLeg(0, TRADER, 10 ether);
        IStakedDETF staking_ = _staking(); IDetfBondNFT nft_ = _nft();
        _exitStandingReceiptsAndChangeOracle(detf, staking_, nft_, address(indexedexManager), owner);
        (uint256 principal_,, uint256 pot_) = detfBonding.previewBond(seShares[0], amount_, DEFAULT_MIN_LOCK);
        FundingExpectation memory expected_ = _expectedBondFunding(detf, staking_, nft_, address(indexedexManager), principal_, pot_);
        vm.startPrank(TRADER); seShares[0].approve(detf, amount_);
        (uint256 id_,) = detfBonding.bond(seShares[0], amount_, DEFAULT_MIN_LOCK, TRADER, false, block.timestamp);
        vm.stopPrank();
        _assertBondFunding(detf, staking_, nft_, id_, expected_);
    }
    function test_primaryMintJoinsActualPaymentAndFundsImmediateRewards() public {
        _useDetf(_deployDetfN(2, 0, 0, true)); _bootstrapViaFirstBond(BUYER, 1_000 ether);
        for (uint8 i_; i_ < 2; ++i_) {
            uint256 donation_ = _fundSeSharesLeg(i_, TRADER, 5_000 ether);
            _donateEpochCapital(_nft(), seShares[i_], donation_, TRADER);
        }
        uint256 amount_ = _fundSeSharesLeg(1, TRADER, 10 ether);
        _assertPrimaryMint(PrimaryContext(detf, _staking(), _nft(), IVault(address(vault)), seShares[1], amount_, TRADER));
    }
    function test_primaryBurnUsesOwnedLpAndPreservesExternalLiquidity() public {
        _useDetf(_deployDetfN(2, 100e18, 10e18, true));
        (uint256 id_,) = _bootstrapViaFirstBond(BUYER, 1_000 ether);
        uint256 principal_ = _claimedBurnPrincipal(detf, _staking(), _nft(), id_, BUYER);
        uint256 externalPayment_ = _fundSeSharesLeg(1, TRADER, 10 ether);
        _assertOwnedLpBurn(PrimaryContext(detf, _staking(), _nft(), IVault(address(vault)), seShares[1], principal_ / 20, BUYER),
            address(router), address(permit2), TRADER, externalPayment_);
    }
}
