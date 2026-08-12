// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Vm} from "forge-std/Vm.sol";
import {VM_ADDRESS} from "@crane/contracts/constants/FoundryConstants.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {
    MixedBufferMultiVaultStablePoolFacet
} from "contracts/protocols/dexes/balancer/v3/pools/stable/mixedBufferMultiVault/MixedBufferMultiVaultStablePoolFacet.sol";
import {
    MixedBufferMultiVaultStablePoolLiquidityFacet
} from "contracts/protocols/dexes/balancer/v3/pools/stable/mixedBufferMultiVault/MixedBufferMultiVaultStablePoolLiquidityFacet.sol";
import {
    MixedBufferMultiVaultStablePoolHookFacet
} from "contracts/protocols/dexes/balancer/v3/pools/stable/mixedBufferMultiVault/MixedBufferMultiVaultStablePoolHookFacet.sol";
import {
    MixedBufferMultiVaultStablePoolStandardVaultPkg,
    IMixedBufferMultiVaultStablePoolPkg
} from "contracts/protocols/dexes/balancer/v3/pools/stable/mixedBufferMultiVault/MixedBufferMultiVaultStablePoolStandardVaultPkg.sol";

library MixedBufferMultiVaultStablePool_FactoryService {
    using BetterEfficientHashLib for bytes;

    /// forge-lint: disable-next-line(screaming-snake-case-const)
    Vm constant vm = Vm(VM_ADDRESS);

    function deployMixedBufferMultiVaultStablePoolFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = create3Factory.deployFacet(
            type(MixedBufferMultiVaultStablePoolFacet).creationCode,
            abi.encode(type(MixedBufferMultiVaultStablePoolFacet).name)._hash()
        );
        vm.label(address(instance), type(MixedBufferMultiVaultStablePoolFacet).name);
    }

    function deployMixedBufferMultiVaultStableLiquidityFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = create3Factory.deployFacet(
            type(MixedBufferMultiVaultStablePoolLiquidityFacet).creationCode,
            abi.encode(type(MixedBufferMultiVaultStablePoolLiquidityFacet).name)._hash()
        );
        vm.label(address(instance), type(MixedBufferMultiVaultStablePoolLiquidityFacet).name);
    }

    function deployMixedBufferMultiVaultStableHookFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = create3Factory.deployFacet(
            type(MixedBufferMultiVaultStablePoolHookFacet).creationCode,
            abi.encode(type(MixedBufferMultiVaultStablePoolHookFacet).name)._hash()
        );
        vm.label(address(instance), type(MixedBufferMultiVaultStablePoolHookFacet).name);
    }

    function deployMixedBufferMultiVaultStablePoolPkg(
        IVaultRegistryDeployment vaultRegistry,
        IMixedBufferMultiVaultStablePoolPkg.PkgInit memory pkgInit
    ) internal returns (IMixedBufferMultiVaultStablePoolPkg instance) {
        instance = IMixedBufferMultiVaultStablePoolPkg(
            address(
                vaultRegistry.deployPkg(
                    type(MixedBufferMultiVaultStablePoolStandardVaultPkg).creationCode,
                    abi.encode(pkgInit),
                    abi.encode(type(MixedBufferMultiVaultStablePoolStandardVaultPkg).name)._hash()
                )
            )
        );
        vm.label(address(instance), type(MixedBufferMultiVaultStablePoolStandardVaultPkg).name);
    }
}
