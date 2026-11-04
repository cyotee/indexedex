# Rechecked comparison

Working note for the later draft. Not a council verdict. Kimi's original had not settled when this was written. Do not treat this file as `coordinator/draft.md`.

## Question

Do actual deposit and exit swaps eliminate APEX-2026-012 when the only venue is the underlying pool and the only reference is this project's TWAP of that pool?

## What the rechecked rows agree on

A swap does not, by itself, make the share cut fair. Rows that still price inventory the swap did not trade can close a target profit. A price-free proportional claim, with the exit paying that same vector and not selling it, did not.

| Source | Rule | Closed target result | Domain limit |
| --- | --- | --- | --- |
| `research/EXECUTED.md` | executed-price mint, half swap, slice exit, vault owns the interval, 0.3% fee, deposit 200 | `+909146072454192229/210758608401740140` | one infinite-range interval; not Wings lifecycle |
| `research/EXECUTED.md` | same, zero fee | `+80/17` | same |
| `research/EXECUTED.md` | proportional join, same swaps | `-8973027/19940090`; 0 of 288 positive | same; unmatched input refunded |
| `research/EXECUTED.md` | live-quote mint, slice exit, no JIT, vault owns the interval | `+22.199955` target | quote valued unsold opposing at zero |
| Astra recheck | gross executed-price, old opposing zero, zero fee, deposit 100, swap 50 | `+5`; incumbent close `95` | no old opposing inventory |
| Astra recheck | same, 0.3% fee | `10470058473/99880180` | same |
| MiniMax `model.py` | executed-price, idle opposing, swap the whole deposit | `+182670959878875300000000000000000/90821980886249` | token0 is target; idle book, not vault LP |
| MiniMax `model.py` | same function, vault liquidity share 1/4, 1/2, 3/4, or 1 | negative | that file's LP accounting, not the interval ledger above |
| Grok `run()` | live-quote mint and quote payout, JIT, fee 3000 | `+1179070738173910`; no-JIT control `-1` | integer quote model; not a rerun of the audit PoC |
| Grok `run()` | deposit swap of 1 wei, 1%, 49%, 50%, or 51%, then the same JIT quote payout | still positive | same |
| Grok `run()` | quote mint, then slice exit, no prior push | `+1103316364600005` | same |
| Grok `run()` | proportional round trip, no sale | `0` | incumbent idle unchanged |
| Grok `run()` | idealized TWAP inside the transaction | `-573794679209779` | not the implemented oracle |
| Grok `run()` | implemented backfill, or idealized TWAP after the window | `+1970597147462162` | same push ledger |

## Disagreement that stays

MiniMax's executed-price function loses money when that file treats the vault as the LP. The interval ledger in `research/EXECUTED.md` gains money when the vault owns the active interval and fills both swaps. Grok's `self_fill_note` is positive but has 2 wei of pool dust on each token, so it is not an exact zero-conservation row. These are different machines. The draft must not pick one sign and delete the other.

A 49%, 50%, or 51% swap is not a safety threshold. MiniMax's idle book is negative at a half swap and positive when the whole deposit is swapped. The interval ledger is positive at 49%, 50%, and 51% of a 200 deposit when the vault owns the interval.

## TWAP

Source check in `coordinator/twap-source.md`: `write` credits the idle gap with the truncated live tick, and `observe` can fill an unwritten tail the same way. `update(PoolKey)` is public. That is not an outside price. Grok's rechecked rows separate an in-transaction idealized reference, which lost money, from the implemented backfill and from the same reference after the window, which did not.

## Not yet in this note

Kimi's original. Production Forge execution. Both-wing activation. A rerun of the audit PoC. None of those absences turns a closed row into a production exploit, or into implementation authority.
