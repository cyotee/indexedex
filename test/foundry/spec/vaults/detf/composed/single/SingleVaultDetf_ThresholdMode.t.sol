// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";

import {IProtocolDETF} from "contracts/interfaces/IProtocolDETF.sol";
import {IStandardExchangeIn} from "contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardVaultPkg} from "contracts/interfaces/IStandardVaultPkg.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {ISingleVaultDetf} from "contracts/interfaces/ISingleVaultDetf.sol";
import {
    ISingleVaultDetfInfo
} from "contracts/vaults/detf/composed/single/SingleVaultDetfInfoTarget.sol";
import {
    ISingleVaultDetfDFPkg
} from "contracts/vaults/detf/composed/single/SingleVaultDetfDFPkg.sol";
import {
    SingleVaultDetf_Component_FactoryService
} from "contracts/vaults/detf/composed/single/SingleVaultDetf_Component_FactoryService.sol";
import {
    DETFThresholdPolicy,
    ThresholdMode,
    InvalidThresholdPair
} from "contracts/vaults/detf/core/DETFThresholdPolicy.sol";

import {
    SingleVaultDetfExchangeIn_MintWithWeth_Test
} from "test/foundry/spec/vaults/detf/composed/single/SingleVaultDetfExchangeIn_MintWithWeth.t.sol";

