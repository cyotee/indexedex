// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {Math} from "@crane/contracts/utils/Math.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IProtocolDETF} from "contracts/interfaces/IProtocolDETF.sol";
import {IDETFNFTVault} from "contracts/interfaces/IDETFNFTVault.sol";

/**
 * @title RebasingClaimTokenRepo
 * @author cyotee doge <not_cyotee@proton.me>
 * @notice Storage library for rebasing claim token rebasing token state.
 * @dev Follows the Crane Repo pattern with dual _layoutStruct() functions.
 *
 *      rebasing claim token is a rebasing token where balanceOf() returns different values
 *      over time based on the current spot redemption value of underlying shares.
 *
 *      Storage model:
 *      - sharesOf[user]: Only changes on mint/burn (constant between transfers)
 *      - totalShares: Only changes on mint/burn
 *      - balanceOf(user): Computed live as sharesOf * redemptionRate
 *      - totalSupply(): Computed live as totalShares * redemptionRate
 */
library RebasingClaimTokenRepo {
    using Math for uint256;

    bytes32 internal constant STORAGE_SLOT = keccak256("indexedex.vaults.protocol.richir");

    uint256 internal constant SHARE_SCALE = 1e9;
    uint256 internal constant SHARE_UNIT = 1e18 * SHARE_SCALE;

    function _shareScale() internal pure returns (uint256) {
        return SHARE_SCALE;
    }

    function _shareUnit() internal pure returns (uint256) {
        return SHARE_UNIT;
    }

    struct Storage {
        /// @notice The Protocol DETF contract (CHIR)
        IProtocolDETF protocolDETF;

        /// @notice The Protocol NFT Vault contract
        IDETFNFTVault nftVault;

        /// @notice The WETH token
        IERC20 rateAsset;

        /// @notice The protocol-owned NFT token ID held by this contract
        uint256 detfNFTId;

        /// @notice Total underlying shares (scaled by SHARE_SCALE for internal precision)
        uint256 totalShares;

        /// @notice Underlying shares per account (scaled by SHARE_SCALE)
        mapping(address account => uint256 shares) sharesOf;

        /// @notice Cached redemption rate (updated on each interaction)
        uint256 cachedRedemptionRate;

        /// @notice Last block when redemption rate was updated
        uint256 lastRateUpdateBlock;
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
        IProtocolDETF protocolDETF_,
        IDETFNFTVault nftVault_,
        IERC20 rateAsset_,
        uint256 detfNFTId_
    ) internal {
        layoutStruct_.protocolDETF = protocolDETF_;
        layoutStruct_.nftVault = nftVault_;
        layoutStruct_.rateAsset = rateAsset_;
        layoutStruct_.detfNFTId = detfNFTId_;
        layoutStruct_.cachedRedemptionRate = 1e18; // Start at 1:1
    }

    function _initialize(
        IProtocolDETF protocolDETF_,
        IDETFNFTVault nftVault_,
        IERC20 rateAsset_,
        uint256 detfNFTId_
    ) internal {
        _initialize(_layoutStruct(), protocolDETF_, nftVault_, rateAsset_, detfNFTId_);
    }

    /* ---------------------------------------------------------------------- */
    /*                         Contract References                            */
    /* ---------------------------------------------------------------------- */

    function _protocolDETF(Storage storage layoutStruct_) internal view returns (IProtocolDETF) {
        return layoutStruct_.protocolDETF;
    }

    function _protocolDETF() internal view returns (IProtocolDETF) {
        return _protocolDETF(_layoutStruct());
    }

    function _setProtocolDETF(Storage storage layoutStruct_, IProtocolDETF protocolDETF_) internal {
        layoutStruct_.protocolDETF = protocolDETF_;
    }

    function _setProtocolDETF(IProtocolDETF protocolDETF_) internal {
        _setProtocolDETF(_layoutStruct(), protocolDETF_);
    }

    function _nftVault(Storage storage layoutStruct_) internal view returns (IDETFNFTVault) {
        return layoutStruct_.nftVault;
    }

    function _nftVault() internal view returns (IDETFNFTVault) {
        return _nftVault(_layoutStruct());
    }

    function _rateAsset(Storage storage layoutStruct_) internal view returns (IERC20) {
        return layoutStruct_.rateAsset;
    }

    function _rateAsset() internal view returns (IERC20) {
        return _rateAsset(_layoutStruct());
    }

    function _detfNFTId(Storage storage layoutStruct_) internal view returns (uint256) {
        return layoutStruct_.detfNFTId;
    }

    function _detfNFTId() internal view returns (uint256) {
        return _detfNFTId(_layoutStruct());
    }

    /* ---------------------------------------------------------------------- */
    /*                         Share Accounting                               */
    /* ---------------------------------------------------------------------- */

    function _totalShares(Storage storage layoutStruct_) internal view returns (uint256) {
        return layoutStruct_.totalShares;
    }

    function _totalShares() internal view returns (uint256) {
        return _totalShares(_layoutStruct());
    }

    function _setTotalShares(Storage storage layoutStruct_, uint256 amount_) internal {
        layoutStruct_.totalShares = amount_;
    }

    function _setTotalShares(uint256 amount_) internal {
        _setTotalShares(_layoutStruct(), amount_);
    }

    function _sharesOf(Storage storage layoutStruct_, address account_) internal view returns (uint256) {
        return layoutStruct_.sharesOf[account_];
    }

    function _sharesOf(address account_) internal view returns (uint256) {
        return _sharesOf(_layoutStruct(), account_);
    }

    function _setSharesOf(Storage storage layoutStruct_, address account_, uint256 shares_) internal {
        layoutStruct_.sharesOf[account_] = shares_;
    }

    function _setSharesOf(address account_, uint256 shares_) internal {
        _setSharesOf(_layoutStruct(), account_, shares_);
    }

    /* ---------------------------------------------------------------------- */
    /*                         Redemption Rate                                */
    /* ---------------------------------------------------------------------- */

    function _cachedRedemptionRate(Storage storage layoutStruct_) internal view returns (uint256) {
        return layoutStruct_.cachedRedemptionRate;
    }

    function _cachedRedemptionRate() internal view returns (uint256) {
        return _cachedRedemptionRate(_layoutStruct());
    }

    function _setCachedRedemptionRate(Storage storage layoutStruct_, uint256 rate_) internal {
        layoutStruct_.cachedRedemptionRate = rate_;
        layoutStruct_.lastRateUpdateBlock = block.number;
    }

    function _setCachedRedemptionRate(uint256 rate_) internal {
        _setCachedRedemptionRate(_layoutStruct(), rate_);
    }

    function _lastRateUpdateBlock(Storage storage layoutStruct_) internal view returns (uint256) {
        return layoutStruct_.lastRateUpdateBlock;
    }

    function _lastRateUpdateBlock() internal view returns (uint256) {
        return _lastRateUpdateBlock(_layoutStruct());
    }

    /* ---------------------------------------------------------------------- */
    /*                         Mint/Burn Operations                           */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice Mints shares to an account.
     * @dev Only affects shares, not balanceOf (which is computed).
     */
    function _mintShares(Storage storage layoutStruct_, address account_, uint256 shares_) internal {
        layoutStruct_.sharesOf[account_] += shares_;
        layoutStruct_.totalShares += shares_;
    }

    function _mintShares(address account_, uint256 shares_) internal {
        _mintShares(_layoutStruct(), account_, shares_);
    }

    /**
     * @notice Burns shares from an account.
     * @dev Only affects shares, not balanceOf (which is computed).
     */
    function _burnShares(Storage storage layoutStruct_, address account_, uint256 shares_) internal {
        require(layoutStruct_.sharesOf[account_] >= shares_, "RebasingClaim: insufficient shares");
        layoutStruct_.sharesOf[account_] -= shares_;
        layoutStruct_.totalShares -= shares_;
    }

    function _burnShares(address account_, uint256 shares_) internal {
        _burnShares(_layoutStruct(), account_, shares_);
    }

    /**
     * @notice Transfers shares between accounts.
     * @dev Used internally by ERC20 transfer functions.
     */
    function _transferShares(Storage storage layoutStruct_, address from_, address to_, uint256 shares_) internal {
        require(layoutStruct_.sharesOf[from_] >= shares_, "RebasingClaim: insufficient shares");
        layoutStruct_.sharesOf[from_] -= shares_;
        layoutStruct_.sharesOf[to_] += shares_;
    }

    function _transferShares(address from_, address to_, uint256 shares_) internal {
        _transferShares(_layoutStruct(), from_, to_, shares_);
    }

    /* ---------------------------------------------------------------------- */
    /*                         Balance Calculations                           */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice Converts external share units to internal precision units.
     */
    function _externalSharesToInternal(uint256 externalShares_) internal pure returns (uint256) {
        return externalShares_ * SHARE_SCALE;
    }

    /**
     * @notice Converts internal share units to external share units (floor).
     */
    function _internalSharesToExternal(uint256 internalShares_) internal pure returns (uint256) {
        return internalShares_ / SHARE_SCALE;
    }

    /**
     * @notice Calculates the rebasing claim token balance from shares.
     * @dev balance = internalShares * redemptionRate / SHARE_UNIT
     */
    function _sharesToBalance(uint256 internalShares_, uint256 redemptionRate_) internal pure returns (uint256) {
        return internalShares_.mulDiv(redemptionRate_, SHARE_UNIT);
    }

    /**
     * @notice Calculates shares from rebasing claim token balance.
     * @dev internalShares = balance * SHARE_UNIT / redemptionRate
     */
    function _balanceToShares(uint256 balance_, uint256 redemptionRate_) internal pure returns (uint256) {
        if (redemptionRate_ == 0) return 0;
        return balance_.mulDiv(SHARE_UNIT, redemptionRate_);
    }
}
