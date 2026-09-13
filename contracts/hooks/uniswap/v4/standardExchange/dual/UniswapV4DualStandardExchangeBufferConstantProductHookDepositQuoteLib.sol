// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
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
    }

    function preview(address tokenIn, uint256 amountIn) external view returns (bool supported, uint256 shares) {
        Leg memory input;
        Leg memory output;
        bool zeroForOne;
        {
            Repo.Layout storage l = Repo._layout();
            address pairIn = l.legs.pairOfStandardExchange[tokenIn];
            bool shareInput = pairIn != address(0);
            if (!shareInput) pairIn = tokenIn;
            zeroForOne = pairIn == l.currency0;
            address pairOut = zeroForOne ? l.currency1 : l.currency0;
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
        uint256 supply = _supplyAfterFee(input, output);
        (uint256 kept, uint256 other) = _swap(input, output, amountIn);
        if (zeroForOne) {
            uint256 idealOther = kept * output.claim / input.claim;
            if (idealOther <= other) other = idealOther;
            else kept = other * input.claim / output.claim;
        } else {
            uint256 idealIn = other * input.claim / output.claim;
            if (idealIn <= kept) kept = idealIn;
            else other = kept * output.claim / input.claim;
        }
        if (kept == 0 || other == 0) return (true, 0);
        uint256 beforeIn = input.claim;
        uint256 beforeOut = output.claim;
        // Each state carries the SE's own fee dilution and downstream pool changes.
        // The two SE books are distinct; deposits use their post-swap states.
        _transition(input, Transition.Operation.DepositExactIn, kept);
        _transition(output, Transition.Operation.DepositExactIn, other);
        shares = Math.mintSharesLater(
            Math.toWad(input.claim - beforeIn, input.decimals),
            Math.toWad(output.claim - beforeOut, output.decimals),
            Math.toWad(beforeIn, input.decimals), Math.toWad(beforeOut, output.decimals), supply
        );
        return (true, shares);
    }

    function _load(address se, address pair) private view returns (Leg memory leg) {
        Repo.Layout storage l = Repo._layout();
        leg.se = se;
        leg.decimals = pair == l.currency0 ? l.decimalsCurrency0 : l.decimalsCurrency1;
        (leg.state, leg.claim) = Transition(se).quoteState(pair, address(this));
        _floorClaim(leg);
    }

    function _floorClaim(Leg memory leg) private view {
        if (leg.claim == 0 && Transition(leg.se).quoteShareBalance(leg.state) > 0) leg.claim = 1;
    }

    function _transition(Leg memory leg, Transition.Operation operation, uint256 amount)
        private view returns (uint256 out)
    {
        (leg.state,, out, leg.claim) = Transition(leg.se).quoteTransition(leg.state, operation, amount);
        _floorClaim(leg);
    }

    function _swap(Leg memory input, Leg memory output, uint256 amountIn)
        private view returns (uint256 kept, uint256 other)
    {
        uint256 beforeIn = input.claim;
        uint256 sale = Math.fromWadFloor(
            Math.swapDepositSaleAmt(Math.toWad(amountIn, input.decimals), Math.toWad(beforeIn, input.decimals)),
            input.decimals
        );
        if (sale > amountIn) sale = amountIn;
        if (sale == 0) sale = amountIn / 2;
        _transition(input, Transition.Operation.DepositExactIn, sale);
        other = Math.fromWadFloor(Math.saleQuote(
            Math.toWad(input.claim - beforeIn, input.decimals),
            Math.toWad(beforeIn, input.decimals), Math.toWad(output.claim, output.decimals)
        ), output.decimals);
        _transition(output, Transition.Operation.WithdrawExactOut, other);
        return (amountIn - sale, other);
    }

    function _supplyAfterFee(Leg memory input, Leg memory output) private view returns (uint256 supply) {
        Repo.Layout storage l = Repo._layout();
        supply = ERC20Repo._totalSupply();
        (IFeeCollectorProxy feeTo, uint256 fee) = IVaultFeeOracleQuery(l.feeOracle).dexSwapFeeAndFeeToOfVault(address(this));
        if (address(feeTo) != address(0) && fee != 0 && l.kLast != 0 && supply != 0) {
            supply += Math.calculateProtocolFee(
                supply, Math.toWad(input.claim, input.decimals) * Math.toWad(output.claim, output.decimals),
                l.kLast, fee * Repo.TRADING_FEE_DENOMINATOR / 1e18
            );
        }
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
        if (tokenIn == l.currency0) {
            p.x += claimInDelta;
            p.y = p.y > p.amountOtherOut ? p.y - p.amountOtherOut : 0;
        } else {
            p.y += claimInDelta;
            p.x = p.x > p.amountOtherOut ? p.x - p.amountOtherOut : 0;
        }
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
        return Math.mintSharesLater(
            Math.toWad(
                _previewBufferClaimIn(_seFor(l.currency0), l.currency0, p.used0),
                Repo._layout().decimalsCurrency0
            ),
            Math.toWad(
                _previewBufferClaimIn(_seFor(l.currency1), l.currency1, p.used1),
                Repo._layout().decimalsCurrency1
            ),
            Math.toWad(p.x, Repo._layout().decimalsCurrency0),
            Math.toWad(p.y, Repo._layout().decimalsCurrency1),
            supply
        );
    }



    function _seFor(address pair) private view returns (address) {
        return Repo._layout().legs.standardExchangeOf[pair];
    }

    function _previewBufferClaimIn(address se, address pair, uint256 amount) private view returns (uint256) {
        return ClaimLib.previewBufferClaimIn(se, pair, amount, IVaultFeeOracleQuery(Repo._layout().feeOracle), address(this));
    }

}
