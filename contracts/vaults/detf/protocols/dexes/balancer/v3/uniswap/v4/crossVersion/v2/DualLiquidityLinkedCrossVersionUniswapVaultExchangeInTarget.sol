// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeErrors} from "@crane/contracts/interfaces/IStandardExchangeErrors.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {BetterSafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {
    ReentrancyLockModifiers
} from "@crane/contracts/access/reentrancy/ReentrancyLockModifiers.sol";
import {
    DualLiquidityLinkedCrossVersionUniswapVaultRepo
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/uniswap/v4/crossVersion/v2/DualLiquidityLinkedCrossVersionUniswapVaultRepo.sol";
import {
    DualLiquidityLinkedCrossVersionUniswapVaultCommon
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/uniswap/v4/crossVersion/v2/DualLiquidityLinkedCrossVersionUniswapVaultCommon.sol";

/// @title DualLiquidityLinkedCrossVersionUniswapVaultExchangeInTarget
/// @notice Implements the deposit routes of `exchangeIn` where `tokenOut` is the vault share
///         token. Every share-minting route pays the usage fee (share inflation to feeTo).
/// @dev Deposit routes join first, then mint against the **actual** BPT received using a pre-join
///      supply/BPT snapshot so holders cannot be diluted by optimistic join quotes. Previews use
///      the same BasePoolMath path with WITH_RATE live↔raw conversion.
abstract contract DualLiquidityLinkedCrossVersionUniswapVaultExchangeInTarget is DualLiquidityLinkedCrossVersionUniswapVaultCommon, ReentrancyLockModifiers {
    using BetterSafeERC20 for IERC20;
    /* ---------------------------------------------------------------------- */
    /*                              Entry point                               */
    /* ---------------------------------------------------------------------- */

    /// @notice Deposits `tokenIn_` and mints vault shares to `recipient_` (tokenOut must be the
    ///         vault share token). Matches the `IStandardExchangeIn.exchangeIn` signature.
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

        TokenKind kindIn_ = _classify(tokenIn_);
        TokenKind kindOut_ = _classify(tokenOut_);
        // The initializing (bootstrap) deposit runs against an empty reserve and mints 1:1; every other
        // route requires a live reserve.
        if (!_isBootstrapDeposit(kindIn_, kindOut_)) {
            _requireReserveLive();
        }
        uint256[6] memory rest_ = _snapshotIntermediates();

        if (kindOut_ == TokenKind.Shares) {
            // Deposit route: mint vault shares.
            amountOut_ = _deposit(kindIn_, tokenIn_, amountIn_, recipient_, pretransferred_);
        } else if (kindIn_ == TokenKind.Shares) {
            // Redemption route: burn vault shares from the caller, pay out `tokenOut_`.
            amountOut_ = _redeem(kindOut_, tokenOut_, amountIn_, recipient_);
        } else {
            // Swap route: exchange between constituent tokens through the legs (no share change).
            _receive(tokenIn_, amountIn_, pretransferred_);
            amountOut_ = _swap(kindIn_, kindOut_, tokenIn_, tokenOut_, amountIn_, recipient_, deadline_);
        }

        if (amountOut_ < minAmountOut_) {
            revert IStandardExchangeErrors.MinAmountNotMet(minAmountOut_, amountOut_);
        }
        _sweepResidual(rest_);
    }

    /* ---------------------------------------------------------------------- */
    /*                          Deposit dispatch                              */
    /* ---------------------------------------------------------------------- */

    /// @dev Routes a share-minting deposit to the correct route helper. The reserve-BPT route
    ///      pulls its own input; all other routes receive `tokenIn_` first.
    function _deposit(TokenKind kindIn_, IERC20 tokenIn_, uint256 amountIn_, address recipient_, bool pretransferred_)
        private
        returns (uint256 amountOut_)
    {
        if (kindIn_ == TokenKind.ReserveBpt) {
            amountOut_ = _depositBpt(tokenIn_, amountIn_, recipient_, pretransferred_);
        } else if (
            kindIn_ == TokenKind.VaultAShare || kindIn_ == TokenKind.VaultBShare || kindIn_ == TokenKind.PairVaultShare
        ) {
            _receive(tokenIn_, amountIn_, pretransferred_);
            amountOut_ = _depositVaultShares(tokenIn_, amountIn_, recipient_);
        } else if (kindIn_ == TokenKind.TokenA || kindIn_ == TokenKind.TokenB) {
            _receive(tokenIn_, amountIn_, pretransferred_);
            amountOut_ = _depositLinkedToken(kindIn_, tokenIn_, amountIn_, recipient_);
        } else if (kindIn_ == TokenKind.CommonToken) {
            _receive(tokenIn_, amountIn_, pretransferred_);
            amountOut_ = _depositCommonToken(amountIn_, recipient_);
        } else {
            revert DualLiquidityLinkedCrossVersionUniswapVaultRepo.UnsupportedRoute(tokenIn_, IERC20(address(this)));
        }
    }

    /* ---------------------------------------------------------------------- */
    /*                          Route 1: reserve BPT                          */
    /* ---------------------------------------------------------------------- */

    /// @dev Direct BPT deposit. Shares are minted against the reserve total that still excludes
    ///      `amountIn_`, so the BPT must be pulled by this call (not pretransferred) to keep the
    ///      pre-mint snapshot valid.
    function _depositBpt(IERC20 bpt_, uint256 amountIn_, address recipient_, bool pretransferred_)
        private
        returns (uint256 userShares_)
    {
        if (pretransferred_) {
            revert DualLiquidityLinkedCrossVersionUniswapVaultRepo.UnsupportedRoute(bpt_, IERC20(address(this)));
        }
        userShares_ = _mintSharesForBpt(amountIn_, recipient_);
        bpt_.transferFrom(msg.sender, address(this), amountIn_);
    }

    /* ---------------------------------------------------------------------- */
    /*                        Route 2: leg vault shares                       */
    /* ---------------------------------------------------------------------- */

    /// @dev Join the pre-supplied vault-share token into the reserve, then mint against the
    ///      **actual** BPT received (pre-join snapshot) so quote/execution drift cannot dilute holders.
    function _depositVaultShares(IERC20 vaultShareToken_, uint256 amountIn_, address recipient_)
        private
        returns (uint256 userShares_)
    {
        uint256 supplyBefore_ = ERC20Repo._totalSupply();
        uint256 bptBefore_ = _totalReserveBpt();
        uint256 bptOut_ = _joinReserveFrom(vaultShareToken_, amountIn_);
        userShares_ = _mintSharesForActualBpt(bptOut_, recipient_, supplyBefore_, bptBefore_);
    }

    /* ---------------------------------------------------------------------- */
    /*                     Route 3: linked token (A or B)                     */
    /* ---------------------------------------------------------------------- */

    /// @dev Best-of two candidates: deposit the linked token into its own leg vault, OR into the
    ///      pair vault — whichever yields more BPT after the reserve join. Mints against actual BPT.
    function _depositLinkedToken(TokenKind kindIn_, IERC20 token_, uint256 amountIn_, address recipient_)
        private
        returns (uint256 userShares_)
    {
        DualLiquidityLinkedCrossVersionUniswapVaultRepo.Storage storage repo_ =
            DualLiquidityLinkedCrossVersionUniswapVaultRepo._layoutStruct();

        (IStandardExchangeProxy legVault_, IERC20 legShare_) =
            kindIn_ == TokenKind.TokenA ? (repo_.vaultA, repo_.vaultAShare) : (repo_.vaultB, repo_.vaultBShare);

        bool useLeg_ = _linkedPrefersLeg(legVault_, legShare_, token_, amountIn_, repo_);
        uint256 supplyBefore_ = ERC20Repo._totalSupply();
        uint256 bptBefore_ = _totalReserveBpt();
        uint256 bptOut_ = useLeg_
            ? _execLinkedViaLeg(legVault_, legShare_, token_, amountIn_)
            : _execLinkedViaPair(repo_, token_, amountIn_);
        userShares_ = _mintSharesForActualBpt(bptOut_, recipient_, supplyBefore_, bptBefore_);
    }

    function _linkedPrefersLeg(
        IStandardExchangeProxy legVault_,
        IERC20 legShare_,
        IERC20 token_,
        uint256 amountIn_,
        DualLiquidityLinkedCrossVersionUniswapVaultRepo.Storage storage repo_
    ) private view returns (bool) {
        uint256 legShareOut_ = legVault_.previewExchangeIn(token_, amountIn_, legShare_);
        uint256 legBpt_ = _quoteJoinReserve(legShare_, legShareOut_);
        uint256 pairShareOut_ = repo_.pairVault.previewExchangeIn(token_, amountIn_, repo_.pairVaultShare);
        uint256 pairBpt_ = _quoteJoinReserve(repo_.pairVaultShare, pairShareOut_);
        return legBpt_ >= pairBpt_;
    }

    function _execLinkedViaLeg(
        IStandardExchangeProxy legVault_,
        IERC20 legShare_,
        IERC20 token_,
        uint256 amountIn_
    ) private returns (uint256 bptOut_) {
        uint256 minShare_ = legVault_.previewExchangeIn(token_, amountIn_, legShare_);
        uint256 gotShare_ = _swapThrough(legVault_, token_, amountIn_, legShare_, minShare_);
        bptOut_ = _joinReserveFrom(legShare_, gotShare_);
    }

    function _execLinkedViaPair(
        DualLiquidityLinkedCrossVersionUniswapVaultRepo.Storage storage repo_,
        IERC20 token_,
        uint256 amountIn_
    ) private returns (uint256 bptOut_) {
        uint256 minShare_ = repo_.pairVault.previewExchangeIn(token_, amountIn_, repo_.pairVaultShare);
        uint256 gotShare_ = _swapThrough(repo_.pairVault, token_, amountIn_, repo_.pairVaultShare, minShare_);
        bptOut_ = _joinReserveFrom(repo_.pairVaultShare, gotShare_);
    }

    /* ---------------------------------------------------------------------- */
    /*                        Route 4: common token                           */
    /* ---------------------------------------------------------------------- */

    /// @dev Best-of two candidates: swap common -> tokenA -> pair share, OR common -> tokenB ->
    ///      pair share, then join. Mints against actual BPT from the join.
    function _depositCommonToken(uint256 amountIn_, address recipient_) private returns (uint256 userShares_) {
        DualLiquidityLinkedCrossVersionUniswapVaultRepo.Storage storage repo_ =
            DualLiquidityLinkedCrossVersionUniswapVaultRepo._layoutStruct();

        bool preferA_ = _commonPrefersA(repo_, amountIn_);
        uint256 supplyBefore_ = ERC20Repo._totalSupply();
        uint256 bptBefore_ = _totalReserveBpt();
        uint256 bptOut_ = preferA_
            ? _execCommonVia(repo_.vaultA, repo_.tokenA, amountIn_)
            : _execCommonVia(repo_.vaultB, repo_.tokenB, amountIn_);
        userShares_ = _mintSharesForActualBpt(bptOut_, recipient_, supplyBefore_, bptBefore_);
    }

    function _commonPrefersA(
        DualLiquidityLinkedCrossVersionUniswapVaultRepo.Storage storage repo_,
        uint256 amountIn_
    ) private view returns (bool) {
        (uint256 bptViaA_,,) = _quoteCommonCandidate(repo_.vaultA, repo_.tokenA, amountIn_);
        (uint256 bptViaB_,,) = _quoteCommonCandidate(repo_.vaultB, repo_.tokenB, amountIn_);
        return bptViaA_ >= bptViaB_;
    }

    function _execCommonVia(IStandardExchangeProxy legVault_, IERC20 linkedToken_, uint256 amountIn_)
        private
        returns (uint256 bptOut_)
    {
        (, uint256 linkedOut_, uint256 pairShareOut_) = _quoteCommonCandidate(legVault_, linkedToken_, amountIn_);
        bptOut_ = _executeCommonCandidate(legVault_, linkedToken_, amountIn_, linkedOut_, pairShareOut_);
    }

    /// @dev Quotes common -> linkedToken (via `legVault_`) -> pair share -> reserve BPT.
    function _quoteCommonCandidate(IStandardExchangeProxy legVault_, IERC20 linkedToken_, uint256 amountIn_)
        private
        view
        returns (uint256 bptOut_, uint256 linkedOut_, uint256 pairShareOut_)
    {
        DualLiquidityLinkedCrossVersionUniswapVaultRepo.Storage storage repo_ = DualLiquidityLinkedCrossVersionUniswapVaultRepo._layoutStruct();
        linkedOut_ = legVault_.previewExchangeIn(repo_.commonToken, amountIn_, linkedToken_);
        pairShareOut_ = repo_.pairVault.previewExchangeIn(linkedToken_, linkedOut_, repo_.pairVaultShare);
        bptOut_ = _quoteJoinReserve(repo_.pairVaultShare, pairShareOut_);
    }

    /// @dev Executes common -> linkedToken -> pair share -> reserve join for the chosen candidate.
    /// @return bptOut_ Actual BPT minted by the reserve join.
    function _executeCommonCandidate(
        IStandardExchangeProxy legVault_,
        IERC20 linkedToken_,
        uint256 amountIn_,
        uint256 linkedOut_,
        uint256 pairShareOut_
    ) private returns (uint256 bptOut_) {
        DualLiquidityLinkedCrossVersionUniswapVaultRepo.Storage storage repo_ = DualLiquidityLinkedCrossVersionUniswapVaultRepo._layoutStruct();
        uint256 gotLinked_ = _swapThrough(legVault_, repo_.commonToken, amountIn_, linkedToken_, linkedOut_);
        uint256 gotPairShare_ =
            _swapThrough(repo_.pairVault, linkedToken_, gotLinked_, repo_.pairVaultShare, pairShareOut_);
        bptOut_ = _joinReserveFrom(repo_.pairVaultShare, gotPairShare_);
    }

    /* ---------------------------------------------------------------------- */
    /*                              Swap dispatch                             */
    /* ---------------------------------------------------------------------- */

    /// @dev Routes a token↔token swap through the legs. No shares are minted or burned and no
    ///      DETF-level fee is charged; the swap aggregates over the leg vaults.
    function _swap(
        TokenKind kindIn_,
        TokenKind kindOut_,
        IERC20 tokenIn_,
        IERC20 tokenOut_,
        uint256 amountIn_,
        address recipient_,
        uint256 deadline_
    ) private returns (uint256 amountOut_) {
        bool linkedPair_ = (kindIn_ == TokenKind.TokenA && kindOut_ == TokenKind.TokenB)
            || (kindIn_ == TokenKind.TokenB && kindOut_ == TokenKind.TokenA);
        bool commonToLinked_ =
            kindIn_ == TokenKind.CommonToken && (kindOut_ == TokenKind.TokenA || kindOut_ == TokenKind.TokenB);
        bool linkedToCommon_ =
            (kindIn_ == TokenKind.TokenA || kindIn_ == TokenKind.TokenB) && kindOut_ == TokenKind.CommonToken;

        if (linkedPair_) {
            amountOut_ = _swapLinked(kindIn_, kindOut_, tokenIn_, tokenOut_, amountIn_, recipient_, deadline_);
        } else if (commonToLinked_ || linkedToCommon_) {
            amountOut_ = _swapViaLeg(kindIn_, kindOut_, tokenIn_, tokenOut_, amountIn_, recipient_, deadline_);
        } else {
            revert DualLiquidityLinkedCrossVersionUniswapVaultRepo.UnsupportedRoute(tokenIn_, tokenOut_);
        }
    }

    /// @dev tokenA↔tokenB: best of the direct pair-vault swap vs the two-hop route via the
    ///      common token through both leg vaults.
    function _swapLinked(
        TokenKind kindIn_,
        TokenKind, /* kindOut_ */
        IERC20 tokenIn_,
        IERC20 tokenOut_,
        uint256 amountIn_,
        address recipient_,
        uint256 deadline_
    ) private returns (uint256 amountOut_) {
        DualLiquidityLinkedCrossVersionUniswapVaultRepo.Storage storage repo_ = DualLiquidityLinkedCrossVersionUniswapVaultRepo._layoutStruct();
        (IStandardExchangeProxy vaultIn_, IStandardExchangeProxy vaultOut_) =
            kindIn_ == TokenKind.TokenA ? (repo_.vaultA, repo_.vaultB) : (repo_.vaultB, repo_.vaultA);

        uint256 directOut_ = repo_.pairVault.previewExchangeIn(tokenIn_, amountIn_, tokenOut_);

        uint256 midOut_ = vaultIn_.previewExchangeIn(tokenIn_, amountIn_, repo_.commonToken);
        uint256 hopOut_ = vaultOut_.previewExchangeIn(repo_.commonToken, midOut_, tokenOut_);

        if (directOut_ >= hopOut_) {
            amountOut_ =
                _legExchange(repo_.pairVault, tokenIn_, amountIn_, tokenOut_, directOut_, recipient_, deadline_);
        } else {
            uint256 gotCommon_ =
                _legExchange(vaultIn_, tokenIn_, amountIn_, repo_.commonToken, midOut_, address(this), deadline_);
            amountOut_ =
                _legExchange(vaultOut_, repo_.commonToken, gotCommon_, tokenOut_, hopOut_, recipient_, deadline_);
        }
    }

    /// @dev common↔linked single-hop swap through that linked token's leg vault.
    function _swapViaLeg(
        TokenKind kindIn_,
        TokenKind kindOut_,
        IERC20 tokenIn_,
        IERC20 tokenOut_,
        uint256 amountIn_,
        address recipient_,
        uint256 deadline_
    ) private returns (uint256 amountOut_) {
        DualLiquidityLinkedCrossVersionUniswapVaultRepo.Storage storage repo_ = DualLiquidityLinkedCrossVersionUniswapVaultRepo._layoutStruct();
        // The linked side of the swap selects the leg.
        TokenKind linkedKind_ = kindIn_ == TokenKind.CommonToken ? kindOut_ : kindIn_;
        IStandardExchangeProxy leg_ = linkedKind_ == TokenKind.TokenA ? repo_.vaultA : repo_.vaultB;

        uint256 quoted_ = leg_.previewExchangeIn(tokenIn_, amountIn_, tokenOut_);
        amountOut_ = _legExchange(leg_, tokenIn_, amountIn_, tokenOut_, quoted_, recipient_, deadline_);
    }

    /// @dev Approves and exchanges through a leg vault, delivering `tokenOut_` to `recipient_`.
    function _legExchange(
        IStandardExchangeProxy vault_,
        IERC20 tokenIn_,
        uint256 amountIn_,
        IERC20 tokenOut_,
        uint256 minOut_,
        address recipient_,
        uint256 deadline_
    ) private returns (uint256 amountOut_) {
        tokenIn_.approve(address(vault_), amountIn_);
        amountOut_ = vault_.exchangeIn(tokenIn_, amountIn_, tokenOut_, minOut_, recipient_, false, deadline_);
    }

    /* ---------------------------------------------------------------------- */
    /*                          Redemption dispatch                           */
    /* ---------------------------------------------------------------------- */

    /// @dev Burns the caller's shares and pays out `tokenOut_`.
    ///      - Reserve BPT: the canonical full-value exit.
    ///      - Vault share / linked token / common: proportional exit, pay the requested leg, then
    ///        redeposit the remaining legs into the reserve (accruing to remaining holders).
    function _redeem(TokenKind kindOut_, IERC20 tokenOut_, uint256 sharesIn_, address recipient_)
        private
        returns (uint256 amountOut_)
    {
        uint256 bptDue_ = _burnSharesForBpt(sharesIn_, msg.sender);

        if (kindOut_ == TokenKind.ReserveBpt) {
            DualLiquidityLinkedCrossVersionUniswapVaultRepo._layoutStruct().reserveBpt.transfer(recipient_, bptDue_);
            return bptDue_;
        }

        uint256[] memory amounts_ = _exitReserveProportional(bptDue_);

        if (
            kindOut_ == TokenKind.VaultAShare || kindOut_ == TokenKind.VaultBShare
                || kindOut_ == TokenKind.PairVaultShare
        ) {
            amountOut_ = _payVaultShare(kindOut_, amounts_, recipient_);
        } else if (kindOut_ == TokenKind.CommonToken || kindOut_ == TokenKind.TokenA || kindOut_ == TokenKind.TokenB) {
            amountOut_ = _payAsset(tokenOut_, amounts_, recipient_);
        } else {
            revert DualLiquidityLinkedCrossVersionUniswapVaultRepo.UnsupportedRoute(IERC20(address(this)), tokenOut_);
        }
    }

    /// @dev Vault-share payout: transfer the requested leg's exited amount, redeposit the other two
    ///      (batched so dust on a single leg cannot underflow Balancer single-token join math).
    function _payVaultShare(TokenKind kindOut_, uint256[] memory amounts_, address recipient_)
        private
        returns (uint256 amountOut_)
    {
        DualLiquidityLinkedCrossVersionUniswapVaultRepo.Storage storage repo_ = DualLiquidityLinkedCrossVersionUniswapVaultRepo._layoutStruct();
        uint256 payIndex_ = kindOut_ == TokenKind.VaultAShare ? 0 : (kindOut_ == TokenKind.VaultBShare ? 1 : 2);

        IERC20[3] memory shares_ = [repo_.vaultAShare, repo_.vaultBShare, repo_.pairVaultShare];
        amountOut_ = amounts_[payIndex_];
        shares_[payIndex_].transfer(recipient_, amountOut_);

        // Quote-then-join or refund remainder to the redeemer (never strand on Balancer vault).
        _redepositRemainder(amounts_, payIndex_, recipient_);
    }

    /// @dev Asset payout: redeem the max-return leg into `tokenOut_`, redeposit the other two legs.
    ///      Only legs whose underlyings include `tokenOut_` are quoted (mirrors preview eligibility).
    function _payAsset(IERC20 tokenOut_, uint256[] memory amounts_, address recipient_)
        private
        returns (uint256 amountOut_)
    {
        DualLiquidityLinkedCrossVersionUniswapVaultRepo.Storage storage repo_ = DualLiquidityLinkedCrossVersionUniswapVaultRepo._layoutStruct();
        IStandardExchangeProxy[3] memory vaults_ = [repo_.vaultA, repo_.vaultB, repo_.pairVault];
        IERC20[3] memory shares_ = [repo_.vaultAShare, repo_.vaultBShare, repo_.pairVaultShare];

        uint256 bestIndex_;
        uint256 bestOut_;
        bool found_;
        for (uint256 i = 0; i < 3; i++) {
            if (amounts_[i] == 0) continue;
            if (!_legCanRedeemTo(i, tokenOut_, repo_)) continue;
            // Eligible legs must quote; do not soft-skip — preview/execution must agree.
            uint256 q_ = vaults_[i].previewExchangeIn(shares_[i], amounts_[i], tokenOut_);
            if (!found_ || q_ > bestOut_) {
                bestOut_ = q_;
                bestIndex_ = i;
                found_ = true;
            }
        }
        if (!found_ || bestOut_ == 0) {
            revert DualLiquidityLinkedCrossVersionUniswapVaultRepo.UnsupportedRoute(IERC20(address(this)), tokenOut_);
        }

        amountOut_ = _legExchange(
            vaults_[bestIndex_],
            shares_[bestIndex_],
            amounts_[bestIndex_],
            tokenOut_,
            bestOut_,
            recipient_,
            block.timestamp
        );

        _redepositRemainder(amounts_, bestIndex_, recipient_);
    }

    /// @dev Whether leg `i` (0=A,1=B,2=pair) can redeem its vault shares into `tokenOut_`.
    ///      Restricts quoting to legs whose underlyings include `tokenOut_`, avoiding spurious
    ///      InvalidRoute / garbage quotes from unrelated vaults.
    function _legCanRedeemTo(
        uint256 i_,
        IERC20 tokenOut_,
        DualLiquidityLinkedCrossVersionUniswapVaultRepo.Storage storage repo_
    ) private view returns (bool) {
        address t = address(tokenOut_);
        if (i_ == 0) return t == address(repo_.commonToken) || t == address(repo_.tokenA);
        if (i_ == 1) return t == address(repo_.commonToken) || t == address(repo_.tokenB);
        // pair vault: tokenA / tokenB only
        return t == address(repo_.tokenA) || t == address(repo_.tokenB);
    }

    /* ---------------------------------------------------------------------- */
    /*                          Shared execution helpers                      */
    /* ---------------------------------------------------------------------- */

    /// @dev Pulls `amountIn_` of `tokenIn_` from the caller unless already pretransferred.
    function _receive(IERC20 tokenIn_, uint256 amountIn_, bool pretransferred_) private {
        if (!pretransferred_) {
            tokenIn_.transferFrom(msg.sender, address(this), amountIn_);
        }
    }

    /// @dev Deposit-path nested leg hop: routes output to this contract with a block-scoped deadline
    ///      (the caller's end-user deadline is already enforced by `_requireLive`).
    /// @dev Intermediate min is **0**, not the optimistic `previewExchangeIn` quote. Nested Uni V4/V2
    ///      share mints can undershoot preview by rounding (multi-hop rate/reserve updates); flooring
    ///      on exact preview reverts `UniswapV4ExchangeIn_SlippageExceeded` on otherwise valid paths
    ///      (e.g. tokenB → shares). End-user slippage is still enforced by DualLiquidity
    ///      `exchangeIn` `minAmountOut` on minted vault shares. Share mint uses **actual** BPT from
    ///      the join (`_mintSharesForActualBpt`), so a lower intermediate out does not dilute holders.
    function _swapThrough(
        IStandardExchangeProxy vault_,
        IERC20 tokenIn_,
        uint256 amountIn_,
        IERC20 tokenOut_,
        uint256 /* minOut_ (ignored; see NatSpec) */
    ) private returns (uint256 amountOut_) {
        amountOut_ = _legExchange(vault_, tokenIn_, amountIn_, tokenOut_, 0, address(this), block.timestamp);
    }

    /// @dev Adds `amount_` of `vaultShareToken_` into the reserve (pre-transfer + router settle; see `_joinReserve`).
    function _joinReserveFrom(IERC20 vaultShareToken_, uint256 amount_) private returns (uint256 bptOut_) {
        bptOut_ = _joinReserve(vaultShareToken_, amount_);
    }
}
