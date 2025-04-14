// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {ONE_WAD} from '@crane/contracts/constants/Constants.sol';
import {IERC20} from '@crane/contracts/interfaces/IERC20.sol';
import {IPool} from '@crane/contracts/interfaces/protocols/dexes/aerodrome/IPool.sol';
import {IRouter as IAerodromeRouter} from '@crane/contracts/interfaces/protocols/dexes/aerodrome/IRouter.sol';
import {IStandardExchangeIn} from 'contracts/interfaces/IStandardExchangeIn.sol';
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
import {
    AerodromeRouterAwareRepo
} from '@crane/contracts/protocols/dexes/aerodrome/v1/aware/AerodromeRouterAwareRepo.sol';
import {ConstProdReserveVaultRepo} from 'contracts/vaults/ConstProdReserveVaultRepo.sol';
import {VaultFeeOracleQueryAwareRepo} from 'contracts/oracles/fee/VaultFeeOracleQueryAwareRepo.sol';
import {ReentrancyLockModifiers} from '@crane/contracts/access/reentrancy/ReentrancyLockModifiers.sol';
import {
    AerodromeStandardExchangeCommon
} from 'contracts/protocols/dexes/aerodrome/v1/AerodromeStandardExchangeCommon.sol';
import {BetterSafeERC20} from '@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol';

