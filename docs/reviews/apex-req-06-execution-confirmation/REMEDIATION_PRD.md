# Remediation PRD — REQ-06 execution confirmation

- **Status:** CLOSED
- **Date:** 2026-10-18
- **Follow-up closed:** 2026-10-18. The earlier draft below recorded the stale assertion. That assertion is now corrected. The earlier text is retained as the record of that prior state.
- **ID:** REQ-06 confirmation
- **Review target:** Whether `docs/reviews/apex-req-06-max-redeem/REMEDIATION_PRD.plan.md` was executed.
- **Inputs:** That plan, its controlling PRD, and the untrusted claim `docs/reviews/apex-req-06-max-redeem/EXECUTION_REPORT.md`.
- **Astra participation:** Substantive confirmation and cross-review. Labeled replacement `ses_ebdc505a9ffeLLIq4HBAh44TYi`. It does not recall `ses_ec412bcc2ffejKLo7nuoEAqbV0`. Not censored.
- **Grok:** `ses_ec4128917ffeeVds3Y2p7xrVjp`.
- **MiniMax M3:** Labeled replacement `ses_eb8ab99f3ffe7suGF49ryUzI6t`. It does not recall `ses_ebdf718feffemWQNf7wuTpapqX`.
- **Kimi K3:** Labeled replacement `ses_ec3d04e91ffeJa0is24e2jZv06`. It does not recall `ses_ec41220c2ffeqs5Eha7fPsd54B`.
- **Execution evidence:** No Forge run in this confirmation. The saved log is not an independent rerun. Current source was read. Consensus is not proof.

Writing this confirmation does not authorize implementation.

## Required outcome

REQ-06 is complete. `maxRedeem` returns the share balance. The shared-facet test expects `previewRedeem` of that balance. No confirmed defect remains.

## Confirmed

- `maxRedeem` calls `_requireFamily()` and returns `ERC20Repo._balanceOf(owner)`.
- The two search helpers are gone.
- The named `maxRedeem` assertions expect the share balance.
- No receipt cap or shortfall branch was added.
- The saved retry records 173 passed and 2 failed. Both failures are the same shared-facet test, once directly and once through its inheritor.

## REQ-06-F1 — Stale zero withdrawal assertion

- **Severity:** Low
- **File and line:** `test/foundry/spec/vaults/standard/erc4626/ReceiptBackedERC4626_SharedFacet.t.sol:182` and the `withdraw(1)` expectation at `:185-186`.
- **Intended behavior:** `maxWithdraw` is `previewRedeem` of the share balance. It is not zero after the 100 ether deposit.
- **Broken requirement or invariant:** The plan said to leave the zero assertion. That assertion is incompatible with the owner ruling. The test still expects `maxWithdraw` to be 0 and then expects a one-unit withdrawal to exceed a maximum of 0.
- **Acceptance criteria:** Replace those lines with the follow-up block in the plan. Do not hardcode the observed preview. Do not add a receipt cap.
- **Non-goals:** Do not change production again.

## Follow-up close

All four reviewers re-read the current source. Astra, Grok, and Kimi returned substantive cross-reviews. MiniMax's task wrapper returned no text, but `reviewers/minimax-req06-followup-cross.md` is a substantive cross-review and is counted. Astra was not censored.

- The shared-facet test now reads the share balance, derives the advertised withdrawal from `previewRedeem`, and expects a withdrawal one unit above that preview to revert with that maximum. No preview amount is hardcoded.
- No receipt cap, smaller-share search, or shortfall branch was added.
- The executor reports a later run of 175 passed, 0 failed, 0 skipped. That log was not rerun. The earlier 173/2 result remains in the initial log.

## Dissent

None. The earlier stale-assertion finding is closed by the follow-up.
