// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {UniswapV4Detf_PolicyLayerBase_Decimals} from
    "test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/decimals/UniswapV4Detf_PolicyLayerBase_Decimals.sol";
import {UniswapV4Detf_OpeningPriceLayerBase_Decimals} from
    "test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/decimals/UniswapV4Detf_OpeningPriceLayerBase_Decimals.sol";
import {UniswapV4Detf_Alignment_RedeemD15PolicyBase_Decimals} from
    "test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/decimals/UniswapV4Detf_Alignment_RedeemD15PolicyBase_Decimals.sol";
import {UniswapV4Detf_Alignment_FeeCreatorClaimBase_Decimals} from
    "test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/decimals/UniswapV4Detf_Alignment_FeeCreatorClaimBase_Decimals.sol";
import {TestBase_UniswapV4Detf_Policy_Decimals} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Policy_Decimals.sol";

/// @notice Decimal Stage 11 Policy layer. Fixture TestBase supplies setUp.
abstract contract UniswapV4Detf_Stage11PolicySuite_Decimals is
    UniswapV4Detf_PolicyLayerBase_Decimals,
    UniswapV4Detf_OpeningPriceLayerBase_Decimals,
    UniswapV4Detf_Alignment_RedeemD15PolicyBase_Decimals,
    UniswapV4Detf_Alignment_FeeCreatorClaimBase_Decimals
{
    function setUp() public virtual override {
        TestBase_UniswapV4Detf_Policy_Decimals.setUp();
    }
}
