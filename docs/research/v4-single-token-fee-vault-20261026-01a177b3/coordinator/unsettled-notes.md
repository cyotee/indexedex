# Unsettled notes

Not a draft. Grok had not reached Native completion when this note was updated. Astra, MiniMax, and Kimi have settled. Grok had not written `response.md`.

| Member | File on disk | Recommendation read from the file | Constraint that member says the design breaks |
| --- | --- | --- | --- |
| astra | yes, settled | T cash vault plus assigned T-denominated LP fee receipts. A sponsor keeps the LP principal. Users deposit and redeem T. | Same-capital reuse of the LP inventory. The share is not the liquidity. |
| minimax | yes, settled | ICHI-style directional V4 liquidity, conservative book valuation, redeem only in X. | Does not claim the remaining pool-price exposure disappears. |
| kimi | yes, settled | Price-free per-component join, single-token exit, unpriced zap in front of issuance. | Strictly single-token deposit at the accounting boundary. |
| grok | no response file | not read | not read |

Do not average these. Wait for Native settlement before the draft.
