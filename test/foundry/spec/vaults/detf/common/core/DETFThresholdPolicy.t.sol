// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {
    DETFThresholdPolicy,
    ThresholdMode,
    InvalidThresholdPair,
    InvalidThresholdMode
} from "contracts/vaults/detf/common/core/DETFThresholdPolicy.sol";

/// @notice Pure unit tests for DETFThresholdPolicy (P0 threshold modes).
/// @dev No diamond / CraneTest - exercises the production library entry points only.
contract DETFThresholdPolicyTest is Test {
    //--------------------------------------------------------------------------
    // Resolve (T1 / T2)
    //--------------------------------------------------------------------------

    function test_resolveThresholds_zerosMapToDefaults() public pure {
        (uint256 mintThreshold_, uint256 burnThreshold_) =
            DETFThresholdPolicy.resolveThresholds(0, 0);
        assertEq(mintThreshold_, DETFThresholdPolicy.DEFAULT_MINT_THRESHOLD);
        assertEq(burnThreshold_, DETFThresholdPolicy.DEFAULT_BURN_THRESHOLD);
        assertEq(mintThreshold_, 1.05e18);
        assertEq(burnThreshold_, 0.95e18);
    }

    function test_resolveThresholds_customPassthrough() public pure {
        uint256 customMint_ = 1.10e18;
        uint256 customBurn_ = 0.90e18;
        (uint256 mintThreshold_, uint256 burnThreshold_) =
            DETFThresholdPolicy.resolveThresholds(customMint_, customBurn_);
        assertEq(mintThreshold_, customMint_);
        assertEq(burnThreshold_, customBurn_);
    }

    function test_resolveThresholds_partialZeros() public pure {
        (uint256 mintOnlyZero_, uint256 burnCustom_) =
            DETFThresholdPolicy.resolveThresholds(0, 0.80e18);
        assertEq(mintOnlyZero_, DETFThresholdPolicy.DEFAULT_MINT_THRESHOLD);
        assertEq(burnCustom_, 0.80e18);

        (uint256 mintCustom_, uint256 burnOnlyZero_) =
            DETFThresholdPolicy.resolveThresholds(1.20e18, 0);
        assertEq(mintCustom_, 1.20e18);
        assertEq(burnOnlyZero_, DETFThresholdPolicy.DEFAULT_BURN_THRESHOLD);
    }

    //--------------------------------------------------------------------------
    // Open always-allow (T3 / T10 / T19)
    //--------------------------------------------------------------------------

    function test_isMintingAllowed_openAlwaysTrue() public pure {
        assertTrue(
            DETFThresholdPolicy._isMintingAllowed(ThresholdMode.Open, 1.05e18, 0)
        );
        assertTrue(
            DETFThresholdPolicy._isMintingAllowed(ThresholdMode.Open, 1.05e18, 1e18)
        );
        assertTrue(
            DETFThresholdPolicy._isMintingAllowed(
                ThresholdMode.Open, 1.05e18, type(uint256).max
            )
        );
    }

    function test_isBurningAllowed_openAlwaysTrue() public pure {
        assertTrue(
            DETFThresholdPolicy._isBurningAllowed(ThresholdMode.Open, 0.95e18, 0)
        );
        assertTrue(
            DETFThresholdPolicy._isBurningAllowed(ThresholdMode.Open, 0.95e18, 1e18)
        );
        assertTrue(
            DETFThresholdPolicy._isBurningAllowed(
                ThresholdMode.Open, 0.95e18, type(uint256).max
            )
        );
    }

    function test_openIgnoresThresholdNumbers() public pure {
        // Open + extreme stored thresholds must never deadband-block mint/burn.
        assertTrue(
            DETFThresholdPolicy._isMintingAllowed(
                ThresholdMode.Open, type(uint256).max, 1e18
            )
        );
        assertTrue(
            DETFThresholdPolicy._isBurningAllowed(ThresholdMode.Open, 1, 1e18)
        );
        assertTrue(
            DETFThresholdPolicy._isMintingAllowed(ThresholdMode.Open, 1, 0)
        );
        assertTrue(
            DETFThresholdPolicy._isBurningAllowed(
                ThresholdMode.Open, type(uint256).max, type(uint256).max
            )
        );
    }

    //--------------------------------------------------------------------------
    // Resolve + require valid pair (T4)
    //--------------------------------------------------------------------------

    function test_resolveAndRequireValidThresholds_zerosOk() public pure {
        (uint256 mintThreshold_, uint256 burnThreshold_) =
            DETFThresholdPolicy.resolveAndRequireValidThresholds(0, 0);
        assertEq(mintThreshold_, 1.05e18);
        assertEq(burnThreshold_, 0.95e18);
        assertTrue(DETFThresholdPolicy.isValidThresholdPair(mintThreshold_, burnThreshold_));
    }

    function test_resolveAndRequireValidThresholds_revertsWhenMintLeBurn() public {
        // Custom mint < burn after resolve.
        vm.expectRevert(
            abi.encodeWithSelector(InvalidThresholdPair.selector, uint256(0.9e18), uint256(1.0e18))
        );
        this.callResolveAndRequire(0.9e18, 1.0e18);

        // Equal custom pair.
        vm.expectRevert(
            abi.encodeWithSelector(InvalidThresholdPair.selector, uint256(1), uint256(1))
        );
        this.callResolveAndRequire(1, 1);
    }

    function test_resolveAndRequireValidThresholds_equalityReverts() public {
        vm.expectRevert(
            abi.encodeWithSelector(InvalidThresholdPair.selector, uint256(1e18), uint256(1e18))
        );
        this.callResolveAndRequire(1e18, 1e18);
    }

    function test_resolveAndRequireValidThresholds_openStillValidatesPair() public {
        // Pair validation is mode-independent; same helper families use for Open init.
        assertFalse(DETFThresholdPolicy.isValidThresholdPair(1e18, 1e18));
        assertFalse(DETFThresholdPolicy.isValidThresholdPair(0.9e18, 1.0e18));
        assertTrue(DETFThresholdPolicy.isValidThresholdPair(1.05e18, 0.95e18));

        vm.expectRevert(
            abi.encodeWithSelector(InvalidThresholdPair.selector, uint256(1e18), uint256(1e18))
        );
        this.callResolveAndRequire(1e18, 1e18);
    }

    function test_isValidThresholdPair_strictGreater() public pure {
        assertTrue(DETFThresholdPolicy.isValidThresholdPair(2, 1));
        assertFalse(DETFThresholdPolicy.isValidThresholdPair(1, 1));
        assertFalse(DETFThresholdPolicy.isValidThresholdPair(1, 2));
    }

    //--------------------------------------------------------------------------
    // Policy deadband + strict inequalities (T5 / T6 / T7)
    //--------------------------------------------------------------------------

    function test_isMintingAllowed_policyEqualityIsDeadband() public pure {
        uint256 mintThreshold_ = 1.05e18;
        assertFalse(
            DETFThresholdPolicy._isMintingAllowed(
                ThresholdMode.Policy, mintThreshold_, mintThreshold_
            )
        );
    }

    function test_isBurningAllowed_policyEqualityIsDeadband() public pure {
        uint256 burnThreshold_ = 0.95e18;
        assertFalse(
            DETFThresholdPolicy._isBurningAllowed(
                ThresholdMode.Policy, burnThreshold_, burnThreshold_
            )
        );
    }

    function test_isMintingAllowed_policyStrictGreater() public pure {
        uint256 mintThreshold_ = 1.05e18;
        assertTrue(
            DETFThresholdPolicy._isMintingAllowed(
                ThresholdMode.Policy, mintThreshold_, mintThreshold_ + 1
            )
        );
        assertFalse(
            DETFThresholdPolicy._isMintingAllowed(
                ThresholdMode.Policy, mintThreshold_, mintThreshold_
            )
        );
        assertFalse(
            DETFThresholdPolicy._isMintingAllowed(
                ThresholdMode.Policy, mintThreshold_, mintThreshold_ - 1
            )
        );
    }

    function test_isBurningAllowed_policyStrictLess() public pure {
        uint256 burnThreshold_ = 0.95e18;
        assertTrue(
            DETFThresholdPolicy._isBurningAllowed(
                ThresholdMode.Policy, burnThreshold_, burnThreshold_ - 1
            )
        );
        assertFalse(
            DETFThresholdPolicy._isBurningAllowed(
                ThresholdMode.Policy, burnThreshold_, burnThreshold_
            )
        );
        assertFalse(
            DETFThresholdPolicy._isBurningAllowed(
                ThresholdMode.Policy, burnThreshold_, burnThreshold_ + 1
            )
        );
    }

    //--------------------------------------------------------------------------
    // 2-arg wrappers = Policy (T18 / legacy)
    //--------------------------------------------------------------------------

    function test_twoArgWrappersAssumePolicy() public pure {
        uint256 mintThreshold_ = 1.05e18;
        uint256 burnThreshold_ = 0.95e18;

        assertEq(
            DETFThresholdPolicy._isMintingAllowed(mintThreshold_, mintThreshold_ + 1),
            DETFThresholdPolicy._isMintingAllowed(
                ThresholdMode.Policy, mintThreshold_, mintThreshold_ + 1
            )
        );
        assertEq(
            DETFThresholdPolicy._isMintingAllowed(mintThreshold_, mintThreshold_),
            DETFThresholdPolicy._isMintingAllowed(
                ThresholdMode.Policy, mintThreshold_, mintThreshold_
            )
        );
        assertEq(
            DETFThresholdPolicy._isBurningAllowed(burnThreshold_, burnThreshold_ - 1),
            DETFThresholdPolicy._isBurningAllowed(
                ThresholdMode.Policy, burnThreshold_, burnThreshold_ - 1
            )
        );
        assertEq(
            DETFThresholdPolicy._isBurningAllowed(burnThreshold_, burnThreshold_),
            DETFThresholdPolicy._isBurningAllowed(
                ThresholdMode.Policy, burnThreshold_, burnThreshold_
            )
        );

        // 2-arg never Open-short-circuits: extreme threshold still Policy-gated.
        assertFalse(DETFThresholdPolicy._isMintingAllowed(type(uint256).max, 1e18));
        assertFalse(DETFThresholdPolicy._isBurningAllowed(1, 1e18));
    }

    //--------------------------------------------------------------------------
    // Mode validation + isOpenMode
    //--------------------------------------------------------------------------

    function test_requireValidThresholdMode_acceptsPolicyAndOpen() public pure {
        DETFThresholdPolicy.requireValidThresholdMode(ThresholdMode.Policy);
        DETFThresholdPolicy.requireValidThresholdMode(ThresholdMode.Open);
        assertTrue(DETFThresholdPolicy.isValidThresholdMode(ThresholdMode.Policy));
        assertTrue(DETFThresholdPolicy.isValidThresholdMode(ThresholdMode.Open));
    }

    function test_requireValidThresholdMode_revertsOnInvalid() public {
        // Raw uint8 path: lib can reject without Solidity enum conversion panic.
        assertFalse(DETFThresholdPolicy.isValidThresholdMode(uint8(2)));
        assertFalse(DETFThresholdPolicy.isValidThresholdMode(uint8(255)));
        vm.expectRevert(abi.encodeWithSelector(InvalidThresholdMode.selector, uint8(2)));
        this.callRequireValidModeRaw(2);
        vm.expectRevert(abi.encodeWithSelector(InvalidThresholdMode.selector, uint8(255)));
        this.callRequireValidModeRaw(255);
    }

    function test_enumEncoding_policyZeroOpenOne() public pure {
        assertEq(uint8(ThresholdMode.Policy), 0);
        assertEq(uint8(ThresholdMode.Open), 1);
    }

    function test_isOpenMode() public pure {
        assertFalse(DETFThresholdPolicy._isOpenMode(ThresholdMode.Policy));
        assertTrue(DETFThresholdPolicy._isOpenMode(ThresholdMode.Open));
    }

    function test_defaultConstants() public pure {
        assertEq(DETFThresholdPolicy.DEFAULT_MINT_THRESHOLD, 1.05e18);
        assertEq(DETFThresholdPolicy.DEFAULT_BURN_THRESHOLD, 0.95e18);
        assertTrue(
            DETFThresholdPolicy.DEFAULT_MINT_THRESHOLD
                > DETFThresholdPolicy.DEFAULT_BURN_THRESHOLD
        );
    }

    //--------------------------------------------------------------------------
    // External wrappers for expectRevert (internal pure cannot be expectReverted directly)
    //--------------------------------------------------------------------------

    function callResolveAndRequire(uint256 mintArg_, uint256 burnArg_)
        external
        pure
        returns (uint256, uint256)
    {
        return DETFThresholdPolicy.resolveAndRequireValidThresholds(mintArg_, burnArg_);
    }

    function callRequireValidMode(ThresholdMode mode_) external pure {
        DETFThresholdPolicy.requireValidThresholdMode(mode_);
    }

    function callRequireValidModeRaw(uint8 mode_) external pure {
        DETFThresholdPolicy.requireValidThresholdMode(mode_);
    }
}
