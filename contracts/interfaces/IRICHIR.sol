// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";

/**
 * @title IRICHIR
 * @author cyotee doge <not_cyotee@proton.me>
 * @notice Interface for RICHIR rebasing token.
 * @dev RICHIR is a true rebasing token where balanceOf() returns different values
 *      over time based on the current spot redemption value of underlying shares.
 *
 *      User's RICHIR balance = userShares * currentRedemptionRate
 *      where: currentRedemptionRate = spotRedemptionQuote(1 share) in WETH terms
 *
 *      Rebasing triggers on any liquidity event in either underlying pool:
 *      - CHIR/WETH Aerodrome pool swaps, deposits, withdrawals
 *      - RICH/CHIR Aerodrome pool swaps, deposits, withdrawals
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
interface IRICHIR is IERC20, IERC20Metadata {
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
     * @notice Returns the current redemption rate (WETH per share).
     * @dev Calculated by simulating full unwinding:
     *      reserve LP -> vault tokens -> Aerodrome LP -> WETH
     * @return rate WETH value per share (1e18 precision)
     */
    function redemptionRate() external view returns (uint256 rate);

    /**
     * @notice Returns the Protocol DETF contract.
     * @return The Protocol DETF contract
     */
    function protocolDETF() external view returns (address);

    /**
     * @notice Returns the protocol-owned NFT token ID held by this contract.
     * @return The protocol NFT token ID
     */
    function protocolNFTId() external view returns (uint256);

    /**
     * @notice Returns the WETH token.
     * @return The WETH token
     */
    function wethToken() external view returns (IERC20);

    /**
     * @notice Converts RICHIR amount to underlying shares.
     * @param richirAmount Amount of RICHIR
     * @return shares Equivalent underlying shares
     */
    function convertToShares(uint256 richirAmount) external view returns (uint256 shares);

    /**
     * @notice Converts underlying shares to RICHIR amount.
     * @param shares Amount of shares
     * @return richirAmount Equivalent RICHIR amount
     */
    function convertToRichir(uint256 shares) external view returns (uint256 richirAmount);

    /**
     * @notice Preview WETH output for redeeming RICHIR.
     * @param richirAmount Amount of RICHIR to redeem
     * @return wethOut Amount of WETH that would be received
     */
    function previewRedeem(uint256 richirAmount) external view returns (uint256 wethOut);

    /* ---------------------------------------------------------------------- */
    /*                          Minting Operations                            */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice Mints RICHIR in exchange for NFT LP shares.
     * @dev Called by Protocol DETF when users sell their NFTs.
     *      LP shares are transferred to the protocol NFT held by this contract.
     * @param lpShares Amount of LP shares being contributed
     * @param recipient Address to receive RICHIR
     * @return richirMinted Amount of RICHIR minted
     */
    function mintFromNFTSale(uint256 lpShares, address recipient) external returns (uint256 richirMinted);

    /* ---------------------------------------------------------------------- */
    /*                          Redemption Operations                         */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice Redeems RICHIR for WETH.
     * @dev Always redeemable - no price gate. RICHIR represents a claim on the
     *      protocol-owned NFT's BPT, and holders can exit at any time.
     *
     *      Process:
     *      1. Burn RICHIR shares
     *      2. Exit reserve pool proportionally (get vault shares)
     *      3. Unwind CHIR/WETH vault shares -> WETH
     *      4. Unwind RICH/CHIR vault shares -> CHIR
     *      5. Swap CHIR -> WETH via CHIR/WETH vault
     *      6. Send total WETH to user
     *
     * @param richirAmount Amount of RICHIR to redeem
     * @param recipient Address to receive WETH
     * @param pretransferred Whether RICHIR was already transferred
     * @return wethOut Amount of WETH sent to recipient
     */
    function redeem(uint256 richirAmount, address recipient, bool pretransferred) external returns (uint256 wethOut);

    /**
     * @notice Burns RICHIR shares without transferring WETH.
     * @dev Called by Protocol DETF during RICHIR → WETH redemption.
     *      The Protocol DETF handles the BPT exit and WETH transfer separately.
     * @param richirAmount Amount of RICHIR balance to burn
     * @param owner Address whose RICHIR is being burned
     * @param pretransferred Whether RICHIR was already transferred to this contract
     * @return sharesBurned Amount of underlying shares burned
     */
    function burnShares(uint256 richirAmount, address owner, bool pretransferred)
        external
        returns (uint256 sharesBurned);

    /* ---------------------------------------------------------------------- */
    /*                              Events                                    */
    /* ---------------------------------------------------------------------- */

    event Minted(address indexed recipient, uint256 lpShares, uint256 sharesMinted, uint256 richirAmount);

    event Redeemed(
        address indexed redeemer, address indexed recipient, uint256 richirAmount, uint256 sharesBurned, uint256 wethOut
    );

    event RedemptionRateUpdated(uint256 oldRate, uint256 newRate);
}
