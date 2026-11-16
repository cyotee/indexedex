// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {RobinhoodCanonicalLib} from "./RobinhoodCanonicalLib.sol";

/// @title Phase_01_Stage_03_UniswapV4
/// @notice Pin live V4 cores. Fail if PoolManager missing. Never deploy V4.
library Phase_01_Stage_03_UniswapV4 {
    struct Pins {
        address poolManager;
        address positionManagerV4;
        address universalRouter;
        address quoter;
        address stateView;
    }

    function execute() internal view returns (Pins memory pins) {
        pins.poolManager = RobinhoodCanonicalLib.poolManager();
        require(
            pins.poolManager != address(0) && pins.poolManager.code.length > 0,
            "Phase 01-03: PoolManager pin has no code"
        );
        pins.positionManagerV4 = RobinhoodCanonicalLib.positionManagerV4();
        pins.universalRouter = RobinhoodCanonicalLib.universalRouter();
        address quoter = RobinhoodCanonicalLib.quoter();
        if (quoter != address(0) && quoter.code.length > 0) pins.quoter = quoter;
        address stateView = RobinhoodCanonicalLib.stateView();
        if (stateView != address(0) && stateView.code.length > 0) pins.stateView = stateView;
    }
}
