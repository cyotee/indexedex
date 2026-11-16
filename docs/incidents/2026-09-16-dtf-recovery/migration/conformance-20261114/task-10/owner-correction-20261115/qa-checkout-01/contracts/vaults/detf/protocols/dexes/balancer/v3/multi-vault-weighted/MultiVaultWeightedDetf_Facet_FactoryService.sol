// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {ArtifactCreationCode} from "contracts/utils/foundry/ArtifactCreationCode.sol";

import {Vm} from "forge-std/Vm.sol";
import {VM_ADDRESS} from "@crane/contracts/constants/FoundryConstants.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";

library MultiVaultWeightedDetf_Facet_FactoryService {
    using BetterEfficientHashLib for bytes;

    Vm constant vm = Vm(VM_ADDRESS);

    function deployMultiVaultWeightedDetfExchangeInFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = IFacet(
            create3Factory.deployFacet(
                ArtifactCreationCode.creationCode("MultiVaultWeightedDetfExchangeInFacet.sol:MultiVaultWeightedDetfExchangeInFacet"),
                abi.encode("MultiVaultWeightedDetfExchangeInFacet")._hash()
            )
        );
        vm.label(address(instance), "MultiVaultWeightedDetfExchangeInFacet");
    }

    function deployMultiVaultWeightedDetfBondingFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = IFacet(
            create3Factory.deployFacet(
                ArtifactCreationCode.creationCode("MultiVaultWeightedDetfBondingFacet.sol:MultiVaultWeightedDetfBondingFacet"),
                abi.encode("MultiVaultWeightedDetfBondingFacet")._hash()
            )
        );
        vm.label(address(instance), "MultiVaultWeightedDetfBondingFacet");
    }

    function deployMultiVaultWeightedDetfInfoFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = IFacet(
            create3Factory.deployFacet(
                ArtifactCreationCode.creationCode("MultiVaultWeightedDetfInfoFacet.sol:MultiVaultWeightedDetfInfoFacet"),
                abi.encode("MultiVaultWeightedDetfInfoFacet")._hash()
            )
        );
        vm.label(address(instance), "MultiVaultWeightedDetfInfoFacet");
    }
}
