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
    EtherFiWeETHStandardExchangeInFacet
} from "contracts/protocols/staking/etherfi/EtherFiWeETHStandardExchangeInFacet.sol";
import {
    EtherFiWeETHStandardExchangeOutFacet
} from "contracts/protocols/staking/etherfi/EtherFiWeETHStandardExchangeOutFacet.sol";
import {EtherFiWeETHMarkerFacet} from "contracts/protocols/staking/etherfi/EtherFiWeETHMarkerFacet.sol";
import {EtherFiWeETHRebalanceFacet} from "contracts/protocols/staking/etherfi/EtherFiWeETHRebalanceFacet.sol";
import {
    IEtherFiWeETHStandardExchangeDFPkg
} from "contracts/protocols/staking/etherfi/interfaces/IEtherFiWeETHStandardExchangeDFPkg.sol";
import {
    EtherFiWeETHStandardExchangeDFPkg
} from "contracts/protocols/staking/etherfi/EtherFiWeETHStandardExchangeDFPkg.sol";

library EtherFiWeETH_Component_FactoryService {
    using BetterEfficientHashLib for bytes;

    Vm constant vm = Vm(VM_ADDRESS);

    function deployEtherFiWeETHStandardExchangeInFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = create3Factory.deployFacet(
            type(EtherFiWeETHStandardExchangeInFacet).creationCode,
            abi.encode(type(EtherFiWeETHStandardExchangeInFacet).name)._hash()
        );
        vm.label(address(instance), type(EtherFiWeETHStandardExchangeInFacet).name);
    }

    function deployEtherFiWeETHStandardExchangeOutFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = create3Factory.deployFacet(
            type(EtherFiWeETHStandardExchangeOutFacet).creationCode,
            abi.encode(type(EtherFiWeETHStandardExchangeOutFacet).name)._hash()
        );
        vm.label(address(instance), type(EtherFiWeETHStandardExchangeOutFacet).name);
    }

    function deployEtherFiWeETHMarkerFacet(ICreate3FactoryProxy create3Factory) internal returns (IFacet instance) {
        instance = create3Factory.deployFacet(
            type(EtherFiWeETHMarkerFacet).creationCode, abi.encode(type(EtherFiWeETHMarkerFacet).name)._hash()
        );
        vm.label(address(instance), type(EtherFiWeETHMarkerFacet).name);
    }

    function deployEtherFiWeETHRebalanceFacet(ICreate3FactoryProxy create3Factory) internal returns (IFacet instance) {
        instance = create3Factory.deployFacet(
            type(EtherFiWeETHRebalanceFacet).creationCode, abi.encode(type(EtherFiWeETHRebalanceFacet).name)._hash()
        );
        vm.label(address(instance), type(EtherFiWeETHRebalanceFacet).name);
    }

    function deployEtherFiWeETHStandardExchangeDFPkg(
        IIndexedexManagerProxy indexedexManager,
        IEtherFiWeETHStandardExchangeDFPkg.PkgInit memory pkgInit
    ) internal returns (IEtherFiWeETHStandardExchangeDFPkg instance) {
        instance = IEtherFiWeETHStandardExchangeDFPkg(
            address(
                IVaultRegistryDeployment(address(indexedexManager)).deployPkg(
                    type(EtherFiWeETHStandardExchangeDFPkg).creationCode,
                    abi.encode(pkgInit),
                    abi.encode(type(EtherFiWeETHStandardExchangeDFPkg).name)._hash()
                )
            )
        );
        vm.label(address(instance), type(EtherFiWeETHStandardExchangeDFPkg).name);
    }
}
