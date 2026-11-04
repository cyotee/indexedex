# Council brief

## Run

- Run ID: se-remaining-functions-20261030-01a18660
- Profile: research
- Council kind: full
- Question: For each remaining open full-spread function, should this family keep it, drop it, or map it onto an accepted standard function?
- Brief path: docs/research/se-remaining-functions-20261030-01a18660/brief.md

## Authorization

- Source: explicit council directive
- Authorizing task or role: the owner's message asking what the council recommends for the remaining functions
- What this council may do: read the admitted files and recommend keep, drop, or map for each named function
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

Required targets:

- `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/PAIRTOKEN_FUNCTIONS_FOR_REVIEW.md`
- `docs/research/se-interface-refund-bundle-20261030-01a18660/REPORT.md`, owner lock and accepted interfaces only
- `docs/research/se-paired-money-necessity-20261030-01a18660/REPORT.md`
- The current declarations of `previewZapCredit`, `previewWithdrawalMode`, `maxZapBps`, and `maxZapTickMove` in the PairToken interface or stage-one PRD

Optional: `contracts/pairtoken-baseline/se-version/PAIR_TOKEN_STANDARD_EXCHANGE_STAGE_ONE_PRD.md` for what the zap functions do. Not new-family law.

Do not edit admitted files. Public web search is not required. Do not send private source excerpts to a search service.

Isolation: shared workspace, `isolated: false`. Write only the owned response path. Do not read peers. Do not launch sub-agents.

## Artifact root

- Run root: `docs/research/se-remaining-functions-20261030-01a18660`
- Final path: `REPORT.md` in that root
- Do not edit the PRD or the function-review file.

## Owner question, quoted

> What does the council recommend for the remaining functions?

The functions still unmarked in the review file are:

- `previewZapCredit(tokenIn, amountIn)` returns the shares a single-token deposit would mint, how much of each currency funds those shares, and how much is left uncredited.
- `previewWithdrawalMode(shares, paired, tokenOut)` says whether a withdrawal would fully compound or only collect fees, and why.
- `maxZapBps()` is the configured cap on how large a single-token deposit or compound swap may be.
- `maxZapTickMove()` is the configured cap on how far that entry swap may move the pool's tick.
- `wrappedNative()` is the wrapper used when a standard nonpayable call has to represent ETH.

Already locked, and not to be reopened: no `rateAsset`, no `getRate`, no ERC-5115, no `depositPair` or `redeemPair` selectors, `exchangeIn` returns `(amountOut, amountRefunded)`, bundle routes are accepted, native on those routes uses the wrapped face, `address(0)` is rejected there.

## What the recommendation must decide

For each of the five functions, recommend keep, drop, or map onto a named accepted function. If you map it, name the function and state what the mapped function does not return.

Do not silently resolve these. Label each as a recommendation:

- `previewExchangeIn` now returns `amountRefunded`, which is unkept input of the token the user provided. `previewZapCredit` also returns a per-currency credit split. Say whether the refund return replaces that split.
- `previewWithdrawalMode` names an internal compound-or-collect choice. Say whether a caller needs that choice, or whether `previewExchangeBundleOut` is enough.
- `maxZapBps` and `maxZapTickMove` are configuration caps, not routes. Dropping the getters is not the same as dropping the caps.
- `wrappedNative` is the wrapper for a native leg. The accepted bundle routes require that face and reject `address(0)`. Say whether the getter stays on this family, moves to the Position Repo, or is unnecessary because `vaultTokens()` already exposes the face.

This recommendation does not authorize implementation and does not lock the PRD.
