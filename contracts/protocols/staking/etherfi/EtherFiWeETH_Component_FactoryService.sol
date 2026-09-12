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

import {IEtherFiWeETHStandardExchangeDFPkg} from "contracts/protocols/staking/etherfi/interfaces/IEtherFiWeETHStandardExchangeDFPkg.sol";

library EtherFiWeETH_Component_FactoryService {
    using BetterEfficientHashLib for bytes;

    Vm constant vm = Vm(VM_ADDRESS);

    function deployEtherFiWeETHStandardExchangeInFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        bytes memory code = ArtifactCreationCode.creationCode("EtherFiWeETHStandardExchangeInFacet.sol:EtherFiWeETHStandardExchangeInFacet");
        instance = create3Factory.deployFacet(code, ArtifactCreationCode.releaseSalt(abi.encode("EtherFiWeETHStandardExchangeInFacet")._hash(), code, ""));
        vm.label(address(instance), "EtherFiWeETHStandardExchangeInFacet");
    }

    function deployEtherFiWeETHStandardExchangeOutFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        bytes memory code = ArtifactCreationCode.creationCode("EtherFiWeETHStandardExchangeOutFacet.sol:EtherFiWeETHStandardExchangeOutFacet");
        instance = create3Factory.deployFacet(code, ArtifactCreationCode.releaseSalt(abi.encode("EtherFiWeETHStandardExchangeOutFacet")._hash(), code, ""));
        vm.label(address(instance), "EtherFiWeETHStandardExchangeOutFacet");
    }

    function deployEtherFiWeETHMarkerFacet(ICreate3FactoryProxy create3Factory) internal returns (IFacet instance) {
        bytes memory code = ArtifactCreationCode.creationCode("EtherFiWeETHMarkerFacet.sol:EtherFiWeETHMarkerFacet");
        instance = create3Factory.deployFacet(code, ArtifactCreationCode.releaseSalt(abi.encode("EtherFiWeETHMarkerFacet")._hash(), code, ""));
        vm.label(address(instance), "EtherFiWeETHMarkerFacet");
    }

    function deployEtherFiWeETHRebalanceFacet(ICreate3FactoryProxy create3Factory) internal returns (IFacet instance) {
        bytes memory code = ArtifactCreationCode.creationCode("EtherFiWeETHRebalanceFacet.sol:EtherFiWeETHRebalanceFacet");
        instance = create3Factory.deployFacet(code, ArtifactCreationCode.releaseSalt(abi.encode("EtherFiWeETHRebalanceFacet")._hash(), code, ""));
        vm.label(address(instance), "EtherFiWeETHRebalanceFacet");
    }

    function deployEtherFiWeETHStandardExchangeDFPkg(
        IIndexedexManagerProxy indexedexManager,
        IEtherFiWeETHStandardExchangeDFPkg.PkgInit memory pkgInit
    ) internal returns (IEtherFiWeETHStandardExchangeDFPkg instance) {
        bytes memory code = ArtifactCreationCode.creationCode("EtherFiWeETHStandardExchangeDFPkg.sol:EtherFiWeETHStandardExchangeDFPkg");
        bytes memory args = abi.encode(pkgInit);
        instance = IEtherFiWeETHStandardExchangeDFPkg(IVaultRegistryDeployment(address(indexedexManager)).deployPkg(
            code, args, ArtifactCreationCode.releaseSalt(abi.encode("EtherFiWeETHStandardExchangeDFPkg")._hash(), code, args)
        ));
        vm.label(address(instance), "EtherFiWeETHStandardExchangeDFPkg");
    }
}
