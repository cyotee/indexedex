// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {IUniswapV4FullSpreadPonsFamilyHookExecutionProtection} from "./interfaces/IUniswapV4FullSpreadPonsFamilyHookExecutionProtection.sol";


import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {
    IUniswapV4FullSpreadPonsFamilyHookLiquidReserve
} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/interfaces/IUniswapV4FullSpreadPonsFamilyHookLiquidReserve.sol";
import {
    UniswapV4FullSpreadPonsFamilyHookLiquidReserveTarget
} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/UniswapV4FullSpreadPonsFamilyHookLiquidReserveTarget.sol";

contract UniswapV4FullSpreadPonsFamilyHookLiquidReserveFacet is UniswapV4FullSpreadPonsFamilyHookLiquidReserveTarget, IFacet {
    function facetName() public pure returns (string memory) {
        return type(UniswapV4FullSpreadPonsFamilyHookLiquidReserveFacet).name;
    }

    function facetInterfaces() public pure returns (bytes4[] memory interfaces) {
        interfaces = new bytes4[](2);
        interfaces[1] = type(IUniswapV4FullSpreadPonsFamilyHookExecutionProtection).interfaceId;
        interfaces[0] = type(IUniswapV4FullSpreadPonsFamilyHookLiquidReserve).interfaceId;
    }

    function facetFuncs() public pure returns (bytes4[] memory funcs) {
        funcs = new bytes4[](8);
        funcs[7] = IUniswapV4FullSpreadPonsFamilyHookExecutionProtection.executionProtectionBps.selector;
        funcs[0] = IUniswapV4FullSpreadPonsFamilyHookLiquidReserve.canOpenPoolManagerUnlock.selector;
        funcs[1] = IUniswapV4FullSpreadPonsFamilyHookLiquidReserve.localReserve.selector;
        funcs[2] = IUniswapV4FullSpreadPonsFamilyHookLiquidReserve.deployedReserve.selector;
        funcs[3] = IUniswapV4FullSpreadPonsFamilyHookLiquidReserve.targetLiquidReservePercentage.selector;
        funcs[4] = IUniswapV4FullSpreadPonsFamilyHookLiquidReserve.actualLiquidReservePercentage.selector;
        funcs[5] = IUniswapV4FullSpreadPonsFamilyHookLiquidReserve.rebalanceLiquidReserve.selector;
        funcs[6] = IUniswapV4FullSpreadPonsFamilyHookLiquidReserve.twapOracle.selector;
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
