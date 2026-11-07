# FullSpread vault acceptance validation - 2026-11-07

`15-vault-regressions.log` rebuilt affected vault and seven-family artifacts,
then ran 19 suites: 285 passed and six failed, 291 total.
All six failures were in newly strengthened test fixtures:

- Four tests registered identical counted `expectCall` expectations repeatedly
  across snapshot-restored cases. Zero-call expectations now span the complete
  case loop. Locked/borrowed mint parity counts six manager unlocks and four
  vault callbacks across two faces: two locked actions and one borrowed outer
  unlock per face. This matches the existing callback suite's per-action law.
- The exact-output negative passed an unfunded uint256 maximum to a router
  that transfers the maximum before calling the hook. It now uses the actual
  funded raw-token balance and reaches the exact inverse-preview rejection.
- Direct new-feeTo maintenance initially expected reinvestment from a lone
  one-sided donation. It now distinguishes the first booked donation from
  the subsequent two-sided reinvestment, then accrues real pool fees and
  positively calls compound as the new owner. Exact funding and no-issuance
  assertions remain.

`15-vault-fixture-corrections.log` passed five of the six repaired cases.
The remaining aggregate unlock expectation was corrected against the existing
two-action callback test, and `15-borrowed-mint-parity.log` passed that case
with exit code 0. All 291 unique cases therefore have passing receipts.
No production vault behavior was changed to make these tests pass.
The final borrowed-file LSP freshness request timed out; Solar subsequently
compiled it successfully and executed the corrected test.

The dedicated nine-matrix plus inherited integration run,
`15-original-failures.log`, passed all 315 cases across 18 suites with
exit code 0 and no skips. Exact identity reconciliation found all 36 original
instances passing with no missing row; see `15-original-outcomes.md`.
`15-original-negatives.md` indexes 62 independent passing negative identities
from the same actual run. Task 15's original fixture migration is complete.
This does not close wider family, interpretation, or release gates.
