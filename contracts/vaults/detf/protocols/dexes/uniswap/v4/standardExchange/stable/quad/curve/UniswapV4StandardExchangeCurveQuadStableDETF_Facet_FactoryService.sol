// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Vm} from "forge-std/Vm.sol";
import {VM_ADDRESS} from "@crane/contracts/constants/FoundryConstants.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";
import {
    UniswapV4StandardExchangeCurveQuadStableDETFFacet
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableDETFFacet.sol";
import {
    UniswapV4StandardExchangeCurveQuadStableDETFExchangeFacet
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableDETFExchangeFacet.sol";
import {
    UniswapV4StandardExchangeCurveQuadStableDETFInfoFacet
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableDETFInfoFacet.sol";
import {
    UniswapV4StandardExchangeCurveQuadStableDETFCompoundFacet
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableDETFCompoundFacet.sol";

library UniswapV4StandardExchangeCurveQuadStableDETF_Facet_FactoryService {
    using BetterEfficientHashLib for bytes;

    Vm constant vm = Vm(VM_ADDRESS);

    function deployUniswapV4StandardExchangeCurveQuadStableDETFFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = create3Factory.deployFacet(
            type(UniswapV4StandardExchangeCurveQuadStableDETFFacet).creationCode,
            abi.encode(type(UniswapV4StandardExchangeCurveQuadStableDETFFacet).name)._hash()
        );
        vm.label(address(instance), type(UniswapV4StandardExchangeCurveQuadStableDETFFacet).name);
    }

    function deployUniswapV4StandardExchangeCurveQuadStableDETFExchangeFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = create3Factory.deployFacet(
            type(UniswapV4StandardExchangeCurveQuadStableDETFExchangeFacet).creationCode,
            abi.encode(type(UniswapV4StandardExchangeCurveQuadStableDETFExchangeFacet).name)._hash()
        );
        vm.label(address(instance), type(UniswapV4StandardExchangeCurveQuadStableDETFExchangeFacet).name);
    }

    function deployUniswapV4StandardExchangeCurveQuadStableDETFInfoFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = create3Factory.deployFacet(
            type(UniswapV4StandardExchangeCurveQuadStableDETFInfoFacet).creationCode,
            abi.encode(type(UniswapV4StandardExchangeCurveQuadStableDETFInfoFacet).name)._hash()
        );
        vm.label(address(instance), type(UniswapV4StandardExchangeCurveQuadStableDETFInfoFacet).name);
    }

    function deployUniswapV4StandardExchangeCurveQuadStableDETFCompoundFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = create3Factory.deployFacet(
            type(UniswapV4StandardExchangeCurveQuadStableDETFCompoundFacet).creationCode,
            abi.encode(type(UniswapV4StandardExchangeCurveQuadStableDETFCompoundFacet).name)._hash()
        );
        vm.label(address(instance), type(UniswapV4StandardExchangeCurveQuadStableDETFCompoundFacet).name);
    }
}
