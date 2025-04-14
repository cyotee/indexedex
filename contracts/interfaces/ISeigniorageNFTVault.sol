// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20MintBurn} from "@crane/contracts/interfaces/IERC20MintBurn.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {ISeigniorageDETF} from "contracts/interfaces/ISeigniorageDETF.sol";

/**
 * @title ISeigniorageNFTVault
 * @author cyotee doge <not_cyotee@proton.me>
 * @notice Interface for Seigniorage NFT Vault that manages bonding positions.
 * @dev NFTs represent shares in the reserve pool's BPT holdings.
 *      The DETF owns this vault and calls lockFromDetf when users underwrite.
 *      Users can claim rewards (sRBT) and unlock positions after lock duration.
 */
interface ISeigniorageNFTVault {
    /* ---------------------------------------------------------------------- */
    /*                                Structs                                 */
    /* ---------------------------------------------------------------------- */

    struct LockInfo {
        /// @notice Original shares allocated to this position (BPT amount)
        uint256 sharesAwarded;
        /// @notice Current reward per share at time of query
        uint256 rewardPerShare;
        /// @notice Bonus percentage (effectiveShares / originalShares scaled by 1e18)
        uint256 bonusPercentage;
        /// @notice Timestamp when position can be unlocked
        uint256 unlockTime;
    }

    /* ---------------------------------------------------------------------- */
    /*                                 Errors                                 */
    /* ---------------------------------------------------------------------- */

    error LockDurationTooShort(uint256 provided, uint256 minimum);
    error LockDurationTooLong(uint256 provided, uint256 maximum);
    error LockDurationNotExpired(uint256 currentTime, uint256 unlockTime);
    error BaseSharesZero();
    error NotBondHolder(address holder, address caller);
    error PositionNotFound(uint256 tokenId);

    /* ---------------------------------------------------------------------- */
    /*                                 Events                                 */
    /* ---------------------------------------------------------------------- */

    event NewLock(
        uint256 indexed tokenId,
        address indexed owner,
        uint256 sharesAwarded,
        uint256 bonusPercentage,
        uint256 unlockTime
    );

    event Unlock(uint256 indexed tokenId, address indexed owner, uint256 liquidityReturned, uint256 rewards);

    event RewardsClaimed(uint256 indexed tokenId, address indexed owner, uint256 rewards);

    /* ---------------------------------------------------------------------- */
    /*                           Core Operations                              */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice Creates a new bonding position.
     * @dev Only callable by the owner (DETF). Mints an NFT to the recipient.
     * @param bptOut Amount of BPT (LP tokens) minted by the underwrite
     * @param bptReserveBefore DETF's BPT reserve before the mint (pre-underwrite)
     * @param lockDuration Duration to lock in seconds
     * @param recipient Address to receive the NFT
     * @return tokenId The minted NFT token ID
     */
    function lockFromDetf(uint256 bptOut, uint256 bptReserveBefore, uint256 lockDuration, address recipient)
        external
        returns (uint256 tokenId);

    /**
     * @notice Unlocks a position and claims underlying value.
     * @dev Burns the NFT and calls DETF.claimLiquidity to extract value.
     * @param tokenId The NFT token ID to unlock
     * @param recipient Address to receive the extracted value
     * @return lpAmount Amount of rate target tokens received
     */
    function unlock(uint256 tokenId, address recipient) external returns (uint256 lpAmount);

    /**
     * @notice Withdraws pending sRBT rewards without unlocking.
     * @param tokenId The NFT token ID
     * @param recipient Address to receive rewards
     * @return rewards Amount of sRBT rewards withdrawn
     */
    function withdrawRewards(uint256 tokenId, address recipient) external returns (uint256 rewards);

    /* ---------------------------------------------------------------------- */
    /*                           View Functions                               */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice Minimum lock duration.
     */
    function minimumLockDuration() external view returns (uint256);

    /**
     * @notice Maximum lock duration.
     */
    function maximumLockDuration() external view returns (uint256);

    /**
     * @notice Minimum bonus percentage (WAD, where 1e18 = 100%).
     * @dev Expressed as an additive bonus over 1x (e.g., 0 = no bonus).
     */
    function minBonusPercentage() external view returns (uint256);

    /**
     * @notice Maximum bonus percentage (WAD, where 1e18 = 100%).
     * @dev Expressed as an additive bonus over 1x (e.g., 3e18 = +300%).
     */
    function maxBonusPercentage() external view returns (uint256);

    /**
     * @notice Returns lock info for a position.
     * @param tokenId The NFT token ID
     * @return info The LockInfo struct
     */
    function lockInfoOf(uint256 tokenId) external view returns (LockInfo memory info);

    /**
     * @notice Returns pending rewards for a position.
     * @param tokenId The NFT token ID
     * @return pending Amount of pending sRBT rewards
     */
    function pendingRewards(uint256 tokenId) external view returns (uint256 pending);

    /**
     * @notice Returns total effective shares across all positions.
     * @return Total effective shares (used for reward distribution)
     */
    function totalShares() external view returns (uint256);

    /**
     * @notice Returns current accumulated reward per share.
     * @return Accumulated reward per share (scaled by 1e18)
     */
    function rewardPerShares() external view returns (uint256);

    /**
     * @notice Alias for reward-per-share accumulator.
     */
    function currentRewardPerShare() external view returns (uint256);

    /**
     * @notice Returns effective (boosted) reward shares for a position.
     */
    function rewardSharesOf(uint256 tokenId) external view returns (uint256);

    /**
     * @notice Returns the per-position reward-per-share checkpoint.
     */
    function rewardPerShareOf(uint256 tokenId) external view returns (uint256);

    /**
     * @notice Returns the unlock time for a position.
     */
    function unlockTimeOf(uint256 tokenId) external view returns (uint256);

    /**
     * @notice Returns the additive bonus percentage for a position.
     */
    function bonusPercentageOf(uint256 tokenId) external view returns (uint256);

    /**
     * @notice Returns the DETF token contract.
     * @return The DETF contract that owns this vault
     */
    function detfToken() external view returns (ISeigniorageDETF);

    /**
     * @notice Returns the LP token (BPT) contract.
     * @return The LP token contract
     */
    function lpToken() external view returns (IERC20);

    /**
     * @notice Returns the reward token (sRBT) contract.
     * @return The reward token contract
     */
    function rewardToken() external view returns (IERC20MintBurn);

    /**
     * @notice Returns the claim token (rate target) contract.
     * @return The claim token contract
     */
    function claimToken() external view returns (IERC20);

    /**
     * @notice Returns the token URI for an NFT.
     * @param tokenId The NFT token ID
     * @return The token URI (base64 encoded JSON with SVG)
     */
    function tokenURI(uint256 tokenId) external view returns (string memory);
}
