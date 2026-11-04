# Zap cap relevance

Revision **se-zap-relevance-20261031-01a18660-final**. Coordinator revision after one advisory pass on draft `se-zap-relevance-20261031-01a18660-r1`. This is not member-approved text, not an implementation, and not a PRD lock.

## Question

Does the adopted design configure `maxZapBps` and `maxZapTickMove`, are those caps relevant, and is `previewZapCredit`'s per-currency split useful to a caller?

## Participation

| Member | Advisory |
| --- | --- |
| Astra | SUPPORT WITH CLARIFICATIONS |
| Grok | REQUESTED CHANGES, on attribution |
| MiniMax | SUPPORT WITH RESERVATIONS |
| Kimi | SUPPORT WITH ONE CORRECTION |

## Answer

### Weir does not configure either cap

No. All four verified that Weir has neither `maxZapBps` nor `maxZapTickMove`.

Weir's zap controls are the deposit `zap` flag, withdrawal `zapTo` of 0, 1, or 2, at most one in-pool swap, the pool's extreme price limit, a deadline, `minShares` on deposit, `min0` and `min1` on withdrawal, and a refund of unused input. `perfFeeBps` cuts harvested fees. It is not an entry-size cap. The extreme price limit allows a consumed swap, not only a partial fill, to move the tick to the boundary.

The full-spread PRD is a different document. It currently lists both fields in `PkgArgs` because that section says `PkgArgs` is the PairToken set, and it rejects invalid zap limits. That is an inherited PairToken requirement, not a Weir setting. The public getters are still open. A package field is not the same thing as a getter.

So the question in front of the owner is whether to keep, narrow, or drop a requirement the current PRD already carries. It is not whether Weir needs these settings added.

### The caps do work Weir's limits do not

All four agree on that distinction. None treats the caps as required to copy Weir.

A size cap bounds an entry against pool reserve. Weir's half-imbalance swap scales with the caller's own deposit, so a large deposit into a shallow pool can still move the price. A tick-move cap bounds how far that entry swap may move the tick. `minShares` protects the caller's share output. It is not either bound. No number was chosen.

Astra would retain both purposes for single-token entry, once the reserve basis and checkpoint are defined. That does not decide the getters. Astra would not automatically carry PairToken's compound quarter-cap just because the field name stays.

Kimi would not import that compound coupling. MiniMax says state the size cap as entry-only, or decide the compound coupling on purpose. Grok says the inherited list already keeps a size test and an entry tick test, and a failed conversion is not that ceiling. Whether a retained size cap also bounds `compound()` is not settled.

### The per-currency split

`previewExchangeIn` returns shares and one same-token refund. It does not return how much of each currency bought shares, or how much of each currency did not.

That split has two uses. The credit pair shows how a one-sided entry was funded across both currencies. The uncredited pair shows value booked to the shared book without minting extra shares. A caller could use the second to refuse a deposit that donates too much, or that donates the currency they do not want to add. One share figure and one same-token refund cannot reconstruct those four amounts, because the swap moves value between the currencies.

The second use exists only if the vault books that remainder. MiniMax reads the current PRD as already saying that. Astra, Grok, and Kimi do not treat that text as an owner lock. This report does not close that reading.

If unused input is refunded, as Weir does, the booked-remainder use does not survive. The uncredited pair is zero because the unused input came back. Astra would not keep `previewZapCredit` solely for that rationale. Grok says the decision use does not survive. MiniMax says the disclosure then collapses into the same-token refund a refunding preview already returns, so a separate preview should be judged again rather than kept by inertia. Kimi keeps only a narrower execution breakdown, and only if the fields are refund-aware. If the fields only expose a booked residual, Kimi rejects that justification too.

## Limits

No implementation was run. This report does not edit the full-spread PRD or the function-review file. It does not authorize code changes.
