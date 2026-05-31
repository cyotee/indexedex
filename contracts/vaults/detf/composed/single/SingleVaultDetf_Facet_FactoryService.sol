// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Vm} from "forge-std/Vm.sol";
import {VM_ADDRESS} from "@crane/contracts/constants/FoundryConstants.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";

import {SingleVaultDetfBondingFacet} from "contracts/vaults/detf/composed/single/SingleVaultDetfBondingFacet.sol";
import {SingleVaultDetfExchangeInFacet} from "contracts/vaults/detf/composed/single/SingleVaultDetfExchangeInFacet.sol";
import {SingleVaultDetfExchangeInQueryFacet} from "contracts/vaults/detf/composed/single/SingleVaultDetfExchangeInQueryFacet.sol";
import {SingleVaultDetfInfoFacet} from "contracts/vaults/detf/composed/single/SingleVaultDetfInfoFacet.sol";
import {SingleVaultDetfExchangeOutFacet} from "contracts/vaults/detf/composed/single/SingleVaultDetfExchangeOutFacet.sol";

library SingleVaultDetf_Facet_FactoryService {
    using BetterEfficientHashLib for bytes;

    Vm constant vm = Vm(VM_ADDRESS);

    function deploySingleVaultDetfExchangeInFacet(ICreate3FactoryProxy create3Factory) internal returns (IFacet instance_) {
        instance_ = create3Factory.deployFacet(type(SingleVaultDetfExchangeInFacet).creationCode, abi.encode(type(SingleVaultDetfExchangeInFacet).name)._hash());
        vm.label(address(instance_), type(SingleVaultDetfExchangeInFacet).name);
    }

    function deploySingleVaultDetfExchangeInQueryFacet(ICreate3FactoryProxy create3Factory) internal returns (IFacet instance_) {
        instance_ = create3Factory.deployFacet(type(SingleVaultDetfExchangeInQueryFacet).creationCode, abi.encode(type(SingleVaultDetfExchangeInQueryFacet).name)._hash());
        vm.label(address(instance_), type(SingleVaultDetfExchangeInQueryFacet).name);
    }

    function deploySingleVaultDetfInfoFacet(ICreate3FactoryProxy create3Factory) internal returns (IFacet instance_) {
        instance_ = create3Factory.deployFacet(type(SingleVaultDetfInfoFacet).creationCode, abi.encode(type(SingleVaultDetfInfoFacet).name)._hash());
        vm.label(address(instance_), type(SingleVaultDetfInfoFacet).name);
    }

    function deploySingleVaultDetfExchangeOutFacet(ICreate3FactoryProxy create3Factory) internal returns (IFacet instance_) {
        instance_ = create3Factory.deployFacet(type(SingleVaultDetfExchangeOutFacet).creationCode, abi.encode(type(SingleVaultDetfExchangeOutFacet).name)._hash());
        vm.label(address(instance_), type(SingleVaultDetfExchangeOutFacet).name);
    }

    function deploySingleVaultDetfBondingFacet(ICreate3FactoryProxy create3Factory) internal returns (IFacet instance_) {
        instance_ = create3Factory.deployFacet(type(SingleVaultDetfBondingFacet).creationCode, abi.encode(type(SingleVaultDetfBondingFacet).name)._hash());
        vm.label(address(instance_), type(SingleVaultDetfBondingFacet).name);
    }
}