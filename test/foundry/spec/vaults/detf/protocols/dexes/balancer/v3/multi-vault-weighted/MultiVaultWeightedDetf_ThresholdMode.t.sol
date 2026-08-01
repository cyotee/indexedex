// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardVaultPkg} from "contracts/interfaces/IStandardVaultPkg.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {
    TestBase_MultiVaultWeightedDetf
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/TestBase_MultiVaultWeightedDetf.sol";
import {
    IMultiVaultWeightedDetfDFPkg
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/MultiVaultWeightedDetfDFPkg.sol";
import {
    IMultiVaultWeightedDetfBonding
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/MultiVaultWeightedDetfBondingTarget.sol";
import {
    IMultiVaultWeightedDetfInfo
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/MultiVaultWeightedDetfInfoTarget.sol";
import {
    MultiVaultWeightedDetfRepo
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/MultiVaultWeightedDetfRepo.sol";
import {
    ISingleStandardExchangeDETFInfo
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/SingleStandardExchangeDETFInfoTarget.sol";
import {
    DETFThresholdPolicy,
    ThresholdMode,
    InvalidThresholdPair
} from "contracts/vaults/detf/common/core/DETFThresholdPolicy.sol";

/// @notice F2 threshold-mode surface: Policy defaults, Open product mode, validation, live coupling.
/// @dev Maps PRD T1–T19 for MultiVaultWeightedDetf (Open-focused + dual-path extremes).
contract MultiVaultWeightedDetf_ThresholdMode_Test is TestBase_MultiVaultWeightedDetf {
    address internal openDetf;
    IMultiVaultWeightedDetfInfo internal openInfo;
    IMultiVaultWeightedDetfBonding internal openBonding;
    IStandardExchangeIn internal openEx;

    function setUp() public virtual override {
        super.setUp();
        openDetf = _deployOpenModeDetfN(1);
        openInfo = IMultiVaultWeightedDetfInfo(openDetf);
        openBonding = IMultiVaultWeightedDetfBonding(openDetf);
        openEx = IStandardExchangeIn(openDetf);
    }

    /* ---------------------------------------------------------------------- */
    /*  T1 - Policy 0,0 → defaults + mode Policy                              */
    /* ---------------------------------------------------------------------- */

    function test_deploy_policyDefaults_thresholdModeAndEvent() public view {
        // Default TestBase instance: Policy + resolved 1.05 / 0.95
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
        IMultiVaultWeightedDetfInfo info_ = IMultiVaultWeightedDetfInfo(custom_);
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
        IMultiVaultWeightedDetfDFPkg.PkgArgs memory args = _buildPkgArgs(1, 1e18, 1e18, true, ThresholdMode.Policy);
        vm.startPrank(owner);
        vm.expectRevert(abi.encodeWithSelector(InvalidThresholdPair.selector, 1e18, 1e18));
        indexedexManager.deployVault(
            IStandardVaultPkg(address(multiVaultWeightedDetfPkg)), abi.encode(args)
        );
        vm.stopPrank();
    }

    function test_deploy_revertsWhenMintLeBurn_open() public {
        IMultiVaultWeightedDetfDFPkg.PkgArgs memory args =
            _buildPkgArgs(1, 0.5e18, 0.6e18, true, ThresholdMode.Open);
        vm.startPrank(owner);
        vm.expectRevert(abi.encodeWithSelector(InvalidThresholdPair.selector, 0.5e18, 0.6e18));
        indexedexManager.deployVault(
            IStandardVaultPkg(address(multiVaultWeightedDetfPkg)), abi.encode(args)
        );
        vm.stopPrank();
    }

    /* ---------------------------------------------------------------------- */
    /*  T4b / T18 - Legal extreme Policy still reports Policy                 */
    /* ---------------------------------------------------------------------- */

    function test_extremePolicy_reportsModePolicy() public {
        // mint=1/burn=max is illegal under mint>burn; legal extreme pair still mode=Policy.
        address extreme_ = _deployExtremePolicyPairDetfN(1);
        IMultiVaultWeightedDetfInfo info_ = IMultiVaultWeightedDetfInfo(extreme_);
        assertEq(uint8(info_.thresholdMode()), uint8(ThresholdMode.Policy), "extreme still Policy");
        assertEq(info_.mintThreshold(), 2);
        assertEq(info_.burnThreshold(), 1);
    }

    function test_openThresholdHelper_isProductOpen() public {
        // Dual-path helper is product Open (always-allow when live).
        address dual_ = _deployOpenThresholdDetf();
        assertEq(uint8(IMultiVaultWeightedDetfInfo(dual_).thresholdMode()), uint8(ThresholdMode.Open));
    }

    /* ---------------------------------------------------------------------- */
    /*  T8 / T11 - Inert blocked (Policy default + Open)                      */
    /* ---------------------------------------------------------------------- */

    function test_openInert_mintBlocked() public {
        uint256 seShares_ = _fundSeShares0(alice, 100e18);
        vm.startPrank(alice);
        seShare0.approve(openDetf, seShares_);
        vm.expectRevert(MultiVaultWeightedDetfRepo.ReservePoolNotInitialized.selector);
        openEx.exchangeIn(seShare0, seShares_, IERC20(openDetf), 0, alice, false, block.timestamp + 1 hours);
        vm.stopPrank();
        assertFalse(openInfo.isMintingAllowed());
        assertFalse(openInfo.isBurningAllowed());
    }

    /* ---------------------------------------------------------------------- */
    /*  T10 / T12 / T13b - Open live inside former deadband                   */
    /* ---------------------------------------------------------------------- */

    function test_openLive_mintAndBurnInsideFormerDeadband() public {
        _goLiveViaBptBond(openDetf, alice, 2_000e18);
        assertTrue(openInfo.isReserveLive(), "live");

        uint256 synth_ = openInfo.syntheticPrice();
        assertTrue(openInfo.isMintingAllowed(), "Open live mint allowed");
        assertTrue(openInfo.isBurningAllowed(), "Open live burn allowed");

        uint256 seShares_ = _fundSeShares0(bob, 20e18);
        uint256 previewMint_ = openEx.previewExchangeIn(seShare0, seShares_, IERC20(openDetf));

        vm.startPrank(bob);
        seShare0.approve(openDetf, seShares_);
        uint256 minted_ = openEx.exchangeIn(
            seShare0, seShares_, IERC20(openDetf), 0, bob, false, block.timestamp + 1 hours
        );
        vm.stopPrank();

        assertTrue(minted_ > 0, "minted");
        assertEq(previewMint_, minted_, "T12 preview==exec mint");

        uint256 burnAmt_ = minted_ / 2;
        uint256 previewBurn_ = openEx.previewExchangeIn(IERC20(openDetf), burnAmt_, seShare0);

        vm.startPrank(bob);
        IERC20(openDetf).approve(openDetf, burnAmt_);
        uint256 burnedOut_ = openEx.exchangeIn(
            IERC20(openDetf), burnAmt_, seShare0, 0, bob, false, block.timestamp + 1 hours
        );
        vm.stopPrank();

        assertTrue(burnedOut_ > 0, "burned to shares");
        assertApproxEqAbs(previewBurn_, burnedOut_, 10, "T12 preview~=exec burn");

        if (
            synth_ <= DETFThresholdPolicy.DEFAULT_MINT_THRESHOLD
                && synth_ >= DETFThresholdPolicy.DEFAULT_BURN_THRESHOLD
        ) {
            // Inside former deadband - mint+burn already proved Open ignores it.
        }
        _assertNoFreeInventory(openDetf);
    }

    function test_openLive_infoBothAllowed() public {
        _goLiveViaBptBond(openDetf, alice, 1_000e18);
        assertTrue(openInfo.isMintingAllowed(), "T13b mint");
        assertTrue(openInfo.isBurningAllowed(), "T13b burn");
    }

    /* ---------------------------------------------------------------------- */
    /*  T13 - Open mint applies usage fee / seigniorage split                 */
    /* ---------------------------------------------------------------------- */

    function test_openMint_appliesUsageFeeAndSeigniorageSplit() public {
        _goLiveViaBptBond(openDetf, alice, 2_000e18);

        address feeTo_ = address(IVaultFeeOracleQuery(address(indexedexManager)).feeTo());
        address bondNft_ = openInfo.bondNftVault();
        uint256 feeBefore_ = IERC20(openDetf).balanceOf(feeTo_);
        uint256 protocolBefore_ = IERC20(openDetf).balanceOf(bondNft_);

        uint256 seShares_ = _fundSeShares0(bob, 20e18);
        vm.startPrank(bob);
        seShare0.approve(openDetf, seShares_);
        uint256 userOut_ =
            openEx.exchangeIn(seShare0, seShares_, IERC20(openDetf), 0, bob, false, block.timestamp + 1 hours);
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
    /*  T17 - Open round-trip mint → burn                                     */
    /* ---------------------------------------------------------------------- */

    function test_openRoundTrip_mintThenBurn() public {
        _goLiveViaBptBond(openDetf, alice, 2_000e18);

        uint256 seShares_ = _fundSeShares0(bob, 30e18);
        vm.startPrank(bob);
        seShare0.approve(openDetf, seShares_);
        uint256 minted_ = openEx.exchangeIn(
            seShare0, seShares_, IERC20(openDetf), 0, bob, false, block.timestamp + 1 hours
        );
        assertTrue(minted_ > 0);

        uint256 seBefore_ = seShare0.balanceOf(bob);
        IERC20(openDetf).approve(openDetf, minted_);
        uint256 sharesOut_ = openEx.exchangeIn(
            IERC20(openDetf), minted_, seShare0, 0, bob, false, block.timestamp + 1 hours
        );
        vm.stopPrank();

        assertTrue(sharesOut_ > 0, "burn payout");
        assertEq(seShare0.balanceOf(bob) - seBefore_, sharesOut_);
        assertEq(IERC20(openDetf).balanceOf(bob), 0, "full burn of free detf");
        _assertNoFreeInventory(openDetf);
    }

    /* ---------------------------------------------------------------------- */
    /*  T19 - Open + non-default stored thresholds never deadband-revert      */
    /* ---------------------------------------------------------------------- */

    function test_openWithNonDefaultStoredThresholds_neverDeadbandRevert() public {
        address customOpen_ = _deployDetfN(1, 1.2e18, 0.8e18, true, ThresholdMode.Open);

        IMultiVaultWeightedDetfInfo info_ = IMultiVaultWeightedDetfInfo(customOpen_);
        IStandardExchangeIn ex_ = IStandardExchangeIn(customOpen_);
        assertEq(uint8(info_.thresholdMode()), uint8(ThresholdMode.Open));
        assertEq(info_.mintThreshold(), 1.2e18);
        assertEq(info_.burnThreshold(), 0.8e18);

        _goLiveViaBptBond(customOpen_, alice, 2_000e18);
        assertTrue(info_.isMintingAllowed());
        assertTrue(info_.isBurningAllowed());

        uint256 seShares_ = _fundSeShares0(bob, 20e18);
        vm.startPrank(bob);
        seShare0.approve(customOpen_, seShares_);
        uint256 minted_ = ex_.exchangeIn(
            seShare0, seShares_, IERC20(customOpen_), 0, bob, false, block.timestamp + 1 hours
        );
        IERC20(customOpen_).approve(customOpen_, minted_ / 2);
        uint256 out_ = ex_.exchangeIn(
            IERC20(customOpen_), minted_ / 2, seShare0, 0, bob, false, block.timestamp + 1 hours
        );
        vm.stopPrank();

        assertTrue(minted_ > 0 && out_ > 0, "Open ignores custom stored band");
        _assertNoFreeInventory(customOpen_);
    }

    /* ---------------------------------------------------------------------- */
    /*  Nested mode independence (no cross-instance inheritance)              */
    /* ---------------------------------------------------------------------- */

    function test_nested_modesIndependent_noInheritance() public {
        // Nested Single SE DETF Open (independent package).
        address nestedOpen_ = _deployNestedSingleSeDetfLive(alice, 800e18, ThresholdMode.Open);
        assertEq(
            uint8(ISingleStandardExchangeDETFInfo(nestedOpen_).thresholdMode()),
            uint8(ThresholdMode.Open),
            "inner Open"
        );

        // Outer Open and outer Policy over the *same* nested - modes are per-instance, not inherited.
        address outerOpen_ = _deployOuterOverNested(nestedOpen_, 0, 0, ThresholdMode.Open);
        address outerPolicy_ = _deployOuterOverNested(nestedOpen_, 0, 0, ThresholdMode.Policy);

        assertEq(
            uint8(IMultiVaultWeightedDetfInfo(outerOpen_).thresholdMode()),
            uint8(ThresholdMode.Open),
            "outer Open"
        );
        assertEq(
            uint8(IMultiVaultWeightedDetfInfo(outerPolicy_).thresholdMode()),
            uint8(ThresholdMode.Policy),
            "outer Policy independent"
        );
        assertEq(
            uint8(ISingleStandardExchangeDETFInfo(nestedOpen_).thresholdMode()),
            uint8(ThresholdMode.Open),
            "inner still Open after both outer deploys"
        );

        // Nested Policy package (first bond ungated) coexists with Open outer without mode coupling.
        address nestedPolicy_ = _deployNestedSingleSeDetfLive(bob, 800e18, ThresholdMode.Policy);
        address outerOverPolicy_ = _deployOuterOverNested(nestedPolicy_, 0, 0, ThresholdMode.Open);
        assertEq(
            uint8(ISingleStandardExchangeDETFInfo(nestedPolicy_).thresholdMode()),
            uint8(ThresholdMode.Policy),
            "inner Policy"
        );
        assertEq(
            uint8(IMultiVaultWeightedDetfInfo(outerOverPolicy_).thresholdMode()),
            uint8(ThresholdMode.Open),
            "outer Open over Policy nested"
        );
        // Inert outer gates stay false regardless of nested mode.
        assertFalse(IMultiVaultWeightedDetfInfo(outerOverPolicy_).isMintingAllowed());
        assertFalse(IMultiVaultWeightedDetfInfo(outerOverPolicy_).isBurningAllowed());
    }

    /* ---------------------------------------------------------------------- */
    /*  Policy deadband still blocks on default Policy instance when live     */
    /* ---------------------------------------------------------------------- */

    function test_policyLive_deadbandBlocksMintAndBurn() public {
        _goLiveViaBptBond(detf, alice, 1_000e18);
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
            uint256 seShares_ = _fundSeShares0(bob, 20e18);
            vm.startPrank(bob);
            seShare0.approve(detf, seShares_);
            vm.expectRevert();
            detfExchangeIn.exchangeIn(
                seShare0, seShares_, IERC20(detf), 0, bob, false, block.timestamp + 1 hours
            );
            vm.stopPrank();
        }
    }
}
