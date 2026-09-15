// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {
    IUniswapV4StandardExchangeLiquidReserveV2
} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/interfaces/IUniswapV4StandardExchangeLiquidReserveV2.sol";
import {
    UniswapV4StandardExchangeLiquidReserveTargetV2
} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/UniswapV4StandardExchangeLiquidReserveTargetV2.sol";

contract UniswapV4StandardExchangeLiquidReserveFacetV2 is UniswapV4StandardExchangeLiquidReserveTargetV2, IFacet {
    function facetName() public pure returns (string memory) {
        return type(UniswapV4StandardExchangeLiquidReserveFacetV2).name;
    }

    function facetInterfaces() public pure returns (bytes4[] memory interfaces) {
        interfaces = new bytes4[](1);
        interfaces[0] = type(IUniswapV4StandardExchangeLiquidReserveV2).interfaceId;
    }

    function facetFuncs() public pure returns (bytes4[] memory funcs) {
        funcs = new bytes4[](7);
        funcs[0] = IUniswapV4StandardExchangeLiquidReserveV2.canOpenPoolManagerUnlock.selector;
        funcs[1] = IUniswapV4StandardExchangeLiquidReserveV2.localReserve.selector;
        funcs[2] = IUniswapV4StandardExchangeLiquidReserveV2.deployedReserve.selector;
        funcs[3] = IUniswapV4StandardExchangeLiquidReserveV2.targetLiquidReservePercentage.selector;
        funcs[4] = IUniswapV4StandardExchangeLiquidReserveV2.actualLiquidReservePercentage.selector;
        funcs[5] = IUniswapV4StandardExchangeLiquidReserveV2.rebalanceLiquidReserve.selector;
        funcs[6] = IUniswapV4StandardExchangeLiquidReserveV2.twapOracle.selector;
    }

    function facetMetadata()
        external
        pure
        returns (string memory name_, bytes4[] memory interfaces, bytes4[] memory functions)
    {
        name_ = facetName();
        interfaces = facetInterfaces();
        functions = facetFuncs();
    }
}
