// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Vm} from "forge-std/Vm.sol";
import {VM_ADDRESS} from "@crane/contracts/constants/FoundryConstants.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IIndexedexManagerProxy} from "contracts/interfaces/proxies/IIndexedexManagerProxy.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";
import {
    LidoWstETHStandardExchangeInFacet
} from "contracts/protocols/staking/lido/LidoWstETHStandardExchangeInFacet.sol";
import {
    LidoWstETHStandardExchangeOutFacet
} from "contracts/protocols/staking/lido/LidoWstETHStandardExchangeOutFacet.sol";
import {LidoWstETHMarkerFacet} from "contracts/protocols/staking/lido/LidoWstETHMarkerFacet.sol";
import {LidoWstETHRebalanceFacet} from "contracts/protocols/staking/lido/LidoWstETHRebalanceFacet.sol";
import {
    ILidoWstETHStandardExchangeDFPkg
} from "contracts/protocols/staking/lido/interfaces/ILidoWstETHStandardExchangeDFPkg.sol";
import {
    LidoWstETHStandardExchangeDFPkg
} from "contracts/protocols/staking/lido/LidoWstETHStandardExchangeDFPkg.sol";

library LidoWstETH_Component_FactoryService {
    using BetterEfficientHashLib for bytes;

    Vm constant vm = Vm(VM_ADDRESS);

    function deployLidoWstETHStandardExchangeInFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = create3Factory.deployFacet(
            type(LidoWstETHStandardExchangeInFacet).creationCode,
            abi.encode(type(LidoWstETHStandardExchangeInFacet).name)._hash()
        );
        vm.label(address(instance), type(LidoWstETHStandardExchangeInFacet).name);
    }

    function deployLidoWstETHStandardExchangeOutFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = create3Factory.deployFacet(
            type(LidoWstETHStandardExchangeOutFacet).creationCode,
            abi.encode(type(LidoWstETHStandardExchangeOutFacet).name)._hash()
        );
        vm.label(address(instance), type(LidoWstETHStandardExchangeOutFacet).name);
    }

    function deployLidoWstETHMarkerFacet(ICreate3FactoryProxy create3Factory) internal returns (IFacet instance) {
        instance = create3Factory.deployFacet(
            type(LidoWstETHMarkerFacet).creationCode, abi.encode(type(LidoWstETHMarkerFacet).name)._hash()
        );
        vm.label(address(instance), type(LidoWstETHMarkerFacet).name);
    }

    function deployLidoWstETHRebalanceFacet(ICreate3FactoryProxy create3Factory) internal returns (IFacet instance) {
        instance = create3Factory.deployFacet(
            type(LidoWstETHRebalanceFacet).creationCode, abi.encode(type(LidoWstETHRebalanceFacet).name)._hash()
        );
        vm.label(address(instance), type(LidoWstETHRebalanceFacet).name);
    }

    function deployLidoWstETHStandardExchangeDFPkg(
        IIndexedexManagerProxy indexedexManager,
        ILidoWstETHStandardExchangeDFPkg.PkgInit memory pkgInit
    ) internal returns (ILidoWstETHStandardExchangeDFPkg instance) {
        instance = ILidoWstETHStandardExchangeDFPkg(
            address(
                IVaultRegistryDeployment(address(indexedexManager)).deployPkg(
                    type(LidoWstETHStandardExchangeDFPkg).creationCode,
                    abi.encode(pkgInit),
                    abi.encode(type(LidoWstETHStandardExchangeDFPkg).name)._hash()
                )
            )
        );
        vm.label(address(instance), type(LidoWstETHStandardExchangeDFPkg).name);
    }
}
