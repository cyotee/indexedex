// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Vm} from "forge-std/Vm.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {IPostDeployAccountHook} from "@crane/contracts/interfaces/IPostDeployAccountHook.sol";
import {IUniswapV4Detf} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/interfaces/IUniswapV4Detf.sol";
import {TestBase_UniswapV4Detf} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf.sol";
import {WindowProbe} from "./WindowProbe.sol";

/// Family: UniswapV4DetfDFPkg (nested postDeploy: bond NFT + claim + 2x SY) and the V4 hook factory window.
contract SibDetfV4WindowTest is TestBase_UniswapV4Detf {
    function test_window_DetfV4_noUntrustedCallee() public {
        IUniswapV4Detf.PkgArgs memory args = _defaultDetfArgs();
        args.name = "Sib V4";
        args.symbol = "SIBV4";
        vm.startStateDiffRecording();
        address d = _deployHookThenDetf(args);
        Vm.AccountAccess[] memory a = vm.stopAndReturnStateDiff();
        WindowProbe.Res memory r = WindowProbe.analyze(a, "DetfV4");
        assertGe(r.windows, 2, "hook factory + detf windows");
        assertEq(r.foreignPostDeployAttempts, 0);
        assertEq(r.hijackDelegatecalls, 0);
        assertEq(r.callsIntoSubst, 0);
        assertEq(IDiamondLoupe(d).facetAddress(IPostDeployAccountHook.postDeploy.selector), address(0));
    }
}
