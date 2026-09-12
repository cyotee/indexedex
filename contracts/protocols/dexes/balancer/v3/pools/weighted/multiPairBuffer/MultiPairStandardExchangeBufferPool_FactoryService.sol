// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {ArtifactCreationCode} from "contracts/utils/foundry/ArtifactCreationCode.sol";

import {Vm} from "forge-std/Vm.sol";
import {VM_ADDRESS} from "@crane/contracts/constants/FoundryConstants.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";

import {IMultiPairStandardExchangeBufferPoolPkg} from "contracts/protocols/dexes/balancer/v3/pools/weighted/multiPairBuffer/MultiPairStandardExchangeBufferPoolStandardVaultPkg.sol";

library MultiPairStandardExchangeBufferPool_FactoryService {
    using BetterEfficientHashLib for bytes;

    /// forge-lint: disable-next-line(screaming-snake-case-const)
    Vm constant vm = Vm(VM_ADDRESS);

    function deployMultiPairBufferPoolFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = create3Factory.deployFacet(
            ArtifactCreationCode.creationCode("MultiPairStandardExchangeBufferPoolFacet.sol:MultiPairStandardExchangeBufferPoolFacet"),
            abi.encode("MultiPairStandardExchangeBufferPoolFacet")._hash()
        );
        vm.label(address(instance), "MultiPairStandardExchangeBufferPoolFacet");
    }

    function deployMultiPairPoolLiquidityFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = create3Factory.deployFacet(
            ArtifactCreationCode.creationCode("MultiPairStandardExchangeBufferPoolLiquidityFacet.sol:MultiPairStandardExchangeBufferPoolLiquidityFacet"),
            abi.encode("MultiPairStandardExchangeBufferPoolLiquidityFacet")._hash()
        );
        vm.label(address(instance), "MultiPairStandardExchangeBufferPoolLiquidityFacet");
    }

    function deployMultiPairHookFacet(ICreate3FactoryProxy create3Factory) internal returns (IFacet instance) {
        instance = create3Factory.deployFacet(
            ArtifactCreationCode.creationCode("MultiPairStandardExchangeHookFacet.sol:MultiPairStandardExchangeHookFacet"),
            abi.encode("MultiPairStandardExchangeHookFacet")._hash()
        );
        vm.label(address(instance), "MultiPairStandardExchangeHookFacet");
    }

    function deployMultiPairBufferPoolPkg(
        IVaultRegistryDeployment vaultRegistry,
        IMultiPairStandardExchangeBufferPoolPkg.PkgInit memory pkgInit
    ) internal returns (IMultiPairStandardExchangeBufferPoolPkg instance) {
        instance = IMultiPairStandardExchangeBufferPoolPkg(
            address(
                vaultRegistry.deployPkg(
                    ArtifactCreationCode.creationCode("MultiPairStandardExchangeBufferPoolStandardVaultPkg.sol:MultiPairStandardExchangeBufferPoolStandardVaultPkg"),
                    abi.encode(pkgInit),
                    abi.encode("MultiPairStandardExchangeBufferPoolStandardVaultPkg")._hash()
                )
            )
        );
        vm.label(address(instance), "MultiPairStandardExchangeBufferPoolStandardVaultPkg");
    }
}
