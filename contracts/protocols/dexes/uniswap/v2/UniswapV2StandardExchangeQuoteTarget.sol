// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IUniswapV2Pair} from "@crane/contracts/interfaces/protocols/dexes/uniswap/v2/IUniswapV2Pair.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {ERC4626Repo} from "@crane/contracts/tokens/ERC4626/ERC4626Repo.sol";
import {UniswapV2FactoryAwareRepo} from "@crane/contracts/protocols/dexes/uniswap/v2/aware/UniswapV2FactoryAwareRepo.sol";
import {BetterMath} from "@crane/contracts/utils/math/BetterMath.sol";
import {ConstProdUtils} from "@crane/contracts/utils/math/ConstProdUtils.sol";
import {UniswapV2Utils} from "@crane/contracts/utils/math/UniswapV2Utils.sol";
import {UNISWAPV2_FEE_DENOMINATOR, UNISWAP_PROTOCOL_FEE_SHARE} from "@crane/contracts/constants/Constants.sol";
import {IStandardExchangeTransitionQuote} from "contracts/interfaces/IStandardExchangeTransitionQuote.sol";
import {VaultFeeOracleQueryAwareRepo} from "contracts/oracles/fee/VaultFeeOracleQueryAwareRepo.sol";
import {UniswapV2StandardExchangeCommon} from "contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeCommon.sol";

