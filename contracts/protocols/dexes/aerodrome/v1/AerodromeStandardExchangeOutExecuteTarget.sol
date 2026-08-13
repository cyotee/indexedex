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
import {IStandardExchangeOut} from 'contracts/interfaces/IStandardExchangeOut.sol';
import {ConstProdReserveVaultRepo} from 'contracts/vaults/ConstProdReserveVaultRepo.sol';
import {VaultFeeOracleQueryAwareRepo} from 'contracts/oracles/fee/VaultFeeOracleQueryAwareRepo.sol';
import {
    AerodromeStandardExchangeCommon
} from 'contracts/protocols/dexes/aerodrome/v1/AerodromeStandardExchangeCommon.sol';

abstract contract AerodromeStandardExchangeOutExecuteTarget is
    AerodromeStandardExchangeCommon,
    ReentrancyLockModifiers,
    IStandardExchangeErrors
{
    using BetterSafeERC20 for IERC20;

    // Debug instrumentation removed — retained in history for investigation

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

    /// @dev Intermediate state for Route 6 to reduce stack depth.
    struct Route6State {
        uint256 vaultLpReserve;
        uint256 vaultTotalShares;
        uint8 decimalOffset;
        uint256 lpTarget;
        uint256 amountIn;
        uint256 creditedIn;
    }

    function exchangeOut(
        IERC20 tokenIn,
        uint256 maxAmountIn,
        IERC20 tokenOut,
        uint256 amountOut,
        address recipient,
        bool pretransferred,
        uint256 deadline
    ) external nonReentrant returns (uint256 amountIn) {
        // Vault-level deadline (peer SE: Uni V2 / Camelot). Router deadline alone
        // does not cover vault-only routes (deposit / withdraw / share mint-burn).
        if (block.timestamp > deadline) {
            revert DeadlineExceeded(deadline, block.timestamp);
        }

        IStandardExchangeOut.OutArgs memory args = IStandardExchangeOut.OutArgs({
            tokenIn: tokenIn,
            maxAmountIn: maxAmountIn,
            tokenOut: tokenOut,
            amountOut: amountOut,
            recipient: recipient,
            pretransferred: pretransferred,
            deadline: deadline
        });

        // ConstProdReserveVaultRepo.Storage storage constProd = ConstProdReserveVaultRepo._layoutStruct();
        // AerodromePoolMetadataRepo.Storage storage  = AerodromePoolMetadataRepo._layoutStruct();
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
            // E6: credit this-call prepaid max when pretransferred; else pull only used.
            uint256 creditedIn;
            (amountIn, creditedIn) =
                _creditOutInbound(args.tokenIn, amountIn, args.maxAmountIn, args.pretransferred);
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
                // Refund this-call unused inbound only (credited − used), not fat max − used.
                // Must happen BEFORE reserve check since tokenIn may be the pool token.
                _refundExcess(args.tokenIn, creditedIn, amountIn, args.pretransferred, msg.sender);
            }
            {
                uint256 poolBalance = IERC20(address(aeroReserve.pool)).balanceOf(address(this));
                uint256 storedReserve = ERC4626Repo._lastTotalAssets();
                if (poolBalance != storedReserve) {
                    revert();
                }
            }
            _syncAllExpectedHoldReserves();
            return amountIn;
        }

        /* ------------------------------------------------------------------ */
        /*                         Pass-through ZapIn                         */
        /* ------------------------------------------------------------------ */

        if (
            ConstProdReserveVaultRepo._isReserveAssetContained(address(args.tokenIn))
                && address(args.tokenOut) == address(aeroReserve.pool)
        ) {
            amountIn = _execPassThroughZapIn(args, aeroReserve);
            _syncAllExpectedHoldReserves();
            return amountIn;
        }

        /* ------------------------------------------------------------------ */
        /*                         Pass-through ZapOut                        */
        /* ------------------------------------------------------------------ */

        if (
            address(args.tokenIn) == address(aeroReserve.pool)
                && ConstProdReserveVaultRepo._isReserveAssetContained(address(args.tokenOut))
        ) {
            amountIn = _execPassThroughZapOut(args, aeroReserve);
            _syncAllExpectedHoldReserves();
            return amountIn;
        }

        /* ------------------------------------------------------------------ */
        /*                    Underlying Pool Vault Deposit                   */
        /* ------------------------------------------------------------------ */

        if (address(args.tokenIn) == address(aeroReserve.pool) && address(args.tokenOut) == address(this)) {
            amountIn = _execUnderlyingPoolVaultDeposit(args, aeroReserve);
            _syncAllExpectedHoldReserves();
            return amountIn;
        }

        /* ------------------------------------------------------------------ */
        /*                  Underlying Pool Vault Withdrawal                  */
        /* ------------------------------------------------------------------ */

        if (address(args.tokenIn) == address(this) && address(args.tokenOut) == address(aeroReserve.pool)) {
            amountIn = _execVaultWithdrawal(args, aeroReserve);
            _syncAllExpectedHoldReserves();
            return amountIn;
        }

        /* ------------------------------------------------------------------ */
        /*                         ZapIn Vault Deposit                        */
        /* ------------------------------------------------------------------ */

        if (
            ConstProdReserveVaultRepo._isReserveAssetContained(address(args.tokenIn))
                && address(args.tokenOut) == address(this)
        ) {
            amountIn = _execZapInVaultDeposit(args, aeroReserve);
            _syncAllExpectedHoldReserves();
            return amountIn;
        }

        /* ------------------------------------------------------------------ */
        /*                       ZapOut Vault Withdrawal                      */
        /* ------------------------------------------------------------------ */

        if (
            address(args.tokenIn) == address(this)
                && ConstProdReserveVaultRepo._isReserveAssetContained(address(args.tokenOut))
        ) {
            amountIn = _execZapOutVaultWithdrawal(args, aeroReserve);
            _syncAllExpectedHoldReserves();
            return amountIn;
        }

        revert InvalidRoute(address(args.tokenIn), address(args.tokenOut));
    }


    function _execZapOutVaultWithdrawal(IStandardExchangeOut.OutArgs memory args, AeroReserve memory aeroReserve)
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


    /// @dev E6: credit prepaid max when pretransferred; else pull only used.
    function _creditOutInbound(IERC20 tokenIn, uint256 usedIn, uint256 maxAmountIn, bool pretransferred)
        internal
        returns (uint256 used, uint256 credited)
    {
        if (pretransferred) {
            credited = _secureTokenTransfer(tokenIn, maxAmountIn, true);
            used = usedIn;
        } else {
            credited = _secureTokenTransfer(tokenIn, usedIn, false);
            used = credited;
        }
    }

    function _quotePassThroughZapIn(IStandardExchangeOut.OutArgs memory args, AeroReserve memory aeroReserve)
        internal
        view
        returns (uint256 amountIn)
    {
        (uint256 reserve0, uint256 reserve1,) = aeroReserve.pool.getReserves();
        (uint256 reserveIn, uint256 reserveOut) = ConstProdUtils._sortReserves(
            address(args.tokenIn), ConstProdReserveVaultRepo._token0(), reserve0, reserve1
        );
        uint256 feePercent = AerodromePoolMetadataRepo._factory()
            .getFee(address(aeroReserve.pool), AerodromePoolMetadataRepo._isStable());
        // Add 1 to lpTarget so on-chain execution still produces >= args.amountOut LP.
        return ConstProdUtils._quoteZapInToTargetLPWithFee(
            args.amountOut + 1,
            IERC20(address(aeroReserve.pool)).totalSupply(),
            reserveIn,
            reserveOut,
            feePercent,
            AERO_FEE_DENOM,
            0,
            0,
            false
        );
    }

    function _execPassThroughZapIn(IStandardExchangeOut.OutArgs memory args, AeroReserve memory aeroReserve)
        internal
        returns (uint256 amountIn)
    {
        amountIn = _quotePassThroughZapIn(args, aeroReserve);
        if (amountIn > args.maxAmountIn) {
            revert MaxAmountExceeded(args.maxAmountIn, amountIn);
        }

        uint256 creditedIn;
        (amountIn, creditedIn) = _creditOutInbound(args.tokenIn, amountIn, args.maxAmountIn, args.pretransferred);

        AerodromeService.SwapDepositVolatileParams memory zapInParams = AerodromeService.SwapDepositVolatileParams({
            router: aeroReserve.router,
            factory: AerodromePoolMetadataRepo._factory(),
            pool: aeroReserve.pool,
            token0: IERC20(ConstProdReserveVaultRepo._token0()),
            tokenIn: args.tokenIn,
            opposingToken: IERC20(ConstProdReserveVaultRepo._opposingToken(address(args.tokenIn))),
            amountIn: amountIn,
            recipient: args.recipient,
            deadline: args.deadline
        });
        uint256 lpOut = AerodromeService._swapDepositVolatile(zapInParams);
        if (lpOut < args.amountOut) revert AmountOutNotMet(args.amountOut, lpOut);

        _refundExcess(args.tokenIn, creditedIn, amountIn, args.pretransferred, msg.sender);

        {
            uint256 poolBalance = IERC20(address(aeroReserve.pool)).balanceOf(address(this));
            uint256 storedReserve = ERC4626Repo._lastTotalAssets();
            if (poolBalance != storedReserve) {
                revert();
            }
        }

        return amountIn;
    }


    function _execVaultWithdrawal(IStandardExchangeOut.OutArgs memory args, AeroReserve memory aeroReserve)
        internal
        returns (uint256 amountIn)
    {
        // Compound fees before computing state (mirrors exchangeIn Route 5).
        _claimAndCompoundFees(_buildCompoundParams(aeroReserve.pool, args.deadline));

        uint256 vaultLpReserve = ERC4626Repo._lastTotalAssets();
        uint256 vaultTotalShares = ERC20Repo._totalSupply();
        uint8 decimalOffset = ERC4626Repo._decimalOffset();

        // Calculate minimum shares needed to redeem at least amountOut LP.
        // _convertToSharesUp rounds up, so we are guaranteed to get >= amountOut LP.
        amountIn = BetterMath._convertToSharesUp(args.amountOut, vaultLpReserve, vaultTotalShares, decimalOffset);

        // Slippage guard.
        if (amountIn > args.maxAmountIn) {
            revert MaxAmountExceeded(args.maxAmountIn, amountIn);
        }

        // Burn shares from caller.
        _secureSelfBurn(msg.sender, amountIn, args.pretransferred);

        // Convert burned shares -> LP (use Down to match the burn amount exactly).
        uint256 lpOut = BetterMath._convertToAssetsDown(amountIn, vaultLpReserve, vaultTotalShares, decimalOffset);

        // Transfer LP to recipient.
        if (lpOut < args.amountOut) revert AmountOutNotMet(args.amountOut, lpOut);
        IERC20(address(aeroReserve.pool)).transfer(args.recipient, lpOut);

        // Update stored LP reserve.
        ERC4626Repo._setLastTotalAssets(IERC20(address(aeroReserve.pool)).balanceOf(address(this)));

        return amountIn;
    }


    function _execZapInVaultDeposit(IStandardExchangeOut.OutArgs memory args, AeroReserve memory aeroReserve)
        internal
        returns (uint256 amountIn)
    {
        // Compound fees (mirrors exchangeIn Route 6 which calls _claimAndCompoundFees).
        _claimAndCompoundFees(_buildCompoundParams(aeroReserve.pool, args.deadline));

        // A0: unbooked reserve LP cannot be absorbed into a zap-in share mint.
        if (IERC20(address(aeroReserve.pool)).balanceOf(address(this)) != ERC4626Repo._lastTotalAssets()) {
            revert();
        }

        Route6State memory s;
        s.vaultLpReserve = ERC4626Repo._lastTotalAssets();
        s.vaultTotalShares = ERC20Repo._totalSupply();
        s.decimalOffset = ERC4626Repo._decimalOffset();

        // Step 1: ERC-4626 inverse — target shares -> target LP.
        {
            uint256 decimalUnit = 10 ** s.decimalOffset;
            // Guard: amountOut must be < S + 10^d (otherwise denominator <= 0).
            require(args.amountOut < s.vaultTotalShares + decimalUnit, "Route6: amountOut >= totalShares + decimalUnit");
            uint256 numerator = args.amountOut * (s.vaultLpReserve + 1);
            uint256 denominator = s.vaultTotalShares + decimalUnit - args.amountOut;
            s.lpTarget = numerator / denominator;
            if (numerator % denominator != 0) {
                s.lpTarget += 1;
            }
        }

        // Step 2: ZapIn inverse — target LP -> amountIn.
        s.amountIn = _quoteZapInForRoute6(args.tokenIn, aeroReserve.pool, s.lpTarget);

        // Slippage guard.
        if (s.amountIn > args.maxAmountIn) {
            revert MaxAmountExceeded(args.maxAmountIn, s.amountIn);
        }

        // E6: credit prepaid max when pretransferred; else pull only used.
        (s.amountIn, s.creditedIn) =
            _creditOutInbound(args.tokenIn, s.amountIn, args.maxAmountIn, args.pretransferred);

        // Execute ZapIn and mint shares.
        return _execZapInVaultDepositFinalize(args, aeroReserve, s);
    }


    function _quoteZapInForRoute6(IERC20 tokenIn, IPool pool, uint256 lpTarget)
        internal
        view
        returns (uint256 amountIn)
    {
        (uint256 reserve0, uint256 reserve1,) = pool.getReserves();
        uint256 feePercent =
            AerodromePoolMetadataRepo._factory().getFee(address(pool), AerodromePoolMetadataRepo._isStable());
        uint256 lpTotalSupply = IERC20(address(pool)).totalSupply();
        (uint256 reserveIn, uint256 reserveOut) =
            ConstProdUtils._sortReserves(address(tokenIn), ConstProdReserveVaultRepo._token0(), reserve0, reserve1);

        return ConstProdUtils._quoteZapInToTargetLPWithFee(
            // uint256 targetLP,
            lpTarget,
            // uint256 lpTotalSupply,
            lpTotalSupply,
            // uint256 reserveIn,
            reserveIn,
            // uint256 reserveOut,
            reserveOut,
            // uint256 feePercent,
            feePercent,
            // uint256 feeDenominator,
            AERO_FEE_DENOM,
            // uint256 kLast,
            0,
            // uint256 ownerFeeShare,
            0,
            // bool feeOn
            false
        );
    }


    function _execZapInVaultDepositFinalize(IStandardExchangeOut.OutArgs memory args, AeroReserve memory aeroReserve, Route6State memory s)
        internal
        returns (uint256)
    {
        // Execute ZapIn to get LP tokens into the vault.
        AerodromeService.SwapDepositVolatileParams memory zapInParams = AerodromeService.SwapDepositVolatileParams({
            router: aeroReserve.router,
            factory: AerodromePoolMetadataRepo._factory(),
            pool: aeroReserve.pool,
            token0: IERC20(ConstProdReserveVaultRepo._token0()),
            tokenIn: args.tokenIn,
            opposingToken: IERC20(ConstProdReserveVaultRepo._opposingToken(address(args.tokenIn))),
            amountIn: s.amountIn,
            recipient: address(this),
            deadline: args.deadline
        });
        uint256 lpReceived = AerodromeService._swapDepositVolatile(zapInParams);

        // Update vault LP reserve after ZapIn.
        ERC4626Repo._setLastTotalAssets(IERC20(address(aeroReserve.pool)).balanceOf(address(this)));

        // Mint vault shares proportional to the LP received.
        uint256 sharesOut =
            BetterMath._convertToSharesDown(lpReceived, s.vaultLpReserve, s.vaultTotalShares, s.decimalOffset);
        if (sharesOut < args.amountOut) revert AmountOutNotMet(args.amountOut, sharesOut);
        ERC20Repo._mint(args.recipient, sharesOut);

        // Refund this-call unused inbound (credited − used), not fat max − used.
        _refundExcess(args.tokenIn, s.creditedIn, s.amountIn, args.pretransferred, msg.sender);

        return s.amountIn;
    }



    /* exec helpers relocated from query half */
    function _execUnderlyingPoolVaultDeposit(IStandardExchangeOut.OutArgs memory args, AeroReserve memory aeroReserve)
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
        if (args.maxAmountIn < amountIn) {
            revert MaxAmountExceeded(args.maxAmountIn, amountIn);
        }
        // Honor pretransferred: false always pulls. Do not credit lastTotal exact-gap.
        amountIn = _secureTokenTransfer(IERC20(address(aeroReserve.pool)), amountIn, args.pretransferred);
        ERC4626Repo._setLastTotalAssets(IERC20(address(aeroReserve.pool)).balanceOf(address(this)));
        // Mint exactly the requested share amount to the recipient.
        ERC20Repo._mint(
            // address account,
            args.recipient,
            // uint256 amount,
            args.amountOut
        );
        return amountIn;
    }


    function _execPassThroughZapOut(IStandardExchangeOut.OutArgs memory args, AeroReserve memory aeroReserve) internal returns (uint256) {
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

        // E6: credit prepaid max when pretransferred; else pull only used LP.
        uint256 creditedIn;
        (s.amountIn, creditedIn) =
            _creditOutInbound(args.tokenIn, s.amountIn, args.maxAmountIn, args.pretransferred);
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
        _refundExcess(args.tokenIn, creditedIn, s.amountIn, args.pretransferred, msg.sender);

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


}
