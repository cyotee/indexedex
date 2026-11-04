// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Vm} from "forge-std/Vm.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {IPostDeployAccountHook} from "@crane/contracts/interfaces/IPostDeployAccountHook.sol";
import {IDiamondFactoryPackage} from "@crane/contracts/interfaces/IDiamondFactoryPackage.sol";
import {ISingleStandardExchangeDETDFPkg} from
    "contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/ISingleStandardExchangeDETDFPkg.sol";
import {TestBase_SingleStandardExchangeDETF} from
    "contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/TestBase_SingleStandardExchangeDETF.sol";
import {WindowProbe} from "./WindowProbe.sol";
import {SibBackdoorFacet, SibEvilToken} from "./SibEvil.sol";

/// Family: SingleStandardExchangeDETDFPkg. Honest window + unprivileged attacker deploy with attacker code as
/// rateTarget (the only free address slot besides the registry-checked SE vault). Attacker code targets the
/// predicted DETF diamond (whose hook facet is mounted during the whole nested postDeploy).
contract SibDetfSingleSEWindowTest is TestBase_SingleStandardExchangeDETF {
    function test_window_DetfSingleSE_honest() public {
        ISingleStandardExchangeDETDFPkg.PkgArgs memory args_ = _defaultArgs();
        args_.name = "Sib honest";
        args_.symbol = "SIBH";
        vm.startStateDiffRecording();
        address d = _deployWithArgs(args_);
        Vm.AccountAccess[] memory a = vm.stopAndReturnStateDiff();
        WindowProbe.Res memory r = WindowProbe.analyze(a, "DetfSingleSE-honest");
        assertGe(r.postDeployCalls, 2, "nested + factory postDeploy");
        assertEq(r.foreignPostDeployAttempts, 0);
        assertEq(r.hijackDelegatecalls, 0);
        assertEq(r.callsIntoSubst, 0);
        assertEq(IDiamondLoupe(d).facetAddress(IPostDeployAccountHook.postDeploy.selector), address(0));
    }

    function test_adversarial_DetfSingleSE_evilRateTarget_cannotHijack() public {
        address attacker = makeAddr("attacker");
        vm.startPrank(attacker);
        SibBackdoorFacet backdoor = new SibBackdoorFacet(attacker);
        SibEvilToken evil = new SibEvilToken(address(backdoor));
        vm.stopPrank();
        ISingleStandardExchangeDETDFPkg.PkgArgs memory args_ = _defaultArgs();
        args_.name = "Sib evil";
        args_.symbol = "SIBE";
        args_.rateTarget = IERC20(address(evil));
        address predicted = diamondPackageFactory.calcAddress(
            IDiamondFactoryPackage(address(singleStandardExchangeDetfPkg)), abi.encode(args_)
        );
        address[] memory t = new address[](1);
        t[0] = predicted;
        evil.setTargets(t);

        vm.startStateDiffRecording();
        vm.prank(attacker);
        address d;
        bool ok;
        try singleStandardExchangeDetfPkg.deployVault(args_) returns (address v) { d = v; ok = true; }
        catch (bytes memory r_) { emit log_named_bytes("adversarial deploy reverted", r_); }
        Vm.AccountAccess[] memory a = vm.stopAndReturnStateDiff();
        WindowProbe.Res memory r = WindowProbe.analyze(a, "DetfSingleSE-adversarial");
        emit log_named_uint("adversarial deploy succeeded", ok ? 1 : 0);
        emit log_named_uint("foreign postDeploy() attempts", r.foreignPostDeployAttempts);
        assertEq(r.hijackDelegatecalls, 0, "no successful hijack");
        assertEq(r.callsIntoSubst, 0, "attacker code never got a non-static CALL");
        if (ok) {
            assertEq(d, predicted);
            assertEq(IDiamondLoupe(d).facetAddress(SibBackdoorFacet.exec.selector), address(0), "NO backdoor");
        }
    }
}
