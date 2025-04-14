// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {Math} from "@crane/contracts/utils/Math.sol";

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {IERC20MintBurn} from "@crane/contracts/interfaces/IERC20MintBurn.sol";
import {LibString} from "@crane/contracts/utils/LibString.sol";
import {Base64} from "@crane/contracts/utils/Base64.sol";
import {BetterMath} from "@crane/contracts/utils/math/BetterMath.sol";
import {BetterSafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {ISeigniorageDETF} from "contracts/interfaces/ISeigniorageDETF.sol";
import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";

/* -------------------------------------------------------------------------- */
/*                              SVG Constants                                 */
/* -------------------------------------------------------------------------- */

string constant METADATA_JSON_PREFIX = "data:application/json;base64,";
string constant JSON_NAME_PREFIX = '{"name": "Pachira Seigniorage Bond NFT # ';
string constant JSON_NAME_SUFFIX = '", ';
string constant JSON_DESCRIPTION = '"description": "This NFT represents a Pachira seigniorage bond.",';
string constant JSON_IMAGE_PREFIX = '"image": "data:image/svg+xml;base64,';

string constant SVG_IMAGE_PREFIX =
    '<?xml version="1.0" encoding="UTF-8"?><svg viewBox="0 0 400 300" xmlns="http://www.w3.org/2000/svg">';

string constant PACHIRA_LOGO_SVG_SYMBOL =
    '<symbol id="pachira-logo" viewBox="0 0 120 32"><path d="m10.05 10.06c4.47-3.03 9.09-6.15 10.67-10.06 11.37 20.26 0 37.24-17.48 27.28-7.53-7.52-0.55-12.24 6.81-17.22zm4.46 3.82c-2.54 2.06-5.21 4.21-5.93 8.23 1.53-2.28 3.43-3.9 5.2-5.43 2.8-2.39 5.3-4.53 5.56-8.53-0.8 2.47-2.78 4.07-4.83 5.73z" clip-rule="evenodd" fill="#4FD44B" fill-rule="evenodd"/><path d="m15.13 20.65h8.44v8.44h-8.44v-8.44zm8.43 0h8.44v8.44h-8.44v-8.44zm0-8.43h8.44v8.44h-8.44v-8.44zm-2.91 5.53h2.91v2.91h-2.91v-2.91zm-0.87-1.17h1.45v1.45h-1.45v-1.45zm-4.65 12.51h2.91v2.91h-2.91v-2.91zm-2.91-2.91h2.91v2.91h-2.91v-2.91z" fill="#161717"/><path d="m26.47 20.95h2.91v2.91h-2.91v-2.91zm0-4.66h1.45v1.45h-1.45v-1.45zm-2.91-4.07h1.45v1.45h-1.45v-1.45zm-8.43 8.43h2.91v2.91h-2.91v-2.91zm4.07 4.37h2.91v2.91h-2.91v-2.91zm2.33-6.11h3.78v3.78h-3.78v-3.78zm2.03 4.95h1.45v1.45h-1.45v-1.45zm-8.43 2.32h2.91v2.91h-2.91v-2.91z" fill="#4FD44B"/><path d="m107.42 21.8 5.22-11.6h2.12l5.24 11.6h-2.25l-4.49-10.46h0.86l-4.48 10.46h-2.22zm2.41-2.68 0.58-1.69h6.26l0.58 1.69h-7.42zm-12.89 2.68v-11.6h4.78c1.02 0 1.9 0.17 2.63 0.5 0.74 0.33 1.31 0.8 1.71 1.42 0.39 0.62 0.59 1.36 0.59 2.21s-0.2 1.58-0.59 2.2c-0.4 0.61-0.97 1.08-1.71 1.41-0.73 0.32-1.61 0.48-2.63 0.48h-3.58l0.96-0.98v4.36h-2.16zm7.59 0-2.93-4.21h2.3l2.95 4.21h-2.32zm-5.43-4.13-0.96-1.02h3.48c0.95 0 1.66-0.21 2.13-0.62 0.49-0.4 0.73-0.97 0.73-1.7 0-0.74-0.24-1.31-0.73-1.71-0.47-0.4-1.18-0.6-2.13-0.6h-3.48l0.96-1.06v6.71zm-7.45 4.13v-11.6h2.15v11.6h-2.15zm-5.26-11.6h2.15v11.6h-2.15v-11.6zm-6 11.6h-2.15v-11.6h2.15v11.6zm6.16-4.97h-6.34v-1.84h6.34v1.84zm-14.99 5.14c-0.88 0-1.7-0.15-2.46-0.43-0.76-0.3-1.41-0.72-1.98-1.25-0.55-0.54-0.98-1.17-1.29-1.9s-0.46-1.53-0.46-2.39 0.15-1.66 0.46-2.39c0.31-0.72 0.75-1.35 1.31-1.88 0.56-0.55 1.22-0.96 1.97-1.25 0.75-0.3 1.58-0.44 2.47-0.44 0.95 0 1.82 0.16 2.6 0.49 0.79 0.32 1.45 0.8 1.99 1.44l-1.39 1.31c-0.42-0.45-0.89-0.79-1.41-1.01-0.52-0.23-1.08-0.35-1.69-0.35s-1.17 0.1-1.67 0.3-0.94 0.48-1.31 0.85c-0.37 0.36-0.65 0.79-0.86 1.29-0.2 0.5-0.3 1.04-0.3 1.64s0.1 1.14 0.3 1.64c0.21 0.5 0.49 0.93 0.86 1.29 0.37 0.37 0.81 0.65 1.31 0.85s1.06 0.3 1.67 0.3 1.17-0.11 1.69-0.33c0.52-0.24 0.99-0.58 1.41-1.05l1.39 1.33c-0.54 0.63-1.2 1.11-1.99 1.44-0.78 0.33-1.65 0.5-2.62 0.5zm-19.26-0.17 5.22-11.6h2.13l5.23 11.6h-2.25l-4.49-10.46h0.86l-4.47 10.46h-2.23zm2.41-2.68 0.58-1.69h6.26l0.58 1.69h-7.42zm-12.04 2.68v-11.6h4.77c1.03 0 1.9 0.17 2.63 0.5 0.74 0.33 1.31 0.8 1.71 1.42s0.6 1.36 0.6 2.21-0.2 1.58-0.6 2.2-0.97 1.09-1.71 1.43c-0.73 0.33-1.6 0.49-2.63 0.49h-3.58l0.96-1.01v4.36h-2.15zm2.15-4.13-0.96-1.04h3.48c0.95 0 1.66-0.2 2.14-0.6s0.73-0.97 0.73-1.7c0-0.74-0.25-1.31-0.73-1.71s-1.19-0.6-2.14-0.6h-3.48l0.96-1.06v6.71z" fill="#4FD44B"/></symbol>';

string constant SVG_IMAGE_TOKEN_ID_PREFIX =
    '<rect width="400" height="300" rx="10" ry="10"/><use x="130" y="10" width="120" height="32" href="#pachira-logo"/><text x="200" y="70" fill="#00ff00" font-family="Courier New, monospace" font-size="24" font-weight="bold" text-anchor="middle">Token ID:</text><text x="200" y="100" fill="#00ff00" font-family="Courier New, monospace" font-size="24" font-weight="bold" text-anchor="middle">';

string constant SVG_UNLOCK_PREFIX =
    '</text><text x="200" y="125" fill="#00ff00" font-family="Courier New, monospace" font-size="18" text-anchor="middle">Time until Unlock</text><text x="200" y="150" fill="#00ff00" font-family="Courier New, monospace" font-size="18" font-weight="bold" text-anchor="middle">';

string constant SVG_TOKEN_1_SYMBOL_PREFIX =
    '</text><rect x="50" y="170" width="150" height="100" rx="5" ry="5" fill="none" stroke="#0f0"/><text x="125" y="200" fill="#00ff00" font-family="Courier New, monospace" font-size="16" font-weight="bold" text-anchor="middle">';

string constant SVG_TOKEN_1_AMOUNT_PREFIX =
    '</text><text x="125" y="220" fill="#00ff00" font-family="Courier New, monospace" font-size="14" text-anchor="middle">Amount:</text><text x="125" y="250" fill="#00ff00" font-family="Courier New, monospace" font-size="14" text-anchor="middle">';

string constant SVG_TOKEN_2_SYMBOL_PREFIX =
    '</text><rect x="200" y="170" width="150" height="100" rx="5" ry="5" fill="none" stroke="#0f0"/><text x="275" y="200" fill="#00ff00" font-family="Courier New, monospace" font-size="16" font-weight="bold" text-anchor="middle">';

string constant SVG_TOKEN_2_AMOUNT_PREFIX =
    '</text><text x="275" y="220" fill="#00ff00" font-family="Courier New, monospace" font-size="14" text-anchor="middle">Amount:</text><text x="275" y="250" fill="#00ff00" font-family="Courier New, monospace" font-size="14" text-anchor="middle">';

string constant SVG_TEXT_CLOSE = "</text>";
string constant SVG_IMAGE_CLOSE = "</svg>";

/**
 * @title SeigniorageNFTVaultRepo
 * @author cyotee doge <not_cyotee@proton.me>
 * @notice Storage library for Seigniorage NFT Vault state.
 * @dev Follows the Crane Repo pattern with dual _layout() functions.
 *      Uses separate mappings for position data to match reference implementation.
 */
library SeigniorageNFTVaultRepo {
    using BetterSafeERC20 for IERC20Metadata;
    using LibString for uint256;

    bytes32 internal constant STORAGE_SLOT = keccak256("indexedex.vaults.seigniorage.nft");

    struct Storage {
        /// @notice The DETF token contract that owns this vault
        ISeigniorageDETF detfToken;
        /// @notice The claim token (underlying asset - rate target)
        IERC20 claimToken;
        /// @notice The LP token (BPT from reserve pool)
        IERC20 lpToken;
        /// @notice The reward token (sRBT - seigniorage rewards)
        IERC20MintBurn rewardToken;
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
        // uint256 minimumLockDuration;
        // /// @notice Maximum lock duration in seconds
        // uint256 maxLockDuration;
        // /// @notice Base bonus multiplier (scaled by 1e18, 1e18 = 1x)
        // uint256 baseBonusMultiplier;
        // /// @notice Maximum bonus multiplier (scaled by 1e18, 4e18 = 4x)
        // uint256 maxBonusMultiplier;
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
        ISeigniorageDETF detfToken_,
        IERC20 claimToken_,
        IERC20 lpToken_,
        IERC20MintBurn rewardToken_,
        uint8 decimalOffset_
        // uint256 minimumLockDuration_,
        // uint256 maxLockDuration_,
        // uint256 baseBonusMultiplier_,
        // uint256 maxBonusMultiplier_
    ) internal {
        layout_.detfToken = detfToken_;
        layout_.claimToken = claimToken_;
        layout_.lpToken = lpToken_;
        layout_.rewardToken = rewardToken_;
        layout_.decimalOffset = decimalOffset_;
        layout_.nextTokenId = 1;
        // layout_.maxLockDuration = maxLockDuration_;
        // layout_.baseBonusMultiplier = baseBonusMultiplier_;
        // layout_.maxBonusMultiplier = maxBonusMultiplier_;
    }

    function _initialize(
        ISeigniorageDETF detfToken_,
        IERC20 claimToken_,
        IERC20 lpToken_,
        IERC20MintBurn rewardToken_,
        uint8 decimalOffset_
        // uint256 maxLockDuration_,
        // uint256 baseBonusMultiplier_,
        // uint256 maxBonusMultiplier_
    ) internal {
        _initialize(
            _layout(),
            detfToken_,
            claimToken_,
            lpToken_,
            rewardToken_,
            decimalOffset_
            // maxLockDuration_,
            // baseBonusMultiplier_,
            // maxBonusMultiplier_
        );
    }

    /* ---------------------------------------------------------------------- */
    /*                            Token References                            */
    /* ---------------------------------------------------------------------- */

    function _detfToken(Storage storage layout_) internal view returns (ISeigniorageDETF) {
        return layout_.detfToken;
    }

    function _detfToken() internal view returns (ISeigniorageDETF) {
        return _detfToken(_layout());
    }

    function _claimToken(Storage storage layout_) internal view returns (IERC20) {
        return layout_.claimToken;
    }

    function _claimToken() internal view returns (IERC20) {
        return _claimToken(_layout());
    }

    function _lpToken(Storage storage layout_) internal view returns (IERC20) {
        return layout_.lpToken;
    }

    function _lpToken() internal view returns (IERC20) {
        return _lpToken(_layout());
    }

    function _rewardToken(Storage storage layout_) internal view returns (IERC20MintBurn) {
        return layout_.rewardToken;
    }

    function _rewardToken() internal view returns (IERC20MintBurn) {
        return _rewardToken(_layout());
    }

    function _decimalOffset(Storage storage layout_) internal view returns (uint8) {
        return layout_.decimalOffset;
    }

    function _decimalOffset() internal view returns (uint8) {
        return _decimalOffset(_layout());
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

    function _setTotalShares(uint256 amount_) internal {
        _setTotalShares(_layout(), amount_);
    }

    function _originalSharesOf(Storage storage layout_, uint256 tokenId_) internal view returns (uint256) {
        return layout_.originalSharesOf[tokenId_];
    }

    function _originalSharesOf(uint256 tokenId_) internal view returns (uint256) {
        return _originalSharesOf(_layout(), tokenId_);
    }

    function _setOriginalSharesOf(Storage storage layout_, uint256 tokenId_, uint256 shares_) internal {
        layout_.originalSharesOf[tokenId_] = shares_;
    }

    function _setOriginalSharesOf(uint256 tokenId_, uint256 shares_) internal {
        _setOriginalSharesOf(_layout(), tokenId_, shares_);
    }

    function _effectiveSharesOf(Storage storage layout_, uint256 tokenId_) internal view returns (uint256) {
        return layout_.effectiveSharesOf[tokenId_];
    }

    function _effectiveSharesOf(uint256 tokenId_) internal view returns (uint256) {
        return _effectiveSharesOf(_layout(), tokenId_);
    }

    function _setEffectiveSharesOf(Storage storage layout_, uint256 tokenId_, uint256 shares_) internal {
        layout_.effectiveSharesOf[tokenId_] = shares_;
    }

    function _setEffectiveSharesOf(uint256 tokenId_, uint256 shares_) internal {
        _setEffectiveSharesOf(_layout(), tokenId_, shares_);
    }

    function _unlockTimeOf(Storage storage layout_, uint256 tokenId_) internal view returns (uint256) {
        return layout_.unlockTimeOf[tokenId_];
    }

    function _unlockTimeOf(uint256 tokenId_) internal view returns (uint256) {
        return _unlockTimeOf(_layout(), tokenId_);
    }

    function _setUnlockTimeOf(Storage storage layout_, uint256 tokenId_, uint256 unlockTime_) internal {
        layout_.unlockTimeOf[tokenId_] = unlockTime_;
    }

    function _setUnlockTimeOf(uint256 tokenId_, uint256 unlockTime_) internal {
        _setUnlockTimeOf(_layout(), tokenId_, unlockTime_);
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

    function _setRewardPerShares(Storage storage layout_, uint256 amount_) internal {
        layout_.rewardPerShares = amount_;
    }

    function _setRewardPerShares(uint256 amount_) internal {
        _setRewardPerShares(_layout(), amount_);
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

    function _setLastRewardTokenBalance(uint256 amount_) internal {
        _setLastRewardTokenBalance(_layout(), amount_);
    }

    function _userRewardPerSharePaid(Storage storage layout_, uint256 tokenId_) internal view returns (uint256) {
        return layout_.userRewardPerSharePaid[tokenId_];
    }

    function _userRewardPerSharePaid(uint256 tokenId_) internal view returns (uint256) {
        return _userRewardPerSharePaid(_layout(), tokenId_);
    }

    function _setUserRewardPerSharePaid(Storage storage layout_, uint256 tokenId_, uint256 amount_) internal {
        layout_.userRewardPerSharePaid[tokenId_] = amount_;
    }

    function _setUserRewardPerSharePaid(uint256 tokenId_, uint256 amount_) internal {
        _setUserRewardPerSharePaid(_layout(), tokenId_, amount_);
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

    function _bonusMultiplierOf(Storage storage layout_, uint256 tokenId_) internal view returns (uint256) {
        return layout_.bonusMultiplierOf[tokenId_];
    }

    function _bonusMultiplierOf(uint256 tokenId_) internal view returns (uint256) {
        return _bonusMultiplierOf(_layout(), tokenId_);
    }

    function _removePosition(uint256 tokenId_) internal {
        _removePosition(_layout(), tokenId_);
    }

    /* ---------------------------------------------------------------------- */
    /*                         Bonus Configuration                            */
    /* ---------------------------------------------------------------------- */

    // function _maxLockDuration(Storage storage layout_) internal view returns (uint256) {
    //     return layout_.maxLockDuration;
    // }

    // function _maxLockDuration() internal view returns (uint256) {
    //     return _maxLockDuration(_layout());
    // }

    // function _baseBonusMultiplier(Storage storage layout_) internal view returns (uint256) {
    //     return layout_.baseBonusMultiplier;
    // }

    // function _baseBonusMultiplier() internal view returns (uint256) {
    //     return _baseBonusMultiplier(_layout());
    // }

    // function _maxBonusMultiplier(Storage storage layout_) internal view returns (uint256) {
    //     return layout_.maxBonusMultiplier;
    // }

    // function _maxBonusMultiplier() internal view returns (uint256) {
    //     return _maxBonusMultiplier(_layout());
    // }

    // TODO Move to Target contracts. Pull values from Vault Fee Oracle.
    // function _calcBonusMultiplier(Storage storage layout_, uint256 lockDuration_) internal view returns (uint256) {
    //     uint256 maxDuration = layout_.maxLockDuration;
    //     uint256 base = layout_.baseBonusMultiplier;
    //     uint256 maxBonus = layout_.maxBonusMultiplier;

    //     if (lockDuration_ >= maxDuration) {
    //         return maxBonus;
    //     }

    //     uint256 bonusRange = maxBonus - base;
    //     uint256 ratio = (lockDuration_ * 1e18) / maxDuration;
    //     uint256 quadraticRatio = (ratio * ratio) / 1e18;

    //     return base + (bonusRange * quadraticRatio) / 1e18;
    // }

    // function _calcBonusMultiplier(uint256 lockDuration_) internal view returns (uint256) {
    //     return _calcBonusMultiplier(_layout(), lockDuration_);
    // }

    /* ---------------------------------------------------------------------- */
    /*                          Share Conversion                              */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice Converts BPT amount to shares using a provided (pre-underwrite) BPT reserve.
     * @dev This avoids using the post-underwrite reserve, which would under-mint shares.
     * @param layout_ Storage layout reference
     * @param bptOut_ Amount of BPT minted by the underwrite
     * @param bptReserveBefore_ DETF's BPT reserve before the mint
     * @return shares_ The number of base shares to allocate
     */
    function _convertToSharesGivenReserve(Storage storage layout_, uint256 bptOut_, uint256 bptReserveBefore_)
        internal
        view
        returns (uint256 shares_)
    {
        uint256 totalShares_ = layout_.totalShares;

        if (totalShares_ == 0 || bptReserveBefore_ == 0) {
            shares_ = bptOut_;
        } else {
            shares_ = BetterMath._convertToSharesUp(bptOut_, bptReserveBefore_, totalShares_, layout_.decimalOffset);
        }
    }

    /**
     * @notice Converts LP token amount to shares using proportional math.
     * @dev Uses BetterMath._convertToSharesUp for proper decimal handling.
     * @param layout_ Storage layout reference
     * @param lpAmount_ Amount of LP tokens (BPT) to convert
     * @return shares_ The number of shares to allocate
     */
    function _convertToShares(Storage storage layout_, uint256 lpAmount_) internal view returns (uint256 shares_) {
        uint256 totalLpReserve = IBasicVault(address(layout_.detfToken)).reserveOfToken(address(layout_.lpToken));
        uint256 totalShares_ = layout_.totalShares;

        if (totalShares_ == 0 || totalLpReserve == 0) {
            // First deposit - shares = amount
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
     * @param layout_ Storage layout reference
     * @param shares_ Amount of shares to convert
     * @return lpAmount_ The equivalent LP token amount
     */
    function _convertToAssets(Storage storage layout_, uint256 shares_) internal view returns (uint256 lpAmount_) {
        uint256 totalLpReserve = IBasicVault(address(layout_.detfToken)).reserveOfToken(address(layout_.lpToken));
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
     * @dev Call this before any position modification.
     * @param layout_ Storage layout reference
     */
    function _updateGlobalRewards(Storage storage layout_) internal {
        uint256 totalShares_ = layout_.totalShares;
        if (totalShares_ == 0) {
            return;
        }

        uint256 currentBalance = IERC20(address(layout_.rewardToken)).balanceOf(address(this));
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
     * @param layout_ Storage layout reference
     * @param tokenId_ The NFT token ID
     * @return pending_ Amount of pending reward tokens
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
            uint256 currentBalance = IERC20(address(layout_.rewardToken)).balanceOf(address(this));
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
        string memory json = _buildJSON(layout_, tokenId_, svg);

        return string(abi.encodePacked(METADATA_JSON_PREFIX, Base64.encode(bytes(json))));
    }

    function _generateTokenURI(uint256 tokenId_) internal view returns (string memory) {
        return _generateTokenURI(_layout(), tokenId_);
    }

    function _buildSVG(Storage storage layout_, uint256 tokenId_) private view returns (string memory) {
        // Calculate values first to reduce stack pressure
        uint256 unlockTime_ = layout_.unlockTimeOf[tokenId_];
        // Calculate unlock string
        string memory unlockStr =
            block.timestamp >= unlockTime_ ? "Unlocked" : _formatDuration(unlockTime_ - block.timestamp);
        uint256 effectiveShares_ = layout_.effectiveSharesOf[tokenId_];
        uint256 portionOfLpReserve = _convertToAssets(layout_, effectiveShares_);
        uint256 claimAmount = layout_.detfToken.previewClaimLiquidity(portionOfLpReserve);

        // Build SVG in parts to avoid stack-too-deep
        string memory part1 = string(
            abi.encodePacked(
                SVG_IMAGE_PREFIX,
                PACHIRA_LOGO_SVG_SYMBOL,
                SVG_IMAGE_TOKEN_ID_PREFIX,
                tokenId_.toString(),
                SVG_UNLOCK_PREFIX,
                unlockStr
            )
        );

        string memory part2 = string(
            abi.encodePacked(
                SVG_TOKEN_1_SYMBOL_PREFIX,
                IERC20Metadata(address(layout_.claimToken)).safeSymbol(),
                SVG_TOKEN_1_AMOUNT_PREFIX,
                claimAmount.toString(),
                SVG_TOKEN_2_SYMBOL_PREFIX,
                IERC20Metadata(address(layout_.rewardToken)).safeSymbol()
            )
        );

        uint256 pendingRewards = _earned(layout_, tokenId_);
        string memory part3 = string(
            abi.encodePacked(SVG_TOKEN_2_AMOUNT_PREFIX, pendingRewards.toString(), SVG_TEXT_CLOSE, SVG_IMAGE_CLOSE)
        );

        return string(abi.encodePacked(part1, part2, part3));
    }

    function _buildJSON(Storage storage layout_, uint256 tokenId_, string memory svg_)
        private
        view
        returns (string memory)
    {
        // Pre-calculate values to reduce stack pressure
        uint256 originalShares_ = layout_.originalSharesOf[tokenId_];
        uint256 effectiveShares_ = layout_.effectiveSharesOf[tokenId_];
        uint256 unlockTime_ = layout_.unlockTimeOf[tokenId_];
        uint256 pendingRewards = _earned(layout_, tokenId_);

        // Build JSON in parts to avoid stack-too-deep
        string memory part1 = string(
            abi.encodePacked(
                JSON_NAME_PREFIX,
                tokenId_.toString(),
                JSON_NAME_SUFFIX,
                JSON_DESCRIPTION,
                JSON_IMAGE_PREFIX,
                Base64.encode(bytes(svg_))
            )
        );

        string memory part2 = string(
            abi.encodePacked(
                '","attributes":[{"trait_type":"Original Shares","value":',
                originalShares_.toString(),
                '},{"trait_type":"Effective Shares","value":',
                effectiveShares_.toString()
            )
        );

        string memory part3 = string(
            abi.encodePacked(
                '},{"trait_type":"Unlock Time","value":',
                unlockTime_.toString(),
                '},{"trait_type":"Pending Reward","value":',
                pendingRewards.toString(),
                "}]}"
            )
        );

        return string(abi.encodePacked(part1, part2, part3));
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
