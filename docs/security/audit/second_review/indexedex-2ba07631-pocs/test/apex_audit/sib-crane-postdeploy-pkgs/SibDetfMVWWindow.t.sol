// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Vm} from "forge-std/Vm.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {IPostDeployAccountHook} from "@crane/contracts/interfaces/IPostDeployAccountHook.sol";
import {TestBase_MultiVaultWeightedDetf} from
    "contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/TestBase_MultiVaultWeightedDetf.sol";
import {WindowProbe} from "./WindowProbe.sol";

/// Family: MultiVaultWeightedDetfDFPkg (nested postDeploy: rate providers, weighted pool, bond NFT, claim, 2x SY).
contract SibDetfMVWWindowTest is TestBase_MultiVaultWeightedDetf {
    function test_window_DetfMVW_noUntrustedCallee() public {
        vm.startStateDiffRecording();
        address d = _deployDetfN(2, 0, 0, true);
        Vm.AccountAccess[] memory a = vm.stopAndReturnStateDiff();
        WindowProbe.Res memory r = WindowProbe.analyze(a, "DetfMVW");
        assertGe(r.windows, 1);
        assertGe(r.postDeployCalls, 2, "nested + factory postDeploy");
        assertEq(r.foreignPostDeployAttempts, 0, "no foreign postDeploy");
        assertEq(r.hijackDelegatecalls, 0, "no hijack");
        assertEq(r.callsIntoSubst, 0, "no CALL into substitutable slot");
        assertEq(IDiamondLoupe(d).facetAddress(IPostDeployAccountHook.postDeploy.selector), address(0));
    }
}
