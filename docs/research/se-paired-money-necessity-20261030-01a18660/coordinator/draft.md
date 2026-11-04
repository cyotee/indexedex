# Coordinator draft

## Draft identity

- Draft ID: se-paired-money-necessity-20261030-01a18660-r1
- Path: docs/research/se-paired-money-necessity-20261030-01a18660/coordinator/draft.md
- Run ID: se-paired-money-necessity-20261030-01a18660
- Status: pending advisory review. This file is not the final.
- Fingerprint: recorded in RUN.md if hashed before review.
- Sources: all four member originals. All settled before this draft.

## Participation

- Council kind: full
- Requested members: astra, grok, minimax, kimi
- Substantive initial responses: all four
- Missing initial responses: none
- Result label: full
- Coordinator mode: invoking-agent
- Coordinator is an independent vote: no

## Question

Does the accepted Standard Exchange redefinition fill the same need as the paired-money functions, and which should this family keep, drop, or map?

## Proposed text

The redefinition fills the paired deposit and paired redeem need. It does not fill `donate` or `compound`.

| Function | Recommendation | Standard function |
| --- | --- | --- |
| `depositPair` | Map. Do not keep the selector. | `exchangeBundleInForSingleOut`. `tokenOut` is the share. `amountsIn` is in `vaultTokens()` order. |
| `previewDepositPair` | Map. Do not keep the selector. | `previewExchangeBundleInForSingleOut`. `tokenOut` is the share. |
| `redeemPair` | Map. Do not keep the selector. | `exchangeBundleOut`. `tokenIn` is the share. `tokensOut` are the two currencies. |
| `previewRedeemPair` | Map. Do not keep the selector. | `previewExchangeBundleOut`. `tokenIn` is the share. |
| `donate` | Keep. | None. It books tokens and mints no shares. No accepted route does that. |
| `compound` | Keep. | None. It collects fees and reinvests them without changing supply. No accepted route does that. |

Maxima versus a declared amount plus a same-token refund is not enough to keep `depositPair`. The caller is made whole either way. Keeping both entry paths would let them disagree.

Raw ETH is not covered by the accepted bundle functions. That is not a reason to keep `redeemPair`. It is also not authority to invent a standard extension. Raw ETH stays outside this redefinition, as the accepted report already says. If this family must still pay raw ETH, that is a separate product decision. This draft does not add that function.

This recommendation does not lock the PRD and does not authorize implementation.

## Preserved disagreements

| Topic | Positions | Not resolved in this draft |
| --- | --- | --- |
| Raw ETH if the family must still pay it | Grok: extend the standard later, do not invent it here, do not keep `redeemPair`. MiniMax: use the wrapped face at the standard boundary, or keep one narrow product function if raw exit is required. Astra: raw payout is a real unpaired capability. | No extension and no retained `redeemPair`. The product decision is left open. |

## Evidence gaps

- No implementation or hook caller was inspected.
- Mapping does not by itself specify PairToken share-credit accounting. The standard names the route. It does not replace S1-ACC-07.

## Coverage adopted from responses

| Target | Status | Adopted from |
| --- | --- | --- |
| Six paired-money functions | Examined by all four | All four, on the table above |
| Accepted bundle routes | Examined | All four |

## Limits

- This draft is not member-approved text.
- No project code or PRD edit is authorized.
