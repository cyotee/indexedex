// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;


/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ReentrancyLockModifiers} from "@crane/contracts/access/reentrancy/ReentrancyLockModifiers.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {ERC4626Repo} from "@crane/contracts/tokens/ERC4626/ERC4626Repo.sol";
import {BetterSafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {SingleVaultDetfCommon} from "contracts/vaults/detf/composed/single/SingleVaultDetfCommon.sol";
import {SingleVaultDetfRepo} from "contracts/vaults/detf/composed/single/SingleVaultDetfRepo.sol";

contract SingleVaultDetfExchangeInTarget is SingleVaultDetfCommon, ReentrancyLockModifiers {
    using BetterSafeERC20 for IERC20;
    using SingleVaultDetfRepo for SingleVaultDetfRepo.Storage;

    function exchangeIn(
        IERC20 tokenIn,
        uint256 amountIn,
        IERC20 tokenOut,
        uint256 minAmountOut,
        address recipient,
        bool pretransferred,
        uint256 deadline
    ) external nonReentrant returns (uint256 amountOut_) {
        if (block.timestamp > deadline) {
            revert DeadlineExceeded(deadline, block.timestamp);
        }
        
        if (amountIn == 0) {
            revert ZeroAmount();
        }

        SingleVaultDetfRepo.Storage storage layoutStruct = SingleVaultDetfRepo._layoutStruct();
        if (!_isInitialized()) {
            revert ReservePoolNotInitialized();
        }
        if (recipient == address(0)) {
            recipient = msg.sender;
        }

        if ((_isRateAsset(layoutStruct, tokenIn) && _isPairToken(layoutStruct, tokenOut)) || (_isPairToken(layoutStruct, tokenIn) && _isRateAsset(layoutStruct, tokenOut))) {
            uint256 actualIn = _secureTokenTransfer(tokenIn, amountIn, pretransferred);
            tokenIn.safeTransfer(address(layoutStruct.underlyingVault), actualIn);
            amountOut_ = layoutStruct.underlyingVault.exchangeIn(tokenIn, actualIn, tokenOut, minAmountOut, recipient, true, deadline);
            return amountOut_;
        }

        if (_isRateAsset(layoutStruct, tokenIn) && _isRebasingClaimToken(tokenOut)) {
            uint256 actualIn = _secureTokenTransfer(tokenIn, amountIn, pretransferred);
            amountOut_ = _mintRebasingClaimFromRateAsset(layoutStruct, actualIn, recipient, deadline);
            if (amountOut_ < minAmountOut) {
                revert SlippageExceeded(minAmountOut, amountOut_);
            }
            return amountOut_;
        }

        if (_isPairToken(layoutStruct, tokenIn) && _isRebasingClaimToken(tokenOut)) {
            uint256 actualIn = _secureTokenTransfer(tokenIn, amountIn, pretransferred);
            uint256 wethAmount = _convertPairToRateAsset(layoutStruct, actualIn, deadline);
            amountOut_ = _mintRebasingClaimFromRateAsset(layoutStruct, wethAmount, recipient, deadline);
            if (amountOut_ < minAmountOut) {
                revert SlippageExceeded(minAmountOut, amountOut_);
            }
            return amountOut_;
        }

        if (_isDetfToken(tokenIn) && _isRateAsset(layoutStruct, tokenOut)) {
            uint256 reserveSpotPrice = _calcReserveSpotPrice();
            if (!_isBurningAllowed(layoutStruct, reserveSpotPrice)) {
                revert BurningNotAllowed(reserveSpotPrice, layoutStruct.burnThreshold);
            }

            uint256 bptIn = _previewDetfRedemptionBptIn(amountIn);
            ERC20Repo._burn(pretransferred ? address(this) : msg.sender, amountIn);

            (uint256 detfAmountOut, uint256 vaultSharesOut) = _exitReservePoolProportionalForBridge(layoutStruct, bptIn);
            _redepositDetfToReservePool(layoutStruct, detfAmountOut);
            amountOut_ = _redeemVaultSharesToWeth(layoutStruct, vaultSharesOut, recipient, deadline);

            if (amountOut_ < minAmountOut) {
                revert SlippageExceeded(minAmountOut, amountOut_);
            }

            _syncLastTotalAssetsFromReservePool(layoutStruct);
            return amountOut_;
        }

        if (_isRebasingClaimToken(tokenIn) && _isRateAsset(layoutStruct, tokenOut)) {
            uint256 actualIn = _secureTokenTransfer(tokenIn, amountIn, pretransferred);
            uint256 bptIn = _previewRebasingClaimRedemptionBptIn(layoutStruct, actualIn);

            tokenIn.safeTransfer(address(layoutStruct._rebasingClaimToken()), actualIn);
            layoutStruct._rebasingClaimToken().burnShares(actualIn, address(this), true);

            uint256 vaultSharesOut = _exitReservePoolToVaultShares(layoutStruct, bptIn);
            amountOut_ = _redeemVaultSharesToWeth(layoutStruct, vaultSharesOut, recipient, deadline);

            if (amountOut_ < minAmountOut) {
                revert SlippageExceeded(minAmountOut, amountOut_);
            }

            _syncLastTotalAssetsFromReservePool(layoutStruct);
            return amountOut_;
        }

        revert IStandardExchangeIn.ExchangeInNotAvailable();
    }

    function mintWithRateAsset(uint256 wethAmount, address recipient, bool pretransferred)
        external
        nonReentrant
        returns (uint256 detfMinted_)
    {
        if (wethAmount == 0) {
            revert ZeroAmount();
        }

        SingleVaultDetfRepo.Storage storage layoutStruct = SingleVaultDetfRepo._layoutStruct();
        if (!_isInitialized()) {
            revert ReservePoolNotInitialized();
        }

        uint256 reserveSpotPrice = _calcReserveSpotPrice();
        if (!_isMintingAllowed(layoutStruct, reserveSpotPrice)) {
            revert MintingNotAllowed(reserveSpotPrice, layoutStruct.mintThreshold);
        }

        if (recipient == address(0)) {
            recipient = msg.sender;
        }

        uint256 actualIn = _secureTokenTransfer(layoutStruct.rateAsset, wethAmount, pretransferred);

        (uint256 vaultShares,) = _depositWethIntoReservePool(layoutStruct, actualIn, block.timestamp);

        MintSplit memory mintSplit = _splitMintedDetfForVaultShares(layoutStruct, vaultShares);
        detfMinted_ = mintSplit.userDetf;
        if (mintSplit.feeToDetf > 0) {
            ERC20Repo._mint(address(layoutStruct._feeOracle().feeTo()), mintSplit.feeToDetf);
        }
        if (mintSplit.bondRewardDetf > 0) {
            ERC20Repo._mint(address(layoutStruct.detfNFTVault), mintSplit.bondRewardDetf);
        }
        ERC20Repo._mint(recipient, detfMinted_);
        _syncLastTotalAssetsFromReservePool(layoutStruct);
    }
}