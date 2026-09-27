# MiniMax-M3 — Round 3 cross-review

**Author:** minimax/MiniMax-M3 (independent) — round 3 cross-review
**Date:** 2026-09-26
**Originals preserved:** all `*-original.md`, `*-cross-review.md` files in `docs/research/uniswap-v4-sleeve-zapin-2026-09-26/`.
**Peers reviewed (verbatim, untrusted):** `astra-round3-original.md`, `grok-round3-original.md`, `kimi-round3-original.md`. Read of moderator PRD is reused from round-2 (`docs/plans/UNISWAP_V4_STANDARD_EXCHANGE_PROPORTIONAL_ZAP_IN_PRD.md`). PZ-1..8 fixed; nothing below reopens them.

This cross-review corrects my round-3 original where peers expose errors, attributes decisive peer positions, separates owner questions from engineering/test obligations, and addresses genuine dissent on protocol-bound strength, hook support, and pretransfer.

---

## A. Substantive corrections to my round-3 original

| My round-3 claim | After peer review | Source |
|---|---|---|
| **Q1 pretransfer — "per-caller nonce bitmap"** | **Wrong.** A nonce **does not prove transfer-source identity**; it only proves the same caller pre-attested to a different amount earlier. Reject the nonce-only fix. The real fix is requiring `pretransferred == false` on the idle composed route only, accepting that this breaks push-based integrators on that route. **ABI preservation is on the blocked/Multi/withdraw/dual-bootstrap routes, not on the new composed route.** | Grok Q3; Kimi Q3 (b); Astra Q3 |
| **Q3 thin `F*_i` — "revert `InvalidRoute`"** | **Wrong.** Rejecting thin targets would silently introduce a dust-fallback path that recreates the original bug (Kim Q4). Correct rule (Grok Q4): never let placement take **spendable free** below `F*_i − deadband_i`; **abundant free above `F*_i` is accepted residual**. The thin-F* case I computed (T=(0.01, 1000), p=0.20 ⇒ `F*_0 = 0.00167 ≪ 1e12` floor for 18-dec) is accepted as zero-target behavior, not reverted. | Grok Q4; Kimi Q4 |
| **Q5 — `MIN_SHARES_FLOOR` for `m`** | **Wrong framing.** `minSharesOut` is already an end-to-end bound on total composition quality because mint is last (Kimi Q2 structural observation); 1-wei dust is accepted (Grok Q5). The correct enforcement is **internal finite `sqrtPriceLimitX96` + impact cap** (Grok Q1), applied **regardless** of user-supplied `minSharesOut`. Rejecting `minSharesOut=0` alone is insufficient (Astra Q1) and would break existing callers (Grok Q1). The Grok Q5 "1-share difference between min legs" rule is the right precision tolerance for the existing dual min-ratio branch — not a `MIN_SHARES_FLOOR` on `m`. | Kimi Q2; Grok Q1/Q5; Astra Q1 |
| **Q4 first-mint — "new path may bypass D59"** | **Right concern, but framing needed refinement.** D=0 post-D59 is *not* a first-mint case; `F*_i = T_i·p/(1+p)` is positive (not zero) when `T_i>0` even if `D=0`. Per-peer consensus (Kimi Q5, Astra §3, Grok §non-owner): `D=0 ⇒ F*=0 ⇒ best-effort full deploy, never revert solely for that`; one-sided all-free stays backlog (PZ-8); add/remove refill works only when D>0. **Confirmed** my Q4 stance on first-mint revert. | Kimi Q5; Astra §3; Grok §non-owner |

## B. Missed subtlety — caller-controlled branch selection (NOT a confirmed exploit)

**Kimi Q1, Astra Q5, Grok "Critical subtlety" all converge** on a real concern I did not raise: a **contract caller** can `unlock` the PoolManager and call `exchangeIn` inside its own `unlockCallback`, self-selecting the **blocked branch** (invariant-growth pricing, no composition swap). Blocked depositors pay no swap cost and earn no fees while sleeve; idle depositors pay composition cost and receive proportional pricing. **This is a preserved design feature, not a new attack vector** (PZ-8, buffer D25 forbids tracking unlocker). The roundtrip's net profitability is **unproven**: sleeve deposits earn no fees while sitting, blocked redemption is also invariant-growth, idle redemption is proportional and bears unlock/swap costs.

