// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/// @title IUniV4DetfBondNft
/// @notice Bond NFT package surface for Uni V4 Single SE DETF.
interface IUniV4DetfBondNft {
    /// @notice Open dual OOR bond. Only DETF owner. Returns tokenId.
    function openBond(
        address recipient,
        uint256 pairPrincipal,
        uint256 pairAmountForLp,
        uint256 detfAmountForLp,
        uint256 effectiveShares,
        uint256 unlockTime,
        int24 pairTickLower,
        int24 pairTickUpper,
        int24 detfTickLower,
        int24 detfTickUpper
    ) external returns (uint256 tokenId);

    /// @notice Claim free DETF rewards while bond is open.
    function claimRewards(uint256 tokenId, address recipient) external returns (uint256 rewards);

    /// @notice Maturity full close: withdraw both, return pair+DETF amounts to caller (DETF orchestrates burn/send).
    function closeBondMature(uint256 tokenId, address caller)
        external
        returns (uint256 pairOut, uint256 detfOut, uint256 rewards);

    /// @notice Sell: withdraw both, leave pair+DETF on this package for DETF to push to rebasing; credit id 0; retire NFT.
    function sellBond(uint256 tokenId, address caller)
        external
        returns (uint256 pairOut, uint256 detfOut, uint256 rewards, uint256 principalCredited);

    /// @notice Pending free DETF rewards for tokenId (0 = protocol).
    function pendingRewards(uint256 tokenId) external view returns (uint256);

    /// @notice Total ledger weight (user bonds + protocol id 0).
    function totalShares() external view returns (uint256);

    /// @notice Protocol id 0 principal (bond-sell credited only).
    function protocolPrincipal() external view returns (uint256);

    function ownerOf(uint256 tokenId) external view returns (address);
    function unlockTimeOf(uint256 tokenId) external view returns (uint256);
    function pairPrincipalOf(uint256 tokenId) external view returns (uint256);
    function effectiveSharesOf(uint256 tokenId) external view returns (uint256);
    function owner() external view returns (address);

    /// @notice Update global reward index from reward-token balance (free DETF held here).
    function updateGlobalRewards() external;
}
