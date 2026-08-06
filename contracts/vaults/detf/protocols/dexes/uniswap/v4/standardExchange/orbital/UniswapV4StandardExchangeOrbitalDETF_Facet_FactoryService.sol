// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Vm} from "forge-std/Vm.sol";
import {VM_ADDRESS} from "@crane/contracts/constants/FoundryConstants.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";
import {
    UniswapV4StandardExchangeOrbitalDETFFacet
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalDETFFacet.sol";
import {
    UniswapV4StandardExchangeOrbitalDETFInfoFacet
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalDETFInfoFacet.sol";

library UniswapV4StandardExchangeOrbitalDETF_Facet_FactoryService {
    using BetterEfficientHashLib for bytes;

    Vm constant vm = Vm(VM_ADDRESS);

    function deployUniswapV4StandardExchangeOrbitalDETFFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = create3Factory.deployFacet(
            type(UniswapV4StandardExchangeOrbitalDETFFacet).creationCode,
            abi.encode(type(UniswapV4StandardExchangeOrbitalDETFFacet).name)._hash()
        );
        vm.label(address(instance), type(UniswapV4StandardExchangeOrbitalDETFFacet).name);
    }

    function deployUniswapV4StandardExchangeOrbitalDETFInfoFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = create3Factory.deployFacet(
            type(UniswapV4StandardExchangeOrbitalDETFInfoFacet).creationCode,
            abi.encode(type(UniswapV4StandardExchangeOrbitalDETFInfoFacet).name)._hash()
        );
        vm.label(address(instance), type(UniswapV4StandardExchangeOrbitalDETFInfoFacet).name);
    }
}
