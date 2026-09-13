// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {BetterSafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {Math} from "@crane/contracts/utils/Math.sol";
import {IStablePool, StablePoolDynamicData} from "@crane/contracts/external/balancer/v3/interfaces/contracts/pool-stable/IStablePool.sol";
import {IWeightedPool, WeightedPoolDynamicData} from "@crane/contracts/external/balancer/v3/interfaces/contracts/pool-weighted/IWeightedPool.sol";
import {IVault} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IVault.sol";
import {BalancerV3VaultAwareRepo} from "@crane/contracts/protocols/dexes/balancer/v3/vault/BalancerV3VaultAwareRepo.sol";
import {BalancerV3WeightedPoolQuote} from "@crane/contracts/protocols/dexes/balancer/v3/utils/BalancerV3WeightedPoolQuote.sol";
import {IDetfErrors} from "contracts/interfaces/IDetfErrors.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {IStandardExchangeErrors} from "contracts/interfaces/IStandardExchangeErrors.sol";
import {IStandardExchangeIn} from "contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "contracts/interfaces/IStandardExchangeOut.sol";
import {IStakedDETF} from "contracts/interfaces/IStakedDETF.sol";
import {IDetfBondNFT} from "contracts/interfaces/IDetfBondNFT.sol";
import {BondTerms} from "contracts/interfaces/VaultFeeTypes.sol";
import {MultiAssetBasicVaultRepo} from "contracts/vaults/basic/MultiAssetBasicVaultRepo.sol";
import {DETFMintSplitLib} from "contracts/vaults/detf/common/core/DETFMintSplitLib.sol";
import {DETFNaturalExpansionLib} from "contracts/vaults/detf/common/core/DETFNaturalExpansionLib.sol";
import {DETFBondNFTMathLib} from "contracts/vaults/detf/common/core/DETFBondNFTMathLib.sol";
import {DETFBalancerReserveSwapTarget} from "contracts/vaults/detf/protocols/dexes/balancer/v3/common/DETFBalancerReserveSwapTarget.sol";
import {ComposedStableCommonDetfRepo as Repo, ComposedStableCommonDetfRepo} from "./ComposedStableCommonDetfRepo.sol";
abstract contract ComposedStableCommonDetfCommon is IStandardExchangeErrors, IDetfErrors, DETFBalancerReserveSwapTarget {
    using BetterSafeERC20 for IERC20;
    using ComposedStableCommonDetfRepo for ComposedStableCommonDetfRepo.Storage;
    uint256 internal constant ONE_WAD = 1e18;
    uint256 internal constant RESERVE_TOKEN_COUNT = 3;
    event NaturalSupplyExpanded(uint256 mintAmount, uint256 syntheticPrice, uint256 newTimestamp);
    struct ReservePoolQuoteContext {
        WeightedPoolDynamicData dynamicData;
        uint256[] weights;
        uint256 tokenInIndex;
        uint256 tokenOutIndex;
    }

    struct RoutedPoolSelection {
        uint256 routeIndex;
        bool depositToStablePool;
        IERC20 poolBptToken;
        IStandardExchangeIn poolRouter;
    }

    struct UnwindPreviewSelection {
        uint256 routeIndex;
        bool exitFromStablePool;
        IERC20 poolBptToken;
        uint256 vaultTokenAmountOut;
        uint256 poolBptAmountOut;
        uint256 detfAmountIn;
    }

    struct ExactInUnwindSelection {
        uint256 routeIndex;
        bool exitFromStablePool;
        IERC20 poolBptToken;
        uint256 poolBptAmountOut;
        uint256 vaultTokenAmountOut;
        uint256 tokenOutAmountOut;
    }

    struct ExactOutSelectionState {
        uint256 bestLiquidity;
        bool foundPath;
        UnwindPreviewSelection selection;
    }

    struct ExactInSelectionState {
        uint256 bestLiquidity;
        bool foundPath;
        ExactInUnwindSelection selection;
    }
    /// @dev Family-local split (3 fields, *Out names) — not equivalent to shared UniV4 MintSplit.
    struct MintSplit {
        uint256 grossDetfOut;
        uint256 userDetfOut;
        uint256 inventoryDetfOut;
    }

    function _stablePoolDynamicData(IStablePool pool_) internal view virtual returns (StablePoolDynamicData memory data_) {
        data_ = pool_.getStablePoolDynamicData();
    }

    function _weightedPoolDynamicData(IWeightedPool pool_)
        internal
        view
        virtual
        returns (WeightedPoolDynamicData memory data_)
    {
        data_ = pool_.getWeightedPoolDynamicData();
    }

    function _weightedPoolWeights(IWeightedPool pool_) internal view virtual returns (uint256[] memory weights_) {
        weights_ = pool_.getNormalizedWeights();
    }

    function _requireReservePoolInitialized() internal view {
        if (!_isReserveLive()) {
            revert ReservePoolNotInitialized();
        }
    }

    function _selectRoutingPath(IERC20 tokenIn_) internal view returns (RoutedPoolSelection memory selection_) {
        ComposedStableCommonDetfRepo.Storage storage layoutStruct = ComposedStableCommonDetfRepo._layoutStruct();

        uint256 routeCount = layoutStruct._routeCount();
        uint256 bestLiquidity = type(uint256).max;
        bool foundRoute;

        for (uint256 i = 0; i < routeCount; i++) {
            ComposedStableCommonDetfRepo.RouteConfig storage route = layoutStruct._routeAt(i);
            if (address(route.baseToken) != address(tokenIn_)) {
                continue;
            }

            uint256 currentLiquidity = _ratedLiquidity(layoutStruct._commonPool(), route.commonPoolTokenIndex);
            if (!foundRoute || currentLiquidity < bestLiquidity) {
                foundRoute = true;
                bestLiquidity = currentLiquidity;
                selection_.routeIndex = i;
            }
        }

        if (!foundRoute) {
            revert InvalidToken(tokenIn_);
        }

        ComposedStableCommonDetfRepo.RouteConfig storage selectedRoute = layoutStruct._routeAt(selection_.routeIndex);
        uint256 stableLiquidity = _ratedLiquidity(layoutStruct._stablePool(), selectedRoute.stablePoolTokenIndex);
        uint256 commonLiquidity = _ratedLiquidity(layoutStruct._commonPool(), selectedRoute.commonPoolTokenIndex);

        if (commonLiquidity < stableLiquidity) {
            selection_.depositToStablePool = false;
            selection_.poolBptToken = layoutStruct._commonPoolBpt();
            selection_.poolRouter = selectedRoute.commonPoolRouter;
        } else {
            selection_.depositToStablePool = true;
            selection_.poolBptToken = layoutStruct._stablePoolBpt();
            selection_.poolRouter = selectedRoute.stablePoolRouter;
        }
    }

    function _ratedLiquidity(IStablePool pool_, uint256 tokenIndex_) internal view returns (uint256 liquidity_) {
        if (address(pool_) == address(0)) {
            return 0;
        }

        StablePoolDynamicData memory data = _stablePoolDynamicData(pool_);
        if (!data.isPoolInitialized || data.balancesLiveScaled18.length <= tokenIndex_) {
            return 0;
        }

        liquidity_ = data.balancesLiveScaled18[tokenIndex_];
    }

    function _unratedLiquidity(IStablePool pool_, uint256 tokenIndex_) internal view returns (uint256 liquidity_) {
        liquidity_ = _ratedLiquidity(pool_, tokenIndex_);
    }

    function _syncAllExpectedHoldReserves() internal {
        address[] memory tokens = MultiAssetBasicVaultRepo._vaultTokens();
        for (uint256 i; i < tokens.length; ++i) {
            IERC20 t = IERC20(tokens[i]);
            MultiAssetBasicVaultRepo._updateReserve(t, t.balanceOf(address(this)));
        }
    }

    function _nestedExchangeInPush(
        IStandardExchangeIn host_,
        IERC20 tokenIn_,
        uint256 amountIn_,
        IERC20 tokenOut_,
        uint256 minOut_,
        address recipient_,
        uint256 deadline_
    ) internal returns (uint256 amountOut_) {
        if (amountIn_ == 0) return 0;
        tokenIn_.safeTransfer(address(host_), amountIn_);
        amountOut_ = host_.exchangeIn(
            tokenIn_, amountIn_, tokenOut_, minOut_, recipient_, true, deadline_
        );
    }

    function _selectedPoolExitPricerIn(bool exitFromStablePool_) internal view returns (IStandardExchangeIn poolExitPricer_) {
        poolExitPricer_ = exitFromStablePool_
            ? ComposedStableCommonDetfRepo._stablePoolExitPricer()
            : ComposedStableCommonDetfRepo._commonPoolExitPricer();
    }

    function _selectedPoolExitPricerOut(bool exitFromStablePool_) internal view returns (IStandardExchangeOut poolExitPricer_) {
        poolExitPricer_ = IStandardExchangeOut(address(_selectedPoolExitPricerIn(exitFromStablePool_)));
    }

    function _executeRoutedEntryToPoolBptShared(
        ComposedStableCommonDetfRepo.RouteConfig storage route_,
        RoutedPoolSelection memory selection_,
        IERC20 tokenIn_,
        uint256 amountIn_,
        uint256 deadline_
    ) internal returns (uint256 poolBptOut_) {
        // Nested fund: push + pretransferred=true (L-DETF-PUSH-NESTED).
        if (amountIn_ > 0) tokenIn_.safeTransfer(address(route_.underlyingVault), amountIn_);
        uint256 vaultTokenOut = route_.underlyingVault.exchangeIn(
            tokenIn_,
            amountIn_,
            route_.vaultToken,
            0,
            address(this),
            true,
            deadline_
        );

        if (vaultTokenOut > 0) route_.vaultToken.safeTransfer(address(selection_.poolRouter), vaultTokenOut);
        poolBptOut_ = selection_.poolRouter.exchangeIn(
            route_.vaultToken,
            vaultTokenOut,
            selection_.poolBptToken,
            0,
            address(this),
            true,
            deadline_
        );
    }

    function _executeComposedPoolExitExactInShared(
        bool exitFromStablePool_,
        IERC20 poolBptToken_,
        uint256 poolBptAmountOut_,
        IERC20 vaultToken_,
        uint256 deadline_
    ) internal returns (uint256 vaultTokenAmountOut_) {
        IStandardExchangeIn poolExitPricer = _selectedPoolExitPricerIn(exitFromStablePool_);

        if (poolBptAmountOut_ > 0) poolBptToken_.safeTransfer(address(poolExitPricer), poolBptAmountOut_);
        vaultTokenAmountOut_ = poolExitPricer.exchangeIn(
            poolBptToken_,
            poolBptAmountOut_,
            vaultToken_,
            0,
            address(this),
            true,
            deadline_
        );
    }

    function _executeComposedPoolExitExactOutShared(
        bool exitFromStablePool_,
        IERC20 poolBptToken_,
        uint256 poolBptAmountOut_,
        IERC20 vaultToken_,
        uint256 vaultTokenAmountOut_,
        uint256 deadline_
    ) internal returns (uint256 poolBptAmountIn_) {
        IStandardExchangeOut poolExitPricer = _selectedPoolExitPricerOut(exitFromStablePool_);

        if (poolBptAmountOut_ > 0) poolBptToken_.safeTransfer(address(poolExitPricer), poolBptAmountOut_);
        poolBptAmountIn_ = poolExitPricer.exchangeOut(
            poolBptToken_,
            poolBptAmountOut_,
            vaultToken_,
            vaultTokenAmountOut_,
            address(this),
            true,
            deadline_
        );
    }

    function _executeUnderlyingExitExactInShared(
        ComposedStableCommonDetfRepo.RouteConfig storage route_,
        IERC20 tokenOut_,
        uint256 vaultTokenAmountOut_,
        address recipient_,
        uint256 deadline_
    ) internal returns (uint256 amountOut_) {
        if (address(route_.vaultToken) == address(tokenOut_)) {
            route_.vaultToken.safeTransfer(recipient_, vaultTokenAmountOut_);
            return vaultTokenAmountOut_;
        }

        if (vaultTokenAmountOut_ > 0) route_.vaultToken.safeTransfer(address(route_.underlyingVault), vaultTokenAmountOut_);
        amountOut_ = route_.underlyingVault.exchangeIn(
            route_.vaultToken,
            vaultTokenAmountOut_,
            tokenOut_,
            0,
            recipient_,
            true,
            deadline_
        );
    }

    function _executeUnderlyingExitExactOutShared(
        ComposedStableCommonDetfRepo.RouteConfig storage route_,
        IERC20 tokenOut_,
        uint256 amountOut_,
        address recipient_,
        uint256 deadline_
    ) internal returns (uint256 vaultTokenAmountIn_) {
        if (address(route_.vaultToken) == address(tokenOut_)) {
            route_.vaultToken.safeTransfer(recipient_, amountOut_);
            return amountOut_;
        }

        IStandardExchangeOut underlyingVault = IStandardExchangeOut(address(route_.underlyingVault));
        uint256 vaultTokenBal_ = route_.vaultToken.balanceOf(address(this));
        // Outer exact-out partial maxIn is success (L-DETF-EXACT-OUT-PARTIAL): host refunds unused to DETF.
        if (vaultTokenBal_ > 0) route_.vaultToken.safeTransfer(address(underlyingVault), vaultTokenBal_);
        vaultTokenAmountIn_ = underlyingVault.exchangeOut(
            route_.vaultToken,
            vaultTokenBal_,
            tokenOut_,
            amountOut_,
            recipient_,
            true,
            deadline_
        );
    }

    function _tryPreviewExchangeOut(address router_, IERC20 tokenIn_, IERC20 tokenOut_, uint256 amountOut_)
        internal
        view
        returns (bool success_, uint256 amountIn_)
    {
        if (router_ == address(0)) {
            return (false, 0);
        }

        try IStandardExchangeOut(router_).previewExchangeOut(tokenIn_, tokenOut_, amountOut_) returns (uint256 quotedIn_) {
            return (true, quotedIn_);
        } catch {
            return (false, 0);
        }
    }

    function _tryPreviewExchangeIn(address router_, IERC20 tokenIn_, uint256 amountIn_, IERC20 tokenOut_)
        internal
        view
        returns (bool success_, uint256 amountOut_)
    {
        if (router_ == address(0)) {
            return (false, 0);
        }

        try IStandardExchangeIn(router_).previewExchangeIn(tokenIn_, amountIn_, tokenOut_) returns (
            uint256 quotedOut_
        ) {
            return (true, quotedOut_);
        } catch {
            return (false, 0);
        }
    }

    function _resolveUnwindRouteEligibility(ComposedStableCommonDetfRepo.RouteConfig storage route_, IERC20 tokenOut_)
        internal
        view
        returns (bool eligible_, bool directVaultTokenExit_)
    {
        directVaultTokenExit_ = address(route_.vaultToken) == address(tokenOut_);
        eligible_ = directVaultTokenExit_ || address(route_.baseToken) == address(tokenOut_);
    }

    function _resolveExactOutVaultTokenAmount(
        ComposedStableCommonDetfRepo.RouteConfig storage route_,
        IERC20 tokenOut_,
        uint256 amountOut_,
        bool directVaultTokenExit_
    ) internal view returns (bool success_, uint256 vaultTokenAmountOut_) {
        if (directVaultTokenExit_) {
            return (true, amountOut_);
        }

        (bool hasVaultQuote, uint256 quotedVaultTokenAmountOut) = _tryPreviewExchangeOut(
            address(route_.underlyingVault), route_.vaultToken, tokenOut_, amountOut_
        );
        if (!hasVaultQuote || quotedVaultTokenAmountOut == 0) {
            return (false, 0);
        }

        return (true, quotedVaultTokenAmountOut);
    }

    function _unwindPoolLegContext(
        ComposedStableCommonDetfRepo.Storage storage layoutStruct_,
        ComposedStableCommonDetfRepo.RouteConfig storage route_,
        bool exitFromStablePool_
    ) internal view returns (uint256 liquidity_, IERC20 poolBptToken_, address poolExitPricer_) {
        if (exitFromStablePool_) {
            liquidity_ = _unratedLiquidity(layoutStruct_._stablePool(), route_.stablePoolTokenIndex);
            poolBptToken_ = layoutStruct_._stablePoolBpt();
            poolExitPricer_ = address(layoutStruct_._stablePoolExitPricer());
            return (liquidity_, poolBptToken_, poolExitPricer_);
        }

        liquidity_ = _unratedLiquidity(layoutStruct_._commonPool(), route_.commonPoolTokenIndex);
        poolBptToken_ = layoutStruct_._commonPoolBpt();
        poolExitPricer_ = address(layoutStruct_._commonPoolExitPricer());
    }

    function _previewMostLiquidUnwindSelection(IERC20 tokenOut_, uint256 amountOut_)
        internal
        view
        returns (UnwindPreviewSelection memory selection_)
    {
        ComposedStableCommonDetfRepo.Storage storage layoutStruct = ComposedStableCommonDetfRepo._layoutStruct();
        uint256 routeCount = layoutStruct._routeCount();
        ExactOutSelectionState memory state_;

        for (uint256 i = 0; i < routeCount; i++) {
            ComposedStableCommonDetfRepo.RouteConfig storage route = layoutStruct._routeAt(i);
            (bool eligibleRoute, bool directVaultTokenExit) = _resolveUnwindRouteEligibility(route, tokenOut_);
            if (!eligibleRoute) {
                continue;
            }

            (bool hasVaultTokenAmountOut, uint256 vaultTokenAmountOut) =
                _resolveExactOutVaultTokenAmount(route, tokenOut_, amountOut_, directVaultTokenExit);
            if (!hasVaultTokenAmountOut) {
                continue;
            }

            {
                (uint256 stableLiquidity, UnwindPreviewSelection memory stableSelection) = _previewUnwindCandidate(
                    layoutStruct, route, vaultTokenAmountOut, true
                );
                state_ = _considerExactOutSelection(stableSelection, stableLiquidity, i, state_);
            }

            {
                (uint256 commonLiquidity, UnwindPreviewSelection memory commonSelection) = _previewUnwindCandidate(
                    layoutStruct, route, vaultTokenAmountOut, false
                );
                state_ = _considerExactOutSelection(commonSelection, commonLiquidity, i, state_);
            }
        }

        if (!state_.foundPath) {
            revert IStandardExchangeOut.ExchangeOutNotAvailable();
        }

        selection_ = state_.selection;
    }

    function _previewUnwindCandidate(
        ComposedStableCommonDetfRepo.Storage storage layoutStruct_,
        ComposedStableCommonDetfRepo.RouteConfig storage route_,
        uint256 vaultTokenAmountOut_,
        bool exitFromStablePool_
    ) internal view returns (uint256 liquidity_, UnwindPreviewSelection memory selection_) {
        address poolExitPricer;
        IERC20 poolBptToken;
        (liquidity_, poolBptToken, poolExitPricer) = _unwindPoolLegContext(layoutStruct_, route_, exitFromStablePool_);
        if (liquidity_ == 0) {
            return (0, selection_);
        }

        (bool hasPoolQuote, uint256 poolBptAmountOut) =
            _previewPoolBptAmountOutForVaultToken(poolExitPricer, poolBptToken, route_.vaultToken, vaultTokenAmountOut_);
        if (!hasPoolQuote || poolBptAmountOut == 0) {
            return (0, selection_);
        }

        selection_.exitFromStablePool = exitFromStablePool_;
        selection_.poolBptToken = poolBptToken;
        selection_.vaultTokenAmountOut = vaultTokenAmountOut_;
        selection_.poolBptAmountOut = poolBptAmountOut;
        selection_.detfAmountIn = _previewReserveDetfInForPoolBptOut(poolBptAmountOut, exitFromStablePool_);
        if (selection_.detfAmountIn == 0) {
            return (0, selection_);
        }
    }

    function _previewExactInUnwindLeg(
        ComposedStableCommonDetfRepo.Storage storage layoutStruct_,
        ComposedStableCommonDetfRepo.RouteConfig storage route_,
        IERC20 tokenOut_,
        uint256 detfAmountIn_,
        bool exitFromStablePool_,
        bool directVaultTokenExit_
    ) internal view returns (uint256 liquidity_, ExactInUnwindSelection memory selection_) {
        address poolExitPricer;
        (liquidity_, selection_.poolBptToken, poolExitPricer) =
            _unwindPoolLegContext(layoutStruct_, route_, exitFromStablePool_);
        if (liquidity_ == 0) {
            return (0, selection_);
        }

        selection_.exitFromStablePool = exitFromStablePool_;
        selection_.poolBptAmountOut = _previewReservePoolBptOutForDetfIn(detfAmountIn_, exitFromStablePool_);
        if (selection_.poolBptAmountOut == 0) {
            return (0, selection_);
        }

        (bool hasVaultQuote, uint256 vaultTokenAmountOut) = _previewVaultTokenAmountOutFromPoolBpt(
            poolExitPricer, selection_.poolBptToken, route_.vaultToken, selection_.poolBptAmountOut
        );
        if (!hasVaultQuote || vaultTokenAmountOut == 0) {
            return (0, selection_);
        }

        selection_.vaultTokenAmountOut = vaultTokenAmountOut;
        (bool hasUnderlyingQuote, uint256 tokenOutAmountOut) =
            _previewUnderlyingTokenAmountOut(route_, tokenOut_, vaultTokenAmountOut, directVaultTokenExit_);
        if (!hasUnderlyingQuote || tokenOutAmountOut == 0) {
            return (0, selection_);
        }

        selection_.tokenOutAmountOut = tokenOutAmountOut;
    }

    function _previewMostLiquidUnwindSelectionForExactIn(IERC20 tokenOut_, uint256 detfAmountIn_)
        internal
        view
        returns (ExactInUnwindSelection memory selection_)
    {
        ComposedStableCommonDetfRepo.Storage storage layoutStruct = ComposedStableCommonDetfRepo._layoutStruct();
        uint256 routeCount = layoutStruct._routeCount();
        ExactInSelectionState memory state_;

        for (uint256 i = 0; i < routeCount; i++) {
            ComposedStableCommonDetfRepo.RouteConfig storage route = layoutStruct._routeAt(i);
            (bool eligibleRoute, bool directVaultTokenExit) = _resolveUnwindRouteEligibility(route, tokenOut_);
            if (!eligibleRoute) {
                continue;
            }

            {
                (uint256 stableLiquidity, ExactInUnwindSelection memory stableSelection) = _previewExactInUnwindLeg(
                    layoutStruct, route, tokenOut_, detfAmountIn_, true, directVaultTokenExit
                );
                state_ = _considerExactInSelection(stableSelection, stableLiquidity, i, state_);
            }

            {
                (uint256 commonLiquidity, ExactInUnwindSelection memory commonSelection) = _previewExactInUnwindLeg(
                    layoutStruct, route, tokenOut_, detfAmountIn_, false, directVaultTokenExit
                );
                state_ = _considerExactInSelection(commonSelection, commonLiquidity, i, state_);
            }
        }

        if (!state_.foundPath) {
            revert IStandardExchangeIn.ExchangeInNotAvailable();
        }

        selection_ = state_.selection;
    }

    function _considerExactOutSelection(
        UnwindPreviewSelection memory candidate_,
        uint256 candidateLiquidity_,
        uint256 routeIndex_,
        ExactOutSelectionState memory state_
    ) internal pure returns (ExactOutSelectionState memory) {
        if (candidate_.detfAmountIn == 0 || candidateLiquidity_ <= state_.bestLiquidity) {
            return state_;
        }

        candidate_.routeIndex = routeIndex_;
        state_.foundPath = true;
        state_.bestLiquidity = candidateLiquidity_;
        state_.selection = candidate_;
        return state_;
    }

    function _considerExactInSelection(
        ExactInUnwindSelection memory candidate_,
        uint256 candidateLiquidity_,
        uint256 routeIndex_,
        ExactInSelectionState memory state_
    ) internal pure returns (ExactInSelectionState memory) {
        if (candidate_.tokenOutAmountOut == 0 || candidateLiquidity_ <= state_.bestLiquidity) {
            return state_;
        }

        candidate_.routeIndex = routeIndex_;
        state_.foundPath = true;
        state_.bestLiquidity = candidateLiquidity_;
        state_.selection = candidate_;
        return state_;
    }

    function _previewPoolBptAmountOutForVaultToken(
        address poolExitPricer_,
        IERC20 poolBptToken_,
        IERC20 vaultToken_,
        uint256 vaultTokenAmountOut_
    ) internal view returns (bool hasPoolQuote_, uint256 poolBptAmountOut_) {
        return _tryPreviewExchangeOut(poolExitPricer_, poolBptToken_, vaultToken_, vaultTokenAmountOut_);
    }

    function _previewVaultTokenAmountOutFromPoolBpt(
        address poolExitPricer_,
        IERC20 poolBptToken_,
        IERC20 vaultToken_,
        uint256 poolBptAmountOut_
    ) internal view returns (bool hasVaultQuote_, uint256 vaultTokenAmountOut_) {
        return _tryPreviewExchangeIn(poolExitPricer_, poolBptToken_, poolBptAmountOut_, vaultToken_);
    }

    function _previewUnderlyingTokenAmountOut(
        ComposedStableCommonDetfRepo.RouteConfig storage route_,
        IERC20 tokenOut_,
        uint256 vaultTokenAmountOut_,
        bool directVaultTokenExit_
    ) internal view returns (bool hasUnderlyingQuote_, uint256 tokenOutAmountOut_) {
        if (directVaultTokenExit_) {
            return (true, vaultTokenAmountOut_);
        }

        return _tryPreviewExchangeIn(address(route_.underlyingVault), route_.vaultToken, vaultTokenAmountOut_, tokenOut_);
    }

    function _isReserveLive() internal view returns (bool) { return Repo._layoutStruct().isReserveLive; }
    function _reserveVault() internal view returns (IVault) { return BalancerV3VaultAwareRepo._balancerV3Vault(); }
    function _mintDetf(address to_, uint256 amount_) internal { if (amount_ != 0) ERC20Repo._mint(to_, amount_); }
    function _burnDetf(address from_, uint256 amount_) internal { ERC20Repo._burn(from_, amount_); }
    function _lpHeld() internal view returns (uint256) {
        Repo.Storage storage s_ = Repo._layoutStruct();
        IERC20 lp_ = IERC20(address(s_.reservePool));
        return lp_.balanceOf(address(this)) + lp_.balanceOf(address(s_.bondNftVault));
    }
    function _bptForDetfShares(uint256 amount_, bool preview_) internal view returns (uint256) {
        uint256 supply_ = ERC20Repo._totalSupply() + (preview_ ? _pendingExpansionDetf() : 0);
        return supply_ == 0 ? 0 : Math.mulDiv(amount_, _lpHeld(), supply_);
    }
    function _previewProportionalExit(uint256 lp_) internal view returns (uint256 detf_, uint256 stable_, uint256 common_) {
        Repo.Storage storage s_ = Repo._layoutStruct();
        uint256 supply_ = IERC20(address(s_.reservePool)).totalSupply();
        if (supply_ == 0 || lp_ == 0) return (0,0,0);
        (,,uint256[] memory raw_,) = _reserveVault().getPoolTokenInfo(address(s_.reservePool));
        return (Math.mulDiv(lp_, raw_[s_.detfIndex], supply_), Math.mulDiv(lp_, raw_[s_.stablePoolBptIndex], supply_),
            Math.mulDiv(lp_, raw_[s_.commonPoolBptIndex], supply_));
    }
    function _poolValue(bool stable_, uint256 amount_) internal view returns (uint256) {
        if (amount_ == 0) return 0;
        Repo.Storage storage s_ = Repo._layoutStruct();
        IERC20 bpt_ = stable_ ? s_._stablePoolBpt() : s_._commonPoolBpt();
        uint256 raw_ = _selectedPoolExitPricerIn(stable_).previewExchangeIn(bpt_, amount_, s_.rateAsset);
        return Math.mulDiv(raw_, ONE_WAD, 10 ** IERC20Metadata(address(s_.rateAsset)).decimals());
    }
    function _syntheticPriceForSupply(uint256 supply_) internal view returns (uint256) {
        (uint256 self_, uint256 stable_, uint256 common_) = _previewProportionalExit(_lpHeld());
        if (supply_ <= self_) return 0;
        return Math.mulDiv(_poolValue(true, stable_) + _poolValue(false, common_), 1e9, supply_ - self_);
    }
    function _syntheticDetfEthPrice() internal view virtual returns (uint256) { return _syntheticPriceForSupply(ERC20Repo._totalSupply()); }
    function _isMintingAllowed() internal view returns (bool) {
        return _isReserveLive() && _syntheticDetfEthPrice() > Repo._layoutStruct().mintThreshold;
    }
    function _isBurningAllowed() internal view returns (bool) {
        return _isReserveLive() && _syntheticDetfEthPrice() < Repo._layoutStruct().burnThreshold;
    }
    function _previewPrimaryMint() internal view returns (bool) {
        return _isReserveLive() && _syntheticPriceForSupply(ERC20Repo._totalSupply() + _pendingExpansionDetf()) > Repo._layoutStruct().mintThreshold;
    }
    function _previewPrimaryBurn() internal view returns (bool) {
        return _isReserveLive() && _syntheticPriceForSupply(ERC20Repo._totalSupply() + _pendingExpansionDetf()) < Repo._layoutStruct().burnThreshold;
    }
    function _expansionQuote() internal view returns (uint256 amount_, uint256 boundary_, uint256 price_) {
        Repo.Storage storage s_ = Repo._layoutStruct();
        price_ = _syntheticDetfEthPrice();
        (amount_, boundary_) = DETFNaturalExpansionLib.computeEpochExpansion(DETFNaturalExpansionLib.EpochInput({
            isLive: s_.isReserveLive, isMintAllowed: price_ > s_.mintThreshold, syntheticPrice: price_,
            totalDetfSupply: ERC20Repo._totalSupply(), lastSettledBoundary: s_.lastExpansionTimestamp,
            nowTimestamp: block.timestamp, closureRatePerSecond: s_.expansionClosureRatePerSecond
        }));
    }
    function _pendingExpansionDetf() internal view returns (uint256 amount_) { (amount_,,) = _expansionQuote(); }
    function _updateExpansionMintOnRewards() internal returns (uint256 amount_) {
        uint256 boundary_; uint256 price_;
        (amount_, boundary_, price_) = _expansionQuote();
        Repo._layoutStruct().lastExpansionTimestamp = boundary_;
        if (amount_ != 0) { _fundStakingRewards(amount_); emit NaturalSupplyExpanded(amount_, price_, boundary_); }
    }
    function _fundStakingRewards(uint256 amount_) internal {
        if (amount_ == 0) return;
        address staking_ = address(Repo._layoutStruct().rebasingDetfToken);
        _mintDetf(address(this), amount_);
        IERC20(address(this)).forceApprove(staking_, amount_);
        IStakedDETF(staking_).fundRewards(amount_);
        IERC20(address(this)).forceApprove(staking_, 0);
    }
    function _effectiveLockDuration(uint256 duration_) internal view returns (uint256) {
        BondTerms memory terms_ = DETFBondNFTMathLib._bondTerms(address(this));
        if (duration_ < terms_.minLockDuration) revert Repo.LockDurationTooShort(duration_, terms_.minLockDuration);
        return duration_ > terms_.maxLockDuration ? terms_.maxLockDuration : duration_;
    }
    function _seigniorageIncentivePercentage() internal view virtual returns (uint256) {
        return Repo._layoutStruct().feeOracle.seigniorageIncentivePercentageOfVault(address(this));
    }
    function _splitMintAmount(uint256 gross_) internal view returns (MintSplit memory split_) {
        split_.grossDetfOut = gross_;
        (split_.userDetfOut, split_.inventoryDetfOut) = DETFMintSplitLib._splitLiveGross(gross_, _seigniorageIncentivePercentage());
    }
    function _splitBondAmount(uint256 gross_, uint256 liquidity_) internal view returns (MintSplit memory split_) {
        split_.grossDetfOut = gross_;
        (split_.userDetfOut, split_.inventoryDetfOut,) = DETFMintSplitLib._splitBond(gross_, liquidity_, _seigniorageIncentivePercentage());
    }
    function _quoteBondJoinDetf(uint256 bpt_, bool stable_) internal view returns (uint256) {
        Repo.Storage storage s_ = Repo._layoutStruct();
        if (!_isReserveLive()) return Math.mulDiv(bpt_, s_.reserveSeedAmounts[0], s_.reserveSeedAmounts[stable_ ? 1 : 2]);
        (,,uint256[] memory raw_,) = _reserveVault().getPoolTokenInfo(address(s_.reservePool));
        return Math.mulDiv(bpt_, raw_[s_.detfIndex], raw_[stable_ ? s_.stablePoolBptIndex : s_.commonPoolBptIndex]);
    }
    function _firstBondLiquidity(uint256 stable_, uint256 common_) internal view returns (uint256) {
        Repo.Storage storage s_ = Repo._layoutStruct();
        uint256 required_ = Math.mulDiv(stable_, s_.reserveSeedAmounts[2], s_.reserveSeedAmounts[1]);
        if (common_ != required_) revert Repo.InvalidSeedRatio(common_, required_);
        // Both payment legs match one seed basket; its DETF leg is minted once.
        return _quoteBondJoinDetf(stable_, true);
    }
    function _previewRoutedPoolBpt(IERC20 in_, uint256 amount_) internal view
        returns (RoutedPoolSelection memory selection_, uint256 vault_, uint256 pool_)
    {
        Repo.Storage storage s_ = Repo._layoutStruct();
        if (address(in_) == address(s_.stablePool) || address(in_) == address(s_.commonPool)) {
            selection_.depositToStablePool = address(in_) == address(s_.stablePool);
            selection_.poolBptToken = in_; selection_.routeIndex = type(uint256).max;
            return (selection_, amount_, amount_);
        }
        selection_ = _selectRoutingPath(in_);
        Repo.RouteConfig storage route_ = s_.routes[selection_.routeIndex];
        vault_ = route_.underlyingVault.previewExchangeIn(in_, amount_, route_.vaultToken);
        pool_ = selection_.poolRouter.previewExchangeIn(route_.vaultToken, vault_, selection_.poolBptToken);
    }
    function _collectRoutedBpt(IERC20 in_, uint256 amount_, bool prepaid_, uint256 deadline_)
        internal returns (RoutedPoolSelection memory selection_, uint256 bpt_)
    {
        (selection_,,) = _previewRoutedPoolBpt(in_, amount_);
        _secureTokenTransfer(in_, amount_, prepaid_);
        if (selection_.routeIndex == type(uint256).max) return (selection_, amount_);
        bpt_ = _executeRoutedEntryToPoolBptShared(Repo._layoutStruct().routes[selection_.routeIndex], selection_, in_, amount_, deadline_);
    }
    function _quoteReserveSwap(uint256 amount_, bool stable_, bool mint_) internal view returns (uint256) {
        Repo.Storage storage s_ = Repo._layoutStruct();
        WeightedPoolDynamicData memory d_ = s_.reservePool.getWeightedPoolDynamicData();
        uint256[] memory w_ = s_.reservePool.getNormalizedWeights();
        uint256 leg_ = stable_ ? s_.stablePoolBptIndex : s_.commonPoolBptIndex;
        uint256 in_ = mint_ ? leg_ : s_.detfIndex; uint256 out_ = mint_ ? s_.detfIndex : leg_;
        uint256 q_ = BalancerV3WeightedPoolQuote.computeOutGivenExactInAfterFee(
            d_.balancesLiveScaled18[in_], w_[in_], d_.balancesLiveScaled18[out_], w_[out_],
            mint_ ? amount_ : amount_ * 1e9, d_.staticSwapFeePercentage
        );
        return mint_ ? q_ / 1e9 : q_;
    }
    function _previewMintAmount(uint256 bpt_, bool stable_) internal view returns (uint256) {
        return _quoteReserveSwap(Math.mulDiv(bpt_, ONE_WAD + _seigniorageIncentivePercentage(), ONE_WAD), stable_, true);
    }
    function _previewMintSplit(uint256 bpt_, bool stable_) internal view returns (MintSplit memory) {
        return _splitMintAmount(_previewMintAmount(bpt_, stable_));
    }
    function _quoteBondPurchase(uint256 bpt_, bool stable_, uint256 duration_) internal view returns (uint256) {
        uint256 boosted_ = Math.mulDiv(bpt_, DETFBondNFTMathLib._bonusMultiplierOfVault(address(this), duration_), ONE_WAD);
        return _isReserveLive() ? _quoteReserveSwap(boosted_, stable_, true)
            : Math.mulDiv(boosted_, 1e9, Repo._layoutStruct().openingDetfPrices[stable_ ? 0 : 1]);
    }
    function _previewReservePoolBptOutForDetfIn(uint256 amount_, bool stable_) internal view returns (uint256) {
        return _quoteReserveSwap(amount_, stable_, false);
    }
    function _previewReserveDetfInForPoolBptOut(uint256 amount_, bool stable_) internal view returns (uint256) {
        Repo.Storage storage s_ = Repo._layoutStruct();
        uint256 leg_ = stable_ ? s_.stablePoolBptIndex : s_.commonPoolBptIndex;
        if (_previewPrimaryBurn()) {
            (,,uint256[] memory raw_,) = _reserveVault().getPoolTokenInfo(address(s_.reservePool));
            uint256 lp_ = Math.mulDiv(amount_, IERC20(address(s_.reservePool)).totalSupply(), raw_[leg_], Math.Rounding.Ceil);
            return Math.mulDiv(lp_, ERC20Repo._totalSupply() + _pendingExpansionDetf(), _lpHeld(), Math.Rounding.Ceil);
        }
        WeightedPoolDynamicData memory d_ = s_.reservePool.getWeightedPoolDynamicData();
        uint256[] memory w_ = s_.reservePool.getNormalizedWeights();
        uint256 q_ = BalancerV3WeightedPoolQuote.computeInGivenExactOutBeforeFee(
            d_.balancesLiveScaled18[s_.detfIndex], w_[s_.detfIndex], d_.balancesLiveScaled18[leg_], w_[leg_], amount_, d_.staticSwapFeePercentage
        );
        return Math.ceilDiv(q_, 1e9);
    }
    function _secureTokenTransfer(IERC20 token_, uint256 amount_, bool prepaid_) internal returns (uint256) {
        uint256 before_ = token_.balanceOf(address(this));
        if (prepaid_) {
            uint256 reserve_ = MultiAssetBasicVaultRepo._reserveOfToken(address(token_));
            uint256 available_ = before_ > reserve_ ? before_ - reserve_ : 0;
            if (amount_ > available_) revert ISecurePullErrors.TransferDeltaInsufficient(amount_, available_);
        } else {
            token_.safeTransferFrom(msg.sender, address(this), amount_);
            uint256 received_ = token_.balanceOf(address(this)) - before_;
            if (received_ != amount_) revert ISecurePullErrors.TransferDeltaInsufficient(amount_, received_);
        }
        return amount_;
    }
    function _joinReserve(uint256 detf_, uint256 stable_, uint256 common_, bool initialize_) internal returns (uint256 lp_) {
        Repo.Storage storage s_ = Repo._layoutStruct();
        uint256[] memory amounts_ = new uint256[](3);
        IERC20[] memory tokens_ = new IERC20[](3);
        tokens_[s_.detfIndex] = IERC20(address(this)); tokens_[s_.stablePoolBptIndex] = s_._stablePoolBpt(); tokens_[s_.commonPoolBptIndex] = s_._commonPoolBpt();
        amounts_[s_.detfIndex] = detf_; amounts_[s_.stablePoolBptIndex] = stable_; amounts_[s_.commonPoolBptIndex] = common_;
        for (uint256 i_; i_ < 3; ++i_) if (amounts_[i_] != 0) tokens_[i_].safeTransfer(address(_reserveVault()), amounts_[i_]);
        lp_ = initialize_ ? s_.balancerV3Router.prepayInitialize(address(s_.reservePool), tokens_, amounts_, 0, "")
            : s_.balancerV3Router.prepayAddLiquidityUnbalanced(address(s_.reservePool), amounts_, 0, "");
        IERC20(address(s_.reservePool)).safeTransfer(address(s_.bondNftVault), lp_);
    }
    function _exitReserveProportional(uint256 lp_) internal returns (uint256 detf_, uint256 stable_, uint256 common_) {
        Repo.Storage storage s_ = Repo._layoutStruct();
        IERC20 token_ = IERC20(address(s_.reservePool));
        uint256 have_ = token_.balanceOf(address(this));
        if (have_ < lp_) s_.bondNftVault.transferHeldToken(token_, address(this), lp_ - have_);
        token_.forceApprove(address(s_.balancerV3Router), lp_);
        uint256[] memory out_ = s_.balancerV3Router.prepayRemoveLiquidityProportional(address(s_.reservePool), lp_, new uint256[](3), "");
        return (out_[s_.detfIndex], out_[s_.stablePoolBptIndex], out_[s_.commonPoolBptIndex]);
    }
    function _isFamilyBurnToken(IERC20 out_) internal view returns (bool) {
        Repo.Storage storage s_ = Repo._layoutStruct();
        if (address(out_) == address(s_.rateAsset) || address(out_) == address(s_.stablePool) || address(out_) == address(s_.commonPool)) return true;
        for (uint256 i_; i_ < s_.routes.length; ++i_) if (out_ == s_.routes[i_].baseToken || address(out_) == address(s_.routes[i_].vaultToken)) return true;
        return false;
    }
    function _routeForOutput(IERC20 out_) internal view returns (uint256) {
        Repo.Storage storage s_ = Repo._layoutStruct();
        for (uint256 i_; i_ < s_.routes.length; ++i_) if (out_ == s_.routes[i_].baseToken || address(out_) == address(s_.routes[i_].vaultToken)) return i_;
        revert InvalidToken(out_);
    }
    function _previewConsolidation(uint256 stable_, uint256 common_, IERC20 out_) internal view returns (uint256 amount_) {
        Repo.Storage storage s_ = Repo._layoutStruct();
        if (address(out_) == address(s_.stablePool)) return stable_;
        if (address(out_) == address(s_.commonPool)) return common_;
        if (out_ == s_.rateAsset) {
            if (stable_ != 0) amount_ += s_.stablePoolExitPricer.previewExchangeIn(s_._stablePoolBpt(), stable_, out_);
            if (common_ != 0) amount_ += s_.commonPoolExitPricer.previewExchangeIn(s_._commonPoolBpt(), common_, out_);
            return amount_;
        }
        Repo.RouteConfig storage route_ = s_.routes[_routeForOutput(out_)];
        uint256 shares_;
        if (stable_ != 0) shares_ += s_.stablePoolExitPricer.previewExchangeIn(s_._stablePoolBpt(), stable_, route_.vaultToken);
        if (common_ != 0) shares_ += s_.commonPoolExitPricer.previewExchangeIn(s_._commonPoolBpt(), common_, route_.vaultToken);
        return address(out_) == address(route_.vaultToken) ? shares_ : route_.underlyingVault.previewExchangeIn(route_.vaultToken, shares_, out_);
    }
    function _consolidatePoolBptsToTokenOut(uint256 stable_, uint256 common_, IERC20 out_, address to_, uint256 deadline_) internal returns (uint256 amount_) {
        Repo.Storage storage s_ = Repo._layoutStruct();
        if (address(out_) == address(s_.stablePool) || address(out_) == address(s_.commonPool)) {
            bool stableOut_ = address(out_) == address(s_.stablePool);
            amount_ = stableOut_ ? stable_ : common_;
            uint256 other_ = stableOut_ ? common_ : stable_;
            if (other_ != 0) _joinReserve(0, stableOut_ ? 0 : other_, stableOut_ ? other_ : 0, false);
            out_.safeTransfer(to_, amount_); return amount_;
        }
        if (out_ == s_.rateAsset) {
            amount_ = _nestedExchangeInPush(s_.stablePoolExitPricer, s_._stablePoolBpt(), stable_, out_, 0, to_, deadline_);
            amount_ += _nestedExchangeInPush(s_.commonPoolExitPricer, s_._commonPoolBpt(), common_, out_, 0, to_, deadline_);
            return amount_;
        }
        Repo.RouteConfig storage route_ = s_.routes[_routeForOutput(out_)];
        uint256 shares_ = _nestedExchangeInPush(s_.stablePoolExitPricer, s_._stablePoolBpt(), stable_, route_.vaultToken, 0, address(this), deadline_);
        shares_ += _nestedExchangeInPush(s_.commonPoolExitPricer, s_._commonPoolBpt(), common_, route_.vaultToken, 0, address(this), deadline_);
        return _executeUnderlyingExitExactInShared(route_, out_, shares_, to_, deadline_);
    }
    function _previewExitSettle(uint256 lp_, IERC20 out_) internal view returns (uint256) {
        (,uint256 stable_, uint256 common_) = _previewProportionalExit(lp_);
        return _previewConsolidation(stable_, common_, out_);
    }
    function _requireActive(uint256 deadline_, uint256 amount_) internal view {
        if (amount_ == 0) revert ZeroAmount();
        if (block.timestamp > deadline_) revert DeadlineExceeded(deadline_, block.timestamp);
    }
    function _directPoolExit(IERC20 out_) internal view returns (bool) {
        Repo.Storage storage s_ = Repo._layoutStruct();
        return address(out_) == address(s_.rateAsset) || address(out_) == address(s_.stablePool) || address(out_) == address(s_.commonPool);
    }
    function _directExitStable(IERC20 out_) internal view returns (bool) {
        Repo.Storage storage s_ = Repo._layoutStruct();
        if (address(out_) == address(s_.stablePool)) return true;
        if (address(out_) == address(s_.commonPool)) return false;
        return _directDepth(true, out_) >= _directDepth(false, out_);
    }
    function _directDepth(bool stable_, IERC20 out_) internal view returns (uint256) {
        address pool_ = stable_ ? address(Repo._layoutStruct().stablePool) : address(Repo._layoutStruct().commonPool);
        (IERC20[] memory tokens_,,,) = _reserveVault().getPoolTokenInfo(pool_);
        uint256[] memory balances_ = _reserveVault().getCurrentLiveBalances(pool_);
        for (uint256 i_; i_ < tokens_.length; ++i_) if (tokens_[i_] == out_) return balances_[i_];
        return 0;
    }
    function _selectExactInExit(IERC20 out_, uint256 amount_) internal view returns (ExactInUnwindSelection memory p_) {
        if (!_directPoolExit(out_)) return _previewMostLiquidUnwindSelectionForExactIn(out_, amount_);
        p_.routeIndex = type(uint256).max;
        p_.exitFromStablePool = _directExitStable(out_);
        p_.poolBptToken = p_.exitFromStablePool ? Repo._stablePoolBpt() : Repo._commonPoolBpt();
        p_.poolBptAmountOut = _quoteReserveSwap(amount_, p_.exitFromStablePool, false);
        p_.tokenOutAmountOut = out_ == p_.poolBptToken ? p_.poolBptAmountOut
            : _selectedPoolExitPricerIn(p_.exitFromStablePool).previewExchangeIn(p_.poolBptToken, p_.poolBptAmountOut, out_);
    }
    function _selectExactOutExit(IERC20 out_, uint256 amount_) internal view returns (UnwindPreviewSelection memory p_) {
        if (!_directPoolExit(out_)) return _previewMostLiquidUnwindSelection(out_, amount_);
        p_.routeIndex = type(uint256).max;
        p_.exitFromStablePool = _directExitStable(out_);
        p_.poolBptToken = p_.exitFromStablePool ? Repo._stablePoolBpt() : Repo._commonPoolBpt();
        p_.poolBptAmountOut = out_ == p_.poolBptToken ? amount_
            : _selectedPoolExitPricerOut(p_.exitFromStablePool).previewExchangeOut(p_.poolBptToken, out_, amount_);
        p_.vaultTokenAmountOut = amount_;
        p_.detfAmountIn = _previewReserveDetfInForPoolBptOut(p_.poolBptAmountOut, p_.exitFromStablePool);
    }
    function _deliverExit(ExactInUnwindSelection memory p_, uint256 bpt_, IERC20 out_, address to_, uint256 deadline_)
        internal returns (uint256)
    {
        if (out_ == p_.poolBptToken) { out_.safeTransfer(to_, bpt_); return bpt_; }
        if (p_.routeIndex == type(uint256).max) return _nestedExchangeInPush(
            _selectedPoolExitPricerIn(p_.exitFromStablePool), p_.poolBptToken, bpt_, out_, 0, to_, deadline_
        );
        Repo.RouteConfig storage route_ = Repo._layoutStruct().routes[p_.routeIndex];
        uint256 shares_ = _executeComposedPoolExitExactInShared(p_.exitFromStablePool, p_.poolBptToken, bpt_, route_.vaultToken, deadline_);
        return _executeUnderlyingExitExactInShared(route_, out_, shares_, to_, deadline_);
    }
    function _executeExactOutExit(IERC20 out_, uint256 amount_, uint256 funded_, address to_, uint256 deadline_)
        internal returns (uint256 paid_)
    {
        UnwindPreviewSelection memory p_ = _selectExactOutExit(out_, amount_);
        uint256 self_; uint256 stable_; uint256 common_;
        bool primary_ = _isBurningAllowed();
        if (primary_) {
            uint256 lp_ = _bptForDetfShares(funded_, false);
            _burnDetf(address(this), funded_);
            (self_, stable_, common_) = _exitReserveProportional(lp_);
            paid_ = funded_;
        } else {
            paid_ = _reserveSwapExactOut(address(Repo._layoutStruct().reservePool), IERC20(address(this)), p_.poolBptToken, p_.poolBptAmountOut, funded_);
            if (p_.exitFromStablePool) stable_ = p_.poolBptAmountOut; else common_ = p_.poolBptAmountOut;
        }
        uint256 usedBpt_ = _deliverExactOut(p_, out_, amount_, to_, deadline_);
        if (p_.exitFromStablePool) stable_ -= usedBpt_; else common_ -= usedBpt_;
        if (self_ != 0 || stable_ != 0 || common_ != 0) _joinReserve(self_, stable_, common_, false);
    }
    function _deliverExactOut(UnwindPreviewSelection memory p_, IERC20 out_, uint256 amount_, address to_, uint256 deadline_)
        internal returns (uint256 used_)
    {
        if (out_ == p_.poolBptToken) { out_.safeTransfer(to_, amount_); return amount_; }
        if (p_.routeIndex == type(uint256).max) {
            IStandardExchangeOut host_ = _selectedPoolExitPricerOut(p_.exitFromStablePool);
            p_.poolBptToken.safeTransfer(address(host_), p_.poolBptAmountOut);
            return host_.exchangeOut(p_.poolBptToken, p_.poolBptAmountOut, out_, amount_, to_, true, deadline_);
        }
        Repo.RouteConfig storage route_ = Repo._layoutStruct().routes[p_.routeIndex];
        used_ = _executeComposedPoolExitExactOutShared(p_.exitFromStablePool, p_.poolBptToken, p_.poolBptAmountOut, route_.vaultToken, p_.vaultTokenAmountOut, deadline_);
        if (out_ == route_.vaultToken) { out_.safeTransfer(to_, amount_); return used_; }
        // Transfer only this route's quoted shares. Existing held balances are never spend credit.
        IStandardExchangeOut underlying_ = IStandardExchangeOut(address(route_.underlyingVault));
        route_.vaultToken.safeTransfer(address(underlying_), p_.vaultTokenAmountOut);
        uint256 consumed_ = underlying_.exchangeOut(route_.vaultToken, p_.vaultTokenAmountOut, out_, amount_, to_, true, deadline_);
        uint256 remainder_ = p_.vaultTokenAmountOut - consumed_;
        if (remainder_ != 0) route_.vaultToken.safeTransfer(msg.sender, remainder_);
    }
    function _tokensIn() internal view returns (address[] memory a_) {
        Repo.Storage storage s_ = Repo._layoutStruct();
        a_ = new address[](s_.routes.length + 2);
        a_[0] = address(s_.stablePool); a_[1] = address(s_.commonPool); uint256 n_ = 2;
        for (uint256 i_; i_ < s_.routes.length; ++i_) n_ = _appendUnique(a_, n_, address(s_.routes[i_].baseToken));
        assembly { mstore(a_, n_) }
    }
    function _tokensOut() internal view returns (address[] memory a_) {
        Repo.Storage storage s_ = Repo._layoutStruct();
        a_ = new address[](s_.routes.length * 2 + 3);
        a_[0] = address(s_.stablePool); a_[1] = address(s_.commonPool); a_[2] = address(s_.rateAsset); uint256 n_ = 3;
        for (uint256 i_; i_ < s_.routes.length; ++i_) {
            n_ = _appendUnique(a_, n_, address(s_.routes[i_].baseToken));
            n_ = _appendUnique(a_, n_, address(s_.routes[i_].vaultToken));
        }
        assembly { mstore(a_, n_) }
    }
    function _appendUnique(address[] memory a_, uint256 n_, address value_) internal pure returns (uint256) {
        for (uint256 i_; i_ < n_; ++i_) if (a_[i_] == value_) return n_;
        a_[n_] = value_; return n_ + 1;
    }
}
