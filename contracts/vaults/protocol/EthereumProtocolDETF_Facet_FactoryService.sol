// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Vm} from "forge-std/Vm.sol";

import {VM_ADDRESS} from "@crane/contracts/constants/FoundryConstants.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";

import {EthereumProtocolDETFExchangeInFacet} from "contracts/vaults/protocol/EthereumProtocolDETFExchangeInFacet.sol";
import {
    EthereumProtocolDETFExchangeInQueryFacet
} from "contracts/vaults/protocol/EthereumProtocolDETFExchangeInQueryFacet.sol";
import {EthereumProtocolDETFExchangeOutFacet} from "contracts/vaults/protocol/EthereumProtocolDETFExchangeOutFacet.sol";
import {EthereumProtocolDETFBondingFacet} from "contracts/vaults/protocol/EthereumProtocolDETFBondingFacet.sol";
import {EthereumProtocolDETFBridgeFacet} from "contracts/vaults/protocol/EthereumProtocolDETFBridgeFacet.sol";
import {
    EthereumProtocolDETFBondingQueryFacet
} from "contracts/vaults/protocol/EthereumProtocolDETFBondingQueryFacet.sol";

library EthereumProtocolDETF_Facet_FactoryService {
    using BetterEfficientHashLib for bytes;

    Vm constant vm = Vm(VM_ADDRESS);

    function deployEthereumProtocolDETFExchangeInFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = create3Factory.deployFacet(
            type(EthereumProtocolDETFExchangeInFacet).creationCode,
            abi.encode(type(EthereumProtocolDETFExchangeInFacet).name)._hash()
        );
        vm.label(address(instance), type(EthereumProtocolDETFExchangeInFacet).name);
    }

    function deployEthereumProtocolDETFExchangeInQueryFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = create3Factory.deployFacet(
            type(EthereumProtocolDETFExchangeInQueryFacet).creationCode,
            abi.encode(type(EthereumProtocolDETFExchangeInQueryFacet).name)._hash()
        );
        vm.label(address(instance), type(EthereumProtocolDETFExchangeInQueryFacet).name);
    }

    function deployEthereumProtocolDETFExchangeOutFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = create3Factory.deployFacet(
            type(EthereumProtocolDETFExchangeOutFacet).creationCode,
            abi.encode(type(EthereumProtocolDETFExchangeOutFacet).name)._hash()
        );
        vm.label(address(instance), type(EthereumProtocolDETFExchangeOutFacet).name);
    }

    function deployEthereumProtocolDETFBondingFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = create3Factory.deployFacet(
            type(EthereumProtocolDETFBondingFacet).creationCode,
            abi.encode(type(EthereumProtocolDETFBondingFacet).name)._hash()
        );
        vm.label(address(instance), type(EthereumProtocolDETFBondingFacet).name);
    }

    function deployEthereumProtocolDETFBridgeFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = create3Factory.deployFacet(
            type(EthereumProtocolDETFBridgeFacet).creationCode,
            abi.encode(type(EthereumProtocolDETFBridgeFacet).name)._hash()
        );
        vm.label(address(instance), type(EthereumProtocolDETFBridgeFacet).name);
    }

    function deployEthereumProtocolDETFBondingQueryFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = create3Factory.deployFacet(
            type(EthereumProtocolDETFBondingQueryFacet).creationCode,
            abi.encode(type(EthereumProtocolDETFBondingQueryFacet).name)._hash()
        );
        vm.label(address(instance), type(EthereumProtocolDETFBondingQueryFacet).name);
    }
}