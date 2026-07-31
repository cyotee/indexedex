// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IDETFNFTVault} from "contracts/interfaces/IDETFNFTVault.sol";
import {BondTerms} from "contracts/interfaces/VaultFeeTypes.sol";
import {DETFBondNFTMathLib} from "contracts/vaults/detf/common/core/DETFBondNFTMathLib.sol";
import {
    TestBase_SingleStandardExchangeDETF
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/TestBase_SingleStandardExchangeDETF.sol";
import {
    ISingleStandardExchangeDETFBonding
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/SingleStandardExchangeDETFBondingTarget.sol";
import {
    ISingleStandardExchangeDETFInfo
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/SingleStandardExchangeDETFInfoTarget.sol";
import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";

/// @notice PRD requirement assertions on production Aerodrome SE attachment.
contract SingleStandardExchangeDETF_Requirements_Test is TestBase_SingleStandardExchangeDETF {
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
        uint256 seign_ =
            IVaultFeeOracleQuery(address(indexedexManager)).seigniorageIncentivePercentageOfVault(openDetf);
        if (usage_ > 0) {
            assertTrue(IERC20(openDetf).balanceOf(feeTo_) > feeBefore_, "feeTo received");
        }
        if (seign_ > 0) {
            assertTrue(IERC20(openDetf).balanceOf(bondNft_) >= protocolBefore_, "protocol nft accrual path");
        }
        _assertNoFreeInventory(openDetf);
    }

    function test_req_nonDilutionExistingHolderOnMint() public {
        _bootstrapDetf(openDetf, alice, 2_000e18);
        uint256 aliceDetf_ = IERC20(openDetf).balanceOf(alice);
        assertTrue(aliceDetf_ > 0, "alice has free detf from bond split");

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

        // Use production SE vaultTokens() surface — pick first underlying that is not the share.
        address[] memory vt_ = IBasicVault(address(seVault)).vaultTokens();
        IERC20 tokenIn_;
        for (uint256 i; i < vt_.length; ++i) {
            if (vt_[i] != address(seShare) && vt_[i] != address(0)) {
                tokenIn_ = IERC20(vt_[i]);
                break;
            }
        }
        assertTrue(address(tokenIn_) != address(0), "se vault has allowlisted underlying");

        // Fund via known mintables when possible; else transfer from whale deposit path.
        uint256 amountIn_ = 50e18;
        if (address(tokenIn_) == address(dai)) {
            dai.mint(bob, amountIn_);
        } else if (address(tokenIn_) == address(usdc)) {
            usdc.mint(bob, amountIn_);
        } else {
            // LP path: acquire via _depositToVault then use LP if listed.
            // Fund bob with LP by depositing then withdrawing underlying path:
            // deposit mints se shares; for LP itself, mint LP via aero router.
            dai.mint(bob, amountIn_);
            usdc.mint(bob, amountIn_);
            vm.startPrank(bob);
            dai.approve(address(aerodromeRouter), amountIn_);
            usdc.approve(address(aerodromeRouter), amountIn_);
            (,, uint256 liq_) = aerodromeRouter.addLiquidity(
                address(dai), address(usdc), false, amountIn_, amountIn_, 1, 1, bob, block.timestamp + 1 hours
            );
            vm.stopPrank();
            tokenIn_ = IERC20(address(aeroDaiUsdcPool));
            amountIn_ = liq_;
        }

        vm.startPrank(bob);
        tokenIn_.approve(openDetf, amountIn_);
        uint256 out_ = openEx.exchangeIn(
            tokenIn_, amountIn_, IERC20(openDetf), 0, bob, false, block.timestamp + 1 hours
        );
        vm.stopPrank();

        assertTrue(out_ > 0, "minted via allowlisted asset");
        _assertNoFreeInventory(openDetf);
    }

    function test_req_passthroughAllowlistedDoesNotMintDetf() public {
        _bootstrapDetf(openDetf, alice, 1_000e18);
        uint256 supplyBefore_ = IERC20(openDetf).totalSupply();

        // LP -> vault shares passthrough (both allowlisted on outer via se share + se vaultTokens).
        uint256 amountIn_ = 30e18;
        dai.mint(bob, amountIn_);
        usdc.mint(bob, amountIn_);
        vm.startPrank(bob);
        dai.approve(address(aerodromeRouter), amountIn_);
        usdc.approve(address(aerodromeRouter), amountIn_);
        (,, uint256 liq_) = aerodromeRouter.addLiquidity(
            address(dai), address(usdc), false, amountIn_, amountIn_, 1, 1, bob, block.timestamp + 1 hours
        );
        IERC20 lp_ = IERC20(address(aeroDaiUsdcPool));
        lp_.approve(openDetf, liq_);
        uint256 out_ =
            openEx.exchangeIn(lp_, liq_, seShare, 0, bob, false, block.timestamp + 1 hours);
        vm.stopPrank();

        assertTrue(out_ > 0, "passthrough out");
        assertEq(IERC20(openDetf).totalSupply(), supplyBefore_, "detf supply unchanged on passthrough");
        _assertNoFreeInventory(openDetf);
    }

    function test_req_bondBonusCurveMinAndClamp() public {
        BondTerms memory terms_ = IVaultFeeOracleQuery(address(indexedexManager)).bondTermsOfVault(openDetf);
        // Fresh open detf per lock scenario to avoid MaxInRatio on successive unbalanced joins.
        address d1 = _deployOpenThresholdDetf("Bonus Min", "bMin");
        uint256 se1_ = _fundSeShares(alice, 500e18);
        vm.startPrank(alice);
        seShare.approve(d1, se1_);
        (uint256 idMin_,) = ISingleStandardExchangeDETFBonding(d1).bond(
            seShare, se1_, terms_.minLockDuration, alice, false, block.timestamp + 1 hours
        );
        vm.stopPrank();

        IDETFNFTVault nft1_ = IDETFNFTVault(ISingleStandardExchangeDETFInfo(d1).bondNftVault());
        assertEq(
            nft1_.positionOf(idMin_).bonusMultiplier,
            DETFBondNFTMathLib._calcBonusMultiplier(terms_, terms_.minLockDuration),
            "min lock bonus"
        );

        address d2 = _deployOpenThresholdDetf("Bonus Clamp", "bMax");
        uint256 se2_ = _fundSeShares(bob, 500e18);
        vm.startPrank(bob);
        seShare.approve(d2, se2_);
        (uint256 idMax_,) = ISingleStandardExchangeDETFBonding(d2).bond(
            seShare, se2_, terms_.maxLockDuration + 365 days, bob, false, block.timestamp + 1 hours
        );
        vm.stopPrank();

        IDETFNFTVault nft2_ = IDETFNFTVault(ISingleStandardExchangeDETFInfo(d2).bondNftVault());
        assertEq(
            nft2_.positionOf(idMax_).bonusMultiplier,
            DETFBondNFTMathLib._calcBonusMultiplier(terms_, terms_.maxLockDuration),
            "clamped max lock bonus"
        );
        assertLe(
            nft2_.positionOf(idMax_).unlockTime,
            block.timestamp + terms_.maxLockDuration + 2,
            "unlock clamped to max"
        );
    }

    function test_req_burnCleansResidual() public {
        _bootstrapDetf(openDetf, alice, 2_000e18);
        uint256 seShares_ = _smallMintShares(bob);
        vm.startPrank(bob);
        seShare.approve(openDetf, seShares_);
        uint256 minted_ =
            openEx.exchangeIn(seShare, seShares_, IERC20(openDetf), 0, bob, false, block.timestamp + 1 hours);
        IERC20(openDetf).approve(openDetf, minted_ / 2);
        openEx.exchangeIn(
            IERC20(openDetf), minted_ / 2, seShare, 0, bob, false, block.timestamp + 1 hours
        );
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
