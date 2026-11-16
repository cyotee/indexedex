// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeTransitionQuote as Transition} from "contracts/interfaces/IStandardExchangeTransitionQuote.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IFeeCollectorProxy} from "contracts/interfaces/proxies/IFeeCollectorProxy.sol";
import {IVaultRegistryDisableQuery} from "contracts/interfaces/IVaultRegistryDisableQuery.sol";
import {Math as FullMath} from "@crane/contracts/utils/Math.sol";
import {ExchangeInAmount} from "contracts/utils/ExchangeInAmount.sol";
import {UniswapV4BufferHookLiquidityRouteLib as Components} from "contracts/hooks/uniswap/v4/libs/UniswapV4BufferHookLiquidityRouteLib.sol";
import {UniswapV4DualStandardExchangeBufferConstantProductHookRepo as Repo} from "./UniswapV4DualStandardExchangeBufferConstantProductHookRepo.sol";
import {UniswapV4DualStandardExchangeBufferConstantProductHookMath as Math} from "./UniswapV4DualStandardExchangeBufferConstantProductHookMath.sol";
import {UniswapV4DualStandardExchangeBufferConstantProductHookClaimLib as ClaimLib} from "./UniswapV4DualStandardExchangeBufferConstantProductHookClaimLib.sol";

/// @notice Dual-family component previews. Opaque optional SE states never substitute for the hook's books.
library UniswapV4DualStandardExchangeBufferConstantProductHookDepositQuoteLib {
    struct Component { uint256 shares; uint256 local; }
    struct Leg {
        address se;
        address pair;
        uint8 decimals;
        bytes state;
        bool unprojected;
        Component book;
    }
    error InsufficientTokenOut();
    error InvalidRoute();

    function book(address pair) internal view returns (Component memory c) {
        Repo.Layout storage l = Repo._layout();
        c.shares = l.shareReserves[l.legs.standardExchangeOf[pair]];
        c.local = l.localReserves[pair];
    }

    function limit(Component memory a, Component memory b, Component memory x, Component memory y, uint256 supply)
        internal pure returns (uint256 gross)
    {
        uint256[] memory available = new uint256[](4);
        uint256[] memory booked = new uint256[](4);
        available[0] = a.shares; available[1] = a.local; available[2] = b.shares; available[3] = b.local;
        booked[0] = x.shares; booked[1] = x.local; booked[2] = y.shares; booked[3] = y.local;
        return Components.maxComponentMint(available, booked, supply);
    }

    function net(uint256 gross) public view returns (uint256 netLp) {
        (IFeeCollectorProxy recipient, uint256 fee) = IVaultFeeOracleQuery(Repo._layout().feeOracle)
            .dexSwapFeeAndFeeToOfVault(address(this));
        (netLp,) = Components.splitMintFee(gross, fee, address(recipient), fee != 0);
    }

    function seed(Component memory a, Component memory b) public view returns (uint256 gross) {
        Repo.Layout storage l = Repo._layout();
        address se0 = l.legs.standardExchangeOf[l.currency0];
        address se1 = l.legs.standardExchangeOf[l.currency1];
        uint8 dec0 = se0 == l.se0 ? l.seDecimals0 : l.seDecimals1;
        uint8 dec1 = se1 == l.se0 ? l.seDecimals0 : l.seDecimals1;
        uint256 total = Math.mintSharesFirst(
            Math.toWad(se0 == l.currency0 ? a.local : a.shares, dec0),
            Math.toWad(se1 == l.currency1 ? b.local : b.shares, dec1));
        return Components.genesisGross(total, Repo.MINIMUM_LIQUIDITY);
    }

    /// @dev One bounded forward estimate, not an inverse operation on the SE. Actual receipts
    /// determine acceptance. No incumbent component is spent, even if conversion is nonlinear.
    function redemptionFor(address se, Component memory available, Component memory old, bytes memory state)
        public view returns (uint256 spend)
    {
        if (available.shares == 0 || old.local == 0) return 0;
        if (old.shares == 0) return available.shares;
        uint256 required = Components.componentContribution(available.shares, old.local, old.shares);
        if (available.local >= required) return 0;
        uint256 missing = required - available.local;
        (ExchangeInAmount.Result memory quote,) = ClaimLib.conversion(se, available.shares, false, state);
        if (quote.amountOut == 0) revert InsufficientTokenOut();
        spend = FullMath.mulDiv(available.shares, missing, quote.amountOut + missing, FullMath.Rounding.Ceil);
    }

    /// @dev Reserve caller-owned pair input before the single SE deposit. The forward
    /// quote sizes a conversion only; final ownership still uses actual S/L quantities.
    function pairToDeposit(address se, uint256 amount, Component memory old, bytes memory state)
        public view returns (uint256)
    {
        if (old.shares == 0) return 0;
        if (old.local == 0) return amount;
        (ExchangeInAmount.Result memory full,) = ClaimLib.conversion(se, amount, true, state);
        uint256 localForFull = Components.componentContribution(full.amountOut, old.local, old.shares);
        uint256 retained = FullMath.mulDiv(amount, localForFull, amount + localForFull, FullMath.Rounding.Ceil);
        return amount - retained;
    }

    function _load(address pair) private view returns (Leg memory leg) {
        Repo.Layout storage l = Repo._layout();
        leg.pair = pair;
        leg.se = l.legs.standardExchangeOf[pair];
        leg.decimals = pair == l.currency0 ? l.decimalsCurrency0 : l.decimalsCurrency1;
        leg.book = book(pair);
        leg.state = ClaimLib.snapshotState(leg.se, address(0));
    }

    function _receive(Leg memory leg, uint256 amount) private view {
        if (leg.state.length != 0 && amount != 0) {
            (leg.state,,,) = Transition(leg.se).quoteTransition(leg.state, Transition.Operation.ReceiveShares, amount);
        }
    }

    function _convert(Leg memory leg, uint256 amount, bool deposit)
        private view returns (ExchangeInAmount.Result memory result)
    {
        if (amount == 0) return result;
        if (leg.unprojected) revert Transition.InvalidQuoteState();
        (result, leg.state) = ClaimLib.conversion(leg.se, amount, deposit, leg.state);
        if (leg.se != leg.pair && leg.state.length == 0 && amount != result.amountRefunded) leg.unprojected = true;
    }

    function _assemble(Leg memory leg, uint256 amount, bool asShare, bool genesis)
        private view returns (Component memory available)
    {
        if (amount == 0) return available;
        if (leg.se == leg.pair) { available.local = amount; return available; }
        if (asShare) {
            available.shares = amount;
            _receive(leg, amount);
        } else if (genesis) {
            if (ClaimLib.disabled(leg.se)) revert IVaultRegistryDisableQuery.VaultDisabled(leg.se);
            ExchangeInAmount.Result memory deposited = _convert(leg, amount, true);
            available.shares = deposited.amountOut;
            available.local = deposited.amountRefunded;
        } else if (leg.book.shares == 0) {
            available.local = amount;
        } else {
            if (leg.unprojected) revert Transition.InvalidQuoteState();
            uint256 forwarded = pairToDeposit(leg.se, amount, leg.book, leg.state);
            ExchangeInAmount.Result memory deposited = _convert(leg, forwarded, true);
            available.shares = deposited.amountOut;
            available.local = amount - forwarded + deposited.amountRefunded;
        }
        uint256 spend;
        if (genesis) (spend,) = Components.bootstrapSplit(available.shares);
        else {
            if (leg.unprojected && available.shares != 0 && leg.book.local != 0 && leg.book.shares != 0
                && available.local < Components.componentContribution(available.shares, leg.book.local, leg.book.shares)) {
                revert Transition.InvalidQuoteState();
            }
            spend = redemptionFor(leg.se, available, leg.book, leg.state);
        }
        if (spend != 0) {
            ExchangeInAmount.Result memory redeemed = _convert(leg, spend, false);
            if (genesis && (redeemed.amountRefunded != 0 || redeemed.amountOut == 0)) revert InsufficientTokenOut();
            available.shares -= spend - redeemed.amountRefunded;
            available.local += redeemed.amountOut;
        }
    }

    function _used(uint256 amount, bool asShare, Component memory available, Component memory old, uint256 gross, uint256 supply)
        private pure returns (uint256)
    {
        if (supply == 0) return amount;
        uint256 excess = asShare
            ? available.shares - Components.componentContribution(gross, old.shares, supply)
            : available.local - Components.componentContribution(gross, old.local, supply);
        return amount - excess;
    }

    function previewFlexible(uint256 amount0, bool asShare0, uint256 amount1, bool asShare1)
        external view returns (uint256 lp, uint256 used0, uint256 used1)
    {
        Repo.Layout storage l = Repo._layout();
        uint256 supply = ERC20Repo._totalSupply();
        if (supply == 0 && (amount0 == 0 || amount1 == 0)) return (0, 0, 0);
        if (supply != 0 && (amount0 == 0 || amount1 == 0)) {
            bool first = amount0 != 0;
            address pair = first ? l.currency0 : l.currency1;
            bool asShare = first ? asShare0 : asShare1;
            uint256 used;
            (lp, used) = _previewSingle(asShare ? l.legs.standardExchangeOf[pair] : pair, first ? amount0 : amount1);
            (used0, used1) = first ? (used, uint256(0)) : (uint256(0), used);
            return (lp, used0, used1);
        }
        Leg memory x = _load(l.currency0);
        Leg memory y = _load(l.currency1);
        Component memory a = _assemble(x, amount0, asShare0, supply == 0);
        Component memory b = _assemble(y, amount1, asShare1, supply == 0);
        uint256 gross = supply == 0 ? seed(a, b) : limit(a, b, x.book, y.book, supply);
        if (gross == 0) return (0, 0, 0);
        lp = net(gross);
        used0 = _used(amount0, asShare0 && x.se != x.pair, a, x.book, gross, supply);
        used1 = _used(amount1, asShare1 && y.se != y.pair, b, y.book, gross, supply);
    }

    function _reserve(Leg memory leg) private view returns (uint256) {
        if (leg.unprojected && leg.book.shares != 0) revert Transition.InvalidQuoteState();
        return leg.book.local + ClaimLib.ratedAt(leg.se, leg.book.shares, leg.state);
    }

    function _swap(Leg memory input, Leg memory output, uint256 amount) private view returns (uint256 received) {
        if (input.unprojected) revert Transition.InvalidQuoteState();
        uint256 gain = ClaimLib.inputGain(input.se, input.book.shares, amount, input.state);
        uint256 budget = Math.fromWadFloor(Math.saleQuote(Math.toWad(gain, input.decimals),
            Math.toWad(_reserve(input), input.decimals), Math.toWad(_reserve(output), output.decimals)), output.decimals);
        ClaimLib.OutputQuote memory quote;
        bytes memory nextOutput;
        (quote, nextOutput) = ClaimLib.outputAt(output.se, budget, output.book.shares, output.book.local, output.state);
        ExchangeInAmount.Result memory deposited = _convert(input, amount, true);
        if (input.se == input.pair) input.book.local += amount;
        else {
            input.book.shares += deposited.amountOut;
            input.book.local += deposited.amountRefunded;
        }
        output.book.shares -= quote.shares - quote.refundedShares;
        output.book.local -= quote.local;
        output.state = nextOutput;
        if (output.se != output.pair && nextOutput.length == 0 && quote.shares != quote.refundedShares) {
            output.unprojected = true;
        }
        return quote.amount;
    }

    function _swapAmount(Leg memory input, uint256 amount) private view returns (uint256) {
        if (input.unprojected) revert Transition.InvalidQuoteState();
        uint256 gain = ClaimLib.inputGain(input.se, input.book.shares, amount, input.state);
        if (gain == 0) return 0;
        uint256 sale = Math.fromWadFloor(Math.swapDepositSaleAmt(Math.toWad(gain, input.decimals),
            Math.toWad(_reserve(input), input.decimals)), input.decimals);
        return FullMath.mulDiv(amount, sale, gain);
    }

    function swapAmount(address pair, uint256 amount) public view returns (uint256) {
        return _swapAmount(_load(pair), amount);
    }

    /// @notice Project the paid swap, then native component acceptance against its resulting book.
    function preview(address tokenIn, uint256 amountIn) public view returns (bool supported, uint256 shares) {
        (shares,) = _previewSingle(tokenIn, amountIn);
        return (true, shares);
    }

    function _previewSingle(address tokenIn, uint256 amountIn) private view returns (uint256 shares, uint256 used) {
        Repo.Layout storage l = Repo._layout();
        address pairIn = l.legs.pairOfStandardExchange[tokenIn];
        bool shareInput = pairIn != address(0) && tokenIn != pairIn;
        if (!shareInput) pairIn = tokenIn;
        if (pairIn != l.currency0 && pairIn != l.currency1) return (0, 0);
        uint256 supply = ERC20Repo._totalSupply();
        if (amountIn == 0 || supply <= Repo.MINIMUM_LIQUIDITY) return (0, 0);
        // A pair input of one native unit cannot fund both the paid sale and its retained leg.
        if (!shareInput && amountIn == 1) return (0, 0);
        Leg memory input = _load(pairIn);
        Leg memory output = _load(pairIn == l.currency0 ? l.currency1 : l.currency0);
        uint256 pairAmount = amountIn;
        uint256 refundedShares;
        if (shareInput) {
            _receive(input, amountIn);
            ExchangeInAmount.Result memory redeemed = _convert(input, amountIn, false);
            pairAmount = redeemed.amountOut;
            refundedShares = redeemed.amountRefunded;
        }
        uint256 sold = _swapAmount(input, pairAmount);
        if (sold == 0 || sold >= pairAmount) return (0, 0);
        uint256 received = _swap(input, output, sold);
        if (received == 0) return (0, 0);
        Component memory a;
        Component memory b;
        // Match execution's currency order for both conversions.
        if (pairIn == l.currency0) {
            a = _assemble(input, pairAmount - sold, false, false);
            b = _assemble(output, received, false, false);
        } else {
            b = _assemble(output, received, false, false);
            a = _assemble(input, pairAmount - sold, false, false);
        }
        uint256 gross = limit(a, b, input.book, output.book, supply);
        if (gross == 0) return (0, 0);
        shares = net(gross);
        used = amountIn - (shareInput
            ? refundedShares + a.shares - Components.componentContribution(gross, input.book.shares, supply)
            : a.local - Components.componentContribution(gross, input.book.local, supply));
    }

    function _withdrawLeg(Leg memory leg, uint256 burned, uint256 supply, bool asShare)
        private view returns (uint256 amount)
    {
        uint256 shares = Components.componentAllocation(burned, leg.book.shares, supply);
        uint256 local = Components.componentAllocation(burned, leg.book.local, supply);
        leg.book.shares -= shares;
        leg.book.local -= local;
        if (leg.se == leg.pair) return local;
        if (asShare) {
            if (local == 0) return shares;
            if (ClaimLib.disabled(leg.se)) revert IVaultRegistryDisableQuery.VaultDisabled(leg.se);
            ExchangeInAmount.Result memory result = _convert(leg, local, true);
            if (result.amountRefunded != 0 || result.amountOut == 0) revert InsufficientTokenOut();
            return shares + result.amountOut;
        }
        if (shares == 0) return local;
        ExchangeInAmount.Result memory result = _convert(leg, shares, false);
        if (result.amountRefunded != 0 || result.amountOut == 0) revert InsufficientTokenOut();
        return local + result.amountOut;
    }

    function previewWithdraw(uint256 burned, bool asShare0, bool asShare1)
        external view returns (uint256 amount0, uint256 amount1)
    {
        Repo.Layout storage l = Repo._layout();
        uint256 supply = ERC20Repo._totalSupply();
        amount0 = _withdrawLeg(_load(l.currency0), burned, supply, asShare0);
        amount1 = _withdrawLeg(_load(l.currency1), burned, supply, asShare1);
    }

    function previewExit(address tokenOut, uint256 burned) external view returns (uint256 amountOut) {
        Repo.Layout storage l = Repo._layout();
        address pair = l.legs.pairOfStandardExchange[tokenOut];
        bool asShare = pair != address(0) && pair != tokenOut;
        if (!asShare) pair = tokenOut;
        Leg memory output = _load(pair);
        Leg memory input = _load(pair == l.currency0 ? l.currency1 : l.currency0);
        uint256 supply = ERC20Repo._totalSupply();
        // Match execution order: currency0, then currency1, before the residual trade.
        uint256 residual;
        if (pair == l.currency0) {
            amountOut = _withdrawLeg(output, burned, supply, false);
            residual = _withdrawLeg(input, burned, supply, false);
        } else {
            residual = _withdrawLeg(input, burned, supply, false);
            amountOut = _withdrawLeg(output, burned, supply, false);
        }
        if (residual != 0) amountOut += _swap(input, output, residual);
        if (asShare && amountOut != 0) {
            if (ClaimLib.disabled(output.se)) revert IVaultRegistryDisableQuery.VaultDisabled(output.se);
            ExchangeInAmount.Result memory result = _convert(output, amountOut, true);
            if (result.amountRefunded != 0 || result.amountOut == 0) revert InsufficientTokenOut();
            amountOut = result.amountOut;
        }
    }
}
