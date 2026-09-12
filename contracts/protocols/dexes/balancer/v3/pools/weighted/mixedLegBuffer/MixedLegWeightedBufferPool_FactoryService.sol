// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {ArtifactCreationCode} from "contracts/utils/foundry/ArtifactCreationCode.sol";

import {Vm} from "forge-std/Vm.sol";
import {VM_ADDRESS} from "@crane/contracts/constants/FoundryConstants.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";

import {IMixedLegWeightedBufferPoolPkg} from "contracts/protocols/dexes/balancer/v3/pools/weighted/mixedLegBuffer/MixedLegWeightedBufferPoolStandardVaultPkg.sol";

library MixedLegWeightedBufferPool_FactoryService {
    using BetterEfficientHashLib for bytes;

    /// forge-lint: disable-next-line(screaming-snake-case-const)
    Vm constant vm = Vm(VM_ADDRESS);

    function deployMixedLegBufferPoolFacet(ICreate3FactoryProxy create3Factory) internal returns (IFacet instance) {
        instance = create3Factory.deployFacet(
            ArtifactCreationCode.creationCode("MixedLegWeightedBufferPoolFacet.sol:MixedLegWeightedBufferPoolFacet"),
            abi.encode("MixedLegWeightedBufferPoolFacet")._hash()
        );
        vm.label(address(instance), "MixedLegWeightedBufferPoolFacet");
    }

    function deployMixedLegLiquidityFacet(ICreate3FactoryProxy create3Factory) internal returns (IFacet instance) {
        instance = create3Factory.deployFacet(
            ArtifactCreationCode.creationCode("MixedLegWeightedBufferPoolLiquidityFacet.sol:MixedLegWeightedBufferPoolLiquidityFacet"),
            abi.encode("MixedLegWeightedBufferPoolLiquidityFacet")._hash()
        );
        vm.label(address(instance), "MixedLegWeightedBufferPoolLiquidityFacet");
    }

    function deployMixedLegHookFacet(ICreate3FactoryProxy create3Factory) internal returns (IFacet instance) {
        instance = create3Factory.deployFacet(
            ArtifactCreationCode.creationCode("MixedLegWeightedBufferPoolHookFacet.sol:MixedLegWeightedBufferPoolHookFacet"),
            abi.encode("MixedLegWeightedBufferPoolHookFacet")._hash()
        );
        vm.label(address(instance), "MixedLegWeightedBufferPoolHookFacet");
    }

    function deployMixedLegBufferPoolPkg(
        IVaultRegistryDeployment vaultRegistry,
        IMixedLegWeightedBufferPoolPkg.PkgInit memory pkgInit
    ) internal returns (IMixedLegWeightedBufferPoolPkg instance) {
        instance = IMixedLegWeightedBufferPoolPkg(
            address(
                vaultRegistry.deployPkg(
                    ArtifactCreationCode.creationCode("MixedLegWeightedBufferPoolStandardVaultPkg.sol:MixedLegWeightedBufferPoolStandardVaultPkg"),
                    abi.encode(pkgInit),
                    abi.encode("MixedLegWeightedBufferPoolStandardVaultPkg")._hash()
                )
            )
        );
        vm.label(address(instance), "MixedLegWeightedBufferPoolStandardVaultPkg");
    }
}
