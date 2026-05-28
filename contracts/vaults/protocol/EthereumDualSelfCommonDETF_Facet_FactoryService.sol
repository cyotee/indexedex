// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Vm} from "forge-std/Vm.sol";

import {VM_ADDRESS} from "@crane/contracts/constants/FoundryConstants.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";

import {EthereumDualSelfCommonDETFExchangeInFacet} from "contracts/vaults/protocol/EthereumDualSelfCommonDETFExchangeInFacet.sol";
import {
    EthereumDualSelfCommonDETFExchangeInQueryFacet
} from "contracts/vaults/protocol/EthereumDualSelfCommonDETFExchangeInQueryFacet.sol";
import {EthereumDualSelfCommonDETFExchangeOutFacet} from "contracts/vaults/protocol/EthereumDualSelfCommonDETFExchangeOutFacet.sol";
import {EthereumDualSelfCommonDETFBondingFacet} from "contracts/vaults/protocol/EthereumDualSelfCommonDETFBondingFacet.sol";
import {EthereumDualSelfCommonDETFBridgeFacet} from "contracts/vaults/protocol/EthereumDualSelfCommonDETFBridgeFacet.sol";
import {
    EthereumDualSelfCommonDETFBondingQueryFacet
} from "contracts/vaults/protocol/EthereumDualSelfCommonDETFBondingQueryFacet.sol";

library EthereumDualSelfCommonDETF_Facet_FactoryService {
    using BetterEfficientHashLib for bytes;

    Vm constant vm = Vm(VM_ADDRESS);

    function deployEthereumDualSelfCommonDETFExchangeInFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = create3Factory.deployFacet(
            type(EthereumDualSelfCommonDETFExchangeInFacet).creationCode,
            abi.encode(type(EthereumDualSelfCommonDETFExchangeInFacet).name)._hash()
        );
        vm.label(address(instance), type(EthereumDualSelfCommonDETFExchangeInFacet).name);
    }

    function deployEthereumDualSelfCommonDETFExchangeInQueryFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = create3Factory.deployFacet(
            type(EthereumDualSelfCommonDETFExchangeInQueryFacet).creationCode,
            abi.encode(type(EthereumDualSelfCommonDETFExchangeInQueryFacet).name)._hash()
        );
        vm.label(address(instance), type(EthereumDualSelfCommonDETFExchangeInQueryFacet).name);
    }

    function deployEthereumDualSelfCommonDETFExchangeOutFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = create3Factory.deployFacet(
            type(EthereumDualSelfCommonDETFExchangeOutFacet).creationCode,
            abi.encode(type(EthereumDualSelfCommonDETFExchangeOutFacet).name)._hash()
        );
        vm.label(address(instance), type(EthereumDualSelfCommonDETFExchangeOutFacet).name);
    }

    function deployEthereumDualSelfCommonDETFBondingFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = create3Factory.deployFacet(
            type(EthereumDualSelfCommonDETFBondingFacet).creationCode,
            abi.encode(type(EthereumDualSelfCommonDETFBondingFacet).name)._hash()
        );
        vm.label(address(instance), type(EthereumDualSelfCommonDETFBondingFacet).name);
    }

    function deployEthereumDualSelfCommonDETFBridgeFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = create3Factory.deployFacet(
            type(EthereumDualSelfCommonDETFBridgeFacet).creationCode,
            abi.encode(type(EthereumDualSelfCommonDETFBridgeFacet).name)._hash()
        );
        vm.label(address(instance), type(EthereumDualSelfCommonDETFBridgeFacet).name);
    }

    function deployEthereumDualSelfCommonDETFBondingQueryFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = create3Factory.deployFacet(
            type(EthereumDualSelfCommonDETFBondingQueryFacet).creationCode,
            abi.encode(type(EthereumDualSelfCommonDETFBondingQueryFacet).name)._hash()
        );
        vm.label(address(instance), type(EthereumDualSelfCommonDETFBondingQueryFacet).name);
    }
}