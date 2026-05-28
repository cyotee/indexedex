// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {ONE_WAD} from "@crane/contracts/constants/Constants.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC4626} from "@crane/contracts/interfaces/IERC4626.sol";
import {IUniswapV2Pair} from "@crane/contracts/interfaces/protocols/dexes/uniswap/v2/IUniswapV2Pair.sol";
import {IPool} from "@crane/contracts/interfaces/protocols/dexes/aerodrome/IPool.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {ERC4626Repo} from "@crane/contracts/tokens/ERC4626/ERC4626Repo.sol";
import {FixedPoint} from "@crane/contracts/external/balancer/v3/solidity-utils/contracts/math/FixedPoint.sol";
import {ConstProdUtils} from "@crane/contracts/utils/math/ConstProdUtils.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IDETF} from "contracts/interfaces/IDETF.sol";
import {IProtocolDETF} from "contracts/interfaces/IProtocolDETF.sol";
import {IProtocolNFTVault} from "contracts/interfaces/IProtocolNFTVault.sol";
import {IStandardExchange} from "contracts/interfaces/IStandardExchange.sol";
import {DETFPreviewLib} from "contracts/vaults/detf/core/DETFPreviewLib.sol";
import {BaseDualSelfCommonDETFRepo} from "contracts/vaults/protocol/BaseDualSelfCommonDETFRepo.sol";
import {BaseDualSelfCommonDETFCommon} from "contracts/vaults/protocol/BaseDualSelfCommonDETFCommon.sol";
import {
    BalancerV38020WeightedPoolMath
} from "contracts/protocols/dexes/balancer/v3/utils/BalancerV38020WeightedPoolMath.sol";
import {IVault} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IVault.sol";
import {TokenInfo} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/VaultTypes.sol";
import {
    BalancerV3VaultAwareRepo
} from "@crane/contracts/protocols/dexes/balancer/v3/vault/BalancerV3VaultAwareRepo.sol";

import {
    PREVIEW_BUFFER_DENOMINATOR,
    PREVIEW_RICHIR_BUFFER_BPS,
    PREVIEW_BPT_BUFFER_DENOMINATOR,
    PREVIEW_BPT_BUFFER_BPS
} from "contracts/constants/Indexedex_CONSTANTS.sol";

/**
 * @title BaseDualSelfCommonDETFExchangeInQueryTarget
 * @author cyotee doge <not_cyotee@proton.me>
 * @notice View-only query functions for Protocol DETF exchange-in previews.
 * @dev Split from BaseDualSelfCommonDETFExchangeInTarget to meet EIP-170 contract size limit.
 *      Contains all preview/query functions while the execute target retains
 *      state-changing functions.
 */
