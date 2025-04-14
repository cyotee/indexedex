// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IProtocolDETF} from "contracts/interfaces/IProtocolDETF.sol";
import {IProtocolNFTVault} from "contracts/interfaces/IProtocolNFTVault.sol";

/**
 * @title RICHIRRepo
 * @author cyotee doge <not_cyotee@proton.me>
 * @notice Storage library for RICHIR rebasing token state.
 * @dev Follows the Crane Repo pattern with dual _layout() functions.
 *
 *      RICHIR is a rebasing token where balanceOf() returns different values
 *      over time based on the current spot redemption value of underlying shares.
 *
 *      Storage model:
 *      - sharesOf[user]: Only changes on mint/burn (constant between transfers)
 *      - totalShares: Only changes on mint/burn
 *      - balanceOf(user): Computed live as sharesOf * redemptionRate
 *      - totalSupply(): Computed live as totalShares * redemptionRate
 */
library RICHIRRepo {
    bytes32 internal constant STORAGE_SLOT = keccak256("indexedex.vaults.protocol.richir");

    struct Storage {
        /// @notice The Protocol DETF contract (CHIR)
        IProtocolDETF protocolDETF;

        /// @notice The Protocol NFT Vault contract
        IProtocolNFTVault nftVault;

        /// @notice The WETH token
        IERC20 wethToken;

        /// @notice The protocol-owned NFT token ID held by this contract
        uint256 protocolNFTId;

        /// @notice Total underlying shares
        uint256 totalShares;

        /// @notice Underlying shares per account (constant between transfers)
        mapping(address account => uint256 shares) sharesOf;

        /// @notice Cached redemption rate (updated on each interaction)
        uint256 cachedRedemptionRate;

        /// @notice Last block when redemption rate was updated
        uint256 lastRateUpdateBlock;
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
        IProtocolNFTVault nftVault_,
        IERC20 wethToken_,
        uint256 protocolNFTId_
    ) internal {
        layout_.protocolDETF = protocolDETF_;
        layout_.nftVault = nftVault_;
        layout_.wethToken = wethToken_;
        layout_.protocolNFTId = protocolNFTId_;
        layout_.cachedRedemptionRate = 1e18; // Start at 1:1
    }

    function _initialize(
        IProtocolDETF protocolDETF_,
        IProtocolNFTVault nftVault_,
        IERC20 wethToken_,
        uint256 protocolNFTId_
    ) internal {
        _initialize(_layout(), protocolDETF_, nftVault_, wethToken_, protocolNFTId_);
    }

    /* ---------------------------------------------------------------------- */
    /*                         Contract References                            */
    /* ---------------------------------------------------------------------- */

    function _protocolDETF(Storage storage layout_) internal view returns (IProtocolDETF) {
        return layout_.protocolDETF;
    }

    function _protocolDETF() internal view returns (IProtocolDETF) {
        return _protocolDETF(_layout());
    }

    function _nftVault(Storage storage layout_) internal view returns (IProtocolNFTVault) {
        return layout_.nftVault;
    }

    function _nftVault() internal view returns (IProtocolNFTVault) {
        return _nftVault(_layout());
    }

    function _wethToken(Storage storage layout_) internal view returns (IERC20) {
        return layout_.wethToken;
    }

    function _wethToken() internal view returns (IERC20) {
        return _wethToken(_layout());
    }

    function _protocolNFTId(Storage storage layout_) internal view returns (uint256) {
        return layout_.protocolNFTId;
    }

    function _protocolNFTId() internal view returns (uint256) {
        return _protocolNFTId(_layout());
    }

    /* ---------------------------------------------------------------------- */
    /*                         Share Accounting                               */
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

    function _sharesOf(Storage storage layout_, address account_) internal view returns (uint256) {
        return layout_.sharesOf[account_];
    }

    function _sharesOf(address account_) internal view returns (uint256) {
        return _sharesOf(_layout(), account_);
    }

    function _setSharesOf(Storage storage layout_, address account_, uint256 shares_) internal {
        layout_.sharesOf[account_] = shares_;
    }

    function _setSharesOf(address account_, uint256 shares_) internal {
        _setSharesOf(_layout(), account_, shares_);
    }

    /* ---------------------------------------------------------------------- */
    /*                         Redemption Rate                                */
    /* ---------------------------------------------------------------------- */

    function _cachedRedemptionRate(Storage storage layout_) internal view returns (uint256) {
        return layout_.cachedRedemptionRate;
    }

    function _cachedRedemptionRate() internal view returns (uint256) {
        return _cachedRedemptionRate(_layout());
    }

    function _setCachedRedemptionRate(Storage storage layout_, uint256 rate_) internal {
        layout_.cachedRedemptionRate = rate_;
        layout_.lastRateUpdateBlock = block.number;
    }

    function _setCachedRedemptionRate(uint256 rate_) internal {
        _setCachedRedemptionRate(_layout(), rate_);
    }

    function _lastRateUpdateBlock(Storage storage layout_) internal view returns (uint256) {
        return layout_.lastRateUpdateBlock;
    }

    function _lastRateUpdateBlock() internal view returns (uint256) {
        return _lastRateUpdateBlock(_layout());
    }

    /* ---------------------------------------------------------------------- */
    /*                         Mint/Burn Operations                           */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice Mints shares to an account.
     * @dev Only affects shares, not balanceOf (which is computed).
     */
    function _mintShares(Storage storage layout_, address account_, uint256 shares_) internal {
        layout_.sharesOf[account_] += shares_;
        layout_.totalShares += shares_;
    }

    function _mintShares(address account_, uint256 shares_) internal {
        _mintShares(_layout(), account_, shares_);
    }

    /**
     * @notice Burns shares from an account.
     * @dev Only affects shares, not balanceOf (which is computed).
     */
    function _burnShares(Storage storage layout_, address account_, uint256 shares_) internal {
        require(layout_.sharesOf[account_] >= shares_, "RICHIR: insufficient shares");
        layout_.sharesOf[account_] -= shares_;
        layout_.totalShares -= shares_;
    }

    function _burnShares(address account_, uint256 shares_) internal {
        _burnShares(_layout(), account_, shares_);
    }

    /**
     * @notice Transfers shares between accounts.
     * @dev Used internally by ERC20 transfer functions.
     */
    function _transferShares(Storage storage layout_, address from_, address to_, uint256 shares_) internal {
        require(layout_.sharesOf[from_] >= shares_, "RICHIR: insufficient shares");
        layout_.sharesOf[from_] -= shares_;
        layout_.sharesOf[to_] += shares_;
    }

    function _transferShares(address from_, address to_, uint256 shares_) internal {
        _transferShares(_layout(), from_, to_, shares_);
    }

    /* ---------------------------------------------------------------------- */
    /*                         Balance Calculations                           */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice Calculates the RICHIR balance from shares.
     * @dev balance = shares * redemptionRate / 1e18
     */
    function _sharesToBalance(uint256 shares_, uint256 redemptionRate_) internal pure returns (uint256) {
        return (shares_ * redemptionRate_) / 1e18;
    }

    /**
     * @notice Calculates shares from RICHIR balance.
     * @dev shares = balance * 1e18 / redemptionRate
     */
    function _balanceToShares(uint256 balance_, uint256 redemptionRate_) internal pure returns (uint256) {
        if (redemptionRate_ == 0) return 0;
        return (balance_ * 1e18) / redemptionRate_;
    }
}
