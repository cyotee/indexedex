// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Vm} from 'forge-std/Vm.sol';
import {VM_ADDRESS} from '@crane/contracts/constants/FoundryConstants.sol';
import {IFacet} from '@crane/contracts/interfaces/IFacet.sol';
import {ICreate3FactoryProxy} from '@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol';
import {BetterEfficientHashLib} from '@crane/contracts/utils/BetterEfficientHashLib.sol';

import {RebasingDETFTokenFacet} from 'contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/RebasingDETFTokenFacet.sol';

library RebasingDETFToken_Facet_FactoryService {
    using BetterEfficientHashLib for bytes;

    Vm constant vm = Vm(VM_ADDRESS);

    function deployRebasingDETFTokenFacet(ICreate3FactoryProxy create3Factory) internal returns (IFacet instance_) {
        instance_ = create3Factory.deployFacet(
            type(RebasingDETFTokenFacet).creationCode,
            abi.encode(type(RebasingDETFTokenFacet).name)._hash()
        );
        vm.label(address(instance_), type(RebasingDETFTokenFacet).name);
    }
}