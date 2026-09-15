// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {
    IUniswapV3StandardExchangeLiquidReserveV2
} from "contracts/vaults/standard/exchange/protocols/uniswap/v3/interfaces/IUniswapV3StandardExchangeLiquidReserveV2.sol";
import {
    UniswapV3StandardExchangeLiquidReserveTargetV2
} from "contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3StandardExchangeLiquidReserveTargetV2.sol";

contract UniswapV3StandardExchangeLiquidReserveFacetV2 is UniswapV3StandardExchangeLiquidReserveTargetV2, IFacet {
    function facetName() public pure returns (string memory) {
        return type(UniswapV3StandardExchangeLiquidReserveFacetV2).name;
    }

    function facetInterfaces() public pure returns (bytes4[] memory interfaces) {
        interfaces = new bytes4[](1);
        interfaces[0] = type(IUniswapV3StandardExchangeLiquidReserveV2).interfaceId;
    }

    function facetFuncs() public pure returns (bytes4[] memory funcs) {
        funcs = new bytes4[](6);
        funcs[0] = IUniswapV3StandardExchangeLiquidReserveV2.canOpenBoundPoolOps.selector;
        funcs[1] = IUniswapV3StandardExchangeLiquidReserveV2.localReserve.selector;
        funcs[2] = IUniswapV3StandardExchangeLiquidReserveV2.deployedReserve.selector;
        funcs[3] = IUniswapV3StandardExchangeLiquidReserveV2.targetLiquidReservePercentage.selector;
        funcs[4] = IUniswapV3StandardExchangeLiquidReserveV2.actualLiquidReservePercentage.selector;
        funcs[5] = IUniswapV3StandardExchangeLiquidReserveV2.rebalanceLiquidReserve.selector;
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
