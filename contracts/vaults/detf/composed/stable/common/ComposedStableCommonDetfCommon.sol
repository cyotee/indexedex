// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {
    StablePoolImmutableData,
    StablePoolDynamicData,
    IStablePool
} from '@crane/contracts/external/balancer/v3/interfaces/contracts/pool-stable/IStablePool.sol';
import {
    WeightedPoolDynamicData,
    IWeightedPool
} from '@crane/contracts/external/balancer/v3/interfaces/contracts/pool-weighted/IWeightedPool.sol';
import {IERC20} from '@crane/contracts/interfaces/IERC20.sol';
import {IERC20MintBurn} from '@crane/contracts/interfaces/IERC20MintBurn.sol';
import {BetterSafeERC20} from '@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol';
import {Math} from '@crane/contracts/utils/Math.sol';

import {DETFCommon} from 'contracts/vaults/detf/DETFCommon.sol';
import {DETFMintSplitLib} from 'contracts/vaults/detf/core/DETFMintSplitLib.sol';
import {DETFThresholdPolicy} from 'contracts/vaults/detf/core/DETFThresholdPolicy.sol';
import {IDETF} from 'contracts/interfaces/IDETF.sol';
import {IStandardExchangeIn} from 'contracts/interfaces/IStandardExchangeIn.sol';
import {IStandardExchangeOut} from 'contracts/interfaces/IStandardExchangeOut.sol';
import {BalancerV3WeightedPoolQuote} from '@crane/contracts/protocols/dexes/balancer/v3/utils/BalancerV3WeightedPoolQuote.sol';
import {MetaStableMath} from '@crane/contracts/protocols/perps/pendle/core/StandardizedYield/implementations/BalancerStable/base/MetaStable/MetaStableMath.sol';
import {ComposedStableCommonDetfRepo} from 'contracts/vaults/detf/composed/stable/common/ComposedStableCommonDetfRepo.sol';

