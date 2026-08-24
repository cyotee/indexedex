// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {LaunchState} from "./LaunchState.sol";
import {UniV4SeInstanceLib} from "./UniV4SeInstanceLib.sol";

/// @title Phase_07_Stage_03_UniV4SeDtfWeth
/// @notice Uni V4 SE + pool for DTF / TTWETH. Width 1. RP on.
library Phase_07_Stage_03_UniV4SeDtfWeth {
    function execute(LaunchState storage s, address owner_) internal {
        UniV4SeInstanceLib.deployTtrichWeth(s, owner_);
    }
}
