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
import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";
import {ISingleVaultDetf} from "contracts/interfaces/ISingleVaultDetf.sol";
import {IProtocolNFTVault} from "contracts/interfaces/IProtocolNFTVault.sol";
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
        uint256 chirIndex;
        uint256 vaultTokenIndex;
        uint256[] weightsArray;
        uint256 totalSupply;
    }

    struct BondAssets {
        uint256 wethAmount;
        uint256 vaultShares;
        uint256 chirAmount;
        uint256 bptOut;
    }

    struct BurnQuoteData {
        IVault balancerVault;
        IWeightedPool reservePool;
        uint256 reservePoolSwapFee;
        uint256 chirIndex;
        uint256 vaultTokenIndex;
        uint256 chirWeight;
        uint256 vaultTokenWeight;
        uint256 reservePoolTotalSupply;
        uint256 reservePoolBptHeld;
        uint256[] balancesRaw;
        TokenInfo[] tokenInfo;
        uint256 ownedChirBalance;
        uint256 ownedReserveVaultBalance;
        uint256 reserveVaultRate;
        uint256 ownedReserveVaultRatedBalance;
    }

    function _isInitialized() internal view returns (bool) {
        return SingleVaultDetfRepo._layout().isReservePoolInitialized;
    }

    function _isWethToken(SingleVaultDetfRepo.Storage storage layout_, IERC20 token_) internal view returns (bool) {
        return address(token_) == address(layout_.wethToken);
    }

    function _isRichToken(SingleVaultDetfRepo.Storage storage layout_, IERC20 token_) internal view returns (bool) {
        return address(token_) == address(layout_.richToken);
    }

    function _isChirToken(IERC20 token_) internal view returns (bool) {
        return address(token_) == address(this);
    }

    function _isRichirToken(IERC20 token_) internal view returns (bool) {
        return address(token_) == address(SingleVaultDetfRepo._richirToken());
    }

    function _loadReservePoolData(ReservePoolData memory data_) internal view returns (uint256[] memory balancesRaw_) {
        SingleVaultDetfRepo.Storage storage layout = SingleVaultDetfRepo._layout();
        data_.balancerVault = BalancerV3VaultAwareRepo._balancerV3Vault();
        data_.reservePool = IWeightedPool(layout.reservePool);
        data_.reservePoolSwapFee = data_.balancerVault.getStaticSwapFeePercentage(address(data_.reservePool));
        data_.chirIndex = layout.chirIndex;
        data_.vaultTokenIndex = layout.vaultTokenIndex;
        data_.weightsArray = data_.reservePool.getNormalizedWeights();
        data_.totalSupply = IERC20(layout.reservePool).totalSupply();

        (, , balancesRaw_,) = data_.balancerVault.getPoolTokenInfo(address(data_.reservePool));
    }

    function _toLiveScaled18(uint256 rawAmount_, TokenInfo memory info_) internal view returns (uint256 scaled18_) {
        uint256 rate = FixedPoint.ONE;
        if (address(info_.rateProvider) != address(0)) {
            rate = info_.rateProvider.getRate();
        }
        scaled18_ = rawAmount_.mulDown(rate);
    }

    function _calcReserveSpotPrice() internal view returns (uint256 spotPrice_) {
        SingleVaultDetfRepo.Storage storage layout = SingleVaultDetfRepo._layout();
        ReservePoolData memory data;
        TokenInfo[] memory tokenInfo;
        uint256[] memory balancesRaw;
        data.balancerVault = BalancerV3VaultAwareRepo._balancerV3Vault();
        data.reservePool = IWeightedPool(layout.reservePool);
        data.reservePoolSwapFee = data.balancerVault.getStaticSwapFeePercentage(address(data.reservePool));
        data.chirIndex = layout.chirIndex;
        data.vaultTokenIndex = layout.vaultTokenIndex;
        data.weightsArray = data.reservePool.getNormalizedWeights();
        data.totalSupply = IERC20(layout.reservePool).totalSupply();
        (, tokenInfo, balancesRaw,) = data.balancerVault.getPoolTokenInfo(address(data.reservePool));

        uint256 chirBalanceScaled18 = _toLiveScaled18(balancesRaw[data.chirIndex], tokenInfo[data.chirIndex]);
        uint256 vaultBalanceScaled18 = _toLiveScaled18(balancesRaw[data.vaultTokenIndex], tokenInfo[data.vaultTokenIndex]);

        if (chirBalanceScaled18 == 0 || vaultBalanceScaled18 == 0) {
            revert PoolImbalanced(vaultBalanceScaled18, chirBalanceScaled18);
        }

        spotPrice_ = BalancerV38020WeightedPoolMath.priceFromReserves(
            vaultBalanceScaled18,
            chirBalanceScaled18,
            layout.vaultTokenWeight,
            layout.chirWeight
        );
    }

    function _calcSyntheticPrice() internal view returns (uint256 syntheticPrice_) {
        SingleVaultDetfRepo.Storage storage layout = SingleVaultDetfRepo._layout();
        uint256 totalSupply = ERC20Repo._totalSupply();
        if (totalSupply == 0) {
            return 1e18;
        }

        ReservePoolData memory data;
        TokenInfo[] memory tokenInfo;
        uint256[] memory balancesRaw;
        data.balancerVault = BalancerV3VaultAwareRepo._balancerV3Vault();
        data.reservePool = IWeightedPool(layout.reservePool);
        data.weightsArray = data.reservePool.getNormalizedWeights();
        data.totalSupply = IERC20(layout.reservePool).totalSupply();
        (, tokenInfo, balancesRaw,) = data.balancerVault.getPoolTokenInfo(address(data.reservePool));

        uint256 reserveBptBalance = IERC20(address(ERC4626Repo._reserveAsset())).balanceOf(address(this));
        if (reserveBptBalance == 0 || data.totalSupply == 0) {
            return 1e18;
        }

        uint256 ownedChir = balancesRaw[layout.chirIndex] * reserveBptBalance / data.totalSupply;
        uint256 ownedVaultShares = balancesRaw[layout.vaultTokenIndex] * reserveBptBalance / data.totalSupply;
        uint256 vaultRate = FixedPoint.ONE;
        if (address(tokenInfo[layout.vaultTokenIndex].rateProvider) != address(0)) {
            vaultRate = tokenInfo[layout.vaultTokenIndex].rateProvider.getRate();
        }

        uint256 totalReserveValue = ownedChir + ownedVaultShares.mulDown(vaultRate);

        syntheticPrice_ = totalReserveValue.divDown(totalSupply);
    }

    function _isMintingAllowed(SingleVaultDetfRepo.Storage storage layout_, uint256 price_) internal view returns (bool) {
        return price_ > layout_.mintThreshold;
    }

    function _isBurningAllowed(SingleVaultDetfRepo.Storage storage layout_, uint256 price_) internal view returns (bool) {
        return price_ < layout_.burnThreshold;
    }

    function _secureTokenTransfer(IERC20 token_, uint256 amount_, bool pretransferred_) internal returns (uint256 actualIn_) {
        if (pretransferred_) {
            return amount_;
        }

        uint256 balBefore = token_.balanceOf(address(this));
        token_.transferFrom(msg.sender, address(this), amount_);
        actualIn_ = token_.balanceOf(address(this)) - balBefore;
    }

    function _calcProportionalChirForVaultShares(SingleVaultDetfRepo.Storage storage layout_, uint256 vaultShares_)
        internal
        view
        returns (uint256 chirAmount_)
    {
        if (IERC20(layout_.reservePool).totalSupply() == 0) {
            chirAmount_ = _calcInitialPeggedChirForVaultShares(layout_, vaultShares_);
            if (chirAmount_ == 0) {
                chirAmount_ = vaultShares_;
            }
            return chirAmount_;
        }

        uint256[] memory balancesRaw;
        (, , balancesRaw,) = BalancerV3VaultAwareRepo._balancerV3Vault().getPoolTokenInfo(layout_.reservePool);

        if (balancesRaw[layout_.chirIndex] == 0 || balancesRaw[layout_.vaultTokenIndex] == 0) {
            chirAmount_ = _calcInitialPeggedChirForVaultShares(layout_, vaultShares_);
        } else {
            chirAmount_ = _quoteChirOutForVaultShares(layout_, vaultShares_);
        }

        if (chirAmount_ == 0) {
            chirAmount_ = vaultShares_;
        }
    }

    function _calcInitialPeggedChirForVaultShares(SingleVaultDetfRepo.Storage storage layout_, uint256 vaultShares_)
        internal
        view
        returns (uint256 chirAmount_)
    {
        uint256 vaultRate = FixedPoint.ONE;
        if (address(layout_.vaultRateProvider) != address(0)) {
            vaultRate = layout_.vaultRateProvider.getRate();
        }

        uint256 vaultValue = vaultShares_.mulDown(vaultRate);
        chirAmount_ = vaultValue.mulDivUp(layout_.chirWeight, layout_.vaultTokenWeight);
    }

    function _quoteChirOutForVaultShares(SingleVaultDetfRepo.Storage storage layout_, uint256 vaultShares_)
        internal
        view
        returns (uint256 chirAmount_)
    {
        IVault balancerVault = BalancerV3VaultAwareRepo._balancerV3Vault();
        TokenInfo[] memory tokenInfo;
        uint256[] memory balancesRaw;
        (, tokenInfo, balancesRaw,) = balancerVault.getPoolTokenInfo(layout_.reservePool);

        uint256 boostedVaultShares = vaultShares_ + vaultShares_.mulDown(_seigniorageIncentivePercentage(layout_));
        uint256 chirOutScaled18 = BalancerV3WeightedPoolQuote.computeOutGivenExactInAfterFee(
            _toLiveScaled18(balancesRaw[layout_.vaultTokenIndex], tokenInfo[layout_.vaultTokenIndex]),
            layout_.vaultTokenWeight,
            _toLiveScaled18(balancesRaw[layout_.chirIndex], tokenInfo[layout_.chirIndex]),
            layout_.chirWeight,
            _toLiveScaled18(boostedVaultShares, tokenInfo[layout_.vaultTokenIndex]),
            balancerVault.getStaticSwapFeePercentage(layout_.reservePool)
        );

        chirAmount_ = chirOutScaled18.divDown(_tokenRate(tokenInfo[layout_.chirIndex]));
    }

    function _seigniorageIncentivePercentage(SingleVaultDetfRepo.Storage storage layout_)
        internal
        view
        returns (uint256 percentage_)
    {
        if (address(layout_._feeOracle()) == address(0)) {
            return 0;
        }

        percentage_ = layout_._feeOracle().seigniorageIncentivePercentageOfVault(address(this));
    }

    function _tokenRate(TokenInfo memory tokenInfo_) internal view returns (uint256 rate_) {
        rate_ = FixedPoint.ONE;
        if (address(tokenInfo_.rateProvider) != address(0)) {
            rate_ = tokenInfo_.rateProvider.getRate();
        }
    }

    function _addLiquidityToReservePool(
        SingleVaultDetfRepo.Storage storage layout_,
        uint256 chirAmount_,
        uint256 vaultShares_
    ) internal returns (uint256 bptOut_) {
        address balancerVault = address(BalancerV3VaultAwareRepo._balancerV3Vault());

        if (IERC20(layout_.reservePool).totalSupply() == 0) {
            IERC20[] memory tokens = new IERC20[](2);
            uint256[] memory exactAmountsIn = new uint256[](2);

            if (address(this) < address(layout_.wethRichVault)) {
                tokens[0] = IERC20(address(this));
                tokens[1] = IERC20(address(layout_.wethRichVault));
                exactAmountsIn[0] = chirAmount_;
                exactAmountsIn[1] = vaultShares_;
            } else {
                tokens[0] = IERC20(address(layout_.wethRichVault));
                tokens[1] = IERC20(address(this));
                exactAmountsIn[0] = vaultShares_;
                exactAmountsIn[1] = chirAmount_;
            }

            if (chirAmount_ != 0) {
                IERC20(address(this)).safeTransfer(balancerVault, chirAmount_);
            }
            if (vaultShares_ != 0) {
                IERC20(address(layout_.wethRichVault)).safeTransfer(balancerVault, vaultShares_);
            }

            return layout_.balancerV3PrepayRouter.prepayInitialize(layout_.reservePool, tokens, exactAmountsIn, 0, "");
        }

        if ((chirAmount_ == 0) != (vaultShares_ == 0)) {
            return _addLiquidityToReservePoolSingleSided(layout_, chirAmount_, vaultShares_);
        }

        uint256[] memory amountsIn = new uint256[](2);
        amountsIn[layout_.chirIndex] = chirAmount_;
        amountsIn[layout_.vaultTokenIndex] = vaultShares_;

        if (chirAmount_ != 0) {
            IERC20(address(this)).safeTransfer(balancerVault, chirAmount_);
        }
        if (vaultShares_ != 0) {
            IERC20(address(layout_.wethRichVault)).safeTransfer(balancerVault, vaultShares_);
        }

        bptOut_ = layout_.balancerV3PrepayRouter.prepayAddLiquidityUnbalanced(layout_.reservePool, amountsIn, 0, "");
    }

    function _addLiquidityToReservePoolSingleSided(
        SingleVaultDetfRepo.Storage storage layout_,
        uint256 chirAmount_,
        uint256 vaultShares_
    ) internal returns (uint256 bptOut_) {
        bool depositChir = chirAmount_ != 0;
        uint256 tokenIndex = depositChir ? layout_.chirIndex : layout_.vaultTokenIndex;
        IERC20 depositToken = depositChir ? IERC20(address(this)) : IERC20(address(layout_.wethRichVault));
        uint256 remainingRaw = depositChir ? chirAmount_ : vaultShares_;
        IVault balancerVault = BalancerV3VaultAwareRepo._balancerV3Vault();
        IWeightedPool reservePool = IWeightedPool(layout_.reservePool);
        uint256[] memory weightsArray = reservePool.getNormalizedWeights();

        while (remainingRaw > 0) {
            uint256 chunkRaw = _singleSidedReserveJoinChunkRaw(
                balancerVault, reservePool, weightsArray, tokenIndex, remainingRaw
            );
            if (chunkRaw == 0) {
                break;
            }

            bptOut_ += _executeSingleSidedReserveJoinChunk(layout_, depositToken, tokenIndex, chunkRaw);
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
        SingleVaultDetfRepo.Storage storage layout_,
        IERC20 depositToken_,
        uint256 tokenIndex_,
        uint256 chunkRaw_
    ) internal returns (uint256 bptOut_) {
        uint256[] memory amountsIn = new uint256[](2);
        amountsIn[tokenIndex_] = chunkRaw_;
        depositToken_.safeTransfer(address(BalancerV3VaultAwareRepo._balancerV3Vault()), chunkRaw_);
        bptOut_ = layout_.balancerV3PrepayRouter.prepayAddLiquidityUnbalanced(layout_.reservePool, amountsIn, 0, "");
    }

    function _previewBptOutForAddLiquidity(
        SingleVaultDetfRepo.Storage storage layout_,
        uint256 chirAmount_,
        uint256 vaultShares_
    ) internal view returns (uint256 bptOut_) {
        if (IERC20(layout_.reservePool).totalSupply() == 0) {
            return chirAmount_ + vaultShares_;
        }

        if ((chirAmount_ == 0) != (vaultShares_ == 0)) {
            return _previewBptOutForSingleSidedAddLiquidity(layout_, chirAmount_, vaultShares_);
        }

        ReservePoolData memory data;
        TokenInfo[] memory tokenInfo;
        uint256[] memory balancesRaw;
        data.balancerVault = BalancerV3VaultAwareRepo._balancerV3Vault();
        data.reservePool = IWeightedPool(layout_.reservePool);
        data.reservePoolSwapFee = data.balancerVault.getStaticSwapFeePercentage(address(data.reservePool));
        data.chirIndex = layout_.chirIndex;
        data.vaultTokenIndex = layout_.vaultTokenIndex;
        data.weightsArray = data.reservePool.getNormalizedWeights();
        data.totalSupply = IERC20(layout_.reservePool).totalSupply();
        (, tokenInfo, balancesRaw,) = data.balancerVault.getPoolTokenInfo(address(data.reservePool));

        uint256[] memory balancesLiveScaled18 = new uint256[](balancesRaw.length);
        uint256[] memory amountsInScaled18 = new uint256[](balancesRaw.length);
        for (uint256 i = 0; i < balancesRaw.length; ++i) {
            balancesLiveScaled18[i] = _toLiveScaled18(balancesRaw[i], tokenInfo[i]);
        }

        amountsInScaled18[layout_.chirIndex] = _toLiveScaled18(chirAmount_, tokenInfo[layout_.chirIndex]);
        amountsInScaled18[layout_.vaultTokenIndex] = _toLiveScaled18(vaultShares_, tokenInfo[layout_.vaultTokenIndex]);

        bptOut_ = BalancerV38020WeightedPoolMath.calcBptOutGivenUnbalancedIn(
            balancesLiveScaled18,
            data.weightsArray,
            amountsInScaled18,
            data.totalSupply,
            data.reservePoolSwapFee
        );
    }

    function _previewBptOutForSingleSidedAddLiquidity(
        SingleVaultDetfRepo.Storage storage layout_,
        uint256 chirAmount_,
        uint256 vaultShares_
    ) internal view returns (uint256 bptOut_) {
        ReservePoolData memory data;
        TokenInfo[] memory tokenInfo;
        uint256[] memory balancesRaw;
        data.balancerVault = BalancerV3VaultAwareRepo._balancerV3Vault();
        data.reservePool = IWeightedPool(layout_.reservePool);
        data.reservePoolSwapFee = data.balancerVault.getStaticSwapFeePercentage(address(data.reservePool));
        data.chirIndex = layout_.chirIndex;
        data.vaultTokenIndex = layout_.vaultTokenIndex;
        data.weightsArray = data.reservePool.getNormalizedWeights();
        data.totalSupply = IERC20(layout_.reservePool).totalSupply();
        (, tokenInfo, balancesRaw,) = data.balancerVault.getPoolTokenInfo(address(data.reservePool));

        bool depositChir = chirAmount_ != 0;
        uint256 tokenIndex = depositChir ? layout_.chirIndex : layout_.vaultTokenIndex;
        uint256 remainingScaled18 = depositChir
            ? _toLiveScaled18(chirAmount_, tokenInfo[tokenIndex])
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

    function _previewRichirMintForBpt(SingleVaultDetfRepo.Storage storage layout_, uint256 bptOut_)
        internal
        view
        returns (uint256 richirOut_)
    {
        if (bptOut_ == 0) {
            return 0;
        }

        IRICHIR richir = layout_._richirToken();
        uint256 totalSharesAfter = richir.totalShares() + bptOut_;
        if (totalSharesAfter == 0) {
            return bptOut_;
        }

        uint256 protocolBptAfter = layout_.protocolNFTVault.originalSharesOf(layout_.protocolNFTId) + bptOut_;
        uint256 wethValueAfter = IStandardExchange(address(this)).previewExchangeIn(
            IERC20(layout_.reservePool),
            protocolBptAfter,
            layout_.wethToken
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
        SingleVaultDetfRepo.Storage storage layout_,
        uint256 wethAmount_,
        address recipient_,
        uint256 deadline_
    ) internal returns (uint256 richirOut_) {
        IERC20(address(layout_.wethToken)).safeTransfer(address(layout_.wethRichVault), wethAmount_);
        uint256 vaultShares = layout_.wethRichVault.exchangeIn(
            layout_.wethToken,
            wethAmount_,
            IERC20(address(layout_.wethRichVault)),
            0,
            address(this),
            true,
            deadline_
        );
        uint256 bptOut = _addLiquidityToReservePool(layout_, 0, vaultShares);
        layout_.protocolNFTVault.addToProtocolNFT(layout_.protocolNFTId, bptOut);
        richirOut_ = layout_._richirToken().mintFromNFTSale(bptOut, recipient_);
        ERC4626Repo._setLastTotalAssets(IERC20(layout_.reservePool).balanceOf(address(this)));
    }

    function _previewChirRedemptionBptIn(uint256 chirAmountIn_) internal view returns (uint256 bptIn_) {
        uint256 vaultSharesTarget = _previewVaultSharesTargetForChirIn(SingleVaultDetfRepo._layout(), chirAmountIn_);
        bptIn_ = _previewBptInForProportionalVaultTokenOut(SingleVaultDetfRepo._layout(), vaultSharesTarget);
    }

    function _previewRichirRedemptionBptIn(SingleVaultDetfRepo.Storage storage layout_, uint256 richirAmount_)
        internal
        view
        returns (uint256 bptIn_)
    {
        IRICHIR richir = layout_._richirToken();
        uint256 richirShares = richir.convertToShares(richirAmount_);
        uint256 totalRichirShares = richir.totalShares();
        uint256 protocolNftBpt = layout_.protocolNFTVault.originalSharesOf(layout_.protocolNFTId);

        if (richirShares == 0 || totalRichirShares == 0 || protocolNftBpt == 0) {
            revert ZeroAmount();
        }

        bptIn_ = richirShares * protocolNftBpt / totalRichirShares;
        if (bptIn_ == 0) {
            revert ZeroAmount();
        }
    }

    function _previewReservePoolExitProportional(SingleVaultDetfRepo.Storage storage layout_, uint256 bptIn_)
        internal
        view
        returns (uint256 chirAmountOut_, uint256 vaultSharesOut_)
    {
        if (bptIn_ == 0) {
            return (0, 0);
        }

        ReservePoolData memory data;
        uint256[] memory balancesRaw = _loadReservePoolData(data);
        if (data.totalSupply == 0) {
            return (0, 0);
        }

        chirAmountOut_ = balancesRaw[layout_.chirIndex] * bptIn_ / data.totalSupply;
        vaultSharesOut_ = balancesRaw[layout_.vaultTokenIndex] * bptIn_ / data.totalSupply;
    }

    function _previewVaultSharesTargetForChirIn(SingleVaultDetfRepo.Storage storage layout_, uint256 chirAmountIn_)
        internal
        view
        returns (uint256 vaultSharesTarget_)
    {
        if (chirAmountIn_ == 0) {
            return 0;
        }

        BurnQuoteData memory data = _loadBurnQuoteData(layout_);
        uint256 effectiveChirIn = _effectiveChirBurnInput(layout_, chirAmountIn_);
        uint256 vaultTokensOutRated = BalancerV3WeightedPoolQuote.computeOutGivenExactInAfterFee(
            data.ownedChirBalance,
            data.chirWeight,
            data.ownedReserveVaultRatedBalance,
            data.vaultTokenWeight,
            effectiveChirIn,
            data.reservePoolSwapFee
        );

        vaultSharesTarget_ = vaultTokensOutRated.divDown(data.reserveVaultRate);
        if (vaultSharesTarget_ == 0) {
            revert ZeroAmount();
        }
    }

    function _previewChirRedemptionAmountForVaultSharesOut(
        SingleVaultDetfRepo.Storage storage layout_,
        uint256 vaultSharesOut_
    ) internal view returns (uint256 chirAmountIn_) {
        if (vaultSharesOut_ == 0) {
            return 0;
        }

        BurnQuoteData memory data = _loadBurnQuoteData(layout_);
        uint256 vaultTokensOutRated = vaultSharesOut_.mulDown(data.reserveVaultRate);
        uint256 effectiveChirIn = BalancerV3WeightedPoolQuote.computeInGivenExactOutBeforeFee(
            data.ownedChirBalance,
            data.chirWeight,
            data.ownedReserveVaultRatedBalance,
            data.vaultTokenWeight,
            vaultTokensOutRated,
            data.reservePoolSwapFee
        );

        chirAmountIn_ = _rawChirBurnInputFromEffective(layout_, effectiveChirIn);
        if (chirAmountIn_ == 0) {
            revert ZeroAmount();
        }
    }

    function _previewBptInForProportionalVaultTokenOut(
        SingleVaultDetfRepo.Storage storage layout_,
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

        uint256 reserveVaultBalance = balancesRaw[layout_.vaultTokenIndex];
        if (reserveVaultBalance == 0) {
            revert ZeroAmount();
        }

        bptIn_ = vaultSharesOut_.mulDivUp(data.totalSupply, reserveVaultBalance);
        if (bptIn_ == 0) {
            revert ZeroAmount();
        }
    }

    function _previewVaultTokenOutForBptIn(SingleVaultDetfRepo.Storage storage layout_, uint256 bptIn_)
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
        data.reservePool = IWeightedPool(layout_.reservePool);
        data.reservePoolSwapFee = data.balancerVault.getStaticSwapFeePercentage(address(data.reservePool));
        data.chirIndex = layout_.chirIndex;
        data.vaultTokenIndex = layout_.vaultTokenIndex;
        data.weightsArray = data.reservePool.getNormalizedWeights();
        data.totalSupply = IERC20(layout_.reservePool).totalSupply();
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
                layout_.vaultTokenIndex,
                chunkBptIn,
                data.totalSupply,
                data.reservePoolSwapFee
            );
            if (vaultOutScaled18 == 0) {
                break;
            }

            uint256 vaultRate = FixedPoint.ONE;
            if (address(tokenInfo[layout_.vaultTokenIndex].rateProvider) != address(0)) {
                vaultRate = tokenInfo[layout_.vaultTokenIndex].rateProvider.getRate();
            }

            vaultSharesOut_ += vaultOutScaled18.divDown(vaultRate);
            balancesLiveScaled18[layout_.vaultTokenIndex] -= vaultOutScaled18;
            data.totalSupply -= chunkBptIn;
            remainingBptIn -= chunkBptIn;
        }
    }

    function _previewBptInForVaultTokenOut(SingleVaultDetfRepo.Storage storage layout_, uint256 vaultSharesOut_)
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
        data.reservePool = IWeightedPool(layout_.reservePool);
        data.reservePoolSwapFee = data.balancerVault.getStaticSwapFeePercentage(address(data.reservePool));
        data.chirIndex = layout_.chirIndex;
        data.vaultTokenIndex = layout_.vaultTokenIndex;
        data.weightsArray = data.reservePool.getNormalizedWeights();
        data.totalSupply = IERC20(layout_.reservePool).totalSupply();
        (, tokenInfo, balancesRaw,) = data.balancerVault.getPoolTokenInfo(address(data.reservePool));

        uint256[] memory balancesLiveScaled18 = new uint256[](balancesRaw.length);
        for (uint256 i = 0; i < balancesRaw.length; ++i) {
            balancesLiveScaled18[i] = _toLiveScaled18(balancesRaw[i], tokenInfo[i]);
        }

        uint256 vaultRate = FixedPoint.ONE;
        if (address(tokenInfo[layout_.vaultTokenIndex].rateProvider) != address(0)) {
            vaultRate = tokenInfo[layout_.vaultTokenIndex].rateProvider.getRate();
        }

        uint256 vaultOutScaled18 = vaultSharesOut_.mulDown(vaultRate);
        uint256 low = 0;
        uint256 high = data.totalSupply.mulDown(BALANCER_MAX_OUT_RATIO);

        while (low < high) {
            uint256 mid = (low + high + 1) / 2;
            uint256 calculatedOut = BalancerV38020WeightedPoolMath.calcSingleOutGivenBptIn(
                balancesLiveScaled18,
                data.weightsArray,
                layout_.vaultTokenIndex,
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
            layout_.vaultTokenIndex,
            low,
            data.totalSupply,
            data.reservePoolSwapFee
        );
        bptIn_ = finalOut < vaultOutScaled18 ? low + 1 : low;
    }

    function _previewChirRedemptionAmountForBptIn(uint256 bptIn_) internal view returns (uint256 chirAmountIn_) {
        if (bptIn_ == 0) {
            return 0;
        }

        (uint256 chirAmountOut, uint256 vaultSharesOut) =
            _previewReservePoolExitProportional(SingleVaultDetfRepo._layout(), bptIn_);
        if (vaultSharesOut == 0) {
            revert ZeroAmount();
        }

        chirAmountIn_ = _previewChirRedemptionAmountForVaultSharesOut(SingleVaultDetfRepo._layout(), vaultSharesOut);
        if (chirAmountIn_ < chirAmountOut) {
            chirAmountIn_ = chirAmountOut;
        }
    }

    function _previewRichirToWethExact(SingleVaultDetfRepo.Storage storage layout_, uint256 exactWethOut_)
        internal
        view
        returns (uint256 richirAmountIn_)
    {
        if (exactWethOut_ == 0) {
            return 0;
        }

        IRICHIR richir = layout_._richirToken();
        uint256 totalRichirShares = richir.totalShares();
        uint256 protocolNftBpt = layout_.protocolNFTVault.originalSharesOf(layout_.protocolNFTId);
        uint256 maxBptIn = IERC20(layout_.reservePool).totalSupply().mulDown(BALANCER_MAX_OUT_RATIO);
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
        uint256 wethOutAtHigh = _previewWethOutForRichirIn(layout_, high);
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
            wethOutAtHigh = _previewWethOutForRichirIn(layout_, high);
            ++iterations;
        }

        if (wethOutAtHigh < exactWethOut_) {
            revert ZeroAmount();
        }

        iterations = 0;
        while (low < high && iterations < MAX_BINARY_SEARCH_ITERATIONS) {
            uint256 mid = (low + high) / 2;
            uint256 wethOutAtMid = _previewWethOutForRichirIn(layout_, mid);
            if (wethOutAtMid < exactWethOut_) {
                low = mid + 1;
            } else {
                high = mid;
            }
            ++iterations;
        }

        richirAmountIn_ = low;
        uint256 wethOutAtQuote = _previewWethOutForRichirIn(layout_, richirAmountIn_);
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

    function _previewWethOutForRichirIn(SingleVaultDetfRepo.Storage storage layout_, uint256 richirAmountIn_)
        internal
        view
        returns (uint256 wethOut_)
    {
        uint256 bptIn = _previewRichirRedemptionBptIn(layout_, richirAmountIn_);
        uint256 vaultSharesOut = _previewVaultTokenOutForBptIn(layout_, bptIn);
        wethOut_ = layout_.wethRichVault.previewExchangeIn(
            IERC20(address(layout_.wethRichVault)),
            vaultSharesOut,
            layout_.wethToken
        );
    }

    function _exitReservePoolToVaultShares(SingleVaultDetfRepo.Storage storage layout_, uint256 bptIn_)
        internal
        returns (uint256 vaultSharesOut_)
    {
        IERC20 reservePoolToken = IERC20(layout_.reservePool);
        uint256 remainingBptIn = bptIn_;

        while (remainingBptIn > 0) {
            uint256 maxChunkBptIn = reservePoolToken.totalSupply().mulDown(BALANCER_MAX_OUT_RATIO);
            if (maxChunkBptIn == 0) {
                break;
            }

            uint256 chunkBptIn = remainingBptIn < maxChunkBptIn ? remainingBptIn : maxChunkBptIn;
            reservePoolToken.forceApprove(address(layout_.balancerV3PrepayRouter), chunkBptIn);
            vaultSharesOut_ += layout_.balancerV3PrepayRouter.prepayRemoveLiquiditySingleTokenExactIn(
                layout_.reservePool,
                chunkBptIn,
                IERC20(address(layout_.wethRichVault)),
                0,
                ""
            );
            remainingBptIn -= chunkBptIn;
        }
    }

    function _exitReservePoolProportionalForBridge(SingleVaultDetfRepo.Storage storage layout_, uint256 bptIn_)
        internal
        returns (uint256 chirAmountOut_, uint256 vaultSharesOut_)
    {
        IERC20 reservePoolToken = IERC20(layout_.reservePool);
        reservePoolToken.forceApprove(address(layout_.balancerV3PrepayRouter), bptIn_);
        uint256[] memory minAmountsOut = new uint256[](2);
        uint256[] memory amountsOut =
            layout_.balancerV3PrepayRouter.prepayRemoveLiquidityProportional(layout_.reservePool, bptIn_, minAmountsOut, "");
        chirAmountOut_ = amountsOut[layout_.chirIndex];
        vaultSharesOut_ = amountsOut[layout_.vaultTokenIndex];
    }

    function _redeemVaultSharesToWeth(
        SingleVaultDetfRepo.Storage storage layout_,
        uint256 vaultSharesIn_,
        address recipient_,
        uint256 deadline_
    ) internal returns (uint256 wethOut_) {
        IERC20 vaultToken = IERC20(address(layout_.wethRichVault));
        vaultToken.forceApprove(address(layout_.wethRichVault), vaultSharesIn_);
        wethOut_ = layout_.wethRichVault.exchangeIn(
            vaultToken,
            vaultSharesIn_,
            layout_.wethToken,
            0,
            recipient_,
            false,
            deadline_
        );
    }

    function _redepositChirToReservePool(SingleVaultDetfRepo.Storage storage layout_, uint256 chirAmount_)
        internal
        returns (uint256 bptOut_)
    {
        if (chirAmount_ == 0) {
            return 0;
        }

        bptOut_ = _addLiquidityToReservePool(layout_, chirAmount_, 0);
    }

    function _loadBurnQuoteData(SingleVaultDetfRepo.Storage storage layout_)
        internal
        view
        returns (BurnQuoteData memory data_)
    {
        data_.balancerVault = BalancerV3VaultAwareRepo._balancerV3Vault();
        data_.reservePool = IWeightedPool(layout_.reservePool);
        data_.reservePoolSwapFee = data_.balancerVault.getStaticSwapFeePercentage(address(data_.reservePool));
        data_.chirIndex = layout_.chirIndex;
        data_.vaultTokenIndex = layout_.vaultTokenIndex;
        data_.chirWeight = layout_.chirWeight;
        data_.vaultTokenWeight = layout_.vaultTokenWeight;
        data_.reservePoolTotalSupply = IERC20(layout_.reservePool).totalSupply();
        data_.reservePoolBptHeld = IERC20(address(ERC4626Repo._reserveAsset())).balanceOf(address(this));

        if (data_.reservePoolTotalSupply == 0 || data_.reservePoolBptHeld == 0) {
            revert ZeroAmount();
        }

        (, data_.tokenInfo, data_.balancesRaw,) = data_.balancerVault.getPoolTokenInfo(address(data_.reservePool));
        data_.ownedChirBalance = BetterMath._mulDivDown(
            data_.balancesRaw[data_.chirIndex], data_.reservePoolBptHeld, data_.reservePoolTotalSupply
        );
        data_.ownedReserveVaultBalance = BetterMath._mulDivDown(
            data_.balancesRaw[data_.vaultTokenIndex], data_.reservePoolBptHeld, data_.reservePoolTotalSupply
        );
        data_.reserveVaultRate = _tokenRate(data_.tokenInfo[data_.vaultTokenIndex]);
        data_.ownedReserveVaultRatedBalance = data_.ownedReserveVaultBalance.mulDown(data_.reserveVaultRate);

        if (data_.ownedChirBalance == 0 || data_.ownedReserveVaultBalance == 0 || data_.ownedReserveVaultRatedBalance == 0) {
            revert ZeroAmount();
        }
    }

    function _effectiveChirBurnInput(SingleVaultDetfRepo.Storage storage layout_, uint256 chirAmountIn_)
        internal
        view
        returns (uint256 effectiveChirIn_)
    {
        uint256 halfIncentive = _seigniorageIncentivePercentage(layout_) / 2;
        effectiveChirIn_ = chirAmountIn_ + chirAmountIn_.mulDown(halfIncentive);
    }

    function _rawChirBurnInputFromEffective(SingleVaultDetfRepo.Storage storage layout_, uint256 effectiveChirIn_)
        internal
        view
        returns (uint256 chirAmountIn_)
    {
        uint256 halfIncentive = _seigniorageIncentivePercentage(layout_) / 2;
        chirAmountIn_ = effectiveChirIn_.mulDivUp(FixedPoint.ONE, FixedPoint.ONE + halfIncentive);
    }

    function _bondFromWeth(SingleVaultDetfRepo.Storage storage layout_, uint256 wethAmount_, uint256 deadline_)
        internal
        returns (BondAssets memory assets_)
    {
        IERC20(address(layout_.wethToken)).safeTransfer(address(layout_.wethRichVault), wethAmount_);
        assets_.vaultShares = layout_.wethRichVault.exchangeIn(
            layout_.wethToken,
            wethAmount_,
            IERC20(address(layout_.wethRichVault)),
            0,
            address(this),
            true,
            deadline_
        );
        assets_.wethAmount = wethAmount_;
        assets_ = _bondFromVaultShares(layout_, assets_.vaultShares);
        assets_.wethAmount = wethAmount_;
    }

    function _bondFromVaultShares(SingleVaultDetfRepo.Storage storage layout_, uint256 vaultShares_)
        internal
        returns (BondAssets memory assets_)
    {
        assets_.vaultShares = vaultShares_;
        assets_.chirAmount = _calcProportionalChirForVaultShares(layout_, assets_.vaultShares);
        ERC20Repo._mint(address(this), assets_.chirAmount);
        assets_.bptOut = _addLiquidityToReservePool(layout_, assets_.chirAmount, assets_.vaultShares);
    }

    function chirToken() external view returns (IERC20MintBurn) {
        return IERC20MintBurn(address(this));
    }

    function richToken() external view returns (IERC20) {
        return SingleVaultDetfRepo._richToken();
    }

    function richirToken() external view returns (IERC20) {
        return IERC20(address(SingleVaultDetfRepo._richirToken()));
    }

    function wethToken() external view returns (IERC20) {
        return SingleVaultDetfRepo._wethToken();
    }

    function protocolNFTVault() external view returns (IProtocolNFTVault) {
        return SingleVaultDetfRepo._protocolNFTVault();
    }

    function chirWethVault() external view returns (IStandardExchange) {
        return SingleVaultDetfRepo._wethRichVault();
    }

    function richChirVault() external view returns (IStandardExchange) {
        return SingleVaultDetfRepo._wethRichVault();
    }

    function reservePool() external view returns (address) {
        return SingleVaultDetfRepo._reservePool();
    }

    function protocolNFTId() external view returns (uint256) {
        return SingleVaultDetfRepo._protocolNFTId();
    }

    function syntheticPrice() public view returns (uint256) {
        return _calcSyntheticPrice();
    }

    function mintThreshold() external view returns (uint256) {
        return SingleVaultDetfRepo._layout().mintThreshold;
    }

    function burnThreshold() external view returns (uint256) {
        return SingleVaultDetfRepo._layout().burnThreshold;
    }

    function isMintingAllowed() external view returns (bool allowed_) {
        return _isMintingAllowed(SingleVaultDetfRepo._layout(), _calcReserveSpotPrice());
    }

    function isBurningAllowed() external view returns (bool allowed_) {
        return _isBurningAllowed(SingleVaultDetfRepo._layout(), _calcReserveSpotPrice());
    }

    function wethRichVault() external view returns (IStandardExchange) {
        return SingleVaultDetfRepo._wethRichVault();
    }

    function vaultRateProvider() external view returns (IRateProvider) {
        return SingleVaultDetfRepo._vaultRateProvider();
    }

    function reservePoolIndexes() external view returns (uint256 chirIndex_, uint256 vaultTokenIndex_) {
        SingleVaultDetfRepo.Storage storage layout = SingleVaultDetfRepo._layout();
        chirIndex_ = layout.chirIndex;
        vaultTokenIndex_ = layout.vaultTokenIndex;
    }
}