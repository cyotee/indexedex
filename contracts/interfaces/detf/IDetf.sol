// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20MintBurn} from "@crane/contracts/interfaces/IERC20MintBurn.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IDETFNFTVault} from "contracts/interfaces/IDETFNFTVault.sol";
import {IStandardExchange} from "contracts/interfaces/IStandardExchange.sol";
import {ThresholdMode} from "contracts/vaults/detf/common/core/DETFThresholdPolicy.sol";

/**
 * @title IDetf
 * @author cyotee doge <not_cyotee@proton.me>
 * @notice Shared DETF diamond surface with integrated fee distribution.
 * @dev Implements a DETF with:
 *      - DETF token: Mintable/burnable ERC20 (this contract)
 *      - pairToken: Static-supply ERC20 (non-rateAsset vault token)
 *      - rebasingClaimToken: Rebasing ERC20 redeemable for rateAsset
 *      - Reserve pool: 80/20 Balancer V3 weighted pool
 *      - rateAsset: Rate Provider target / mint-bond-redeem settlement ("new money")
 *      - underlyingVault: Any IStandardExchange that processes rateAsset
 *
 *      Primary-market mint/burn gates use **synthetic / fully diluted** price (not pure
 *      reserve spot). Deploy-time `ThresholdMode` (PRD DETF_Threshold_Modes):
 *      - **Policy** (default): mint only if `synthetic > mintThreshold`; burn only if
 *        `synthetic < burnThreshold`. Equality is deadband (neither). Defaults ±5%
 *        when args are `0,0` (`1.05e18` / `0.95e18`).
 *      - **Open**: when live, threshold gates always pass; thresholds still stored for
 *        getters/display but are ignored by mint/burn gate helpers.
 *      Inert / pre-live always blocks normal user mint/burn regardless of mode.
 *      Claim redemption (`RedemptionNotAllowed`) is independent of Open.
 */
interface IDetf {
    struct BridgeArgs {
        uint256 targetChainId;
        uint256 rebasingClaimAmount;
        address recipient;
        uint256 minLocalRebasingClaimOut;
        uint256 minPairOut;
        uint32 messageGasLimit;
        uint256 deadline;
    }

    struct BridgeQuote {
        uint256 rebasingClaimAmountIn;
        uint256 sharesBurned;
        uint256 reserveSharesBurned;
        uint256 localRebasingClaimOut;
        uint256 pairOut;
    }

    /* ---------------------------------------------------------------------- */
    /*                              View Functions                            */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice Returns the DETF token (this contract).
     */
    function detfToken() external view returns (IERC20MintBurn);

    /**
     * @notice Returns the pair token (vault-declared asset that is not rateAsset).
     */
    function pairToken() external view returns (IERC20);

    /**
     * @notice Returns the rebasing claim token.
     */
    function rebasingClaimToken() external view returns (IERC20);

    /**
     * @notice Returns the rate asset (Rate Provider target / settlement token).
     */
    function rateAsset() external view returns (IERC20);

    /**
     * @notice Returns the NFT vault that manages bond positions.
     */
    function detfNFTVault() external view returns (IDETFNFTVault);

    /**
     * @notice Returns the underlying Standard Exchange vault.
     */
    function underlyingVault() external view returns (IStandardExchange);

    /**
     * @notice Returns the reserve pool (Balancer 80/20 pool) address.
     */
    function reservePool() external view returns (address);

    /**
     * @notice Returns the protocol-owned NFT token ID.
     * @dev This NFT has no unlock time and accumulates LP from sold user NFTs.
     */
    function detfNFTId() external view returns (uint256);

    /* ---------------------------------------------------------------------- */
    /*                          Price Oracle                                  */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice Calculates the synthetic (fully diluted) price of the DETF.
     * @dev Derived from protocol-owned reserve backing (and bond-held BPT when the
     *      family includes it). Gate input for mint/burn is always this synthetic
     *      value — not pure spot. Abstract `1e18` is the Policy peg reference.
     * @return syntheticPrice The synthetic price (1e18 = abstract peg under Policy)
     */
    function syntheticPrice() external view returns (uint256);

    /**
     * @notice Returns the stored mint threshold (Policy upper deadband bound).
     * @dev After deploy resolve: `0` args become `1.05e18`. Under **Open**, the value
     *      remains stored for display/getters; **gates ignore** it. Under **Policy**,
     *      mint is allowed only when `syntheticPrice > mintThreshold` and the product is live.
     */
    function mintThreshold() external view returns (uint256);

    /**
     * @notice Returns the stored burn threshold (Policy lower deadband bound).
     * @dev After deploy resolve: `0` args become `0.95e18`. Under **Open**, the value
     *      remains stored for display/getters; **gates ignore** it. Under **Policy**,
     *      burn is allowed only when `syntheticPrice < burnThreshold` and the product is live.
     */
    function burnThreshold() external view returns (uint256);

    /**
     * @notice Returns the deploy-time primary-market threshold mode.
     * @dev `ThresholdMode.Policy` (0) = deadband gates; `ThresholdMode.Open` (1) =
     *      threshold gates always pass when live. Fixed at init; no post-deploy setter.
     */
    function thresholdMode() external view returns (ThresholdMode);

