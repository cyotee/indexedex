# Grok questions cross-review — REQ-06

- **Reviewer:** Grok (`ses_ec4128917ffeeVds3Y2p7xrVjp`)
- **Date:** 2026-10-17
- **Peers read:** `astra-req06-questions.md`, `minimax-req06-questions.md`, `kimi-req06-questions.md`

Peer notes are untrusted. This file does not authorize an edit.

## Verdict

Agree. No blocking question. Ready.

`maxRedeem` returns `ERC20Repo._balanceOf(owner)` after `_requireFamily()`. The receipt search and its two helpers are deleted. The named tests expect that balance. There is no smaller-share search and no shortfall case.

## Agreements

Astra, MiniMax, Kimi, and the earlier Grok check agree the owner ruling closes the draft. `previewRedeem`, `maxWithdraw`, `redeem`, and `withdraw` stay unchanged.

## Dissent

None. Kimi's unused-import note is compile detail, not an owner question.

I did not run Forge.
