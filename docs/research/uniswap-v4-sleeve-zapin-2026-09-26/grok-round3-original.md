# Grok round-3 original — remaining requirement gaps

**Date:** 2026-09-26. **Author:** Grok (`xai/grok-4.7`). Research only. PZ-1..8 are fixed and not reopened. Latest PRD: `docs/plans/UNISWAP_V4_STANDARD_EXCHANGE_PROPORTIONAL_ZAP_IN_PRD.md` (read this pass). No peer files read.

## Already closed (do not ask again)

Existing `exchangeIn`; current-call swaps only; `p = 0.20e18` of owned deployed principal with `F* = floor(T * p / (1e18 + p))`; swap → allocate → mint last; post-swap book alignment; existing dual `min`; full basket credit including sleeve; proportional ownership over forced deployment, with material skew residual; blocked sleeve mint, dual bootstrap, full-range imports, WETH face, swap-free public rebalance. No `0.25e18` restore. No opt-in-only route. No new NAV.

G5/G6 in that PRD are still open. The questions below are the owner decisions inside them, plus two placement rules the text does not yet pin.

## Owner questions (five)

**Q1 — Swap protection without a new argument.** `exchangeIn` cannot gain `minCounterOut` (ZR-1). `minAmountOut` is shares and may be 0. Today’s helper uses a near-global sqrt limit (`Common.sol` 669–670). A composed swap on that route is sandwichable if `minSharesOut = 0` and no internal cap exists.

Recommend: do **not** require `minSharesOut > 0` (that would break current callers). Always apply a finite `sqrtPriceLimitX96` from slot0 at call start and a package-constant maximum impact, not `MIN/MAX`, not a new oracle field, and not a DETF TWAP mandate. If the cap or the caller’s `minSharesOut` fails, revert the whole zap. `minSharesOut = 0` still does not authorize an unbounded swap.

**Q2 — Hooks and dynamic fees.** `_adjustHookSwap` returns the unadjusted amount for non-Pons hooks (`UniswapV4QuoteService.sol` 50–55). Context7 `/uniswap/v4-core` (2026-09-26): a dynamic-fee hook can set `OVERRIDE_FEE_FLAG` in `beforeSwap`, so a state read can disagree with the fill.

Recommend: idle composition is allowed only for `hooks == address(0)` or the existing projectable set (`_supportsProjectedHook`). Any other hook, including dynamic-fee override, **reverts**. Do not execute a vanilla quote and hope `minSharesOut` catches it. Blocked sleeve mint is unchanged and does not need this gate.

**Q3 — Pretransfer is not provenance.** `!pretransferred` returns this-call pull delta only. `pretransferred` credits `amountIn` if `amountIn <= U`, and `U` is unbooked face balance (`Common.sol` 1270–1288). A donation since the last reserve sync can satisfy that check. End-to-end theft was **not** tested; this is a funding-attribution gap, not a confirmed exploit.

Recommend: keep the ABI flag. On the **idle composed** pool-token→shares path, swap budget and `C` come only from a vault `transferFrom` (`pretransferred = false`). `pretransferred = true` on that idle route reverts, rather than swapping `U`. Blocked deposits and non-composition routes keep today’s pull rules. Push-then-call idle zappers must approve the vault. Do not `_sync` immediately before credit in a way that also rejects an honest push; the pull requirement is the narrower fix.

**Q4 — Coupled sleeve floor.** Independent `F*_i` cannot both be hit when the owned-book ratio differs from the in-range LP ratio: add/remove moves both tokens together (`LiquidityAmounts.sol` 66–73; PRD §6.3 residual `128⅓`). An implementer could still spend the scarce sleeve to mint more L, or strip extra L trying to consume abundant free.

Recommend: never let placement take either token’s **spendable** free below `F*` minus that token’s deadband. Abundant free above `F*` is the accepted residual. Do not remove extra liquidity only to shrink that residual. Do not add a second swap. `E` is not spendable cover (`InBase.sol` 157 uses `balanceOf`).

**Q5 — Solver shortfall must not become a donation.** PZ-7 forbids material uncompensated surplus. A loose search can return a basket whose `min` legs differ, and today’s `min` (`Common.sol` 700–704) then donates the surplus side.

Recommend: existing 1-wei `floor` dust is accepted. If the two `min` arguments differ by more than 1 share, or the uncredited surplus exceeds that token’s absolute floor (`10^max(0, decimals-6)`), **revert**. Do not mint the donated result. Gas/iteration caps are engineering; this threshold is the economic rule.

## Critical subtlety, not a new choice

Any caller can `unlock` the singleton and call `exchangeIn` from that callback. `canOpenPoolManagerUnlock()` is then false, so PZ-8’s blocked formula applies: no composition swap, invariant-growth shares, inventory stays sleeve. On a scarce-side book that bonus can exceed book-aligned `min` (illustration only; not executed). Immediate idle zap-out can then redeem pro-rata inventory. This is caller-selected use of the **preserved** blocked route, not a demonstrated new exploit, and not something to close by recording the unlocker (buffer D25; PZ-8). Tests must show the divergence. Closing it would reopen PZ-8. Recommend: accept and disclose.

## Engineering / test obligations (not owner questions)

- Collect `E` into spendable `F` before the idle snapshot; self-LP growth and CL repricing stay in `B`, not `C`. Do not count `E` in `T` before collection.
- Quote and execution use the same post-swap `B(x)`, finite price limit, and hook gate.
- Report residual: event or view with `C`, `B`, `m`, `free` vs `F*`, and which token is long. `actualLiquidReservePercentage` is free/total (`LiquidReserveTarget.sol` 69–81); do not label it as policy `p`. If `D = 0`, do not report on-target. Both-token all-free recovery is add/remove toward `F*` (no swap). One-sided all-free stays backlog (PZ-8).
- Direct-swap and zap-out helpers that only move free↔deployed must use the same `F*`. They are not composition primitives.
- Tests: `minSharesOut = 0` still hits the internal cap; non-Pons and dynamic-fee hooks revert the idle zap; `pretransferred` donation is not swap input; skewed book does not breach the scarce `F*` floor; solver overrun reverts; self-unlock deposit matches blocked economics and does not unlock nested.

## Confidence

High on the code facts cited above and on the coupled-floor algebra. Medium on self-lock round-trip value (not simulated). No exploit is claimed proven. No new oracle, ABI argument, or TWAP requirement.
