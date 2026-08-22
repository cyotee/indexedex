// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {Math} from "@crane/contracts/utils/Math.sol";

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {ERC721Repo} from "@crane/contracts/tokens/ERC721/ERC721Repo.sol";
import {LibString} from "@crane/contracts/utils/LibString.sol";
import {Base64} from "@crane/contracts/utils/Base64.sol";
import {BetterMath} from "@crane/contracts/utils/math/BetterMath.sol";
import {BetterSafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IDetf} from "contracts/interfaces/detf/IDetf.sol";
import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";

/* -------------------------------------------------------------------------- */
/*                              SVG Constants                                 */
/* -------------------------------------------------------------------------- */

string constant METADATA_JSON_PREFIX = "data:application/json;base64,";
string constant JSON_NAME_PREFIX = '{"name": "Protocol Bond NFT # ';
string constant JSON_NAME_SUFFIX = '", ';
string constant JSON_DESCRIPTION = '"description": "This NFT represents a DETF bond position.",';
string constant JSON_IMAGE_PREFIX = '"image": "data:image/svg+xml;base64,';

string constant SVG_IMAGE_PREFIX =
    '<?xml version="1.0" encoding="UTF-8"?><svg viewBox="0 0 400 300" xmlns="http://www.w3.org/2000/svg">';

string constant SVG_IMAGE_TOKEN_ID_PREFIX =
    '<rect width="400" height="300" rx="10" ry="10" fill="#1a1a2e"/><text x="200" y="40" fill="#00ff00" font-family="Courier New, monospace" font-size="18" font-weight="bold" text-anchor="middle">PROTOCOL BOND</text><text x="200" y="70" fill="#00ff00" font-family="Courier New, monospace" font-size="24" font-weight="bold" text-anchor="middle">Token ID: ';

string constant SVG_UNLOCK_PREFIX =
    '</text><text x="200" y="100" fill="#00ff00" font-family="Courier New, monospace" font-size="14" text-anchor="middle">Unlock: ';

string constant SVG_SHARES_PREFIX =
    '</text><rect x="50" y="120" width="300" height="80" rx="5" ry="5" fill="none" stroke="#00ff00"/><text x="200" y="150" fill="#00ff00" font-family="Courier New, monospace" font-size="14" text-anchor="middle">Shares: ';

string constant SVG_REWARDS_PREFIX =
    '</text><text x="200" y="180" fill="#00ff00" font-family="Courier New, monospace" font-size="14" text-anchor="middle">Pending rewards: ';

string constant SVG_TEXT_CLOSE = "</text>";
string constant SVG_IMAGE_CLOSE = "</svg>";

/**
 * @title DETFNFTVaultRepo
 * @author cyotee doge <not_cyotee@proton.me>
 * @notice Storage library for Protocol NFT Vault state.
 * @dev Follows the Crane Repo pattern with dual _layoutStruct() functions.
 *      Manages bond positions with:
 *      - Original shares (base LP allocation)
 *      - Effective shares (boosted by lock duration)
 *      - Reward-token tracking
 *      - Protocol-owned NFT for accumulated positions
 */
