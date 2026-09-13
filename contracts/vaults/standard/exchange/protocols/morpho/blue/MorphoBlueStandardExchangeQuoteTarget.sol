// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {Math} from "@crane/contracts/utils/Math.sol";
import {IMorpho, Market} from "@crane/contracts/external/morpho/blue/interfaces/IMorpho.sol";
import {MorphoBalancesLib} from "@crane/contracts/external/morpho/blue/libraries/periphery/MorphoBalancesLib.sol";
import {SharesMathLib} from "@crane/contracts/external/morpho/blue/libraries/SharesMathLib.sol";
import {IStandardExchangeTransitionQuote} from "contracts/interfaces/IStandardExchangeTransitionQuote.sol";
import {VaultFeeOracleQueryAwareRepo} from "contracts/oracles/fee/VaultFeeOracleQueryAwareRepo.sol";
import {MorphoBlueStandardExchangeRepo} from "contracts/vaults/standard/exchange/protocols/morpho/blue/MorphoBlueStandardExchangeRepo.sol";
import {MorphoBlueStandardExchangeCommon} from "contracts/vaults/standard/exchange/protocols/morpho/blue/MorphoBlueStandardExchangeCommon.sol";
import {IMorphoBlueStandardExchange} from "contracts/vaults/standard/exchange/protocols/morpho/blue/IMorphoBlueStandardExchange.sol";

abstract contract MorphoBlueStandardExchangeQuoteTarget is MorphoBlueStandardExchangeCommon, IStandardExchangeTransitionQuote {
    using SharesMathLib for uint256;
    using MorphoBalancesLib for IMorpho;

    struct QuoteState {
        address exchange;
        address holder;
        uint256 holderShares;
        uint256 supply;
        uint256 idle;
        uint256 marketAssets;
        uint256 marketShares;
        uint256 marketBorrowed;
        uint256 suppliedShares;
    }

    function quoteState(address asset_, address holder_)
        external view returns (bytes memory state_, uint256 holderAssets_)
    {
        if (asset_ != address(_loan())) revert UnsupportedQuoteAsset(asset_);
        QuoteState memory q;
        q.exchange = address(this);
        q.holder = holder_;
        q.holderShares = IERC20(address(this)).balanceOf(holder_);
        q.supply = ERC20Repo._totalSupply();
        q.idle = _idle();
        (q.marketAssets, q.marketShares, q.marketBorrowed,) = _morpho().expectedMarketBalances(_params());
        q.suppliedShares = _morpho().position(MorphoBlueStandardExchangeRepo._marketId(), address(this)).supplyShares;
        if (_morpho().feeRecipient() == address(this)) {
            Market memory market_ = _morpho().market(MorphoBlueStandardExchangeRepo._marketId());
            q.suppliedShares += q.marketShares - market_.totalSupplyShares;
        }
        return (abi.encode(q), _assetsFromSharesDown(q.holderShares, _quoteNav(q), q.supply));
    }

    function quoteTransition(bytes calldata state_, Operation operation_, uint256 amount_)
        external view returns (bytes memory nextState_, uint256 amountIn_, uint256 amountOut_, uint256 holderAssetsAfter_)
    {
        QuoteState memory q = abi.decode(state_, (QuoteState));
        if (q.exchange != address(this)) revert InvalidQuoteState();
        amountIn_ = amount_;
        if (operation_ == Operation.ReceiveShares) {
            q.holderShares += amount_;
            if (q.holderShares > q.supply) revert InvalidQuoteState();
            return (abi.encode(q), amount_, amount_, _assetsFromSharesDown(q.holderShares, _quoteNav(q), q.supply));
        }
        if (operation_ == Operation.DepositExactIn) {
            amountOut_ = _sharesFromAssetsDown(amount_, _quoteNav(q), q.supply);
            q.supply += amountOut_;
            q.holderShares += amountOut_;
            address feeTo_ = address(VaultFeeOracleQueryAwareRepo._feeOracle().feeTo());
            if (feeTo_ != address(0)) {
                uint256 fee_ = Math.mulDiv(
                    amountOut_, VaultFeeOracleQueryAwareRepo._feeOracle().usageFeeOfVault(address(this)), 1e18
                );
                q.supply += fee_;
                if (q.holder == feeTo_) q.holderShares += fee_;
            }
            uint256 supplied_ = amount_.toSharesDown(q.marketAssets, q.marketShares);
            q.suppliedShares += supplied_;
            q.marketShares += supplied_;
            q.marketAssets += amount_;
        } else {
            if (operation_ == Operation.WithdrawExactOut) {
                amountOut_ = amount_;
                amountIn_ = _sharesFromAssetsUp(amount_, _quoteNav(q), q.supply);
            } else {
                amountOut_ = _assetsFromSharesDown(amount_, _quoteNav(q), q.supply);
            }
            if (amountIn_ > q.holderShares) revert InsufficientQuoteShares(amountIn_, q.holderShares);
            q.holderShares -= amountIn_;
            q.supply -= amountIn_;
            _quotePay(q, amountOut_);
        }
        return (abi.encode(q), amountIn_, amountOut_, _assetsFromSharesDown(q.holderShares, _quoteNav(q), q.supply));
    }

    function _quoteNav(QuoteState memory q) private pure returns (uint256) {
        return q.idle + q.suppliedShares.toAssetsDown(q.marketAssets, q.marketShares);
    }

    function quoteAssets(bytes calldata state_, uint256 shares_) external view returns (uint256) {
        QuoteState memory q = abi.decode(state_, (QuoteState));
        if (q.exchange != address(this)) revert InvalidQuoteState();
        return _assetsFromSharesDown(shares_, _quoteNav(q), q.supply);
    }

    function quoteTotalSupply(bytes calldata state_) external view returns (uint256) {
        QuoteState memory q = abi.decode(state_, (QuoteState));
        if (q.exchange != address(this)) revert InvalidQuoteState();
        return q.supply;
    }

    function quoteShareBalance(bytes calldata state_) external view returns (uint256) {
        QuoteState memory q = abi.decode(state_, (QuoteState));
        if (q.exchange != address(this)) revert InvalidQuoteState();
        return q.holderShares;
    }

    function _quotePay(QuoteState memory q, uint256 assets_) private pure {
        if (assets_ <= q.idle) {
            q.idle -= assets_;
            return;
        }
        uint256 needed_ = assets_ - q.idle;
        uint256 cash_ = q.marketAssets - q.marketBorrowed;
        if (needed_ > cash_) revert IMorphoBlueStandardExchange.InsufficientLiquidity(assets_, q.idle + cash_);
        uint256 suppliedAssets_ = q.suppliedShares.toAssetsDown(q.marketAssets, q.marketShares);
        uint256 shares_ = needed_ >= suppliedAssets_
            ? q.suppliedShares : needed_.toSharesUp(q.marketAssets, q.marketShares);
        uint256 withdrawn_ = needed_ >= suppliedAssets_ ? suppliedAssets_ : needed_;
        q.suppliedShares -= shares_;
        q.marketShares -= shares_;
        q.marketAssets -= withdrawn_;
        q.idle = q.idle + withdrawn_ - assets_;
    }
}
