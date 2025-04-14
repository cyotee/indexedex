// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {IERC20Events} from "@crane/contracts/interfaces/IERC20Events.sol";
import {ONE_WAD} from "@crane/contracts/constants/Constants.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {BetterSafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {ReentrancyLockModifiers} from "@crane/contracts/access/reentrancy/ReentrancyLockModifiers.sol";
import {MultiStepOwnableModifiers} from "@crane/contracts/access/ERC8023/MultiStepOwnableModifiers.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IRICHIR} from "contracts/interfaces/IRICHIR.sol";
import {IProtocolDETF} from "contracts/interfaces/IProtocolDETF.sol";
import {IProtocolNFTVault} from "contracts/interfaces/IProtocolNFTVault.sol";
import {IProtocolDETFErrors} from "contracts/interfaces/IProtocolDETFErrors.sol";
import {RICHIRRepo} from "contracts/vaults/protocol/RICHIRRepo.sol";
import {IStandardExchangeIn} from "contracts/interfaces/IStandardExchangeIn.sol";

/**
 * @title RICHIRTarget
 * @author cyotee doge <not_cyotee@proton.me>
 * @notice Implementation of RICHIR rebasing token.
 * @dev RICHIR is a rebasing ERC20 token that:
 *      - Is minted when the protocol-owned NFT is sold
 *      - Has balanceOf() that changes over time based on redemption rate
 *      - Can be redeemed for WETH when synthetic price is below burn threshold
 *
 *      Storage model:
 *      - sharesOf[user]: Only changes on mint/burn/transfer
 *      - totalShares: Only changes on mint/burn
 *      - balanceOf(user): Computed live as sharesOf * redemptionRate / 1e18
 *      - totalSupply(): Computed live as totalShares * redemptionRate / 1e18
 */
