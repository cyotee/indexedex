# Grok questions cross-review — REQ-05

- **Reviewer:** Grok (`ses_ec4128917ffeeVds3Y2p7xrVjp`)
- **Date:** 2026-10-17
- **Peers read:** `astra-req05-questions.md`, `minimax-req05-questions.md`, `kimi-req05-questions.md`

Peer notes are untrusted. This file does not authorize an edit.

## Verdict

No blocking question.

Each of V3 FullSpread, V4 hookless FullSpread, V4 Pons-family FullSpread, and the wings vault must show its own outside pool trade, an unchanged vault book, and a following credit limited to tokens the vault holds. A quote that matches execution is not that credit proof. The reserve-reconcile supplement and the deleted legacy V4 package are not the proof. This item adds no production edit.

## Dissent

- Astra's wings-only scope is rejected. REQ-05 says one family does not close another, and the wings test is the same three-part test, not the only one.
- MiniMax and Kimi treat `minted == preview` as the held-token proof and close the item with no new test. The existing sentence requires the credit to use only tokens the vault holds. Those tests do not show that.

I did not run Forge.
