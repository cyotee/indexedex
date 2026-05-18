// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ReentrancyLockModifiers} from "@crane/contracts/access/reentrancy/ReentrancyLockModifiers.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {ERC4626Repo} from "@crane/contracts/tokens/ERC4626/ERC4626Repo.sol";
import {BetterSafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";

import {IStandardExchangeOut} from "contracts/interfaces/IStandardExchangeOut.sol";
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
    ) external lock returns (uint256 amountIn_) {
        if (block.timestamp > deadline) {
            revert DeadlineExceeded(deadline, block.timestamp);
        }

        SingleVaultDetfRepo.Storage storage layout = SingleVaultDetfRepo._layout();
        if (!_isInitialized()) {
            revert ReservePoolNotInitialized();
        }
        if (recipient == address(0)) {
            recipient = msg.sender;
        }

        if ((_isWethToken(layout, tokenIn) && _isRichToken(layout, tokenOut)) || (_isRichToken(layout, tokenIn) && _isWethToken(layout, tokenOut))) {
            amountIn_ = layout.wethRichVault.previewExchangeOut(tokenIn, tokenOut, amountOut);
            if (amountIn_ > maxAmountIn) {
                revert SlippageExceeded(maxAmountIn, amountIn_);
            }
            uint256 actualIn = _secureTokenTransfer(tokenIn, amountIn_, pretransferred);
            tokenIn.safeTransfer(address(layout.wethRichVault), actualIn);
            layout.wethRichVault.exchangeOut(tokenIn, actualIn, tokenOut, amountOut, recipient, true, deadline);
            return actualIn;
        }

        if (_isChirToken(tokenIn) && _isWethToken(layout, tokenOut)) {
            uint256 reserveSpotPrice = _calcReserveSpotPrice();
            if (!_isBurningAllowed(layout, reserveSpotPrice)) {
                revert BurningNotAllowed(reserveSpotPrice, layout.burnThreshold);
            }

            uint256 vaultSharesNeeded =
                layout.wethRichVault.previewExchangeOut(IERC20(address(layout.wethRichVault)), layout.wethToken, amountOut);
            uint256 bptIn = _previewBptInForProportionalVaultTokenOut(layout, vaultSharesNeeded);
            amountIn_ = _previewChirRedemptionAmountForVaultSharesOut(layout, vaultSharesNeeded);

            if (amountIn_ > maxAmountIn) {
                revert SlippageExceeded(maxAmountIn, amountIn_);
            }

            ERC20Repo._burn(pretransferred ? address(this) : msg.sender, amountIn_);

            (uint256 chirAmountOut, uint256 vaultSharesOut) = _exitReservePoolProportionalForBridge(layout, bptIn);
            _redepositChirToReservePool(layout, chirAmountOut);
            uint256 wethOut = _redeemVaultSharesToWeth(layout, vaultSharesOut, address(this), deadline);

            if (wethOut < amountOut) {
                revert SlippageExceeded(amountOut, wethOut);
            }

            layout.wethToken.safeTransfer(recipient, amountOut);
            if (wethOut > amountOut) {
                layout.wethToken.safeTransfer(msg.sender, wethOut - amountOut);
            }

            ERC4626Repo._setLastTotalAssets(IERC20(layout.reservePool).balanceOf(address(this)));
            return amountIn_;
        }

        if (_isRichirToken(tokenIn) && _isWethToken(layout, tokenOut)) {
            amountIn_ = _previewRichirToWethExact(layout, amountOut);
            if (amountIn_ > maxAmountIn) {
                revert SlippageExceeded(maxAmountIn, amountIn_);
            }

            uint256 actualIn = _secureTokenTransfer(tokenIn, amountIn_, pretransferred);
            uint256 bptIn = _previewRichirRedemptionBptIn(layout, actualIn);

            tokenIn.safeTransfer(address(layout._richirToken()), actualIn);
            layout._richirToken().burnShares(actualIn, address(this), true);

            uint256 vaultSharesOut = _exitReservePoolToVaultShares(layout, bptIn);
            uint256 wethOut = _redeemVaultSharesToWeth(layout, vaultSharesOut, address(this), deadline);

            if (wethOut < amountOut) {
                revert SlippageExceeded(amountOut, wethOut);
            }

            layout.wethToken.safeTransfer(recipient, amountOut);
            if (wethOut > amountOut) {
                layout.wethToken.safeTransfer(msg.sender, wethOut - amountOut);
            }

            ERC4626Repo._setLastTotalAssets(IERC20(layout.reservePool).balanceOf(address(this)));
            return actualIn;
        }

        revert IStandardExchangeOut.ExchangeOutNotAvailable();
    }
}