// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {IERC20} from '@crane/contracts/interfaces/IERC20.sol';
import {IPool} from '@crane/contracts/interfaces/protocols/dexes/aerodrome/IPool.sol';
import {IRouter as IAerodromeRouter} from '@crane/contracts/interfaces/protocols/dexes/aerodrome/IRouter.sol';
import {BetterSafeERC20} from '@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol';
import {BetterMath} from '@crane/contracts/utils/math/BetterMath.sol';
import {ConstProdUtils} from '@crane/contracts/utils/math/ConstProdUtils.sol';
import {ERC20Repo} from '@crane/contracts/tokens/ERC20/ERC20Repo.sol';
import {ERC4626Repo} from '@crane/contracts/tokens/ERC4626/ERC4626Repo.sol';
import {ERC4626Service} from '@crane/contracts/tokens/ERC4626/ERC4626Service.sol';
import {AerodromeUtils} from '@crane/contracts/utils/math/AerodromeUtils.sol';
import {AerodromeService} from '@crane/contracts/protocols/dexes/aerodrome/v1/services/AerodromeService.sol';
import {
    AerodromePoolMetadataRepo
} from '@crane/contracts/protocols/dexes/aerodrome/v1/aware/AerodromePoolMetadataRepo.sol';
import {ReentrancyLockModifiers} from '@crane/contracts/access/reentrancy/ReentrancyLockModifiers.sol';
import {
    AerodromeRouterAwareRepo
} from '@crane/contracts/protocols/dexes/aerodrome/v1/aware/AerodromeRouterAwareRepo.sol';

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IStandardExchangeErrors} from '@crane/contracts/interfaces/IStandardExchangeErrors.sol';
import {IStandardExchangeErrors} from '@crane/contracts/interfaces/IStandardExchangeErrors.sol';
import {IStandardExchangeOut} from 'contracts/interfaces/IStandardExchangeOut.sol';
import {ConstProdReserveVaultRepo} from 'contracts/vaults/ConstProdReserveVaultRepo.sol';
import {VaultFeeOracleQueryAwareRepo} from 'contracts/oracles/fee/VaultFeeOracleQueryAwareRepo.sol';
import {
    AerodromeStandardExchangeCommon
} from 'contracts/protocols/dexes/aerodrome/v1/AerodromeStandardExchangeCommon.sol';