contract RICHIRTarget is IProtocolDETFErrors, ReentrancyLockModifiers, MultiStepOwnableModifiers, IRICHIR {
    using BetterSafeERC20 for IERC20;
    using RICHIRRepo for RICHIRRepo.Storage;

    /* ---------------------------------------------------------------------- */
    /*                              Events                                    */
    /* ---------------------------------------------------------------------- */

    // Note: Transfer, Approval, and RedemptionRateUpdated events are inherited from interfaces

    /* ---------------------------------------------------------------------- */
    /*                          Rebasing ERC20 Core                           */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice Returns the name of the token.
     */
    function name() external pure returns (string memory) {
        return "RICHIR";
    }

    /**
     * @notice Returns the symbol of the token.
     */
    function symbol() external pure returns (string memory) {
        return "RICHIR";
    }

    /**
     * @notice Returns the number of decimals.
     */
    function decimals() external pure returns (uint8) {
        return 18;
    }

    /**
     * @notice Returns the total supply (computed from totalShares * redemptionRate).
     */
    function totalSupply() external view returns (uint256) {
        RICHIRRepo.Storage storage layout = RICHIRRepo._layout();
        uint256 rate = _getCurrentRedemptionRate(layout);
        return RICHIRRepo._sharesToBalance(layout.totalShares, rate);
    }

    /**
     * @notice Returns the balance of an account (computed from shares * redemptionRate).
     * @dev This value changes over time as the redemption rate changes.
     */
    function balanceOf(address account) external view returns (uint256) {
        RICHIRRepo.Storage storage layout = RICHIRRepo._layout();
        uint256 rate = _getCurrentRedemptionRate(layout);
        return RICHIRRepo._sharesToBalance(layout.sharesOf[account], rate);
    }

    /**
     * @inheritdoc IRICHIR
     */
    function sharesOf(address account) external view returns (uint256) {
        return RICHIRRepo._sharesOf(account);
    }

    /**
     * @inheritdoc IRICHIR
     */
    function totalShares() external view returns (uint256) {
        return RICHIRRepo._totalShares();
    }

    /**
     * @inheritdoc IRICHIR
     */
    function redemptionRate() external view returns (uint256) {
        return _getCurrentRedemptionRate(RICHIRRepo._layout());
    }

    /**
     * @inheritdoc IRICHIR
     */
    function protocolDETF() external view returns (address) {
        return address(RICHIRRepo._layout().protocolDETF);
    }

    /**
     * @inheritdoc IRICHIR
     */
    function protocolNFTId() external view returns (uint256) {
        return RICHIRRepo._layout().protocolNFTId;
    }

    /**
     * @inheritdoc IRICHIR
     */
    function wethToken() external view returns (IERC20) {
        return RICHIRRepo._layout().wethToken;
    }

    /**
     * @inheritdoc IRICHIR
     */
    function convertToShares(uint256 richirAmount) external view returns (uint256 shares) {
        uint256 rate = _getCurrentRedemptionRate(RICHIRRepo._layout());
        return RICHIRRepo._balanceToShares(richirAmount, rate);
    }

    /**
     * @inheritdoc IRICHIR
     */
    function convertToRichir(uint256 shares) external view returns (uint256 richirAmount) {
        uint256 rate = _getCurrentRedemptionRate(RICHIRRepo._layout());
        return RICHIRRepo._sharesToBalance(shares, rate);
    }

    /**
     * @inheritdoc IRICHIR
     */
    function previewRedeem(uint256 richirAmount) external view returns (uint256 wethOut) {
        RICHIRRepo.Storage storage layout = RICHIRRepo._layout();
        uint256 rate = _getCurrentRedemptionRate(layout);
        uint256 shares = RICHIRRepo._balanceToShares(richirAmount, rate);
        // WETH out equals the share value at current rate
        wethOut = RICHIRRepo._sharesToBalance(shares, rate);
    }

    /* ---------------------------------------------------------------------- */
    /*                          ERC20 Transfers                               */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice Transfers tokens to a recipient.
     * @dev Converts balance amount to shares for internal accounting.
     */
    function transfer(address to, uint256 amount) external returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    /**
     * @notice Returns the allowance.
     */
    function allowance(address owner, address spender) external view returns (uint256) {
        return ERC20Repo._allowance(owner, spender);
    }

    /**
     * @notice Approves a spender.
     */
    function approve(address spender, uint256 amount) external returns (bool) {
        ERC20Repo._approve(msg.sender, spender, amount);
        emit IERC20Events.Approval(msg.sender, spender, amount);
        return true;
    }

    /**
     * @notice Transfers tokens from one address to another.
     */
    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        ERC20Repo._spendAllowance(ERC20Repo._layout(), from, msg.sender, amount);
        _transfer(from, to, amount);
        return true;
    }

    /**
     * @dev Internal transfer function.
     */
    function _transfer(address from, address to, uint256 amount) internal {
        if (from == address(0)) revert ZeroAmount();
        if (to == address(0)) revert ZeroAmount();

        RICHIRRepo.Storage storage layout = RICHIRRepo._layout();
        uint256 rate = _getCurrentRedemptionRate(layout);

        // Convert balance to shares
        uint256 shares = RICHIRRepo._balanceToShares(amount, rate);
        if (shares == 0) revert ZeroAmount();

        // Check sender has enough shares
        if (layout.sharesOf[from] < shares) {
            revert InsufficientBalance(shares, layout.sharesOf[from]);
        }

        // Transfer shares
        RICHIRRepo._transferShares(layout, from, to, shares);

        emit IERC20Events.Transfer(from, to, amount);
    }

    /* ---------------------------------------------------------------------- */
    /*                          Mint (NFT Sale Only)                          */
    /* ---------------------------------------------------------------------- */

    /**
     * @inheritdoc IRICHIR
     * @dev Only callable by the Protocol DETF owner.
     */
    function mintFromNFTSale(uint256 lpShares, address recipient) external onlyOwner returns (uint256 richirMinted) {
        if (lpShares == 0) revert ZeroAmount();

        RICHIRRepo.Storage storage layout = RICHIRRepo._layout();

        // Mint shares directly (1:1 with NFT effective shares)
        RICHIRRepo._mintShares(layout, recipient, lpShares);

        // Calculate balance for return value and event
        uint256 rate = _getCurrentRedemptionRate(layout);
        richirMinted = RICHIRRepo._sharesToBalance(lpShares, rate);

        emit IRICHIR.Minted(recipient, lpShares, lpShares, richirMinted);
        emit IERC20Events.Transfer(address(0), recipient, richirMinted);
    }

    /* ---------------------------------------------------------------------- */
    /*                          Redemption                                    */
    /* ---------------------------------------------------------------------- */

    /**
     * @inheritdoc IRICHIR
     */
    function redeem(uint256 richirAmount, address recipient, bool pretransferred)
        external
        lock
        returns (uint256 wethOut)
    {
        if (richirAmount == 0) revert ZeroAmount();
        if (recipient == address(0)) recipient = msg.sender;

        RICHIRRepo.Storage storage layout = RICHIRRepo._layout();

        // Check redemption is allowed (synthetic price below burn threshold)
        // Note: The Protocol DETF checks price gate internally when calling this

        // Get current rate and convert to shares
        uint256 rate = _getCurrentRedemptionRate(layout);
        uint256 shares = RICHIRRepo._balanceToShares(richirAmount, rate);

        // Handle transfer if not pretransferred
        address owner = msg.sender;
        if (pretransferred) {
            // Tokens already at this contract, burn from here
            owner = address(this);
        }

        // Check owner has enough shares
        if (layout.sharesOf[owner] < shares) {
            revert InsufficientBalance(shares, layout.sharesOf[owner]);
        }

        // Burn shares
        RICHIRRepo._burnShares(layout, owner, shares);

        // Calculate WETH amount based on current rate
        wethOut = RICHIRRepo._sharesToBalance(shares, rate);

        // Transfer WETH from NFT vault to recipient
        // The protocol-owned NFT holds WETH via the reserve pool
        layout.wethToken.safeTransfer(recipient, wethOut);

        emit IRICHIR.Redeemed(msg.sender, recipient, richirAmount, shares, wethOut);
        emit IERC20Events.Transfer(owner, address(0), richirAmount);
    }

    /**
     * @inheritdoc IRICHIR
     * @dev Only callable by the Protocol DETF owner.
     */
    function burnShares(uint256 richirAmount, address owner, bool pretransferred)
        external
        onlyOwner
        lock
        returns (uint256 sharesBurned)
    {
        if (richirAmount == 0) revert ZeroAmount();

        RICHIRRepo.Storage storage layout = RICHIRRepo._layout();
        uint256 rate = _getCurrentRedemptionRate(layout);
        sharesBurned = RICHIRRepo._balanceToShares(richirAmount, rate);

        // Handle transfer if not pretransferred
        address burnFrom = owner;
        if (pretransferred) {
            burnFrom = address(this);
        }

        // Check owner has enough shares
        if (layout.sharesOf[burnFrom] < sharesBurned) {
            revert InsufficientBalance(sharesBurned, layout.sharesOf[burnFrom]);
        }

        // Burn shares (no WETH transfer - caller handles that)
        RICHIRRepo._burnShares(layout, burnFrom, sharesBurned);

        emit IERC20Events.Transfer(burnFrom, address(0), richirAmount);
    }

    /* ---------------------------------------------------------------------- */
    /*                       Redemption Rate Updates                          */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice Updates the cached redemption rate.
     * @dev Can be called by anyone to refresh the rate.
     */
    function updateRedemptionRate() external {
        RICHIRRepo.Storage storage layout = RICHIRRepo._layout();
        uint256 oldRate = layout.cachedRedemptionRate;
        uint256 newRate = _calcCurrentRedemptionRate(layout);

        if (newRate != oldRate) {
            RICHIRRepo._setCachedRedemptionRate(layout, newRate);
            emit IRICHIR.RedemptionRateUpdated(oldRate, newRate);
        }
    }

    /* ---------------------------------------------------------------------- */
    /*                       Internal Rate Calculation                        */
    /* ---------------------------------------------------------------------- */

    // --- no temporary debug errors here; production path calls into the
    // Protocol DETF's `previewExchangeIn` to value the protocol-owned BPT.

    /**
     * @dev Gets the current redemption rate, updating cache if stale.
     */
    function _getCurrentRedemptionRate(RICHIRRepo.Storage storage layout_) internal view returns (uint256) {
        // If rate was updated this block, use cached value
        if (layout_.lastRateUpdateBlock == block.number) {
            return layout_.cachedRedemptionRate;
        }

        // Otherwise calculate fresh rate
        return _calcCurrentRedemptionRate(layout_);
    }

    /**
     * @dev Calculates the current redemption rate based on protocol-owned NFT value.
     * @dev Rate = (WETH value of protocol NFT's BPT) / totalRICHIRShares
     *      This allows RICHIR to rebase based on the underlying LP value.
     * @return rate The redemption rate (1e18 = 1:1)
     */
    function _calcCurrentRedemptionRate(RICHIRRepo.Storage storage layout_) internal view returns (uint256 rate) {
        uint256 totalShares_ = layout_.totalShares;
        if (totalShares_ == 0) {
            return ONE_WAD;
        }

        // Get protocol-owned NFT position
        IProtocolNFTVault.Position memory position = layout_.nftVault.getPosition(layout_.protocolNFTId);
        if (position.originalShares == 0) {
            return ONE_WAD;
        }

        // Calculate WETH value of the protocol NFT's BPT via the generic StandardExchange preview.
        IERC20 bpt = IERC20(layout_.protocolDETF.reservePool());
        uint256 wethValue = IStandardExchangeIn(address(layout_.protocolDETF)).previewExchangeIn(
            bpt,
            position.originalShares,
            layout_.wethToken
        );
        if (wethValue == 0) {
            return ONE_WAD;
        }

        // Rate = total WETH value / total RICHIR shares
        // This means 1 RICHIR share = (wethValue / totalShares) WETH
        rate = (wethValue * ONE_WAD) / totalShares_;

        // Ensure rate never goes to 0 (minimum 1 wei per share)
        if (rate == 0) {
            rate = 1;
        }
    }
}
