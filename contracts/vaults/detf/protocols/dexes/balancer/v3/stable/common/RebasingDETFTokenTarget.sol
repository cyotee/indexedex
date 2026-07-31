// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20Events} from '@crane/contracts/interfaces/IERC20Events.sol';
import {ONE_WAD} from '@crane/contracts/constants/Constants.sol';
import {IERC20} from '@crane/contracts/interfaces/IERC20.sol';
import {Math} from '@crane/contracts/utils/Math.sol';
import {ERC20Repo} from '@crane/contracts/tokens/ERC20/ERC20Repo.sol';
import {BetterSafeERC20} from '@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol';
import {ReentrancyLockModifiers} from '@crane/contracts/access/reentrancy/ReentrancyLockModifiers.sol';
import {MultiStepOwnableModifiers} from '@crane/contracts/access/ERC8023/MultiStepOwnableModifiers.sol';

import {IRebasingClaimToken} from 'contracts/interfaces/IRebasingClaimToken.sol';
import {IStandardExchangeIn} from 'contracts/interfaces/IStandardExchangeIn.sol';
import {IStandardExchangeOut} from 'contracts/interfaces/IStandardExchangeOut.sol';
import {IDETF} from 'contracts/interfaces/IDETF.sol';
import {IDetf} from 'contracts/interfaces/detf/IDetf.sol';
import {IDetfErrors} from 'contracts/interfaces/IDetfErrors.sol';
import {IDETFNFTVault} from 'contracts/interfaces/IDETFNFTVault.sol';
import {RebasingDETFTokenRepo} from 'contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/RebasingDETFTokenRepo.sol';

