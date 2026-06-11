// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IHooks} from
    "@crane/contracts/external/balancer/v3/interfaces/contracts/vault/IHooks.sol";
import {
    HookFlags,
    TokenConfig,
    TokenType,
    LiquidityManagement,
    PoolSwapParams,
    AfterSwapParams,
    AddLiquidityKind,
    RemoveLiquidityKind,
    AddLiquidityParams,
    RemoveLiquidityParams
} from "@crane/contracts/external/balancer/v3/interfaces/contracts/vault/VaultTypes.sol";
import {IVault} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IVault.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {Math} from "@crane/contracts/utils/Math.sol";
import {IStandardExchange} from "contracts/interfaces/IStandardExchange.sol";

import {IStandardExchangeBufferPool} from
    "contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/IStandardExchangeBufferPool.sol";
import {StandardExchangeBufferPoolRepo as Repo} from
    "contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/StandardExchangeBufferPoolRepo.sol";

/**
 * @title StandardExchangeBufferHookTarget
 * @notice Abstract hook target implementing IHooks for the StandardExchangeBufferPool.
 * @dev Abstract because `_balancerV3Vault()` and `_expectedFactory()` are left virtual
 *      for the facet (Task 12) to provide. This slice covers registration + initialization.
 *      Swap and LP hooks are filled in by Tasks 8-11.
 */
