// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {TestBase_UniswapV4Detf_Decimals} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Decimals.sol";
import {UniswapV4Detf_OwnerOnlyLiquidityBase_Decimals} from
    "test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/decimals/UniswapV4Detf_OwnerOnlyLiquidityBase_Decimals.sol";
import {UniswapV4Detf_OwnerOnlyLiquidityOpenBase_Decimals} from
    "test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/decimals/UniswapV4Detf_OwnerOnlyLiquidityOpenBase_Decimals.sol";

/// @notice CP gold owner-only liquidity concrete (PRD §7.7).
abstract contract UniswapV4Detf_OwnerOnlyLiquidity_Decimals is
    TestBase_UniswapV4Detf_Decimals,
    UniswapV4Detf_OwnerOnlyLiquidityBase_Decimals,
    UniswapV4Detf_OwnerOnlyLiquidityOpenBase_Decimals
{
    function test_reserveHook_ownerIsDetf()
        public
        view
        override(UniswapV4Detf_OwnerOnlyLiquidityBase_Decimals, UniswapV4Detf_OwnerOnlyLiquidityOpenBase_Decimals)
    {
        UniswapV4Detf_OwnerOnlyLiquidityOpenBase_Decimals.test_reserveHook_ownerIsDetf();
    }

    function test_reserveHook_thirdPartyAddReverts()
        public
        override(UniswapV4Detf_OwnerOnlyLiquidityBase_Decimals, UniswapV4Detf_OwnerOnlyLiquidityOpenBase_Decimals)
    {
        UniswapV4Detf_OwnerOnlyLiquidityOpenBase_Decimals.test_reserveHook_thirdPartyAddReverts();
    }
}
