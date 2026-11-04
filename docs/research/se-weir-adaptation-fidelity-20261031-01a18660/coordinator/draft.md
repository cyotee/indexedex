# Coordinator draft

## Draft identity

- Draft ID: se-weir-adaptation-fidelity-20261031-01a18660-r1
- Path: docs/research/se-weir-adaptation-fidelity-20261031-01a18660/coordinator/draft.md
- Run ID: se-weir-adaptation-fidelity-20261031-01a18660
- Status: pending advisory review. This file is not the final.
- Fingerprint: not computed
- Sources: members/astra/response.md, members/grok/response.md, members/minimax/response.md, members/kimi/response.md

## Participation

- Council kind: full
- Requested members: Astra, Grok, MiniMax, Kimi
- Substantive initial responses: Astra st_01a19300, Grok st_01a19301, MiniMax st_01a1931a after a cancelled read-loop attempt, Kimi st_01a19303
- Missing initial responses: none
- Result label: full
- Coordinator mode: invoking agent
- Coordinator is an independent vote: no

## Question

Does the full-spread PRD adapt WeirVaults to the tokenized Standard Exchange standard, or does it mix in PairToken design without authorization?

## Proposed text

These are recommendations. They do not rewrite the PRD and do not authorize implementation.

All four originals agree that the current PRD is not a Weir adaptation. It says it is a sibling of PairToken stage one and inherits that economics by ID. That is why the package inputs were copied. The owner rejected that basis. Deleting the sibling sentence without replacing the inherited economics would leave the same design under a new name.

What can stay without a new case is the tokenized shape already locked: one ERC-20 share, one pool, one full-range position, the accepted exchange routes, and the written owner locks. The money rules under that shape have to be respecified from Weir: actual swap deltas, unused input returned to the payer, idle from fees and reinvestment, and compound that harvests and reinvests without a PairToken ratio swap.

| Item | Recommendation |
| --- | --- |
| `maxZapBps` as an inherited package input | Remove. It is not Weir. Astra's separate entry-size case is not approval of the copied field. |
| `maxZapTickMove` as an inherited package input | Not settled. See the disagreement table. |
| `previewZapCredit` | Remove. Weir has no such view. The accepted previews are the quote surface. |
| Booked no-share remainder | Remove as an entrant donation. Weir refunds unused input. Idle dust from fees is a different rule. |
| `IncompleteConversion` | Remove. Weir accounts actual deltas and forbids a consumption-equality check. |
| `donate` | Already locked by FS-OWN-09. It is not a Weir function. The contradiction is left for the owner. |
| `compound` | Weir has the operation. Keep the harvest-and-reinvest behavior. Remove the PairToken compound swap, quarter-cap, and no-fee rule. |

No cap number is chosen.

## Preserved disagreements

| Topic | Positions | Not resolved in this draft |
| --- | --- | --- |
| Entry-size policy | Astra: ask the owner to authorize an explicit entry-size bound, not the copied `PkgArgs` field and not the compound quarter-cap. Grok, Kimi, and MiniMax: remove `maxZapBps` with no replacement case. | Whether any entry-size bound should exist after the copied field is removed. |
| Tick bound | Astra and Grok: the PairToken field is not authorized, but a local entry tick or price bound can be an explicit case. Grok withdraws that case if borrowed `exchangeIn` is rejected. Kimi: remove the field and do not keep it as a silent constant. MiniMax: remove the knob; if a guard is wanted, it should be a Weir-shaped price limit, authorized separately. | Whether any local price or tick guard is worth authorizing. |
| `donate` versus Weir | Kimi: the lock stands as a deliberate exception. Grok and MiniMax: the lock exists, and it contradicts Weir's refusal to book direct donations. They do not vote the lock away. | Whether the owner keeps `donate` after seeing that contradiction. |

## Evidence gaps

- No original executed a deposit.
- Astra lists additional authorization cases beyond the named items. This draft does not adopt those cases as council recommendations. Advisory should say if one of them is load-bearing and was omitted.
- The first MiniMax attempt was cancelled before it wrote a file. The settled MiniMax response is the retry.

## Coverage adopted from responses

| Target | Status | Adopted from | Conflict or gap |
| --- | --- | --- | --- |
| PairToken inheritance is the wrong basis | Read | All four | No conflict. |
| Named removals except the tick bound | Read | All four, with Astra's entry-size case separated | The copied fields are not authorized. |
| Tick bound | Read | All four | Split on whether a replacement guard needs a case. |

## Limits

- Static reading only. No execution was run for this draft.
- This draft does not claim permission confinement.
- Original response files were read and are preserved.
- No project code, configuration, or Git action is authorized by this draft.
- The coordinator did not vote on the open splits.
