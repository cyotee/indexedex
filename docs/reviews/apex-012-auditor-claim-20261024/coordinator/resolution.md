# Coordinator resolution

- Draft reviewed: draft-apex-012-auditor-claim-20261024-r1
- Final: `docs/reviews/apex-012-auditor-claim-20261024/REPORT.md`
- Coordinator revision. Not member-approved text.

| Concern | Disposition |
| --- | --- |
| Honest `V0` deposit and inflated `V1` redeem is the withdrawal story, not a broadening | Changed. The report is broader on the spot channel and on unsettled in-unlock depth. |
| "Accounted as a loss" is the owner's wording | Changed. The report shows holder entitlement falls and that `HolderValueLoss` does not see the inflation. It does not establish a separate loss-recording entry. |
| Settled sequence must include the later removal | Changed. |
| 7.5% figure belongs to the settled path and is valued at the starting price | Changed. |
| Scripted 0% sleeve blocks the in-unlock path only | Changed. |
| In-unlock profit is capped by the pre-attack sleeve and can repeat when it refills | Changed. |
| SEC-08 names temporary liquidity and JIT; the tested bound still passes | Changed. Not turned into an invalid-call claim. |
| Status is High and latent, not deployed | Changed. |
| Fix list should keep `requiredInput`, the TWAP-bounded `V_ref` example, and the haircut fee | Changed, as the auditor's list. Not adopted. |

No concern was rejected.
