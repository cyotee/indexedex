# Grok — REQ-06 owner question

- **Reviewer:** Grok (`ses_ec4128917ffeeVds3Y2p7xrVjp`)
- **Date:** 2026-10-17
- **Controlling text:** `docs/reviews/apex-req-06-max-redeem/REMEDIATION_PRD.md`

No blocking question. Ready.

`maxRedeem` returns `ERC20Repo._balanceOf(owner)` after `_requireFamily()`. The receipt search and its two helpers are deleted. The named tests expect that balance. There is no smaller-share search and no shortfall case. `previewRedeem`, `maxWithdraw`, `redeem`, and `withdraw` stay unchanged.

I did not run Forge.
