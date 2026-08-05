// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC721} from "@crane/contracts/interfaces/IERC721.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IDetf} from "contracts/interfaces/detf/IDetf.sol";
import {IDetfSelfNftInventoryPolicy} from "contracts/vaults/detf/common/inventory/IDetfSelfNftInventoryPolicy.sol";

/**
 * @title IDETFNFTVault
 * @author cyotee doge <not_cyotee@proton.me>
 * @notice Interface for Protocol NFT Vault managing bond positions.
 * @dev Each NFT represents a bonded position with:
 *      - Original shares (base LP allocation)
 *      - Effective shares (boosted by lock duration)
 *      - Unlock time (when position can be redeemed)
 *      - CHIR rewards (accumulated from protocol seigniorage and vault-held CHIR rewards)
 *
 *      The protocol-owned NFT has no unlock time and accumulates LP
 *      from sold user NFTs.
 */
interface IDETFNFTVault is IERC721, IDetfSelfNftInventoryPolicy {
    /* ---------------------------------------------------------------------- */
    /*                              Structs                                   */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice Bond position data.
     */
    struct Position {
        uint256 originalShares; // Base LP allocation
        uint256 effectiveShares; // Boosted shares for reward calculation
        uint256 bonusMultiplier; // Lock duration bonus (1e18 = 1x)
        uint256 unlockTime; // Timestamp when position unlocks
        uint256 rewardDebt; // Reward debt for calculating pending rewards
    }

    /* ---------------------------------------------------------------------- */
    /*                              View Functions                            */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice Returns the DETF diamond.
     * @return The DETF diamond
     */
    function detf() external view returns (IDetf);

    /**
     * @notice Returns the LP token (BPT from reserve pool).
     * @return The LP token
     */
    function lpToken() external view returns (IERC20);

    /**
    * @notice Returns the reward token.
    * @return The reward token for this vault's accrual model. For historical Protocol DETF deployments this was CHIR.
     */
    function rewardToken() external view returns (IERC20);

    /**
     * @notice Returns the total effective shares across all positions.
     * @return Total effective shares
     */
    function totalShares() external view returns (uint256);

    /**
     * @notice Returns the protocol-owned NFT token ID.
     * @return The protocol NFT token ID
     */
    function detfNFTId() external view returns (uint256);

    /**
     * @notice Returns the position data for a token ID.
     * @param tokenId The NFT token ID
     * @return position The position data
     */
    function positionOf(uint256 tokenId) external view returns (Position memory position);

    /**
     * @notice Returns the position data for a token ID (alias for positionOf).
     * @param tokenId The NFT token ID
     * @return position The position data
     */
    function getPosition(uint256 tokenId) external view returns (Position memory position);

    /**
     * @notice Returns the original shares for a token ID.
     * @param tokenId The NFT token ID
     * @return shares Original shares
     */
    function originalSharesOf(uint256 tokenId) external view returns (uint256 shares);

    /**
     * @notice Returns the effective shares for a token ID.
     * @param tokenId The NFT token ID
     * @return shares Effective shares
     */
    function effectiveSharesOf(uint256 tokenId) external view returns (uint256 shares);

    /**
     * @notice Returns the unlock time for a token ID.
     * @param tokenId The NFT token ID
     * @return unlockTime Unlock timestamp
     */
    function unlockTimeOf(uint256 tokenId) external view returns (uint256 unlockTime);

    /**
     * @notice Checks if a position is unlocked.
     * @param tokenId The NFT token ID
     * @return unlocked True if position can be redeemed
     */
    function isUnlocked(uint256 tokenId) external view returns (bool unlocked);

    /**
    * @notice Returns pending reward-token rewards for a token ID.
     * @param tokenId The NFT token ID
    * @return pending Amount of pending reward-token rewards. For historical Protocol DETF deployments this was CHIR.
     */
    function pendingRewards(uint256 tokenId) external view returns (uint256 pending);

    /**
     * @notice Converts LP amount to shares.
     * @param lpAmount Amount of LP tokens
     * @return shares Equivalent shares
     */
    function convertToShares(uint256 lpAmount) external view returns (uint256 shares);

    /**
     * @notice Converts shares to LP amount.
     * @param shares Amount of shares
     * @return lpAmount Equivalent LP tokens
     */
    function convertToAssets(uint256 shares) external view returns (uint256 lpAmount);

    /**
     * @notice Owner (DETF) transfers a foreign ERC-20 held by this vault (e.g. reserve LP).
     * @dev Used for physical LP custody: bond NFT holds user reserve LP; DETF may pull on
     *      maturity close / sell-to-protocol migration.
     */
    function transferHeldToken(IERC20 token, address to, uint256 amount) external;

