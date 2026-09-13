// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {UniswapV4Detf_Alignment_CloseD25Base} from
    "test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_Alignment_CloseD25Base.sol";

/// @notice D32 funded replacements for D25; shared by actual provider fixtures.
/// @dev TestBase_UniswapV4Detf arrives via CloseD25Base (C3-safe). No empty `test_*` stubs.
abstract contract UniswapV4Detf_Alignment_CloseD25OpenBase is UniswapV4Detf_Alignment_CloseD25Base {

    function test_D25_fundedPrincipalAndRewardsPayOnlyStaking() public {
        (, uint256 id_) = _liveAliceBob();
        _assertD25FundedPayout(detfInfo, id_, d25Bob);
    }

    function test_D25_standingReceiptsAlreadyFundedBeforeClaim() public {
        (, uint256 id_) = _liveAliceBob();
        _assertD25StandingReceipts(detfInfo, id_, d25Bob);
    }

    function test_D25_reservedRolesCannotClaimPurchasedPrincipal() public {
        _liveAliceOnly();
        _assertD25ReservedPositions(detfInfo, d25Alice);
    }

    function test_D25_finalClaimRetainsProtocolLiquidity() public {
        uint256 id_ = _liveAliceOnly();
        _assertD25FinalClaim(detfInfo, id_, d25Alice);
    }
}
