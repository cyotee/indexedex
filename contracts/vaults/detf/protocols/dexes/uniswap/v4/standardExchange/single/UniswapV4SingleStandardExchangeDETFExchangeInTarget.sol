// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeErrors} from "@crane/contracts/interfaces/IStandardExchangeErrors.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {BetterSafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {Math} from "@crane/contracts/utils/Math.sol";
import {DETFUsageFeeLib} from "contracts/vaults/detf/common/core/DETFUsageFeeLib.sol";
import {
    UniswapV4SingleStandardExchangeDETFCommon
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/single/UniswapV4SingleStandardExchangeDETFCommon.sol";
import {
    UniswapV4SingleStandardExchangeDETFRepo
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/single/UniswapV4SingleStandardExchangeDETFRepo.sol";

/// @title UniswapV4SingleStandardExchangeDETFExchangeInTarget
/// @notice Primary mint/burn routes (exact-in) + previews.
abstract contract UniswapV4SingleStandardExchangeDETFExchangeInTarget is UniswapV4SingleStandardExchangeDETFCommon {
    using BetterSafeERC20 for IERC20;

    function exchangeIn(
        IERC20 tokenIn_,
        uint256 amountIn_,
        IERC20 tokenOut_,
        uint256 minAmountOut_,
        address recipient_,
        bool pretransferred_,
        uint256 deadline_
    ) public virtual nonReentrant returns (uint256 amountOut_) {
        _requireActive(deadline_, amountIn_);
        if (recipient_ == address(0)) recipient_ = msg.sender;

        UniswapV4SingleStandardExchangeDETFRepo.Storage storage s = _s();

        // Burn DETF → share or SE token
        if (address(tokenIn_) == address(this)) {
            return _burnDetfExactIn(amountIn_, tokenOut_, minAmountOut_, recipient_, pretransferred_);
        }

        // Mint DETF
        if (address(tokenOut_) == address(this)) {
            _pokeListingOracle();
            _tryNaturalExpansion();

            bool firstMint = !s.isReserveLive;
            if (!firstMint) {
                _requireLive();
                if (!_isMintingAllowed()) {
                    revert UniswapV4SingleStandardExchangeDETFRepo.MintingNotAllowed(
                        _syntheticPrice(), s.mintThreshold
                    );
                }
            }

            (uint256 vaultShares_, uint256 pairNotional_) =
                _settleInventoryAndPairNotional(tokenIn_, amountIn_, pretransferred_, deadline_);

            amountOut_ = _mintDetfFromPairNotional(pairNotional_, vaultShares_, recipient_, firstMint);
            if (amountOut_ < minAmountOut_) {
                revert IStandardExchangeErrors.MinAmountNotMet(minAmountOut_, amountOut_);
            }
            _tryCompoundProtocolRewards();
            return amountOut_;
        }

        revert UniswapV4SingleStandardExchangeDETFRepo.UnsupportedRoute(tokenIn_, tokenOut_);
    }

    function previewExchangeIn(IERC20 tokenIn_, uint256 amountIn_, IERC20 tokenOut_)
        public
        view
        virtual
        returns (uint256 amountOut_)
    {
        if (amountIn_ == 0) return 0;
        UniswapV4SingleStandardExchangeDETFRepo.Storage storage s = _s();

        if (address(tokenIn_) == address(this)) {
            // Burn preview: usage fee then fair-share of inventory.
            (uint256 afterFee_,) = DETFUsageFeeLibPreview(amountIn_);
            uint256 supply = ERC20Repo._totalSupply();
            if (supply == 0) return 0;
            uint256 inv = s.standardExchangeVaultShare.balanceOf(address(this));
            uint256 sharesOut = Math.mulDiv(afterFee_, inv, supply);
            if (address(tokenOut_) == address(s.standardExchangeVaultShare)) return sharesOut;
            if (_isAllowlistedTokenIn(tokenOut_) && sharesOut > 0) {
                return s.standardExchangeVault.previewExchangeIn(
                    s.standardExchangeVaultShare, sharesOut, tokenOut_
                );
            }
            return 0;
        }

        if (address(tokenOut_) == address(this)) {
            uint256 pairNotional_ = _previewPairNotional(tokenIn_, amountIn_);
            MintSplit memory split_ = _splitMintedDetf(_quoteGrossDetfFromPairNotional(pairNotional_));
            return split_.userDetf;
        }
        return 0;
    }

    function DETFUsageFeeLibPreview(uint256 gross_) internal view returns (uint256 afterFee_, uint256 fee_) {
        return DETFUsageFeeLib._splitUsageFee(gross_, _usageFeeWad());
    }

    function _previewPairNotional(IERC20 tokenIn_, uint256 amountIn_) internal view returns (uint256) {
        UniswapV4SingleStandardExchangeDETFRepo.Storage storage s = _s();
        if (address(tokenIn_) == address(s.pairToken)) return amountIn_;
        if (address(tokenIn_) == address(s.standardExchangeVaultShare)) {
            return s.standardExchangeVault.previewExchangeIn(tokenIn_, amountIn_, s.pairToken);
        }
        if (_isAllowlistedTokenIn(tokenIn_)) {
            return s.standardExchangeVault.previewExchangeIn(tokenIn_, amountIn_, s.pairToken);
        }
        return 0;
    }

    function _settleInventoryAndPairNotional(
        IERC20 tokenIn_,
        uint256 amountIn_,
        bool pretransferred_,
        uint256 deadline_
    ) internal returns (uint256 vaultShares_, uint256 pairNotional_) {
        UniswapV4SingleStandardExchangeDETFRepo.Storage storage s = _s();

        if (address(tokenIn_) == address(s.pairToken)) {
            uint256 pulled_ = _pullToken(tokenIn_, amountIn_, pretransferred_);
            pairNotional_ = pulled_;
            tokenIn_.safeTransfer(address(s.standardExchangeVault), pulled_);
            vaultShares_ = s.standardExchangeVault.exchangeIn(
                tokenIn_, pulled_, s.standardExchangeVaultShare, 0, address(this), true, deadline_
            );
        } else if (address(tokenIn_) == address(s.standardExchangeVaultShare)) {
            vaultShares_ = _pullToken(tokenIn_, amountIn_, pretransferred_);
            pairNotional_ =
                s.standardExchangeVault.previewExchangeIn(tokenIn_, vaultShares_, s.pairToken);
        } else if (_isAllowlistedTokenIn(tokenIn_)) {
            uint256 pulled_ = _pullToken(tokenIn_, amountIn_, pretransferred_);
            pairNotional_ = s.standardExchangeVault.previewExchangeIn(tokenIn_, pulled_, s.pairToken);
            tokenIn_.safeTransfer(address(s.standardExchangeVault), pulled_);
            vaultShares_ = s.standardExchangeVault.exchangeIn(
                tokenIn_, pulled_, s.standardExchangeVaultShare, 0, address(this), true, deadline_
            );
        } else {
            revert UniswapV4SingleStandardExchangeDETFRepo.UnsupportedRoute(tokenIn_, IERC20(address(this)));
        }
    }

    function _mintDetfFromPairNotional(
        uint256 pairNotional_,
        uint256 /* vaultShares_ */,
        address recipient_,
        bool firstMint_
    ) internal returns (uint256 userOut_) {
        UniswapV4SingleStandardExchangeDETFRepo.Storage storage s = _s();
        MintSplit memory split_ = _splitMintedDetf(_quoteGrossDetfFromPairNotional(pairNotional_));

        _mintDetf(recipient_, split_.userDetf);
        if (split_.feeToDetf > 0) _mintDetf(_feeTo(), split_.feeToDetf);
        _routeInventoryDetf(split_.inventoryDetf);

        if (firstMint_) {
            UniswapV4SingleStandardExchangeDETFRepo._setReserveLive();
        }
        return split_.userDetf;
    }

    function _burnDetfExactIn(
        uint256 amountIn_,
        IERC20 tokenOut_,
        uint256 minAmountOut_,
        address recipient_,
        bool pretransferred_
    ) internal returns (uint256 amountOut_) {
        _pokeListingOracle();
        _requireLive();
        UniswapV4SingleStandardExchangeDETFRepo.Storage storage s = _s();
        if (!_isBurningAllowed()) {
            revert UniswapV4SingleStandardExchangeDETFRepo.BurningNotAllowed(_syntheticPrice(), s.burnThreshold);
        }

        if (!pretransferred_) {
            IERC20(address(this)).safeTransferFrom(msg.sender, address(this), amountIn_);
        }

        // Usage fee only on burn.
        (uint256 afterFee_, uint256 feeAmt_) = DETFUsageFeeLib._splitUsageFee(amountIn_, _usageFeeWad());
        // Fee stays as free DETF to feeTo (burn fee slice transferred).
        if (feeAmt_ > 0) IERC20(address(this)).safeTransfer(_feeTo(), feeAmt_);

        uint256 supply = ERC20Repo._totalSupply(); // full supply before burn of afterFee
        uint256 inv = s.standardExchangeVaultShare.balanceOf(address(this));
        if (inv == 0) revert UniswapV4SingleStandardExchangeDETFRepo.EmptyInventory();

        uint256 sharesOut = Math.mulDiv(afterFee_, inv, supply);
        if (sharesOut == 0) revert UniswapV4SingleStandardExchangeDETFRepo.EmptyInventory();

        _burnDetf(address(this), afterFee_);

        if (address(tokenOut_) == address(s.standardExchangeVaultShare)) {
            s.standardExchangeVaultShare.safeTransfer(recipient_, sharesOut);
            amountOut_ = sharesOut;
        } else if (_isAllowlistedTokenIn(tokenOut_)) {
            s.standardExchangeVaultShare.safeTransfer(address(s.standardExchangeVault), sharesOut);
            amountOut_ = s.standardExchangeVault.exchangeIn(
                s.standardExchangeVaultShare,
                sharesOut,
                tokenOut_,
                minAmountOut_,
                recipient_,
                true,
                block.timestamp
            );
        } else {
            revert UniswapV4SingleStandardExchangeDETFRepo.UnsupportedRoute(IERC20(address(this)), tokenOut_);
        }

        if (amountOut_ < minAmountOut_) {
            revert IStandardExchangeErrors.MinAmountNotMet(minAmountOut_, amountOut_);
        }
        _tryNaturalExpansion();
        _tryCompoundProtocolRewards();
    }
}
