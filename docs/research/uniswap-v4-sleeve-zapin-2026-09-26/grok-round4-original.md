# Grok round-4 original — impact limits, hooks, pretransfer, alignment

**Date:** 2026-09-26. **Author:** Grok (`xai/grok-4.7`). Research only. Prior files unchanged. Numbers below are reasoned defaults, not measured optima. PZ route, post-swap `B`, mint-last, and `F* = floor(T * p / (1e18 + p))` at `p = 0.20e18` stay. Owner overrides: public rebalance may swap up to the protection limit; no discretionary hook whitelist.

## 1. Protection numbers

Separate these. Do not fold fees or the sleeve deadband into “impact.”

| Limit | Default | What it bounds |
|---|---|---|
| Terminal spot impact | **50 bps / call** from that call’s start `sqrtPriceX96` | How far this call may move the pool |
| Same-block cumulative | **100 bps** from the first anchor in the block | Repeated calls must not restart the budget |
| Execution slippage | **10 bps** worse than the fee-inclusive quote at that start price | Fill vs quote, after known LP/protocol/hook fee |
| Fees | excluded | A 30 bps pool fee is not 30 bps of impact |
| Anchor / TWAP | **off** | Optional. If enabled: 100 bps vs a fresh TWAP, else fail closed |
| Alignment loss | **1 bp** unitless (below) | Share-ratio error, not deadband |
| Sleeve deadband | unchanged `max(floor, 5% of F*)` | Placement dust only |

**Why 50/100.** One call can still repair a step. Ten same-block calls at 50 bps from a moving spot would walk about 5%. A shared 100 bps anchor stops that bypass. The next block resets, so a patient caller can still walk the price over many blocks. That residual is why an independent reference exists as an option, not a default. DETF law does not require TWAP. A stale or short-cardinality TWAP must not be treated as fresh.

**Who pays.** Deposit composition still charges the caller: impact and fees shrink `C`. Permissionless repair swaps move incumbent inventory, so fees and impact are socialized across shareholders. That is the cost of the owner’s repeated-rebalance request. Each repair call must reduce unitless skew or increase deployed `L`; otherwise it is a no-op. Do not swap for zero progress.

**Config.** Recommend fee-oracle type default, stored `0` = fall through to these package constants. Not a new admin and not a per-vault owner. Vaults stay on the same cascade as `liquidReservePercentage`.

**Remaining owner choices:** (1) accept 50/100/10 or replace them; (2) cumulative spot budget only, or also require TWAP (recommend off); (3) type-default-plus-fallback versus immutable constants (recommend the cascade).

## 2. Hooks — flags do not prove compatibility

**Fact.** This vault adds and removes liquidity by `poolManager.unlock` → `modifyLiquidity` (`Common.sol` 676–679, 1033–1062). It does not call Universal Router or PositionManager for the managed book.

Universal Router `V4_POSITION_MANAGER_CALL` is mint-oriented. `Dispatcher.sol` (upstream `main`, fetched 2026-09-26) comments “should only call modifyLiquidities() to mint” and calls `_checkV4PositionManagerCall`. That check (`V3ToV4Migrator.sol`, same fetch) reverts `OnlyMintAllowed` for `INCREASE_LIQUIDITY`, `INCREASE_LIQUIDITY_FROM_DELTAS`, `DECREASE_LIQUIDITY`, and `BURN_POSITION`. PositionManager itself still implements increase, decrease, and burn (`v4-periphery` `PositionManager.sol`, fetched 2026-09-26). So UR success at mint is not evidence this vault can remove liquidity, and this vault’s direct path is not an UR allowlist pass.

Hook address bits mark which callbacks are installed, not that the logic is safe or that `msg.sender` / `hookData` match a router. No before/after-add-liquidity flags only means those two callbacks are skipped. Swap flags still run on composition and repair swaps. A simulation is not a future guarantee if the hook is upgradeable or reads external state.

**Owner fallback, applied.** Do not build a whitelist. The deployer-supplied `PoolKey` is assumed executable. Admission is not quote accuracy. Still require settled deltas (`CurrencyNotSettled` / `NonzeroDeltaCount`). If the hook is not in the projectable quote set, do not publish a vanilla amount as exact; execution may proceed under the impact caps and revert on settlement or cap failure.

Sources: https://github.com/Uniswap/universal-router/blob/main/contracts/base/Dispatcher.sol and `contracts/modules/V3ToV4Migrator.sol`; https://github.com/Uniswap/v4-periphery/blob/main/src/PositionManager.sol; Context7 `/uniswap/docs` command `0x14` (2026-09-26). Local UR copy was not in this checkout. Upstream `main` is unpinned.

## 3. Pretransfer — settled, not reopened

Law: eligible contract may claim `amountIn <= U = live balance − local snapshot`. No origin proof. Integrator must atomically push and call. EOA reverts `EOAPretransferNotAllowed` (`BASIC_VAULT_RESERVE_DELTA_PRETRANSFER_PRD.md` lines 21, 35–47, 294–303; `LocalCreditLib.sol` 23–27). Exact-in refunds nothing.

V4 must keep face unbooked `U = balanceOf − (R − deployed)` (`Common.sol` 1281–1284). `BasicVaultCommon` uses `U = B − R` (lines 100–105). If `R` is the economic total, that formula collides with face balance. Credit **before** fee collection or any sync; collecting first inflates `U` and can claim fees as the caller’s push. End of every successful money op syncs the full expected-hold set, including sleeve (`L-RSRV-SYNC-FULL`).

**Code-law gap, not a new product choice:** V4 `_secureTokenTransfer` (`Common.sol` 1270–1288) does not call `requirePretransferCaller`. The guard is required by APEX D9. Absent call is an implementation miss.

## 4. Alignment — best effort, bounded donation

Unitless error, both `B_i > 0`:

```text
q_i = C_i / B_i
e = |q0 − q1| / max(q0, q1)
```

Default: treat `e ≤ 1 bp` (`1e14 / 1e18`) as aligned. Then existing `min` donates at most about that fraction of the larger leg. If no swap inside the impact budget reaches 1 bp, **do not donate the rest**. Skip the swap and mint the raw deposit with the existing single-sided formula. That is best effort, not unlimited surplus. Exact-in does not refund unused input; unswapped input stays in `C` and is absorbed into `R` at end sync. Zero output is a failed swap leg, not a composed success: no one-sided “aligned” mint of a zero counter-token. `minSharesOut` remains an independent share floor. It does not replace the 50/100 bps caps. Partial deployment of a skewed book remains allowed; that residual is placement, not alignment donation.

## 5. Uncertainty

No pool was simulated. 50/100/10/1 are defaults, not fitted. Same-block cap does not stop multi-block walks. Upstream router `main` may differ from a deployed router. Hook execution can still revert or mis-quote after admission.
