// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IRateProvider} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRateProvider.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {IStandardVaultPkg} from "contracts/interfaces/IStandardVaultPkg.sol";
import {
    TestBase_MultiVaultWeightedDetf_Adversarial
} from "test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/adversarial/TestBase_MultiVaultWeightedDetf_Adversarial.sol";
import {
    IMultiVaultWeightedDetfDFPkg
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/MultiVaultWeightedDetfDFPkg.sol";
import {
    IMultiVaultWeightedDetfInfo
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/MultiVaultWeightedDetfInfoTarget.sol";
import {ThresholdMode} from "contracts/vaults/detf/common/core/DETFThresholdPolicy.sol";

/// @notice WP-SEC-PKG-MV-001: processArgs locks vaultShares[i] to the registered SE share.
/// @dev Hostile / zero / unregistered share cannot be configured. Gold TestBase + registry deploy.
contract Adversarial_PkgArgs_Test is TestBase_MultiVaultWeightedDetf_Adversarial {
    function test_PKG_zeroVaultShare_reverts() public {
        IMultiVaultWeightedDetfDFPkg.PkgArgs memory args = _pkgArgsN1(seVault0, IERC20(address(0)));
        _expectDeployRevertInvalidVaultShare(args, 0, address(seVault0), address(0));
    }

    function test_PKG_unregisteredVault_reverts() public {
        address unregistered_ = makeAddr("unregisteredVault");
        IMultiVaultWeightedDetfDFPkg.PkgArgs memory args =
            _pkgArgsN1(IStandardExchangeProxy(unregistered_), IERC20(unregistered_));
        vm.startPrank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(IMultiVaultWeightedDetfDFPkg.UnregisteredVault.selector, unregistered_)
        );
        indexedexManager.deployVault(
            IStandardVaultPkg(address(multiVaultWeightedDetfPkg)), abi.encode(args)
        );
        vm.stopPrank();
    }

    function test_PKG_explicitHostileShare_reverts() public {
        IMultiVaultWeightedDetfDFPkg.PkgArgs memory args =
            _pkgArgsN1(seVault0, IERC20(address(hostileShare)));
        _expectDeployRevertInvalidVaultShare(args, 0, address(seVault0), address(hostileShare));
    }

    function test_PKG_mismatchedRegisteredShare_reverts() public {
        _ensureSeVaults(2);
        IMultiVaultWeightedDetfDFPkg.PkgArgs memory args = _pkgArgsN1(seVaults[0], seShares[1]);
        _expectDeployRevertInvalidVaultShare(args, 0, address(seVaults[0]), address(seShares[1]));
    }

    function test_PKG_explicitRegisteredShare_deploysInert() public {
        IMultiVaultWeightedDetfDFPkg.PkgArgs memory args = _pkgArgsN1(seVault0, seShare0);
        args.name = "PKG Registered Share";
        args.symbol = "pkgRS";
        vm.startPrank(owner);
        address instance_ = indexedexManager.deployVault(
            IStandardVaultPkg(address(multiVaultWeightedDetfPkg)), abi.encode(args)
        );
        vm.stopPrank();
        assertTrue(instance_ != address(0), "proxy");
        _assertInert(instance_);
        assertEq(IMultiVaultWeightedDetfInfo(instance_).vaultShares()[0], address(seShare0), "share");
        assertEq(IMultiVaultWeightedDetfInfo(instance_).underlyingVaults()[0], address(seVault0), "vault");
    }

    function test_C1_hostileVaultShare_deploy_reverts() public {
        IMultiVaultWeightedDetfDFPkg.PkgArgs memory args =
            _pkgArgsN1(seVault0, IERC20(address(hostileShare)));
        _expectDeployRevertInvalidVaultShare(args, 0, address(seVault0), address(hostileShare));
    }

    function _pkgArgsN1(IStandardExchangeProxy vault_, IERC20 share_)
        internal
        view
        returns (IMultiVaultWeightedDetfDFPkg.PkgArgs memory args)
    {
        args.vaults = new IStandardExchangeProxy[](1);
        args.vaultShares = new IERC20[](1);
        args.rateProviders = new IRateProvider[](1);
        args.rateAssets = new IERC20[](1);
        args.vaultWeights = new uint256[](1);
        args.vaults[0] = vault_;
        args.vaultShares[0] = share_;
        args.rateAssets[0] = rateAsset0;
        args.vaultWeights[0] = 20e16;
        args.weightDetf = 80e16;
        args.mintThreshold = 0;
        args.burnThreshold = 0;
        args.thresholdMode = ThresholdMode.Open;
        args.name = "PKG Hostile MVW";
        args.symbol = "pkgH";
    }

    function _expectDeployRevertInvalidVaultShare(
        IMultiVaultWeightedDetfDFPkg.PkgArgs memory args,
        uint256 index_,
        address vault_,
        address share_
    ) internal {
        vm.startPrank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(
                IMultiVaultWeightedDetfDFPkg.InvalidVaultShare.selector, index_, vault_, share_
            )
        );
        indexedexManager.deployVault(
            IStandardVaultPkg(address(multiVaultWeightedDetfPkg)), abi.encode(args)
        );
        vm.stopPrank();
    }
}
