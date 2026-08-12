// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Vm} from "forge-std/Vm.sol";
import {VM_ADDRESS} from "@crane/contracts/constants/FoundryConstants.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";
import {
    MultiVaultWeightedDetfExchangeInFacet
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/MultiVaultWeightedDetfExchangeInFacet.sol";
import {
    MultiVaultWeightedDetfBondingFacet
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/MultiVaultWeightedDetfBondingFacet.sol";
import {
    MultiVaultWeightedDetfInfoFacet
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/MultiVaultWeightedDetfInfoFacet.sol";

library MultiVaultWeightedDetf_Facet_FactoryService {
    using BetterEfficientHashLib for bytes;

    Vm constant vm = Vm(VM_ADDRESS);

    function deployMultiVaultWeightedDetfExchangeInFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = IFacet(
            create3Factory.deployFacet(
                type(MultiVaultWeightedDetfExchangeInFacet).creationCode,
                abi.encode(type(MultiVaultWeightedDetfExchangeInFacet).name)._hash()
            )
        );
        vm.label(address(instance), type(MultiVaultWeightedDetfExchangeInFacet).name);
    }

    function deployMultiVaultWeightedDetfBondingFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = IFacet(
            create3Factory.deployFacet(
                type(MultiVaultWeightedDetfBondingFacet).creationCode,
                abi.encode(type(MultiVaultWeightedDetfBondingFacet).name)._hash()
            )
        );
        vm.label(address(instance), type(MultiVaultWeightedDetfBondingFacet).name);
    }

    function deployMultiVaultWeightedDetfInfoFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = IFacet(
            create3Factory.deployFacet(
                type(MultiVaultWeightedDetfInfoFacet).creationCode,
                abi.encode(type(MultiVaultWeightedDetfInfoFacet).name)._hash()
            )
        );
        vm.label(address(instance), type(MultiVaultWeightedDetfInfoFacet).name);
    }
}
