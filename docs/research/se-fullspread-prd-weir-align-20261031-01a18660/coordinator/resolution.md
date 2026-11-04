# Coordinator resolution

- Draft: se-fullspread-prd-weir-align-20261031-01a18660-r1
- SHA-256: c7afa4cd5c82ff0338ebe3cc09ab5aa216280fa17a2c584127b349e73cd10527
- Published to: contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_PRD.md
- Revision: fullspread-se-prd-weir-align-r1
- The publication changes are coordinator revisions after advisory. They are not a new member vote.

| Concern | Disposition |
| --- | --- |
| Astra, Grok, MiniMax, Kimi: the draft's direction matches | Adopted as the basis of the PRD edit. |
| MiniMax and Kimi: replacing the inheritance sentence leaves the old list, package checks, and acceptance rows | Adopted. Those rows were replaced in the PRD. |
| Astra: state the full genesis sequence, including the later addition of minted shares | Adopted in FS-MONEY-01. |
| MiniMax: the floor is supply not credited to the recipient, not an open holder address | Adopted. No holder address was chosen. |
| MiniMax: name the removed acceptance rows | Adopted in FS-TEST-02. |
| MiniMax: state the range-boundary swap limit and pro-rata idle | Adopted. `zapTo` was not added. |
| Treasury performance fee | Not added. The PRD says that absence is not PairToken's no-fee rule. |
| Genesis-floor representation and second-currency encoding | Left unresolved. The PRD states the cited formula and the accepted return. It does not add a ledger, a holder, or a return field. |
| Zap guards | Not added. |
