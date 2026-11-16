// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {RobinhoodCanonicalLib} from "./RobinhoodCanonicalLib.sol";

/// @title Phase_01_Stage_01_Permit2
/// @notice Pin canonical Permit2. Fail if no code. Never deploy Permit2.
library Phase_01_Stage_01_Permit2 {
    function execute() internal view returns (address permit2) {
        permit2 = RobinhoodCanonicalLib.permit2();
        require(permit2 != address(0) && permit2.code.length > 0, "Phase 01-01: Permit2 pin has no code");
    }
}
