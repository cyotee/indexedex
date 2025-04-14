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
import {IStandardExchangeOut} from "contracts/interfaces/IStandardExchangeOut.sol";
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
 * @title SeigniorageDETFExchangeOutTarget
 * @author cyotee doge <not_cyotee@proton.me>
 * @notice Implementation of IStandardExchangeOut for Seigniorage DETF.
 * @dev Handles exact-output exchanges for mint and burn operations.
 *      When above peg: Users specify exact DETF output → calculates reserve input
 *      When below peg: Users specify exact reserve output → calculates DETF input
 */
contract SeigniorageDETFExchangeOutTarget is SeigniorageDETFCommon, ReentrancyLockModifiers, IStandardExchangeOut {
    using BetterSafeERC20 for IERC20;
    using SeigniorageDETFRepo for SeigniorageDETFRepo.Storage;

    struct ExchangeOutParams {
        IERC20 tokenIn;
        uint256 maxAmountIn;
        IERC20 tokenOut;
        uint256 amountOut;
        address recipient;
        bool pretransferred;
        uint256 deadline;
        uint256 dilutedPrice;
    }

    /* ---------------------------------------------------------------------- */
    /*                          Preview Exchange Out                          */
    /* ---------------------------------------------------------------------- */

    /**
     * @inheritdoc IStandardExchangeOut
     * @dev Calculates the amount of tokenIn required to receive exactly amountOut of tokenOut.
     */
    function previewExchangeOut(IERC20 tokenIn, IERC20 tokenOut, uint256 amountOut)
        external
        view
        returns (uint256 amountIn)
    {
        SeigniorageDETFRepo.Storage storage layout = SeigniorageDETFRepo._layout();

        ReservePoolState memory poolState;
        _loadReservePoolState(layout, poolState);

        uint256 dilutedPrice = _calcDilutedPrice(layout, poolState);

        /* ------------------------------------------------------------------ */
        /*             Reserve Vault → DETF (Mint - exact output)             */
        /* ------------------------------------------------------------------ */

        if (_isReserveVaultToken(layout, tokenIn) && _isSelfToken(tokenOut)) {
            if (!_isAbovePeg(dilutedPrice)) {
                revert PriceBelowPeg(dilutedPrice, ONE_WAD);
            }

            // Use WeightedMath to calculate reserve input for exact DETF output
            amountIn = WeightedMath.computeInGivenExactOut(
                poolState.reserveVaultBalance,
                poolState.reserveVaultWeight,
                poolState.selfBalance,
                poolState.selfWeight,
                amountOut
            );
            return amountIn;
        }

        /* ------------------------------------------------------------------ */
        /*             DETF → Reserve Vault (Burn - exact output)             */
        /* ------------------------------------------------------------------ */

        if (_isSelfToken(tokenIn) && _isReserveVaultToken(layout, tokenOut)) {
            if (!_isBelowPeg(dilutedPrice)) {
                revert PriceAbovePeg(dilutedPrice, ONE_WAD);
            }

            // Use WeightedMath to calculate DETF input for exact reserve output
            amountIn = WeightedMath.computeInGivenExactOut(
                poolState.selfBalance,
                poolState.selfWeight,
                poolState.reserveVaultBalance,
                poolState.reserveVaultWeight,
                amountOut
            );
            return amountIn;
        }

        /* ------------------------------------------------------------------ */
        /*        Reserve Vault Constituent → DETF (ZapIn - exact output)     */
        /* ------------------------------------------------------------------ */

        if (_isValidMintToken(layout, tokenIn) && _isSelfToken(tokenOut)) {
            if (!_isAbovePeg(dilutedPrice)) {
                revert PriceBelowPeg(dilutedPrice, ONE_WAD);
            }

            // Calculate reserve needed using WeightedMath
            uint256 reserveNeeded = WeightedMath.computeInGivenExactOut(
                poolState.reserveVaultBalance,
                poolState.reserveVaultWeight,
                poolState.selfBalance,
                poolState.selfWeight,
                amountOut
            );

            IStandardExchange reserveVault = layout.reserveVault;
            amountIn = reserveVault.previewExchangeOut(tokenIn, IERC20(address(reserveVault)), reserveNeeded);
            return amountIn;
        }

        /* ------------------------------------------------------------------ */
        /*        DETF → Reserve Vault Constituent (ZapOut - exact output)    */
        /* ------------------------------------------------------------------ */

        if (_isSelfToken(tokenIn) && _isValidMintToken(layout, tokenOut)) {
            if (!_isBelowPeg(dilutedPrice)) {
                revert PriceAbovePeg(dilutedPrice, ONE_WAD);
            }

            IStandardExchange reserveVault = layout.reserveVault;
            uint256 reserveNeeded = reserveVault.previewExchangeOut(IERC20(address(reserveVault)), tokenOut, amountOut);

            // Calculate DETF needed using WeightedMath
            amountIn = WeightedMath.computeInGivenExactOut(
                poolState.selfBalance,
                poolState.selfWeight,
                poolState.reserveVaultBalance,
                poolState.reserveVaultWeight,
                reserveNeeded
            );
            return amountIn;
        }

        /* ------------------------------------------------------------------ */
        /*                         DETF ↔ sRBT (1:1)                         */
        /* ------------------------------------------------------------------ */

        if (_isSelfToken(tokenIn) && address(tokenOut) == address(layout.seigniorageToken)) {
            if (!_isAbovePeg(dilutedPrice)) {
                revert PriceBelowPeg(dilutedPrice, ONE_WAD);
            }
            return amountOut;
        }

        if (address(tokenIn) == address(layout.seigniorageToken) && _isSelfToken(tokenOut)) {
            if (dilutedPrice < ONE_WAD) {
                revert PriceBelowPeg(dilutedPrice, ONE_WAD);
            }
            return amountOut;
        }

        revert InvalidRoute(address(tokenIn), address(tokenOut));
    }

    /* ---------------------------------------------------------------------- */
    /*                              Exchange Out                              */
    /* ---------------------------------------------------------------------- */

    /**
     * @inheritdoc IStandardExchangeOut
     */
    function exchangeOut(
        IERC20 tokenIn,
        uint256 maxAmountIn,
        IERC20 tokenOut,
        uint256 amountOut,
        address recipient,
        bool pretransferred,
        uint256 deadline
    ) external lock returns (uint256 amountIn) {
        if (block.timestamp > deadline) {
            revert DeadlineExceeded(deadline, block.timestamp);
        }

        SeigniorageDETFRepo.Storage storage layout = SeigniorageDETFRepo._layout();

        ReservePoolState memory poolState;
        _loadReservePoolState(layout, poolState);

        uint256 dilutedPrice = _calcDilutedPrice(layout, poolState);

        ExchangeOutParams memory params = ExchangeOutParams({
            tokenIn: tokenIn,
            maxAmountIn: maxAmountIn,
            tokenOut: tokenOut,
            amountOut: amountOut,
            recipient: recipient,
            pretransferred: pretransferred,
            deadline: deadline,
            dilutedPrice: dilutedPrice
        });

        if (_isReserveVaultToken(layout, tokenIn) && _isSelfToken(tokenOut)) {
            return _executeReserveToDetfOut(layout, params);
        }

        if (_isSelfToken(tokenIn) && _isReserveVaultToken(layout, tokenOut)) {
            return _executeDetfToReserveOut(layout, params);
        }

        if (_isValidMintToken(layout, tokenIn) && _isSelfToken(tokenOut)) {
            return _executeZapInOut(layout, params);
        }

        if (_isSelfToken(tokenIn) && _isValidMintToken(layout, tokenOut)) {
            return _executeZapOutOut(layout, params);
        }

        // DETF (RBT) -> sRBT (exact output, 1:1) when above peg.
        if (_isSelfToken(tokenIn) && address(tokenOut) == address(layout.seigniorageToken)) {
            if (!_isAbovePeg(dilutedPrice)) {
                revert PriceBelowPeg(dilutedPrice, ONE_WAD);
            }

            amountIn = amountOut;
            if (amountIn > maxAmountIn) {
                revert MaxAmountExceeded(maxAmountIn, amountIn);
            }

            if (recipient == address(0)) {
                recipient = msg.sender;
            }

            _secureSelfBurn(msg.sender, amountIn, pretransferred);
            layout.seigniorageToken.mint(recipient, amountOut);
            return amountIn;
        }

        // sRBT -> DETF (RBT) (exact output, 1:1) when at-or-above peg.
        if (address(tokenIn) == address(layout.seigniorageToken) && _isSelfToken(tokenOut)) {
            if (dilutedPrice < ONE_WAD) {
                revert PriceBelowPeg(dilutedPrice, ONE_WAD);
            }

            amountIn = amountOut;
            if (amountIn > maxAmountIn) {
                revert MaxAmountExceeded(maxAmountIn, amountIn);
            }

            if (recipient == address(0)) {
                recipient = msg.sender;
            }

            address burnFrom = pretransferred ? address(this) : msg.sender;
            layout.seigniorageToken.burn(burnFrom, amountIn);
            ERC20Repo._mint(recipient, amountOut);
            return amountIn;
        }

        revert InvalidRoute(address(tokenIn), address(tokenOut));
    }

    /* ---------------------------------------------------------------------- */
    /*                       Exchange Out Route Handlers                      */
    /* ---------------------------------------------------------------------- */

    function _executeReserveToDetfOut(SeigniorageDETFRepo.Storage storage layout_, ExchangeOutParams memory p_)
        internal
        returns (uint256 amountIn_)
    {
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

        // Calculate reduced fee
        uint256 feeReductionPPM = layout_.feeOracle.seigniorageIncentivePercentageOfVault(address(this));
        uint256 feeAdjusted =
            FixedPoint.ONE - BetterMath._percentageOfWAD(resPoolData.reservePoolSwapFee, feeReductionPPM);

        // Use WeightedMath to calculate amountIn for exact amountOut
        amountIn_ = WeightedMath.computeInGivenExactOut(
            resPoolData.reserveVaultRatedBalance,
            resPoolData.reserveVaultReservePoolWeight,
            resPoolData.selfReservePoolRatedBalance,
            resPoolData.selfReservePoolWeight,
            p_.amountOut
        );

        // Apply fee adjustment (reverse)
        amountIn_ = FixedPoint.divUp(amountIn_, feeAdjusted);

        if (amountIn_ > p_.maxAmountIn) {
            revert MaxAmountExceeded(p_.maxAmountIn, amountIn_);
        }

        // Secure token transfer
        uint256 actualIn = _secureTokenTransfer(p_.tokenIn, amountIn_, p_.pretransferred);
        if (actualIn < amountIn_) {
            revert TransferAmountNotReceived(amountIn_, actualIn);
        }

        // Execute mint with pool
        _executeMintExactWithPool(
            layout_, resPoolData, sRbtData, currentRatedBalances, actualIn, p_.amountOut, p_.recipient
        );

        _refundExcess(p_.tokenIn, p_.maxAmountIn, amountIn_, p_.pretransferred, msg.sender);
    }

    function _executeDetfToReserveOut(SeigniorageDETFRepo.Storage storage layout_, ExchangeOutParams memory p_)
        internal
        returns (uint256 amountIn_)
    {
        // Load pool state
        ReservePoolData memory resPoolData;
        uint256[] memory currentRatedBalances = _loadReservePoolData(resPoolData, new uint256[](0));

        RBTData memory rbtData;
        _loadRBTData(rbtData);

        SRBTData memory sRbtData;
        _loadSRBTData(sRbtData, resPoolData);

        // Check price
        rbtData.selfDilutedPrice = _calcDilutedPriceFromData(rbtData, sRbtData, resPoolData);
        if (rbtData.selfDilutedPrice > ONE_WAD) {
            revert PriceAbovePeg(rbtData.selfDilutedPrice, ONE_WAD);
        }

        // Calculate reduced fee
        uint256 feeReductionPPM = layout_.feeOracle.seigniorageIncentivePercentageOfVault(address(this));
        uint256 feeAdjusted =
            FixedPoint.ONE - BetterMath._percentageOfWAD(resPoolData.reservePoolSwapFee, feeReductionPPM);

        // Use WeightedMath to calculate DETF needed for exact reserve vault out
        amountIn_ = WeightedMath.computeInGivenExactOut(
            resPoolData.selfReservePoolRatedBalance,
            resPoolData.selfReservePoolWeight,
            resPoolData.reserveVaultRatedBalance,
            resPoolData.reserveVaultReservePoolWeight,
            p_.amountOut
        );

        // Apply fee adjustment (reverse)
        amountIn_ = FixedPoint.divUp(amountIn_, feeAdjusted);

        if (amountIn_ > p_.maxAmountIn) {
            revert MaxAmountExceeded(p_.maxAmountIn, amountIn_);
        }

        _secureSelfBurn(msg.sender, amountIn_, p_.pretransferred);

        // Execute burn with pool
        _executeBurnExactWithPool(layout_, resPoolData, currentRatedBalances, p_.amountOut, p_.recipient);
    }

    function _executeZapInOut(SeigniorageDETFRepo.Storage storage layout_, ExchangeOutParams memory p_)
        internal
        returns (uint256 amountIn_)
    {
        // Calculate reserve needed
        uint256 reserveNeeded = _calcReserveNeededForMint(layout_, p_.amountOut);

        // Get constituent amount needed from reserve vault
        IStandardExchange reserveVault = layout_.reserveVault;
        amountIn_ = reserveVault.previewExchangeOut(p_.tokenIn, IERC20(address(reserveVault)), reserveNeeded);

        if (amountIn_ > p_.maxAmountIn) {
            revert MaxAmountExceeded(p_.maxAmountIn, amountIn_);
        }

        uint256 actualIn = _secureTokenTransfer(p_.tokenIn, amountIn_, p_.pretransferred);
        if (actualIn < amountIn_) {
            revert TransferAmountNotReceived(amountIn_, actualIn);
        }

        // Convert to reserve vault shares and execute mint
        uint256 reserveReceived = _convertAndDeposit(layout_, p_.tokenIn, actualIn, reserveNeeded, p_.deadline);

        // Execute mint with pool
        _executeMintWithPoolForZap(layout_, reserveReceived, p_.amountOut, p_.recipient);

        _refundExcess(p_.tokenIn, p_.maxAmountIn, amountIn_, p_.pretransferred, msg.sender);
    }

    function _executeZapOutOut(SeigniorageDETFRepo.Storage storage layout_, ExchangeOutParams memory p_)
        internal
        returns (uint256 amountIn_)
    {
        // Calculate reserve vault needed for exact output
        IStandardExchange reserveVault = layout_.reserveVault;
        uint256 reserveNeeded =
            reserveVault.previewExchangeOut(IERC20(address(reserveVault)), p_.tokenOut, p_.amountOut);

        // Calculate DETF needed for burn
        amountIn_ = _calcDetfNeededForBurn(layout_, reserveNeeded);

        if (amountIn_ > p_.maxAmountIn) {
            revert MaxAmountExceeded(p_.maxAmountIn, amountIn_);
        }

        _secureSelfBurn(msg.sender, amountIn_, p_.pretransferred);

        // Execute burn with pool to get reserve vault
        _executeBurnWithPoolForZap(layout_, reserveNeeded, address(reserveVault));

        // Convert reserve vault to final output token
        IERC20(address(reserveVault)).safeTransfer(address(reserveVault), reserveNeeded);
        reserveVault.exchangeOut(
            IERC20(address(reserveVault)), reserveNeeded, p_.tokenOut, p_.amountOut, p_.recipient, true, p_.deadline
        );
    }

    /* ---------------------------------------------------------------------- */
    /*                          Pool Execution Helpers                        */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice Executes mint with pool interaction for exact output.
     */
    function _executeMintExactWithPool(
        SeigniorageDETFRepo.Storage storage layout_,
        ReservePoolData memory resPoolData_,
        SRBTData memory sRbtData_,
        uint256[] memory currentRatedBalances_,
        uint256 reserveAmount_,
        uint256 detfAmount_,
        address recipient_
    ) internal {
        // Calculate BPT for adding liquidity
        resPoolData_.expectedBpt = BalancerV38020WeightedPoolMath.calcBptOutGivenSingleIn(
            currentRatedBalances_,
            resPoolData_.weightsArray,
            resPoolData_.reserveVaultIndexInReservePool,
            reserveAmount_,
            resPoolData_.resPoolTotalSupply,
            resPoolData_.reservePoolSwapFee
        );

        // Add liquidity to pool
        uint256[] memory paymentAmountsIn = new uint256[](2);
        paymentAmountsIn[resPoolData_.reserveVaultIndexInReservePool] = reserveAmount_;

        layout_.balancerV3PrepayRouter
            .prepayAddLiquidityUnbalanced(
                address(resPoolData_.reservePool), paymentAmountsIn, resPoolData_.expectedBpt, ""
            );

        // Calculate seigniorage
        uint256 feeReductionPPM = layout_.feeOracle.seigniorageIncentivePercentageOfVault(address(this));
        uint256 amountInReduced = FixedPoint.mulDown(
            reserveAmount_,
            FixedPoint.ONE - BetterMath._percentageOfWAD(resPoolData_.reservePoolSwapFee, feeReductionPPM)
        );

        SRBTAmounts memory srbt;
        srbt.effectiveMintPriceFull = FixedPoint.divDown(amountInReduced, detfAmount_);
        if (srbt.effectiveMintPriceFull > ONE_WAD) {
            srbt.premiumPerRBT = srbt.effectiveMintPriceFull - ONE_WAD;
            srbt.grossSeigniorage = FixedPoint.mulDown(detfAmount_, srbt.premiumPerRBT);
            srbt.sRBTToMint = FixedPoint.divDown(srbt.grossSeigniorage, ONE_WAD);
        }

        // Mint DETF to recipient
        ERC20Repo._mint(recipient_, detfAmount_);

        // Mint sRBT if any
        if (srbt.sRBTToMint > 0) {
            sRbtData_.seigniorageToken.mint(address(layout_.seigniorageNFTVault), srbt.sRBTToMint);
        }
    }

    /**
     * @notice Executes burn with pool interaction for exact output.
     */
    function _executeBurnExactWithPool(
        SeigniorageDETFRepo.Storage storage layout_,
        ReservePoolData memory resPoolData_,
        uint256[] memory currentRatedBalances_,
        uint256 reserveAmount_,
        address recipient_
    ) internal {
        // Calculate BPT needed for proportional exit
        resPoolData_.expectedBpt = BalancerV38020WeightedPoolMath.calcBptInGivenProportionalOut(
            currentRatedBalances_,
            resPoolData_.resPoolTotalSupply,
            resPoolData_.reserveVaultIndexInReservePool,
            reserveAmount_
        );

        // Transfer BPT to Balancer vault
        IERC20(address(resPoolData_.reservePool))
            .safeTransfer(address(resPoolData_.balV3Vault), resPoolData_.expectedBpt);

        // Remove liquidity
        uint256[] memory minAmountsOut = new uint256[](2);
        minAmountsOut[resPoolData_.reserveVaultIndexInReservePool] = reserveAmount_;

        layout_.balancerV3PrepayRouter
            .prepayRemoveLiquidityProportional(
                address(resPoolData_.reservePool), resPoolData_.expectedBpt, minAmountsOut, ""
            );

        // Transfer reserve vault to recipient
        IERC20(address(layout_.reserveVault)).safeTransfer(recipient_, reserveAmount_);

        // Redeposit unused tokens
        _redepositUnusedTokens(layout_, resPoolData_);
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

    /* ---------------------------------------------------------------------- */
    /*                          Zap Helper Functions                          */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice Calculates reserve vault needed to mint exact DETF using pool math.
     */
    function _calcReserveNeededForMint(SeigniorageDETFRepo.Storage storage layout_, uint256 detfAmount_)
        internal
        view
        returns (uint256 reserveNeeded_)
    {
        ReservePoolData memory resPoolData;
        _loadReservePoolData(resPoolData, new uint256[](0));

        RBTData memory rbtData;
        _loadRBTData(rbtData);

        SRBTData memory sRbtData;
        _loadSRBTData(sRbtData, resPoolData);

        // Check price
        rbtData.selfDilutedPrice = _calcDilutedPriceFromData(rbtData, sRbtData, resPoolData);
        if (rbtData.selfDilutedPrice <= ONE_WAD) {
            revert PriceBelowPeg(rbtData.selfDilutedPrice, ONE_WAD);
        }

        uint256 feeReductionPPM = layout_.feeOracle.seigniorageIncentivePercentageOfVault(address(this));
        uint256 feeAdjusted =
            FixedPoint.ONE - BetterMath._percentageOfWAD(resPoolData.reservePoolSwapFee, feeReductionPPM);

        reserveNeeded_ = WeightedMath.computeInGivenExactOut(
            resPoolData.reserveVaultRatedBalance,
            resPoolData.reserveVaultReservePoolWeight,
            resPoolData.selfReservePoolRatedBalance,
            resPoolData.selfReservePoolWeight,
            detfAmount_
        );
        reserveNeeded_ = FixedPoint.divUp(reserveNeeded_, feeAdjusted);
    }

    /**
     * @notice Converts constituent to reserve vault and deposits to Balancer vault.
     */
    function _convertAndDeposit(
        SeigniorageDETFRepo.Storage storage layout_,
        IERC20 tokenIn_,
        uint256 actualIn_,
        uint256 reserveNeeded_,
        uint256 deadline_
    ) internal returns (uint256 reserveReceived_) {
        IStandardExchange reserveVault = layout_.reserveVault;
        IVault balV3Vault = BalancerV3VaultAwareRepo._balancerV3Vault();

        tokenIn_.safeTransfer(address(reserveVault), actualIn_);
        reserveReceived_ = reserveVault.exchangeOut(
            tokenIn_, actualIn_, IERC20(address(reserveVault)), reserveNeeded_, address(balV3Vault), true, deadline_
        );
    }

    /**
     * @notice Executes mint with pool for zap operations.
     */
    function _executeMintWithPoolForZap(
        SeigniorageDETFRepo.Storage storage layout_,
        uint256 reserveAmount_,
        uint256 detfAmount_,
        address recipient_
    ) internal {
        ReservePoolData memory resPoolData;
        uint256[] memory currentRatedBalances = _loadReservePoolData(resPoolData, new uint256[](0));

        SRBTData memory sRbtData;
        _loadSRBTData(sRbtData, resPoolData);

        _executeMintExactWithPool(
            layout_, resPoolData, sRbtData, currentRatedBalances, reserveAmount_, detfAmount_, recipient_
        );
    }

    /**
     * @notice Calculates DETF needed for burn using pool math.
     */
    function _calcDetfNeededForBurn(SeigniorageDETFRepo.Storage storage layout_, uint256 reserveAmount_)
        internal
        view
        returns (uint256 detfNeeded_)
    {
        ReservePoolData memory resPoolData;
        _loadReservePoolData(resPoolData, new uint256[](0));

        RBTData memory rbtData;
        _loadRBTData(rbtData);

        SRBTData memory sRbtData;
        _loadSRBTData(sRbtData, resPoolData);

        // Check price
        rbtData.selfDilutedPrice = _calcDilutedPriceFromData(rbtData, sRbtData, resPoolData);
        if (rbtData.selfDilutedPrice > ONE_WAD) {
            revert PriceAbovePeg(rbtData.selfDilutedPrice, ONE_WAD);
        }

        uint256 feeReductionPPM = layout_.feeOracle.seigniorageIncentivePercentageOfVault(address(this));
        uint256 feeAdjusted =
            FixedPoint.ONE - BetterMath._percentageOfWAD(resPoolData.reservePoolSwapFee, feeReductionPPM);

        detfNeeded_ = WeightedMath.computeInGivenExactOut(
            resPoolData.selfReservePoolRatedBalance,
            resPoolData.selfReservePoolWeight,
            resPoolData.reserveVaultRatedBalance,
            resPoolData.reserveVaultReservePoolWeight,
            reserveAmount_
        );
        detfNeeded_ = FixedPoint.divUp(detfNeeded_, feeAdjusted);
    }

    /**
     * @notice Executes burn with pool for zap operations.
     */
    function _executeBurnWithPoolForZap(
        SeigniorageDETFRepo.Storage storage layout_,
        uint256 reserveAmount_,
        address recipient_
    ) internal {
        ReservePoolData memory resPoolData;
        uint256[] memory currentRatedBalances = _loadReservePoolData(resPoolData, new uint256[](0));

        _executeBurnExactWithPool(layout_, resPoolData, currentRatedBalances, reserveAmount_, recipient_);
    }
}
