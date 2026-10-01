// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {SeMatrixFixture} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrixFixture.sol";
import {SeMatrix_EtherFiFixture} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrix_EtherFiFixture.sol";
import {
    UniswapV4StandardExchangeOrbitalBufferHook_SeMatrixBehavior
} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHook_SeMatrixBehavior.sol";

/// @notice D20: orbital × EtherFiWeETHStandardExchange. Face: the family's HermeticWETH (18 decimals; M14: LSTs run at 18 only). Partial case: liquidity-pool pause (boolean capacity); booked reserve is reserveOfToken(weth).
contract UniswapV4StandardExchangeOrbitalBufferHook_SeMatrix_EtherFiWeETHStandardExchange is UniswapV4StandardExchangeOrbitalBufferHook_SeMatrixBehavior {
    /// @dev One package per family per test contract; every SE leg's fixture reuses it.
    address internal sharedPkg;

    function _newFixture() internal override returns (SeMatrixFixture) {
        SeMatrix_EtherFiFixture f = new SeMatrix_EtherFiFixture(_ctx(), sharedPkg);
        sharedPkg = f.pkg();
        return f;
    }

    /// @dev F4 resolved 2026-09-21: the hermetic stubs now expose the protocol views `quoteState` reads, so the
    ///      gold `test_row_previewMatchesExecution` runs. Red record: run 5 asserted `InvalidQuoteState()` here.
}
