# Council brief

## Run

- Run ID: se-weir-adaptation-fidelity-20261031-01a18660
- Profile: research
- Council kind: full
- Question: Does the full-spread PRD adapt WeirVaults to the tokenized Standard Exchange standard, or does it mix in PairToken design without authorization?
- Brief path: docs/research/se-weir-adaptation-fidelity-20261031-01a18660/brief.md

## Authorization

- Source: explicit council directive
- Authorizing task or role: the owner's message rejecting PairToken as the basis and asking for a full review
- What this council may do: read the admitted files and classify every material requirement
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

Required, read completely:

- `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_PRD.md`
- `contracts/protocols/strategy/weir/WeirVaults.sol`
- `contracts/protocols/strategy/weir/WEIR_VAULT_SOURCE_IMPORT_PRD.md`, the behavior requirements, not the import-path tables
- `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/PAIRTOKEN_FUNCTIONS_FOR_REVIEW.md`, the locked basis note and the locked function decisions

Optional, only to identify a PairToken source. Do not treat it as authority for this vault:

- `contracts/pairtoken-baseline/se-version/PAIR_TOKEN_STANDARD_EXCHANGE_STAGE_ONE_PRD.md`

Do not edit admitted files. Do not read peers. Do not launch sub-agents. Public web search is not required.

Isolation: shared workspace, `isolated: false`. Write only the owned response path.

## Artifact root

- Run root: `docs/research/se-weir-adaptation-fidelity-20261031-01a18660`
- Final path: `REPORT.md` in that root
- Do not edit the PRD.

## Owner question, quoted

> Why did ur PRD copy the PairToken package inputs? We're not basing this vault on PairToken, we're adopting the Weir Vault. We shouldn't be mixing design without an explicit discussion.
>
> We need the council to review the entire PRD and the Weir Vaults code to ensure the PRD reflects our intent of adapting the Weir Vaults design to our tokenized vault standard. If the council feels we should include aspects of the PairToken design in our vault, they need to explain why, making an explcit case for why I should authorize this design change.

## Why the PRD copied those inputs

The current PRD says, in its own Goal section, that this family is a sibling of PairToken stage one and that it inherits that economics by ID. It also says it is not WeirVaults and not a Weir source copy. Those sentences are why `PkgArgs` was copied. They are not authority. The owner has rejected that basis. Do not defend them.

## What the recommendation must decide

The authorized design is WeirVaults adapted to one tokenized Standard Exchange vault: one share token, one pool, one position, the accepted exchange routes, and the owner locks already written. It is not "add ERC-20 to the Weir manager," and it is not a PairToken sibling.

Read the whole PRD against `WeirVaults.sol`. Classify every material requirement whose behavior is not required by Weir and is not required by the tokenized exchange surface or an owner lock.

For each such item, use one of three dispositions:

- **Remove.** It is PairToken design with no case.
- **Authorization case.** You recommend keeping it. State the Weir behavior it replaces or changes, the caller or vault harm if it is absent, and why the owner should allow the mix. A case that only says "PairToken had it" fails.
- **Already authorized.** Name the owner lock or the tokenized-standard surface. Do not relitigate a lock unless it contradicts the Weir-adaptation basis. If it does, name the contradiction and leave it for the owner. Do not vote the lock away.

The inventory must include, and is not limited to, `maxZapBps`, `maxZapTickMove`, `previewZapCredit`, booked no-share remainder, `IncompleteConversion`, `donate`, and `compound`. Say which of those are Weir, which are PairToken, and which are both under different rules.

Do not choose cap numbers. Do not rewrite the PRD. This review does not authorize implementation.