contract RebasingDETFTokenTarget is IDetfErrors, ReentrancyLockModifiers, MultiStepOwnableModifiers, IRebasingClaimToken {
    using BetterSafeERC20 for IERC20;
    using RebasingDETFTokenRepo for RebasingDETFTokenRepo.Storage;

    function name() external pure returns (string memory) {
        return 'RebasingDETFToken';
    }

    function symbol() external pure returns (string memory) {
        return 'RDETF';
    }

    function decimals() external pure returns (uint8) {
        return 18;
    }

    function totalSupply() external view returns (uint256) {
        RebasingDETFTokenRepo.Storage storage layoutStruct = RebasingDETFTokenRepo._layoutStruct();
        uint256 rate = _getCurrentRedemptionRate(layoutStruct);
        return RebasingDETFTokenRepo._sharesToBalance(layoutStruct.totalShares, rate);
    }

    function balanceOf(address account) external view returns (uint256) {
        RebasingDETFTokenRepo.Storage storage layoutStruct = RebasingDETFTokenRepo._layoutStruct();
        uint256 rate = _getCurrentRedemptionRate(layoutStruct);
        return RebasingDETFTokenRepo._sharesToBalance(layoutStruct.sharesOf[account], rate);
    }

    function sharesOf(address account) external view returns (uint256) {
        return RebasingDETFTokenRepo._internalSharesToExternal(RebasingDETFTokenRepo._sharesOf(account));
    }

    function totalShares() external view returns (uint256) {
        return RebasingDETFTokenRepo._internalSharesToExternal(RebasingDETFTokenRepo._totalShares());
    }

    function redemptionRate() external view returns (uint256) {
        return _getCurrentRedemptionRate(RebasingDETFTokenRepo._layoutStruct());
    }

    function detf() external view returns (address) {
        return address(RebasingDETFTokenRepo._detf());
    }

    function setDetf(address detf_) external onlyOwner {
        RebasingDETFTokenRepo._setDetf(IDETF(detf_));
    }

    function detfNFTId() external view returns (uint256) {
        return RebasingDETFTokenRepo._detfNFTId();
    }

    function rateAsset() external view returns (IERC20) {
        return RebasingDETFTokenRepo._rateAsset();
    }

    function convertToShares(uint256 rebasingClaimAmount) external view returns (uint256 shares) {
        uint256 rate = _getCurrentRedemptionRate(RebasingDETFTokenRepo._layoutStruct());
        return RebasingDETFTokenRepo._internalSharesToExternal(RebasingDETFTokenRepo._balanceToShares(rebasingClaimAmount, rate));
    }

    function convertToClaim(uint256 shares) external view returns (uint256 rebasingClaimAmount) {
        uint256 rate = _getCurrentRedemptionRate(RebasingDETFTokenRepo._layoutStruct());
        uint256 internalShares = RebasingDETFTokenRepo._externalSharesToInternal(shares);
        return RebasingDETFTokenRepo._sharesToBalance(internalShares, rate);
    }

    function previewRedeem(uint256 rebasingClaimAmount) external view returns (uint256 wethOut) {
        wethOut = _previewExchangeIn(
            RebasingDETFTokenRepo._layoutStruct(), IERC20(address(this)), rebasingClaimAmount, RebasingDETFTokenRepo._rateAsset()
        );
    }

    function previewExchangeIn(IERC20 tokenIn, uint256 amountIn, IERC20 tokenOut)
        external
        view
        returns (uint256 amountOut)
    {
        amountOut = _previewExchangeIn(RebasingDETFTokenRepo._layoutStruct(), tokenIn, amountIn, tokenOut);
    }

    function previewExchangeOut(IERC20 tokenIn, IERC20 tokenOut, uint256 amountOut)
        external
        view
        returns (uint256 amountIn)
    {
        amountIn = _previewExchangeOut(RebasingDETFTokenRepo._layoutStruct(), tokenIn, tokenOut, amountOut);
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function allowance(address owner, address spender) external view returns (uint256) {
        return ERC20Repo._allowance(owner, spender);
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        ERC20Repo._approve(msg.sender, spender, amount);
        emit IERC20Events.Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        ERC20Repo._spendAllowance(ERC20Repo._layoutStruct(), from, msg.sender, amount);
        _transfer(from, to, amount);
        return true;
    }

    function mintFromNFTSale(uint256 lpShares, address recipient) external onlyOwner returns (uint256 rebasingClaimMinted) {
        if (lpShares == 0) revert ZeroAmount();

        RebasingDETFTokenRepo.Storage storage layoutStruct = RebasingDETFTokenRepo._layoutStruct();
        uint256 internalShares = RebasingDETFTokenRepo._externalSharesToInternal(lpShares);

        RebasingDETFTokenRepo._mintShares(layoutStruct, recipient, internalShares);

        uint256 rate = _getCurrentRedemptionRate(layoutStruct);
        rebasingClaimMinted = RebasingDETFTokenRepo._sharesToBalance(internalShares, rate);

        emit IRebasingClaimToken.Minted(recipient, lpShares, lpShares, rebasingClaimMinted);
        emit IERC20Events.Transfer(address(0), recipient, rebasingClaimMinted);
    }

    function redeem(uint256 rebasingClaimAmount, address recipient, bool pretransferred)
        external
        nonReentrant
        returns (uint256 wethOut)
    {
        if (rebasingClaimAmount == 0) revert ZeroAmount();

        RebasingDETFTokenRepo.Storage storage layoutStruct = RebasingDETFTokenRepo._layoutStruct();
        uint256 actualIn = _secureTokenTransfer(IERC20(address(this)), rebasingClaimAmount, pretransferred);
        wethOut = _executeCommonTokenClaim(layoutStruct, actualIn, recipient == address(0) ? msg.sender : recipient);
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

        RebasingDETFTokenRepo.Storage storage layoutStruct = RebasingDETFTokenRepo._layoutStruct();
        _requireSupportedExchangePath(layoutStruct, tokenIn, tokenOut);

        uint256 actualIn = _secureTokenTransfer(tokenIn, amountIn, pretransferred);
        amountOut = _executeCommonTokenClaim(layoutStruct, actualIn, recipient == address(0) ? msg.sender : recipient);
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

        RebasingDETFTokenRepo.Storage storage layoutStruct = RebasingDETFTokenRepo._layoutStruct();
        _requireSupportedExchangePath(layoutStruct, tokenIn, tokenOut);

        amountIn = _previewExchangeOut(layoutStruct, tokenIn, tokenOut, amountOut);
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

        uint256 actualAmountOut = _executeCommonTokenClaim(layoutStruct, amountIn, recipient == address(0) ? msg.sender : recipient);
        if (actualAmountOut < amountOut) {
            revert SlippageExceeded(amountOut, actualAmountOut);
        }

        if (depositedIn > amountIn) {
            IERC20(address(this)).safeTransfer(msg.sender, depositedIn - amountIn);
        }
    }

    function burnShares(uint256 rebasingClaimAmount, address owner, bool pretransferred)
        external
        onlyOwner
        nonReentrant
        returns (uint256 sharesBurned)
    {
        if (rebasingClaimAmount == 0) revert ZeroAmount();

        RebasingDETFTokenRepo.Storage storage layoutStruct = RebasingDETFTokenRepo._layoutStruct();
        uint256 rate = _getCurrentRedemptionRate(layoutStruct);
        uint256 internalSharesBurned = RebasingDETFTokenRepo._balanceToShares(rebasingClaimAmount, rate);

        address burnFrom = owner;
        if (pretransferred) {
            burnFrom = address(this);
        }

        if (layoutStruct.sharesOf[burnFrom] < internalSharesBurned) {
            revert InsufficientBalance(
                RebasingDETFTokenRepo._internalSharesToExternal(internalSharesBurned),
                RebasingDETFTokenRepo._internalSharesToExternal(layoutStruct.sharesOf[burnFrom])
            );
        }

        RebasingDETFTokenRepo._burnShares(layoutStruct, burnFrom, internalSharesBurned);
        sharesBurned = RebasingDETFTokenRepo._internalSharesToExternal(internalSharesBurned);

        emit IERC20Events.Transfer(burnFrom, address(0), rebasingClaimAmount);
    }

    function updateRedemptionRate() external {
        RebasingDETFTokenRepo.Storage storage layoutStruct = RebasingDETFTokenRepo._layoutStruct();
        uint256 oldRate = layoutStruct.cachedRedemptionRate;
        uint256 newRate = _calcCurrentRedemptionRate(layoutStruct);

        if (newRate != oldRate) {
            RebasingDETFTokenRepo._setCachedRedemptionRate(layoutStruct, newRate);
            emit IRebasingClaimToken.RedemptionRateUpdated(oldRate, newRate);
        }
    }

    function _transfer(address from, address to, uint256 amount) internal {
        if (from == address(0)) revert ZeroAmount();
        if (to == address(0)) revert ZeroAmount();

        RebasingDETFTokenRepo.Storage storage layoutStruct = RebasingDETFTokenRepo._layoutStruct();
        uint256 rate = _getCurrentRedemptionRate(layoutStruct);
        uint256 senderBalance = RebasingDETFTokenRepo._sharesToBalance(layoutStruct.sharesOf[from], rate);
        if (amount > senderBalance) {
            revert InsufficientBalance(amount, senderBalance);
        }

        uint256 shares = amount == senderBalance
            ? layoutStruct.sharesOf[from]
            : RebasingDETFTokenRepo._balanceToShares(amount, rate);
        if (shares == 0) revert ZeroAmount();

        if (layoutStruct.sharesOf[from] < shares) {
            revert InsufficientBalance(
                RebasingDETFTokenRepo._internalSharesToExternal(shares),
                RebasingDETFTokenRepo._internalSharesToExternal(layoutStruct.sharesOf[from])
            );
        }

        RebasingDETFTokenRepo._transferShares(layoutStruct, from, to, shares);

        emit IERC20Events.Transfer(from, to, amount);
    }

    function _configuredCommonToken(RebasingDETFTokenRepo.Storage storage layoutStruct_) internal view returns (IERC20) {
        return layoutStruct_.rateAsset;
    }

    function _requireSupportedExchangePath(
        RebasingDETFTokenRepo.Storage storage layoutStruct_,
        IERC20 tokenIn_,
        IERC20 tokenOut_
    ) internal view {
        if (address(tokenIn_) != address(this)) {
            revert InvalidToken(tokenIn_);
        }
        if (address(tokenOut_) != address(_configuredCommonToken(layoutStruct_))) {
            revert InvalidToken(tokenOut_);
        }
    }

    function _previewExchangeIn(
        RebasingDETFTokenRepo.Storage storage layoutStruct_,
        IERC20 tokenIn_,
        uint256 amountIn_,
        IERC20 tokenOut_
    ) internal view returns (uint256 amountOut_) {
        if (amountIn_ == 0) {
            return 0;
        }

        _requireSupportedExchangePath(layoutStruct_, tokenIn_, tokenOut_);

        uint256 reserveBptAmount = layoutStruct_.detf.previewRebasingDetfTokenReserveBpt(amountIn_);
        if (reserveBptAmount == 0) {
            return 0;
        }

        amountOut_ = IDetf(address(layoutStruct_.detf)).previewClaimLiquidity(reserveBptAmount);
    }

    function _previewExchangeOut(
        RebasingDETFTokenRepo.Storage storage layoutStruct_,
        IERC20 tokenIn_,
        IERC20 tokenOut_,
        uint256 amountOut_
    ) internal view returns (uint256 amountIn_) {
        if (amountOut_ == 0) {
            return 0;
        }

        _requireSupportedExchangePath(layoutStruct_, tokenIn_, tokenOut_);

        uint256 maxAmountIn = RebasingDETFTokenRepo._sharesToBalance(layoutStruct_.totalShares, _getCurrentRedemptionRate(layoutStruct_));
        if (maxAmountIn == 0) {
            revert IStandardExchangeOut.ExchangeOutNotAvailable();
        }

        uint256 maxAmountOut = _previewExchangeIn(layoutStruct_, tokenIn_, maxAmountIn, tokenOut_);
        if (maxAmountOut < amountOut_) {
            revert IStandardExchangeOut.ExchangeOutNotAvailable();
        }

        uint256 low = 0;
        uint256 high = maxAmountIn;

        while (low < high) {
            uint256 mid = low + ((high - low) / 2);
            uint256 quotedOut = _previewExchangeIn(layoutStruct_, tokenIn_, mid, tokenOut_);
            if (quotedOut >= amountOut_) {
                high = mid;
            } else {
                low = mid + 1;
            }
        }

        amountIn_ = high;
    }

    function _executeCommonTokenClaim(
        RebasingDETFTokenRepo.Storage storage layoutStruct_,
        uint256 rebasingClaimAmount_,
        address recipient_
    ) internal returns (uint256 amountOut_) {
        if (rebasingClaimAmount_ == 0) {
            revert ZeroAmount();
        }

        uint256 reserveBptAmount = layoutStruct_.detf.previewRebasingDetfTokenReserveBpt(rebasingClaimAmount_);
        uint256 rate = _getCurrentRedemptionRate(layoutStruct_);
        uint256 shares = RebasingDETFTokenRepo._balanceToShares(rebasingClaimAmount_, rate);

        if (layoutStruct_.sharesOf[address(this)] < shares) {
            revert InsufficientBalance(
                RebasingDETFTokenRepo._internalSharesToExternal(shares),
                RebasingDETFTokenRepo._internalSharesToExternal(layoutStruct_.sharesOf[address(this)])
            );
        }

        RebasingDETFTokenRepo._burnShares(layoutStruct_, address(this), shares);
        amountOut_ = IDetf(address(layoutStruct_.detf)).claimLiquidity(reserveBptAmount, recipient_);

        emit IRebasingClaimToken.Redeemed(
            msg.sender,
            recipient_,
            rebasingClaimAmount_,
            RebasingDETFTokenRepo._internalSharesToExternal(shares),
            amountOut_
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

    function _getCurrentRedemptionRate(RebasingDETFTokenRepo.Storage storage layoutStruct_) internal view returns (uint256) {
        if (layoutStruct_.lastRateUpdateBlock == block.number) {
            return layoutStruct_.cachedRedemptionRate;
        }

        return _calcCurrentRedemptionRate(layoutStruct_);
    }

    function _calcCurrentRedemptionRate(RebasingDETFTokenRepo.Storage storage layoutStruct_) internal view returns (uint256 rate) {
        uint256 totalShares_ = layoutStruct_.totalShares;
        if (totalShares_ == 0) {
            return ONE_WAD;
        }

        IDETFNFTVault.Position memory position = layoutStruct_.nftVault.getPosition(layoutStruct_.detfNFTId);
        if (position.originalShares == 0) {
            return ONE_WAD;
        }

        uint256 wethValue = layoutStruct_.detf.previewRebasingDetfTokenEthValue(position.originalShares);
        if (wethValue == 0) {
            return ONE_WAD;
        }

        rate = Math.mulDiv(wethValue, RebasingDETFTokenRepo._shareUnit(), totalShares_);
        if (rate == 0) {
            rate = 1;
        }
    }
}