contract AerodromeStandardExchangeInTarget is
    AerodromeStandardExchangeCommon,
    ReentrancyLockModifiers,
    IStandardExchangeIn
{
    using BetterSafeERC20 for IERC20;

    uint256 constant AERO_FEE_DENOM = 10000;

    function previewExchangeIn(IERC20 tokenIn, uint256 amountIn, IERC20 tokenOut)
        external
        view
        returns (uint256 amountOut)
    {
        ConstProdReserveVaultRepo.Storage storage constProd = ConstProdReserveVaultRepo._layout();

        IAerodromeRouter aerodromeRouter = AerodromeRouterAwareRepo._aerodromeRouter();
        IPool pool = IPool(address(ERC4626Repo._reserveAsset()));

        /* ------------------------------------------------------------------ */
        /*                          Pass-through Swap                         */
        /* ------------------------------------------------------------------ */

        if (
            ConstProdReserveVaultRepo._isReserveAssetContained(constProd, address(tokenIn))
                && ConstProdReserveVaultRepo._isReserveAssetContained(constProd, address(tokenOut))
        ) {
            return pool.getAmountOut(amountIn, address(tokenIn));
        }

        AerodromePoolMetadataRepo.Storage storage aeroPoolMeta = AerodromePoolMetadataRepo._layout();

        /* ------------------------------------------------------------------ */
        /*                         Pass-through ZapIn                         */
        /* ------------------------------------------------------------------ */

        if (
            ConstProdReserveVaultRepo._isReserveAssetContained(constProd, address(tokenIn))
                && address(tokenOut) == address(pool)
        ) {
            (uint256 _reserve0, uint256 _reserve1,) = pool.getReserves();
            (uint256 reserveIn, uint256 reserveOut) = ConstProdUtils._sortReserves(
                address(tokenIn), ConstProdReserveVaultRepo._token0(), _reserve0, _reserve1
            );
            return AerodromeUtils._quoteSwapDepositWithFee(
                // uint256 amountIn,
                amountIn,
                // uint256 lpTotalSupply,
                IERC20(address(pool)).totalSupply(),
                // uint256 reserveIn,
                reserveIn,
                // uint256 reserveOut,
                reserveOut,
                // uint256 feePercent
                AerodromePoolMetadataRepo._factory(aeroPoolMeta)
                    .getFee(address(pool), AerodromePoolMetadataRepo._isStable(aeroPoolMeta))
            );
        }

        /* ------------------------------------------------------------------ */
        /*                         Pass-through ZapOut                        */
        /* ------------------------------------------------------------------ */

        if (
            address(tokenIn) == address(pool)
                && ConstProdReserveVaultRepo._isReserveAssetContained(constProd, address(tokenOut))
        ) {
            (uint256 _reserve0, uint256 _reserve1,) = pool.getReserves();
            // Sort reserves by tokenOut (the token we want to receive)
            // knownReserve = tokenOut reserve, unknownReserve = opposingToken reserve
            (uint256 reserveOut, uint256 reserveIn) = ConstProdUtils._sortReserves(
                address(tokenOut), ConstProdReserveVaultRepo._token0(), _reserve0, _reserve1
            );
            return AerodromeUtils._quoteWithdrawSwapWithFee(
                // uint256 ownedLPAmount,
                amountIn,
                // uint256 lpTotalSupply,
                IERC20(address(pool)).totalSupply(),
                // uint256 reserveOut (tokenOut reserve),
                reserveOut,
                // uint256 reserveIn (opposingToken reserve),
                reserveIn,
                // uint256 feePercent,
                AerodromePoolMetadataRepo._factory(aeroPoolMeta)
                    .getFee(address(pool), AerodromePoolMetadataRepo._isStable(aeroPoolMeta))
            );
        }

        /* ------------------------------------------------------------------ */
        /*                    Underlying Pool Vault Deposit                   */
        /* ------------------------------------------------------------------ */

        if (address(tokenIn) == address(pool) && address(tokenOut) == address(this)) {
            (uint256 reserve0, uint256 reserve1,) = pool.getReserves();
            uint256 lpTotalSupply = IERC20(address(pool)).totalSupply();
            uint256 aeroSwapFeePercent = AerodromePoolMetadataRepo._factory(aeroPoolMeta)
                .getFee(address(pool), AerodromePoolMetadataRepo._isStable(aeroPoolMeta));

            PreviewState memory state = _calcPreviewState(pool, reserve0, reserve1, lpTotalSupply, aeroSwapFeePercent);
            return BetterMath._convertToSharesDown(
                amountIn, state.vaultLpReserve, state.vaultTotalShares, state.decimalOffset
            );
        }

        /* ------------------------------------------------------------------ */
        /*                  Underlying Pool Vault Withdrawal                  */
        /* ------------------------------------------------------------------ */

        if (address(tokenIn) == address(this) && address(tokenOut) == address(pool)) {
            (uint256 reserve0, uint256 reserve1,) = pool.getReserves();
            uint256 lpTotalSupply = IERC20(address(pool)).totalSupply();
            uint256 aeroSwapFeePercent = AerodromePoolMetadataRepo._factory(aeroPoolMeta)
                .getFee(address(pool), AerodromePoolMetadataRepo._isStable(aeroPoolMeta));

            PreviewState memory state = _calcPreviewState(pool, reserve0, reserve1, lpTotalSupply, aeroSwapFeePercent);
            return BetterMath._convertToAssetsDown(
                amountIn, state.vaultLpReserve, state.vaultTotalShares, state.decimalOffset
            );
        }

        /* ------------------------------------------------------------------ */
        /*                         ZapIn Vault Deposit                        */
        /* ------------------------------------------------------------------ */

        if (
            ConstProdReserveVaultRepo._isReserveAssetContained(constProd, address(tokenIn))
                && address(tokenOut) == address(this)
        ) {
            (uint256 reserve0, uint256 reserve1,) = pool.getReserves();
            address token0 = ConstProdReserveVaultRepo._token0();
            (uint256 reserveIn, uint256 reserveOut) =
                ConstProdUtils._sortReserves(address(tokenIn), token0, reserve0, reserve1);
            uint256 lpTotalSupply = IERC20(address(pool)).totalSupply();
            uint256 aeroSwapFeePercent = AerodromePoolMetadataRepo._factory(aeroPoolMeta)
                .getFee(address(pool), AerodromePoolMetadataRepo._isStable(aeroPoolMeta));

            // Calculate LP from user's ZapIn
            uint256 lpFromZapIn = AerodromeUtils._quoteSwapDepositWithFee(
                amountIn, lpTotalSupply, reserveIn, reserveOut, aeroSwapFeePercent
            );

            PreviewState memory state = _calcPreviewState(pool, reserve0, reserve1, lpTotalSupply, aeroSwapFeePercent);
            return BetterMath._convertToSharesDown(
                lpFromZapIn, state.vaultLpReserve, state.vaultTotalShares, state.decimalOffset
            );
        }

        /* ------------------------------------------------------------------ */
        /*                       ZapOut Vault Withdrawal                      */
        /* ------------------------------------------------------------------ */

        if (
            address(tokenIn) == address(this)
                && ConstProdReserveVaultRepo._isReserveAssetContained(constProd, address(tokenOut))
        ) {
            (uint256 reserve0, uint256 reserve1,) = pool.getReserves();
            uint256 lpTotalSupply = IERC20(address(pool)).totalSupply();
            uint256 aeroSwapFeePercent = AerodromePoolMetadataRepo._factory(aeroPoolMeta)
                .getFee(address(pool), AerodromePoolMetadataRepo._isStable(aeroPoolMeta));

            Route7PreviewParams memory params = Route7PreviewParams({
                pool: pool,
                tokenOut: tokenOut,
                sharesIn: amountIn,
                reserve0: reserve0,
                reserve1: reserve1,
                lpTotalSupply: lpTotalSupply,
                swapFeePercent: aeroSwapFeePercent
            });

            return _previewRoute7ZapOutWithdraw(params);
        }
        revert InvalidRoute(address(tokenIn), address(tokenOut));
    }

    struct Route7PreviewParams {
        IPool pool;
        IERC20 tokenOut;
        uint256 sharesIn;
        uint256 reserve0;
        uint256 reserve1;
        uint256 lpTotalSupply;
        uint256 swapFeePercent;
    }

    function _previewRoute7ZapOutWithdraw(Route7PreviewParams memory params) internal view returns (uint256 amountOut) {
        PreviewCompoundState memory compoundState = _previewCompoundState(
            params.pool, params.reserve0, params.reserve1, params.lpTotalSupply, params.swapFeePercent
        );

        uint256 protocolFeeLP = BetterMath._percentageOfWAD(
            compoundState.lpMinted, VaultFeeOracleQueryAwareRepo._feeOracle().usageFeeOfVault(address(this))
        );

        uint256 vaultLpReserve =
            IERC20(address(params.pool)).balanceOf(address(this)) + (compoundState.lpMinted - protocolFeeLP);

        uint256 lpFromShares = BetterMath._convertToAssetsDown(
            params.sharesIn, vaultLpReserve, ERC20Repo._totalSupply(), ERC4626Repo._decimalOffset()
        );

        (uint256 reserveOut, uint256 reserveIn) = ConstProdUtils._sortReserves(
            address(params.tokenOut),
            ConstProdReserveVaultRepo._token0(),
            compoundState.reserve0,
            compoundState.reserve1
        );

        return AerodromeUtils._quoteWithdrawSwapWithFee(
            lpFromShares, compoundState.lpTotalSupply, reserveOut, reserveIn, params.swapFeePercent
        );
    }

    function exchangeIn(
        IERC20 tokenIn,
        uint256 amountIn,
        IERC20 tokenOut,
        uint256 minAmountOut,
        address recipient,
        bool pretransferred,
        uint256 deadline
    ) external lock returns (uint256 amountOut) {
        ConstProdReserveVaultRepo.Storage storage constProd = ConstProdReserveVaultRepo._layout();
        IAerodromeRouter aerodromeRouter = AerodromeRouterAwareRepo._aerodromeRouter();
        IPool pool = IPool(address(ERC4626Repo._reserveAsset()));

        /* ------------------------------------------------------------------ */
        /*                          Pass-through Swap                         */
        /* ------------------------------------------------------------------ */
        if (
            ConstProdReserveVaultRepo._isReserveAssetContained(constProd, address(tokenIn))
                && ConstProdReserveVaultRepo._isReserveAssetContained(constProd, address(tokenOut))
        ) {
            return _swapReserveAssets(tokenIn, amountIn, tokenOut, minAmountOut, recipient, pretransferred, deadline);
        }

        /* ------------------------------------------------------------------ */
        /*                         Pass-through ZapIn                         */
        /* ------------------------------------------------------------------ */

        if (
            ConstProdReserveVaultRepo._isReserveAssetContained(constProd, address(tokenIn))
                && address(tokenOut) == address(pool)
        ) {
            amountIn = _secureTokenTransfer(
                // IERC20 tokenIn,
                tokenIn,
                // uint256 amountTokenToDeposit,
                amountIn,
                // bool pretransferred
                pretransferred
            );
            AerodromeService.SwapDepositVolatileParams memory params = AerodromeService.SwapDepositVolatileParams({
                router: aerodromeRouter,
                factory: AerodromePoolMetadataRepo._factory(),
                pool: pool,
                token0: IERC20(ConstProdReserveVaultRepo._token0()),
                tokenIn: tokenIn,
                opposingToken: IERC20(ConstProdReserveVaultRepo._opposingToken(address(tokenIn))),
                amountIn: amountIn,
                recipient: recipient,
                deadline: deadline
            });
            amountOut = AerodromeService._swapDepositVolatile(params);
            if (amountOut < minAmountOut) {
                revert MinAmountNotMet(minAmountOut, amountOut);
            }
            {
                uint256 poolBalance = IERC20(address(pool)).balanceOf(address(this));
                uint256 storedReserve = ERC4626Repo._lastTotalAssets();
                if (poolBalance != storedReserve) {
                    revert();
                }
            }
            return amountOut;
        }

        /* ------------------------------------------------------------------ */
        /*                         Pass-through ZapOut                        */
        /* ------------------------------------------------------------------ */

        if (
            address(tokenIn) == address(pool)
                && ConstProdReserveVaultRepo._isReserveAssetContained(constProd, address(tokenOut))
        ) {
            amountIn = _secureTokenTransfer(
                // IERC20 tokenIn,
                tokenIn,
                // uint256 amountTokenToDeposit,
                amountIn,
                // bool pretransferred
                pretransferred
            );
            // Approve LP tokens for the router to burn
            IERC20(address(pool)).approve(address(aerodromeRouter), amountIn);
            amountOut =
                _withdrawSwapVolatileSafe(aerodromeRouter, pool, IERC20(tokenOut), amountIn, recipient, deadline);
            if (amountOut < minAmountOut) {
                revert MinAmountNotMet(minAmountOut, amountOut);
            }
            {
                uint256 poolBalance = IERC20(address(pool)).balanceOf(address(this));
                uint256 storedReserve = ERC4626Repo._lastTotalAssets();
                if (poolBalance != storedReserve) {
                    revert();
                }
            }
            return amountOut;
        }

        /* ------------------------------------------------------------------ */
        /*                    Underlying Pool Vault Deposit                   */
        /* ------------------------------------------------------------------ */

        if (address(tokenIn) == address(pool) && address(tokenOut) == address(this)) {
            _claimAndCompoundFees(_buildCompoundParams(pool, deadline));

            VaultState memory vs;
            vs.vaultLpReserve = ERC4626Repo._lastTotalAssets();
            vs.vaultTotalShares = ERC20Repo._totalSupply();
            vs.decimalOffset = ERC4626Repo._decimalOffset();

            amountIn = ERC4626Service._secureReserveDeposit(ERC4626Repo._layout(), vs.vaultLpReserve, amountIn);
            amountOut =
                BetterMath._convertToSharesDown(amountIn, vs.vaultLpReserve, vs.vaultTotalShares, vs.decimalOffset);
            if (amountOut < minAmountOut) revert MinAmountNotMet(minAmountOut, amountOut);
            ERC20Repo._mint(recipient, amountOut);
            return amountOut;
        }

        /* ------------------------------------------------------------------ */
        /*                  Underlying Pool Vault Withdrawal                  */
        /* ------------------------------------------------------------------ */

        if (address(tokenIn) == address(this) && address(tokenOut) == address(pool)) {
            _claimAndCompoundFees(_buildCompoundParams(pool, deadline));

            VaultState memory vs;
            vs.vaultLpReserve = ERC4626Repo._lastTotalAssets();
            vs.vaultTotalShares = ERC20Repo._totalSupply();
            vs.decimalOffset = ERC4626Repo._decimalOffset();

            _secureSelfBurn(msg.sender, amountIn, pretransferred);
            amountOut =
                BetterMath._convertToAssetsDown(amountIn, vs.vaultLpReserve, vs.vaultTotalShares, vs.decimalOffset);
            if (amountOut < minAmountOut) revert MinAmountNotMet(minAmountOut, amountOut);
            IERC20(address(pool)).transfer(recipient, amountOut);
            ERC4626Repo._setLastTotalAssets(IERC20(address(pool)).balanceOf(address(this)));
            return amountOut;
        }

        /* ------------------------------------------------------------------ */
        /*                         ZapIn Vault Deposit                        */
        /* ------------------------------------------------------------------ */

        if (
            ConstProdReserveVaultRepo._isReserveAssetContained(constProd, address(tokenIn))
                && address(tokenOut) == address(this)
        ) {
            _claimAndCompoundFees(_buildCompoundParams(pool, deadline));
            amountIn = _secureTokenTransfer(tokenIn, amountIn, pretransferred);

            VaultState memory vs;
            vs.vaultLpReserve = ERC4626Repo._lastTotalAssets();
            vs.vaultTotalShares = ERC20Repo._totalSupply();
            vs.decimalOffset = ERC4626Repo._decimalOffset();

            AerodromeService.SwapDepositVolatileParams memory zapInParams = AerodromeService.SwapDepositVolatileParams({
                router: aerodromeRouter,
                factory: AerodromePoolMetadataRepo._factory(),
                pool: pool,
                token0: IERC20(ConstProdReserveVaultRepo._token0()),
                tokenIn: tokenIn,
                opposingToken: IERC20(ConstProdReserveVaultRepo._opposingToken(address(tokenIn))),
                amountIn: amountIn,
                recipient: address(this),
                deadline: deadline
            });
            uint256 lpMinted = AerodromeService._swapDepositVolatile(zapInParams);

            ERC4626Repo._setLastTotalAssets(IERC20(address(pool)).balanceOf(address(this)));
            amountOut =
                BetterMath._convertToSharesDown(lpMinted, vs.vaultLpReserve, vs.vaultTotalShares, vs.decimalOffset);
            if (amountOut < minAmountOut) revert MinAmountNotMet(minAmountOut, amountOut);
            ERC20Repo._mint(recipient, amountOut);
            return amountOut;
        }

        /* ------------------------------------------------------------------ */
        /*                       ZapOut Vault Withdrawal                      */
        /* ------------------------------------------------------------------ */

        if (
            address(tokenIn) == address(this)
                && ConstProdReserveVaultRepo._isReserveAssetContained(constProd, address(tokenOut))
        ) {
            _claimAndCompoundFees(_buildCompoundParams(pool, deadline));

            VaultState memory vs;
            vs.vaultLpReserve = ERC4626Repo._lastTotalAssets();
            vs.vaultTotalShares = ERC20Repo._totalSupply();
            vs.decimalOffset = ERC4626Repo._decimalOffset();

            _secureSelfBurn(msg.sender, amountIn, pretransferred);
            uint256 lpAmount =
                BetterMath._convertToAssetsDown(amountIn, vs.vaultLpReserve, vs.vaultTotalShares, vs.decimalOffset);

            IERC20(address(pool)).approve(address(aerodromeRouter), lpAmount);
            amountOut =
                _withdrawSwapVolatileSafe(aerodromeRouter, pool, IERC20(tokenOut), lpAmount, recipient, deadline);

            if (amountOut < minAmountOut) revert MinAmountNotMet(minAmountOut, amountOut);
            ERC4626Repo._setLastTotalAssets(IERC20(address(pool)).balanceOf(address(this)));
            return amountOut;
        }

        revert InvalidRoute(address(tokenIn), address(tokenOut));
    }

    function _swapReserveAssets(
        IERC20 tokenIn,
        uint256 amountIn,
        IERC20 tokenOut,
        uint256 minAmountOut,
        address recipient,
        bool pretransferred,
        uint256 deadline
    ) internal returns (uint256 amountOut) {
        IAerodromeRouter aerodromeRouter = AerodromeRouterAwareRepo._aerodromeRouter();

        amountIn = _secureTokenTransfer(tokenIn, amountIn, pretransferred);
        tokenIn.approve(address(aerodromeRouter), amountIn);

        IAerodromeRouter.Route[] memory routes = new IAerodromeRouter.Route[](1);
        routes[0] = IAerodromeRouter.Route({
            from: address(tokenIn),
            to: address(tokenOut),
            stable: AerodromePoolMetadataRepo._isStable(),
            factory: address(AerodromePoolMetadataRepo._factory())
        });

        address swapRecipient = recipient;
        if (recipient == address(tokenIn) || recipient == address(tokenOut)) {
            swapRecipient = address(this);
        }

        uint256[] memory amountsOut =
            aerodromeRouter.swapExactTokensForTokens(amountIn, minAmountOut, routes, swapRecipient, deadline);

        if (IERC20(address(ERC4626Repo._reserveAsset())).balanceOf(address(this)) != ERC4626Repo._lastTotalAssets()) {
            revert();
        }

        amountOut = amountsOut[amountsOut.length - 1];
        if (swapRecipient != recipient) {
            tokenOut.safeTransfer(recipient, amountOut);
        }
    }

    function _withdrawSwapVolatileSafe(
        IAerodromeRouter aerodromeRouter,
        IPool pool,
        IERC20 tokenOut,
        uint256 lpBurnAmt,
        address recipient,
        uint256 deadline
    ) internal returns (uint256 amountOut) {
        address opposingToken = ConstProdReserveVaultRepo._opposingToken(address(tokenOut));
        address swapRecipient = recipient;
        if (recipient == address(tokenOut) || recipient == opposingToken || recipient == address(pool)) {
            swapRecipient = address(this);
        }

        AerodromeService.WithdrawSwapVolatileParams memory params = AerodromeService.WithdrawSwapVolatileParams({
            aerodromeRouter: aerodromeRouter,
            pool: pool,
            factory: AerodromePoolMetadataRepo._factory(),
            tokenOut: tokenOut,
            opposingToken: IERC20(opposingToken),
            lpBurnAmt: lpBurnAmt,
            recipient: swapRecipient,
            deadline: deadline
        });
        amountOut = AerodromeService._withdrawSwapVolatile(params);
        if (swapRecipient != recipient) {
            tokenOut.safeTransfer(recipient, amountOut);
        }
    }
}
