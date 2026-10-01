# Grok — Cross-review: remaining zap-in open items

**Date:** 2026-09-27. **Reviewer:** Grok (xai/grok-4.7). Peers read in full: Astra, MiniMax M3, Kimi K3 originals only. Untrusted evidence. No cross-review artifacts. `GROK_ORIGINAL.md` unchanged.

## Corrections

| Claim | Who | Verdict |
|---|---|---|
| Hookless dynamic-flag and 100% fee need an owner confirmation because §10 is silent | Kimi A1 | **Not an owner decision.** `Hooks.isValidHookAddress` already returns false when `hooks == address(0)` and `fee` is dynamic (`Hooks.sol` 124–127). A hookless package that retains structural PoolKey validation (PRD §10 line 381) rejects that key without a new policy. `fee == 1_000_000` is a valid static fee. Exact-output then reverts in core when `swapFee >= MAX_SWAP_FEE` (`Pool.sol` 315–319). That is route-domain handling, not a product ban. A named 100% rejection would be a new policy. Do not ask for it. |
| `LiquidityAmounts.getLiquidityForAmounts` proves a combined exact-output-plus-rebalance closed form | MiniMax E-4 / MIR-1 | **Does not.** The helper is algebraic placement at a known price (`lib/crane/contracts/protocols/dexes/uniswap/v4/libraries/LiquidityAmounts.sol`, not MiniMax’s `contracts/dexes/.../utils/` path). PRD line 214: an operation-only formula does not establish a quotation that includes maintenance. Do not mark those routes supported from this inference. |
| D26 pins a codehash, and the new package bytecode must equal the live hook | MiniMax §2 and V-1 | **Address pin only.** D26 and `ROBINHOOD_MAIN.sol` 441 fix `PONS_V2_MEME_HOOK`. PRD line 365 says the source path is not proof of deployed bytecode. The gate is hook runtime versus the local v2 port, not package bytecode versus the hook address. |
| Editor stack-too-deep on the parity test is executed build evidence, and the candidate must be fixed | Kimi B1 / C2 | **Diagnostic only.** `UniswapV4FullSpreadClosedFormCandidate.sol` exists (21 lines) and is not an adopted formula. PRD line 233: preliminary candidates must not override the source review and are not nonexistence proofs. No forge run is claimed here. Do not require repairing that unadopted file before the matrix. |
| `_amountInForShares` prepaid-credit argument contradicts PRD funding | MiniMax X-5 | **Overstated.** `OutBase.sol` 49–62 subtracts prepaid credit from incumbent reserves so unbooked prepaid is not treated as prior backing. That is not a new owner funding rule. The helper is still only the invariant-growth inverse (`StandardExchangeConstantProduct.sol` 67–96), not idle composition-plus-`min()` (PRD line 214). |
| Grok original: no human checkpoint at all | Grok original §2 | **Narrowed.** No design question blocks the plan. §3.1’s recorded audit-submission readiness determination is a later human sign-off (PRD line 85). It is not an input needed now. |

## Agreements

Astra, MiniMax, Kimi, and Grok agree D1–D26 close the former product forks: two separated families, fixed 25/50/10/1 with no setter, formula-based exact-output, narrow both-mode interleaving exception, fixed `PONS_V2_MEME_HOOK`, and gated legacy removal. Do not reopen them.

The next engineering artifact is the §6.4 route matrix from existing helpers. `_sharesForSingleExit` (lines 113–128) is bisection and cannot underwrite exact-output. Family directories are not implemented. Deployed-runtime equivalence is unproven. Older co-located PRDs stay unedited until a separate documentation task; this PRD wins (line 97).

## Remaining dissent

- **Priority.** MiniMax ranks the bytecode gate above the matrix and says planning cannot be finalized without it. Astra and Grok keep the matrix first and provenance in parallel. Hookless inventory does not wait on the Pons runtime hash. Pons behavioral claims do.
- **100% fee.** Kimi still wants a named reject. The other three do not treat it as required policy. Unresolved only if the owner later wants a product ban. It is not a checkpoint for this plan.
- **Share-side exact-out already recovered.** MiniMax MIR-2. Not adopted. An invariant-growth inverse is not the idle zap, and a search inverse is ineligible.

## Prioritized open items

1. **Engineering:** §6.4 matrix. Name the helper, closed form versus search, maintenance included or not, D19 exception or not, and the revert. Do not adopt `UniswapV4FullSpreadClosedFormCandidate`.
2. **Verification:** fork-labeled codehash and behavior of `0xE5e7…e044` and manager `0x8366…0951` against the local v2 port and `ROBINHOOD_MAIN` constants. Address is closed. Equivalence is not.
3. **Engineering:** family trees under the D22 paths, fixed constants, quote parity, no unknown-hook vanilla fallback, no shared dispatcher.
4. **Later human checkpoint:** §3.1 readiness record before any legacy deletion. Criteria are already written.
5. **Documentation:** reconcile older SE PRDs in a separate authorized task. Not a product fork.

## Human checkpoint

None now, except the already-specified §3.1 sign-off when both families are audit-submission ready. Do not ask the owner to admit or ban dynamic, malformed, or 100% fees, to bless `LiquidityAmounts` as a combined quotation, or to fix the unadopted candidate.

**Saved:** `docs/research/uniswap-v4-open-items-2026-09-27/GROK_CROSS_REVIEW.md`
