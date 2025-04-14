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

import {IProtocolNFTVault} from "contracts/interfaces/IProtocolNFTVault.sol";
import {IStandardExchange} from "contracts/interfaces/IStandardExchange.sol";

/**
 * @title IProtocolDETF
 * @author cyotee doge <not_cyotee@proton.me>
 * @notice Interface for Protocol DETF (CHIR token) with integrated fee distribution.
 * @dev Implements a DETF with:
 *      - CHIR: Mintable/burnable ERC20 (the DETF token)
 *      - RICH: Static supply ERC20 (reward token)
 *      - RICHIR: Rebasing ERC20 redeemable for WETH
 *      - Reserve pool: 80/20 Balancer V3 weighted pool
 *
 *      Uses a fully diluted, backing-derived synthetic spot price to gate
 *      asymmetric operations with a deadband around peg:
 *      - mint below the lower deadband bound
 *      - burn above the upper deadband bound
 *      - disable both inside the deadband
 */
interface IProtocolDETF {
    struct BridgeArgs {
        uint256 targetChainId;
        uint256 richirAmount;
        address recipient;
        uint256 minLocalRichirOut;
        uint256 minRichOut;
        uint32 messageGasLimit;
        uint256 deadline;
    }

    struct BridgeQuote {
        uint256 richirAmountIn;
        uint256 sharesBurned;
        uint256 reserveSharesBurned;
        uint256 localRichirOut;
        uint256 richOut;
    }

    /* ---------------------------------------------------------------------- */
    /*                              View Functions                            */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice Returns the CHIR token (this contract).
     * @return The CHIR token (Protocol DETF token)
     */
    function chirToken() external view returns (IERC20MintBurn);

    /**
     * @notice Returns the RICH token (static supply reward token).
     * @return The RICH token
     */
    function richToken() external view returns (IERC20);

    /**
     * @notice Returns the RICHIR token (rebasing redemption token).
     * @return The RICHIR token
     */
    function richirToken() external view returns (IERC20);

    /**
     * @notice Returns the WETH token (chain's wrapped gas token).
     * @return The WETH token
     */
    function wethToken() external view returns (IERC20);

    /**
     * @notice Returns the NFT vault that manages bond positions.
     * @return The NFT vault contract
     */
    function protocolNFTVault() external view returns (IProtocolNFTVault);

    /**
     * @notice Returns the CHIR/WETH Standard Exchange Vault.
     * @return The CHIR/WETH vault
     */
    function chirWethVault() external view returns (IStandardExchange);

    /**
     * @notice Returns the RICH/CHIR Standard Exchange Vault.
     * @return The RICH/CHIR vault
     */
    function richChirVault() external view returns (IStandardExchange);

    /**
     * @notice Returns the reserve pool (Balancer 80/20 pool) address.
     * @return The reserve pool contract
     */
    function reservePool() external view returns (address);

    /**
     * @notice Returns the protocol-owned NFT token ID.
     * @dev This NFT has no unlock time and accumulates LP from sold user NFTs.
     * @return The protocol NFT token ID
     */
    function protocolNFTId() external view returns (uint256);

    /* ---------------------------------------------------------------------- */
    /*                          Price Oracle                                  */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice Calculates the synthetic spot price quoted as RICH per 1 WETH.
     * @dev Derived from the protocol-owned reserve backing and weighted-pool spot-price math.
     *      `1e18` represents peg, values below peg favor minting, and values above peg favor burning.
     * @return syntheticPrice The synthetic price (1e18 = peg)
     */
    function syntheticPrice() external view returns (uint256);

    /**
     * @notice Returns the upper deadband bound.
     * @dev Burning is allowed only when the synthetic price is above this bound.
     * @return threshold The upper deadband bound (e.g., 1.005e18)
     */
    function mintThreshold() external view returns (uint256);

    /**
     * @notice Returns the lower deadband bound.
     * @dev Minting is allowed only when the synthetic price is below this bound.
     * @return threshold The lower deadband bound (e.g., 0.995e18)
     */
    function burnThreshold() external view returns (uint256);

    /**
     * @notice Checks if minting is currently allowed.
     * @return allowed True if syntheticPrice is below `burnThreshold()`
     */
    function isMintingAllowed() external view returns (bool allowed);

    /**
     * @notice Checks if burning/redemption is currently allowed.
     * @return allowed True if syntheticPrice is above `mintThreshold()`
     */
    function isBurningAllowed() external view returns (bool allowed);

    /* ---------------------------------------------------------------------- */
    /*                          Minting Operations                            */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice Mints CHIR by depositing WETH.
        * @dev Only allowed when syntheticPrice is below the lower deadband bound.
     *      WETH is paired with minted CHIR, LPed, vaulted, and added to reserve.
     * @param wethAmount Amount of WETH to deposit
     * @param recipient Address to receive CHIR
     * @param pretransferred Whether WETH was already transferred
     * @return chirMinted Amount of CHIR minted to recipient
     */
    function mintWithWeth(uint256 wethAmount, address recipient, bool pretransferred)
        external
        returns (uint256 chirMinted);

