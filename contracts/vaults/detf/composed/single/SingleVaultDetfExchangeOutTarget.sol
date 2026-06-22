// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ReentrancyLockModifiers} from "@crane/contracts/access/reentrancy/ReentrancyLockModifiers.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {ERC4626Repo} from "@crane/contracts/tokens/ERC4626/ERC4626Repo.sol";
import {BetterSafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";

import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {SingleVaultDetfCommon} from "contracts/vaults/detf/composed/single/SingleVaultDetfCommon.sol";
import {SingleVaultDetfRepo} from "contracts/vaults/detf/composed/single/SingleVaultDetfRepo.sol";

contract SingleVaultDetfExchangeOutTarget is SingleVaultDetfCommon, ReentrancyLockModifiers {
    using BetterSafeERC20 for IERC20;
    using SingleVaultDetfRepo for SingleVaultDetfRepo.Storage;

    function exchangeOut(
        IERC20 tokenIn,
        uint256 maxAmountIn,
        IERC20 tokenOut,
        uint256 amountOut,
        address recipient,
        bool pretransferred,
        uint256 deadline
    ) external nonReentrant returns (uint256 amountIn_) {
        if (block.timestamp > deadline) {
            revert DeadlineExceeded(deadline, block.timestamp);
        }

        SingleVaultDetfRepo.Storage storage layoutStruct = SingleVaultDetfRepo._layoutStruct();
        if (!_isInitialized()) {
            revert ReservePoolNotInitialized();
        }
        if (recipient == address(0)) {
            recipient = msg.sender;
        }

        if ((_isWethToken(layoutStruct, tokenIn) && _isRichToken(layoutStruct, tokenOut)) || (_isRichToken(layoutStruct, tokenIn) && _isWethToken(layoutStruct, tokenOut))) {
            amountIn_ = layoutStruct.wethRichVault.previewExchangeOut(tokenIn, tokenOut, amountOut);
            if (amountIn_ > maxAmountIn) {
                revert SlippageExceeded(maxAmountIn, amountIn_);
            }
            uint256 actualIn = _secureTokenTransfer(tokenIn, amountIn_, pretransferred);
            tokenIn.safeTransfer(address(layoutStruct.wethRichVault), actualIn);
            layoutStruct.wethRichVault.exchangeOut(tokenIn, actualIn, tokenOut, amountOut, recipient, true, deadline);
            return actualIn;
        }

        if (_isChirToken(tokenIn) && _isWethToken(layoutStruct, tokenOut)) {
            uint256 reserveSpotPrice = _calcReserveSpotPrice();
            if (!_isBurningAllowed(layoutStruct, reserveSpotPrice)) {
                revert BurningNotAllowed(reserveSpotPrice, layoutStruct.burnThreshold);
            }

            uint256 vaultSharesNeeded =
                layoutStruct.wethRichVault.previewExchangeOut(IERC20(address(layoutStruct.wethRichVault)), layoutStruct.wethToken, amountOut);
            uint256 bptIn = _previewBptInForProportionalVaultTokenOut(layoutStruct, vaultSharesNeeded);
            amountIn_ = _previewChirRedemptionAmountForVaultSharesOut(layoutStruct, vaultSharesNeeded);

            if (amountIn_ > maxAmountIn) {
                revert SlippageExceeded(maxAmountIn, amountIn_);
            }

            ERC20Repo._burn(pretransferred ? address(this) : msg.sender, amountIn_);

            (uint256 chirAmountOut, uint256 vaultSharesOut) = _exitReservePoolProportionalForBridge(layoutStruct, bptIn);
            _redepositChirToReservePool(layoutStruct, chirAmountOut);
            uint256 wethOut = _redeemVaultSharesToWeth(layoutStruct, vaultSharesOut, address(this), deadline);

            if (wethOut < amountOut) {
                revert SlippageExceeded(amountOut, wethOut);
            }

            layoutStruct.wethToken.safeTransfer(recipient, amountOut);
            if (wethOut > amountOut) {
                layoutStruct.wethToken.safeTransfer(msg.sender, wethOut - amountOut);
            }

            _syncLastTotalAssetsFromReservePool(layoutStruct);
            return amountIn_;
        }

        if (_isRichirToken(tokenIn) && _isWethToken(layoutStruct, tokenOut)) {
            amountIn_ = _previewRichirToWethExact(layoutStruct, amountOut);
            if (amountIn_ > maxAmountIn) {
                revert SlippageExceeded(maxAmountIn, amountIn_);
            }

            uint256 actualIn = _secureTokenTransfer(tokenIn, amountIn_, pretransferred);
            uint256 bptIn = _previewRichirRedemptionBptIn(layoutStruct, actualIn);

            tokenIn.safeTransfer(address(layoutStruct._richirToken()), actualIn);
            layoutStruct._richirToken().burnShares(actualIn, address(this), true);

            uint256 vaultSharesOut = _exitReservePoolToVaultShares(layoutStruct, bptIn);
            uint256 wethOut = _redeemVaultSharesToWeth(layoutStruct, vaultSharesOut, address(this), deadline);

            if (wethOut < amountOut) {
                revert SlippageExceeded(amountOut, wethOut);
            }

            layoutStruct.wethToken.safeTransfer(recipient, amountOut);
            if (wethOut > amountOut) {
                layoutStruct.wethToken.safeTransfer(msg.sender, wethOut - amountOut);
            }

            _syncLastTotalAssetsFromReservePool(layoutStruct);
            return actualIn;
        }

        revert IStandardExchangeOut.ExchangeOutNotAvailable();
    }
}