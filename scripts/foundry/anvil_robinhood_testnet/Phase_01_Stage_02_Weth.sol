// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {RobinhoodCanonicalLib} from "./RobinhoodCanonicalLib.sol";

/// @title Phase_01_Stage_02_Weth
/// @notice Pin ROBINHOOD_TESTNET.WETH. Fail if no code. Never deploy WETH.
library Phase_01_Stage_02_Weth {
    function execute() internal view returns (address weth) {
        weth = RobinhoodCanonicalLib.weth();
        require(weth != address(0) && weth.code.length > 0, "Phase 01-02: WETH pin has no code");
    }
}
