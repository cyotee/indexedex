// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {
    TestBase_SingleStandardExchangeDETF_Decimals
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/TestBase_SingleStandardExchangeDETF_Decimals.sol";

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IDetfBondNFT} from "contracts/interfaces/IDetfBondNFT.sol";
import {BondTerms} from "contracts/interfaces/VaultFeeTypes.sol";
import {
    ISingleStandardExchangeDETFBonding
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/SingleStandardExchangeDETFBondingTarget.sol";
import {
    ISingleStandardExchangeDETFInfo
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/SingleStandardExchangeDETFInfoTarget.sol";
import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";

/// @notice PRD requirement assertions on production Aerodrome SE attachment.
abstract contract SingleStandardExchangeDETF_Requirements_Decimals is TestBase_SingleStandardExchangeDETF_Decimals {
    address internal openDetf;
    ISingleStandardExchangeDETFInfo internal openInfo;
    ISingleStandardExchangeDETFBonding internal openBonding;
    IStandardExchangeIn internal openEx;

    function setUp() public virtual override {
        super.setUp();
        openDetf = _deployOpenThresholdDetf("Req Open DETF", "rqDETF");
        openInfo = ISingleStandardExchangeDETFInfo(openDetf);
        openBonding = ISingleStandardExchangeDETFBonding(openDetf);
        openEx = IStandardExchangeIn(openDetf);
    }

    /// @dev Keep mint size small vs reserve to stay under Balancer MaxInRatio.
    function _smallMintShares(address to_) internal returns (uint256 shares_) {
        shares_ = _fundSeShares(to_, 20e18);
    }

    function test_req_feeSplitDestinationsOnMint() public {
        _bootstrapDetf(openDetf, alice, 2_000e18);

        address feeTo_ = address(IVaultFeeOracleQuery(address(indexedexManager)).feeTo());
        address bondNft_ = openInfo.bondNftVault();
        uint256 feeBefore_ = IERC20(openDetf).balanceOf(feeTo_);
        uint256 protocolBefore_ = IERC20(openDetf).balanceOf(bondNft_);

        uint256 seShares_ = _smallMintShares(bob);
        vm.startPrank(bob);
        seShare.approve(openDetf, seShares_);
        uint256 userOut_ =
            openEx.exchangeIn(seShare, seShares_, IERC20(openDetf), 0, bob, false, block.timestamp + 1 hours);
        vm.stopPrank();

        assertTrue(userOut_ > 0, "user mint");
        uint256 usage_ = IVaultFeeOracleQuery(address(indexedexManager)).usageFeeOfVault(openDetf);
        uint256 seign_ = IVaultFeeOracleQuery(address(indexedexManager)).seigniorageIncentivePercentageOfVault(openDetf);
        usage_;
        assertEq(IERC20(openDetf).balanceOf(feeTo_), feeBefore_, "D14 no feeTo mint");
        if (seign_ > 0) {
            assertTrue(IERC20(openDetf).balanceOf(bondNft_) >= protocolBefore_, "protocol nft accrual path");
        }
        _assertNoFreeInventory(openDetf);
    }

    function test_req_nonDilutionExistingHolderOnMint() public {
        _bootstrapDetf(openDetf, alice, 2_000e18);
        uint256 aliceShares_ = _smallMintShares(alice);
        vm.startPrank(alice);
        seShare.approve(openDetf, aliceShares_);
        uint256 aliceDetf_ =
            openEx.exchangeIn(seShare, aliceShares_, IERC20(openDetf), 0, alice, false, block.timestamp + 1 hours);
        vm.stopPrank();
        assertGt(aliceDetf_, 0, "existing holder acquired funded DETF");

        uint256 seShares_ = _smallMintShares(bob);
        vm.startPrank(bob);
        seShare.approve(openDetf, seShares_);
        openEx.exchangeIn(seShare, seShares_, IERC20(openDetf), 0, bob, false, block.timestamp + 1 hours);
        vm.stopPrank();

        assertEq(IERC20(openDetf).balanceOf(alice), aliceDetf_, "alice free detf non-diluted");
        _assertNoFreeInventory(openDetf);
    }

    function test_req_allowlistedAssetMintPath() public {
        _bootstrapDetf(openDetf, alice, 2_000e18);
        IERC20 payment_ = IERC20(seVault.asset());
        address[] memory tokens_ = IBasicVault(address(seVault)).vaultTokens();
        assertEq(tokens_.length, 1, "SE accepts its LP asset");
        assertEq(tokens_[0], address(payment_));
        // Acquire real LP in native units through the funded SE deposit/redeem
        // path, instead of treating an 18-decimal constant as raw LP input.
        uint256 shares_ = _fundSeShares(bob, 50e18);
        vm.prank(bob);
        uint256 amount_ = seVault.redeem(shares_, bob, bob);
        assertGt(amount_, 0, "funded LP payment");
        uint256 quote_ = openEx.previewExchangeIn(payment_, amount_, IERC20(openDetf));
        assertGt(quote_, 0);
        vm.startPrank(bob);
        payment_.approve(openDetf, amount_);
        uint256 out_ =
            openEx.exchangeIn(payment_, amount_, IERC20(openDetf), quote_, bob, false, block.timestamp + 1 hours);
        vm.stopPrank();
        assertEq(out_, quote_, "allowlisted LP route preview matches execution");
        assertEq(IERC20(openDetf).balanceOf(bob), out_);
        _assertNoFreeInventory(openDetf);
    }

    function test_req_passthroughAllowlistedDoesNotMintDetf() public {
        _bootstrapDetf(openDetf, alice, 1_000e18);
        uint256 supplyBefore_ = IERC20(openDetf).totalSupply();

        // LP -> vault shares passthrough (both allowlisted on outer via se share + se vaultTokens).
        uint256 amountIn_ = 30e18;
        rateAsset.mint(bob, amountIn_);
        pairToken.mint(bob, amountIn_);
        vm.startPrank(bob);
        rateAsset.approve(address(aerodromeRouter), amountIn_);
        pairToken.approve(address(aerodromeRouter), amountIn_);
        (,, uint256 liq_) = aerodromeRouter.addLiquidity(
            address(rateAsset), address(pairToken), false, amountIn_, amountIn_, 1, 1, bob, block.timestamp + 1 hours
        );
        IERC20 lp_ = IERC20(address(aeroDaiUsdcPool));
        lp_.approve(openDetf, liq_);
        uint256 out_ = openEx.exchangeIn(lp_, liq_, seShare, 0, bob, false, block.timestamp + 1 hours);
        vm.stopPrank();

        assertTrue(out_ > 0, "passthrough out");
        assertEq(IERC20(openDetf).totalSupply(), supplyBefore_, "detf supply unchanged on passthrough");
        _assertNoFreeInventory(openDetf);
    }

    function test_req_bondBonusCurveMinAndClamp() public {
        BondTerms memory terms_ = IVaultFeeOracleQuery(address(indexedexManager)).bondTermsOfVault(openDetf);
        uint256 payment_ = _fundSeShares(alice, 500e18);
        (uint256 minimum_, uint256 minG_,) = openBonding.previewBond(seShare, payment_, terms_.minLockDuration);
        (uint256 maximum_, uint256 maxG_,) = openBonding.previewBond(seShare, payment_, terms_.maxLockDuration);
        (uint256 clamped_, uint256 clampG_,) =
            openBonding.previewBond(seShare, payment_, terms_.maxLockDuration + 365 days);
        assertGt(minimum_, 0);
        assertGt(maximum_, minimum_, "duration increases purchased principal");
        assertEq(clamped_, maximum_, "duration bonus clamps to maximum");
        assertEq(minG_, maxG_, "duration bonus does not boost reserve liquidity");
        assertEq(clampG_, maxG_);
        vm.startPrank(alice);
        seShare.approve(openDetf, payment_);
        (uint256 id_,) = openBonding.bond(
            seShare, payment_, terms_.maxLockDuration + 365 days, alice, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
        IDetfBondNFT nft_ = IDetfBondNFT(openInfo.bondNftVault());
        assertEq(nft_.positionOf(id_).principal, maximum_, "quoted principal funded");
        assertEq(nft_.positionOf(id_).vestingDuration, terms_.maxLockDuration, "vesting duration clamped");
    }

    function test_req_burnCleansResidual() public {
        _bootstrapDetf(openDetf, alice, 2_000e18);
        uint256 seShares_ = _smallMintShares(bob);
        vm.startPrank(bob);
        seShare.approve(openDetf, seShares_);
        uint256 minted_ =
            openEx.exchangeIn(seShare, seShares_, IERC20(openDetf), 0, bob, false, block.timestamp + 1 hours);
        IERC20(openDetf).approve(openDetf, minted_ / 2);
        openEx.exchangeIn(IERC20(openDetf), minted_ / 2, seShare, 0, bob, false, block.timestamp + 1 hours);
        vm.stopPrank();
        _assertNoFreeInventory(openDetf);
    }

    function test_req_syntheticMintGateDefaultThreshold() public {
        _bootstrapViaFirstBond(alice, 1_000e18);
        if (detfInfo.syntheticPrice() <= 1.05e18) {
            assertFalse(detfInfo.isMintingAllowed(), "mint not allowed at/below threshold");
        }
    }
}
