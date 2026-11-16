// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {ArtifactCreationCode} from "contracts/utils/foundry/ArtifactCreationCode.sol";

import {Vm} from 'forge-std/Vm.sol';
import {VM_ADDRESS} from '@crane/contracts/constants/FoundryConstants.sol';
import {IFacet} from '@crane/contracts/interfaces/IFacet.sol';
import {ICreate3FactoryProxy} from '@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol';
import {BetterEfficientHashLib} from '@crane/contracts/utils/BetterEfficientHashLib.sol';

library ComposedStableCommonDetf_Facet_FactoryService {
    using BetterEfficientHashLib for bytes;

    Vm constant vm = Vm(VM_ADDRESS);

    function deployComposedStableCommonDetfExchangeInFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance_)
    {
        instance_ = create3Factory.deployFacet(
            ArtifactCreationCode.creationCode("ComposedStableCommonDetfExchangeIn.sol:ComposedStableCommonDetfExchangeIn"),
            abi.encode("ComposedStableCommonDetfExchangeIn")._hash()
        );
        vm.label(address(instance_), "ComposedStableCommonDetfExchangeIn");
    }

    function deployComposedStableCommonDetfExchangeOutQueryFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance_)
    {
        instance_ = create3Factory.deployFacet(
            ArtifactCreationCode.creationCode("ComposedStableCommonDetfExchangeOutQueryFacet.sol:ComposedStableCommonDetfExchangeOutQueryFacet"),
            abi.encode("ComposedStableCommonDetfExchangeOutQueryFacet")._hash()
        );
        vm.label(address(instance_), "ComposedStableCommonDetfExchangeOutQueryFacet");
    }

    function deployComposedStableCommonDetfBondingFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance_)
    {
        instance_ = create3Factory.deployFacet(
            ArtifactCreationCode.creationCode("ComposedStableCommonDetfBondingFacet.sol:ComposedStableCommonDetfBondingFacet"),
            abi.encode("ComposedStableCommonDetfBondingFacet")._hash()
        );
        vm.label(address(instance_), "ComposedStableCommonDetfBondingFacet");
    }

    function deployRebasingDetfTokenPricingFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance_)
    {
        instance_ = create3Factory.deployFacet(
            ArtifactCreationCode.creationCode("RebasingDETFTokenPricingFacet.sol:RebasingDETFTokenPricingFacet"),
            abi.encode("RebasingDETFTokenPricingFacet")._hash()
        );
        vm.label(address(instance_), "RebasingDETFTokenPricingFacet");
    }
}