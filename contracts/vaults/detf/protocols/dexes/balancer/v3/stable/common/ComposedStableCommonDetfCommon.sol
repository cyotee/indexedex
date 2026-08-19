// SPDX-License-Identifier: BSL-1.1
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

import {IVault} from '@crane/contracts/interfaces/protocols/dexes/balancer/v3/IVault.sol';
import {IDetfErrors} from 'contracts/interfaces/IDetfErrors.sol';
import {ISecurePullErrors} from 'contracts/interfaces/ISecurePullErrors.sol';
import {MultiAssetBasicVaultRepo} from 'contracts/vaults/basic/MultiAssetBasicVaultRepo.sol';
import {IStandardExchangeErrors} from 'contracts/interfaces/IStandardExchangeErrors.sol';
import {DETFMintSplitLib} from 'contracts/vaults/detf/common/core/DETFMintSplitLib.sol';
import {DETFThresholdPolicy, ThresholdMode} from 'contracts/vaults/detf/common/core/DETFThresholdPolicy.sol';
import {DETFProtocolCompoundLib} from 'contracts/vaults/detf/common/core/DETFProtocolCompoundLib.sol';
import {DETFNaturalExpansionLib} from 'contracts/vaults/detf/common/core/DETFNaturalExpansionLib.sol';
import {DETFBondLifecycleLib} from 'contracts/vaults/detf/common/core/DETFBondLifecycleLib.sol';
import {
    DETF_CREATOR_BOND_NFT_ID,
    DETF_FEE_TO_BOND_NFT_ID
} from 'contracts/vaults/detf/common/core/DETFBondNftIds.sol';
import {IVaultFeeOracleQuery} from 'contracts/interfaces/IVaultFeeOracleQuery.sol';
import {IDETF} from 'contracts/interfaces/IDETF.sol';
import {IDetf} from 'contracts/interfaces/detf/IDetf.sol';
import {IDETFNFTVault} from 'contracts/interfaces/IDETFNFTVault.sol';
import {IRebasingClaimToken} from 'contracts/interfaces/IRebasingClaimToken.sol';
import {IDetfSelfNftInventoryPolicy} from 'contracts/vaults/detf/common/inventory/IDetfSelfNftInventoryPolicy.sol';
import {IStandardExchangeIn} from 'contracts/interfaces/IStandardExchangeIn.sol';
import {IStandardExchangeOut} from 'contracts/interfaces/IStandardExchangeOut.sol';
import {BalancerV3WeightedPoolQuote} from '@crane/contracts/protocols/dexes/balancer/v3/utils/BalancerV3WeightedPoolQuote.sol';
import {MetaStableMath} from '@crane/contracts/protocols/perps/pendle/core/StandardizedYield/implementations/BalancerStable/base/MetaStable/MetaStableMath.sol';
import {ComposedStableCommonDetfRepo} from 'contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/ComposedStableCommonDetfRepo.sol';

/// @dev Minimal pool-token surface for Balancer V3 vault address (BalancerPoolToken.getVault).
interface IComposedStableBalancerPoolToken {
    function getVault() external view returns (IVault);
}

