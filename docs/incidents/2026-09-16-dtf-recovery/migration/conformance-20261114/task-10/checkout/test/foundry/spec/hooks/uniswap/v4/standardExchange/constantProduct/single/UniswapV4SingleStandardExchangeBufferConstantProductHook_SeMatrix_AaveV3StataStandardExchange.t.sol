// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {SeMatrixFixture} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrixFixture.sol";
import {SeMatrix_StataFixture} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrix_StataFixture.sol";
import {
    UniswapV4SingleStandardExchangeBufferConstantProductHook_SeMatrixBehavior
} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_SeMatrixBehavior.sol";

/// @notice D20: constantProduct/single × AaveV3StataStandardExchange (COMPATIBLE; the M13 host row for
///         this heavy family). Face: the 18-decimal Aave underlying (Crane testnet WETH) of a
///         StataTokenV2 on the real Crane Aave V3.6 pool, wrapped by the registry-deployed Stata SE
///         package; SE shares are 18 decimals. Partial case: `IPoolConfigurator.setSupplyCap`.
contract UniswapV4SingleStandardExchangeBufferConstantProductHook_SeMatrix_AaveV3StataStandardExchange is
    UniswapV4SingleStandardExchangeBufferConstantProductHook_SeMatrixBehavior
{
    function _newFixture() internal override returns (SeMatrixFixture) {
        return new SeMatrix_StataFixture(_ctx(), address(0), 18);
    }
}
