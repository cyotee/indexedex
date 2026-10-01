# MiniMax-M3 — Cross-review: Uniswap V4 SE sleeve zap-in proportional seat + policy sleeve

**Author:** minimax/MiniMax-M3 (independent) — cross-review pass
**Date:** 2026-09-26
**Original preserved:** `docs/research/uniswap-v4-sleeve-zapin-2026-09-26/minimax-original.md` (unchanged; do not rewrite history).
**Peers reviewed (verbatim, as untrusted model evidence):**
- `docs/research/uniswap-v4-sleeve-zapin-2026-09-26/astra-original.md`
- `docs/research/uniswap-v4-sleeve-zapin-2026-09-26/grok-original.md`
- `docs/research/uniswap-v4-sleeve-zapin-2026-09-26/kimi-original.md`
**Code references re-verified this pass:** `Common.sol:305–805`, `InBase.sol:185–377`, `DFPkg.sol:94–247`, `LiquidReserveTarget.sol:22–96`. **External:** Context7 `/uniswap/v4-core` (PoolManager singleton lock semantics, accessed 2026-09-26).

Per instructions: peers are evidence, not authority; named models or quotes are not endorsements. No code/tests/shell/delegation this pass. No new PRD amendment text drafted.

---

## A. Agreements (high-confidence)

All four originals converge on:

1. **Root cause** is structural, not a bug: D30 full-range always-in-range + D27 sleeve-then-deploy + D28 no-rebalance-swap + D32 binding-token-absorbs ⇒ `LiquidityAmounts.getLiquidityForAmounts(spot, min, max, excess0, excess1) == 0` when one of `(excess0, excess1)` is 0. Cited at `Common.sol:564–570`, `Common.sol:822–858` (`_deployExcessLiquidity` early-return), `Common.sol:843–845`. **Bootstrap**: first-mint with one token returns 0 (`Common.sol:693–695`); D59 dual-token activation preserved.
2. **The user's proposal is a change** requiring PRD supersession, not a silent fix. No peer argues otherwise.
3. **Caller-only composition**: composition scope is the **depositor's** idle single-token excess. Public `rebalanceLiquidReserve` (D10, D28) stays add/remove-only, idle-only, no swaps. Backlog from blocked deposits/donations is *not* auto-composed.
4. **PM idle vs in-session nomenclature** is correctly handled in code: `canOpenPoolManagerUnlock() = !TransientStateLibrary.isUnlocked(_poolManager())` (`Common.sol:315–317`). PM idle ↔ V4 locked; PM in-session ↔ V4 unlocked. Outer `unlock` session forbids nested unlock (Context7 `/uniswap/v4-core`: `swap`/`modifyLiquidity`/`take`/`settle`/`mint`/`burn` only inside `unlockCallback`).
5. **Multi join/exit (D41–D52) unchanged**: no-swap behavior is preserved. The new behavior is bounded to single-token `IStandardExchangeIn` zap-in.
6. **Dual bootstrap preserved** (D59). One-sided first mint keeps returning 0 / `ZeroAmount` (`InBase.sol:293–294`).
7. **Native / WETH**: WETH face only; unwrap only for PM settlement, wrap native takes (`Common.sol:411–425`, `Common.sol:1096–1118`); no payable ETH deposit; PoolKey order not numeric sort.

## B. Specific objections / corrections to my original

| My original claim | Position after peer review | Evidence |
|---|---|---|
| R-D60a.4 *"blocked ⇒ revert"* | **Confirmed.** All peers agree. | Grok R1; Kimi §3.2; Astra §3.1 |
| R-D60a.10 *"same `_syntheticOfPair`-style gate"* | **Withdraw.** Grok flagged this as low-confidence because `_syntheticOfPair` is **DETF** price-gate logic; the SE Standard Exchange is **not a DETF** and is not subject to CLAUDE.md non-negotiable 5 (mandatory price gates apply to **DETF instances** only). Kimi's TWAP-gated `minOut` via `_adjustHookSwap` is the correct framing. | CLAUDE.md non-negotiable 5; `DETF_ALIGNMENT_PRD.md` §24.1; DETF vs SE Standard Exchange is a different product. **No issuance formula or TWAP requirement may be imported from DETF law.** |
| *"block imported `zapInSwapAndJoin`"* | **Too strict.** Grok R4 + Kimi §3.5 + Astra agree imported positions may use NFT ticks; if imported is **out-of-range** and one-sided L is consumed, swap is unneeded. Only in-range imports need composition. | `Common.sol:510–523` `_managedTicks`; imported tick passthrough; `LiquidityAmounts` binding on scarce leg. |
| *"new facet"* | **Still correct as one option; surface distinction is what matters.** Kimi proposes extending `_executeZapInDeposit` internally and adding a new external selector; Grok leaves selector placement open (extend `exchangeIn` or new selector). The product requirement is **distinct surface from the existing single-token sleeve-mint path**. | D57–D59 require sleeve operations to survive blocked path; existing `exchangeIn` single-token zap-in must keep working unchanged. |
| *"preview == exec on the swap"* | **Confirmed**, with caveat. Astra explicitly requires update of `IStandardExchangeInQueryTarget` *and* `IStandardExchangeTransitionQuote`. Kimi's option (B) ("preview unchanged, D24 ignores it") is rejected because it hides slippage from users — the user has a `minSharesOut` check that depends on accurate preview. | `InBase.sol:256–266` preview; `InQueryTarget.sol:15–29,61–118` transition preview; user expectation of accurate `previewExchangeIn`. |
| *"DFPkg additive cut"* | **Confirmed.** Existing 15-facet cut list (`DFPkg.sol:170–247`) is additive; new facets are additional cut rows. | `DFPkg.sol:148–164` interface list and `facetCuts` array. |
| *"constant `liquidReservePercentage` reuse"* | **Confirmed.** No new oracle fields. | `Common.sol:343–347`. |
| *"`nonReentrant` from base, locked from inner unlock"* | **Sharpen.** Grok §Security raised that **lock-slot sharing is not fully traced**; this is a real adversarial gap. The zap-in opens a single `unlock` session containing swap + `modifyLiquidity`; the `unlockCallback` caller-check (`Common.sol:996–999`) is the second guard. Both must hold for adversarial correctness. Verify in test A-Z9. | `Common.sol:996–1013`. |

