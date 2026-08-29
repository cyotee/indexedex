// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {UniswapV4Detf_Alignment_FeeCreatorClaimBase} from
    "test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_Alignment_FeeCreatorClaimBase.sol";

/// @notice CP gold FC1–FC12 via Bond NFT claimRewards (WP-UDPL-CLAIM). FC4 later bond.
contract UniswapV4Detf_Alignment_FeeCreatorClaim is UniswapV4Detf_Alignment_FeeCreatorClaimBase {
    function test_FC1_univ4Detf_cp_feeToAndCreatorCanClaim() public { _assertFC1(); }
    function test_FC2_univ4Detf_cp_claimEqualsPendingAndBalance() public { _assertFC2(); }
    function test_FC3_univ4Detf_cp_dueAmountsFloor() public { _assertFC3(); }
    function test_FC4_univ4Detf_cp_newSharesDoNotClaimOldPot() public { _assertFC4(); }
    function test_FC5_univ4Detf_cp_newPotAtNewWeights() public { _assertFC5(); }
    function test_FC6_univ4Detf_cp_secondClaimZero() public { _assertFC6(); }
    function test_FC7_univ4Detf_cp_nonOwnerCannotClaim() public { _assertFC7(); }
    function test_FC8_univ4Detf_cp_ids1and2CannotSellOrClose() public { _assertFC8(); }
    function test_FC9_univ4Detf_cp_d2NoOriginalShares() public { _assertFC9(); }
    function test_FC10_univ4Detf_cp_feeToChangeDoesNotMoveId1() public { _assertFC10(); }
    function test_FC11_univ4Detf_cp_creatorZeroFeeToOwnsBoth() public { _assertFC11(); }
    function test_FC12_univ4Detf_cp_conservationTwoWaves() public { _assertFC12(); }
}
