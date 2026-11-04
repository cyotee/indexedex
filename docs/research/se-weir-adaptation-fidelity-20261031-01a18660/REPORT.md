# Weir adaptation fidelity

Revision **se-weir-adaptation-fidelity-20261031-01a18660-final**. Coordinator revision after one advisory pass on draft `se-weir-adaptation-fidelity-20261031-01a18660-r1`. This is not member-approved text, not an implementation, and not a PRD rewrite.

## Question

Does the full-spread PRD adapt WeirVaults to the tokenized Standard Exchange standard, or does it mix in PairToken design without authorization?

## Participation

| Member | Advisory |
| --- | --- |
| Astra | REQUEST CHANGES, on attribution and omitted cases |
| Grok | REQUESTED CHANGES, on attribution |
| MiniMax | SUPPORT WITH CORRECTIONS |
| Kimi | SUPPORT WITH CORRECTIONS |

The first MiniMax attempt was cancelled. It never wrote a file. The settled original is the retry.

## Answer

The PRD does not adapt Weir. It is PairToken stage-one economics with a full-range Uniswap V4 position. Its Goal section says it is a sibling of PairToken and inherits that economics by ID. That is why `PkgArgs` was copied. The owner rejected that basis. Deleting the sibling sentence without replacing the inherited economics would leave the same design under a new name. The inheritance also sits in the authority table and in the money rules, not only in that one sentence.

What can stay without a new case is the tokenized shape already locked: one ERC-20 share, one pool, one full-range position, the accepted exchange routes, and the written owner locks. The money rules under that shape have to be respecified from Weir.

| Item | Recommendation |
| --- | --- |
| `maxZapBps` as a copied package field | Remove. It is not Weir. |
| `maxZapTickMove` as a copied package field | Remove as a copied field. A replacement guard is not settled. |
| `previewZapCredit` | Remove. Weir has no such view. |
| Booked no-share remainder | Remove as an entrant donation. Weir refunds unused input. Fee idle is a different rule. |
| `IncompleteConversion` | Remove as an entry rule only. It does not remove the accepted one-token exit. |
| `donate` | Already locked. It is not a Weir function. Left for the owner. |
| `compound` | Keep the Weir harvest-and-reinvest operation. Do not import PairToken's ratio swap or quarter-cap by silence. |

No cap number is chosen.

### What Weir does that the PRD replaced

Unused declared input goes back to the payer. A swap is settled from the deltas actually returned. There is no consumption-equality check. Shares are issued from liquidity, with a genesis floor, and idle is not in that denominator. Compound runs before deposit and before withdrawal, harvests fees, and reinvests. It does not run a ratio swap. Direct transfers are not booked as donations.

The PRD instead inherits PairToken share credit, books an addition remainder without extra shares, requires the selected entry half-swap to consume its whole input, and uses a withdrawal-only collect-or-compound fallback that Weir does not have.

### Authorization cases, not adopted

These are member cases. They are not council requirements and not owner approval.

- Astra would ask for an explicit entry-size bound, separate from the copied `maxZapBps` field and from any compound cap.
- Astra and Grok would ask for a local entry tick or price bound, not the copied `maxZapTickMove` field. Grok withdraws that case if the borrowed `exchangeIn` path is rejected. Kimi would not keep the field as a silent constant. MiniMax would remove the knob. If a guard is wanted, MiniMax says it should be a Weir-shaped price limit, authorized separately.
- Kimi would keep an operation-scoped write guard and expected-callback commitment, and would not import PairToken's economic read guard. Kimi would also isolate native `sync` to the borrowed-unlock path only.
- Grok has three further cases in the original. They were not adopted here.

`donate` stays only because FS-OWN-09 locked it. Weir does not book direct donations. The council does not vote that lock away. If it stays, that is an explicit exception, not a path back to PairToken issuance.

MiniMax treats the missing treasury performance fee as a possible deliberate divergence under the standard fee surface. That is not a council decision to add Weir's fee, and it is not a decision to import PairToken's no-fee rule.

## Limits

No implementation was run. This report does not edit the full-spread PRD. It does not authorize code changes.