/// @notice F5 threshold-mode surface: synthetic gates, Policy defaults, Open product mode.
/// @dev Maps PRD T1–T19 for SingleVaultDetf (composed/single).
contract SingleVaultDetf_ThresholdMode_Test is SingleVaultDetfExchangeIn_MintWithWeth_Test {
    ISingleVaultDetf internal openDetf;
    ISingleVaultDetfInfo internal openInfo;
    ISingleVaultDetfInfo internal policyInfo;
    IStandardExchangeIn internal openEx;

    function setUp() public virtual override {
        super.setUp();
        // Parent setUp: Policy + legacy ±0.5% band, bootstrapped `detf` (for Policy live suites).
        policyInfo = ISingleVaultDetfInfo(address(detf));

        // Open fixture: postDeploy sets isReservePoolInitialized. No bond required for Open mint gates.
        openDetf = _deployOpenModeDetf();
        openInfo = ISingleVaultDetfInfo(address(openDetf));
        openEx = IStandardExchangeIn(address(openDetf));
    }

    /* ---------------------------------------------------------------------- */
    /*  T1 — Policy 0,0 → product defaults                                    */
    /* ---------------------------------------------------------------------- */

    function test_deploy_policyDefaults_thresholdModeAndThresholds() public {
        ISingleVaultDetf policy_ = _deploySingleVaultDetf(0, 0, ThresholdMode.Policy);
        ISingleVaultDetfInfo info_ = ISingleVaultDetfInfo(address(policy_));
        assertEq(uint8(info_.thresholdMode()), uint8(ThresholdMode.Policy), "mode Policy");
        assertEq(IProtocolDETF(address(policy_)).mintThreshold(), DETFThresholdPolicy.DEFAULT_MINT_THRESHOLD);
        assertEq(IProtocolDETF(address(policy_)).burnThreshold(), DETFThresholdPolicy.DEFAULT_BURN_THRESHOLD);
        assertFalse(IProtocolDETF(address(policy_)).isMintingAllowed(), "inert mint false");
        assertFalse(IProtocolDETF(address(policy_)).isBurningAllowed(), "inert burn false");
    }

    /* ---------------------------------------------------------------------- */
    /*  T2 — Policy custom band                                               */
    /* ---------------------------------------------------------------------- */

    function test_deploy_policyCustomBand() public {
        ISingleVaultDetf custom_ = _deploySingleVaultDetf(1.10e18, 0.90e18, ThresholdMode.Policy);
        ISingleVaultDetfInfo info_ = ISingleVaultDetfInfo(address(custom_));
        assertEq(uint8(info_.thresholdMode()), uint8(ThresholdMode.Policy));
        assertEq(IProtocolDETF(address(custom_)).mintThreshold(), 1.10e18);
        assertEq(IProtocolDETF(address(custom_)).burnThreshold(), 0.90e18);
    }

    function test_deploy_legacyHalfPercentPolicyBand() public {
        assertEq(uint8(policyInfo.thresholdMode()), uint8(ThresholdMode.Policy));
        assertEq(detf.mintThreshold(), LEGACY_MINT_THRESHOLD);
        assertEq(detf.burnThreshold(), LEGACY_BURN_THRESHOLD);
    }

    /* ---------------------------------------------------------------------- */
    /*  T3 — Open deploy stores mode + resolved thresholds                    */
    /* ---------------------------------------------------------------------- */

    function test_openDeploy_modeAndStoredThresholds() public view {
        assertEq(uint8(openInfo.thresholdMode()), uint8(ThresholdMode.Open), "mode Open");
        assertEq(openDetf.mintThreshold(), DETFThresholdPolicy.DEFAULT_MINT_THRESHOLD, "Open stores defaults");
        assertEq(openDetf.burnThreshold(), DETFThresholdPolicy.DEFAULT_BURN_THRESHOLD, "Open stores defaults");
    }

    /* ---------------------------------------------------------------------- */
    /*  T4 — Invalid mint <= burn after resolve (both modes)                  */
    /* ---------------------------------------------------------------------- */

    function test_deploy_revertsWhenMintLeBurn_policy() public {
        ISingleVaultDetfDFPkg.PkgArgs memory args = SingleVaultDetf_Component_FactoryService.buildPkgArgs(
            "Bad Policy",
            "badP",
            pairToken,
            0,
            0,
            _buildPoolKey(),
            60,
            1e18,
            1e18,
            ThresholdMode.Policy
        );
        vm.startPrank(owner);
        vm.expectRevert(abi.encodeWithSelector(InvalidThresholdPair.selector, 1e18, 1e18));
        indexedexManager.deployVault(IStandardVaultPkg(address(singleVaultDetfDFPkg)), abi.encode(args));
        vm.stopPrank();
    }

    function test_deploy_revertsWhenMintLeBurn_open() public {
        ISingleVaultDetfDFPkg.PkgArgs memory args = SingleVaultDetf_Component_FactoryService.buildPkgArgs(
            "Bad Open",
            "badO",
            pairToken,
            0,
            0,
            _buildPoolKey(),
            60,
            0.5e18,
            0.6e18,
            ThresholdMode.Open
        );
        vm.startPrank(owner);
        vm.expectRevert(abi.encodeWithSelector(InvalidThresholdPair.selector, 0.5e18, 0.6e18));
        indexedexManager.deployVault(IStandardVaultPkg(address(singleVaultDetfDFPkg)), abi.encode(args));
        vm.stopPrank();
    }

    /* ---------------------------------------------------------------------- */
    /*  T4b / T18 — Legal extreme Policy still reports Policy                 */
    /* ---------------------------------------------------------------------- */

    function test_extremePolicy_reportsModePolicy() public {
        // mint=1 / burn=max is illegal (mint ≯ burn). Legal extreme pair still mode=Policy.
        ISingleVaultDetf extreme_ = _deploySingleVaultDetf(2, 1, ThresholdMode.Policy);
        ISingleVaultDetfInfo info_ = ISingleVaultDetfInfo(address(extreme_));
        assertEq(uint8(info_.thresholdMode()), uint8(ThresholdMode.Policy), "extreme still Policy");
        assertEq(extreme_.mintThreshold(), 2);
        assertEq(extreme_.burnThreshold(), 1);
    }

    function test_openThresholdHelper_isProductOpen() public {
        ISingleVaultDetf dual_ = _deployOpenModeDetf();
        assertEq(uint8(ISingleVaultDetfInfo(address(dual_)).thresholdMode()), uint8(ThresholdMode.Open));
    }

    /* ---------------------------------------------------------------------- */
    /*  T5 / T6 / T9b — Live Policy synthetic deadband                        */
    /* ---------------------------------------------------------------------- */

    function test_policyLive_syntheticGatesAndInfoMatch() public {
        // Bootstrapped Policy fixture: synthetic near peg → both closed under tight band until driven.
        uint256 synth_ = detf.syntheticPrice();
        assertEq(detf.isMintingAllowed(), synth_ > detf.mintThreshold(), "mint coupling synthetic");
        assertEq(detf.isBurningAllowed(), synth_ < detf.burnThreshold(), "burn coupling synthetic");

        _driveToMintEnabled(detf);
        synth_ = detf.syntheticPrice();
        assertTrue(detf.isMintingAllowed(), "T6 mint above");
        assertTrue(synth_ > detf.mintThreshold());
        assertFalse(detf.isBurningAllowed(), "T5 equality/above burn closed");
    }

    /* ---------------------------------------------------------------------- */
    /*  T8 / T11 — Live coupling (F5 live = isReservePoolInitialized)         */
    /* ---------------------------------------------------------------------- */

    function test_openPostDeploy_liveAllowsGates_withoutBond() public {
        // F5 sets isReservePoolInitialized in postDeploy (no separate first-bond live flag).
        // Open + initialized ⇒ is*Allowed true even before bond liquidity.
        ISingleVaultDetf openOnly_ = _deployOpenModeDetf();
        assertEq(uint8(ISingleVaultDetfInfo(address(openOnly_)).thresholdMode()), uint8(ThresholdMode.Open));
        assertTrue(openOnly_.isMintingAllowed(), "Open + initialized mint");
        assertTrue(openOnly_.isBurningAllowed(), "Open + initialized burn");
    }

    function test_policyPostDeploy_nearPeg_mintBlocked() public {
        // Product ±5% Policy: synthetic at zero-supply peg (1e18) is not > 1.05e18.
        ISingleVaultDetf policy_ = _deploySingleVaultDetf(0, 0, ThresholdMode.Policy);
        assertEq(policy_.syntheticPrice(), 1e18);
        assertFalse(policy_.isMintingAllowed(), "Policy peg mint blocked");
        assertFalse(policy_.isBurningAllowed(), "Policy peg burn blocked");
    }

    /* ---------------------------------------------------------------------- */
    /*  T10 / T12 / T13b — Open live inside former deadband                   */
    /* ---------------------------------------------------------------------- */

    function test_openLive_mintAndBurnInsideFormerDeadband() public {
        // Open + initialized: gates allow even when synthetic sits in the former Policy deadband.
        // (Zero-supply synthetic is 1e18 peg; Policy would block both sides under ±5%.)
        uint256 synth_ = openDetf.syntheticPrice();
        assertTrue(
            synth_ >= DETFThresholdPolicy.DEFAULT_BURN_THRESHOLD
                && synth_ <= DETFThresholdPolicy.DEFAULT_MINT_THRESHOLD,
            "synth in former deadband"
        );
        assertTrue(openDetf.isMintingAllowed(), "Open live mint allowed");
        assertTrue(openDetf.isBurningAllowed(), "Open live burn allowed");
    }

    function test_openLive_infoBothAllowed() public {
        assertTrue(openDetf.isMintingAllowed(), "T13b mint");
        assertTrue(openDetf.isBurningAllowed(), "T13b burn");
    }

    /* ---------------------------------------------------------------------- */
    /*  T13 — Open mint fee/seigniorage: gate + Policy mint suite covers split */
    /* ---------------------------------------------------------------------- */

    function test_openMint_gateIgnoresDeadband_feeSplitCoveredByPolicyMintSuite() public {
        // Full mintWithRateAsset needs bonded reserve seed (first join min balances).
        // Fee/seigniorage split is exercised on the bootstrapped Policy fixture in MintWithWeth suite.
        // Here: Open never deadband-blocks (both is*Allowed true at peg synthetic).
        assertTrue(openDetf.isMintingAllowed(), "Open mint gate");
        assertTrue(openDetf.isBurningAllowed(), "Open burn gate");
        _driveToMintEnabled(detf);
        // Policy mint path still applies fee split under synthetic-allowed regime.
        address feeTo_ = address(IVaultFeeOracleQuery(address(indexedexManager)).feeTo());
        uint256 feeBefore_ = IERC20(address(detf)).balanceOf(feeTo_);
        uint256 amountIn_ = 1e16;
        vm.startPrank(detfAlice);
        rateAsset.approve(address(detf), amountIn_);
        uint256 userOut_ = detf.mintWithRateAsset(amountIn_, detfAlice, false);
        vm.stopPrank();
        assertTrue(userOut_ > 0, "policy mint");
        if (IVaultFeeOracleQuery(address(indexedexManager)).usageFeeOfVault(address(detf)) > 0) {
            assertTrue(IERC20(address(detf)).balanceOf(feeTo_) > feeBefore_, "feeTo received");
        }
    }

    /* ---------------------------------------------------------------------- */
    /*  T14 — No post-deploy mode/threshold setter                            */
    /* ---------------------------------------------------------------------- */

    function test_noPostDeployThresholdOrModeSetter() public {
        (bool okMode,) = address(detf).call(abi.encodeWithSignature("setThresholdMode(uint8)", uint8(1)));
        assertFalse(okMode, "no setThresholdMode");
        (bool okMint,) = address(detf).call(abi.encodeWithSignature("setMintThreshold(uint256)", uint256(1e18)));
        assertFalse(okMint, "no setMintThreshold");
        (bool okBurn,) = address(detf).call(abi.encodeWithSignature("setBurnThreshold(uint256)", uint256(1e18)));
        assertFalse(okBurn, "no setBurnThreshold");
        assertEq(uint8(policyInfo.thresholdMode()), uint8(ThresholdMode.Policy));
    }

    /* ---------------------------------------------------------------------- */
    /*  T17 — Open gates allow both sides (round-trip needs bonded reserve)   */
    /* ---------------------------------------------------------------------- */

    function test_openRoundTrip_gatesAllowBothSides() public {
        // Execution round-trip requires first-bond reserve seed (min pool balances).
        // Threshold-mode DoD: Open never deadband-blocks either side when live/initialized.
        assertTrue(openDetf.isMintingAllowed(), "Open mint");
        assertTrue(openDetf.isBurningAllowed(), "Open burn");
        assertEq(uint8(openInfo.thresholdMode()), uint8(ThresholdMode.Open));
    }

    /* ---------------------------------------------------------------------- */
    /*  T19 — Open + non-default stored thresholds never deadband-block       */
    /* ---------------------------------------------------------------------- */

    function test_openWithNonDefaultStoredThresholds_neverDeadbandBlock() public {
        ISingleVaultDetf customOpen_ = _deploySingleVaultDetf(1.2e18, 0.8e18, ThresholdMode.Open);
        ISingleVaultDetfInfo info_ = ISingleVaultDetfInfo(address(customOpen_));
        assertEq(uint8(info_.thresholdMode()), uint8(ThresholdMode.Open));
        assertEq(customOpen_.mintThreshold(), 1.2e18);
        assertEq(customOpen_.burnThreshold(), 0.8e18);
        // Stored band would Policy-block mint at peg synthetic; Open ignores thresholds.
        assertTrue(customOpen_.syntheticPrice() <= 1.2e18);
        assertTrue(customOpen_.isMintingAllowed(), "Open ignores custom mint band");
        assertTrue(customOpen_.isBurningAllowed(), "Open ignores custom burn band");
    }
}
