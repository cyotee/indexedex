// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {ArtifactCreationCode} from "contracts/utils/foundry/ArtifactCreationCode.sol";

import {Vm} from "forge-std/Vm.sol";
import {VM_ADDRESS} from "@crane/contracts/constants/FoundryConstants.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";

import {IMixedBufferMultiVaultStablePoolPkg} from "contracts/protocols/dexes/balancer/v3/pools/stable/mixedBufferMultiVault/MixedBufferMultiVaultStablePoolStandardVaultPkg.sol";

library MixedBufferMultiVaultStablePool_FactoryService {
    using BetterEfficientHashLib for bytes;

    /// forge-lint: disable-next-line(screaming-snake-case-const)
    Vm constant vm = Vm(VM_ADDRESS);

    function deployMixedBufferMultiVaultStablePoolFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = create3Factory.deployFacet(
            ArtifactCreationCode.creationCode("MixedBufferMultiVaultStablePoolFacet.sol:MixedBufferMultiVaultStablePoolFacet"),
            abi.encode("MixedBufferMultiVaultStablePoolFacet")._hash()
        );
        vm.label(address(instance), "MixedBufferMultiVaultStablePoolFacet");
    }

    function deployMixedBufferMultiVaultStableLiquidityFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = create3Factory.deployFacet(
            ArtifactCreationCode.creationCode("MixedBufferMultiVaultStablePoolLiquidityFacet.sol:MixedBufferMultiVaultStablePoolLiquidityFacet"),
            abi.encode("MixedBufferMultiVaultStablePoolLiquidityFacet")._hash()
        );
        vm.label(address(instance), "MixedBufferMultiVaultStablePoolLiquidityFacet");
    }

    function deployMixedBufferMultiVaultStableHookFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = create3Factory.deployFacet(
            ArtifactCreationCode.creationCode("MixedBufferMultiVaultStablePoolHookFacet.sol:MixedBufferMultiVaultStablePoolHookFacet"),
            abi.encode("MixedBufferMultiVaultStablePoolHookFacet")._hash()
        );
        vm.label(address(instance), "MixedBufferMultiVaultStablePoolHookFacet");
    }

    function deployMixedBufferMultiVaultStablePoolPkg(
        IVaultRegistryDeployment vaultRegistry,
        IMixedBufferMultiVaultStablePoolPkg.PkgInit memory pkgInit
    ) internal returns (IMixedBufferMultiVaultStablePoolPkg instance) {
        instance = IMixedBufferMultiVaultStablePoolPkg(
            address(
                vaultRegistry.deployPkg(
                    ArtifactCreationCode.creationCode("MixedBufferMultiVaultStablePoolStandardVaultPkg.sol:MixedBufferMultiVaultStablePoolStandardVaultPkg"),
                    abi.encode(pkgInit),
                    abi.encode("MixedBufferMultiVaultStablePoolStandardVaultPkg")._hash()
                )
            )
        );
        vm.label(address(instance), "MixedBufferMultiVaultStablePoolStandardVaultPkg");
    }
}
