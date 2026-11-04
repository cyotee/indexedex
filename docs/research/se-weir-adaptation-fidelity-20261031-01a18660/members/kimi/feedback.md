# Kimi advisory feedback

## Identity

- Member: Kimi
- Actual Native identity: not exposed
- Advisory disposition: **support with corrections**

## Draft under review

- Draft ID: `se-weir-adaptation-fidelity-20261031-01a18660-r1`
- Path: `docs/research/se-weir-adaptation-fidelity-20261031-01a18660/coordinator/draft.md`
- SHA-256 verified before review: `eafad1d94fdf7fd8cc4d291262d98698bce2767ee9a8b16410dac8b37858a0b8`

## Fidelity to Kimi's original

The draft states my core conclusion and named-item positions accurately: the PRD's PairToken basis is unauthorized; the copied zap fields, specialized zap-credit preview, entrant no-share remainder, and `IncompleteConversion` should be removed; `donate` remains a locked deliberate exception; and PairToken's compound algorithm should not replace Weir's. The preserved disagreement table also states my positions on entry size, the tick bound, and `donate` without resolving them by vote.

The draft is incomplete as a representation of my full original in the following respects.

## Corrections by draft section

### Evidence gaps

The sentence “Astra lists additional authorization cases beyond the named items” omits that **Kimi also made two explicit authorization cases**. Record them without adopting them as consensus:

1. An operation-scoped cross-facet **write** guard and expected-callback commitment, expressly excluding PairToken's economic read guard, reserve snapshots, and per-action planner.
2. Native `sync` isolation **only on the borrowed-unlock path**, not as a blanket repair of Weir's ordinary native settlement.

These are load-bearing parts of my original because they are the only two open PairToken mechanisms for which I recommended retention. The final report should either carry them as coordinator-adopted recommendations with their cases or list them as not adopted; it should not attribute additional cases only to Astra.

### Coverage adopted from responses

The coverage table is limited to the general PairToken-basis conclusion and named zap items. It omits the broader classified inventory in my original. Add a coverage row recording that Kimi also classified, with dispositions, the following material carry-overs:

- geometric-mean and reserve-ratio issuance, removal of Weir's unassigned `MIN_SHARES`, and the `G_i`/`qCredit` non-dilution model;
- PairToken zap sizing and bootstrap restrictions, strict exit completion, zero-payout rejection, and terminal rebootstrap;
- fee checkpoints and attribution, removal of Weir's performance fee/treasury administration, and the compound ratio-swap/dust/cap rules;
- collection-only withdrawal fallback, the fixed projection/work-budget engine, and PairToken's generic booked-reserve denominator;
- the vault-self recipient ban, hookless-only restriction, removal of Weir pause/ownership behavior, per-action unlock dispatch, and economic read guards/snapshots.

If the coordinator does not adopt those classifications, label them as preserved but not adopted rather than narrowing my original to the named items. This is a coverage correction, not a request to decide any split by counting positions.

### Proposed text — `compound`

The row accurately recommends removing PairToken's no-fee rule, but it omits my lock-interpretation caveat. Preserve that FS-OWN-09 authorizes the function and that Weir's treasury cut remains the baseline **unless** “puts them back” was intended to require reinvestment of all collected fees. If that was the intended meaning, the lock conflicts with Weir and needs owner clarification. Do not present that conditional lock question as already resolved.

## Preserved disagreements

I do not withdraw or alter my positions recorded in the disagreement table, and I do not vote on which position should prevail. The owner should decide the open entry-size and tick/price-guard questions only after an explicit case; the `donate` lock remains in force while its Weir contradiction is disclosed.

## Limits

This is one static advisory pass on the hash-verified frozen draft. I did not read peer originals, edit any admitted source, run tests, or authorize implementation. These corrections concern fidelity and coverage of my original; they do not replace the draft or resolve the preserved splits.
