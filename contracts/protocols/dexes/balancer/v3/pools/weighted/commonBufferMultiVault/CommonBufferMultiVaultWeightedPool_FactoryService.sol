// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Vm} from "forge-std/Vm.sol";
import {VM_ADDRESS} from "@crane/contracts/constants/FoundryConstants.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {
    CommonBufferMultiVaultWeightedPoolFacet
} from "contracts/protocols/dexes/balancer/v3/pools/weighted/commonBufferMultiVault/CommonBufferMultiVaultWeightedPoolFacet.sol";
import {
    CommonBufferMultiVaultWeightedPoolLiquidityFacet
} from "contracts/protocols/dexes/balancer/v3/pools/weighted/commonBufferMultiVault/CommonBufferMultiVaultWeightedPoolLiquidityFacet.sol";
import {
    CommonBufferMultiVaultWeightedPoolHookFacet
} from "contracts/protocols/dexes/balancer/v3/pools/weighted/commonBufferMultiVault/CommonBufferMultiVaultWeightedPoolHookFacet.sol";
import {
    CommonBufferMultiVaultWeightedPoolStandardVaultPkg,
    ICommonBufferMultiVaultWeightedPoolPkg
} from "contracts/protocols/dexes/balancer/v3/pools/weighted/commonBufferMultiVault/CommonBufferMultiVaultWeightedPoolStandardVaultPkg.sol";

library CommonBufferMultiVaultWeightedPool_FactoryService {
    using BetterEfficientHashLib for bytes;

    /// forge-lint: disable-next-line(screaming-snake-case-const)
    Vm constant vm = Vm(VM_ADDRESS);

    function deployCommonBufferMultiVaultPoolFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = create3Factory.deployFacet(
            type(CommonBufferMultiVaultWeightedPoolFacet).creationCode,
            abi.encode(type(CommonBufferMultiVaultWeightedPoolFacet).name)._hash()
        );
        vm.label(address(instance), type(CommonBufferMultiVaultWeightedPoolFacet).name);
    }

    function deployCommonBufferMultiVaultLiquidityFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = create3Factory.deployFacet(
            type(CommonBufferMultiVaultWeightedPoolLiquidityFacet).creationCode,
            abi.encode(type(CommonBufferMultiVaultWeightedPoolLiquidityFacet).name)._hash()
        );
        vm.label(address(instance), type(CommonBufferMultiVaultWeightedPoolLiquidityFacet).name);
    }

    function deployCommonBufferMultiVaultHookFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = create3Factory.deployFacet(
            type(CommonBufferMultiVaultWeightedPoolHookFacet).creationCode,
            abi.encode(type(CommonBufferMultiVaultWeightedPoolHookFacet).name)._hash()
        );
        vm.label(address(instance), type(CommonBufferMultiVaultWeightedPoolHookFacet).name);
    }

    function deployCommonBufferMultiVaultPoolPkg(
        IVaultRegistryDeployment vaultRegistry,
        ICommonBufferMultiVaultWeightedPoolPkg.PkgInit memory pkgInit
    ) internal returns (ICommonBufferMultiVaultWeightedPoolPkg instance) {
        instance = ICommonBufferMultiVaultWeightedPoolPkg(
            address(
                vaultRegistry.deployPkg(
                    type(CommonBufferMultiVaultWeightedPoolStandardVaultPkg).creationCode,
                    abi.encode(pkgInit),
                    abi.encode(type(CommonBufferMultiVaultWeightedPoolStandardVaultPkg).name)._hash()
                )
            )
        );
        vm.label(address(instance), type(CommonBufferMultiVaultWeightedPoolStandardVaultPkg).name);
    }
}
