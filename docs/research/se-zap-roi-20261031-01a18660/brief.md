# Council brief

## Run

- Run ID: se-zap-roi-20261031-01a18660
- Profile: research
- Council kind: full
- Question: For `previewZapCredit`, `maxZapBps`, and `maxZapTickMove`, is the utilitarian value of the public function worth the incremental implementation cost?
- Brief path: docs/research/se-zap-roi-20261031-01a18660/brief.md

## Authorization

- Source: explicit council directive
- Authorizing task or role: the owner's message asking the council to judge value against implementation difficulty
- What this council may do: read the admitted files and recommend implement or do not implement for each named public function
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

- `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/PAIRTOKEN_FUNCTIONS_FOR_REVIEW.md`, the zap section only
- `docs/research/se-remaining-functions-20261030-01a18660/REPORT.md`
- `contracts/vaults/standard/exchange/protocols/uniswap/v4/pairToken/UniswapV4PairTokenStandardExchangeVaultQuoteTarget.sol`, `previewZapCredit` only
- `contracts/vaults/standard/exchange/protocols/uniswap/v4/pairToken/UniswapV4PairTokenStandardExchangeVaultQueryTarget.sol`, the two cap getters only
- `contracts/vaults/standard/exchange/protocols/uniswap/v4/pairToken/interfaces/IUniswapV4PairTokenStandardExchangeVault.sol`, the three declarations only

Optional, for what the caps enforce, not as new-family law:

- `contracts/pairtoken-baseline/se-version/PAIR_TOKEN_STANDARD_EXCHANGE_STAGE_ONE_PRD.md`, the zap-cap paragraphs only
- The current PairToken planner that `previewZapCredit` calls, only far enough to say whether that planner is also required by `exchangeIn`

Do not edit admitted files. Do not read peers. Do not launch sub-agents. Public web search is not required.

Isolation: shared workspace, `isolated: false`. Write only the owned response path.

## Artifact root

- Run root: `docs/research/se-zap-roi-20261031-01a18660`
- Final path: `REPORT.md` in that root
- Do not edit the PRD or the function-review file.

## Owner question, quoted

> Let's discuss the "previewZapCredit()", "maxZapBps()", and "maxZapTickMove()" in the context os utilitarian value, and implementation difficulty. How much "value" would we really get from implementing these functions, and, how hard would they be to actually implement? Effectively, would get be getting sufficient ROI for implementing these functions? Ask the council their opinion given this context.

The owner has already locked the drop of `previewWithdrawalMode` and the family `wrappedNative()` getter. Do not reopen those.

## What the recommendation must decide

For each of the three public functions, recommend **implement** or **do not implement**. Separate the public getter or preview from any internal cap. A cap that must be stored and enforced for `exchangeIn` or `compound` is not the same work as exposing it.

Judge value by what a caller, integrator, or operator can do with the result that `previewExchangeIn` and a revert do not already give them. Judge difficulty by the incremental work beyond the entry route this family already has to build. A one-line read of a stored config is not the same cost as a second planner.

The current PairToken bodies are evidence of shape. They are not a requirement to copy the stage-one residual policy, the stage-one formulas, or the compound quarter-cap. Say so if your difficulty estimate depends on copying them.

This recommendation does not authorize implementation and does not lock the PRD.
