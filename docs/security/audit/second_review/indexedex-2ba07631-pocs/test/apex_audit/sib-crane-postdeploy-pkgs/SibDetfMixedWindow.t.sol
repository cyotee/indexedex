// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Vm} from "forge-std/Vm.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {IPostDeployAccountHook} from "@crane/contracts/interfaces/IPostDeployAccountHook.sol";
import {TestBase_MixedBufferMultiVaultStableDetf} from
    "contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/TestBase_MixedBufferMultiVaultStableDetf.sol";
import {WindowProbe} from "./WindowProbe.sol";

/// Family: MixedBufferMultiVaultStableDetfDFPkg (nested postDeploy deploys a MixedBuffer pool diamond in-window).
contract SibDetfMixedWindowTest is TestBase_MixedBufferMultiVaultStableDetf {
    function test_window_DetfMixed_noUntrustedCallee() public {
        vm.startStateDiffRecording();
        address d = _deployDetfN(2, 0, 0);
        Vm.AccountAccess[] memory a = vm.stopAndReturnStateDiff();
        WindowProbe.Res memory r = WindowProbe.analyze(a, "DetfMixed");
        assertGe(r.windows, 1);
        assertGe(r.postDeployCalls, 2, "nested + factory postDeploy");
        assertEq(r.foreignPostDeployAttempts, 0, "no foreign postDeploy");
        assertEq(r.hijackDelegatecalls, 0, "no hijack");
        assertEq(r.callsIntoSubst, 0, "no CALL into substitutable slot");
        assertEq(IDiamondLoupe(d).facetAddress(IPostDeployAccountHook.postDeploy.selector), address(0));
    }
}
