// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {Math} from "@crane/contracts/utils/Math.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {IStandardExchangeTransitionQuote} from "contracts/interfaces/IStandardExchangeTransitionQuote.sol";
import {AaveCrossVersionLoopExchangeBase} from "./AaveCrossVersionLoopExchangeBase.sol";
import {CrossVersionLoopExecutor} from "./CrossVersionLoopExecutor.sol";
import {CrossVersionLoopService} from "./CrossVersionLoopService.sol";
import {AaveV36Service} from "./AaveV36Service.sol";
import {AaveV4Service} from "./AaveV4Service.sol";

/**
 * @title AaveCrossVersionLoopStandardExchangeTransitionQuoteTarget
 * @author cyotee doge <doge.cyotee>
 * @notice Sequential, read-only transition quotes for the cross-version leverage-loop Standard Exchange
 *         (the loop diamond's own share is the SE share; the SE face/accounting asset is tokenA). Mirrors
 *         the loop's shared preview/execution math wei-for-wei, so a `quoteState` + `quoteTransition`
 *         chain equals the loop's actual `exchangeIn` / `exchangeOut` outcome (orbital's
 *         `test_row_previewMatchesExecution`).
 *
 * @dev D61: the loop is deliberately conservative. On an exact-input redemption it prices the share at
 *      NAV then caps at the tokenA a proportional unwind actually frees
 *      (`local + floor(phi*suppliedA) - ceil(phi*debtA)`); on an exact-output withdrawal it raises the
 *      share count so the floor/ceil unwind still frees the request. This projection reproduces those
 *      exact floor/ceil values from a snapshot of the projectable position — NOT a NAV price — so the
 *      preview equals the conservative amount execution actually delivers.
 *
 *      Threaded state carries the SE supply and holder share balance, the V3 tokenA collateral
 *      (`suppliedA`), the V4 tokenA debt (`debtA`), the locally retained tokenA (`localA`, D43), the
 *      tokenB USD leg of NAV (`navB`, unchanged by a tokenA-only deposit/loop), and the snapshot oracle
 *      price / token unit. NAV is recomputed from those legs each step, matching live `navUsd` exactly.
 *      Every transition threads the legs with the same rounding execution uses, so a subsequent
 *      transition or rate quote on the projected state stays wei-exact. The loop never charges a usage
 *      fee on a deposit, so `quoteTotalSupply` is the plain projected supply.
 */
