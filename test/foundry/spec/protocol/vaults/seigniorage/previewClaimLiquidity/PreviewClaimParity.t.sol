// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IBasicVault} from "contracts/vaults/basic/IBasicVault.sol";
import {ISeigniorageNFTVault} from "contracts/interfaces/ISeigniorageNFTVault.sol";
import {
    SeigniorageDETFIntegration_Test
} from "test/foundry/spec/protocol/vaults/seigniorage/SeigniorageDETFIntegration.t.sol";

/// @notice Parity tests ensuring previewClaimLiquidity does not overestimate execution by more than 1 wei
contract PreviewClaimParity is SeigniorageDETFIntegration_Test {
    function _seedDetfReserve(uint256 amountIn) internal returns (uint256 lpReserve) {
        _mintVaultShares(owner, 1e18);

        uint256 reserveAssetIn = _mintReserveAssetTo(alice, amountIn);

        vm.startPrank(alice);
        _vaultAsset().approve(address(detf), reserveAssetIn);
        detf.underwrite(_vaultAsset(), reserveAssetIn, LOCK_DURATION, alice, false);
        vm.stopPrank();

        lpReserve = IBasicVault(address(detf)).reserveOfToken(detf.reservePool());
        assertGt(lpReserve, 0, "expected reserve pool LP after underwriting");
    }

    function _claimAsNftVault(uint256 lpAmount) internal returns (uint256 executed) {
        vm.prank(address(detf.seigniorageNFTVault()));
        executed = detf.claimLiquidity(lpAmount, address(this));
    }

    function test_preview_not_more_than_execution_plus_one_initialized() public {
        uint256 lpAmount = _seedDetfReserve(UNDERWRITE_AMOUNT) / 2;

        uint256 preview = detf.previewClaimLiquidity(lpAmount);
        uint256 executed = _claimAsNftVault(lpAmount);

        assertTrue(preview <= executed + 1, "preview overestimates execution by > 1 wei (initialized)");
    }

    function test_preview_not_more_than_execution_plus_one_near_empty() public {
        uint256 lpReserve = _seedDetfReserve(UNDERWRITE_AMOUNT);
        uint256 lpAmount = lpReserve / 1_000_000;
        assertGt(lpAmount, 0, "expected non-zero dust lp amount");

        uint256 preview = detf.previewClaimLiquidity(lpAmount);
        uint256 executed = _claimAsNftVault(lpAmount);

        assertTrue(preview <= executed + 1, "preview overestimates execution by > 1 wei (near-empty)");
    }

    function test_preview_not_more_than_execution_plus_one_rate_provider_token() public {
        uint256 lpAmount = _seedDetfReserve(UNDERWRITE_AMOUNT / 2) / 2;

        uint256 preview = detf.previewClaimLiquidity(lpAmount);
        uint256 executed = _claimAsNftVault(lpAmount);

        assertTrue(preview <= executed + 1, "preview overestimates execution by > 1 wei (rate-provider)");
    }
}
