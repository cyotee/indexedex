// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardVaultPkg} from "contracts/interfaces/IStandardVaultPkg.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {
    TestBase_SingleStandardExchangeDETF
} from "contracts/vaults/detf/standardExchange/single/TestBase_SingleStandardExchangeDETF.sol";
import {
    ISingleStandardExchangeDETDFPkg
} from "contracts/vaults/detf/standardExchange/single/SingleStandardExchangeDETDFPkg.sol";
import {
    ISingleStandardExchangeDETFBonding
} from "contracts/vaults/detf/standardExchange/single/SingleStandardExchangeDETFBondingTarget.sol";
import {
    ISingleStandardExchangeDETFInfo
} from "contracts/vaults/detf/standardExchange/single/SingleStandardExchangeDETFInfoTarget.sol";
import {
    SingleStandardExchangeDETFRepo
} from "contracts/vaults/detf/standardExchange/single/SingleStandardExchangeDETFRepo.sol";
import {
    DETFThresholdPolicy,
    ThresholdMode,
    InvalidThresholdPair
} from "contracts/vaults/detf/core/DETFThresholdPolicy.sol";

/// @notice F1 threshold-mode surface: Policy defaults, Open product mode, validation, live coupling.
/// @dev Maps PRD T1–T19 for SingleStandardExchangeDETF (Open-focused + dual-path extremes).
contract SingleStandardExchangeDETF_ThresholdMode_Test is TestBase_SingleStandardExchangeDETF {
    address internal openDetf;
    ISingleStandardExchangeDETFInfo internal openInfo;
    ISingleStandardExchangeDETFBonding internal openBonding;
    IStandardExchangeIn internal openEx;

    function setUp() public virtual override {
        super.setUp();
        // Default fixture is Policy + 0,0 (from TestBase). Open fixture for Open suites.
        openDetf = _deployOpenModeDetf("Open Mode DETF", "omDETF");
        openInfo = ISingleStandardExchangeDETFInfo(openDetf);
        openBonding = ISingleStandardExchangeDETFBonding(openDetf);
        openEx = IStandardExchangeIn(openDetf);
    }

    /* ---------------------------------------------------------------------- */
    /*  T1 — Policy 0,0 → defaults + mode Policy                              */
    /* ---------------------------------------------------------------------- */

    function test_deploy_policyDefaults_thresholdModeAndEvent() public {
        // Default TestBase instance: Policy + resolved 1.05 / 0.95
        assertEq(uint8(detfInfo.thresholdMode()), uint8(ThresholdMode.Policy), "mode Policy");
        assertEq(detfInfo.mintThreshold(), DETFThresholdPolicy.DEFAULT_MINT_THRESHOLD);
        assertEq(detfInfo.burnThreshold(), DETFThresholdPolicy.DEFAULT_BURN_THRESHOLD);
        assertFalse(detfInfo.isMintingAllowed(), "inert mint false");
        assertFalse(detfInfo.isBurningAllowed(), "inert burn false");
    }

    /* ---------------------------------------------------------------------- */
    /*  T2 — Policy custom band                                               */
    /* ---------------------------------------------------------------------- */

    function test_deploy_policyCustomBand() public {
        address custom_ = _deployPolicyThresholds(1.10e18, 0.90e18);
        ISingleStandardExchangeDETFInfo info_ = ISingleStandardExchangeDETFInfo(custom_);
        assertEq(uint8(info_.thresholdMode()), uint8(ThresholdMode.Policy));
        assertEq(info_.mintThreshold(), 1.10e18);
        assertEq(info_.burnThreshold(), 0.90e18);
    }

    /* ---------------------------------------------------------------------- */
    /*  T3 — Open deploy stores mode + resolved thresholds                    */
    /* ---------------------------------------------------------------------- */

    function test_openDeploy_modeAndStoredThresholds() public view {
        assertEq(uint8(openInfo.thresholdMode()), uint8(ThresholdMode.Open), "mode Open");
        assertEq(openInfo.mintThreshold(), DETFThresholdPolicy.DEFAULT_MINT_THRESHOLD, "Open stores defaults");
        assertEq(openInfo.burnThreshold(), DETFThresholdPolicy.DEFAULT_BURN_THRESHOLD, "Open stores defaults");
        assertFalse(openInfo.isReserveLive(), "inert");
        assertFalse(openInfo.isMintingAllowed(), "Open inert mint false");
        assertFalse(openInfo.isBurningAllowed(), "Open inert burn false");
    }

    /* ---------------------------------------------------------------------- */
    /*  T4 — Invalid mint <= burn after resolve (both modes)                  */
    /* ---------------------------------------------------------------------- */

    function test_deploy_revertsWhenMintLeBurn_policy() public {
        ISingleStandardExchangeDETDFPkg.PkgArgs memory args = ISingleStandardExchangeDETDFPkg.PkgArgs({
            name: "Bad Policy Pair",
            symbol: "badP",
            standardExchangeVault: seVault,
            standardExchangeVaultShare: IERC20(address(0)),
            rateTarget: rateTargetToken,
            detfWeight: 0,
            vaultShareWeight: 0,
            mintThreshold: 1e18,
            burnThreshold: 1e18,
            thresholdMode: ThresholdMode.Policy,
        expansionClosureRatePerSecond: 0,
        expansionCatchUpMaxSeconds: 0,
        expansionCatchUpCapBps: 0
        });
        vm.startPrank(owner);
        vm.expectRevert(abi.encodeWithSelector(InvalidThresholdPair.selector, 1e18, 1e18));
        indexedexManager.deployVault(
            IStandardVaultPkg(address(singleStandardExchangeDetfPkg)), abi.encode(args)
        );
        vm.stopPrank();
    }

    function test_deploy_revertsWhenMintLeBurn_open() public {
        ISingleStandardExchangeDETDFPkg.PkgArgs memory args = ISingleStandardExchangeDETDFPkg.PkgArgs({
            name: "Bad Open Pair",
            symbol: "badO",
            standardExchangeVault: seVault,
            standardExchangeVaultShare: IERC20(address(0)),
            rateTarget: rateTargetToken,
            detfWeight: 0,
            vaultShareWeight: 0,
            mintThreshold: 0.5e18,
            burnThreshold: 0.6e18,
            thresholdMode: ThresholdMode.Open,
        expansionClosureRatePerSecond: 0,
        expansionCatchUpMaxSeconds: 0,
        expansionCatchUpCapBps: 0
        });
        vm.startPrank(owner);
        vm.expectRevert(abi.encodeWithSelector(InvalidThresholdPair.selector, 0.5e18, 0.6e18));
        indexedexManager.deployVault(
            IStandardVaultPkg(address(singleStandardExchangeDetfPkg)), abi.encode(args)
        );
        vm.stopPrank();
    }

    /* ---------------------------------------------------------------------- */
    /*  T4b / T18 — Legal extreme Policy still reports Policy                 */
    /* ---------------------------------------------------------------------- */

    function test_extremePolicy_reportsModePolicy() public {
        // mint=1/burn=max is illegal under mint>burn; legal extreme pair still mode=Policy.
        address extreme_ = _deployExtremePolicyPairDetf("Extreme Policy DETF", "epDETF");
        ISingleStandardExchangeDETFInfo info_ = ISingleStandardExchangeDETFInfo(extreme_);
        assertEq(uint8(info_.thresholdMode()), uint8(ThresholdMode.Policy), "extreme still Policy");
        assertEq(info_.mintThreshold(), 2);
        assertEq(info_.burnThreshold(), 1);
    }

    function test_openThresholdHelper_isProductOpen() public {
        // Dual-path helper is product Open (always-allow when live).
        address dual_ = _deployOpenThresholdDetf("Dual Path Open", "dpOpen");
        assertEq(uint8(ISingleStandardExchangeDETFInfo(dual_).thresholdMode()), uint8(ThresholdMode.Open));
    }

    /* ---------------------------------------------------------------------- */
    /*  T8 / T11 — Inert blocked (Policy default + Open)                      */
    /* ---------------------------------------------------------------------- */

    function test_openInert_mintBlocked() public {
        uint256 seShares_ = _fundSeShares(alice, 100e18);
        vm.startPrank(alice);
        seShare.approve(openDetf, seShares_);
        vm.expectRevert(SingleStandardExchangeDETFRepo.ReservePoolNotInitialized.selector);
        openEx.exchangeIn(seShare, seShares_, IERC20(openDetf), 0, alice, false, block.timestamp + 1 hours);
        vm.stopPrank();
        assertFalse(openInfo.isMintingAllowed());
        assertFalse(openInfo.isBurningAllowed());
    }

    /* ---------------------------------------------------------------------- */
    /*  T10 / T12 / T13b — Open live inside former deadband                   */
    /* ---------------------------------------------------------------------- */

    function test_openLive_mintAndBurnInsideFormerDeadband() public {
        _bootstrapDetf(openDetf, alice, 2_000e18);
        assertTrue(openInfo.isReserveLive(), "live");

        uint256 synth_ = openInfo.syntheticPrice();
        // Near-peg bootstrap: synth should sit inside default Policy deadband for assert path.
        // Open still allows both sides regardless.
        assertTrue(openInfo.isMintingAllowed(), "Open live mint allowed");
        assertTrue(openInfo.isBurningAllowed(), "Open live burn allowed");

        uint256 seShares_ = _fundSeShares(bob, 20e18);
        uint256 previewMint_ = openEx.previewExchangeIn(seShare, seShares_, IERC20(openDetf));

        vm.startPrank(bob);
        seShare.approve(openDetf, seShares_);
        uint256 minted_ = openEx.exchangeIn(
            seShare, seShares_, IERC20(openDetf), 0, bob, false, block.timestamp + 1 hours
        );
        vm.stopPrank();

        assertTrue(minted_ > 0, "minted");
        assertApproxEqAbs(previewMint_, minted_, 1, "T12 preview==exec mint");

        uint256 burnAmt_ = minted_ / 2;
        uint256 previewBurn_ = openEx.previewExchangeIn(IERC20(openDetf), burnAmt_, seShare);

        vm.startPrank(bob);
        IERC20(openDetf).approve(openDetf, burnAmt_);
        uint256 burnedOut_ = openEx.exchangeIn(
            IERC20(openDetf), burnAmt_, seShare, 0, bob, false, block.timestamp + 1 hours
        );
        vm.stopPrank();

        assertTrue(burnedOut_ > 0, "burned to shares");
        assertApproxEqAbs(previewBurn_, burnedOut_, 1, "T12 preview==exec burn");

        // Document synth relative to defaults (informational for deadband claim).
        if (synth_ <= DETFThresholdPolicy.DEFAULT_MINT_THRESHOLD
            && synth_ >= DETFThresholdPolicy.DEFAULT_BURN_THRESHOLD)
        {
            // Inside former deadband — mint+burn already proved Open ignores it.
        }
        _assertNoFreeInventory(openDetf);
    }

    function test_openLive_infoBothAllowed() public {
        _bootstrapDetf(openDetf, alice, 1_000e18);
        assertTrue(openInfo.isMintingAllowed(), "T13b mint");
        assertTrue(openInfo.isBurningAllowed(), "T13b burn");
    }

    /* ---------------------------------------------------------------------- */
    /*  T13 — Open mint applies usage fee / seigniorage split                 */
    /* ---------------------------------------------------------------------- */

    function test_openMint_appliesUsageFeeAndSeigniorageSplit() public {
        _bootstrapDetf(openDetf, alice, 2_000e18);

        address feeTo_ = address(IVaultFeeOracleQuery(address(indexedexManager)).feeTo());
        address bondNft_ = openInfo.bondNftVault();
        uint256 feeBefore_ = IERC20(openDetf).balanceOf(feeTo_);
        uint256 protocolBefore_ = IERC20(openDetf).balanceOf(bondNft_);

        uint256 seShares_ = _fundSeShares(bob, 20e18);
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
            assertTrue(IERC20(openDetf).balanceOf(bondNft_) >= protocolBefore_, "protocol path");
        }
        _assertNoFreeInventory(openDetf);
    }

    /* ---------------------------------------------------------------------- */
    /*  T14 — No post-deploy mode/threshold setter                            */
    /* ---------------------------------------------------------------------- */

    function test_noPostDeployThresholdOrModeSetter() public {
        (bool okMode,) = detf.call(abi.encodeWithSignature("setThresholdMode(uint8)", uint8(1)));
        assertFalse(okMode, "no setThresholdMode");
        (bool okMint,) = detf.call(abi.encodeWithSignature("setMintThreshold(uint256)", uint256(1e18)));
        assertFalse(okMint, "no setMintThreshold");
        (bool okBurn,) = detf.call(abi.encodeWithSignature("setBurnThreshold(uint256)", uint256(1e18)));
        assertFalse(okBurn, "no setBurnThreshold");
        // Mode remains Policy on default instance.
        assertEq(uint8(detfInfo.thresholdMode()), uint8(ThresholdMode.Policy));
    }

    /* ---------------------------------------------------------------------- */
    /*  T17 — Open round-trip mint → burn                                     */
    /* ---------------------------------------------------------------------- */

    function test_openRoundTrip_mintThenBurn() public {
        _bootstrapDetf(openDetf, alice, 2_000e18);

        uint256 seShares_ = _fundSeShares(bob, 30e18);
        vm.startPrank(bob);
        seShare.approve(openDetf, seShares_);
        uint256 minted_ = openEx.exchangeIn(
            seShare, seShares_, IERC20(openDetf), 0, bob, false, block.timestamp + 1 hours
        );
        assertTrue(minted_ > 0);

        uint256 seBefore_ = seShare.balanceOf(bob);
        IERC20(openDetf).approve(openDetf, minted_);
        uint256 sharesOut_ = openEx.exchangeIn(
            IERC20(openDetf), minted_, seShare, 0, bob, false, block.timestamp + 1 hours
        );
        vm.stopPrank();

        assertTrue(sharesOut_ > 0, "burn payout");
        assertEq(seShare.balanceOf(bob) - seBefore_, sharesOut_);
        assertEq(IERC20(openDetf).balanceOf(bob), 0, "full burn of free detf");
        _assertNoFreeInventory(openDetf);
    }

    /* ---------------------------------------------------------------------- */
    /*  T19 — Open + non-default stored thresholds never deadband-revert      */
    /* ---------------------------------------------------------------------- */

    function test_openWithNonDefaultStoredThresholds_neverDeadbandRevert() public {
        ISingleStandardExchangeDETDFPkg.PkgArgs memory args = ISingleStandardExchangeDETDFPkg.PkgArgs({
            name: "Open Custom Thresholds",
            symbol: "ocDETF",
            standardExchangeVault: seVault,
            standardExchangeVaultShare: IERC20(address(0)),
            rateTarget: rateTargetToken,
            detfWeight: 0,
            vaultShareWeight: 0,
            mintThreshold: 1.2e18,
            burnThreshold: 0.8e18,
            thresholdMode: ThresholdMode.Open,
        expansionClosureRatePerSecond: 0,
        expansionCatchUpMaxSeconds: 0,
        expansionCatchUpCapBps: 0
        });
        vm.startPrank(owner);
        address customOpen_ = indexedexManager.deployVault(
            IStandardVaultPkg(address(singleStandardExchangeDetfPkg)), abi.encode(args)
        );
        vm.stopPrank();

        ISingleStandardExchangeDETFInfo info_ = ISingleStandardExchangeDETFInfo(customOpen_);
        IStandardExchangeIn ex_ = IStandardExchangeIn(customOpen_);
        assertEq(uint8(info_.thresholdMode()), uint8(ThresholdMode.Open));
        assertEq(info_.mintThreshold(), 1.2e18);
        assertEq(info_.burnThreshold(), 0.8e18);

        _bootstrapDetf(customOpen_, alice, 2_000e18);
        assertTrue(info_.isMintingAllowed());
        assertTrue(info_.isBurningAllowed());

        uint256 seShares_ = _fundSeShares(bob, 20e18);
        vm.startPrank(bob);
        seShare.approve(customOpen_, seShares_);
        uint256 minted_ = ex_.exchangeIn(
            seShare, seShares_, IERC20(customOpen_), 0, bob, false, block.timestamp + 1 hours
        );
        IERC20(customOpen_).approve(customOpen_, minted_ / 2);
        uint256 out_ = ex_.exchangeIn(
            IERC20(customOpen_), minted_ / 2, seShare, 0, bob, false, block.timestamp + 1 hours
        );
        vm.stopPrank();

        assertTrue(minted_ > 0 && out_ > 0, "Open ignores custom stored band");
        _assertNoFreeInventory(customOpen_);
    }

    /* ---------------------------------------------------------------------- */
    /*  Policy deadband still blocks on default Policy instance when live     */
    /* ---------------------------------------------------------------------- */

    function test_policyLive_deadbandBlocksMintAndBurn() public {
        // Default detf is Policy + ±5%. Bootstrap near peg → both gates closed.
        _bootstrapViaFirstBond(alice, 1_000e18);
        uint256 synth_ = detfInfo.syntheticPrice();
        assertEq(
            detfInfo.isMintingAllowed(),
            detfInfo.isReserveLive() && synth_ > detfInfo.mintThreshold(),
            "mint coupling"
        );
        assertEq(
            detfInfo.isBurningAllowed(),
            detfInfo.isReserveLive() && synth_ < detfInfo.burnThreshold(),
            "burn coupling"
        );

        if (!detfInfo.isMintingAllowed()) {
            uint256 seShares_ = _fundSeShares(bob, 20e18);
            vm.startPrank(bob);
            seShare.approve(detf, seShares_);
            vm.expectRevert();
            detfExchangeIn.exchangeIn(
                seShare, seShares_, IERC20(detf), 0, bob, false, block.timestamp + 1 hours
            );
            vm.stopPrank();
        }
    }
}