## C. Evidence that changes my view

1. **Mint-before-swap socialization** — all four reject it. MiniMax-M3 original and Grok R2 both proposed swap-before-mint; Kimi recommends swap-before-mint execution with preview classified as rebalance-like (rejected; see §D); Astra requires explicit issuance-equation verification.
2. **Single `unlock` containing swap + `modifyLiquidity`** is feasible and confirmed upstream — Context7 `/uniswap/v4-core` shows `PoolManager.unlock` accepts multiple delta operations in one callback; settling is checked once at the end. **My original was right to propose a single session; Grok/Kimi explored two-session variants.** Single-session saves gas and a reentrancy boundary; two-session is simpler. Recommend single session with explicit settle-then-add sequencing.
3. **Self-LP fee recycling** — Grok Economics, Astra Economics: when the vault owns a meaningful fraction of the pool, a vault-on-vault swap incurs the vault's own LP-fee rebate plus a protocol-fee leak. **My original missed this.** Capture as an open question and reason about impact cap.
4. **`UniswapV4QuoteService` selective hook support** — Astra §4: "Its hook handling is selective (`:19–57`); arbitrary/dynamic hooks need explicit support or fail-closed quotes." This needs verification before any hook-fee or projected-hook pool is used as the price quote source for the zap-in swap. The current `_adjustHookSwap` is for swap-result adjustment, not pre-trade quote.
5. **Test slack in `_assertFreeWithinDeadband`** — Grok: existing helper permits ~25%/50% of total slack (≈ far laxer than the new policy). **My original acceptance criteria PMC-6 / should specify a tighter bound for the new test surface.** Open question: does the new PRD ship a stricter helper.
6. **`IStandardExchangeInMulti` is *already* the dual join** (`InMultiTarget.sol:11–30`). My original flagged it as the only path that seeds L. Grok and Kimi corroborate. Use it as the seat-leg of the new zap-in; do not duplicate the seat logic.

## D. Unresolved dissent

1. **Preview classification.** Kimi option (B): keep `previewExchangeIn` shares math unchanged (D24 says previews ignore rebalance) + informational view for split. MiniMax-M3/Grok/Astra: preview must include the composition quote because users execute against `minSharesOut`. **Sided with MiniMax-M3/Grok/Astra: the swap is part of the user route, not rebalance. D24 supersession is narrow and explicit (preview must include the swap when idle; when blocked, stays at sleeve-cover model).** Kimi's recommendation is unsafe for a user-facing surface.
2. **Swap-failure semantics.** Kimi: skip-to-D32-leftover on TWAP-gate failure (D11 best-effort consistent). MiniMax-M3/Grok/Astra: explicit revert or explicitly-bounded skip with an event. **Astra's stronger phrasing:** "decide atomic required composition/deployment versus explicitly permitted deferred placement—never silently convert failed zap execution into success." Recommend: **atomic required on first single-side excess swap; leftover dust may stay free as the residual only.** Document the two failure modes:
   - Insufficient counter-deposit ⇒ revert `InvalidRoute` before mint.
   - Slippage exceeded ⇒ revert with explicit `MinAmountNotMet`.
3. **Public rebalance backlog policy.** All four agree: backlog from blocked deposits can stay undeployed indefinitely. Grok/Kimi suggest: **only a later idle single-token zap-in of the same depositor** could compose. Recommend: **no auto-composition; backlog remains a known acceptance under D2/D18.**
4. **Optimal swap sizing.** Kimi's close-form vs spot approximation; both flag as unresolved. Recommend: a per-call **impact cap** (bps or absolute WAD) plus a user-supplied `minCounterOut`; let the optimal be the closed-form derived by the implementation plan, not invented here.
5. **Hook-aware quote path.** Astra flagged `UniswapV4QuoteService` selectivity. Recommend: implementation plan must verify support for hook-fee / projected-hook pools and either extend the quote service or fail-closed quotes.

