// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {SeMatrixFixture} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrixFixture.sol";
import {SeMatrix_StataFixture} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrix_StataFixture.sol";
import {
    UniswapV4SingleSEBufferHook_SeMatrixBehavior
} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/single/UniswapV4SingleSEBufferHook_SeMatrixBehavior.sol";

/// @notice D20 / R10.3: single SE buffer hook (non-CP) × AaveV3StataStandardExchange (COMPATIBLE). The
///         former DEFERRED (SE-capability gap) is closed: the Stata SE OUT facet now serves wrap
///         exact-out (`previewExchangeOut(face, SE, shares)` → underlying-in via `previewMint`), so the
///         hook's `previewWrapExactOut` no longer reverts `InvalidStataRoute(face, SE)`. Face: the
///         18-decimal Aave underlying (Crane testnet WETH) of a StataTokenV2 on the real Crane Aave
///         V3.6 pool. Partial case: `IPoolConfigurator.setSupplyCap`.
contract UniswapV4SingleSEBufferHook_SeMatrix_AaveV3StataStandardExchange is
    UniswapV4SingleSEBufferHook_SeMatrixBehavior
{
    function _newFixture() internal override returns (SeMatrixFixture) {
        return new SeMatrix_StataFixture(_ctx(), address(0), 18);
    }
}
