// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IPoolLiquidity} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IPoolLiquidity.sol";
import {IStandardExchangeBufferPool} from
    "contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/IStandardExchangeBufferPool.sol";

/**
 * @title StandardExchangeBufferPoolLiquidityTarget
 * @notice IPoolLiquidity implementation for the Standard Exchange Buffer Pool. Provides the
 *         passthrough CUSTOM add/remove paths the hook uses during pre-seat and post-swap
 *         reconcile to move tokens between the Balancer V3 Vault's per-pool balances without
 *         minting or burning BPT.
 *
 * @dev    Why this exists at all
 *         ---------------------------------------------------------------------------------
 *         The hook orchestrates a multi-call dance against the Balancer V3 Vault during every
 *         swap (see `StandardExchangeBufferHookTarget.onBeforeSwap` and `onAfterSwap`). For
 *         shares -> TTA swaps the hook redeems shares for TTA at the Standard Exchange Vault
 *         and needs to:
 *           (a) increase the pool's per-pool TTA balance by Y_TTA_raw without minting BPT, AND
 *           (b) decrease the pool's per-pool shares balance by S without burning BPT.
 *         Step (a) is achievable with `addLiquidity(DONATION)` (Vault directly accepts the
 *         tokens). Step (b) has no DONATION equivalent — there is no "negative donation". The
 *         only way to decrement a per-pool balance without burning BPT is `removeLiquidity`
 *         with `kind = CUSTOM`, where this contract decides the exit amounts and signals
 *         `bptAmountIn = 0`.
 *
 *         The TTA -> shares post-swap reconcile uses the mirror: `addLiquidity(CUSTOM)` to
 *         increase the per-pool shares balance with `bptAmountOut = 0`, paired with
 *         `removeLiquidity(CUSTOM)` to decrement TTA. (We prefer DONATION when adding, but
 *         CUSTOM is also valid — it's the *remove* side that has no alternative.)
 *
 * @dev    Why the body is a passthrough
 *         ---------------------------------------------------------------------------------
 *         All math is done by the hook before it calls `Vault.addLiquidity(CUSTOM)` /
 *         `removeLiquidity(CUSTOM)`. The hook has already decided the exact `amountsIn` /
 *         `amountsOut` it wants the Vault to accept and which side to debit/credit. This
 *         facet's job is just to confirm those amounts and report zero BPT delta.
 *
 *         The `maxAmountsInScaled18` / `minAmountsOutScaled18` parameters are the amounts the
 *         hook specified in the call to the Vault. We return them as the authoritative
 *         `amountsInScaled18` / `amountsOutScaled18` for the Vault to settle against.
 *
 * @dev    Why the `router != address(this)` check is critical (especially for remove)
 *         ---------------------------------------------------------------------------------
 *         The Vault forwards `msg.sender` of the call to `Vault.addLiquidity` /
 *         `Vault.removeLiquidity` as the `router` argument. See Balancer V3 Vault.sol:
 *
 *           lib/daosys/lib/crane/contracts/external/balancer/v3/vault/contracts/Vault.sol
 *           lines 648-659  (AddLiquidityKind.CUSTOM dispatch, `msg.sender` on line 654)
 *           lines 882-892  (RemoveLiquidityKind.CUSTOM dispatch, `msg.sender` on line 887)
 *
 *         Vault.sol comment at 651/884: "Uses msg.sender as the Router (the contract that
 *         called the Vault)."
 *
 *         Our hook lives at the same address as the pool (registered with `hooksContract ==
 *         pool`). When the hook's facet code (executing in the pool Diamond's context)
 *         invokes `vault.addLiquidity(...)` or `vault.removeLiquidity(...)`, the EVM treats
 *         the pool Diamond as `msg.sender` at the Vault. The Vault forwards that as
 *         `router`, so `router == pool address`. This facet also runs in the pool Diamond,
 *         so `address(this) == pool address`. Therefore `router == address(this)` only when
 *         the call originates from our own hook.
 *
 *         Without the check the `removeLiquidity(CUSTOM)` path would be a public drain:
 *           1. Attacker calls `Vault.removeLiquidity({pool, kind: CUSTOM, maxBptAmountIn: 0,
 *              minAmountsOut: [arbitrary, arbitrary], ...})` via any router or inside their
 *              own unlock session.
 *           2. Vault calls this facet's `onRemoveLiquidityCustom(router=attackerRouter, 0,
 *              [arbitrary, arbitrary], ...)`.
 *           3. Without the gate, this facet returns `(0, [arbitrary, arbitrary], ...)`.
 *           4. Vault burns 0 BPT and supplies the attacker a credit of `[arbitrary,
 *              arbitrary]`. They `sendTo` it out and the pool is drained.
 *         The gate makes step 3 revert with `NotHookCaller(attacker)`.
 *
 *         The add side is a softer concern: a passthrough `onAddLiquidityCustom` from an
 *         external caller is functionally equivalent to `addLiquidity(DONATION)` (caller
 *         supplies tokens, gets no BPT), which our LiquidityManagement already permits via
 *         `enableDonation = true`. The check is symmetric primarily for hygiene and to
 *         ensure consistency if the body grows non-passthrough logic later.
 *
 * @dev    Why the Balancer V3 PoolMock doesn't have this check
 *         ---------------------------------------------------------------------------------
 *         The reference `PoolMock` at
 *
 *           lib/daosys/lib/crane/contracts/external/balancer/v3/vault/contracts/test/PoolMock.sol
 *           lines 57-75
 *
 *         ignores its `router` argument (`address,` — unnamed). That's safe for PoolMock
 *         because it's a Vault test fixture with no protected reserves and is meant to
 *         exercise dispatch paths permissively. Production `IPoolLiquidity` implementations
 *         with passthrough math must add the equivalent gate.
 */
