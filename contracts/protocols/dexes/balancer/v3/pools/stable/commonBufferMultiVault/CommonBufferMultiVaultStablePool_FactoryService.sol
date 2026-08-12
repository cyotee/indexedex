// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Vm} from "forge-std/Vm.sol";
import {VM_ADDRESS} from "@crane/contracts/constants/FoundryConstants.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {
    CommonBufferMultiVaultStablePoolFacet
} from "contracts/protocols/dexes/balancer/v3/pools/stable/commonBufferMultiVault/CommonBufferMultiVaultStablePoolFacet.sol";
import {
    CommonBufferMultiVaultStablePoolLiquidityFacet
} from "contracts/protocols/dexes/balancer/v3/pools/stable/commonBufferMultiVault/CommonBufferMultiVaultStablePoolLiquidityFacet.sol";
import {
    CommonBufferMultiVaultStablePoolHookFacet
} from "contracts/protocols/dexes/balancer/v3/pools/stable/commonBufferMultiVault/CommonBufferMultiVaultStablePoolHookFacet.sol";
import {
    CommonBufferMultiVaultStablePoolStandardVaultPkg,
    ICommonBufferMultiVaultStablePoolPkg
} from "contracts/protocols/dexes/balancer/v3/pools/stable/commonBufferMultiVault/CommonBufferMultiVaultStablePoolStandardVaultPkg.sol";

library CommonBufferMultiVaultStablePool_FactoryService {
    using BetterEfficientHashLib for bytes;

    /// forge-lint: disable-next-line(screaming-snake-case-const)
    Vm constant vm = Vm(VM_ADDRESS);

    function deployCommonBufferMultiVaultStablePoolFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = create3Factory.deployFacet(
            type(CommonBufferMultiVaultStablePoolFacet).creationCode,
            abi.encode(type(CommonBufferMultiVaultStablePoolFacet).name)._hash()
        );
        vm.label(address(instance), type(CommonBufferMultiVaultStablePoolFacet).name);
    }

    function deployCommonBufferMultiVaultStableLiquidityFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = create3Factory.deployFacet(
            type(CommonBufferMultiVaultStablePoolLiquidityFacet).creationCode,
            abi.encode(type(CommonBufferMultiVaultStablePoolLiquidityFacet).name)._hash()
        );
        vm.label(address(instance), type(CommonBufferMultiVaultStablePoolLiquidityFacet).name);
    }

    function deployCommonBufferMultiVaultStableHookFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = create3Factory.deployFacet(
            type(CommonBufferMultiVaultStablePoolHookFacet).creationCode,
            abi.encode(type(CommonBufferMultiVaultStablePoolHookFacet).name)._hash()
        );
        vm.label(address(instance), type(CommonBufferMultiVaultStablePoolHookFacet).name);
    }

    function deployCommonBufferMultiVaultStablePoolPkg(
        IVaultRegistryDeployment vaultRegistry,
        ICommonBufferMultiVaultStablePoolPkg.PkgInit memory pkgInit
    ) internal returns (ICommonBufferMultiVaultStablePoolPkg instance) {
        instance = ICommonBufferMultiVaultStablePoolPkg(
            address(
                vaultRegistry.deployPkg(
                    type(CommonBufferMultiVaultStablePoolStandardVaultPkg).creationCode,
                    abi.encode(pkgInit),
                    abi.encode(type(CommonBufferMultiVaultStablePoolStandardVaultPkg).name)._hash()
                )
            )
        );
        vm.label(address(instance), type(CommonBufferMultiVaultStablePoolStandardVaultPkg).name);
    }
}