abstract contract AerodromeStandardExchangeOutQueryTarget is
    AerodromeStandardExchangeCommon,
    ReentrancyLockModifiers,
    IStandardExchangeErrors
{
    using BetterSafeERC20 for IERC20;

    // Debug instrumentation removed — retained in history for investigation

    function previewExchangeOut(IERC20 tokenIn, IERC20 tokenOut, uint256 amountOut)
        external
        view
        returns (uint256 amountIn)
    {
        // Mirror the same 7-branch logic as exchangeOut but with view-only calculations

        // Determine actual token route from provided tokens.
        // Intended supported routes.
        // 1. Pass-through Swap - Swap of token contained in the underlying pool for the opposing token contained in the underlying pool.
        //    Implemented in first branch.
        // 2. Pass-through ZapIn - Deposit as ZapIn of token contained in the underlying pool for the underlying pool token.
        //    Implemented in second branch.
        // 3. Underlying Pool Vault Deposit - Deposit of the underlying pool token into the vault.
        //    Implemented in third branch.
        // 4. ZapIn Vault Deposit - Deposit as ZapIn of the token contained in the underlying pool for the underlying pool token into the vault.
        //    Implemented in fourth branch.
        // 5. Underlying Pool Vault Withdrawal - Withdraw of the underlying pool token from the vault.
        //    Implemented in fifth branch.
        // 6. Pass-through ZapOut - Withdraw as ZapOut of token contained in the underlying pool from the underlying pool as tokenIn.
        //    Implemented in sixth branch.
        // 7. ZapOut Vault Withdrawal - Withdraw as ZapOut of token contained in the underlying pool from the underlying pool token from the vault.
        //    Implemented in seventh branch.

        // ConstProdReserveVaultRepo.Storage storage constProd = ConstProdReserveVaultRepo._layoutStruct();
        // IPool pool = IPool(address(ERC4626Repo._reserveAsset()));
        // AerodromePoolMetadataRepo.Storage storage  = AerodromePoolMetadataRepo._layoutStruct();
        AeroReserve memory aeroReserve;
        aeroReserve.router = AerodromeRouterAwareRepo._aerodromeRouter();
        aeroReserve.pool = IPool(address(ERC4626Repo._reserveAsset()));

        /* ------------------------------------------------------------------ */
        /*                          Pass-through Swap                         */
        /* ------------------------------------------------------------------ */

        if (
            ConstProdReserveVaultRepo._isReserveAssetContained(address(tokenIn))
                && ConstProdReserveVaultRepo._isReserveAssetContained(address(tokenOut))
        ) {
            // Load pool reserves.
            (aeroReserve.knownReserve, aeroReserve.opposingReserve,) = aeroReserve.pool.getReserves();
            // Sort reserves to match tokenIn/tokenOut order.
            (aeroReserve.knownReserve, aeroReserve.opposingReserve) = ConstProdUtils._sortReserves(
                // address knownToken,
                address(tokenIn),
                // address token0,
                ConstProdReserveVaultRepo._token0(),
                // uint256 reserve0,
                aeroReserve.knownReserve,
                // uint256 reserve1
                aeroReserve.opposingReserve
            );
            // Calculate the amount in required to purchase the requested amount out.
            return ConstProdUtils._purchaseQuote(
                // uint256 amountOut,
                amountOut,
                // uint256 reserveIn,
                aeroReserve.knownReserve,
                // uint256 reserveOut,
                aeroReserve.opposingReserve,
                // uint256 feePercent,
                AerodromePoolMetadataRepo._factory()
                    .getFee(address(aeroReserve.pool), AerodromePoolMetadataRepo._isStable()),
                // uint256 feeDenominator
                AERO_FEE_DENOM
            );
        }

        /* ------------------------------------------------------------------ */
        /*                         Pass-through ZapIn                         */
        /* ------------------------------------------------------------------ */

        if (
            ConstProdReserveVaultRepo._isReserveAssetContained(address(tokenIn))
                && address(tokenOut) == address(aeroReserve.pool)
        ) {
            // Inverse of AerodromeUtils._quoteSwapDepositWithFee: given target LP amount out,
            // find minimum amountIn of tokenIn required. Uses ConstProdUtils binary-search inverse.
            (aeroReserve.knownReserve, aeroReserve.opposingReserve,) = aeroReserve.pool.getReserves();
            (aeroReserve.knownReserve, aeroReserve.opposingReserve) = ConstProdUtils._sortReserves(
                address(tokenIn),
                ConstProdReserveVaultRepo._token0(),
                aeroReserve.knownReserve,
                aeroReserve.opposingReserve
            );
            uint256 feePercent = AerodromePoolMetadataRepo._factory()
                .getFee(address(aeroReserve.pool), AerodromePoolMetadataRepo._isStable());
            // Use amountOut+1 to account for 1-wei rounding difference between the binary-search
            // math and the on-chain AerodromeService execution path (same as _execPassThroughZapIn).
            return ConstProdUtils._quoteZapInToTargetLPWithFee(
                // uint256 targetLP,
                amountOut + 1,
                // uint256 lpTotalSupply,
                IERC20(address(aeroReserve.pool)).totalSupply(),
                // uint256 reserveIn,
                aeroReserve.knownReserve,
                // uint256 reserveOut,
                aeroReserve.opposingReserve,
                // uint256 feePercent,
                feePercent,
                // uint256 feeDenominator,
                AERO_FEE_DENOM,
                // uint256 kLast (Aerodrome does not use protocol fee minting),
                0,
                // uint256 ownerFeeShare,
                0,
                // bool feeOn
                false
            );
        }

        /* ------------------------------------------------------------------ */
        /*                         Pass-through ZapOut                        */
        /* ------------------------------------------------------------------ */

        if (
            address(tokenIn) == address(aeroReserve.pool)
                && ConstProdReserveVaultRepo._isReserveAssetContained(address(tokenOut))
        ) {
            // Load pool reserves.
            (aeroReserve.knownReserve, aeroReserve.opposingReserve,) = aeroReserve.pool.getReserves();
            // Sort reserves to match tokenIn/tokenOut order.
            (aeroReserve.knownReserve, aeroReserve.opposingReserve) = ConstProdUtils._sortReserves(
                // address knownToken,
                address(tokenIn),
                // address token0,
                ConstProdReserveVaultRepo._token0(),
                // uint256 reserve0,
                aeroReserve.knownReserve,
                // uint256 reserve1
                aeroReserve.opposingReserve
            );
            // Calculate the amount of LP tokens needed to zapout to the desired amount out.
            amountIn = ConstProdUtils._quoteZapOutToTargetWithFee(
                // uint256 desiredOut,
                amountOut,
                // uint256 lpTotalSupply,
                IERC20(address(aeroReserve.pool)).totalSupply(),
                // uint256 reserveDesired,
                aeroReserve.knownReserve,
                // uint256 reserveOther,
                aeroReserve.opposingReserve,
                // uint256 feePercent,
                AerodromePoolMetadataRepo._factory()
                    .getFee(address(aeroReserve.pool), AerodromePoolMetadataRepo._isStable()),
                // uint256 feeDenominator,
                AERO_FEE_DENOM,
                // uint256 kLast,
                0,
                // uint256 ownerFeeShare,
                0,
                // bool feeOn
                false
            );
            return amountIn;
        }

        /* ------------------------------------------------------------------ */
        /*                    Underlying Pool Vault Deposit                   */
        /* ------------------------------------------------------------------ */

        if (address(tokenIn) == address(aeroReserve.pool) && address(tokenOut) == address(this)) {
            // Load pool reserves.
            (uint256 reserve0, uint256 reserve1,) = aeroReserve.pool.getReserves();
            // Calculate equivalent LP from accrued market maker fees.
            uint256 poolFeeLPShares = _calculateLPFromPoolFees(
                // uint256 claimable0,
                aeroReserve.pool.claimable0(address(this)),
                // uint256 claimable1,
                aeroReserve.pool.claimable1(address(this)),
                // uint256 reserve0,
                reserve0,
                // uint256 reserve1,
                reserve1,
                // uint256 lpTotalSupply,
                IERC20(address(aeroReserve.pool)).totalSupply(),
                // uint256 swapFeePercent
                AerodromePoolMetadataRepo._factory()
                    .getFee(address(aeroReserve.pool), AerodromePoolMetadataRepo._isStable())
            );
            // Calculate fee shares as percentage of equivalent LP from market maker fees.
            poolFeeLPShares = BetterMath._percentageOfWAD(
                // uint256 total,
                poolFeeLPShares,
                // uint256 percentage,
                VaultFeeOracleQueryAwareRepo._feeOracle().usageFeeOfVault(address(this))
            );
            // Load state once so we can reuse across operations.
            // Load vault LP reserve.
            uint256 vaultLpReserve = ERC4626Repo._lastTotalAssets();
            // Load total vault shares.
            uint256 vaultTotalShares = ERC20Repo._totalSupply();
            // Load configured decimal offset.
            uint8 decimalOffset = ERC4626Repo._decimalOffset();
            poolFeeLPShares =
                BetterMath._convertToSharesDown(poolFeeLPShares, vaultLpReserve, vaultTotalShares, decimalOffset);
            // Add calculated fee shares to vault total shares.
            vaultTotalShares += poolFeeLPShares;
            // Calculate the amount of LP tokens needed to mint the requested amount of vault shares.
            // Note: amountOut is the shares target passed in by the caller.
            return BetterMath._convertToAssetsUp(amountOut, vaultLpReserve, vaultTotalShares, decimalOffset);
        }
        /* ------------------------------------------------------------------ */
        /*                  Underlying Pool Vault Withdrawal                  */
        /* ------------------------------------------------------------------ */

        if (address(tokenIn) == address(this) && address(tokenOut) == address(aeroReserve.pool)) {
            // Load the pool reserves.
            (uint256 reserve0, uint256 reserve1,) = aeroReserve.pool.getReserves();
            // Calculate equivalent LP from accrued market maker fees.
            uint256 poolFeeLPShares = _calculateLPFromPoolFees(
                // uint256 claimable0,
                aeroReserve.pool.claimable0(address(this)),
                // uint256 claimable1,
                aeroReserve.pool.claimable1(address(this)),
                // uint256 reserve0,
                reserve0,
                // uint256 reserve1,
                reserve1,
                // uint256 lpTotalSupply,
                IERC20(address(aeroReserve.pool)).totalSupply(),
                // uint256 swapFeePercent
                AerodromePoolMetadataRepo._factory()
                    .getFee(address(aeroReserve.pool), AerodromePoolMetadataRepo._isStable())
            );
            // Calculate the vault fee as percentage of equivalent LP from market maker fes.
            poolFeeLPShares = BetterMath._percentageOfWAD(
                // uint256 total,
                poolFeeLPShares,
                // uint256 percentage,
                VaultFeeOracleQueryAwareRepo._feeOracle().usageFeeOfVault(address(this))
            );
            // Load vault LP reserve.
            uint256 vaultLpReserve = ERC4626Repo._lastTotalAssets();
            // Load vault total shares.
            uint256 vaultTotalShares = ERC20Repo._totalSupply();
            // Load decimal offset.
            uint8 decimalOffset = ERC4626Repo._decimalOffset();
            // Calculate vault fee shares.
            poolFeeLPShares =
                BetterMath._convertToSharesDown(poolFeeLPShares, vaultLpReserve, vaultTotalShares, decimalOffset);
            // Add vault fee shares to vault total shares.
            vaultTotalShares += poolFeeLPShares;
            // Calculate amount of shares needed to redeem at least amountOut LP tokens.
            // Note: amountOut is the LP target passed in by the caller.
            return BetterMath._convertToSharesUp(amountOut, vaultLpReserve, vaultTotalShares, decimalOffset);
        }

        /* ------------------------------------------------------------------ */
        /*                         ZapIn Vault Deposit                        */
        /* ------------------------------------------------------------------ */

        if (ConstProdReserveVaultRepo._isReserveAssetContained(address(tokenIn)) && address(tokenOut) == address(this))
        {
            // Two-step inverse:
            //   Step 1: Convert target shares -> target LP tokens using post-deposit ERC-4626 inverse.
            //   Step 2: Convert target LP -> amountIn of tokenIn via ZapIn inverse.
            (uint256 reserve0, uint256 reserve1,) = aeroReserve.pool.getReserves();
            uint256 lpTotalSupply = IERC20(address(aeroReserve.pool)).totalSupply();
            uint256 feePercent = AerodromePoolMetadataRepo._factory()
                .getFee(address(aeroReserve.pool), AerodromePoolMetadataRepo._isStable());

            // Compute post-compound vault state (mirrors exchangeIn Route 6 which calls _claimAndCompoundFees)
            PreviewState memory state = _calcPreviewState(aeroReserve.pool, reserve0, reserve1, lpTotalSupply, feePercent);

            // Step 1: ERC-4626 inverse — shares -> LP.
            // exchangeIn Route 6 computes shares = floor(LP * (S + 10^d) / (R_before + LP + 1))
            // Inverse: LP >= ceil(shares * (R_before + 1) / (S + 10^d - shares))
            uint256 decimalUnit = 10 ** state.decimalOffset;
            if (amountOut >= state.vaultTotalShares + decimalUnit) return 0;
            uint256 lpTarget;
            {
                uint256 numerator = amountOut * (state.vaultLpReserve + 1);
                uint256 denominator = state.vaultTotalShares + decimalUnit - amountOut;
                lpTarget = numerator / denominator;
                if (denominator > 0 && numerator % denominator != 0) {
                    lpTarget += 1;
                }
            }

            // Step 2: ZapIn inverse — LP target -> amountIn.
            (aeroReserve.knownReserve, aeroReserve.opposingReserve) = ConstProdUtils._sortReserves(
                address(tokenIn), ConstProdReserveVaultRepo._token0(), reserve0, reserve1
            );
            return ConstProdUtils._quoteZapInToTargetLPWithFee(
                // uint256 targetLP,
                lpTarget,
                // uint256 lpTotalSupply,
                lpTotalSupply,
                // uint256 reserveIn,
                aeroReserve.knownReserve,
                // uint256 reserveOut,
                aeroReserve.opposingReserve,
                // uint256 feePercent,
                feePercent,
                // uint256 feeDenominator,
                AERO_FEE_DENOM,
                // uint256 kLast (Aerodrome does not use protocol fee minting),
                0,
                // uint256 ownerFeeShare,
                0,
                // bool feeOn
                false
            );
        }

        /* ------------------------------------------------------------------ */
        /*                       ZapOut Vault Withdrawal                      */
        /* ------------------------------------------------------------------ */

        if (address(tokenIn) == address(this) && ConstProdReserveVaultRepo._isReserveAssetContained(address(tokenOut)))
        {
            uint256 lpTotalSupply = IERC20(address(aeroReserve.pool)).totalSupply();
            uint256 aeroSwapFeePercent = AerodromePoolMetadataRepo._factory()
                .getFee(address(aeroReserve.pool), AerodromePoolMetadataRepo._isStable());
            // Load the pool reserves.
            (uint256 reserve0, uint256 reserve1,) = aeroReserve.pool.getReserves();
            uint256 poolFeeLPShares = _calcVaultFeeLPAmount(
                // IPool pool,
                aeroReserve.pool,
                // uint256 reserve0,
                reserve0,
                // uint256 reserve1,
                reserve1,
                // uint256 lpTotalSupply,
                lpTotalSupply,
                // uint256 aeroSwapFeePercent
                aeroSwapFeePercent
            );
            // Load vault LP reserve.
            uint256 vaultLpReserve = ERC4626Repo._lastTotalAssets();
            // Load vault total shares.
            uint256 vaultTotalShares = ERC20Repo._totalSupply();
            // Load decimal offset.
            uint8 decimalOffset = ERC4626Repo._decimalOffset();
            // Calculate vault fee shares.
            poolFeeLPShares =
                BetterMath._convertToSharesDown(poolFeeLPShares, vaultLpReserve, vaultTotalShares, decimalOffset);
            // Add vault fee shares to vault total shares.
            vaultTotalShares += poolFeeLPShares;
            // Sort reserves to match tokenOut order.
            (uint256 knownReserve, uint256 opposingReserve) = ConstProdUtils._sortReserves(
                // address knownToken,
                address(tokenOut),
                // address token0,
                ConstProdReserveVaultRepo._token0(),
                // uint256 reserve0,
                reserve0,
                // uint256 reserve1
                reserve1
            );
            // Calculate the amount of LP tokens needed to zapout to the desired amount out.
            amountIn = ConstProdUtils._quoteZapOutToTargetWithFee(
                // uint256 desiredOut,
                amountOut,
                // uint256 lpTotalSupply,
                lpTotalSupply,
                // uint256 reserveDesired,
                knownReserve,
                // uint256 reserveOther,
                opposingReserve,
                // uint256 feePercent,
                aeroSwapFeePercent,
                // uint256 feeDenominator,
                AERO_FEE_DENOM,
                // uint256 kLast,
                0,
                // uint256 ownerFeeShare,
                0,
                // bool feeOn
                false
            );
            amountIn = BetterMath._convertToSharesUp(amountIn, vaultLpReserve, vaultTotalShares, decimalOffset);
            return amountIn;
        }

        revert InvalidRoute(address(tokenIn), address(tokenOut));
    }


}
