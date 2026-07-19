// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {InvariantAssertLib} from "contracts/test/invariant/InvariantAssertLib.sol";

/// @notice Wave 0 compile smoke for InvariantAssertLib (no production deploy).
contract InvariantHarness_Compile_Test is Test {
    function test_compile_claimRatioGte_andProRata() public pure {
        assertTrue(InvariantAssertLib.claimRatioGte(2, 1, 1, 1));
        assertEq(InvariantAssertLib.proRataClaim(50, 100, 200), 100);
        assertEq(InvariantAssertLib.proRataClaim(0, 100, 200), 0);
        assertEq(InvariantAssertLib.proRataClaim(10, 0, 200), 0);
    }
}
