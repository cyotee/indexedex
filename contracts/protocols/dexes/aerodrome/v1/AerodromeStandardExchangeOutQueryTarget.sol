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

        if (ConstProdReserveVaultRepo._isReserveAssetContained(address(tokenIn)) && address(tokenOut) == address(aeroReserve.pool)) {
            (uint256 reserve0_, uint256 reserve1_,) = aeroReserve.pool.getReserves();
            (uint256 in_, uint256 out_) = ConstProdUtils._sortReserves(address(tokenIn), ConstProdReserveVaultRepo._token0(), reserve0_, reserve1_);
            uint256 fee_ = AerodromePoolMetadataRepo._factory().getFee(address(aeroReserve.pool), AerodromePoolMetadataRepo._isStable());
            return _quoteAeroZapToLp(amountOut, IERC20(address(aeroReserve.pool)).totalSupply(), in_, out_, fee_);
        }
        if (address(tokenIn) == address(aeroReserve.pool) && ConstProdReserveVaultRepo._isReserveAssetContained(address(tokenOut))) {
            (uint256 reserve0_, uint256 reserve1_,) = aeroReserve.pool.getReserves();
            (uint256 out_, uint256 other_) = ConstProdUtils._sortReserves(address(tokenOut), ConstProdReserveVaultRepo._token0(), reserve0_, reserve1_);
            uint256 fee_ = AerodromePoolMetadataRepo._factory().getFee(address(aeroReserve.pool), AerodromePoolMetadataRepo._isStable());
            return _quoteAeroLpToToken(amountOut, IERC20(address(aeroReserve.pool)).totalSupply(), out_, other_, fee_);
        }

        // Share issuance and redemption use the same actual compounding state as exact-in routes.
        if (
            (address(tokenOut) == address(this) && (address(tokenIn) == address(aeroReserve.pool)
                || ConstProdReserveVaultRepo._isReserveAssetContained(address(tokenIn))))
            || (address(tokenIn) == address(this) && (address(tokenOut) == address(aeroReserve.pool)
                || ConstProdReserveVaultRepo._isReserveAssetContained(address(tokenOut))))
        ) return _previewFundedExactOutput(aeroReserve.pool, tokenIn, tokenOut, amountOut);

        revert InvalidRoute(address(tokenIn), address(tokenOut));
    }


}
