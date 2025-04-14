// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                 Balancer V3                                */
/* -------------------------------------------------------------------------- */

import {IVault} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IVault.sol";
import {IBasePool} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IBasePool.sol";
import {IWeightedPool} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IWeightedPool.sol";
import {TokenInfo, Rounding} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/VaultTypes.sol";
import {FixedPoint} from "@crane/contracts/external/balancer/v3/solidity-utils/contracts/math/FixedPoint.sol";
import {WeightedMath} from "@crane/contracts/external/balancer/v3/solidity-utils/contracts/math/WeightedMath.sol";

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {ONE_WAD} from "@crane/contracts/constants/Constants.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {BetterSafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {ERC4626Repo} from "@crane/contracts/tokens/ERC4626/ERC4626Repo.sol";
import {ReentrancyLockModifiers} from "@crane/contracts/access/reentrancy/ReentrancyLockModifiers.sol";
import {
    BalancerV3VaultAwareRepo
} from "@crane/contracts/protocols/dexes/balancer/v3/vault/BalancerV3VaultAwareRepo.sol";

import {Math} from "@crane/contracts/utils/Math.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IStandardExchange} from "contracts/interfaces/IStandardExchange.sol";
import {ISeigniorageNFTVault} from "contracts/interfaces/ISeigniorageNFTVault.sol";
import {ISeigniorageDETF} from "contracts/interfaces/ISeigniorageDETF.sol";
import {ISeigniorageDETFErrors} from "contracts/interfaces/ISeigniorageDETFErrors.sol";
import {IStandardExchangeErrors} from "contracts/interfaces/IStandardExchangeErrors.sol";
import {
    IBalancerV3StandardExchangeRouterPrepay
} from "contracts/interfaces/IBalancerV3StandardExchangeRouterPrepay.sol";
import {BondTerms} from "contracts/interfaces/VaultFeeTypes.sol";
import {SeigniorageDETFRepo} from "contracts/vaults/seigniorage/SeigniorageDETFRepo.sol";
import {SeigniorageDETFCommon} from "contracts/vaults/seigniorage/SeigniorageDETFCommon.sol";
import {
    BalancerV38020WeightedPoolMath
} from "contracts/protocols/dexes/balancer/v3/utils/BalancerV38020WeightedPoolMath.sol";

/**
 * @title ISeigniorageDETFUnderwriting
 * @notice Interface for underwriting (bonding) operations on Seigniorage DETF.
 */
interface ISeigniorageDETFUnderwriting is ISeigniorageDETFErrors, IStandardExchangeErrors {
    /**
     * @notice Underwrites (bonds) tokens to receive an NFT position with boosted rewards.
     * @dev Deposits to the 80/20 Balancer pool and credits the user with BPT shares.
     * @param tokenIn Token to deposit (reserve vault constituent or reserve vault shares)
     * @param amountIn Amount to deposit
     * @param lockDuration Duration to lock the position in seconds
     * @param recipient Address to receive the NFT
     * @param pretransferred Whether tokens were already transferred to this contract
     * @return tokenId The minted NFT token ID
     */
    function underwrite(IERC20 tokenIn, uint256 amountIn, uint256 lockDuration, address recipient, bool pretransferred)
        external
        returns (uint256 tokenId);

    /**
     * @notice Previews the shares that would be awarded for an underwrite operation.
     * @param tokenIn Token to deposit
     * @param amountIn Amount to deposit
     * @param lockDuration Duration to lock
     * @return originalShares Base shares awarded (BPT amount)
     * @return effectiveShares Boosted shares (including time bonus)
     * @return bonusMultiplier The bonus multiplier applied (1e18 = 1x)
     */
    function previewUnderwrite(IERC20 tokenIn, uint256 amountIn, uint256 lockDuration)
        external
        view
        returns (uint256 originalShares, uint256 effectiveShares, uint256 bonusMultiplier);

    /**
     * @notice Redeems an NFT position after unlock, returning underlying tokens.
     * @param tokenId The NFT to redeem
     * @param recipient Address to receive the underlying tokens
     * @return amountOut Amount of rate target tokens returned
     */
    function redeem(uint256 tokenId, address recipient) external returns (uint256 amountOut);

    /**
     * @notice Previews the amount returned from redeeming an NFT.
     * @param tokenId The NFT to query
     * @return amountOut Amount of BPT shares that would be claimed
     */
    function previewRedeem(uint256 tokenId) external view returns (uint256 amountOut);