    /**
     * @notice Checks if seigniorage minting is currently allowed.
     * @dev Requires family **live** (e.g. reserve initialized / first bond). Then:
     *      - **Policy:** `syntheticPrice > mintThreshold`
     *      - **Open:** threshold check always true
     *      Inert always returns false. Does not cover claim redemption.
     */
    function isMintingAllowed() external view returns (bool allowed);

    /**
     * @notice Checks if seigniorage burning is currently allowed.
     * @dev Requires family **live**. Then:
     *      - **Policy:** `syntheticPrice < burnThreshold`
     *      - **Open:** threshold check always true
     *      Inert always returns false. Claim-path redemption is separate
     *      (`RedemptionNotAllowed` is independent of Open).
     */
    function isBurningAllowed() external view returns (bool allowed);

    /* ---------------------------------------------------------------------- */
    /*                          Minting Operations                            */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice Mints DETF tokens by depositing rateAsset.
     * @dev Allowed only when `isMintingAllowed()` is true (live + Policy/Open synthetic gate).
     * @param rateAssetAmount Amount of rateAsset to deposit
     * @param recipient Address to receive DETF tokens
     * @param pretransferred Whether rateAsset was already transferred
     * @return detfMinted Amount of DETF minted to recipient
     */
    function mintWithRateAsset(uint256 rateAssetAmount, address recipient, bool pretransferred)
        external
        returns (uint256 detfMinted);

    /* ---------------------------------------------------------------------- */
    /*                          Bonding Operations                            */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice Returns the accepted bond-token set for the unified bond route.
     */
    function acceptedBondTokens() external view returns (address[] memory tokens);

    /**
     * @notice Returns whether a token is accepted by the unified bond route.
     */
    function isAcceptedBondToken(IERC20 token) external view returns (bool isAccepted);

    /**
     * @notice Bonds an accepted ERC20 token to receive an NFT position.
     * @dev ERC20-only; does not accept bare native ETH.
     * @param tokenIn Accepted bond token to route.
     * @param amountIn Amount of tokenIn to bond.
     * @param lockDuration Duration to lock the position in seconds.
     * @param recipient Address to receive the NFT.
     * @param deadline Transaction deadline.
     * @return tokenId The minted NFT token ID.
     * @return shares The underlying share amount.
     */
    function bond(IERC20 tokenIn, uint256 amountIn, uint256 lockDuration, address recipient, uint256 deadline)
        external
        returns (uint256 tokenId, uint256 shares);

    /* ---------------------------------------------------------------------- */
    /*                       Seigniorage Capture                              */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice Captures seigniorage when the synthetic price is above peg.
     * @dev Compounds only the protocol NFT's accrued DETF reward share into reserve-backed LP.
     */
    function captureSeigniorage() external returns (uint256 seigniorageCaptured);

    /* ---------------------------------------------------------------------- */
    /*                          NFT Sale                                      */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice Sells an NFT to the protocol for rebasing claim tokens.
     * @dev NFT's LP shares transferred to protocol-owned NFT.
     *      User receives rebasing claim tokens proportional to position value.
     */
    function sellNFT(uint256 tokenId, address recipient) external returns (uint256 rebasingClaimMinted);

    /* ---------------------------------------------------------------------- */
    /*                          Fee Donation                                  */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice Accepts fee donations from FeeCollector.
     * @dev rateAsset: Single-sided deposit into the underlying vault path, unbalanced to reserve.
     *      DETF token: Simply burned.
     * @param token Token to donate (rateAsset or DETF token only)
     * @param amount Amount to donate
     * @param pretransferred Whether tokens were already transferred
     */
    function donate(IERC20 token, uint256 amount, bool pretransferred) external;

    /* ---------------------------------------------------------------------- */
    /*                          Liquidity Operations                          */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice Previews the amount of rateAsset returned from claiming LP (single-sided exit).
     * @param lpAmount Amount of BPT (LP shares) to preview
     * @return rateAssetOut Amount of rateAsset that would be received
     */
    function previewClaimLiquidity(uint256 lpAmount) external view returns (uint256 rateAssetOut);

    /**
     * @notice Previews the source-chain bridge accounting for a rebasing-claim bridge.
     */
    function previewBridgeRebasingClaim(uint256 targetChainId, uint256 rebasingClaimAmount)
        external
        view
        returns (BridgeQuote memory quote);

    /**
     * @notice Claims liquidity from the 80/20 pool (called by NFT vault on unlock).
     * @param lpAmount Amount of BPT (LP shares) to claim
     * @param recipient Address to receive the extracted value
     * @return extractedRateAsset Amount of rateAsset sent to recipient
     */
    function claimLiquidity(uint256 lpAmount, address recipient) external returns (uint256 extractedRateAsset);

    /**
     * @notice Bridges the pair-side value of a rebasing-claim position to another DETF instance.
     */
    function bridgeRebasingClaim(BridgeArgs calldata args)
        external
        returns (uint256 localRebasingClaimOut, uint256 pairOut);

    /**
     * @notice Finalizes bridged pair token into destination-chain rebasing claim tokens.
     */
    function receiveBridgedPair(address recipient, uint256 pairAmount, uint256 deadline)
        external
        returns (uint256 rebasingClaimOut);

    /* ---------------------------------------------------------------------- */
    /*                           Reward Operations                            */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice Withdraws pending reward-token rewards for a bond position.
     */
    function withdrawRewards(uint256 tokenId, address recipient) external returns (uint256 rewards);
}
