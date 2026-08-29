// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {UniswapV4Detf_Alignment_CloseD25Base} from
    "test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_Alignment_CloseD25Base.sol";

/// @notice Stage 11 Open D25 IDs (PRD §7.0 / §7.4). Gold CP inherits this.
/// @dev TestBase_UniswapV4Detf arrives via CloseD25Base (C3-safe). No empty `test_*` stubs.
abstract contract UniswapV4Detf_Alignment_CloseD25OpenBase is UniswapV4Detf_Alignment_CloseD25Base {
    /// @notice Close pays user DETF only via NFT `claimRewards` on that id, not withdrawn self-leg.
    function test_D25_1_userDetfOnlyFromClaimRewards() public {
        _assert_D25_1_userDetfOnlyFromClaimRewards();
    }

    /// @notice Withdrawn DETF is rejoined; that DETF supply is not burned for the self-leg.
    function test_D25_2_withdrawnDetfNotBurned() public {
        _assert_D25_2_withdrawnDetfNotBurned();
    }

    /// @notice Id 0 originalShares increase when withdrawn DETF rejoins.
    function test_D25_3_id0OriginalSharesRise() public {
        _assert_D25_3_id0OriginalSharesRise();
    }

    /// @notice Default close can pay every non-DETF `hook.tokens()` slot; DETF slot 0 unpaid.
    function test_D25_4_userReceivesNonDetfBasket() public {
        _assert_D25_4_userReceivesNonDetfBasket();
    }

    /// @notice Ids 1 and 2 cannot close.
    function test_D25_5_ids1and2CannotClose() public {
        _assert_D25_5_ids1and2CannotClose();
    }

    /// @notice `previewCloseBondMature` matches execute.
    function test_D25_6_previewEqualsExecute() public {
        _assert_D25_6_previewEqualsExecute();
    }

    /// @notice DETF rejoin at MIN liquidity still has lpOut>0 (id 0 originalShares rise) or reverts D30.
    function test_D25_7_minRejoinLpOutGt0() public {
        _assert_D25_7_minRejoinLpOutGt0();
    }

    /// @notice Last user close does not jump fee/creator (ids 1–2) pending.
    function test_D25_lastClose_feeCreatorPendingDoesNotJump() public {
        _assert_D25_lastClose_feeCreatorPendingDoesNotJump();
    }
}
