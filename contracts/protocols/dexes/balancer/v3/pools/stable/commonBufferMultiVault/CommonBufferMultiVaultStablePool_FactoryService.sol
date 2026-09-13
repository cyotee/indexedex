// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {ArtifactCreationCode} from "contracts/utils/foundry/ArtifactCreationCode.sol";

import {Vm} from "forge-std/Vm.sol";
import {VM_ADDRESS} from "@crane/contracts/constants/FoundryConstants.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";

import {ICommonBufferMultiVaultStablePoolPkg} from "contracts/protocols/dexes/balancer/v3/pools/stable/commonBufferMultiVault/ICommonBufferMultiVaultStablePoolPkg.sol";

library CommonBufferMultiVaultStablePool_FactoryService {
    using BetterEfficientHashLib for bytes;

    /// forge-lint: disable-next-line(screaming-snake-case-const)
    Vm constant vm = Vm(VM_ADDRESS);

    function deployCommonBufferMultiVaultStablePoolFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = create3Factory.deployFacet(
            ArtifactCreationCode.creationCode("CommonBufferMultiVaultStablePoolFacet.sol:CommonBufferMultiVaultStablePoolFacet"),
            abi.encode("CommonBufferMultiVaultStablePoolFacet")._hash()
        );
        vm.label(address(instance), "CommonBufferMultiVaultStablePoolFacet");
    }

    function deployCommonBufferMultiVaultStableLiquidityFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = create3Factory.deployFacet(
            ArtifactCreationCode.creationCode("CommonBufferMultiVaultStablePoolLiquidityFacet.sol:CommonBufferMultiVaultStablePoolLiquidityFacet"),
            abi.encode("CommonBufferMultiVaultStablePoolLiquidityFacet")._hash()
        );
        vm.label(address(instance), "CommonBufferMultiVaultStablePoolLiquidityFacet");
    }

    function deployCommonBufferMultiVaultStableHookFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = create3Factory.deployFacet(
            ArtifactCreationCode.creationCode("CommonBufferMultiVaultStablePoolHookFacet.sol:CommonBufferMultiVaultStablePoolHookFacet"),
            abi.encode("CommonBufferMultiVaultStablePoolHookFacet")._hash()
        );
        vm.label(address(instance), "CommonBufferMultiVaultStablePoolHookFacet");
    }

    function deployCommonBufferMultiVaultStablePoolPkg(
        IVaultRegistryDeployment vaultRegistry,
        ICommonBufferMultiVaultStablePoolPkg.PkgInit memory pkgInit
    ) internal returns (ICommonBufferMultiVaultStablePoolPkg instance) {
        instance = ICommonBufferMultiVaultStablePoolPkg(
            address(
                vaultRegistry.deployPkg(
                    ArtifactCreationCode.creationCode("CommonBufferMultiVaultStablePoolStandardVaultPkg.sol:CommonBufferMultiVaultStablePoolStandardVaultPkg"),
                    abi.encode(pkgInit),
                    abi.encode("CommonBufferMultiVaultStablePoolStandardVaultPkg")._hash()
                )
            )
        );
        vm.label(address(instance), "CommonBufferMultiVaultStablePoolStandardVaultPkg");
    }
}
