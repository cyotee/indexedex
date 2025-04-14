// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "forge-std/Test.sol";
import {SeigniorageSetterSelectors} from "../contracts/test/helpers/SeigniorageSetterSelectors.sol";

contract SeigniorageSelectorTest is Test {
    function test_setSeigniorage_selector_matches_sig() public pure {
        bytes4 expected = bytes4(keccak256("setSeigniorage(uint256)"));
        assertEq(SeigniorageSetterSelectors.SET_SEIGNIORAGE, expected);
    }
}
