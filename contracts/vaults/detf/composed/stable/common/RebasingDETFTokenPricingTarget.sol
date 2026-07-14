// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                 Balancer V3                                */
/* -------------------------------------------------------------------------- */

import {
    StablePoolDynamicData,
    StablePoolImmutableData,
    IStablePool
} from '@crane/contracts/external/balancer/v3/interfaces/contracts/pool-stable/IStablePool.sol';
import {
    WeightedPoolDynamicData
} from '@crane/contracts/external/balancer/v3/interfaces/contracts/pool-weighted/IWeightedPool.sol';
import {FixedPoint} from '@crane/contracts/external/balancer/v3/solidity-utils/contracts/math/FixedPoint.sol';
import {StableMath} from '@crane/contracts/external/balancer/v3/solidity-utils/contracts/math/StableMath.sol';

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {IERC20} from '@crane/contracts/interfaces/IERC20.sol';
import {Math} from '@crane/contracts/utils/Math.sol';

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IDETF} from 'contracts/interfaces/IDETF.sol';
import {IDETFNFTVault} from 'contracts/interfaces/IDETFNFTVault.sol';
import {IRebasingClaimToken} from 'contracts/interfaces/IRebasingClaimToken.sol';
import {IStandardExchangeIn} from 'contracts/interfaces/IStandardExchangeIn.sol';
import {ComposedStableCommonDetfRepo} from 'contracts/vaults/detf/composed/stable/common/ComposedStableCommonDetfRepo.sol';

