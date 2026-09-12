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
import {IStandardizedYield} from "@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {IStakedDETF} from "contracts/interfaces/IStakedDETF.sol";
import {IDetfBondNFT} from "contracts/interfaces/IDetfBondNFT.sol";
import {DETFFundedStakingMath as Math} from "contracts/vaults/detf/common/core/DETFFundedStakingMath.sol";
import {TestBase_MixedBufferMultiVaultStableDetf} from "contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/TestBase_MixedBufferMultiVaultStableDetf.sol";
import {MixedBufferMultiVaultStableDetfDFPkg, IMixedBufferMultiVaultStableDetfDFPkg} from "contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/MixedBufferMultiVaultStableDetfDFPkg.sol";
import {MixedBufferMultiVaultStablePoolFacet} from "contracts/protocols/dexes/balancer/v3/pools/stable/mixedBufferMultiVault/MixedBufferMultiVaultStablePoolFacet.sol";
import {MixedBufferMultiVaultStablePoolLiquidityFacet} from "contracts/protocols/dexes/balancer/v3/pools/stable/mixedBufferMultiVault/MixedBufferMultiVaultStablePoolLiquidityFacet.sol";
import {MixedBufferMultiVaultStablePoolHookFacet} from "contracts/protocols/dexes/balancer/v3/pools/stable/mixedBufferMultiVault/MixedBufferMultiVaultStablePoolHookFacet.sol";

