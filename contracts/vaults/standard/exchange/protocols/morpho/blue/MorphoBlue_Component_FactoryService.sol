// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Vm} from "forge-std/Vm.sol";
import {VM_ADDRESS} from "@crane/contracts/constants/FoundryConstants.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IIndexedexManagerProxy} from "contracts/interfaces/proxies/IIndexedexManagerProxy.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";
import {
    MorphoBlueERC4626Facet
} from "contracts/vaults/standard/exchange/protocols/morpho/blue/MorphoBlueERC4626Facet.sol";
import {
    MorphoBlueStandardExchangeInFacet
} from "contracts/vaults/standard/exchange/protocols/morpho/blue/MorphoBlueStandardExchangeInFacet.sol";
import {
    MorphoBlueStandardExchangeOutFacet
} from "contracts/vaults/standard/exchange/protocols/morpho/blue/MorphoBlueStandardExchangeOutFacet.sol";
import {
    MorphoBlueStandardExchangeMarkerFacet
} from "contracts/vaults/standard/exchange/protocols/morpho/blue/MorphoBlueStandardExchangeMarkerFacet.sol";
import {
    IMorphoBlueStandardExchangeDFPkg
} from "contracts/vaults/standard/exchange/protocols/morpho/blue/IMorphoBlueStandardExchangeDFPkg.sol";
import {
    MorphoBlueStandardExchangeDFPkg
} from "contracts/vaults/standard/exchange/protocols/morpho/blue/MorphoBlueStandardExchangeDFPkg.sol";

library MorphoBlue_Component_FactoryService {
    using BetterEfficientHashLib for bytes;

    Vm constant vm = Vm(VM_ADDRESS);

    function deployMorphoBlueERC4626Facet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = create3Factory.deployFacet(
            type(MorphoBlueERC4626Facet).creationCode,
            abi.encode(type(MorphoBlueERC4626Facet).name)._hash()
        );
        vm.label(address(instance), type(MorphoBlueERC4626Facet).name);
    }

    function deployMorphoBlueStandardExchangeInFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = create3Factory.deployFacet(
            type(MorphoBlueStandardExchangeInFacet).creationCode,
            abi.encode(type(MorphoBlueStandardExchangeInFacet).name)._hash()
        );
        vm.label(address(instance), type(MorphoBlueStandardExchangeInFacet).name);
    }

    function deployMorphoBlueStandardExchangeOutFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = create3Factory.deployFacet(
            type(MorphoBlueStandardExchangeOutFacet).creationCode,
            abi.encode(type(MorphoBlueStandardExchangeOutFacet).name)._hash()
        );
        vm.label(address(instance), type(MorphoBlueStandardExchangeOutFacet).name);
    }

    function deployMorphoBlueStandardExchangeMarkerFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = create3Factory.deployFacet(
            type(MorphoBlueStandardExchangeMarkerFacet).creationCode,
            abi.encode(type(MorphoBlueStandardExchangeMarkerFacet).name)._hash()
        );
        vm.label(address(instance), type(MorphoBlueStandardExchangeMarkerFacet).name);
    }

    function deployMorphoBlueStandardExchangeDFPkg(
        IIndexedexManagerProxy indexedexManager,
        IMorphoBlueStandardExchangeDFPkg.PkgInit memory pkgInit
    ) internal returns (IMorphoBlueStandardExchangeDFPkg instance) {
        instance = IMorphoBlueStandardExchangeDFPkg(
            address(
                IVaultRegistryDeployment(address(indexedexManager)).deployPkg(
                    type(MorphoBlueStandardExchangeDFPkg).creationCode,
                    abi.encode(pkgInit),
                    abi.encode(type(MorphoBlueStandardExchangeDFPkg).name)._hash()
                )
            )
        );
        vm.label(address(instance), type(MorphoBlueStandardExchangeDFPkg).name);
    }
}
