// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                 Balancer V3                                */
/* -------------------------------------------------------------------------- */

import {IVault} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IVault.sol";
import {IWeightedPool} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IWeightedPool.sol";
import {FixedPoint} from "@crane/contracts/external/balancer/v3/solidity-utils/contracts/math/FixedPoint.sol";
import {WeightedMath} from "@crane/contracts/external/balancer/v3/solidity-utils/contracts/math/WeightedMath.sol";

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {ONE_WAD} from "@crane/contracts/constants/Constants.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20MintBurn} from "@crane/contracts/interfaces/IERC20MintBurn.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {BetterSafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {BetterMath} from "@crane/contracts/utils/math/BetterMath.sol";
import {ReentrancyLockModifiers} from "@crane/contracts/access/reentrancy/ReentrancyLockModifiers.sol";
import {
    BalancerV3VaultAwareRepo
} from "@crane/contracts/protocols/dexes/balancer/v3/vault/BalancerV3VaultAwareRepo.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IStandardExchange} from "contracts/interfaces/IStandardExchange.sol";
import {IStandardExchangeIn} from "contracts/interfaces/IStandardExchangeIn.sol";
import {ISeigniorageNFTVault} from "contracts/interfaces/ISeigniorageNFTVault.sol";
import {
    IBalancerV3StandardExchangeRouterPrepay
} from "contracts/interfaces/IBalancerV3StandardExchangeRouterPrepay.sol";
import {
    BalancerV38020WeightedPoolMath
} from "contracts/protocols/dexes/balancer/v3/utils/BalancerV38020WeightedPoolMath.sol";
import {SeigniorageDETFRepo} from "contracts/vaults/seigniorage/SeigniorageDETFRepo.sol";
import {SeigniorageDETFCommon} from "contracts/vaults/seigniorage/SeigniorageDETFCommon.sol";

/**
 * @title SeigniorageDETFExchangeInTarget
 * @author cyotee doge <not_cyotee@proton.me>
 * @notice Implementation of IStandardExchangeIn for Seigniorage DETF.
 * @dev Handles mint (above peg) and burn (below peg) operations.
 *      When above peg: Users deposit reserve tokens → receive DETF tokens + seigniorage captured
 *      When below peg: Users burn DETF tokens → receive reserve tokens
 */
contract SeigniorageDETFExchangeInTarget is SeigniorageDETFCommon, ReentrancyLockModifiers, IStandardExchangeIn {
    using BetterSafeERC20 for IERC20;
    using SeigniorageDETFRepo for SeigniorageDETFRepo.Storage;

    struct ExchangeInParams {
        IERC20 tokenIn;
        uint256 amountIn;
        IERC20 tokenOut;
        uint256 minAmountOut;
        address recipient;
        bool pretransferred;
        uint256 deadline;
        uint256 dilutedPrice;
    }

    /* ---------------------------------------------------------------------- */
    /*                           Preview Exchange In                          */
    /* ---------------------------------------------------------------------- */

    /**
     * @inheritdoc IStandardExchangeIn
     * @dev Supported routes:
     *      1. Reserve vault token → DETF (mint when above peg)
     *      2. DETF → Reserve vault token (burn when below peg)
     *      3. Reserve vault constituent → DETF (ZapIn mint)
     *      4. DETF → Reserve vault constituent (ZapOut burn)
     *      5. DETF (RBT) → sRBT (1:1, above peg)
     *      6. sRBT → DETF (RBT) (1:1, at-or-above peg)
     */
    function previewExchangeIn(IERC20 tokenIn, uint256 amountIn, IERC20 tokenOut)
        external
        view
        returns (uint256 amountOut)
    {
        SeigniorageDETFRepo.Storage storage layout = SeigniorageDETFRepo._layout();

        ReservePoolState memory poolState;
        _loadReservePoolState(layout, poolState);

        uint256 dilutedPrice = _calcDilutedPrice(layout, poolState);

        /* ------------------------------------------------------------------ */
        /*                     Reserve Vault → DETF (Mint)                    */
        /* ------------------------------------------------------------------ */

        if (_isReserveVaultToken(layout, tokenIn) && _isSelfToken(tokenOut)) {
            if (!_isAbovePeg(dilutedPrice)) {
                revert PriceBelowPeg(dilutedPrice, ONE_WAD);
            }

            amountOut = _calcMintAmount(amountIn, dilutedPrice);
            return amountOut;
        }

        /* ------------------------------------------------------------------ */
        /*                     DETF → Reserve Vault (Burn)                    */
        /* ------------------------------------------------------------------ */

        if (_isSelfToken(tokenIn) && _isReserveVaultToken(layout, tokenOut)) {
            if (!_isBelowPeg(dilutedPrice)) {
                revert PriceAbovePeg(dilutedPrice, ONE_WAD);
            }

            amountOut = _calcBurnAmount(amountIn, dilutedPrice);
            return amountOut;
        }

        /* ------------------------------------------------------------------ */
        /*                Reserve Vault Constituent → DETF (ZapIn)            */
        /* ------------------------------------------------------------------ */

        if (_isValidMintToken(layout, tokenIn) && _isSelfToken(tokenOut)) {
            if (!_isAbovePeg(dilutedPrice)) {
                revert PriceBelowPeg(dilutedPrice, ONE_WAD);
            }

            IStandardExchange reserveVault = layout.reserveVault;
            uint256 reserveShares = reserveVault.previewExchangeIn(tokenIn, amountIn, IERC20(address(reserveVault)));

            amountOut = _calcMintAmount(reserveShares, dilutedPrice);
            return amountOut;
        }

        /* ------------------------------------------------------------------ */
        /*                DETF → Reserve Vault Constituent (ZapOut)           */
        /* ------------------------------------------------------------------ */

        if (_isSelfToken(tokenIn) && _isValidMintToken(layout, tokenOut)) {
            if (!_isBelowPeg(dilutedPrice)) {
                revert PriceAbovePeg(dilutedPrice, ONE_WAD);
            }

            uint256 reserveShares = _calcBurnAmount(amountIn, dilutedPrice);

            IStandardExchange reserveVault = layout.reserveVault;
            amountOut = reserveVault.previewExchangeIn(IERC20(address(reserveVault)), reserveShares, tokenOut);
            return amountOut;
        }

        /* ------------------------------------------------------------------ */
        /*                         DETF ↔ sRBT (1:1)                         */
        /* ------------------------------------------------------------------ */

        if (_isSelfToken(tokenIn) && address(tokenOut) == address(layout.seigniorageToken)) {
            if (!_isAbovePeg(dilutedPrice)) {
                revert PriceBelowPeg(dilutedPrice, ONE_WAD);
            }
            return amountIn;
        }

        if (address(tokenIn) == address(layout.seigniorageToken) && _isSelfToken(tokenOut)) {
            if (dilutedPrice < ONE_WAD) {
                revert PriceBelowPeg(dilutedPrice, ONE_WAD);
            }
            return amountIn;
        }

        revert InvalidRoute(address(tokenIn), address(tokenOut));
    }

    /* ---------------------------------------------------------------------- */
    /*                              Exchange In                               */
    /* ---------------------------------------------------------------------- */

    /**
     * @inheritdoc IStandardExchangeIn
     */
    function exchangeIn(
        IERC20 tokenIn,
        uint256 amountIn,
        IERC20 tokenOut,
        uint256 minAmountOut,
        address recipient,
        bool pretransferred,
        uint256 deadline
    ) external lock returns (uint256 amountOut) {
        if (block.timestamp > deadline) {
            revert DeadlineExceeded(deadline, block.timestamp);
        }

        SeigniorageDETFRepo.Storage storage layout = SeigniorageDETFRepo._layout();

        ReservePoolState memory poolState;
        _loadReservePoolState(layout, poolState);

        ExchangeInParams memory params = ExchangeInParams({
            tokenIn: tokenIn,
            amountIn: amountIn,
            tokenOut: tokenOut,
            minAmountOut: minAmountOut,
            recipient: recipient,
            pretransferred: pretransferred,
            deadline: deadline,
            dilutedPrice: _calcDilutedPrice(layout, poolState)
        });

        if (_isReserveVaultToken(layout, tokenIn) && _isSelfToken(tokenOut)) {
            return _executeReserveToDetfIn(layout, params);
        }

        if (_isSelfToken(tokenIn) && _isReserveVaultToken(layout, tokenOut)) {
            return _executeDetfToReserveIn(layout, params);
        }

        if (_isValidMintToken(layout, tokenIn) && _isSelfToken(tokenOut)) {
            return _executeZapInIn(layout, params);
        }

        if (_isSelfToken(tokenIn) && _isValidMintToken(layout, tokenOut)) {
            return _executeZapOutIn(layout, params);
        }

        // DETF (RBT) -> sRBT (1:1) when above peg.
        if (_isSelfToken(tokenIn) && address(tokenOut) == address(layout.seigniorageToken)) {
            if (!_isAbovePeg(params.dilutedPrice)) {
                revert PriceBelowPeg(params.dilutedPrice, ONE_WAD);
            }

            if (recipient == address(0)) {
                recipient = msg.sender;
            }

            _secureSelfBurn(msg.sender, amountIn, pretransferred);
            layout.seigniorageToken.mint(recipient, amountIn);

            amountOut = amountIn;
            if (amountOut < minAmountOut) {
                revert MinAmountNotMet(minAmountOut, amountOut);
            }
            return amountOut;
        }

        // sRBT -> DETF (RBT) (1:1) when at-or-above peg.
        if (address(tokenIn) == address(layout.seigniorageToken) && _isSelfToken(tokenOut)) {
            if (params.dilutedPrice < ONE_WAD) {
                revert PriceBelowPeg(params.dilutedPrice, ONE_WAD);
            }

            if (recipient == address(0)) {
                recipient = msg.sender;
            }

            address burnFrom = pretransferred ? address(this) : msg.sender;
            layout.seigniorageToken.burn(burnFrom, amountIn);
            ERC20Repo._mint(recipient, amountIn);

            amountOut = amountIn;
            if (amountOut < minAmountOut) {
                revert MinAmountNotMet(minAmountOut, amountOut);
            }
            return amountOut;
        }

        revert InvalidRoute(address(tokenIn), address(tokenOut));
    }

    /* ---------------------------------------------------------------------- */
    /*                       Exchange In Route Handlers                       */
    /* ---------------------------------------------------------------------- */

    function _executeReserveToDetfIn(SeigniorageDETFRepo.Storage storage layout_, ExchangeInParams memory p_)
        internal
        returns (uint256 amountOut_)
    {
        // Load pool state
        ReservePoolData memory resPoolData;
        uint256[] memory currentRatedBalances = _loadReservePoolData(resPoolData, new uint256[](0));

        RBTData memory rbtData;
        _loadRBTData(rbtData);
        rbtData.reserveVault = layout_.reserveVault;

        SRBTData memory sRbtData;
        _loadSRBTData(sRbtData, resPoolData);

        // Calculate diluted price
        rbtData.selfDilutedPrice = _calcDilutedPriceFromData(rbtData, sRbtData, resPoolData);

        if (rbtData.selfDilutedPrice <= ONE_WAD) {
            revert PriceBelowPeg(rbtData.selfDilutedPrice, ONE_WAD);
        }

        // Secure token deposit
        uint256 originalAmountIn = _secureTokenTransfer(p_.tokenIn, p_.amountIn, p_.pretransferred);

        // Calculate reduced fee percentage
        uint256 feeReductionPPM = layout_.feeOracle.seigniorageIncentivePercentageOfVault(address(this));
        uint256 amountInWithReducedFeeApplied = FixedPoint.mulDown(
            originalAmountIn,
            FixedPoint.ONE - BetterMath._percentageOfWAD(resPoolData.reservePoolSwapFee, feeReductionPPM)
        );

        // Transfer to Balancer vault
        p_.tokenIn.safeTransfer(address(resPoolData.balV3Vault), originalAmountIn);

        // Calculate expected BPT from single-asset deposit
        resPoolData.expectedBpt = BalancerV38020WeightedPoolMath.calcBptOutGivenSingleIn(
            currentRatedBalances,
            resPoolData.weightsArray,
            resPoolData.reserveVaultIndexInReservePool,
            originalAmountIn,
            resPoolData.resPoolTotalSupply,
            resPoolData.reservePoolSwapFee
        );

        // Create deposit amounts array (single-sided deposit)
        uint256[] memory paymentAmountsIn = new uint256[](2);
        paymentAmountsIn[resPoolData.reserveVaultIndexInReservePool] = originalAmountIn;

        // Add liquidity via prepay router
        layout_.balancerV3PrepayRouter
            .prepayAddLiquidityUnbalanced(
                address(resPoolData.reservePool), paymentAmountsIn, resPoolData.expectedBpt, ""
            );

        // Calculate full-fee effective input
        uint256 effectiveInFull = FixedPoint.mulDown(originalAmountIn, FixedPoint.ONE - resPoolData.reservePoolSwapFee);

        // Calculate amountOut at FULL fee for profit margin calc
        uint256 amountOutFull = WeightedMath.computeOutGivenExactIn(
            resPoolData.reserveVaultRatedBalance,
            resPoolData.reserveVaultReservePoolWeight,
            resPoolData.selfReservePoolRatedBalance,
            resPoolData.selfReservePoolWeight,
            effectiveInFull
        );

        // Calculate mint amount at REDUCED fee
        amountOut_ = WeightedMath.computeOutGivenExactIn(
            resPoolData.reserveVaultRatedBalance,
            resPoolData.reserveVaultReservePoolWeight,
            resPoolData.selfReservePoolRatedBalance,
            resPoolData.selfReservePoolWeight,
            amountInWithReducedFeeApplied
        );

        if (amountOut_ < p_.minAmountOut) {
            revert MinAmountNotMet(p_.minAmountOut, amountOut_);
        }

        // Calculate seigniorage profit margin
        SRBTAmounts memory srbt;
        srbt.effectiveMintPriceFull = FixedPoint.divDown(amountInWithReducedFeeApplied, amountOutFull);
        srbt.premiumPerRBT = srbt.effectiveMintPriceFull - ONE_WAD;
        srbt.grossSeigniorage = FixedPoint.mulDown(amountOutFull, srbt.premiumPerRBT);
        srbt.discountRBT = amountOut_ - amountOutFull;
        srbt.discountMargin = FixedPoint.mulDown(srbt.discountRBT, ONE_WAD);
        srbt.profitMargin = srbt.grossSeigniorage + srbt.discountMargin;
        srbt.sRBTToMint = FixedPoint.divDown(srbt.profitMargin, ONE_WAD);

        // Mint DETF to recipient
        ERC20Repo._mint(p_.recipient, amountOut_);

        // Mint sRBT to NFT vault for bond holders
        if (srbt.sRBTToMint > 0) {
            sRbtData.seigniorageToken.mint(address(layout_.seigniorageNFTVault), srbt.sRBTToMint);
        }
    }

    function _executeDetfToReserveIn(SeigniorageDETFRepo.Storage storage layout_, ExchangeInParams memory p_)
        internal
        returns (uint256 amountOut_)
    {
        // Load pool state
        ReservePoolData memory resPoolData;
        uint256[] memory currentRatedBalances = _loadReservePoolData(resPoolData, new uint256[](0));

        RBTData memory rbtData;
        _loadRBTData(rbtData);
        rbtData.reserveVault = layout_.reserveVault;

        SRBTData memory sRbtData;
        _loadSRBTData(sRbtData, resPoolData);

        // Calculate diluted price
        rbtData.selfDilutedPrice = _calcDilutedPriceFromData(rbtData, sRbtData, resPoolData);

        if (rbtData.selfDilutedPrice > ONE_WAD) {
            revert PriceAbovePeg(rbtData.selfDilutedPrice, ONE_WAD);
        }

        // Burn DETF tokens
        _secureSelfBurn(msg.sender, p_.amountIn, p_.pretransferred);

        // Calculate reduced fee percentage
        uint256 feeReductionPPM = layout_.feeOracle.seigniorageIncentivePercentageOfVault(address(this));
        uint256 amountInWithReducedFeeApplied = FixedPoint.mulDown(
            p_.amountIn, FixedPoint.ONE - BetterMath._percentageOfWAD(resPoolData.reservePoolSwapFee, feeReductionPPM)
        );

        // Calculate amountOut using WeightedMath
        amountOut_ = WeightedMath.computeOutGivenExactIn(
            resPoolData.selfReservePoolRatedBalance,
            resPoolData.selfReservePoolWeight,
            resPoolData.reserveVaultRatedBalance,
            resPoolData.reserveVaultReservePoolWeight,
            amountInWithReducedFeeApplied
        );

        if (amountOut_ < p_.minAmountOut) {
            revert MinAmountNotMet(p_.minAmountOut, amountOut_);
        }

        // Calculate expected BPT for proportional exit
        resPoolData.expectedBpt = BalancerV38020WeightedPoolMath.calcBptInGivenProportionalOut(
            currentRatedBalances, resPoolData.resPoolTotalSupply, resPoolData.reserveVaultIndexInReservePool, amountOut_
        );

        // Transfer BPT to Balancer vault
        IERC20(address(resPoolData.reservePool)).safeTransfer(address(resPoolData.balV3Vault), resPoolData.expectedBpt);

        // Remove liquidity via prepay router
        uint256[] memory minAmountsOut = new uint256[](2);
        minAmountsOut[resPoolData.reserveVaultIndexInReservePool] = amountOut_;

        layout_.balancerV3PrepayRouter
            .prepayRemoveLiquidityProportional(
                address(resPoolData.reservePool), resPoolData.expectedBpt, minAmountsOut, ""
            );

        // Transfer reserve vault to recipient
        p_.tokenOut.safeTransfer(p_.recipient, amountOut_);

        // Redeposit unused tokens back to pool
        _redepositUnusedTokens(layout_, resPoolData);
    }

    /**
     * @notice Redeposits any unused reserve vault and self tokens back to the pool.
     */
    function _redepositUnusedTokens(SeigniorageDETFRepo.Storage storage layout_, ReservePoolData memory resPoolData_)
        internal
    {
        uint256 unusedReserveVault = IERC20(address(layout_.reserveVault)).balanceOf(address(this));
        uint256 unusedSelf = ERC20Repo._balanceOf(address(this));

        if (unusedReserveVault == 0 && unusedSelf == 0) {
            return;
        }

        // Refresh pool state
        uint256[] memory currentBalances =
            resPoolData_.balV3Vault.getCurrentLiveBalances(address(resPoolData_.reservePool));
        uint256 poolTotalSupply = resPoolData_.balV3Vault.totalSupply(address(resPoolData_.reservePool));

        uint256[] memory unusedAmounts = new uint256[](2);
        unusedAmounts[resPoolData_.reserveVaultIndexInReservePool] = unusedReserveVault;
        unusedAmounts[resPoolData_.selfIndexInReservePool] = unusedSelf;

        uint256 expectedBpt = BalancerV38020WeightedPoolMath.calcBptOutGivenUnbalancedIn(
            currentBalances, resPoolData_.weightsArray, unusedAmounts, poolTotalSupply, resPoolData_.reservePoolSwapFee
        );

        if (expectedBpt > 0) {
            layout_.balancerV3PrepayRouter
                .prepayAddLiquidityUnbalanced(address(resPoolData_.reservePool), unusedAmounts, expectedBpt, "");
        }
    }

    function _executeZapInIn(SeigniorageDETFRepo.Storage storage layout_, ExchangeInParams memory p_)
        internal
        returns (uint256 amountOut_)
    {
        // Secure token deposit first
        uint256 actualIn = _secureTokenTransfer(p_.tokenIn, p_.amountIn, p_.pretransferred);

        // Convert to reserve vault shares and send to Balancer vault
        uint256 originalAmountIn = _convertToReserveVault(layout_, p_.tokenIn, actualIn, p_.deadline);

        // Execute the mint with pool interaction
        amountOut_ = _executeMintWithPool(layout_, originalAmountIn, p_.minAmountOut, p_.recipient);
    }

    /**
     * @notice Converts input token to reserve vault shares.
     */
    function _convertToReserveVault(
        SeigniorageDETFRepo.Storage storage layout_,
        IERC20 tokenIn_,
        uint256 amountIn_,
        uint256 deadline_
    ) internal returns (uint256 reserveVaultOut_) {
        IStandardExchange reserveVault = layout_.reserveVault;
        IVault balV3Vault = BalancerV3VaultAwareRepo._balancerV3Vault();

        tokenIn_.safeTransfer(address(reserveVault), amountIn_);

        reserveVaultOut_ = reserveVault.exchangeIn(
            tokenIn_, amountIn_, IERC20(address(reserveVault)), 0, address(balV3Vault), true, deadline_
        );
    }

    /**
     * @notice Executes mint with pool interaction - handles liquidity add and seigniorage.
     */
    function _executeMintWithPool(
        SeigniorageDETFRepo.Storage storage layout_,
        uint256 originalAmountIn_,
        uint256 minAmountOut_,
        address recipient_
    ) internal returns (uint256 amountOut_) {
        // Load pool state
        ReservePoolData memory resPoolData;
        uint256[] memory currentRatedBalances = _loadReservePoolData(resPoolData, new uint256[](0));

        RBTData memory rbtData;
        _loadRBTData(rbtData);

        SRBTData memory sRbtData;
        _loadSRBTData(sRbtData, resPoolData);

        // Check price
        rbtData.selfDilutedPrice = _calcDilutedPriceFromData(rbtData, sRbtData, resPoolData);
        if (rbtData.selfDilutedPrice <= ONE_WAD) {
            revert PriceBelowPeg(rbtData.selfDilutedPrice, ONE_WAD);
        }

        // Calculate fees
        uint256 feeReductionPPM = layout_.feeOracle.seigniorageIncentivePercentageOfVault(address(this));
        uint256 amountInReduced = FixedPoint.mulDown(
            originalAmountIn_,
            FixedPoint.ONE - BetterMath._percentageOfWAD(resPoolData.reservePoolSwapFee, feeReductionPPM)
        );

        // Add liquidity to pool
        _addSingleSidedLiquidity(layout_, resPoolData, currentRatedBalances, originalAmountIn_);

        // Calculate mint amounts
        amountOut_ = _calcMintAmountsAndSeigniorage(
            layout_, resPoolData, sRbtData, originalAmountIn_, amountInReduced, minAmountOut_, recipient_
        );
    }

    /**
     * @notice Adds single-sided liquidity to the pool.
     */
    function _addSingleSidedLiquidity(
        SeigniorageDETFRepo.Storage storage layout_,
        ReservePoolData memory resPoolData_,
        uint256[] memory currentRatedBalances_,
        uint256 amountIn_
    ) internal {
        resPoolData_.expectedBpt =
            BalancerV38020WeightedPoolMath.calcBptOutGivenSingleIn(
                currentRatedBalances_,
                resPoolData_.weightsArray,
                resPoolData_.reserveVaultIndexInReservePool,
                amountIn_,
                resPoolData_.resPoolTotalSupply,
                resPoolData_.reservePoolSwapFee
            );

        uint256[] memory paymentAmountsIn = new uint256[](2);
        paymentAmountsIn[resPoolData_.reserveVaultIndexInReservePool] = amountIn_;

        layout_.balancerV3PrepayRouter
            .prepayAddLiquidityUnbalanced(
                address(resPoolData_.reservePool), paymentAmountsIn, resPoolData_.expectedBpt, ""
            );
    }

    /**
     * @notice Calculates mint amounts and seigniorage.
     */
    function _calcMintAmountsAndSeigniorage(
        SeigniorageDETFRepo.Storage storage layout_,
        ReservePoolData memory resPoolData_,
        SRBTData memory sRbtData_,
        uint256 originalAmountIn_,
        uint256 amountInReduced_,
        uint256 minAmountOut_,
        address recipient_
    ) internal returns (uint256 amountOut_) {
        uint256 effectiveInFull = FixedPoint.mulDown(
            originalAmountIn_, FixedPoint.ONE - resPoolData_.reservePoolSwapFee
        );

        uint256 amountOutFull = WeightedMath.computeOutGivenExactIn(
            resPoolData_.reserveVaultRatedBalance,
            resPoolData_.reserveVaultReservePoolWeight,
            resPoolData_.selfReservePoolRatedBalance,
            resPoolData_.selfReservePoolWeight,
            effectiveInFull
        );

        amountOut_ = WeightedMath.computeOutGivenExactIn(
            resPoolData_.reserveVaultRatedBalance,
            resPoolData_.reserveVaultReservePoolWeight,
            resPoolData_.selfReservePoolRatedBalance,
            resPoolData_.selfReservePoolWeight,
            amountInReduced_
        );

        if (amountOut_ < minAmountOut_) {
            revert MinAmountNotMet(minAmountOut_, amountOut_);
        }

        // Calculate and mint seigniorage
        SRBTAmounts memory srbt;
        srbt.effectiveMintPriceFull = FixedPoint.divDown(amountInReduced_, amountOutFull);
        srbt.premiumPerRBT = srbt.effectiveMintPriceFull - ONE_WAD;
        srbt.grossSeigniorage = FixedPoint.mulDown(amountOutFull, srbt.premiumPerRBT);
        srbt.discountRBT = amountOut_ - amountOutFull;
        srbt.discountMargin = FixedPoint.mulDown(srbt.discountRBT, ONE_WAD);
        srbt.profitMargin = srbt.grossSeigniorage + srbt.discountMargin;
        srbt.sRBTToMint = FixedPoint.divDown(srbt.profitMargin, ONE_WAD);

        ERC20Repo._mint(recipient_, amountOut_);
        if (srbt.sRBTToMint > 0) {
            sRbtData_.seigniorageToken.mint(address(layout_.seigniorageNFTVault), srbt.sRBTToMint);
        }
    }

    /**
     * @notice Executes redeem with pool interaction - handles liquidity removal.
     */
    function _executeRedeemWithPool(SeigniorageDETFRepo.Storage storage layout_, uint256 amountIn_)
        internal
        returns (uint256 reserveVaultOut_, ReservePoolData memory resPoolData_)
    {
        // Load pool state
        uint256[] memory currentRatedBalances = _loadReservePoolData(resPoolData_, new uint256[](0));

        RBTData memory rbtData;
        _loadRBTData(rbtData);

        SRBTData memory sRbtData;
        _loadSRBTData(sRbtData, resPoolData_);

        // Check price
        rbtData.selfDilutedPrice = _calcDilutedPriceFromData(rbtData, sRbtData, resPoolData_);
        if (rbtData.selfDilutedPrice > ONE_WAD) {
            revert PriceAbovePeg(rbtData.selfDilutedPrice, ONE_WAD);
        }

        // Calculate reduced fee
        uint256 feeReductionPPM = layout_.feeOracle.seigniorageIncentivePercentageOfVault(address(this));
        uint256 amountInReduced = FixedPoint.mulDown(
            amountIn_, FixedPoint.ONE - BetterMath._percentageOfWAD(resPoolData_.reservePoolSwapFee, feeReductionPPM)
        );

        // Calculate reserve vault out
        reserveVaultOut_ = WeightedMath.computeOutGivenExactIn(
            resPoolData_.selfReservePoolRatedBalance,
            resPoolData_.selfReservePoolWeight,
            resPoolData_.reserveVaultRatedBalance,
            resPoolData_.reserveVaultReservePoolWeight,
            amountInReduced
        );

        // Remove liquidity
        _removeProportionalLiquidity(layout_, resPoolData_, currentRatedBalances, reserveVaultOut_);
    }

    /**
     * @notice Removes proportional liquidity from the pool.
     */
    function _removeProportionalLiquidity(
        SeigniorageDETFRepo.Storage storage layout_,
        ReservePoolData memory resPoolData_,
        uint256[] memory currentRatedBalances_,
        uint256 reserveVaultOut_
    ) internal {
        resPoolData_.expectedBpt = BalancerV38020WeightedPoolMath.calcBptInGivenProportionalOut(
            currentRatedBalances_,
            resPoolData_.resPoolTotalSupply,
            resPoolData_.reserveVaultIndexInReservePool,
            reserveVaultOut_
        );

        // Transfer BPT to Balancer vault
        IERC20(address(resPoolData_.reservePool))
            .safeTransfer(address(resPoolData_.balV3Vault), resPoolData_.expectedBpt);

        // Remove liquidity
        uint256[] memory minAmountsOut = new uint256[](2);
        minAmountsOut[resPoolData_.reserveVaultIndexInReservePool] = reserveVaultOut_;

        layout_.balancerV3PrepayRouter
            .prepayRemoveLiquidityProportional(
                address(resPoolData_.reservePool), resPoolData_.expectedBpt, minAmountsOut, ""
            );
    }

    /**
     * @notice Converts reserve vault tokens to output token.
     */
    function _convertReserveToOutput(
        SeigniorageDETFRepo.Storage storage layout_,
        uint256 reserveVaultAmount_,
        IERC20 tokenOut_,
        uint256 minAmountOut_,
        address recipient_,
        uint256 deadline_
    ) internal returns (uint256 amountOut_) {
        IStandardExchange reserveVault = layout_.reserveVault;
        IERC20(address(reserveVault)).safeTransfer(address(reserveVault), reserveVaultAmount_);

        amountOut_ = reserveVault.exchangeIn(
            IERC20(address(reserveVault)), reserveVaultAmount_, tokenOut_, minAmountOut_, recipient_, true, deadline_
        );
    }

    function _executeZapOutIn(SeigniorageDETFRepo.Storage storage layout_, ExchangeInParams memory p_)
        internal
        returns (uint256 amountOut_)
    {
        // Burn DETF tokens
        _secureSelfBurn(msg.sender, p_.amountIn, p_.pretransferred);

        // Execute redeem with pool interaction
        ReservePoolData memory resPoolData;
        uint256 reserveVaultOut;
        (reserveVaultOut, resPoolData) = _executeRedeemWithPool(layout_, p_.amountIn);

        // Convert reserve vault to target token
        amountOut_ =
            _convertReserveToOutput(layout_, reserveVaultOut, p_.tokenOut, p_.minAmountOut, p_.recipient, p_.deadline);

        // Redeposit unused tokens
        _redepositUnusedTokens(layout_, resPoolData);
    }
}
