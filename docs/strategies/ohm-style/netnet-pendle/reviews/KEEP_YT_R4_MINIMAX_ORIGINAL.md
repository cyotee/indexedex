# MiniMax M3 — KEEP_YT_R4 first pass

- Identity: `minimax/MiniMax-M3` (council-minimax, independent). Provider attestation: not claimed.
- Source: PRD v0.14, REQUIREMENTS_QUESTIONS.md, `NETNET_PENDLE_OPERATION_MATRIX.md`, `CLAUDE.md`, `lib/crane/contracts/protocols/perps/pendle/router/ActionAddRemoveLiqV3.sol`, `ActionBase.sol`, `IPActionAddRemoveLiqV3.sol`. No peer artifacts read. No shell/tests/delegation.

## Practical recommendation

**Use the official Pendle V3 `addLiquiditySingleTokenKeepYt` entry-point at lines 236–303 of `ActionAddRemoveLiqV3.sol` as the single canonical Keep-YT primitive.** It is **atomic internal split, not a swap+deposit loop.** The flow is: (1) `_mintSyFromToken(input)` mints SY once from the input; (2) `netSyMintPy = (netSyIn × state.totalPt) / (state.totalPt + pyIndex.syToAsset(state.totalSy))` (line 286) — a formula proportional to current LP composition; (3) `_transferOut(SY, YT, netSyMintPy)` + `YT.mintPY(market, receiver)` produces `netYtOut` PT and YT simultaneously with the YT sent to receiver; (4) `_transferOut(SY, market, netSyAddLiquidity)` and `IPMarket.mint(receiver, netSyAddLiquidity, netYtOut)` produces LP. No AMM swap is invoked. Minima: `minLpOut`, `minYtOut` enforced separately (lines 301–302). The reciprocal single-side YT exit and PT-side exits exist as `removeLiquiditySinglePt`, `removeLiquiditySingleToken` and the `KeepYt` mirror at the Pendle router.

## Conditional preference vs final atomic selection

**Conditional preference.** A multi-hop split is **not** used by the canonical router. **Final atomic selection** of the entry-point name and the storage shape is still engineer work; the contract-level decision is independent of the multi-hop question.

## Loops do not help

Splitting a Keep-YT join into multiple smaller `_mintSyFromToken` → `addLiquiditySingleTokenKeepYt` cycles adds:
- gas: each cycle is a full `mintSY` + `mintPY` + LP-mint triple;
- price impact: the formula at line 286 reads `_readMarket(market).totalPt` / `pyIndex.syToAsset(totalSy)` once per call; multiple cycles each read a slightly shifted post-state, giving a different YT/PY split than the original single call;
- minOut slippage checks (`minLpOut`, `minYtOut`) accumulate, increasing revert probability.

A single call with the user's intended `netSyIn` already gives the correct accounting split. Repeating it does not converge to a better split than the first call. **Do not invent a per-loop hook.** The router-level single primitive is sufficient.

## Old/new SY conversions on rollover

Each Pendle market has its own SY, PT, YT addresses ([`PendleYieldContractFactory`](lib/crane/contracts/protocols/perps/pendle/core/YieldContracts/PendleYieldContractFactory.sol), already confirmed in earlier rounds). PRD v0.14 §11 selects:
- factory-first validation via the configured `PendleFactoryAwareRepo` (preserved in matrix row 01b);
- new SY permitted across rollovers;
- **stable underlying/SY identity** — i.e. `SY.assetInfo()` matches across old/new SY, not literal address equality (matrix row 42 line 55).

Practical implication for the custom hook's `rollover(targetMarket)`:
- If old SY `assetInfo()` (underlying, decimals, yieldToken semantics) equals new SY `assetInfo()`, **no token conversion is required** — old-market LP redemption proceeds to underlying, new-market `addLiquidityDualTokenAndPt` proceeds from underlying to LP. This is the Pendle V3 standard path.
- If `assetInfo()` differs (new wrapper), underlying conversion is required and incurs tax on NET legs in our custom V2 SE; documented per hop. PRD §8 mandates per-hop predicates.
- "Old/new SY accounting" (PRD v0.14 title) means the hook bookkeeping must distinguish: (a) `oldSY_LP` redeemed into its own SY's underlying/assetInfo; (b) `newSY_LP` minted from that same underlying. The cross-SY rebase conversion, if `assetInfo()` differs, must be modeled as an actual token swap, not as an internal ledger entry.

**Empty target edge.** A new market with zero LP requires a full-book first join (R51, §10.4: G/U/B/R formula). The `addLiquidityDualTokenAndPt` / `addLiquiditySingleTokenKeepYt` math assumes the AMM invariant exists; on an empty target, `state.totalPt`/`totalSy` zero — division-by-zero hazard. Engineering must initialize the target's first position using the explicit full-book join (a dual-token entry), not Keep-YT, until the AMM invariant is non-zero.

## Expired market removal edge

`isExpired()` is checked at `removeLiquiditySingleSy` (line 418); expired market → `__removeLpToSyAfterExpiry` (line 426) which burns LP and redeems YT in one path. PRD R10: "Expired-market LP deposits are blocked. The protocol retains underlying mature-PT realization and historical claim handling; funded staking/bond token claims remain." For rollover, the source market must be expired before `rollover(targetMarket)` proceeds; the function reverts while current market active (R09). A target with `expiry <= block.timestamp` must also revert per R09 "rejects incompatible successor" logic. Live deployments on Robinhood should verify `BOND_EPOCH_CAP_BPS` and exact divisor values before any mass-rollover deployment; current pin is the local snapshot only.

## Practical recommendation summary

1. Use `addLiquiditySingleTokenKeepYt` once per Keep-YT entry; do not loop.
2. Use `addLiquidityDualTokenAndPt` for full-book initial join (R51 + bootstrap).
3. Rollover path: validate factory recognition first; require equal `assetInfo()` on old/new SY; on differing `assetInfo()`, model as a real swap through the custom V2 SE with per-hop tax predicates.
4. Reject target markets with `expiry <= block.timestamp`.

## At most two economic clarifications (0.5% basis/gate not assumed)

**Q1.** The proposed `0.5% per NET epoch` expansion rate and its basis (per totalSupply, per eligible stakers, per net-acquired LP) are **not selected**. Confirm whether the `0.5%` is a placeholder example, a hard cap (i.e., "≤0.5%"), a target, or a budget; confirm its basis (per totalSupply, per circulating staked sDETF, per hook LP supply); confirm the gate (zero, NET-state synced, or synthetic-premium-closure).

**Q2.** The proposed `1 DETF = 1000 NET` opening-price framing remains a **proposal** (PRD §10.4, last paragraph before policy list, last sentence). Confirm whether any specific opening price is a hard requirement of the deployment, an illustration, or open. PRD §10.4 states "**The proposed 1 NET-equivalent per DETF opening quote remains a proposal, not a selected numeric parameter.**" Either ratify this as the selected opening or treat as UNKNOWN.

## Not owner

- Whether `addLiquiditySingleTokenKeepYt` is the right entry-point name (engineer).
- Exact slippage tolerance per call (engineer).
- Fee oracle lookup keys (settled: hook proxy / DETF instance, R36).
- Old/new SY accounting implementation (engineer; the policy is selected above).
- V2 SE parity selector inventory (engineer; A21).

## Saved

- `docs/strategies/ohm-style/netnet-pendle/reviews/KEEP_YT_R4_MINIMAX_ORIGINAL.md`
- Other files unchanged. No implementation, no shell/tests/delegation, no peer artifacts read. References are not proof of live Robinhood deployment.
