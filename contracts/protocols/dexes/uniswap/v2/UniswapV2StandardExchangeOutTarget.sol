// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {
    UNISWAP_PROTOCOL_FEE_SHARE,
    UNISWAP_FEE_DENOMINATOR,
    UNISWAPV2_FEE_PERCENT,
    UNISWAPV2_FEE_DENOMINATOR,
    UNISWAPV2_PROTOCOL_FEE_SHARE
} from "@crane/contracts/constants/Constants.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IUniswapV2Pair} from "@crane/contracts/interfaces/protocols/dexes/uniswap/v2/IUniswapV2Pair.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {ERC4626Repo} from "@crane/contracts/tokens/ERC4626/ERC4626Repo.sol";
import {ERC4626Service} from "@crane/contracts/tokens/ERC4626/ERC4626Service.sol";
import {
    UniswapV2FactoryAwareRepo
} from "@crane/contracts/protocols/dexes/uniswap/v2/aware/UniswapV2FactoryAwareRepo.sol";
import {BetterMath} from "@crane/contracts/utils/math/BetterMath.sol";
import {ConstProdUtils} from "@crane/contracts/utils/math/ConstProdUtils.sol";
import {UniswapV2RouterAwareRepo} from "@crane/contracts/protocols/dexes/uniswap/v2/aware/UniswapV2RouterAwareRepo.sol";
import {ReentrancyLockModifiers} from "@crane/contracts/access/reentrancy/ReentrancyLockModifiers.sol";
import {BetterSafeERC20 as SafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {UniswapV2Service} from "@crane/contracts/protocols/dexes/uniswap/v2/services/UniswapV2Service.sol";
import {IUniswapV2Router} from "@crane/contracts/interfaces/protocols/dexes/uniswap/v2/IUniswapV2Router.sol";
import {IUniswapV2Pair} from "@crane/contracts/interfaces/protocols/dexes/uniswap/v2/IUniswapV2Pair.sol";
import {UniswapV2Utils} from "@crane/contracts/utils/math/UniswapV2Utils.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {ConstProdReserveVaultRepo} from "contracts/vaults/ConstProdReserveVaultRepo.sol";
import {VaultFeeOracleQueryAwareRepo} from "contracts/oracles/fee/VaultFeeOracleQueryAwareRepo.sol";
import {
    UniswapV2StandardExchangeCommon
} from "contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeCommon.sol";

abstract contract UniswapV2StandardExchangeOutTarget is
    UniswapV2StandardExchangeCommon,
    ReentrancyLockModifiers,
    IStandardExchangeOut
{
    using SafeERC20 for IERC20;
    using UniswapV2Service for IUniswapV2Router;
    using UniswapV2Service for IUniswapV2Pair;

    function previewExchangeOut(IERC20 tokenIn, IERC20 tokenOut, uint256 amountOut)
        external
        view
        returns (uint256 amountIn)
    {
        // Mirror the same 7-branch logic as exchangeOut but with view-only calculations

        // Determine actual token route from provided tokens.
        // Intended supported routes.
        // 1. Pass-through Swap - Swap of token contained in the underlying pool for the opposing token contained in the underlying pool.
        //    Implelemented in first branch.
        // 2. Pass-through ZapIn - Deposit as ZapIn of token contained in the underlying pool for the underlying pool token.
        //    Implelemented in second branch.
        // 3. Underlying Pool Vault Deposit - Deposit of the underlying pool token into the vault.
        //    Implelemented in third branch.
        // 4. ZapIn Vault Deposit - Deposit as ZapIn of the token contained in the underlying pool for the underlying pool token into the vault.
        //    Implelemented in fourth branch.
        // 5. Underlying Pool Vault Withdrawal - Withdraw of the underlying pool token from the vault.
        //    Implelemented in fifth branch.
        // 6. Pass-through ZapOut - Withdraw as ZapOut of token contained in the underlying pool from the underlying pool as tokenIn.
        //    Implelemented in sixth branch.
        // 7. ZapOut Vault Withdrawal - Withdraw as ZapOut of token contained in the underlying pool from the underlying pool token from the vault.
        //    Implelemented in seventh branch.

        UnIV2IndexSourceReserves memory indexSource;

        ConstProdReserveVaultRepo.Storage storage constProd = ConstProdReserveVaultRepo._layoutStruct();

        // Ensure the pool reference is available before any calculations that
        // rely on the pool (e.g. _loadIndexSourceReserves). The pass-through
        // execution path calls _loadIndexSourceReserves and expects indexSource.pool to be set.
        indexSource.pool = IUniswapV2Pair(address(ERC4626Repo._reserveAsset()));

        // Ensure the pool reference is available before any preview calculations that
        // rely on the pool (e.g. _loadIndexSourceReserves). The pass-through preview
        // path calls _loadIndexSourceReserves and expects indexSource.pool to be set.
        indexSource.pool = IUniswapV2Pair(address(ERC4626Repo._reserveAsset()));

        /* ------------------------------------------------------------------ */
        /*                          Pass-through Swap                         */
        /* ------------------------------------------------------------------ */

        if (
            ConstProdReserveVaultRepo._isReserveAssetContained(constProd, address(tokenIn))
                && ConstProdReserveVaultRepo._isReserveAssetContained(constProd, address(tokenOut))
        ) {
            // Load the index source data.
            // Loads the underlying pool token, token 0, and token 1.
            // Also loads the reserves of the known token and the opposing token.
            // Also loads the fee percent of the known token and the opposing token.
            // Sorts the reserves of the known token and the opposing token.
            _loadIndexSourceReserves(indexSource, tokenIn);
            // Calculate the amount in required to purchase the requested amount out.
            // Use Uniswap router/library math (getAmountIn) to exactly match execution semantics
            // (router uses its own integer rounding and +1 safety increment).
            amountIn = UniswapV2RouterAwareRepo._uniswapV2Router()
                .getAmountIn(amountOut, indexSource.knownReserve, indexSource.opposingReserve);
            return amountIn;
        }

        indexSource.pool = IUniswapV2Pair(address(ERC4626Repo._reserveAsset()));

        /* ------------------------------------------------------------------ */
        /*                         Pass-through ZapIn                         */
        /* ------------------------------------------------------------------ */

        if (
            ConstProdReserveVaultRepo._isReserveAssetContained(constProd, address(tokenIn))
                && address(tokenOut) == address(indexSource.pool)
        ) {
            // Inverse of _quoteSwapDepositWithFee: given target LP amount out, find minimum
            // amountIn of tokenIn required.  Uses closed-form binary search in ConstProdUtils.
            _loadIndexSourceReserves(indexSource, tokenIn);
            amountIn = ConstProdUtils._quoteZapInToTargetLPWithFee(
                // uint256 targetLP,
                amountOut,
                // uint256 lpTotalSupply,
                indexSource.totalSupply,
                // uint256 reserveIn,
                indexSource.knownReserve,
                // uint256 reserveOut,
                indexSource.opposingReserve,
                // uint256 feePercent,
                indexSource.knownfeePercent,
                // uint256 feeDenominator,
                UNISWAPV2_FEE_DENOMINATOR,
                // uint256 kLast,
                indexSource.kLast,
                // uint256 ownerFeeShare,
                UNISWAPV2_PROTOCOL_FEE_SHARE,
                // bool feeOn
                UniswapV2FactoryAwareRepo._uniswapV2Factory().feeTo() != address(0)
            );
            return amountIn;
        }

        /* ------------------------------------------------------------------ */
        /*                         Pass-through ZapOut                        */
        /* ------------------------------------------------------------------ */

        if (
            address(tokenIn) == address(indexSource.pool)
                && ConstProdReserveVaultRepo._isReserveAssetContained(constProd, address(tokenOut))
        ) {
            // Load the index source data.
            // Loads the underlying pool token, token 0, and token 1.
            // Also loads the reserves of the known token and the opposing token.
            // Also loads the fee percent of the known token and the opposing token.
            // Sorts the reserves of the known token and the opposing token.
            _loadIndexSourceReserves(indexSource, tokenOut);
            // Load the index supply data.
            // Loads the total supply of the underlying pool token.
            // Loads the kLast of the underlying pool token.
            // UniV2IndexSupply memory indexSupply;
            // _loadIndexSupply(indexSource, indexSupply);
            // Calculate the amount of LP tokens needed to ZapOut to target amount out.
            // Quotes an overage as a margin due to inability to efficiently quote exact amount in.
            amountIn = ConstProdUtils._quoteZapOutToTargetWithFee(
                // uint256 desiredOut,
                amountOut,
                // uint256 lpTotalSupply,
                indexSource.totalSupply,
                // uint256 reserveIn,
                indexSource.knownReserve,
                // uint256 reserveOut,
                indexSource.opposingReserve,
                // uint256 feePercent,
                indexSource.opTokenFeePercent,
                // uint256 feeDenominator,
                100000,
                // uint256 kLast,
                indexSource.kLast,
                // uint256 ownerFeeShare,
                UNISWAP_PROTOCOL_FEE_SHARE,
                // bool feeOn
                UniswapV2FactoryAwareRepo._uniswapV2Factory().feeTo() != address(0)
            );
            return amountIn;
        }

        /* ------------------------------------------------------------------ */
        /*                    Underlying Pool Vault Deposit                   */
        /* ------------------------------------------------------------------ */

        if (address(tokenIn) == address(indexSource.pool) && address(tokenOut) == address(this)) {
            // Load the index source data.
            // Loads the underlying pool token, token 0, and token 1.
            // Also loads the reserves of the known token and the opposing token.
            // Also loads the fee percent of the known token and the opposing token.
            // Sorts the reserves of the known token and the opposing token.
            // Pass IERC20(address(0)) as the known token force token0 to be the known token.
            _loadIndexSourceReserves(indexSource, IERC20(address(0)));
            // Load the index supply data.
            // Loads the total supply of the underlying pool token.
            // Loads the kLast of the underlying pool token.
            // UniV2IndexSupply memory indexSupply;
            // _loadIndexSupply(indexSource, indexSupply);
            // Load the strategy vault data.
            // Loads the vault LP reserve, vault total shares.
            // Also loads the known token last owned source reserve.
            // Also loads the opposing token last owned source reserve.
            // Also stores the fee shares.
            UniV2StrategyVault memory vault;
            _loadStrategyVault(vault, IERC20(indexSource.token0));
            // Calculates the vault fee.
            // Will add fee shares to vault.vaultTotalShares.
            _calcVaultFee(indexSource, vault);
            // Calculate the underlying pool tokens amountIn for vault Shares amountOut.
            return BetterMath._convertToAssetsUp(
                // uint256 shares,
                amountOut,
                // uint256 reserve,
                vault.vaultLpReserve,
                // uint256 totalShares
                vault.vaultTotalShares,
                ERC4626Repo._decimalOffset()
            );
        }

        /* ------------------------------------------------------------------ */
        /*                  Underlying Pool Vault Withdrawal                  */
        /* ------------------------------------------------------------------ */

        if (address(tokenIn) == address(this) && address(tokenOut) == address(indexSource.pool)) {
            // Load the index source data.
            // Loads the underlying pool token, token 0, and token 1.
            // Also loads the reserves of the known token and the opposing token.
            // Also loads the fee percent of the known token and the opposing token.
            // Sorts the reserves of the known token and the opposing token.
            // Pass IERC20(address(0)) as the known token force token0 to be the known token.
            _loadIndexSourceReserves(indexSource, IERC20(address(0)));
            // Load the index supply data.
            // Loads the total supply of the underlying pool token.
            // Loads the kLast of the underlying pool token.
            // UniV2IndexSupply memory indexSupply;
            // _loadIndexSupply(indexSource, indexSupply);
            // Load the strategy vault data.
            // Loads the vault LP reserve, vault total shares.
            // Also loads the known token last owned source reserve.
            // Also loads the opposing token last owned source reserve.
            // Also stores the fee shares.
            UniV2StrategyVault memory vault;
            _loadStrategyVault(vault, IERC20(indexSource.token0));
            // Calculates the vault fee.
            // Will add fee shares to vault.vaultTotalShares.
            _calcVaultFee(indexSource, vault);
            // Calculate shares due for withdrawal of amountOut.
            amountIn = BetterMath._convertToSharesUp(
                // uint256 assets,
                amountOut,
                // uint256 reserve,
                vault.vaultLpReserve,
                // uint256 totalShares
                vault.vaultTotalShares,
                ERC4626Repo._decimalOffset()
            );

            // Return exact shares needed to match execution (no additional rounding)
            return amountIn;
        }

        /* ------------------------------------------------------------------ */
        /*                         ZapIn Vault Deposit                        */
        /* ------------------------------------------------------------------ */

        if (
            ConstProdReserveVaultRepo._isReserveAssetContained(constProd, address(tokenIn))
                && address(tokenOut) == address(this)
        ) {
            // Two-step inverse:
            //   Step 1: Convert target shares → target LP tokens using the post-deposit
            //           inverse formula (mirrors exchangeIn Route 6 share accounting).
            //   Step 2: Convert target LP → amountIn of tokenIn via ZapIn inverse.
            _loadIndexSourceReserves(indexSource, tokenIn);
            UniV2StrategyVault memory vault;
            _loadStrategyVault(vault, tokenIn);
            _calcVaultFee(indexSource, vault);
            // Correct post-deposit inverse of:
            //   shares = floor(LP * (S + 10^d) / (R_before + LP + 1))
            // Solving for LP:
            //   LP >= ceil(shares * (R_before + 1) / (S + 10^d - shares))
            uint256 decimalUnit = 10 ** ERC4626Repo._decimalOffset();
            if (amountOut >= vault.vaultTotalShares + decimalUnit) return 0;
            uint256 lpTarget;
            {
                uint256 numerator = amountOut * (vault.vaultLpReserve + 1);
                uint256 denominator = vault.vaultTotalShares + decimalUnit - amountOut;
                lpTarget = numerator / denominator;
                if (denominator > 0 && numerator % denominator != 0) {
                    lpTarget += 1;
                }
            }
            amountIn = ConstProdUtils._quoteZapInToTargetLPWithFee(
                // uint256 targetLP,
                lpTarget,
                // uint256 lpTotalSupply,
                indexSource.totalSupply,
                // uint256 reserveIn,
                indexSource.knownReserve,
                // uint256 reserveOut,
                indexSource.opposingReserve,
                // uint256 feePercent,
                indexSource.knownfeePercent,
                // uint256 feeDenominator,
                UNISWAPV2_FEE_DENOMINATOR,
                // uint256 kLast,
                indexSource.kLast,
                // uint256 ownerFeeShare,
                UNISWAPV2_PROTOCOL_FEE_SHARE,
                // bool feeOn
                UniswapV2FactoryAwareRepo._uniswapV2Factory().feeTo() != address(0)
            );
            return amountIn;
        }

        /* ------------------------------------------------------------------ */
        /*                       ZapOut Vault Withdrawal                      */
        /* ------------------------------------------------------------------ */

        if (
            address(tokenIn) == address(this)
                && ConstProdReserveVaultRepo._isReserveAssetContained(constProd, address(tokenOut))
        ) {
            // Load the index source data.
            // Loads the underlying pool token, token 0, and token 1.
            // Also loads the reserves of the known token and the opposing token.
            // Also loads the fee percent of the known token and the opposing token.
            // Sorts the reserves of the known token and the opposing token.
            _loadIndexSourceReserves(indexSource, tokenOut);
            // Load the index supply data.
            // Loads the total supply of the underlying pool token.
            // Loads the kLast of the underlying pool token.
            // UniV2IndexSupply memory indexSupply;
            // _loadIndexSupply(indexSource, indexSupply);
            // Load the strategy vault data.
            // Loads the vault LP reserve, vault total shares.
            // Also loads the known token last owned source reserve.
            // Also loads the opposing token last owned source reserve.
            // Also stores the fee shares.
            UniV2StrategyVault memory vault;
            _loadStrategyVault(vault, tokenOut);
            // Calculates the vault fee.
            // Will add fee shares to vault.vaultTotalShares.
            _calcVaultFee(indexSource, vault);
            // Calculate the amount of LP tokens needed to ZapOut to target amount out.
            amountOut = ConstProdUtils._quoteZapOutToTargetWithFee(
                // uint256 desiredOut,
                amountOut,
                // uint256 lpTotalSupply,
                indexSource.totalSupply,
                // uint256 reserveIn,
                indexSource.knownReserve,
                // uint256 reserveOut,
                indexSource.opposingReserve,
                // uint256 feePercent,
                indexSource.opTokenFeePercent,
                // uint256 feeDenominator,
                100000,
                // uint256 kLast,
                indexSource.kLast,
                // uint256 ownerFeeShare,
                UNISWAP_PROTOCOL_FEE_SHARE,
                // bool feeOn
                UniswapV2FactoryAwareRepo._uniswapV2Factory().feeTo() != address(0)
            );
            // Calculate the shares due for withdrawal of amountOut.
            amountIn = BetterMath._convertToSharesUp(
                // uint256 assets,
                amountOut,
                // uint256 reserve,
                vault.vaultLpReserve,
                // uint256 totalShares
                vault.vaultTotalShares,
                ERC4626Repo._decimalOffset()
            );

            return amountIn;
        }
        revert InvalidRoute(address(tokenIn), address(tokenOut));
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
        _requireNotDisabled();
        if (block.timestamp > deadline) {
            revert DeadlineExceeded(deadline, block.timestamp);
        }
        // Same 7-branch logic as exchangeIn but with reverse calculations

        // Determine actual token route from provided tokens.
        // Intended supported routes.
        // 1. Pass-through Swap - Swap of token contained in the underlying pool for the opposing token contained in the underlying pool.
        //    Implelemented in first branch.
        // 2. Pass-through ZapIn - Deposit as ZapIn of token contained in the underlying pool for the underlying pool token.
        //    Implelemented in second branch.
        // 3. Underlying Pool Vault Deposit - Deposit of the underlying pool token into the vault.
        //    Implelemented in third branch.
        // 4. ZapIn Vault Deposit - Deposit as ZapIn of the token contained in the underlying pool for the underlying pool token into the vault.
        //    Implelemented in fourth branch.
        // 5. Underlying Pool Vault Withdrawal - Withdraw of the underlying pool token from the vault.
        //    Implelemented in fifth branch.
        // 6. Pass-through ZapOut - Withdraw as ZapOut of token contained in the underlying pool from the underlying pool as tokenIn.
        //    Implelemented in sixth branch.
        // 7. ZapOut Vault Withdrawal - Withdraw as ZapOut of token contained in the underlying pool from the underlying pool token from the vault.
        //    Implelemented in seventh branch.

        UnIV2IndexSourceReserves memory indexSource;

        ConstProdReserveVaultRepo.Storage storage constProd = ConstProdReserveVaultRepo._layoutStruct();

        // Initialize the pool reference early, before any branches that rely on it.
        // This is required for the pass-through swap path which calls _loadIndexSourceReserves.
        indexSource.pool = IUniswapV2Pair(address(ERC4626Repo._reserveAsset()));

        /* ------------------------------------------------------------------ */
        /*                          Pass-through Swap                         */
        /* ------------------------------------------------------------------ */

        if (
            ConstProdReserveVaultRepo._isReserveAssetContained(constProd, address(tokenIn))
                && ConstProdReserveVaultRepo._isReserveAssetContained(constProd, address(tokenOut))
        ) {
            // Load the index source data.
            // Loads the underlying pool token, token 0, and token 1.
            // Also loads the reserves of the known token and the opposing token.
            // Also loads the fee percent of the known token and the opposing token.
            // Sorts the reserves of the known token and the opposing token.
            // Pass IERC20(address(0)) as the known token force token0 to be the known token.
            _loadIndexSourceReserves(indexSource, tokenIn);

            // Calculate the amountIn required to purchase the requested amountOut
            // amountIn = ConstProdUtils._purchaseQuote(
            //     // uint256 amountOut,
            //     amountOut,
            //     // uint256 reserveIn,
            //     indexSource.knownReserve,
            //     // uint256 reserveOut,
            //     indexSource.opposingReserve,
            //     // uint256 feePercent
            //     indexSource.knownfeePercent
            // );
            IUniswapV2Router uniV2Router = UniswapV2RouterAwareRepo._uniswapV2Router();
            // Use Uniswap router/library math (getAmountIn) to exactly match preview semantics
            // and the router's integer rounding/+1 safety increment.
            amountIn = uniV2Router.getAmountIn(amountOut, indexSource.knownReserve, indexSource.opposingReserve);

            // Check if the required amountIn is greater than the maxAmountIn
            if (amountIn > maxAmountIn) {
                revert MaxAmountExceeded(maxAmountIn, amountIn);
            }

            // Pull the required amountIn
            amountIn = _secureTokenTransfer(tokenIn, amountIn, pretransferred);

            // Perform the swap
            amountIn = uniV2Router._swapTokensForExactTokens(tokenIn, amountIn, tokenOut, amountOut, recipient);

            // Refund any excess pretransferred tokenIn back to the caller.
            _refundExcess(tokenIn, maxAmountIn, amountIn, pretransferred, msg.sender);

            return amountIn;
        }

        indexSource.pool = IUniswapV2Pair(address(ERC4626Repo._reserveAsset()));

        /* ------------------------------------------------------------------ */
        /*                         Pass-through ZapIn                         */
        /* ------------------------------------------------------------------ */

        if (
            ConstProdReserveVaultRepo._isReserveAssetContained(constProd, address(tokenIn))
                && address(tokenOut) == address(indexSource.pool)
        ) {
            // Compute amountIn required to ZapIn and receive at least amountOut LP tokens.
            _loadIndexSourceReserves(indexSource, tokenIn);
            amountIn = ConstProdUtils._quoteZapInToTargetLPWithFee(
                // uint256 targetLP,
                amountOut,
                // uint256 lpTotalSupply,
                indexSource.totalSupply,
                // uint256 reserveIn,
                indexSource.knownReserve,
                // uint256 reserveOut,
                indexSource.opposingReserve,
                // uint256 feePercent,
                indexSource.knownfeePercent,
                // uint256 feeDenominator,
                UNISWAPV2_FEE_DENOMINATOR,
                // uint256 kLast,
                indexSource.kLast,
                // uint256 ownerFeeShare,
                UNISWAPV2_PROTOCOL_FEE_SHARE,
                // bool feeOn
                UniswapV2FactoryAwareRepo._uniswapV2Factory().feeTo() != address(0)
            );
            // Slippage guard: caller must have approved at least amountIn.
            if (amountIn > maxAmountIn) {
                revert MaxAmountExceeded(maxAmountIn, amountIn);
            }
            // Secure tokenIn from the caller.
            amountIn = _secureTokenTransfer(tokenIn, amountIn, pretransferred);
            // Execute the swap/deposit (ZapIn).
            uint256 lpOut = UniswapV2RouterAwareRepo._uniswapV2Router()
                ._swapDeposit(
                    // IUniswapV2Router router,
                    // IUniswapV2Pair pool,
                    indexSource.pool,
                    // IERC20 tokenIn,
                    tokenIn,
                    // uint256 saleAmt,
                    amountIn,
                    // IERC20 opToken,
                    IERC20(ConstProdReserveVaultRepo._opposingToken(address(tokenIn)))
                );
            // Ensure the LP output meets the requested amountOut.
            if (lpOut < amountOut) revert AmountOutNotMet(amountOut, lpOut);
            // Transfer the LP tokens to the recipient.
            IERC20(address(indexSource.pool))
                .safeTransfer(
                    recipient,
                    lpOut
                );
            // Refund any excess pretransferred tokenIn.
            _refundExcess(tokenIn, maxAmountIn, amountIn, pretransferred, msg.sender);
            // Verify the vault's stored LP reserve is still consistent.
            {
                UniV2StrategyVault memory vault2;
                _loadStrategyVault(vault2, tokenIn);
                uint256 poolBalance = indexSource.pool.balanceOf(address(this));
                if (poolBalance != vault2.vaultLpReserve) {
                    revert();
                }
            }
            return amountIn;
        }

        /* ------------------------------------------------------------------ */
        /*                         Pass-through ZapOut                        */
        /* ------------------------------------------------------------------ */

        if (
            address(tokenIn) == address(indexSource.pool)
                && ConstProdReserveVaultRepo._isReserveAssetContained(constProd, address(tokenOut))
        ) {
            // Load the index source data.
            // Loads the underlying pool token, token 0, and token 1.
            // Also loads the reserves of the known token and the opposing token.
            // Also loads the fee percent of the known token and the opposing token.
            // Sorts the reserves of the known token and the opposing token.
            // Pass IERC20(address(0)) as the known token force token0 to be the known token.
            _loadIndexSourceReserves(indexSource, tokenOut);
            // Load the index supply data.
            // Loads the total supply of the underlying pool token.
            // Loads the kLast of the underlying pool token.
            // UniV2IndexSupply memory indexSupply;
            // _loadIndexSupply(indexSource, indexSupply);
            // Load the strategy vault data.
            // Loads the vault LP reserve, vault total shares.
            // Also loads the known token last owned source reserve.
            // Also loads the opposing token last owned source reserve.
            // Also stores the fee shares.
            UniV2StrategyVault memory vault;
            _loadStrategyVault(vault, tokenOut);

            amountIn = ConstProdUtils._quoteZapOutToTargetWithFee(
                // uint256 desiredOut,
                amountOut,
                // uint256 lpTotalSupply,
                indexSource.totalSupply,
                // uint256 reserveIn,
                indexSource.knownReserve,
                // uint256 reserveOut,
                indexSource.opposingReserve,
                // uint256 feePercent,
                indexSource.opTokenFeePercent,
                // uint256 feeDenominator,
                UNISWAP_FEE_DENOMINATOR,
                // uint256 kLast,
                indexSource.kLast,
                // uint256 ownerFeeShare,
                UNISWAP_PROTOCOL_FEE_SHARE,
                // bool feeOn
                UniswapV2FactoryAwareRepo._uniswapV2Factory().feeTo() != address(0)
            );
            // Check if the required amountIn is greater then the maxAmountIn.
            if (amountIn > maxAmountIn) {
                // If required amountIn is greater then maxAmountIn, revert.
                revert MaxAmountExceeded(maxAmountIn, amountIn);
            }
            // Secure the payment of the tokenIn.
            // NOTE: _secureTokenTransfer returns balanceOf(this), which may exceed amountIn
            // when pretransferred with surplus. Use the computed amountIn for operations
            // and refund any excess to the caller.
            _secureTokenTransfer(
                // IERC20 tokenIn,
                tokenIn,
                // uint256 amountTokenToDeposit,
                amountIn,
                // bool pretransferred
                pretransferred
            );
            // Load the router.
            // IUniswapV2Router router_ = _uniV2Router();
            amountOut = indexSource.pool
                ._withdrawSwapDirect(
                    // IUniswapV2Pair pool,
                    // IUniswapV2Router router,
                    UniswapV2RouterAwareRepo._uniswapV2Router(),
                    // uint256 amt,
                    amountIn,
                    // IERC20 tokenOut,
                    tokenOut,
                    // IERC20 opToken
                    IERC20(ConstProdReserveVaultRepo._opposingToken(address(tokenOut)))
                );
            // Transfer the underlying pool token to the recipient.
            IERC20(address(tokenOut))
                .safeTransfer(
                    // IERC20 token,
                    // address to,
                    recipient,
                    // uint256 amount
                    amountOut
                );
            // Refund any excess pretransferred tokenIn back to the caller.
            // Must happen BEFORE reserve check since tokenIn IS the pool token —
            // surplus LP in the vault would cause the reserve check to fail.
            _refundExcess(tokenIn, maxAmountIn, amountIn, pretransferred, msg.sender);
            // No reserve change, so no update needed.
            // But we do receive and send pool tokens, so we must verify the reserve still matches the held balance.
            // Check that local balance of the pool token still matches the stored reserve.
            uint256 poolBalance = indexSource.pool.balanceOf(address(this));
            if (poolBalance != vault.vaultLpReserve) {
                revert();
            }
            // Go ahead and terminate further executiuon.
            return amountIn;
        }

        /* ------------------------------------------------------------------ */
        /*                    Underlying Pool Vault Deposit                   */
        /* ------------------------------------------------------------------ */

        if (address(tokenIn) == address(indexSource.pool) && address(tokenOut) == address(this)) {
            _loadIndexSourceReserves(indexSource, IERC20(address(0)));
            // UniV2IndexSupply memory indexSupply;
            // _loadIndexSupply(indexSource, indexSupply);
            UniV2StrategyVault memory vault;
            _loadStrategyVault(vault, IERC20(indexSource.token0));
            _calcVaultFee(indexSource, vault);
            // Mint the shares to the protocol.
            ERC20Repo._mint(
                // address account,
                address(VaultFeeOracleQueryAwareRepo._feeOracle().feeTo()),
                // uint256 amount,
                vault.feeShares
            );

            // Calculate how many pool tokens are needed to get the desired amount of shares
            // Use totalShares + feeShares to account for the fee impact on conversion ratio
            amountIn = BetterMath._convertToAssetsUp(
                amountOut, vault.vaultLpReserve, vault.vaultTotalShares, ERC4626Repo._decimalOffset()
            );

            // Check if the required amountIn is greater than the maxAmountIn
            if (amountIn > maxAmountIn) {
                revert MaxAmountExceeded(maxAmountIn, amountIn);
            }

            // Secure the payment of the tokenIn
            amountIn = ERC4626Service._secureReserveDeposit(
                ERC4626Repo._layoutStruct(),
                vault.vaultLpReserve,
                // uint256 amountTokenToDeposit,
                amountIn
            );

            uint256 actualShares = BetterMath._convertToSharesDown(
                // uint256 assets,
                amountIn,
                // uint256 reserve,
                vault.vaultLpReserve,
                // uint256 totalShares
                vault.vaultTotalShares,
                ERC4626Repo._decimalOffset()
            );

            if (actualShares != amountOut) revert AmountOutNotMet(amountOut, actualShares);

            // Update the reserve of the underlying pool token
            // _updateReserve(IERC20(address(indexSource.pool)), indexSource.pool.balanceOf(address(this)));

            // Mint exactly the requested amountOut to the recipient
            ERC20Repo._mint(
                // address account,
                recipient,
                // uint256 amount,
                amountOut
            );
            return amountIn;
        }

        /* ------------------------------------------------------------------ */
        /*                  Underlying Pool Vault Withdrawal                  */
        /* ------------------------------------------------------------------ */

        if (address(tokenIn) == address(this) && address(tokenOut) == address(indexSource.pool)) {
            _loadIndexSourceReserves(indexSource, IERC20(address(0)));
            // UniV2IndexSupply memory indexSupply;
            // _loadIndexSupply(indexSource, indexSupply);
            UniV2StrategyVault memory vault;
            _loadStrategyVault(vault, IERC20(indexSource.token0));
            _calcVaultFee(indexSource, vault);
            // Mint the shares to the protocol.
            ERC20Repo._mint(
                // address account,
                address(VaultFeeOracleQueryAwareRepo._feeOracle().feeTo()),
                // uint256 amount,
                vault.feeShares
            );

            // Calculate the amount of shares needed to withdraw amountOut, rounding UP to ensure
            // the burned shares always cover the exact assets paid out.
            amountIn = BetterMath._convertToSharesUp(
                /* assets */
                amountOut,
                /* reserve */
                vault.vaultLpReserve,
                /* totalShares */
                vault.vaultTotalShares,
                ERC4626Repo._decimalOffset()
            );

            // Check if the required amountIn is greater then the maxAmountIn.
            if (amountIn > maxAmountIn) {
                // If required amountIn is greater then maxAmountIn, revert.
                revert MaxAmountExceeded(maxAmountIn, amountIn);
            }

            // Secure the burn of the underlying pool token.
            _secureSelfBurn(
                // address owner,
                msg.sender,
                // uint256 burnAmount,
                amountIn,
                // bool preTransferred
                pretransferred
            );

            // Transfer exactly the requested amountOut (don't recalculate to avoid rounding errors)
            IERC20(address(indexSource.pool))
                .safeTransfer(
                    // IERC20 token,
                    // address to,
                    recipient,
                    // uint256 amount
                    amountOut
                );

            // Update the reserve of the underlying pool token.
            ERC4626Repo._setLastTotalAssets(
                // uint256 amount
                indexSource.pool.balanceOf(address(this))
            );

            // Go ahead and terminate further executiuon.
            return amountIn;
        }

        /* ------------------------------------------------------------------ */
        /*                         ZapIn Vault Deposit                        */
        /* ------------------------------------------------------------------ */

        if (
            ConstProdReserveVaultRepo._isReserveAssetContained(constProd, address(tokenIn))
                && address(tokenOut) == address(this)
        ) {
            return _exchangeOut_zapInVaultDeposit(tokenIn, maxAmountIn, amountOut, recipient, pretransferred);
        }

        /* ------------------------------------------------------------------ */
        /*                       ZapOut Vault Withdrawal                      */
        /* ------------------------------------------------------------------ */

        if (
            address(tokenIn) == address(this)
                && ConstProdReserveVaultRepo._isReserveAssetContained(constProd, address(tokenOut))
        ) {
            _loadIndexSourceReserves(indexSource, tokenOut);
            // UniV2IndexSupply memory indexSupply;
            // _loadIndexSupply(indexSource, indexSupply);
            UniV2StrategyVault memory vault;
            _loadStrategyVault(vault, tokenOut);
            _calcVaultFee(indexSource, vault);
            // Mint the shares to the protocol.
            ERC20Repo._mint(
                // address account,
                address(VaultFeeOracleQueryAwareRepo._feeOracle().feeTo()),
                // uint256 amount,
                vault.feeShares
            );
            uint256 lpToBurn = ConstProdUtils._quoteZapOutToTargetWithFee(
                // uint256 desiredOut,
                amountOut,
                // uint256 lpTotalSupply,
                indexSource.totalSupply,
                // uint256 reserveIn,
                indexSource.knownReserve,
                // uint256 reserveOut,
                indexSource.opposingReserve,
                // uint256 feePercent,
                indexSource.opTokenFeePercent,
                // uint256 feeDenominator,
                100000,
                // uint256 kLast,
                indexSource.kLast,
                // uint256 ownerFeeShare,
                UNISWAP_PROTOCOL_FEE_SHARE,
                // bool feeOn
                UniswapV2FactoryAwareRepo._uniswapV2Factory().feeTo() != address(0)
            );
            // Calculate shares using SAME conversion method as execution
            // Use exact same _convertToShares function with Floor rounding (matches execution function)
            amountIn = BetterMath._convertToSharesUp(
                // uint256 assets,
                lpToBurn,
                // uint256 reserve,
                vault.vaultLpReserve,
                // uint256 totalShares
                vault.vaultTotalShares,
                ERC4626Repo._decimalOffset()
            );

            // Secure the burn of the underlying pool token
            _secureSelfBurn(msg.sender, amountIn, pretransferred);
            // Load the router.
            // IUniswapV2Router router_ = _uniV2Router();
            amountOut = indexSource.pool
                ._withdrawSwapDirect(
                    // IUniswapV2Pair pool,
                    // IUniswapV2Router router,
                    UniswapV2RouterAwareRepo._uniswapV2Router(),
                    // uint256 amt,
                    lpToBurn,
                    // IERC20 tokenOut,
                    tokenOut,
                    // IERC20 opToken
                    IERC20(ConstProdReserveVaultRepo._opposingToken(address(tokenOut)))
                );

            // Transfer the resulting tokenOut to the recipient (withdrawSwapDirect leaves proceeds on the vault)
            IERC20(tokenOut)
                .safeTransfer(
                    // IERC20 token,
                    // address to,
                    recipient,
                    // uint256 amount
                    amountOut
                );

            // Update the reserve of the underlying pool token
            // Update the reserve of the underlying pool token.
            ERC4626Repo._setLastTotalAssets(
                // uint256 amount
                indexSource.pool.balanceOf(address(this))
            );

            return amountIn;
        }
        // console.log("UniswapV2StandardExchangeOutFacet::exchangeOut: no branch matched, reverting with InvalidRoute");
        revert InvalidRoute(address(tokenIn), address(tokenOut));
    }

    /* ---------------------------------------------------------------------- */
    /*               Internal helper — Route 6 exchangeOut body               */
    /* ---------------------------------------------------------------------- */

    /**
     * @dev Extracted to avoid stack-too-deep in the main exchangeOut dispatcher.
     *      Implements Route 6 (ZapIn Vault Deposit, exact-out variant):
     *      caller supplies tokenIn, receives exactly amountOut vault shares.
     */
    function _exchangeOut_zapInVaultDeposit(
        IERC20 tokenIn,
        uint256 maxAmountIn,
        uint256 amountOut,
        address recipient,
        bool pretransferred
    ) internal returns (uint256 amountIn) {
        UnIV2IndexSourceReserves memory indexSource;
        indexSource.pool = IUniswapV2Pair(address(ERC4626Repo._reserveAsset()));

        // Load reserves and vault state.
        _loadIndexSourceReserves(indexSource, tokenIn);
        UniV2StrategyVault memory vault;
        _loadStrategyVault(vault, tokenIn);
        // Mint vault fee shares (matches the In side's _calcAndMintVaultFee call).
        _calcAndMintVaultFee(indexSource, vault);

        // Step 1: ERC-4626 inverse (post-deposit accounting) — shares → LP.
        //
        // exchangeIn Route 6 computes shares as:
        //   shares = floor(lpReceived * (S + 10^d) / (R_before + lpReceived + 1))
        //
        // Solving for the minimum lpReceived:
        //   LP >= ceil(shares * (R_before + 1) / (S + 10^d - shares))
        //
        // Guard: amountOut must be < S + 10^d (otherwise denominator <= 0).
        uint256 decimalUnit = 10 ** ERC4626Repo._decimalOffset();
        require(amountOut < vault.vaultTotalShares + decimalUnit, "amountOut >= totalShares + decimalUnit");
        uint256 lpTarget;
        {
            uint256 numerator = amountOut * (vault.vaultLpReserve + 1);
            uint256 denominator = vault.vaultTotalShares + decimalUnit - amountOut;
            lpTarget = numerator / denominator;
            if (numerator % denominator != 0) {
                lpTarget += 1;
            }
        }

        // Step 2: ZapIn inverse — LP target → amountIn of tokenIn.
        amountIn = ConstProdUtils._quoteZapInToTargetLPWithFee(
            // uint256 targetLP,
            lpTarget,
            // uint256 lpTotalSupply,
            indexSource.totalSupply,
            // uint256 reserveIn,
            indexSource.knownReserve,
            // uint256 reserveOut,
            indexSource.opposingReserve,
            // uint256 feePercent,
            indexSource.knownfeePercent,
            // uint256 feeDenominator,
            UNISWAPV2_FEE_DENOMINATOR,
            // uint256 kLast,
            indexSource.kLast,
            // uint256 ownerFeeShare,
            UNISWAPV2_PROTOCOL_FEE_SHARE,
            // bool feeOn
            UniswapV2FactoryAwareRepo._uniswapV2Factory().feeTo() != address(0)
        );

        // Slippage guard.
        if (amountIn > maxAmountIn) {
            revert MaxAmountExceeded(maxAmountIn, amountIn);
        }

        // Secure tokenIn from the caller.
        amountIn = _secureTokenTransfer(tokenIn, amountIn, pretransferred);

        // Execute the ZapIn: swap + deposit, collecting LP tokens.
        uint256 lpReceived = UniswapV2RouterAwareRepo._uniswapV2Router()
            ._swapDeposit(
                // IUniswapV2Router router,
                // IUniswapV2Pair pool,
                indexSource.pool,
                // IERC20 tokenIn,
                tokenIn,
                // uint256 saleAmt,
                amountIn,
                // IERC20 opToken,
                IERC20(ConstProdReserveVaultRepo._opposingToken(address(tokenIn)))
            );

        // Update vault LP reserve.
        vault.vaultLpReserve = indexSource.pool.balanceOf(address(this));
        ERC4626Repo._setLastTotalAssets(vault.vaultLpReserve);

        // Update owned reserve tracking (mirrors the In-side exchangeIn Route 6).
        (uint256 ownedReserve0, uint256 ownedReserve1) = ConstProdUtils._quoteWithdrawWithFee(
            // uint256 ownedLPAmount,
            vault.vaultLpReserve,
            // uint256 lpTotalSupply,
            indexSource.totalSupply,
            // uint256 totalReserveA,
            indexSource.knownReserve,
            // uint256 totalReserveB,
            indexSource.opposingReserve,
            // uint256 kLast,
            indexSource.kLast,
            // uint256 ownerFeeShare,
            UNISWAPV2_PROTOCOL_FEE_SHARE,
            // bool feeOn
            UniswapV2FactoryAwareRepo._uniswapV2Factory().feeTo() != address(0)
        );
        ConstProdReserveVaultRepo._setYieldReserveOfToken(address(indexSource.token0), ownedReserve0);
        ConstProdReserveVaultRepo._setYieldReserveOfToken(address(indexSource.token1), ownedReserve1);

        // Convert actual LP received → shares (floor, matching exchangeIn behaviour).
        uint256 actualShares = BetterMath._convertToSharesDown(
            // uint256 assets,
            lpReceived,
            // uint256 reserve,
            vault.vaultLpReserve,
            // uint256 totalShares
            vault.vaultTotalShares,
            ERC4626Repo._decimalOffset()
        );

        // Guard: actual shares must be at least the requested amountOut.
        if (actualShares < amountOut) revert AmountOutNotMet(amountOut, actualShares);

        // Mint exactly the requested amountOut to the recipient (not actualShares — the caller
        // specified a target; any rounding surplus stays in the vault, benefiting all holders).
        ERC20Repo._mint(recipient, amountOut);

        // Refund any excess pretransferred tokenIn.
        _refundExcess(tokenIn, maxAmountIn, amountIn, pretransferred, msg.sender);

        return amountIn;
    }
}
