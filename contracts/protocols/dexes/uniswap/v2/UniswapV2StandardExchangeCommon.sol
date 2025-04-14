// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {ONE_WAD, UNISWAP_PROTOCOL_FEE_SHARE} from "@crane/contracts/constants/Constants.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IUniswapV2Pair} from "@crane/contracts/interfaces/protocols/dexes/uniswap/v2/IUniswapV2Pair.sol";
import {IUniswapV2Router} from "@crane/contracts/interfaces/protocols/dexes/uniswap/v2/IUniswapV2Router.sol";
import {UniswapV2Service} from "@crane/contracts/protocols/dexes/uniswap/v2/services/UniswapV2Service.sol";
import {BetterSafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {ERC4626Repo} from "@crane/contracts/tokens/ERC4626/ERC4626Repo.sol";
import {Permit2AwareRepo} from "@crane/contracts/protocols/utils/permit2/aware/Permit2AwareRepo.sol";
import {
    UniswapV2FactoryAwareRepo
} from "@crane/contracts/protocols/dexes/uniswap/v2/aware/UniswapV2FactoryAwareRepo.sol";
import {BetterMath} from "@crane/contracts/utils/math/BetterMath.sol";
import {ConstProdUtils} from "@crane/contracts/utils/math/ConstProdUtils.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {ConstProdReserveVaultRepo} from "contracts/vaults/ConstProdReserveVaultRepo.sol";
import {VaultFeeOracleQueryAwareRepo} from "contracts/oracles/fee/VaultFeeOracleQueryAwareRepo.sol";
import {BasicVaultCommon} from "contracts/vaults/basic/BasicVaultCommon.sol";

// abstract
contract UniswapV2StandardExchangeCommon is BasicVaultCommon {
    using ERC20Repo for ERC20Repo.Storage;
    using BetterSafeERC20 for IERC20;
    using ERC4626Repo for ERC4626Repo.Storage;
    using ConstProdReserveVaultRepo for ConstProdReserveVaultRepo.Storage;

    struct UnIV2IndexSourceReserves {
        IUniswapV2Pair pool;
        address token0;
        address token1;
        uint256 knownReserve;
        uint256 opposingReserve;
        uint256 knownfeePercent;
        uint256 opTokenFeePercent;
        uint256 totalSupply;
        uint256 kLast;
    }

    struct UniV2StrategyVault {
        uint256 vaultLpReserve;
        uint256 vaultTotalShares;
        uint256 knownTokenLastOwnedSourceReserve;
        uint256 opTokenLastOwnedSourceReserve;
        uint256 feeShares;
    }

    function _loadIndexSourceReserves(UnIV2IndexSourceReserves memory indexSource, IERC20 knownToken) internal view {
        // indexSource.pool = IUniswapV2Pair(address(ERC4626Repo._reserveAsset()));
        ConstProdReserveVaultRepo.Storage storage constProd = ConstProdReserveVaultRepo._layout();
        indexSource.token0 = constProd._token0();
        indexSource.token1 = constProd._token1();
        indexSource.totalSupply = indexSource.pool.totalSupply();
        indexSource.kLast = indexSource.pool.kLast();
        (uint112 reserve0, uint112 reserve1,) = indexSource.pool.getReserves();
        (
            indexSource.knownReserve,
            indexSource.opposingReserve,
            indexSource.knownfeePercent,
            indexSource.opTokenFeePercent
        ) =
            UniswapV2Service._sortReserves(
                address(knownToken) == address(0) ? IERC20(indexSource.token0) : knownToken,
                indexSource.token0,
                reserve0,
                reserve1
            );
    }

    function _loadStrategyVault(
        UniV2StrategyVault memory vault,
        // UnIV2IndexSourceReserves memory indexSource,
        IERC20 knownToken
    )
        internal
        view
    {
        vault.vaultLpReserve = ERC4626Repo._lastTotalAssets();
        vault.vaultTotalShares = ERC20Repo._totalSupply();
        ConstProdReserveVaultRepo.Storage storage constProd = ConstProdReserveVaultRepo._layout();
        vault.knownTokenLastOwnedSourceReserve = constProd._yieldReserveOfToken(address(knownToken));
        vault.opTokenLastOwnedSourceReserve =
            constProd._yieldReserveOfToken(constProd._opposingToken(address(knownToken)));
        vault.knownTokenLastOwnedSourceReserve = constProd._yieldReserveOfToken(address(knownToken));
        vault.opTokenLastOwnedSourceReserve =
            constProd._yieldReserveOfToken(constProd._opposingToken(address(knownToken)));
    }

    function _calcVaultFee(UnIV2IndexSourceReserves memory indexSource, UniV2StrategyVault memory vault) internal view {
        (uint256 knownTokenFeeYield, uint256 opTokenFeeYield) = ConstProdUtils._calculateFeePortionForPosition(
            // uint256 ownedLP,
            vault.vaultLpReserve,
            // uint256 initialA,
            vault.knownTokenLastOwnedSourceReserve,
            // uint256 initialB,
            vault.opTokenLastOwnedSourceReserve,
            // uint256 reserveA,
            indexSource.knownReserve,
            // uint256 reserveB,
            indexSource.opposingReserve,
            // uint256 totalSupply
            indexSource.totalSupply
        );
        uint256 feeShareLPEquiv = ConstProdUtils._quoteDepositWithFee(
            // uint256 amountADeposit,
            knownTokenFeeYield,
            // uint256 amountBDeposit,
            opTokenFeeYield,
            // uint256 lpTotalSupply,
            indexSource.totalSupply,
            // uint256 lpReserveA,
            vault.knownTokenLastOwnedSourceReserve,
            // uint256 lpReserveB,
            vault.opTokenLastOwnedSourceReserve,
            // uint256 kLast,
            indexSource.kLast,
            // uint256 ownerFeeShare,
            UNISWAP_PROTOCOL_FEE_SHARE,
            // bool feeOn
            UniswapV2FactoryAwareRepo._uniswapV2Factory().feeTo() != address(0)
        );
        feeShareLPEquiv = BetterMath._percentageOfWAD(
            // uint256 total,
            feeShareLPEquiv,
            // uint256 percentage,
            VaultFeeOracleQueryAwareRepo._feeOracle().usageFeeOfVault(address(this))
        );

        vault.feeShares = BetterMath._convertToSharesDown(
            feeShareLPEquiv, vault.vaultLpReserve, vault.vaultTotalShares, ERC4626Repo._decimalOffset()
        );
        vault.vaultTotalShares += vault.feeShares;
    }

    function _calcAndMintVaultFee(
        UnIV2IndexSourceReserves memory indexSource,
        // UniV2IndexSupply memory indexSupply,
        UniV2StrategyVault memory vault
    )
        internal
    {
        _calcVaultFee(
            // UnIV2IndexSourceReserves memory indexSource,
            indexSource,
            // UniV2IndexSupply memory indexSupply,
            // indexSupply,
            // UniV2StrategyVault memory vault
            vault
        );
        ERC20Repo._mint(
            // address account,
            address(VaultFeeOracleQueryAwareRepo._feeOracle().feeTo()),
            // uint256 amount,
            vault.feeShares
        );
    }

    /* ---------------------------------------------------------------------- */

    struct UniV2Strategy {
        IUniswapV2Router router;
        IUniswapV2Pair pool;
        uint256 poolReserve;
        uint256 totalShares;
        uint256 poolTotalSupply;
        uint256 knownTokenPoolReserve;
        uint256 opTokenPoolReserve;
        uint256 protocolFee;
        uint256 protFeeDenom;
        IERC20 tokenIn;
        IERC20 tokenOut;
        uint256 knownTokenYieldLastOwnedReserve;
        uint256 opTokenYieldLastOwnedReserve;
    }

    function _calculateVaultFee(UniV2Strategy memory strategy, UniswapV2Service.ReserveInfo memory reserves)
        internal
        view
        returns (uint256 feeShares)
    {
        // console.log("UniswapV2StandardStrategyVaultStorage::_calculateVaultFee entering function.");
        (uint256 knownTokenYield, uint256 opTokenYield) = ConstProdUtils._calculateFeePortionForPosition(
            // uint256 ownedLP,
            strategy.poolReserve,
            // uint256 initialA,
            strategy.knownTokenYieldLastOwnedReserve,
            // uint256 initialB,
            strategy.opTokenYieldLastOwnedReserve,
            // uint256 reserveA,
            reserves.knownReserve,
            // uint256 reserveB,
            reserves.opposingReserve,
            // uint256 totalSupply
            strategy.poolTotalSupply
        );
        uint256 feeLP = ConstProdUtils._depositQuote(
            // uint256 amountADeposit,
            knownTokenYield,
            // uint256 amountBDeposit,
            opTokenYield,
            // uint256 lpTotalSupply,
            strategy.poolTotalSupply,
            // uint256 lpReserveA,
            reserves.knownReserve,
            // uint256 lpReserveB
            reserves.opposingReserve
        );
        feeLP = BetterMath._percentageOfWAD(
            feeLP, VaultFeeOracleQueryAwareRepo._feeOracle().usageFeeOfVault(address(this))
        );
        feeShares = BetterMath._convertToSharesDown(
            feeLP, strategy.poolReserve, strategy.totalShares, ERC4626Repo._decimalOffset()
        );
        // strategy.totalShares += feeShares;
        // console.log("UniswapV2StandardStrategyVaultStorage::_calculateVaultFee exiting function.");
        return feeShares;
    }

    // /**
    //  * @dev Calculate vault fees without minting them (for preview functions)
    //  * @param reserveA Current reserve of token A in the yield token
    //  * @param reserveB Current reserve of token B in the yield token
    //  * @param totalSupply Current total supply of vault tokens
    //  * @return feeShares Amount of vault shares that would be minted as fees
    //  */
    // function _calculateVaultFeePreview(uint256 reserveA, uint256 reserveB, uint256 totalSupply)
    //     internal
    //     view
    //     returns (uint256 feeShares)
    // {
    //     // Get current vault LP balance
    //     /// forge-lint: disable-next-line(mixed-case-variable)
    //     uint256 currentLPBalance = _pool().balanceOf(address(this));

    //     // Calculate current liquidity value using withdrawal quote
    //     uint256 currentLiquidityValue = _calculateLiquidityValue(currentLPBalance, reserveA, reserveB);

    //     // Get last recorded liquidity value
    //     uint256 lastLiquidityValue = _summedOwnedYieldTokenReserves();
    //     uint256 lastTotalSupply = _constantProductStandardStrategyVault().yieldTokenLastTotalSupply;

    //     // Check if this is the first operation (no previous state data)
    //     bool isFirstOperation = (lastLiquidityValue == 0 || lastTotalSupply == 0);

    //     if (!isFirstOperation && currentLiquidityValue > lastLiquidityValue) {
    //         // Calculate the actual yield earned by the vault
    //         uint256 yieldEarned = currentLiquidityValue - lastLiquidityValue;

    //         // Calculate fee shares based on actual yield
    //         feeShares = _calculateFeeSharesFromYield(yieldEarned, lastTotalSupply, totalSupply);
    //     }

    //     return feeShares;
    // }

    // /**
    //  * @dev Calculate and mint vault fees based on actual yield earned from LP position value growth
    //  * @param reserveA Current reserve of token A in the yield token
    //  * @param reserveB Current reserve of token B in the yield token
    //  * @param totalSupply Current total supply of vault tokens
    //  * @return feeShares Amount of vault shares minted as fees
    //  */
    // function _calculateAndMintVaultFee(uint256 reserveA, uint256 reserveB, uint256 totalSupply)
    //     internal
    //     returns (uint256 feeShares)
    // {
    //     // Get current vault LP balance
    //     /// forge-lint: disable-next-line(mixed-case-variable)
    //     uint256 currentLPBalance = _pool().balanceOf(address(this));

    //     // Calculate current liquidity value using withdrawal quote
    //     uint256 currentLiquidityValue = _calculateLiquidityValue(currentLPBalance, reserveA, reserveB);

    //     // Get last recorded liquidity value
    //     uint256 lastLiquidityValue = _summedOwnedYieldTokenReserves();
    //     uint256 lastTotalSupply = _constantProductStandardStrategyVault().yieldTokenLastTotalSupply;

    //     // Check if this is the first operation (no previous state data)
    //     bool isFirstOperation = (lastLiquidityValue == 0 || lastTotalSupply == 0);

    //     if (!isFirstOperation && currentLiquidityValue > lastLiquidityValue) {
    //         // Calculate the actual yield earned by the vault
    //         uint256 yieldEarned = currentLiquidityValue - lastLiquidityValue;

    //         // Calculate fee shares based on actual yield
    //         feeShares = _calculateFeeSharesFromYield(yieldEarned, lastTotalSupply, totalSupply);

    //         // Mint fee shares if any
    //         if (feeShares > 0) {
    //             IVaultRegistryFeeOracleQuery oracle = _feeOracle();
    //             address feeTo = oracle.feeTo();
    //             if (feeTo != address(0)) {
    //                 uint256 totalBefore = _totalSupply();

    //                 _mint(feeTo, feeShares);
    //                 // log post-mint total supply
    //                 uint256 totalAfter = _totalSupply();

    //                 _feeCollector().pushSingleTokenFee(OZIERC20(address(this)));
    //             }
    //         }
    //     }

    //     // Always update state for next calculation
    //     _updateOwnedSummedYieldTokenReserves(currentLiquidityValue);

    //     // Update yieldTokenLastTotalSupply for future fee calculations
    //     // This ensures the vault tracks the pool state for fee calculations
    //     _constantProductStandardStrategyVault().yieldTokenLastTotalSupply = _pool().totalSupply();

    //     return feeShares;
    // }

    // /**
    //  * @dev Calculate fee shares based on actual yield earned
    //  * @param yieldEarned The actual yield earned (increase in LP position value)
    //  * @param lastTotalSupply The total supply when last fee was calculated
    //  * @param currentTotalSupply The current total supply
    //  * @return feeShares The number of fee shares to mint
    //  */
    // function _calculateFeeSharesFromYield(uint256 yieldEarned, uint256 lastTotalSupply, uint256 currentTotalSupply)
    //     internal
    //     view
    //     returns (uint256 feeShares)
    // {
    //     if (yieldEarned == 0 || lastTotalSupply == 0) return 0;

    //     // Get vault fee percentage
    //     IVaultRegistryFeeOracleQuery oracle = _standardVault().feeOracle;
    //     uint256 vaultFee = oracle.usageFeeOfVault(address(this));

    //     // Calculate fee as percentage of yield
    //     uint256 feeAmount = (yieldEarned * vaultFee) / 1e6; // vaultFee is in PPM (parts per million)

    //     // Convert fee amount to fee shares
    //     // feeShares = (feeAmount * currentTotalSupply) / currentLiquidityValue
    //     // But we need to calculate this proportionally to avoid circular dependency
    //     /// forge-lint: disable-next-line(mixed-case-variable)
    //     uint256 currentLPBalance = _pool().balanceOf(address(this));
    //     (uint112 reserve0, uint112 reserve1,) = _pool().getReserves();
    //     uint256 currentLiquidityValue = _calculateLiquidityValue(currentLPBalance, uint256(reserve0), uint256(reserve1));

    //     if (currentLiquidityValue > 0) {
    //         feeShares = (feeAmount * currentTotalSupply) / currentLiquidityValue;
    //     }

    //     return feeShares;
    // }

    // /**
    //  * @dev Calculate the current value of the vault's LP position
    //  * @param lpBalance The vault's current LP token balance
    //  * @param reserve0 Current reserve of token0
    //  * @param reserve1 Current reserve of token1
    //  * @return totalValue The total value of the LP position
    //  */
    // function _calculateLiquidityValue(uint256 lpBalance, uint256 reserve0, uint256 reserve1)
    //     internal
    //     view
    //     returns (uint256 totalValue)
    // {
    //     if (lpBalance == 0) return 0;

    //     uint256 totalSupply = _pool().totalSupply();

    //     // Use ConstProdUtils to calculate token amounts
    //     (uint256 token0Amount, uint256 token1Amount) = ConstProdUtils._withdrawQuote(
    //         lpBalance, // LP tokens to withdraw
    //         totalSupply, // total LP supply
    //         reserve0, // reserve0
    //         reserve1 // reserve1
    //     );

    //     // Total value is sum of both tokens
    //     totalValue = token0Amount + token1Amount;

    //     return totalValue;
    // }

    // function _sortedYieldReserves(IUniswapV2Pair pool_, IERC20 tokenIn)
    //     internal
    //     view
    //     returns (uint256 reserveKnown, uint256 reserveUnknown)
    // {
    //     (uint256 reserve0, uint256 reserve1,) = pool_.getReserves();
    //     (reserveKnown, reserveUnknown) = ConstProdUtils._sortReserves(address(tokenIn), _token0(), reserve0, reserve1);
    // }
}
