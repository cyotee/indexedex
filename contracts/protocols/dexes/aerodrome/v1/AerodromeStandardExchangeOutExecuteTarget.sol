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
        internal returns (uint256 amountIn_)
    {
        _claimAndCompoundFees(_buildCompoundParams(aeroReserve.pool, args.deadline));
        uint256 held_ = IERC20(address(aeroReserve.pool)).balanceOf(address(this)); uint256 shares_ = ERC20Repo._totalSupply();
        uint8 offset_ = ERC4626Repo._decimalOffset();
        uint256 lp_ = _quoteAeroWithdrawAfterCompound(aeroReserve.pool, args.tokenOut, args.amountOut);
        amountIn_ = BetterMath._convertToSharesUp(lp_, held_, shares_, offset_);
        if (amountIn_ > args.maxAmountIn) revert MaxAmountExceeded(args.maxAmountIn, amountIn_);
        _secureSelfBurn(msg.sender, amountIn_, args.pretransferred);
        _refundExcess(IERC20(address(this)), args.maxAmountIn, amountIn_, args.pretransferred, msg.sender);
        lp_ = BetterMath._convertToAssetsDown(amountIn_, held_, shares_, offset_);
        IERC20(address(aeroReserve.pool)).approve(address(aeroReserve.router), lp_);
        uint256 paid_ = _withdrawSwapVolatileSafe(aeroReserve.router, aeroReserve.pool, args.tokenOut, lp_, args.recipient, args.deadline);
        if (paid_ < args.amountOut) revert AmountOutNotMet(args.amountOut, paid_);
        ERC4626Repo._setLastTotalAssets(IERC20(address(aeroReserve.pool)).balanceOf(address(this)));
    }

    function _quoteAeroWithdrawAfterCompound(IPool pool_, IERC20 out_, uint256 target_) private view returns (uint256) {
        (uint256 reserve0_, uint256 reserve1_,) = pool_.getReserves();
        (uint256 desired_, uint256 other_) = ConstProdUtils._sortReserves(address(out_), ConstProdReserveVaultRepo._token0(), reserve0_, reserve1_);
        uint256 fee_ = AerodromePoolMetadataRepo._factory().getFee(address(pool_), AerodromePoolMetadataRepo._isStable());
        return _quoteAeroLpToToken(target_, IERC20(address(pool_)).totalSupply(), desired_, other_, fee_);
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
        internal view returns (uint256)
    {
        return _quoteZapInForRoute6(args.tokenIn, aeroReserve.pool, args.amountOut);
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

        uint256 vaultLpReserve = IERC20(address(aeroReserve.pool)).balanceOf(address(this));
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
        _refundExcess(IERC20(address(this)), args.maxAmountIn, amountIn, args.pretransferred, msg.sender);

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
        Route6State memory s;
        // Fees compounded by this call are existing holders' funds, never prepaid user input.
        if (args.pretransferred) s.creditedIn = _secureTokenTransfer(args.tokenIn, args.maxAmountIn, true);
        // Compound fees (mirrors exchangeIn Route 6 which calls _claimAndCompoundFees).
        _claimAndCompoundFees(_buildCompoundParams(aeroReserve.pool, args.deadline));

        // A0: unbooked reserve LP cannot be absorbed into a zap-in share mint.
        if (IERC20(address(aeroReserve.pool)).balanceOf(address(this)) != ERC4626Repo._lastTotalAssets()) {
            revert();
        }

        s.vaultLpReserve = ERC4626Repo._lastTotalAssets();
        s.vaultTotalShares = ERC20Repo._totalSupply();
        s.decimalOffset = ERC4626Repo._decimalOffset();

        // Exact inverse of shares minted against assets before the user's zap.
        s.lpTarget = BetterMath._convertToAssetsUp(args.amountOut, s.vaultLpReserve, s.vaultTotalShares, s.decimalOffset);

        // Step 2: ZapIn inverse — target LP -> amountIn.
        s.amountIn = _quoteZapInForRoute6(args.tokenIn, aeroReserve.pool, s.lpTarget);

        // Slippage guard.
        if (s.amountIn > args.maxAmountIn) {
            revert MaxAmountExceeded(args.maxAmountIn, s.amountIn);
        }

        // E6: credit prepaid max when pretransferred; else pull only used.
        if (!args.pretransferred) {
            (s.amountIn, s.creditedIn) = _creditOutInbound(args.tokenIn, s.amountIn, args.maxAmountIn, false);
        }

        // Execute ZapIn and mint shares.
        return _execZapInVaultDepositFinalize(args, aeroReserve, s);
    }


    function _quoteZapInForRoute6(IERC20 tokenIn, IPool pool, uint256 lpTarget)
        internal view returns (uint256)
    {
        (uint256 reserve0_, uint256 reserve1_,) = pool.getReserves();
        (uint256 in_, uint256 out_) = ConstProdUtils._sortReserves(address(tokenIn), ConstProdReserveVaultRepo._token0(), reserve0_, reserve1_);
        uint256 fee_ = AerodromePoolMetadataRepo._factory().getFee(address(pool), AerodromePoolMetadataRepo._isStable());
        return _quoteAeroZapToLp(lpTarget, IERC20(address(pool)).totalSupply(), in_, out_, fee_);
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
        internal returns (uint256 amountIn_)
    {
        // Validate prepaid LP before compounding can create any new, unbooked LP.
        uint256 credited_;
        if (args.pretransferred) credited_ = _secureTokenTransfer(args.tokenIn, args.maxAmountIn, true);
        _claimAndCompoundFees(_buildCompoundParams(aeroReserve.pool, args.deadline));
        uint256 held_ = IERC20(address(aeroReserve.pool)).balanceOf(address(this)) - credited_;
        amountIn_ = BetterMath._convertToAssetsUp(args.amountOut, held_, ERC20Repo._totalSupply(), ERC4626Repo._decimalOffset());
        if (amountIn_ > args.maxAmountIn) revert MaxAmountExceeded(args.maxAmountIn, amountIn_);
        if (!args.pretransferred) (amountIn_, credited_) = _creditOutInbound(args.tokenIn, amountIn_, args.maxAmountIn, false);
        _refundExcess(args.tokenIn, credited_, amountIn_, args.pretransferred, msg.sender);
        ERC20Repo._mint(args.recipient, args.amountOut);
        ERC4626Repo._setLastTotalAssets(IERC20(address(aeroReserve.pool)).balanceOf(address(this)));
    }



    function _execPassThroughZapOut(IStandardExchangeOut.OutArgs memory args, AeroReserve memory aeroReserve) internal returns (uint256) {
        PassThroughZapOutState memory s;

        // Load pool reserves and derived values
        (s.reserve0, s.reserve1,) = aeroReserve.pool.getReserves();
        (s.knownReserve, s.opposingReserve) = ConstProdUtils._sortReserves(
            address(args.tokenOut), ConstProdReserveVaultRepo._token0(), s.reserve0, s.reserve1
        );
        s.lpTotalSupply = IERC20(address(aeroReserve.pool)).totalSupply();

        s.amountIn = _quoteAeroLpToToken(args.amountOut, s.lpTotalSupply, s.knownReserve, s.opposingReserve,
            AerodromePoolMetadataRepo._factory().getFee(address(aeroReserve.pool), AerodromePoolMetadataRepo._isStable()));

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