contract RebasingDETFTokenPricingTarget is IDETF {
    using ComposedStableCommonDetfRepo for ComposedStableCommonDetfRepo.Storage;
    using FixedPoint for uint256;

    uint256 internal constant ONE_WAD = 1e18;

    function _isContract(address account_) internal view returns (bool) {
        return account_.code.length != 0;
    }

    function bondNftVault() external view returns (address bondNftVault_) {
        bondNftVault_ = address(ComposedStableCommonDetfRepo._bondNftVault());
    }

    function detfNFTId() external view returns (uint256 detfNFTId_) {
        IDETFNFTVault bondNftVault_ = ComposedStableCommonDetfRepo._bondNftVault();
        if (address(bondNftVault_) == address(0) || !_isContract(address(bondNftVault_))) {
            return 0;
        }

        detfNFTId_ = bondNftVault_.detfNFTId();
    }

    function rebasingDetfToken() external view returns (address rebasingDetfToken_) {
        rebasingDetfToken_ = address(ComposedStableCommonDetfRepo._rebasingDetfToken());
    }

    function reservePool() external view returns (address reservePool_) {
        reservePool_ = address(ComposedStableCommonDetfRepo._reservePool());
    }

    function previewRebasingDetfTokenReserveBpt(uint256 rebasingDetfAmount)
        external
        view
        returns (uint256 reserveBptAmount)
    {
        if (rebasingDetfAmount == 0) {
            return 0;
        }

        IDETFNFTVault bondNftVault_ = ComposedStableCommonDetfRepo._bondNftVault();
        IRebasingClaimToken rebasingDetfToken_ = ComposedStableCommonDetfRepo._rebasingDetfToken();

        if (address(bondNftVault_) == address(0) || address(rebasingDetfToken_) == address(0)) {
            return 0;
        }

        uint256 rebasingClaimShares = rebasingDetfToken_.convertToShares(rebasingDetfAmount);
        uint256 totalRebasingClaimShares = rebasingDetfToken_.totalShares();
        uint256 protocolReserveBpt = bondNftVault_.originalSharesOf(bondNftVault_.detfNFTId());

        if (rebasingClaimShares == 0 || totalRebasingClaimShares == 0 || protocolReserveBpt == 0) {
            return 0;
        }

        reserveBptAmount = Math.mulDiv(rebasingClaimShares, protocolReserveBpt, totalRebasingClaimShares);
    }

    function previewRebasingDetfTokenEthValue(uint256 reserveBptAmount) external view returns (uint256 wethValue) {
        if (reserveBptAmount == 0) {
            return 0;
        }

        (uint256 detfAmount, uint256 stablePoolBptAmount, uint256 commonPoolBptAmount) =
            _previewReservePoolDecomposition(reserveBptAmount);

        if (detfAmount == 0 && stablePoolBptAmount == 0 && commonPoolBptAmount == 0) {
            return 0;
        }

        uint256 syntheticPrice = syntheticDetfEthPrice();

        wethValue = previewStablePoolBptEthValue(stablePoolBptAmount) + previewCommonPoolBptEthValue(commonPoolBptAmount);

        if (detfAmount != 0 && syntheticPrice != 0) {
            wethValue += Math.mulDiv(detfAmount, syntheticPrice, ONE_WAD);
        }
    }

    function previewStablePoolBptEthValue(uint256 stablePoolBptAmount) public view returns (uint256 wethValue) {
        ComposedStableCommonDetfRepo.Storage storage layoutStruct = ComposedStableCommonDetfRepo._layoutStruct();
        IERC20 rateAsset = layoutStruct._rateAsset();
        IStandardExchangeIn stablePoolExitPricer = layoutStruct._stablePoolExitPricer();
        IStablePool stablePool = layoutStruct._stablePool();

        if (stablePoolBptAmount == 0 || address(rateAsset) == address(0)) {
            return 0;
        }

        if (address(stablePool) != address(0)) {
            wethValue = _previewStablePoolSingleTokenExit(stablePool, stablePoolBptAmount, rateAsset);
            if (wethValue != 0 || address(stablePoolExitPricer) == address(0)) {
                return wethValue;
            }
        }

        if (address(stablePoolExitPricer) == address(0)) {
            return 0;
        }

        try stablePoolExitPricer.previewExchangeIn(layoutStruct._stablePoolBpt(), stablePoolBptAmount, rateAsset) returns (
            uint256 wethValue_
        ) {
            return wethValue_;
        } catch {
            return 0;
        }
    }

    function previewCommonPoolBptEthValue(uint256 commonPoolBptAmount) public view returns (uint256 wethValue) {
        ComposedStableCommonDetfRepo.Storage storage layoutStruct = ComposedStableCommonDetfRepo._layoutStruct();
        IERC20 rateAsset = layoutStruct._rateAsset();
        IStandardExchangeIn commonPoolExitPricer = layoutStruct._commonPoolExitPricer();
        IStablePool commonPool = layoutStruct._commonPool();

        if (commonPoolBptAmount == 0 || address(rateAsset) == address(0)) {
            return 0;
        }

        if (address(commonPool) != address(0)) {
            wethValue = _previewStablePoolSingleTokenExit(commonPool, commonPoolBptAmount, rateAsset);
            if (wethValue != 0 || address(commonPoolExitPricer) == address(0)) {
                return wethValue;
            }
        }

        if (address(commonPoolExitPricer) == address(0)) {
            return 0;
        }

        try commonPoolExitPricer.previewExchangeIn(layoutStruct._commonPoolBpt(), commonPoolBptAmount, rateAsset) returns (
            uint256 wethValue_
        ) {
            return wethValue_;
        } catch {
            return 0;
        }
    }

    function syntheticDetfEthPrice() public view returns (uint256 wethPerDetf) {
        ComposedStableCommonDetfRepo.Storage storage layoutStruct = ComposedStableCommonDetfRepo._layoutStruct();
        IERC20 detfToken = layoutStruct._detfToken();
        address reservePoolAddress = address(layoutStruct._reservePool());

        if (address(detfToken) == address(0) || reservePoolAddress == address(0)) {
            return 0;
        }

        uint256 reserveBptHeld = IERC20(reservePoolAddress).balanceOf(address(this));
        (uint256 reserveOwnedDetf, uint256 reserveOwnedStableBpt, uint256 reserveOwnedCommonBpt) =
            _previewReservePoolDecomposition(reserveBptHeld);

        uint256 externalSupply;
        uint256 totalSupply = detfToken.totalSupply();
        if (totalSupply <= reserveOwnedDetf) {
            return 0;
        }
        externalSupply = totalSupply - reserveOwnedDetf;

        uint256 externalBackingValue =
            previewStablePoolBptEthValue(reserveOwnedStableBpt) + previewCommonPoolBptEthValue(reserveOwnedCommonBpt);

        if (externalBackingValue == 0) {
            return 0;
        }

        return Math.mulDiv(externalBackingValue, ONE_WAD, externalSupply);
    }

    function previewReservePoolDecomposition(uint256 reserveBptAmount)
        external
        view
        returns (uint256 detfAmount, uint256 stablePoolBptAmount, uint256 commonPoolBptAmount)
    {
        return _previewReservePoolDecomposition(reserveBptAmount);
    }

    function _previewReservePoolDecomposition(uint256 reserveBptAmount)
        internal
        view
        returns (uint256 detfAmount, uint256 stablePoolBptAmount, uint256 commonPoolBptAmount)
    {
        ComposedStableCommonDetfRepo.Storage storage layoutStruct = ComposedStableCommonDetfRepo._layoutStruct();
        if (reserveBptAmount == 0 || address(layoutStruct._reservePool()) == address(0)) {
            return (0, 0, 0);
        }

        WeightedPoolDynamicData memory poolData = layoutStruct._reservePool().getWeightedPoolDynamicData();
        if (poolData.totalSupply == 0 || poolData.balancesLiveScaled18.length <= layoutStruct._commonPoolBptIndex()) {
            return (0, 0, 0);
        }

        detfAmount = Math.mulDiv(poolData.balancesLiveScaled18[layoutStruct._detfIndex()], reserveBptAmount, poolData.totalSupply);
        stablePoolBptAmount =
            Math.mulDiv(poolData.balancesLiveScaled18[layoutStruct._stablePoolBptIndex()], reserveBptAmount, poolData.totalSupply);
        commonPoolBptAmount =
            Math.mulDiv(poolData.balancesLiveScaled18[layoutStruct._commonPoolBptIndex()], reserveBptAmount, poolData.totalSupply);
    }

    function _previewStablePoolSingleTokenExit(IStablePool pool_, uint256 bptAmount_, IERC20 tokenOut_)
        internal
        view
        returns (uint256 amountOut_)
    {
        if (address(pool_) == address(0) || bptAmount_ == 0 || address(tokenOut_) == address(0)) {
            return 0;
        }

        StablePoolDynamicData memory poolData = pool_.getStablePoolDynamicData();
        if (!poolData.isPoolInitialized || poolData.totalSupply == 0 || bptAmount_ >= poolData.totalSupply) {
            return 0;
        }

        StablePoolImmutableData memory immutableData = pool_.getStablePoolImmutableData();
        uint256 tokenIndex = _tokenIndexOf(immutableData.tokens, tokenOut_);
        if (tokenIndex == type(uint256).max) {
            return 0;
        }

        return _calcStablePoolSingleTokenOutGivenExactBptIn(
            poolData.amplificationParameter,
            poolData.balancesLiveScaled18,
            tokenIndex,
            bptAmount_,
            poolData.totalSupply,
            poolData.staticSwapFeePercentage
        );
    }

    function _calcStablePoolSingleTokenOutGivenExactBptIn(
        uint256 amplificationParameter_,
        uint256[] memory balances_,
        uint256 tokenIndex_,
        uint256 bptAmountIn_,
        uint256 bptTotalSupply_,
        uint256 swapFeePercentage_
    ) internal pure returns (uint256 amountOut_) {
        uint256 currentInvariant = StableMath.computeInvariant(amplificationParameter_, balances_);
        if (currentInvariant == 0) {
            return 0;
        }

        uint256 newInvariant = (bptTotalSupply_ - bptAmountIn_).divUp(bptTotalSupply_).mulUp(currentInvariant);
        uint256 newBalanceTokenIndex = StableMath.computeBalance(amplificationParameter_, balances_, newInvariant, tokenIndex_);
        uint256 amountOutWithoutFee = balances_[tokenIndex_] - newBalanceTokenIndex;

        uint256 sumBalances;
        for (uint256 i = 0; i < balances_.length; i++) {
            sumBalances += balances_[i];
        }

        uint256 currentWeight = balances_[tokenIndex_].divDown(sumBalances);
        uint256 taxablePercentage = currentWeight.complement();
        uint256 taxableAmount = amountOutWithoutFee.mulUp(taxablePercentage);
        uint256 nonTaxableAmount = amountOutWithoutFee - taxableAmount;

        amountOut_ = nonTaxableAmount + taxableAmount.mulDown(FixedPoint.ONE - swapFeePercentage_);
    }

    function _tokenIndexOf(IERC20[] memory tokens_, IERC20 token_) internal pure returns (uint256 index_) {
        for (uint256 i = 0; i < tokens_.length; i++) {
            if (address(tokens_[i]) == address(token_)) {
                return i;
            }
        }

        return type(uint256).max;
    }
}