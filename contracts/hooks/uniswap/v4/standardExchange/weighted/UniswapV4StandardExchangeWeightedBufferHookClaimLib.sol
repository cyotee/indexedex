// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

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
        if (se == address(0) || se == l.tokens[i]) {
            address rpRaw = l.rateProviders[i];
            uint256 units = rpRaw == address(0) ? pairAmount : (pairAmount * _readRate(rpRaw)) / Math.RATE_PRECISION;
            return Math.scaleTo(units, l.ratedScales[i]);
        }
        address rp = l.rateProviders[i];
        if (rp == address(0)) revert RateProviderRequired();
        uint256 shares = IStandardExchangeIn(se).previewExchangeIn(IERC20(l.tokens[i]), pairAmount, IERC20(se));
        if (shares == 0) return 0;
        uint256 pairUnits = Math.ratedPairUnits(shares, _readRate(rp), l.invScales[i], l.ratedScales[i]);
        return Math.scaleTo(pairUnits, l.ratedScales[i]);
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
        uint256 seBal = IERC20(se).balanceOf(address(this));
        if (seBal == 0) return 0;
        if (rp == address(0)) revert RateProviderRequired();
        return Math.ratedPairUnits(seBal, _readRate(rp), l.invScales[i], l.ratedScales[i]);
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
        return l.standardExchanges[i] == address(0) ? l.rawReserves[i] : IERC20(l.standardExchanges[i]).balanceOf(address(this));
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
        address se = l.standardExchanges[j];
        if (se != address(0) && se != l.tokens[j]) {
            if (manager == address(0)) sharesOut = nativeForRatedWad(j, budget, false);
            else {
                uint256 rate = ContextQuote.rate(se, l.tokens[j], l.rateProviders[j], manager);
                sharesOut = FullMath.mulDiv(FullMath.mulDiv(budget, 1e18, rate), 1e18, l.invScales[j]);
            }
            if (sharesOut >= _nativeAt(j)) revert Math.WouldZeroReserve();
            if (manager == address(0)) amountOut = sharesOut == 0 ? 0 : IStandardExchangeIn(se).previewExchangeIn(IERC20(se), sharesOut, IERC20(l.tokens[j]));
            else (amountOut,) = ContextQuote.redeem(se, l.tokens[j], address(this), sharesOut, manager);
        } else {
            amountOut = Math.descale(budget, l.ratedScales[j]);
            if (amountOut >= _nativeAt(j)) revert Math.WouldZeroReserve();
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
            else {
                if (l.rateProviders[i] == address(0)) revert RateProviderRequired();
                units = Math.ratedPairUnits(IERC20(se).balanceOf(address(this)), ContextQuote.rate(se, l.tokens[i], l.rateProviders[i], manager), l.invScales[i], l.ratedScales[i]);
            }
            rated[i] = Math.scaleTo(units, l.ratedScales[i]);
        }
    }

    function pairInWithContext(uint8 i, uint256 amount, address manager) public view returns (uint256) {
        Repo.Layout storage l = Repo._layout();
        address se = l.standardExchanges[i];
        (uint256 shares,) = ContextQuote.deposit(se, l.tokens[i], address(this), amount, manager);
        if (shares == 0) return 0;
        if (l.rateProviders[i] == address(0)) revert RateProviderRequired();
        return Math.scaleTo(Math.ratedPairUnits(shares, ContextQuote.rate(se, l.tokens[i], l.rateProviders[i], manager), l.invScales[i], l.ratedScales[i]), l.ratedScales[i]);
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
        if (se == address(0) || se == l.tokens[i] || !ContextQuote.supported(se)) {
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
            if (se != address(0) && se != l.tokens[j] && ContextQuote.supported(se)) {
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
        if (se == address(0) || se == l.tokens[j]) {
            if (amount >= _nativeAt(j)) revert Math.WouldZeroReserve();
            return _legacyOutputDebit(j, amount);
        }
        bytes memory state = ContextQuote.exactOutputState(se, l.tokens[j], manager);
        uint256 shares = ContextQuote.withdrawFromState(se, l.tokens[j], amount, state);
        if (shares == 0) revert IStandardExchangeOut.ExchangeOutNotAvailable();
        if (shares >= _nativeAt(j)) revert Math.WouldZeroReserve();
        if (!ContextQuote.supported(se)) return _legacyOutputDebit(j, amount);
        if (state.length == 0) return ratedWadForNativeUp(j, shares);
        uint256 wad = FullMath.mulDiv(shares, l.invScales[j], Math.RATE_PRECISION, FullMath.Rounding.Ceil);
        return FullMath.mulDiv(wad, ContextQuote.rateFromState(se, l.tokens[j], l.rateProviders[j], state), Math.RATE_PRECISION, FullMath.Rounding.Ceil);
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
        if (se == pairToken) return seAmount;
        return IStandardExchangeIn(se).previewExchangeIn(IERC20(se), seAmount, IERC20(pairToken));
    }

    /// @dev Preview shares minted when buffering `amountInRaw` pair tokens into SE.
    function previewBufferShares(address se, address pairToken, uint256 amountInRaw)
        external
        view
        returns (uint256 sharesOut)
    {
        if (amountInRaw == 0 || se == address(0)) return 0;
        if (se == pairToken) return amountInRaw;
        return IStandardExchangeIn(se).previewExchangeIn(IERC20(pairToken), amountInRaw, IERC20(se));
    }

    /// @dev Preview pair tokens from unwrapping `seAmount` shares.
    function previewUnwrap(address se, address pairToken, uint256 seAmount)
        external
        view
        returns (uint256 amountOut)
    {
        if (seAmount == 0 || se == address(0)) return 0;
        if (se == pairToken) return seAmount;
        return IStandardExchangeIn(se).previewExchangeIn(IERC20(se), seAmount, IERC20(pairToken));
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
        if (amountInRaw == 0) return 0;
        if (se == pairToken) return amountInRaw;
        uint256 minOut =
            IStandardExchangeIn(se).previewExchangeIn(IERC20(pairToken), amountInRaw, IERC20(se));
        if (minOut == 0) revert BufferFailed();
        IERC20(pairToken).forceApprove(se, amountInRaw);
        uint256 balBefore = IERC20(se).balanceOf(address(this));
        sharesOut = IStandardExchangeIn(se).exchangeIn(
            IERC20(pairToken),
            amountInRaw,
            IERC20(se),
            minOut,
            address(this),
            false,
            block.timestamp
        );
        // Prefer balance delta (covers fee-mint edge cases).
        IERC20(pairToken).forceApprove(se, 0);
        uint256 delta = IERC20(se).balanceOf(address(this)) - balBefore;
        if (delta > sharesOut) sharesOut = delta;
        if (sharesOut < minOut) revert BufferFailed();
    }

    /// @notice Unwrap SE shares to pair token for `to`.
    function unwrap(address se, address pairToken, uint256 seAmount, address to)
        external
        returns (uint256 amountOut)
    {
        if (seAmount == 0) return 0;
        if (se == pairToken) {
            if (to != address(this)) IERC20(se).safeTransfer(to, seAmount);
            return seAmount;
        }
        uint256 minOut =
            IStandardExchangeIn(se).previewExchangeIn(IERC20(se), seAmount, IERC20(pairToken));
        if (minOut == 0) revert UnwrapFailed();
        IERC20(se).forceApprove(se, seAmount);
        amountOut = IStandardExchangeIn(se).exchangeIn(
            IERC20(se), seAmount, IERC20(pairToken), minOut, to, false, block.timestamp
        );
        IERC20(se).forceApprove(se, 0);
        if (amountOut < minOut) revert UnwrapFailed();
    }

    /// @notice Unwrap exact pair-token out (burns SE shares as needed).
    function unwrapExactTokenOut(address se, address pairToken, uint256 amountOut, address to)
        external
        returns (uint256 seIn)
    {
        if (amountOut == 0) return 0;
        if (se == pairToken) {
            if (to != address(this)) IERC20(pairToken).safeTransfer(to, amountOut);
            return amountOut;
        }
        seIn = IStandardExchangeOut(se).previewExchangeOut(IERC20(se), IERC20(pairToken), amountOut);
        uint256 beforeBalance = IERC20(pairToken).balanceOf(address(this));
        IERC20(se).forceApprove(se, seIn);
        uint256 spent = IStandardExchangeOut(se).exchangeOut(
            IERC20(se), seIn, IERC20(pairToken), amountOut, address(this), false, block.timestamp
        );
        IERC20(se).forceApprove(se, 0);
        uint256 received = IERC20(pairToken).balanceOf(address(this)) - beforeBalance;
        if (spent > seIn || received < amountOut) revert UnwrapFailed();
        if (to != address(this)) IERC20(pairToken).safeTransfer(to, amountOut);
        uint256 surplus = received - amountOut;
        if (surplus != 0 && IStandardExchangeIn(se).previewExchangeIn(IERC20(pairToken), surplus, IERC20(se)) != 0) {
            buffer(se, pairToken, surplus);
        }
        return spent;
    }

    /// @dev Dilution-aware claim delta for buffering `amountInRaw` into SE (no RP).
    function previewBufferClaimIn(address se, address pairToken, uint256 amountInRaw, address hook)
        external
        view
        returns (uint256)
    {
        if (amountInRaw == 0 || se == address(0)) return 0;
        if (se == pairToken) return amountInRaw;
        uint256 sharesOut =
            IStandardExchangeIn(se).previewExchangeIn(IERC20(pairToken), amountInRaw, IERC20(se));
        if (sharesOut == 0) return 0;
        uint256 seBalBefore = IERC20(se).balanceOf(hook);
        uint256 claimBefore = seBalBefore == 0
            ? 0
            : IStandardExchangeIn(se).previewExchangeIn(IERC20(se), seBalBefore, IERC20(pairToken));
        uint256 claimAfter =
            IStandardExchangeIn(se).previewExchangeIn(IERC20(se), seBalBefore + sharesOut, IERC20(pairToken));
        return claimAfter > claimBefore ? claimAfter - claimBefore : 0;
    }
}