contract BaseDualSelfCommonDETFExchangeInQueryTarget is BaseDualSelfCommonDETFCommon {
    using BaseDualSelfCommonDETFRepo for BaseDualSelfCommonDETFRepo.Storage;
    using FixedPoint for uint256;

    uint256 private constant DIRECT_PREVIEW_EXTRA_BUFFER_BPS = 20;
    uint256 private constant RICHIR_REDEMPTION_PREVIEW_BUFFER_BPS = 1750;
    uint256 private constant BASE_CHIR_REDEMPTION_ROUNDING_ADJUSTMENT = 1;

    struct ReservePoolBptPreview {
        uint256[] balancesRaw;
        uint256 bptOut;
        uint256 poolSupply;
        uint256 chirIdx;
        uint256 richIdx;
    }

    /* ---------------------------------------------------------------------- */
    /*                           Preview Exchange In                          */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice Previews the expected output amount for an exchange-in operation.
     * @param tokenIn Input token
     * @param amountIn Input amount
     * @param tokenOut Output token
     * @return amountOut Expected output amount
     * @dev Supported routes:
     *      1. WETH → CHIR (mint when above mint threshold)
     *      2. RICH → CHIR (sell RICH for CHIR)
     *      3. CHIR → WETH (redeem when below burn threshold)
     *      4. RICHIR → WETH (redeem RICHIR for WETH)
     *      5. RICH → RICHIR (convert RICH to RICHIR)
    *      6. WETH → RICHIR (direct WETH deposit into the CHIR/WETH vault, then mint RICHIR)
     *      7. WETH → RICH (buy RICH with WETH, multi-hop)
     *      8. RICH → WETH (sell RICH for WETH, multi-hop)
     *      9. BPT → WETH (proportional exit, unwind to WETH)
     */
    function previewExchangeIn(IERC20 tokenIn, uint256 amountIn, IERC20 tokenOut)
        external
        view
        returns (uint256 amountOut)
    {
        BaseDualSelfCommonDETFRepo.Storage storage layoutStruct = BaseDualSelfCommonDETFRepo._layoutStruct();

        if (!_isInitialized()) {
            revert ReservePoolNotInitialized();
        }

        PoolReserves memory reserves;
        _loadPoolReserves(layoutStruct, reserves);
        uint256 syntheticPrice = _calcSyntheticPrice(reserves);

        /* ------------------------------------------------------------------ */
        /*                    CHIR → WETH (Below-Peg Redeem)                  */
        /* ------------------------------------------------------------------ */

        if (_isChirToken(tokenIn) && _isWethToken(layoutStruct, tokenOut)) {
            if (!_isBurningAllowed(layoutStruct, syntheticPrice)) {
                revert BurningNotAllowed(syntheticPrice, layoutStruct.burnThreshold);
            }

            uint256 bptIn = _previewChirRedemptionBptIn(amountIn);
            (uint256 chirWethVaultSharesOut, uint256 richChirVaultSharesOut) =
                _previewChirRedemptionReserveShares(layoutStruct, bptIn);
            return _previewChirRedemptionUnwind(layoutStruct, chirWethVaultSharesOut, richChirVaultSharesOut);
        }

        /* ------------------------------------------------------------------ */
        /*                         WETH → CHIR (Mint)                         */
        /* ------------------------------------------------------------------ */

        if (_isWethToken(layoutStruct, tokenIn) && _isChirToken(tokenOut)) {
            if (!_isMintingAllowed(layoutStruct, syntheticPrice)) {
                revert MintingNotAllowed(syntheticPrice, layoutStruct.mintThreshold);
            }

            amountOut = _previewMintChirFromWeth(layoutStruct, amountIn);
            return amountOut;
        }

        /* ------------------------------------------------------------------ */
        /*                     RICH → CHIR (Mint Wrapper)                    */
        /* ------------------------------------------------------------------ */

        if (_isRichToken(layoutStruct, tokenIn) && _isChirToken(tokenOut)) {
            if (!_isMintingAllowed(layoutStruct, syntheticPrice)) {
                revert MintingNotAllowed(syntheticPrice, layoutStruct.mintThreshold);
            }

            // Swap RICH -> CHIR (RICH/CHIR Aerodrome pool)
            uint256 chirOut = layoutStruct.richChirVault.previewExchangeIn(tokenIn, amountIn, IERC20(address(this)));

            // Swap CHIR -> WETH (CHIR/WETH pool)
            uint256 wethOut = layoutStruct.chirWethVault.previewExchangeIn(IERC20(address(this)), chirOut, layoutStruct.wethToken);

            amountOut = _previewMintChirFromWeth(layoutStruct, wethOut);
            return amountOut;
        }

        /* ------------------------------------------------------------------ */
        /*                     RICHIR → WETH (Redemption)                     */
        /* ------------------------------------------------------------------ */

        if (_isRichirToken(layoutStruct, tokenIn) && _isWethToken(layoutStruct, tokenOut)) {
            uint256 bptIn = _previewRichirRedemptionBptIn(layoutStruct, amountIn);
            (uint256 chirWethVaultSharesOut, uint256 richChirVaultSharesOut) =
                _previewChirRedemptionReserveShares(layoutStruct, bptIn);
            return _previewRichirRedemptionUnwind(layoutStruct, chirWethVaultSharesOut, richChirVaultSharesOut);
        }

        /* ------------------------------------------------------------------ */
        /*                     RICHIR → RICH (Redemption)                     */
        /* ------------------------------------------------------------------ */

        if (_isRichirToken(layoutStruct, tokenIn) && _isRichToken(layoutStruct, tokenOut)) {
            uint256 bptIn = _previewRichirRedemptionBptIn(layoutStruct, amountIn);
            (, uint256 richChirVaultSharesOut) = _previewChirRedemptionReserveShares(layoutStruct, bptIn);
            uint256 amountOut_ = layoutStruct.richChirVault.previewExchangeIn(
                IERC20(address(layoutStruct.richChirVault)), richChirVaultSharesOut, layoutStruct.richToken
            );
            if (amountOut_ > 10) {
                amountOut_ -= 10;
            }
            return amountOut_;
        }

        /* ------------------------------------------------------------------ */
        /*                      RICH → RICHIR (Single-Call)                   */
        /* ------------------------------------------------------------------ */

        if (_isRichToken(layoutStruct, tokenIn) && _isRichirToken(layoutStruct, tokenOut)) {
            return _previewDepositToRichir(
                layoutStruct,
                layoutStruct.richChirVault,
                layoutStruct.richToken,
                amountIn,
                layoutStruct.richChirVaultIndex
            );
        }

        /* ------------------------------------------------------------------ */
        /*                      WETH → RICHIR (Single-Call)                   */
        /* ------------------------------------------------------------------ */

        if (_isWethToken(layoutStruct, tokenIn) && _isRichirToken(layoutStruct, tokenOut)) {
            return _previewDepositToRichir(
                layoutStruct,
                layoutStruct.chirWethVault,
                layoutStruct.wethToken,
                amountIn,
                layoutStruct.chirWethVaultIndex
            );
        }

        /* ------------------------------------------------------------------ */
        /*                    BPT (Reserve Pool) → WETH                        */
        /* ------------------------------------------------------------------ */

        if (
            _isWethToken(layoutStruct, tokenOut)
                && (
                    address(tokenIn) == address(_reservePool())
                        || address(tokenIn) == address(ERC4626Repo._reserveAsset())
                )
        ) {
            if (amountIn == 0) {
                return 0;
            }

            (uint256 chirWethVaultSharesOut, uint256 richChirVaultSharesOut) =
                _previewChirRedemptionReserveShares(layoutStruct, amountIn);
            return _previewChirRedemptionUnwind(layoutStruct, chirWethVaultSharesOut, richChirVaultSharesOut);
        }

        /* ------------------------------------------------------------------ */
        /*                        WETH → RICH (Buy RICH)                      */
        /* ------------------------------------------------------------------ */

        if (_isWethToken(layoutStruct, tokenIn) && _isRichToken(layoutStruct, tokenOut)) {
            return _previewSwapViaChir(
                layoutStruct,
                layoutStruct.chirWethVault,
                layoutStruct.wethToken,
                amountIn,
                layoutStruct.richChirVault,
                layoutStruct.richToken
            );
        }

        /* ------------------------------------------------------------------ */
        /*                       RICH → WETH (Sell RICH)                      */
        /* ------------------------------------------------------------------ */

        if (_isRichToken(layoutStruct, tokenIn) && _isWethToken(layoutStruct, tokenOut)) {
            return _previewSwapViaChir(
                layoutStruct,
                layoutStruct.richChirVault,
                layoutStruct.richToken,
                amountIn,
                layoutStruct.chirWethVault,
                layoutStruct.wethToken
            );
        }

        revert InvalidToken(tokenIn);
    }

    /* ---------------------------------------------------------------------- */
    /*                       Internal Preview Helpers                         */
    /* ---------------------------------------------------------------------- */

    function _previewRichirRedemptionBptIn(BaseDualSelfCommonDETFRepo.Storage storage layoutStruct_, uint256 richirAmount_)
        internal
        view
        returns (uint256 bptIn_)
    {
        uint256 richirShares = layoutStruct_.richirToken.convertToShares(richirAmount_);
        uint256 totalRichirShares = layoutStruct_.richirToken.totalShares();
        uint256 protocolNftBpt = layoutStruct_.protocolNFTVault.originalSharesOf(layoutStruct_.protocolNFTId);
        bptIn_ = (richirShares * protocolNftBpt) / totalRichirShares;
    }

    function _previewChirRedemptionBptIn(uint256 amountIn_) internal view virtual returns (uint256 bptIn_) {
        uint256 chirTotalSupply = ERC20Repo._totalSupply();
        if (chirTotalSupply == 0) {
            revert ZeroAmount();
        }

        uint256 bptHeld = IERC20(address(_reservePool())).balanceOf(address(this));
        if (bptHeld == 0) {
            revert ZeroAmount();
        }

        bptIn_ = (amountIn_ * bptHeld) / chirTotalSupply;
        if (bptIn_ == 0) {
            revert ZeroAmount();
        }
    }

    function _previewChirRedemptionReserveShares(BaseDualSelfCommonDETFRepo.Storage storage layoutStruct_, uint256 bptIn_)
        internal
        view
        returns (uint256 chirWethVaultSharesOut_, uint256 richChirVaultSharesOut_)
    {
        ReservePoolData memory resPoolData;
        (, uint256[] memory currentBalancesRaw) = _loadReservePoolDataWithTokenInfo(resPoolData);
        if (resPoolData.resPoolTotalSupply == 0) {
            revert ZeroAmount();
        }

        uint256[] memory amountsOut = BalancerV38020WeightedPoolMath.calcProportionalAmountsOutGivenBptIn(
            currentBalancesRaw,
            resPoolData.resPoolTotalSupply,
            bptIn_
        );

        chirWethVaultSharesOut_ = amountsOut[layoutStruct_.chirWethVaultIndex];
        richChirVaultSharesOut_ = amountsOut[layoutStruct_.richChirVaultIndex];
    }

    // function _rateOf(TokenInfo memory t_) internal view returns (uint256 rate_) {
    //     rate_ = FixedPoint.ONE;
    //     if (address(t_.rateProvider) != address(0)) {
    //         rate_ = t_.rateProvider.getRate();
    //     }
    // }

    function _previewChirRedemptionUnwind(
        BaseDualSelfCommonDETFRepo.Storage storage layoutStruct_,
        uint256 chirWethVaultSharesOut_,
        uint256 richChirVaultSharesOut_
    ) internal view returns (uint256 amountOut_) {
        uint256 wethFromChirWeth = layoutStruct_.chirWethVault
            .previewExchangeIn(IERC20(address(layoutStruct_.chirWethVault)), chirWethVaultSharesOut_, layoutStruct_.wethToken);

        uint256 chirFromRichChir = layoutStruct_.richChirVault
            .previewExchangeIn(IERC20(address(layoutStruct_.richChirVault)), richChirVaultSharesOut_, IERC20(address(this)));

        uint256 wethFromChirSwap =
            _previewChirSwapAfterChirWethAerodromeUnwind(layoutStruct_, chirWethVaultSharesOut_, wethFromChirWeth, chirFromRichChir);

        amountOut_ = wethFromChirWeth + wethFromChirSwap;
        if (amountOut_ > BASE_CHIR_REDEMPTION_ROUNDING_ADJUSTMENT) {
            amountOut_ -= BASE_CHIR_REDEMPTION_ROUNDING_ADJUSTMENT;
        }
    }

    function _previewRichirRedemptionUnwind(
        BaseDualSelfCommonDETFRepo.Storage storage layoutStruct_,
        uint256 chirWethVaultSharesOut_,
        uint256 richChirVaultSharesOut_
    ) internal view returns (uint256 amountOut_) {
        uint256 wethFromChirWeth = layoutStruct_.chirWethVault
            .previewExchangeIn(IERC20(address(layoutStruct_.chirWethVault)), chirWethVaultSharesOut_, layoutStruct_.wethToken);

        (, uint256 chirFromBurn) = _previewRichChirVaultBurn(layoutStruct_, richChirVaultSharesOut_);

        uint256 wethFromChirSwap =
            layoutStruct_.chirWethVault.previewExchangeIn(IERC20(address(this)), chirFromBurn, layoutStruct_.wethToken);

        amountOut_ = wethFromChirWeth + wethFromChirSwap;
        amountOut_ = DETFPreviewLib._applyDiscountBps(
            amountOut_, RICHIR_REDEMPTION_PREVIEW_BUFFER_BPS, PREVIEW_BUFFER_DENOMINATOR
        );
    }

    function _previewRichChirVaultBurn(
        BaseDualSelfCommonDETFRepo.Storage storage layoutStruct_,
        uint256 richChirVaultSharesOut_
    ) internal view returns (uint256 richOut_, uint256 chirOut_) {
        IERC20 richChirVaultToken = IERC20(address(layoutStruct_.richChirVault));
        IERC20 lpToken = IERC20(IERC4626(address(layoutStruct_.richChirVault)).asset());
        uint256 lpOut =
            layoutStruct_.richChirVault.previewExchangeIn(richChirVaultToken, richChirVaultSharesOut_, lpToken);

        IUniswapV2Pair pool = IUniswapV2Pair(address(lpToken));
        (uint256 reserve0, uint256 reserve1,) = pool.getReserves();
        uint256 totalSupply = lpToken.totalSupply();

        if (pool.token0() == address(layoutStruct_.richToken)) {
            richOut_ = (lpOut * reserve0) / totalSupply;
            chirOut_ = (lpOut * reserve1) / totalSupply;
        } else {
            richOut_ = (lpOut * reserve1) / totalSupply;
            chirOut_ = (lpOut * reserve0) / totalSupply;
        }
    }

    function _previewDepositToRichir(
        BaseDualSelfCommonDETFRepo.Storage storage layoutStruct_,
        IStandardExchange vault_,
        IERC20 tokenIn_,
        uint256 amountIn_,
        uint256 vaultIndex_
    ) internal view returns (uint256 richirOut_) {
        if (amountIn_ == 0) {
            return 0;
        }

        // Preview vault shares using a post-compound pool state simulation.
        // This keeps previewExchangeIn conservative for Aerodrome vault deposits.
        uint256 vaultShares = _previewVaultSharesPostCompound(vault_, tokenIn_, amountIn_);

        ReservePoolBptPreview memory p = _previewReservePoolBptOut(layoutStruct_, vaultIndex_, vaultShares);

        ReservePoolData memory resPoolData;
        _loadReservePoolData(resPoolData, new uint256[](0));

        uint256 newProtocolReserveBpt =
            layoutStruct_.protocolNFTVault.getPosition(layoutStruct_.protocolNFTId).originalShares + p.bptOut;
        uint256 newTotalRichirShares = layoutStruct_.richirToken.totalShares() + p.bptOut;

        if (newProtocolReserveBpt == 0 || newTotalRichirShares == 0) {
            return 0;
        }

        uint256 newWethValue = IDETF(address(this)).previewRebasingDetfTokenEthValue(newProtocolReserveBpt);
        if (newWethValue == 0) {
            return 0;
        }

        // Mirror RebasingDETFTokenTarget.mintFromNFTSale: mint external shares 1:1 with BPT,
        // then value them using the post-deposit redemption rate.
        richirOut_ = (p.bptOut * newWethValue) / newTotalRichirShares;

        // Apply precision buffer to ensure preview never exceeds actual execution.
        // previewExchangeIn should underestimate (return ≤ actual).
        richirOut_ =
            DETFPreviewLib._applyDiscountBps(richirOut_, PREVIEW_RICHIR_BUFFER_BPS, PREVIEW_BUFFER_DENOMINATOR);

        if (_buildCompoundSim(vault_).compoundLP == 0) {
            richirOut_ = DETFPreviewLib._applyDiscountBps(
                richirOut_, DIRECT_PREVIEW_EXTRA_BUFFER_BPS, PREVIEW_BUFFER_DENOMINATOR
            );
        }
    }

    function _previewReservePoolBptOut(
        BaseDualSelfCommonDETFRepo.Storage storage,
        uint256 vaultIndex_,
        uint256 vaultShares_
    ) internal view returns (ReservePoolBptPreview memory p_) {
        BridgeReservePoolBptPreview memory sharedPreview =
            _previewReservePoolSingleInBptOut(BaseDualSelfCommonDETFRepo._layoutStruct(), vaultIndex_, vaultShares_);

        p_.balancesRaw = sharedPreview.balancesRaw;
        p_.bptOut = sharedPreview.bptOut;
        p_.poolSupply = sharedPreview.poolSupply;
        p_.chirIdx = sharedPreview.chirIdx;
        p_.richIdx = sharedPreview.richIdx;
    }

    function _previewSwapViaChir(
        BaseDualSelfCommonDETFRepo.Storage storage,
        IStandardExchange vaultIn_,
        IERC20 tokenIn_,
        uint256 amountIn_,
        IStandardExchange vaultOut_,
        IERC20 tokenOut_
    ) internal view returns (uint256 amountOut_) {
        if (amountIn_ == 0) {
            return 0;
        }

        uint256 chirOut = vaultIn_.previewExchangeIn(tokenIn_, amountIn_, IERC20(address(this)));
        amountOut_ = vaultOut_.previewExchangeIn(IERC20(address(this)), chirOut, tokenOut_);
    }

    /* ---------------------------------------------------------------------- */
    /*                      Mint Preview Helper                                */
    /* ---------------------------------------------------------------------- */

    function _previewMintChirFromWeth(BaseDualSelfCommonDETFRepo.Storage storage layoutStruct_, uint256 wethIn_)
        internal
        view
        returns (uint256 chirOut_)
    {
        // Get CHIR/WETH pool reserves
        IUniswapV2Pair chirWethPool = IUniswapV2Pair(address(IERC4626(address(layoutStruct_.chirWethVault)).asset()));
        (uint256 reserve0, uint256 reserve1,) = chirWethPool.getReserves();
        address token0 = chirWethPool.token0();

        uint256 wethReserve;
        uint256 chirReserve;
        if (token0 == address(layoutStruct_.wethToken)) {
            wethReserve = reserve0;
            chirReserve = reserve1;
        } else {
            wethReserve = reserve1;
            chirReserve = reserve0;
        }

        // Get swap fee from pool
        uint256 swapFeePercent = _poolSwapFeePercent(address(chirWethPool));

        // Apply seigniorage incentive - increase WETH amount
        uint256 seignioragePct = layoutStruct_._feeOracle().seigniorageIncentivePercentageOfVault(address(this));
        uint256 wethWithIncentive = wethIn_ + (wethIn_ * seignioragePct / FixedPoint.ONE);

        // Use ConstProdUtils._saleQuote to calculate base CHIR (same as execution)
        uint256 baseChir =
            ConstProdUtils._saleQuote(wethWithIncentive, wethReserve, chirReserve, swapFeePercent);

        // 50/50 split: user receives base * (1 - pct/2)
        chirOut_ = baseChir * (FixedPoint.ONE - seignioragePct / 2) / FixedPoint.ONE;
    }

    function _previewChirSwapAfterChirWethAerodromeUnwind(
        BaseDualSelfCommonDETFRepo.Storage storage layoutStruct_,
        uint256 chirWethVaultSharesIn_,
        uint256 wethFromChirWeth_,
        uint256 chirIn_
    ) internal view returns (uint256 wethOut_) {
        if (chirIn_ == 0) {
            return 0;
        }

        IPool chirWethPool = IPool(address(IERC4626(address(layoutStruct_.chirWethVault)).asset()));
        AeroCompoundSim memory sim_ = _buildCompoundSim(layoutStruct_.chirWethVault);
        uint256 lpFromShares_ = layoutStruct_.chirWethVault.previewExchangeIn(
            IERC20(address(layoutStruct_.chirWethVault)), chirWethVaultSharesIn_, IERC20(address(chirWethPool))
        );

        if (lpFromShares_ == 0) {
            return 0;
        }

        uint256 wethReserve_ = sim_.token0 == address(layoutStruct_.wethToken) ? sim_.reserve0 : sim_.reserve1;
        uint256 chirReserve_ = sim_.token0 == address(layoutStruct_.wethToken) ? sim_.reserve1 : sim_.reserve0;

        if (wethFromChirWeth_ >= wethReserve_) {
            return 0;
        }

        (, uint256 chirWithdrawn) = ConstProdUtils._withdrawQuote(
            lpFromShares_, sim_.lpTotalSupply, wethReserve_, chirReserve_
        );

        uint256 chirFeeTaken = (chirWithdrawn * sim_.swapFeePercent) / 10_000;
        if (chirFeeTaken >= chirReserve_) {
            return 0;
        }

        uint256 postUnwindWethReserve_ = wethReserve_ - wethFromChirWeth_;
        uint256 postUnwindChirReserve_ = chirReserve_ - chirFeeTaken;
        wethOut_ = ConstProdUtils._saleQuote(
            chirIn_, postUnwindChirReserve_, postUnwindWethReserve_, sim_.swapFeePercent, 10_000
        );
    }

}
