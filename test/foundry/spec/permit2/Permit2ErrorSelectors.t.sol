// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "forge-std/Test.sol";
import "contracts/test/helpers/Permit2ErrorSelectors.sol";

contract Permit2ErrorSelectorsTest is Test {
    function test_selectors_match_keccak() public pure {
        // Verify the helpers equal the canonical keccak signatures
        assertEq(Permit2ErrorSelectors.Permit2_NotApproved, bytes4(keccak256("NotApproved(address)")));
        assertEq(Permit2ErrorSelectors.Permit2_TransferFailed, bytes4(keccak256("TransferFailed()")));
        assertEq(Permit2ErrorSelectors.Permit2_Permit2Failed, bytes4(keccak256("Permit2Failed()")));
        assertEq(Permit2ErrorSelectors.Permit2_Permit2ApproveFailed, bytes4(keccak256("Permit2ApproveFailed()")));
        assertEq(Permit2ErrorSelectors.Permit2_Permit2AmountOverflow, bytes4(keccak256("Permit2AmountOverflow()")));
    }
}
