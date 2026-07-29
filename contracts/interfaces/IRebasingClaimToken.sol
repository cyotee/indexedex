// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";

/**
 * @title IRebasingClaimToken
 * @author cyotee doge <not_cyotee@proton.me>
 * @notice Interface for rebasing claim token.
 * @dev rebasing claim token is a true rebasing token where balanceOf() returns different values
 *      over time based on the current spot redemption value of underlying shares.
 *
 *      User's rebasing claim token balance = userShares * currentRedemptionRate
 *      where: currentRedemptionRate = spotRedemptionQuote(1 share) in rateAsset terms
 *
 *      Rebasing triggers on any liquidity event in either underlying pool:
 *      - DETF/rateAsset Aerodrome pool swaps, deposits, withdrawals
 *      - pair/CHIR Aerodrome pool swaps, deposits, withdrawals
 *
 *      This means balanceOf() can return different values between any two calls.
 *
 *      INTENTIONAL INCOMPATIBILITIES:
 *      - AMM liquidity pools (balance changes break invariants)
 *      - Lending protocols (collateral value unstable)
 *      - Yield aggregators (share accounting assumptions violated)
 *      - Most DeFi integrations expecting stable balanceOf()
 *
 *      This is designed as a redemption claim, not a composable DeFi primitive.
 */
interface IRebasingClaimToken is IERC20, IERC20Metadata, IStandardExchangeIn, IStandardExchangeOut {
    /* ---------------------------------------------------------------------- */
    /*                              View Functions                            */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice Returns the underlying shares owned by an account.
     * @dev Shares are constant between mint/burn operations.
     *      balanceOf() is computed as sharesOf * redemptionRate.
     * @param account The address to query
     * @return shares The underlying share balance
     */
    function sharesOf(address account) external view returns (uint256 shares);

    /**
     * @notice Returns the total underlying shares.
     * @dev totalSupply() is computed as totalShares * redemptionRate.
     * @return shares Total underlying shares
     */
    function totalShares() external view returns (uint256 shares);

    /**
    * @notice Returns the current redemption rate (configured common-token value per share).
     * @dev Calculated by simulating full unwinding:
     *      reserve LP -> vault tokens -> Aerodrome LP -> rateAsset
     * @return rate rateAsset value per share (1e18 precision)
     */
    function redemptionRate() external view returns (uint256 rate);

    /**
     * @notice Returns the DETF diamond.
     * @return The DETF diamond
     */
    function detf() external view returns (address);

    /**
     * @notice Sets the DETF contract used for pricing and redemption callbacks.
     * @dev Owner-only deployment-time wiring hook for composed DETF deployments.
     * @param detf The DETF contract
     */
    function setDetf(address detf) external;

    /**
     * @notice Returns the protocol-owned NFT token ID held by this contract.
     * @return The protocol NFT token ID
     */
    function detfNFTId() external view returns (uint256);

    /**
    * @notice Returns the configured common-token boundary.
    * @dev The method name remains `rateAsset()` for compatibility with existing callers.
    *      Deployments may use any configured common token, not only rateAsset.
    * @return The configured common token
     */
    function rateAsset() external view returns (IERC20);

    /**
     * @notice Converts rebasing claim token amount to underlying shares.
     * @param rebasingClaimAmount Amount of rebasing claim token
     * @return shares Equivalent underlying shares
     */
    function convertToShares(uint256 rebasingClaimAmount) external view returns (uint256 shares);

    /**
     * @notice Converts underlying shares to rebasing claim token amount.
     * @param shares Amount of shares
     * @return rebasingClaimAmount Equivalent rebasing claim token amount
     */
    function convertToClaim(uint256 shares) external view returns (uint256 rebasingClaimAmount);

    /**
    * @notice Preview configured common-token output for redeeming rebasing claim token.
     * @param rebasingClaimAmount Amount of rebasing claim token to redeem
    * @return wethOut Amount of configured common token that would be received
     */
    function previewRedeem(uint256 rebasingClaimAmount) external view returns (uint256 wethOut);

    /* ---------------------------------------------------------------------- */
    /*                          Minting Operations                            */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice Mints rebasing claim token in exchange for NFT LP shares.
     * @dev Called by the DETF diamond when users sell their NFTs.
     *      LP shares are transferred to the protocol NFT held by this contract.
     * @param lpShares Amount of LP shares being contributed
     * @param recipient Address to receive rebasing claim token
     * @return rebasingClaimMinted Amount of rebasing claim token minted
     */
    function mintFromNFTSale(uint256 lpShares, address recipient) external returns (uint256 rebasingClaimMinted);

    /* ---------------------------------------------------------------------- */
    /*                          Redemption Operations                         */
    /* ---------------------------------------------------------------------- */

    /**
    * @notice Redeems rebasing claim token for the configured common token.
    * @dev Compatibility wrapper around the canonical `exchangeIn(rebasing claim token -> common token)` path.
    *      Always redeemable - no price gate. rebasing claim token represents a claim on the
    *      protocol-owned NFT's reserve-pool BPT, and holders can exit at any time.
     *
     *      Process:
    *      1. Convert apparent rebasing claim token amount to internal shares
    *      2. Convert those shares into protocol-owned reserve-pool BPT claim
    *      3. Burn the rebasing claim token shares atomically
    *      4. Ask the DETF to claim/unwind that reserve-pool BPT into the configured common token
    *      5. Send the common token to the user
     *
     * @param rebasingClaimAmount Amount of rebasing claim token to redeem
    * @param recipient Address to receive the configured common token
     * @param pretransferred Whether rebasing claim token was already transferred
    * @return wethOut Amount of configured common token sent to recipient
     */
    function redeem(uint256 rebasingClaimAmount, address recipient, bool pretransferred) external returns (uint256 wethOut);

    /**
     * @notice Burns rebasing claim token shares without transferring rateAsset.
     * @dev Called by the DETF diamond during rebasing claim token → rateAsset redemption.
     *      The DETF diamond handles the BPT exit and rateAsset transfer separately.
     * @param rebasingClaimAmount Amount of rebasing claim token balance to burn
     * @param owner Address whose rebasing claim token is being burned
     * @param pretransferred Whether rebasing claim token was already transferred to this contract
     * @return sharesBurned Amount of underlying shares burned
     */
    function burnShares(uint256 rebasingClaimAmount, address owner, bool pretransferred)
        external
        returns (uint256 sharesBurned);

    /* ---------------------------------------------------------------------- */
    /*                              Events                                    */
    /* ---------------------------------------------------------------------- */

    event Minted(address indexed recipient, uint256 lpShares, uint256 sharesMinted, uint256 rebasingClaimAmount);

    event Redeemed(
        address indexed redeemer, address indexed recipient, uint256 rebasingClaimAmount, uint256 sharesBurned, uint256 wethOut
    );

    event RedemptionRateUpdated(uint256 oldRate, uint256 newRate);
}
