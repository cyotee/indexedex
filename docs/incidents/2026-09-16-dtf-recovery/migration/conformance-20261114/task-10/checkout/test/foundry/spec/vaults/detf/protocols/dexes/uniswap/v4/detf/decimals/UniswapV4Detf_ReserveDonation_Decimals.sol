// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {DetfResidualAssertions} from "contracts/test/libs/DetfResidualAssertions.sol";
import {TestBase_UniswapV4Detf_Decimals} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Decimals.sol";
import {UniswapV4Detf_ReserveDonationBase_Decimals} from
    "test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/decimals/UniswapV4Detf_ReserveDonationBase_Decimals.sol";
import {UniswapV4Detf_ReserveDonationOpenBase_Decimals} from
    "test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/decimals/UniswapV4Detf_ReserveDonationOpenBase_Decimals.sol";

/// @notice CP gold donation R12a on SUT UniswapV4DetfDFPkg / IUniswapV4Detf.
/// @dev T7.13 in UniswapV4Detf_Donate.t.sol remains the pathfinder; DN1 is the product-law suite.
///      TestBase_UniswapV4Detf_Decimals arrives via OpenBase (C3-safe).
///      Pair/share leftovers must be exactly booked and non-joinable, individually and collectively.
abstract contract UniswapV4Detf_ReserveDonation_Decimals is
    UniswapV4Detf_ReserveDonationOpenBase_Decimals,
    UniswapV4Detf_ReserveDonationBase_Decimals
{
    function _assertNoJoinableDust() internal view virtual override {
        DetfResidualAssertions.assertNoJoinableDust(detf, detfInfo.hook());
    }
}
