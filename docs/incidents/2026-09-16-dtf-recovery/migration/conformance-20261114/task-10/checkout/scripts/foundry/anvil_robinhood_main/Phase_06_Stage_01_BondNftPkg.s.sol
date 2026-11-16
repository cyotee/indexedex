// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {LaunchStageBase} from "./LaunchStageBase.sol";
import {Phase_06_Stage_01_BondNftPkg as BondNftLib} from "./Phase_06_Stage_01_BondNftPkg.sol";

/// @title Phase_06_Stage_01_BondNftPkg
/// @notice Resolve the current component set through implementation-sensitive CREATE3 salts.
contract Phase_06_Stage_01_BondNftPkg is LaunchStageBase {
    function run() external {
        _start("Phase 06 Stage 01: Bond NFT pkg");
        // Address records alone cannot establish release freshness.
        _requireCreate3(s);
        _requireCommonFacets(s);
        _requireManager(s);
        _broadcast();
        BondNftLib.execute(s);
        vm.stopBroadcast();
        _exportPkg("p0601", FILE_06_01, "bondNftVaultPkg", s.bondNftVaultPkg);
        _logAddress("bondNftVaultPkg:", s.bondNftVaultPkg);
        _logComplete("Phase 06 Stage 01");
    }
}
