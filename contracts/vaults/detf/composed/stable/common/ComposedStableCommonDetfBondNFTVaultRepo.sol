// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Math} from "@crane/contracts/utils/Math.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {ERC721Repo} from "@crane/contracts/tokens/ERC721/ERC721Repo.sol";
import {LibString} from "@crane/contracts/utils/LibString.sol";
import {Base64} from "@crane/contracts/utils/Base64.sol";
import {BetterMath} from "@crane/contracts/utils/math/BetterMath.sol";
import {BetterSafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";

import {IProtocolDETF} from "contracts/interfaces/IProtocolDETF.sol";
import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";

string constant CSCD_BOND_METADATA_JSON_PREFIX = "data:application/json;base64,";
string constant CSCD_BOND_JSON_NAME_PREFIX = '{"name": "Composed Stable Bond NFT # ';
string constant CSCD_BOND_JSON_NAME_SUFFIX = '", ';
string constant CSCD_BOND_JSON_DESCRIPTION =
    '"description": "This NFT represents a composed stable DETF bond position.",';
string constant CSCD_BOND_JSON_IMAGE_PREFIX = '"image": "data:image/svg+xml;base64,';
string constant CSCD_BOND_SVG_IMAGE_PREFIX =
    '<?xml version="1.0" encoding="UTF-8"?><svg viewBox="0 0 400 300" xmlns="http://www.w3.org/2000/svg">';
string constant CSCD_BOND_SVG_IMAGE_TOKEN_ID_PREFIX =
    '<rect width="400" height="300" rx="10" ry="10" fill="#102138"/><text x="200" y="40" fill="#b9ff6a" font-family="Courier New, monospace" font-size="18" font-weight="bold" text-anchor="middle">COMPOSED STABLE BOND</text><text x="200" y="70" fill="#b9ff6a" font-family="Courier New, monospace" font-size="24" font-weight="bold" text-anchor="middle">Token ID: ';
string constant CSCD_BOND_SVG_UNLOCK_PREFIX =
    '</text><text x="200" y="100" fill="#b9ff6a" font-family="Courier New, monospace" font-size="14" text-anchor="middle">Unlock: ';
string constant CSCD_BOND_SVG_SHARES_PREFIX =
    '</text><rect x="50" y="120" width="300" height="80" rx="5" ry="5" fill="none" stroke="#b9ff6a"/><text x="200" y="150" fill="#b9ff6a" font-family="Courier New, monospace" font-size="14" text-anchor="middle">Shares: ';
string constant CSCD_BOND_SVG_REWARDS_PREFIX =
    '</text><text x="200" y="180" fill="#b9ff6a" font-family="Courier New, monospace" font-size="14" text-anchor="middle">Pending Rewards: ';
string constant CSCD_BOND_SVG_TEXT_CLOSE = "</text>";
string constant CSCD_BOND_SVG_IMAGE_CLOSE = "</svg>";

library ComposedStableCommonDetfBondNFTVaultRepo {
    using BetterSafeERC20 for IERC20Metadata;
    using LibString for uint256;

    bytes32 internal constant STORAGE_SLOT = keccak256("indexedex.vaults.detf.composed.stable.common.bond.nft");

    struct Storage {
        IProtocolDETF protocolDETF;
        IERC20 lpToken;
        IERC20 rewardToken;
        uint256 deploymentTimestamp;
        uint256 lastRewardTokenBalance;
        uint256 totalShares;
        uint256 rewardPerShares;
        uint8 decimalOffset;
        mapping(uint256 tokenId => uint256 originalShares) originalSharesOf;
        mapping(uint256 tokenId => uint256 effectiveShares) effectiveSharesOf;
        mapping(uint256 tokenId => uint256 bonusMultiplier) bonusMultiplierOf;
        mapping(uint256 tokenId => uint256 unlockTime) unlockTimeOf;
        mapping(uint256 tokenId => uint256) userRewardPerSharePaid;
        uint256 nextTokenId;
        uint256 detfNFTId;
        uint256 feeRecipientNFTId;
        bool detfNFTSold;
    }

    function _layoutStruct(bytes32 slot_) internal pure returns (Storage storage layoutStruct_) {
        assembly {
            layoutStruct_.slot := slot_
        }
    }

    function _layoutStruct() internal pure returns (Storage storage) {
        return _layoutStruct(STORAGE_SLOT);
    }

    function _initialize(
        Storage storage layoutStruct_,
        IProtocolDETF protocolDETF_,
        IERC20 lpToken_,
        IERC20 rewardToken_,
        uint8 decimalOffset_
    ) internal {
        layoutStruct_.protocolDETF = protocolDETF_;
        layoutStruct_.lpToken = lpToken_;
        layoutStruct_.rewardToken = rewardToken_;
        layoutStruct_.deploymentTimestamp = block.timestamp;
        layoutStruct_.decimalOffset = decimalOffset_;
        layoutStruct_.nextTokenId = 1;
    }

    function _initialize(IProtocolDETF protocolDETF_, IERC20 lpToken_, IERC20 rewardToken_, uint8 decimalOffset_)
        internal
    {
        _initialize(_layoutStruct(), protocolDETF_, lpToken_, rewardToken_, decimalOffset_);
    }

    function _setDETFNFTId(Storage storage layoutStruct_, uint256 tokenId_) internal {
        layoutStruct_.detfNFTId = tokenId_;
    }

    function _setDETFNFTId(uint256 tokenId_) internal {
        _setDETFNFTId(_layoutStruct(), tokenId_);
    }

    function _setFeeRecipientNFTId(Storage storage layoutStruct_, uint256 tokenId_) internal {
        layoutStruct_.feeRecipientNFTId = tokenId_;
    }

    function _setFeeRecipientNFTId(uint256 tokenId_) internal {
        _setFeeRecipientNFTId(_layoutStruct(), tokenId_);
    }

    function _protocolDETF(Storage storage layoutStruct_) internal view returns (IProtocolDETF) {
        return layoutStruct_.protocolDETF;
    }

    function _protocolDETF() internal view returns (IProtocolDETF) {
        return _protocolDETF(_layoutStruct());
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

    function _feeRecipientNFTId(Storage storage layoutStruct_) internal view returns (uint256) {
        return layoutStruct_.feeRecipientNFTId;
    }

    function _feeRecipientNFTId() internal view returns (uint256) {
        return _feeRecipientNFTId(_layoutStruct());
    }

    function _deploymentTimestamp(Storage storage layoutStruct_) internal view returns (uint256) {
        return layoutStruct_.deploymentTimestamp;
    }

    function _deploymentTimestamp() internal view returns (uint256) {
        return _deploymentTimestamp(_layoutStruct());
    }

    function _setDETFNFTSold(Storage storage layoutStruct_, bool sold_) internal {
        layoutStruct_.detfNFTSold = sold_;
    }

    function _setDETFNFTSold(bool sold_) internal {
        _setDETFNFTSold(_layoutStruct(), sold_);
    }

    function _detfNFTSold(Storage storage layoutStruct_) internal view returns (bool) {
        return layoutStruct_.detfNFTSold;
    }

    function _detfNFTSold() internal view returns (bool) {
        return _detfNFTSold(_layoutStruct());
    }

    function _totalShares(Storage storage layoutStruct_) internal view returns (uint256) {
        return layoutStruct_.totalShares;
    }

    function _totalShares() internal view returns (uint256) {
        return _totalShares(_layoutStruct());
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
        delete layoutStruct_.originalSharesOf[tokenId_];
        delete layoutStruct_.effectiveSharesOf[tokenId_];
        delete layoutStruct_.bonusMultiplierOf[tokenId_];
        delete layoutStruct_.unlockTimeOf[tokenId_];
        delete layoutStruct_.userRewardPerSharePaid[tokenId_];
    }

    function _removePosition(uint256 tokenId_) internal {
        _removePosition(_layoutStruct(), tokenId_);
    }

    function _addToPosition(Storage storage layoutStruct_, uint256 tokenId_, uint256 additionalShares_) internal {
        layoutStruct_.originalSharesOf[tokenId_] += additionalShares_;
        layoutStruct_.effectiveSharesOf[tokenId_] += additionalShares_;
        layoutStruct_.totalShares += additionalShares_;
    }

    function _addToPosition(uint256 tokenId_, uint256 additionalShares_) internal {
        _addToPosition(_layoutStruct(), tokenId_, additionalShares_);
    }

    function _convertToShares(Storage storage layoutStruct_, uint256 lpAmount_) internal view returns (uint256 shares_) {
        uint256 totalLpReserve = IBasicVault(address(layoutStruct_.protocolDETF)).reserveOfToken(address(layoutStruct_.lpToken));
        uint256 totalShares_ = layoutStruct_.totalShares;

        if (totalShares_ == 0 || totalLpReserve == 0) {
            shares_ = lpAmount_;
        } else {
            shares_ = BetterMath._convertToSharesUp(lpAmount_, totalLpReserve, totalShares_, layoutStruct_.decimalOffset);
        }
    }

    function _convertToShares(uint256 lpAmount_) internal view returns (uint256) {
        return _convertToShares(_layoutStruct(), lpAmount_);
    }

    function _convertToAssets(Storage storage layoutStruct_, uint256 shares_) internal view returns (uint256 lpAmount_) {
        uint256 totalLpReserve = IBasicVault(address(layoutStruct_.protocolDETF)).reserveOfToken(address(layoutStruct_.lpToken));
        uint256 totalShares_ = layoutStruct_.totalShares;

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

    function _earned(Storage storage layoutStruct_, uint256 tokenId_) internal view returns (uint256 pending_) {
        uint256 effectiveShares_ = layoutStruct_.effectiveSharesOf[tokenId_];
        if (effectiveShares_ == 0) {
            return 0;
        }

        uint256 rewardPerShare = layoutStruct_.rewardPerShares;
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

    function _generateTokenURI(Storage storage layoutStruct_, uint256 tokenId_) internal view returns (string memory) {
        string memory svg = _buildSVG(layoutStruct_, tokenId_);
        string memory json = _buildJSON(tokenId_, svg);

        return string(abi.encodePacked(CSCD_BOND_METADATA_JSON_PREFIX, Base64.encode(bytes(json))));
    }

    function _generateTokenURI(uint256 tokenId_) internal view returns (string memory) {
        return _generateTokenURI(_layoutStruct(), tokenId_);
    }

    function _buildSVG(Storage storage layoutStruct_, uint256 tokenId_) private view returns (string memory) {
        string memory svg = string.concat(CSCD_BOND_SVG_IMAGE_PREFIX, CSCD_BOND_SVG_IMAGE_TOKEN_ID_PREFIX, tokenId_.toString());

        string memory unlockStr;
        if (tokenId_ == layoutStruct_.detfNFTId) {
            unlockStr = "Protocol (No Lock)";
        } else {
            uint256 unlockTime_ = layoutStruct_.unlockTimeOf[tokenId_];
            unlockStr = block.timestamp >= unlockTime_ ? "Unlocked" : _formatDuration(unlockTime_ - block.timestamp);
        }
        svg = string.concat(svg, CSCD_BOND_SVG_UNLOCK_PREFIX, unlockStr);

        uint256 effectiveShares_ = layoutStruct_.effectiveSharesOf[tokenId_];
        svg = string.concat(svg, CSCD_BOND_SVG_SHARES_PREFIX, effectiveShares_.toString());

        uint256 pendingRewards = _earned(layoutStruct_, tokenId_);
        svg = string.concat(svg, CSCD_BOND_SVG_REWARDS_PREFIX, pendingRewards.toString());

        svg = string.concat(svg, CSCD_BOND_SVG_TEXT_CLOSE, CSCD_BOND_SVG_IMAGE_CLOSE);
        return svg;
    }

    function _buildJSON(uint256 tokenId_, string memory svg_) private pure returns (string memory) {
        return string(
            abi.encodePacked(
                CSCD_BOND_JSON_NAME_PREFIX,
                tokenId_.toString(),
                CSCD_BOND_JSON_NAME_SUFFIX,
                CSCD_BOND_JSON_DESCRIPTION,
                CSCD_BOND_JSON_IMAGE_PREFIX,
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