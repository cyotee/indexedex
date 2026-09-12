// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {ArtifactCreationCode} from "contracts/utils/foundry/ArtifactCreationCode.sol";

import {Vm} from "forge-std/Vm.sol";
import {VM_ADDRESS} from "@crane/contracts/constants/FoundryConstants.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";

import {ICommonBufferMultiVaultWeightedPoolPkg} from "contracts/protocols/dexes/balancer/v3/pools/weighted/commonBufferMultiVault/CommonBufferMultiVaultWeightedPoolStandardVaultPkg.sol";

library CommonBufferMultiVaultWeightedPool_FactoryService {
    using BetterEfficientHashLib for bytes;

    /// forge-lint: disable-next-line(screaming-snake-case-const)
    Vm constant vm = Vm(VM_ADDRESS);

    function deployCommonBufferMultiVaultPoolFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = create3Factory.deployFacet(
            ArtifactCreationCode.creationCode("CommonBufferMultiVaultWeightedPoolFacet.sol:CommonBufferMultiVaultWeightedPoolFacet"),
            abi.encode("CommonBufferMultiVaultWeightedPoolFacet")._hash()
        );
        vm.label(address(instance), "CommonBufferMultiVaultWeightedPoolFacet");
    }

    function deployCommonBufferMultiVaultLiquidityFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = create3Factory.deployFacet(
            ArtifactCreationCode.creationCode("CommonBufferMultiVaultWeightedPoolLiquidityFacet.sol:CommonBufferMultiVaultWeightedPoolLiquidityFacet"),
            abi.encode("CommonBufferMultiVaultWeightedPoolLiquidityFacet")._hash()
        );
        vm.label(address(instance), "CommonBufferMultiVaultWeightedPoolLiquidityFacet");
    }

    function deployCommonBufferMultiVaultHookFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = create3Factory.deployFacet(
            ArtifactCreationCode.creationCode("CommonBufferMultiVaultWeightedPoolHookFacet.sol:CommonBufferMultiVaultWeightedPoolHookFacet"),
            abi.encode("CommonBufferMultiVaultWeightedPoolHookFacet")._hash()
        );
        vm.label(address(instance), "CommonBufferMultiVaultWeightedPoolHookFacet");
    }

    function deployCommonBufferMultiVaultPoolPkg(
        IVaultRegistryDeployment vaultRegistry,
        ICommonBufferMultiVaultWeightedPoolPkg.PkgInit memory pkgInit
    ) internal returns (ICommonBufferMultiVaultWeightedPoolPkg instance) {
        instance = ICommonBufferMultiVaultWeightedPoolPkg(
            address(
                vaultRegistry.deployPkg(
                    ArtifactCreationCode.creationCode("CommonBufferMultiVaultWeightedPoolStandardVaultPkg.sol:CommonBufferMultiVaultWeightedPoolStandardVaultPkg"),
                    abi.encode(pkgInit),
                    abi.encode("CommonBufferMultiVaultWeightedPoolStandardVaultPkg")._hash()
                )
            )
        );
        vm.label(address(instance), "CommonBufferMultiVaultWeightedPoolStandardVaultPkg");
    }
}