contract StandardExchangeBufferPoolLiquidityTarget is IPoolLiquidity {
    /**
     * @notice CUSTOM add-liquidity entry point. Accepts the caller-supplied amounts at face
     *         value and returns zero BPT minted. Restricted to the pool's own hook via the
     *         `router == address(this)` gate.
     * @param  router                  msg.sender of the originating `Vault.addLiquidity` call,
     *                                 forwarded by the Vault. Must equal `address(this)` (the
     *                                 pool/hook Diamond address) — see contract NatSpec for
     *                                 the threat model.
     * @param  maxAmountsInScaled18    The exact amounts the hook wants credited to per-pool
     *                                 balances, in scaled-18 + rate-adjusted units. We return
     *                                 these unchanged as the authoritative `amountsInScaled18`.
     */
    function onAddLiquidityCustom(
        address router,
        uint256[] memory maxAmountsInScaled18,
        uint256 /*minBptAmountOut*/,
        uint256[] memory /*balancesScaled18*/,
        bytes memory /*userData*/
    )
        external override
        returns (uint256[] memory amountsInScaled18, uint256 bptAmountOut, uint256[] memory swapFeeAmountsScaled18, bytes memory returnData)
    {
        // Reject any caller that isn't the hook itself. `router` is the msg.sender at the
        // Vault (Vault.sol:654); `address(this)` is the pool/hook Diamond address. Only the
        // hook's internal reconcile path produces a match.
        if (router != address(this)) revert IStandardExchangeBufferPool.NotHookCaller(router);

        // Pass through the hook-specified amounts. The hook already computed these against
        // the Standard Exchange Vault's exchange rate; no further validation needed here.
        amountsInScaled18 = maxAmountsInScaled18;
        // No BPT is minted: this path exists to update per-pool balances without changing
        // BPT supply. virtualTTA / hookSharesDelta are kept in sync by the hook itself.
        bptAmountOut = 0;
        swapFeeAmountsScaled18 = new uint256[](maxAmountsInScaled18.length);
        returnData = "";
    }

    /**
     * @notice CUSTOM remove-liquidity entry point. Returns the caller-supplied amounts at
     *         face value with zero BPT burned. Restricted to the pool's own hook via the
     *         `router == address(this)` gate.
     * @dev    This is the security-critical surface: without the router gate, any caller
     *         could specify arbitrary `minAmountsOut`, receive a Vault credit for those
     *         amounts (burning 0 BPT), and drain the pool. The gate enforces hook-only
     *         access — see contract NatSpec.
     * @param  router                  msg.sender of the originating `Vault.removeLiquidity`
     *                                 call. Must equal `address(this)`.
     * @param  minAmountsOutScaled18   The exact amounts the hook wants debited from per-pool
     *                                 balances, in scaled-18 + rate-adjusted units.
     */
    function onRemoveLiquidityCustom(
        address router,
        uint256 /*maxBptAmountIn*/,
        uint256[] memory minAmountsOutScaled18,
        uint256[] memory /*balancesScaled18*/,
        bytes memory /*userData*/
    )
        external override
        returns (uint256 bptAmountIn, uint256[] memory amountsOutScaled18, uint256[] memory swapFeeAmountsScaled18, bytes memory returnData)
    {
        // Hook-only gate. See contract NatSpec for the drain attack this prevents.
        if (router != address(this)) revert IStandardExchangeBufferPool.NotHookCaller(router);

        // No BPT is burned: this path lets the hook decrement per-pool balances (e.g. drain
        // shares the hook redeemed at the Standard Exchange Vault) without affecting BPT
        // supply or LP positions.
        bptAmountIn = 0;
        amountsOutScaled18 = minAmountsOutScaled18;
        swapFeeAmountsScaled18 = new uint256[](minAmountsOutScaled18.length);
        returnData = "";
    }
}