abstract contract UniswapV2StandardExchangeQuoteTarget is UniswapV2StandardExchangeCommon, IStandardExchangeTransitionQuote {
    struct QuoteState {
        address exchange;
        address asset;
        address holder;
        uint256 holderShares;
        uint256 actualLp;
        uint256 poolHeldLp;
        uint256 knownBalance;
        uint256 opposingBalance;
        UnIV2IndexSourceReserves pool;
        UniV2StrategyVault vault;
    }

    function quoteState(address asset_, address holder_) external view returns (bytes memory state_, uint256 holderAssets_) {
        QuoteState memory q;
        q.exchange = address(this);
        q.asset = asset_;
        q.holder = holder_;
        q.holderShares = IERC20(address(this)).balanceOf(holder_);
        q.pool.pool = IUniswapV2Pair(address(ERC4626Repo._reserveAsset()));
        bool lpAsset_ = asset_ == address(q.pool.pool);
        // LP-denominated claims still checkpoint the two pool legs in token0 order.
        _loadIndexSourceReserves(q.pool, lpAsset_ ? IERC20(address(0)) : IERC20(asset_));
        if (!lpAsset_ && asset_ != q.pool.token0 && asset_ != q.pool.token1) revert UnsupportedQuoteAsset(asset_);
        address known_ = lpAsset_ ? q.pool.token0 : asset_;
        _loadStrategyVault(q.vault, IERC20(known_));
        q.actualLp = q.pool.pool.balanceOf(address(this));
        q.poolHeldLp = q.pool.pool.balanceOf(address(q.pool.pool));
        q.knownBalance = IERC20(known_).balanceOf(address(q.pool.pool));
        q.opposingBalance = IERC20(known_ == q.pool.token0 ? q.pool.token1 : q.pool.token0).balanceOf(address(q.pool.pool));
        return (abi.encode(q), _quoteAssets(q, q.holderShares));
    }

    function quoteTransition(bytes calldata state_, Operation operation_, uint256 amount_)
        external view returns (bytes memory nextState_, uint256 amountIn_, uint256 amountOut_, uint256 holderAssetsAfter_)
    {
        QuoteState memory q = _decodeQuote(state_);
        if (operation_ == Operation.ReceiveShares) {
            q.holderShares += amount_;
            if (q.holderShares > q.vault.vaultTotalShares) revert InvalidQuoteState();
            return (abi.encode(q), amount_, amount_, _quoteAssets(q, q.holderShares));
        }
        _calcVaultFee(q.pool, q.vault);
        if (q.holder == address(VaultFeeOracleQueryAwareRepo._feeOracle().feeTo())) q.holderShares += q.vault.feeShares;
        amountIn_ = amount_;
        bool lpAsset_ = q.asset == address(q.pool.pool);
        if (operation_ == Operation.DepositExactIn) {
            if (!lpAsset_ && q.actualLp != q.vault.vaultLpReserve) revert InvalidQuoteState();
            uint256 lp_ = lpAsset_ ? amount_ : _quoteDeposit(q, amount_);
            amountOut_ = BetterMath._convertToSharesDown(
                lp_, lpAsset_ ? q.actualLp : q.vault.vaultLpReserve,
                q.vault.vaultTotalShares, ERC4626Repo._decimalOffset()
            );
            q.holderShares += amountOut_;
            q.vault.vaultTotalShares += amountOut_;
            q.actualLp += lp_;
        } else {
            uint256 lp_;
            if (operation_ == Operation.WithdrawExactOut) {
                lp_ = lpAsset_ ? amount_ : ConstProdUtils._quoteZapOutToTargetWithFee(
                    amount_, q.pool.totalSupply, q.pool.knownReserve, q.pool.opposingReserve,
                    q.pool.opTokenFeePercent, UNISWAPV2_FEE_DENOMINATOR, q.pool.kLast,
                    UNISWAP_PROTOCOL_FEE_SHARE, _quoteFeeTo() != address(0)
                );
                amountIn_ = BetterMath._convertToSharesUp(
                    lp_, q.vault.vaultLpReserve, q.vault.vaultTotalShares, ERC4626Repo._decimalOffset()
                );
            } else {
                lp_ = BetterMath._convertToAssetsDown(
                    amount_, q.vault.vaultLpReserve, q.vault.vaultTotalShares, ERC4626Repo._decimalOffset()
                );
            }
            if (amountIn_ > q.holderShares) revert InsufficientQuoteShares(amountIn_, q.holderShares);
            q.holderShares -= amountIn_;
            q.vault.vaultTotalShares -= amountIn_;
            q.actualLp -= lp_;
            amountOut_ = lpAsset_ ? lp_ : _quoteWithdraw(q, lp_);
        }
        q.vault.vaultLpReserve = q.actualLp;
        q.vault.knownTokenLastOwnedSourceReserve = BetterMath._mulDiv(q.actualLp, q.pool.knownReserve, q.pool.totalSupply);
        q.vault.opTokenLastOwnedSourceReserve = BetterMath._mulDiv(q.actualLp, q.pool.opposingReserve, q.pool.totalSupply);
        q.vault.feeShares = 0;
        return (abi.encode(q), amountIn_, amountOut_, _quoteAssets(q, q.holderShares));
    }

    function quoteAssets(bytes calldata state_, uint256 shares_) external view returns (uint256) {
        return _quoteAssets(_decodeQuote(state_), shares_);
    }

    function quoteExternalDeposit(bytes calldata state_, address tokenIn_, uint256 amountIn_)
        external view returns (bytes memory nextState_, uint256 sharesOut_, uint256 holderAssetsAfter_)
    {
        QuoteState memory q = _decodeQuote(state_);
        if (tokenIn_ == address(q.pool.pool)) {
            _calcVaultFee(q.pool, q.vault);
            if (q.holder == address(VaultFeeOracleQueryAwareRepo._feeOracle().feeTo())) q.holderShares += q.vault.feeShares;
            sharesOut_ = BetterMath._convertToSharesDown(
                amountIn_, q.actualLp, q.vault.vaultTotalShares, ERC4626Repo._decimalOffset()
            );
            q.vault.vaultTotalShares += sharesOut_;
            q.actualLp += amountIn_;
            q.vault.vaultLpReserve = q.actualLp;
            q.vault.knownTokenLastOwnedSourceReserve = BetterMath._mulDiv(q.actualLp, q.pool.knownReserve, q.pool.totalSupply);
            q.vault.opTokenLastOwnedSourceReserve = BetterMath._mulDiv(q.actualLp, q.pool.opposingReserve, q.pool.totalSupply);
            q.vault.feeShares = 0;
        } else {
            if (tokenIn_ != q.pool.token0 && tokenIn_ != q.pool.token1) revert UnsupportedQuoteAsset(tokenIn_);
            address accounting_ = q.asset;
            if (q.asset == address(q.pool.pool)) q.asset = q.pool.token0;
            bool flipped = tokenIn_ != q.asset;
            if (flipped) _flipQuoteAsset(q);
            (bytes memory projected,, uint256 minted,) = IStandardExchangeTransitionQuote(address(this)).quoteTransition(
                abi.encode(q), Operation.DepositExactIn, amountIn_
            );
            q = abi.decode(projected, (QuoteState));
            q.holderShares -= minted;
            sharesOut_ = minted;
            if (flipped) _flipQuoteAsset(q);
            q.asset = accounting_;
        }
        return (abi.encode(q), sharesOut_, _quoteAssets(q, q.holderShares));
    }

    function _flipQuoteAsset(QuoteState memory q) private pure {
        q.asset = q.asset == q.pool.token0 ? q.pool.token1 : q.pool.token0;
        (q.knownBalance, q.opposingBalance) = (q.opposingBalance, q.knownBalance);
        (q.pool.knownReserve, q.pool.opposingReserve) = (q.pool.opposingReserve, q.pool.knownReserve);
        (q.pool.knownfeePercent, q.pool.opTokenFeePercent) = (q.pool.opTokenFeePercent, q.pool.knownfeePercent);
        (q.vault.knownTokenLastOwnedSourceReserve, q.vault.opTokenLastOwnedSourceReserve) =
            (q.vault.opTokenLastOwnedSourceReserve, q.vault.knownTokenLastOwnedSourceReserve);
    }

    function quoteExternalExchange(bytes calldata state_, address tokenIn_, uint256 amountIn_)
        external view returns (bytes memory nextState_, uint256 amountOut_, uint256 holderAssetsAfter_)
    {
        QuoteState memory q = _decodeQuote(state_);
        address opposing_ = q.asset == q.pool.token0 ? q.pool.token1 : q.pool.token0;
        if (q.asset == address(q.pool.pool)) {
            if (tokenIn_ != q.pool.token0 && tokenIn_ != q.pool.token1) revert UnsupportedQuoteAsset(tokenIn_);
            q.asset = q.pool.token0;
            bool flipped = tokenIn_ != q.asset;
            if (flipped) _flipQuoteAsset(q);
            amountOut_ = _quoteDeposit(q, amountIn_);
            if (flipped) _flipQuoteAsset(q);
            q.asset = address(q.pool.pool);
            // The live pass-through returns newly minted LP to its caller and
            // rejects any change to the SE's held LP, including pool fee LP.
            if (q.actualLp != q.vault.vaultLpReserve) revert InvalidQuoteState();
        } else if (tokenIn_ == address(q.pool.pool)) {
            // These LP tokens belong to the separate caller. Retain the SE's own
            // LP and fee checkpoints; only the shared pool state changes.
            amountOut_ = _quoteWithdraw(q, amountIn_);
            if (q.actualLp != q.vault.vaultLpReserve) revert InvalidQuoteState();
        } else if (tokenIn_ == opposing_) {
            amountOut_ = ConstProdUtils._saleQuote(
                amountIn_, q.pool.opposingReserve, q.pool.knownReserve,
                q.pool.opTokenFeePercent, UNISWAPV2_FEE_DENOMINATOR
            );
            q.knownBalance -= amountOut_;
            q.opposingBalance += amountIn_;
            q.pool.knownReserve = q.knownBalance;
            q.pool.opposingReserve = q.opposingBalance;
        } else revert UnsupportedQuoteAsset(tokenIn_);
        return (abi.encode(q), amountOut_, _quoteAssets(q, q.holderShares));
    }

    function quoteTotalSupply(bytes calldata state_) external view returns (uint256) {
        return _decodeQuote(state_).vault.vaultTotalShares;
    }

    function quoteShareBalance(bytes calldata state_) external view returns (uint256) {
        return _decodeQuote(state_).holderShares;
    }

    function _decodeQuote(bytes calldata state_) private view returns (QuoteState memory q) {
        q = abi.decode(state_, (QuoteState));
        if (q.exchange != address(this) || address(q.pool.pool) != address(ERC4626Repo._reserveAsset())) revert InvalidQuoteState();
    }

    function _quoteAssets(QuoteState memory q, uint256 shares_) private view returns (uint256) {
        UniV2StrategyVault memory v = abi.decode(abi.encode(q.vault), (UniV2StrategyVault));
        _calcVaultFee(q.pool, v);
        uint256 lp_ = BetterMath._convertToAssetsDown(shares_, v.vaultLpReserve, v.vaultTotalShares, ERC4626Repo._decimalOffset());
        if (q.asset == address(q.pool.pool)) return lp_;
        return UniswapV2Utils._quoteWithdrawSwapFee(
            lp_, q.pool.totalSupply, q.pool.knownReserve, q.pool.opposingReserve, q.pool.opTokenFeePercent,
            UNISWAPV2_FEE_DENOMINATOR, q.pool.kLast, _quoteFeeTo() != address(0)
        );
    }

    function _quoteFeeTo() private view returns (address) {
        return UniswapV2FactoryAwareRepo._uniswapV2Factory().feeTo();
    }

    function _quoteMintPoolFee(QuoteState memory q) private view returns (uint256 fee_) {
        address recipient_ = _quoteFeeTo();
        if (recipient_ != address(0)) {
            fee_ = ConstProdUtils._calculateProtocolFee(
                q.pool.totalSupply, q.pool.knownReserve * q.pool.opposingReserve, q.pool.kLast,
                UNISWAP_PROTOCOL_FEE_SHARE
            );
            q.pool.totalSupply += fee_;
            if (recipient_ == address(this)) q.actualLp += fee_;
            if (recipient_ == address(q.pool.pool)) q.poolHeldLp += fee_;
        } else q.pool.kLast = 0;
    }

    function _quoteDeposit(QuoteState memory q, uint256 amount_) private view returns (uint256 lp_) {
        uint256 sold_ = ConstProdUtils._swapDepositSaleAmt(amount_, q.pool.knownReserve, q.pool.knownfeePercent);
        uint256 other_ = ConstProdUtils._saleQuote(
            sold_, q.pool.knownReserve, q.pool.opposingReserve, q.pool.knownfeePercent, UNISWAPV2_FEE_DENOMINATOR
        );
        q.knownBalance += sold_;
        q.opposingBalance -= other_;
        q.pool.knownReserve = q.knownBalance;
        q.pool.opposingReserve = q.opposingBalance;
        uint256 known_ = amount_ - sold_;
        uint256 optimal_ = BetterMath._mulDiv(known_, q.pool.opposingReserve, q.pool.knownReserve);
        if (optimal_ <= other_) other_ = optimal_;
        else known_ = BetterMath._mulDiv(other_, q.pool.knownReserve, q.pool.opposingReserve);
        _quoteMintPoolFee(q);
        lp_ = BetterMath._min(
            BetterMath._mulDiv(known_, q.pool.totalSupply, q.pool.knownReserve),
            BetterMath._mulDiv(other_, q.pool.totalSupply, q.pool.opposingReserve)
        );
        q.pool.totalSupply += lp_;
        q.knownBalance += known_;
        q.opposingBalance += other_;
        q.pool.knownReserve = q.knownBalance;
        q.pool.opposingReserve = q.opposingBalance;
        if (_quoteFeeTo() != address(0)) q.pool.kLast = q.pool.knownReserve * q.pool.opposingReserve;
    }

    function _quoteWithdraw(QuoteState memory q, uint256 lp_) private view returns (uint256 assets_) {
        uint256 burned_ = lp_ + q.poolHeldLp;
        _quoteMintPoolFee(q);
        q.poolHeldLp -= burned_ - lp_;
        uint256 known_ = BetterMath._mulDiv(burned_, q.knownBalance, q.pool.totalSupply);
        uint256 other_ = BetterMath._mulDiv(burned_, q.opposingBalance, q.pool.totalSupply);
        q.pool.totalSupply -= burned_;
        q.knownBalance -= known_;
        q.opposingBalance -= other_;
        q.pool.knownReserve = q.knownBalance;
        q.pool.opposingReserve = q.opposingBalance;
        if (_quoteFeeTo() != address(0)) q.pool.kLast = q.pool.knownReserve * q.pool.opposingReserve;
        uint256 proceeds_ = ConstProdUtils._saleQuote(
            other_, q.pool.opposingReserve, q.pool.knownReserve, q.pool.opTokenFeePercent, UNISWAPV2_FEE_DENOMINATOR
        );
        q.knownBalance -= proceeds_;
        q.opposingBalance += other_;
        q.pool.knownReserve = q.knownBalance;
        q.pool.opposingReserve = q.opposingBalance;
        return known_ + proceeds_;
    }
}
