# Council brief

## Run

- Run ID: se-zap-relevance-20261031-01a18660
- Profile: research
- Council kind: full
- Question: Does the vault design being adopted configure `maxZapBps` and `maxZapTickMove`, are those caps relevant to that design, and is `previewZapCredit`'s per-currency split useful to a caller?
- Brief path: docs/research/se-zap-relevance-20261031-01a18660/brief.md

## Authorization

- Source: explicit council directive
- Authorizing task or role: the owner's message asking what the council thinks
- What this council may do: read the admitted files and answer the three questions
- What this council may not do: implement, edit the PRD or the function-review file, run tests, install, deploy, use wallets, stage or commit or push Git, launch another council, or inspect credentials
- Inherited permissions: accepted. That acceptance is not extra task authority.

## Coordinator

- Requested mode: invoking-agent
- Requested role: invoking agent, not a fifth vote
- Actual identity: record in RUN.md only after Native exposes it.

## Requested roster

| Label | Model | Owned response | Owned feedback |
| --- | --- | --- | --- |
| astra | `chatgpt-subscription/gpt-6-astra:high` | `members/astra/response.md` | `members/astra/feedback.md` |
| grok | `xai/grok-4.7:xhigh` | `members/grok/response.md` | `members/grok/feedback.md` |
| minimax | `minimax/MiniMax-M3`, adaptive thinking | `members/minimax/response.md` | `members/minimax/feedback.md` |
| kimi | `kimi-coding/k3.1-pro:high`, global route | `members/kimi/response.md` | `members/kimi/feedback.md` |

## Admission

Required:

- `contracts/protocols/strategy/weir/WEIR_VAULT_SOURCE_IMPORT_PRD.md`, WI-13 through WI-20 and the DepositParams and WithdrawParams rows
- `contracts/protocols/strategy/weir/WeirVaults.sol`, the deposit, withdraw, and zap functions only
- `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_PRD.md`, the `PkgArgs` list and FS-OWN-09 and FS-OWN-10 only
- `docs/research/se-zap-roi-20261031-01a18660/REPORT.md`

Optional, as the origin of the two names, not as Weir law:

- `contracts/pairtoken-baseline/se-version/PAIR_TOKEN_STANDARD_EXCHANGE_STAGE_ONE_PRD.md`, the zap-cap paragraphs only

Do not edit admitted files. Do not read peers. Do not launch sub-agents. A coordinator search found no `maxZapBps` or `maxZapTickMove` string in the Weir import PRD. Verify that yourself. Do not treat the coordinator's search as a finding.

Isolation: shared workspace, `isolated: false`. Write only the owned response path.

## Artifact root

- Run root: `docs/research/se-zap-relevance-20261031-01a18660`
- Final path: `REPORT.md` in that root
- Do not edit the PRD or the function-review file.

## Owner question, quoted

> To confirm, does the Weir Vault desing we're adopting configure Max Zap BPS and Max Zap Tick Move values? Are they actually relevant to our design? And, for "previewZapCredit", what value could callers get from knowing the per currency split? Is this data actually useful? What does the council think?

## What the recommendation must decide

Answer three questions. Do not reopen the locked drops of `previewWithdrawalMode` and `wrappedNative()`.

1. Does Weir configure `maxZapBps` and `maxZapTickMove`? Name the Weir controls that do exist for a zap, if any. Separate Weir from the full-spread PRD. The full-spread `PkgArgs` list currently includes both fields because it says `PkgArgs` is the PairToken set. That sentence is not proof that Weir has them.

2. Are those two caps relevant to the design being adopted? The adopted product is a single-position full-spread Standard Exchange vault. It still has single-token `exchangeIn`. Weir's deposit has a `zap` flag and refunds unused input. Say whether a size-bps cap and an entry tick-move cap do work in that product that Weir's own swap limits do not already do. Do not invent a number.

3. What can a caller do with `previewZapCredit`'s per-currency split that `previewExchangeIn` does not already let them do? Say whether that use survives if unused input is refunded, as Weir does, rather than booked. If the split is only useful under a booked-residual policy this family has not locked, say that.

This recommendation does not authorize implementation and does not lock the PRD.
