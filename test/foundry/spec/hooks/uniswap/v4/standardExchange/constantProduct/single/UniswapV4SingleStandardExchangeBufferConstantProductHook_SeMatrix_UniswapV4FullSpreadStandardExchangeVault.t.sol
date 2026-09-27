// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {SeMatrixFixture} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrixFixture.sol";
import {SeMatrix_FullSpreadV4Fixture} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrix_FullSpreadV4Fixture.sol";
import {UniswapV4SingleStandardExchangeBufferConstantProductHook_SeMatrixBehavior} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_SeMatrixBehavior.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";

/// @notice D20: constantProduct/single x UniswapV4FullSpreadStandardExchangeVault (COMPATIBLE). Face: 18-decimal pool currency0 (`SimpleMintableERC20`, ERC-20 variant) of a hermetic Uniswap V4 3000-fee pool on
///         the SE's own PoolManager, seeded by an independent LP; SE deployed through the production FullSpread V4
///         package (shared per test contract). Native-ETH variant out of scope.
contract UniswapV4SingleStandardExchangeBufferConstantProductHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault is UniswapV4SingleStandardExchangeBufferConstantProductHook_SeMatrixBehavior {
    /// @dev Package deployed once per test contract; later fixtures (one per SE leg) reuse it.
    address internal sharedPkg;

    function _newFixture() internal override returns (SeMatrixFixture) {
        SeMatrix_FullSpreadV4Fixture f = new SeMatrix_FullSpreadV4Fixture(_ctx(), sharedPkg);
        sharedPkg = f.pkg();
        return f;
    }

    /// @dev F6 fixed 2026-09-21 (D55): FullSpread exact-out spends the previewed shares and delivers exactly the
    ///      request, so the gold body and default residual tolerance apply. Red record: run 6 tolerances.
}
