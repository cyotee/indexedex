// SPDX-License-Identifier: BUSL-1.1
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

import {IStandardExchangeOut} from 'contracts/interfaces/IStandardExchangeOut.sol';
import {ConstProdReserveVaultRepo} from 'contracts/vaults/ConstProdReserveVaultRepo.sol';
import {VaultFeeOracleQueryAwareRepo} from 'contracts/oracles/fee/VaultFeeOracleQueryAwareRepo.sol';
import {
    AerodromeStandardExchangeCommon
} from 'contracts/protocols/dexes/aerodrome/v1/AerodromeStandardExchangeCommon.sol';

contract AerodromeStandardExchangeOutTarget is
    AerodromeStandardExchangeCommon,
    ReentrancyLockModifiers,
    IStandardExchangeOut
{
    using BetterSafeERC20 for IERC20;

    // Debug instrumentation removed — retained in history for investigation

    uint256 constant AERO_FEE_DENOM = 10000;

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

        // ConstProdReserveVaultRepo.Storage storage constProd = ConstProdReserveVaultRepo._layout();
        // IPool pool = IPool(address(ERC4626Repo._reserveAsset()));
        // AerodromePoolMetadataRepo.Storage storage  = AerodromePoolMetadataRepo._layout();
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
            // No gas efficient way to calculate the the amount in for a ZapIn to target amount out.
            revert RouteNotSupported(
                address(tokenIn), address(tokenOut), IStandardExchangeOut.previewExchangeOut.selector
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
            return BetterMath._convertToAssetsUp(amountIn, vaultLpReserve, vaultTotalShares, decimalOffset);
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
            // Calculate amount of
            return BetterMath._convertToSharesDown(amountIn, vaultLpReserve, vaultTotalShares, decimalOffset);
        }

        /* ------------------------------------------------------------------ */
        /*                         ZapIn Vault Deposit                        */
        /* ------------------------------------------------------------------ */

        if (ConstProdReserveVaultRepo._isReserveAssetContained(address(tokenIn)) && address(tokenOut) == address(this))
        {
            // No gas efficient way to calculate the the amount in for a ZapIn to target amount out.
            revert RouteNotSupported(
                address(tokenIn), address(tokenOut), IStandardExchangeOut.previewExchangeOut.selector
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

    function _execUnderlyingPoolVaultDeposit(OutArgs memory args, AeroReserve memory aeroReserve)
        internal
        returns (uint256)
    {
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
            AerodromePoolMetadataRepo._factory().getFee(address(aeroReserve.pool), false)
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
        ERC20Repo._mint(
            // address account,
            address(VaultFeeOracleQueryAwareRepo._feeOracle().feeTo()),
            // uint256 amount,
            poolFeeLPShares
        );
        // Add calculated fee shares to vault total shares.
        vaultTotalShares += poolFeeLPShares;
        // Calculate the amount of LP tokens needed to mint the requested amount of vault shares.
        uint256 amountIn =
            BetterMath._convertToAssetsUp(args.amountOut, vaultLpReserve, vaultTotalShares, decimalOffset);
        amountIn = ERC4626Service._secureReserveDeposit(ERC4626Repo._layout(), vaultLpReserve, amountIn);
        if (args.maxAmountIn < amountIn) {
            revert MaxAmountExceeded(args.maxAmountIn, amountIn);
        }
        ERC20Repo._mint(
            // address account,
            args.recipient,
            // uint256 amount,
            amountIn
        );
        return amountIn;
    }

    // Helper struct to reduce stack usage in pass-through ZapOut flow
    struct PassThroughZapOutState {
        uint256 reserve0;
        uint256 reserve1;
        uint256 knownReserve;
        uint256 opposingReserve;
        uint256 lpTotalSupply;
        uint256 amountIn;
        address opposingToken;
    }

    function _execPassThroughZapOut(OutArgs memory args, AeroReserve memory aeroReserve) internal returns (uint256) {
        PassThroughZapOutState memory s;

        // Load pool reserves and derived values
        (s.reserve0, s.reserve1,) = aeroReserve.pool.getReserves();
        (s.knownReserve, s.opposingReserve) = ConstProdUtils._sortReserves(
            address(args.tokenOut), ConstProdReserveVaultRepo._token0(), s.reserve0, s.reserve1
        );
        s.lpTotalSupply = IERC20(address(aeroReserve.pool)).totalSupply();

        // Calculate the amount of LP tokens needed to zapout to the desired amount out.
        s.amountIn = ConstProdUtils._quoteZapOutToTargetWithFee(
            // uint256 desiredOut,
            args.amountOut,
            // uint256 lpTotalSupply,
            s.lpTotalSupply,
            // uint256 reserveDesired,
            s.knownReserve,
            // uint256 reserveOther,
            s.opposingReserve,
            // uint256 feePercent,
            AerodromePoolMetadataRepo._factory().getFee(address(aeroReserve.pool), false),
            // uint256 feeDenominator,
            AERO_FEE_DENOM,
            // uint256 kLast,
            0,
            // uint256 ownerFeeShare,
            0,
            // bool feeOn
            false
        );

        if (args.maxAmountIn < s.amountIn) {
            revert MaxAmountExceeded(args.maxAmountIn, s.amountIn);
        }

        // Transfer tokens in (may be pretransferred)
        // uint256 balVaultBefore = IERC20(address(aeroReserve.pool)).balanceOf(address(this));
        // uint256 balCallerBefore = IERC20(address(aeroReserve.pool)).balanceOf(msg.sender);
        _secureTokenTransfer(args.tokenIn, s.amountIn, args.pretransferred);
        // uint256 balVaultAfter = IERC20(address(aeroReserve.pool)).balanceOf(address(this));
        // uint256 balCallerAfter = IERC20(address(aeroReserve.pool)).balanceOf(msg.sender);

        // Build params and execute withdraw+swap sending swapped tokens to vault
        s.opposingToken = ConstProdReserveVaultRepo._opposingToken(address(args.tokenOut));
        AerodromeService.WithdrawSwapVolatileParams memory params = AerodromeService.WithdrawSwapVolatileParams({
            aerodromeRouter: aeroReserve.router,
            pool: aeroReserve.pool,
            factory: AerodromePoolMetadataRepo._factory(),
            tokenOut: IERC20(args.tokenOut),
            opposingToken: IERC20(s.opposingToken),
            lpBurnAmt: s.amountIn,
            recipient: address(this),
            deadline: args.deadline
        });

        // Approve LP tokens for the router to burn and execute
        IERC20(address(aeroReserve.pool)).approve(address(aeroReserve.router), s.amountIn);
        uint256 actualOut = AerodromeService._withdrawSwapVolatile(params);
        // log balances after withdraw+swap (kept as local vars for potential future debug)
        // uint256 balVaultAfterSwap = IERC20(address(aeroReserve.pool)).balanceOf(address(this));
        if (actualOut < args.amountOut) {
            revert AmountOutNotMet(args.amountOut, actualOut);
        }

        // Transfer exact requested amount to recipient and refund any excess
        IERC20(address(args.tokenOut)).safeTransfer(args.recipient, args.amountOut);
        _refundExcess(args.tokenIn, args.maxAmountIn, s.amountIn, args.pretransferred, msg.sender);

        // Sanity check stored reserve
        {
            uint256 poolBalance = IERC20(address(aeroReserve.pool)).balanceOf(address(this));
            uint256 storedReserve = ERC4626Repo._lastTotalAssets();
            if (poolBalance != storedReserve) {
                revert();
            }
        }

        return s.amountIn;
    }

    function exchangeOut(
        IERC20 tokenIn,
        uint256 maxAmountIn,
        IERC20 tokenOut,
        uint256 amountOut,
        address recipient,
        bool pretransferred,
        uint256 deadline
    ) external lock returns (uint256 amountIn) {
        OutArgs memory args = OutArgs({
            tokenIn: tokenIn,
            maxAmountIn: maxAmountIn,
            tokenOut: tokenOut,
            amountOut: amountOut,
            recipient: recipient,
            pretransferred: pretransferred,
            deadline: deadline
        });

        // ConstProdReserveVaultRepo.Storage storage constProd = ConstProdReserveVaultRepo._layout();
        // AerodromePoolMetadataRepo.Storage storage  = AerodromePoolMetadataRepo._layout();
        // IAerodromeRouter aerodromeRouter = AerodromeRouterAwareRepo._aerodromeRouter();
        // IPool pool = IPool(address(ERC4626Repo._reserveAsset()));
        AeroReserve memory aeroReserve;
        aeroReserve.router = AerodromeRouterAwareRepo._aerodromeRouter();
        aeroReserve.pool = IPool(address(ERC4626Repo._reserveAsset()));

        /* ------------------------------------------------------------------ */
        /*                          Pass-through Swap                         */
        /* ------------------------------------------------------------------ */

        if (
            ConstProdReserveVaultRepo._isReserveAssetContained(address(args.tokenIn))
                && ConstProdReserveVaultRepo._isReserveAssetContained(address(args.tokenOut))
        ) {
            // Load pool reserves.
            (aeroReserve.knownReserve, aeroReserve.opposingReserve,) = aeroReserve.pool.getReserves();
            // Sort reserves to match tokenIn/tokenOut order.
            (uint256 knownReserve, uint256 opposingReserve) = ConstProdUtils._sortReserves(
                // address knownToken,
                address(args.tokenIn),
                // address token0,
                ConstProdReserveVaultRepo._token0(),
                // uint256 reserve0,
                aeroReserve.knownReserve,
                // uint256 reserve1
                aeroReserve.opposingReserve
            );
            // Calculate the amount in required to purchase the requested amount out.
            amountIn = ConstProdUtils._purchaseQuote(
                // uint256 amountOut,
                args.amountOut,
                // uint256 reserveIn,
                knownReserve,
                // uint256 reserveOut,
                opposingReserve,
                // uint256 feePercent,
                AerodromePoolMetadataRepo._factory().getFee(address(aeroReserve.pool), false),
                // uint256 feeDenominator
                AERO_FEE_DENOM
            );
            if (args.maxAmountIn < amountIn) {
                revert MaxAmountExceeded(args.maxAmountIn, amountIn);
            }
            amountIn = _secureTokenTransfer(
                // IERC20 tokenIn,
                args.tokenIn,
                // uint256 amountTokenToDeposit,
                amountIn,
                // bool pretransferred
                args.pretransferred
            );
            // Use low-level pool.swap() for exact-out semantics.
            // Transfer the computed amountIn directly to the pool, then call swap
            // specifying the exact amountOut desired. This ensures only the needed
            // input is consumed, allowing _refundExcess to return any surplus.
            args.tokenIn.safeTransfer(address(aeroReserve.pool), amountIn);
            {
                // Capture vault balance of tokenOut so we can compute actualOut when the
                // pool sends swapped tokens to the vault. We deliberately use
                // `address(this)` as the swap recipient so the contract can send the
                // exact requested amount to the caller and retain any tiny rounding
                // surplus. This preserves exact-out semantics for the caller.
                // uint256 vaultTokenBefore = IERC20(address(args.tokenOut)).balanceOf(address(this));
                address token0 = ConstProdReserveVaultRepo._token0();
                (uint256 amount0Out, uint256 amount1Out) =
                    address(args.tokenOut) == token0 ? (args.amountOut, uint256(0)) : (uint256(0), args.amountOut);
                // Receive the swapped tokens in the vault first.
                aeroReserve.pool.swap(amount0Out, amount1Out, address(this), new bytes(0));
                // uint256 vaultTokenAfter = IERC20(address(args.tokenOut)).balanceOf(address(this));
                // uint256 actualOut = vaultTokenAfter - vaultTokenBefore;
                // Transfer exactly the requested amount to the recipient and keep any
                // tiny rounding surplus in the vault.
                IERC20(address(args.tokenOut)).safeTransfer(args.recipient, args.amountOut);
                // Refund any excess pretransferred tokenIn back to the caller.
                // Must happen BEFORE reserve check since tokenIn may be the pool token.
                _refundExcess(args.tokenIn, args.maxAmountIn, amountIn, args.pretransferred, msg.sender);
            }
            {
                uint256 poolBalance = IERC20(address(aeroReserve.pool)).balanceOf(address(this));
                uint256 storedReserve = ERC4626Repo._lastTotalAssets();
                if (poolBalance != storedReserve) {
                    revert();
                }
            }
            return amountIn;
        }

        /* ------------------------------------------------------------------ */
        /*                         Pass-through ZapIn                         */
        /* ------------------------------------------------------------------ */

        if (
            ConstProdReserveVaultRepo._isReserveAssetContained(address(args.tokenIn))
                && address(args.tokenOut) == address(aeroReserve.pool)
        ) {
            // No gas efficient way to calculate the the amount in for a ZapIn to target amount out.
            revert RouteNotSupported(
                address(tokenIn), address(tokenOut), IStandardExchangeOut.previewExchangeOut.selector
            );
        }

        /* ------------------------------------------------------------------ */
        /*                         Pass-through ZapOut                        */
        /* ------------------------------------------------------------------ */

        if (
            address(args.tokenIn) == address(aeroReserve.pool)
                && ConstProdReserveVaultRepo._isReserveAssetContained(address(args.tokenOut))
        ) {
            return _execPassThroughZapOut(args, aeroReserve);
        }

        /* ------------------------------------------------------------------ */
        /*                    Underlying Pool Vault Deposit                   */
        /* ------------------------------------------------------------------ */

        if (address(args.tokenIn) == address(aeroReserve.pool) && address(args.tokenOut) == address(this)) {
            return _execUnderlyingPoolVaultDeposit(args, aeroReserve);
        }

        /* ------------------------------------------------------------------ */
        /*                  Underlying Pool Vault Withdrawal                  */
        /* ------------------------------------------------------------------ */

        if (address(args.tokenIn) == address(this) && address(args.tokenOut) == address(aeroReserve.pool)) {}

        /* ------------------------------------------------------------------ */
        /*                         ZapIn Vault Deposit                        */
        /* ------------------------------------------------------------------ */

        if (
            ConstProdReserveVaultRepo._isReserveAssetContained(address(args.tokenIn))
                && address(args.tokenOut) == address(this)
        ) {}

        /* ------------------------------------------------------------------ */
        /*                       ZapOut Vault Withdrawal                      */
        /* ------------------------------------------------------------------ */

        if (
            address(args.tokenIn) == address(this)
                && ConstProdReserveVaultRepo._isReserveAssetContained(address(args.tokenOut))
        ) {
            return _execZapOutVaultWithdrawal(args, aeroReserve);
        }

        revert InvalidRoute(address(args.tokenIn), address(args.tokenOut));
    }

    // }

    /**
     * @dev Internal helper to execute ZapOut Vault Withdrawal ExactOut.
     * Extracted to avoid stack too deep errors.
     */
    function _execZapOutVaultWithdrawal(OutArgs memory args, AeroReserve memory aeroReserve)
        internal
        returns (uint256)
    {
        uint256 vaultLpReserve = ERC4626Repo._lastTotalAssets();
        uint256 vaultTotalShares = ERC20Repo._totalSupply();
        uint8 decimalOffset = ERC4626Repo._decimalOffset();
        uint256 poolFeeLPShares;
        uint256 lpNeeded;

        // Calculate LP needed and fee shares in a nested block to free stack
        {
            uint256 lpTotalSupply = IERC20(address(aeroReserve.pool)).totalSupply();
            uint256 aeroSwapFeePercent = AerodromePoolMetadataRepo._factory()
                .getFee(address(aeroReserve.pool), AerodromePoolMetadataRepo._isStable());
            (uint256 reserve0, uint256 reserve1,) = aeroReserve.pool.getReserves();

            poolFeeLPShares =
                _calcVaultFeeLPAmount(aeroReserve.pool, reserve0, reserve1, lpTotalSupply, aeroSwapFeePercent);
            poolFeeLPShares =
                BetterMath._convertToSharesDown(poolFeeLPShares, vaultLpReserve, vaultTotalShares, decimalOffset);
            vaultTotalShares += poolFeeLPShares;

            (uint256 knownReserve, uint256 opposingReserve) = ConstProdUtils._sortReserves(
                address(args.tokenOut), ConstProdReserveVaultRepo._token0(), reserve0, reserve1
            );

            lpNeeded = ConstProdUtils._quoteZapOutToTargetWithFee(
                args.amountOut,
                lpTotalSupply,
                knownReserve,
                opposingReserve,
                aeroSwapFeePercent,
                AERO_FEE_DENOM,
                0,
                0,
                false
            );
        }

        // Convert LP to shares - round UP to favor vault
        uint256 amountInLocal = BetterMath._convertToSharesUp(lpNeeded, vaultLpReserve, vaultTotalShares, decimalOffset);

        // Check maxAmountIn constraint
        if (args.maxAmountIn < amountInLocal) {
            revert MaxAmountExceeded(args.maxAmountIn, amountInLocal);
        }

        // Mint vault fees and burn shares
        if (poolFeeLPShares > 0) {
            ERC20Repo._mint(address(VaultFeeOracleQueryAwareRepo._feeOracle().feeTo()), poolFeeLPShares);
        }
        _secureSelfBurn(msg.sender, amountInLocal, args.pretransferred);

        // Convert shares to LP and execute ZapOut
        {
            // Use _convertToAssetsUp to ensure we have at least the calculated LP amount
            // Preview uses _convertToSharesUp, so we need to round up here to match
            uint256 lpAmount =
                BetterMath._convertToAssetsUp(amountInLocal, vaultLpReserve, vaultTotalShares, decimalOffset);
            IERC20(address(aeroReserve.pool)).approve(address(aeroReserve.router), lpAmount);

            AerodromeService.WithdrawSwapVolatileParams memory params = AerodromeService.WithdrawSwapVolatileParams({
                aerodromeRouter: aeroReserve.router,
                pool: aeroReserve.pool,
                factory: AerodromePoolMetadataRepo._factory(),
                tokenOut: args.tokenOut,
                opposingToken: IERC20(ConstProdReserveVaultRepo._opposingToken(address(args.tokenOut))),
                lpBurnAmt: lpAmount,
                recipient: args.recipient,
                deadline: args.deadline
            });

            uint256 actualOut = AerodromeService._withdrawSwapVolatile(params);
            // Emit debug info removed
            if (actualOut < args.amountOut) {
                revert AmountOutNotMet(args.amountOut, actualOut);
            }
        }

        ERC4626Repo._setLastTotalAssets(IERC20(address(aeroReserve.pool)).balanceOf(address(this)));
        return amountInLocal;
    }
}