library DETFNFTVaultRepo {
    using BetterSafeERC20 for IERC20Metadata;
    using LibString for uint256;

    bytes32 internal constant STORAGE_SLOT = keccak256("indexedex.vaults.protocol.nft");

    struct Storage {
        /// @notice The DETF diamond
        IDetf detf;
        /// @notice The LP token (BPT from reserve pool)
        IERC20 lpToken;
        /// @notice The reward token
        IERC20 rewardToken;
        /// @notice Last recorded reward token balance for calculating new rewards
        uint256 lastRewardTokenBalance;
        /// @notice Total effective shares across all positions
        uint256 totalShares;
        /// @notice Accumulated reward per share (scaled by 1e18)
        uint256 rewardPerShares;
        /// @notice Decimal offset for share calculations
        uint8 decimalOffset;
        /// @notice Original shares allocated to each token ID
        mapping(uint256 tokenId => uint256 originalShares) originalSharesOf;
        /// @notice Boosted shares (including bonus) for each token ID
        mapping(uint256 tokenId => uint256 effectiveShares) effectiveSharesOf;
        /// @notice Bonus multiplier (scaled by 1e18) used when position was created
        mapping(uint256 tokenId => uint256 bonusMultiplier) bonusMultiplierOf;
        /// @notice Unlock timestamp for each token ID
        mapping(uint256 tokenId => uint256 unlockTime) unlockTimeOf;
        /// @notice Reward per share at time of last update for each token ID
        mapping(uint256 tokenId => uint256) userRewardPerSharePaid;
        /// @notice Counter for generating unique token IDs
        uint256 nextTokenId;
        /// @notice Protocol-owned NFT token ID (has no unlock time). 0 is a valid D7 protocol id.
        uint256 detfNFTId;
        /// @notice Sum of originalShares across all tokenIds (user + protocol).
        uint256 totalOriginalShares;
        /// @notice L6: protocol NFT has been minted. Do not treat `detfNFTId == 0` as unwired.
        bool protocolNftInitialized;
        /// @notice D7: ids 0, 1, and 2 have been minted (protocol / feeTo / creator).
        bool reservedIdsWired;
    }

    /* ---------------------------------------------------------------------- */
    /*                           Layout Functions                             */
    /* ---------------------------------------------------------------------- */

    function _layoutStruct(bytes32 slot_) internal pure returns (Storage storage layoutStruct_) {
        assembly {
            layoutStruct_.slot := slot_
        }
    }

    function _layoutStruct() internal pure returns (Storage storage) {
        return _layoutStruct(STORAGE_SLOT);
    }

    /* ---------------------------------------------------------------------- */
    /*                         Initialization                                 */
    /* ---------------------------------------------------------------------- */

    function _initialize(
        Storage storage layoutStruct_,
        IDetf detf_,
        IERC20 lpToken_,
        IERC20 rewardToken_,
        uint8 decimalOffset_
    ) internal {
        layoutStruct_.detf = detf_;
        layoutStruct_.lpToken = lpToken_;
        layoutStruct_.rewardToken = rewardToken_;
        layoutStruct_.decimalOffset = decimalOffset_;
        layoutStruct_.nextTokenId = 1;
    }

    function _initialize(IDetf detf_, IERC20 lpToken_, IERC20 rewardToken_, uint8 decimalOffset_)
        internal
    {
        _initialize(_layoutStruct(), detf_, lpToken_, rewardToken_, decimalOffset_);
    }

    function _setDETFNFTId(Storage storage layoutStruct_, uint256 tokenId_) internal {
        layoutStruct_.detfNFTId = tokenId_;
    }

    function _setDETFNFTId(uint256 tokenId_) internal {
        _setDETFNFTId(_layoutStruct(), tokenId_);
    }

    function _protocolNftInitialized(Storage storage layoutStruct_) internal view returns (bool) {
        return layoutStruct_.protocolNftInitialized;
    }

    function _protocolNftInitialized() internal view returns (bool) {
        return _protocolNftInitialized(_layoutStruct());
    }

    function _setProtocolNftInitialized(Storage storage layoutStruct_, bool value_) internal {
        layoutStruct_.protocolNftInitialized = value_;
    }

    function _setProtocolNftInitialized(bool value_) internal {
        _setProtocolNftInitialized(_layoutStruct(), value_);
    }

    function _reservedIdsWired(Storage storage layoutStruct_) internal view returns (bool) {
        return layoutStruct_.reservedIdsWired;
    }

    function _reservedIdsWired() internal view returns (bool) {
        return _reservedIdsWired(_layoutStruct());
    }

    function _setReservedIdsWired(Storage storage layoutStruct_, bool value_) internal {
        layoutStruct_.reservedIdsWired = value_;
    }

    function _setReservedIdsWired(bool value_) internal {
        _setReservedIdsWired(_layoutStruct(), value_);
    }

    /* ---------------------------------------------------------------------- */
    /*                            Token References                            */
    /* ---------------------------------------------------------------------- */

    function _detf(Storage storage layoutStruct_) internal view returns (IDetf) {
        return layoutStruct_.detf;
    }

    function _detf() internal view returns (IDetf) {
        return _detf(_layoutStruct());
    }

    function _lpToken(Storage storage layoutStruct_) internal view returns (IERC20) {
        return layoutStruct_.lpToken;
    }

    function _lpToken() internal view returns (IERC20) {
        return _lpToken(_layoutStruct());
    }

    function _rewardToken(Storage storage layoutStruct_) internal view returns (IERC20) {
        return layoutStruct_.rewardToken;
    }

    function _rewardToken() internal view returns (IERC20) {
        return _rewardToken(_layoutStruct());
    }

    function _decimalOffset(Storage storage layoutStruct_) internal view returns (uint8) {
        return layoutStruct_.decimalOffset;
    }

    function _decimalOffset() internal view returns (uint8) {
        return _decimalOffset(_layoutStruct());
    }

    function _detfNFTId(Storage storage layoutStruct_) internal view returns (uint256) {
        return layoutStruct_.detfNFTId;
    }

    function _detfNFTId() internal view returns (uint256) {
        return _detfNFTId(_layoutStruct());
    }

    /* ---------------------------------------------------------------------- */
    /*                          Share Accounting                              */
    /* ---------------------------------------------------------------------- */

    function _totalShares(Storage storage layoutStruct_) internal view returns (uint256) {
        return layoutStruct_.totalShares;
    }

    function _totalShares() internal view returns (uint256) {
        return _totalShares(_layoutStruct());
    }

    function _totalOriginalShares(Storage storage layoutStruct_) internal view returns (uint256) {
        return layoutStruct_.totalOriginalShares;
    }

    function _totalOriginalShares() internal view returns (uint256) {
        return _totalOriginalShares(_layoutStruct());
    }

    function _setTotalShares(Storage storage layoutStruct_, uint256 amount_) internal {
        layoutStruct_.totalShares = amount_;
    }

    function _originalSharesOf(Storage storage layoutStruct_, uint256 tokenId_) internal view returns (uint256) {
        return layoutStruct_.originalSharesOf[tokenId_];
    }

    function _originalSharesOf(uint256 tokenId_) internal view returns (uint256) {
        return _originalSharesOf(_layoutStruct(), tokenId_);
    }

    function _effectiveSharesOf(Storage storage layoutStruct_, uint256 tokenId_) internal view returns (uint256) {
        return layoutStruct_.effectiveSharesOf[tokenId_];
    }

    function _effectiveSharesOf(uint256 tokenId_) internal view returns (uint256) {
        return _effectiveSharesOf(_layoutStruct(), tokenId_);
    }

    function _unlockTimeOf(Storage storage layoutStruct_, uint256 tokenId_) internal view returns (uint256) {
        return layoutStruct_.unlockTimeOf[tokenId_];
    }

    function _unlockTimeOf(uint256 tokenId_) internal view returns (uint256) {
        return _unlockTimeOf(_layoutStruct(), tokenId_);
    }

    function _bonusMultiplierOf(Storage storage layoutStruct_, uint256 tokenId_) internal view returns (uint256) {
        return layoutStruct_.bonusMultiplierOf[tokenId_];
    }

    function _bonusMultiplierOf(uint256 tokenId_) internal view returns (uint256) {
        return _bonusMultiplierOf(_layoutStruct(), tokenId_);
    }

    /* ---------------------------------------------------------------------- */
    /*                          Reward Accounting                             */
    /* ---------------------------------------------------------------------- */

    function _rewardPerShares(Storage storage layoutStruct_) internal view returns (uint256) {
        return layoutStruct_.rewardPerShares;
    }

    function _rewardPerShares() internal view returns (uint256) {
        return _rewardPerShares(_layoutStruct());
    }

    function _lastRewardTokenBalance(Storage storage layoutStruct_) internal view returns (uint256) {
        return layoutStruct_.lastRewardTokenBalance;
    }

    function _lastRewardTokenBalance() internal view returns (uint256) {
        return _lastRewardTokenBalance(_layoutStruct());
    }

    function _setLastRewardTokenBalance(Storage storage layoutStruct_, uint256 amount_) internal {
        layoutStruct_.lastRewardTokenBalance = amount_;
    }

    function _userRewardPerSharePaid(Storage storage layoutStruct_, uint256 tokenId_) internal view returns (uint256) {
        return layoutStruct_.userRewardPerSharePaid[tokenId_];
    }

    function _userRewardPerSharePaid(uint256 tokenId_) internal view returns (uint256) {
        return _userRewardPerSharePaid(_layoutStruct(), tokenId_);
    }

    /* ---------------------------------------------------------------------- */
    /*                         Position Management                            */
    /* ---------------------------------------------------------------------- */

    function _nextTokenId(Storage storage layoutStruct_) internal view returns (uint256) {
        return layoutStruct_.nextTokenId;
    }

    function _nextTokenId() internal view returns (uint256) {
        return _nextTokenId(_layoutStruct());
    }

    function _incrementNextTokenId(Storage storage layoutStruct_) internal returns (uint256 tokenId_) {
        tokenId_ = layoutStruct_.nextTokenId;
        layoutStruct_.nextTokenId = tokenId_ + 1;
    }

    function _incrementNextTokenId() internal returns (uint256) {
        return _incrementNextTokenId(_layoutStruct());
    }

    function _createPosition(
        Storage storage layoutStruct_,
        uint256 tokenId_,
        uint256 originalShares_,
        uint256 effectiveShares_,
        uint256 bonusMultiplier_,
        uint256 unlockTime_
    ) internal {
        layoutStruct_.originalSharesOf[tokenId_] = originalShares_;
        layoutStruct_.effectiveSharesOf[tokenId_] = effectiveShares_;
        layoutStruct_.bonusMultiplierOf[tokenId_] = bonusMultiplier_;
        layoutStruct_.unlockTimeOf[tokenId_] = unlockTime_;
        layoutStruct_.userRewardPerSharePaid[tokenId_] = layoutStruct_.rewardPerShares;
        layoutStruct_.totalShares += effectiveShares_;
        layoutStruct_.totalOriginalShares += originalShares_;
    }

    function _createPosition(
        uint256 tokenId_,
        uint256 originalShares_,
        uint256 effectiveShares_,
        uint256 bonusMultiplier_,
        uint256 unlockTime_
    ) internal {
        _createPosition(_layoutStruct(), tokenId_, originalShares_, effectiveShares_, bonusMultiplier_, unlockTime_);
    }

    function _removePosition(Storage storage layoutStruct_, uint256 tokenId_) internal {
        layoutStruct_.totalShares -= layoutStruct_.effectiveSharesOf[tokenId_];
        layoutStruct_.totalOriginalShares -= layoutStruct_.originalSharesOf[tokenId_];
        delete layoutStruct_.originalSharesOf[tokenId_];
        delete layoutStruct_.effectiveSharesOf[tokenId_];
        delete layoutStruct_.bonusMultiplierOf[tokenId_];
        delete layoutStruct_.unlockTimeOf[tokenId_];
        delete layoutStruct_.userRewardPerSharePaid[tokenId_];
    }

    function _removePosition(uint256 tokenId_) internal {
        _removePosition(_layoutStruct(), tokenId_);
    }

    /**
     * @notice Adds LP to an existing position without affecting lock time.
     * @dev Used when adding to the protocol-owned NFT (sell-in, protocol compound BPT credit).
     *      Reward debt is kept consistent so new principal does not invent phantom pending:
     *      - First shares on a tokenId: set paid = current `rewardPerShares` (baseline).
     *      - Additional shares: preserve previously earned pending by re-basing paid on new effective.
     *      Callers should `_updateGlobalRewards` first (see `addToDETFNFT` / sell path).
     */
    function _addToPosition(Storage storage layoutStruct_, uint256 tokenId_, uint256 additionalShares_) internal {
        if (additionalShares_ == 0) return;

        uint256 oldEff_ = layoutStruct_.effectiveSharesOf[tokenId_];
        if (oldEff_ == 0) {
            // No prior stake: do not inherit historical rewardPerShares as claimable debt.
            layoutStruct_.userRewardPerSharePaid[tokenId_] = layoutStruct_.rewardPerShares;
            layoutStruct_.originalSharesOf[tokenId_] += additionalShares_;
            layoutStruct_.effectiveSharesOf[tokenId_] += additionalShares_;
            layoutStruct_.totalShares += additionalShares_;
            layoutStruct_.totalOriginalShares += additionalShares_;
            return;
        }

        // Preserve pending earned on old stake while increasing principal.
        uint256 pending_ = _earned(layoutStruct_, tokenId_);
        layoutStruct_.originalSharesOf[tokenId_] += additionalShares_;
        layoutStruct_.effectiveSharesOf[tokenId_] += additionalShares_;
        layoutStruct_.totalShares += additionalShares_;
        layoutStruct_.totalOriginalShares += additionalShares_;

        uint256 newEff_ = layoutStruct_.effectiveSharesOf[tokenId_];
        uint256 rps_ = layoutStruct_.rewardPerShares;
        // pending = newEff * (rps - paid) / 1e18  ⇒  paid = rps - pending * 1e18 / newEff
        if (newEff_ > 0 && pending_ > 0) {
            uint256 pendingPerShare_ = (pending_ * 1e18) / newEff_;
            layoutStruct_.userRewardPerSharePaid[tokenId_] =
                rps_ > pendingPerShare_ ? rps_ - pendingPerShare_ : 0;
        } else {
            layoutStruct_.userRewardPerSharePaid[tokenId_] = rps_;
        }
    }

    function _addToPosition(uint256 tokenId_, uint256 additionalShares_) internal {
        _addToPosition(_layoutStruct(), tokenId_, additionalShares_);
    }

    /// @notice L7: add effective-share weight only. Does not change `originalShares`.
    /// @dev Reward debt matches `_addToPosition` first/add paths so new shares do not claim old pot (FC4).
    function _addEffectiveSharesOnly(Storage storage layoutStruct_, uint256 tokenId_, uint256 additionalShares_)
        internal
    {
        if (additionalShares_ == 0) return;

        uint256 oldEff_ = layoutStruct_.effectiveSharesOf[tokenId_];
        if (oldEff_ == 0) {
            layoutStruct_.userRewardPerSharePaid[tokenId_] = layoutStruct_.rewardPerShares;
            layoutStruct_.effectiveSharesOf[tokenId_] += additionalShares_;
            layoutStruct_.totalShares += additionalShares_;
            return;
        }

        uint256 pending_ = _earned(layoutStruct_, tokenId_);
        layoutStruct_.effectiveSharesOf[tokenId_] += additionalShares_;
        layoutStruct_.totalShares += additionalShares_;

        uint256 newEff_ = layoutStruct_.effectiveSharesOf[tokenId_];
        uint256 rps_ = layoutStruct_.rewardPerShares;
        if (newEff_ > 0 && pending_ > 0) {
            uint256 pendingPerShare_ = (pending_ * 1e18) / newEff_;
            layoutStruct_.userRewardPerSharePaid[tokenId_] =
                rps_ > pendingPerShare_ ? rps_ - pendingPerShare_ : 0;
        } else {
            layoutStruct_.userRewardPerSharePaid[tokenId_] = rps_;
        }
    }

    function _addEffectiveSharesOnly(uint256 tokenId_, uint256 additionalShares_) internal {
        _addEffectiveSharesOnly(_layoutStruct(), tokenId_, additionalShares_);
    }

    error BondNotMature(uint256 unlockTime);
    error InsufficientOriginalShares(uint256 needed, uint256 available);

    /**
     * @notice Debits LP 1:1 from original and effective shares (inverse of `_addToPosition`).
     * @dev only protocol NFT. Preserves pending reward debt on remaining effective shares.
     */
    function _removeFromPosition(Storage storage layoutStruct_, uint256 tokenId_, uint256 shares_) internal {
        if (shares_ == 0) return;

        uint256 orig_ = layoutStruct_.originalSharesOf[tokenId_];
        if (shares_ > orig_) {
            revert InsufficientOriginalShares(shares_, orig_);
        }

        uint256 pending_ = _earned(layoutStruct_, tokenId_);
        layoutStruct_.originalSharesOf[tokenId_] -= shares_;
        layoutStruct_.effectiveSharesOf[tokenId_] -= shares_;
        layoutStruct_.totalShares -= shares_;
        layoutStruct_.totalOriginalShares -= shares_;

        uint256 newEff_ = layoutStruct_.effectiveSharesOf[tokenId_];
        uint256 rps_ = layoutStruct_.rewardPerShares;
        if (newEff_ > 0 && pending_ > 0) {
            uint256 pendingPerShare_ = (pending_ * 1e18) / newEff_;
            layoutStruct_.userRewardPerSharePaid[tokenId_] =
                rps_ > pendingPerShare_ ? rps_ - pendingPerShare_ : 0;
        } else {
            layoutStruct_.userRewardPerSharePaid[tokenId_] = rps_;
        }
    }

    function _removeFromPosition(uint256 tokenId_, uint256 shares_) internal {
        _removeFromPosition(_layoutStruct(), tokenId_, shares_);
    }

    /* ---------------------------------------------------------------------- */
    /*                          Share Conversion                              */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice LP inventory used for share↔asset conversion (alignment N10).
     * @dev Numerator is physical `lpToken.balanceOf(this)`. Denominator is `totalOriginalShares`.
     *      Do not use `totalShares` (effective) and do not subtract protocol / id 0 effective shares.
     *      Empty originalShares or empty physical LP is the 1:1 branch in `_convertToShares` /
     *      `_convertToAssets` (no diamond call). Diamond `reserveOfToken` is only for peers that
     *      still custody BPT on the DETF while originalShares are already non-zero.
     */
    function _totalLpReserveForConversion(Storage storage layoutStruct_)
        internal
        view
        returns (uint256 totalLpReserve_, uint256 totalShares_)
    {
        totalShares_ = layoutStruct_.totalOriginalShares;
        totalLpReserve_ = layoutStruct_.lpToken.balanceOf(address(this));
        if (totalLpReserve_ > 0) {
            return (totalLpReserve_, totalShares_);
        }
        if (totalShares_ == 0) {
            return (0, 0);
        }
        // Diamond-custody peers: BPT still on the DETF (not this NFT).
        totalLpReserve_ = IBasicVault(address(layoutStruct_.detf)).reserveOfToken(address(layoutStruct_.lpToken));
    }

    /**
     * @notice Converts LP token amount to shares using proportional math.
     */
    function _convertToShares(Storage storage layoutStruct_, uint256 lpAmount_) internal view returns (uint256 shares_) {
        (uint256 totalLpReserve, uint256 totalShares_) = _totalLpReserveForConversion(layoutStruct_);

        if (totalShares_ == 0 || totalLpReserve == 0) {
            shares_ = lpAmount_;
        } else {
            shares_ = BetterMath._convertToSharesUp(lpAmount_, totalLpReserve, totalShares_, layoutStruct_.decimalOffset);
        }
    }

    function _convertToShares(uint256 lpAmount_) internal view returns (uint256) {
        return _convertToShares(_layoutStruct(), lpAmount_);
    }

    /// @notice Convert inbound LP using a **pre-credit** physical LP snapshot (N10 / donate N4).
    /// @dev After LP has already landed, `convertToShares(ΔL)` would use L' and under-mint id 0.
    function _convertToSharesAtLpReserve(
        Storage storage layoutStruct_,
        uint256 lpAmount_,
        uint256 lpReserveBefore_
    ) internal view returns (uint256 shares_) {
        uint256 totalShares_ = layoutStruct_.totalOriginalShares;
        if (totalShares_ == 0 || lpReserveBefore_ == 0) {
            return lpAmount_;
        }
        shares_ = BetterMath._convertToSharesUp(
            lpAmount_, lpReserveBefore_, totalShares_, layoutStruct_.decimalOffset
        );
    }

    /**
     * @notice Converts shares back to LP token amount.
     */
    function _convertToAssets(Storage storage layoutStruct_, uint256 shares_) internal view returns (uint256 lpAmount_) {
        (uint256 totalLpReserve, uint256 totalShares_) = _totalLpReserveForConversion(layoutStruct_);

        if (totalShares_ == 0 || totalLpReserve == 0) {
            lpAmount_ = shares_;
        } else {
            lpAmount_ = BetterMath._convertToAssets(
                shares_, totalLpReserve, totalShares_, layoutStruct_.decimalOffset, Math.Rounding.Floor
            );
        }
    }

    function _convertToAssets(uint256 shares_) internal view returns (uint256) {
        return _convertToAssets(_layoutStruct(), shares_);
    }

    /* ---------------------------------------------------------------------- */
    /*                          Reward Calculations                           */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice Updates the global reward per share based on new reward deposits.
     */
    function _updateGlobalRewards(Storage storage layoutStruct_) internal {
        uint256 totalShares_ = layoutStruct_.totalShares;
        if (totalShares_ == 0) {
            return;
        }

        uint256 currentBalance = layoutStruct_.rewardToken.balanceOf(address(this));
        uint256 lastBalance = layoutStruct_.lastRewardTokenBalance;

        if (currentBalance > lastBalance) {
            uint256 newRewards = currentBalance - lastBalance;
            layoutStruct_.rewardPerShares += (newRewards * 1e18) / totalShares_;
            layoutStruct_.lastRewardTokenBalance = currentBalance;
        }
    }

    function _updateGlobalRewards() internal {
        _updateGlobalRewards(_layoutStruct());
    }

    /**
     * @notice Calculates pending rewards for a token ID.
     */
    function _earned(Storage storage layoutStruct_, uint256 tokenId_) internal view returns (uint256 pending_) {
        uint256 effectiveShares_ = layoutStruct_.effectiveSharesOf[tokenId_];
        if (effectiveShares_ == 0) {
            return 0;
        }

        uint256 rewardPerShare = layoutStruct_.rewardPerShares;

        // Include pending rewards not yet distributed
        uint256 totalShares_ = layoutStruct_.totalShares;
        if (totalShares_ > 0) {
            uint256 currentBalance = layoutStruct_.rewardToken.balanceOf(address(this));
            uint256 lastBalance = layoutStruct_.lastRewardTokenBalance;
            if (currentBalance > lastBalance) {
                uint256 newRewards = currentBalance - lastBalance;
                rewardPerShare += (newRewards * 1e18) / totalShares_;
            }
        }

        uint256 paidPerShare = layoutStruct_.userRewardPerSharePaid[tokenId_];
        if (rewardPerShare <= paidPerShare) {
            return 0;
        }

        pending_ = (effectiveShares_ * (rewardPerShare - paidPerShare)) / 1e18;
    }

    function _earned(uint256 tokenId_) internal view returns (uint256) {
        return _earned(_layoutStruct(), tokenId_);
    }

    /* ---------------------------------------------------------------------- */
    /*                          NFT Metadata                                  */
    /* ---------------------------------------------------------------------- */

    function _generateTokenURI(Storage storage layoutStruct_, uint256 tokenId_) internal view returns (string memory) {
        string memory svg = _buildSVG(layoutStruct_, tokenId_);
        string memory json = _buildJSON(tokenId_, svg);

        return string(abi.encodePacked(METADATA_JSON_PREFIX, Base64.encode(bytes(json))));
    }

    function _generateTokenURI(uint256 tokenId_) internal view returns (string memory) {
        return _generateTokenURI(_layoutStruct(), tokenId_);
    }

    function _buildSVG(Storage storage layoutStruct_, uint256 tokenId_) private view returns (string memory) {
        string memory svg = string.concat(SVG_IMAGE_PREFIX, SVG_IMAGE_TOKEN_ID_PREFIX, tokenId_.toString());

        string memory unlockStr;
        // Handle protocol NFT special case
        if (tokenId_ == layoutStruct_.detfNFTId) {
            unlockStr = "Protocol (No Lock)";
        } else {
            uint256 unlockTime_ = layoutStruct_.unlockTimeOf[tokenId_];
            unlockStr = block.timestamp >= unlockTime_ ? "Unlocked" : _formatDuration(unlockTime_ - block.timestamp);
        }
        svg = string.concat(svg, SVG_UNLOCK_PREFIX, unlockStr);

        uint256 effectiveShares_ = layoutStruct_.effectiveSharesOf[tokenId_];
        svg = string.concat(svg, SVG_SHARES_PREFIX, effectiveShares_.toString());

        uint256 pendingRewards = _earned(layoutStruct_, tokenId_);
        svg = string.concat(svg, SVG_REWARDS_PREFIX, pendingRewards.toString());

        svg = string.concat(svg, SVG_TEXT_CLOSE, SVG_IMAGE_CLOSE);
        // string memory svg = string(abi.encodePacked(
        //     SVG_IMAGE_PREFIX,
        //     SVG_IMAGE_TOKEN_ID_PREFIX,
        //     tokenId_.toString(),
        //     SVG_UNLOCK_PREFIX,
        //     unlockStr,
        //     SVG_SHARES_PREFIX,
        //     effectiveShares_.toString(),
        //     SVG_REWARDS_PREFIX,
        //     pendingRewards.toString(),
        //     SVG_TEXT_CLOSE,
        //     SVG_IMAGE_CLOSE
        // ));

        return svg;
    }

    function _buildJSON(uint256 tokenId_, string memory svg_) private pure returns (string memory) {
        return string(
            abi.encodePacked(
                JSON_NAME_PREFIX,
                tokenId_.toString(),
                JSON_NAME_SUFFIX,
                JSON_DESCRIPTION,
                JSON_IMAGE_PREFIX,
                Base64.encode(bytes(svg_)),
                '"}'
            )
        );
    }

    function _formatDuration(uint256 secs_) private pure returns (string memory) {
        if (secs_ == 0) return "0";
        uint256 d = secs_ / 86400;
        uint256 h = (secs_ % 86400) / 3600;
        uint256 m = (secs_ % 3600) / 60;

        if (d > 0) {
            return string(abi.encodePacked(d.toString(), "d ", h.toString(), "h"));
        }
        if (h > 0) {
            return string(abi.encodePacked(h.toString(), "h ", m.toString(), "m"));
        }
        return string(abi.encodePacked(m.toString(), "m"));
    }
}
