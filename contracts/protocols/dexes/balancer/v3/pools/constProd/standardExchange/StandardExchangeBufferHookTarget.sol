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

        if (!lm.disableUnbalancedLiquidity) return false;
        if (!lm.enableAddLiquidityCustom) return false;
        if (!lm.enableRemoveLiquidityCustom) return false;
        if (!lm.enableDonation) return false;

        return true;
    }

    /* ----- Initialization ----- */

    /**
     * @notice Hook executed before pool initialization.
     * @dev Seeds virtualTTA = s_init * rate / 1e18, and resets hookSharesDelta to 0.
     *      Reverts if the rate provider returns zero or the resulting virtualTTA is zero.
     */
    function onBeforeInitialize(uint256[] memory exactAmountsIn, bytes memory)
        external virtual override returns (bool)
    {
        if (msg.sender != _balancerV3Vault()) return false;
        uint256 sharesIdx = Repo._sharesIndex();
        uint256 sInitRaw = exactAmountsIn[sharesIdx];
        uint256 rate = Repo._rateProvider().getRate();
        if (rate == 0) revert IStandardExchangeBufferPool.RateProviderZero();
        // Assumes 18-decimal share token; multi-decimal handling added if needed.
        uint256 virtualInit = (sInitRaw * rate) / 1e18;
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
     * @dev Only PROPORTIONAL and CUSTOM add-liquidity kinds are permitted.
     *      CUSTOM is the hook's own reconcile path and is returned as a no-op.
     *      PROPORTIONAL with no TTA contribution (maxAmountsInScaled18[ttaIdx] == 0) is also a no-op.
     *      PROPORTIONAL with TTA contribution: drains the LP's TTA, deposits it into the Standard
     *      Exchange Vault to mint shares, credits the minted shares to the Balancer Vault, then
     *      adjusts the pool's per-pool balances accordingly (remove TTA side, add shares side).
     *      Updates hookSharesDelta += Y' to track the hook's net shares inflow.
     */
    function onBeforeAddLiquidity(
        address /*router*/,
        address pool,
        AddLiquidityKind kind,
        uint256[] memory maxAmountsInScaled18,
        uint256 /*minBptAmountOut*/,
        uint256[] memory /*balancesScaled18*/,
        bytes memory /*userData*/
    ) external virtual override returns (bool) {
        if (msg.sender != _balancerV3Vault()) return false;
        if (pool != address(this)) return false;
        if (kind == AddLiquidityKind.UNBALANCED || kind == AddLiquidityKind.SINGLE_TOKEN_EXACT_OUT) {
            revert IStandardExchangeBufferPool.AddLiquidityNotProportional();
        }
        if (kind == AddLiquidityKind.CUSTOM || kind == AddLiquidityKind.DONATION) return true; // hook's own reconcile path / vault donation

        uint256 ttaIdx = Repo._ttaIndex();
        uint256 sharesIdx = Repo._sharesIndex();
        uint256 ttaIn = maxAmountsInScaled18[ttaIdx];
        if (ttaIn == 0) return true; // shares-only contribution; nothing to convert

        // Convert LP's TTA into shares via Standard Exchange Vault and reconcile pool balances.
        IVault vault = IVault(_balancerV3Vault());
        IStandardExchange seVault = Repo._standardExchangeVault();
        IERC20 ttaTok = Repo._ttaToken();
        IERC20 shareTok = Repo._shareToken();

        vault.sendTo(ttaTok, address(this), ttaIn);
        ttaTok.approve(address(seVault), ttaIn);
        uint256 Y_prime = seVault.exchangeIn(ttaTok, ttaIn, shareTok, 0, address(vault), false, block.timestamp);
        if (Y_prime == 0) revert IStandardExchangeBufferPool.PostSwapDepositFailed(ttaIn);
        vault.settle(shareTok, Y_prime);

        uint256[] memory remAmts = new uint256[](2);
        remAmts[ttaIdx] = ttaIn;
        vault.removeLiquidity(_buildRemoveLiquidityParams(address(this), 0, remAmts, RemoveLiquidityKind.CUSTOM));

        uint256[] memory addAmts = new uint256[](2);
        addAmts[sharesIdx] = Y_prime;
        vault.addLiquidity(_buildAddLiquidityParams(address(this), addAmts, 0, AddLiquidityKind.DONATION));

        Repo._setHookSharesDelta(Repo._hookSharesDelta() + int256(Y_prime));
        return true;
    }

    /**
     * @notice Hook executed after add-liquidity operations.
     * @dev Scales virtualTTA and hookSharesDelta proportionally by the BPT minted.
     *      If T_pre = 0 (first mint), returns early. Otherwise:
     *      virtualTTA += bptAmountOut * virtualTTA_pre / T_pre
     *      hookSharesDelta += bptAmountOut * hookSharesDelta_pre / T_pre (signed)
     *      Returns (true, amountsInRaw) since enableHookAdjustedAmounts = false.
     */
    function onAfterAddLiquidity(
        address /*router*/, address pool, AddLiquidityKind /*kind*/,
        uint256[] memory /*amountsInScaled18*/,
        uint256[] memory amountsInRaw,
        uint256 bptAmountOut,
        uint256[] memory /*balancesScaled18*/,
        bytes memory /*userData*/
    ) external virtual override returns (bool, uint256[] memory) {
        if (msg.sender != _balancerV3Vault()) return (false, amountsInRaw);
        if (pool != address(this)) return (false, amountsInRaw);
        uint256 tPost = IERC20(address(this)).totalSupply();
        uint256 tPre = tPost - bptAmountOut;
        if (tPre == 0) return (true, amountsInRaw); // first-mint case

        uint256 vtPre = Repo._virtualTTA();
        int256 hPre = Repo._hookSharesDelta();

        Repo._setVirtualTTA(vtPre + (bptAmountOut * vtPre) / tPre);
        int256 hAdd = (int256(bptAmountOut) * hPre) / int256(tPre);
        Repo._setHookSharesDelta(hPre + hAdd);

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

        // 1) Preview and drain S shares; exchange for Y_TTA sent to the Balancer Vault.
        uint256 S = seVault.previewExchangeOut(shareTok, ttaTok, Y_TTA_raw);
        vault.sendTo(shareTok, address(this), S);
        shareTok.approve(address(seVault), S);
        uint256 sharesConsumed = seVault.exchangeOut(shareTok, S, ttaTok, Y_TTA_raw, address(vault), false, block.timestamp);
        if (sharesConsumed == 0) revert IStandardExchangeBufferPool.PreSeatRedemptionFailed(S, Y_TTA_raw);

        // 2) Settle + DONATE Y_TTA into the pool's per-pool TTA balance.
        vault.settle(ttaTok, Y_TTA_raw);
        {
            uint256 ttaIdx = Repo._ttaIndex();
            uint256[] memory addAmts = new uint256[](2);
            addAmts[ttaIdx] = Y_TTA_raw;
            vault.addLiquidity(_buildAddLiquidityParams(address(this), addAmts, 0, AddLiquidityKind.DONATION));
        }

        // 3) removeLiquidity to decrement pool's shares balance by S.
        {
            uint256[] memory remAmts = new uint256[](2);
            remAmts[Repo._sharesIndex()] = S;
            vault.removeLiquidity(_buildRemoveLiquidityParams(address(this), 0, remAmts, RemoveLiquidityKind.CUSTOM));
        }

        // 4) Update hookSharesDelta -= S (re-establishes derivedY invariant after removeLiquidity).
        //    virtualTTA is deferred to onAfterSwap so onSwap sees the original x.
        Repo._setHookSharesDelta(Repo._hookSharesDelta() - int256(S));
        Repo._setPendingPreSeatS(S);
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

        // TTA->shares post-swap reconcile.
        IVault vault = IVault(_balancerV3Vault());
        IStandardExchange seVault = Repo._standardExchangeVault();
        IERC20 ttaTok = Repo._ttaToken();
        IERC20 shareTok = Repo._shareToken();

        uint256 X_raw = params.amountInScaled18; // assumes 18-decimal TTA
        uint256 ttaIdx = Repo._ttaIndex();
        uint256 sharesIdx = Repo._sharesIndex();

        // 1) Drain the X TTA the swap just added to the pool.
        vault.sendTo(ttaTok, address(this), X_raw);

        // 2) Approve Standard Exchange Vault for X TTA; deposit to mint Y' shares to Balancer Vault.
        ttaTok.approve(address(seVault), X_raw);
        uint256 Y_prime = seVault.exchangeIn(ttaTok, X_raw, shareTok, 0, address(vault), false, block.timestamp);
        if (Y_prime == 0) revert IStandardExchangeBufferPool.PostSwapDepositFailed(X_raw);

        // 3) Credit the Balancer Vault for the newly minted shares.
        vault.settle(shareTok, Y_prime);

        // 4) Decrement pool's per-pool TTA balance back to zero.
        uint256[] memory remAmts = new uint256[](2);
        remAmts[ttaIdx] = X_raw;
        vault.removeLiquidity(_buildRemoveLiquidityParams(address(this), 0, remAmts, RemoveLiquidityKind.CUSTOM));

        // 5) Add the minted shares to the pool's per-pool shares balance.
        uint256[] memory addAmts = new uint256[](2);
        addAmts[sharesIdx] = Y_prime;
        vault.addLiquidity(_buildAddLiquidityParams(address(this), addAmts, 0, AddLiquidityKind.DONATION));

        // 6) Update state.
        Repo._setVirtualTTA(Repo._virtualTTA() + X_raw);
        Repo._setHookSharesDelta(Repo._hookSharesDelta() + int256(Y_prime));

        return (true, params.amountCalculatedRaw);
    }

    /// @dev Not used (shouldCallComputeDynamicSwapFee = false). Returns (false, 0).
    function onComputeDynamicSwapFeePercentage(PoolSwapParams calldata, address, uint256)
        external view virtual override returns (bool, uint256)
    {
        return (false, 0);
    }
}
