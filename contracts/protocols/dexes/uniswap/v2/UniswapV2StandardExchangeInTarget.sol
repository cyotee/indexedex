// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {
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
import {UniswapV2RouterAwareRepo} from "@crane/contracts/protocols/dexes/uniswap/v2/aware/UniswapV2RouterAwareRepo.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IStandardExchangeIn} from "contracts/interfaces/IStandardExchangeIn.sol";
import {ConstProdReserveVaultRepo} from "contracts/vaults/ConstProdReserveVaultRepo.sol";
import {VaultFeeOracleQueryAwareRepo} from "contracts/oracles/fee/VaultFeeOracleQueryAwareRepo.sol";
import {
    UniswapV2StandardExchangeCommon
} from "contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeCommon.sol";

// abstract
contract UniswapV2StandardExchangeInTarget is
    UniswapV2StandardExchangeCommon,
    ReentrancyLockModifiers,
    IStandardExchangeIn
{
    using SafeERC20 for IERC20;
    using UniswapV2Service for IUniswapV2Router;
    using UniswapV2Service for IUniswapV2Pair;

    /* ------------------------- IStandardExchangeIn ------------------------ */

    function previewExchangeIn(IERC20 tokenIn, uint256 amountIn, IERC20 tokenOut)
        external
        view
        returns (uint256 amountOut)
    {
        // Determine actual token route from provided tokens.
        // Intended supported routes.
        // 1. Pass-through Swap - Swap of token contained in the underlying pool for the opposing token contained in the underlying pool.
        // 2. Pass-through ZapIn - Deposit as ZapIn of token contained in the underlying pool for the underlying pool token.
        // 3. Underlying Pool Vault Deposit - Deposit of the underlying pool token into the vault.
        // 4. ZapIn Vault Deposit - Deposit as ZapIn of the token contained in the underlying pool for the underlying pool token into the vault.
        // 5. Underlying Pool Vault Withdrawal - Withdraw of the underlying pool token from the vault.
        // 6. Pass-through ZapOut - Withdraw as ZapOut of token contained in the underlying pool from the underlying pool as tokenIn.
        // 7. ZapOut Vault Withdrawal - Withdraw as ZapOut of token contained in the underlying pool from the underlying pool token from the vault.

        ConstProdReserveVaultRepo.Storage storage constProd = ConstProdReserveVaultRepo._layout();

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
            IUniswapV2Pair pool = IUniswapV2Pair(address(ERC4626Repo._reserveAsset()));
            (uint256 reserveIn, uint256 reserveOut,) = pool.getReserves();
            (reserveIn, reserveOut) = ConstProdUtils._sortReserves(
                address(tokenIn), ConstProdReserveVaultRepo._token0(), reserveIn, reserveOut
            );
            return ConstProdUtils._saleQuote(
                // uint256 amountIn,
                amountIn,
                // uint256 reserveIn,
                reserveIn,
                // uint256 reserveOut,
                reserveOut,
                // uint256 saleFeePercent
                300
            );
        }

        UnIV2IndexSourceReserves memory indexSource;

        indexSource.pool = IUniswapV2Pair(address(ERC4626Repo._reserveAsset()));

        /* ------------------------------------------------------------------ */
        /*                         Pass-through ZapIn                         */
        /* ------------------------------------------------------------------ */

        if (
            ConstProdReserveVaultRepo._isReserveAssetContained(constProd, address(tokenIn))
                && address(tokenOut) == address(indexSource.pool)
        ) {
            // Load the index source data.
            // Loads the underlying pool token, token 0, and token 1.
            // Also loads the reserves of the known token and the opposing token.
            // Also loads the fee percent of the known token and the opposing token.
            // Sorts the reserves of the known token and the opposing token.
            _loadIndexSourceReserves(indexSource, tokenIn);
            amountOut = ConstProdUtils._quoteSwapDepositWithFee(
                // uint256 amountIn,
                amountIn,
                // uint256 lpTotalSupply,
                indexSource.totalSupply,
                // uint256 reserveIn,
                indexSource.knownReserve,
                // uint256 reserveOut,
                indexSource.opposingReserve,
                // uint256 feePercent,
                indexSource.knownfeePercent,
                // uint256 kLast,
                indexSource.kLast,
                // uint256 ownerFeeShare,
                UNISWAPV2_PROTOCOL_FEE_SHARE,
                // bool feeOn
                UniswapV2FactoryAwareRepo._uniswapV2Factory().feeTo() != address(0)
            );
            return amountOut;
        }

        // indexSource.pool = IUniswapV2Pair(address(ERC4626Repo._reserveAsset()));

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
            // Calculate the amount out from a withdraw/swap (ZapOut).
            // Done through the underlying pool for amountIn.
            amountOut = UniswapV2Utils._quoteWithdrawSwapFee(
                // uint256 ownedLPAmount,
                amountIn,
                // uint256 lpTotalSupply,
                indexSource.totalSupply,
                // uint256 reserveA,
                indexSource.knownReserve,
                // uint256 reserveB,
                indexSource.opposingReserve,
                // uint256 feePercent,
                indexSource.opTokenFeePercent,
                // uint256 feeDenominator,
                UNISWAPV2_FEE_DENOMINATOR,
                // uint256 kLast,
                indexSource.kLast,
                // bool feeOn
                UniswapV2FactoryAwareRepo._uniswapV2Factory().feeTo() != address(0)
            );
            return amountOut;
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
            // `exchangeIn` computes shares against the post-deposit reserve.
            // Mirror that here so preview matches execution.
            uint256 reserveAfter = vault.vaultLpReserve + amountIn;
            // Calculate the shares received for a deposit of the underlying pool token for amountIn.
            amountOut = BetterMath._convertToSharesDown(
                amountIn, reserveAfter, vault.vaultTotalShares, ERC4626Repo._decimalOffset()
            );
            return amountOut;
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
            // Convert the underlying pool tokens due for withdrawal of amountIn.
            amountOut = BetterMath._convertToAssetsDown(
                amountIn, vault.vaultLpReserve, vault.vaultTotalShares, ERC4626Repo._decimalOffset()
            );
            return amountOut;
        }

        /* ------------------------------------------------------------------ */
        /*                         ZapIn Vault Deposit                        */
        /* ------------------------------------------------------------------ */

        if (
            ConstProdReserveVaultRepo._isReserveAssetContained(constProd, address(tokenIn))
                && address(tokenOut) == address(this)
        ) {
            // Load the index source data.
            // Loads the underlying pool token, token 0, and token 1.
            // Also loads the reserves of the known token and the opposing token.
            // Also loads the fee percent of the known token and the opposing token.
            // Sorts the reserves of the known token and the opposing token.
            // Pass IERC20(address(0)) as the known token force token0 to be the known token.
            _loadIndexSourceReserves(indexSource, tokenIn);
            // Load the strategy vault data.
            // Loads the vault LP reserve, vault total shares.
            // Also loads the known token last owned source reserve.
            // Also loads the opposing token last owned source reserve.
            // Also stores the fee shares.
            UniV2StrategyVault memory vault;
            _loadStrategyVault(vault, tokenIn);
            // Calculates the vault fee.
            // Will add fee shares to vault.vaultTotalShares.
            _calcVaultFee(indexSource, vault);
            // Calculate the LP tokens received for a swap/deposit (ZapIn) of tokenIn for amountIn.
            amountIn = ConstProdUtils._quoteSwapDepositWithFee(
                // uint256 amountIn,
                amountIn,
                // uint256 lpTotalSupply,
                indexSource.totalSupply,
                // uint256 reserveIn,
                indexSource.knownReserve,
                // uint256 reserveOut,
                indexSource.opposingReserve,
                // uint256 feePercent,
                indexSource.knownfeePercent,
                // uint256 kLast,
                indexSource.kLast,
                // uint256 ownerFeeShare,
                UNISWAPV2_PROTOCOL_FEE_SHARE,
                // bool feeOn
                UniswapV2FactoryAwareRepo._uniswapV2Factory().feeTo() != address(0)
            );
            // `exchangeIn` computes shares against the post-deposit reserve.
            // Mirror that here so preview matches execution.
            uint256 reserveAfter = vault.vaultLpReserve + amountIn;
            // Calculate the shares minted for the LP tokens from the swap/deposit.
            amountOut = BetterMath._convertToSharesDown(
                amountIn, reserveAfter, vault.vaultTotalShares, ERC4626Repo._decimalOffset()
            );
            // console.log("UniswapV2StandardExchangeInFacet::previewExchangeIn: amountOut", amountOut);
            return amountOut;
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
            // Calculate the underlying pool tokens due for withdrawal of amountIn.
            amountIn = BetterMath._convertToAssetsDown(
                amountIn, vault.vaultLpReserve, vault.vaultTotalShares, ERC4626Repo._decimalOffset()
            );
            // Calculate the tokens out for a withdraw/swap (ZapOut).
            // Done through the underlying pool for amountIn.
            return UniswapV2Utils._quoteWithdrawSwapFee(
                // uint256 ownedLPAmount,
                amountIn,
                // uint256 lpTotalSupply,
                indexSource.totalSupply,
                // uint256 reserveA,
                indexSource.knownReserve,
                // uint256 reserveB,
                indexSource.opposingReserve,
                // uint256 feePercent,
                indexSource.opTokenFeePercent,
                // uint256 feeDenominator,
                UNISWAPV2_FEE_DENOMINATOR,
                // uint256 kLast,
                indexSource.kLast,
                // bool feeOn
                UniswapV2FactoryAwareRepo._uniswapV2Factory().feeTo() != address(0)
            );
        }

        revert InvalidRoute(address(tokenIn), address(tokenOut));
    }

    // tag::exchangeIn[]
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

        ConstProdReserveVaultRepo.Storage storage constProd = ConstProdReserveVaultRepo._layout();

        /* ------------------------------------------------------------------ */
        /*                          Pass-through Swap                         */
        /* ------------------------------------------------------------------ */

        if (
            ConstProdReserveVaultRepo._isReserveAssetContained(constProd, address(tokenIn))
                && ConstProdReserveVaultRepo._isReserveAssetContained(constProd, address(tokenOut))
        ) {
            // If this is a swap to pass-through to the underlying pool,
            // we need to secure the payment of the tokenIn.
            amountIn = _secureTokenTransfer(
                // IERC20 tokenIn,
                tokenIn,
                // uint256 amountTokenToDeposit,
                amountIn,
                // bool pretransferred
                pretransferred
            );
            uint256 result = UniswapV2RouterAwareRepo._uniswapV2Router()
                ._swapExactTokensForTokens(
                    // IUniswapV2Router router,
                    // IERC20 tokenIn,
                    tokenIn,
                    // uint256 amountIn,
                    amountIn,
                    // IERC20 tokenOut,
                    tokenOut,
                    // uint256 minAmountOut,
                    minAmountOut,
                    // address recipient
                    recipient
                );
            return result;
        }

        UnIV2IndexSourceReserves memory indexSource;
        indexSource.pool = IUniswapV2Pair(address(ERC4626Repo._reserveAsset()));

        /* ------------------------------------------------------------------ */
        /*                         Pass-through ZapIn                         */
        /* ------------------------------------------------------------------ */

        if (
            ConstProdReserveVaultRepo._isReserveAssetContained(constProd, address(tokenIn))
                && address(tokenOut) == address(indexSource.pool)
        ) {
            // Secure token to vault control.
            amountIn = _secureTokenTransfer(
                // IERC20 tokenIn,
                tokenIn,
                // uint256 amountTokenToDeposit,
                amountIn,
                // bool pretransferred
                pretransferred
            );
            // Execute the swap/deposit (ZapIn).
            amountOut = UniswapV2RouterAwareRepo._uniswapV2Router()
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
            if (amountOut < minAmountOut) revert MinAmountNotMet(minAmountOut, amountOut);
            // Transfer the underlying pool token from the swap/deposit to the recipient.
            IERC20(address(indexSource.pool))
                .safeTransfer(
                    // IERC20 token,
                    recipient,
                    // uint256 amount
                    amountOut
                );
            // No reserve change, so no updated needed.
            // But we do receive and send pool tokens, so we must verify the reserve still matches the held balance.
            // Check that local balance of the pool token still matches the stored reserve.
            {
                uint256 poolBalance = indexSource.pool.balanceOf(address(this));
                uint256 storedReserve = ERC4626Repo._lastTotalAssets();
                if (poolBalance != storedReserve) {
                    revert();
                }
            }
            // Go ahead and terminate further execution.
            return amountOut;
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
            // Secure the pool token to vault control.
            amountIn = _secureTokenTransfer(
                // IERC20 tokenIn,
                tokenIn,
                // uint256 amountTokenToDeposit,
                amountIn,
                // bool pretransferred
                pretransferred
            );
            // Execute the withdraw/swap (ZapOut).
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
            if (amountOut < minAmountOut) revert MinAmountNotMet(minAmountOut, amountOut);
            // Transfer the tokenOut to the recipient.
            IERC20(address(tokenOut))
                .safeTransfer(
                    // IERC20 token,
                    // address to,
                    recipient,
                    // uint256 amount
                    amountOut
                );
            // No reserve change, so no updated needed.
            // But we do received and sen pool tokens, so we must verify the reserve still matches the held balance.
            // Check that local balance of the pool token still matches the stored reserve.
            uint256 poolBalance = indexSource.pool.balanceOf(address(this));
            uint256 storedReserve = ERC4626Repo._lastTotalAssets();
            if (poolBalance != storedReserve) {
                revert();
            }
            // Go ahead and terminate furtherRecordedVote.
            return amountOut;
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
            _calcAndMintVaultFee(indexSource, vault);
            // Mint the shares to the protocol.
            // Use the total share overload to save gas on loading the total supply.
            // ERC20Repo._mint(
            //     // address account,
            //     VaultFeeOralceQueryAwareRepo._feeOracle().feeTo(),
            //     // uint256 amount,
            //     vault.feeShares
            // );
            // Secure the pool token to vault control.
            amountIn = ERC4626Service._secureReserveDeposit(
                ERC4626Repo._layout(),
                vault.vaultLpReserve,
                // uint256 amountTokenToDeposit,
                amountIn
            );
            // Reserve does change, so we're updating the stored reserve value.
            // Update the reserve of the underlying pool token.
            vault.vaultLpReserve = indexSource.pool.balanceOf(address(this));
            ERC4626Repo._setLastTotalAssets(
                // uint256 amount
                vault.vaultLpReserve
            );
            // Calculated the owned reserves of the LP token reserves.
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
            // Store the owned reserves for yield tracking.
            ConstProdReserveVaultRepo._setYieldReserveOfToken(address(indexSource.token0), ownedReserve0);
            ConstProdReserveVaultRepo._setYieldReserveOfToken(address(indexSource.token1), ownedReserve1);
            // Calculate the shares to mint for the secured amountIn.
            amountOut = BetterMath._convertToSharesDown(
                // uint256 assets,
                amountIn,
                // uint256 reserve,
                vault.vaultLpReserve,
                // uint256 totalShares
                vault.vaultTotalShares,
                ERC4626Repo._decimalOffset()
            );
            if (amountOut < minAmountOut) {
                revert MinAmountNotMet(minAmountOut, amountOut);
            }
            // Mint the shares to the recipient.
            ERC20Repo._mint(
                // address account,
                recipient,
                // uint256 amount,
                amountOut
            );
            // Go ahead and terminate furtherRecordedVote.
            return amountOut;
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
            _calcAndMintVaultFee(indexSource, vault);
            // Mint the shares to the protocol.
            // ERC20Repo._mint(
            //     // address account,
            //     VaultFeeOralceQueryAwareRepo._feeOracle().feeTo(),
            //     // uint256 amount,
            //     vault.feeShares
            // );
            // Secure the burn of vault shares.
            _secureSelfBurn(
                // address owner,
                msg.sender,
                // uint256 burnAmount,
                amountIn,
                // bool preTransferred
                pretransferred
            );
            // Convert the shares to assets.
            amountOut = BetterMath._convertToAssetsDown(
                // uint256 shares,
                amountIn,
                // uint256 reserve,
                vault.vaultLpReserve,
                // uint256 totalShares
                vault.vaultTotalShares,
                ERC4626Repo._decimalOffset()
            );
            if (amountOut < minAmountOut) revert MinAmountNotMet(minAmountOut, amountOut);
            // Transfer the assets to the recipient.
            IERC20(address(indexSource.pool))
                .safeTransfer(
                    // IERC20 token,
                    // address to,
                    recipient,
                    // uint256 amount
                    amountOut
                );
            // Reserve does change, so we're updating the stored reserve value.
            // Update the reserve of the underlying pool token.
            vault.vaultLpReserve = indexSource.pool.balanceOf(address(this));
            ERC4626Repo._setLastTotalAssets(
                // uint256 amount
                vault.vaultLpReserve
            );
            // Calculated the owned reserves of the LP token reserves.
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
            // Store the owned reserves for yield tracking.
            // _setYieldReserveOfToken(address(indexSource.token0), ownedReserve0);
            // _setYieldReserveOfToken(address(indexSource.token1), ownedReserve1);
            ConstProdReserveVaultRepo._setYieldReserveOfToken(address(indexSource.token0), ownedReserve0);
            ConstProdReserveVaultRepo._setYieldReserveOfToken(address(indexSource.token1), ownedReserve1);
            return amountOut;
        }

        /* ------------------------------------------------------------------ */
        /*                         ZapIn Vault Deposit                        */
        /* ------------------------------------------------------------------ */

        if (
            ConstProdReserveVaultRepo._isReserveAssetContained(constProd, address(tokenIn))
                && address(tokenOut) == address(this)
        ) {
            // Load the index source data.
            // Loads the underlying pool token, token 0, and token 1.
            // Also loads the reserves of the known token and the opposing token.
            // Also loads the fee percent of the known token and the opposing token.
            // Sorts the reserves of the known token and the opposing token.
            _loadIndexSourceReserves(indexSource, tokenIn);
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
            _loadStrategyVault(vault, tokenIn);
            // Calculates the vault fee.
            // Will add fee shares to vault.vaultTotalShares.
            _calcAndMintVaultFee(indexSource, vault);
            // Mint the shares to the protocol.
            // ERC20Repo._mint(
            //     // address account,
            //     VaultFeeOralceQueryAwareRepo._feeOracle().feeTo(),
            //     // uint256 amount,
            //     vault.feeShares
            // );
            // Secure the tokenIn to vault control.
            amountIn = _secureTokenTransfer(
                // IERC20 tokenIn,
                tokenIn,
                // uint256 amountTokenToDeposit,
                amountIn,
                // bool pretransferred
                pretransferred
            );
            // Execute the swap/deposit (ZapIn).
            amountIn = UniswapV2RouterAwareRepo._uniswapV2Router()
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
            // Reserve does change, so we're updating the stored reserve value.
            // Update the reserve of the underlying pool token.
            vault.vaultLpReserve = indexSource.pool.balanceOf(address(this));
            ERC4626Repo._setLastTotalAssets(
                // uint256 amount
                vault.vaultLpReserve
            );
            // Calculated the owned reserves of the LP token reserves.
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
            // Store the owned reserves for yield tracking.
            // _setYieldReserveOfToken(address(indexSource.token0), ownedReserve0);
            // _setYieldReserveOfToken(address(indexSource.token1), ownedReserve1);
            ConstProdReserveVaultRepo._setYieldReserveOfToken(address(indexSource.token0), ownedReserve0);
            ConstProdReserveVaultRepo._setYieldReserveOfToken(address(indexSource.token1), ownedReserve1);
            // Calculate the shares to mint for the secured amountIn.
            amountOut = BetterMath._convertToSharesDown(
                // uint256 assets,
                amountIn,
                // uint256 reserve,
                vault.vaultLpReserve,
                // uint256 totalShares
                vault.vaultTotalShares,
                ERC4626Repo._decimalOffset()
            );
            if (amountOut < minAmountOut) {
                revert MinAmountNotMet(minAmountOut, amountOut);
            }
            // Mint the shares to the recipient.
            ERC20Repo._mint(
                // address account,
                recipient,
                // uint256 amount,
                amountOut
            );
            return amountOut;
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
            _loadStrategyVault(vault, IERC20(tokenOut));
            // Calculates the vault fee.
            // Will add fee shares to vault.vaultTotalShares.
            _calcAndMintVaultFee(indexSource, vault);
            // Mint the shares to the protocol.
            // ERC20Repo._mint(
            //     // address account,
            //     VaultFeeOralceQueryAwareRepo._feeOracle().feeTo(),
            //     // uint256 amount,
            //     vault.feeShares
            // );

            // Secure the burn of vault shares.
            _secureSelfBurn(
                // address owner,
                msg.sender,
                // uint256 burnAmount,
                amountIn,
                // bool preTransferred
                pretransferred
            );
            // Convert the shares to assets.
            amountIn = BetterMath._convertToAssetsDown(
                // uint256 shares,
                amountIn,
                // uint256 reserve,
                vault.vaultLpReserve,
                // uint256 totalShares
                vault.vaultTotalShares,
                ERC4626Repo._decimalOffset()
            );
            // Execute the withdraw/swap (ZapOut).
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
                    // IERC20(_opposingToken(address(tokenOut)))
                    IERC20(ConstProdReserveVaultRepo._opposingToken(address(tokenOut)))
                );
            if (amountOut < minAmountOut) revert MinAmountNotMet(minAmountOut, amountOut);
            // Transfer the underlying pool token to the recipient.
            IERC20(address(tokenOut))
                .safeTransfer(
                    // IERC20 token,
                    // address to,
                    recipient,
                    // uint256 amount
                    amountOut
                );
            // Reserve does change, so we're updating the stored reserve value.
            // Update the reserve of the underlying pool token.
            vault.vaultLpReserve = indexSource.pool.balanceOf(address(this));
            ERC4626Repo._setLastTotalAssets(
                // uint256 amount
                vault.vaultLpReserve
            );
            // Calculated the owned reserves of the LP token reserves.
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
            // Store the owned reserves for yield tracking.
            // _setYieldReserveOfToken(address(indexSource.token0), ownedReserve0);
            // _setYieldReserveOfToken(address(indexSource.token1), ownedReserve1);
            ConstProdReserveVaultRepo._setYieldReserveOfToken(address(indexSource.token0), ownedReserve0);
            ConstProdReserveVaultRepo._setYieldReserveOfToken(address(indexSource.token1), ownedReserve1);
            // Go ahead and terminate further execution.
            return amountOut;
        }

        revert InvalidRoute(address(tokenIn), address(tokenOut));
    }
    // end::exchangeIn[]
}
