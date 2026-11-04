# Coordinator resolution

- Draft reviewed: draft-apex-012-prd-clarity-20261024-r1
- Final: `docs/reviews/apex-012-prd-clarity-20261024/REMEDIATION_PRD.md`
- This resolution is a coordinator revision. It is not member-approved text.

| Concern | Disposition |
| --- | --- |
| Kimi: defect 2 attributed the direct contradiction to all four | Changed. All four recorded the missing mint basis. The direct conflict was explicit in a subset. |
| Astra 7 and Grok 1: the sum formula leaned on a design | Changed. The question asks for a per-slot common fraction. It does not offer a summed or target-only formula as an unconstrained choice. |
| Astra 8: idle ownership was already required | Changed. The question is how exit and leftovers implement that ownership, not whether idle is owned. |
| Astra 8 and MiniMax C3: rebalance must not reopen the sell ban | Changed. The ban stands. The question is only how the existing swap path is removed or disabled. |
| Astra 9 and Grok 5: `quoteRate` and `liquidationValue` already have a disposition | Changed. Live valuation is not reopened. The open items are projected `state_`, the executing exact routes, and exact-output refund rules. |
| Astra 1, Grok 3, MiniMax C2 and C4: fees, LP fee, and harvest re-place | Carried as expanded questions. |
| Astra 2 and Grok 2 and 4: snapshots, refund, two-sided predicate | Carried. |
| Astra 3: empty slot while supply remains, per-slot rounding | Carried, constrained by the ban on later deposits opening a range. |
| Astra 4: counter domain if a debit exceeds the counter | Carried. No implementation is selected. |
| Astra 5: donation boundary | Carried. |
| Astra 6: test 2 inequality | Carried as a test requirement, not a product redesign. |
| MiniMax C1: V3 `slot0` versus the current-tick split | Carried. A literal ban makes the specified exit unimplementable. |
| Astra 10 and Grok 7: older mandate precedence | Kept as a precedence question. Wording was re-read, including the 2026-10-15 header. It does not invite a third model. |
| Grok 6: shared policy overstated | Changed. Members share the prohibitions and scope rulings, not the accounting equations. |

No concern was rejected. No economic design was added.
