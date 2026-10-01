// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {SeMatrixFixture} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrixFixture.sol";
import {SeMatrix_StataFixture} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrix_StataFixture.sol";
import {
    UniswapV4StandardExchangeCurveQuadStableBufferHook_SeMatrixBehavior
} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHook_SeMatrixBehavior.sol";

/// @notice D20 / R10.3: curve quad-stable buffer hook × AaveV3StataStandardExchange (COMPATIBLE). The
///         former DEFERRED (SE-capability gap) is closed: the Stata SE OUT facet now serves wrap
///         exact-out (face in for exact SE shares out via `previewMint`), so the exact-out swap rows no
///         longer revert `InvalidStataRoute(face, SE)`. The four quad legs each stand up a distinct Aave
///         stata market (the fixture discriminates its package salt by fixture address). Each leg's face
///         is that market's 18-decimal underlying (Crane testnet WETH). Partial case:
///         `IPoolConfigurator.setSupplyCap`.
contract UniswapV4StandardExchangeCurveQuadStableBufferHook_SeMatrix_AaveV3StataStandardExchange is
    UniswapV4StandardExchangeCurveQuadStableBufferHook_SeMatrixBehavior
{
    function _newFixture() internal override returns (SeMatrixFixture) {
        return new SeMatrix_StataFixture(_ctx(), address(0), 18);
    }
}
