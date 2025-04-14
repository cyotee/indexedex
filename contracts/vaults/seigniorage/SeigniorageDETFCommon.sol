// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                 Balancer V3                                */
/* -------------------------------------------------------------------------- */

import {IVault} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IVault.sol";
import {IWeightedPool} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IWeightedPool.sol";
import {FixedPoint} from "@crane/contracts/external/balancer/v3/solidity-utils/contracts/math/FixedPoint.sol";
import {WeightedMath} from "@crane/contracts/external/balancer/v3/solidity-utils/contracts/math/WeightedMath.sol";
import {IERC4626} from "@crane/contracts/interfaces/IERC4626.sol";

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {ONE_WAD} from "@crane/contracts/constants/Constants.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20MintBurn} from "@crane/contracts/interfaces/IERC20MintBurn.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {ERC4626Repo} from "@crane/contracts/tokens/ERC4626/ERC4626Repo.sol";
import {BetterSafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {BetterMath} from "@crane/contracts/utils/math/BetterMath.sol";
import {Permit2AwareRepo} from "@crane/contracts/protocols/utils/permit2/aware/Permit2AwareRepo.sol";
import {
    BalancerV3VaultAwareRepo
} from "@crane/contracts/protocols/dexes/balancer/v3/vault/BalancerV3VaultAwareRepo.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IStandardExchange} from "contracts/interfaces/IStandardExchange.sol";
import {ISeigniorageDETFErrors} from "contracts/interfaces/ISeigniorageDETFErrors.sol";
import {SeigniorageDETFRepo} from "contracts/vaults/seigniorage/SeigniorageDETFRepo.sol";
import {
    BalancerV38020WeightedPoolMath
} from "contracts/protocols/dexes/balancer/v3/utils/BalancerV38020WeightedPoolMath.sol";
import {BasicVaultCommon} from "contracts/vaults/basic/BasicVaultCommon.sol";

/**
 * @title SeigniorageDETFCommon
 * @author cyotee doge <not_cyotee@proton.me>
 * @notice Common functionality for Seigniorage DETF exchange operations.
 * @dev Contains shared logic for loading pool state, calculating diluted prices,
 *      and managing seigniorage mechanics.
 */
abstract contract SeigniorageDETFCommon is BasicVaultCommon, ISeigniorageDETFErrors {
    using BetterSafeERC20 for IERC20;
    using SeigniorageDETFRepo for SeigniorageDETFRepo.Storage;

    /* ---------------------------------------------------------------------- */
    /*                           Memory Structures                            */
    /* ---------------------------------------------------------------------- */

    /// @notice Balancer V3 pool state data for calculations
    struct ReservePoolData {
        IVault balV3Vault;
        IWeightedPool reservePool;
        uint256 reservePoolSwapFee;
        uint256 reserveVaultIndexInReservePool;
        uint256 reserveVaultRatedBalance;
        uint256 reserveVaultReservePoolWeight;
        uint256 selfIndexInReservePool;
        uint256 selfReservePoolRatedBalance;
        uint256 selfReservePoolWeight;
        uint256 resPoolTotalSupply;
        uint256 expectedBpt;
        uint256[] weightsArray;
        uint256 reserveVaultRate;
    }

    /// @notice DETF (RBT) token data
    struct RBTData {
        IStandardExchange reserveVault;
        uint256 selfTotalSupply;
        uint256 selfDilutedPrice;
    }

    /// @notice Seigniorage token (sRBT) data
    struct SRBTData {
        IERC20MintBurn seigniorageToken;
        uint256 srbtTotalSupply;
        uint256 sRbtReserveVaultDebt;
    }

    /// @notice Seigniorage profit margin calculation outputs
    struct SRBTAmounts {
        uint256 effectiveMintPriceFull;
        uint256 premiumPerRBT;
        uint256 grossSeigniorage;
        uint256 discountRBT;
        uint256 discountMargin;
        uint256 profitMargin;
        uint256 sRBTToMint;
    }

    /// @notice Legacy struct - keeping for compatibility
    struct ReservePoolState {
        uint256 selfBalance;
        uint256 reserveVaultBalance;
        uint256 selfWeight;
        uint256 reserveVaultWeight;
        uint256 swapFeePercentage;
        uint256 selfTotalSupply;
        uint256 sRbtTotalSupply;
        uint256 sRbtReserveVaultDebt;
    }

    /// @notice Legacy struct - keeping for compatibility
    struct SeigniorageCalc {
        uint256 dilutedPrice;
        uint256 grossSeigniorage;
        uint256 discountMargin;
        uint256 profitMargin;
        uint256 seigniorageTokens;
        uint256 reducedFeePercent;
    }

    /* ---------------------------------------------------------------------- */
    /*                         Pool State Loading                             */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice Loads the current state of the 80/20 reserve pool into ReservePoolData.
     * @dev Matches the original implementation's data loading pattern.
     * @param resPoolData_ Memory struct to populate with pool state
     * @param currentRatedBalances_ Output array for rated balances (to avoid re-fetching)
     */
    function _loadReservePoolData(ReservePoolData memory resPoolData_, uint256[] memory currentRatedBalances_)
        internal
        view
        returns (uint256[] memory)
    {
        SeigniorageDETFRepo.Storage storage layout = SeigniorageDETFRepo._layout();

        resPoolData_.balV3Vault = BalancerV3VaultAwareRepo._balancerV3Vault();
        resPoolData_.reservePool = IWeightedPool(address(ERC4626Repo._reserveAsset()));
        resPoolData_.reservePoolSwapFee =
            resPoolData_.balV3Vault.getStaticSwapFeePercentage(address(resPoolData_.reservePool));

        // Get live (rated) balances from Balancer V3 vault
        currentRatedBalances_ = resPoolData_.balV3Vault.getCurrentLiveBalances(address(resPoolData_.reservePool));

        // Cache indices for gas efficiency
        resPoolData_.reserveVaultIndexInReservePool = layout.reserveVaultIndexInReservePool;
        resPoolData_.selfIndexInReservePool = layout.selfIndexInReservePool;

        // Load balances
        resPoolData_.reserveVaultRatedBalance = currentRatedBalances_[resPoolData_.reserveVaultIndexInReservePool];
        resPoolData_.selfReservePoolRatedBalance = currentRatedBalances_[resPoolData_.selfIndexInReservePool];

        // Load weights (from storage - they never change)
        resPoolData_.reserveVaultReservePoolWeight = layout.reserveVaultReservePoolWeight;
        resPoolData_.selfReservePoolWeight = layout.selfReservePoolWeight;

        // Create weights array for pool math operations
        resPoolData_.weightsArray = new uint256[](2);
        resPoolData_.weightsArray[resPoolData_.reserveVaultIndexInReservePool] =
        resPoolData_.reserveVaultReservePoolWeight;
        resPoolData_.weightsArray[resPoolData_.selfIndexInReservePool] = resPoolData_.selfReservePoolWeight;

        // Load pool total supply
        resPoolData_.resPoolTotalSupply = resPoolData_.balV3Vault.totalSupply(address(resPoolData_.reservePool));

        return currentRatedBalances_;
    }

    /**
     * @notice Loads DETF (RBT) token data.
     */
    function _loadRBTData(RBTData memory rbtData_) internal view {
        SeigniorageDETFRepo.Storage storage layout = SeigniorageDETFRepo._layout();
        rbtData_.reserveVault = layout.reserveVault;
        rbtData_.selfTotalSupply = ERC20Repo._totalSupply();
    }

    /**
     * @notice Loads seigniorage token (sRBT) data and calculates debt.
     */
    function _loadSRBTData(SRBTData memory sRbtData_, ReservePoolData memory resPoolData_) internal view {
        SeigniorageDETFRepo.Storage storage layout = SeigniorageDETFRepo._layout();
        sRbtData_.seigniorageToken = layout.seigniorageToken;
        sRbtData_.srbtTotalSupply = IERC20(address(sRbtData_.seigniorageToken)).totalSupply();

        // Calculate sRBT reserve vault debt using WeightedMath
        if (sRbtData_.srbtTotalSupply > 0 && resPoolData_.selfReservePoolRatedBalance > 0) {
            sRbtData_.sRbtReserveVaultDebt = WeightedMath.computeOutGivenExactIn(
                resPoolData_.selfReservePoolRatedBalance, // balanceIn (RBT in pool)
                resPoolData_.selfReservePoolWeight, // weightIn
                resPoolData_.reserveVaultRatedBalance, // balanceOut (reserve vault in pool)
                resPoolData_.reserveVaultReservePoolWeight, // weightOut
                FixedPoint.mulDown(sRbtData_.srbtTotalSupply, FixedPoint.ONE - resPoolData_.reservePoolSwapFee)
            );
        }
    }

    /**
     * @notice Calculates diluted price from loaded pool data.
     * @dev Formula: priceFromReserves(reserveBalance - sRbtDebt, selfSupply + sRbtSupply, weights)
     */
    function _calcDilutedPriceFromData(
        RBTData memory rbtData_,
        SRBTData memory sRbtData_,
        ReservePoolData memory resPoolData_
    ) internal pure returns (uint256 dilutedPrice_) {
        // Calculate diluted price minus the reserve token debt owed via sRBT
        dilutedPrice_ = BalancerV38020WeightedPoolMath.priceFromReserves(
            resPoolData_.reserveVaultRatedBalance - sRbtData_.sRbtReserveVaultDebt, // adjusted reserve
            rbtData_.selfTotalSupply + sRbtData_.srbtTotalSupply, // total claims
            resPoolData_.reserveVaultReservePoolWeight,
            resPoolData_.selfReservePoolWeight
        );
    }

    /**
     * @notice Legacy: Loads the current state of the 80/20 reserve pool.
     * @param layout_ Storage layout reference
     * @param state_ Memory struct to populate with pool state
     */
    function _loadReservePoolState(SeigniorageDETFRepo.Storage storage layout_, ReservePoolState memory state_)
        internal
        view
    {
        IWeightedPool pool = IWeightedPool(address(ERC4626Repo._reserveAsset()));
        IVault balV3Vault = BalancerV3VaultAwareRepo._balancerV3Vault();

        uint256[] memory balances = balV3Vault.getCurrentLiveBalances(address(pool));
        uint256[] memory weights = pool.getNormalizedWeights();

        uint256 selfIndex = layout_.selfIndexInReservePool;
        uint256 reserveVaultIndex = layout_.reserveVaultIndexInReservePool;

        state_.selfBalance = balances[selfIndex];
        state_.reserveVaultBalance = balances[reserveVaultIndex];
        state_.selfWeight = weights[selfIndex];
        state_.reserveVaultWeight = weights[reserveVaultIndex];
        state_.swapFeePercentage = balV3Vault.getStaticSwapFeePercentage(address(pool));
        state_.selfTotalSupply = ERC20Repo._totalSupply();
        state_.sRbtTotalSupply = IERC20(address(layout_.seigniorageToken)).totalSupply();

        if (state_.sRbtTotalSupply > 0 && state_.selfBalance > 0) {
            uint256 sRbtAfterFee = FixedPoint.mulDown(state_.sRbtTotalSupply, FixedPoint.ONE - state_.swapFeePercentage);
            state_.sRbtReserveVaultDebt = WeightedMath.computeOutGivenExactIn(
                state_.selfBalance,
                state_.selfWeight,
                state_.reserveVaultBalance,
                state_.reserveVaultWeight,
                sRbtAfterFee
            );
        }
    }

    function _loadReservePoolState(ReservePoolState memory state_) internal view {
        _loadReservePoolState(SeigniorageDETFRepo._layout(), state_);
    }

    /* ---------------------------------------------------------------------- */
    /*                       Diluted Price Calculation                        */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice Calculates the diluted price of the DETF token accounting for sRBT debt.
     * @dev The diluted price represents the true backing per token when considering
     *      all outstanding claims (both RBT and sRBT). This is calculated by:
     *      1. Subtracting sRBT debt from reserve vault balance (what would be owed if all sRBT redeemed)
     *      2. Adding sRBT supply to RBT supply (total claims on reserves)
     *      3. Using weighted pool math to calculate spot price from adjusted reserves
     *
     *      Formula: priceFromReserves(
     *          reserveBalance - sRbtDebt,
     *          selfSupply + sRbtSupply,
     *          reserveWeight,
     *          selfWeight
     *      )
     *
     * @param state_ The loaded reserve pool state (must be loaded with _loadReservePoolState first)
     * @return dilutedPrice_ The current diluted price in WAD (1e18 = peg price)
     */
    function _calcDilutedPrice(SeigniorageDETFRepo.Storage storage, ReservePoolState memory state_)
        internal
        pure
        returns (uint256 dilutedPrice_)
    {
        // If no RBT in pool, price is at peg
        if (state_.selfBalance == 0) {
            return ONE_WAD;
        }

        // Calculate adjusted reserve balance (subtract sRBT debt)
        // This represents the "available" reserves after accounting for sRBT claims
        uint256 adjustedReserveBalance = state_.reserveVaultBalance > state_.sRbtReserveVaultDebt
            ? state_.reserveVaultBalance - state_.sRbtReserveVaultDebt
            : 0;

        // If no reserves available after debt, price is 0
        if (adjustedReserveBalance == 0) {
            return 0;
        }

        // Calculate total claims (RBT + sRBT supply)
        // sRBT represents future claims on RBT, so it dilutes the price
        uint256 totalClaims = state_.selfTotalSupply + state_.sRbtTotalSupply;

        // Calculate diluted price using weighted pool math
        // priceFromReserves calculates: (baseReserve / quoteReserve) * (quoteWeight / baseWeight)
        dilutedPrice_ = BalancerV38020WeightedPoolMath.priceFromReserves(
            adjustedReserveBalance, // baseCurrencyReserve (reserve vault minus debt)
            totalClaims, // quoteCurrencyReserve (RBT + sRBT)
            state_.reserveVaultWeight, // baseCurrencyWeight (80%)
            state_.selfWeight // quoteCurrencyWeight (20%)
        );
    }

    function _calcDilutedPrice(ReservePoolState memory state_) internal pure returns (uint256) {
        return _calcDilutedPrice(SeigniorageDETFRepo._layout(), state_);
    }

    /**
     * @notice Checks if the current price is above peg (seigniorage capture mode).
     * @param dilutedPrice_ The current diluted price
     * @return True if price is above 1 WAD (peg price)
     */
    function _isAbovePeg(uint256 dilutedPrice_) internal pure returns (bool) {
        return dilutedPrice_ > ONE_WAD;
    }

    /**
     * @notice Checks if the current price is below peg (redemption mode).
     * @param dilutedPrice_ The current diluted price
     * @return True if price is at or below 1 WAD (peg price)
     */
    function _isBelowPeg(uint256 dilutedPrice_) internal pure returns (bool) {
        return dilutedPrice_ <= ONE_WAD;
    }

    /* ---------------------------------------------------------------------- */
    /*                      Seigniorage Calculations                          */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice Calculates seigniorage components for a mint operation above peg.
     * @dev When the DETF trades above peg, new tokens can be minted.
     *      The seigniorage is split between:
     *      - discountMargin: Fee reduction given to users (incentive)
     *      - profitMargin: Captured as seigniorage tokens for bond holders
     * @param layout_ Storage layout reference
     * @param calc_ Seigniorage calculation struct to populate
     * @param amountIn_ Amount of reserve tokens deposited
     */
    function _calcSeigniorage(
        SeigniorageDETFRepo.Storage storage layout_,
        SeigniorageCalc memory calc_,
        uint256 amountIn_
    ) internal view {
        if (calc_.dilutedPrice <= ONE_WAD) {
            return;
        }

        calc_.grossSeigniorage = amountIn_ - (amountIn_ * ONE_WAD / calc_.dilutedPrice);

        uint256 reductionPPM = layout_._swapFeeReductionPercentagePPM();
        calc_.reducedFeePercent = reductionPPM;

        calc_.discountMargin = BetterMath._percentageOfWAD(calc_.grossSeigniorage, reductionPPM);

        calc_.profitMargin = calc_.grossSeigniorage - calc_.discountMargin;

        if (calc_.profitMargin > 0) {
            calc_.seigniorageTokens = calc_.profitMargin;
        }
    }

    function _calcSeigniorage(SeigniorageCalc memory calc_, uint256 amountIn_) internal view {
        _calcSeigniorage(SeigniorageDETFRepo._layout(), calc_, amountIn_);
    }

    /* ---------------------------------------------------------------------- */
    /*                       Amount Calculations                              */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice Calculates amount of DETF tokens to mint for a given reserve deposit.
     * @dev At peg (1:1), 1 reserve token = 1 DETF token.
     *      Above peg, fewer DETF tokens are minted per reserve token.
     * @param amountIn_ Amount of reserve tokens to deposit
     * @param dilutedPrice_ Current diluted price
     * @return amountOut_ Amount of DETF tokens to mint
     */
    function _calcMintAmount(uint256 amountIn_, uint256 dilutedPrice_) internal pure returns (uint256 amountOut_) {
        if (dilutedPrice_ <= ONE_WAD) {
            amountOut_ = amountIn_;
        } else {
            amountOut_ = (amountIn_ * ONE_WAD) / dilutedPrice_;
        }
    }

    /**
     * @notice Calculates amount of reserve tokens to return for burning DETF tokens.
     * @dev At or below peg, 1 DETF token = 1 reserve token.
     * @param amountIn_ Amount of DETF tokens to burn
     * @param dilutedPrice_ Current diluted price
     * @return amountOut_ Amount of reserve tokens to return
     */
    function _calcBurnAmount(uint256 amountIn_, uint256 dilutedPrice_) internal pure returns (uint256 amountOut_) {
        if (dilutedPrice_ <= ONE_WAD) {
            amountOut_ = amountIn_;
        } else {
            amountOut_ = (amountIn_ * dilutedPrice_) / ONE_WAD;
        }
    }

    /* ---------------------------------------------------------------------- */
    /*                        Token Route Validation                          */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice Checks if a token is valid for minting DETF (reserve vault token).
     * @param layout_ Storage layout reference
     * @param token_ Token to check
     * @return True if token is a valid reserve vault constituent
     */
    function _isValidMintToken(SeigniorageDETFRepo.Storage storage layout_, IERC20 token_)
        internal
        view
        returns (bool)
    {
        // Canonical mint token is the reserve vault's ERC4626 reserve asset.
        return address(token_) == IERC4626(address(layout_.reserveVault)).asset();
    }

    function _isValidMintToken(IERC20 token_) internal view returns (bool) {
        return _isValidMintToken(SeigniorageDETFRepo._layout(), token_);
    }

    /**
     * @notice Checks if the target token is this DETF contract (for minting).
     * @param token_ Token to check
     * @return True if token address equals this contract
     */
    function _isSelfToken(IERC20 token_) internal view returns (bool) {
        return address(token_) == address(this);
    }

    /**
     * @notice Checks if the token is the reserve vault.
     * @param layout_ Storage layout reference
     * @param token_ Token to check
     * @return True if token is the reserve vault
     */
    function _isReserveVaultToken(SeigniorageDETFRepo.Storage storage layout_, IERC20 token_)
        internal
        view
        returns (bool)
    {
        return address(token_) == address(layout_.reserveVault);
    }

    function _isReserveVaultToken(IERC20 token_) internal view returns (bool) {
        return _isReserveVaultToken(SeigniorageDETFRepo._layout(), token_);
    }

    /* ---------------------------------------------------------------------- */
    /*                        Reserve Pool Initialization                     */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice Checks if the reserve pool has been initialized.
     * @return True if initialized
     */
    function _isInitialized() internal view returns (bool) {
        return SeigniorageDETFRepo._isReservePoolInitialized();
    }

    /**
     * @notice Gets the reserve pool address.
     * @return The weighted pool contract
     */
    function _reservePool() internal view returns (IWeightedPool) {
        return IWeightedPool(address(ERC4626Repo._reserveAsset()));
    }

    /**
     * @notice Gets the reserve vault address.
     * @return The reserve vault exchange contract
     */
    function _reserveVault() internal view returns (IStandardExchange) {
        return SeigniorageDETFRepo._reserveVault();
    }

    /**
     * @notice Gets the seigniorage token address.
     * @return The seigniorage token (sRBT)
     */
    function _seigniorageToken() internal view returns (IERC20) {
        return IERC20(address(SeigniorageDETFRepo._seigniorageToken()));
    }
}
