// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {FixtureEconomics} from "./FixtureEconomics.sol";
import {LaunchState} from "./LaunchState.sol";
import {InitDevService} from "@crane/contracts/InitDevService.sol";

/// @title Phase_02_Stage_01_Create3Factory
/// @notice Deploy a new CREATE3 for this tree. Does not bind a ROBINHOOD_MAIN CREATE3 pin.
/// @dev Uses InitDevService.initFactory only. Diamond package factory lives in Stage 02.
library Phase_02_Stage_01_Create3Factory {
    function execute(LaunchState storage s, address owner_) internal {
        bytes32 salt = keccak256(abi.encode(owner_, FixtureEconomics.SALT_NS, "Create3Factory"));
        s.create3Factory = InitDevService.initFactory(owner_, salt);
    }
}
