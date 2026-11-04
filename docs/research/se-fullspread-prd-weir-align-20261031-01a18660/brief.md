# Brief

## Identity

- Run ID: se-fullspread-prd-weir-align-20261031-01a18660
- Profile: research, with an authorized documentation update after the final
- Council kind: full
- Requested members: Astra, Grok, MiniMax, Kimi
- Coordinator mode: invoking agent
- Output root: docs/research/se-fullspread-prd-weir-align-20261031-01a18660/
- Publication target: contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_PRD.md
- Authorization: the owner asked the council to update that PRD with the locked decisions and to clarify it so it adapts WeirVaults. This brief does not authorize contract implementation.

## Question

What exact PRD replacements remove unauthorized PairToken inheritance and state the Weir-adapted money rules, without reopening a locked owner decision and without inventing a zap guard?

## Owner directive

This vault adapts WeirVaults to the tokenized Standard Exchange standard. It is one ERC-20 share, one pool, and one full-range position. It is not a copy of Weir's multi-vault manager, and it is not a sibling of PairToken. PairToken economics are not inherited. A PairToken aspect stays only where an owner lock already keeps it.

The owner has not authorized a replacement for `maxZapBps`, `maxZapTickMove`, or `previewZapCredit`. Do not invent one. Do not choose a cap number.

## Locked decisions to preserve

Preserve the substance of FS-OWN-01 through FS-OWN-10. Do not reopen them.

- FS-OWN-09 keeps `donate` and `compound`. `donate` is an explicit exception. Weir does not book a direct transfer as a donation. Say that. Do not delete the lock.
- `compound` stays, but its behavior is Weir's: harvest fees and reinvest them. It is not PairToken's ratio swap, quarter-cap, or no-fee rule. Cite the Weir function. Do not add a fee the owner did not authorize.
- FS-OWN-08 keeps the accepted routes and the `(amountOut, amountRefunded)` return. The one-token exit pays the selected token or reverts. That exit rule is not `IncompleteConversion`.
- FS-OWN-10 drops `previewWithdrawalMode` and the family `wrappedNative()` getter. Its current last sentence, that the zap views stay open, is superseded by this update. Close them as absent, not as a new design.

## Required removals

Remove these as unauthorized PairToken carry-overs:

- The Goal sentence that calls this family a sibling of PairToken and says to inherit that economics by ID.
- PairToken stage one as the economics authority. It is not the source of issuance, zap credit, or package zap fields.
- `maxZapBps` and `maxZapTickMove` as `PkgArgs` fields.
- `previewZapCredit`.
- `IncompleteConversion` as an entry consumption-equality check.
- Booking addition remainder `J_i` to shared backing without extra shares.
- Inherited share credit `S1-ACC-07` as this family's issuance rule.

## Required Weir alignment

Read `contracts/protocols/strategy/weir/WeirVaults.sol` before writing a money rule. Cite the function. Do not invent a formula the source does not state.

State, with a citation:

- Unused declared input is returned to the payer.
- A swap is settled from the deltas actually returned. There is no consumption-equality check.
- How Weir issues shares, including whether idle is in the denominator and whether a genesis case exists. Quote the source. If the source does not state a formula you expected, say that and do not add one.
- `compound` harvests and reinvests, and whether Weir calls it before deposit and before withdrawal.

The accepted one-token exit remains. It is a route constraint, not a Weir two-currency zap and not `IncompleteConversion`.

## Targets

Read these. Do not edit them on the initial pass.

- contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_PRD.md
- contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/PAIRTOKEN_FUNCTIONS_FOR_REVIEW.md
- docs/research/se-weir-adaptation-fidelity-20261031-01a18660/REPORT.md
- contracts/protocols/strategy/weir/WeirVaults.sol

Sections that must be covered: Goal, Authority and precedence, FS-X04, FS-OWN-10's open-zap sentence, package inputs and `PkgArgs`, FS-MONEY-01, the issuance table, and every acceptance or test row that asserts a removed rule. Name any other PairToken-economics sentence you find, by section.

Do not rewrite hook bindings, compiler law, or locked facet wiring except where a sentence asserts a removed rule.

## Member boundaries

Write only the assigned `members/<member>/response.md`. Do not edit the PRD, the review file, this brief, or a peer file. Do not read peer responses. Do not delegate. Do not run Forge, Git, installs, or deployments. Do not implement.

A case for a new guard goes under "Requires owner authorization" and is not proposed PRD text.