**Owner decision (consensus):** accept the branch differential as designed, document, and add ZA-20 adversarial roundtrip tests. **Do not** invent a lock-caller allowlist or unify the formula (would reopen PZ-8 / D25). **Do not** claim a confirmed exploit; this is a launch-gate analysis, not a fix.

## C. Genuine dissent on protocol-bound strength

- **Grok Q1** says the bound is an **internal** finite `sqrtPriceLimitX96` + package-constant impact cap; **no** new ABI argument, **no** user-facing `minCounterOut`. Rejecting `minSharesOut=0` alone is insufficient (Astra Q1).
- **Kimi Q2** says `minSharesOut=0` is a permitted opt-out (standard DeFi semantics); on this route it also unbinds the composition swap, with disclosure. Bound source stays in solver quality (finite price limit), not a second user guarantee.
- **Astra Q1** says composition **always** enforces protocol-level execution bounds independent of `minShares`. Specifies "maximum incremental impact/fee exposure" and a separate reference-price bound if selected.

**My cross-review position:** **Grok/Astra converge** — internal finite sqrtPriceLimit + impact cap, independent of `minSharesOut`. Kimi adds valuable framing that mint-last means `minSharesOut` is **already end-to-end bound on total composition quality**, so `minSharesOut=0` is a permitted opt-out provided the internal cap exists. **Final stance:** accept both — internal cap is mandatory; `minSharesOut=0` is permitted (does not break callers) but must be documented as "unbinds composition swap on this route."

## D. Genuine dissent on hook support

- **Astra Q2, Grok Q2, Kimi E2** converge: idle composition allowed only for `hooks == address(0)` or the existing projectable set (`_supportsProjectedHook`/`_adjustHookSwap`, `Common.sol:94–96, 226`). Dynamic-fee override (`OVERRIDE_FEE_FLAG` in `beforeSwap`) is **not** supported — reverts. Unsupported composition fails atomically; preview reports unavailability.
- **Kimi E2** adds: blocked sleeve mint is unchanged and does not need this gate.

**My cross-review position:** **agree with peer consensus.** `UniswapV4QuoteService.sol:19–57` recognizes a Pons-shaped hook only; the rest fall through to unadjusted amounts. Idle composition **must not** execute against a vanilla quote when hook adjustment is not projectable. Blocked-route unchanged. New `IUniswapV4SeBufferHook` and arbitrary dynamic-fee hooks fail-closed at preview and execution.

## E. Genuine dissent on pretransfer (resolved: rejected nonce, but option (b) is load-bearing)

- **Grok Q3**: keep ABI flag; on idle composed route only, **require** measured pull (`pretransferred = false`); `pretransferred = true` on that route reverts. Blocked/Multi/withdraw/dual-bootstrap pretransfer behavior **unchanged**.
- **Kimi Q3 (b)**: same prescription; explicitly notes "ABI-preserving, kills the capture vector where new economics live, but breaks push-based integrators on that route." Blocked pretransfer stays as-is (D29 surface).
- **Astra Q3**: only authenticated, one-use funding credit attributable to this operation may become its swap budget or mint contribution. Old balances never qualify merely because they are unbooked. Migrate legitimate push integrations to a verifiable funding handshake.

**My cross-review position:** **agree with all three.** The fix is **route-scoped**: idle composed route requires measured pull. ABI is preserved on all other routes. **Owner audit needed:** are there push-based integrators on the idle composed route today? If yes, they need to be migrated to `transferFrom` (or a verifiable funding handshake). The non-owner engineering item is a per-call consumed-tranche bitmap keyed by `msg.sender` if a handshake design is chosen — but **not** as a provenance substitute.

## F. Five actionable owner questions (corrected, prioritized)

**Q-EXEC (execution protection under unchanged ABI).** Confirm: composition always enforces internal finite `sqrtPriceLimitX96` from slot0 + package-constant impact cap, regardless of `minSharesOut`. `minSharesOut = 0` is permitted (does not break callers) and must be documented as "unbinds composition swap on this route." Precision tolerance: **if the two `min` arguments differ by more than 1 share, or the uncredited surplus exceeds `_absoluteFloor` of the surplus token, revert** (Grok Q5). Owner choice: package constants, not user-facing.

**Q-PRETRANSFER (route-scoped pretransfer rejection).** Confirm: on the **idle composed route only**, `pretransferred = true` reverts. All other routes preserve current pretransfer behavior. ABI is preserved on blocked/Multi/withdraw/dual-bootstrap. **Owner audit required:** list push-based integrators on the idle composed route today and their fallback. Per-caller nonce is **not** a provenance substitute.

