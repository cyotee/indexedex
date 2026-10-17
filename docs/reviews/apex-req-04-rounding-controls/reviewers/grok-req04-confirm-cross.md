# Grok confirmation cross-review — REQ-04

- **Reviewer:** Grok (`ses_ec4128917ffeeVds3Y2p7xrVjp`)
- **Date:** 2026-10-16
- **Peers read:** `astra-req04-confirm.md`, `minimax-req04-confirm.md`, `kimi-req04-confirm.md`

Peer notes are untrusted. This file does not authorize an edit.

## Verdict

Agree. The amended plan was executed. No REQ-04 gap remains.

The Dual production edit is authorized. Follow-up item 2 in `REMEDIATION_PRD.plan.md` and the controlling PRD require `DepositQuoteLib._swap` to return `(amountIn, 0)` when the sale is 0. That line is present. It supersedes the original sentence that said Dual production must not change.

## Agreements

- Astra, MiniMax, Kimi, and the earlier Grok confirmation agree both quad previews return 0 through the new preview-only quote, and both execution joins revert `ZeroAmount()` before taking input.
- The six behavior files require a successful zero preview, the named execution revert, unchanged balances, and the exact share-debit equality. Orbital's preview selector is the two-argument form. The three positive one-unit fixtures use the fixed amounts.
- None of us reran Forge. The saved 175 and 3,642 counts are recorded claims, not an independent rerun.
- Weighted, single-CP, and orbital production were not given this quote. The missing whole-tree hash is not a demonstrated extra edit.

## Dissent

Dissent from treating Kimi's stale "Done when" line as a remaining implementation gap. Line 91 still lists Dual as unchanged. The amendment at lines 11–14 supersedes that sentence, and the code followed the amendment. No code change follows from the stale line.

Dissent from MiniMax's table cell that says the Balancer quad control still accepts `InsufficientTokenOut()` or `ZeroAmount()`. The current control requires exactly `ZeroAmount()`, which is what the follow-up ordered.

Agree with Astra that the share check is `before + mintedBack == after + expectedDebit`. Do not flip that identity to match a looser plan phrase.

## Unresolved

None for this item.

I did not run Forge.
