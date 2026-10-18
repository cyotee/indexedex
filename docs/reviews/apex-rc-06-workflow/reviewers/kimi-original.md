# Kimi K3 — RC-06 orbital unwrap: the workflow, in plain English (replacement-session original)

- **Label:** Replacement-session original, not continuity. I do not recall `ses_ec41220c2ffeqs5Eha7fPsd54B`. No peer notes were read, including `docs/reviews/apex-rc-06-unwrap/reviewers/`. The controlling text (`docs/reviews/apex-2026-09-17-remediation-council/REMEDIATION_PRD.md` RC-06 at `:146-157`) was read fresh this round — no guard denial. All code cited below was read in current source this round. Nothing was edited. I did not run Forge.
- **Date:** 2026-10-18.

## What the unwrap is for

The orbital hook holds three pool tokens. Some legs are "buffered": instead of holding the raw token, the hook holds shares of a Standard Exchange (SE) vault that wraps it. When a user swaps and the token they receive sits on a buffered leg, the hook cannot hand over SE shares — the user asked for the real token. The hook must first convert shares into the token. That conversion is the "unwrap."

## What the function does now (every step verified)

`_unwrapExactTokenOut(token, amountOut)` at `UniswapV4StandardExchangeOrbitalBufferHookCommon.sol:711-727`:

1. If `amountOut` is zero, or the leg's "SE" is the token itself, there is nothing to unwrap and it stops there.
2. It reads how many SE shares the hook may spend (`_spendableSeShares`) and asks the SE how many shares are needed to produce exactly `amountOut` tokens (`ClaimLib.invertUnwrapExactTokenOut` — the exact-out quote). Zero or above-capacity quotes revert.
3. It approves the SE to pull exactly that quoted share amount (`:720`), calls the SE's `exchangeOut`, which pulls those shares and delivers `amountOut` tokens to the hook (`:722-724`), then sets the approval back to zero (`:725`).
4. Finally it checks the hook actually received at least `amountOut` tokens; if not, everything reverts (`:726`).

So the function does real work — it performs the unwrap. "Returns nothing" means only that it has no `returns` clause: it produces no value for a caller to read.

## Who calls it, and what they do with it

Exactly three call sites, all on exact-out swap settlements, all as bare statements:

- `Common.sol:758` — inside `_swapExactOutExecute` (`:750-765`), the internal exact-out engine: it computes the user's input charge from its own preview (`:756`), then unwraps the output leg if buffered (otherwise it just decrements the raw reserve book, `:760-762`). Its own return is that separately computed input — nothing from the unwrap.
- `SeTarget.sol:144` — the public exact-out swap route (`:130-157`): pull the user's input, unwrap the output leg if buffered, pay the user exactly `amountOut`, sync the book.
- `SeTarget.sol:213` — `_payOwnerSwap` (`:209-218`), the owner-only internal swap: the same unwrap-then-settle shape.

## The September defect and why it is gone

In September this function returned a number meant to be "shares spent," but assigned it the approval cap and discarded what the SE actually reported spending. Today there is no return value at all — the PRD's second permitted resolution ("the unused return is removed and every caller is updated") is what the current source contains. The approval-to-zero hygiene and the short-delivery revert are intact, and because the approved amount equals the computed quote, the unwrap cannot leak a surplus.

## Is the path executed correctly?

Yes, as far as current source shows: the SE pulls only the quoted shares, the hook pays out only after verifying delivery, and no caller consumes a misreported count because none exists. This is a source-presence judgment; I did not run the path.

## Answer

No remaining defect

I did not run Forge.
