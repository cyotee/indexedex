# Kimi K3 — plan-readiness pass: REQ-V4-01

- **Label:** Replacement-session plan-readiness pass, not continuity. I do not recall `ses_ec41220c2ffeqs5Eha7fPsd54B`. No other reviewers' notes were read. No code edited; no plan file written.
- **Date:** 2026-10-14.
- **Controlling document:** `docs/reviews/apex-req-v4-01-internal-settlement/REMEDIATION_PRD.md` (re-read in full; 71 lines, including the 2026-10-15 owner ruling at `:9`).
- I did not run Forge.

## Verdict: ready — no owner decision remains

The PRD plus the 2026-10-15 owner ruling close every choice I or the peers previously flagged. The ruling answers deletion (both delegate functions go: `executeNamedHolderRedemption` **and** the legacy V4 four-argument `executeZapOutExactIn`), the InTarget rewire (the ordinary share exit calls `_executeZapOutExactIn` directly with `address(this)`), the disable check (REQ-V4-02 stays separate; this item does not add it), the size contingency (report, never restore the hop), and the test gate (the existing legacy V4 vault-held redeem suite). Current source matches the PRD's description of the defect (`UniswapV4StandardYieldExecutionTarget.sol:26-36`; `UniswapV4StandardExchangeInTarget.sol:79-84,101-118`; `UniswapV4StandardExchangeInExecutionDelegate.sol:13-18,27-34`; inherited declaration `UniswapV4StandardExchangeInBase.sol:146-152`).

The owner ruling's factual premise verified this turn: a repo-wide grep for `executeZapOutExactIn` finds the legacy V4 delegate's wrapper referenced only at `UniswapV4StandardExchangeInTarget.sol:110`; all other hits are the V3 FullSpread, hookless, and Pons families' own copies (untouched per `:39`) or tests of those families. The legacy V4 test suite does not reference either deleted function, so the deletions do not break its compilation.

## Mechanical closures the plan must state (none is an owner decision)

1. **Edit order.** Three files, one working-tree change, compiled and tested once at the end. State the order so no intermediate state is mistaken for done: (a) `UniswapV4StandardYieldExecutionTarget.sol` — replace the `_settleNamedHolder` body; (b) `UniswapV4StandardExchangeInTarget.sol` — rewire the share exit and delete `_delegateExecuteZapOutExactIn`; (c) `UniswapV4StandardExchangeInExecutionDelegate.sol` — delete the two functions last, after no live caller remains. (Deletion is compile-safe in any order because callers encode by signature string, but this order keeps runtime wiring coherent while editing.)
2. **Exact calls.** In `_settleNamedHolder`: `amount_ = _executeZapOutExactIn(tokenOut_, shares_, minimum_, receiver_, holder_);` — replacing the delegatecall, the assembly revert, and the result decode, keeping `nonReentrant` and the trailing `_pokeBoundPoolTwap()` (PRD `:26-33`; do not copy V3's immediate return). In `UniswapV4StandardExchangeInTarget.sol:81`: `amountOut = _executeZapOutExactIn(address(tokenOut), actualIn, minAmountOut, recipient, address(this));` — the wrapper's documented holder semantics preserved (`shares were already pulled onto the vault`).
3. **What is deleted, exactly.** From the delegate: `executeNamedHolderRedemption` (`:13-18`) and `executeZapOutExactIn` (`:27-34`) only. From InTarget: `_delegateExecuteZapOutExactIn` (`:101-118`) only. Everything else stays: `executeZapInDeposit` (`:20-25`) and `_delegateExecuteZapInDeposit` (`:89-99`), including the deposit delegatecall (PRD `:37-38`). The plan should also state the deliberate non-cleanup: the delegate's `SELF` immutable and `DelegateCallRequired` error (`:9-10`) become unused after the deletions and are **left in place**, because the owner ruling enumerates exactly two deletions; an implementer must not extend the cleanup on their own judgment.
4. **Which deployed unit is measured.** `UniswapV4StandardExchangeInFacet` (PRD `:41`) — the one unit that gains inlined settlement code from both the yield body and the rewired share exit. Measure its runtime after the artifact refresh; if it exceeds 24,576 bytes, stop and report the measured size; do not restore the hop, add a self-call, paste the settlement body, or enable `via_ir` (PRD `:41`). The delegate shrinks; no gate applies to it, but reporting its size alongside is acceptable.
5. **Test file to run.** `test/foundry/spec/protocol/dexes/uniswap/v4/UniswapV4StandardExchangeVaultHeldRedeem.t.sol` (PRD `:66`), run unchanged; it asserts behavior, not the hop — verified this turn that it does not reference either deleted function. The plan should instruct a grep for decimals or sibling variants of that suite at implementation time and run any found. Because this is a production edit, the plan must order the artifact refresh before the test: `python3 scripts/forge-artifacts.py` with the three edited sources as positional arguments and the test file as `--test-root`, per `docs/testing/ARTIFACT_BUILDS.md`.
6. **Pre-deletion verification step.** A repo-wide grep for `executeNamedHolderRedemption` and for the legacy V4 `executeZapOutExactIn` signature string, repeated at implementation time; if any new caller exists then, stop and report instead of deleting (owner ruling `:9` assumed one caller; today that assumption holds).
7. **Editorial, not a choice.** The PRD numbers two consecutive steps "8" (`:37-38`). The plan should renumber them sequentially when consolidating; the content is unambiguous, so this is not an owner question.

## What I am not asking

- No decision on the call shape, holder selection, lock, TWAP poke, or disable check — all recorded (PRD `:26-36`, `:51`, `:57`).
- No decision on V3 FullSpread, hookless, or Pons — excluded by `:39`, `:58`, `:61`.
- No decision on the size-limit outcome — pre-decided by `:41` and `:53`.
- No function name, error name, command, or line-layout question — the PRD text and repo rules select them.

I did not run Forge.
