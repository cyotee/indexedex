# Council brief

## Run

- Run ID: se-fullspread-prd-quality-20261103
- Profile: review
- Council kind: full
- Question: Does the rewritten full-spread PRD say each locked requirement clearly enough that two implementors would copy it the same way?
- Brief path: `docs/reviews/se-fullspread-prd-quality-20261103/brief.md`

## Authorization

- Source: explicit council directive
- The owner asked the council to review the PRD for quality and clarity.
- What this council may do: read the target and the lock file, and write the assigned review.
- What this council may not do: edit the PRD, edit the draft, edit the blockers file, run tests, install, deploy, operate wallets, or use Git.
- A finding is advice. It does not authorize an edit.
- Inherited permissions: accepted. They are not extra authority and not a sandbox.

## Requested roster

| Label | Requested model | Owned response |
| --- | --- | --- |
| astra | `chatgpt-subscription/gpt-6-astra:high` | `members/astra/response.md` |
| grok | `xai/grok-4.7:xhigh` | `members/grok/response.md` |
| minimax | `minimax/MiniMax-M3` | `members/minimax/response.md` |
| kimi | `kimi-coding/k3.1-pro:high`, global route | `members/kimi/response.md` |

## Targets

- Required target: `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_PRD.md`
- Clarity standard, not a second target: `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/IMPLEMENTATION_PLAN_BLOCKERS.md`, including the 2026-11-03 overrides. A later override wins.
- Also binding for pretransfer sentences: `docs/vaults/PRETRANSFER_DIRECTIVE.md`
- Do not read peer responses. Do not send private excerpts to a search service.

## Scope copied to every member

- Write only your owned `response.md`.
- Do not launch sub-agents. No Forge, tests, installs, or Git.
- Keep Review findings. No `FILL`.
- A defect is a sentence two implementors would copy differently, a contradicted sentence left beside a lock, or a requirement too unclear to test. Prose style alone is not a defect.
- Do not invent economics, events, errors, or selectors in a fix direction. A fix direction is advice, not an edit.
- If you find no defect, say so and name the coverage. Empty approval is not a result.
- Read the whole PRD. Do not review a different file.

## Attempt caps

A member assignment caps at three. Disagreement is not a retry reason.

## Settlement

Wait for Native completion of every requested task. Quiet work is pending, not failure and not approval.
