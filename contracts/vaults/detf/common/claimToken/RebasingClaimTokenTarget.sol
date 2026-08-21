// SPDX-License-Identifier: BSL-1.1
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
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {IDetf} from "contracts/interfaces/detf/IDetf.sol";
import {IDETFNFTVault} from "contracts/interfaces/IDETFNFTVault.sol";
import {IDetfErrors} from "contracts/interfaces/IDetfErrors.sol";
import {RebasingClaimTokenRepo} from "contracts/vaults/detf/common/claimToken/RebasingClaimTokenRepo.sol";
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
    function name() external view returns (string memory) {
        return ERC20Repo._name();
    }

    /**
     * @notice Returns the symbol of the token.
     */
    function symbol() external view returns (string memory) {
        return ERC20Repo._symbol();
    }

    /**
     * @notice Returns the number of decimals.
     */
    function decimals() external pure returns (uint8) {
        return 18;
    }

    /**
     * @notice Total supply is the zapout of protocol-owned reserve LP (bond NFT id 0).
     * @dev Zero when there are no claim shares or the protocol NFT holds no LP.
     */
    function totalSupply() external view returns (uint256) {
        return _protocolNftZapOut(RebasingClaimTokenRepo._layoutStruct());
    }

    /**
     * @notice Returns the balance of an account (computed from shares * redemptionRate).
     * @dev This value changes over time as the redemption rate changes.
     */
    function balanceOf(address account) external view returns (uint256) {
        return _balanceOf(account);
    }

    function _balanceOf(address account) internal view returns (uint256) {
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
        return mintFromNFTSale(lpShares, type(uint256).max, recipient);
    }

    /// @inheritdoc IRebasingClaimToken
    function mintFromNFTSale(uint256 assets, uint256 totalAssetsBefore, address recipient)
        public
        onlyOwner
        returns (uint256 rebasingClaimMinted)
    {
        if (assets == 0) revert ZeroAmount();

        RebasingClaimTokenRepo.Storage storage layoutStruct = RebasingClaimTokenRepo._layoutStruct();
        uint256 totalAssets = totalAssetsBefore == type(uint256).max
            ? layoutStruct.nftVault.originalSharesOf(layoutStruct.detfNFTId)
            : totalAssetsBefore;
        uint256 totalSharesExt = RebasingClaimTokenRepo._internalSharesToExternal(layoutStruct.totalShares);
        uint256 sharesOutExt = totalAssets == 0 ? assets : (assets * totalSharesExt) / totalAssets;
        uint256 internalShares = RebasingClaimTokenRepo._externalSharesToInternal(sharesOutExt);

        RebasingClaimTokenRepo._mintShares(layoutStruct, recipient, internalShares);

        uint256 rate = _getCurrentRedemptionRate(layoutStruct);
        rebasingClaimMinted = RebasingClaimTokenRepo._sharesToBalance(internalShares, rate);

        emit IRebasingClaimToken.Minted(recipient, assets, sharesOutExt, rebasingClaimMinted);
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

        uint256 depositedIn = _secureTokenTransfer(tokenIn, amountIn, pretransferred);

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
     * @dev Owner (DETF) pulls foreign ERC-20 held here (protocol reserve LP custody).
     *      Not nonReentrant: DETF claimLiquidity may call this while claim redeem holds the lock (L-CLAIM-1 unwind).
     */
    function transferHeldToken(IERC20 token, address to, uint256 amount) external onlyOwner {
        if (to == address(0) || address(token) == address(0)) revert ZeroAmount();
        if (amount == 0) revert ZeroAmount();
        token.safeTransfer(to, amount);
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

        // L-GAPS-9/10 / L-CLAIM-3: pretransferred burns only shares already held on this diamond.
        // Owner-only path; redeem/exchange use _secureTokenTransfer delta gate for free-credit.
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

        // Burn shares (no rateAsset transfer - caller/DETF handles LP unwind)
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
    /// @dev ERC-4626 assets = originalSharesOf(detfNFTId). Never diamond BPT balance.
    function _convertInternalSharesToProtocolBpt(
        RebasingClaimTokenRepo.Storage storage layoutStruct_,
        uint256 internalShares_
    ) internal view returns (uint256 bptOut_) {
        uint256 totalSharesExt_ = RebasingClaimTokenRepo._internalSharesToExternal(layoutStruct_.totalShares);
        if (totalSharesExt_ == 0 || internalShares_ == 0) {
            return 0;
        }
        uint256 totalAssets_ = layoutStruct_.nftVault.originalSharesOf(layoutStruct_.detfNFTId);
        uint256 extShares_ = RebasingClaimTokenRepo._internalSharesToExternal(internalShares_);
        bptOut_ = (extShares_ * totalAssets_) / totalSharesExt_;
    }

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

        // 4626 convertToAssets against protocol NFT originalShares (before burn).
        uint256 bptOut_ = _convertInternalSharesToProtocolBpt(layoutStruct_, shares);
        if (bptOut_ == 0) revert ZeroAmount();

        // Burn claim shares first (CEI).
        RebasingClaimTokenRepo._burnShares(layoutStruct_, address(this), shares);

        // L-CLAIM-1/2: fund redeem by unwinding protocol NFT LP via DETF - not idle rateAsset inventory.
        wethOut_ = layoutStruct_.detf.claimLiquidity(bptOut_, recipient_);

        emit IRebasingClaimToken.Redeemed(
            msg.sender, recipient_, rebasingClaimAmount_, bptOut_, wethOut_
        );
        emit IERC20Events.Transfer(address(this), address(0), rebasingClaimAmount_);
    }

    /**
     * @dev Delta-based secure pull (L-GAPS-9/10 / L-CLAIM-3 / ISecurePullErrors).
     *      Blocks free credit of idle inventory via pretransferred=true with no in-call transfer (I1).
     *      Absolute `balanceOf >= claimed` without a positive in-window delta is forbidden.
     *      Self-token pulls use internal `_transfer` so share accounting stays consistent;
     *      foreign tokens use safeTransferFrom (FoT-safe observed delta).
     */
    function _secureTokenTransfer(IERC20 token_, uint256 amount_, bool pretransferred_) internal returns (uint256 actualIn_) {
        uint256 balanceBefore = token_.balanceOf(address(this));
        if (!pretransferred_) {
            if (address(token_) == address(this)) {
                _transfer(msg.sender, address(this), amount_);
            } else {
                token_.safeTransferFrom(msg.sender, address(this), amount_);
            }
        }
        uint256 observedDelta = token_.balanceOf(address(this)) - balanceBefore;
        if (pretransferred_) {
            if (amount_ > observedDelta) {
                revert ISecurePullErrors.TransferDeltaInsufficient(amount_, observedDelta);
            }
            // Credit exactly claimed; surplus delta is not credited (no exact-delta grief).
            return amount_;
        }
        // Self-token transfer is exact (share accounting); foreign may be FoT-short.
        if (address(token_) == address(this)) {
            return amount_;
        }
        return observedDelta;
    }

    /**
     * @dev Rate such that balanceOf = pro-rata of `_protocolNftZapOut` (totalSupply).
     */
    function _calcCurrentRedemptionRate(RebasingClaimTokenRepo.Storage storage layoutStruct_) internal view returns (uint256 rate) {
        uint256 totalShares_ = layoutStruct_.totalShares;
        if (totalShares_ == 0) {
            return ONE_WAD;
        }

        uint256 zapout_ = _protocolNftZapOut(layoutStruct_);
        if (zapout_ == 0) {
            return ONE_WAD;
        }

        rate = Math.mulDiv(zapout_, RebasingClaimTokenRepo._shareUnit(), totalShares_);
        if (rate == 0) {
            rate = 1;
        }
    }

    /// @dev Zapout of the protocol bond NFT's whole reserve-LP slice (4626 assets, then single-sided exit).
    function _protocolNftZapOut(RebasingClaimTokenRepo.Storage storage layoutStruct_)
        internal
        view
        returns (uint256 zapout_)
    {
        if (layoutStruct_.totalShares == 0) return 0;
        uint256 orig_ = layoutStruct_.nftVault.originalSharesOf(layoutStruct_.detfNFTId);
        if (orig_ == 0) {
            IDETFNFTVault.Position memory position_ = layoutStruct_.nftVault.getPosition(layoutStruct_.detfNFTId);
            orig_ = position_.originalShares;
        }
        if (orig_ == 0) return 0;

        uint256 lp_ = orig_;
        try layoutStruct_.nftVault.convertToAssets(orig_) returns (uint256 assets_) {
            if (assets_ > 0) lp_ = assets_;
        } catch {}

        return _reserveShareZapOut(layoutStruct_, lp_);
    }

    /// @dev Canonical quote: DETF `previewClaimLiquidity` (reserve LP zapout). Fallback: previewExchangeIn.
    function _reserveShareZapOut(RebasingClaimTokenRepo.Storage storage layoutStruct_, uint256 lpAmount_)
        internal
        view
        returns (uint256 zapout_)
    {
        try layoutStruct_.detf.previewClaimLiquidity(lpAmount_) returns (uint256 z_) {
            return z_;
        } catch {
            IERC20 bpt = IERC20(layoutStruct_.detf.reservePool());
            return IStandardExchangeIn(address(layoutStruct_.detf)).previewExchangeIn(
                bpt, lpAmount_, layoutStruct_.rateAsset
            );
        }
    }
}
