// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {SeMatrixFixture} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrixFixture.sol";
import {SeMatrix_FullSpreadV3Fixture} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrix_FullSpreadV3Fixture.sol";
import {UniswapV4DualSEBCPHook_SeMatrixBehavior} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualSEBCPHook_SeMatrixBehavior.sol";

/// @notice D20: dual x UniswapV3FullSpreadStandardExchangeVault (COMPATIBLE). Face: 18-decimal pool token0 (`SimpleMintableERC20`) of a hermetic Uniswap V3 3000-fee pool seeded by an
///         independent LP; SE deployed through the production FullSpread V3 package (shared per test contract).
contract UniswapV4DualSEBCPHook_SeMatrix_UniswapV3FullSpreadStandardExchangeVault is UniswapV4DualSEBCPHook_SeMatrixBehavior {
    /// @dev Package deployed once per test contract; later fixtures (one per SE leg) reuse it.
    address internal sharedPkg;

    function _newFixture() internal override returns (SeMatrixFixture) {
        SeMatrix_FullSpreadV3Fixture f = new SeMatrix_FullSpreadV3Fixture(_ctx(), sharedPkg);
        sharedPkg = f.pkg();
        return f;
    }

    /// @dev F6 fixed 2026-09-21 (D55): FullSpread exact-out spends the previewed shares and delivers exactly the
    ///      request, so the gold body and default residual tolerance apply. Red record: run 6 tolerances.
}
