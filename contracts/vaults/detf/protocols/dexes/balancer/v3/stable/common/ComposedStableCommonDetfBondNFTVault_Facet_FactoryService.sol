// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Vm} from "forge-std/Vm.sol";
import {VM_ADDRESS} from "@crane/contracts/constants/FoundryConstants.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";

import {ComposedStableCommonDetfBondNFTVaultFacet} from "contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/ComposedStableCommonDetfBondNFTVaultFacet.sol";

library ComposedStableCommonDetfBondNFTVault_Facet_FactoryService {
    using BetterEfficientHashLib for bytes;

    Vm internal constant vm = Vm(VM_ADDRESS);

    function deployComposedStableCommonDetfBondNFTVaultFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance_)
    {
        instance_ = create3Factory.deployFacet(
            type(ComposedStableCommonDetfBondNFTVaultFacet).creationCode,
            abi.encode(type(ComposedStableCommonDetfBondNFTVaultFacet).name)._hash()
        );
        vm.label(address(instance_), type(ComposedStableCommonDetfBondNFTVaultFacet).name);
    }
}