abstract contract AaveCrossVersionLoopStandardExchangeTransitionQuoteTarget is
    AaveCrossVersionLoopExchangeBase, IStandardExchangeTransitionQuote
{
    struct LoopQuoteState {
        address exchange; // identity guard: the loop diamond that produced this snapshot
        address asset; // the SE face/accounting asset (tokenA)
        address holder;
        uint256 holderShares; // projected holder SE-share balance
        uint256 supply; // projected SE-share total supply
        uint256 suppliedA; // V3 tokenA collateral
        uint256 debtA; // V4 tokenA debt
        uint256 localA; // locally retained tokenA (D43)
        uint256 navB; // tokenB USD leg of NAV (oracle base), constant for a tokenA-only projection
        uint256 priceA; // snapshot V3 oracle price of tokenA
        uint256 unitA; // 10 ** tokenA decimals
    }

    /* ------------------------------- snapshot ------------------------------ */

    function quoteState(address asset, address holder)
        external view returns (bytes memory state, uint256 holderAssets)
    {
        CrossVersionLoopExecutor.Market memory m = _market();
        if (asset != address(m.tokenA)) revert UnsupportedQuoteAsset(asset);
        LoopQuoteState memory q = _snapshot(m, asset, holder);
        holderAssets = _quoteAssets(q, q.holderShares);
        state = abi.encode(q);
    }

    function _snapshot(CrossVersionLoopExecutor.Market memory m, address asset, address holder)
        private view returns (LoopQuoteState memory q)
    {
        q.exchange = address(this);
        q.asset = asset;
        q.holder = holder;
        q.holderShares = IERC20(address(this)).balanceOf(holder);
        q.supply = ERC20Repo._totalSupply();
        q.suppliedA = AaveV36Service.suppliedOf(m.v36Pool, address(m.tokenA), address(this));
        q.debtA = AaveV4Service.debtOf(m.v4Spoke, m.v4ReserveIdA, address(this));
        q.localA = CrossVersionLoopExecutor.localTokenA(m);
        q.priceA = m.v36Oracle.getAssetPrice(address(m.tokenA));
        q.unitA = 10 ** IERC20Metadata(address(m.tokenA)).decimals();
        // NAV tokenB leg = full navUsd minus the tokenA leg the projected fields reconstruct.
        uint256 navUsd_ = CrossVersionLoopExecutor.navUsd(m);
        uint256 navA_ = _toUsdA(q, _netTokenA(q));
        q.navB = navUsd_ > navA_ ? navUsd_ - navA_ : 0;
    }

    function _decode(bytes calldata state) private view returns (LoopQuoteState memory q) {
        q = abi.decode(state, (LoopQuoteState));
        if (q.exchange != address(this) || q.asset != address(_market().tokenA)) revert InvalidQuoteState();
    }

    /* --------------------------- projected NAV math ------------------------ */

    function _netTokenA(LoopQuoteState memory q) private pure returns (uint256) {
        uint256 netA = q.suppliedA > q.debtA ? q.suppliedA - q.debtA : 0;
        return netA + q.localA;
    }

    function _toUsdA(LoopQuoteState memory q, uint256 amountA) private pure returns (uint256) {
        return (amountA * q.priceA) / q.unitA;
    }

    /// @dev Live-equivalent NAV (oracle base): tokenA leg reconstructed from the projected position plus
    ///      the constant tokenB leg. Matches `CrossVersionLoopExecutor.navUsd` on the snapshot state.
    function _nav(LoopQuoteState memory q) private pure returns (uint256) {
        return _toUsdA(q, _netTokenA(q)) + q.navB;
    }

    /// @dev Projection of `AaveCrossVersionLoopExchangeBase._amountForShares` (exact-input redemption):
    ///      NAV price of the share, capped at what a proportional unwind actually frees.
    function _quoteAssets(LoopQuoteState memory q, uint256 shares) private pure returns (uint256 amount) {
        if (shares == 0 || q.supply == 0) return 0;
        uint256 nav_ = _nav(q);
        uint256 value_ = Math.mulDiv(shares, nav_, q.supply);
        amount = q.priceA == 0 ? 0 : Math.mulDiv(value_, q.unitA, q.priceA);
        if (shares <= q.supply) {
            uint256 deliverable_ = q.localA + _freeableA(q, shares);
            if (deliverable_ < amount) amount = deliverable_;
        }
    }

    /// @dev Projection of `CrossVersionLoopExecutor.proportionalFreeableA`: floor(phi*suppliedA) - ceil(phi*debtA).
    function _freeableA(LoopQuoteState memory q, uint256 shares) private pure returns (uint256) {
        if (shares == 0 || q.supply == 0) return 0;
        uint256 wA = Math.mulDiv(q.suppliedA, shares, q.supply);
        uint256 rA = Math.mulDiv(q.debtA, shares, q.supply, Math.Rounding.Ceil);
        return wA > rA ? wA - rA : 0;
    }

    /// @dev Projection of `AaveCrossVersionLoopExchangeBase._sharesForAmountOut` (exact-output withdrawal):
    ///      NAV-priced ceil share count, bumped to the net-tokenA basis so the floor/ceil unwind frees the
    ///      request.
    function _sharesForAmount(LoopQuoteState memory q, uint256 amount) private pure returns (uint256 shares) {
        if (amount == 0) return 0;
        uint256 nav_ = _nav(q);
        if (nav_ == 0 || q.supply == 0) revert EmptyLoopNAV();
        uint256 value_ = Math.mulDiv(amount, q.priceA, q.unitA, Math.Rounding.Ceil);
        shares = Math.mulDiv(value_, q.supply, nav_, Math.Rounding.Ceil);
        if (q.localA < amount) {
            uint256 need_ = amount - q.localA;
            uint256 net_ = q.suppliedA > q.debtA ? q.suppliedA - q.debtA : 0;
            if (net_ > 0) {
                uint256 bumped_ = Math.mulDiv(need_ + 2, q.supply, net_, Math.Rounding.Ceil);
                if (bumped_ > shares) shares = bumped_;
            }
        }
        if (shares == 0) shares = 1;
    }

    /* -------------------------- position threading -------------------------- */

    /// @dev Thread a proportional unwind of `shares` (redeem or exact-out withdraw), paying `paid` tokenA.
    ///      Withdraws floor(phi*suppliedA) collateral, repays ceil(phi*debtA) debt, and the net freed
    ///      tokenA above `paid` is retained locally — the same rounding `proportionalUnwind` uses, so the
    ///      net tokenA leg drops by exactly `paid`.
    function _unwind(LoopQuoteState memory q, uint256 shares, uint256 paid) private pure {
        uint256 wA = Math.mulDiv(q.suppliedA, shares, q.supply);
        uint256 rA = Math.mulDiv(q.debtA, shares, q.supply, Math.Rounding.Ceil);
        q.suppliedA -= wA;
        q.debtA -= rA;
        uint256 freed_ = wA > rA ? wA - rA : 0; // net tokenA released to the raw balance
        q.localA = q.localA + freed_ - paid; // guaranteed >= 0: paid <= localA + freed_
        q.supply -= shares;
        q.holderShares -= shares;
    }

    /* ----------------------------- transitions ----------------------------- */

    function quoteTransition(bytes calldata state, Operation operation, uint256 amount)
        external view returns (bytes memory nextState, uint256 amountIn, uint256 amountOut, uint256 holderAssetsAfter)
    {
        LoopQuoteState memory q = _decode(state);
        if (operation == Operation.ReceiveShares) {
            q.holderShares += amount;
            if (q.holderShares > q.supply) revert InvalidQuoteState();
            amountIn = amount;
            amountOut = amount;
        } else if (operation == Operation.DepositExactIn) {
            amountIn = amount;
            amountOut = _applyDeposit(q, amount);
        } else if (operation == Operation.RedeemExactIn) {
            amountIn = amount;
            if (amount > q.holderShares) revert InsufficientQuoteShares(amount, q.holderShares);
            amountOut = _quoteAssets(q, amount);
            _unwind(q, amount, amountOut);
        } else {
            // WithdrawExactOut: `amount` is the exact tokenA paid to the holder.
            amountOut = amount;
            amountIn = _sharesForAmount(q, amount);
            if (amountIn > q.holderShares) revert InsufficientQuoteShares(amountIn, q.holderShares);
            _unwind(q, amountIn, amount);
        }
        holderAssetsAfter = _quoteAssets(q, q.holderShares);
        nextState = abi.encode(q);
    }

    /// @dev Projection of the exchangeIn tokenA deposit: mint `floor(valueUsd(amount) * supply / nav)`
    ///      from the pre-deposit NAV/supply, then thread the tokenA leg up by `amount` (booked into the
    ///      collateral field: the individual leverage split is never re-read after a deposit, and the net
    ///      tokenA leg — all a later rate quote reads — is exact). First deposit locks MINIMUM_LIQUIDITY.
    function _applyDeposit(LoopQuoteState memory q, uint256 amount) private pure returns (uint256 minted) {
        uint256 value_ = _toUsdA(q, amount);
        minted = CrossVersionLoopService.sharesForDeposit(_nav(q), q.supply, value_);
        if (q.supply == 0) {
            minted = minted > MINIMUM_LIQUIDITY ? minted - MINIMUM_LIQUIDITY : 0;
            q.supply += minted + (minted > 0 ? MINIMUM_LIQUIDITY : 0);
        } else {
            q.supply += minted;
        }
        q.holderShares += minted;
        q.suppliedA += amount; // net tokenA leg grows by exactly the deposit
    }

    /* ------------------------------- readers ------------------------------- */

    function quoteAssets(bytes calldata state, uint256 shares) external view returns (uint256 assets) {
        return _quoteAssets(_decode(state), shares);
    }

    function quoteShareBalance(bytes calldata state) external view returns (uint256 shares) {
        return _decode(state).holderShares;
    }

    function quoteTotalSupply(bytes calldata state) external view returns (uint256 shares) {
        return _decode(state).supply;
    }
}
