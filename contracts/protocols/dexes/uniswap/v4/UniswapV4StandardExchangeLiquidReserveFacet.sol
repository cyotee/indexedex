// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {
    IUniswapV4StandardExchangeLiquidReserve
} from "contracts/protocols/dexes/uniswap/v4/interfaces/IUniswapV4StandardExchangeLiquidReserve.sol";
import {
    UniswapV4StandardExchangeLiquidReserveTarget
} from "contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeLiquidReserveTarget.sol";

contract UniswapV4StandardExchangeLiquidReserveFacet is UniswapV4StandardExchangeLiquidReserveTarget, IFacet {
    function facetName() public pure returns (string memory) {
        return type(UniswapV4StandardExchangeLiquidReserveFacet).name;
    }

    function facetInterfaces() public pure returns (bytes4[] memory interfaces) {
        interfaces = new bytes4[](1);
        interfaces[0] = type(IUniswapV4StandardExchangeLiquidReserve).interfaceId;
    }

    function facetFuncs() public pure returns (bytes4[] memory funcs) {
        funcs = new bytes4[](6);
        funcs[0] = IUniswapV4StandardExchangeLiquidReserve.canOpenPoolManagerUnlock.selector;
        funcs[1] = IUniswapV4StandardExchangeLiquidReserve.localReserve.selector;
        funcs[2] = IUniswapV4StandardExchangeLiquidReserve.deployedReserve.selector;
        funcs[3] = IUniswapV4StandardExchangeLiquidReserve.targetLiquidReservePercentage.selector;
        funcs[4] = IUniswapV4StandardExchangeLiquidReserve.actualLiquidReservePercentage.selector;
        funcs[5] = IUniswapV4StandardExchangeLiquidReserve.rebalanceLiquidReserve.selector;
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
