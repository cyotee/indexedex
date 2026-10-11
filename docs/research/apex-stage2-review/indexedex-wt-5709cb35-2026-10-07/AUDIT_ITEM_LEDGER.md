# Audit-item ledger

Historical claim labels are not current criterion status. Current inspection starts at `NOT_ASSESSED`. No chain inventory is run in Stage 2.

| audit_id | historical allegation to inspect | current surfaces | linked R IDs | owner | historical claim | current inspection |
| --- | --- | --- | --- | --- | --- | --- |
| APEX-2026-001-M | Stale stored-total / outside-trade credit | V3, V4 hookless, V4 Pons, wings outside-trade tests and their bookkeeping | R3, R4, S2-ADD-005 | C02 primary; C03 C04 C05 separate | CLAIM_UNVERIFIED | NOT_ASSESSED |
| APEX-2026-001-M2 | Instance/implementation inventory | Documentary evidence only | R4, S2-ADD-008 | C01 | CLAIM_UNVERIFIED | NOT_ASSESSED |
| APEX-2026-003 | Custody SE/SY share ownership and refunds | RebasingAware targets and adversarial tests | R5, S2-ADD-003 | C06 | CLAIM_UNVERIFIED | NOT_ASSESSED |
| APEX-2026-008 | Orbital operation-scoped refund/credit | Orbital hook target and matrix behavior | R6 | C09 | CLAIM_UNVERIFIED | NOT_ASSESSED |
| APEX-2026-009 | ERC-4626/Morpho share-burn/refund | Receipt and Morpho routes | R7, R8 | C07 | CLAIM_UNVERIFIED | NOT_ASSESSED |
| APEX-2026-004B | Idle-underlying and exact-input refund | ERC-4626 SE and cited D16 consumers | R8 | C07 | CLAIM_UNVERIFIED | NOT_ASSESSED |
| APEX-2026-005 | Local-credit arithmetic and consumers | `LocalCreditLib` and actual call sites | R9 | C06 | CLAIM_UNVERIFIED | NOT_ASSESSED |
| beforeSwap retraction | Withdrawn missing-guard claim | Balancer-quad beforeSwap caller check | R10.1 | C09 | CLAIM_UNVERIFIED | NOT_ASSESSED |
| weighted-dust retraction | Withdrawn dust-theft claim | Weighted buffer-first residual | R10.2 | C09 | CLAIM_UNVERIFIED | NOT_ASSESSED |

Seven entries and two retractions are listed. None are closed by this skeleton.