abstract contract ComposedStableCommonDetfCommon is DETFCommon {
    using BetterSafeERC20 for IERC20;
    using ComposedStableCommonDetfRepo for ComposedStableCommonDetfRepo.Storage;

    uint256 internal constant ONE_WAD = 1e18;

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

    struct MintSplit {
        uint256 grossDetfOut;
        uint256 userDetfOut;
        uint256 protocolDetfOut;
    }

    function _syntheticDetfEthPrice() internal view virtual returns (uint256 syntheticPrice_) {
        syntheticPrice_ = IDETF(address(this)).syntheticDetfEthPrice();
    }

    function _seigniorageIncentivePercentage() internal view virtual returns (uint256 percentage_) {
        ComposedStableCommonDetfRepo.Storage storage layoutStruct = ComposedStableCommonDetfRepo._layoutStruct();
        if (address(layoutStruct._feeOracle()) == address(0)) {
            return 0;
        }

        percentage_ = layoutStruct._feeOracle().seigniorageIncentivePercentageOfVault(address(this));
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
        WeightedPoolDynamicData memory dynamicData =
            _weightedPoolDynamicData(ComposedStableCommonDetfRepo._reservePool());
        if (!dynamicData.isPoolInitialized || dynamicData.totalSupply == 0) {
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

    function _previewRoutedPoolBpt(IERC20 tokenIn_, uint256 amountIn_)
        internal
        view
        returns (RoutedPoolSelection memory selection_, uint256 vaultTokenOut_, uint256 poolBptOut_)
    {
        ComposedStableCommonDetfRepo.Storage storage layoutStruct = ComposedStableCommonDetfRepo._layoutStruct();
        selection_ = _selectRoutingPath(tokenIn_);
        ComposedStableCommonDetfRepo.RouteConfig storage selectedRoute = layoutStruct._routeAt(selection_.routeIndex);

        vaultTokenOut_ = selectedRoute.underlyingVault.previewExchangeIn(tokenIn_, amountIn_, selectedRoute.vaultToken);
        if (vaultTokenOut_ == 0) {
            return (selection_, 0, 0);
        }

        (bool hasRouterQuote, uint256 quotedPoolBptOut) = _tryPreviewExchangeIn(
            address(selection_.poolRouter), selectedRoute.vaultToken, vaultTokenOut_, selection_.poolBptToken
        );
        if (hasRouterQuote) {
            return (selection_, vaultTokenOut_, quotedPoolBptOut);
        }

        IStablePool routedPool = selection_.depositToStablePool ? layoutStruct._stablePool() : layoutStruct._commonPool();
        uint256 routedPoolTokenIndex =
            selection_.depositToStablePool ? selectedRoute.stablePoolTokenIndex : selectedRoute.commonPoolTokenIndex;

        poolBptOut_ = _previewStablePoolBptOut(routedPool, routedPoolTokenIndex, vaultTokenOut_);
    }

    function _previewMintAmount(uint256 poolBptAmount_, bool depositToStablePool_) internal view returns (uint256 amountOut_) {
        if (poolBptAmount_ == 0) {
            return 0;
        }

        _requireReservePoolInitialized();

        ComposedStableCommonDetfRepo.Storage storage layoutStruct = ComposedStableCommonDetfRepo._layoutStruct();
        WeightedPoolDynamicData memory dynamicData = _weightedPoolDynamicData(layoutStruct._reservePool());
        uint256[] memory weights = _weightedPoolWeights(layoutStruct._reservePool());

        uint256 tokenInIndex = depositToStablePool_ ? layoutStruct._stablePoolBptIndex() : layoutStruct._commonPoolBptIndex();
        uint256 tokenOutIndex = layoutStruct._detfIndex();
        uint256 boostedPoolBptIn = _applySeigniorageBoost(poolBptAmount_);

        if (
            boostedPoolBptIn == 0 || dynamicData.balancesLiveScaled18.length <= tokenInIndex
                || dynamicData.balancesLiveScaled18.length <= tokenOutIndex || weights.length <= tokenInIndex
                || weights.length <= tokenOutIndex || dynamicData.balancesLiveScaled18[tokenInIndex] == 0
                || dynamicData.balancesLiveScaled18[tokenOutIndex] == 0
        ) {
            revert ReservePoolNotInitialized();
        }

        amountOut_ = BalancerV3WeightedPoolQuote.computeOutGivenExactInAfterFee(
            dynamicData.balancesLiveScaled18[tokenInIndex],
            weights[tokenInIndex],
            dynamicData.balancesLiveScaled18[tokenOutIndex],
            weights[tokenOutIndex],
            boostedPoolBptIn,
            dynamicData.staticSwapFeePercentage
        );
    }

    function _applySeigniorageBoost(uint256 amount_) internal view returns (uint256 boostedAmount_) {
        uint256 seignioragePercentage = _seigniorageIncentivePercentage();
        if (seignioragePercentage == 0) {
            return amount_;
        }

        boostedAmount_ = amount_ + Math.mulDiv(amount_, seignioragePercentage, ONE_WAD);
    }

    function _splitMintAmount(uint256 grossDetfOut_) internal view returns (MintSplit memory split_) {
        split_.grossDetfOut = grossDetfOut_;
        if (grossDetfOut_ == 0) {
            return split_;
        }

        (split_.userDetfOut, split_.protocolDetfOut) =
            DETFMintSplitLib._splitHalfSeigniorage(grossDetfOut_, _seigniorageIncentivePercentage());
    }

    function _previewMintSplit(uint256 poolBptAmount_, bool depositToStablePool_)
        internal
        view
        returns (MintSplit memory split_)
    {
        split_ = _splitMintAmount(_previewMintAmount(poolBptAmount_, depositToStablePool_));
    }

    function _secureTokenTransfer(IERC20 token_, uint256 amount_, bool pretransferred_) internal returns (uint256 actualIn_) {
        if (pretransferred_) {
            return amount_;
        }

        uint256 balanceBefore = token_.balanceOf(address(this));
        token_.safeTransferFrom(msg.sender, address(this), amount_);
        actualIn_ = token_.balanceOf(address(this)) - balanceBefore;
    }

    function _approvePermit2Spend(IERC20 token_, uint256 amount_, bool exactOut_) internal {
        if (amount_ == 0) {
            return;
        }

        ComposedStableCommonDetfRepo.Storage storage layoutStruct = ComposedStableCommonDetfRepo._layoutStruct();
        if (
            address(ComposedStableCommonDetfRepo._permit2(layoutStruct)) == address(0)
                || address(ComposedStableCommonDetfRepo._balancerV3Router(layoutStruct)) == address(0)
        ) {
            if (exactOut_) {
                revert IStandardExchangeOut.ExchangeOutNotAvailable();
            }

            revert IStandardExchangeIn.ExchangeInNotAvailable();
        }

        token_.forceApprove(address(ComposedStableCommonDetfRepo._permit2(layoutStruct)), amount_);
        ComposedStableCommonDetfRepo._permit2(layoutStruct).approve(
            address(token_), address(ComposedStableCommonDetfRepo._balancerV3Router(layoutStruct)), uint160(amount_), type(uint48).max
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

    function _executeComposedPoolExitExactInShared(
        bool exitFromStablePool_,
        IERC20 poolBptToken_,
        uint256 poolBptAmountOut_,
        IERC20 vaultToken_,
        uint256 deadline_
    ) internal returns (uint256 vaultTokenAmountOut_) {
        IStandardExchangeIn poolExitPricer = _selectedPoolExitPricerIn(exitFromStablePool_);

        poolBptToken_.safeTransfer(address(poolExitPricer), poolBptAmountOut_);
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

        poolBptToken_.safeTransfer(address(poolExitPricer), poolBptAmountOut_);
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

        route_.vaultToken.transfer(address(route_.underlyingVault), vaultTokenAmountOut_);
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
        vaultTokenAmountIn_ = underlyingVault.exchangeOut(
            route_.vaultToken,
            route_.vaultToken.balanceOf(address(this)),
            tokenOut_,
            amountOut_,
            recipient_,
            true,
            deadline_
        );

        if (route_.vaultToken.balanceOf(address(this)) != 0) {
            revert IStandardExchangeOut.ExchangeOutNotAvailable();
        }
    }

    function _isMintingAllowed(uint256 syntheticPrice_) internal view returns (bool allowed_) {
        allowed_ = DETFThresholdPolicy._isMintingAllowed(ComposedStableCommonDetfRepo._mintThreshold(), syntheticPrice_);
    }

    function _isBurningAllowed(uint256 syntheticPrice_) internal view returns (bool allowed_) {
        allowed_ = DETFThresholdPolicy._isBurningAllowed(ComposedStableCommonDetfRepo._burnThreshold(), syntheticPrice_);
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

    function _previewStablePoolBptOut(IStablePool pool_, uint256 tokenIndex_, uint256 amountIn_)
        internal
        view
        returns (uint256 bptOut_)
    {
        if (address(pool_) == address(0) || amountIn_ == 0) {
            return 0;
        }

        StablePoolDynamicData memory dynamicData = _stablePoolDynamicData(pool_);
        if (
            !dynamicData.isPoolInitialized || dynamicData.totalSupply == 0 || dynamicData.balancesLiveScaled18.length <= tokenIndex_
                || dynamicData.tokenRates.length <= tokenIndex_
        ) {
            return 0;
        }

        StablePoolImmutableData memory immutableData = pool_.getStablePoolImmutableData();
        if (immutableData.decimalScalingFactors.length <= tokenIndex_) {
            return 0;
        }

        uint256[] memory amountsIn = new uint256[](dynamicData.balancesLiveScaled18.length);
        uint256 scaledAmountIn = amountIn_ * immutableData.decimalScalingFactors[tokenIndex_];
        scaledAmountIn = Math.mulDiv(scaledAmountIn, dynamicData.tokenRates[tokenIndex_], ONE_WAD);
        amountsIn[tokenIndex_] = scaledAmountIn;

        return MetaStableMath._calcBptOutGivenExactTokensIn(
            dynamicData.amplificationParameter,
            dynamicData.balancesLiveScaled18,
            amountsIn,
            dynamicData.totalSupply,
            dynamicData.staticSwapFeePercentage
        );
    }

    function _previewReservePoolBptOutForDetfIn(uint256 detfAmountIn_, bool exitFromStablePool_)
        internal
        view
        returns (uint256 amountOut_)
    {
        if (detfAmountIn_ == 0) {
            return 0;
        }

        ReservePoolQuoteContext memory context_ = _reservePoolQuoteContext(exitFromStablePool_);
        if (!_hasReservePoolQuoteLiquidity(context_)) {
            return 0;
        }

        amountOut_ = BalancerV3WeightedPoolQuote.computeOutGivenExactInAfterFee(
            context_.dynamicData.balancesLiveScaled18[context_.tokenInIndex],
            context_.weights[context_.tokenInIndex],
            context_.dynamicData.balancesLiveScaled18[context_.tokenOutIndex],
            context_.weights[context_.tokenOutIndex],
            detfAmountIn_,
            context_.dynamicData.staticSwapFeePercentage
        );
    }

    function _previewReserveDetfInForPoolBptOut(uint256 poolBptAmountOut_, bool exitFromStablePool_)
        internal
        view
        returns (uint256 amountIn_)
    {
        if (poolBptAmountOut_ == 0) {
            return 0;
        }

        ReservePoolQuoteContext memory context_ = _reservePoolQuoteContext(exitFromStablePool_);
        if (!_hasReservePoolQuoteLiquidity(context_)) {
            return 0;
        }

        if (context_.dynamicData.balancesLiveScaled18[context_.tokenOutIndex] <= poolBptAmountOut_) {
            return 0;
        }

        amountIn_ = BalancerV3WeightedPoolQuote.computeInGivenExactOutBeforeFee(
            context_.dynamicData.balancesLiveScaled18[context_.tokenInIndex],
            context_.weights[context_.tokenInIndex],
            context_.dynamicData.balancesLiveScaled18[context_.tokenOutIndex],
            context_.weights[context_.tokenOutIndex],
            poolBptAmountOut_,
            context_.dynamicData.staticSwapFeePercentage
        );
    }

    function _reservePoolQuoteContext(bool exitFromStablePool_)
        internal
        view
        returns (ReservePoolQuoteContext memory context_)
    {
        ComposedStableCommonDetfRepo.Storage storage layoutStruct = ComposedStableCommonDetfRepo._layoutStruct();
        context_.dynamicData = _weightedPoolDynamicData(layoutStruct._reservePool());
        context_.weights = _weightedPoolWeights(layoutStruct._reservePool());
        context_.tokenInIndex = layoutStruct._detfIndex();
        context_.tokenOutIndex = exitFromStablePool_ ? layoutStruct._stablePoolBptIndex() : layoutStruct._commonPoolBptIndex();
    }

    function _hasReservePoolQuoteLiquidity(ReservePoolQuoteContext memory context_)
        internal
        pure
        returns (bool hasLiquidity_)
    {
        hasLiquidity_ = context_.dynamicData.isPoolInitialized
            && context_.dynamicData.balancesLiveScaled18.length > context_.tokenInIndex
            && context_.dynamicData.balancesLiveScaled18.length > context_.tokenOutIndex
            && context_.weights.length > context_.tokenInIndex
            && context_.weights.length > context_.tokenOutIndex
            && context_.dynamicData.balancesLiveScaled18[context_.tokenInIndex] != 0
            && context_.dynamicData.balancesLiveScaled18[context_.tokenOutIndex] != 0;
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

    function _mintDetf(address recipient_, uint256 amount_) internal {
        IERC20MintBurn(address(ComposedStableCommonDetfRepo._detfToken())).mint(recipient_, amount_);
    }
}