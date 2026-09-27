// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {SeMatrixFixture} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrixFixture.sol";
import {SeMatrix_RocketFixture} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrix_RocketFixture.sol";
import {
    UniswapV4StandardExchangeWeightedBufferHook_SeMatrixBehavior
} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_SeMatrixBehavior.sol";

/// @notice D20: weighted × RocketPoolRETHStandardExchange. Face: the family's HermeticWETH (18 decimals; M14: LSTs run at 18 only). Partial case: deposit-pool capacity cap; booked reserve is reserveOfToken(weth).
contract UniswapV4StandardExchangeWeightedBufferHook_SeMatrix_RocketPoolRETHStandardExchange is UniswapV4StandardExchangeWeightedBufferHook_SeMatrixBehavior {
    /// @dev One package per family per test contract; every SE leg's fixture reuses it.
    address internal sharedPkg;

    function _newFixture() internal override returns (SeMatrixFixture) {
        SeMatrix_RocketFixture f = new SeMatrix_RocketFixture(_ctx(), sharedPkg);
        sharedPkg = f.pkg();
        return f;
    }
}
