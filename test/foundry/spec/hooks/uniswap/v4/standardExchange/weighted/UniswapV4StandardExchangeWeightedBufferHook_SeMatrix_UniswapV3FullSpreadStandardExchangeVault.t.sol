// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {SeMatrixFixture} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrixFixture.sol";
import {SeMatrix_FullSpreadV3Fixture} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrix_FullSpreadV3Fixture.sol";
import {UniswapV4StandardExchangeWeightedBufferHook_SeMatrixBehavior} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_SeMatrixBehavior.sol";

/// @notice D20: weighted x UniswapV3FullSpreadStandardExchangeVault (COMPATIBLE). Face: 18-decimal pool token0 (`SimpleMintableERC20`) of a hermetic Uniswap V3 3000-fee pool seeded by an
///         independent LP; SE deployed through the production FullSpread V3 package (shared per test contract).
contract UniswapV4StandardExchangeWeightedBufferHook_SeMatrix_UniswapV3FullSpreadStandardExchangeVault is UniswapV4StandardExchangeWeightedBufferHook_SeMatrixBehavior {
    /// @dev Package deployed once per test contract; later fixtures (one per SE leg) reuse it.
    address internal sharedPkg;

    function _newFixture() internal override returns (SeMatrixFixture) {
        SeMatrix_FullSpreadV3Fixture f = new SeMatrix_FullSpreadV3Fixture(_ctx(), sharedPkg);
        sharedPkg = f.pkg();
        return f;
    }
}
