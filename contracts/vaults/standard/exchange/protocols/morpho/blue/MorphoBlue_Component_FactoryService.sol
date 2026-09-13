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

import {IMorphoBlueStandardExchangeDFPkg} from "contracts/vaults/standard/exchange/protocols/morpho/blue/IMorphoBlueStandardExchangeDFPkg.sol";

library MorphoBlue_Component_FactoryService {
    using BetterEfficientHashLib for bytes;

    Vm constant vm = Vm(VM_ADDRESS);

    function deployMorphoBlueERC4626Facet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        bytes memory initCode_ = ArtifactCreationCode.creationCode("MorphoBlueERC4626Facet.sol:MorphoBlueERC4626Facet");
        instance = create3Factory.deployFacet(
            initCode_, ArtifactCreationCode.releaseSalt(abi.encode("MorphoBlueERC4626Facet")._hash(), initCode_, "")
        );
        vm.label(address(instance), "MorphoBlueERC4626Facet");
    }

    function deployMorphoBlueStandardExchangeInFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        bytes memory initCode_ = ArtifactCreationCode.creationCode("MorphoBlueStandardExchangeInFacet.sol:MorphoBlueStandardExchangeInFacet");
        instance = create3Factory.deployFacet(
            initCode_, ArtifactCreationCode.releaseSalt(abi.encode("MorphoBlueStandardExchangeInFacet")._hash(), initCode_, "")
        );
        vm.label(address(instance), "MorphoBlueStandardExchangeInFacet");
    }

    function deployMorphoBlueStandardExchangeOutFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        bytes memory initCode_ = ArtifactCreationCode.creationCode("MorphoBlueStandardExchangeOutFacet.sol:MorphoBlueStandardExchangeOutFacet");
        instance = create3Factory.deployFacet(
            initCode_, ArtifactCreationCode.releaseSalt(abi.encode("MorphoBlueStandardExchangeOutFacet")._hash(), initCode_, "")
        );
        vm.label(address(instance), "MorphoBlueStandardExchangeOutFacet");
    }

    function deployMorphoBlueStandardExchangeMarkerFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        bytes memory initCode_ = ArtifactCreationCode.creationCode("MorphoBlueStandardExchangeMarkerFacet.sol:MorphoBlueStandardExchangeMarkerFacet");
        instance = create3Factory.deployFacet(
            initCode_, ArtifactCreationCode.releaseSalt(abi.encode("MorphoBlueStandardExchangeMarkerFacet")._hash(), initCode_, "")
        );
        vm.label(address(instance), "MorphoBlueStandardExchangeMarkerFacet");
    }

    function deployMorphoBlueStandardExchangeDFPkg(
        IIndexedexManagerProxy indexedexManager,
        IMorphoBlueStandardExchangeDFPkg.PkgInit memory pkgInit
    ) internal returns (IMorphoBlueStandardExchangeDFPkg instance) {
        bytes memory initCode_ = ArtifactCreationCode.creationCode("MorphoBlueStandardExchangeDFPkg.sol:MorphoBlueStandardExchangeDFPkg");
        bytes memory initArgs_ = abi.encode(pkgInit);
        instance = IMorphoBlueStandardExchangeDFPkg(
            address(
                IVaultRegistryDeployment(address(indexedexManager)).deployPkg(
                    initCode_,
                    initArgs_,
                    ArtifactCreationCode.releaseSalt(abi.encode("MorphoBlueStandardExchangeDFPkg")._hash(), initCode_, initArgs_)
                )
            )
        );
        vm.label(address(instance), "MorphoBlueStandardExchangeDFPkg");
    }
}
