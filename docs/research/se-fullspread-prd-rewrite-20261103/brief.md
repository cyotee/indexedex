# Council brief

## Run

- Run ID: se-fullspread-prd-rewrite-20261103
- Profile: research
- Council kind: full
- Question: What is the single replacement text for the full-spread vault PRD, copied from the locked decisions?
- Brief path: `docs/research/se-fullspread-prd-rewrite-20261103/brief.md`

## Authorization

- Source: explicit council directive
- Authorizing task or role: the owner asked the council to rewrite the PRD from all locked decisions
- What this council may do: read the admitted sources and write the assigned replacement text
- What this council may not do: edit the PRD on the initial pass, edit the blockers file, edit the pretransfer directive, run tests, install, deploy, operate wallets, or use Git
- The coordinator applies one edit to the PRD after the responses are compared. A member does not.
- Inherited permissions: accepted. They are not extra authority and not a sandbox.

## Requested roster

| Label | Requested model | Owned response |
| --- | --- | --- |
| astra | `chatgpt-subscription/gpt-6-astra:high` | `members/astra/response.md` |
| grok | `xai/grok-4.7:xhigh` | `members/grok/response.md` |
| minimax | `minimax/MiniMax-M3` | `members/minimax/response.md` |
| kimi | `kimi-coding/k3.1-pro:high`, global route | `members/kimi/response.md` |

## Admission

- Current PRD: `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_PRD.md`
- Lock authority: `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/IMPLEMENTATION_PLAN_BLOCKERS.md`, including the 2026-11-03 overrides. A later override wins over an earlier sentence in that file.
- Also binding: `docs/vaults/PRETRANSFER_DIRECTIVE.md`
- Preview consumers: `docs/research/se-fullspread-preview-consumers-20261103/REPORT.md` and `INDEX.md`
- Accepted return ABI: `docs/research/se-interface-refund-bundle-20261030-01a18660/REPORT.md`
- Do not read peer responses. Do not send private excerpts to a search service.

## Scope copied to every member

- Write only your owned `response.md`. Do not edit the PRD.
- Do not launch sub-agents. No Forge, tests, installs, or Git.
- No Review findings section. No `FILL`.
- Keep Identity, Question and targets, Evidence, Assumptions, Coverage, Conclusions, and Limits. Delete Review findings. No `FILL`.
- Conclusions is the complete replacement PRD, not a list of edits and not a commentary. The other sections cite what you read. They are not a second PRD.
- Keep the current section order and requirement IDs where the requirement remains. Replace a contradicted sentence. Do not leave the old sentence beside the lock.
- Do not invent economics, events, errors, or selectors.
- A filled reading that was stated and not rejected is part of the lock: the caller's share is `shares burned / total shares` before the burn, rounded down. `Donation()` has no fields. A both-token exit pays that claim in both tokens and does not swap. An exit preview uses the same apportioning as execution and is the share valuation. A mint preview does not credit existing fees to the new depositor.
- Name the six fail-closed preview consumers and the three one-word ABI bindings with path and line, from the consumer report. State that every other one-word reader of `previewExchangeIn` in `INDEX.md` migrates to `(uint256 amountOut, uint256 amountRefunded)`. Do not paste the 1626-line index into the PRD.
- `previewExchangeIn` and `exchangeIn` keep their selectors and return the tuple. `exchangeOut` and `previewExchangeOut` do not gain a refund return.

## Attempt caps

A member assignment caps at three. Disagreement is not a retry reason.

## Settlement

Wait for Native completion of every requested task. Quiet work is pending, not failure and not approval.
