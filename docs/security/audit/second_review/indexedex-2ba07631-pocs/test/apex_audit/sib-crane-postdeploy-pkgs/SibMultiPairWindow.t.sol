// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Vm} from "forge-std/Vm.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {IPostDeployAccountHook} from "@crane/contracts/interfaces/IPostDeployAccountHook.sol";
import {TestBase_MultiPairStandardExchangeBufferPool} from "test/foundry/spec/protocols/dexes/balancer/v3/pools/weighted/multiPairBuffer/bases/TestBase_MultiPairStandardExchangeBufferPool.sol";
import {WindowProbe} from "./WindowProbe.sol";

/// Family window probe: honest deployment of this Balancer pool pkg (hooks == pool proxy itself).
contract SibMultiPairWindowTest is TestBase_MultiPairStandardExchangeBufferPool {
    WindowProbe.Res internal honestRes;

    function _deployBufferPool() internal virtual override {
        vm.startStateDiffRecording();
        super._deployBufferPool();
        Vm.AccountAccess[] memory a = vm.stopAndReturnStateDiff();
        honestRes = WindowProbe.analyze(a, "MultiPair");
    }

    function test_window_MultiPair_noUntrustedCallee() public view {
        assertGe(honestRes.windows, 1, "window found");
        assertGe(honestRes.postDeployCalls, 1, "factory postDeploy seen");
        assertEq(honestRes.foreignPostDeployAttempts, 0, "no foreign postDeploy");
        assertEq(honestRes.hijackDelegatecalls, 0, "no hijack");
        assertEq(honestRes.callsIntoSubst, 0, "no CALL into substitutable slot");
        assertEq(IDiamondLoupe(bufferPool).facetAddress(IPostDeployAccountHook.postDeploy.selector), address(0));
    }
}