abstract contract StandardExchangeBufferHookTarget is IHooks {

    /* ----- Virtual hooks (resolved by the facet) ----- */

    /// @dev Returns the Balancer V3 Vault address. Implemented by the facet.
    function _balancerV3Vault() internal view virtual returns (address);

    /// @dev Returns the expected pool factory address. Implemented by the facet.
    function _expectedFactory() internal view virtual returns (address);

    /* ----- Registration ----- */

    /**
     * @notice Returns the set of hooks this contract implements.
     * @return hookFlags Flags indicating which hooks are active.
     */
    function getHookFlags() external pure virtual override returns (HookFlags memory) {
        return HookFlags({
            enableHookAdjustedAmounts: false,
            shouldCallBeforeInitialize: true,
            shouldCallAfterInitialize: false,
            shouldCallComputeDynamicSwapFee: false,
            shouldCallBeforeSwap: true,
            shouldCallAfterSwap: true,
            shouldCallBeforeAddLiquidity: true,
            shouldCallAfterAddLiquidity: true,
            shouldCallBeforeRemoveLiquidity: false,
            shouldCallAfterRemoveLiquidity: true
        });
    }

    /**
     * @notice Hook executed when a pool is registered with this hook contract.
     * @dev Validates: msg.sender is Vault, factory matches expected, pool is this contract,
     *      tokenConfig has exactly 2 entries with correct types and rate provider, and all
     *      required LiquidityManagement flags are set.
     */
    function onRegister(
        address factory,
        address pool,
        TokenConfig[] memory tokenConfig,
        LiquidityManagement calldata lm
    ) external view virtual override returns (bool) {
        if (msg.sender != _balancerV3Vault()) return false;
        if (factory != _expectedFactory()) return false;
        if (pool != address(this)) return false;
        if (tokenConfig.length != 2) return false;

        uint256 ttaIdx = Repo._ttaIndex();
        uint256 sharesIdx = Repo._sharesIndex();

        if (address(tokenConfig[ttaIdx].token) != address(Repo._ttaToken())) return false;
        if (address(tokenConfig[sharesIdx].token) != address(Repo._shareToken())) return false;
        if (tokenConfig[ttaIdx].tokenType != TokenType.STANDARD) return false;
        if (tokenConfig[sharesIdx].tokenType != TokenType.WITH_RATE) return false;
        if (address(tokenConfig[sharesIdx].rateProvider) != address(Repo._rateProvider())) return false;

        if (lm.disableUnbalancedLiquidity) return false;
        if (!lm.enableAddLiquidityCustom) return false;
        if (!lm.enableRemoveLiquidityCustom) return false;
        if (!lm.enableDonation) return false;

        return true;
    }

    /* ----- Initialization ----- */

    /**
     * @notice Hook executed before pool initialization.
     * @dev Seeds virtualTTA from the shares-side scaled18 amount and resets hookSharesDelta to 0.
     *
     *      Balancer V3 passes `exactAmountsInScaled18` to this hook.  For a WITH_RATE share token
     *      the scaled18 value is `rawShares * rate / 1e18`, which is already expressed in TTA-equivalent
     *      units (i.e. the economic DAI value of the seeded shares).  Therefore virtualTTA is set
     *      directly to `exactAmountsIn[sharesIdx]` — no further rate multiplication is needed.
     *
     *      Using the scaled18 amount also keeps virtualTTA consistent with Balancer's live-balance
     *      accounting: after initialization `liveBalance[sharesIdx] == rawBalance * rate / 1e18`,
     *      so `virtualTTA == liveBalance[sharesIdx]` immediately after the seed.
     *
     *      Reverts if the rate provider returns zero or the resulting virtualTTA is zero.
     */
    function onBeforeInitialize(uint256[] memory exactAmountsIn, bytes memory)
        external virtual override returns (bool)
    {
        if (msg.sender != _balancerV3Vault()) return false;
        uint256 sharesIdx = Repo._sharesIndex();
        uint256 rate = Repo._rateProvider().getRate();
        if (rate == 0) revert IStandardExchangeBufferPool.RateProviderZero();
        // exactAmountsIn is exactAmountsInScaled18 from Balancer. For WITH_RATE tokens,
        // scaled18 = rawShares * rate / 1e18 — already in TTA-equivalent units.
        uint256 virtualInit = exactAmountsIn[sharesIdx];
        if (virtualInit == 0) revert IStandardExchangeBufferPool.InitialInvariantTooSmall();
        Repo._setVirtualTTA(virtualInit);
        Repo._setHookSharesDelta(0);
        return true;
    }

    /* ----- Stubs for remaining IHooks methods (filled in Tasks 8-11) ----- */

    /// @dev Not used (shouldCallAfterInitialize = false). Returns false.
    function onAfterInitialize(uint256[] memory, uint256, bytes memory)
        external virtual override returns (bool)
    {
        return false;
    }

    /**
     * @notice Hook executed before add-liquidity operations.
     * @dev All standard add-liquidity kinds are permitted: PROPORTIONAL, UNBALANCED,
     *      SINGLE_TOKEN_EXACT_OUT, CUSTOM, and DONATION.
     *      Returns true without modification for all accepted kinds; state updates
     *      (virtualTTA, hookSharesDelta) are handled entirely in onAfterAddLiquidity.
     *
     *      NOTE: A TTA-only contribution path (where the hook converts TTA→shares on behalf of the LP)
     *      cannot be implemented here because vault.sendTo would fail — the vault has not yet received
     *      any TTA from the LP at the time this hook runs. Such a path would require a CUSTOM
     *      add-liquidity kind where the LP pre-sends TTA to the hook before the vault call.
     */
    function onBeforeAddLiquidity(
        address /*router*/,
        address pool,
        AddLiquidityKind /*kind*/,
        uint256[] memory /*maxAmountsInScaled18*/,
        uint256 /*minBptAmountOut*/,
        uint256[] memory /*balancesScaled18*/,
        bytes memory /*userData*/
    ) external virtual override returns (bool) {
        if (msg.sender != _balancerV3Vault()) return false;
        if (pool != address(this)) return false;
        return true;
    }

    /**
     * @notice Hook executed after add-liquidity operations.
     * @dev Kind-aware state update for virtualTTA and hookSharesDelta.
     *
     *      PROPORTIONAL: proportionally scales virtualTTA and hookSharesDelta by bptOut/totalSupply_pre.
     *        virtualTTA  += bptAmountOut * virtualTTA_pre  / T_pre
     *        hookSharesDelta += bptAmountOut * hookSharesDelta_pre / T_pre (signed)
     *        First-mint case (T_pre == 0): returns early with no state change.
     *
     *      UNBALANCED / SINGLE_TOKEN_EXACT_OUT: increments virtualTTA by the actual TTA scaled18
     *        contributed (amountsInScaled18[ttaIdx]). hookSharesDelta is NOT mutated for the shares
     *        contribution — derived_y (= actualShares - hookSharesDelta) grows naturally as the LP's
     *        shares are credited to the pool's balance, keeping the CP product consistent.
     *        This also means unbalanced TTA adds leave physical TTA sitting in the pool between
     *        operations ("eventual zero TTA" semantics); subsequent TTA→shares swaps or an explicit
     *        sweep will drain it to the Standard Exchange Vault.
     *
     *      DONATION: like UNBALANCED but bptAmountOut == 0; grows virtualTTA by the donated TTA
     *        scaled18 amount. The donated shares side grows actualShares (and thus derived_y)
     *        naturally.
     *
     *      CUSTOM: the hook's own reconcile path is self-bookkeeping. Skip.
     *
     *      Returns (true, amountsInRaw) since enableHookAdjustedAmounts = false.
     */
    function onAfterAddLiquidity(
        address /*router*/, address pool, AddLiquidityKind kind,
        uint256[] memory amountsInScaled18,
        uint256[] memory amountsInRaw,
        uint256 bptAmountOut,
        uint256[] memory /*balancesScaled18*/,
        bytes memory /*userData*/
    ) external virtual override returns (bool, uint256[] memory) {
        if (msg.sender != _balancerV3Vault()) return (false, amountsInRaw);
        if (pool != address(this)) return (false, amountsInRaw);

        if (kind == AddLiquidityKind.PROPORTIONAL) {
            uint256 tPost = IERC20(address(this)).totalSupply();
            uint256 tPre = tPost - bptAmountOut;
            if (tPre == 0) return (true, amountsInRaw); // first-mint case

            uint256 vtPre = Repo._virtualTTA();
            int256 hPre = Repo._hookSharesDelta();

            Repo._setVirtualTTA(vtPre + (bptAmountOut * vtPre) / tPre);
            int256 hAdd = (int256(bptAmountOut) * hPre) / int256(tPre);
            Repo._setHookSharesDelta(hPre + hAdd);
        } else if (
            kind == AddLiquidityKind.UNBALANCED ||
            kind == AddLiquidityKind.SINGLE_TOKEN_EXACT_OUT
        ) {
            // Non-proportional LP adds: virtualTTA grows by the actual TTA contributed
            // (amountsInScaled18[ttaIdx]).  For STANDARD-type TTA tokens there is no rate, so
            // amountsInScaled18 == amountsInRaw (both 18-decimal raw values).
            // hookSharesDelta is left unchanged: the LP's shares contribution is credited to
            // actualShares by the Vault, so derived_y = (actualShares - hookSharesDelta) * r
            // grows by exactly sharesInScaled without any delta adjustment.
            // NOTE: Physical TTA deposited sits in the pool between operations under the
            // "eventual zero TTA" invariant.  The next TTA→shares swap reconcile drains it.
            uint256 ttaIdx = Repo._ttaIndex();
            uint256 ttaInScaled = amountsInScaled18[ttaIdx];
            if (ttaInScaled > 0) {
                Repo._setVirtualTTA(Repo._virtualTTA() + ttaInScaled);
            }
        }
        // DONATION and CUSTOM kinds use a bptAmountOut of 0; the proportional branch above
        // would zero out the delta anyway.  More importantly, DONATION is used internally by
        // _preSeatShares and onAfterSwap to move tokens into the pool as part of swap
        // reconciliation — incrementing virtualTTA in those paths would double-count.
        // DONATION therefore remains a no-op for virtualTTA / hookSharesDelta here.

        return (true, amountsInRaw);
    }

    /// @dev Not used (shouldCallBeforeRemoveLiquidity = false). Returns false.
    function onBeforeRemoveLiquidity(
        address,
        address,
        RemoveLiquidityKind,
        uint256,
        uint256[] memory,
        uint256[] memory,
        bytes memory
    ) external virtual override returns (bool) {
        return false;
    }

    /**
     * @notice Hook executed after remove-liquidity operations.
     * @dev Scales virtualTTA and hookSharesDelta proportionally by the BPT redeemed.
     *      If T_pre = 0, returns early. Otherwise:
     *      Deduction = bptAmountIn * virtualTTA_pre / T_pre
     *      virtualTTA -= min(Deduction, virtualTTA_pre) [clamp at zero]
     *      hookSharesDelta -= bptAmountIn * hookSharesDelta_pre / T_pre (signed)
     *      Returns (true, amountsOutRaw) since enableHookAdjustedAmounts = false.
     */
    function onAfterRemoveLiquidity(
        address /*router*/, address pool, RemoveLiquidityKind /*kind*/,
        uint256 bptAmountIn,
        uint256[] memory /*amountsOutScaled18*/,
        uint256[] memory amountsOutRaw,
        uint256[] memory /*balancesScaled18*/,
        bytes memory /*userData*/
    ) external virtual override returns (bool, uint256[] memory) {
        if (msg.sender != _balancerV3Vault()) return (false, amountsOutRaw);
        if (pool != address(this)) return (false, amountsOutRaw);
        uint256 tPost = IERC20(address(this)).totalSupply();
        uint256 tPre = tPost + bptAmountIn;
        if (tPre == 0) return (true, amountsOutRaw);

        uint256 vtPre = Repo._virtualTTA();
        int256 hPre = Repo._hookSharesDelta();

        uint256 vtSub = (bptAmountIn * vtPre) / tPre;
        Repo._setVirtualTTA(vtSub >= vtPre ? 0 : vtPre - vtSub);

        int256 hSub = (int256(bptAmountIn) * hPre) / int256(tPre);
        Repo._setHookSharesDelta(hPre - hSub);

        return (true, amountsOutRaw);
    }

    /**
     * @notice Hook executed before each swap.
     * @dev For shares→TTA swaps (indexIn == sharesIndex): performs the pre-seat operation that
     *      redeems virtual TTA from the Standard Exchange Vault and seats it in the Balancer pool
     *      before the swap math runs. This ensures the Vault has real TTA to deliver.
     *      For TTA→shares swaps (indexIn == ttaIndex): no-op; reconciliation is done in onAfterSwap.
     */
    function onBeforeSwap(PoolSwapParams calldata params, address pool)
        public virtual override returns (bool)
    {
        if (msg.sender != _balancerV3Vault()) return false;
        if (pool != address(this)) return false;

        uint256 ttaIdx = Repo._ttaIndex();
        if (params.indexIn == ttaIdx) {
            // TTA->shares: post-swap reconcile (Task 9) handles it; nothing to do here.
            return true;
        }

        // shares->TTA: pre-seat TTA into the pool before swap math runs.
        _preSeatShares(params, pool);
        return true;
    }

    /* ----- Internal helpers ----- */

    /**
     * @dev Executes the TTA→shares post-swap reconcile using exchangeOut (target output).
     *      Extracted to avoid stack-too-deep in onAfterSwap.
     *
     *      Algorithm:
     *      1. Drain X_raw TTA from Balancer Vault to this hook.
     *      2. Call seVault.exchangeOut(TTA, X_raw, shares, sharesOut, vault) to mint exactly
     *         sharesOut shares to the Balancer Vault, consuming X_used ≤ X_raw TTA.
     *      3. Settle the minted shares into the Vault.
     *      4. If ttaSurplus = X_raw - X_used > 0: transfer surplus TTA to Vault and settle.
     *      5. DONATE [ttaSurplus, sharesOut] into pool — surplus TTA stays per "eventual zero TTA";
     *         sharesOut restores pool's shares balance (swap took them for the user).
     *      6. CUSTOM removeLiquidity [X_raw, 0] — zeroes out the swap-added TTA in pool balance.
     *      7. virtualTTA += X_raw; hookSharesDelta += sharesOut.
     *
     *      End-state invariants (for the Balancer Vault's delta accounting within the unlock):
     *      - delta[TTA] = 0: swap added X_raw (user's input), hook drained X_raw via sendTo.
     *      - delta[shares] = 0: swap owed sharesOut to user, seVault minted sharesOut to vault,
     *        hook settled them. User router sendTo handles delivery to user.
     *      - pool.actualTTA = ttaSurplus (may be > 0 per eventual-zero-TTA semantics).
     *      - pool.actualShares = unchanged (donation added sharesOut, swap had removed sharesOut).
     */
    function _reconcileTTAToShares(uint256 X_raw, uint256 sharesOut) internal {
        IVault vault = IVault(_balancerV3Vault());
        IStandardExchange seVault = Repo._standardExchangeVault();
        IERC20 ttaTok = Repo._ttaToken();
        IERC20 shareTok = Repo._shareToken();
        uint256 ttaIdx = Repo._ttaIndex();
        uint256 sharesIdx = Repo._sharesIndex();

        // 1) Drain the full X_raw TTA the swap added to the pool into this hook.
        vault.sendTo(ttaTok, address(this), X_raw);

        // 2) Approve SE vault for up to X_raw TTA; tell it to mint EXACTLY sharesOut shares
        //    to the Balancer Vault, consuming ≤ X_raw TTA. Returns X_used ≤ X_raw.
        ttaTok.approve(address(seVault), X_raw);
        uint256 X_used = seVault.exchangeOut(
            ttaTok, X_raw, shareTok, sharesOut, address(vault), false, block.timestamp
        );
        if (X_used == 0) revert IStandardExchangeBufferPool.PostSwapDepositFailed(X_raw);
        // Guard: SE vault must not consume more than the approved maximum.
        if (X_used > X_raw) revert IStandardExchangeBufferPool.PostSwapDepositFailed(X_raw);

        // 3) Credit the Balancer Vault for the minted shares.
        //
        //    The donation in step 5 cannot debit the hook by the full `sharesOut`: Balancer V3
        //    round-trips raw → scaled18 → raw using floor/ceil, and for rate providers that
        //    return a value far below 1e18 (e.g. the V2 SE Vault with decimal-offset shares)
        //    the recovered raw is strictly less than `sharesOut`.  We compute that round-trip
        //    target up-front, cap the settle credit at the same value, and bump
        //    `hookSharesDelta` by it below.  The leftover (`sharesOut - donationRaw`) remains
        //    in the Balancer Vault's free balance — see Vault.sol:148-165 ("we simply discard
        //    the leftover by considering the given hint as the amount paid").  This is the
        //    inherent precision loss when the rate provider's rate << 1e18; on identity-rate
        //    providers (rate == 1e18) `donationRaw == sharesOut` and no leftover arises.
        uint256 donationRaw = _bv3SharesDonationRaw(sharesOut);
        vault.settle(shareTok, donationRaw);

        // 4) If surplus TTA remains, send it back to the Balancer Vault and settle it so that
        //    the donation in step 5 can move it into the pool's balance.
        uint256 ttaSurplus = X_raw - X_used;
        if (ttaSurplus > 0) {
            ttaTok.transfer(address(vault), ttaSurplus);
            vault.settle(ttaTok, ttaSurplus);
        }

        // 5) DONATE [ttaSurplus, sharesOut] into pool.  Balancer V3 will recompute the shares
        //    amountInRaw as `donationRaw` via its scale-round-trip, matching the settle credit
        //    in step 3.  Passing `sharesOut` (rather than `donationRaw`) as maxAmountsIn is
        //    benign — the recovered amountInRaw is `≤ sharesOut`, satisfying the AmountInAboveMax
        //    guard — and keeps the call shape symmetric with the swap's output amount.
        {
            uint256[] memory addAmts = new uint256[](2);
            addAmts[ttaIdx] = ttaSurplus;
            addAmts[sharesIdx] = sharesOut;
            vault.addLiquidity(_buildAddLiquidityParams(address(this), addAmts, 0, AddLiquidityKind.DONATION));
        }

        // 6) Remove the swap-added TTA from pool's balance (net TTA = ttaSurplus after donation).
        {
            uint256[] memory remAmts = new uint256[](2);
            remAmts[ttaIdx] = X_raw;
            vault.removeLiquidity(_buildRemoveLiquidityParams(address(this), 0, remAmts, RemoveLiquidityKind.CUSTOM));
        }

        // 7) Update state.
        //    virtualTTA += X_raw: the full swap amount increases the pool's virtual TTA depth.
        //    hookSharesDelta += donationRaw: the donation actually credited `donationRaw` raw
        //    shares to pool.balance (not `sharesOut` — see step 3).  Using `donationRaw` here
        //    keeps `derivedY = actualSharesScaled - lift(hookSharesDelta)` at the CP-expected
        //    post-swap value `D_initial_scaled - sharesOutScaled`.
        Repo._setVirtualTTA(Repo._virtualTTA() + X_raw);
        Repo._setHookSharesDelta(Repo._hookSharesDelta() + int256(donationRaw));
    }

    /**
     * @dev Executes the shares→TTA pre-seat operation.
     *      Extracted to avoid stack-too-deep in onBeforeSwap.
     *
     *      Algorithm:
     *      1. Compute Y_TTA (fee-adjusted): the TTA amount the CP formula will produce for the
     *         given shares input. The swap fee is subtracted from the scaled18 input to match
     *         what onSwap will see (the Vault deducts fees before calling onSwap).
     *      2. Query how many shares S are needed to redeem Y_TTA from the SE Vault.
     *      3. Drain S shares from the Balancer Vault to this hook; exchange for Y_TTA via seVault.
     *      4. Settle + DONATE the Y_TTA into the pool so the swap has real TTA to deliver.
     *      5. removeLiquidity(S shares) to decrement the pool's raw shares balance.
     *      6. Update hookSharesDelta -= S (keeps derivedY stable for onSwap despite step 5).
     *      7. Store S in pendingPreSeatS; decrement virtualTTA in onAfterSwap (after swap math).
     */
    function _preSeatShares(PoolSwapParams calldata params, address pool) internal {
        uint256 x = Repo._virtualTTA();
        if (x == 0) revert IStandardExchangeBufferPool.PoolTTASideExhausted();

        uint256 y = _derivedY(params.balancesScaled18);
        if (y == 0) revert IStandardExchangeBufferPool.PoolSharesSideExhausted();

        IVault vault = IVault(_balancerV3Vault());
        IStandardExchange seVault = Repo._standardExchangeVault();

        // Compute Y_TTA using the fee-adjusted input so it matches onSwap's output exactly.
        // The Vault applies FixedPoint.mulUp(amountIn, feePercent) as fee; replicate with Ceil.
        uint256 swapFeePercentage = vault.getStaticSwapFeePercentage(pool);
        uint256 amountInPostFee;
        {
            uint256 feeAmount = Math.mulDiv(params.amountGivenScaled18, swapFeePercentage, 1e18, Math.Rounding.Ceil);
            amountInPostFee = params.amountGivenScaled18 - feeAmount;
        }
        uint256 Y_TTA_raw = (x * amountInPostFee) / (y + amountInPostFee); // assumes 18-dec TTA
        if (Y_TTA_raw > x) revert IStandardExchangeBufferPool.VirtualTTAUnderflow(x, Y_TTA_raw);

        IERC20 shareTok = Repo._shareToken();
        IERC20 ttaTok = Repo._ttaToken();

        // 1) Preview the shares needed (S) and align the drain amount with what
        //    `removeLiquidity` will actually return (`drainAmount`).
        //
        //    For rate providers returning rate < 1e18, Balancer V3's
        //    `ceil(sRaw*rate/1e18) → floor(scaled*1e18/rate)` round-trip overshoots:
        //    a removeLiq request for minAmountsOut = S returns `amountOutRaw > S`.
        //    Passing the projected `amountOutRaw` (drainAmount) as both the
        //    `sendTo`/`exchangeOut` amount AND the `minAmountsOut` argument makes the
        //    round-trip self-consistent and balances the Vault's delta accounting.
        //    On identity-rate providers (rate == 1e18) drainAmount == S.
        uint256 S = seVault.previewExchangeOut(shareTok, ttaTok, Y_TTA_raw);
        uint256 drainAmount = _bv3SharesRemoveOutRaw(S);

        // 2) Drain and removeLiquidity BEFORE the exchangeOut.
        //    Ordering matters: the SE Vault's exchangeOut burns shares and drains
        //    underlying reserves, which perturbs the rate provider's quote.  If
        //    removeLiquidity ran AFTER exchangeOut, BV3 would re-read the rate at that
        //    later point and the round-trip `floor(ceil(drainAmount*rate'/1e18)*1e18/rate')`
        //    would diverge from drainAmount.  Running it here, back-to-back with the
        //    sendTo, guarantees both use the same pre-exchange rate.
        vault.sendTo(shareTok, address(this), drainAmount);
        {
            uint256[] memory remAmts = new uint256[](2);
            remAmts[Repo._sharesIndex()] = drainAmount;
            vault.removeLiquidity(_buildRemoveLiquidityParams(address(this), 0, remAmts, RemoveLiquidityKind.CUSTOM));
        }

        // 3) Approve SE Vault and exchangeOut the drained shares for Y_TTA_raw.
        shareTok.approve(address(seVault), drainAmount);
        uint256 sharesConsumed =
            seVault.exchangeOut(shareTok, drainAmount, ttaTok, Y_TTA_raw, address(vault), false, block.timestamp);
        if (sharesConsumed == 0) revert IStandardExchangeBufferPool.PreSeatRedemptionFailed(drainAmount, Y_TTA_raw);

        // 4) Settle TTA received from the SE Vault.
        vault.settle(ttaTok, Y_TTA_raw);

        // 5) If exchangeOut left a surplus of shares (drainAmount - sharesConsumed), return
        //    the surplus to the Vault and settle, capping the settle credit at the
        //    precision-aware DONATION amount so the subsequent debit exactly matches.
        //    This call to _bv3SharesDonationRaw uses the POST-exchange rate (because
        //    exchangeOut has already mutated SE Vault state); the subsequent DONATION will
        //    use the same rate when re-reading via Vault rate-loading, so the values align.
        uint256 sharesSurplus = drainAmount - sharesConsumed;
        uint256 surplusDonationRaw = _bv3SharesDonationRaw(sharesSurplus);
        if (sharesSurplus > 0) {
            shareTok.transfer(address(vault), sharesSurplus);
            vault.settle(shareTok, surplusDonationRaw);
        }

        // 6) DONATE [Y_TTA_raw, sharesSurplus] into pool.  BV3 round-trips the shares amount
        //    to `surplusDonationRaw` (matching step 5's settle credit) and adds Y_TTA_raw
        //    raw TTA (no rate scaling needed for STANDARD-type TTA).
        {
            uint256 ttaIdx = Repo._ttaIndex();
            uint256 sharesIdx_ = Repo._sharesIndex();
            uint256[] memory addAmts = new uint256[](2);
            addAmts[ttaIdx] = Y_TTA_raw;
            addAmts[sharesIdx_] = sharesSurplus;
            vault.addLiquidity(_buildAddLiquidityParams(address(this), addAmts, 0, AddLiquidityKind.DONATION));
        }

        // 7) Update hookSharesDelta to keep derivedY = lift(pool.balance[shares]) -
        //    lift(hookSharesDelta) UNCHANGED for onSwap (which the Vault calls after
        //    onBeforeSwap with `reloadBalancesAndRates`-fresh state).
        //
        //    Net pool.balance[shares] change from this pre-seat:
        //      -drainAmount (removeLiq) + surplusDonationRaw (donation)
        //    => hookSharesDelta -= (drainAmount - surplusDonationRaw)
        //
        //    In the identity-rate case where drainAmount == S and surplusDonationRaw ==
        //    sharesSurplus == S - sharesConsumed, this reduces to the original
        //    `hookSharesDelta -= sharesConsumed` invariant.
        //
        //    virtualTTA is deferred to onAfterSwap so onSwap sees the original x.
        Repo._setHookSharesDelta(Repo._hookSharesDelta() - int256(drainAmount - surplusDonationRaw));
        Repo._setPendingPreSeatS(drainAmount);
    }

    /**
     * @dev Returns the effective shares-side depth used in AMM math, derived from the live balance
     *      minus the hook's accumulated reshuffling offset (hookSharesDelta).
     *      Mirrors StandardExchangeBufferPoolTarget._derivedY.
     */
    function _derivedY(uint256[] memory balancesLiveScaled18) internal view returns (uint256) {
        uint256 sharesIdx = Repo._sharesIndex();
        int256 h = Repo._hookSharesDelta();
        uint256 actualSharesScaled = balancesLiveScaled18[sharesIdx];
        if (h <= 0) {
            // Negative delta means hook added shares — effective depth is larger.
            uint256 add = _liftSharesToScaled18Rated(uint256(-h));
            unchecked { return actualSharesScaled + add; }
        }
        // Positive delta means hook removed shares from the effective pool side.
        uint256 sub = _liftSharesToScaled18Rated(uint256(h));
        if (sub >= actualSharesScaled) return 0;
        unchecked { return actualSharesScaled - sub; }
    }

    /**
     * @dev Converts a raw shares amount to scaled18+rated units, matching Vault's balancesLiveScaled18.
     *      Mirrors StandardExchangeBufferPoolTarget._liftSharesToScaled18Rated.
     */
    function _liftSharesToScaled18Rated(uint256 rawShares) internal view returns (uint256) {
        if (rawShares == 0) return 0;
        uint256 rate = Repo._rateProvider().getRate();
        if (rate == 0) revert IStandardExchangeBufferPool.RateProviderZero();
        uint8 decimals = IERC20Metadata(address(Repo._shareToken())).decimals();
        uint256 scaleFactor = 10 ** (uint256(18) - uint256(decimals));
        return Math.mulDiv(rawShares * scaleFactor, rate, 1e18);
    }

    /**
     * @dev Computes the exact raw shares amount that Balancer V3 will charge as `amountInRaw`
     *      when given `desiredRaw` as `maxAmountsIn[sharesIdx]` for an addLiquidity DONATION (or
     *      any kind that re-derives amountInRaw from scaled).
     *
     *      Balancer V3 applies this round-trip (see Vault.sol:528 and 683):
     *        scaled       = floor(desiredRaw * scaleFactor * rate / 1e18)
     *        amountInRaw  = ceil (scaled * 1e18 / (scaleFactor * rate))
     *
     *      For tokens where `scaleFactor * rate` does not divide cleanly into the scaled-18 grid
     *      (e.g. a rate provider returning a value far below 1e18, as for the V2 SE Vault with
     *      its decimal-offset shares), `amountInRaw < desiredRaw` — the hook's `settle` credit
     *      and the DONATION debit therefore differ unless we anticipate the round-trip and
     *      either (a) cap the `settle` hint to the same value Balancer will derive, or
     *      (b) bump `hookSharesDelta` by `amountInRaw` instead of `desiredRaw`.
     *
     *      For tokens with `rate == 1e18` (typical ERC4626 wrappers like the Aerodrome SE Vault)
     *      this is an identity function.
     */
    function _bv3SharesDonationRaw(uint256 desiredRaw) internal view returns (uint256) {
        if (desiredRaw == 0) return 0;
        uint256 rate = Repo._rateProvider().getRate();
        if (rate == 0) revert IStandardExchangeBufferPool.RateProviderZero();
        uint8 decimals = IERC20Metadata(address(Repo._shareToken())).decimals();
        uint256 denom = (10 ** (uint256(18) - uint256(decimals))) * rate;
        uint256 scaled = (desiredRaw * denom) / 1e18;
        return Math.mulDiv(scaled, 1e18, denom, Math.Rounding.Ceil);
    }

    /**
     * @dev Computes the exact raw shares amount that Balancer V3 will return as `amountOutRaw`
     *      when given `sRaw` as `minAmountsOut[sharesIdx]` for a removeLiquidity CUSTOM with
     *      the buffer-pool's passthrough `onRemoveLiquidityCustom`.
     *
     *      Balancer V3 applies this round-trip (see Vault.sol:764 and 915):
     *        scaled        = ceil (sRaw * scaleFactor * rate / 1e18)   (toScaled18ApplyRateRoundUp)
     *        amountOutRaw  = floor(scaled * 1e18 / (scaleFactor * rate))
     *
     *      For rate providers returning rate < 1e18, the ceil-then-floor pair overshoots:
     *      `amountOutRaw > sRaw` by up to `1e18 / (scaleFactor * rate)` wei.  Aligning the
     *      hook's pre-seat drain amount with this projected output is what keeps the Vault
     *      delta accounting balanced — see `_preSeatShares` step 1.
     */
    function _bv3SharesRemoveOutRaw(uint256 sRaw) internal view returns (uint256) {
        if (sRaw == 0) return 0;
        uint256 rate = Repo._rateProvider().getRate();
        if (rate == 0) revert IStandardExchangeBufferPool.RateProviderZero();
        uint8 decimals = IERC20Metadata(address(Repo._shareToken())).decimals();
        uint256 denom = (10 ** (uint256(18) - uint256(decimals))) * rate;
        uint256 scaled = Math.mulDiv(sRaw, denom, 1e18, Math.Rounding.Ceil);
        return (scaled * 1e18) / denom;
    }

    /**
     * @dev Builds an AddLiquidityParams struct for calling vault.addLiquidity.
     */
    function _buildAddLiquidityParams(
        address to_,
        uint256[] memory maxAmountsIn_,
        uint256 minBptAmountOut_,
        AddLiquidityKind kind_
    ) internal view returns (AddLiquidityParams memory) {
        return AddLiquidityParams({
            pool: address(this),
            to: to_,
            maxAmountsIn: maxAmountsIn_,
            minBptAmountOut: minBptAmountOut_,
            kind: kind_,
            userData: ""
        });
    }

    /**
     * @dev Builds a RemoveLiquidityParams struct for calling vault.removeLiquidity.
     */
    function _buildRemoveLiquidityParams(
        address from_,
        uint256 maxBptAmountIn_,
        uint256[] memory minAmountsOut_,
        RemoveLiquidityKind kind_
    ) internal view returns (RemoveLiquidityParams memory) {
        return RemoveLiquidityParams({
            pool: address(this),
            from: from_,
            maxBptAmountIn: maxBptAmountIn_,
            minAmountsOut: minAmountsOut_,
            kind: kind_,
            userData: ""
        });
    }

    /**
     * @notice Hook executed after each swap.
     * @dev For TTA→shares swaps (tokenIn == ttaToken): performs the post-swap reconcile that
     *      drains the TTA the swap added to the pool, deposits it into the Standard Exchange Vault
     *      to mint shares, credits those shares to the Balancer Vault, then adjusts the pool's
     *      per-pool balances accordingly.
     *      For shares→TTA swaps (tokenIn == shareToken): applies the deferred state update from
     *      onBeforeSwap — decrements virtualTTA by the actual TTA out and hookSharesDelta by the
     *      pre-seat shares S that were stored in pendingPreSeatS.
     *      Always returns the Vault-computed amount unchanged (enableHookAdjustedAmounts = false).
     */
    function onAfterSwap(AfterSwapParams calldata params)
        public virtual override returns (bool, uint256)
    {
        if (msg.sender != _balancerV3Vault()) return (false, params.amountCalculatedRaw);
        if (params.pool != address(this)) return (false, params.amountCalculatedRaw);

        bool ttaIn = (address(params.tokenIn) == address(Repo._ttaToken()));
        if (!ttaIn) {
            // shares->TTA: apply deferred virtualTTA update from onBeforeSwap pre-seat.
            // hookSharesDelta was already decremented by S in onBeforeSwap (to keep derivedY stable
            // for the swap math).  Now we decrement virtualTTA by the actual TTA delivered to the user.
            uint256 actualTTAOut = params.amountCalculatedRaw; // 18-decimal TTA (EXACT_IN)
            // Clear the pending pre-seat flag.
            Repo._setPendingPreSeatS(0);
            // Decrement virtualTTA by the actual TTA delivered to the user.
            uint256 vtNow = Repo._virtualTTA();
            if (actualTTAOut > vtNow) revert IStandardExchangeBufferPool.VirtualTTAUnderflow(vtNow, actualTTAOut);
            Repo._setVirtualTTA(vtNow - actualTTAOut);
            return (true, params.amountCalculatedRaw);
        }

        // TTA->shares post-swap reconcile: extracted to avoid stack-too-deep.
        _reconcileTTAToShares(params.amountInScaled18, params.amountCalculatedRaw);
        return (true, params.amountCalculatedRaw);
    }

    /// @dev Not used (shouldCallComputeDynamicSwapFee = false). Returns (false, 0).
    function onComputeDynamicSwapFeePercentage(PoolSwapParams calldata, address, uint256)
        external view virtual override returns (bool, uint256)
    {
        return (false, 0);
    }
}