    /* ---------------------------------------------------------------------- */
    /*                          Position Management                           */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice Creates a new bond position.
     * @dev Called by the DETF diamond during bonding.
     * @param lpAmount Amount of LP tokens to bond
     * @param lockDuration Duration to lock in seconds
     * @param recipient Address to receive the NFT
     * @return tokenId The minted NFT token ID
     */
    function createPosition(uint256 lpAmount, uint256 lockDuration, address recipient)
        external
        returns (uint256 tokenId);

    /// @notice Mints and records the protocol-owned NFT (once).
    /// @dev Expected to be called during package post-deploy/initialization.
    function initializeDETFNFT() external returns (uint256 tokenId);

    /**
     * @notice Redeems a position after unlock.
     * @param tokenId The NFT token ID
     * @param recipient Address to receive the extracted value and rewards
     * @param deadline Route deadline (reverts if exceeded)
     * @return wethOut Amount of WETH extracted and sent to `recipient`
     */
    function redeemPosition(uint256 tokenId, address recipient, uint256 deadline) external returns (uint256 wethOut);

    /**
    * @notice Claims reward-token rewards without redeeming position.
     * @param tokenId The NFT token ID
     * @param recipient Address to receive rewards
    * @return rewards Amount of reward-token rewards claimed. For historical Protocol DETF deployments this was CHIR.
     */
    function claimRewards(uint256 tokenId, address recipient) external returns (uint256 rewards);

    /* ---------------------------------------------------------------------- */
    /*                         Bond NFT → rebasing claim sale                         */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice Sells a user bond NFT position into the protocol-owned position.
     * @dev Intended to be called by the DETF diamond (owner) when a user invokes
     *      the canonical Bond NFT → rebasing claim token route.
     *
     *      Semantics (per TASK.md):
    *      - Harvest pending reward-token rewards and send them to `rewardsRecipient`.
     *      - Transfer principal-only shares (`originalShares`) into the protocol NFT.
     *      - Burn the sold bond NFT.
     *
     * @param tokenId The user bond NFT tokenId to sell.
     * @param seller The expected owner of `tokenId`.
     * @param rewardsRecipient Address to receive harvested rewards.
     * @return principalShares Principal-only shares contributed to the protocol NFT.
     * @return rewardsClaimed Amount of reward-token rewards claimed. For historical Protocol DETF deployments this was CHIR.
     */
    function sellPositionToDetfNft(uint256 tokenId, address seller, address rewardsRecipient)
        external
        returns (uint256 principalShares, uint256 rewardsClaimed);

    /* ---------------------------------------------------------------------- */
    /*                          Protocol NFT Operations                       */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice Adds LP to the protocol-owned NFT.
     * @dev Called when users sell their NFTs to the protocol.
     *      Does not reset lock time or affect rewards.
     * @param tokenId The protocol NFT token ID
     * @param lpAmount Amount of LP tokens to add
     */
    function addToDETFNFT(uint256 tokenId, uint256 lpAmount) external;

    /**
     * @notice Marks the protocol NFT as sold.
     * @dev Called when rebasing claim token is minted against this position.
     *      After this, no more LP can be added to the protocol NFT.
     * @param tokenId The protocol NFT token ID
     */
    function markDETFNFTSold(uint256 tokenId) external;

    /**
     * @notice Reallocates uncollected protocol NFT rewards as bond incentives.
     * @dev Can only be called by feeTo address from VaultFeeOracle.
     * @param recipient Address to receive reallocated rewards
    * @return amount Amount of reward-token rewards reallocated. For historical Protocol DETF deployments this was CHIR.
     */
    function reallocateDetfNftRewards(address recipient) external returns (uint256 amount);

    /* ---------------------------------------------------------------------- */
    /*                              Events                                    */
    /* ---------------------------------------------------------------------- */

    event PositionCreated(
        uint256 indexed tokenId,
        address indexed recipient,
        uint256 lpAmount,
        uint256 originalShares,
        uint256 effectiveShares,
        uint256 unlockTime
    );

    event PositionRedeemed(uint256 indexed tokenId, address indexed recipient, uint256 lpAmount, uint256 rewards);

    event RewardsClaimed(uint256 indexed tokenId, address indexed recipient, uint256 rewards);

    event DETFNFTUpdated(uint256 indexed tokenId, uint256 lpAdded, uint256 newTotalShares);

    event DetfNftRewardsReallocated(address indexed recipient, uint256 amount);
}
