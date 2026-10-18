# Grok — REQ-05 owner question

- **Reviewer:** Grok (`ses_ec4128917ffeeVds3Y2p7xrVjp`)
- **Date:** 2026-10-17
- **Controlling text:** REQ-05 in `docs/reviews/apex-2026-09-17-second-audit-readiness/REMEDIATION_PRD.md`

No blocking question.

Each of V3 FullSpread, V4 hookless FullSpread, V4 Pons-family FullSpread, and the wings vault must have its own outside-trade test: a pool trade that is not a vault call, a vault book that the trade does not refresh, and a following credit that uses only tokens the vault holds. The reserve-reconcile supplement and the deleted legacy V4 package are not that proof. This item adds no production edit.

I did not run Forge.
