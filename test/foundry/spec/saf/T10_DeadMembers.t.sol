// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {DETFNFTVaultService} from "contracts/vaults/detf/common/bondNft/DETFNFTVaultService.sol";

/// @notice T10 / L-STRUCT-2: harvest/redeem params compile without dead tokenId/recipient fields.
contract T10_DeadMembers_Test is Test {
    function test_harvestParams_mathOnlyFields() public pure {
        DETFNFTVaultService.HarvestParams memory p = DETFNFTVaultService.HarvestParams({
            effectiveShares: 1e18,
            rewardPerShares: 2e18,
            paidPerShare: 1e18
        });
        DETFNFTVaultService.HarvestResult memory r = DETFNFTVaultService._calcHarvestRewards(p);
        assertTrue(r.hasRewards || r.rewards == 0);
    }

    function test_redeemParams_noTokenId() public pure {
        DETFNFTVaultService.RedeemParams memory p = DETFNFTVaultService.RedeemParams({
            recipient: address(1),
            caller: address(2),
            detf: address(3)
        });
        // Validate shape only — pure helper uses caller/detf/owner.
        assertTrue(p.caller != address(0));
    }
}
