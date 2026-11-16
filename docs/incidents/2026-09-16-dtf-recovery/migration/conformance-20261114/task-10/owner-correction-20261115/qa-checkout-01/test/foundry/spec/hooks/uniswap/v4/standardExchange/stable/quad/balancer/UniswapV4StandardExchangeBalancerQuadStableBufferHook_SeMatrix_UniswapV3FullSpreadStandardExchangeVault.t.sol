// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {SeMatrixFixture} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrixFixture.sol";
import {SeMatrix_FullSpreadV3Fixture} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrix_FullSpreadV3Fixture.sol";
import {
    UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrixBehavior
} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrixBehavior.sol";

/// @notice D20: balancer-quad × UniswapV3FullSpreadStandardExchangeVault (COMPATIBLE). This hook family mints SE shares through the
///         SE's exact-out mint route (`previewExchangeOut(face, se, sharesOut)` /
///         `exchangeOut(face, max, se, sharesOut)`). The FullSpread SE gained that route under
///         APEX D64 (owner ruling 2026-09-23, closed-form single-token deposit inverse
///         `StandardExchangeConstantProduct._amountInForShares`), so the gold row body now runs.
///         Red record: before D64 the SE reverted `IStandardExchangeOut.ExchangeOutNotAvailable()`
///         on a share output (the prior `test_INCOMPATIBLE_FullSpread_noExactOutMintRoute`).
contract UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrix_UniswapV3FullSpreadStandardExchangeVault is UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrixBehavior {
    /// @dev Package deployed once per test contract; later fixtures (one per SE leg) reuse it.
    address internal sharedPkg;

    function _newFixture() internal override returns (SeMatrixFixture) {
        SeMatrix_FullSpreadV3Fixture f = new SeMatrix_FullSpreadV3Fixture(_ctx(), sharedPkg);
        sharedPkg = f.pkg();
        return f;
    }
}
