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

import {IStandardExchangeIn} from "contracts/interfaces/IStandardExchangeIn.sol";
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
    ) external lock returns (uint256 amountOut_) {
        if (block.timestamp > deadline) {
            revert DeadlineExceeded(deadline, block.timestamp);
        }
        
        if (amountIn == 0) {
            revert ZeroAmount();
        }

        SingleVaultDetfRepo.Storage storage layout = SingleVaultDetfRepo._layout();
        if (!_isInitialized()) {
            revert ReservePoolNotInitialized();
        }
        if (recipient == address(0)) {
            recipient = msg.sender;
        }

        if ((_isWethToken(layout, tokenIn) && _isRichToken(layout, tokenOut)) || (_isRichToken(layout, tokenIn) && _isWethToken(layout, tokenOut))) {
            uint256 actualIn = _secureTokenTransfer(tokenIn, amountIn, pretransferred);
            tokenIn.safeTransfer(address(layout.wethRichVault), actualIn);
            amountOut_ = layout.wethRichVault.exchangeIn(tokenIn, actualIn, tokenOut, minAmountOut, recipient, true, deadline);
            return amountOut_;
        }

        if (_isWethToken(layout, tokenIn) && _isRichirToken(tokenOut)) {
            uint256 actualIn = _secureTokenTransfer(tokenIn, amountIn, pretransferred);
            amountOut_ = _mintRichirFromWeth(layout, actualIn, recipient, deadline);
            if (amountOut_ < minAmountOut) {
                revert SlippageExceeded(minAmountOut, amountOut_);
            }
            return amountOut_;
        }

        if (_isRichToken(layout, tokenIn) && _isRichirToken(tokenOut)) {
            uint256 actualIn = _secureTokenTransfer(tokenIn, amountIn, pretransferred);
            tokenIn.safeTransfer(address(layout.wethRichVault), actualIn);
            uint256 wethAmount = layout.wethRichVault.exchangeIn(
                tokenIn,
                actualIn,
                layout.wethToken,
                0,
                address(this),
                true,
                deadline
            );
            amountOut_ = _mintRichirFromWeth(layout, wethAmount, recipient, deadline);
            if (amountOut_ < minAmountOut) {
                revert SlippageExceeded(minAmountOut, amountOut_);
            }
            return amountOut_;
        }

        if (_isChirToken(tokenIn) && _isWethToken(layout, tokenOut)) {
            uint256 reserveSpotPrice = _calcReserveSpotPrice();
            if (!_isBurningAllowed(layout, reserveSpotPrice)) {
                revert BurningNotAllowed(reserveSpotPrice, layout.burnThreshold);
            }

            uint256 bptIn = _previewChirRedemptionBptIn(amountIn);
            ERC20Repo._burn(pretransferred ? address(this) : msg.sender, amountIn);

            (uint256 chirAmountOut, uint256 vaultSharesOut) = _exitReservePoolProportionalForBridge(layout, bptIn);
            _redepositChirToReservePool(layout, chirAmountOut);
            amountOut_ = _redeemVaultSharesToWeth(layout, vaultSharesOut, recipient, deadline);

            if (amountOut_ < minAmountOut) {
                revert SlippageExceeded(minAmountOut, amountOut_);
            }

            ERC4626Repo._setLastTotalAssets(IERC20(layout.reservePool).balanceOf(address(this)));
            return amountOut_;
        }

        if (_isRichirToken(tokenIn) && _isWethToken(layout, tokenOut)) {
            uint256 actualIn = _secureTokenTransfer(tokenIn, amountIn, pretransferred);
            uint256 bptIn = _previewRichirRedemptionBptIn(layout, actualIn);

            tokenIn.safeTransfer(address(layout._richirToken()), actualIn);
            layout._richirToken().burnShares(actualIn, address(this), true);

            uint256 vaultSharesOut = _exitReservePoolToVaultShares(layout, bptIn);
            amountOut_ = _redeemVaultSharesToWeth(layout, vaultSharesOut, recipient, deadline);

            if (amountOut_ < minAmountOut) {
                revert SlippageExceeded(minAmountOut, amountOut_);
            }

            ERC4626Repo._setLastTotalAssets(IERC20(layout.reservePool).balanceOf(address(this)));
            return amountOut_;
        }

        revert IStandardExchangeIn.ExchangeInNotAvailable();
    }

    function mintWithWeth(uint256 wethAmount, address recipient, bool pretransferred)
        external
        lock
        returns (uint256 chirMinted_)
    {
        if (wethAmount == 0) {
            revert ZeroAmount();
        }

        SingleVaultDetfRepo.Storage storage layout = SingleVaultDetfRepo._layout();
        if (!_isInitialized()) {
            revert ReservePoolNotInitialized();
        }

        uint256 reserveSpotPrice = _calcReserveSpotPrice();
        if (!_isMintingAllowed(layout, reserveSpotPrice)) {
            revert MintingNotAllowed(reserveSpotPrice, layout.mintThreshold);
        }

        if (recipient == address(0)) {
            recipient = msg.sender;
        }

        uint256 actualIn = _secureTokenTransfer(layout.wethToken, wethAmount, pretransferred);

        IERC20(address(layout.wethToken)).safeTransfer(address(layout.wethRichVault), actualIn);
        uint256 vaultShares = layout.wethRichVault.exchangeIn(
            layout.wethToken,
            actualIn,
            IERC20(address(layout.wethRichVault)),
            0,
            address(this),
            true,
            block.timestamp
        );

        chirMinted_ = _calcProportionalChirForVaultShares(layout, vaultShares);
        _addLiquidityToReservePool(layout, 0, vaultShares);
        ERC20Repo._mint(recipient, chirMinted_);
        ERC4626Repo._setLastTotalAssets(IERC20(layout.reservePool).balanceOf(address(this)));
    }
}