// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {Math} from "@crane/contracts/utils/Math.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {BetterSafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {IVault} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IVault.sol";
import {IBasePool} from "@crane/contracts/external/balancer/v3/interfaces/contracts/vault/IBasePool.sol";
import {BasePoolMath} from "@crane/contracts/external/balancer/v3/vault/contracts/BasePoolMath.sol";
import {
    ScalingHelpers
} from "@crane/contracts/external/balancer/v3/solidity-utils/contracts/helpers/ScalingHelpers.sol";
import {
    IBalancerV3StandardExchangeRouterProxy
} from "contracts/interfaces/proxies/IBalancerV3StandardExchangeRouterProxy.sol";
import {
    BalancerV3StandardExchangeRouterAwareRepo
} from "contracts/protocols/dexes/balancer/v3/routers/BalancerV3StandardExchangeRouterAwareRepo.sol";
import {
    BalancerV3VaultAwareRepo
} from "@crane/contracts/protocols/dexes/balancer/v3/vault/BalancerV3VaultAwareRepo.sol";
import {DETFUsageFeeLib} from "contracts/vaults/detf/common/core/DETFUsageFeeLib.sol";
import {StandardVaultRepo} from "contracts/vaults/standard/StandardVaultRepo.sol";
import {IVaultRegistryDisableQuery} from "contracts/interfaces/IVaultRegistryDisableQuery.sol";
import {
    DualLiquidityLinkedCrossVersionUniswapVaultRepo
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/uniswap/v4/crossVersion/v2/DualLiquidityLinkedCrossVersionUniswapVaultRepo.sol";
import {
    DualLiquidityLinkedCrossVersionUniswapVaultMathLib
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/uniswap/v4/crossVersion/v2/DualLiquidityLinkedCrossVersionUniswapVaultMathLib.sol";

/// @title DualLiquidityLinkedCrossVersionUniswapVaultCommon
/// @notice Abstract base providing shared internal helpers for the DualLiquidityLinkedCrossVersionUniswapVault family.
///         All functions are internal; concrete facets or targets inherit and expose them.
///
/// @dev ERC-20 mint/burn goes through ERC20Repo (same pattern as RebasingDETFTokenTarget).
///      Share math delegates to DualLiquidityLinkedCrossVersionUniswapVaultMathLib; fee split to DETFUsageFeeLib.
abstract contract DualLiquidityLinkedCrossVersionUniswapVaultCommon {
    using BetterSafeERC20 for IERC20;

    /* ---------------------------------------------------------------------- */
    /*                               TokenKind                                */
    /* ---------------------------------------------------------------------- */

    /// @notice Classifies a token relative to this DETF's configured token set.
    enum TokenKind {
        None,
        Shares,
        ReserveBpt,
        CommonToken,
        TokenA,
        TokenB,
        VaultAShare,
        VaultBShare,
        PairVaultShare
    }

    /* ---------------------------------------------------------------------- */
    /*                          Reserve BPT Balance                           */
    /* ---------------------------------------------------------------------- */

    /// @notice Returns the reserve BPT balance held by this contract (proxy).
    function _totalReserveBpt() internal view returns (uint256) {
        return DualLiquidityLinkedCrossVersionUniswapVaultRepo._layoutStruct().reserveBpt.balanceOf(address(this));
    }

    /* ---------------------------------------------------------------------- */
    /*                          Share Mint / Burn                             */
    /* ---------------------------------------------------------------------- */

    /// @notice Quotes the user and fee share slices for `bptIn_` against the CURRENT reserve
    ///         state (i.e. BEFORE `bptIn_` enters the reserve). Pure view; mints nothing.
    /// @dev Single source of truth for the deposit fee split, shared by `_mintSharesForBpt`
    ///      (execution) and the query facets (preview) so the two can never drift.
    /// @param bptIn_ BPT amount that will be deposited after the caller settles it.
    /// @return userShares_ Shares the depositor would receive (gross minus fee).
    /// @return feeShares_  Shares the fee recipient would receive.
    function _previewSharesForBpt(uint256 bptIn_) internal view returns (uint256 userShares_, uint256 feeShares_) {
        uint256 totalSupply_ = ERC20Repo._totalSupply();
        uint256 totalBpt_ = _totalReserveBpt();
        uint256 gross_ = DualLiquidityLinkedCrossVersionUniswapVaultMathLib._sharesForBpt(bptIn_, totalSupply_, totalBpt_);
        uint256 feeWad_ = DualLiquidityLinkedCrossVersionUniswapVaultRepo._layoutStruct().feeOracle.usageFeeOfVault(address(this));
        (userShares_, feeShares_) = DETFUsageFeeLib._splitUsageFee(gross_, feeWad_);
    }

    /// @notice Computes gross shares for `bptIn` against the CURRENT reserve (must exclude `bptIn_`),
    ///         splits via the usage fee oracle, then mints user + fee slices.
    /// @dev Prefer `_mintSharesForActualBpt` after a join: mint against a pre-join snapshot so
    ///      share issuance tracks actual BPT received, never an optimistic quote.
    /// @param bptIn_    BPT amount being deposited (not yet in `_totalReserveBpt` for this path).
    /// @param recipient_ Address that receives the user portion of newly minted shares.
    /// @return userShares_ Shares minted to `recipient_` (gross minus fee).
    function _mintSharesForBpt(uint256 bptIn_, address recipient_) internal returns (uint256 userShares_) {
        userShares_ = _mintSharesForBptAgainst(bptIn_, recipient_, ERC20Repo._totalSupply(), _totalReserveBpt());
    }

    /// @notice Mint shares for `bptIn_` using an explicit pre-join supply/BPT snapshot.
    /// @dev Call after the join when `_totalReserveBpt()` already includes `bptIn_`, passing the
    ///      supply and BPT captured before the join. Prevents dilution from quote > actual BPT.
    function _mintSharesForActualBpt(
        uint256 bptIn_,
        address recipient_,
        uint256 totalSupplyBefore_,
        uint256 totalBptBefore_
    ) internal returns (uint256 userShares_) {
        userShares_ = _mintSharesForBptAgainst(bptIn_, recipient_, totalSupplyBefore_, totalBptBefore_);
    }

    function _mintSharesForBptAgainst(
        uint256 bptIn_,
        address recipient_,
        uint256 totalSupply_,
        uint256 totalBpt_
    ) private returns (uint256 userShares_) {
        uint256 gross_ =
            DualLiquidityLinkedCrossVersionUniswapVaultMathLib._sharesForBpt(bptIn_, totalSupply_, totalBpt_);
        uint256 feeWad_ =
            DualLiquidityLinkedCrossVersionUniswapVaultRepo._layoutStruct().feeOracle.usageFeeOfVault(address(this));
        uint256 feeShares_;
        (userShares_, feeShares_) = DETFUsageFeeLib._splitUsageFee(gross_, feeWad_);

        if (userShares_ > 0) {
            ERC20Repo._mint(recipient_, userShares_);
        }
        if (feeShares_ > 0) {
            address feeTo_ = address(DualLiquidityLinkedCrossVersionUniswapVaultRepo._layoutStruct().feeOracle.feeTo());
            ERC20Repo._mint(feeTo_, feeShares_);
        }
    }

    /// @notice Burns `sharesIn_` from `from_` and returns the BPT amount they represent
    ///         (quoted BEFORE the shares are burned, per the MathLib convention).
    /// @param sharesIn_ Shares to burn.
    /// @param from_     Account whose shares are burned.
    /// @return bptOut_ BPT amount owed to the redeemer.
    function _burnSharesForBpt(uint256 sharesIn_, address from_) internal returns (uint256 bptOut_) {
        bptOut_ = _quoteBptForShares(sharesIn_);
        ERC20Repo._burn(from_, sharesIn_);
    }

    /// @notice View mirror of `_burnSharesForBpt`: the BPT `sharesIn_` represents at the current
    ///         reserve ratio, without burning. Shared by execution and redemption previews.
    function _quoteBptForShares(uint256 sharesIn_) internal view returns (uint256 bptOut_) {
        bptOut_ = DualLiquidityLinkedCrossVersionUniswapVaultMathLib._bptForShares(sharesIn_, ERC20Repo._totalSupply(), _totalReserveBpt());
    }

    /* ---------------------------------------------------------------------- */
    /*                       Exact-out inverse helpers                        */
    /* ---------------------------------------------------------------------- */

    /// @notice Grosses `userShares_` up for the usage fee so the depositor receives exactly
    ///         `userShares_` while the fee slice is minted on top.
    /// @return grossShares_ Total shares to mint (user + fee).
    /// @return feeShares_   Shares minted to the fee recipient.
    function _grossUpShares(uint256 userShares_) internal view returns (uint256 grossShares_, uint256 feeShares_) {
        uint256 feeWad_ = DualLiquidityLinkedCrossVersionUniswapVaultRepo._layoutStruct().feeOracle.usageFeeOfVault(address(this));
        // grossShares = ceil(userShares * ONE / (ONE - feeWad)); feeWad < ONE assumed for exact-out.
        grossShares_ = _ceilDiv(userShares_, ONE_WAD, ONE_WAD - feeWad_);
        feeShares_ = grossShares_ - userShares_;
    }

    /// @notice BPT required to back `grossShares_` new shares at the current reserve ratio (rounded up).
    function _bptForSharesUp(uint256 grossShares_) internal view returns (uint256 bptNeeded_) {
        bptNeeded_ = _ceilDiv(grossShares_, _totalReserveBpt(), ERC20Repo._totalSupply());
    }

    /// @notice Shares that must burn to release at least `bptOut_` of reserve BPT (rounded up, with a
    ///         one-unit safety margin so post-burn flooring never falls short of `bptOut_`).
    function _sharesForBptUp(uint256 bptOut_) internal view returns (uint256 sharesIn_) {
        sharesIn_ = _ceilDiv(bptOut_, ERC20Repo._totalSupply(), _totalReserveBpt()) + 1;
    }

    /// @notice Per-1e18-BPT payout of exit-token `index_` (0=A,1=B,2=pair) from a proportional exit.
    function _exitPerBpt(uint256 index_) internal view returns (uint256 rate_) {
        rate_ = _previewExitReserveProportional(ONE_WAD)[index_];
    }

    /// @notice Reserve BPT that must be exited so a proportional exit yields at least `amountOut_` of
    ///         exit-token `index_`. Uses the linear per-BPT rate, then corrects for weighted-pool
    ///         flooring so the guarantee holds to the wei. Shared by the exact-out redeem execution and
    ///         its query so `previewExchangeOut == amountIn` stays exact.
    function _bptDueForVaultShareExactOut(uint256 index_, uint256 amountOut_) internal view returns (uint256 bptDue_) {
        uint256 perBpt_ = _exitPerBpt(index_);
        bptDue_ = _ceilDiv(amountOut_, ONE_WAD, perBpt_);
        uint256 got_ = _previewExitReserveProportional(bptDue_)[index_];
        if (got_ < amountOut_) {
            bptDue_ += _ceilDiv(amountOut_ - got_, ONE_WAD, perBpt_) + 1;
        }
    }

    uint256 private constant ONE_WAD = 1e18;

    /// @dev Ceiling of `a_ * b_ / c_` without intermediate-overflow loss, via mulmod remainder check.
    function _ceilDiv(uint256 a_, uint256 b_, uint256 c_) private pure returns (uint256 result_) {
        result_ = Math.mulDiv(a_, b_, c_);
        if (mulmod(a_, b_, c_) > 0) result_ += 1;
    }

    /* ---------------------------------------------------------------------- */
    /*                     Reserve Pool state / index mapping                 */
    /* ---------------------------------------------------------------------- */

    /// @dev The Standard-Exchange router used to execute reserve liquidity operations.
    function _reserveRouter() internal view returns (IBalancerV3StandardExchangeRouterProxy router_) {
        router_ = BalancerV3StandardExchangeRouterAwareRepo._balancerV3StandardExchangeRouter();
    }

    /// @dev The Balancer V3 vault, source of live reserve-pool balances and swap fee.
    function _reserveVault() internal view returns (IVault vault_) {
        vault_ = BalancerV3VaultAwareRepo._balancerV3Vault();
    }

    /// @dev Reserve-pool registration index for one of the three vault-share tokens.
    function _reservePoolIndexOf(IERC20 vaultShareToken_) internal view returns (uint256 index_) {
        DualLiquidityLinkedCrossVersionUniswapVaultRepo.Storage storage repo_ = DualLiquidityLinkedCrossVersionUniswapVaultRepo._layoutStruct();
        if (address(vaultShareToken_) == address(repo_.vaultAShare)) return repo_.indexA;
        if (address(vaultShareToken_) == address(repo_.vaultBShare)) return repo_.indexB;
        if (address(vaultShareToken_) == address(repo_.pairVaultShare)) return repo_.indexPair;
        revert DualLiquidityLinkedCrossVersionUniswapVaultRepo.UnsupportedRoute(vaultShareToken_, IERC20(address(this)));
    }

    /// @dev Live reserve-pool state for **exit / general** quotes.
    ///      Uses Vault `getCurrentLiveBalances` (ROUND_DOWN), matching removeLiquidity.
    /// @return balances_ Live balances (scaled 18) in pool registration order.
    /// @return totalSupply_ Reserve BPT total supply.
    /// @return swapFee_ Static swap fee percentage (WAD).
    function _reservePoolState()
        internal
        view
        returns (uint256[] memory balances_, uint256 totalSupply_, uint256 swapFee_)
    {
        DualLiquidityLinkedCrossVersionUniswapVaultRepo.Storage storage repo_ =
            DualLiquidityLinkedCrossVersionUniswapVaultRepo._layoutStruct();
        address pool_ = address(repo_.reservePool);
        balances_ = _reserveVault().getCurrentLiveBalances(pool_);
        totalSupply_ = IERC20(pool_).totalSupply();
        swapFee_ = _reserveVault().getStaticSwapFeePercentage(pool_);
    }

    /// @dev Live balances for **add/join** quotes. Vault `addLiquidity` loads pool data with
    ///      `Rounding.ROUND_UP` (see VaultLiquidityFacet), not ROUND_DOWN from
    ///      `getCurrentLiveBalances`. Rebuild live balances from raw + rates with RoundUp so
    ///      `computeAddLiquidityUnbalanced` matches the live join BPT.
    function _reservePoolStateForAdd()
        internal
        view
        returns (uint256[] memory balancesLive_, uint256 totalSupply_, uint256 swapFee_)
    {
        DualLiquidityLinkedCrossVersionUniswapVaultRepo.Storage storage repo_ =
            DualLiquidityLinkedCrossVersionUniswapVaultRepo._layoutStruct();
        address pool_ = address(repo_.reservePool);
        IVault vault_ = _reserveVault();

        (,, uint256[] memory balancesRaw_,) = vault_.getPoolTokenInfo(pool_);
        (uint256[] memory scalingFactors_, uint256[] memory tokenRates_) = vault_.getPoolTokenRates(pool_);

        uint256 n_ = balancesRaw_.length;
        balancesLive_ = new uint256[](n_);
        for (uint256 i = 0; i < n_; i++) {
            balancesLive_[i] = ScalingHelpers.toScaled18ApplyRateRoundUp(
                balancesRaw_[i], scalingFactors_[i], tokenRates_[i]
            );
        }
        totalSupply_ = IERC20(pool_).totalSupply();
        swapFee_ = vault_.getStaticSwapFeePercentage(pool_);
    }

    /* ---------------------------------------------------------------------- */
    /*                          Reserve Pool Join / Exit                      */
    /* ---------------------------------------------------------------------- */

    /// @notice Joins the reserve pool by adding `amount_` of `vaultShareToken_` unbalanced, minting BPT
    ///         to this contract. Funds the add by pre-transferring the token to the Balancer Vault, which
    ///         the router then settles (the seigniorage funding pattern) — no Permit2 pull.
    /// @return bptOut_ BPT minted to this contract.
    function _joinReserve(IERC20 vaultShareToken_, uint256 amount_) internal returns (uint256 bptOut_) {
        DualLiquidityLinkedCrossVersionUniswapVaultRepo.Storage storage repo_ = DualLiquidityLinkedCrossVersionUniswapVaultRepo._layoutStruct();
        uint256 numTokens_ = _reserveVault().getCurrentLiveBalances(address(repo_.reservePool)).length;

        uint256[] memory amountsIn_ = new uint256[](numTokens_);
        amountsIn_[_reservePoolIndexOf(vaultShareToken_)] = amount_;

        // The prepay router settles via `vault.settle`, crediting tokens already sent to the vault
        // (the seigniorage funding pattern). Pre-transfer, then add unbalanced.
        vaultShareToken_.safeTransfer(address(_reserveVault()), amount_);
        bptOut_ = _reserveRouter().prepayAddLiquidityUnbalanced(address(repo_.reservePool), amountsIn_, 0, "");
    }

    /// @notice Adds up to all three vault-share tokens (DETF order [A, B, pair]) into the reserve in a
    ///         single unbalanced add, minting BPT to this contract. Batching keeps the invariant delta
    ///         positive so tiny per-leg leftovers (which would underflow a lone single-token add) ride
    ///         along with the larger legs. Zero-amount legs are skipped.
    function _joinReserveMulti(uint256 aAmount_, uint256 bAmount_, uint256 pairAmount_)
        internal
        returns (uint256 bptOut_)
    {
        DualLiquidityLinkedCrossVersionUniswapVaultRepo.Storage storage repo_ = DualLiquidityLinkedCrossVersionUniswapVaultRepo._layoutStruct();
        uint256[] memory amountsIn_ =
            new uint256[](_reserveVault().getCurrentLiveBalances(address(repo_.reservePool)).length);
        amountsIn_[repo_.indexA] = aAmount_;
        amountsIn_[repo_.indexB] = bAmount_;
        amountsIn_[repo_.indexPair] = pairAmount_;

        address vault_ = address(_reserveVault());
        if (aAmount_ > 0) repo_.vaultAShare.safeTransfer(vault_, aAmount_);
        if (bAmount_ > 0) repo_.vaultBShare.safeTransfer(vault_, bAmount_);
        if (pairAmount_ > 0) repo_.pairVaultShare.safeTransfer(vault_, pairAmount_);

        bptOut_ = _reserveRouter().prepayAddLiquidityUnbalanced(address(repo_.reservePool), amountsIn_, 0, "");
    }

    /// @notice Quotes the BPT output for a hypothetical unbalanced add of `amount_` `vaultShareToken_`.
    /// @dev `amount_` is a **raw** ERC20 amount. Scaled to live with RoundDown (Vault add path);
    ///      balances use ROUND_UP live state to match `addLiquidity`.
    function _quoteJoinReserve(IERC20 vaultShareToken_, uint256 amount_) internal view returns (uint256 bptOut_) {
        DualLiquidityLinkedCrossVersionUniswapVaultRepo.Storage storage repo_ =
            DualLiquidityLinkedCrossVersionUniswapVaultRepo._layoutStruct();
        (uint256[] memory balances_, uint256 totalSupply_, uint256 swapFee_) = _reservePoolStateForAdd();
        (uint256[] memory scalingFactors_, uint256[] memory tokenRates_) =
            _reserveVault().getPoolTokenRates(address(repo_.reservePool));

        uint256 index_ = _reservePoolIndexOf(vaultShareToken_);
        uint256[] memory exactAmountsLive_ = new uint256[](balances_.length);
        exactAmountsLive_[index_] =
            ScalingHelpers.toScaled18ApplyRateRoundDown(amount_, scalingFactors_[index_], tokenRates_[index_]);

        (bptOut_,) = BasePoolMath.computeAddLiquidityUnbalanced(
            balances_, exactAmountsLive_, totalSupply_, swapFee_, IBasePool(address(repo_.reservePool))
        );
    }

    /// @notice Quotes BPT for a multi-leg unbalanced add of raw DETF-order amounts [A, B, pair].
    function _quoteJoinReserveMulti(uint256 aAmount_, uint256 bAmount_, uint256 pairAmount_)
        internal
        view
        returns (uint256 bptOut_)
    {
        DualLiquidityLinkedCrossVersionUniswapVaultRepo.Storage storage repo_ =
            DualLiquidityLinkedCrossVersionUniswapVaultRepo._layoutStruct();
        (uint256[] memory balances_, uint256 totalSupply_, uint256 swapFee_) = _reservePoolStateForAdd();
        (uint256[] memory scalingFactors_, uint256[] memory tokenRates_) =
            _reserveVault().getPoolTokenRates(address(repo_.reservePool));

        uint256[] memory exactAmountsLive_ = new uint256[](balances_.length);
        if (aAmount_ > 0) {
            exactAmountsLive_[repo_.indexA] = ScalingHelpers.toScaled18ApplyRateRoundDown(
                aAmount_, scalingFactors_[repo_.indexA], tokenRates_[repo_.indexA]
            );
        }
        if (bAmount_ > 0) {
            exactAmountsLive_[repo_.indexB] = ScalingHelpers.toScaled18ApplyRateRoundDown(
                bAmount_, scalingFactors_[repo_.indexB], tokenRates_[repo_.indexB]
            );
        }
        if (pairAmount_ > 0) {
            exactAmountsLive_[repo_.indexPair] = ScalingHelpers.toScaled18ApplyRateRoundDown(
                pairAmount_, scalingFactors_[repo_.indexPair], tokenRates_[repo_.indexPair]
            );
        }

        (bptOut_,) = BasePoolMath.computeAddLiquidityUnbalanced(
            balances_, exactAmountsLive_, totalSupply_, swapFee_, IBasePool(address(repo_.reservePool))
        );
    }

    /// @notice Quotes the `vaultShareToken_` **raw** input required to mint exactly `bptOut_` reserve BPT.
    /// @dev Live amount from BasePoolMath is converted back to raw with RoundUp (Vault add path).
    function _quoteJoinReserveOut(IERC20 vaultShareToken_, uint256 bptOut_) internal view returns (uint256 amountIn_) {
        DualLiquidityLinkedCrossVersionUniswapVaultRepo.Storage storage repo_ =
            DualLiquidityLinkedCrossVersionUniswapVaultRepo._layoutStruct();
        (uint256[] memory balances_, uint256 totalSupply_, uint256 swapFee_) = _reservePoolStateForAdd();
        (uint256[] memory scalingFactors_, uint256[] memory tokenRates_) =
            _reserveVault().getPoolTokenRates(address(repo_.reservePool));

        uint256 index_ = _reservePoolIndexOf(vaultShareToken_);
        uint256 amountInLive_;
        (amountInLive_,) = BasePoolMath.computeAddLiquiditySingleTokenExactOut(
            balances_,
            index_,
            bptOut_,
            totalSupply_,
            swapFee_,
            IBasePool(address(repo_.reservePool))
        );
        amountIn_ =
            ScalingHelpers.toRawUndoRateRoundUp(amountInLive_, scalingFactors_[index_], tokenRates_[index_]);
    }

    /// @notice Adds exactly `amountIn_` of `vaultShareToken_` (the exact-out quote, rounded up) to mint at
    ///         least `minBpt_` reserve BPT to this contract. Any excess BPT accrues to the reserve.
    function _joinReserveOut(IERC20 vaultShareToken_, uint256 amountIn_, uint256 minBpt_) internal {
        DualLiquidityLinkedCrossVersionUniswapVaultRepo.Storage storage repo_ = DualLiquidityLinkedCrossVersionUniswapVaultRepo._layoutStruct();
        uint256[] memory amountsIn_ =
            new uint256[](_reserveVault().getCurrentLiveBalances(address(repo_.reservePool)).length);
        amountsIn_[_reservePoolIndexOf(vaultShareToken_)] = amountIn_;

        vaultShareToken_.safeTransfer(address(_reserveVault()), amountIn_);
        _reserveRouter().prepayAddLiquidityUnbalanced(address(repo_.reservePool), amountsIn_, minBpt_, "");
    }

    /// @notice Exits the reserve proportionally, burning `bptIn_` and receiving all three vault-share
    ///         tokens back to this contract.
    /// @return amounts_ [vaultAShare, vaultBShare, pairVaultShare] amounts received.
    function _exitReserveProportional(uint256 bptIn_) internal returns (uint256[] memory amounts_) {
        DualLiquidityLinkedCrossVersionUniswapVaultRepo.Storage storage repo_ = DualLiquidityLinkedCrossVersionUniswapVaultRepo._layoutStruct();
        uint256[] memory minOut_ =
            new uint256[](_reserveVault().getCurrentLiveBalances(address(repo_.reservePool)).length);

        // On remove, the vault burns BPT from `from` (this contract) after spending the router's
        // allowance (`_spendAllowance(pool, this, router, bptIn)`), so keep the BPT and approve the router.
        IERC20(address(repo_.reservePool)).forceApprove(address(_reserveRouter()), bptIn_);
        uint256[] memory raw_ =
            _reserveRouter().prepayRemoveLiquidityProportional(address(repo_.reservePool), bptIn_, minOut_, "");
        amounts_ = _reorderToDetf(raw_);
    }

    /// @notice View mirror of `_exitReserveProportional` for redemption previews.
    /// @return amounts_ [vaultAShare, vaultBShare, pairVaultShare] **raw** ERC20 amounts a proportional
    ///         exit would return (not live scaled18). Matches VaultLiquidityFacet's
    ///         `toRawUndoRateRoundDown` conversion so WITH_RATE leg shares preview == execution.
    function _previewExitReserveProportional(uint256 bptIn_) internal view returns (uint256[] memory amounts_) {
        DualLiquidityLinkedCrossVersionUniswapVaultRepo.Storage storage repo_ =
            DualLiquidityLinkedCrossVersionUniswapVaultRepo._layoutStruct();
        address pool_ = address(repo_.reservePool);
        (uint256[] memory balancesLive_, uint256 totalSupply_,) = _reservePoolState();
        uint256[] memory amountsLive_ =
            BasePoolMath.computeProportionalAmountsOut(balancesLive_, totalSupply_, bptIn_);

        (uint256[] memory scalingFactors_, uint256[] memory tokenRates_) = _reserveVault().getPoolTokenRates(pool_);
        uint256 n_ = amountsLive_.length;
        uint256[] memory raw_ = new uint256[](n_);
        for (uint256 i = 0; i < n_; i++) {
            raw_[i] = ScalingHelpers.toRawUndoRateRoundDown(amountsLive_[i], scalingFactors_[i], tokenRates_[i]);
        }
        amounts_ = _reorderToDetf(raw_);
    }

    /// @dev Reorders a pool-registration-order amounts array into DETF order [A, B, pair].
    function _reorderToDetf(uint256[] memory raw_) private view returns (uint256[] memory amounts_) {
        DualLiquidityLinkedCrossVersionUniswapVaultRepo.Storage storage repo_ = DualLiquidityLinkedCrossVersionUniswapVaultRepo._layoutStruct();
        amounts_ = new uint256[](3);
        amounts_[0] = raw_[repo_.indexA];
        amounts_[1] = raw_[repo_.indexB];
        amounts_[2] = raw_[repo_.indexPair];
    }

    /* ---------------------------------------------------------------------- */
    /*                     Redeposit remainder (redeem paths)                 */
    /* ---------------------------------------------------------------------- */

    /// @notice After a convenience redeem pays one leg, redeposit the other legs into the reserve.
    /// @dev Policy (no silent fund loss):
    ///      1. Quote multi-join BPT with WITH_RATE-correct scaling.
    ///      2. If quote is 0 (dust that cannot mint BPT) → refund remaining leg shares to `refundTo_`.
    ///      3. Otherwise hard-join via `_joinReserveMulti` (no try/catch). On Balancer failure the
    ///         whole redeem reverts atomically — pre-transfers, burn, and exit all roll back.
    ///      Successful joins already refund unused prepaid amounts via the prepay router hook
    ///      (`tokenInCredit - amountIn` → sender = this diamond); residual dust is swept to `feeTo`.
    /// @param amounts_  DETF-order exited amounts [A, B, pair] from the proportional exit.
    /// @param skipIndex_ Index of the leg already paid to the user (0/1/2).
    /// @param refundTo_  Recipient if the remainder cannot mint BPT (typically redeem recipient).
    function _redepositRemainder(uint256[] memory amounts_, uint256 skipIndex_, address refundTo_) internal {
        DualLiquidityLinkedCrossVersionUniswapVaultRepo.Storage storage repo_ =
            DualLiquidityLinkedCrossVersionUniswapVaultRepo._layoutStruct();

        uint256 a_ = skipIndex_ == 0 ? 0 : amounts_[0];
        uint256 b_ = skipIndex_ == 1 ? 0 : amounts_[1];
        uint256 pair_ = skipIndex_ == 2 ? 0 : amounts_[2];
        if (a_ + b_ + pair_ == 0) return;

        uint256 bptOut_ = _quoteJoinReserveMulti(a_, b_, pair_);
        if (bptOut_ == 0) {
            if (a_ > 0) repo_.vaultAShare.safeTransfer(refundTo_, a_);
            if (b_ > 0) repo_.vaultBShare.safeTransfer(refundTo_, b_);
            if (pair_ > 0) repo_.pairVaultShare.safeTransfer(refundTo_, pair_);
            return;
        }

        // Hard join — failure reverts the entire redemption (atomic, no stranded prepay inventory).
        _joinReserveMulti(a_, b_, pair_);
    }

    /// @notice Redeposit arbitrary DETF-order leftovers (exact-out pay-leg dust included).
    function _redepositAmounts(uint256 a_, uint256 b_, uint256 pair_, address refundTo_) internal {
        DualLiquidityLinkedCrossVersionUniswapVaultRepo.Storage storage repo_ =
            DualLiquidityLinkedCrossVersionUniswapVaultRepo._layoutStruct();
        if (a_ + b_ + pair_ == 0) return;

        uint256 bptOut_ = _quoteJoinReserveMulti(a_, b_, pair_);
        if (bptOut_ == 0) {
            if (a_ > 0) repo_.vaultAShare.safeTransfer(refundTo_, a_);
            if (b_ > 0) repo_.vaultBShare.safeTransfer(refundTo_, b_);
            if (pair_ > 0) repo_.pairVaultShare.safeTransfer(refundTo_, pair_);
            return;
        }
        _joinReserveMulti(a_, b_, pair_);
    }

    /* ---------------------------------------------------------------------- */
    /*                             Token Classifier                           */
    /* ---------------------------------------------------------------------- */

    /// @notice Maps `token_` to one of the nine TokenKind values for this DETF family.
    function _classify(IERC20 token_) internal view returns (TokenKind kind_) {
        if (address(token_) == address(this)) return TokenKind.Shares;

        DualLiquidityLinkedCrossVersionUniswapVaultRepo.Storage storage repo_ = DualLiquidityLinkedCrossVersionUniswapVaultRepo._layoutStruct();
        if (address(token_) == address(repo_.reserveBpt)) return TokenKind.ReserveBpt;
        if (address(token_) == address(repo_.commonToken)) return TokenKind.CommonToken;
        if (address(token_) == address(repo_.tokenA)) return TokenKind.TokenA;
        if (address(token_) == address(repo_.tokenB)) return TokenKind.TokenB;
        if (address(token_) == address(repo_.vaultAShare)) return TokenKind.VaultAShare;
        if (address(token_) == address(repo_.vaultBShare)) return TokenKind.VaultBShare;
        if (address(token_) == address(repo_.pairVaultShare)) return TokenKind.PairVaultShare;
        return TokenKind.None;
    }

    /* ---------------------------------------------------------------------- */
    /*                            Liveness Guard                              */
    /* ---------------------------------------------------------------------- */

    /// @notice Universal precondition: non-zero amount and unexpired deadline. Does NOT require a live
    ///         reserve — the bootstrapping first deposit runs against an empty reserve.
    /// @param deadline_ Unix timestamp after which the call is considered expired.
    /// @param amount_   Input/output amount (must be non-zero).
    function _requireActive(uint256 deadline_, uint256 amount_) internal view {
        _requireNotDisabled();
        if (amount_ == 0) revert DualLiquidityLinkedCrossVersionUniswapVaultRepo.ZeroAmount();
        if (block.timestamp > deadline_) revert DualLiquidityLinkedCrossVersionUniswapVaultRepo.DeadlineExpired(deadline_);
    }

    /// @notice Reverts if this vault is disabled by address or package on the Vault Registry.
    function _requireNotDisabled() internal view {
        address reg = address(StandardVaultRepo._feeOracle());
        if (IVaultRegistryDisableQuery(reg).isDisabled(address(this))) {
            revert IVaultRegistryDisableQuery.VaultDisabled(address(this));
        }
    }

    /// @notice Reverts unless the reserve already holds BPT. Required by every route except the
    ///         bootstrapping first deposit.
    function _requireReserveLive() internal view {
        if (_totalReserveBpt() == 0) {
            revert DualLiquidityLinkedCrossVersionUniswapVaultRepo.ReservePoolNotInitialized();
        }
    }

    /// @notice True when this call is the vault's initializing deposit: the reserve-BPT → shares route
    ///         into a vault whose supply is still zero. Such a deposit mints 1:1 and is allowed to run
    ///         against an empty reserve; all other routes require `_requireReserveLive`.
    function _isBootstrapDeposit(TokenKind kindIn_, TokenKind kindOut_) internal view returns (bool) {
        return kindOut_ == TokenKind.Shares && kindIn_ == TokenKind.ReserveBpt && ERC20Repo._totalSupply() == 0;
    }

    /* ---------------------------------------------------------------------- */
    /*                          Residual Dust Sweep                           */
    /* ---------------------------------------------------------------------- */

    /// @notice Snapshots this contract's resting balances of the six non-BPT intermediate
    ///         tokens (commonToken, tokenA, tokenB, and the three vault-share tokens).
    /// @dev Order is fixed: [commonToken, tokenA, tokenB, vaultAShare, vaultBShare, pairVaultShare].
    ///      Reserve BPT is intentionally excluded — it is the backing asset and is expected to grow.
    function _snapshotIntermediates() internal view returns (uint256[6] memory balances_) {
        DualLiquidityLinkedCrossVersionUniswapVaultRepo.Storage storage repo_ = DualLiquidityLinkedCrossVersionUniswapVaultRepo._layoutStruct();
        balances_[0] = repo_.commonToken.balanceOf(address(this));
        balances_[1] = repo_.tokenA.balanceOf(address(this));
        balances_[2] = repo_.tokenB.balanceOf(address(this));
        balances_[3] = repo_.vaultAShare.balanceOf(address(this));
        balances_[4] = repo_.vaultBShare.balanceOf(address(this));
        balances_[5] = repo_.pairVaultShare.balanceOf(address(this));
    }

    /// @notice Sweeps any intermediate-token dust a route left on the proxy to the fee oracle's
    ///         `feeTo()`. Real leg swaps and V2 zaps leave dust-level remainders that would otherwise
    ///         strand on the proxy; routing them to `feeTo()` — rather than refunding the caller, which
    ///         may be a contract that cannot process a partial refund — keeps every route clean while the
    ///         minted shares / payout stay exactly as quoted (dust is never part of the reserve BPT).
    /// @param before_ Snapshot from `_snapshotIntermediates` taken before the route body ran.
    function _sweepResidual(uint256[6] memory before_) internal {
        DualLiquidityLinkedCrossVersionUniswapVaultRepo.Storage storage repo_ = DualLiquidityLinkedCrossVersionUniswapVaultRepo._layoutStruct();
        address feeTo_ = address(repo_.feeOracle.feeTo());
        _sweepDust(repo_.commonToken, before_[0], feeTo_);
        _sweepDust(repo_.tokenA, before_[1], feeTo_);
        _sweepDust(repo_.tokenB, before_[2], feeTo_);
        _sweepDust(repo_.vaultAShare, before_[3], feeTo_);
        _sweepDust(repo_.vaultBShare, before_[4], feeTo_);
        _sweepDust(repo_.pairVaultShare, before_[5], feeTo_);
    }

    /// @dev Transfers any balance of `token_` above `restingBalance_` to `feeTo_`.
    function _sweepDust(IERC20 token_, uint256 restingBalance_, address feeTo_) private {
        uint256 current_ = token_.balanceOf(address(this));
        if (current_ > restingBalance_) {
            token_.safeTransfer(feeTo_, current_ - restingBalance_);
        }
    }
}
