// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {ArtifactCreationCode} from "contracts/utils/foundry/ArtifactCreationCode.sol";

import {Vm} from "forge-std/Vm.sol";
import {VM_ADDRESS} from "@crane/contracts/constants/FoundryConstants.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";

library MixedBufferMultiVaultStableDetf_Facet_FactoryService {
    using BetterEfficientHashLib for bytes;

    Vm constant vm = Vm(VM_ADDRESS);

    function deployMixedBufferMultiVaultStableDetfExchangeInFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = IFacet(
            create3Factory.deployFacet(
                ArtifactCreationCode.creationCode("MixedBufferMultiVaultStableDetfExchangeInFacet.sol:MixedBufferMultiVaultStableDetfExchangeInFacet"),
                abi.encode("MixedBufferMultiVaultStableDetfExchangeInFacet")._hash()
            )
        );
        vm.label(address(instance), "MixedBufferMultiVaultStableDetfExchangeInFacet");
    }

    function deployMixedBufferMultiVaultStableDetfBondingFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = IFacet(
            create3Factory.deployFacet(
                ArtifactCreationCode.creationCode("MixedBufferMultiVaultStableDetfBondingFacet.sol:MixedBufferMultiVaultStableDetfBondingFacet"),
                abi.encode("MixedBufferMultiVaultStableDetfBondingFacet")._hash()
            )
        );
        vm.label(address(instance), "MixedBufferMultiVaultStableDetfBondingFacet");
    }

    function deployMixedBufferMultiVaultStableDetfInfoFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = IFacet(
            create3Factory.deployFacet(
                ArtifactCreationCode.creationCode("MixedBufferMultiVaultStableDetfInfoFacet.sol:MixedBufferMultiVaultStableDetfInfoFacet"),
                abi.encode("MixedBufferMultiVaultStableDetfInfoFacet")._hash()
            )
        );
        vm.label(address(instance), "MixedBufferMultiVaultStableDetfInfoFacet");
    }
}