    /* ---------------------------------------------------------------------- */
    /*                          Bonding Operations                            */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice Bonds WETH to receive an NFT position.
     * @dev WETH paired with minted CHIR, LPed into CHIR/WETH pool.
     * @param wethAmount Amount of WETH to bond
     * @param lockDuration Duration to lock the position in seconds
     * @param recipient Address to receive the NFT
     * @param pretransferred Whether WETH was already transferred
     * @return tokenId The minted NFT token ID
     */
    function bondWithWeth(uint256 wethAmount, uint256 lockDuration, address recipient, bool pretransferred)
        external
        returns (uint256 tokenId);

    /**
     * @notice Bonds RICH to receive an NFT position.
     * @dev RICH paired with minted CHIR, LPed into RICH/CHIR pool.
     * @param richAmount Amount of RICH to bond
     * @param lockDuration Duration to lock the position in seconds
     * @param recipient Address to receive the NFT
     * @param pretransferred Whether RICH was already transferred
     * @return tokenId The minted NFT token ID
     */
    function bondWithRich(uint256 richAmount, uint256 lockDuration, address recipient, bool pretransferred)
        external
        returns (uint256 tokenId);

    /* ---------------------------------------------------------------------- */
    /*                       Seigniorage Capture                              */
    /* ---------------------------------------------------------------------- */

    /**
        * @notice Captures seigniorage when the synthetic price is above peg.
     * @dev Mints CHIR, zaps into RICH/CHIR vault, adds to reserve.
     *      Not credited to any account - benefits all NFT holders.
     * @return seigniorageCaptured Amount of CHIR minted as seigniorage
     */
    function captureSeigniorage() external returns (uint256 seigniorageCaptured);

    /* ---------------------------------------------------------------------- */
    /*                          NFT Sale                                      */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice Sells an NFT to the protocol for RICHIR.
     * @dev NFT's LP shares transferred to protocol-owned NFT.
     *      User receives RICHIR tokens proportional to position value.
     * @param tokenId The NFT token ID to sell
     * @param recipient Address to receive RICHIR
     * @return richirMinted Amount of RICHIR minted to recipient
     */
    function sellNFT(uint256 tokenId, address recipient) external returns (uint256 richirMinted);

    /* ---------------------------------------------------------------------- */
    /*                          Fee Donation                                  */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice Accepts fee donations from FeeCollector.
     * @dev WETH: Single-sided deposit to CHIR/WETH vault, unbalanced to reserve.
     *      CHIR: Simply burned.
     * @param token Token to donate (WETH or CHIR only)
     * @param amount Amount to donate
     * @param pretransferred Whether tokens were already transferred
     */
    function donate(IERC20 token, uint256 amount, bool pretransferred) external;

    /* ---------------------------------------------------------------------- */
    /*                          Liquidity Operations                          */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice Previews the amount of WETH returned from claiming LP (single-sided exit).
     * @param lpAmount Amount of BPT (LP shares) to preview
     * @return wethOut Amount of WETH that would be received
     */
    function previewClaimLiquidity(uint256 lpAmount) external view returns (uint256 wethOut);

    /**
     * @notice Previews the source-chain bridge accounting for a RICHIR bridge.
     * @param targetChainId Destination chain ID.
     * @param richirAmount Apparent RICHIR amount to bridge.
     * @return quote Bridge accounting preview.
     */
    function previewBridgeRichir(uint256 targetChainId, uint256 richirAmount)
        external
        view
        returns (BridgeQuote memory quote);

    /**
     * @notice Claims liquidity from the 80/20 pool (called by NFT vault on unlock).
     * @param lpAmount Amount of BPT (LP shares) to claim
     * @param recipient Address to receive the extracted value
     * @return extractedWeth Amount of WETH sent to recipient
     */
    function claimLiquidity(uint256 lpAmount, address recipient) external returns (uint256 extractedWeth);

    /**
     * @notice Bridges the RICH-side value of a RICHIR position to another DETF instance.
     * @param args Bridge execution arguments.
     * @return localRichirOut Compensating local RICHIR minted to the caller.
     * @return richOut Raw RICH bridged to the destination relayer.
     */
    function bridgeRichir(BridgeArgs calldata args)
        external
        returns (uint256 localRichirOut, uint256 richOut);

    /**
     * @notice Finalizes bridged RICH into destination-chain RICHIR.
     * @param recipient Address receiving destination RICHIR.
     * @param richAmount Bridged RICH amount to convert.
     * @param deadline Execution deadline for the destination conversion.
     * @return richirOut Destination RICHIR minted.
     */
    function receiveBridgedRich(address recipient, uint256 richAmount, uint256 deadline)
        external
        returns (uint256 richirOut);

    /* ---------------------------------------------------------------------- */
    /*                           Reward Operations                            */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice Withdraws pending RICH rewards for a bond position.
     * @param tokenId The NFT token ID
     * @param recipient Address to receive the rewards
     * @return rewards Amount of RICH rewards withdrawn
     */
    function withdrawRewards(uint256 tokenId, address recipient) external returns (uint256 rewards);
}