    /**
     * @notice Claims liquidity from the 80/20 pool (called by NFT vault on unlock).
     * @dev Removes liquidity proportionally, extracts reserve vault value as rate target,
     *      and redeposits RBT back to maintain pool balance.
     * @param lpAmount Amount of BPT (LP shares) to claim
     * @param recipient Address to receive the extracted value
     * @return extractedLiquidity Amount of rate target tokens sent to recipient
     */
    function claimLiquidity(uint256 lpAmount, address recipient) external returns (uint256 extractedLiquidity);
}

/**
 * @title SeigniorageDETFUnderwritingTarget
 * @author cyotee doge <not_cyotee@proton.me>
 * @notice Implementation of underwriting (bonding) operations for Seigniorage DETF.
 * @dev Users deposit reserve vault tokens, which are added to the 80/20 Balancer pool
 *      along with freshly minted RBT. The DETF holds the resulting BPT, and users
 *      receive NFT positions tracking their share of that BPT.
 */
contract SeigniorageDETFUnderwritingTarget is
    SeigniorageDETFCommon,
    ReentrancyLockModifiers,
    ISeigniorageDETFUnderwriting
{
    using BetterSafeERC20 for IERC20;
    using FixedPoint for uint256;
    using SeigniorageDETFRepo for SeigniorageDETFRepo.Storage;

    uint256 internal constant _POOL_MINIMUM_TOTAL_SUPPLY = 1e6;

    /* ---------------------------------------------------------------------- */
    /*                           Memory Structures                            */
    /* ---------------------------------------------------------------------- */

    struct UnderwriteData {
        uint256 reserveVaultAmountIn;
        uint256 equivRbtAmount;
        uint256 expectedBptOut;
        uint256 actualBptOut;
        uint256[] depositAmounts;
        uint256[] balancesRaw;
        uint256[] currentRatedBalances;
        uint256[] weightsArray;
        uint256 poolTotalSupply;
        uint256 reserveVaultRate;
        uint256 selfIndex;
        uint256 reserveVaultIndex;
        uint256 selfWeight;
        uint256 reserveVaultWeight;
    }

    function _syncLpReserve(SeigniorageDETFRepo.Storage storage layout) internal {
        layout;
        ERC4626Repo._setLastTotalAssets(ERC4626Repo._reserveAsset().balanceOf(address(this)));
    }

    /* ---------------------------------------------------------------------- */
    /*                              Underwrite                                */
    /* ---------------------------------------------------------------------- */

    /**
     * @inheritdoc ISeigniorageDETFUnderwriting
     */
    function underwrite(IERC20 tokenIn, uint256 amountIn, uint256 lockDuration, address recipient, bool pretransferred)
        external
        lock
        returns (uint256 tokenId)
    {
        if (recipient == address(0)) {
            recipient = msg.sender;
        }

        SeigniorageDETFRepo.Storage storage layout = SeigniorageDETFRepo._layout();
        UnderwriteData memory data;

        IVault balV3Vault = BalancerV3VaultAwareRepo._balancerV3Vault();
        IStandardExchange reserveVault = layout.reserveVault;

        // Step 1: Convert input to reserve vault shares and transfer to Balancer vault
        if (_isReserveVaultToken(layout, tokenIn)) {
            // Input is reserve vault shares - transfer directly to Balancer vault
            if (pretransferred) {
                tokenIn.safeTransfer(address(balV3Vault), amountIn);
            } else {
                tokenIn.safeTransferFrom(msg.sender, address(balV3Vault), amountIn);
            }
            data.reserveVaultAmountIn = amountIn;
        } else if (_isValidMintToken(layout, tokenIn)) {
            // Input is reserve vault constituent - exchange for reserve vault shares
            if (pretransferred) {
                tokenIn.safeTransfer(address(reserveVault), amountIn);
            } else {
                tokenIn.safeTransferFrom(msg.sender, address(reserveVault), amountIn);
            }
            data.reserveVaultAmountIn = reserveVault.exchangeIn(
                tokenIn, amountIn, IERC20(address(reserveVault)), 0, address(balV3Vault), true, block.timestamp
            );
        } else {
            revert InvalidRoute(address(tokenIn), address(reserveVault));
        }

        // Step 2: Load pool state
        IWeightedPool reservePool_ = IWeightedPool(address(ERC4626Repo._reserveAsset()));
        (,, data.balancesRaw, data.currentRatedBalances) = balV3Vault.getPoolTokenInfo(address(reservePool_));

        data.selfIndex = layout.selfIndexInReservePool;
        data.reserveVaultIndex = layout.reserveVaultIndexInReservePool;
        data.selfWeight = layout.selfReservePoolWeight;
        data.reserveVaultWeight = layout.reserveVaultReservePoolWeight;

        data.weightsArray = new uint256[](2);
        data.weightsArray[data.reserveVaultIndex] = data.reserveVaultWeight;
        data.weightsArray[data.selfIndex] = data.selfWeight;

        data.poolTotalSupply = balV3Vault.totalSupply(address(reservePool_));
        data.depositAmounts = new uint256[](2);

        // Step 3: Calculate equivalent RBT amount for proportional deposit
        if (data.poolTotalSupply == 0) {
            // Pool initialization:
            // - Pick an initial self-token amount such that rated balances match weights.
            // - Compute expected BPT out via the pool's own `computeInvariant` to ensure the
            //   `minBptAmountOut` matches Balancer's minting logic.

            // Fetch the pool's rate provider for the reserve-vault token so we can compute rated balances.
            (, TokenInfo[] memory tokenInfo,,) = balV3Vault.getPoolTokenInfo(address(reservePool_));
            data.reserveVaultRate = tokenInfo[data.reserveVaultIndex].rateProvider.getRate();

            // Target ratio (in rated terms): selfRated / reserveRated = selfWeight / reserveWeight
            uint256 weightRatio = data.selfWeight.divDown(data.reserveVaultWeight);

            // Reserve token is a rate token; the pool invariant is computed on liveScaled18 balances.
            uint256 ratedReserveVaultAmount = data.reserveVaultAmountIn.mulDown(data.reserveVaultRate);
            data.equivRbtAmount = ratedReserveVaultAmount.mulUp(weightRatio);

            data.depositAmounts[data.reserveVaultIndex] = data.reserveVaultAmountIn;
            data.depositAmounts[data.selfIndex] = data.equivRbtAmount;

            uint256[] memory balancesLiveScaled18 = new uint256[](2);
            balancesLiveScaled18[data.reserveVaultIndex] = ratedReserveVaultAmount;
            balancesLiveScaled18[data.selfIndex] = data.equivRbtAmount;

            uint256 invariant =
                IBasePool(address(reservePool_)).computeInvariant(balancesLiveScaled18, Rounding.ROUND_DOWN);

            data.expectedBptOut = invariant > _POOL_MINIMUM_TOTAL_SUPPLY ? invariant - _POOL_MINIMUM_TOTAL_SUPPLY : 0;
        } else {
            // Existing pool - calculate proportional amounts
            data.equivRbtAmount = BalancerV38020WeightedPoolMath.calcEquivalentProportionalGivenSingle(
                data.currentRatedBalances,
                data.weightsArray,
                data.poolTotalSupply,
                data.reserveVaultIndex,
                data.reserveVaultAmountIn
            );

            data.depositAmounts[data.reserveVaultIndex] = data.reserveVaultAmountIn;
            data.depositAmounts[data.selfIndex] = data.equivRbtAmount;

            data.expectedBptOut = BalancerV38020WeightedPoolMath.calcBptOutGivenProportionalIn(
                data.balancesRaw, data.weightsArray, data.poolTotalSupply, data.depositAmounts
            );
        }

        // Step 4: Mint RBT and transfer to Balancer vault
        ERC20Repo._mint(address(balV3Vault), data.equivRbtAmount);

        // Capture DETF's BPT reserve before the mint for correct share pricing.
        uint256 bptReserveBefore = ERC4626Repo._reserveAsset().balanceOf(address(this));

        // Step 5: Add liquidity to pool
        _addLiquidityToPool(layout, reservePool_, reserveVault, data);

        // Keep BasicVault reserve views in-sync with actual BPT balance.
        _syncLpReserve(layout);

        // Step 6: Credit NFT vault with BPT shares (DETF keeps the BPT)
        tokenId = layout.seigniorageNFTVault.lockFromDetf(data.actualBptOut, bptReserveBefore, lockDuration, recipient);
    }

    /**
     * @dev Internal function to add liquidity to the Balancer pool.
     *      Separated to reduce stack depth in underwrite function.
     */
    function _addLiquidityToPool(
        SeigniorageDETFRepo.Storage storage layout,
        IWeightedPool reservePool_,
        IStandardExchange reserveVault,
        UnderwriteData memory data
    ) internal {
        IBalancerV3StandardExchangeRouterPrepay prepayRouter = layout.balancerV3PrepayRouter;

        if (SeigniorageDETFRepo._isReservePoolInitialized()) {
            data.actualBptOut = prepayRouter.prepayAddLiquidityUnbalanced(
                address(reservePool_), data.depositAmounts, data.expectedBptOut, ""
            );
        } else {
            // Initialize pool
            IERC20[] memory poolTokens = new IERC20[](2);
            poolTokens[0] = IERC20(address(reserveVault));
            poolTokens[1] = IERC20(address(this));
            // Sort addresses (Balancer requires sorted token array)
            if (address(poolTokens[0]) > address(poolTokens[1])) {
                (poolTokens[0], poolTokens[1]) = (poolTokens[1], poolTokens[0]);
            }

            prepayRouter.prepayInitialize(
                address(reservePool_), poolTokens, data.depositAmounts, data.expectedBptOut, ""
            );

            SeigniorageDETFRepo._setIsReservePoolInitialized();
            data.actualBptOut = data.expectedBptOut;
        }
    }

    /**
     * @inheritdoc ISeigniorageDETFUnderwriting
     */
    function previewUnderwrite(IERC20 tokenIn, uint256 amountIn, uint256 lockDuration)
        external
        view
        returns (uint256 originalShares, uint256 effectiveShares, uint256 bonusMultiplier)
    {
        SeigniorageDETFRepo.Storage storage layout = SeigniorageDETFRepo._layout();

        uint256 reserveVaultAmountIn = _previewReserveVaultAmount(layout, tokenIn, amountIn);

        uint256 expectedBptOut = _previewBptOut(layout, reserveVaultAmountIn);

        uint256 bptReserveBefore = ERC4626Repo._reserveAsset().balanceOf(address(this));
        uint256 totalSharesBefore = layout.seigniorageNFTVault.totalShares();

        if (totalSharesBefore == 0 || bptReserveBefore == 0) {
            originalShares = expectedBptOut;
        } else {
            originalShares = Math.mulDiv(expectedBptOut, totalSharesBefore, bptReserveBefore, Math.Rounding.Ceil);
        }
        bonusMultiplier = _calcBonusMultiplier(lockDuration);
        effectiveShares = (originalShares * bonusMultiplier) / ONE_WAD;
    }

    /**
     * @dev Calculate reserve vault amount from input token.
     */
    function _previewReserveVaultAmount(SeigniorageDETFRepo.Storage storage layout, IERC20 tokenIn, uint256 amountIn)
        internal
        view
        returns (uint256 reserveVaultAmountIn)
    {
        if (_isReserveVaultToken(layout, tokenIn)) {
            reserveVaultAmountIn = amountIn;
        } else if (_isValidMintToken(layout, tokenIn)) {
            reserveVaultAmountIn =
                layout.reserveVault.previewExchangeIn(tokenIn, amountIn, IERC20(address(layout.reserveVault)));
        } else {
            revert InvalidRoute(address(tokenIn), address(layout.reserveVault));
        }
    }

    /**
     * @dev Calculate expected BPT out for given reserve vault amount.
     */
    function _previewBptOut(SeigniorageDETFRepo.Storage storage layout, uint256 reserveVaultAmountIn)
        internal
        view
        returns (uint256 bptOut)
    {
        IVault balV3Vault = BalancerV3VaultAwareRepo._balancerV3Vault();
        address reservePoolAddr = address(ERC4626Repo._reserveAsset());

        (,, uint256[] memory balancesRaw,) = balV3Vault.getPoolTokenInfo(reservePoolAddr);
        uint256 poolTotalSupply = balV3Vault.totalSupply(reservePoolAddr);

        uint256 reserveVaultIndex = layout.reserveVaultIndexInReservePool;
        uint256 selfIndex = layout.selfIndexInReservePool;

        uint256[] memory weightsArray = new uint256[](2);
        weightsArray[reserveVaultIndex] = layout.reserveVaultReservePoolWeight;
        weightsArray[selfIndex] = layout.selfReservePoolWeight;

        if (poolTotalSupply == 0) {
            // Mirror the initialize-path math used in `underwrite` so previews match actual init.
            (, TokenInfo[] memory tokenInfo,,) = balV3Vault.getPoolTokenInfo(reservePoolAddr);
            uint256 reserveVaultRate = tokenInfo[reserveVaultIndex].rateProvider.getRate();

            uint256 weightRatio = layout.selfReservePoolWeight.divDown(layout.reserveVaultReservePoolWeight);
            uint256 ratedReserveVaultAmount = reserveVaultAmountIn.mulDown(reserveVaultRate);
            uint256 initEquivRbtAmount = ratedReserveVaultAmount.mulUp(weightRatio);

            uint256[] memory balancesLiveScaled18 = new uint256[](2);
            balancesLiveScaled18[reserveVaultIndex] = ratedReserveVaultAmount;
            balancesLiveScaled18[selfIndex] = initEquivRbtAmount;

            uint256 invariant = IBasePool(reservePoolAddr).computeInvariant(balancesLiveScaled18, Rounding.ROUND_DOWN);
            return invariant > _POOL_MINIMUM_TOTAL_SUPPLY ? invariant - _POOL_MINIMUM_TOTAL_SUPPLY : 0;
        }

        uint256 equivRbtAmount = BalancerV38020WeightedPoolMath.calcEquivalentProportionalGivenSingle(
            balancesRaw, weightsArray, poolTotalSupply, reserveVaultIndex, reserveVaultAmountIn
        );

        uint256[] memory depositAmounts = new uint256[](2);
        depositAmounts[reserveVaultIndex] = reserveVaultAmountIn;
        depositAmounts[selfIndex] = equivRbtAmount;

        bptOut = BalancerV38020WeightedPoolMath.calcBptOutGivenProportionalIn(
            balancesRaw, weightsArray, poolTotalSupply, depositAmounts
        );
    }

    /**
     * @dev Calculate bonus multiplier based on lock duration.
     *      Uses quadratic curve between min/max bond terms.
     */
    function _calcBonusMultiplier(uint256 lockDuration) internal view returns (uint256 bonusMultiplier) {
        SeigniorageDETFRepo.Storage storage layout = SeigniorageDETFRepo._layout();
        BondTerms memory terms = layout.feeOracle.bondTermsOfVault(address(layout.seigniorageNFTVault));

        // Expected invariant, but guard to avoid division-by-zero.
        if (terms.maxLockDuration <= terms.minLockDuration) {
            return ONE_WAD + terms.maxBonusPercentage;
        }

        // Preview functions should remain non-reverting; clamp outside-range durations.
        if (lockDuration <= terms.minLockDuration) {
            return ONE_WAD + terms.minBonusPercentage;
        }
        if (lockDuration >= terms.maxLockDuration) {
            return ONE_WAD + terms.maxBonusPercentage;
        }

        uint256 normalized =
            ((lockDuration - terms.minLockDuration) * ONE_WAD) / (terms.maxLockDuration - terms.minLockDuration);
        uint256 curveFactor = (normalized * normalized) / ONE_WAD;

        uint256 bonus;
        if (terms.maxBonusPercentage >= terms.minBonusPercentage) {
            bonus = terms.minBonusPercentage + ((terms.maxBonusPercentage - terms.minBonusPercentage) * curveFactor)
                / ONE_WAD;
        } else {
            bonus = terms.maxBonusPercentage;
        }

        bonusMultiplier = ONE_WAD + bonus;
    }

    /* ---------------------------------------------------------------------- */
    /*                                Redeem                                  */
    /* ---------------------------------------------------------------------- */

    /**
     * @inheritdoc ISeigniorageDETFUnderwriting
     */
    function redeem(uint256 tokenId, address recipient) external lock returns (uint256 amountOut) {
        SeigniorageDETFRepo.Storage storage layout = SeigniorageDETFRepo._layout();
        ISeigniorageNFTVault nftVault = layout.seigniorageNFTVault;

        // NFT vault will call claimLiquidity which handles the pool withdrawal
        amountOut = nftVault.unlock(tokenId, recipient);
    }

    /**
     * @inheritdoc ISeigniorageDETFUnderwriting
     */
    function previewRedeem(uint256 tokenId) external view returns (uint256 amountOut) {
        SeigniorageDETFRepo.Storage storage layout = SeigniorageDETFRepo._layout();
        ISeigniorageNFTVault nftVault = layout.seigniorageNFTVault;

        uint256 shares = nftVault.rewardSharesOf(tokenId);
        uint256 totalShares_ = nftVault.totalShares();
        uint256 totalLpReserve = ERC4626Repo._reserveAsset().balanceOf(address(this));

        if (totalShares_ == 0 || totalLpReserve == 0) {
            return shares;
        }

        amountOut = Math.mulDiv(shares, totalLpReserve, totalShares_, Math.Rounding.Floor);
    }

    /* ---------------------------------------------------------------------- */
    /*                           Claim Liquidity                              */
    /* ---------------------------------------------------------------------- */

    /**
     * @inheritdoc ISeigniorageDETFUnderwriting
     * @dev This is called by the NFT vault when a position is unlocked.
     *      It removes liquidity from the 80/20 pool, extracts the reserve vault
     *      portion as rate target tokens, and redeposits the RBT portion back
     *      to maintain pool balance.
     */
    function claimLiquidity(uint256 lpAmount, address recipient) external returns (uint256 extractedLiquidity) {
        SeigniorageDETFRepo.Storage storage layout = SeigniorageDETFRepo._layout();

        if (msg.sender != address(layout.seigniorageNFTVault)) {
            revert NotNFTVault(msg.sender);
        }

        // Step 1 & 2: Remove liquidity from pool
        (uint256 reserveVaultOut, uint256 selfOut) = _removeLiquidityFromPool(layout, lpAmount);

        // Step 3: Exchange reserve vault for rate target and send to recipient
        extractedLiquidity = _extractAndSendRateTarget(layout, reserveVaultOut, recipient);

        // Step 4: Redeposit RBT back to pool to maintain balance
        if (selfOut > 0) {
            _redepositRbtToPool(layout, selfOut);
        }

        // Keep BasicVault reserve views in-sync with actual BPT balance.
        _syncLpReserve(layout);
    }

    /**
     * @dev Internal function to remove liquidity from the Balancer pool.
     *      Returns the amounts of reserve vault and self tokens received.
     */
    function _removeLiquidityFromPool(SeigniorageDETFRepo.Storage storage layout, uint256 lpAmount)
        internal
        returns (uint256 reserveVaultOut, uint256 selfOut)
    {
        IVault balV3Vault = BalancerV3VaultAwareRepo._balancerV3Vault();
        IWeightedPool reservePool_ = IWeightedPool(address(ERC4626Repo._reserveAsset()));
        IStandardExchange reserveVault = layout.reserveVault;

        uint256 selfIndex = layout.selfIndexInReservePool;
        uint256 reserveVaultIndex = layout.reserveVaultIndexInReservePool;

        // Calculate expected amounts from proportional exit
        uint256 poolTotalSupply = balV3Vault.totalSupply(address(reservePool_));
        // `getCurrentLiveBalances` returns balances scaled by token rates for yield-bearing tokens.
        // However, `removeLiquidity` expects `minAmountsOut` in raw token units.
        // Use raw balances to avoid inflating min-out for tokens with a rate provider.
        (,, uint256[] memory currentBalances,) = balV3Vault.getPoolTokenInfo(address(reservePool_));

        uint256[] memory expectedExitAmounts = BalancerV38020WeightedPoolMath.calcProportionalAmountsOutGivenBptIn(
            currentBalances, poolTotalSupply, lpAmount
        );

        // Apply 1-wei rounding tolerance for Balancer V3 proportional exit math.
        // Balancer's internal mulDivDown can round differently from our local estimate,
        // producing amounts up to 1 wei below expectedExitAmounts. Mutate in-place to
        // avoid an extra stack variable (this function is near the EVM stack limit).
        for (uint256 i = 0; i < expectedExitAmounts.length; ++i) {
            if (expectedExitAmounts[i] > 0) {
                unchecked {
                    expectedExitAmounts[i] -= 1;
                }
            }
        }

        // Balancer V3 remove-liquidity flow may pull BPT via `transferFrom` from different callers
        // (Vault, Router, or our prepay router callback path), depending on the exact Vault/Router wiring.
        // Approve exact `lpAmount` for the relevant contracts (no allowance accumulation).
        IERC20 bpt = IERC20(address(reservePool_));
        bpt.forceApprove(address(balV3Vault), lpAmount);
        if (address(layout.balancerV3PrepayRouter) != address(0)) {
            bpt.forceApprove(address(layout.balancerV3PrepayRouter), lpAmount);
        }

        uint256[] memory amountsOut = layout.balancerV3PrepayRouter
            .prepayRemoveLiquidityProportional(address(reservePool_), lpAmount, expectedExitAmounts, "");

        // Verify received amounts
        reserveVaultOut = IERC20(address(reserveVault)).balanceOf(address(this));
        if (reserveVaultOut < amountsOut[reserveVaultIndex]) {
            revert ReserveExpectedAmountNotReceived(amountsOut[reserveVaultIndex], reserveVaultOut);
        }

        selfOut = IERC20(address(this)).balanceOf(address(this));
        if (selfOut < amountsOut[selfIndex]) {
            revert SelfExpectedAmountNotReceived(amountsOut[selfIndex], selfOut);
        }
    }

    /**
     * @dev Internal function to exchange reserve vault for rate target and send to recipient.
     */
    function _extractAndSendRateTarget(
        SeigniorageDETFRepo.Storage storage layout,
        uint256 reserveVaultAmount,
        address recipient
    ) internal returns (uint256 rateTargetOut) {
        IStandardExchange reserveVault = layout.reserveVault;
        IERC20 rateTarget = layout.reserveVaultRateTarget;

        uint256 expectedOut =
            reserveVault.previewExchangeIn(IERC20(address(reserveVault)), reserveVaultAmount, rateTarget);

        IERC20(address(reserveVault)).safeTransfer(address(reserveVault), reserveVaultAmount);

        rateTargetOut = reserveVault.exchangeIn(
            IERC20(address(reserveVault)), reserveVaultAmount, rateTarget, expectedOut, recipient, true, block.timestamp
        );
    }

    /**
     * @dev Internal function to redeposit RBT back to the pool to maintain balance.
     */
    function _redepositRbtToPool(SeigniorageDETFRepo.Storage storage layout, uint256 rbtAmount) internal {
        IVault balV3Vault = BalancerV3VaultAwareRepo._balancerV3Vault();
        IWeightedPool reservePool_ = IWeightedPool(address(ERC4626Repo._reserveAsset()));

        uint256 selfIndex = layout.selfIndexInReservePool;
        uint256 reserveVaultIndex = layout.reserveVaultIndexInReservePool;

        // Refresh pool state
        uint256[] memory currentBalances = balV3Vault.getCurrentLiveBalances(address(reservePool_));
        uint256 poolTotalSupply = balV3Vault.totalSupply(address(reservePool_));
        uint256 swapFee = balV3Vault.getStaticSwapFeePercentage(address(reservePool_));

        uint256[] memory weightsArray = new uint256[](2);
        weightsArray[reserveVaultIndex] = layout.reserveVaultReservePoolWeight;
        weightsArray[selfIndex] = layout.selfReservePoolWeight;

        uint256[] memory depositAmounts = new uint256[](2);

        // Balancer WeightedMath enforces a maximum in-ratio (30% of the current token balance).
        // After a near-full exit (e.g., only the minimum BPT supply remains), the pool balances can be tiny,
        // and attempting to redeposit the entire `rbtAmount` will revert with "Exceeds max in ratio".
        // Cap the unbalanced redeposit to the maximum allowed amount.
        uint256 maxRbtIn = FixedPoint.mulDown(currentBalances[selfIndex], 30e16);
        if (maxRbtIn > 0) {
            unchecked {
                maxRbtIn -= 1;
            }
        }

        uint256 rbtToDeposit = Math.min(rbtAmount, maxRbtIn);
        if (rbtToDeposit == 0) {
            return;
        }

        depositAmounts[selfIndex] = rbtToDeposit;

        uint256 expectedBptOut = BalancerV38020WeightedPoolMath.calcBptOutGivenUnbalancedIn(
            currentBalances, weightsArray, depositAmounts, poolTotalSupply, swapFee
        );

        // `calcBptOutGivenUnbalancedIn` is an estimate, and Balancer's internal rounding can mint slightly
        // less BPT than `expectedBptOut` (especially when balances/supply are close to the minimum).
        // Apply a tiny safety margin so redeposit doesn't revert on dust differences.
        uint256 minBptOut = FixedPoint.mulDown(expectedBptOut, 9999e14); // 1 bps slippage

        // Transfer RBT to Balancer vault
        IERC20(address(this)).safeTransfer(address(balV3Vault), rbtToDeposit);

        layout.balancerV3PrepayRouter.prepayAddLiquidityUnbalanced(address(reservePool_), depositAmounts, minBptOut, "");
    }

    /* ---------------------------------------------------------------------- */
    /*                       Preview Claim Liquidity                          */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice Previews the amount of rate target tokens returned from claiming LP.
     * @dev Calculates what would be returned if claimLiquidity were called.
     * @param lpAmount Amount of BPT (LP shares) to preview
     * @return liquidityOut Amount of rate target tokens that would be received
     */
    function previewClaimLiquidity(uint256 lpAmount) external view returns (uint256 liquidityOut) {
        SeigniorageDETFRepo.Storage storage layout = SeigniorageDETFRepo._layout();

        IVault balV3Vault = BalancerV3VaultAwareRepo._balancerV3Vault();
        IWeightedPool reservePool_ = IWeightedPool(address(ERC4626Repo._reserveAsset()));
        IStandardExchange reserveVault = layout.reserveVault;

        uint256 reserveVaultIndex = layout.reserveVaultIndexInReservePool;

        // Calculate expected amounts from proportional exit using raw balances.
        // `getCurrentLiveBalances` returns balances scaled by token rates for yield-bearing tokens,
        // but `removeLiquidity` returns raw token units. Use raw balances so the preview matches execution.
        uint256 poolTotalSupply = balV3Vault.totalSupply(address(reservePool_));
        (,, uint256[] memory currentBalances,) = balV3Vault.getPoolTokenInfo(address(reservePool_));

        uint256[] memory expectedExitAmounts = BalancerV38020WeightedPoolMath.calcProportionalAmountsOutGivenBptIn(
            currentBalances, poolTotalSupply, lpAmount
        );

        // Apply the same 1-wei rounding tolerance used in `_removeLiquidityFromPool` so
        // preview does not overestimate execution due to rounding differences.
        for (uint256 i = 0; i < expectedExitAmounts.length; ++i) {
            if (expectedExitAmounts[i] > 0) {
                unchecked {
                    expectedExitAmounts[i] -= 1;
                }
            }
        }

        uint256 reserveVaultOut = expectedExitAmounts[reserveVaultIndex];

        // Apply the same 1-wei rounding tolerance used in _removeLiquidityFromPool().
        // The remove path subtracts 1 wei from each expected exit amount to avoid
        // spurious reverts when Balancer's internal rounding mints/pulls slightly
        // less than the local estimate. Mirror that here so previews do not
        // systematically overestimate execution by more than 1 wei.
        if (reserveVaultOut > 0) {
            unchecked {
                reserveVaultOut -= 1;
            }
        }

        // Preview exchange of reserve vault to rate target
        liquidityOut = reserveVault.previewExchangeIn(
            IERC20(address(reserveVault)), reserveVaultOut, layout.reserveVaultRateTarget
        );
    }

    /* ---------------------------------------------------------------------- */
    /*                          ISeigniorageDETF Views                        */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice Returns the seigniorage reward token (sRBT).
     * @return The seigniorage token contract
     */
    function seigniorageToken() external view returns (IERC20) {
        return IERC20(address(SeigniorageDETFRepo._seigniorageToken()));
    }

    /**
     * @notice Returns the NFT vault that manages bond positions.
     * @return The NFT vault contract
     */
    function seigniorageNFTVault() external view returns (ISeigniorageNFTVault) {
        return SeigniorageDETFRepo._seigniorageNFTVault();
    }

    /**
     * @notice Returns the rate target token for reserve vault valuation.
     * @return The rate target token (e.g., USDC)
     */
    function reserveVaultRateTarget() external view returns (IERC20) {
        return SeigniorageDETFRepo._reserveVaultRateTarget();
    }

    /**
     * @notice Returns the reserve pool (Balancer 80/20 pool) address.
     * @return The reserve pool contract
     */
    function reservePool() external view returns (address) {
        return address(ERC4626Repo._reserveAsset());
    }

    /**
     * @notice Withdraws pending sRBT rewards for a bond position.
     * @dev Convenience wrapper to the NFT vault.
     */
    function withdrawRewards(uint256 tokenId, address recipient) external returns (uint256 rewards) {
        return SeigniorageDETFRepo._seigniorageNFTVault().withdrawRewards(tokenId, recipient);
    }
}
