// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {IUniswapV4FullSpreadHooklessStandardExchangeVaultExecutionProtection} from "./interfaces/IUniswapV4FullSpreadHooklessStandardExchangeVaultExecutionProtection.sol";


import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {
    IUniswapV4FullSpreadHooklessStandardExchangeVaultLiquidReserve
} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/interfaces/IUniswapV4FullSpreadHooklessStandardExchangeVaultLiquidReserve.sol";
import {
    UniswapV4FullSpreadHooklessStandardExchangeVaultLiquidReserveTarget
} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/UniswapV4FullSpreadHooklessStandardExchangeVaultLiquidReserveTarget.sol";

contract UniswapV4FullSpreadHooklessStandardExchangeVaultLiquidReserveFacet is UniswapV4FullSpreadHooklessStandardExchangeVaultLiquidReserveTarget, IFacet {
    function facetName() public pure returns (string memory) {
        return type(UniswapV4FullSpreadHooklessStandardExchangeVaultLiquidReserveFacet).name;
    }

    function facetInterfaces() public pure returns (bytes4[] memory interfaces) {
        interfaces = new bytes4[](2);
        interfaces[1] = type(IUniswapV4FullSpreadHooklessStandardExchangeVaultExecutionProtection).interfaceId;
        interfaces[0] = type(IUniswapV4FullSpreadHooklessStandardExchangeVaultLiquidReserve).interfaceId;
    }

    function facetFuncs() public pure returns (bytes4[] memory funcs) {
        funcs = new bytes4[](8);
        funcs[7] = IUniswapV4FullSpreadHooklessStandardExchangeVaultExecutionProtection.executionProtectionBps.selector;
        funcs[0] = IUniswapV4FullSpreadHooklessStandardExchangeVaultLiquidReserve.canOpenPoolManagerUnlock.selector;
        funcs[1] = IUniswapV4FullSpreadHooklessStandardExchangeVaultLiquidReserve.localReserve.selector;
        funcs[2] = IUniswapV4FullSpreadHooklessStandardExchangeVaultLiquidReserve.deployedReserve.selector;
        funcs[3] = IUniswapV4FullSpreadHooklessStandardExchangeVaultLiquidReserve.targetLiquidReservePercentage.selector;
        funcs[4] = IUniswapV4FullSpreadHooklessStandardExchangeVaultLiquidReserve.actualLiquidReservePercentage.selector;
        funcs[5] = IUniswapV4FullSpreadHooklessStandardExchangeVaultLiquidReserve.rebalanceLiquidReserve.selector;
        funcs[6] = IUniswapV4FullSpreadHooklessStandardExchangeVaultLiquidReserve.twapOracle.selector;
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
