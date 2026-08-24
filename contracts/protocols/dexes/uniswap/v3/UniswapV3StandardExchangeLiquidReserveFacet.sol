// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {
    IUniswapV3StandardExchangeLiquidReserve
} from "contracts/protocols/dexes/uniswap/v3/interfaces/IUniswapV3StandardExchangeLiquidReserve.sol";
import {
    UniswapV3StandardExchangeLiquidReserveTarget
} from "contracts/protocols/dexes/uniswap/v3/UniswapV3StandardExchangeLiquidReserveTarget.sol";

contract UniswapV3StandardExchangeLiquidReserveFacet is UniswapV3StandardExchangeLiquidReserveTarget, IFacet {
    function facetName() public pure returns (string memory) {
        return type(UniswapV3StandardExchangeLiquidReserveFacet).name;
    }

    function facetInterfaces() public pure returns (bytes4[] memory interfaces) {
        interfaces = new bytes4[](1);
        interfaces[0] = type(IUniswapV3StandardExchangeLiquidReserve).interfaceId;
    }

    function facetFuncs() public pure returns (bytes4[] memory funcs) {
        funcs = new bytes4[](6);
        funcs[0] = IUniswapV3StandardExchangeLiquidReserve.canOpenBoundPoolOps.selector;
        funcs[1] = IUniswapV3StandardExchangeLiquidReserve.localReserve.selector;
        funcs[2] = IUniswapV3StandardExchangeLiquidReserve.deployedReserve.selector;
        funcs[3] = IUniswapV3StandardExchangeLiquidReserve.targetLiquidReservePercentage.selector;
        funcs[4] = IUniswapV3StandardExchangeLiquidReserve.actualLiquidReservePercentage.selector;
        funcs[5] = IUniswapV3StandardExchangeLiquidReserve.rebalanceLiquidReserve.selector;
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
