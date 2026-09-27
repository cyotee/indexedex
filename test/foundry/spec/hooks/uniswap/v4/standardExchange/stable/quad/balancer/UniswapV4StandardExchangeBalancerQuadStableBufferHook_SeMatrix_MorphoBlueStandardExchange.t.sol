// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {SeMatrixFixture} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrixFixture.sol";
import {SeMatrix_MorphoFixture} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrix_MorphoFixture.sol";
import {
    UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrixBehavior
} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrixBehavior.sol";

/// @notice D20: Balancer quad-stable × MorphoBlueStandardExchange (COMPATIBLE). Face: the 18-decimal loan token of a
///         hermetic Morpho Blue market wrapped by the production Morpho Blue SE package; every SE leg
///         binds its own Morpho SE (M4) and shares one package and one Morpho singleton.
contract UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrix_MorphoBlueStandardExchange is UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrixBehavior {
    address internal sharedPkg;
    address internal sharedMorpho;

    function _newFixture() internal override returns (SeMatrixFixture) {
        SeMatrix_MorphoFixture f = new SeMatrix_MorphoFixture(_ctx(), sharedPkg, sharedMorpho);
        sharedPkg = f.pkg();
        sharedMorpho = address(f.morpho());
        return f;
    }
}
