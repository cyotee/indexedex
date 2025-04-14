// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {ISeigniorageNFTVault} from "contracts/interfaces/ISeigniorageNFTVault.sol";

/**
 * @title ISeigniorageDETF
 * @author cyotee doge <not_cyotee@proton.me>
 * @notice Interface for Seigniorage DETF (Decentralized Exchange-Traded Fund).
 * @dev A reserve-backed ERC20 that maintains peg via an 80/20 Balancer pool.
 *      When above peg, users can mint by depositing reserve tokens.
 *      When below peg, users can burn to receive reserve tokens.
 *      Seigniorage (profit from above-peg mints) is distributed to NFT bond holders.
 */
interface ISeigniorageDETF {
    /* ---------------------------------------------------------------------- */
    /*                              View Functions                            */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice Returns the seigniorage reward token (sRBT).
     * @return The seigniorage token contract
     */
    function seigniorageToken() external view returns (IERC20);

    /**
     * @notice Returns the NFT vault that manages bond positions.
     * @return The NFT vault contract
     */
    function seigniorageNFTVault() external view returns (ISeigniorageNFTVault);

    /**
     * @notice Returns the rate target token for reserve vault valuation.
     * @return The rate target token (e.g., USDC)
     */
    function reserveVaultRateTarget() external view returns (IERC20);

    /**
     * @notice Returns the reserve pool (Balancer 80/20 pool) address.
     * @return The reserve pool contract
     */
    function reservePool() external view returns (address);

    /* ---------------------------------------------------------------------- */
    /*                          Underwriting Operations                       */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice Underwrites (bonds) tokens to receive an NFT position with boosted rewards.
     * @dev Deposits to the 80/20 Balancer pool and credits the user with BPT shares.
     * @param tokenIn Token to deposit (reserve vault shares or constituent)
     * @param amountIn Amount to deposit
     * @param lockDuration Duration to lock the position in seconds
     * @param recipient Address to receive the NFT
     * @param pretransferred Whether tokens were already transferred to this contract
     * @return tokenId The minted NFT token ID
     */
    function underwrite(IERC20 tokenIn, uint256 amountIn, uint256 lockDuration, address recipient, bool pretransferred)
        external
        returns (uint256 tokenId);

    /* ---------------------------------------------------------------------- */
    /*                          Liquidity Operations                          */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice Previews the amount of rate target tokens returned from claiming LP.
     * @param lpAmount Amount of BPT (LP shares) to preview
     * @return liquidityOut Amount of rate target tokens that would be received
     */
    function previewClaimLiquidity(uint256 lpAmount) external view returns (uint256 liquidityOut);

    /**
     * @notice Claims liquidity from the 80/20 pool (called by NFT vault on unlock).
     * @dev Removes liquidity proportionally, extracts reserve vault value as rate target,
     *      and redeposits RBT back to maintain pool balance.
     * @param lpAmount Amount of BPT (LP shares) to claim
     * @param recipient Address to receive the extracted value
     * @return extractedLiquidity Amount of rate target tokens sent to recipient
     */
    function claimLiquidity(uint256 lpAmount, address recipient) external returns (uint256 extractedLiquidity);

    /* ---------------------------------------------------------------------- */
    /*                           Reward Operations                            */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice Withdraws pending sRBT rewards for a bond position.
     * @param tokenId The NFT token ID
     * @param recipient Address to receive the rewards
     * @return rewards Amount of sRBT rewards withdrawn
     */
    function withdrawRewards(uint256 tokenId, address recipient) external returns (uint256 rewards);
}
