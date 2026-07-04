// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                 Balancer V3                                */
/* -------------------------------------------------------------------------- */

import {IVault} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IVault.sol";
import {IWeightedPool} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IWeightedPool.sol";
import {IRateProvider} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRateProvider.sol";
import {FixedPoint} from "@crane/contracts/external/balancer/v3/solidity-utils/contracts/math/FixedPoint.sol";
import {TokenInfo} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/VaultTypes.sol";
import {
    BalancerV3WeightedPoolQuote
} from "@crane/contracts/protocols/dexes/balancer/v3/utils/BalancerV3WeightedPoolQuote.sol";

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20MintBurn} from "@crane/contracts/interfaces/IERC20MintBurn.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {ERC4626Repo} from "@crane/contracts/tokens/ERC4626/ERC4626Repo.sol";
import {BetterSafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {BetterMath} from "@crane/contracts/utils/math/BetterMath.sol";
import {
    BalancerV3VaultAwareRepo
} from "@crane/contracts/protocols/dexes/balancer/v3/vault/BalancerV3VaultAwareRepo.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {DETFCommon} from "contracts/vaults/detf/DETFCommon.sol";
import {DETFBalancerScaleLib} from "contracts/vaults/detf/core/DETFBalancerScaleLib.sol";
import {DETFUsageFeeLib} from "contracts/vaults/detf/core/DETFUsageFeeLib.sol";
import {DETFThresholdPolicy} from "contracts/vaults/detf/core/DETFThresholdPolicy.sol";
import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";
import {ISingleVaultDetf} from "contracts/interfaces/ISingleVaultDetf.sol";
import {IDETFNFTVault} from "contracts/interfaces/IDETFNFTVault.sol";
import {IRICHIR} from "contracts/interfaces/IRICHIR.sol";
import {IStandardExchange} from "contracts/interfaces/IStandardExchange.sol";
import {
    BalancerV38020WeightedPoolMath
} from "contracts/protocols/dexes/balancer/v3/utils/BalancerV38020WeightedPoolMath.sol";
import {SingleVaultDetfRepo} from "contracts/vaults/detf/composed/single/SingleVaultDetfRepo.sol";

abstract contract SingleVaultDetfCommon is DETFCommon {
    using FixedPoint for uint256;
    using BetterSafeERC20 for IERC20;
    using SingleVaultDetfRepo for SingleVaultDetfRepo.Storage;

    uint256 internal constant BALANCER_MAX_OUT_RATIO = 30e16;
    uint256 internal constant MAX_BINARY_SEARCH_ITERATIONS = 32;

    struct ReservePoolData {
        IVault balancerVault;
        IWeightedPool reservePool;
        uint256 reservePoolSwapFee;
        uint256 detfIndex;
        uint256 vaultTokenIndex;
        uint256[] weightsArray;
        uint256 totalSupply;
    }

    struct BondAssets { 
        uint256 wethAmount;
        uint256 vaultShares;
        uint256 detfAmount;
        uint256 bptOut;
    }

    struct BurnQuoteData {
        IVault balancerVault;
        IWeightedPool reservePool;
        uint256 reservePoolSwapFee;
        uint256 detfIndex;
        uint256 vaultTokenIndex;
        uint256 detfWeight;
        uint256 vaultTokenWeight;
        uint256 reservePoolTotalSupply;
        uint256 reservePoolBptHeld;
        uint256[] balancesRaw;
        TokenInfo[] tokenInfo;
        uint256 ownedDetfBalance;
        uint256 ownedReserveVaultBalance;
        uint256 reserveVaultRate;
        uint256 ownedReserveVaultRatedBalance;
    }

    struct MintSplit {
        uint256 grossDetf;
        uint256 userDetf;
        uint256 feeToDetf;
        uint256 bondRewardDetf;
    }

    function _isInitialized() internal view returns (bool) {
        return SingleVaultDetfRepo._layoutStruct().isReservePoolInitialized;
    }

    function _isWethToken(SingleVaultDetfRepo.Storage storage layoutStruct_, IERC20 token_) internal view returns (bool) {
        return address(token_) == address(layoutStruct_.wethToken);
    }

    function _isRichToken(SingleVaultDetfRepo.Storage storage layoutStruct_, IERC20 token_) internal view returns (bool) {
        return address(token_) == address(layoutStruct_.richToken);
    }

    function _isDetfToken(IERC20 token_) internal view returns (bool) {
        return address(token_) == address(this);
    }

    function _isRichirToken(IERC20 token_) internal view returns (bool) {
        return address(token_) == address(SingleVaultDetfRepo._richirToken());
    }

    function _loadReservePoolData(ReservePoolData memory data_) internal view returns (uint256[] memory balancesRaw_) {
        SingleVaultDetfRepo.Storage storage layoutStruct = SingleVaultDetfRepo._layoutStruct();
        data_.balancerVault = BalancerV3VaultAwareRepo._balancerV3Vault();
        data_.reservePool = IWeightedPool(layoutStruct.reservePool);
        data_.reservePoolSwapFee = data_.balancerVault.getStaticSwapFeePercentage(address(data_.reservePool));
        data_.detfIndex = layoutStruct.detfIndex;
        data_.vaultTokenIndex = layoutStruct.vaultTokenIndex;
        data_.weightsArray = data_.reservePool.getNormalizedWeights();
        data_.totalSupply = IERC20(layoutStruct.reservePool).totalSupply();

        (, , balancesRaw_,) = data_.balancerVault.getPoolTokenInfo(address(data_.reservePool));
    }

    function _toLiveScaled18(uint256 rawAmount_, TokenInfo memory info_) internal view returns (uint256 scaled18_) {
        scaled18_ = DETFBalancerScaleLib._toLiveScaled18(rawAmount_, info_);
    }

    function _calcReserveSpotPrice() internal view returns (uint256 spotPrice_) {
        SingleVaultDetfRepo.Storage storage layoutStruct = SingleVaultDetfRepo._layoutStruct();
        ReservePoolData memory data;
        TokenInfo[] memory tokenInfo;
        uint256[] memory balancesRaw;
        data.balancerVault = BalancerV3VaultAwareRepo._balancerV3Vault();
        data.reservePool = IWeightedPool(layoutStruct.reservePool);
        data.reservePoolSwapFee = data.balancerVault.getStaticSwapFeePercentage(address(data.reservePool));
        data.detfIndex = layoutStruct.detfIndex;
        data.vaultTokenIndex = layoutStruct.vaultTokenIndex;
        data.weightsArray = data.reservePool.getNormalizedWeights();
        data.totalSupply = IERC20(layoutStruct.reservePool).totalSupply();
        (, tokenInfo, balancesRaw,) = data.balancerVault.getPoolTokenInfo(address(data.reservePool));

        uint256 detfBalanceScaled18 = _toLiveScaled18(balancesRaw[data.detfIndex], tokenInfo[data.detfIndex]);
        uint256 vaultBalanceScaled18 = _toLiveScaled18(balancesRaw[data.vaultTokenIndex], tokenInfo[data.vaultTokenIndex]);

        if (detfBalanceScaled18 == 0 || vaultBalanceScaled18 == 0) {
            revert PoolImbalanced(vaultBalanceScaled18, detfBalanceScaled18);
        }

        spotPrice_ = BalancerV38020WeightedPoolMath.priceFromReserves(
            vaultBalanceScaled18,
            detfBalanceScaled18,
            layoutStruct.vaultTokenWeight,
            layoutStruct.detfWeight
        );
    }

    function _calcSyntheticPrice() internal view returns (uint256 syntheticPrice_) {
        SingleVaultDetfRepo.Storage storage layoutStruct = SingleVaultDetfRepo._layoutStruct();
        uint256 totalSupply = ERC20Repo._totalSupply();
        if (totalSupply == 0) {
            return 1e18;
        }

        ReservePoolData memory data;
        TokenInfo[] memory tokenInfo;
        uint256[] memory balancesRaw;
        data.balancerVault = BalancerV3VaultAwareRepo._balancerV3Vault();
        data.reservePool = IWeightedPool(layoutStruct.reservePool);
        data.weightsArray = data.reservePool.getNormalizedWeights();
        data.totalSupply = IERC20(layoutStruct.reservePool).totalSupply();
        (, tokenInfo, balancesRaw,) = data.balancerVault.getPoolTokenInfo(address(data.reservePool));

        uint256 reserveBptBalance = IERC20(layoutStruct.reservePool).balanceOf(address(this));
        if (reserveBptBalance == 0 || data.totalSupply == 0) {
            return 1e18;
        }

        uint256 ownedDetf = balancesRaw[layoutStruct.detfIndex] * reserveBptBalance / data.totalSupply;
        uint256 ownedVaultShares = balancesRaw[layoutStruct.vaultTokenIndex] * reserveBptBalance / data.totalSupply;
        uint256 vaultRate = FixedPoint.ONE;
        if (address(tokenInfo[layoutStruct.vaultTokenIndex].rateProvider) != address(0)) {
            vaultRate = tokenInfo[layoutStruct.vaultTokenIndex].rateProvider.getRate();
        }

        uint256 totalReserveValue = ownedDetf + ownedVaultShares.mulDown(vaultRate);

        syntheticPrice_ = totalReserveValue.divDown(totalSupply);
    }

    function _isMintingAllowed(SingleVaultDetfRepo.Storage storage layoutStruct_, uint256 price_) internal view returns (bool) {
        return DETFThresholdPolicy._isMintingAllowed(layoutStruct_.mintThreshold, price_);
    }

    function _isBurningAllowed(SingleVaultDetfRepo.Storage storage layoutStruct_, uint256 price_) internal view returns (bool) {
        return DETFThresholdPolicy._isBurningAllowed(layoutStruct_.burnThreshold, price_);
    }

    function _secureTokenTransfer(IERC20 token_, uint256 amount_, bool pretransferred_) internal returns (uint256 actualIn_) {
        if (pretransferred_) {
            return amount_;
        }

        uint256 balBefore = token_.balanceOf(address(this));
        token_.transferFrom(msg.sender, address(this), amount_);
        actualIn_ = token_.balanceOf(address(this)) - balBefore;
    }

    function _calcProportionalDetfForVaultShares(SingleVaultDetfRepo.Storage storage layoutStruct_, uint256 vaultShares_)
        internal
        view
        returns (uint256 detfAmount_)
    {
        if (IERC20(layoutStruct_.reservePool).totalSupply() == 0) {
            detfAmount_ = _calcInitialPeggedDetfForVaultShares(layoutStruct_, vaultShares_);
            if (detfAmount_ == 0) {
                detfAmount_ = vaultShares_;
            }
            return detfAmount_;
        }

        uint256[] memory balancesRaw;
        (, , balancesRaw,) = BalancerV3VaultAwareRepo._balancerV3Vault().getPoolTokenInfo(layoutStruct_.reservePool);

        if (balancesRaw[layoutStruct_.detfIndex] == 0 || balancesRaw[layoutStruct_.vaultTokenIndex] == 0) {
            detfAmount_ = _calcInitialPeggedDetfForVaultShares(layoutStruct_, vaultShares_);
        } else {
            detfAmount_ = _quoteDetfOutForVaultShares(layoutStruct_, vaultShares_);
        }

        if (detfAmount_ == 0) {
            detfAmount_ = vaultShares_;
        }
    }

    function _calcInitialPeggedDetfForVaultShares(SingleVaultDetfRepo.Storage storage layoutStruct_, uint256 vaultShares_)
        internal
        view
        returns (uint256 detfAmount_)
    {
        uint256 vaultRate = FixedPoint.ONE;
        if (address(layoutStruct_.vaultRateProvider) != address(0)) {
            vaultRate = layoutStruct_.vaultRateProvider.getRate();
        }

        uint256 vaultValue = vaultShares_.mulDown(vaultRate);
        detfAmount_ = vaultValue.mulDivUp(layoutStruct_.detfWeight, layoutStruct_.vaultTokenWeight);
    }

    function _quoteDetfOutForVaultShares(SingleVaultDetfRepo.Storage storage layoutStruct_, uint256 vaultShares_)
        internal
        view
        returns (uint256 detfAmount_)
    {
        IVault balancerVault = BalancerV3VaultAwareRepo._balancerV3Vault();
        TokenInfo[] memory tokenInfo;
        uint256[] memory balancesRaw;
        (, tokenInfo, balancesRaw,) = balancerVault.getPoolTokenInfo(layoutStruct_.reservePool);

        uint256 boostedVaultShares = vaultShares_ + vaultShares_.mulDown(_seigniorageIncentivePercentage(layoutStruct_));
        uint256 detfOutScaled18 = BalancerV3WeightedPoolQuote.computeOutGivenExactInAfterFee(
            _toLiveScaled18(balancesRaw[layoutStruct_.vaultTokenIndex], tokenInfo[layoutStruct_.vaultTokenIndex]),
            layoutStruct_.vaultTokenWeight,
            _toLiveScaled18(balancesRaw[layoutStruct_.detfIndex], tokenInfo[layoutStruct_.detfIndex]),
            layoutStruct_.detfWeight,
            _toLiveScaled18(boostedVaultShares, tokenInfo[layoutStruct_.vaultTokenIndex]),
            balancerVault.getStaticSwapFeePercentage(layoutStruct_.reservePool)
        );

        detfAmount_ = detfOutScaled18.divDown(_tokenRate(tokenInfo[layoutStruct_.detfIndex]));
    }

    function _seigniorageIncentivePercentage(SingleVaultDetfRepo.Storage storage layoutStruct_)
        internal
        view
        returns (uint256 percentage_)
    {
        if (address(layoutStruct_._feeOracle()) == address(0)) {
            return 0;
        }

        percentage_ = layoutStruct_._feeOracle().seigniorageIncentivePercentageOfVault(address(this));
    }

    function _usageFeePercentage(SingleVaultDetfRepo.Storage storage layoutStruct_)
        internal
        view
        returns (uint256 percentage_)
    {
        if (address(layoutStruct_._feeOracle()) == address(0)) {
            return 0;
        }

        percentage_ = layoutStruct_._feeOracle().usageFeeOfVault(address(this));
    }

    function _splitMintedDetf(SingleVaultDetfRepo.Storage storage layoutStruct_, uint256 grossDetf_)
        internal
        view
        returns (MintSplit memory split_)
    {
        split_.grossDetf = grossDetf_;
        if (grossDetf_ == 0) {
            return split_;
        }

        (uint256 remainingAfterFee, uint256 feeToDetf) =
            DETFUsageFeeLib._splitUsageFee(grossDetf_, _usageFeePercentage(layoutStruct_));
        split_.feeToDetf = feeToDetf;
        uint256 halfIncentive = _seigniorageIncentivePercentage(layoutStruct_) / 2;
        split_.bondRewardDetf = remainingAfterFee.mulDown(halfIncentive);
        split_.userDetf = remainingAfterFee - split_.bondRewardDetf;
    }

    function _splitMintedDetfForVaultShares(
        SingleVaultDetfRepo.Storage storage layoutStruct_,
        uint256 vaultShares_
    ) internal view returns (MintSplit memory split_) {
        split_ = _splitMintedDetf(layoutStruct_, _calcProportionalDetfForVaultShares(layoutStruct_, vaultShares_));
    }

    function _tokenRate(TokenInfo memory tokenInfo_) internal view returns (uint256 rate_) {
        rate_ = FixedPoint.ONE;
        if (address(tokenInfo_.rateProvider) != address(0)) {
            rate_ = tokenInfo_.rateProvider.getRate();
        }
    }

    function _addLiquidityToReservePool(
        SingleVaultDetfRepo.Storage storage layoutStruct_,
        uint256 detfAmount_,
        uint256 vaultShares_
    ) internal returns (uint256 bptOut_) {
        address balancerVault = address(BalancerV3VaultAwareRepo._balancerV3Vault());

        if (IERC20(layoutStruct_.reservePool).totalSupply() == 0) {
            IERC20[] memory tokens = new IERC20[](2);
            uint256[] memory exactAmountsIn = new uint256[](2);

            if (address(this) < address(layoutStruct_.wethRichVault)) {
                tokens[0] = IERC20(address(this));
                tokens[1] = IERC20(address(layoutStruct_.wethRichVault));
                exactAmountsIn[0] = detfAmount_;
                exactAmountsIn[1] = vaultShares_;
            } else {
                tokens[0] = IERC20(address(layoutStruct_.wethRichVault));
                tokens[1] = IERC20(address(this));
                exactAmountsIn[0] = vaultShares_;
                exactAmountsIn[1] = detfAmount_;
            }

            if (detfAmount_ != 0) {
                IERC20(address(this)).safeTransfer(balancerVault, detfAmount_);
            }
            if (vaultShares_ != 0) {
                IERC20(address(layoutStruct_.wethRichVault)).safeTransfer(balancerVault, vaultShares_);
            }

            return layoutStruct_.balancerV3PrepayRouter.prepayInitialize(layoutStruct_.reservePool, tokens, exactAmountsIn, 0, "");
        }

        if ((detfAmount_ == 0) != (vaultShares_ == 0)) {
            return _addLiquidityToReservePoolSingleSided(layoutStruct_, detfAmount_, vaultShares_);
        }

        uint256[] memory amountsIn = new uint256[](2);
        amountsIn[layoutStruct_.detfIndex] = detfAmount_;
        amountsIn[layoutStruct_.vaultTokenIndex] = vaultShares_;

        if (detfAmount_ != 0) {
            IERC20(address(this)).safeTransfer(balancerVault, detfAmount_);
        }
        if (vaultShares_ != 0) {
            IERC20(address(layoutStruct_.wethRichVault)).safeTransfer(balancerVault, vaultShares_);
        }

        bptOut_ = layoutStruct_.balancerV3PrepayRouter.prepayAddLiquidityUnbalanced(layoutStruct_.reservePool, amountsIn, 0, "");
    }

    function _addLiquidityToReservePoolSingleSided(
        SingleVaultDetfRepo.Storage storage layoutStruct_,
        uint256 detfAmount_,
        uint256 vaultShares_
    ) internal returns (uint256 bptOut_) {
        bool depositDetf = detfAmount_ != 0;
        uint256 tokenIndex = depositDetf ? layoutStruct_.detfIndex : layoutStruct_.vaultTokenIndex;
        IERC20 depositToken = depositDetf ? IERC20(address(this)) : IERC20(address(layoutStruct_.wethRichVault));
        uint256 remainingRaw = depositDetf ? detfAmount_ : vaultShares_;
        IVault balancerVault = BalancerV3VaultAwareRepo._balancerV3Vault();
        IWeightedPool reservePool_ = IWeightedPool(layoutStruct_.reservePool);
        uint256[] memory weightsArray = reservePool_.getNormalizedWeights();

        while (remainingRaw > 0) {
            uint256 chunkRaw = _singleSidedReserveJoinChunkRaw(
                balancerVault, reservePool_, weightsArray, tokenIndex, remainingRaw
            );
            if (chunkRaw == 0) {
                break;
            }

            bptOut_ += _executeSingleSidedReserveJoinChunk(layoutStruct_, depositToken, tokenIndex, chunkRaw);
            remainingRaw -= chunkRaw;
        }
    }

    function _singleSidedReserveJoinChunkRaw(
        IVault balancerVault_,
        IWeightedPool reservePool_,
        uint256[] memory weightsArray_,
        uint256 tokenIndex_,
        uint256 remainingRaw_
    ) internal view returns (uint256 chunkRaw_) {
        (, TokenInfo[] memory tokenInfo, uint256[] memory balancesRaw,) = balancerVault_.getPoolTokenInfo(address(reservePool_));

        uint256[] memory balancesLiveScaled18 = new uint256[](balancesRaw.length);
        for (uint256 i = 0; i < balancesRaw.length; ++i) {
            balancesLiveScaled18[i] = _toLiveScaled18(balancesRaw[i], tokenInfo[i]);
        }

        uint256 maxChunkScaled18 = balancesLiveScaled18[tokenIndex_].mulDown(30e16);
        uint256 remainingScaled18 = _toLiveScaled18(remainingRaw_, tokenInfo[tokenIndex_]);
        uint256 chunkScaled18 = remainingScaled18 < maxChunkScaled18 ? remainingScaled18 : maxChunkScaled18;
        if (chunkScaled18 == 0) {
            return 0;
        }

        chunkRaw_ = chunkScaled18.divDown(_tokenRate(tokenInfo[tokenIndex_]));
        if (chunkRaw_ == 0) {
            return 0;
        }
        if (chunkRaw_ > remainingRaw_) {
            chunkRaw_ = remainingRaw_;
        }
    }

    function _executeSingleSidedReserveJoinChunk(
        SingleVaultDetfRepo.Storage storage layoutStruct_,
        IERC20 depositToken_,
        uint256 tokenIndex_,
        uint256 chunkRaw_
    ) internal returns (uint256 bptOut_) {
        uint256[] memory amountsIn = new uint256[](2);
        amountsIn[tokenIndex_] = chunkRaw_;
        depositToken_.safeTransfer(address(BalancerV3VaultAwareRepo._balancerV3Vault()), chunkRaw_);
        bptOut_ = layoutStruct_.balancerV3PrepayRouter.prepayAddLiquidityUnbalanced(layoutStruct_.reservePool, amountsIn, 0, "");
    }

    function _previewBptOutForAddLiquidity(
        SingleVaultDetfRepo.Storage storage layoutStruct_,
        uint256 detfAmount_,
        uint256 vaultShares_
    ) internal view returns (uint256 bptOut_) {
        if (IERC20(layoutStruct_.reservePool).totalSupply() == 0) {
            return detfAmount_ + vaultShares_;
        }

        if ((detfAmount_ == 0) != (vaultShares_ == 0)) {
            return _previewBptOutForSingleSidedAddLiquidity(layoutStruct_, detfAmount_, vaultShares_);
        }

        ReservePoolData memory data;
        TokenInfo[] memory tokenInfo;
        uint256[] memory balancesRaw;
        data.balancerVault = BalancerV3VaultAwareRepo._balancerV3Vault();
        data.reservePool = IWeightedPool(layoutStruct_.reservePool);
        data.reservePoolSwapFee = data.balancerVault.getStaticSwapFeePercentage(address(data.reservePool));
        data.detfIndex = layoutStruct_.detfIndex;
        data.vaultTokenIndex = layoutStruct_.vaultTokenIndex;
        data.weightsArray = data.reservePool.getNormalizedWeights();
        data.totalSupply = IERC20(layoutStruct_.reservePool).totalSupply();
        (, tokenInfo, balancesRaw,) = data.balancerVault.getPoolTokenInfo(address(data.reservePool));

        uint256[] memory balancesLiveScaled18 = new uint256[](balancesRaw.length);
        uint256[] memory amountsInScaled18 = new uint256[](balancesRaw.length);
        for (uint256 i = 0; i < balancesRaw.length; ++i) {
            balancesLiveScaled18[i] = _toLiveScaled18(balancesRaw[i], tokenInfo[i]);
        }

        amountsInScaled18[layoutStruct_.detfIndex] = _toLiveScaled18(detfAmount_, tokenInfo[layoutStruct_.detfIndex]);
        amountsInScaled18[layoutStruct_.vaultTokenIndex] = _toLiveScaled18(vaultShares_, tokenInfo[layoutStruct_.vaultTokenIndex]);

        bptOut_ = BalancerV38020WeightedPoolMath.calcBptOutGivenUnbalancedIn(
            balancesLiveScaled18,
            data.weightsArray,
            amountsInScaled18,
            data.totalSupply,
            data.reservePoolSwapFee
        );
    }

    function _previewBptOutForSingleSidedAddLiquidity(
        SingleVaultDetfRepo.Storage storage layoutStruct_,
        uint256 detfAmount_,
        uint256 vaultShares_
    ) internal view returns (uint256 bptOut_) {
        ReservePoolData memory data;
        TokenInfo[] memory tokenInfo;
        uint256[] memory balancesRaw;
        data.balancerVault = BalancerV3VaultAwareRepo._balancerV3Vault();
        data.reservePool = IWeightedPool(layoutStruct_.reservePool);
        data.reservePoolSwapFee = data.balancerVault.getStaticSwapFeePercentage(address(data.reservePool));
        data.detfIndex = layoutStruct_.detfIndex;
        data.vaultTokenIndex = layoutStruct_.vaultTokenIndex;
        data.weightsArray = data.reservePool.getNormalizedWeights();
        data.totalSupply = IERC20(layoutStruct_.reservePool).totalSupply();
        (, tokenInfo, balancesRaw,) = data.balancerVault.getPoolTokenInfo(address(data.reservePool));

        bool depositDetf = detfAmount_ != 0;
        uint256 tokenIndex = depositDetf ? layoutStruct_.detfIndex : layoutStruct_.vaultTokenIndex;
        uint256 remainingScaled18 = depositDetf
            ? _toLiveScaled18(detfAmount_, tokenInfo[tokenIndex])
            : _toLiveScaled18(vaultShares_, tokenInfo[tokenIndex]);

        uint256[] memory balancesLiveScaled18 = new uint256[](balancesRaw.length);
        for (uint256 i = 0; i < balancesRaw.length; ++i) {
            balancesLiveScaled18[i] = _toLiveScaled18(balancesRaw[i], tokenInfo[i]);
        }

        while (remainingScaled18 > 0) {
            uint256 chunkScaled18 = balancesLiveScaled18[tokenIndex].mulDown(30e16);
            if (chunkScaled18 > remainingScaled18) {
                chunkScaled18 = remainingScaled18;
            }
            if (chunkScaled18 == 0) {
                break;
            }

            uint256 chunkBptOut = BalancerV38020WeightedPoolMath.calcBptOutGivenSingleIn(
                balancesLiveScaled18,
                data.weightsArray,
                tokenIndex,
                chunkScaled18,
                data.totalSupply,
                data.reservePoolSwapFee
            );
            if (chunkBptOut == 0) {
                break;
            }

            bptOut_ += chunkBptOut;
            balancesLiveScaled18[tokenIndex] += chunkScaled18;
            data.totalSupply += chunkBptOut;
            remainingScaled18 -= chunkScaled18;
        }
    }

    function _previewRichirMintForBpt(SingleVaultDetfRepo.Storage storage layoutStruct_, uint256 bptOut_)
        internal
        view
        returns (uint256 richirOut_)
    {
        if (bptOut_ == 0) {
            return 0;
        }

        IRICHIR richir = layoutStruct_._richirToken();
        uint256 totalSharesAfter = richir.totalShares() + bptOut_;
        if (totalSharesAfter == 0) {
            return bptOut_;
        }

        uint256 protocolBptAfter = layoutStruct_.detfNFTVault.originalSharesOf(layoutStruct_.detfNFTId) + bptOut_;
        uint256 wethValueAfter = IStandardExchange(address(this)).previewExchangeIn(
            IERC20(layoutStruct_.reservePool),
            protocolBptAfter,
            layoutStruct_.wethToken
        );
        if (wethValueAfter == 0) {
            return bptOut_;
        }

        uint256 rateAfter = wethValueAfter * FixedPoint.ONE / totalSharesAfter;
        if (rateAfter == 0) {
            rateAfter = 1;
        }
        richirOut_ = bptOut_ * rateAfter / FixedPoint.ONE;
    }

    function _mintRichirFromWeth(
        SingleVaultDetfRepo.Storage storage layoutStruct_,
        uint256 wethAmount_,
        address recipient_,
        uint256 deadline_
    ) internal returns (uint256 richirOut_) {
        (, uint256 bptOut) = _depositWethIntoReservePool(layoutStruct_, wethAmount_, deadline_);
        richirOut_ = _mintRichirFromReservePoolBpt(layoutStruct_, bptOut, recipient_);
        _syncLastTotalAssetsFromReservePool(layoutStruct_);
    }

    function _mintRichirFromReservePoolBpt(
        SingleVaultDetfRepo.Storage storage layoutStruct_,
        uint256 bptOut_,
        address recipient_
    ) internal returns (uint256 richirOut_) {
        if (bptOut_ == 0) {
            return 0;
        }

        layoutStruct_.detfNFTVault.addToDETFNFT(layoutStruct_.detfNFTId, bptOut_);
        richirOut_ = layoutStruct_._richirToken().mintFromNFTSale(bptOut_, recipient_);
    }

    function _syncLastTotalAssetsFromReservePool(SingleVaultDetfRepo.Storage storage layoutStruct_) internal {
        ERC4626Repo._setLastTotalAssets(IERC20(layoutStruct_.reservePool).balanceOf(address(this)));
    }

    function _depositWethIntoReservePool(
        SingleVaultDetfRepo.Storage storage layoutStruct_,
        uint256 wethAmount_,
        uint256 deadline_
    ) internal returns (uint256 vaultSharesOut_, uint256 bptOut_) {
        vaultSharesOut_ = _depositWethIntoVaultShares(layoutStruct_, wethAmount_, deadline_);
        bptOut_ = _addLiquidityToReservePool(layoutStruct_, 0, vaultSharesOut_);
    }

    function _convertRichToWeth(
        SingleVaultDetfRepo.Storage storage layoutStruct_,
        uint256 richAmount_,
        uint256 deadline_
    ) internal returns (uint256 wethAmountOut_) {
        layoutStruct_.richToken.safeTransfer(address(layoutStruct_.wethRichVault), richAmount_);
        wethAmountOut_ = layoutStruct_.wethRichVault.exchangeIn(
            layoutStruct_.richToken,
            richAmount_,
            layoutStruct_.wethToken,
            0,
            address(this),
            true,
            deadline_
        );
    }

    function _depositWethIntoVaultShares(
        SingleVaultDetfRepo.Storage storage layoutStruct_,
        uint256 wethAmount_,
        uint256 deadline_
    ) internal returns (uint256 vaultSharesOut_) {
        IERC20(address(layoutStruct_.wethToken)).safeTransfer(address(layoutStruct_.wethRichVault), wethAmount_);
        vaultSharesOut_ = layoutStruct_.wethRichVault.exchangeIn(
            layoutStruct_.wethToken,
            wethAmount_,
            IERC20(address(layoutStruct_.wethRichVault)),
            0,
            address(this),
            true,
            deadline_
        );
    }

    function _previewDetfRedemptionBptIn(uint256 detfAmountIn_) internal view returns (uint256 bptIn_) {
        uint256 vaultSharesTarget = _previewVaultSharesTargetForDetfIn(SingleVaultDetfRepo._layoutStruct(), detfAmountIn_);
        bptIn_ = _previewBptInForProportionalVaultTokenOut(SingleVaultDetfRepo._layoutStruct(), vaultSharesTarget);
    }

    function _previewRichirRedemptionBptIn(SingleVaultDetfRepo.Storage storage layoutStruct_, uint256 richirAmount_)
        internal
        view
        returns (uint256 bptIn_)
    {
        IRICHIR richir = layoutStruct_._richirToken();
        uint256 richirShares = richir.convertToShares(richirAmount_);
        uint256 totalRichirShares = richir.totalShares();
        uint256 protocolNftBpt = layoutStruct_.detfNFTVault.originalSharesOf(layoutStruct_.detfNFTId);

        if (richirShares == 0 || totalRichirShares == 0 || protocolNftBpt == 0) {
            revert ZeroAmount();
        }

        bptIn_ = richirShares * protocolNftBpt / totalRichirShares;
        if (bptIn_ == 0) {
            revert ZeroAmount();
        }
    }

    function _previewReservePoolExitProportional(SingleVaultDetfRepo.Storage storage layoutStruct_, uint256 bptIn_)
        internal
        view
        returns (uint256 detfAmountOut_, uint256 vaultSharesOut_)
    {
        if (bptIn_ == 0) {
            return (0, 0);
        }

        ReservePoolData memory data;
        uint256[] memory balancesRaw = _loadReservePoolData(data);
        if (data.totalSupply == 0) {
            return (0, 0);
        }

        detfAmountOut_ = balancesRaw[layoutStruct_.detfIndex] * bptIn_ / data.totalSupply;
        vaultSharesOut_ = balancesRaw[layoutStruct_.vaultTokenIndex] * bptIn_ / data.totalSupply;
    }

    function _previewVaultSharesTargetForDetfIn(SingleVaultDetfRepo.Storage storage layoutStruct_, uint256 detfAmountIn_)
        internal
        view
        returns (uint256 vaultSharesTarget_)
    {
        if (detfAmountIn_ == 0) {
            return 0;
        }

        BurnQuoteData memory data = _loadBurnQuoteData(layoutStruct_);
        uint256 effectiveDetfIn = _effectiveDetfBurnInput(layoutStruct_, detfAmountIn_);
        uint256 vaultTokensOutRated = BalancerV3WeightedPoolQuote.computeOutGivenExactInAfterFee(
            data.ownedDetfBalance,
            data.detfWeight,
            data.ownedReserveVaultRatedBalance,
            data.vaultTokenWeight,
            effectiveDetfIn,
            data.reservePoolSwapFee
        );

        vaultSharesTarget_ = vaultTokensOutRated.divDown(data.reserveVaultRate);
        if (vaultSharesTarget_ == 0) {
            revert ZeroAmount();
        }
    }

    function _previewDetfRedemptionAmountForVaultSharesOut(
        SingleVaultDetfRepo.Storage storage layoutStruct_,
        uint256 vaultSharesOut_
    ) internal view returns (uint256 detfAmountIn_) {
        if (vaultSharesOut_ == 0) {
            return 0;
        }

        BurnQuoteData memory data = _loadBurnQuoteData(layoutStruct_);
        uint256 vaultTokensOutRated = vaultSharesOut_.mulDown(data.reserveVaultRate);
        uint256 effectiveDetfIn = BalancerV3WeightedPoolQuote.computeInGivenExactOutBeforeFee(
            data.ownedDetfBalance,
            data.detfWeight,
            data.ownedReserveVaultRatedBalance,
            data.vaultTokenWeight,
            vaultTokensOutRated,
            data.reservePoolSwapFee
        );

        detfAmountIn_ = _rawDetfBurnInputFromEffective(layoutStruct_, effectiveDetfIn);
        if (detfAmountIn_ == 0) {
            revert ZeroAmount();
        }
    }

    function _previewBptInForProportionalVaultTokenOut(
        SingleVaultDetfRepo.Storage storage layoutStruct_,
        uint256 vaultSharesOut_
    ) internal view returns (uint256 bptIn_) {
        if (vaultSharesOut_ == 0) {
            return 0;
        }

        ReservePoolData memory data;
        uint256[] memory balancesRaw = _loadReservePoolData(data);
        if (data.totalSupply == 0) {
            revert ZeroAmount();
        }

        uint256 reserveVaultBalance = balancesRaw[layoutStruct_.vaultTokenIndex];
        if (reserveVaultBalance == 0) {
            revert ZeroAmount();
        }

        bptIn_ = vaultSharesOut_.mulDivUp(data.totalSupply, reserveVaultBalance);
        if (bptIn_ == 0) {
            revert ZeroAmount();
        }
    }

    function _previewVaultTokenOutForBptIn(SingleVaultDetfRepo.Storage storage layoutStruct_, uint256 bptIn_)
        internal
        view
        returns (uint256 vaultSharesOut_)
    {
        if (bptIn_ == 0) {
            return 0;
        }

        ReservePoolData memory data;
        TokenInfo[] memory tokenInfo;
        uint256[] memory balancesRaw;
        data.balancerVault = BalancerV3VaultAwareRepo._balancerV3Vault();
        data.reservePool = IWeightedPool(layoutStruct_.reservePool);
        data.reservePoolSwapFee = data.balancerVault.getStaticSwapFeePercentage(address(data.reservePool));
        data.detfIndex = layoutStruct_.detfIndex;
        data.vaultTokenIndex = layoutStruct_.vaultTokenIndex;
        data.weightsArray = data.reservePool.getNormalizedWeights();
        data.totalSupply = IERC20(layoutStruct_.reservePool).totalSupply();
        (, tokenInfo, balancesRaw,) = data.balancerVault.getPoolTokenInfo(address(data.reservePool));

        uint256[] memory balancesLiveScaled18 = new uint256[](balancesRaw.length);
        for (uint256 i = 0; i < balancesRaw.length; ++i) {
            balancesLiveScaled18[i] = _toLiveScaled18(balancesRaw[i], tokenInfo[i]);
        }

        uint256 remainingBptIn = bptIn_;
        while (remainingBptIn > 0) {
            uint256 maxChunkBptIn = data.totalSupply.mulDown(BALANCER_MAX_OUT_RATIO);
            if (maxChunkBptIn == 0) {
                break;
            }

            uint256 chunkBptIn = remainingBptIn < maxChunkBptIn ? remainingBptIn : maxChunkBptIn;
            uint256 vaultOutScaled18 = BalancerV38020WeightedPoolMath.calcSingleOutGivenBptIn(
                balancesLiveScaled18,
                data.weightsArray,
                layoutStruct_.vaultTokenIndex,
                chunkBptIn,
                data.totalSupply,
                data.reservePoolSwapFee
            );
            if (vaultOutScaled18 == 0) {
                break;
            }

            uint256 vaultRate = FixedPoint.ONE;
            if (address(tokenInfo[layoutStruct_.vaultTokenIndex].rateProvider) != address(0)) {
                vaultRate = tokenInfo[layoutStruct_.vaultTokenIndex].rateProvider.getRate();
            }

            vaultSharesOut_ += vaultOutScaled18.divDown(vaultRate);
            balancesLiveScaled18[layoutStruct_.vaultTokenIndex] -= vaultOutScaled18;
            data.totalSupply -= chunkBptIn;
            remainingBptIn -= chunkBptIn;
        }
    }

    function _previewBptInForVaultTokenOut(SingleVaultDetfRepo.Storage storage layoutStruct_, uint256 vaultSharesOut_)
        internal
        view
        returns (uint256 bptIn_)
    {
        if (vaultSharesOut_ == 0) {
            return 0;
        }

        ReservePoolData memory data;
        TokenInfo[] memory tokenInfo;
        uint256[] memory balancesRaw;
        data.balancerVault = BalancerV3VaultAwareRepo._balancerV3Vault();
        data.reservePool = IWeightedPool(layoutStruct_.reservePool);
        data.reservePoolSwapFee = data.balancerVault.getStaticSwapFeePercentage(address(data.reservePool));
        data.detfIndex = layoutStruct_.detfIndex;
        data.vaultTokenIndex = layoutStruct_.vaultTokenIndex;
        data.weightsArray = data.reservePool.getNormalizedWeights();
        data.totalSupply = IERC20(layoutStruct_.reservePool).totalSupply();
        (, tokenInfo, balancesRaw,) = data.balancerVault.getPoolTokenInfo(address(data.reservePool));

        uint256[] memory balancesLiveScaled18 = new uint256[](balancesRaw.length);
        for (uint256 i = 0; i < balancesRaw.length; ++i) {
            balancesLiveScaled18[i] = _toLiveScaled18(balancesRaw[i], tokenInfo[i]);
        }

        uint256 vaultRate = FixedPoint.ONE;
        if (address(tokenInfo[layoutStruct_.vaultTokenIndex].rateProvider) != address(0)) {
            vaultRate = tokenInfo[layoutStruct_.vaultTokenIndex].rateProvider.getRate();
        }

        uint256 vaultOutScaled18 = vaultSharesOut_.mulDown(vaultRate);
        uint256 low = 0;
        uint256 high = data.totalSupply.mulDown(BALANCER_MAX_OUT_RATIO);

        while (low < high) {
            uint256 mid = (low + high + 1) / 2;
            uint256 calculatedOut = BalancerV38020WeightedPoolMath.calcSingleOutGivenBptIn(
                balancesLiveScaled18,
                data.weightsArray,
                layoutStruct_.vaultTokenIndex,
                mid,
                data.totalSupply,
                data.reservePoolSwapFee
            );

            if (calculatedOut >= vaultOutScaled18) {
                high = mid - 1;
            } else {
                low = mid;
            }
        }

        uint256 finalOut = BalancerV38020WeightedPoolMath.calcSingleOutGivenBptIn(
            balancesLiveScaled18,
            data.weightsArray,
            layoutStruct_.vaultTokenIndex,
            low,
            data.totalSupply,
            data.reservePoolSwapFee
        );
        bptIn_ = finalOut < vaultOutScaled18 ? low + 1 : low;
    }

    function _previewDetfRedemptionAmountForBptIn(uint256 bptIn_) internal view returns (uint256 detfAmountIn_) {
        if (bptIn_ == 0) {
            return 0;
        }

        (uint256 detfAmountOut, uint256 vaultSharesOut) =
            _previewReservePoolExitProportional(SingleVaultDetfRepo._layoutStruct(), bptIn_);
        if (vaultSharesOut == 0) {
            revert ZeroAmount();
        }

        detfAmountIn_ = _previewDetfRedemptionAmountForVaultSharesOut(SingleVaultDetfRepo._layoutStruct(), vaultSharesOut);
        if (detfAmountIn_ < detfAmountOut) {
            detfAmountIn_ = detfAmountOut;
        }
    }

    function _previewRichirToWethExact(SingleVaultDetfRepo.Storage storage layoutStruct_, uint256 exactWethOut_)
        internal
        view
        returns (uint256 richirAmountIn_)
    {
        if (exactWethOut_ == 0) {
            return 0;
        }

        IRICHIR richir = layoutStruct_._richirToken();
        uint256 totalRichirShares = richir.totalShares();
        uint256 protocolNftBpt = layoutStruct_.detfNFTVault.originalSharesOf(layoutStruct_.detfNFTId);
        uint256 maxBptIn = IERC20(layoutStruct_.reservePool).totalSupply().mulDown(BALANCER_MAX_OUT_RATIO);
        if (protocolNftBpt < maxBptIn) {
            maxBptIn = protocolNftBpt;
        }
        if (totalRichirShares == 0 || protocolNftBpt == 0 || maxBptIn == 0) {
            revert ZeroAmount();
        }

        uint256 maxRichirShares = maxBptIn * totalRichirShares / protocolNftBpt;
        uint256 maxRichirAmount = richir.convertToRichir(maxRichirShares);
        if (maxRichirAmount == 0) {
            revert ZeroAmount();
        }

        uint256 low = 0;
        uint256 high = exactWethOut_ > maxRichirAmount ? maxRichirAmount : exactWethOut_;
        uint256 wethOutAtHigh = _previewWethOutForRichirIn(layoutStruct_, high);
        if (wethOutAtHigh == 0) {
            revert ZeroAmount();
        }

        uint256 iterations;
        while (wethOutAtHigh < exactWethOut_ && iterations < MAX_BINARY_SEARCH_ITERATIONS) {
            low = high;
            if (high == maxRichirAmount) {
                break;
            }
            high *= 2;
            if (high > maxRichirAmount) {
                high = maxRichirAmount;
            }
            wethOutAtHigh = _previewWethOutForRichirIn(layoutStruct_, high);
            ++iterations;
        }

        if (wethOutAtHigh < exactWethOut_) {
            revert ZeroAmount();
        }

        iterations = 0;
        while (low < high && iterations < MAX_BINARY_SEARCH_ITERATIONS) {
            uint256 mid = (low + high) / 2;
            uint256 wethOutAtMid = _previewWethOutForRichirIn(layoutStruct_, mid);
            if (wethOutAtMid < exactWethOut_) {
                low = mid + 1;
            } else {
                high = mid;
            }
            ++iterations;
        }

        richirAmountIn_ = low;
        uint256 wethOutAtQuote = _previewWethOutForRichirIn(layoutStruct_, richirAmountIn_);
        if (wethOutAtQuote < exactWethOut_) {
            if (richirAmountIn_ == maxRichirAmount) {
                revert ZeroAmount();
            }
            richirAmountIn_ += 1;
        }

        uint256 buffer = richirAmountIn_ / 10_000;
        if (buffer == 0) {
            buffer = 1;
        }
        richirAmountIn_ += buffer;
        if (richirAmountIn_ > maxRichirAmount) {
            richirAmountIn_ = maxRichirAmount;
        }
    }

    function _previewWethOutForRichirIn(SingleVaultDetfRepo.Storage storage layoutStruct_, uint256 richirAmountIn_)
        internal
        view
        returns (uint256 wethOut_)
    {
        uint256 bptIn = _previewRichirRedemptionBptIn(layoutStruct_, richirAmountIn_);
        uint256 vaultSharesOut = _previewVaultTokenOutForBptIn(layoutStruct_, bptIn);
        wethOut_ = layoutStruct_.wethRichVault.previewExchangeIn(
            IERC20(address(layoutStruct_.wethRichVault)),
            vaultSharesOut,
            layoutStruct_.wethToken
        );
    }

    function _exitReservePoolToVaultShares(SingleVaultDetfRepo.Storage storage layoutStruct_, uint256 bptIn_)
        internal
        returns (uint256 vaultSharesOut_)
    {
        IERC20 reservePoolToken = IERC20(layoutStruct_.reservePool);
        uint256 remainingBptIn = bptIn_;

        while (remainingBptIn > 0) {
            uint256 maxChunkBptIn = reservePoolToken.totalSupply().mulDown(BALANCER_MAX_OUT_RATIO);
            if (maxChunkBptIn == 0) {
                break;
            }

            uint256 chunkBptIn = remainingBptIn < maxChunkBptIn ? remainingBptIn : maxChunkBptIn;
            reservePoolToken.forceApprove(address(layoutStruct_.balancerV3PrepayRouter), chunkBptIn);
            vaultSharesOut_ += layoutStruct_.balancerV3PrepayRouter.prepayRemoveLiquiditySingleTokenExactIn(
                layoutStruct_.reservePool,
                chunkBptIn,
                IERC20(address(layoutStruct_.wethRichVault)),
                0,
                ""
            );
            remainingBptIn -= chunkBptIn;
        }
    }

    function _exitReservePoolProportionalForBridge(SingleVaultDetfRepo.Storage storage layoutStruct_, uint256 bptIn_)
        internal
        returns (uint256 detfAmountOut_, uint256 vaultSharesOut_)
    {
        IERC20 reservePoolToken = IERC20(layoutStruct_.reservePool);
        reservePoolToken.forceApprove(address(layoutStruct_.balancerV3PrepayRouter), bptIn_);
        uint256[] memory minAmountsOut = new uint256[](2);
        uint256[] memory amountsOut =
            layoutStruct_.balancerV3PrepayRouter.prepayRemoveLiquidityProportional(layoutStruct_.reservePool, bptIn_, minAmountsOut, "");
        detfAmountOut_ = amountsOut[layoutStruct_.detfIndex];
        vaultSharesOut_ = amountsOut[layoutStruct_.vaultTokenIndex];
    }

    function _redeemVaultSharesToWeth(
        SingleVaultDetfRepo.Storage storage layoutStruct_,
        uint256 vaultSharesIn_,
        address recipient_,
        uint256 deadline_
    ) internal returns (uint256 wethOut_) {
        IERC20 vaultToken = IERC20(address(layoutStruct_.wethRichVault));
        vaultToken.forceApprove(address(layoutStruct_.wethRichVault), vaultSharesIn_);
        wethOut_ = layoutStruct_.wethRichVault.exchangeIn(
            vaultToken,
            vaultSharesIn_,
            layoutStruct_.wethToken,
            0,
            recipient_,
            false,
            deadline_
        );
    }

    function _redepositDetfToReservePool(SingleVaultDetfRepo.Storage storage layoutStruct_, uint256 detfAmount_)
        internal
        returns (uint256 bptOut_)
    {
        if (detfAmount_ == 0) {
            return 0;
        }

        bptOut_ = _addLiquidityToReservePool(layoutStruct_, detfAmount_, 0);
    }

    function _loadBurnQuoteData(SingleVaultDetfRepo.Storage storage layoutStruct_)
        internal
        view
        returns (BurnQuoteData memory data_)
    {
        data_.balancerVault = BalancerV3VaultAwareRepo._balancerV3Vault();
        data_.reservePool = IWeightedPool(layoutStruct_.reservePool);
        data_.reservePoolSwapFee = data_.balancerVault.getStaticSwapFeePercentage(address(data_.reservePool));
        data_.detfIndex = layoutStruct_.detfIndex;
        data_.vaultTokenIndex = layoutStruct_.vaultTokenIndex;
        data_.detfWeight = layoutStruct_.detfWeight;
        data_.vaultTokenWeight = layoutStruct_.vaultTokenWeight;
        data_.reservePoolTotalSupply = IERC20(layoutStruct_.reservePool).totalSupply();
        data_.reservePoolBptHeld = IERC20(layoutStruct_.reservePool).balanceOf(address(this));

        if (data_.reservePoolTotalSupply == 0 || data_.reservePoolBptHeld == 0) {
            revert ZeroAmount();
        }

        (, data_.tokenInfo, data_.balancesRaw,) = data_.balancerVault.getPoolTokenInfo(address(data_.reservePool));
        data_.ownedDetfBalance = BetterMath._mulDivDown(
            data_.balancesRaw[data_.detfIndex], data_.reservePoolBptHeld, data_.reservePoolTotalSupply
        );
        data_.ownedReserveVaultBalance = BetterMath._mulDivDown(
            data_.balancesRaw[data_.vaultTokenIndex], data_.reservePoolBptHeld, data_.reservePoolTotalSupply
        );
        data_.reserveVaultRate = _tokenRate(data_.tokenInfo[data_.vaultTokenIndex]);
        data_.ownedReserveVaultRatedBalance = data_.ownedReserveVaultBalance.mulDown(data_.reserveVaultRate);

        if (data_.ownedDetfBalance == 0 || data_.ownedReserveVaultBalance == 0 || data_.ownedReserveVaultRatedBalance == 0) {
            revert ZeroAmount();
        }
    }

    function _effectiveDetfBurnInput(SingleVaultDetfRepo.Storage storage layoutStruct_, uint256 detfAmountIn_)
        internal
        view
        returns (uint256 effectiveDetfIn_)
    {
        uint256 halfIncentive = _seigniorageIncentivePercentage(layoutStruct_) / 2;
        effectiveDetfIn_ = detfAmountIn_ + detfAmountIn_.mulDown(halfIncentive);
    }

    function _rawDetfBurnInputFromEffective(SingleVaultDetfRepo.Storage storage layoutStruct_, uint256 effectiveDetfIn_)
        internal
        view
        returns (uint256 detfAmountIn_)
    {
        uint256 halfIncentive = _seigniorageIncentivePercentage(layoutStruct_) / 2;
        detfAmountIn_ = effectiveDetfIn_.mulDivUp(FixedPoint.ONE, FixedPoint.ONE + halfIncentive);
    }

    function _bondFromWeth(SingleVaultDetfRepo.Storage storage layoutStruct_, uint256 wethAmount_, uint256 deadline_)
        internal
        returns (BondAssets memory assets_)
    {
        assets_.vaultShares = _depositWethIntoVaultShares(layoutStruct_, wethAmount_, deadline_);
        assets_.wethAmount = wethAmount_;
        assets_ = _bondFromVaultShares(layoutStruct_, assets_.vaultShares);
        assets_.wethAmount = wethAmount_;
    }

    function _bondFromVaultShares(SingleVaultDetfRepo.Storage storage layoutStruct_, uint256 vaultShares_)
        internal
        returns (BondAssets memory assets_)
    {
        assets_.vaultShares = vaultShares_;
        assets_.detfAmount = _calcProportionalDetfForVaultShares(layoutStruct_, assets_.vaultShares);
        ERC20Repo._mint(address(this), assets_.detfAmount);
        assets_.bptOut = _addLiquidityToReservePool(layoutStruct_, assets_.detfAmount, assets_.vaultShares);
    }

}