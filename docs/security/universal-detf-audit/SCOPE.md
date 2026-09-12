# Review scope and status

Priority: universal Uniswap V4 DETF composed with Single Standard Exchange Buffer Constant Product hook. Robinhood infrastructure is reported deployed by the owner; this review has not changed or verified deployed instances.

| Component | Current review status |
|-----------|-----------------------|
| Universal DETF Target/Common | Initial money-path read; mature-close authorization corrected and verified; remaining accounting review incomplete |
| Universal bond NFT vault | Close/retire, reward authorization and custody helper review; full reward/claim audit incomplete |
| Selected CP hook | Initialization/deployment checks and partial callback/pull/accounting read; canonical initialization fix pending runtime verification |
| Collector / fee oracle | Initial source tracing; downstream fee routing and live proxy cuts unverified |
| Crane | Required guidance and relevant helper implementations consulted; broad framework review incomplete |
| Other hooks | Existing D25 shared-code regression checks pass; not a full audit of their implementations |
| External SE integrations | Gold fixture used for authorization reproduction; production integration matrix rerun pending |

Do not describe this scope record or its passing tests as a completed production security audit.
