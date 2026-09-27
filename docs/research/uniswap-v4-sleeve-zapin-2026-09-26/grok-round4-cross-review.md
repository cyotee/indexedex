# Grok round-4 cross-review

**Date:** 2026-09-27. **Author:** Grok (`xai/grok-4.7`). Originals preserved. Peers are untrusted evidence. No peer cross-reviews read. No new external API claim.

Owner overrides stand: repeated bounded public repair swaps supersede the old swap-free public-rebalance rule; deployer assumes PoolKey compatibility if flags cannot prove it; pretransfer is settled reserve-delta law, not provenance.

## Corrections

**MiniMax contradicts the owner on repair swaps.** Sections 4–5 say `rebalanceLiquidReserve` never swaps and permissionless repair is out of scope. That is the superseded rule. Repair swaps are in scope, spend incumbent inventory, mint no shares, and socialize fees and impact. Deposit swaps still spend only the credited caller basket.

**`1e-4` is 1 bp, not 10.** MiniMax §3 calls `1e-4` both 10 bps and 0.01%. `1e-4 = 1 bp = 0.01%`. `10 bps = 1e-3`. Do not adopt their “10 bps alignment” label.

**Do not add `≥ 2 × LP fee` to a fee-inclusive quote.** Kimi’s execution headroom `max(2 × fee tier, 10 bps)` double-counts a fee the quote already includes. Astra is right: 10 bp is adverse fill versus that quote, not a second fee allowance.

**Do not apply 50 bp to `sqrtPriceX96`.** Astra: price `P` moves about twice a sqrt-price move. Grok round-4’s “50 bps from start sqrt price” overstates the price cap. State the cap on price, not sqrt price.

**`deployed > 0` does not prove over-credit.** MiniMax’s example (`B0=50`, `R=100`, `deployed=80`, `U=30`) is not a consistent sync. V4 `R` is an economic total (`Common.sol` 605–623: face plus deployed plus uncollected fees). Subtracting **current** deployed from that `R` matches face book only at the sync instant. After price or fee drift it is not a durable local snapshot (`BasicVaultRepo.sol` 25–27). It can over- or under-size `U`. Forcing `U = B − R` while `R` still includes deployed would reject legitimate face pushes. The fix is a face snapshot, not a blind BasicVault formula on economic `R`.

**EOA guard and end-sync, from the call chain.** `InTarget.exchangeIn` (37–65) calls `_secureTokenTransfer` and does not call `LocalCreditLib.requirePretransferCaller`. The override (`Common.sol` 1270–1288) does not either. The guard exists on other packages (for example `UniswapV4FullSpreadStandardExchangeVaultCommon.sol` 1223) and in `LocalCreditLib.sol` 23–27. Absence on this SE path is a code-law gap, not a new provenance rule. End-sync is not universally missing: direct swap syncs at `InBase.sol` 85, then rebalances. Zap-in syncs at 307, then tail-rebalances at 309–311. Rebalance syncs only if `moved` (`Common.sol` 808–810). MiniMax’s claim that direct swap never syncs is false. The real gap is sync-before-later mutation, and booking economic totals instead of face balances.

**Withdraw Grok’s silent single-sided fallback.** If the deposit swap cannot meet the alignment bound, do not mint with invariant growth. That changes share law. Best effort means bounded repair progress and a disclosed placement residual, not a different issuance branch. Astra’s revert-on-deposit / stop-on-repair split is the one that preserves PZ-5. Kimi’s “exceeding tolerance reverts, never mint the donated result” matches the deposit side. An absolute-floor escape from the relative bound can allow a large fractional donation on a tiny basket. Do not add that escape.

**Hooks.** No disagreement on the source facts. UR `main` `_checkV4PositionManagerCall` rejects increase, increase-from-deltas, decrease, and burn (moderator-confirmed; Grok and Kimi fetched it). PositionManager itself supports those actions. Upstream `main` warns delta-derived mint/increase lack a minimum-liquidity bound. That is a periphery warning, not a claim this vault uses those paths. This vault calls `modifyLiquidity` with an explicit liquidity amount. Flags mark callbacks, not arbitrary behavior. No whitelist. Admission is not a vanilla quote: non-projectable hooks must not be reported as exact. Settlement and caps still apply.

## Recommended defaults (non-empirical)

| Control | Proposal |
|---|---|
| Per-call price move | **25 bp** on price `P`, not on sqrt price. 50 bp is the looser alternative, still on `P`. |
| Fee-inclusive fill | **10 bp** worse than the same-state quote. Do not add `2 × fee`. |
| Aggregate budget | **100 bp gross** price travel per vault per 30-minute window, both directions, not netted. Plus gross input turnover, Astra’s **10% of each token’s window-start book**, so round-trips cannot churn inside a flat net price. |
| Alignment | **1 bp = `1e-4`**, realized uncompensated fraction `max_i(1 − m·B_i/(S·C_i))` (Astra). Not 10 bps. |
| Sleeve deadband | unchanged. Not a trading tolerance. |
| TWAP | off unless bundle 1 enables it. A per-block reset does not bound multi-block drift. Net displacement does not bound fee churn. |

Deposit swap that cannot meet 1 bp **reverts**. It does not fall back to invariant growth and does not donate the surplus. Exact-in still does not refund; that rule applies only after a successful credit, not as a way to keep a failed alignment. Public repair may stop inside the budget with a residual and no new shares. Zero mint on a composed dual basket reverts; it is not a one-sided activation.

## Owner decision bundles

**Bundle 1 — numeric envelope, source, and residual risk.** Approve the table, or replace the four numbers. Config source: package constants with stored-0 fallthrough, not a new oracle field and not a hook whitelist. Accept that 100 bp gross per 30 minutes limits rate and churn but does not prove a fair start price unless an independent reference is added. Recommend the table with TWAP off.

**Bundle 2 — only if the owner wants a different failure mode.** Default needs no second product: failed deposit alignment reverts; repair stops with residual. Approve an invariant-growth or sleeve-mint fallback only by an explicit yes. Silence is not that yes.

Pretransfer provenance and hook admission are not open. Close the EOA-guard miss and separate face `R` from economic totals in the implementation plan. Credit before fee collection. End-sync face balances after the last balance move, including repair.
