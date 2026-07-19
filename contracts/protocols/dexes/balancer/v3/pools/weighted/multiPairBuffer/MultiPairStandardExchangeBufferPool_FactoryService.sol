// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Vm} from "forge-std/Vm.sol";
import {VM_ADDRESS} from "@crane/contracts/constants/FoundryConstants.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {
    MultiPairStandardExchangeBufferPoolFacet
} from "contracts/protocols/dexes/balancer/v3/pools/weighted/multiPairBuffer/MultiPairStandardExchangeBufferPoolFacet.sol";
import {
    MultiPairStandardExchangeBufferPoolLiquidityFacet
} from "contracts/protocols/dexes/balancer/v3/pools/weighted/multiPairBuffer/MultiPairStandardExchangeBufferPoolLiquidityFacet.sol";
import {
    MultiPairStandardExchangeHookFacet
} from "contracts/protocols/dexes/balancer/v3/pools/weighted/multiPairBuffer/MultiPairStandardExchangeHookFacet.sol";
import {
    MultiPairStandardExchangeBufferPoolStandardVaultPkg,
    IMultiPairStandardExchangeBufferPoolPkg
} from "contracts/protocols/dexes/balancer/v3/pools/weighted/multiPairBuffer/MultiPairStandardExchangeBufferPoolStandardVaultPkg.sol";

library MultiPairStandardExchangeBufferPool_FactoryService {
    using BetterEfficientHashLib for bytes;

    /// forge-lint: disable-next-line(screaming-snake-case-const)
    Vm constant vm = Vm(VM_ADDRESS);

    function deployMultiPairBufferPoolFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = create3Factory.deployFacet(
            type(MultiPairStandardExchangeBufferPoolFacet).creationCode,
            abi.encode(type(MultiPairStandardExchangeBufferPoolFacet).name)._hash()
        );
        vm.label(address(instance), type(MultiPairStandardExchangeBufferPoolFacet).name);
    }

    function deployMultiPairPoolLiquidityFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = create3Factory.deployFacet(
            type(MultiPairStandardExchangeBufferPoolLiquidityFacet).creationCode,
            abi.encode(type(MultiPairStandardExchangeBufferPoolLiquidityFacet).name)._hash()
        );
        vm.label(address(instance), type(MultiPairStandardExchangeBufferPoolLiquidityFacet).name);
    }

    function deployMultiPairHookFacet(ICreate3FactoryProxy create3Factory) internal returns (IFacet instance) {
        instance = create3Factory.deployFacet(
            type(MultiPairStandardExchangeHookFacet).creationCode,
            abi.encode(type(MultiPairStandardExchangeHookFacet).name)._hash()
        );
        vm.label(address(instance), type(MultiPairStandardExchangeHookFacet).name);
    }

    function deployMultiPairBufferPoolPkg(
        IVaultRegistryDeployment vaultRegistry,
        IMultiPairStandardExchangeBufferPoolPkg.PkgInit memory pkgInit
    ) internal returns (IMultiPairStandardExchangeBufferPoolPkg instance) {
        instance = IMultiPairStandardExchangeBufferPoolPkg(
            address(
                vaultRegistry.deployPkg(
                    type(MultiPairStandardExchangeBufferPoolStandardVaultPkg).creationCode,
                    abi.encode(pkgInit),
                    abi.encode(type(MultiPairStandardExchangeBufferPoolStandardVaultPkg).name)._hash()
                )
            )
        );
        vm.label(address(instance), type(MultiPairStandardExchangeBufferPoolStandardVaultPkg).name);
    }
}
