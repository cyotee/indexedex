// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {ArtifactCreationCode} from "contracts/utils/foundry/ArtifactCreationCode.sol";

import {Vm} from "forge-std/Vm.sol";
import {VM_ADDRESS} from "@crane/contracts/constants/FoundryConstants.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";

library SingleStandardExchangeDETF_Facet_FactoryService {
    using BetterEfficientHashLib for bytes;

    Vm constant vm = Vm(VM_ADDRESS);

    function deploySingleStandardExchangeDETFExchangeInFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = create3Factory.deployFacet(
            ArtifactCreationCode.creationCode("SingleStandardExchangeDETFExchangeInFacet.sol:SingleStandardExchangeDETFExchangeInFacet"),
            abi.encode("SingleStandardExchangeDETFExchangeInFacet")._hash()
        );
        vm.label(address(instance), "SingleStandardExchangeDETFExchangeInFacet");
    }
    function deploySingleStandardExchangeDETFBondingFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = create3Factory.deployFacet(
            ArtifactCreationCode.creationCode("SingleStandardExchangeDETFBondingFacet.sol:SingleStandardExchangeDETFBondingFacet"),
            abi.encode("SingleStandardExchangeDETFBondingFacet")._hash()
        );
        vm.label(address(instance), "SingleStandardExchangeDETFBondingFacet");
    }
}
