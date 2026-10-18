# Astra — REQ-05 requirements check

**Replacement-session original.** I am the labeled replacement and do not recall `ses_ec412bcc2ffejKLo7nuoEAqbV0`. No other reviewers' notes were read for this check. I re-read REQ-05 at `docs/reviews/apex-2026-09-17-second-audit-readiness/REMEDIATION_PRD.md:255–268`; the original family-by-family verification remains preserved in `astra-req05.md`.

**No blocking question.**

**Closed PRD scope (one sentence):** Complete the wings vault's outside-trade physical-credit test oracle against its own accounting, preserving the independently established V3 FullSpread, V4 hookless FullSpread and V4 Pons-family FullSpread coverage, so a real pool trade outside the vault leaves its stored books unchanged and the following credit is demonstrably limited to tokens actually held, without changing production, restoring the deleted legacy V4 package, reconstructing old stored-total cases or citing the reserve-reconcile supplement as proof.

REQ-05 already fixes the four-family acceptance boundary and wings' stage-1 obligation. My independent verification identified a remaining wings assertion gap, not a production defect: its named outside-trade control checks the subsequent deposit against the vault's own preview rather than establishing the physical-credit limit. No owner decision is needed to distinguish that test-oracle repair from production work.

The other three families' source-level coverage is not an independent runtime pass, and one family's tests do not close another. No additional economics, custody rule, new error or production redesign is proposed. Historical evidence remains historical; deletion of the old package is not completion of this item.

Only this assigned Markdown requirements answer was created. No code, test, PRD, configuration or instruction file was edited. No delegation, shell, build, test or deployment was performed. This requirements conclusion does not authorize implementation. Return to the coordinator/human and stop.

I did not run Forge.
