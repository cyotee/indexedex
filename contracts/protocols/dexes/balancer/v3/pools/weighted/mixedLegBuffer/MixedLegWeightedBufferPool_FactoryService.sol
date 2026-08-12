// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Vm} from "forge-std/Vm.sol";
import {VM_ADDRESS} from "@crane/contracts/constants/FoundryConstants.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {
    MixedLegWeightedBufferPoolFacet
} from "contracts/protocols/dexes/balancer/v3/pools/weighted/mixedLegBuffer/MixedLegWeightedBufferPoolFacet.sol";
import {
    MixedLegWeightedBufferPoolLiquidityFacet
} from "contracts/protocols/dexes/balancer/v3/pools/weighted/mixedLegBuffer/MixedLegWeightedBufferPoolLiquidityFacet.sol";
import {
    MixedLegWeightedBufferPoolHookFacet
} from "contracts/protocols/dexes/balancer/v3/pools/weighted/mixedLegBuffer/MixedLegWeightedBufferPoolHookFacet.sol";
import {
    MixedLegWeightedBufferPoolStandardVaultPkg,
    IMixedLegWeightedBufferPoolPkg
} from "contracts/protocols/dexes/balancer/v3/pools/weighted/mixedLegBuffer/MixedLegWeightedBufferPoolStandardVaultPkg.sol";

library MixedLegWeightedBufferPool_FactoryService {
    using BetterEfficientHashLib for bytes;

    /// forge-lint: disable-next-line(screaming-snake-case-const)
    Vm constant vm = Vm(VM_ADDRESS);

    function deployMixedLegBufferPoolFacet(ICreate3FactoryProxy create3Factory) internal returns (IFacet instance) {
        instance = create3Factory.deployFacet(
            type(MixedLegWeightedBufferPoolFacet).creationCode,
            abi.encode(type(MixedLegWeightedBufferPoolFacet).name)._hash()
        );
        vm.label(address(instance), type(MixedLegWeightedBufferPoolFacet).name);
    }

    function deployMixedLegLiquidityFacet(ICreate3FactoryProxy create3Factory) internal returns (IFacet instance) {
        instance = create3Factory.deployFacet(
            type(MixedLegWeightedBufferPoolLiquidityFacet).creationCode,
            abi.encode(type(MixedLegWeightedBufferPoolLiquidityFacet).name)._hash()
        );
        vm.label(address(instance), type(MixedLegWeightedBufferPoolLiquidityFacet).name);
    }

    function deployMixedLegHookFacet(ICreate3FactoryProxy create3Factory) internal returns (IFacet instance) {
        instance = create3Factory.deployFacet(
            type(MixedLegWeightedBufferPoolHookFacet).creationCode,
            abi.encode(type(MixedLegWeightedBufferPoolHookFacet).name)._hash()
        );
        vm.label(address(instance), type(MixedLegWeightedBufferPoolHookFacet).name);
    }

    function deployMixedLegBufferPoolPkg(
        IVaultRegistryDeployment vaultRegistry,
        IMixedLegWeightedBufferPoolPkg.PkgInit memory pkgInit
    ) internal returns (IMixedLegWeightedBufferPoolPkg instance) {
        instance = IMixedLegWeightedBufferPoolPkg(
            address(
                vaultRegistry.deployPkg(
                    type(MixedLegWeightedBufferPoolStandardVaultPkg).creationCode,
                    abi.encode(pkgInit),
                    abi.encode(type(MixedLegWeightedBufferPoolStandardVaultPkg).name)._hash()
                )
            )
        );
        vm.label(address(instance), type(MixedLegWeightedBufferPoolStandardVaultPkg).name);
    }
}
