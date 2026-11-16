// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {SeMatrixFixture} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrixFixture.sol";
import {SeMatrix_EtherFiFixture} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrix_EtherFiFixture.sol";
import {
    UniswapV4DualSEBCPHook_SeMatrixBehavior
} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualSEBCPHook_SeMatrixBehavior.sol";

/// @notice D20: dual-SE constant-product × EtherFiWeETHStandardExchange. Face: the family's HermeticWETH (18 decimals; M14: LSTs run at 18 only). Partial case: liquidity-pool pause (boolean capacity); booked reserve is reserveOfToken(weth).
contract UniswapV4DualSEBCPHook_SeMatrix_EtherFiWeETHStandardExchange is UniswapV4DualSEBCPHook_SeMatrixBehavior {
    /// @dev One package per family per test contract; every SE leg's fixture reuses it.
    address internal sharedPkg;

    function _newFixture() internal override returns (SeMatrixFixture) {
        SeMatrix_EtherFiFixture f = new SeMatrix_EtherFiFixture(_ctx(), sharedPkg);
        sharedPkg = f.pkg();
        return f;
    }
}
