// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {TestBase_UniswapV4Detf} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf.sol";
import {UniswapV4Detf_OwnerOnlyLiquidityBase} from
    "test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_OwnerOnlyLiquidityBase.sol";
import {UniswapV4Detf_OwnerOnlyLiquidityOpenBase} from
    "test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_OwnerOnlyLiquidityOpenBase.sol";

/// @notice CP gold owner-only liquidity concrete (PRD §7.7).
contract UniswapV4Detf_OwnerOnlyLiquidity is
    TestBase_UniswapV4Detf,
    UniswapV4Detf_OwnerOnlyLiquidityBase,
    UniswapV4Detf_OwnerOnlyLiquidityOpenBase
{
    function test_reserveHook_ownerIsDetf()
        public
        view
        override(UniswapV4Detf_OwnerOnlyLiquidityBase, UniswapV4Detf_OwnerOnlyLiquidityOpenBase)
    {
        UniswapV4Detf_OwnerOnlyLiquidityOpenBase.test_reserveHook_ownerIsDetf();
    }

    function test_reserveHook_thirdPartyAddReverts()
        public
        override(UniswapV4Detf_OwnerOnlyLiquidityBase, UniswapV4Detf_OwnerOnlyLiquidityOpenBase)
    {
        UniswapV4Detf_OwnerOnlyLiquidityOpenBase.test_reserveHook_thirdPartyAddReverts();
    }
}
