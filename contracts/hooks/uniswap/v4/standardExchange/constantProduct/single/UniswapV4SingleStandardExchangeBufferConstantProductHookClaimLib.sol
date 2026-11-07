// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {ExchangeInAmount} from "contracts/utils/ExchangeInAmount.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {Math as FullMath} from "@crane/contracts/utils/Math.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IVaultRegistryDisableQuery} from "contracts/interfaces/IVaultRegistryDisableQuery.sol";
import {IFeeCollectorProxy} from "contracts/interfaces/proxies/IFeeCollectorProxy.sol";
import {UniswapV4BufferHookLiquidityRouteLib as Components} from "contracts/hooks/uniswap/v4/libs/UniswapV4BufferHookLiquidityRouteLib.sol";
import {UniswapV4SingleStandardExchangeBufferConstantProductHookInQuoteBase as QuoteBase, ISingleBufferQuoteErrors} from "./UniswapV4SingleStandardExchangeBufferConstantProductHookInQuoteBase.sol";
import {IStandardExchangeTransitionQuote as Transition} from "contracts/interfaces/IStandardExchangeTransitionQuote.sol";

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC165} from "@crane/contracts/interfaces/IERC165.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {BetterSafeERC20 as SafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {IStandardExchangeTransitionQuote} from "contracts/interfaces/IStandardExchangeTransitionQuote.sol";
import {IRateProvider} from "@crane/contracts/protocols/dexes/balancer/common/interfaces/IRateProvider.sol";
import {UniswapV4SeBufferHookLegLib as LegLib} from "contracts/hooks/uniswap/v4/libs/UniswapV4SeBufferHookLegLib.sol";
import {UniswapV4SeBufferHookContextQuoteLib as ContextQuote} from "contracts/hooks/uniswap/v4/libs/UniswapV4SeBufferHookContextQuoteLib.sol";
import {
    UniswapV4SingleStandardExchangeBufferConstantProductHookRepo as Repo
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookRepo.sol";
import {
    UniswapV4SingleStandardExchangeBufferConstantProductHookMath as Math
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookMath.sol";

/**
 * @title UniswapV4SingleStandardExchangeBufferConstantProductHookClaimLib
 * @notice D78 claim-in / invert for pair-side buffer composition (ERC-4626 SE peer).
 * @dev D60: the pair leg of the swap invariant is SE shares x the configured rate provider
 *      (WAD whole pair tokens per whole share). The hook never derives a rate from the SE's
 *      own quotes; SE quotes are used only to count shares minted or pair paid out.
 *      External library: DELEGATECALL keeps `Repo._layout()` on the hook diamond.
 */
library UniswapV4SingleStandardExchangeBufferConstantProductHookClaimLib {
    using SafeERC20 for IERC20;

    error InvalidRoute();
    error ZeroAmount();
    error InsufficientLpOut();
    event ZapSwap(address indexed sender, address tokenIn, address tokenOut, uint256 amountIn, uint256 amountOut);

    struct Basket {
        uint256 raw;
        uint256 shares;
        uint256 local;
    }

    function componentBook() public view returns (Basket memory book_) {
        Repo.Layout storage l = Repo._layout();
        return Basket(l.bookedRaw, l.bookedSeShares, l.localPairReserve);
    }

    function disabled() public view returns (bool) {
        Repo.Layout storage l = Repo._layout();
        IVaultRegistryDisableQuery registry_ = IVaultRegistryDisableQuery(l.registry);
        if (registry_.packageOfVault(l.standardExchange) == address(0)) revert InvalidRoute();
        return registry_.isDisabled(l.standardExchange);
    }

    function mintFee(uint256 gross_) public view returns (uint256 net_, uint256 fee_, address recipient_) {
        (IFeeCollectorProxy to_, uint256 percentage_) =
            IVaultFeeOracleQuery(Repo._layout().feeOracle).dexSwapFeeAndFeeToOfVault(address(this));
        recipient_ = address(to_);
        (net_, fee_) = Components.splitMintFee(gross_, percentage_, recipient_, percentage_ != 0);
    }

    /// @dev One forward conversion estimate assembles caller inventory; only actual
    /// receipts determine acceptance. This does not invert an SE exact-output route.
    function _shareSale(uint256 shares_, uint256 local_, Basket memory book_) private view returns (uint256) {
        Repo.Layout storage l = Repo._layout();
        if (shares_ == 0 || book_.local == 0) return 0;
        if (book_.shares == 0) return shares_;
        uint256 requiredLocal_ = FullMath.mulDiv(shares_, book_.local, book_.shares, FullMath.Rounding.Ceil);
        if (local_ >= requiredLocal_) return 0;
        ExchangeInAmount.Result memory q_ = ExchangeInAmount.previewResult(
            IStandardExchangeIn(l.standardExchange), IERC20(l.standardExchange), shares_, IERC20(l.pairToken)
        );
        uint256 equivalent_ = FullMath.mulDiv(q_.amountOut, book_.shares, shares_);
        uint256 missing_ = book_.local - FullMath.mulDiv(local_, book_.shares, shares_);
        return FullMath.mulDiv(shares_, missing_, book_.local + equivalent_, FullMath.Rounding.Ceil);
    }

    function _pairDeposit(uint256 pair_, Basket memory book_) private view returns (uint256) {
        Repo.Layout storage l = Repo._layout();
        if (pair_ == 0 || book_.shares == 0 || disabled()) return 0;
        if (book_.local == 0) return pair_;
        ExchangeInAmount.Result memory q_ = ExchangeInAmount.previewResult(
            IStandardExchangeIn(l.standardExchange), IERC20(l.pairToken), pair_, IERC20(l.standardExchange)
        );
        uint256 localForShares_ = FullMath.mulDiv(q_.amountOut, book_.local, book_.shares, FullMath.Rounding.Ceil);
        return FullMath.mulDiv(pair_, pair_, pair_ + localForShares_);
    }

    function _convert(uint256 amount_, bool sharesIn_) private returns (ExchangeInAmount.Result memory receipt_) {
        Repo.Layout storage l = Repo._layout();
        IERC20 input_ = IERC20(sharesIn_ ? l.standardExchange : l.pairToken);
        IERC20 output_ = IERC20(sharesIn_ ? l.pairToken : l.standardExchange);
        uint256 beforeIn_ = input_.balanceOf(address(this));
        uint256 beforeOut_ = output_.balanceOf(address(this));
        input_.forceApprove(l.standardExchange, amount_);
        receipt_ = ExchangeInAmount.exchangeResult(
            IStandardExchangeIn(l.standardExchange), input_, amount_, output_, 0, address(this), false, block.timestamp
        );
        input_.forceApprove(l.standardExchange, 0);
        ExchangeInAmount.requireReceipt(amount_, receipt_, beforeIn_, input_.balanceOf(address(this)),
            beforeOut_, output_.balanceOf(address(this)));
    }

    function convertCallerShares(uint256 shares_) external returns (uint256 pair_) {
        ExchangeInAmount.Result memory receipt_ = _convert(shares_, true);
        if (receipt_.amountRefunded != 0) revert InsufficientTokenOut();
        return receipt_.amountOut;
    }

    /// @notice Attribute pool-owned input and its actual refund exactly once.
    function bufferPoolPair(uint256 amount_) public returns (uint256 shares_) {
        if (amount_ == 0) return 0;
        Repo.Layout storage l = Repo._layout();
        if (disabled()) {
            l.localPairReserve += amount_;
            return 0;
        }
        ExchangeInAmount.Result memory receipt_ = _convert(amount_, false);
        l.bookedSeShares += receipt_.amountOut;
        l.localPairReserve += receipt_.amountRefunded;
        return receipt_.amountOut;
    }

    /// @notice Fixed pair output uses local custody before an existing supported SE inverse.
    function takeExactPair(uint256 amount_) external returns (uint256) {
        Repo.Layout storage l = Repo._layout();
        uint256 local_ = FullMath.min(l.localPairReserve, amount_);
        l.localPairReserve -= local_;
        uint256 deficit_ = amount_ - local_;
        if (deficit_ == 0) return amount_;
        uint256 shares_ = IStandardExchangeOut(l.standardExchange).previewExchangeOut(
            IERC20(l.standardExchange), IERC20(l.pairToken), deficit_
        );
        if (shares_ == 0) revert IStandardExchangeOut.ExchangeOutNotAvailable();
        if (shares_ > l.bookedSeShares) revert InsufficientTokenOut();
        uint256 beforeShares_ = IERC20(l.standardExchange).balanceOf(address(this));
        uint256 beforePair_ = IERC20(l.pairToken).balanceOf(address(this));
        IERC20(l.standardExchange).forceApprove(l.standardExchange, shares_);
        uint256 consumed_ = IStandardExchangeOut(l.standardExchange).exchangeOut(
            IERC20(l.standardExchange), shares_, IERC20(l.pairToken), deficit_, address(this), false, block.timestamp
        );
        IERC20(l.standardExchange).forceApprove(l.standardExchange, 0);
        uint256 received_ = IERC20(l.pairToken).balanceOf(address(this)) - beforePair_;
        if (consumed_ > shares_ || beforeShares_ - IERC20(l.standardExchange).balanceOf(address(this)) != consumed_
            || received_ < deficit_) revert InsufficientTokenOut();
        l.bookedSeShares -= consumed_;
        l.localPairReserve += received_ - deficit_;
        return amount_;
    }

    function _assemble(uint256 raw_, uint256 input_, bool sharesIn_, bool genesis_, Basket memory book_)
        private returns (Basket memory basket_)
    {
        basket_.raw = raw_;
        if (sharesIn_) {
            uint256 spend_ = genesis_ ? input_ / 20 : _shareSale(input_, 0, book_);
            basket_.shares = input_;
            if (spend_ != 0) {
                ExchangeInAmount.Result memory receipt_ = _convert(spend_, true);
                if (receipt_.amountRefunded != 0) revert InsufficientTokenOut();
                basket_.shares -= spend_;
                basket_.local = receipt_.amountOut;
            }
            if (genesis_ && (spend_ == 0 || basket_.local == 0)) revert ZeroAmount();
        } else {
            if (genesis_) {
                if (disabled()) revert IVaultRegistryDisableQuery.VaultDisabled(Repo._layout().standardExchange);
                ExchangeInAmount.Result memory acquired_ = _convert(input_, false);
                uint256 spend_ = acquired_.amountOut / 20;
                if (spend_ == 0) revert ZeroAmount();
                ExchangeInAmount.Result memory redeemed_ = _convert(spend_, true);
                if (redeemed_.amountRefunded != 0 || redeemed_.amountOut == 0) revert InsufficientTokenOut();
                basket_.shares = acquired_.amountOut - spend_;
                basket_.local = acquired_.amountRefunded + redeemed_.amountOut;
                return basket_;
            }
            uint256 deposit_ = _pairDeposit(input_, book_);
            basket_.local = input_;
            if (deposit_ != 0) {
                ExchangeInAmount.Result memory receipt_ = _convert(deposit_, false);
                basket_.shares = receipt_.amountOut;
                basket_.local = ExchangeInAmount.localCredit(input_, deposit_, receipt_.amountRefunded);
            }
        }
    }

    function _previewBasket(uint256 raw_, uint256 input_, bool sharesIn_, bool genesis_, Basket memory book_)
        private view returns (Basket memory basket_)
    {
        Repo.Layout storage l = Repo._layout();
        basket_.raw = raw_;
        if (sharesIn_) {
            uint256 spend_ = genesis_ ? input_ / 20 : _shareSale(input_, 0, book_);
            basket_.shares = input_;
            if (spend_ != 0) {
                ExchangeInAmount.Result memory receipt_ = ExchangeInAmount.previewResult(
                    IStandardExchangeIn(l.standardExchange), IERC20(l.standardExchange), spend_, IERC20(l.pairToken)
                );
                if (receipt_.amountRefunded != 0) return Basket(0, 0, 0);
                basket_.shares -= spend_;
                basket_.local = receipt_.amountOut;
            }
            if (genesis_ && (spend_ == 0 || basket_.local == 0)) return Basket(0, 0, 0);
        } else {
            if (genesis_) {
                if (disabled()) revert IVaultRegistryDisableQuery.VaultDisabled(l.standardExchange);
                if (!_supportsTransitionQuote(l.standardExchange, l.pairToken, address(this))) {
                    revert Transition.InvalidQuoteState();
                }
                (bytes memory state_,) = Transition(l.standardExchange).quoteState(l.pairToken, address(this));
                uint256 consumed_;
                uint256 acquired_;
                (state_, consumed_, acquired_,) = Transition(l.standardExchange).quoteTransition(
                    state_, Transition.Operation.DepositExactIn, input_
                );
                uint256 spend_ = acquired_ / 20;
                if (spend_ == 0) return Basket(0, 0, 0);
                uint256 burned_;
                uint256 local_;
                (, burned_, local_,) = Transition(l.standardExchange).quoteTransition(
                    state_, Transition.Operation.RedeemExactIn, spend_
                );
                if (burned_ != spend_ || local_ == 0) return Basket(0, 0, 0);
                basket_.shares = acquired_ - spend_;
                basket_.local = input_ - consumed_ + local_;
                return basket_;
            }
            uint256 deposit_ = _pairDeposit(input_, book_);
            basket_.local = input_;
            if (deposit_ != 0) {
                ExchangeInAmount.Result memory receipt_ = ExchangeInAmount.previewResult(
                    IStandardExchangeIn(l.standardExchange), IERC20(l.pairToken), deposit_, IERC20(l.standardExchange)
                );
                basket_.shares = receipt_.amountOut;
                basket_.local = ExchangeInAmount.localCredit(input_, deposit_, receipt_.amountRefunded);
            }
        }
    }

    function _accepted(Basket memory available_, Basket memory book_, uint256 supply_)
        private view returns (uint256 gross_, Basket memory accepted_)
    {
        Repo.Layout storage l = Repo._layout();
        if (supply_ == 0) {
            if (available_.raw == 0 || available_.shares == 0 || available_.local == 0) return (0, accepted_);
            uint256 seed_ = Math.mintSharesFirst(
                Math.toWad(available_.raw, singleDecimals(l.rawToken)),
                Math.toWad(available_.shares, l.seDecimals)
            );
            if (seed_ <= Repo.MINIMUM_LIQUIDITY) return (0, accepted_);
            return (seed_ - Repo.MINIMUM_LIQUIDITY, available_);
        }
        uint256[] memory available = new uint256[](3);
        uint256[] memory booked = new uint256[](3);
        available[0] = available_.raw; available[1] = available_.shares; available[2] = available_.local;
        booked[0] = book_.raw; booked[1] = book_.shares; booked[2] = book_.local;
        gross_ = Components.maxComponentMint(available, booked, supply_);
        accepted_ = Basket(
            Components.componentContribution(gross_, booked[0], supply_),
            Components.componentContribution(gross_, booked[1], supply_),
            Components.componentContribution(gross_, booked[2], supply_)
        );
    }

    function _commitBasket(
        Basket memory book_, Basket memory available_, uint256 gross_, Basket memory accepted_,
        address to_, uint256 minimum_, uint256 supply_
    ) private returns (uint256 net_) {
        if (gross_ == 0) revert ZeroAmount();
        uint256 fee_;
        address feeTo_;
        (net_, fee_, feeTo_) = mintFee(gross_);
        if (net_ < minimum_) revert InsufficientLpOut();
        Repo.Layout storage l = Repo._layout();
        l.bookedRaw = book_.raw + accepted_.raw;
        l.bookedSeShares = book_.shares + accepted_.shares;
        l.localPairReserve = book_.local + accepted_.local;
        uint256 unusedRaw_ = available_.raw - accepted_.raw;
        uint256 unusedShares_ = available_.shares - accepted_.shares;
        uint256 unusedPair_ = available_.local - accepted_.local;
        if (supply_ == 0) ERC20Repo._mint(address(0), Repo.MINIMUM_LIQUIDITY);
        if (fee_ != 0) ERC20Repo._mint(feeTo_, fee_);
        if (net_ != 0) ERC20Repo._mint(to_, net_);
        if (unusedRaw_ != 0) IERC20(l.rawToken).safeTransfer(msg.sender, unusedRaw_);
        if (unusedShares_ != 0) IERC20(l.standardExchange).safeTransfer(msg.sender, unusedShares_);
        if (unusedPair_ != 0) IERC20(l.pairToken).safeTransfer(msg.sender, unusedPair_);
    }

    /// @dev Initial caller inventory is separate from the incumbent book.
    function _singleInput(address input_, uint256 amount_) private view returns (Basket memory available_) {
        Repo.Layout storage l = Repo._layout();
        if (input_ == l.rawToken) available_.raw = amount_;
        else if (input_ == l.pairToken) available_.local = amount_;
        else if (input_ == l.standardExchange) available_.shares = amount_;
        else revert InvalidRoute();
    }

    /// @dev Price a paid preparatory trade, then accept LP against the resulting
    /// book. Raw input buys the buffered leg in kind; pair/share sales retain
    /// their native input in that leg. No SE conversion is needed for this trade.
    function _singleSwap(address input_, uint256 amount_, Basket memory book_)
        private view returns (Basket memory available_, uint256 sold_, uint256 counter_, uint256 kept_)
    {
        return _singleSwapAtRate(input_, amount_, book_, _rate(Repo._layout()));
    }

    function _singleSwapAtRate(address input_, uint256 amount_, Basket memory book_, uint256 rate_)
        private view returns (Basket memory available_, uint256 sold_, uint256 counter_, uint256 kept_)
    {
        Repo.Layout storage l = Repo._layout();
        available_ = _singleInput(input_, amount_);
        uint256 pairReserve_ = book_.local + _ratedWith(l, book_.shares, rate_);
        if (amount_ == 0 || book_.raw == 0 || pairReserve_ == 0) return (available_, 0, 0, amount_);
        if (input_ == l.rawToken) {
            sold_ = Math.fromWadFloor(Math.swapDepositSaleAmt(
                Math.toWad(amount_, singleDecimals(l.rawToken)),
                Math.toWad(book_.raw, singleDecimals(l.rawToken))
            ), singleDecimals(l.rawToken));
            if (sold_ == 0 || sold_ >= amount_) return (available_, 0, 0, amount_);
            counter_ = Math.fromWadFloor(Math.saleQuote(
                Math.toWad(sold_, singleDecimals(l.rawToken)),
                Math.toWad(book_.raw, singleDecimals(l.rawToken)),
                Math.toWad(pairReserve_, _pairDecimals(l))
            ), _pairDecimals(l));
            available_.raw = amount_ - sold_;
            available_.shares = FullMath.mulDiv(book_.shares, counter_, pairReserve_);
            available_.local = FullMath.mulDiv(book_.local, counter_, pairReserve_);
            book_.raw += sold_;
            book_.shares -= available_.shares;
            book_.local -= available_.local;
        } else {
            uint256 value_ = input_ == l.pairToken ? amount_ : _ratedWith(l, amount_, rate_);
            if (value_ == 0) return (available_, 0, 0, amount_);
            uint256 saleValue_ = Math.fromWadFloor(Math.swapDepositSaleAmt(
                Math.toWad(value_, _pairDecimals(l)),
                Math.toWad(pairReserve_, _pairDecimals(l))
            ), _pairDecimals(l));
            sold_ = input_ == l.pairToken ? saleValue_
                : FullMath.mulDiv(amount_, saleValue_, value_, FullMath.Rounding.Ceil);
            if (sold_ == 0 || sold_ >= amount_) return (available_, 0, 0, amount_);
            uint256 actualValue_ = input_ == l.pairToken ? sold_ : _ratedWith(l, sold_, rate_);
            counter_ = singlePairRawOut(actualValue_, pairReserve_, book_.raw);
            book_.raw -= counter_;
            available_.raw = counter_;
            if (input_ == l.pairToken) {
                book_.local += sold_;
                available_.local = amount_ - sold_;
            } else {
                book_.shares += sold_;
                available_.shares = amount_ - sold_;
            }
        }
        kept_ = amount_ - sold_;
    }

    function singleComponentJoin(address input_, uint256 amount_, address to_, uint256 minimum_, uint256 exactNet_)
        public returns (uint256 net_)
    {
        uint256 supply_ = ERC20Repo._totalSupply();
        if (supply_ == 0) revert InvalidRoute();
        Basket memory book_ = componentBook();
        (Basket memory available_, uint256 sold_, uint256 counter_, uint256 kept_) = _singleSwap(input_, amount_, book_);
        if (book_.raw != 0 && available_.raw == 0) revert ZeroAmount();
        Repo.Layout storage l = Repo._layout();
        if (input_ != l.rawToken) {
            available_ = _assemble(available_.raw, kept_, input_ == l.standardExchange, false, book_);
        }
        (uint256 gross_, Basket memory accepted_) = _accepted(available_, book_, supply_);
        if (exactNet_ != 0) {
            (IFeeCollectorProxy toFee_, uint256 percentage_) =
                IVaultFeeOracleQuery(Repo._layout().feeOracle).dexSwapFeeAndFeeToOfVault(address(this));
            uint256 required_ = Components.grossForNet(exactNet_, percentage_, address(toFee_), percentage_ != 0);
            if (gross_ < required_) revert InsufficientLpOut();
            gross_ = required_;
            accepted_ = Basket(
                Components.componentContribution(gross_, book_.raw, supply_),
                Components.componentContribution(gross_, book_.shares, supply_),
                Components.componentContribution(gross_, book_.local, supply_)
            );
        }
        net_ = _commitBasket(book_, available_, gross_, accepted_, to_, minimum_, supply_);
        if (sold_ != 0) emit ZapSwap(msg.sender, input_, input_ == l.rawToken ? l.pairToken : l.rawToken, sold_, counter_);
    }

    function previewSingleComponentJoin(address input_, uint256 amount_) external view returns (uint256 net_) {
        uint256 supply_ = ERC20Repo._totalSupply();
        if (supply_ == 0 || amount_ == 0) return 0;
        Basket memory book_ = componentBook();
        (Basket memory available_,,, uint256 kept_) = _singleSwap(input_, amount_, book_);
        if (book_.raw != 0 && available_.raw == 0) return 0;
        Repo.Layout storage l = Repo._layout();
        if (input_ != l.rawToken) {
            available_ = _previewBasket(available_.raw, kept_, input_ == l.standardExchange, false, book_);
        }
        (uint256 gross_,) = _accepted(available_, book_, supply_);
        (net_,,) = mintFee(gross_);
    }

    /// @notice Raw-input LP assembly changes only hook custody, not SE state.
    function previewRawClaimAfterJoin(uint256 rawInput_, uint256 lp_) external view returns (uint256 rawOutput_) {
        Repo.Layout storage l = Repo._layout();
        uint256 supply_ = ERC20Repo._totalSupply();
        if (lp_ == 0 || supply_ == 0) return 0;
        Basket memory book_ = componentBook();
        (Basket memory available_,,,) = _singleSwap(l.rawToken, rawInput_, book_);
        (uint256 gross_, Basket memory accepted_) = _accepted(available_, book_, supply_);
        if (gross_ == 0) return 0;
        book_.raw += accepted_.raw;
        book_.shares += accepted_.shares;
        book_.local += accepted_.local;
        supply_ += gross_;
        Basket memory claim_ = Basket(
            Components.componentAllocation(lp_, book_.raw, supply_),
            Components.componentAllocation(lp_, book_.shares, supply_),
            Components.componentAllocation(lp_, book_.local, supply_)
        );
        uint256 value_ = claim_.local + _ratedOf(l, claim_.shares);
        uint256 remainingPair_ = book_.local - claim_.local + _ratedOf(l, book_.shares - claim_.shares);
        rawOutput_ = claim_.raw;
        if (value_ != 0) rawOutput_ += singlePairRawOut(value_, remainingPair_, book_.raw - claim_.raw);
    }

    /// @notice Quote the paid preparatory trade separately from LP acceptance.
    function previewComponentSplit(address input_, uint256 amount_)
        external view returns (uint256 sold_, uint256 counter_, uint256 kept_)
    {
        (, sold_, counter_, kept_) = _singleSwap(input_, amount_, componentBook());
    }

    /// @notice Accept the actual caller basket; never count ambient balances or rated growth.
    function joinComponents(uint256 raw_, uint256 input_, bool sharesIn_, address to_, uint256 minimum_)
        external returns (uint256 net_, uint256 usedRaw_, uint256 usedInput_)
    {
        uint256 supply_ = ERC20Repo._totalSupply();
        if (supply_ != 0 && (raw_ == 0 || input_ == 0)) {
            Repo.Layout storage l = Repo._layout();
            IERC20 token_ = IERC20(raw_ != 0 ? l.rawToken : sharesIn_ ? l.standardExchange : l.pairToken);
            uint256 before_ = token_.balanceOf(msg.sender);
            uint256 supplied_ = raw_ != 0 ? raw_ : input_;
            net_ = singleComponentJoin(address(token_), supplied_, to_, minimum_, 0);
            uint256 used_ = supplied_ - (token_.balanceOf(msg.sender) - before_);
            if (raw_ != 0) usedRaw_ = used_;
            else usedInput_ = used_;
            return (net_, usedRaw_, usedInput_);
        }
        Basket memory book_ = componentBook();
        Basket memory available_ = _assemble(raw_, input_, sharesIn_, supply_ == 0, book_);
        (uint256 gross_, Basket memory accepted_) = _accepted(available_, book_, supply_);
        net_ = _commitBasket(book_, available_, gross_, accepted_, to_, minimum_, supply_);
        usedRaw_ = accepted_.raw;
        usedInput_ = input_ - (sharesIn_ ? available_.shares - accepted_.shares : available_.local - accepted_.local);
    }

    function previewComponentJoin(uint256 raw_, uint256 input_, bool sharesIn_)
        external view returns (uint256 net_, uint256 usedRaw_, uint256 usedInput_)
    {
        uint256 supply_ = ERC20Repo._totalSupply();
        if (supply_ != 0 && (raw_ == 0 || input_ == 0)) {
            Repo.Layout storage l = Repo._layout();
            address token_ = raw_ != 0 ? l.rawToken : sharesIn_ ? l.standardExchange : l.pairToken;
            Basket memory book_ = componentBook();
            (Basket memory prepared_,,, uint256 kept_) = _singleSwap(token_, raw_ != 0 ? raw_ : input_, book_);
            if (book_.raw != 0 && prepared_.raw == 0) return (0, 0, 0);
            if (raw_ == 0) prepared_ = _previewBasket(prepared_.raw, kept_, sharesIn_, false, book_);
            (uint256 gross_, Basket memory accepted_) = _accepted(prepared_, book_, supply_);
            if (gross_ == 0) return (0, 0, 0);
            (net_,,) = mintFee(gross_);
            if (raw_ != 0) usedRaw_ = raw_ - (prepared_.raw - accepted_.raw);
            else usedInput_ = input_ - (sharesIn_
                ? prepared_.shares - accepted_.shares : prepared_.local - accepted_.local);
            return (net_, usedRaw_, usedInput_);
        }
        Basket memory available_ = _previewBasket(raw_, input_, sharesIn_, ERC20Repo._totalSupply() == 0, componentBook());
        (uint256 gross_, Basket memory accepted_) = _accepted(available_, componentBook(), ERC20Repo._totalSupply());
        if (gross_ == 0) return (0, 0, 0);
        (net_,,) = mintFee(gross_);
        usedRaw_ = accepted_.raw;
        usedInput_ = input_ - (sharesIn_ ? available_.shares - accepted_.shares : available_.local - accepted_.local);
    }

    function componentClaim(uint256 burned_) public view returns (Basket memory claim_) {
        Repo.Layout storage l = Repo._layout();
        uint256 supply_ = ERC20Repo._totalSupply();
        claim_.raw = Components.componentAllocation(burned_, l.bookedRaw, supply_);
        claim_.shares = Components.componentAllocation(burned_, l.bookedSeShares, supply_);
        claim_.local = Components.componentAllocation(burned_, l.localPairReserve, supply_);
    }

    /// @dev Allocate first, then price only the exiting basket against remaining
    /// backing. In-kind shares do not mutate the underlying SE before its sole
    /// final redemption, so ordinary exact-input previews need no invented state.
    function _singleExitBasket(uint256 burned_, bool asPair_)
        private view returns (Basket memory book_, Basket memory payout_)
    {
        Repo.Layout storage l = Repo._layout();
        payout_ = componentClaim(burned_);
        book_ = componentBook();
        book_.raw -= payout_.raw;
        book_.shares -= payout_.shares;
        book_.local -= payout_.local;
        uint256 reservePair_ = book_.local + _ratedOf(l, book_.shares);
        if (asPair_) {
            if (payout_.raw == 0) return (book_, payout_);
            if (book_.raw == 0 || reservePair_ == 0) revert InsufficientTokenOut();
            uint256 budget_ = Math.fromWadFloor(Math.saleQuote(
                Math.toWad(payout_.raw, singleDecimals(l.rawToken)),
                Math.toWad(book_.raw, singleDecimals(l.rawToken)),
                Math.toWad(reservePair_, _pairDecimals(l))
            ), _pairDecimals(l));
            uint256 shares_ = FullMath.mulDiv(book_.shares, budget_, reservePair_);
            uint256 local_ = FullMath.mulDiv(book_.local, budget_, reservePair_);
            book_.raw += payout_.raw;
            book_.shares -= shares_;
            book_.local -= local_;
            payout_.raw = 0;
            payout_.shares += shares_;
            payout_.local += local_;
        } else {
            uint256 value_ = payout_.local + _ratedOf(l, payout_.shares);
            if (value_ == 0 && (payout_.shares != 0 || payout_.local != 0)) revert InsufficientTokenOut();
            if (value_ == 0) return (book_, payout_);
            if (book_.raw == 0 || reservePair_ == 0) revert InsufficientTokenOut();
            uint256 raw_ = singlePairRawOut(value_, reservePair_, book_.raw);
            book_.raw -= raw_;
            book_.shares += payout_.shares;
            book_.local += payout_.local;
            payout_.raw += raw_;
            payout_.shares = 0;
            payout_.local = 0;
        }
    }

    function previewSingleComponentExit(uint256 burned_, bool asPair_) external view returns (uint256 output_) {
        if (burned_ == 0 || ERC20Repo._totalSupply() == 0) return 0;
        (, Basket memory payout_) = _singleExitBasket(burned_, asPair_);
        if (!asPair_) return payout_.raw;
        output_ = payout_.local;
        if (payout_.shares != 0) {
            Repo.Layout storage l = Repo._layout();
            ExchangeInAmount.Result memory quote_ = ExchangeInAmount.previewResult(
                IStandardExchangeIn(l.standardExchange), IERC20(l.standardExchange), payout_.shares, IERC20(l.pairToken)
            );
            if (quote_.amountRefunded != 0 || quote_.amountOut == 0) revert InsufficientTokenOut();
            output_ += quote_.amountOut;
        }
    }

    function singleComponentExit(address holder_, uint256 burned_, address to_, uint256 minimum_, bool asPair_)
        external returns (uint256 output_)
    {
        if (burned_ == 0) revert ZeroAmount();
        (Basket memory book_, Basket memory payout_) = _singleExitBasket(burned_, asPair_);
        ERC20Repo._burn(holder_, burned_);
        Repo.Layout storage l = Repo._layout();
        l.bookedRaw = book_.raw;
        l.bookedSeShares = book_.shares;
        l.localPairReserve = book_.local;
        output_ = asPair_ ? payout_.local : payout_.raw;
        if (payout_.shares != 0) {
            ExchangeInAmount.Result memory receipt_ = _convert(payout_.shares, true);
            if (receipt_.amountRefunded != 0 || receipt_.amountOut == 0) revert InsufficientTokenOut();
            output_ += receipt_.amountOut;
        }
        if (output_ < minimum_) revert InsufficientTokenOut();
        if (output_ != 0) IERC20(asPair_ ? l.pairToken : l.rawToken).safeTransfer(to_, output_);
    }

    function previewComponentExit(uint256 burned_, bool sharesOut_)
        external view returns (uint256 raw_, uint256 output_)
    {
        if (burned_ == 0 || ERC20Repo._totalSupply() == 0) return (0, 0);
        Repo.Layout storage l = Repo._layout();
        Basket memory claim_ = componentClaim(burned_);
        raw_ = claim_.raw;
        output_ = sharesOut_ ? claim_.shares : claim_.local;
        uint256 convert_ = sharesOut_ ? claim_.local : claim_.shares;
        if (convert_ != 0) {
            ExchangeInAmount.Result memory q_ = ExchangeInAmount.previewResult(
                IStandardExchangeIn(l.standardExchange),
                IERC20(sharesOut_ ? l.pairToken : l.standardExchange), convert_,
                IERC20(sharesOut_ ? l.standardExchange : l.pairToken)
            );
            if (q_.amountRefunded != 0) revert InsufficientTokenOut();
            output_ += q_.amountOut;
        }
    }

    function withdrawComponents(
        address holder_, uint256 burned_, address to_, uint256 minRaw_, uint256 minOutput_, bool sharesOut_
    ) external returns (uint256 raw_, uint256 output_) {
        if (burned_ == 0) revert ZeroAmount();
        Repo.Layout storage l = Repo._layout();
        Basket memory claim_ = componentClaim(burned_);
        ERC20Repo._burn(holder_, burned_);
        l.bookedRaw -= claim_.raw;
        l.bookedSeShares -= claim_.shares;
        l.localPairReserve -= claim_.local;
        raw_ = claim_.raw;
        output_ = sharesOut_ ? claim_.shares : claim_.local;
        uint256 convert_ = sharesOut_ ? claim_.local : claim_.shares;
        if (convert_ != 0) {
            if (sharesOut_ && disabled()) revert IVaultRegistryDisableQuery.VaultDisabled(l.standardExchange);
            ExchangeInAmount.Result memory receipt_ = _convert(convert_, !sharesOut_);
            if (receipt_.amountRefunded != 0 || receipt_.amountOut == 0) revert InsufficientTokenOut();
            output_ += receipt_.amountOut;
        }
        if (raw_ < minRaw_ || output_ < minOutput_) revert InsufficientTokenOut();
        if (raw_ != 0) IERC20(l.rawToken).safeTransfer(to_, raw_);
        if (output_ != 0) IERC20(sharesOut_ ? l.standardExchange : l.pairToken).safeTransfer(to_, output_);
    }

    function singleZapState(address tokenIn, uint256 sold, uint256 other, uint256 kept)
        external view returns (QuoteBase.SingleZapQuote memory q)
    {
        Repo.Layout storage l = Repo._layout();
        (q.state,) = Transition(l.standardExchange).quoteState(l.pairToken, address(this));
        q.pairReserve = ratedClaimOfState(l.standardExchange, q.state);
        q.rawReserve = IERC20(l.rawToken).balanceOf(address(this));
        if (tokenIn == l.rawToken) {
            uint256 budget = Math.fromWadFloor(Math.saleQuote(Math.toWad(sold, singleDecimals(l.rawToken)),
                Math.toWad(q.rawReserve, singleDecimals(l.rawToken)), Math.toWad(q.pairReserve, singleDecimals(l.pairToken))), singleDecimals(l.pairToken));
            (q.state, other, q.pairReserve) = _singleZapUnwrap(q.state, budget);
            q.rawReserve += sold;
            q.rawAdded = kept;
            q.pairAdded = other;
        } else {
            uint256 minted;
            (q.state,, minted, q.pairReserve) = _singleMintableDeposit(q.state, sold);
            if (minted == 0) return q;
            q.rawReserve -= other;
            q.rawAdded = other;
            q.pairAdded = kept;
        }
        if (q.pairReserve == 0) q.pairReserve = 1;
    }

    function singleShareZapState(bytes memory state, uint256 shares) external view returns (QuoteBase.SingleZapQuote memory q) {
        Repo.Layout storage l = Repo._layout();
        Transition quote = Transition(l.standardExchange);
        q.state = state;
        (q.state,,,) = quote.quoteTransition(q.state, Transition.Operation.ReceiveShares, shares);
        Basket memory book = componentBook();
        (Basket memory available,,,) = _singleSwapAtRate(
            l.standardExchange, shares, book, _rateForState(l, q.state)
        );
        q.rawReserve = book.raw;
        q.shareReserve = book.shares;
        q.localReserve = book.local;
        q.rawAdded = available.raw;
        shares = available.shares;
        uint256 redeem;
        if (q.localReserve != 0 && shares != 0) {
            if (q.shareReserve == 0) redeem = shares;
            else {
                (,, uint256 quotedOut,) = quote.quoteTransition(q.state, Transition.Operation.RedeemExactIn, shares);
                uint256 equivalent = FullMath.mulDiv(quotedOut, q.shareReserve, shares);
                redeem = FullMath.mulDiv(shares, q.localReserve, q.localReserve + equivalent, FullMath.Rounding.Ceil);
            }
        }
        q.sharesAdded = shares - redeem;
        if (redeem != 0) {
            uint256 consumed;
            (q.state, consumed, q.pairAdded,) = quote.quoteTransition(q.state, Transition.Operation.RedeemExactIn, redeem);
            if (consumed != redeem) revert InsufficientTokenOut();
        }
        q.pairReserve = q.localReserve + _ratedWith(l, q.shareReserve, _rateForState(l, q.state));
    }

    /// @dev Return the mutated projection because external library calls copy memory arguments.
    function singleFinishDeposit(QuoteBase.SingleZapQuote memory q, uint256 supply)
        external view returns (QuoteBase.SingleZapQuote memory updated, uint256 minted, uint256 finalSupply)
    {
        Basket memory available = Basket(q.rawAdded, q.sharesAdded, q.pairAdded);
        Basket memory book = Basket(q.rawReserve, q.shareReserve, q.localReserve);
        (uint256 gross, Basket memory accepted) = _accepted(available, book, supply);
        (minted,,) = mintFee(gross);
        q.rawReserve += accepted.raw;
        q.shareReserve += accepted.shares;
        q.localReserve += accepted.local;
        q.rawAdded -= accepted.raw;
        q.sharesAdded -= accepted.shares;
        q.pairAdded -= accepted.local;
        q.pairReserve = q.localReserve + _ratedWith(Repo._layout(), q.shareReserve, _rateForState(Repo._layout(), q.state));
        finalSupply = supply + gross;
        updated = q;
    }

    function _singleSharesAfterZap(QuoteBase.SingleZapQuote memory q, uint256 delta, uint256 reserve, uint256 supply)
        private view returns (uint256)
    {
        return Math.mintSharesLater(singleOrderX(q.rawAdded, delta), singleOrderY(q.rawAdded, delta),
            singleOrderX(q.rawReserve, reserve), singleOrderY(q.rawReserve, reserve), supply);
    }

    function _singleMintableDeposit(bytes memory state, uint256 amount) private view returns (bytes memory, uint256, uint256, uint256) {
        Repo.Layout storage l = Repo._layout();
        return quoteMintableDepositExactIn(l.standardExchange, l.pairToken, state, amount);
    }

    function _singleZapUnwrap(bytes memory state, uint256 budget) private view returns (bytes memory next, uint256 received, uint256 claimAfter) {
        Repo.Layout storage l = Repo._layout();
        uint256 held = Transition(l.standardExchange).quoteShareBalance(state);
        uint256 amount = sharesForPairUnitsDownAtState(budget, state);
        if (amount == 0) return (state, 0, ratedClaimOfState(l.standardExchange, state));
        if (amount >= held) revert ISingleBufferQuoteErrors.InsufficientTokenOut();
        (next,, received,) = Transition(l.standardExchange).quoteTransition(state, Transition.Operation.RedeemExactIn, amount);
        if (received == 0) return (state, 0, ratedClaimOfState(l.standardExchange, state));
        claimAfter = ratedClaimOfState(l.standardExchange, next);
    }

    function _singlePairZapSale(uint256 amount, uint256 claim, uint256 reserve) private view returns (uint256 sold) {
        uint8 decimals = singleDecimals(Repo._layout().pairToken);
        uint256 saleClaim = Math.fromWadFloor(Math.swapDepositSaleAmt(Math.toWad(claim, decimals), Math.toWad(reserve, decimals)), decimals);
        sold = claim == 0 ? amount / 2 : amount * saleClaim / claim;
        if (sold > amount) sold = amount;
        if (sold == 0 || sold >= amount) sold = amount / 2;
    }

    function singlePairRawOut(uint256 claimIn, uint256 pairReserve, uint256 rawReserve) internal view returns (uint256) {
        Repo.Layout storage l = Repo._layout();
        uint8 pairDecimals = singleDecimals(l.pairToken);
        uint8 rawDecimals = singleDecimals(l.rawToken);
        return Math.fromWadFloor(Math.saleQuote(Math.toWad(claimIn, pairDecimals), Math.toWad(pairReserve, pairDecimals),
            Math.toWad(rawReserve, rawDecimals)), rawDecimals);
    }

    function singleDecimals(address token) internal view returns (uint8 d) {
        Repo.Layout storage l = Repo._layout();
        if (token == l.currency0) d = l.decimalsCurrency0;
        else if (token == l.currency1) d = l.decimalsCurrency1;
        else revert ISingleBufferQuoteErrors.InvalidToken();
        if (d == 0) d = 18;
    }
    function singleOrderX(uint256 raw, uint256 pair) internal view returns (uint256) {
        return Repo._layout().currency0 == Repo._layout().rawToken ? raw : pair;
    }
    function singleOrderY(uint256 raw, uint256 pair) internal view returns (uint256) {
        return Repo._layout().currency0 == Repo._layout().rawToken ? pair : raw;
    }
    function singleClamp(uint256 x, uint256 y, uint256 amount0, uint256 amount1) internal pure returns (uint256 used0, uint256 used1) {
        used0 = amount0;
        used1 = amount1;
        if (x == 0 || y == 0) revert ISingleBufferQuoteErrors.NotLive();
        uint256 ideal1 = (used0 * y) / x;
        if (ideal1 <= used1) used1 = ideal1;
        else used0 = (used1 * x) / y;
        if (used0 == 0 || used1 == 0) {
            if (used0 == 0 && (amount0 > 0 || x > 0)) used0 = 1;
            if (used1 == 0 && (amount1 > 0 || y > 0)) used1 = 1;
            if (used0 == 0 || used1 == 0) revert ISingleBufferQuoteErrors.ZeroAmount();
        }
    }

    struct ExactInOutput {
        uint256 amountOut;
        uint256 sharesOut;
    }

    struct WithdrawalPlan {
        uint256 pairUser;
        uint256 residualOut;
        uint256 residualShares;
        uint256 remainingShares;
        uint256 remainingRated;
        uint256 rate;
        bytes state;
    }

    /// @dev Pro-rata redemption precedes the residual swap, including in the quote state.
    function withdrawalPlan(uint256 rawUser, uint256 seUser, uint256 rawRemain, bool asPair)
        external view returns (WithdrawalPlan memory q)
    {
        Repo.Layout storage l = Repo._layout();
        q.remainingShares = IERC20(l.standardExchange).balanceOf(address(this)) - seUser;
        if (l.standardExchange != l.pairToken && _supportsTransitionQuote(l.standardExchange, l.pairToken, address(this))) {
            (q.state,) = IStandardExchangeTransitionQuote(l.standardExchange).quoteState(l.pairToken, address(this));
            if (seUser != 0) {
                (q.state,, q.pairUser,) = IStandardExchangeTransitionQuote(l.standardExchange).quoteTransition(
                    q.state, IStandardExchangeTransitionQuote.Operation.RedeemExactIn, seUser);
            }
            q.rate = _rateForState(l, q.state);
        } else {q.pairUser = seUser == 0 ? 0 : l.standardExchange == l.pairToken ? seUser
                : ExchangeInAmount.previewOut(IStandardExchangeIn(address(IStandardExchangeIn(l.standardExchange))), IERC20(l.standardExchange), seUser, IERC20(l.pairToken));
            q.rate = _rate(l);
        }
        q.remainingRated = _ratedWith(l, q.remainingShares, q.rate);
        if (q.remainingRated == 0 && q.remainingShares != 0) q.remainingRated = 1;
        if (asPair) _quoteWithdrawalRawSale(l, q, rawUser, rawRemain);
        else _quoteWithdrawalPairSale(l, q, rawRemain);
    }

    function _quoteWithdrawalRawSale(Repo.Layout storage l, WithdrawalPlan memory q, uint256 rawUser, uint256 rawRemain) private view {
        if (rawUser == 0 || rawRemain == 0 || q.remainingRated == 0) return;
        uint8 rawDecimals = l.currency0 == l.rawToken ? l.decimalsCurrency0 : l.decimalsCurrency1;
        uint256 budget = Math.fromWadFloor(Math.saleQuote(Math.toWad(rawUser, rawDecimals),
            Math.toWad(rawRemain, rawDecimals), Math.toWad(q.remainingRated, _pairDecimals(l))), _pairDecimals(l));
        (uint256 invScale, uint256 ratedScale) = _scales(l);
        q.residualShares = Math.sharesForPairUnitsDown(budget, q.rate, invScale, ratedScale);
        if (q.residualShares == 0) return;
        if (q.residualShares >= q.remainingShares) revert InsufficientTokenOut();
        if (q.state.length != 0) {
            (,, q.residualOut,) = IStandardExchangeTransitionQuote(l.standardExchange).quoteTransition(
                q.state, IStandardExchangeTransitionQuote.Operation.RedeemExactIn, q.residualShares);
        } else {q.residualOut = l.standardExchange == l.pairToken ? q.residualShares
                : ExchangeInAmount.previewOut(IStandardExchangeIn(address(IStandardExchangeIn(l.standardExchange))), IERC20(l.standardExchange), q.residualShares, IERC20(l.pairToken));
        }
    }

    function _quoteWithdrawalPairSale(Repo.Layout storage l, WithdrawalPlan memory q, uint256 rawRemain) private view {
        if (q.pairUser == 0 || rawRemain == 0 || q.remainingRated == 0) return;
        uint256 gain;
        if (q.state.length != 0) {
            (bytes memory next,, uint256 minted,) = IStandardExchangeTransitionQuote(l.standardExchange).quoteTransition(
                q.state, IStandardExchangeTransitionQuote.Operation.DepositExactIn, q.pairUser);
            uint256 afterRated = _ratedWith(l, q.remainingShares + minted, _rateForState(l, next));
            gain = afterRated > q.remainingRated ? afterRated - q.remainingRated : 0;
        } else {
            gain = _ratedOf(l, _previewPairToShares(l.standardExchange, l.pairToken, q.pairUser));
        }
        if (gain == 0) return;
        uint8 rawDecimals = l.currency0 == l.rawToken ? l.decimalsCurrency0 : l.decimalsCurrency1;
        q.residualOut = Math.fromWadFloor(Math.saleQuote(Math.toWad(gain, _pairDecimals(l)),
            Math.toWad(q.remainingRated, _pairDecimals(l)), Math.toWad(rawRemain, rawDecimals)), rawDecimals);
    }

    function sharesForPairUnitsDown(uint256 units) public view returns (uint256) {
        Repo.Layout storage l = Repo._layout();
        (uint256 invScale, uint256 ratedScale) = _scales(l);
        return Math.sharesForPairUnitsDown(units, _rate(l), invScale, ratedScale);
    }

    function sharesForPairUnitsDownAtState(uint256 units, bytes memory state) public view returns (uint256) {
        Repo.Layout storage l = Repo._layout();
        (uint256 invScale, uint256 ratedScale) = _scales(l);
        return Math.sharesForPairUnitsDown(units, _rateForState(l, state), invScale, ratedScale);
    }

    function previewBudget(uint256 ratedBudget) public view returns (ExactInOutput memory output) {
        Repo.Layout storage l = Repo._layout();
        uint256 local = FullMath.min(ratedBudget, l.localPairReserve);
        output.amountOut = local;
        if (local == ratedBudget) return output;
        output.sharesOut = sharesForPairUnitsDown(ratedBudget - local);
        if (output.sharesOut > l.bookedSeShares) revert InsufficientTokenOut();
        if (output.sharesOut == 0) return output;
        ExchangeInAmount.Result memory receipt = ExchangeInAmount.previewResult(
            IStandardExchangeIn(l.standardExchange), IERC20(l.standardExchange), output.sharesOut, IERC20(l.pairToken)
        );
        if (receipt.amountRefunded != 0) revert InsufficientTokenOut();
        if (receipt.amountOut == 0) output.sharesOut = 0;
        output.amountOut += receipt.amountOut;
    }

    function previewBudgetWithContext(uint256 ratedBudget, address manager) external view returns (ExactInOutput memory output) {
        Repo.Layout storage l = Repo._layout();
        uint256 local = FullMath.min(ratedBudget, l.localPairReserve);
        if (local == ratedBudget) return ExactInOutput(local, 0);
        bytes memory state = ContextQuote.snapshot(l.standardExchange, l.pairToken, address(this), manager);
        if (state.length == 0) return previewBudget(ratedBudget);
        (uint256 invScale, uint256 ratedScale) = _scales(l);
        output.amountOut = local;
        output.sharesOut = Math.sharesForPairUnitsDown(ratedBudget - local, _rateForState(l, state), invScale, ratedScale);
        if (output.sharesOut > l.bookedSeShares) revert InsufficientTokenOut();
        if (output.sharesOut == 0) return output;
        (, uint256 consumed, uint256 received,) = IStandardExchangeTransitionQuote(l.standardExchange).quoteTransition(
            state, IStandardExchangeTransitionQuote.Operation.RedeemExactIn, output.sharesOut);
        if (consumed != output.sharesOut) revert InsufficientTokenOut();
        if (received == 0) output.sharesOut = 0;
        output.amountOut += received;
    }

    function ratedReserveWithContext(address manager) external view returns (uint256) {
        Repo.Layout storage l = Repo._layout();
        bytes memory state = ContextQuote.snapshot(l.standardExchange, l.pairToken, address(this), manager);
        return l.localPairReserve + (state.length == 0 ? _ratedOf(l, l.bookedSeShares)
            : _ratedWith(l, l.bookedSeShares, _rateForState(l, state)));
    }

    function previewBufferClaimInWithContext(uint256 amount, address manager) external view returns (uint256) {
        Repo.Layout storage l = Repo._layout();
        if (amount == 0 || disabled()) return amount;
        bytes memory state = ContextQuote.snapshot(l.standardExchange, l.pairToken, address(this), manager);
        if (state.length == 0) return _claimIn(l, amount);
        (, uint256 gained) = projectedClaimIn(l.standardExchange, state, l.bookedSeShares, amount);
        return gained;
    }

    function unwrapQuoted(ExactInOutput memory output) external returns (uint256 amountOut) {
        Repo.Layout storage l = Repo._layout();
        uint256 local = FullMath.min(l.localPairReserve, output.amountOut);
        if (output.sharesOut > l.bookedSeShares) revert InsufficientTokenOut();
        l.localPairReserve -= local;
        l.bookedSeShares -= output.sharesOut;
        amountOut = local;
        if (output.sharesOut != 0) {
            ExchangeInAmount.Result memory receipt = _convert(output.sharesOut, true);
            if (receipt.amountRefunded != 0) revert InsufficientTokenOut();
            amountOut += receipt.amountOut;
        }
        if (amountOut < output.amountOut) revert InsufficientTokenOut();
    }

    function exactOutputRatedDebit(uint256 amountOut) public view returns (uint256) {
        Repo.Layout storage l = Repo._layout();
        uint256 local = FullMath.min(amountOut, l.localPairReserve);
        if (local == amountOut) return amountOut;
        uint256 shares = IStandardExchangeOut(l.standardExchange).previewExchangeOut(
            IERC20(l.standardExchange), IERC20(l.pairToken), amountOut - local);
        if (shares == 0) revert IStandardExchangeOut.ExchangeOutNotAvailable();
        if (shares > l.bookedSeShares) revert InsufficientTokenOut();
        (uint256 invScale, uint256 ratedScale) = _scales(l);
        return local + Math.ratedPairUnitsUp(shares, _rate(l), invScale, ratedScale);
    }

    function requireInputInverse(uint256 ratedInput) public view {
        Repo.Layout storage l = Repo._layout();
        if (disabled()) return;
        if (l.standardExchange == l.pairToken || !ContextQuote.supported(l.standardExchange)) return;
        (uint256 invScale, uint256 ratedScale) = _scales(l);
        uint256 shares = Math.sharesForPairUnitsUp(ratedInput, _rate(l), invScale, ratedScale);
        if (IStandardExchangeOut(l.standardExchange).previewExchangeOut(IERC20(l.pairToken), IERC20(l.standardExchange), shares) == 0)
            revert IStandardExchangeOut.ExchangeOutNotAvailable();
    }
    error InsufficientTokenOut();

    struct ExactOutputContext {
        bytes state;
        uint256 reserve;
        uint256 raw;
        uint8 rawDecimals;
        uint8 pairDecimals;
    }

    /// @dev Linked EO coordinator. Zero manager preserves the actual-context owner/SE path.
    function quoteExactOutContext(bool zeroForOne, uint256 amountOut, address manager)
        external view returns (uint256)
    {
        Repo.Layout storage l = Repo._layout();
        ExactOutputContext memory q;
        bool localOnly = zeroForOne == (l.currency0 == l.rawToken) && amountOut <= l.localPairReserve;
        q.state = localOnly || disabled()
            ? ContextQuote.snapshot(l.standardExchange, l.pairToken, address(this), manager)
            : ContextQuote.exactOutputState(l.standardExchange, l.pairToken, manager);
        uint256 held = l.bookedSeShares;
        q.reserve = l.localPairReserve
            + (q.state.length == 0 ? _ratedOf(l, held) : _ratedWith(l, held, _rateForState(l, q.state)));
        q.rawDecimals = l.rawToken == l.currency0 ? l.decimalsCurrency0 : l.decimalsCurrency1;
        if (q.rawDecimals == 0) q.rawDecimals = 18;
        q.pairDecimals = _pairDecimals(l);
        if (q.pairDecimals == 0) q.pairDecimals = 18;
        q.raw = Math.toWad(l.bookedRaw, q.rawDecimals);
        q.reserve = Math.toWad(q.reserve, q.pairDecimals);
        if (zeroForOne == (l.currency0 == l.rawToken)) {
            uint256 debit = _exactOutputDebit(l, amountOut, q.state);
            return Math.fromWadCeil(Math.purchaseQuote(Math.toWad(debit, q.pairDecimals), q.raw, q.reserve), q.rawDecimals);
        }
        uint256 needed = Math.fromWadCeil(Math.purchaseQuote(Math.toWad(amountOut, q.rawDecimals), q.reserve, q.raw), q.pairDecimals);
        _requireInputInverseContext(l, needed, q.state);
        return _invertBufferClaimIn(l, needed, q.state);
    }

    function _requireInputInverseContext(Repo.Layout storage l, uint256 needed, bytes memory state) private view {
        if (disabled()) return;
        if (l.standardExchange == l.pairToken || !ContextQuote.supported(l.standardExchange)) return;
        if (state.length == 0) requireInputInverse(needed);
        else {
            (uint256 invScale, uint256 ratedScale) = _scales(l);
            uint256 shares = Math.sharesForPairUnitsUp(needed, _rateForState(l, state), invScale, ratedScale);
            if (ContextQuote.inputForSharesFromState(l.standardExchange, l.pairToken, shares, state) == 0)
                revert IStandardExchangeOut.ExchangeOutNotAvailable();
        }
    }

    function _exactOutputDebit(Repo.Layout storage l, uint256 amount, bytes memory state) private view returns (uint256) {
        if (state.length == 0) return exactOutputRatedDebit(amount);
        uint256 local = FullMath.min(amount, l.localPairReserve);
        if (local == amount) return amount;
        uint256 shares = ContextQuote.withdrawFromState(l.standardExchange, l.pairToken, amount - local, state);
        if (shares == 0 || shares > l.bookedSeShares) revert InsufficientTokenOut();
        (uint256 invScale, uint256 ratedScale) = _scales(l);
        return local + Math.ratedPairUnitsUp(shares, _rateForState(l, state), invScale, ratedScale);
    }

    /// @dev Residual maintenance only. A zero quote means the amount cannot enter
    /// the vault yet and stays owned locally.
    function previewResidualBuffer(uint256 amount) internal view returns (uint256 shares) {
        Repo.Layout storage l = Repo._layout();(uint256 quotedAmountOut,) = IStandardExchangeIn(l.standardExchange).previewExchangeIn(IERC20(l.pairToken), amount, IERC20(l.standardExchange)
        );
        return quotedAmountOut;
    }

    /// @dev Consume the immediately preceding residual quote without evaluating
    /// the same read-only composition plan a second time. The minimum is retained.
    function bufferQuotedResidual(uint256 amount, uint256 minimum) external {
        Repo.Layout storage l = Repo._layout();
        IERC20(l.pairToken).forceApprove(l.standardExchange, amount);ExchangeInAmount.exchangeOut(IStandardExchangeIn(address(IStandardExchangeIn(l.standardExchange))), IERC20(l.pairToken), amount, IERC20(l.standardExchange), minimum, address(this), false, block.timestamp
        );
        IERC20(l.pairToken).forceApprove(l.standardExchange, 0);
    }
    error RateProviderFailed();
    error RateProviderRequired();

    /* ------------------------------ D60 rated valuation ------------------------------ */

    /// @notice Fail-closed provider read. Identity leg without a provider reads as 1e18 (raw balance).
    function rate() external view returns (uint256) {
        return _rate(Repo._layout());
    }

    /// @notice SE shares (or identity pair units) valued in pair-token units at the provider rate.
    function ratedOf(uint256 shares) external view returns (uint256) {
        return _ratedOf(Repo._layout(), shares);
    }

    /// @notice Shares needed to represent `pairUnits` at the provider rate, rounding up.
    function sharesForPairUnitsUp(uint256 pairUnits) external view returns (uint256) {
        Repo.Layout storage l = Repo._layout();
        if (pairUnits == 0) return 0;
        if (l.pairToken == l.standardExchange && l.rateProvider == address(0)) return pairUnits;
        (uint256 invScale, uint256 ratedScale) = _scales(l);
        return Math.sharesForPairUnitsUp(pairUnits, _rate(l), invScale, ratedScale);
    }

    /// @notice The hook's SE balance valued at the provider rate; a non-empty book never reads zero.
    function ratedReserve() external view returns (uint256) {
        Repo.Layout storage l = Repo._layout();
        return l.localPairReserve + _ratedOf(l, l.bookedSeShares);
    }

    function _rate(Repo.Layout storage l) private view returns (uint256 rate_) {
        address rp = l.rateProvider;
        if (rp == address(0)) {
            if (l.pairToken == l.standardExchange) return Math.RATE_PRECISION;
            revert RateProviderRequired();
        }
        (bool ok, bytes memory data) = rp.staticcall(abi.encodeWithSelector(IRateProvider.getRate.selector));
        if (!ok || data.length != 32) revert RateProviderFailed();
        rate_ = abi.decode(data, (uint256));
        if (rate_ == 0) revert RateProviderFailed();
    }

    function _scales(Repo.Layout storage l) private view returns (uint256 invScale, uint256 ratedScale) {
        uint8 seDec = l.pairToken == l.standardExchange ? _pairDecimals(l) : l.seDecimals;
        invScale = 10 ** (36 - uint256(seDec));
        ratedScale = 10 ** (36 - uint256(_pairDecimals(l)));
    }

    function _pairDecimals(Repo.Layout storage l) private view returns (uint8) {
        return l.currency0 == l.pairToken ? l.decimalsCurrency0 : l.decimalsCurrency1;
    }

    function _ratedOf(Repo.Layout storage l, uint256 shares) private view returns (uint256) {
        if (shares == 0) return 0;
        if (l.pairToken == l.standardExchange && l.rateProvider == address(0)) return shares;
        (uint256 invScale, uint256 ratedScale) = _scales(l);
        return Math.ratedPairUnits(shares, _rate(l), invScale, ratedScale);
    }

    function _ratedWith(Repo.Layout storage l, uint256 shares, uint256 rate_) private view returns (uint256) {
        if (shares == 0) return 0;
        if (l.pairToken == l.standardExchange && l.rateProvider == address(0)) return shares;
        (uint256 invScale, uint256 ratedScale) = _scales(l);
        return Math.ratedPairUnits(shares, rate_, invScale, ratedScale);
    }

    /// @dev The provider's rate for a projected SE `state` (D41 / D48 `IStandardExchangeRateQuote`), so a
    ///      preview rates the post-buffer book the way execution will read it; a provider without projected
    ///      quotes answers with its live rate. Fails closed like `_rate`.
    function _rateForState(Repo.Layout storage l, bytes memory state) private view returns (uint256) {
        if (l.rateProvider == address(0)) return _rate(l);
        LegLib.ExternalQuote memory q;
        q.exchange = IStandardExchangeTransitionQuote(l.standardExchange);
        q.state = state;
        q.pair = l.pairToken;
        return LegLib.rateAfterExchange(q, l.pairToken, l.rateProvider);
    }

    /* ------------------------------ transition quotes ------------------------------ */

    function supportsTransitionQuote(address se, address pairToken, address holder) external view returns (bool) {
        return _supportsTransitionQuote(se, pairToken, holder);
    }

    function _supportsTransitionQuote(address se, address pairToken, address holder) private view returns (bool) {
        if (ContextQuote.supported(se)) {
            IStandardExchangeTransitionQuote(se).quoteState(pairToken, holder);
            return true;
        }
        if (!IERC165(se).supportsInterface(type(IStandardExchangeTransitionQuote).interfaceId)) return false;
        // D37: probe with staticcall. Identity SE (share == pair) and other
        // unquotable assets must not hard-revert the join; fallback 1:1 claim.
        (bool ok, bytes memory ret) = se.staticcall(
            abi.encodeCall(IStandardExchangeTransitionQuote.quoteState, (pairToken, holder))
        );
        return ok && ret.length > 0;
    }

    function _previewPairToShares(address se, address pairToken, uint256 amountInRaw)
        private
        view
        returns (uint256)
    {
        if (amountInRaw == 0) return 0;
        if (se == pairToken) return amountInRaw;(uint256 quotedAmountOut,) = IStandardExchangeIn(se).previewExchangeIn(IERC20(pairToken), amountInRaw, IERC20(se));
        return quotedAmountOut;
    }

    /// @notice Projected SE state after depositing `amountInRaw` pair tokens, with the holder's
    ///         projected share balance valued at the provider rate (D60) as `ratedHolderClaimAfter`.
    /// @dev H2: Uni V3/V4 `quoteTransition(DepositExactIn)` reverts `InvalidQuoteState`
    ///      when the deposit mints 0 shares (1 wei of an 18-dec pair into a large book).
    ///      `previewExchangeIn` returns 0 for that dust; skip the transition call.
    function quoteMintableDepositExactIn(
        address se,
        address pairToken,
        bytes memory state,
        uint256 amountInRaw
    )
        public
        view
        returns (bytes memory nextState, uint256 amountIn, uint256 amountOut, uint256 ratedHolderClaimAfter)
    {
        Repo.Layout storage l = Repo._layout();
        if (amountInRaw == 0 || _previewPairToShares(se, pairToken, amountInRaw) == 0) {
            return (state, 0, 0, _ratedClaimOfState(l, se, state));
        }
        (nextState, amountIn, amountOut,) = IStandardExchangeTransitionQuote(se).quoteTransition(
            state, IStandardExchangeTransitionQuote.Operation.DepositExactIn, amountInRaw
        );
        ratedHolderClaimAfter = _ratedClaimOfState(l, se, nextState);
    }

    /// @notice Rated holder claim for an already projected `state`: shares x the provider's rate for that state.
    function ratedClaimOfState(address se, bytes memory state) public view returns (uint256) {
        return _ratedClaimOfState(Repo._layout(), se, state);
    }

    function _ratedClaimOfState(Repo.Layout storage l, address se, bytes memory state) private view returns (uint256) {
        uint256 shares_ = IStandardExchangeTransitionQuote(se).quoteShareBalance(state);
        if (shares_ == 0) return 0;
        return _ratedWith(l, shares_, _rateForState(l, state));
    }

    /// @notice Swap-side book at a projected external SE `state` (a route that redeems or deposits before the
    ///         hook swaps): the held shares valued at that state's rate, and the claim `assets` pair tokens add
    ///         when buffered from that state (post-buffer projected rate), computed the way `_claimIn` does.
    function projectedClaimIn(address se, bytes memory state, uint256 heldShares, uint256 assets)
        public view returns (uint256 reserveBefore, uint256 claimIn)
    {
        Repo.Layout storage l = Repo._layout();
        reserveBefore = l.localPairReserve + _ratedWith(l, heldShares, _rateForState(l, state));
        if (assets == 0) return (reserveBefore, 0);
        if (disabled()) return (reserveBefore, assets);
        (bytes memory next, uint256 consumed, uint256 minted,) = IStandardExchangeTransitionQuote(se)
            .quoteTransition(state, IStandardExchangeTransitionQuote.Operation.DepositExactIn, assets);
        uint256 refund = ExchangeInAmount.fromConsumedInput(assets, consumed, minted).amountRefunded;
        uint256 afterValue = l.localPairReserve + refund + _ratedWith(l, heldShares + minted, _rateForState(l, next));
        claimIn = afterValue > reserveBefore ? afterValue - reserveBefore : 0;
    }

    /* ------------------------------ buffer claim-in ------------------------------ */

    /// @dev Pair units the swap reserve gains when `amountInRaw` pair tokens are buffered: the rated book after
    ///      the buffer minus the rated book before it. With a transition-quoting SE the post-buffer book is
    ///      `(held + minted) x rateAfter`, where `rateAfter` is the provider's projected rate for that state
    ///      (an SE usage fee or first-deposit rounding moves the rate; execution reads the moved rate). Without a
    ///      transition quote the gain is `previewExchangeIn(pair -> se) x live rate`. Identity leg: the pair units.
    function _claimIn(Repo.Layout storage l, uint256 amountInRaw) private view returns (uint256) {
        if (amountInRaw == 0) return 0;
        if (disabled()) return amountInRaw;
        ExchangeInAmount.Result memory receipt = ExchangeInAmount.previewResult(
            IStandardExchangeIn(l.standardExchange), IERC20(l.pairToken), amountInRaw, IERC20(l.standardExchange)
        );
        if (!_supportsTransitionQuote(l.standardExchange, l.pairToken, address(this))) {
            return receipt.amountRefunded + _ratedOf(l, receipt.amountOut);
        }
        (bytes memory state,) = IStandardExchangeTransitionQuote(l.standardExchange).quoteState(l.pairToken, address(this));
        (, uint256 gain) = projectedClaimIn(l.standardExchange, state, l.bookedSeShares, amountInRaw);
        return gain;
    }

    function previewBufferClaimIn(uint256 amountInRaw) external view returns (uint256) {
        return _claimIn(Repo._layout(), amountInRaw);
    }

    function invertBufferClaimIn(uint256 claimInNeeded) external view returns (uint256 amountInRaw) {
        return _invertBufferClaimIn(Repo._layout(), claimInNeeded, bytes(""));
    }

    function _claimInContext(Repo.Layout storage l, uint256 amount, bytes memory state) private view returns (uint256 gain) {
        if (disabled()) return amount;
        if (state.length == 0) return _claimIn(l, amount);
        (, gain) = projectedClaimIn(l.standardExchange, state, l.bookedSeShares, amount);
    }

    function _invertBufferClaimIn(Repo.Layout storage l, uint256 claimInNeeded, bytes memory state) private view returns (uint256) {
        if (claimInNeeded == 0) return 0;
        if (disabled()) return claimInNeeded;
        uint256 hi = claimInNeeded;
        uint256 guard;
        while (_claimInContext(l, hi, state) < claimInNeeded && guard < 64) {
            hi = hi * 2;
            unchecked {
                ++guard;
            }
        }
        if (_claimInContext(l, hi, state) < claimInNeeded) {
            revert InsufficientTokenOut();
        }
        uint256 lo = 1;
        while (lo < hi) {
            uint256 mid = (lo + hi) / 2;
            if (_claimInContext(l, mid, state) >= claimInNeeded) {
                hi = mid;
            } else {
                lo = mid + 1;
            }
        }
        return lo;
    }
}
