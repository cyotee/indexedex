// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Vm} from "forge-std/Vm.sol";
import {VM_ADDRESS} from "@crane/contracts/constants/FoundryConstants.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";
import {
    UniswapV4StandardExchangeWeightedDETFFacet
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedDETFFacet.sol";
import {
    UniswapV4StandardExchangeWeightedDETFInfoFacet
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedDETFInfoFacet.sol";

library UniswapV4StandardExchangeWeightedDETF_Facet_FactoryService {
    using BetterEfficientHashLib for bytes;

    Vm constant vm = Vm(VM_ADDRESS);

    function deployUniswapV4StandardExchangeWeightedDETFFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = create3Factory.deployFacet(
            type(UniswapV4StandardExchangeWeightedDETFFacet).creationCode,
            abi.encode(type(UniswapV4StandardExchangeWeightedDETFFacet).name)._hash()
        );
        vm.label(address(instance), type(UniswapV4StandardExchangeWeightedDETFFacet).name);
    }

    function deployUniswapV4StandardExchangeWeightedDETFInfoFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = create3Factory.deployFacet(
            type(UniswapV4StandardExchangeWeightedDETFInfoFacet).creationCode,
            abi.encode(type(UniswapV4StandardExchangeWeightedDETFInfoFacet).name)._hash()
        );
        vm.label(address(instance), type(UniswapV4StandardExchangeWeightedDETFInfoFacet).name);
    }
}
