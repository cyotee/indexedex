// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {UniswapV4Detf_OpeningPriceBase} from
    "test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_OpeningPriceBase.sol";

/**
 * @title UniswapV4Detf_OpeningPriceLayerBase
 * @notice T1/T2/T5 only (gold + Stage 11 Policy). T6 is Weighted/Quad later WPs.
 */
abstract contract UniswapV4Detf_OpeningPriceLayerBase is UniswapV4Detf_OpeningPriceBase {
    function test_T1_openingZero_storesAsCreation_firstBondGAtPeg() public {
        _assert_T1_openingZero_storesAsCreation_firstBondGAtPeg(detf);
    }

    function test_T2_openingUsesG_creationViewUnchanged() public {
        address d = _openingT2Detf();
        _assert_T2_openingUsesG_creationViewUnchanged(d);
    }

    function test_T5_creationZero_revertsInvalidCreationRate() public {
        _assert_T5_creationZero_revertsInvalidCreationRate();
    }
}
