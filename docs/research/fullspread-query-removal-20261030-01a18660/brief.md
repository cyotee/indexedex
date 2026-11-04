# Full-spread query and getRate removal — council brief

## Run

- Run ID: fullspread-query-removal-20261030-01a18660
- Profile: research
- Council kind: full
- Question: The owner is considering removing the PairToken query selectors and `getRate()` from the published full-spread Standard Exchange vault. They do not yet know how a given vault should be rated at creation. What problems does that removal cause? What should stay?
- Brief path: docs/research/fullspread-query-removal-20261030-01a18660/brief.md

## Authorization

- Source: explicit council directive
- Authorizing task: owner question in the invoking session, 2026-10-30
- What this council may do: read the admitted files and write the owned response
- What this council may not do: edit the published PRD, implement, run Forge, install, deploy, use Git, or launch another council

Owner question, verbatim:

> Then I think we need to drop the PairToken queries and the getRate() function. We don't know how we would want to rate any given vault when it is created. What does the council think of removing the PairToken functions? Would there be any problems with removing them?

Read "PairToken queries" as the eleven family query selectors plus `getRate()`: `poolManager`, `poolKey`, `wrappedNative`, `rateAsset`, `tickLower`, `tickUpper`, `positionLiquidity`, `localReserves`, `basket`, `maxZapBps`, `maxZapTickMove`, and `getRate`. Do not expand the proposed removal to `exchangeIn`, `previewExchangeIn`, paired methods, SY `exchangeRate`, or the five shared facets unless a cited caller makes one of those inseparable from the query list. Flag that boundary if you disagree.

## Coordinator

- Requested mode: invoking-agent
- The coordinator is not a vote

## Requested roster

| Label | Model | Owned response |
| --- | --- | --- |
| astra | `chatgpt-subscription/gpt-6-astra:high` | members/astra/response.md |
| grok | `xai/grok-4.7:xhigh` | members/grok/response.md |
| minimax | `minimax/MiniMax-M3` | members/minimax/response.md |
| kimi | `kimi-coding/k3.1-pro:high` | members/kimi/response.md |

## Admission

- Required targets: the published PRD and the current hook call pattern
- Admitted read scope: the files named below. No peer originals.
- Depth: direct members from root session `01a18660-756f-7c57-b112-de7a5348283c`, depth 1. Prior council-member launches from this root settled at depth 1.
- Isolation: shared workspace, `isolated: false`

## Delivery

- Run root: docs/research/fullspread-query-removal-20261030-01a18660
- This pass writes opinions only. Do not edit `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_PRD.md`.

## Scope copied to every member

- Independent first pass. Do not read peers.
- Write only the owned response. If the patch tool cannot write it, return the complete Markdown inline and stop.
- No sub-agents, no Forge, no project edits.
- A prior council installed `getRate` because a buffered hook leg needs `IRateProvider` and the then-current instruction preserved a one-share exit rate. The owner is now saying the rate policy is not known. That new statement is the question. Do not treat the published PRD as a veto of the question, and do not treat it as already answering it.

## Admitted sources

- `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_PRD.md`
- `contracts/pairtoken-baseline/se-version/PAIR_TOKEN_STANDARD_EXCHANGE_STAGE_ONE_PRD.md`, sections on queries, native faces, and the route table
- One current buffer-hook family that calls `previewExchangeIn` / `exchangeIn` and binds `IRateProvider`. `contracts/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualStandardExchangeBufferConstantProductHookCommon.sol` is a sufficient example. Check the package's provider requirement when `token != standardExchange`.
- Do not send private source to a public search.

## Response shape

1. Identity and assigned route, not a runtime attestation
2. Direct answer: remove, keep, or split
3. Problems caused by removing the eleven queries, each with a caller or interface that needs it, or an explicit "no external caller found"
4. Problems caused by removing `getRate`, including hook integration and the fact that the rate policy is undecided
5. What must stay if those are removed
6. The smallest PRD change, if any, that records the owner's undecided rate without inventing a formula
7. Limits

Stop after the original.
