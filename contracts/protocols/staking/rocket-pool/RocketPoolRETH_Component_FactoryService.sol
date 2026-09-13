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

import {IRocketPoolRETHStandardExchangeDFPkg} from "contracts/protocols/staking/rocket-pool/interfaces/IRocketPoolRETHStandardExchangeDFPkg.sol";

library RocketPoolRETH_Component_FactoryService {
    using BetterEfficientHashLib for bytes;

    Vm constant vm = Vm(VM_ADDRESS);

    function deployRocketPoolRETHStandardExchangeInFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        bytes memory code = ArtifactCreationCode.creationCode("RocketPoolRETHStandardExchangeInFacet.sol:RocketPoolRETHStandardExchangeInFacet");
        instance = create3Factory.deployFacet(code, keccak256(abi.encode("RocketPoolRETHStandardExchangeInFacet", keccak256(code))));
        vm.label(address(instance), "RocketPoolRETHStandardExchangeInFacet");
    }

    function deployRocketPoolRETHStandardExchangeOutFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        bytes memory code = ArtifactCreationCode.creationCode("RocketPoolRETHStandardExchangeOutFacet.sol:RocketPoolRETHStandardExchangeOutFacet");
        instance = create3Factory.deployFacet(code, keccak256(abi.encode("RocketPoolRETHStandardExchangeOutFacet", keccak256(code))));
        vm.label(address(instance), "RocketPoolRETHStandardExchangeOutFacet");
    }

    function deployRocketPoolRETHMarkerFacet(ICreate3FactoryProxy create3Factory) internal returns (IFacet instance) {
        bytes memory code = ArtifactCreationCode.creationCode("RocketPoolRETHMarkerFacet.sol:RocketPoolRETHMarkerFacet");
        instance = create3Factory.deployFacet(code, keccak256(abi.encode("RocketPoolRETHMarkerFacet", keccak256(code))));
        vm.label(address(instance), "RocketPoolRETHMarkerFacet");
    }

    function deployRocketPoolRETHRebalanceFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        bytes memory code = ArtifactCreationCode.creationCode("RocketPoolRETHRebalanceFacet.sol:RocketPoolRETHRebalanceFacet");
        instance = create3Factory.deployFacet(code, keccak256(abi.encode("RocketPoolRETHRebalanceFacet", keccak256(code))));
        vm.label(address(instance), "RocketPoolRETHRebalanceFacet");
    }

    function deployRocketPoolRETHStandardExchangeDFPkg(
        IIndexedexManagerProxy indexedexManager,
        IRocketPoolRETHStandardExchangeDFPkg.PkgInit memory pkgInit
    ) internal returns (IRocketPoolRETHStandardExchangeDFPkg instance) {
        bytes memory code = ArtifactCreationCode.creationCode("RocketPoolRETHStandardExchangeDFPkg.sol:RocketPoolRETHStandardExchangeDFPkg");
        bytes memory arguments = abi.encode(pkgInit);
        bytes32 releaseSalt = keccak256(abi.encode("RocketPoolRETHStandardExchangeDFPkg", keccak256(code), keccak256(arguments)));
        instance = IRocketPoolRETHStandardExchangeDFPkg(address(
            IVaultRegistryDeployment(address(indexedexManager)).deployPkg(code, arguments, releaseSalt)
        ));
        vm.label(address(instance), "RocketPoolRETHStandardExchangeDFPkg");
    }
}
