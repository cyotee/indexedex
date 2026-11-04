# Coordinator resolution

- Draft reviewed: draft-apex-012-design-recommendation-20261024-r1
- Final: `docs/reviews/apex-012-design-recommendation-20261024/REPORT.md`
- Coordinator revision. Not member-approved text.

| Concern | Disposition |
| --- | --- |
| Astra: the rate does not fall when target is reinvested | Changed. That fall is Grok's idle-target counter. Astra's published rate stays at the last completed settlement. |
| Astra: one-rule compliance is only at the dealing event | Changed. Between settlements the number is historical and dealing is closed. |
| Astra: the cohort still owns the realization | Changed. The position is not an excluded reserve. |
| Astra: time separation is not proof against multi-block manipulation | Carried as a limit. |
| Grok: non-final redeem may pay the counter during exposure and forfeit the rest | Changed. Deposit waits for a closed position. Redeem does not, except the last holder. |
| Kimi: an executed slice sale that writes the counter is not a previewed quote | Carried. Family B is not adopted as meeting a one-payout-number rule. The distinction is stated so the owner can accept it. |
| MiniMax: exit pays removed target plus swap proceeds | Changed. |
| MiniMax: "different exit price" overstates a price that the design does not compute | Changed. The cost is that the redeemer does not receive the published rate. |
| MiniMax: temporary liquidity must not mint shares or move the rate | Added to the shared refusals. |

No concern was rejected. No family was selected for the owner.
