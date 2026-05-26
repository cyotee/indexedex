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

        ComposedStableCommonDetfRepo.Storage storage layoutStruct = ComposedStableCommonDetfRepo._layoutStruct();
        WeightedPoolDynamicData memory dynamicData = _weightedPoolDynamicData(layoutStruct._reservePool());
        uint256[] memory weights = _weightedPoolWeights(layoutStruct._reservePool());

        uint256 tokenInIndex = layoutStruct._detfIndex();
        uint256 tokenOutIndex = exitFromStablePool_ ? layoutStruct._stablePoolBptIndex() : layoutStruct._commonPoolBptIndex();

        if (
            !dynamicData.isPoolInitialized || dynamicData.balancesLiveScaled18.length <= tokenInIndex
                || dynamicData.balancesLiveScaled18.length <= tokenOutIndex || weights.length <= tokenInIndex
                || weights.length <= tokenOutIndex || dynamicData.balancesLiveScaled18[tokenInIndex] == 0
                || dynamicData.balancesLiveScaled18[tokenOutIndex] == 0
        ) {
            return 0;
        }

        amountOut_ = BalancerV3WeightedPoolQuote.computeOutGivenExactInAfterFee(
            dynamicData.balancesLiveScaled18[tokenInIndex],
            weights[tokenInIndex],
            dynamicData.balancesLiveScaled18[tokenOutIndex],
            weights[tokenOutIndex],
            detfAmountIn_,
            dynamicData.staticSwapFeePercentage
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

        ComposedStableCommonDetfRepo.Storage storage layoutStruct = ComposedStableCommonDetfRepo._layoutStruct();
        WeightedPoolDynamicData memory dynamicData = _weightedPoolDynamicData(layoutStruct._reservePool());
        uint256[] memory weights = _weightedPoolWeights(layoutStruct._reservePool());

        uint256 tokenInIndex = layoutStruct._detfIndex();
        uint256 tokenOutIndex = exitFromStablePool_ ? layoutStruct._stablePoolBptIndex() : layoutStruct._commonPoolBptIndex();

        if (
            !dynamicData.isPoolInitialized || dynamicData.balancesLiveScaled18.length <= tokenInIndex
                || dynamicData.balancesLiveScaled18.length <= tokenOutIndex || weights.length <= tokenInIndex
                || weights.length <= tokenOutIndex || dynamicData.balancesLiveScaled18[tokenInIndex] == 0
                || dynamicData.balancesLiveScaled18[tokenOutIndex] <= poolBptAmountOut_
        ) {
            return 0;
        }

        amountIn_ = BalancerV3WeightedPoolQuote.computeInGivenExactOutBeforeFee(
            dynamicData.balancesLiveScaled18[tokenInIndex],
            weights[tokenInIndex],
            dynamicData.balancesLiveScaled18[tokenOutIndex],
            weights[tokenOutIndex],
            poolBptAmountOut_,
            dynamicData.staticSwapFeePercentage
        );
    }

    function _previewMostLiquidUnwindSelection(IERC20 tokenOut_, uint256 amountOut_)
        internal
        view
        returns (UnwindPreviewSelection memory selection_)
    {
        ComposedStableCommonDetfRepo.Storage storage layoutStruct = ComposedStableCommonDetfRepo._layoutStruct();
        uint256 routeCount = layoutStruct._routeCount();
        uint256 bestLiquidity;
        bool foundPath;

        for (uint256 i = 0; i < routeCount; i++) {
            ComposedStableCommonDetfRepo.RouteConfig storage route = layoutStruct._routeAt(i);
            bool directVaultTokenExit = address(route.vaultToken) == address(tokenOut_);
            if (!directVaultTokenExit && address(route.baseToken) != address(tokenOut_)) {
                continue;
            }

            uint256 vaultTokenAmountOut;
            if (directVaultTokenExit) {
                vaultTokenAmountOut = amountOut_;
            } else {
                (bool hasVaultQuote, uint256 quotedVaultTokenAmountOut) = _tryPreviewExchangeOut(
                    address(route.underlyingVault), route.vaultToken, tokenOut_, amountOut_
                );
                if (!hasVaultQuote || quotedVaultTokenAmountOut == 0) {
                    continue;
                }

                vaultTokenAmountOut = quotedVaultTokenAmountOut;
            }

            {
                (uint256 stableLiquidity, UnwindPreviewSelection memory stableSelection) = _previewUnwindCandidate(
                    layoutStruct, route, vaultTokenAmountOut, true
                );
                if (stableSelection.detfAmountIn != 0 && stableLiquidity > bestLiquidity) {
                    foundPath = true;
                    bestLiquidity = stableLiquidity;
                    stableSelection.routeIndex = i;
                    selection_ = stableSelection;
                }
            }

            {
                (uint256 commonLiquidity, UnwindPreviewSelection memory commonSelection) = _previewUnwindCandidate(
                    layoutStruct, route, vaultTokenAmountOut, false
                );
                if (commonSelection.detfAmountIn != 0 && commonLiquidity > bestLiquidity) {
                    foundPath = true;
                    bestLiquidity = commonLiquidity;
                    commonSelection.routeIndex = i;
                    selection_ = commonSelection;
                }
            }
        }

        if (!foundPath) {
            revert IStandardExchangeOut.ExchangeOutNotAvailable();
        }
    }

    function _previewUnwindCandidate(
        ComposedStableCommonDetfRepo.Storage storage layoutStruct_,
        ComposedStableCommonDetfRepo.RouteConfig storage route_,
        uint256 vaultTokenAmountOut_,
        bool exitFromStablePool_
    ) internal view returns (uint256 liquidity_, UnwindPreviewSelection memory selection_) {
        address poolExitPricer;
        IERC20 poolBptToken;
        if (exitFromStablePool_) {
            poolExitPricer = address(layoutStruct_._stablePoolExitPricer());
            poolBptToken = layoutStruct_._stablePoolBpt();
            liquidity_ = _unratedLiquidity(layoutStruct_._stablePool(), route_.stablePoolTokenIndex);
        } else {
            poolExitPricer = address(layoutStruct_._commonPoolExitPricer());
            poolBptToken = layoutStruct_._commonPoolBpt();
            liquidity_ = _unratedLiquidity(layoutStruct_._commonPool(), route_.commonPoolTokenIndex);
        }
        if (liquidity_ == 0) {
            return (0, selection_);
        }

        (bool hasPoolQuote, uint256 poolBptAmountOut) = _tryPreviewExchangeOut(
            poolExitPricer, poolBptToken, route_.vaultToken, vaultTokenAmountOut_
        );
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
        if (exitFromStablePool_) {
            liquidity_ = _unratedLiquidity(layoutStruct_._stablePool(), route_.stablePoolTokenIndex);
            selection_.poolBptToken = layoutStruct_._stablePoolBpt();
            poolExitPricer = address(layoutStruct_._stablePoolExitPricer());
        } else {
            liquidity_ = _unratedLiquidity(layoutStruct_._commonPool(), route_.commonPoolTokenIndex);
            selection_.poolBptToken = layoutStruct_._commonPoolBpt();
            poolExitPricer = address(layoutStruct_._commonPoolExitPricer());
        }
        if (liquidity_ == 0) {
            return (0, selection_);
        }

        selection_.exitFromStablePool = exitFromStablePool_;
        selection_.poolBptAmountOut = _previewReservePoolBptOutForDetfIn(detfAmountIn_, exitFromStablePool_);
        if (selection_.poolBptAmountOut == 0) {
            return (0, selection_);
        }

        (bool hasVaultQuote, uint256 vaultTokenAmountOut) = _tryPreviewExchangeIn(
            poolExitPricer,
            selection_.poolBptToken,
            selection_.poolBptAmountOut,
            route_.vaultToken
        );
        if (!hasVaultQuote || vaultTokenAmountOut == 0) {
            return (0, selection_);
        }

        selection_.vaultTokenAmountOut = vaultTokenAmountOut;
        if (directVaultTokenExit_) {
            selection_.tokenOutAmountOut = vaultTokenAmountOut;
            return (liquidity_, selection_);
        }

        (bool hasUnderlyingQuote, uint256 tokenOutAmountOut) = _tryPreviewExchangeIn(
            address(route_.underlyingVault),
            route_.vaultToken,
            vaultTokenAmountOut,
            tokenOut_
        );
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
        uint256 bestLiquidity;
        bool foundPath;

        for (uint256 i = 0; i < routeCount; i++) {
            ComposedStableCommonDetfRepo.RouteConfig storage route = layoutStruct._routeAt(i);
            bool directVaultTokenExit = address(route.vaultToken) == address(tokenOut_);
            if (!directVaultTokenExit && address(route.baseToken) != address(tokenOut_)) {
                continue;
            }

            {
                (uint256 stableLiquidity, ExactInUnwindSelection memory stableSelection) = _previewExactInUnwindLeg(
                    layoutStruct, route, tokenOut_, detfAmountIn_, true, directVaultTokenExit
                );
                if (stableSelection.tokenOutAmountOut != 0 && stableLiquidity > bestLiquidity) {
                    foundPath = true;
                    bestLiquidity = stableLiquidity;
                    stableSelection.routeIndex = i;
                    selection_ = stableSelection;
                }
            }

            {
                (uint256 commonLiquidity, ExactInUnwindSelection memory commonSelection) = _previewExactInUnwindLeg(
                    layoutStruct, route, tokenOut_, detfAmountIn_, false, directVaultTokenExit
                );
                if (commonSelection.tokenOutAmountOut != 0 && commonLiquidity > bestLiquidity) {
                    foundPath = true;
                    bestLiquidity = commonLiquidity;
                    commonSelection.routeIndex = i;
                    selection_ = commonSelection;
                }
            }
        }

        if (!foundPath) {
            revert IStandardExchangeIn.ExchangeInNotAvailable();
        }
    }

    function _mintDetf(address recipient_, uint256 amount_) internal {
        IERC20MintBurn(address(ComposedStableCommonDetfRepo._detfToken())).mint(recipient_, amount_);
    }
}