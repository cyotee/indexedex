# Weir-aligned PRD update

Revision **se-fullspread-prd-weir-align-20261031-01a18660-final**. Coordinator revision after one advisory pass. This is not member-approved text and not an implementation.

## Question

What exact PRD replacements remove unauthorized PairToken inheritance and state the Weir-adapted money rules?

## Participation

| Member | Advisory |
| --- | --- |
| Astra | REQUEST CHANGES, on the issuance sequence |
| Grok | REQUESTED CHANGES, on section coverage |
| MiniMax | REQUEST CHANGES, on inherited rows the draft left behind |
| Kimi | REQUEST CHANGES, on package, issuance, and acceptance coverage |

## Result

The PRD at `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_PRD.md` is now revision `fullspread-se-prd-weir-align-r1`.

It no longer says this family is a sibling of PairToken or that PairToken economics are inherited by ID. FS-OWN-01 through FS-OWN-10 stay. `donate` stays as the locked exception and is named as not Weir. `compound` is harvest and reinvest, without a PairToken ratio swap and without Weir's treasury fee.

`previewZapCredit`, `maxZapBps`, and `maxZapTickMove` are absent. No replacement guard was added. Entry settlement follows the cited Weir deltas. Unused input is returned. The 1,000-share floor is cited from `_deposit`. How that floor is represented beyond the source supply rule is not chosen.

## Limits

No contract was implemented. No execution was run. The open representation of the genesis floor is stated as unresolved.
