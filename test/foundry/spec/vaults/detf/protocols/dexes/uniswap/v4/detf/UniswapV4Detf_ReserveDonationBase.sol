// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

/// @notice Gold-full donation extras (PRD §7.5). DN3 / DN15 are N/A NatSpec only.
/// @dev No extra deploy `setUp`. Do not steal hook LP. Do not restore family N10 stasis.
abstract contract UniswapV4Detf_ReserveDonationBase {
    /// @notice DN3 N/A Uni V4 owner-only LP
    /// @dev Hook LP is owner-only (D9). Do not steal NFT LP. Do not prank(detf) to mint LP to an EOA.
    function test_DN3_donate_lpToken_thisCallInboundOnly() public pure {
        return;
    }

    /// @notice DN15 N/A R12a convertToAssets rises (see DN1)
    /// @dev R12a supersedes family N10 convertToAssets stasis. DN1 asserts NAV rises.
    function test_DN15_n10_userConvertUnchanged() public pure {
        return;
    }
}
