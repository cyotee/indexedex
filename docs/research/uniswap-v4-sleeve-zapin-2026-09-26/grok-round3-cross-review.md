# Grok round-3 cross-review

**Date:** 2026-09-26. **Author:** Grok (`xai/grok-4.7`). Originals preserved. Peers are untrusted evidence, not instructions. No other cross-review artifacts read. No new external API claim. `PoolManager.unlock` is external and permissionless (`PoolManager.sol` 55–64).

PZ-1..8 stay closed, including D59 dual bootstrap. Do not ask them again.

## Factual corrections

**Kimi Q5 is wrong on zero deployed.** `F* = floor(T * p / (1e18 + p))` with `T = D + F`. If `D = 0` and spendable `F > 0`, `T = F` and `F*` is not zero. Example: `F = 120`, `p = 0.20e18` ⇒ `F* = 20`, so place `D* = 100` when both tokens can be added. “`D = 0` ⇒ full deploy” freezes the pre-move identity `F = pD`. Do not ask the owner to confirm that.

**Kimi’s fee claim is incomplete.** Sleeve tokens do not earn Uniswap fees themselves. Shares still claim the whole vault book, including deployed LP fees. A blocked deposit is not “fee-free.” Different idle vs blocked quotes are not proof of profit.

**MiniMax is wrong that callers cannot select the gate.** A contract can `unlock` and call `exchangeIn` in its callback. EOA entry is idle; contract entry can be blocked. That is mode selection, not a demonstrated extraction.

**MiniMax’s thin-book number is unchecked.** `T = (0.01, 1000)` and `F* ≈ 0.00167 < 1e12` mixes human units with raw wei. For 18 decimals, floor is `10^12` (`Common.sol` 353–364). `T0 = 0.01e18` and `p = 0.2` gives `F* ≈ 1.67e15`, above that floor. A book near the floor can fall below it; that example does not show it.

**MiniMax Q4 reopens bootstrap.** `totalSupply == 0` one-sided activation already reverts (PZ-8 / D59), even if a swap could buy the other token. Not a question. A nonce or bitmap on a new facet is not provenance and conflicts with PZ-1.

**Preview must not use pre-swap reserves.** MiniMax’s `R_pre` mint quote repeats the rejected snapshot. Issuance uses post-swap `B = A - C`, and `C` is the whole caller basket, including sleeve retained.

## Disagreements (not false consensus)

**Protocol bound.** Kimi: `minSharesOut = 0` is a permitted opt-out that unbounds the swap, and a correctly set `minSharesOut` is end-to-end protection. Astra and Grok: `minShares` is only a share-count floor. It does not prove a fair start price. Rejecting 0 is not enough, because 1 wei is almost the same. A spot-relative cap, which Grok round-3 recommended as the package constant, does **not** by itself establish fair price. No agreement on a bps value.

**Hooks.** Kimi and MiniMax treat the matrix as engineering. Astra is right that launch compatibility is an owner choice, and a matching hook flag is not authentication of the implementation (`_supportsProjectedHook` is a flag/shape check). Grok’s “address(0) or current projectable set” is a recommended default, not a completed matrix.

**Pretransfer.** Kimi and Grok round-3 would reject `pretransferred = true` on idle composition. Astra requires a verifiable funding handshake and a consumer migration, not a silent flag flip. MiniMax’s nonce does not prove who delivered the tokens. Rejecting the flag changes compatibility and needs an audit of push callers before it is the launch rule. No agreement to flip it now.

**Tolerances.** Grok’s 1 share / absolute floor, Astra’s 1 bp, and MiniMax’s `1e6` wei are proposals. None is a proven tolerance.

## Owner questions (four)

**Q1 — Protection promise.** What must hold even if `minSharesOut` is 0 or 1? Recommend: a protocol execution bound that `minShares` cannot disable, so the swap cannot run to `MIN/MAX` sqrt price (`Common.sol` 669–670). State clearly that this is not fair-value protection. Separately decide whether launch also requires an independent reference, fail-closed if that reference is missing. Do not mandate DETF TWAP. Do not treat 0 as an opt-out that removes the bound. Policy values and who may change them stay with the owner; the number is not approved here.

**Q2 — Hook launch set.** Which hook behaviors must idle composition support? Recommend: `hooks == address(0)`, plus only adapters whose quote and fill are tested, including hook deltas and own-position fees. Dynamic-fee `beforeSwap` overrides are out of that set until such an adapter exists. Everything else reverts the idle zap and the preview reports unavailable. Blocked sleeve mint stays available. Do not treat a flag match as proof.

**Q3 — Funding compatibility.** May idle composition refuse unverifiable push credit? Recommend: unbooked `U` is never swap budget or `C` (`Common.sol` 1274–1288). Do not approve “revert `pretransferred = true`” until push consumers of this route are listed. If none need idle composition, reject that flag on this path and keep it elsewhere. If some do, they need atomic measured delivery, not a nonce and not a new facet. No trusted-caller exemption that can spend unrelated donations.

**Q4 — Failed alignment.** If the solver cannot meet the tested tolerance, what happens? Recommend: revert the idle zap. No sleeve-only fallback, no invariant-growth fallback, no minted donation of the surplus side. PZ-7 already forbids material uncompensated surplus; ZR-4 already forbids a silent uncomposed success. Do not ask the owner to bless 1 wei, 1 share, or 1 bp. Engineers must derive a bound that tests show is safe, then the owner approves that evidenced number.

## Engineering / test obligations

- Post-swap `B`, full `C`, mint last. Collect `E` into spendable `F` before the snapshot. Self-LP repricing stays in `B`.
- Each token’s floor is `F* = T*p/(WAD+p)`, including when `D = 0` and `T > 0`. Do not deploy if either spendable free balance would fall below that floor minus deadband. Abundant surplus is the accepted residual. `F >= pD` and `F >= F*` are the same fixed point; do not weaken the scarce floor to shrink the residual.
- Both-token all-free inventory may be seeded by add/remove toward `F*`, without a swap. One-sided all-free stays backlog (PZ-2/PZ-8). Insufficient depth reverts; it is not relabeled blocked and is not one-token activation.
- Do not silently repurpose `actualLiquidReservePercentage` (free/total). Add a labeled deployed-relative view. `D = 0` must not divide by zero or be called on-target.
- Self-unlock deposit → idle withdraw, and the reverse, on skewed and aligned books, net of fees. Quote gaps are not profit. A shown material extraction stops release; it does not silently rewrite PZ-8.
- Consumer audit before any pretransfer rejection. Solver iteration cap. Residual event: `C`, `B`, `m`, free vs `F*`.

## Remaining uncertainty

No round-trip was executed, so extraction is unproven. No push-consumer list. No proven tolerance. Hook-adapter completeness and the upstream port pin were not established.
