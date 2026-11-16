// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {SeMatrixFixture} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrixFixture.sol";
import {SeMatrix_LidoFixture} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrix_LidoFixture.sol";
import {
    UniswapV4StandardExchangeOrbitalBufferHook_SeMatrixBehavior
} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHook_SeMatrixBehavior.sol";

/// @notice D20: orbital × LidoWstETHStandardExchange. Face: the family's HermeticWETH (18 decimals; M14: LSTs run at 18 only). Booked reserve is the WETH sleeve (WETH→SE never stakes in-tx).
contract UniswapV4StandardExchangeOrbitalBufferHook_SeMatrix_LidoWstETHStandardExchange is UniswapV4StandardExchangeOrbitalBufferHook_SeMatrixBehavior {
    /// @dev One package per family per test contract; every SE leg's fixture reuses it.
    address internal sharedPkg;

    function _newFixture() internal override returns (SeMatrixFixture) {
        SeMatrix_LidoFixture f = new SeMatrix_LidoFixture(_ctx(), sharedPkg);
        sharedPkg = f.pkg();
        return f;
    }
}
