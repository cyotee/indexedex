// SPDX-License-Identifier: BSL-1.1
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

    /// @notice Debit principal shares 1:1 (original and effective) from the protocol-owned NFT.
    /// @dev onlyOwner. Only `tokenId == detfNFTId`. Inverse of `addToDETFNFT` / `_addToPosition`.
    ///      Preserves pending reward debt. Reverts if `shares` exceeds `originalShares`.
    function removeFromDETFNFT(uint256 tokenId, uint256 shares) external;

    /// @notice Unlock timestamp for a bond tokenId (0 / past = mature).
    function unlockTimeOf(uint256 tokenId) external view returns (uint256 unlockTime);

    /// @notice Principal (BPT) shares for a bond tokenId.
    function originalSharesOf(uint256 tokenId) external view returns (uint256 shares);

    /// @notice Reward-ledger (effective) shares for a bond tokenId.
    function effectiveSharesOf(uint256 tokenId) external view returns (uint256 shares);

    /// @notice Sum of effectiveShares across all tokenIds (user + protocol + standing reward).
    function totalShares() external view returns (uint256 shares);

    /// @notice Sum of originalShares across all tokenIds (user + protocol).
    function totalOriginalShares() external view returns (uint256 shares);

    /// @notice D7 reserved ids 0/1/2. User `createPosition` starts at 3 after this returns.
    /// @dev `creator == 0` mints id 2 to `feeTo` (D21). Id 0 is a valid protocol id (L6).
    function initializeReservedBondNfts(address feeTo, address creator) external returns (uint256 protocolId);

    /// @notice L6 wired sentinel. Not `detfNftId == 0`.
    function reservedBondNftsWired() external view returns (bool);

    /// @notice L7: add effective-share weight only on ids 1 or 2. Does not change `originalShares`.
    function addEffectiveSharesOnly(uint256 tokenId, uint256 shares) external;

    /// @notice Harvest free DETF rewards accrued to the detf-owned NFT to `recipient`.
    /// @dev Free-DETF harvest — not BPT compound. Compound remains DETF-orchestrated.
    function reallocateDetfNftRewards(address recipient) external returns (uint256 amount);
}