// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {
    IUniswapV3FullSpreadStandardExchangeVaultLiquidReserve
} from "contracts/vaults/standard/exchange/protocols/uniswap/v3/interfaces/IUniswapV3FullSpreadStandardExchangeVaultLiquidReserve.sol";
import {
    UniswapV3FullSpreadStandardExchangeVaultLiquidReserveTarget
} from "contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultLiquidReserveTarget.sol";

contract UniswapV3FullSpreadStandardExchangeVaultLiquidReserveFacet is UniswapV3FullSpreadStandardExchangeVaultLiquidReserveTarget, IFacet {
    function facetName() public pure returns (string memory) {
        return type(UniswapV3FullSpreadStandardExchangeVaultLiquidReserveFacet).name;
    }

    function facetInterfaces() public pure returns (bytes4[] memory interfaces) {
        interfaces = new bytes4[](1);
        interfaces[0] = type(IUniswapV3FullSpreadStandardExchangeVaultLiquidReserve).interfaceId;
    }

    function facetFuncs() public pure returns (bytes4[] memory funcs) {
        funcs = new bytes4[](6);
        funcs[0] = IUniswapV3FullSpreadStandardExchangeVaultLiquidReserve.canOpenBoundPoolOps.selector;
        funcs[1] = IUniswapV3FullSpreadStandardExchangeVaultLiquidReserve.localReserve.selector;
        funcs[2] = IUniswapV3FullSpreadStandardExchangeVaultLiquidReserve.deployedReserve.selector;
        funcs[3] = IUniswapV3FullSpreadStandardExchangeVaultLiquidReserve.targetLiquidReservePercentage.selector;
        funcs[4] = IUniswapV3FullSpreadStandardExchangeVaultLiquidReserve.actualLiquidReservePercentage.selector;
        funcs[5] = IUniswapV3FullSpreadStandardExchangeVaultLiquidReserve.rebalanceLiquidReserve.selector;
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