abstract contract ComposedStableCommonDetfCommon is IStandardExchangeErrors, IDetfErrors {
    using BetterSafeERC20 for IERC20;
    using ComposedStableCommonDetfRepo for ComposedStableCommonDetfRepo.Storage;

    uint256 internal constant ONE_WAD = 1e18;
    /// @dev Family reserve is always DETF + stable BPT + common BPT (3 legs).
    uint256 internal constant RESERVE_TOKEN_COUNT = 3;

    /// @notice Emitted when detf-owned NFT pending seigniorage DETF is compounded into reserve BPT.
    event ProtocolRewardsCompounded(uint256 detfIn, uint256 bptOut);

    /// @notice Emitted when natural supply expansion mints free DETF into the bond NFT vault.
    event NaturalSupplyExpanded(uint256 mintAmount, uint256 syntheticPrice, uint256 newTimestamp);

    error NotSelf();
    error CompoundJoinProducedZeroBpt();

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
        if (!_isReserveLive()) {
            revert ReservePoolNotInitialized();
        }
    }

    /// @dev Family live probe: reserve pool initialized with non-zero total supply.
    function _isReserveLive() internal view returns (bool live_) {
        WeightedPoolDynamicData memory dynamicData =
            _weightedPoolDynamicData(ComposedStableCommonDetfRepo._reservePool());
        live_ = dynamicData.isPoolInitialized && dynamicData.totalSupply > 0;
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

        (split_.userDetfOut, split_.inventoryDetfOut) =
            DETFMintSplitLib._splitLiveGross(grossDetfOut_, _seigniorageIncentivePercentage());
    }

    function _splitBondAmount(uint256 joinDetf_) internal view returns (MintSplit memory split_) {
        split_.grossDetfOut = joinDetf_;
        if (joinDetf_ == 0) {
            return split_;
        }
        (uint256 user_, uint256 pot_,) = DETFMintSplitLib._splitBond(joinDetf_, _seigniorageIncentivePercentage());
        split_.userDetfOut = user_;
        split_.inventoryDetfOut = pot_;
    }

    function _feeTo() internal view returns (address feeTo_) {
        IVaultFeeOracleQuery oracle_ = ComposedStableCommonDetfRepo._feeOracle();
        if (address(oracle_) == address(0)) return address(0);
        return address(oracle_.feeTo());
    }

    function _requireNotStandingRewardNft(uint256 tokenId_) internal pure {
        if (tokenId_ == DETF_FEE_TO_BOND_NFT_ID || tokenId_ == DETF_CREATOR_BOND_NFT_ID) {
            revert IDetfErrors.DETFNFTRestricted(tokenId_);
        }
    }

    function _ensureReservedBondNftsWired() internal {
        IDETFNFTVault vault_ = ComposedStableCommonDetfRepo._bondNftVault();
        if (address(vault_) == address(0)) return;
        try vault_.reservedBondNftsWired() returns (bool wired_) {
            if (wired_) return;
        } catch {
            return;
        }
        address feeTo_ = _feeTo();
        if (feeTo_ == address(0)) return;
        try vault_.initializeReservedBondNfts(feeTo_, ComposedStableCommonDetfRepo._creator()) {} catch {}
    }

    function _topUpFeeCreatorShares() internal {
        IDETFNFTVault vault_ = ComposedStableCommonDetfRepo._bondNftVault();
        if (address(vault_) == address(0)) return;
        IVaultFeeOracleQuery oracle_ = ComposedStableCommonDetfRepo._feeOracle();
        if (address(oracle_) == address(0)) return;
        (, uint256 f_, uint256 c_) = oracle_.seigniorageSplitOfVault(address(this));
        DETFBondLifecycleLib._topUpFeeCreatorShares(IDetfSelfNftInventoryPolicy(address(vault_)), f_, c_);
    }

    /// @notice Unboosted DETF self-leg for a bond join (D24).
    function _quoteBondJoinDetf(uint256 poolBptAmount_, bool depositToStablePool_)
        internal
        view
        returns (uint256 detfOut_)
    {
        if (poolBptAmount_ == 0) return 0;
        ComposedStableCommonDetfRepo.Storage storage s = ComposedStableCommonDetfRepo._layoutStruct();
        WeightedPoolDynamicData memory dynamic_ = _weightedPoolDynamicData(s.reservePool);
        uint256 inIdx_ = depositToStablePool_ ? s.stablePoolBptIndex : s.commonPoolBptIndex;
        if (
            !dynamic_.isPoolInitialized || dynamic_.totalSupply == 0
                || dynamic_.balancesLiveScaled18.length <= inIdx_
                || dynamic_.balancesLiveScaled18.length <= s.detfIndex
        ) {
            return poolBptAmount_;
        }
        uint256 inBal_ = dynamic_.balancesLiveScaled18[inIdx_];
        uint256 detfBal_ = dynamic_.balancesLiveScaled18[s.detfIndex];
        if (inBal_ == 0) return poolBptAmount_;
        detfOut_ = poolBptAmount_ * detfBal_ / inBal_;
        if (detfOut_ == 0) detfOut_ = poolBptAmount_;
    }

    function _lpHeld() internal view returns (uint256 held_) {
        ComposedStableCommonDetfRepo.Storage storage s = ComposedStableCommonDetfRepo._layoutStruct();
        IERC20 bpt_ = IERC20(address(s.reservePool));
        held_ = bpt_.balanceOf(address(this));
        if (address(s.bondNftVault) != address(0)) {
            held_ += bpt_.balanceOf(address(s.bondNftVault));
        }
    }

    function _bptForDetfShares(uint256 detfShares_) internal view returns (uint256 bptOut_) {
        uint256 supply_ = ComposedStableCommonDetfRepo._detfToken().totalSupply();
        uint256 bpt_ = _lpHeld();
        if (supply_ == 0 || bpt_ == 0) return 0;
        bptOut_ = detfShares_ * bpt_ / supply_;
    }

    function _burnDetf(address from_, uint256 amount_) internal {
        if (amount_ == 0) return;
        IERC20MintBurn(address(ComposedStableCommonDetfRepo._detfToken())).burn(from_, amount_);
    }

    function _previewProportionalDetf(uint256 bptIn_) internal view returns (uint256 detfOut_) {
        if (bptIn_ == 0) return 0;
        ComposedStableCommonDetfRepo.Storage storage s = ComposedStableCommonDetfRepo._layoutStruct();
        WeightedPoolDynamicData memory dynamic_ = _weightedPoolDynamicData(s.reservePool);
        if (!dynamic_.isPoolInitialized || dynamic_.totalSupply == 0) return 0;
        if (dynamic_.balancesLiveScaled18.length <= s.detfIndex) return 0;
        detfOut_ = dynamic_.balancesLiveScaled18[s.detfIndex] * bptIn_ / dynamic_.totalSupply;
    }

    function _previewProportionalExit(uint256 bptIn_)
        internal
        view
        returns (uint256 detfOut_, uint256 stableOut_, uint256 commonOut_)
    {
        if (bptIn_ == 0) return (0, 0, 0);
        ComposedStableCommonDetfRepo.Storage storage s = ComposedStableCommonDetfRepo._layoutStruct();
        WeightedPoolDynamicData memory dynamic_ = _weightedPoolDynamicData(s.reservePool);
        if (!dynamic_.isPoolInitialized || dynamic_.totalSupply == 0) return (0, 0, 0);
        uint256 supply_ = dynamic_.totalSupply;
        if (dynamic_.balancesLiveScaled18.length > s.detfIndex) {
            detfOut_ = dynamic_.balancesLiveScaled18[s.detfIndex] * bptIn_ / supply_;
        }
        if (dynamic_.balancesLiveScaled18.length > s.stablePoolBptIndex) {
            stableOut_ = dynamic_.balancesLiveScaled18[s.stablePoolBptIndex] * bptIn_ / supply_;
        }
        if (dynamic_.balancesLiveScaled18.length > s.commonPoolBptIndex) {
            commonOut_ = dynamic_.balancesLiveScaled18[s.commonPoolBptIndex] * bptIn_ / supply_;
        }
    }

    function _previewMintSplit(uint256 poolBptAmount_, bool depositToStablePool_)
        internal
        view
        returns (MintSplit memory split_)
    {
        split_ = _splitMintAmount(_previewMintAmount(poolBptAmount_, depositToStablePool_));
    }

    /**
     * @dev Reserve-delta secure pull (L-DETF-LOCAL-PUSH / ISecurePullErrors).
     *      pretransferred: claimed <= U = B - R; false: pull delta only (FoT-safe).
     */
    function _secureTokenTransfer(IERC20 token_, uint256 amount_, bool pretransferred_) internal returns (uint256 actualIn_) {
        uint256 R = MultiAssetBasicVaultRepo._reserveOfToken(address(token_));
        uint256 B0 = token_.balanceOf(address(this));
        if (!pretransferred_) {
            token_.safeTransferFrom(msg.sender, address(this), amount_);
            return token_.balanceOf(address(this)) - B0;
        }
        uint256 U = B0 - R;
        if (amount_ > U) {
            revert ISecurePullErrors.TransferDeltaInsufficient(amount_, U);
        }
        return amount_;
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

    function _depositIntoReservePoolShared(
        ComposedStableCommonDetfRepo.Storage storage layoutStruct_,
        RoutedPoolSelection memory selection_,
        uint256 poolBptOut_,
        uint256 deadline_
    ) internal returns (uint256 reservePoolBptOut_) {
        IERC20 reservePoolToken = IERC20(address(ComposedStableCommonDetfRepo._reservePool(layoutStruct_)));
        uint256 balanceBefore = reservePoolToken.balanceOf(address(this));

        // Nested fund: push + pretransferred=true (L-DETF-PUSH-NESTED).
        address reserveRouter_ = address(ComposedStableCommonDetfRepo._reservePoolEntryRouter(layoutStruct_));
        if (poolBptOut_ > 0) selection_.poolBptToken.safeTransfer(reserveRouter_, poolBptOut_);
        ComposedStableCommonDetfRepo._reservePoolEntryRouter(layoutStruct_).exchangeIn(
            selection_.poolBptToken,
            poolBptOut_,
            reservePoolToken,
            0,
            address(this),
            true,
            deadline_
        );

        reservePoolBptOut_ = reservePoolToken.balanceOf(address(this)) - balanceBefore;
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

    /// @dev Live-coupled: false when reserve not initialized. Open short-circuit only via lib.
    function _isMintingAllowed(uint256 syntheticPrice_) internal view returns (bool allowed_) {
        if (!_isReserveLive()) return false;
        allowed_ = DETFThresholdPolicy._isMintingAllowed(
            ComposedStableCommonDetfRepo._thresholdMode(),
            ComposedStableCommonDetfRepo._mintThreshold(),
            syntheticPrice_
        );
    }

    /// @dev Live-coupled: false when reserve not initialized. Open short-circuit only via lib.
    function _isBurningAllowed(uint256 syntheticPrice_) internal view returns (bool allowed_) {
        if (!_isReserveLive()) return false;
        allowed_ = DETFThresholdPolicy._isBurningAllowed(
            ComposedStableCommonDetfRepo._thresholdMode(),
            ComposedStableCommonDetfRepo._burnThreshold(),
            syntheticPrice_
        );
    }

    function _isMintingAllowed() internal view returns (bool allowed_) {
        allowed_ = _isMintingAllowed(_syntheticDetfEthPrice());
    }

    function _isBurningAllowed() internal view returns (bool allowed_) {
        allowed_ = _isBurningAllowed(_syntheticDetfEthPrice());
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

    /* ---------------------------------------------------------------------- */
    /*                     Natural supply expansion (Phase 2)                 */
    /* ---------------------------------------------------------------------- */

    /// @dev Mint-on-update natural expansion into bond NFT vault (same sink as seigniorage inventory).
    ///      Uses only `DETFNaturalExpansionLib`; Open / not-live / not-mint-allowed → zero mint.
    ///      Advances `lastExpansionTimestamp` only when mint > 0. Seeds clock if still zero while live.
    ///      Expansion target is bond-reward DETF (`detfToken`), not the rebasing claim token.
    function _updateExpansionMintOnRewards() internal returns (uint256 mintAmount_) {
        ComposedStableCommonDetfRepo.Storage storage s = ComposedStableCommonDetfRepo._layoutStruct();
        if (!_isReserveLive() || address(s.bondNftVault) == address(0)) {
            return 0;
        }
        // Seed accrual clock on first live touch if not already set at bootstrap.
        if (s.lastExpansionTimestamp == 0) {
            s.lastExpansionTimestamp = block.timestamp;
            return 0;
        }

        DETFNaturalExpansionLib.AccrualInput memory in_;
        in_.isLive = true;
        in_.isPolicyMode = s.thresholdMode == ThresholdMode.Policy;
        in_.isMintAllowed = _isMintingAllowed();
        in_.syntheticPrice = _syntheticDetfEthPrice();
        // Family DETF share is the mintable detfToken (diamond is not the ERC-20).
        in_.totalDetfSupply = s.detfToken.totalSupply();
        in_.lastExpansionTimestamp = s.lastExpansionTimestamp;
        in_.nowTimestamp = block.timestamp;
        in_.closureRatePerSecond = s.expansionClosureRatePerSecond;
        in_.catchUpMaxSeconds = s.expansionCatchUpMaxSeconds;
        in_.catchUpCapBps = s.expansionCatchUpCapBps;

        uint256 newTs_;
        (mintAmount_, newTs_) = DETFNaturalExpansionLib.computeExpansionMint(in_);
        if (mintAmount_ > 0) {
            _mintDetf(address(s.bondNftVault), mintAmount_);
            s.lastExpansionTimestamp = newTs_;
            emit NaturalSupplyExpanded(mintAmount_, in_.syntheticPrice, newTs_);
        }
    }

    /* ---------------------------------------------------------------------- */
    /*                     Protocol seigniorage compound                      */
    /* ---------------------------------------------------------------------- */

    /// @dev Single-sided DETF join into the weighted reserve (DETF leg only).
    ///      Tokens must be held by this diamond; prepaid to Balancer vault then joined via SE router.
    function _joinReserveDetfOnly(uint256 detfAmount_) internal returns (uint256 bptOut_) {
        if (detfAmount_ == 0) {
            return 0;
        }

        ComposedStableCommonDetfRepo.Storage storage layoutStruct = ComposedStableCommonDetfRepo._layoutStruct();
        if (address(layoutStruct.balancerV3Router) == address(0)) {
            return 0;
        }
        address pool_ = address(layoutStruct.reservePool);
        IVault balVault_ = IComposedStableBalancerPoolToken(pool_).getVault();

        uint256[] memory amountsIn_ = new uint256[](RESERVE_TOKEN_COUNT);
        amountsIn_[layoutStruct.detfIndex] = detfAmount_;

        layoutStruct.detfToken.safeTransfer(address(balVault_), detfAmount_);
        bptOut_ = layoutStruct.balancerV3Router.prepayAddLiquidityUnbalanced(pool_, amountsIn_, 0, '');
    }

    /// @dev Best-effort protocol NFT compound for lazy hooks and public surface.
    ///      Preferred pull pattern: atomic self-call harvest+join+BPT credit; join failure rolls back harvest.
    ///      Dust gate + harvest live inside the atomic self-call so mock/incomplete bond vaults
    ///      cannot revert the outer mint/bond path (pendingRewards / detfNFTId outside try would).
    ///      Runs natural expansion mint-on-update first so expansion + protocol share compound in one touch.
    function _tryCompoundProtocolRewards() internal returns (uint256 detfIn_, uint256 bptOut_) {
        ComposedStableCommonDetfRepo.Storage storage layoutStruct = ComposedStableCommonDetfRepo._layoutStruct();
        if (address(layoutStruct.bondNftVault) == address(0) || !_isReserveLive()) {
            return (0, 0);
        }

        // Phase 2: accrue free DETF into bond vault before protocol harvest sees balances.
        _updateExpansionMintOnRewards();

        // External self-call so join (or bond-vault view) revert rolls back harvest.
        try this.compoundProtocolRewardsAtomic() returns (uint256 d_, uint256 b_) {
            detfIn_ = d_;
            bptOut_ = b_;
            if (bptOut_ > 0) {
                emit ProtocolRewardsCompounded(detfIn_, bptOut_);
            }
        } catch {
            return (0, 0);
        }
    }

    /// @notice Atomic harvest → single-sided DETF join → credit BPT to detf NFT. Only self-callable.
    /// @dev Used by `_tryCompoundProtocolRewards` via try/catch for preferred pull atomicity.
    ///      Not permissionless ops surface — reverts unless `msg.sender == address(this)`.
    function compoundProtocolRewardsAtomic() external returns (uint256 detfIn_, uint256 bptOut_) {
        if (msg.sender != address(this)) revert NotSelf();
        return _compoundProtocolRewardsAtomic();
    }

    function _compoundProtocolRewardsAtomic() internal returns (uint256 detfIn_, uint256 bptOut_) {
        ComposedStableCommonDetfRepo.Storage storage layoutStruct = ComposedStableCommonDetfRepo._layoutStruct();
        IDETFNFTVault vault_ = layoutStruct.bondNftVault;
        uint256 protocolId_ = vault_.detfNFTId();

        uint256 pending_ = vault_.pendingRewards(protocolId_);
        if (!DETFProtocolCompoundLib.isCompoundable(pending_)) {
            return (0, 0);
        }

        // Harvest free DETF to this diamond (authorized as owner of bond vault / protocol DETF).
        detfIn_ = vault_.reallocateDetfNftRewards(address(this));
        if (detfIn_ == 0) {
            return (0, 0);
        }

        // DETF self-leg only into weighted reserve; weight skew accepted (PRD §9).
        bptOut_ = _joinReserveDetfOnly(detfIn_);
        if (bptOut_ == 0) revert CompoundJoinProducedZeroBpt();

        DETFBondLifecycleLib._addReservePoolBptToDetfNft(
            IERC20(address(layoutStruct.reservePool)),
            IDetfSelfNftInventoryPolicy(address(vault_)),
            protocolId_,
            bptOut_
        );
        _topUpFeeCreatorShares();
    }

    /* ---------------------------------------------------------------------- */
    /*                     Product-law bond / claim helpers                   */
    /* ---------------------------------------------------------------------- */

    function _requireMature(uint256 tokenId_) internal view {
        uint256 unlock_ = ComposedStableCommonDetfRepo._bondNftVault().unlockTimeOf(tokenId_);
        if (block.timestamp < unlock_) {
            revert ComposedStableCommonDetfRepo.BondNotMature(unlock_);
        }
    }

    function _requireActive(uint256 deadline_, uint256 amount_) internal view {
        if (amount_ == 0) revert ZeroAmount();
        if (block.timestamp > deadline_) {
            revert DeadlineExceeded(deadline_, block.timestamp);
        }
    }

    function _protocolOriginalShares() internal view returns (uint256) {
        IDETFNFTVault vault_ = ComposedStableCommonDetfRepo._bondNftVault();
        if (address(vault_) == address(0)) return 0;
        return vault_.originalSharesOf(vault_.detfNFTId());
    }

    function _userPileReserved() internal view returns (uint256) {
        IDETFNFTVault vault_ = ComposedStableCommonDetfRepo._bondNftVault();
        if (address(vault_) == address(0)) return 0;
        uint256 totalOrig_ = vault_.totalOriginalShares();
        uint256 protocol_ = _protocolOriginalShares();
        return totalOrig_ > protocol_ ? totalOrig_ - protocol_ : 0;
    }

    function _singleSidedJoinDetf(uint256 detfAmount_) internal returns (uint256 bptOut_) {
        bptOut_ = _joinReserveDetfOnly(detfAmount_);
    }

    function _isFamilyBurnToken(IERC20 tokenOut_) internal view returns (bool) {
        if (address(tokenOut_) == address(0)) return false;
        ComposedStableCommonDetfRepo.Storage storage s = ComposedStableCommonDetfRepo._layoutStruct();
        if (address(tokenOut_) == address(s.rateAsset)) return true;
        uint256 routeCount_ = ComposedStableCommonDetfRepo._routeCount(s);
        for (uint256 i; i < routeCount_; ++i) {
            ComposedStableCommonDetfRepo.RouteConfig storage route_ = ComposedStableCommonDetfRepo._routeAt(s, i);
            if (address(tokenOut_) == address(route_.baseToken) || address(tokenOut_) == address(route_.vaultToken)) {
                return true;
            }
        }
        return false;
    }

    function _previewJoinDetfOnly(uint256 detfAmount_) internal view returns (uint256 bptOut_) {
        if (detfAmount_ == 0) return 0;
        ComposedStableCommonDetfRepo.Storage storage s = ComposedStableCommonDetfRepo._layoutStruct();
        WeightedPoolDynamicData memory dynamic_ = _weightedPoolDynamicData(s.reservePool);
        if (!dynamic_.isPoolInitialized || dynamic_.totalSupply == 0) return 0;
        if (dynamic_.balancesLiveScaled18.length <= s.detfIndex) return 0;
        uint256 detfBal_ = dynamic_.balancesLiveScaled18[s.detfIndex];
        if (detfBal_ == 0) return 0;
        bptOut_ = (detfAmount_ * dynamic_.totalSupply) / detfBal_;
    }

    function _previewClaimMinted(uint256 assets_, uint256 totalAssets_) internal view returns (uint256) {
        IRebasingClaimToken claim_ = ComposedStableCommonDetfRepo._rebasingDetfToken();
        if (address(claim_) == address(0)) return 0;
        uint256 totalShares_ = claim_.totalShares();
        uint256 sharesOut_ = totalAssets_ == 0 ? assets_ : (assets_ * totalShares_) / totalAssets_;
        return claim_.convertToClaim(sharesOut_);
    }

    function _previewClaimBptOut(uint256 claimAmount_) internal view returns (uint256 bptOut_) {
        IRebasingClaimToken claim_ = ComposedStableCommonDetfRepo._rebasingDetfToken();
        if (address(claim_) == address(0) || claimAmount_ == 0) return 0;
        uint256 shares_ = claim_.convertToShares(claimAmount_);
        uint256 totalShares_ = claim_.totalShares();
        uint256 totalAssets_ = _protocolOriginalShares();
        if (shares_ == 0 || totalShares_ == 0) return 0;
        bptOut_ = (shares_ * totalAssets_) / totalShares_;
    }

    function _exitReserveProportional(uint256 bptIn_)
        internal
        returns (uint256 detfOut_, uint256 stableBptOut_, uint256 commonBptOut_)
    {
        ComposedStableCommonDetfRepo.Storage storage s = ComposedStableCommonDetfRepo._layoutStruct();
        IERC20 reservePoolToken_ = IERC20(address(s.reservePool));
        reservePoolToken_.forceApprove(address(s.balancerV3Router), bptIn_);
        uint256[] memory minAmountsOut_ = new uint256[](RESERVE_TOKEN_COUNT);
        uint256[] memory amountsOut_ = s.balancerV3Router.prepayRemoveLiquidityProportional(
            address(s.reservePool), bptIn_, minAmountsOut_, ''
        );
        detfOut_ = amountsOut_[s.detfIndex];
        stableBptOut_ = amountsOut_[s.stablePoolBptIndex];
        commonBptOut_ = amountsOut_[s.commonPoolBptIndex];
    }

    function _redepositDetfSelfLeg(uint256 detfAmount_) internal {
        if (detfAmount_ == 0) return;
        ComposedStableCommonDetfRepo.Storage storage s = ComposedStableCommonDetfRepo._layoutStruct();
        uint256 bptBack_ = _singleSidedJoinDetf(detfAmount_);
        if (bptBack_ > 0 && address(s.bondNftVault) != address(0)) {
            s.bondNftVault.addToDETFNFT(s.bondNftVault.detfNFTId(), bptBack_);
        }
    }

    function _exitRedepositSettle(
        uint256 bptIn_,
        IERC20 tokenOut_,
        uint256 minOut_,
        address recipient_,
        uint256 deadline_
    ) internal returns (uint256 amountOut_) {
        (uint256 detfLeg_, uint256 stableBpt_, uint256 commonBpt_) = _exitReserveProportional(bptIn_);
        _redepositDetfSelfLeg(detfLeg_);
        amountOut_ = _consolidatePoolBptsToTokenOut(stableBpt_, commonBpt_, tokenOut_, recipient_, deadline_);
        if (amountOut_ < minOut_) {
            revert SlippageExceeded(minOut_, amountOut_);
        }
    }

    function _consolidatePoolBptsToTokenOut(
        uint256 stableBptAmount_,
        uint256 commonBptAmount_,
        IERC20 tokenOut_,
        address recipient_,
        uint256 deadline_
    ) internal returns (uint256 amountOut_) {
        ComposedStableCommonDetfRepo.Storage storage s = ComposedStableCommonDetfRepo._layoutStruct();
        if (address(tokenOut_) == address(s.rateAsset)) {
            if (stableBptAmount_ != 0) {
                IERC20 stablePoolBpt_ = s.stablePoolBpt;
                address pricer_ = address(s.stablePoolExitPricer);
                stablePoolBpt_.safeTransfer(pricer_, stableBptAmount_);
                amountOut_ += s.stablePoolExitPricer.exchangeIn(
                    stablePoolBpt_, stableBptAmount_, tokenOut_, 0, recipient_, true, deadline_
                );
            }
            if (commonBptAmount_ != 0) {
                IERC20 commonPoolBpt_ = s.commonPoolBpt;
                address pricer_ = address(s.commonPoolExitPricer);
                commonPoolBpt_.safeTransfer(pricer_, commonBptAmount_);
                amountOut_ += s.commonPoolExitPricer.exchangeIn(
                    commonPoolBpt_, commonBptAmount_, tokenOut_, 0, recipient_, true, deadline_
                );
            }
            return amountOut_;
        }

        uint256 routeCount_ = ComposedStableCommonDetfRepo._routeCount(s);
        for (uint256 i; i < routeCount_; ++i) {
            ComposedStableCommonDetfRepo.RouteConfig storage route_ = ComposedStableCommonDetfRepo._routeAt(s, i);
            if (address(tokenOut_) != address(route_.baseToken) && address(tokenOut_) != address(route_.vaultToken)) {
                continue;
            }
            uint256 vaultAmt_;
            if (stableBptAmount_ != 0) {
                vaultAmt_ += _executeComposedPoolExitExactInShared(
                    true, s.stablePoolBpt, stableBptAmount_, route_.vaultToken, deadline_
                );
            }
            if (commonBptAmount_ != 0) {
                vaultAmt_ += _executeComposedPoolExitExactInShared(
                    false, s.commonPoolBpt, commonBptAmount_, route_.vaultToken, deadline_
                );
            }
            return _executeUnderlyingExitExactInShared(route_, tokenOut_, vaultAmt_, recipient_, deadline_);
        }

        revert InvalidRoute(address(0), address(tokenOut_));
    }

    function _previewExitSettle(uint256 bptIn_, IERC20 tokenOut_) internal view returns (uint256 amountOut_) {
        if (bptIn_ == 0 || !_isFamilyBurnToken(tokenOut_)) return 0;
        if (address(tokenOut_) == address(ComposedStableCommonDetfRepo._rateAsset())) {
            return IDetf(address(this)).previewClaimLiquidity(bptIn_);
        }
        return bptIn_;
    }
}