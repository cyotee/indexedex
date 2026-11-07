// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {IVaultRegistryDisableQuery} from "contracts/interfaces/IVaultRegistryDisableQuery.sol";
import {ExchangeInAmount} from "contracts/utils/ExchangeInAmount.sol";

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {Math as FullMath} from "@crane/contracts/utils/Math.sol";
import {UniswapV4SeBufferHookContextQuoteLib as ContextQuote} from "contracts/hooks/uniswap/v4/libs/UniswapV4SeBufferHookContextQuoteLib.sol";
import {BetterSafeERC20 as SafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {UniswapV4StandardExchangeWeightedBufferHookRepo as Repo} from
    "contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookRepo.sol";
import {UniswapV4StandardExchangeWeightedBufferHookMath as Math} from
    "contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookMath.sol";
import {IRateProvider} from
    "@crane/contracts/protocols/dexes/balancer/common/interfaces/IRateProvider.sol";

/**
 * @title UniswapV4StandardExchangeWeightedBufferHookClaimLib
 * @notice SE buffer / unwrap + claim / rate helpers (external lib keeps diamond under EIP-170).
 * @dev Buffer uses exchangeIn(pair→SE); unwrap uses exchangeIn(SE→pair) with exchangeOut fallback.
 *      High-level library calls use DELEGATECALL so address(this) remains the hook.
 */
library UniswapV4StandardExchangeWeightedBufferHookClaimLib {
    using SafeERC20 for IERC20;

    error BufferFailed();
    error UnwrapFailed();
    error RateProviderFailed();
    error RateProviderRequired();
    error ZeroAmount();
    error InvalidPair();
    error SwapNotLive();
    error InvalidFeeWad();

    /// @dev Unchanged quote orchestration, linked instead of repeated in consuming facets.
    function previewSwapExactInContext(address tokenIn, address tokenOut, uint256 amountIn, address manager)
        external view returns (uint256 amountOut, uint256 sharesOut)
    {
        if (amountIn == 0) revert ZeroAmount();
        if (tokenIn == tokenOut) revert InvalidPair();
        uint8 i = Repo._indexOf(Repo._layout(), tokenIn);
        uint8 j = Repo._indexOf(Repo._layout(), tokenOut);
        uint256[] memory rated = manager == address(0) ? _ratedWadAll() : ratedWadAllWithContext(manager);
        if (rated[i] == 0 || rated[j] == 0) revert SwapNotLive();
        Repo.Layout storage l = Repo._layout();
        uint256 feeWad = IVaultFeeOracleQuery(l.feeOracle).dexSwapFeeOfVault(address(this));
        if (feeWad >= Math.WAD) revert InvalidFeeWad();
        uint256 net = Math.applyTradingFeeNet(amountIn, feeWad);
        uint256 ratedInflow = manager == address(0) || l.standardExchanges[i] == address(0) || l.standardExchanges[i] == l.tokens[i]
            ? mapPairInToRatedWad(i, net) : pairInWithContext(i, net, manager);
        return quoteSwapExactInContext(i, j, rated, ratedInflow, manager);
    }

    function _ratedWadAll() private view returns (uint256[] memory rated) {
        Repo.Layout storage l = Repo._layout();
        rated = new uint256[](l.numTokens);
        for (uint8 i; i < l.numTokens; ++i) rated[i] = Math.scaleTo(ratedPairUnits(i), l.ratedScales[i]);
    }

    function mapPairInToRatedWad(uint8 i, uint256 pairAmount) public view returns (uint256) {
        Repo.Layout storage l = Repo._layout();
        address se = l.standardExchanges[i];
        if (se == address(0)) {
            uint256 units = l.rateProviders[i] == address(0) ? pairAmount : FullMath.mulDiv(pairAmount, _readRate(l.rateProviders[i]), 1e18);
            return Math.scaleTo(units, l.ratedScales[i]);
        }
        if (isDisabled(i)) return Math.scaleTo(pairAmount, l.ratedScales[i]);
        ExchangeInAmount.Result memory result = ExchangeInAmount.previewResult(IStandardExchangeIn(se), IERC20(l.tokens[i]), pairAmount, IERC20(se));
        if (result.amountOut == 0) return Math.scaleTo(result.amountRefunded, l.ratedScales[i]);
        return Math.scaleTo(result.amountRefunded + Math.ratedPairUnits(result.amountOut, _readRate(l.rateProviders[i]), l.invScales[i], l.ratedScales[i]), l.ratedScales[i]);
    }


    function ratedPairUnits(uint8 i) public view returns (uint256) {
        Repo.Layout storage l = Repo._layout();
        address se = l.standardExchanges[i];
        address rp = l.rateProviders[i];
        // D60: raw leg = raw balance (times the rate when a provider is configured); buffered leg = shares x rate.
        // The hook never derives a rate from the SE's own quotes.
        if (se == address(0)) {
            if (rp == address(0)) return l.rawReserves[i];
            return Math.ratedPairUnits(l.rawReserves[i], _readRate(rp), l.invScales[i], l.ratedScales[i]);
        }
        uint256 seBal = l.seReserves[i];
        if (seBal == 0) return l.rawReserves[i];
        if (rp == address(0)) revert RateProviderRequired();
        return l.rawReserves[i] + Math.ratedPairUnits(seBal, _readRate(rp), l.invScales[i], l.ratedScales[i]);
    }

    function _readRate(address rp) private view returns (uint256 rate) {
        if (rp == address(0)) return 0;
        (bool ok, bytes memory data) =
            rp.staticcall(abi.encodeWithSelector(IRateProvider.getRate.selector));
        if (!ok || data.length != 32) revert RateProviderFailed();
        rate = abi.decode(data, (uint256));
        if (rate == 0) revert RateProviderFailed();
    }

    function getRateFailClosed(address provider) external view returns (uint256) {
        return _readRate(provider);
    }

    /// @dev Convert a rated swap budget to native inventory; EI floors, EO funding ceils.
    function nativeForRatedWad(uint8 i, uint256 ratedWad, bool roundUp) public view returns (uint256) {
        if (ratedWad == 0) return 0;
        Repo.Layout storage l = Repo._layout();
        address rp = l.rateProviders[i];
        if (rp == address(0)) revert RateProviderRequired();
        FullMath.Rounding rounding = roundUp ? FullMath.Rounding.Ceil : FullMath.Rounding.Floor;
        uint256 sharesWad = FullMath.mulDiv(ratedWad, Math.RATE_PRECISION, _readRate(rp), rounding);
        return FullMath.mulDiv(sharesWad, Math.RATE_PRECISION, l.invScales[i], rounding);
    }

    function ratedWadForNativeUp(uint8 i, uint256 units) public view returns (uint256) {
        Repo.Layout storage l = Repo._layout();
        address rp = l.rateProviders[i];
        if (rp == address(0)) revert RateProviderRequired();
        uint256 wad = FullMath.mulDiv(units, l.invScales[i], Math.RATE_PRECISION, FullMath.Rounding.Ceil);
        return FullMath.mulDiv(wad, _readRate(rp), Math.RATE_PRECISION, FullMath.Rounding.Ceil);
    }

    function _nativeAt(uint8 i) private view returns (uint256) {
        Repo.Layout storage l = Repo._layout();
        return l.standardExchanges[i] == address(0) ? l.rawReserves[i] : l.seReserves[i];
    }

    function quoteSwapExactIn(uint8 i, uint8 j, uint256[] memory rated, uint256 inflow)
        external view returns (uint256 amountOut, uint256 sharesOut)
    {
        return quoteSwapExactInContext(i, j, rated, inflow, address(0));
    }

    function quoteSwapExactInContext(uint8 i, uint8 j, uint256[] memory rated, uint256 inflow, address manager)
        public view returns (uint256 amountOut, uint256 sharesOut)
    {
        Repo.Layout storage l = Repo._layout();
        if (inflow > rated[i] * Math.MAX_IN_RATIO / Math.WAD) revert Math.MaxInRatio();
        uint256 budget = Math.quoteExactIn(rated[i], l.weights[i], rated[j], l.weights[j], inflow, Math.RATE_PRECISION, Math.RATE_PRECISION, 0);
        if (budget >= rated[j]) revert Math.WouldZeroReserve();
        return _outputBudget(j, budget, manager);
    }

    function _outputBudget(uint8 j, uint256 budget, address manager) private view returns (uint256 amountOut, uint256 sharesOut) {
        Repo.Layout storage l = Repo._layout();
        uint256 nativeBudget = Math.descale(budget, l.ratedScales[j]);
        uint256 local = FullMath.min(l.rawReserves[j], nativeBudget);
        if (l.standardExchanges[j] == address(0)) {
            amountOut = Math.descale(budget, l.ratedScales[j]);
            if (amountOut >= l.rawReserves[j]) revert Math.WouldZeroReserve();
        } else {
            uint256 deficit = nativeBudget > local ? budget - Math.scaleTo(local, l.ratedScales[j]) : 0;
            if (deficit != 0) {
                uint256 rate = manager == address(0) ? _readRate(l.rateProviders[j]) : ContextQuote.rate(l.standardExchanges[j], l.tokens[j], l.rateProviders[j], manager);
                sharesOut = FullMath.mulDiv(FullMath.mulDiv(deficit, 1e18, rate), 1e18, l.invScales[j]);
                if (sharesOut > l.seReserves[j]) revert Math.WouldZeroReserve();
                if (sharesOut != 0) {
                    (ExchangeInAmount.Result memory r,) = ContextQuote.redeemResult(l.standardExchanges[j], l.tokens[j], address(this), sharesOut, manager);
                    if (r.amountRefunded != 0) revert UnwrapFailed();
                    amountOut = r.amountOut;
                }
            }
            amountOut += local;
        }
        if (amountOut == 0) revert Math.ZeroAmount();
    }

    function ratedWadAllWithContext(address manager) public view returns (uint256[] memory rated) {
        Repo.Layout storage l = Repo._layout();
        rated = new uint256[](l.numTokens);
        for (uint8 i; i < l.numTokens; ++i) {
            address se = l.standardExchanges[i];
            uint256 units;
            if (se == address(0) || se == l.tokens[i]) units = ratedPairUnits(i);
            else if (l.seReserves[i] == 0) units = l.rawReserves[i];
            else {
                if (l.rateProviders[i] == address(0)) revert RateProviderRequired();
                units = l.rawReserves[i] + Math.ratedPairUnits(l.seReserves[i], ContextQuote.rate(se, l.tokens[i], l.rateProviders[i], manager), l.invScales[i], l.ratedScales[i]);
            }
            rated[i] = Math.scaleTo(units, l.ratedScales[i]);
        }
    }

    function pairInWithContext(uint8 i, uint256 amount, address manager) public view returns (uint256) {
        Repo.Layout storage l = Repo._layout();
        if (isDisabled(i)) return Math.scaleTo(amount, l.ratedScales[i]);
        (ExchangeInAmount.Result memory result,) = ContextQuote.depositResult(l.standardExchanges[i], l.tokens[i], address(this), amount, manager);
        if (result.amountOut == 0) return Math.scaleTo(result.amountRefunded, l.ratedScales[i]);
        return Math.scaleTo(result.amountRefunded + Math.ratedPairUnits(result.amountOut, ContextQuote.rate(l.standardExchanges[i], l.tokens[i], l.rateProviders[i], manager), l.invScales[i], l.ratedScales[i]), l.ratedScales[i]);
    }

    function quoteSwapExactOut(uint8 i, uint8 j, uint256[] memory rated, uint256 amountOut, uint256 feeWad)
        external view returns (uint256 amountIn)
    {
        return quoteSwapExactOutContext(i, j, rated, amountOut, feeWad, address(0));
    }

    function quoteSwapExactOutContext(uint8 i, uint8 j, uint256[] memory rated, uint256 amountOut, uint256 feeWad, address manager)
        public view returns (uint256 amountIn)
    {
        Repo.Layout storage l = Repo._layout();
        uint256 debit = _exactOutputDebit(j, amountOut, manager);
        if (debit > rated[j] * Math.MAX_OUT_RATIO / Math.WAD) revert Math.MaxOutRatio();
        address se = l.standardExchanges[i];
        if (se == address(0) || isDisabled(i) || !ContextQuote.supported(se)) {
            return _legacyInputQuote(i, j, rated, amountOut, debit, feeWad);
        }
        uint256 netRated = Math.quoteExactOut(rated[i], l.weights[i], rated[j], l.weights[j], debit, Math.RATE_PRECISION, Math.RATE_PRECISION, 0);
        uint256 netPair = _inputForRatedContext(i, netRated, manager);
        if (netPair == 0) revert IStandardExchangeOut.ExchangeOutNotAvailable();
        amountIn = Math.grossUpExactOut(netPair, feeWad);
        if (amountIn == 0) revert Math.ZeroAmount();
    }

    struct LegacyExactOutputQuote {
        uint256 balanceIn;
        uint256 weightIn;
        uint256 balanceOut;
        uint256 weightOut;
        uint256 amountOut;
        uint256 inputScale;
        uint256 outputScale;
        uint256 feeWad;
    }

    function _legacyInputQuote(uint8 i, uint8 j, uint256[] memory rated, uint256 amountOut, uint256 debit, uint256 feeWad)
        private view returns (uint256)
    {
        Repo.Layout storage l = Repo._layout();
        LegacyExactOutputQuote memory q;
        q.balanceIn = rated[i];
        q.weightIn = l.weights[i];
        q.balanceOut = rated[j];
        q.weightOut = l.weights[j];
        q.amountOut = amountOut;
        q.inputScale = l.ratedScales[i];
        q.outputScale = l.ratedScales[j];
        q.feeWad = feeWad;
        // Both legacy legs use precisely the original raw-output/scales call. A
        // mixed contextual output instead supplies its already rated share debit.
        {
            address se = l.standardExchanges[j];
            if (se != address(0)) {
                q.amountOut = debit;
                q.outputScale = Math.RATE_PRECISION;
            }
        }
        return _quoteLegacyExactOutput(q);
    }

    function _quoteLegacyExactOutput(LegacyExactOutputQuote memory q) private pure returns (uint256) {
        return Math.quoteExactOut(q.balanceIn, q.weightIn, q.balanceOut, q.weightOut,
            q.amountOut, q.inputScale, q.outputScale, q.feeWad);
    }

    function _exactOutputDebit(uint8 j, uint256 amount, address manager) private view returns (uint256) {
        Repo.Layout storage l = Repo._layout();
        address se = l.standardExchanges[j];
        if (se == address(0)) return _legacyOutputDebit(j, amount);
        uint256 local = FullMath.min(amount, l.rawReserves[j]);
        uint256 debit = Math.scaleToUp(local, l.ratedScales[j]);
        if (local == amount) return debit;
        bytes memory state = ContextQuote.exactOutputState(se, l.tokens[j], manager);
        uint256 shares = ContextQuote.withdrawFromState(se, l.tokens[j], amount - local, state);
        if (shares == 0) revert IStandardExchangeOut.ExchangeOutNotAvailable();
        if (shares > l.seReserves[j]) revert Math.WouldZeroReserve();
        if (state.length == 0) return debit + ratedWadForNativeUp(j, shares);
        uint256 wad = FullMath.mulDiv(shares, l.invScales[j], 1e18, FullMath.Rounding.Ceil);
        return debit + FullMath.mulDiv(wad, ContextQuote.rateFromState(se, l.tokens[j], l.rateProviders[j], state), 1e18, FullMath.Rounding.Ceil);
    }

    /// @dev b019f232 weighted EO priced nominal pair output; no CP-style input search.
    function _legacyOutputDebit(uint8 j, uint256 amount) private view returns (uint256) {
        if (amount >= ratedPairUnits(j)) revert Math.WouldZeroReserve();
        return Math.scaleToUp(amount, Repo._layout().ratedScales[j]);
    }

    function _inputForRatedContext(uint8 i, uint256 netRated, address manager) private view returns (uint256) {
        Repo.Layout storage l = Repo._layout();
        address se = l.standardExchanges[i];
        bytes memory state = ContextQuote.exactOutputState(se, l.tokens[i], manager);
        uint256 shares = _sharesForRatedContext(i, netRated, state);
        return ContextQuote.inputForSharesFromState(se, l.tokens[i], shares, state);
    }

    function _sharesForRatedContext(uint8 i, uint256 netRated, bytes memory state) private view returns (uint256) {
        if (state.length == 0) return nativeForRatedWad(i, netRated, true);
        Repo.Layout storage l = Repo._layout();
        uint256 rate = ContextQuote.rateFromState(l.standardExchanges[i], l.tokens[i], l.rateProviders[i], state);
        uint256 sharesWad = FullMath.mulDiv(netRated, Math.RATE_PRECISION, rate, FullMath.Rounding.Ceil);
        return FullMath.mulDiv(sharesWad, Math.RATE_PRECISION, l.invScales[i], FullMath.Rounding.Ceil);
    }

    /// @dev Live claim of SE shares → pair token units (fee-inclusive preview).
    function seClaimOf(address se, address pairToken, uint256 seAmount) external view returns (uint256) {
        if (seAmount == 0 || se == address(0)) return 0;
        if (se == pairToken) return seAmount;(uint256 quotedAmountOut,) = IStandardExchangeIn(se).previewExchangeIn(IERC20(se), seAmount, IERC20(pairToken));
        return quotedAmountOut;
    }

    /// @dev Preview shares minted when buffering `amountInRaw` pair tokens into SE.
    function previewBufferShares(address se, address pairToken, uint256 amountInRaw)
        external
        view
        returns (uint256 sharesOut)
    {
        if (amountInRaw == 0 || se == address(0)) return 0;
        if (se == pairToken) return amountInRaw;(uint256 quotedAmountOut,) = IStandardExchangeIn(se).previewExchangeIn(IERC20(pairToken), amountInRaw, IERC20(se));
        return quotedAmountOut;
    }

    /// @dev Preview pair tokens from unwrapping `seAmount` shares.
    function previewUnwrap(address se, address pairToken, uint256 seAmount)
        external
        view
        returns (uint256 amountOut)
    {
        if (seAmount == 0 || se == address(0)) return 0;
        if (se == pairToken) return seAmount;(uint256 quotedAmountOut,) = IStandardExchangeIn(se).previewExchangeIn(IERC20(se), seAmount, IERC20(pairToken));
        return quotedAmountOut;
    }

    /// @notice Shares needed so unwrap delivers at least `amountOutNative` pair tokens.
    function invertUnwrapExactTokenOut(address se, address pairToken, uint256 amountOutNative)
        external
        view
        returns (uint256 sharesIn)
    {
        if (amountOutNative == 0) return 0;
        if (se == pairToken) return amountOutNative;
        return IStandardExchangeOut(se).previewExchangeOut(IERC20(se), IERC20(pairToken), amountOutNative);
    }

    /// @notice Pair tokens needed to mint at least `sharesOut` SE shares via buffer.
    function invertBufferExactSharesOut(address se, address pairToken, uint256 sharesOut)
        external
        view
        returns (uint256 amountInRaw)
    {
        if (sharesOut == 0) return 0;
        if (se == pairToken) return sharesOut;
        return IStandardExchangeOut(se).previewExchangeOut(IERC20(pairToken), IERC20(se), sharesOut);
    }

    /// @notice Buffer full gross pair tokens into SE; minOut = tight fee-inclusive preview.
    /// @return sharesOut SE shares received by hook (balance delta).
    function buffer(address se, address pairToken, uint256 amountInRaw) public returns (uint256 sharesOut) {
        return convert(Repo._indexOf(Repo._layout(), pairToken), false, amountInRaw).amountOut;
    }

    /// @notice Unwrap SE shares to pair token for `to`.
    function unwrap(address se, address pairToken, uint256 seAmount, address to) external returns (uint256 amountOut) {
        ExchangeInAmount.Result memory r = convert(Repo._indexOf(Repo._layout(), pairToken), true, seAmount);
        if (r.amountRefunded != 0 || (seAmount != 0 && r.amountOut == 0)) revert UnwrapFailed();
        amountOut = r.amountOut;
        if (to != address(this) && amountOut != 0) IERC20(pairToken).safeTransfer(to, amountOut);
    }

    /// @notice Unwrap exact pair-token out (burns SE shares as needed).
    function unwrapExactTokenOut(address se, address pairToken, uint256 amountOut, address to) external returns (uint256 spent) {
        Repo.Layout storage l = Repo._layout();
        uint8 i = Repo._indexOf(l, pairToken);
        uint256 local = FullMath.min(amountOut, l.rawReserves[i]);
        l.rawReserves[i] -= local;
        uint256 deficit = amountOut - local;
        if (deficit != 0) {
            uint256 maximum = IStandardExchangeOut(se).previewExchangeOut(IERC20(se), IERC20(pairToken), deficit);
            if (maximum == 0) revert IStandardExchangeOut.ExchangeOutNotAvailable();
            if (maximum > l.seReserves[i]) revert UnwrapFailed();
            uint256 beforeShares = IERC20(se).balanceOf(address(this));
            uint256 beforePair = IERC20(pairToken).balanceOf(address(this));
            IERC20(se).forceApprove(se, maximum);
            spent = IStandardExchangeOut(se).exchangeOut(IERC20(se), maximum, IERC20(pairToken), deficit, address(this), false, block.timestamp);
            IERC20(se).forceApprove(se, 0);
            uint256 received = IERC20(pairToken).balanceOf(address(this)) - beforePair;
            if (spent > maximum || beforeShares - IERC20(se).balanceOf(address(this)) != spent || received < deficit) revert UnwrapFailed();
            l.seReserves[i] -= spent;
            l.rawReserves[i] += received - deficit;
        }
        if (to != address(this)) IERC20(pairToken).safeTransfer(to, amountOut);
    }

    /// @dev Dilution-aware claim delta for buffering `amountInRaw` into SE (no RP).
    function previewBufferClaimIn(address se, address pairToken, uint256 amountInRaw, address hook)
        external
        view
        returns (uint256)
    {
        if (amountInRaw == 0 || se == address(0)) return 0;
        if (se == pairToken) return amountInRaw;(uint256 sharesOut,) = IStandardExchangeIn(se).previewExchangeIn(IERC20(pairToken), amountInRaw, IERC20(se));
        if (sharesOut == 0) return 0;
        uint256 seBalBefore = IERC20(se).balanceOf(hook);uint256 claimBefore = seBalBefore == 0
            ? 0
            : ExchangeInAmount.previewOut(IStandardExchangeIn(address(IStandardExchangeIn(se))), IERC20(se), seBalBefore, IERC20(pairToken));(uint256 claimAfter,) = IStandardExchangeIn(se).previewExchangeIn(IERC20(se), seBalBefore + sharesOut, IERC20(pairToken));
        return claimAfter > claimBefore ? claimAfter - claimBefore : 0;
    }

    /// @dev Unknown or foreign registrations are unsupported, never implicitly enabled.
    function isDisabled(uint8 i) public view returns (bool) {
        Repo.Layout storage l = Repo._layout();
        if (l.standardExchanges[i] == address(0)) return false;
        IVaultRegistryDisableQuery registry = IVaultRegistryDisableQuery(l.vaultRegistry);
        if (registry.packageOfVault(l.standardExchanges[i]) == address(0)) revert BufferFailed();
        return registry.isDisabled(l.standardExchanges[i]);
    }

    /// @dev Receipt belongs to the invoking operation; this function never books caller assets.
    function convert(uint8 i, bool sharesIn, uint256 amount) public returns (ExchangeInAmount.Result memory r) {
        if (amount == 0) return r;
        Repo.Layout storage l = Repo._layout();
        address se = l.standardExchanges[i];
        if (!sharesIn && isDisabled(i)) return ExchangeInAmount.Result(0, amount);
        IERC20 input = IERC20(sharesIn ? se : l.tokens[i]);
        IERC20 output = IERC20(sharesIn ? l.tokens[i] : se);
        uint256 beforeIn = input.balanceOf(address(this));
        uint256 beforeOut = output.balanceOf(address(this));
        ExchangeInAmount.Result memory quote = ExchangeInAmount.previewResult(IStandardExchangeIn(se), input, amount, output);
        input.forceApprove(se, amount);
        r = ExchangeInAmount.exchangeResult(IStandardExchangeIn(se), input, amount, output, quote.amountOut, address(this), false, block.timestamp);
        input.forceApprove(se, 0);
        ExchangeInAmount.requireReceipt(amount, r, beforeIn, input.balanceOf(address(this)), beforeOut, output.balanceOf(address(this)));
    }

    function bufferPool(uint8 i, uint256 amount) external returns (uint256) {
        Repo.Layout storage l = Repo._layout();
        if (l.standardExchanges[i] == address(0)) { l.rawReserves[i] += amount; return 0; }
        ExchangeInAmount.Result memory r = convert(i, false, amount);
        l.seReserves[i] += r.amountOut;
        l.rawReserves[i] += r.amountRefunded;
        return r.amountOut;
    }
}
