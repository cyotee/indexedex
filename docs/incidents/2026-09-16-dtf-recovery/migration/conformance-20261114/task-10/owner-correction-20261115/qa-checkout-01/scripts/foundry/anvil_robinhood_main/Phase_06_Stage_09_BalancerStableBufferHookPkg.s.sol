// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {LaunchStageBase} from "./LaunchStageBase.sol";
import {Phase_06_Stage_09_BalancerStableBufferHookPkg as BalancerHookLib} from "./Phase_06_Stage_09_BalancerStableBufferHookPkg.sol";

/// @title Phase_06_Stage_09_BalancerStableBufferHookPkg
/// @notice Resolve the current component set through implementation-sensitive CREATE3 salts.
contract Phase_06_Stage_09_BalancerStableBufferHookPkg is LaunchStageBase {
    function run() external {
        _start("Phase 06 Stage 09: Balancer Stable buffer hook pkg");
        // Address records alone cannot establish release freshness.
        _requireCreate3(s);
        _requireCommonFacets(s);
        _requireManager(s);
        _broadcast();
        address pkg = BalancerHookLib.execute(s);
        vm.stopBroadcast();
        _exportPkg("p0609", "phase06_stage09_balancer_stable_hook_pkg.json", "balancerStableHookPkg", pkg);
        _logAddress("balancerStableHookPkg:", pkg);
        _logComplete("Phase 06 Stage 09");
    }
}
