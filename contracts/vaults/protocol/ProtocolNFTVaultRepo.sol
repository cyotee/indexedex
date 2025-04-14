// SPDX-License-Identifier: BUSL-1.1
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

import {IProtocolDETF} from "contracts/interfaces/IProtocolDETF.sol";
import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";

/* -------------------------------------------------------------------------- */
/*                              SVG Constants                                 */
/* -------------------------------------------------------------------------- */

string constant METADATA_JSON_PREFIX = "data:application/json;base64,";
string constant JSON_NAME_PREFIX = '{"name": "Protocol Bond NFT # ';
string constant JSON_NAME_SUFFIX = '", ';
string constant JSON_DESCRIPTION = '"description": "This NFT represents a Protocol DETF bond position.",';
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
    '</text><text x="200" y="180" fill="#00ff00" font-family="Courier New, monospace" font-size="14" text-anchor="middle">Pending RICH: ';

string constant SVG_TEXT_CLOSE = "</text>";
string constant SVG_IMAGE_CLOSE = "</svg>";

/**
 * @title ProtocolNFTVaultRepo
 * @author cyotee doge <not_cyotee@proton.me>
 * @notice Storage library for Protocol NFT Vault state.
 * @dev Follows the Crane Repo pattern with dual _layout() functions.
 *      Manages bond positions with:
 *      - Original shares (base LP allocation)
 *      - Effective shares (boosted by lock duration)
 *      - RICH rewards tracking
 *      - Protocol-owned NFT for accumulated positions
 */
