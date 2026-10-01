// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {SeMatrixFixture} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrixFixture.sol";
import {SeMatrix_CbmvFixture} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrix_CbmvFixture.sol";
import {
    UniswapV4SingleStandardExchangeBufferConstantProductHook_SeMatrixBehavior
} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_SeMatrixBehavior.sol";

/// @notice D20: constantProduct/single x CommonBufferMultiVaultWeightedPool (M13 executed row). SE: the Balancer V3 common-buffer multi-vault weighted pool
///         diamond; its own BPT is the SE share (D38). Face token: the leg-0 Aerodrome SE share
///         (18 decimals), the only physical pool token the pool's native BPT route accepts as
///         `tokenIn` (the buffer token is virtual on that route, `getTokensIn()` excludes it). The
///         pool is deployed through its package and seeded with `router.initialize` inside the
///         fixture before the hook is deployed (M10 / section 11).
contract UniswapV4SingleStandardExchangeBufferConstantProductHook_SeMatrix_CommonBufferMultiVaultWeightedPool is
    UniswapV4SingleStandardExchangeBufferConstantProductHook_SeMatrixBehavior
{
    function _newFixture() internal override returns (SeMatrixFixture) {
        return new SeMatrix_CbmvFixture(_ctx(), address(0));
    }

    /// @dev F7 (2026-09-21) closed by D60 (2026-09-22): previews reverted `InvariantRatioBelowMin` because the
    ///      hook valued the SE leg with a full-supply single-token exit quote of the Balancer pool. The reserve
    ///      is now SE shares x the `StandardExchangeRateProvider` rate; the preview and PoolManager swap rows
    ///      run the behavior's controls unchanged.
}
