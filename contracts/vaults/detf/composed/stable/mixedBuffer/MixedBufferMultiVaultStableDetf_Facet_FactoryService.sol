// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Vm} from "forge-std/Vm.sol";
import {VM_ADDRESS} from "@crane/contracts/constants/FoundryConstants.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";
import {
    MixedBufferMultiVaultStableDetfExchangeInFacet
} from "contracts/vaults/detf/composed/stable/mixedBuffer/MixedBufferMultiVaultStableDetfExchangeInFacet.sol";

library MixedBufferMultiVaultStableDetf_Facet_FactoryService {
    using BetterEfficientHashLib for bytes;

    Vm constant vm = Vm(VM_ADDRESS);

    function deployMixedBufferMultiVaultStableDetfExchangeInFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = IFacet(
            create3Factory.deployFacet(
                type(MixedBufferMultiVaultStableDetfExchangeInFacet).creationCode,
                abi.encode(type(MixedBufferMultiVaultStableDetfExchangeInFacet).name)._hash()
            )
        );
        vm.label(address(instance), type(MixedBufferMultiVaultStableDetfExchangeInFacet).name);
    }
}