library ProtocolNFTVaultRepo {
    using BetterSafeERC20 for IERC20Metadata;
    using LibString for uint256;

    bytes32 internal constant STORAGE_SLOT = keccak256("indexedex.vaults.protocol.nft");

    struct Storage {
        /// @notice The Protocol DETF contract
        IProtocolDETF protocolDETF;
        /// @notice The LP token (BPT from reserve pool)
        IERC20 lpToken;
        /// @notice The reward token (RICH)
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
        /// @notice Protocol-owned NFT token ID (has no unlock time)
        uint256 protocolNFTId;
        /// @notice Whether the protocol NFT has been sold (backing RICHIR)
        bool protocolNFTSold;
    }

    /* ---------------------------------------------------------------------- */
    /*                           Layout Functions                             */
    /* ---------------------------------------------------------------------- */

    function _layout(bytes32 slot_) internal pure returns (Storage storage layout_) {
        assembly {
            layout_.slot := slot_
        }
    }

    function _layout() internal pure returns (Storage storage) {
        return _layout(STORAGE_SLOT);
    }

    /* ---------------------------------------------------------------------- */
    /*                         Initialization                                 */
    /* ---------------------------------------------------------------------- */

    function _initialize(
        Storage storage layout_,
        IProtocolDETF protocolDETF_,
        IERC20 lpToken_,
        IERC20 rewardToken_,
        uint8 decimalOffset_
    ) internal {
        layout_.protocolDETF = protocolDETF_;
        layout_.lpToken = lpToken_;
        layout_.rewardToken = rewardToken_;
        layout_.decimalOffset = decimalOffset_;
        layout_.nextTokenId = 1;
    }

    function _initialize(IProtocolDETF protocolDETF_, IERC20 lpToken_, IERC20 rewardToken_, uint8 decimalOffset_)
        internal
    {
        _initialize(_layout(), protocolDETF_, lpToken_, rewardToken_, decimalOffset_);
    }

    function _setProtocolNFTId(Storage storage layout_, uint256 tokenId_) internal {
        layout_.protocolNFTId = tokenId_;
    }

    function _setProtocolNFTId(uint256 tokenId_) internal {
        _setProtocolNFTId(_layout(), tokenId_);
    }

    /* ---------------------------------------------------------------------- */
    /*                            Token References                            */
    /* ---------------------------------------------------------------------- */

    function _protocolDETF(Storage storage layout_) internal view returns (IProtocolDETF) {
        return layout_.protocolDETF;
    }

    function _protocolDETF() internal view returns (IProtocolDETF) {
        return _protocolDETF(_layout());
    }

    function _lpToken(Storage storage layout_) internal view returns (IERC20) {
        return layout_.lpToken;
    }

    function _lpToken() internal view returns (IERC20) {
        return _lpToken(_layout());
    }

    function _rewardToken(Storage storage layout_) internal view returns (IERC20) {
        return layout_.rewardToken;
    }

    function _rewardToken() internal view returns (IERC20) {
        return _rewardToken(_layout());
    }

    function _decimalOffset(Storage storage layout_) internal view returns (uint8) {
        return layout_.decimalOffset;
    }

    function _decimalOffset() internal view returns (uint8) {
        return _decimalOffset(_layout());
    }

    function _protocolNFTId(Storage storage layout_) internal view returns (uint256) {
        return layout_.protocolNFTId;
    }

    function _protocolNFTId() internal view returns (uint256) {
        return _protocolNFTId(_layout());
    }

    /* ---------------------------------------------------------------------- */
    /*                        Protocol NFT Sold Flag                           */
    /* ---------------------------------------------------------------------- */

    function _setProtocolNFTSold(Storage storage layout_, bool sold_) internal {
        layout_.protocolNFTSold = sold_;
    }

    function _setProtocolNFTSold(bool sold_) internal {
        _setProtocolNFTSold(_layout(), sold_);
    }

    function _protocolNFTSold(Storage storage layout_) internal view returns (bool) {
        return layout_.protocolNFTSold;
    }

    function _protocolNFTSold() internal view returns (bool) {
        return _protocolNFTSold(_layout());
    }

    /* ---------------------------------------------------------------------- */
    /*                          Share Accounting                              */
    /* ---------------------------------------------------------------------- */

    function _totalShares(Storage storage layout_) internal view returns (uint256) {
        return layout_.totalShares;
    }

    function _totalShares() internal view returns (uint256) {
        return _totalShares(_layout());
    }

    function _setTotalShares(Storage storage layout_, uint256 amount_) internal {
        layout_.totalShares = amount_;
    }

    function _originalSharesOf(Storage storage layout_, uint256 tokenId_) internal view returns (uint256) {
        return layout_.originalSharesOf[tokenId_];
    }

    function _originalSharesOf(uint256 tokenId_) internal view returns (uint256) {
        return _originalSharesOf(_layout(), tokenId_);
    }

    function _effectiveSharesOf(Storage storage layout_, uint256 tokenId_) internal view returns (uint256) {
        return layout_.effectiveSharesOf[tokenId_];
    }

    function _effectiveSharesOf(uint256 tokenId_) internal view returns (uint256) {
        return _effectiveSharesOf(_layout(), tokenId_);
    }

    function _unlockTimeOf(Storage storage layout_, uint256 tokenId_) internal view returns (uint256) {
        return layout_.unlockTimeOf[tokenId_];
    }

    function _unlockTimeOf(uint256 tokenId_) internal view returns (uint256) {
        return _unlockTimeOf(_layout(), tokenId_);
    }

    function _bonusMultiplierOf(Storage storage layout_, uint256 tokenId_) internal view returns (uint256) {
        return layout_.bonusMultiplierOf[tokenId_];
    }

    function _bonusMultiplierOf(uint256 tokenId_) internal view returns (uint256) {
        return _bonusMultiplierOf(_layout(), tokenId_);
    }

    /* ---------------------------------------------------------------------- */
    /*                          Reward Accounting                             */
    /* ---------------------------------------------------------------------- */

    function _rewardPerShares(Storage storage layout_) internal view returns (uint256) {
        return layout_.rewardPerShares;
    }

    function _rewardPerShares() internal view returns (uint256) {
        return _rewardPerShares(_layout());
    }

    function _lastRewardTokenBalance(Storage storage layout_) internal view returns (uint256) {
        return layout_.lastRewardTokenBalance;
    }

    function _lastRewardTokenBalance() internal view returns (uint256) {
        return _lastRewardTokenBalance(_layout());
    }

    function _setLastRewardTokenBalance(Storage storage layout_, uint256 amount_) internal {
        layout_.lastRewardTokenBalance = amount_;
    }

    function _userRewardPerSharePaid(Storage storage layout_, uint256 tokenId_) internal view returns (uint256) {
        return layout_.userRewardPerSharePaid[tokenId_];
    }

    function _userRewardPerSharePaid(uint256 tokenId_) internal view returns (uint256) {
        return _userRewardPerSharePaid(_layout(), tokenId_);
    }

    /* ---------------------------------------------------------------------- */
    /*                         Position Management                            */
    /* ---------------------------------------------------------------------- */

    function _nextTokenId(Storage storage layout_) internal view returns (uint256) {
        return layout_.nextTokenId;
    }

    function _nextTokenId() internal view returns (uint256) {
        return _nextTokenId(_layout());
    }

    function _incrementNextTokenId(Storage storage layout_) internal returns (uint256 tokenId_) {
        tokenId_ = layout_.nextTokenId;
        layout_.nextTokenId = tokenId_ + 1;
    }

    function _incrementNextTokenId() internal returns (uint256) {
        return _incrementNextTokenId(_layout());
    }

    function _createPosition(
        Storage storage layout_,
        uint256 tokenId_,
        uint256 originalShares_,
        uint256 effectiveShares_,
        uint256 bonusMultiplier_,
        uint256 unlockTime_
    ) internal {
        layout_.originalSharesOf[tokenId_] = originalShares_;
        layout_.effectiveSharesOf[tokenId_] = effectiveShares_;
        layout_.bonusMultiplierOf[tokenId_] = bonusMultiplier_;
        layout_.unlockTimeOf[tokenId_] = unlockTime_;
        layout_.userRewardPerSharePaid[tokenId_] = layout_.rewardPerShares;
        layout_.totalShares += effectiveShares_;
    }

    function _createPosition(
        uint256 tokenId_,
        uint256 originalShares_,
        uint256 effectiveShares_,
        uint256 bonusMultiplier_,
        uint256 unlockTime_
    ) internal {
        _createPosition(_layout(), tokenId_, originalShares_, effectiveShares_, bonusMultiplier_, unlockTime_);
    }

    function _removePosition(Storage storage layout_, uint256 tokenId_) internal {
        layout_.totalShares -= layout_.effectiveSharesOf[tokenId_];
        delete layout_.originalSharesOf[tokenId_];
        delete layout_.effectiveSharesOf[tokenId_];
        delete layout_.bonusMultiplierOf[tokenId_];
        delete layout_.unlockTimeOf[tokenId_];
        delete layout_.userRewardPerSharePaid[tokenId_];
    }

    function _removePosition(uint256 tokenId_) internal {
        _removePosition(_layout(), tokenId_);
    }

    /**
     * @notice Adds LP to an existing position without affecting lock time.
     * @dev Used when adding to the protocol-owned NFT.
     */
    function _addToPosition(Storage storage layout_, uint256 tokenId_, uint256 additionalShares_) internal {
        layout_.originalSharesOf[tokenId_] += additionalShares_;
        layout_.effectiveSharesOf[tokenId_] += additionalShares_;
        layout_.totalShares += additionalShares_;
    }

    function _addToPosition(uint256 tokenId_, uint256 additionalShares_) internal {
        _addToPosition(_layout(), tokenId_, additionalShares_);
    }

    /* ---------------------------------------------------------------------- */
    /*                          Share Conversion                              */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice Converts LP token amount to shares using proportional math.
     */
    function _convertToShares(Storage storage layout_, uint256 lpAmount_) internal view returns (uint256 shares_) {
        uint256 totalLpReserve = IBasicVault(address(layout_.protocolDETF)).reserveOfToken(address(layout_.lpToken));
        uint256 totalShares_ = layout_.totalShares;

        if (totalShares_ == 0 || totalLpReserve == 0) {
            shares_ = lpAmount_;
        } else {
            shares_ = BetterMath._convertToSharesUp(lpAmount_, totalLpReserve, totalShares_, layout_.decimalOffset);
        }
    }

    function _convertToShares(uint256 lpAmount_) internal view returns (uint256) {
        return _convertToShares(_layout(), lpAmount_);
    }

    /**
     * @notice Converts shares back to LP token amount.
     */
    function _convertToAssets(Storage storage layout_, uint256 shares_) internal view returns (uint256 lpAmount_) {
        uint256 totalLpReserve = IBasicVault(address(layout_.protocolDETF)).reserveOfToken(address(layout_.lpToken));
        uint256 totalShares_ = layout_.totalShares;

        if (totalShares_ == 0 || totalLpReserve == 0) {
            lpAmount_ = shares_;
        } else {
            lpAmount_ = BetterMath._convertToAssets(
                shares_, totalLpReserve, totalShares_, layout_.decimalOffset, Math.Rounding.Floor
            );
        }
    }

    function _convertToAssets(uint256 shares_) internal view returns (uint256) {
        return _convertToAssets(_layout(), shares_);
    }

    /* ---------------------------------------------------------------------- */
    /*                          Reward Calculations                           */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice Updates the global reward per share based on new reward deposits.
     */
    function _updateGlobalRewards(Storage storage layout_) internal {
        uint256 totalShares_ = layout_.totalShares;
        if (totalShares_ == 0) {
            return;
        }

        uint256 currentBalance = layout_.rewardToken.balanceOf(address(this));
        uint256 lastBalance = layout_.lastRewardTokenBalance;

        if (currentBalance > lastBalance) {
            uint256 newRewards = currentBalance - lastBalance;
            layout_.rewardPerShares += (newRewards * 1e18) / totalShares_;
            layout_.lastRewardTokenBalance = currentBalance;
        }
    }

    function _updateGlobalRewards() internal {
        _updateGlobalRewards(_layout());
    }

    /**
     * @notice Calculates pending rewards for a token ID.
     */
    function _earned(Storage storage layout_, uint256 tokenId_) internal view returns (uint256 pending_) {
        uint256 effectiveShares_ = layout_.effectiveSharesOf[tokenId_];
        if (effectiveShares_ == 0) {
            return 0;
        }

        uint256 rewardPerShare = layout_.rewardPerShares;

        // Include pending rewards not yet distributed
        uint256 totalShares_ = layout_.totalShares;
        if (totalShares_ > 0) {
            uint256 currentBalance = layout_.rewardToken.balanceOf(address(this));
            uint256 lastBalance = layout_.lastRewardTokenBalance;
            if (currentBalance > lastBalance) {
                uint256 newRewards = currentBalance - lastBalance;
                rewardPerShare += (newRewards * 1e18) / totalShares_;
            }
        }

        uint256 paidPerShare = layout_.userRewardPerSharePaid[tokenId_];
        if (rewardPerShare <= paidPerShare) {
            return 0;
        }

        pending_ = (effectiveShares_ * (rewardPerShare - paidPerShare)) / 1e18;
    }

    function _earned(uint256 tokenId_) internal view returns (uint256) {
        return _earned(_layout(), tokenId_);
    }

    /* ---------------------------------------------------------------------- */
    /*                          NFT Metadata                                  */
    /* ---------------------------------------------------------------------- */

    function _generateTokenURI(Storage storage layout_, uint256 tokenId_) internal view returns (string memory) {
        string memory svg = _buildSVG(layout_, tokenId_);
        string memory json = _buildJSON(tokenId_, svg);

        return string(abi.encodePacked(METADATA_JSON_PREFIX, Base64.encode(bytes(json))));
    }

    function _generateTokenURI(uint256 tokenId_) internal view returns (string memory) {
        return _generateTokenURI(_layout(), tokenId_);
    }

    function _buildSVG(Storage storage layout_, uint256 tokenId_) private view returns (string memory) {
        string memory svg = string.concat(SVG_IMAGE_PREFIX, SVG_IMAGE_TOKEN_ID_PREFIX, tokenId_.toString());

        string memory unlockStr;
        // Handle protocol NFT special case
        if (tokenId_ == layout_.protocolNFTId) {
            unlockStr = "Protocol (No Lock)";
        } else {
            uint256 unlockTime_ = layout_.unlockTimeOf[tokenId_];
            unlockStr = block.timestamp >= unlockTime_ ? "Unlocked" : _formatDuration(unlockTime_ - block.timestamp);
        }
        svg = string.concat(svg, SVG_UNLOCK_PREFIX, unlockStr);

        uint256 effectiveShares_ = layout_.effectiveSharesOf[tokenId_];
        svg = string.concat(svg, SVG_SHARES_PREFIX, effectiveShares_.toString());

        uint256 pendingRewards = _earned(layout_, tokenId_);
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
