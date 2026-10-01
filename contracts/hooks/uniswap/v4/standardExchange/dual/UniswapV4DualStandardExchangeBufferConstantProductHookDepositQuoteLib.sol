// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IFeeCollectorProxy} from "contracts/interfaces/proxies/IFeeCollectorProxy.sol";
import {IStandardExchangeTransitionQuote as Transition} from "contracts/interfaces/IStandardExchangeTransitionQuote.sol";
import {UniswapV4DualStandardExchangeBufferConstantProductHookRepo as Repo} from "./UniswapV4DualStandardExchangeBufferConstantProductHookRepo.sol";
import {UniswapV4DualStandardExchangeBufferConstantProductHookMath as Math} from "./UniswapV4DualStandardExchangeBufferConstantProductHookMath.sol";
import {UniswapV4DualStandardExchangeBufferConstantProductHookClaimLib as ClaimLib} from "./UniswapV4DualStandardExchangeBufferConstantProductHookClaimLib.sol";

import {IUniswapV4DualStandardExchangeBufferConstantProductHook as IHook} from "./interfaces/IUniswapV4DualStandardExchangeBufferConstantProductHook.sol";

/// @notice Projects both SE inventories through the same unwrap, swap, and join sequence as execution.
library UniswapV4DualStandardExchangeBufferConstantProductHookDepositQuoteLib {
    struct Leg {
        address se;
        uint8 decimals;
        bytes state;
        uint256 claim;
        /// @dev D59: the holder's projected SE share balance; issuance follows it.
        uint256 shares;
    }

    function preview(address tokenIn, uint256 amountIn) external view returns (bool supported, uint256 shares) {
        Leg memory input;
        Leg memory output;
        bool zeroForOne;
        address pairIn;
        address pairOut;
        {
            Repo.Layout storage l = Repo._layout();
            pairIn = l.legs.pairOfStandardExchange[tokenIn];
            bool shareInput = pairIn != address(0);
            if (!shareInput) pairIn = tokenIn;
            zeroForOne = pairIn == l.currency0;
            pairOut = zeroForOne ? l.currency1 : l.currency0;
            address seIn = l.legs.standardExchangeOf[pairIn];
            address seOut = l.legs.standardExchangeOf[pairOut];
            if (!ClaimLib.supportsTransitionQuote(seIn, pairIn, address(this))
                || !ClaimLib.supportsTransitionQuote(seOut, pairOut, address(this))) return (false, 0);
            input = _load(seIn, pairIn);
            output = _load(seOut, pairOut);
            if (shareInput) {
                _transition(input, Transition.Operation.ReceiveShares, amountIn);
                amountIn = _transition(input, Transition.Operation.RedeemExactIn, amountIn);
            }
        }
        Issuance memory v;
        v.supply = _supplyAfterFee(input, output);
        (uint256 kept, uint256 other) = _swap(input, output, pairIn, amountIn);
        // F9: clamp on the post-zap rated reserves, matching execution's `_clampToClaimRatio`
        // (`claimSupplyCurrency0/1` after the zap swap buffered/unwrapped the two legs).
        uint256 rIn = ClaimLib.ratedReserveOfState(input.se, input.state);
        uint256 rOut = ClaimLib.ratedReserveOfState(output.se, output.state);
        if (zeroForOne) {
            uint256 idealOther = kept * rOut / rIn;
            if (idealOther <= other) other = idealOther;
            else kept = other * rIn / rOut;
        } else {
            uint256 idealIn = other * rIn / rOut;
            if (idealIn <= kept) kept = idealIn;
            else other = kept * rOut / rIn;
        }
        if (kept == 0 || other == 0) return (true, 0);
        // D59: issuance follows the raw share book of the projected states: each leg's projected share
        // balance after the zap swap and the shares each intake mints, all from the SE's own sequential
        // projection (a later step in the same state sees the earlier step's fee and pool changes).
        shares = _issue(input, output, kept, other, v.supply);
        return (true, shares);
    }

    /// @dev Stack-safe issuance frame: each leg mints from its projected post-zap share book.
    function _issue(Leg memory input, Leg memory output, uint256 kept, uint256 other, uint256 supply)
        private view returns (uint256 shares)
    {
        uint256 beforeIn = input.shares;
        uint256 beforeOut = output.shares;
        uint256 mintedIn = _transition(input, Transition.Operation.DepositExactIn, kept);
        uint256 mintedOut = _transition(output, Transition.Operation.DepositExactIn, other);
        shares = Math.mintSharesLater(mintedIn, mintedOut, beforeIn, beforeOut, supply);
    }

    /// @dev LP for the post-zap proportional intake from the raw share book: the input leg holds its
    ///      pre-zap shares plus the sale buffer's mint, the output leg its pre-zap shares minus the exact-out
    ///      burn; the intake mints `kept` and `other` through the SE's live previews.
    /// @dev Stack-safe frame for the projected issuance.
    struct Issuance {
        uint256 supply;
    }


    function _load(address se, address pair) private view returns (Leg memory leg) {
        Repo.Layout storage l = Repo._layout();
        leg.se = se;
        leg.decimals = pair == l.currency0 ? l.decimalsCurrency0 : l.decimalsCurrency1;
        (leg.state, leg.claim) = Transition(se).quoteState(pair, address(this));
        leg.shares = Transition(se).quoteShareBalance(leg.state);
        _floorClaim(leg);
    }

    function _floorClaim(Leg memory leg) private view {
        if (leg.claim == 0 && Transition(leg.se).quoteShareBalance(leg.state) > 0) leg.claim = 1;
    }

    function _transition(Leg memory leg, Transition.Operation operation, uint256 amount)
        private view returns (uint256 out)
    {
        (leg.state,, out, leg.claim) = Transition(leg.se).quoteTransition(leg.state, operation, amount);
        leg.shares = Transition(leg.se).quoteShareBalance(leg.state);
        _floorClaim(leg);
    }

    /// @dev F9/D62: size the zap off the same rated book execution uses (`Common._computeSaleAmt` /
    ///      `_quoteExactInAmountOut`), read from the PROJECTED leg states — never the live SE balance. For a
    ///      share input, execution unwraps the input SE before it sizes anything (`joinSingleAssetExactIn`);
    ///      that redeem moves the input leg's rated book, so `input.state` here (post ReceiveShares +
    ///      RedeemExactIn) is the book execution actually reads, and the live `ratedReserve` is the stale
    ///      pre-unwrap book. For a pair input `input.state`/`output.state` equal the live states, so the
    ///      pair route is unchanged. Sale, buffer claim-in and the CP `other` quote all read the same
    ///      pre-buffer projected book execution reads ⇒ preview == execution to the wei.
    function _swap(Leg memory input, Leg memory output, address pairIn, uint256 amountIn)
        private view returns (uint256 kept, uint256 other)
    {
        // Split into helpers so the no-via-ir stack stays under the 16-slot limit (D62/F9).
        uint256 sale = _saleAmount(input, amountIn);
        uint256 claimIn = ClaimLib.projectedBufferClaimIn(input.se, input.state, sale);
        uint256 budget = _otherFromClaim(input, output, claimIn);
        ClaimLib.OutputQuote memory quote;
        bytes memory nextOutput;
        (quote, nextOutput) = ClaimLib.projectOutputExactIn(output.se, output.state, budget);
        _transition(input, Transition.Operation.DepositExactIn, sale);
        output.state = nextOutput;
        output.shares = Transition(output.se).quoteShareBalance(nextOutput);
        output.claim = ClaimLib.ratedReserveOfState(output.se, nextOutput);
        other = quote.amount;
        return (amountIn - sale, other);
    }

    /// @dev Sale amount off the input leg's PROJECTED rated reserve, matching execution's `_computeSaleAmt`
    ///      on the post-unwrap book.
    function _saleAmount(Leg memory input, uint256 amountIn) private view returns (uint256 sale) {
        uint256 ratedIn = ClaimLib.ratedReserveOfState(input.se, input.state);
        sale = Math.fromWadFloor(
            Math.swapDepositSaleAmt(Math.toWad(amountIn, input.decimals), Math.toWad(ratedIn, input.decimals)),
            input.decimals
        );
        if (sale > amountIn) sale = amountIn;
        if (sale == 0) sale = amountIn / 2;
    }

    /// @dev Other-leg output from the claim-in, via the rated CP quote (`_quoteExactInAmountOut`), read from
    ///      the projected leg states execution quotes against (post-unwrap input, pre-swap output).
    function _otherFromClaim(Leg memory input, Leg memory output, uint256 claimIn)
        private view returns (uint256)
    {
        uint256 ratedIn = ClaimLib.ratedReserveOfState(input.se, input.state);
        uint256 ratedOut = ClaimLib.ratedReserveOfState(output.se, output.state);
        return Math.fromWadFloor(Math.saleQuote(
            Math.toWad(claimIn, input.decimals),
            Math.toWad(ratedIn, input.decimals), Math.toWad(ratedOut, output.decimals)
        ), output.decimals);
    }

    function _supplyAfterFee(Leg memory input, Leg memory output) private view returns (uint256 supply) {
        Repo.Layout storage l = Repo._layout();
        supply = ERC20Repo._totalSupply();
        (IFeeCollectorProxy feeTo, uint256 fee) = IVaultFeeOracleQuery(l.feeOracle).dexSwapFeeAndFeeToOfVault(address(this));
        if (address(feeTo) != address(0) && fee != 0 && l.kLast != 0 && supply != 0) {
            // D60: execution mints the protocol-fee LP from the rated book (`_wadProduct`, provider rates),
            // not from the SE's holder-asset claims; project it from the same book so previews agree to the wei.
            uint256 k = Math.toWad(IHook(address(this)).claimSupplyCurrency0(), l.decimalsCurrency0)
                * Math.toWad(IHook(address(this)).claimSupplyCurrency1(), l.decimalsCurrency1);
            supply += Math.calculateProtocolFee(supply, k, l.kLast, fee * Repo.TRADING_FEE_DENOMINATOR / 1e18);
        }
        input; output;
    }
    /// @dev Stack-safe intermediate for single-asset deposit preview.
    struct DepositSinglePreview {
        uint256 amountToSwap;
        uint256 amountOtherOut;
        uint256 amountKeptIn;
        uint256 x;
        uint256 y;
        uint256 used0;
        uint256 used1;
        /// @dev D59: raw share reserves after the zap swap.
        uint256 xs;
        uint256 ys;
    }

    /// @dev Retains the legacy quote for SEs without sequential quote support.
    function previewLegacy(address tokenIn, uint256 amountIn, uint256 supply) external view returns (uint256) {
        DepositSinglePreview memory p;
        (p.amountToSwap, p.amountOtherOut, p.amountKeptIn) = IHook(address(this)).previewZapSplit(tokenIn, amountIn);
        _applyZapToClaimsPreview(tokenIn, p);
        if (p.x == 0 || p.y == 0) return 0;
        _clampSingleDepositAdds(tokenIn, p);
        if (p.used0 == 0 || p.used1 == 0) return 0;
        return _mintSharesFromUsedPreview(p, supply);
    }


    function _applyZapToClaimsPreview(address tokenIn, DepositSinglePreview memory p) private view {
        Repo.Layout storage l = Repo._layout();
        uint256 claimInDelta =
            _previewBufferClaimIn(_seFor(tokenIn), tokenIn, p.amountToSwap);
        p.x = IHook(address(this)).claimSupplyCurrency0();
        p.y = IHook(address(this)).claimSupplyCurrency1();
        p.xs = IERC20(_seFor(l.currency0)).balanceOf(address(this));
        p.ys = IERC20(_seFor(l.currency1)).balanceOf(address(this));
        address tokenOut = tokenIn == l.currency0 ? l.currency1 : l.currency0;
        uint256 sharesIn = _previewRawShares(_seFor(tokenIn), tokenIn, p.amountToSwap);
        uint256 budget = Math.fromWadFloor(Math.saleQuote(Math.toWad(claimInDelta, _decimalsOfToken(tokenIn)),
            Math.toWad(tokenIn == l.currency0 ? p.x : p.y, _decimalsOfToken(tokenIn)),
            Math.toWad(tokenIn == l.currency0 ? p.y : p.x, _decimalsOfToken(tokenOut))), _decimalsOfToken(tokenOut));
        ClaimLib.OutputQuote memory output = ClaimLib.previewOutputExactIn(_seFor(tokenOut), budget);
        uint256 sharesOut = output.shares;
        if (tokenIn == l.currency0) {
            p.x += claimInDelta;
            p.xs += sharesIn;
            p.ys -= sharesOut;
            p.y = ClaimLib.ratedOf(_seFor(tokenOut), p.ys);
        } else {
            p.y += claimInDelta;
            p.ys += sharesIn;
            p.xs -= sharesOut;
            p.x = ClaimLib.ratedOf(_seFor(tokenOut), p.xs);
        }
    }

    function _previewRawShares(address se, address pair, uint256 amount) private view returns (uint256) {
        if (amount == 0) return 0;
        if (se == pair) return amount;
        return IStandardExchangeIn(se).previewExchangeIn(IERC20(pair), amount, IERC20(se));
    }

    function _decimalsOfToken(address token) private view returns (uint8) {
        Repo.Layout storage l = Repo._layout();
        return token == l.currency0 ? l.decimalsCurrency0 : l.decimalsCurrency1;
    }


    function _clampSingleDepositAdds(address tokenIn, DepositSinglePreview memory p) private view {
        Repo.Layout storage l = Repo._layout();
        uint256 add0 = tokenIn == l.currency0 ? p.amountKeptIn : p.amountOtherOut;
        uint256 add1 = tokenIn == l.currency0 ? p.amountOtherOut : p.amountKeptIn;
        p.used0 = add0;
        p.used1 = add1;
        uint256 ideal1 = (p.used0 * p.y) / p.x;
        if (ideal1 <= p.used1) p.used1 = ideal1;
        else p.used0 = (p.used1 * p.x) / p.y;
    }


    function _mintSharesFromUsedPreview(DepositSinglePreview memory p, uint256 supply)
        private
        view
        returns (uint256)
    {
        Repo.Layout storage l = Repo._layout();
        // D59: issuance follows the raw share book after the zap swap.
        return Math.mintSharesLater(
            _previewRawShares(_seFor(l.currency0), l.currency0, p.used0),
            _previewRawShares(_seFor(l.currency1), l.currency1, p.used1),
            p.xs, p.ys, supply
        );
    }



    function _seFor(address pair) private view returns (address) {
        return Repo._layout().legs.standardExchangeOf[pair];
    }

    function _previewBufferClaimIn(address se, address pair, uint256 amount) private view returns (uint256) {
        return ClaimLib.previewBufferClaimIn(se, pair, amount);
    }

}
