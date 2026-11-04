# Coordinator draft

## Draft identity

- Draft ID: se-fullspread-prd-weir-align-20261031-01a18660-r1
- Path: docs/research/se-fullspread-prd-weir-align-20261031-01a18660/coordinator/draft.md
- Run ID: se-fullspread-prd-weir-align-20261031-01a18660
- Status: pending advisory review. This file is not the PRD and not the final.
- Sources: members/astra/response.md, members/grok/response.md, members/minimax/response.md, members/kimi/response.md

## Participation

- Council kind: full
- Requested members: Astra, Grok, MiniMax, Kimi
- Substantive initial responses: Astra st_01a19369, Grok st_01a1936a, MiniMax st_01a1936b, Kimi st_01a1936c
- Missing initial responses: none
- Coordinator mode: invoking agent
- Coordinator is an independent vote: no

## Question

What exact PRD replacements remove unauthorized PairToken inheritance and state the Weir-adapted money rules, without reopening a locked owner decision and without inventing a zap guard?

## Proposed text

These replacements are recommendations for the coordinator to apply after advisory. They do not implement contracts.

### Goal

Replace the two paragraphs that begin "This is not WeirVaults" and "It is a sibling of PairToken".

This family adapts the cited money operations of `contracts/protocols/strategy/weir/WeirVaults.sol` to the tokenized Standard Exchange standard. It has one ERC-20 share, one pool, and one full-range position. It does not copy Weir's manager of many virtual vaults.

It is not a sibling of PairToken and does not inherit PairToken economics by requirement ID. FS-OWN-01 through FS-OWN-10 stay locked. A PairToken economic or package choice stays only where one of those locks already keeps it.

Replace the first bullet under "What this family is not" with: not a source copy of Weir's multi-vault manager, and not a mechanical wrapper around its internal share ledger.

### FS-X04

Replace the row.

Single-token entry does not require the selected swap to consume its entire input. There is no `IncompleteConversion` check. `deposit` returns unused declared input to the payer. `_deposit` settles from the deltas actually returned and sends a positive credit back to the depositor. Addition remainder `J_i` is not booked to shared backing. Issuance follows FS-MONEY-01, not S1-ACC-07. This row does not change the accepted one-token exit. That route pays the selected token or reverts.

### FS-OWN-09 and FS-OWN-10

Keep both locks. Add these clarifications.

`donate` stays because FS-OWN-09 keeps it. `WeirVaults.sol` has no `donate`. `deposit`, `withdraw`, and `_compound` do not book a direct transfer as a donation. Keeping `donate` is an explicit exception. It does not restore PairToken issuance.

`compound()` stays the locked selector. Its behavior is harvest and reinvest, as in `_compound`, without PairToken's ratio swap or quarter-cap. `unlockCallback` calls `_compound` before `_deposit` and before `_withdraw`. That ordering is the adaptation. It does not add Weir's `compound(PoolKey, bytes)` selector. Weir's treasury performance fee is source attribution only. This update does not add that fee, and it does not adopt PairToken's no-fee rule.

`previewZapCredit`, `maxZapBps`, and `maxZapTickMove` are absent. No replacement view, cap, tick bound, or hidden constant is added. Delete those two fields from `PkgArgs`. Delete `IncompleteConversion` from the family error list.

### Authority

Replace PairToken stage one as the economics authority. `WeirVaults.sol` is the source of the deposit, withdrawal, issuance, and compound rules expressly stated here. Its multi-vault manager, administration surface, and treasury fee are not inherited. PairToken stage one is not an economics authority. No issuance, zap-credit, addition-remainder, or package zap rule is inherited from it. An FS delta no longer means "every other clause of that inherited requirement stays."

Keep the accepted Standard Exchange routes, hook bindings, and owner locks. Do not rewrite those except where a sentence asserts a removed rule.

### FS-MONEY-01

Replace the inherited-surface section with these rules. Citations are from the current `WeirVaults.sol`.

- `deposit` pulls the declared amounts, then sends `amount - used` of each currency back to `msg.sender`.
- `_deposit` settles each currency from the net delta. A positive credit goes back to the depositor. Shares are credited to `p.recipient`, who need not be the payer.
- There is no consumption-equality check.
- If `totalShares` is zero and liquidity is above `MIN_SHARES`, minted shares are `liquidity - MIN_SHARES`, and `totalShares` is set to `MIN_SHARES`. The source comment says that floor is never redeemable. `MIN_SHARES` is `1_000`.
- Otherwise minted shares are `liquidity * totalShares / v.liquidity`. Idle balances are not in that denominator.
- `_compound` harvests fees by a zero-liquidity modification, reinvests the remainder plus idle, and holds leftover as idle. The source also takes `perfFeeBps` to `treasury`. That cut is not adopted here.
- `unlockCallback` compounds before deposit and before withdrawal.

The accepted routes stay. Do not install Weir's `deposit`, `withdraw`, `zap`, or `zapTo` selectors. Do not add a return field. Unused input and a positive credit are returned to the payer. They are not booked without shares. The one-token exit still pays only the selected token or reverts.

The ERC-20 representation of the unredeemable `MIN_SHARES` floor is not chosen. Do not add a second share ledger, pick a holder address, or rescale the constant in this update.

### Tests and acceptance

Replace rows and bullets that require `IncompleteConversion`, booked `J_i`, `previewZapCredit`, `maxZapBps`, `maxZapTickMove`, or S1-ACC-07 share credit. A predicted partial selected entry swap is no longer a revert-before-funds case. Unused input is returned. The one-token exit row stays. Do not add a test for a cap or tick guard that this update does not define.

## Preserved disagreements

| Topic | Positions | Not resolved in this draft |
| --- | --- | --- |
| Genesis floor as a new lock | MiniMax treats adopting `MIN_SHARES` as needing a separate owner lock because the old PRD forbade dead shares. Grok states the `_deposit` branch as the adaptation. Astra says the source floor is known, and the ERC-20 representation is not. | The draft states the cited formula and does not choose the representation. It does not restore the old dead-share ban. |
| Second-currency credit on a one-token route | Astra says not to force every source credit into one refund figure or add a return field. The other originals say unused input is returned and remainder is not booked. | The draft returns the credit to the payer and keeps the accepted return. It does not define a new encoding. |

## Limits

- The coordinator checked `deposit`, `unlockCallback`, `_deposit`, `_withdraw`, and `_compound` in the current `WeirVaults.sol`. No execution was run.
- This draft does not edit the PRD.
- No zap guard and no performance fee are proposed.
- Original response files are preserved.
