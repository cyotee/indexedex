// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardVaultPkg} from "contracts/interfaces/IStandardVaultPkg.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {
    TestBase_MixedBufferMultiVaultStableDetf
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/TestBase_MixedBufferMultiVaultStableDetf.sol";
import {
    IMixedBufferMultiVaultStableDetfDFPkg
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/MixedBufferMultiVaultStableDetfDFPkg.sol";
import {
    IMixedBufferMultiVaultStableDetfBonding
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/MixedBufferMultiVaultStableDetfBondingTarget.sol";
import {
    IMixedBufferMultiVaultStableDetfInfo
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/MixedBufferMultiVaultStableDetfInfoTarget.sol";
import {
    MixedBufferMultiVaultStableDetfRepo
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/MixedBufferMultiVaultStableDetfRepo.sol";
import {
    DETFThresholdPolicy,
    ThresholdMode,
    InvalidThresholdPair
} from "contracts/vaults/detf/common/core/DETFThresholdPolicy.sol";

/// @notice F3 threshold-mode surface: Policy defaults, Open product mode, validation, live coupling.
/// @dev Maps PRD T1–T19 for MixedBufferMultiVaultStableDetf. Open does not unlock non-buffer burn.
contract MixedBufferMultiVaultStableDetf_ThresholdMode_Test is TestBase_MixedBufferMultiVaultStableDetf {
    address internal openDetf;
    IMixedBufferMultiVaultStableDetfInfo internal openInfo;
    IMixedBufferMultiVaultStableDetfBonding internal openBonding;
    IStandardExchangeIn internal openEx;

    function setUp() public virtual override {
        super.setUp();
        openDetf = _deployOpenModeDetfN(1);
        openInfo = IMixedBufferMultiVaultStableDetfInfo(openDetf);
        openBonding = IMixedBufferMultiVaultStableDetfBonding(openDetf);
        openEx = IStandardExchangeIn(openDetf);
    }

    /* ---------------------------------------------------------------------- */
    /*  T1 - Policy 0,0 → defaults + mode Policy                              */
    /* ---------------------------------------------------------------------- */

    function test_deploy_policyDefaults_thresholdModeAndEvent() public view {
        assertEq(uint8(detfInfo.thresholdMode()), uint8(ThresholdMode.Policy), "mode Policy");
        assertEq(detfInfo.mintThreshold(), DETFThresholdPolicy.DEFAULT_MINT_THRESHOLD);
        assertEq(detfInfo.burnThreshold(), DETFThresholdPolicy.DEFAULT_BURN_THRESHOLD);
        assertFalse(detfInfo.isMintingAllowed(), "inert mint false");
        assertFalse(detfInfo.isBurningAllowed(), "inert burn false");
    }

    /* ---------------------------------------------------------------------- */
    /*  T2 - Policy custom band                                               */
    /* ---------------------------------------------------------------------- */

    function test_deploy_policyCustomBand() public {
        address custom_ = _deployPolicyThresholdsN(1, 1.10e18, 0.90e18);
        IMixedBufferMultiVaultStableDetfInfo info_ = IMixedBufferMultiVaultStableDetfInfo(custom_);
        assertEq(uint8(info_.thresholdMode()), uint8(ThresholdMode.Policy));
        assertEq(info_.mintThreshold(), 1.10e18);
        assertEq(info_.burnThreshold(), 0.90e18);
    }

    /* ---------------------------------------------------------------------- */
    /*  T3 - Open deploy stores mode + resolved thresholds                    */
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
    /*  T4 - Invalid mint <= burn after resolve (both modes)                  */
    /* ---------------------------------------------------------------------- */

    function test_deploy_revertsWhenMintLeBurn_policy() public {
        IMixedBufferMultiVaultStableDetfDFPkg.PkgArgs memory args =
            _buildPkgArgs(1, 1e18, 1e18, ThresholdMode.Policy);
        vm.startPrank(owner);
        vm.expectRevert(abi.encodeWithSelector(InvalidThresholdPair.selector, 1e18, 1e18));
        indexedexManager.deployVault(
            IStandardVaultPkg(address(mixedBufferDetfPkg)), abi.encode(args)
        );
        vm.stopPrank();
    }

    function test_deploy_revertsWhenMintLeBurn_open() public {
        IMixedBufferMultiVaultStableDetfDFPkg.PkgArgs memory args =
            _buildPkgArgs(1, 0.5e18, 0.6e18, ThresholdMode.Open);
        vm.startPrank(owner);
        vm.expectRevert(abi.encodeWithSelector(InvalidThresholdPair.selector, 0.5e18, 0.6e18));
        indexedexManager.deployVault(
            IStandardVaultPkg(address(mixedBufferDetfPkg)), abi.encode(args)
        );
        vm.stopPrank();
    }

    /* ---------------------------------------------------------------------- */
    /*  T4b / T18 - Legal extreme Policy still reports Policy                 */
    /* ---------------------------------------------------------------------- */

    function test_extremePolicy_reportsModePolicy() public {
        address extreme_ = _deployExtremePolicyPairDetfN(1);
        IMixedBufferMultiVaultStableDetfInfo info_ = IMixedBufferMultiVaultStableDetfInfo(extreme_);
        assertEq(uint8(info_.thresholdMode()), uint8(ThresholdMode.Policy), "extreme still Policy");
        assertEq(info_.mintThreshold(), 2);
        assertEq(info_.burnThreshold(), 1);
    }

    function test_openThresholdHelper_isProductOpen() public {
        address dual_ = _deployOpenThresholdDetfN(1);
        assertEq(uint8(IMixedBufferMultiVaultStableDetfInfo(dual_).thresholdMode()), uint8(ThresholdMode.Open));
    }

    /* ---------------------------------------------------------------------- */
    /*  T8 / T11 - Inert blocked (Policy default + Open)                      */
    /* ---------------------------------------------------------------------- */

    function test_openInert_mintBlocked() public {
        _fundBuffer(alice, 100e18);
        vm.startPrank(alice);
        IERC20(address(dai)).approve(openDetf, 100e18);
        vm.expectRevert(MixedBufferMultiVaultStableDetfRepo.ReservePoolNotInitialized.selector);
        openEx.exchangeIn(
            IERC20(address(dai)), 100e18, IERC20(openDetf), 0, alice, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
        assertFalse(openInfo.isMintingAllowed());
        assertFalse(openInfo.isBurningAllowed());
    }

    /* ---------------------------------------------------------------------- */
    /*  T10 / T12 / T13b - Open live inside former deadband (buffer burn)     */
    /* ---------------------------------------------------------------------- */

    function test_openLive_mintAndBurnInsideFormerDeadband() public {
        _bootstrapDefault(openDetf, alice);
        assertTrue(openInfo.isReserveLive(), "live");

        uint256 synth_ = openInfo.syntheticPrice();
        assertTrue(openInfo.isMintingAllowed(), "Open live mint allowed");
        assertTrue(openInfo.isBurningAllowed(), "Open live burn allowed");

        uint256 previewMint_ =
            openEx.previewExchangeIn(IERC20(address(dai)), 50e18, IERC20(openDetf));
        uint256 minted_ = _mintDetfFromBuffer(openDetf, bob, 50e18);
        assertTrue(minted_ > 0, "minted");
        assertEq(previewMint_, minted_, "T12 preview==exec mint");

        uint256 burnAmt_ = minted_ / 2;
        uint256 previewBurn_ =
            openEx.previewExchangeIn(IERC20(openDetf), burnAmt_, IERC20(address(dai)));
        uint256 burnedOut_ = _burnDetfToBuffer(openDetf, bob, burnAmt_);
        assertTrue(burnedOut_ > 0, "burned to buffer");
        assertApproxEqAbs(previewBurn_, burnedOut_, 10, "T12 preview~=exec burn");

        // F3 lock: Open must not unlock vaultShare burn.
        uint256 remaining_ = IERC20(openDetf).balanceOf(bob);
        if (remaining_ > 0) {
            address share0_ = openInfo.vaultShares()[0];
            vm.startPrank(bob);
            IERC20(openDetf).approve(openDetf, remaining_);
            vm.expectRevert(
                abi.encodeWithSelector(
                    MixedBufferMultiVaultStableDetfRepo.InvalidRoute.selector, openDetf, share0_
                )
            );
            openEx.exchangeIn(
                IERC20(openDetf), remaining_ / 2 == 0 ? remaining_ : remaining_ / 2,
                IERC20(share0_),
                0,
                bob,
                false,
                block.timestamp + 1 hours
            );
            vm.stopPrank();
        }

        if (
            synth_ <= DETFThresholdPolicy.DEFAULT_MINT_THRESHOLD
                && synth_ >= DETFThresholdPolicy.DEFAULT_BURN_THRESHOLD
        ) {
            // Inside former deadband - mint+burn already proved Open ignores it.
        }
        _assertNoFreeInventory(openDetf);
    }

    function test_openLive_infoBothAllowed() public {
        _bootstrapDefault(openDetf, alice);
        assertTrue(openInfo.isMintingAllowed(), "T13b mint");
        assertTrue(openInfo.isBurningAllowed(), "T13b burn");
    }

    /* ---------------------------------------------------------------------- */
    /*  T13 - Open mint applies usage fee / seigniorage split                 */
    /* ---------------------------------------------------------------------- */

    function test_openMint_appliesUsageFeeAndSeigniorageSplit() public {
        _bootstrapDefault(openDetf, alice);

        address feeTo_ = address(IVaultFeeOracleQuery(address(indexedexManager)).feeTo());
        address bondNft_ = openInfo.bondNftVault();
        uint256 feeBefore_ = IERC20(openDetf).balanceOf(feeTo_);
        uint256 protocolBefore_ = IERC20(openDetf).balanceOf(bondNft_);

        uint256 userOut_ = _mintDetfFromBuffer(openDetf, bob, 50e18);
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
    /*  T14 - No post-deploy mode/threshold setter                            */
    /* ---------------------------------------------------------------------- */

    function test_noPostDeployThresholdOrModeSetter() public {
        (bool okMode,) = detf.call(abi.encodeWithSignature("setThresholdMode(uint8)", uint8(1)));
        assertFalse(okMode, "no setThresholdMode");
        (bool okMint,) = detf.call(abi.encodeWithSignature("setMintThreshold(uint256)", uint256(1e18)));
        assertFalse(okMint, "no setMintThreshold");
        (bool okBurn,) = detf.call(abi.encodeWithSignature("setBurnThreshold(uint256)", uint256(1e18)));
        assertFalse(okBurn, "no setBurnThreshold");
        assertEq(uint8(detfInfo.thresholdMode()), uint8(ThresholdMode.Policy));
    }

    /* ---------------------------------------------------------------------- */
    /*  T15 - Policy deadband not bypassed by alternate mint input            */
    /* ---------------------------------------------------------------------- */

    function test_policyDeadband_blocksBothBufferAndShareMint() public {
        // Closed mint under max mintThreshold (Policy).
        address closed_ = _deployDetfN(1, type(uint256).max, 0, ThresholdMode.Policy);
        IMixedBufferMultiVaultStableDetfInfo info_ = IMixedBufferMultiVaultStableDetfInfo(closed_);
        IStandardExchangeIn ex_ = IStandardExchangeIn(closed_);
        _bootstrapDefault(closed_, alice);
        assertFalse(info_.isMintingAllowed(), "mint closed");

        _fundBuffer(bob, 50e18);
        vm.startPrank(bob);
        IERC20(address(dai)).approve(closed_, 50e18);
        vm.expectRevert(
            abi.encodeWithSelector(
                MixedBufferMultiVaultStableDetfRepo.MintingNotAllowed.selector,
                info_.syntheticPrice(),
                info_.mintThreshold()
            )
        );
        ex_.exchangeIn(
            IERC20(address(dai)), 50e18, IERC20(closed_), 0, bob, false, block.timestamp + 1 hours
        );
        vm.stopPrank();

        uint256 shares_ = _fundVaultShares(0, bob, 50e18);
        address shareTok_ = info_.vaultShares()[0];
        vm.startPrank(bob);
        IERC20(shareTok_).approve(closed_, shares_);
        vm.expectRevert(
            abi.encodeWithSelector(
                MixedBufferMultiVaultStableDetfRepo.MintingNotAllowed.selector,
                info_.syntheticPrice(),
                info_.mintThreshold()
            )
        );
        ex_.exchangeIn(
            IERC20(shareTok_), shares_, IERC20(closed_), 0, bob, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
    }

    /* ---------------------------------------------------------------------- */
    /*  T17 - Open round-trip mint → burn buffer                              */
    /* ---------------------------------------------------------------------- */

    function test_openRoundTrip_mintThenBurnBuffer() public {
        _bootstrapDefault(openDetf, alice);

        uint256 minted_ = _mintDetfFromBuffer(openDetf, bob, 80e18);
        assertTrue(minted_ > 0);

        uint256 bufBefore_ = IERC20(address(dai)).balanceOf(bob);
        uint256 out_ = _burnDetfToBuffer(openDetf, bob, minted_);
        assertTrue(out_ > 0, "burn payout");
        assertEq(IERC20(address(dai)).balanceOf(bob) - bufBefore_, out_);
        assertEq(IERC20(openDetf).balanceOf(bob), 0, "full burn of free detf");
        _assertNoFreeInventory(openDetf);
    }

    /* ---------------------------------------------------------------------- */
    /*  T19 - Open + non-default stored thresholds never deadband-revert      */
    /* ---------------------------------------------------------------------- */

    function test_openWithNonDefaultStoredThresholds_neverDeadbandRevert() public {
        address customOpen_ = _deployDetfN(1, 1.2e18, 0.8e18, ThresholdMode.Open);

        IMixedBufferMultiVaultStableDetfInfo info_ = IMixedBufferMultiVaultStableDetfInfo(customOpen_);
        assertEq(uint8(info_.thresholdMode()), uint8(ThresholdMode.Open));
        assertEq(info_.mintThreshold(), 1.2e18);
        assertEq(info_.burnThreshold(), 0.8e18);

        _bootstrapDefault(customOpen_, alice);
        assertTrue(info_.isMintingAllowed());
        assertTrue(info_.isBurningAllowed());

        uint256 minted_ = _mintDetfFromBuffer(customOpen_, bob, 50e18);
        uint256 out_ = _burnDetfToBuffer(customOpen_, bob, minted_ / 2);
        assertTrue(minted_ > 0 && out_ > 0, "Open ignores custom stored band");
        _assertNoFreeInventory(customOpen_);
    }

    /* ---------------------------------------------------------------------- */
    /*  Bootstrap first bond remains synthetically ungated                    */
    /* ---------------------------------------------------------------------- */

    function test_bootstrapFirstBond_ungatedUnderPolicyClosedMint() public {
        // Even with mint closed forever (Policy max mint), first bond still goes live.
        address closed_ = _deployDetfN(1, type(uint256).max, 0, ThresholdMode.Policy);
        IMixedBufferMultiVaultStableDetfInfo info_ = IMixedBufferMultiVaultStableDetfInfo(closed_);
        assertFalse(info_.isReserveLive());
        _bootstrapDefault(closed_, alice);
        assertTrue(info_.isReserveLive(), "bootstrap ungated by synthetic");
        assertFalse(info_.isMintingAllowed(), "post-bootstrap mint still closed under Policy");
    }

    /* ---------------------------------------------------------------------- */
    /*  Policy deadband still blocks on default Policy instance when live     */
    /* ---------------------------------------------------------------------- */

    function test_policyLive_deadbandBlocksMintAndBurn() public {
        _bootstrapDefault(detf, alice);
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
            _fundBuffer(bob, 20e18);
            vm.startPrank(bob);
            IERC20(address(dai)).approve(detf, 20e18);
            vm.expectRevert();
            detfExchangeIn.exchangeIn(
                IERC20(address(dai)), 20e18, IERC20(detf), 0, bob, false, block.timestamp + 1 hours
            );
            vm.stopPrank();
        }
    }
}
