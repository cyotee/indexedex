// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {LaunchStageBase} from "./LaunchStageBase.sol";
import {Phase_06_Stage_02_RebasingClaimPkg as ClaimLib} from "./Phase_06_Stage_02_RebasingClaimPkg.sol";

/// @title Phase_06_Stage_02_RebasingClaimPkg
/// @notice Resolve the current component set through implementation-sensitive CREATE3 salts.
contract Phase_06_Stage_02_RebasingClaimPkg is LaunchStageBase {
    function run() external {
        _start("Phase 06 Stage 02: Rebasing claim pkg");
        // Address records alone cannot establish release freshness.
        _requireDiamondFactory(s);
        _requireCommonFacets(s);
        _broadcast();
        ClaimLib.execute(s);
        vm.stopBroadcast();
        _exportPkg("p0602", FILE_06_02, "rebasingClaimTokenPkg", s.rebasingClaimTokenPkg);
        _logAddress("rebasingClaimTokenPkg:", s.rebasingClaimTokenPkg);
        _logComplete("Phase 06 Stage 02");
    }
}
