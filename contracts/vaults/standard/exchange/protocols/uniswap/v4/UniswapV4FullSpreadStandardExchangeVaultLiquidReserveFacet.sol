// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {
    IUniswapV4FullSpreadStandardExchangeVaultLiquidReserve
} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/interfaces/IUniswapV4FullSpreadStandardExchangeVaultLiquidReserve.sol";
import {
    UniswapV4FullSpreadStandardExchangeVaultLiquidReserveTarget
} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/UniswapV4FullSpreadStandardExchangeVaultLiquidReserveTarget.sol";

contract UniswapV4FullSpreadStandardExchangeVaultLiquidReserveFacet is UniswapV4FullSpreadStandardExchangeVaultLiquidReserveTarget, IFacet {
    function facetName() public pure returns (string memory) {
        return type(UniswapV4FullSpreadStandardExchangeVaultLiquidReserveFacet).name;
    }

    function facetInterfaces() public pure returns (bytes4[] memory interfaces) {
        interfaces = new bytes4[](1);
        interfaces[0] = type(IUniswapV4FullSpreadStandardExchangeVaultLiquidReserve).interfaceId;
    }

    function facetFuncs() public pure returns (bytes4[] memory funcs) {
        funcs = new bytes4[](7);
        funcs[0] = IUniswapV4FullSpreadStandardExchangeVaultLiquidReserve.canOpenPoolManagerUnlock.selector;
        funcs[1] = IUniswapV4FullSpreadStandardExchangeVaultLiquidReserve.localReserve.selector;
        funcs[2] = IUniswapV4FullSpreadStandardExchangeVaultLiquidReserve.deployedReserve.selector;
        funcs[3] = IUniswapV4FullSpreadStandardExchangeVaultLiquidReserve.targetLiquidReservePercentage.selector;
        funcs[4] = IUniswapV4FullSpreadStandardExchangeVaultLiquidReserve.actualLiquidReservePercentage.selector;
        funcs[5] = IUniswapV4FullSpreadStandardExchangeVaultLiquidReserve.rebalanceLiquidReserve.selector;
        funcs[6] = IUniswapV4FullSpreadStandardExchangeVaultLiquidReserve.twapOracle.selector;
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
