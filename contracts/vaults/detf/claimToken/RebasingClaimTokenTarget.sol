// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {IERC20Events} from "@crane/contracts/interfaces/IERC20Events.sol";
import {ONE_WAD} from "@crane/contracts/constants/Constants.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {Math} from "@crane/contracts/utils/Math.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {BetterSafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {ReentrancyLockModifiers} from "@crane/contracts/access/reentrancy/ReentrancyLockModifiers.sol";
import {MultiStepOwnableModifiers} from "@crane/contracts/access/ERC8023/MultiStepOwnableModifiers.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IRebasingClaimToken} from "contracts/interfaces/IRebasingClaimToken.sol";
import {IDetf} from "contracts/interfaces/detf/IDetf.sol";
import {IDETFNFTVault} from "contracts/interfaces/IDETFNFTVault.sol";
import {IDetfErrors} from "contracts/interfaces/IDetfErrors.sol";
import {RebasingClaimTokenRepo} from "contracts/vaults/detf/claimToken/RebasingClaimTokenRepo.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";

/**
 * @title RebasingClaimTokenTarget
 * @author cyotee doge <not_cyotee@proton.me>
 * @notice Implementation of rebasing claim token rebasing token.
 * @dev rebasing claim token is a rebasing ERC20 token that:
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
contract RebasingClaimTokenTarget is IDetfErrors, ReentrancyLockModifiers, MultiStepOwnableModifiers, IRebasingClaimToken {
    using BetterSafeERC20 for IERC20;
    using RebasingClaimTokenRepo for RebasingClaimTokenRepo.Storage;

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
        return "RebasingClaim";
    }

    /**
     * @notice Returns the symbol of the token.
     */
    function symbol() external pure returns (string memory) {
        return "RebasingClaim";
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
        RebasingClaimTokenRepo.Storage storage layoutStruct = RebasingClaimTokenRepo._layoutStruct();
        uint256 rate = _getCurrentRedemptionRate(layoutStruct);
        return RebasingClaimTokenRepo._sharesToBalance(layoutStruct.totalShares, rate);
    }

    /**
     * @notice Returns the balance of an account (computed from shares * redemptionRate).
     * @dev This value changes over time as the redemption rate changes.
     */
    function balanceOf(address account) external view returns (uint256) {
        RebasingClaimTokenRepo.Storage storage layoutStruct = RebasingClaimTokenRepo._layoutStruct();
        uint256 rate = _getCurrentRedemptionRate(layoutStruct);
        return RebasingClaimTokenRepo._sharesToBalance(layoutStruct.sharesOf[account], rate);
    }

    /**
     * @inheritdoc IRebasingClaimToken
     */
    function sharesOf(address account) external view returns (uint256) {
        return RebasingClaimTokenRepo._internalSharesToExternal(RebasingClaimTokenRepo._sharesOf(account));
    }

    /**
     * @inheritdoc IRebasingClaimToken
     */
    function totalShares() external view returns (uint256) {
        return RebasingClaimTokenRepo._internalSharesToExternal(RebasingClaimTokenRepo._totalShares());
    }

    /**
     * @inheritdoc IRebasingClaimToken
     */
    function redemptionRate() external view returns (uint256) {
        return _getCurrentRedemptionRate(RebasingClaimTokenRepo._layoutStruct());
    }

    /**
     * @inheritdoc IRebasingClaimToken
     */
    function detf() external view returns (address) {
        return address(RebasingClaimTokenRepo._layoutStruct().detf);
    }

    /**
     * @inheritdoc IRebasingClaimToken
     */
    function setDetf(address detf_) external onlyOwner {
        RebasingClaimTokenRepo._setDetf(IDetf(detf_));
    }

    /**
     * @inheritdoc IRebasingClaimToken
     */
    function detfNFTId() external view returns (uint256) {
        return RebasingClaimTokenRepo._layoutStruct().detfNFTId;
    }

    /**
     * @inheritdoc IRebasingClaimToken
     */
    function rateAsset() external view returns (IERC20) {
        return RebasingClaimTokenRepo._layoutStruct().rateAsset;
    }

    /**
     * @inheritdoc IRebasingClaimToken
     */
    function convertToShares(uint256 rebasingClaimAmount) external view returns (uint256 shares) {
        uint256 rate = _getCurrentRedemptionRate(RebasingClaimTokenRepo._layoutStruct());
        return RebasingClaimTokenRepo._internalSharesToExternal(RebasingClaimTokenRepo._balanceToShares(rebasingClaimAmount, rate));
    }

    /**
     * @inheritdoc IRebasingClaimToken
     */
    function convertToClaim(uint256 shares) external view returns (uint256 rebasingClaimAmount) {
        uint256 rate = _getCurrentRedemptionRate(RebasingClaimTokenRepo._layoutStruct());
        uint256 internalShares = RebasingClaimTokenRepo._externalSharesToInternal(shares);
        return RebasingClaimTokenRepo._sharesToBalance(internalShares, rate);
    }

    /**
     * @inheritdoc IRebasingClaimToken
     */
    function previewRedeem(uint256 rebasingClaimAmount) external view returns (uint256 wethOut) {
        RebasingClaimTokenRepo.Storage storage layoutStruct = RebasingClaimTokenRepo._layoutStruct();
        uint256 rate = _getCurrentRedemptionRate(layoutStruct);
        uint256 shares = RebasingClaimTokenRepo._balanceToShares(rebasingClaimAmount, rate);
        // WETH out equals the share value at current rate
        wethOut = RebasingClaimTokenRepo._sharesToBalance(shares, rate);
    }

    function previewExchangeIn(IERC20 tokenIn, uint256 amountIn, IERC20 tokenOut)
        external
        view
        returns (uint256 amountOut)
    {
        if (amountIn == 0) {
            return 0;
        }
        if (address(tokenIn) != address(this)) {
            revert InvalidToken(tokenIn);
        }
        if (address(tokenOut) != address(RebasingClaimTokenRepo._layoutStruct().rateAsset)) {
            revert InvalidToken(tokenOut);
        }

        RebasingClaimTokenRepo.Storage storage layoutStruct = RebasingClaimTokenRepo._layoutStruct();
        uint256 rate = _getCurrentRedemptionRate(layoutStruct);
        uint256 shares = RebasingClaimTokenRepo._balanceToShares(amountIn, rate);
        amountOut = RebasingClaimTokenRepo._sharesToBalance(shares, rate);
    }

    function previewExchangeOut(IERC20 tokenIn, IERC20 tokenOut, uint256 amountOut)
        external
        view
        returns (uint256 amountIn)
    {
        if (amountOut == 0) {
            return 0;
        }
        if (address(tokenIn) != address(this)) {
            revert InvalidToken(tokenIn);
        }
        if (address(tokenOut) != address(RebasingClaimTokenRepo._layoutStruct().rateAsset)) {
            revert InvalidToken(tokenOut);
        }

        uint256 rate = _getCurrentRedemptionRate(RebasingClaimTokenRepo._layoutStruct());
        if (rate == 0) {
            revert IStandardExchangeOut.ExchangeOutNotAvailable();
        }

        amountIn = Math.mulDiv(amountOut, ONE_WAD, rate, Math.Rounding.Ceil);
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
        ERC20Repo._spendAllowance(ERC20Repo._layoutStruct(), from, msg.sender, amount);
        _transfer(from, to, amount);
        return true;
    }

    /**
     * @dev Internal transfer function.
     */
    function _transfer(address from, address to, uint256 amount) internal {
        if (from == address(0)) revert ZeroAmount();
        if (to == address(0)) revert ZeroAmount();

        RebasingClaimTokenRepo.Storage storage layoutStruct = RebasingClaimTokenRepo._layoutStruct();
        uint256 rate = _getCurrentRedemptionRate(layoutStruct);

        // Convert balance to shares
        uint256 shares = RebasingClaimTokenRepo._balanceToShares(amount, rate);
        if (shares == 0) revert ZeroAmount();

        // Check sender has enough shares
        if (layoutStruct.sharesOf[from] < shares) {
            revert InsufficientBalance(
                RebasingClaimTokenRepo._internalSharesToExternal(shares),
                RebasingClaimTokenRepo._internalSharesToExternal(layoutStruct.sharesOf[from])
            );
        }

        // Transfer shares
        RebasingClaimTokenRepo._transferShares(layoutStruct, from, to, shares);

        emit IERC20Events.Transfer(from, to, amount);
    }

    /* ---------------------------------------------------------------------- */
    /*                          Mint (NFT Sale Only)                          */
    /* ---------------------------------------------------------------------- */

    /**
     * @inheritdoc IRebasingClaimToken
     * @dev Only callable by the DETF diamond owner.
     */
    function mintFromNFTSale(uint256 lpShares, address recipient) external onlyOwner returns (uint256 rebasingClaimMinted) {
        if (lpShares == 0) revert ZeroAmount();

        RebasingClaimTokenRepo.Storage storage layoutStruct = RebasingClaimTokenRepo._layoutStruct();
        uint256 internalShares = RebasingClaimTokenRepo._externalSharesToInternal(lpShares);

        // Mint shares with internal precision while preserving 18-decimal external units.
        RebasingClaimTokenRepo._mintShares(layoutStruct, recipient, internalShares);

        // Calculate balance for return value and event
        uint256 rate = _getCurrentRedemptionRate(layoutStruct);
        rebasingClaimMinted = RebasingClaimTokenRepo._sharesToBalance(internalShares, rate);

        emit IRebasingClaimToken.Minted(recipient, lpShares, lpShares, rebasingClaimMinted);
        emit IERC20Events.Transfer(address(0), recipient, rebasingClaimMinted);
    }

    /* ---------------------------------------------------------------------- */
    /*                          Redemption                                    */
    /* ---------------------------------------------------------------------- */

    /**
     * @inheritdoc IRebasingClaimToken
     */
    function redeem(uint256 rebasingClaimAmount, address recipient, bool pretransferred)
        external
        nonReentrant
        returns (uint256 wethOut)
    {
        if (rebasingClaimAmount == 0) revert ZeroAmount();

        RebasingClaimTokenRepo.Storage storage layoutStruct = RebasingClaimTokenRepo._layoutStruct();
        uint256 actualIn = _secureTokenTransfer(IERC20(address(this)), rebasingClaimAmount, pretransferred);
        wethOut = _executeRedeem(layoutStruct, actualIn, recipient == address(0) ? msg.sender : recipient);
    }

    function exchangeIn(
        IERC20 tokenIn,
        uint256 amountIn,
        IERC20 tokenOut,
        uint256 minAmountOut,
        address recipient,
        bool pretransferred,
        uint256 deadline
    ) external nonReentrant returns (uint256 amountOut) {
        if (block.timestamp > deadline) {
            revert DeadlineExceeded(deadline, block.timestamp);
        }
        if (amountIn == 0) revert ZeroAmount();
        if (address(tokenIn) != address(this)) {
            revert InvalidToken(tokenIn);
        }

        RebasingClaimTokenRepo.Storage storage layoutStruct = RebasingClaimTokenRepo._layoutStruct();
        if (address(tokenOut) != address(layoutStruct.rateAsset)) {
            revert InvalidToken(tokenOut);
        }

        uint256 actualIn = _secureTokenTransfer(tokenIn, amountIn, pretransferred);
        amountOut = _executeRedeem(layoutStruct, actualIn, recipient == address(0) ? msg.sender : recipient);
        if (amountOut < minAmountOut) {
            revert SlippageExceeded(minAmountOut, amountOut);
        }
    }

    function exchangeOut(
        IERC20 tokenIn,
        uint256 maxAmountIn,
        IERC20 tokenOut,
        uint256 amountOut,
        address recipient,
        bool pretransferred,
        uint256 deadline
    ) external nonReentrant returns (uint256 amountIn) {
        if (block.timestamp > deadline) {
            revert DeadlineExceeded(deadline, block.timestamp);
        }
        if (amountOut == 0) revert ZeroAmount();
        if (address(tokenIn) != address(this)) {
            revert InvalidToken(tokenIn);
        }

        RebasingClaimTokenRepo.Storage storage layoutStruct = RebasingClaimTokenRepo._layoutStruct();
        if (address(tokenOut) != address(layoutStruct.rateAsset)) {
            revert InvalidToken(tokenOut);
        }

        uint256 rate = _getCurrentRedemptionRate(layoutStruct);
        amountIn = Math.mulDiv(amountOut, ONE_WAD, rate, Math.Rounding.Ceil);
        if (amountIn > maxAmountIn) {
            revert SlippageExceeded(maxAmountIn, amountIn);
        }

        uint256 depositedIn;
        if (pretransferred) {
            depositedIn = maxAmountIn;
        } else {
            depositedIn = _secureTokenTransfer(tokenIn, amountIn, false);
        }

        if (depositedIn < amountIn) {
            revert SlippageExceeded(amountIn, depositedIn);
        }

        uint256 actualOut = _executeRedeem(layoutStruct, amountIn, recipient == address(0) ? msg.sender : recipient);
        if (actualOut < amountOut) {
            revert SlippageExceeded(amountOut, actualOut);
        }

        if (depositedIn > amountIn) {
            IERC20(address(this)).safeTransfer(msg.sender, depositedIn - amountIn);
        }
    }

    /**
     * @inheritdoc IRebasingClaimToken
     * @dev Only callable by the DETF diamond owner.
     */
    function burnShares(uint256 rebasingClaimAmount, address owner, bool pretransferred)
        external
        onlyOwner
        nonReentrant
        returns (uint256 sharesBurned)
    {
        if (rebasingClaimAmount == 0) revert ZeroAmount();

        RebasingClaimTokenRepo.Storage storage layoutStruct = RebasingClaimTokenRepo._layoutStruct();
        uint256 rate = _getCurrentRedemptionRate(layoutStruct);
        uint256 internalSharesBurned = RebasingClaimTokenRepo._balanceToShares(rebasingClaimAmount, rate);

        // Handle transfer if not pretransferred
        address burnFrom = owner;
        if (pretransferred) {
            burnFrom = address(this);
        }

        // Check owner has enough shares
        if (layoutStruct.sharesOf[burnFrom] < internalSharesBurned) {
            revert InsufficientBalance(
                RebasingClaimTokenRepo._internalSharesToExternal(internalSharesBurned),
                RebasingClaimTokenRepo._internalSharesToExternal(layoutStruct.sharesOf[burnFrom])
            );
        }

        // Burn shares (no WETH transfer - caller handles that)
        RebasingClaimTokenRepo._burnShares(layoutStruct, burnFrom, internalSharesBurned);

        sharesBurned = RebasingClaimTokenRepo._internalSharesToExternal(internalSharesBurned);

        emit IERC20Events.Transfer(burnFrom, address(0), rebasingClaimAmount);
    }

    /* ---------------------------------------------------------------------- */
    /*                       Redemption Rate Updates                          */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice Updates the cached redemption rate.
     * @dev Can be called by anyone to refresh the rate.
     */
    function updateRedemptionRate() external {
        RebasingClaimTokenRepo.Storage storage layoutStruct = RebasingClaimTokenRepo._layoutStruct();
        uint256 oldRate = layoutStruct.cachedRedemptionRate;
        uint256 newRate = _calcCurrentRedemptionRate(layoutStruct);

        if (newRate != oldRate) {
            RebasingClaimTokenRepo._setCachedRedemptionRate(layoutStruct, newRate);
            emit IRebasingClaimToken.RedemptionRateUpdated(oldRate, newRate);
        }
    }

    /* ---------------------------------------------------------------------- */
    /*                       Internal Rate Calculation                        */
    /* ---------------------------------------------------------------------- */

    // --- no temporary debug errors here; production path calls into the
    // DETF diamond `previewExchangeIn` to value the protocol-owned BPT.

    /**
     * @dev Gets the current redemption rate, updating cache if stale.
     */
    function _getCurrentRedemptionRate(RebasingClaimTokenRepo.Storage storage layoutStruct_) internal view returns (uint256) {
        // If rate was updated this block, use cached value
        if (layoutStruct_.lastRateUpdateBlock == block.number) {
            return layoutStruct_.cachedRedemptionRate;
        }

        // Otherwise calculate fresh rate
        return _calcCurrentRedemptionRate(layoutStruct_);
    }

    function _executeRedeem(RebasingClaimTokenRepo.Storage storage layoutStruct_, uint256 rebasingClaimAmount_, address recipient_)
        internal
        returns (uint256 wethOut_)
    {
        uint256 rate = _getCurrentRedemptionRate(layoutStruct_);
        uint256 shares = RebasingClaimTokenRepo._balanceToShares(rebasingClaimAmount_, rate);

        if (layoutStruct_.sharesOf[address(this)] < shares) {
            revert InsufficientBalance(
                RebasingClaimTokenRepo._internalSharesToExternal(shares),
                RebasingClaimTokenRepo._internalSharesToExternal(layoutStruct_.sharesOf[address(this)])
            );
        }

        RebasingClaimTokenRepo._burnShares(layoutStruct_, address(this), shares);
        wethOut_ = RebasingClaimTokenRepo._sharesToBalance(shares, rate);
        layoutStruct_.rateAsset.safeTransfer(recipient_, wethOut_);

        emit IRebasingClaimToken.Redeemed(
            msg.sender, recipient_, rebasingClaimAmount_, RebasingClaimTokenRepo._internalSharesToExternal(shares), wethOut_
        );
        emit IERC20Events.Transfer(address(this), address(0), rebasingClaimAmount_);
    }

    function _secureTokenTransfer(IERC20 token_, uint256 amount_, bool pretransferred_) internal returns (uint256 actualIn_) {
        if (pretransferred_) {
            return amount_;
        }

        if (address(token_) == address(this)) {
            _transfer(msg.sender, address(this), amount_);
            return amount_;
        }

        uint256 balanceBefore = token_.balanceOf(address(this));
        token_.safeTransferFrom(msg.sender, address(this), amount_);
        actualIn_ = token_.balanceOf(address(this)) - balanceBefore;
    }

    /**
     * @dev Calculates the current redemption rate based on protocol-owned NFT value.
     * @dev Rate = (WETH value of protocol NFT's BPT) / totalRebasingClaimShares
     *      This allows rebasing claim token to rebase based on the underlying LP value.
     * @return rate The redemption rate (1e18 = 1:1)
     */
    function _calcCurrentRedemptionRate(RebasingClaimTokenRepo.Storage storage layoutStruct_) internal view returns (uint256 rate) {
        uint256 totalShares_ = layoutStruct_.totalShares;
        if (totalShares_ == 0) {
            return ONE_WAD;
        }

        // Get protocol-owned NFT position
        IDETFNFTVault.Position memory position = layoutStruct_.nftVault.getPosition(layoutStruct_.detfNFTId);
        if (position.originalShares == 0) {
            return ONE_WAD;
        }

        // Calculate WETH value of the protocol NFT's BPT via the generic StandardExchange preview.
        IERC20 bpt = IERC20(layoutStruct_.detf.reservePool());
        uint256 wethValue = IStandardExchangeIn(address(layoutStruct_.detf)).previewExchangeIn(
            bpt,
            position.originalShares,
            layoutStruct_.rateAsset
        );
        if (wethValue == 0) {
            return ONE_WAD;
        }

        // Rate = total WETH value / total rebasing claim token shares
        // This means 1 rebasing claim token share = (wethValue / totalShares) WETH
        rate = Math.mulDiv(wethValue, RebasingClaimTokenRepo._shareUnit(), totalShares_);

        // Ensure rate never goes to 0 (minimum 1 wei per share)
        if (rate == 0) {
            rate = 1;
        }
    }
}
