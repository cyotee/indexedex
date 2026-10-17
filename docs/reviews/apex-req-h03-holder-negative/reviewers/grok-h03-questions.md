# Grok — REQ-H03 question

- **Reviewer:** Grok (`ses_ec4128917ffeeVds3Y2p7xrVjp`)
- **Date:** 2026-10-16
- **Controlling text:** `docs/reviews/apex-req-h03-holder-negative/REMEDIATION_PRD.md`

No blocking question.

The owner ruling replaces the panic-only expectation. `_burn(Storage, address, uint256)` must revert `IERC20Errors.ERC20InsufficientBalance(account, currentBalance, amount)` before storage changes, then decrease that balance once, decrease supply, and emit the existing `Transfer`. It must not call `_decreaseBalanceOf`. The V3 test must expect `IERC20Errors.ERC20InsufficientBalance.selector` with `holder, 0, 1`. A different revert stops and is reported. The shared-library effect of editing `ERC20Repo._burn` is the stated target, not a question.

I did not run Forge.
