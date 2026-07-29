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
    RocketPoolRETHStandardExchangeInFacet
} from "contracts/protocols/staking/rocket-pool/RocketPoolRETHStandardExchangeInFacet.sol";
import {
    RocketPoolRETHStandardExchangeOutFacet
} from "contracts/protocols/staking/rocket-pool/RocketPoolRETHStandardExchangeOutFacet.sol";
import {RocketPoolRETHMarkerFacet} from "contracts/protocols/staking/rocket-pool/RocketPoolRETHMarkerFacet.sol";
import {RocketPoolRETHRebalanceFacet} from "contracts/protocols/staking/rocket-pool/RocketPoolRETHRebalanceFacet.sol";
import {
    IRocketPoolRETHStandardExchangeDFPkg
} from "contracts/protocols/staking/rocket-pool/interfaces/IRocketPoolRETHStandardExchangeDFPkg.sol";
import {
    RocketPoolRETHStandardExchangeDFPkg
} from "contracts/protocols/staking/rocket-pool/RocketPoolRETHStandardExchangeDFPkg.sol";

library RocketPoolRETH_Component_FactoryService {
    using BetterEfficientHashLib for bytes;

    Vm constant vm = Vm(VM_ADDRESS);

    function deployRocketPoolRETHStandardExchangeInFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = create3Factory.deployFacet(
            type(RocketPoolRETHStandardExchangeInFacet).creationCode,
            abi.encode(type(RocketPoolRETHStandardExchangeInFacet).name)._hash()
        );
        vm.label(address(instance), type(RocketPoolRETHStandardExchangeInFacet).name);
    }

    function deployRocketPoolRETHStandardExchangeOutFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = create3Factory.deployFacet(
            type(RocketPoolRETHStandardExchangeOutFacet).creationCode,
            abi.encode(type(RocketPoolRETHStandardExchangeOutFacet).name)._hash()
        );
        vm.label(address(instance), type(RocketPoolRETHStandardExchangeOutFacet).name);
    }

    function deployRocketPoolRETHMarkerFacet(ICreate3FactoryProxy create3Factory) internal returns (IFacet instance) {
        instance = create3Factory.deployFacet(
            type(RocketPoolRETHMarkerFacet).creationCode, abi.encode(type(RocketPoolRETHMarkerFacet).name)._hash()
        );
        vm.label(address(instance), type(RocketPoolRETHMarkerFacet).name);
    }

    function deployRocketPoolRETHRebalanceFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = create3Factory.deployFacet(
            type(RocketPoolRETHRebalanceFacet).creationCode,
            abi.encode(type(RocketPoolRETHRebalanceFacet).name)._hash()
        );
        vm.label(address(instance), type(RocketPoolRETHRebalanceFacet).name);
    }

    function deployRocketPoolRETHStandardExchangeDFPkg(
        IIndexedexManagerProxy indexedexManager,
        IRocketPoolRETHStandardExchangeDFPkg.PkgInit memory pkgInit
    ) internal returns (IRocketPoolRETHStandardExchangeDFPkg instance) {
        instance = IRocketPoolRETHStandardExchangeDFPkg(
            address(
                IVaultRegistryDeployment(address(indexedexManager)).deployPkg(
                    type(RocketPoolRETHStandardExchangeDFPkg).creationCode,
                    abi.encode(pkgInit),
                    abi.encode(type(RocketPoolRETHStandardExchangeDFPkg).name)._hash()
                )
            )
        );
        vm.label(address(instance), type(RocketPoolRETHStandardExchangeDFPkg).name);
    }
}