## E. Recommended PRD decisions (precise; do not invent issuance formula or TWAP-from-DETF)

| Decision | Recommendation | Reason |
|---|---|---|
| **D27 amendment** | Add a third bullet: *"Idle single-token zap-in may execute a bounded counter-token swap of the **depositor's** idle excess within one PoolManager `unlock` session. This is a **deposit-time user op**, distinct from `rebalanceLiquidReserve` (which remains add/remove-only, D28)."* | Distinguishes user op from rebalance; preserves D28; aligns with all peers. |
| **D28 carve-out wording** | Adopt Kimi's phrasing: carve-out, not repeal — limited to single-token `exchangeIn` zap-in user route. Public rebalance untouched. | All peers; preserves invariant. |
| **D32 fallback** | Zap-in path: when the bounded swap cannot form the needed pair (counter-token dust) or fails its own slippage gate, leftover stays free as **dust** under D32; the call reverts, not silently returns success. | Astra's clarification; Kimi's D11 consistency. |
| **D24 supersession scope** | Narrow: preview of idle single-token zap-in must include the bounded swap and post-swap `_sharesOutForDeposit`. Blocked preview remains sleeve-cover-only. Standard previews **and** transition projections are updated. | Pre-existing user expectations; user-facing risk. |
| **D45/D47 Multi** | Unchanged; restate in PRD that zap-in swap does not extend to Multi unbalanced join. | Kimi §3.5; my R-D60a.7. |
| **D59 first-mint** | Unchanged; first-mint single-token still returns 0 / reverts. Zap-in applies to **subsequent** deposits only. | All peers; bootstrap preserved. |
| **Native / WETH** | Existing WETH face; no payable ETH deposit; WETH for native leg of PoolKey in pricing and accounting; `_erc20Face` + `_takeCurrency`/`_settleCurrency` already handle this. | All peers. |
| **Imported positions** | Zap-in swap is **optional** on imported positions: required only when NFT is in-range and one-sided excess exists. Out-of-range imported deploys the consumable side without swap. NFT ticks unchanged. | Grok R4 + Kimi §3.5 + Astra §3 — corrects my original's blanket-revert. |
| **Approval gating** | Owner-only DETF internal — **not applicable** here. The SE Standard Exchange is not a DETF instance and is not under CLAUDE.md non-negotiable 5. Do not invent a TWAP-from-DETF requirement. | Grok low-confidence noted; CLAUDE.md applies to DETFs. |
| **Audit / preview parity surface** | Update `IStandardExchangeIn` preview, `IStandardExchangeInMulti` preview, `IStandardExchangeInQueryTarget` transition projections, and SY consumers that quote the SE Standard Exchange. | Astra §4; Kimi preview §5. |
| **Test slack** | New tests use tighter bounds than current `_assertFreeWithinDeadband`; document the helper if a new one ships. | Grok §Test acceptance. |
| **Self-LP fee recycling / impact cap** | Open research question for the implementation plan; not invented in this PRD. | Grok Economics; my §C.3. |
| **Bounded swap semantics** | Atomic required on first excess swap; explicit revert on minOut miss; the call does **not** succeed silently. | Astra §4 explicit. |

## F. Remaining approval blockers

1. **No PRD text drafted** (this pass is research only). Owner / PRD-author must decide §E items.
2. **Hook-aware quote path**: implementation plan must verify `_adjustHookSwap` and `UniswapV4QuoteService` cover the new zap-in's quote path or extend it / fail-closed.
3. **Self-LP fee recycling** when the vault is a meaningful fraction of the pool: implementation plan must bound impact and document the bound.
4. **Imported-position composition semantics** (NFT ticks; OOR no-swap; in-range swap) must be explicit in the new PRD clause.
5. **Test helper tightening** for the new acceptance surface.
6. **No code edits, tests, or shell runs in this cross-review pass.** All Peer and original reports preserved.

## G. Confidence and gaps

- **High** on root cause, D28 carve-out framing, dual bootstrap invariant, native/WETH.
- **High** on swap-before-mint ordering; **medium** on optimal swap sizing (closed-form not derived; implementation plan must).
- **Medium** on hook-aware quote support (Astra-flagged; needs verification).
- **Low** on whether every facet shares one reentrancy slot (Grok-flagged); test A-Z9 must prove it.
- **Gap**: did not re-read peer artifacts other than the three originals; did not write code/tests; did not invoke Context7 beyond `/uniswap/v4-core`; no new search/fetch round.
- **Gap**: `apply_patch` tool unavailable; cross-review report authored with `write`.
- **Gap**: original report and three peer originals not synthesized into a single consensus document — this is a separate task.

---

*End of cross-review. Saved at `docs/research/uniswap-v4-sleeve-zapin-2026-09-26/minimax-cross-review.md`. Cross-review is research-only; no PRD edits, no code, no shell, no delegation. Original preserved unchanged.*
