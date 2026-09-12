// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {ArtifactCreationCode} from "contracts/utils/foundry/ArtifactCreationCode.sol";

import {Vm} from "forge-std/Vm.sol";
import {VM_ADDRESS} from "@crane/contracts/constants/FoundryConstants.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IIndexedexManagerProxy} from "contracts/interfaces/proxies/IIndexedexManagerProxy.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";

import {ILidoWstETHStandardExchangeDFPkg} from "contracts/protocols/staking/lido/interfaces/ILidoWstETHStandardExchangeDFPkg.sol";

library LidoWstETH_Component_FactoryService {
    using BetterEfficientHashLib for bytes;

    Vm constant vm = Vm(VM_ADDRESS);

    function deployLidoWstETHStandardExchangeInFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        bytes memory code = ArtifactCreationCode.creationCode("LidoWstETHStandardExchangeInFacet.sol:LidoWstETHStandardExchangeInFacet");
        instance = create3Factory.deployFacet(code, ArtifactCreationCode.releaseSalt(abi.encode("LidoWstETHStandardExchangeInFacet")._hash(), code, ""));
        vm.label(address(instance), "LidoWstETHStandardExchangeInFacet");
    }

    function deployLidoWstETHStandardExchangeOutFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        bytes memory code = ArtifactCreationCode.creationCode("LidoWstETHStandardExchangeOutFacet.sol:LidoWstETHStandardExchangeOutFacet");
        instance = create3Factory.deployFacet(code, ArtifactCreationCode.releaseSalt(abi.encode("LidoWstETHStandardExchangeOutFacet")._hash(), code, ""));
        vm.label(address(instance), "LidoWstETHStandardExchangeOutFacet");
    }

    function deployLidoWstETHMarkerFacet(ICreate3FactoryProxy create3Factory) internal returns (IFacet instance) {
        bytes memory code = ArtifactCreationCode.creationCode("LidoWstETHMarkerFacet.sol:LidoWstETHMarkerFacet");
        instance = create3Factory.deployFacet(code, ArtifactCreationCode.releaseSalt(abi.encode("LidoWstETHMarkerFacet")._hash(), code, ""));
        vm.label(address(instance), "LidoWstETHMarkerFacet");
    }

    function deployLidoWstETHRebalanceFacet(ICreate3FactoryProxy create3Factory) internal returns (IFacet instance) {
        bytes memory code = ArtifactCreationCode.creationCode("LidoWstETHRebalanceFacet.sol:LidoWstETHRebalanceFacet");
        instance = create3Factory.deployFacet(code, ArtifactCreationCode.releaseSalt(abi.encode("LidoWstETHRebalanceFacet")._hash(), code, ""));
        vm.label(address(instance), "LidoWstETHRebalanceFacet");
    }

    function deployLidoWstETHStandardExchangeDFPkg(
        IIndexedexManagerProxy indexedexManager,
        ILidoWstETHStandardExchangeDFPkg.PkgInit memory pkgInit
    ) internal returns (ILidoWstETHStandardExchangeDFPkg instance) {
        bytes memory code = ArtifactCreationCode.creationCode("LidoWstETHStandardExchangeDFPkg.sol:LidoWstETHStandardExchangeDFPkg");
        bytes memory args = abi.encode(pkgInit);
        instance = ILidoWstETHStandardExchangeDFPkg(IVaultRegistryDeployment(address(indexedexManager)).deployPkg(
            code, args, ArtifactCreationCode.releaseSalt(abi.encode("LidoWstETHStandardExchangeDFPkg")._hash(), code, args)
        ));
        vm.label(address(instance), "LidoWstETHStandardExchangeDFPkg");
    }
}
