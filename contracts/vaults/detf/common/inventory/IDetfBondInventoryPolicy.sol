// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/// @notice Bond NFT vault inventory surface used by true DETFs.
/// @dev `reallocateDetfNftRewards` is **free-DETF harvest** only. Protocol seigniorage
///      **compound** (reward DETF → single-sided reserve join → BPT credited to detf-owned
///      NFT) is **DETF-orchestrated** via family `_tryCompoundProtocolRewards` using
///      `DETFProtocolCompoundLib` dust gates — not performed inside this harvest path.
interface IDetfBondInventoryPolicy {
    function detfNFTId() external view returns (uint256 tokenId);

    function createPosition(uint256 shares, uint256 lockDuration, address recipient)
        external
        returns (uint256 tokenId);

    /// @notice Open bond with separate principal (LP) and reward-weight base (before lock bonus).
    /// @dev originalShares = fungible LP principal; effectiveBase * lockBonus = reward ledger weight.
    ///      Orbital DETF uses rateAsset open-time mids as effectiveBase; CP may keep createPosition(lp).
    function createPositionWithEffectiveBase(
        uint256 originalShares,
        uint256 effectiveBase,
        uint256 lockDuration,
        address recipient
    ) external returns (uint256 tokenId);

    function sellPositionToDetfNft(uint256 tokenId, address seller, address rewardsRecipient)
        external
        returns (uint256 principalShares, uint256 rewardsClaimed);

    /// @notice Credit principal shares (typically reserve BPT) onto an existing bond NFT.
    /// @dev Used after a successful protocol compound join to add BPT to the detf-owned NFT.
    function addToDETFNFT(uint256 tokenId, uint256 shares) external;

    /// @notice Harvest free DETF rewards accrued to the detf-owned NFT to `recipient`.
    /// @dev Free-DETF harvest — not BPT compound. Compound remains DETF-orchestrated.
    function reallocateDetfNftRewards(address recipient) external returns (uint256 amount);
}