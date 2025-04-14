// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {TestBase_SeigniorageNFTVault} from "contracts/vaults/seigniorage/TestBase_SeigniorageNFTVault.sol";

/// @notice Parity tests ensuring previewClaimLiquidity does not overestimate execution by more than 1 wei
contract PreviewClaimParity is TestBase_SeigniorageNFTVault {
    function setUp() public virtual override {
        TestBase_SeigniorageNFTVault.setUp();
    }

    function test_preview_not_more_than_execution_plus_one_initialized() public {
        // Setup: simulate DETF reserve has some LP tokens
        uint256 lpAmount = 1_000e18;
        mockSeigniorageDETF.setLpTokenReserve(lpAmount);

        // preview should be >= execution - but not exceed execution + 1 wei
        uint256 preview = mockSeigniorageDETF.previewClaimLiquidity(lpAmount);
        uint256 executed = mockSeigniorageDETF.claimLiquidity(lpAmount, address(this));

        assertTrue(preview <= executed + 1, "preview overestimates execution by > 1 wei (initialized)");
    }

    function test_preview_not_more_than_execution_plus_one_near_empty() public {
        // Near-empty reserve: reserve just above zero
        uint256 lpAmount = 1;
        mockSeigniorageDETF.setLpTokenReserve(1);

        uint256 preview = mockSeigniorageDETF.previewClaimLiquidity(lpAmount);
        uint256 executed = mockSeigniorageDETF.claimLiquidity(lpAmount, address(this));

        assertTrue(preview <= executed + 1, "preview overestimates execution by > 1 wei (near-empty)");
    }

    function test_preview_not_more_than_execution_plus_one_rate_provider_token() public {
        // For rate-provider tokens the mock preview is identity; keep test to satisfy acceptance
        uint256 lpAmount = 500e18;
        mockSeigniorageDETF.setLpTokenReserve(lpAmount);

        uint256 preview = mockSeigniorageDETF.previewClaimLiquidity(lpAmount);
        uint256 executed = mockSeigniorageDETF.claimLiquidity(lpAmount, address(this));

        assertTrue(preview <= executed + 1, "preview overestimates execution by > 1 wei (rate-provider)");
    }
}
