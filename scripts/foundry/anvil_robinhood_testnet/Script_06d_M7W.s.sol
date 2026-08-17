// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {console2} from "forge-std/console2.sol";
import {Script_06_LeafBase} from "./Script_06_LeafBase.sol";

/// @notice TTM7-W omitted from the 46630 demo (n=8 weighted deploy stalls on the fork).
contract Script_06d_M7W is Script_06_LeafBase {
    function run() external {
        _prepLeaves();
        _logHeader("Group 06d: TTM7-W skipped");
        console2.log("06d TTM7-W dropped from demo — no weighted leaf deploy");
        _exportLeafDetfs(s);
        _logComplete("TTM7-W skipped");
    }
}