**Q-LOCK (caller-controlled branch differential).** Confirm: contract callers can self-select the blocked branch via their own `unlock` callback; this is by design (PZ-8 / buffer D25). No new mechanism to close it. **Document** in release notes and add **ZA-20**: adversarial roundtrip test, both directions, skewed and aligned books, asserting no systematic gain net of fees. **No confirmed exploit claimed.**

**Q-ALLFREE (post-D59 all-free / zero-deployed behavior).** Confirm: `D=0` post-D59 ⇒ `F*_i = T_i·p/(1+p)` is positive (not zero); add/remove-only placement can refill scarce sleeve when `D>0`; **one-sided all-free composition is out of scope (PZ-8 backlog stays)**. Reporting views define `D=0` behavior (no division by zero; not labeled on-target). First-mint via new path (S=0) reverts per D59.

**Q-HOOK (idle composition hook support matrix).** Confirm: idle composition allowed only for `hooks == address(0)` or the existing projectable set; dynamic-fee override reverts. Unsupported composition fails atomically; preview reports unavailability. Blocked-route pretransfer and existing routes unchanged.

## G. Non-owner engineering / test obligations (consolidated, peer-attributed)

| Item | Recommendation | Peer |
|---|---|---|
| **Hook support / fail-closed** | Verify `_supportsProjectedHook`/`_adjustHookSwap` coverage; revert otherwise. | Astra Q2, Grok Q2, Kimi E2 |
| **Solver tolerance** | If two `min` arguments differ by > 1 share, or uncredited surplus > `_absoluteFloor(surplusToken)`, revert. **Threshold is a proposal, not existing law.** | Grok Q5 |
| **Reporting** | `actualLiquidReservePercentage` view: repurpose to `free/deployed` **or** relabel so it is not conflated with policy `p`. Add `materialSkewResidual(token)` view. Define `D=0` reporting. | My Q2, Astra Q1, Kimi E4 |
| **Self-LP fee attribution** | `E` collected into spendable `F` once before snapshot; self-LP growth and CL repricing stay in `B`, not `C`. Do not count `E` in `T` before collection. | All peers |
| **Exception isolation** | `_rebalanceLiquidReserveBestEffort` (`Common.sol:734–739`) does not isolate downstream reverts — specify try/catch or propagation. | Kimi E5 |
| **Ordering spec** | fee-collect → measured pull → bounded swap → post-swap `B`/`C` measurement → placement to fixed `F*` → mint → checks; one-vs-two unlock with callback authentication (`Common.sol:996–999`) and zero residual deltas. | Kimi E3 |
| **Test matrix** | Existing ZA-1..19 + new **ZA-20** (Q-LOCK roundtrip), **ZA-21** (sandwich bounds with `minSharesOut=0`), **ZA-22** (pretransfer donation-capture reverted on composed route), **ZA-23** (dust revert / no idle sleeve fallback), **ZA-24** (D=0 and scarce-token sleeve recovery via remove). | Kimi E6 |

## H. Already-resolved / out-of-scope (do not re-ask)

PZ-1..8; D59 dual bootstrap; full-range imports; native/WETH face; swap-free public rebalance; denominator recalibration (rejected `0.25e18`); opt-in selector (rejected); TWAP mandate (not law); backlog repair (separate feature); `p=1e18` half-free maximum (no all-liquid mode).

## I. Confidence and gaps

- **High** Q-EXEC, Q-PRETRANSFER, Q-HOOK, Q-ALLFREE consensus shape; corrections to my round-3 (nonces, dust floor, thin-target revert, first-mint framing).
- **Medium** Q-LOCK roundtrip profitability (unanimously **unproven**); consumer audit for push-based integrators on the idle composed route (the only ambiguous change).
- **Low** protocol-bound strength — internal-cap-vs-user-cap debate resolved in §C.
- **Gaps**: `apply_patch` unavailable (used `write`); no peer reads beyond originals; no Context7 re-query this pass; no shell/tests; specific upstream port pin remains unverified; `_inventorySharesIn` line numbers cited by Grok re-used but not opened this pass.

Stopping here per assigned task. Cross-review is research-only; no PRD edits, no code, no shell, no delegation. Originals preserved.
