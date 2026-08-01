// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {DETFProtocolCompoundLib} from "contracts/vaults/detf/common/core/DETFProtocolCompoundLib.sol";

/// @notice Pure unit tests for DETFProtocolCompoundLib (Stage 00 protocol compound foundation).
/// @dev No diamond / CraneTest - exercises the production library entry points only.
contract DETFProtocolCompoundLibTest is Test {
    //--------------------------------------------------------------------------
    // Dust gate (T0.1 / T0.2)
    //--------------------------------------------------------------------------

    function test_isCompoundable_zeroIsFalse() public pure {
        // T0.1: pending of 0 is never compoundable.
        assertFalse(DETFProtocolCompoundLib.isCompoundable(0));
    }

    function test_isCompoundable_dustBoundary() public pure {
        // T0.2: at dust = not compoundable; dust+1 = compoundable.
        uint256 dust_ = DETFProtocolCompoundLib.DEFAULT_COMPOUND_DUST;
        assertEq(dust_, 1, "Stage 00 default dust is 1 wei DETF");
        assertFalse(DETFProtocolCompoundLib.isCompoundable(dust_));
        assertTrue(DETFProtocolCompoundLib.isCompoundable(dust_ + 1));
    }

    function test_isCompoundable_aboveDust() public pure {
        assertTrue(DETFProtocolCompoundLib.isCompoundable(2));
        assertTrue(DETFProtocolCompoundLib.isCompoundable(1e18));
        assertTrue(DETFProtocolCompoundLib.isCompoundable(type(uint256).max));
    }

    function test_isCompoundable_customDust() public pure {
        // Family override: same strict-greater semantics with caller-supplied dust.
        uint256 customDust_ = 1000;
        assertFalse(DETFProtocolCompoundLib.isCompoundable(0, customDust_));
        assertFalse(DETFProtocolCompoundLib.isCompoundable(customDust_, customDust_));
        assertTrue(DETFProtocolCompoundLib.isCompoundable(customDust_ + 1, customDust_));
        assertTrue(DETFProtocolCompoundLib.isCompoundable(customDust_ + 500, customDust_));
    }

    function test_defaultDust_matchesUnaryGate() public pure {
        // Unary overload must equal binary overload with DEFAULT_COMPOUND_DUST.
        uint256 dust_ = DETFProtocolCompoundLib.DEFAULT_COMPOUND_DUST;
        assertEq(
            DETFProtocolCompoundLib.isCompoundable(0),
            DETFProtocolCompoundLib.isCompoundable(0, dust_)
        );
        assertEq(
            DETFProtocolCompoundLib.isCompoundable(dust_),
            DETFProtocolCompoundLib.isCompoundable(dust_, dust_)
        );
        assertEq(
            DETFProtocolCompoundLib.isCompoundable(dust_ + 1),
            DETFProtocolCompoundLib.isCompoundable(dust_ + 1, dust_)
        );
    }
}