contract MixedBufferFundedStakingTest is TestBase_MixedBufferMultiVaultStableDetf, FundedReserveDonationAssertions, FundedBalancerEpochAssertions, FundedBondCloseAssertions, FundedRewardAssertions, FundedPrimaryRouteAssertions, FundedThresholdAssertions {
    function test_inertPrimaryRouteRequiresFirstBond() public {
        _fundBuffer(address(this), 1 ether);
        _assertInertRoute(detf, IERC20(address(dai)), 1 ether);
    }
    function _deployThresholdPair(uint256 mint_, uint256 burn_) internal override returns (address) { return _deployDetfN(1, mint_, burn_); }

    address internal constant BUYER = address(0xB012);
    address internal constant TRADER = address(0xADEF);
    function _staking() internal view returns (IStakedDETF) { return IStakedDETF(detfInfo.rebasingClaimToken()); }
    function _nft() internal view returns (IDetfBondNFT) { return IDetfBondNFT(detfInfo.bondNftVault()); }

    function test_mixedNativeUnitsAndFundedSYRoutes() public view {
        _assertFundedEpochConfiguration(detf);
        assertEq(IERC20Metadata(detf).decimals(), 9);
        assertEq(_staking().decimals(), 9);
        assertEq(IStandardizedYield(detfInfo.rawSY()).yieldToken(), detf);
        assertEq(IStandardizedYield(detfInfo.stakingSY()).yieldToken(), address(_staking()));
        assertTrue(IStandardizedYield(detfInfo.rawSY()).isValidTokenIn(detfInfo.bufferToken()));
        assertTrue(IStandardizedYield(detfInfo.stakingSY()).isValidTokenOut(address(seShares[0])));
        address[] memory facets_ = IDiamondLoupe(detf).facetAddresses();
        for (uint256 i; i < facets_.length; ++i) assertLe(facets_[i].code.length, 24_576);
        assertLe(address(mixedBufferDetfPkg).code.length, 24_576);
    }

    function test_mixedFirstBondPurchasesFundedPrincipalInAdditionToLiquidity() public {
        uint256 shares_ = _fundVaultShares(0, BUYER, BOOTSTRAP_SHARE_FUND);
        _fundBuffer(BUYER, BOOTSTRAP_BUFFER);
        uint256[] memory amounts_ = new uint256[](1); amounts_[0] = shares_;
        (uint256 p_, uint256 g_, uint256 pot_) = detfBonding.previewBootstrapFirstBond(BOOTSTRAP_BUFFER, amounts_, DEFAULT_MIN_LOCK);
        assertEq(g_, (BOOTSTRAP_BUFFER + shares_) / 2 / 1e9);
        vm.startPrank(BUYER);
        dai.approve(detf, BOOTSTRAP_BUFFER); seShares[0].approve(detf, shares_);
        (uint256 id_, uint256 lp_, uint256 principal_) = detfBonding.bootstrapFirstBond(BOOTSTRAP_BUFFER, amounts_, DEFAULT_MIN_LOCK, BUYER, block.timestamp);
        vm.stopPrank();
        assertEq(principal_, p_);
        assertEq(_nft().positionOf(id_).principal, p_);
        assertEq(IERC20(detf).totalSupply(), p_ + g_ + pot_);
        assertEq(IERC20(detf).balanceOf(BUYER), 0);
        assertEq(IERC20(detfInfo.reservePool()).balanceOf(address(_nft())), lp_);
        assertGe(_staking().balanceOf(address(_nft())), p_);
    }

    function test_mixedThreeVaultBootstrapAndDurationQuote() public {
        _useDetf(_deployDetfN(3, 100e18, 0.1e18));
        (uint256 id_, uint256 lp_, uint256 p_) = _bootstrapDefault(detf, BUYER);
        assertGt(lp_, 0); assertEq(_nft().positionOf(id_).principal, p_);
        (uint256 short_, uint256 shortG_,) = detfBonding.previewBond(seShares[2], 1 ether, DEFAULT_MIN_LOCK);
        (uint256 long_, uint256 longG_,) = detfBonding.previewBond(seShares[2], 1 ether, DEFAULT_MAX_LOCK);
        assertGt(long_, short_); assertEq(longG_, shortG_);
    }

    function test_mixedHalfwayClaimUnstakesWithoutLPWithdrawal() public {
        _useDetf(_deployDetfN(1, 100e18, 0.1e18));
        (uint256 id_, uint256 lp_,) = _bootstrapDefault(detf, BUYER);
        Math.BondPosition memory p_ = _nft().positionOf(id_);
        vm.warp(p_.startTimestamp + p_.vestingDuration / 2);
        IDetfBondNFT nft_ = _nft();
        vm.prank(BUYER); (uint256 principal_, uint256 rewards_) = nft_.claimBond(id_, BUYER);
        assertEq(principal_, p_.principal / 2);
        IStakedDETF staking_ = _staking();
        vm.prank(BUYER); staking_.exchangeIn(IERC20(address(staking_)), principal_ + rewards_, IERC20(detf), 0, BUYER, false, block.timestamp);
        assertEq(IERC20(detf).balanceOf(BUYER), principal_ + rewards_);
        assertEq(IERC20(detfInfo.reservePool()).balanceOf(address(_nft())), lp_);
    }

    function test_mixedGatedBufferMintUsesSupplyNeutralSwap() public { _gatedMint(true); }
    function test_mixedGatedShareMintUsesSupplyNeutralSwap() public { _gatedMint(false); }
    function _gatedMint(bool buffer_) internal {
        _useDetf(_deployDetfN(1, 100e18, 0.1e18)); _bootstrapDefault(detf, BUYER);
        IERC20 input_ = buffer_ ? IERC20(address(dai)) : seShares[0];
        uint256 amount_ = 1 ether;
        if (buffer_) _fundBuffer(TRADER, amount_); else amount_ = _fundVaultShares(0, TRADER, amount_);
        uint256 supply_ = IERC20(detf).totalSupply();
        uint256 backing_ = _staking().stakingState().accountedBacking;
        uint256 quote_ = detfExchangeIn.previewExchangeIn(input_, amount_, IERC20(detf));
        vm.startPrank(TRADER); input_.approve(detf, amount_);
        assertEq(detfExchangeIn.exchangeIn(input_, amount_, IERC20(detf), quote_, TRADER, false, block.timestamp), quote_);
        vm.stopPrank();
        assertGt(quote_, 0); assertEq(IERC20(detf).totalSupply(), supply_);
        assertEq(_staking().stakingState().accountedBacking, backing_);
    }

    function test_mixedGatedBufferBurnUsesSupplyNeutralSwap() public { _gatedBurn(true); }
    function test_mixedGatedShareBurnUsesSupplyNeutralSwap() public { _gatedBurn(false); }
    function _gatedBurn(bool buffer_) internal {
        _useDetf(_deployDetfN(1, 100e18, 0.1e18));
        (uint256 id_,, uint256 p_) = _bootstrapDefault(detf, BUYER);
        vm.warp(block.timestamp + DEFAULT_MIN_LOCK);
        IDetfBondNFT nft_ = _nft();
        vm.prank(BUYER); nft_.claimBond(id_, BUYER);
        IStakedDETF staking_ = _staking();
        vm.prank(BUYER); staking_.exchangeIn(IERC20(address(staking_)), p_, IERC20(detf), p_, BUYER, false, block.timestamp);
        IERC20 out_ = buffer_ ? IERC20(address(dai)) : seShares[0];
        uint256 amount_ = p_ / 1000;
        uint256 quote_ = detfExchangeIn.previewExchangeIn(IERC20(detf), amount_, out_);
        uint256 supply_ = IERC20(detf).totalSupply();
        vm.startPrank(BUYER); IERC20(detf).approve(detf, amount_);
        assertEq(detfExchangeIn.exchangeIn(IERC20(detf), amount_, out_, quote_, BUYER, false, block.timestamp), quote_);
        vm.stopPrank();
        assertGt(quote_, 0); assertEq(IERC20(detf).totalSupply(), supply_);
    }

    function test_mixedFixedEpochConsumesSevenDaysWithoutCap() public {
        _useDetf(_deployDetfN(1, 100e18, 0.1e18)); _bootstrapDefault(detf, BUYER);
        uint256 anchor_ = detfInfo.epochAnchor();
        vm.warp(anchor_ + 25 hours); assertEq(detfInfo.synchronizeRewards(), 0);
        assertEq(detfInfo.lastExpansionTimestamp(), anchor_ + 24 hours);
        vm.warp(anchor_ + 7 days); assertEq(detfInfo.synchronizeRewards(), 0);
        assertEq(detfInfo.lastExpansionTimestamp(), anchor_ + 7 days);
    }

    function test_mixedDonationsQuoteTheConvertedBufferAndKeepFundedPrincipal() public {
        _useDetf(_deployDetfN(2, 100e18, 0.1e18));
        (uint256 id_,,) = _bootstrapDefault(detf, BUYER);
        uint256 shares_ = _fundVaultShares(1, TRADER, 10 ether); _fundBuffer(TRADER, 10 ether);
        vm.warp(block.timestamp + 25 hours);
        _assertFundedDonation(detf, _nft(), _staking(), seShares[1], shares_, TRADER, id_);
        _assertFundedDonation(detf, _nft(), _staking(), IERC20(address(dai)), 10 ether, TRADER, id_);
        IDetfBondNFT nft_ = _nft(); IStakedDETF staking_ = _staking();
        vm.warp(nft_.positionOf(id_).startTimestamp + DEFAULT_MIN_LOCK / 2);
        vm.prank(BUYER); uint256 vested_ = nft_.claimPrincipal(id_, BUYER);
        vm.prank(BUYER); staking_.exchangeIn(IERC20(address(staking_)), vested_, IERC20(detf), vested_, BUYER, false, block.timestamp);
        vm.warp(block.timestamp + 25 hours);
        _assertFundedDonation(detf, nft_, staking_, IERC20(detf), vested_ / 100, BUYER, id_);
    }

    function test_mixedPositiveEpochCatchupFundsOneAggregateWithoutLpChange() public {
        IMixedBufferMultiVaultStableDetfDFPkg.PkgArgs memory args_ = _buildPkgArgs(1, 0, 0);
        args_.expansionClosureRatePerSecond = 1e12; _useDetf(_deployWithArgs(args_));
        _bootstrapDefault(detf, BUYER);
        _fundBuffer(TRADER, 10 ether);
        vm.startPrank(TRADER); dai.approve(detf, 10 ether);
        detfBonding.bond(IERC20(address(dai)), 10 ether, DEFAULT_MIN_LOCK, TRADER, false, block.timestamp);
        vm.stopPrank();
        for (uint256 i_; i_ < 12; ++i_) {
            uint256 shares_ = _fundVaultShares(0, TRADER, BOOTSTRAP_SHARE_FUND);
            _donateEpochCapital(_nft(), seShares[0], shares_, TRADER);
        }
        _assertFundedBalancerEpochs(detf, _staking(), _nft(), detfInfo.syntheticPrice());
    }

    function test_finalFundedClaimPaysOnlyStakingAndRetiresBond() public {
        _useDetf(_deployDetfN(1, 100e18, 0.1e18));
        (uint256 id_,,) = _bootstrapDefault(detf, BUYER);
        IERC20[] memory payments_ = new IERC20[](2);
        payments_[0] = IERC20(address(dai)); payments_[1] = seShares[0];
        _assertFinalFundedClaim(detf, _nft(), _staking(), id_, BUYER, payments_);
    }
    function test_standingRecipientsExitAndReceiveLaterBondFundingAtExactFloors() public {
        _bootstrapDefault(detf, BUYER);
        uint256 amount_ = _fundVaultShares(0, TRADER, 10 ether);
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
        _bootstrapDefault(detf, BUYER);
        for (uint256 i_; i_ < 12; ++i_) {
            uint256 donation_ = _fundVaultShares(0, TRADER, BOOTSTRAP_SHARE_FUND);
            _donateEpochCapital(_nft(), seShares[0], donation_, TRADER);
        }
        uint256 amount_ = _fundVaultShares(0, TRADER, 10 ether);
        _assertPrimaryMint(PrimaryContext(detf, _staking(), _nft(), IVault(address(vault)), seShares[0], amount_, TRADER));
    }
    function test_primaryBurnUsesOwnedLpAndPreservesExternalLiquidity() public {
        _useDetf(_deployDetfN(1, 100e18, 10e18));
        (uint256 id_,,) = _bootstrapDefault(detf, BUYER);
        uint256 principal_ = _claimedBurnPrincipal(detf, _staking(), _nft(), id_, BUYER);
        uint256 externalPayment_ = _fundVaultShares(0, TRADER, 10 ether);
        _assertOwnedLpBurn(PrimaryContext(detf, _staking(), _nft(), IVault(address(vault)), seShares[0], principal_ / 20, BUYER),
            address(router), address(permit2), TRADER, externalPayment_);
    }
}
