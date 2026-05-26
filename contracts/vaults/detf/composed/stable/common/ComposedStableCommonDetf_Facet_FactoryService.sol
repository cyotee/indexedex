// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Vm} from 'forge-std/Vm.sol';
import {VM_ADDRESS} from '@crane/contracts/constants/FoundryConstants.sol';
import {IFacet} from '@crane/contracts/interfaces/IFacet.sol';
import {ICreate3FactoryProxy} from '@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol';
import {BetterEfficientHashLib} from '@crane/contracts/utils/BetterEfficientHashLib.sol';

import {ComposedStableCommonDetfExchangeIn} from 'contracts/vaults/detf/composed/stable/common/ComposedStableCommonDetfExchangeIn.sol';
import {
    ComposedStableCommonDetfBondingFacet
} from 'contracts/vaults/detf/composed/stable/common/ComposedStableCommonDetfBondingFacet.sol';
import {
    ComposedStableCommonDetfExchangeOutQueryFacet
} from 'contracts/vaults/detf/composed/stable/common/ComposedStableCommonDetfExchangeOutQueryFacet.sol';
import {RebasingDETFTokenPricingFacet} from 'contracts/vaults/detf/composed/stable/common/RebasingDETFTokenPricingFacet.sol';

library ComposedStableCommonDetf_Facet_FactoryService {
    using BetterEfficientHashLib for bytes;

    Vm constant vm = Vm(VM_ADDRESS);

    function deployComposedStableCommonDetfExchangeInFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance_)
    {
        instance_ = create3Factory.deployFacet(
            type(ComposedStableCommonDetfExchangeIn).creationCode,
            abi.encode(type(ComposedStableCommonDetfExchangeIn).name)._hash()
        );
        vm.label(address(instance_), type(ComposedStableCommonDetfExchangeIn).name);
    }

    function deployComposedStableCommonDetfExchangeOutQueryFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance_)
    {
        instance_ = create3Factory.deployFacet(
            type(ComposedStableCommonDetfExchangeOutQueryFacet).creationCode,
            abi.encode(type(ComposedStableCommonDetfExchangeOutQueryFacet).name)._hash()
        );
        vm.label(address(instance_), type(ComposedStableCommonDetfExchangeOutQueryFacet).name);
    }

    function deployComposedStableCommonDetfBondingFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance_)
    {
        instance_ = create3Factory.deployFacet(
            type(ComposedStableCommonDetfBondingFacet).creationCode,
            abi.encode(type(ComposedStableCommonDetfBondingFacet).name)._hash()
        );
        vm.label(address(instance_), type(ComposedStableCommonDetfBondingFacet).name);
    }

    function deployRebasingDetfTokenPricingFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance_)
    {
        instance_ = create3Factory.deployFacet(
            type(RebasingDETFTokenPricingFacet).creationCode,
            abi.encode(type(RebasingDETFTokenPricingFacet).name)._hash()
        );
        vm.label(address(instance_), type(RebasingDETFTokenPricingFacet).name);
    }
}