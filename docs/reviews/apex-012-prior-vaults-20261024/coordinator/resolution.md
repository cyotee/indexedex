# Coordinator resolution

- Draft reviewed: draft-apex-012-prior-vaults-20261024-r1
- Final: `docs/reviews/apex-012-prior-vaults-20261024/REPORT.md`
- Coordinator revision. Not member-approved text.

| Concern | Disposition |
| --- | --- |
| Charm was not shown to fail the auditor's spot-move sequence | Changed. Charm is spot-sensitive. The survey did not run that sequence against it. |
| Two-token inference needs more than a fixed spot | Changed. Vault-owned liquidity, inventory, fees, and supply are also held fixed. |
| Delayed fee recognition is the proposed adaptation, not a Panoptic restriction | Changed. Fee earning is not given up. Recognition waits for a real credit. |
| Cached mark is unchanged between updates, and a refresh is not shown to be a sale into remaining depth | Changed. |
| Arrakis and Charm formulas also read idle balances | Changed. |
| Charm's TWAP gates rebalance, not the payment. Arrakis evidence is the underlying library | Changed. |
| The survey supports none of the auditor's fix list | Changed. |
| Slot0 readers were grouped by some members on the spot-move sequence, not on the depth claim | Changed. |

No concern was rejected.
