# Council brief

## Run

- Run ID: se-paired-money-necessity-20261030-01a18660
- Profile: research
- Council kind: full
- Question: Does the accepted Standard Exchange redefinition fill the same need as the paired-money functions, and which of those functions should this family keep, drop, or map onto a named standard function?
- Brief path: docs/research/se-paired-money-necessity-20261030-01a18660/brief.md

## Authorization

- Source: explicit council directive
- Authorizing task or role: the owner's message asking what the council thinks of dropping the paired-money functions because the Standard Exchange redefinition fills the same need
- What this council may do: read the admitted files and recommend keep, drop, or map for each named function
- What this council may not do: implement findings, edit the PRD or the function-review file, run tests, install dependencies, deploy, operate wallets, stage or commit or push Git, replace configuration, launch an unrequested council, or inspect credentials
- Inherited permissions: accepted. That acceptance is not a sandbox and not extra task authority.

## Coordinator

- Requested mode: invoking-agent
- Requested role: invoking agent, not a fifth vote
- Requested model and reasoning: current session model
- Actual role, model, reasoning, and task ID: record in RUN.md only after Native exposes them.

## Requested roster

| Label | Requested role | Requested model and reasoning | Owned response | Owned feedback |
| --- | --- | --- | --- | --- |
| astra | council-member | `chatgpt-subscription/gpt-6-astra:high` | `members/astra/response.md` | `members/astra/feedback.md` |
| grok | council-member | `xai/grok-4.7:xhigh` | `members/grok/response.md` | `members/grok/feedback.md` |
| minimax | council-member | `minimax/MiniMax-M3`, admitted adaptive thinking | `members/minimax/response.md` | `members/minimax/feedback.md` |
| kimi | council-member | `kimi-coding/k3.1-pro:high`, global route | `members/kimi/response.md` | `members/kimi/feedback.md` |

## Admission

- Required targets: the paired-money section of `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/PAIRTOKEN_FUNCTIONS_FOR_REVIEW.md`; the owner lock and accepted interfaces in `docs/research/se-interface-refund-bundle-20261030-01a18660/REPORT.md`; the current PairToken declarations of `depositPair`, `previewDepositPair`, `redeemPair`, `previewRedeemPair`, `donate`, and `compound` in `contracts/vaults/standard/exchange/protocols/uniswap/v4/pairToken/interfaces/IUniswapV4PairTokenStandardExchangeVault.sol` or the stage-one PRD if the interface file does not declare one of them
- Optional context: `contracts/pairtoken-baseline/se-version/PAIR_TOKEN_STANDARD_EXCHANGE_STAGE_ONE_PRD.md` for what those functions do. Not interface law for the new standard.
- Admitted read scope: those files only. Do not edit them.
- Required tools: file read
- Optional tools: local search. Public web search is not required. If used, do not send private source excerpts.
- Public-query boundary: generalize public searches. Do not send private source excerpts.
- Depth preflight: invoking agent is the root coordinator. Direct members need depth 1.
- Effective isolation: shared workspace, `isolated: false`. Members write only their owned response path.

## Artifact root and delivery

- Admitted run root: `docs/research/se-paired-money-necessity-20261030-01a18660`
- Delivery: both
- Intended final path: `docs/research/se-paired-money-necessity-20261030-01a18660/REPORT.md`
- Cooperative publication target: none. Do not edit the full-spread PRD or the function-review file.

## Owned paths

| Writer | May write | Must not write |
| --- | --- | --- |
| Coordinator | `brief.md`, `RUN.md`, `coordinator/draft.md`, `coordinator/resolution.md`, `REPORT.md` | member files |
| Member astra | `members/astra/response.md`, later `members/astra/feedback.md` | peer files, draft, final, project code |
| Member grok | `members/grok/response.md`, later `members/grok/feedback.md` | peer files, draft, final, project code |
| Member minimax | `members/minimax/response.md`, later `members/minimax/feedback.md` | peer files, draft, final, project code |
| Member kimi | `members/kimi/response.md`, later `members/kimi/feedback.md` | peer files, draft, final, project code |

## Scope copied to every member

- The initial pass is independent. Do not read peer responses.
- Write only the owned response path. Do not launch sub-agents.
- Do not implement. Consultation does not authorize a PRD edit.

## Owner question, quoted

> I'm not sure we need to keep the "Pair Money" group functions. I think the redefinition of the Standard Exchange standard fills the same need as the "Paired Money" functions. What does the council think?

The paired-money group in the review file is:

- `depositPair(amount0Max, amount1Max, minShares, recipient, deadline)` takes both pool currencies, up to the two maxima, and mints shares. On a native pool, the native side is `msg.value`.
- `previewDepositPair(amount0Max, amount1Max)` returns the shares that deposit would mint and how much of each token it would take.
- `redeemPair(shares, min0, min1, recipient, deadline)` burns the caller's shares and pays both pool currencies, including raw ETH on a native pool.
- `previewRedeemPair(shares)` returns those two payouts.
- `donate(token, amount)` adds tokens to the vault's book and mints no shares.
- `compound()` collects fees and puts them back into the position. It does not change the share supply.

The accepted standard, owner-locked after the prior council, is in the report named above. `exchangeIn` and `previewExchangeIn` return `(amountOut, amountRefunded)`. `exchangeBundleInForSingleOut` takes `amountsIn` in `vaultTokens()` order and one output token, and returns the output plus per-token refunds. `exchangeBundleOut` takes one pay token and caller-named output addresses, with floors, and returns the receipts plus the unkept pay-token refund. `exchangeOut` does not gain a refund return. Native ETH is not accepted on those new functions. The caller passes the wrapped ERC-20 face.

## What the recommendation must decide

For each of the six functions, recommend keep, drop, or map onto a named accepted standard function. If you map it, name the standard function and the argument that makes the route a deposit or a withdrawal. State any behavior the standard function does not cover. Do not treat `donate` and `compound` as covered by a bundle route unless you can name the route that does that work.

Do not silently resolve these. Label each resolution as a recommendation:

- `depositPair` takes maxima and may take less. Bundle-in takes declared amounts and refunds the unkept part. Say whether that difference is enough to keep `depositPair`.
- `redeemPair` pays raw ETH on a native pool. The accepted bundle functions do not. Say whether that is a reason to keep a paired redeem, or a reason to extend the standard. Do not invent the extension.
- Whether dropping the paired functions removes a second entry path that could disagree with `exchangeBundleInForSingleOut`.
- Whether `previewDepositPair` and `previewRedeemPair` remain necessary if the paired mutators are dropped.

This recommendation does not authorize implementation and does not lock the PRD.
