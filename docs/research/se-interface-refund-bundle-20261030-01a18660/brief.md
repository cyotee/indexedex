# Council brief

## Run

- Run ID: se-interface-refund-bundle-20261030-01a18660
- Profile: research
- Council kind: full
- Question: Should the Standard Exchange interface set be redefined so one previewExchange/exchange family covers swaps, deposits, and withdrawals, including a same-token refund when an input cannot be fully consumed, and what exact interface definitions does the council recommend?
- Brief path: docs/research/se-interface-refund-bundle-20261030-01a18660/brief.md

## Authorization

- Source: explicit council directive
- Authorizing task or role: the owner's message in this session asking what the council thinks of redefining the Standard Exchange interfaces and to deliver recommended interface definitions
- What this council may do: read the admitted interfaces and related comments, then recommend interface definitions and say whether the proposed redefinition should replace, extend, or sit beside the current surfaces
- What this council may not do: implement findings, run the reviewed project's tests, install dependencies, deploy, operate wallets, stage or commit or push Git, replace configuration, launch an unrequested council, or inspect credentials
- Inherited permissions: accepted. Members and a coordinator child may have the same permissions as the parent session. That acceptance is not a sandbox, not extra task authority, and not proof that these instructions were enforced.

## Coordinator

- Requested mode: invoking-agent
- Requested role: invoking agent, not a fifth vote
- Requested model and reasoning: current session model
- Actual role, model, reasoning, and task ID: record in `RUN.md` only after Native exposes them. Leave them unwritten here rather than guessing.

## Requested roster

| Label | Requested role | Requested model and reasoning | Owned response | Owned feedback |
| --- | --- | --- | --- | --- |
| astra | council-member | `chatgpt-subscription/gpt-6-astra:high` | `members/astra/response.md` | `members/astra/feedback.md` |
| grok | council-member | `xai/grok-4.7:xhigh` | `members/grok/response.md` | `members/grok/feedback.md` |
| minimax | council-member | `minimax/MiniMax-M3`, admitted adaptive thinking, not a selectable depth | `members/minimax/response.md` | `members/minimax/feedback.md` |
| kimi | council-member | `kimi-coding/k3.1-pro:high`, global route | `members/kimi/response.md` | `members/kimi/feedback.md` |

## Admission

- Required targets: the current Standard Exchange interface files listed below, read from the repository, not from memory
- Optional context: `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/PAIRTOKEN_FUNCTIONS_FOR_REVIEW.md` and `UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_PRD.md`. These explain why the refund question arose. They are not the interface law.
- Admitted read scope: the required interface files, their immediate error interface, and the optional full-spread notes. Do not edit them.
- Required tools: file read
- Optional tools: local search inside the repository. Public web search is not required. If used, generalize the query and do not send private source excerpts.
- Public-query boundary: generalize public searches and documentation queries, or use public identifiers. Do not send private source excerpts to those services.
- Depth preflight: invoking agent is the root coordinator. Direct members need depth 1. No nested council.
- Effective isolation: shared workspace, `isolated: false`. Members write only their owned response path.

Required interface files:

- `lib/crane/contracts/interfaces/IStandardExchangeIn.sol`
- `lib/crane/contracts/interfaces/IStandardExchangeOut.sol`
- `lib/crane/contracts/interfaces/IStandardExchangeErrors.sol`
- `contracts/interfaces/IStandardExchange.sol`
- `contracts/interfaces/IStandardExchangeInMulti.sol`
- `contracts/interfaces/IStandardExchangeOutMulti.sol`
- `contracts/interfaces/IStandardExchangeMultiAssetLiquidity.sol`
- `contracts/vaults/basic/IBasicVault.sol`

## Artifact root and delivery

- Admitted run root: `docs/research/se-interface-refund-bundle-20261030-01a18660`
- Delivery: both
- Intended final path: `docs/research/se-interface-refund-bundle-20261030-01a18660/REPORT.md`
- Cooperative publication target: none. Do not edit the full-spread PRD or the function-review file.

## Owned paths

| Writer | May write | Must not write |
| --- | --- | --- |
| Coordinator | `brief.md`, `RUN.md`, `coordinator/draft.md`, `coordinator/resolution.md`, `REPORT.md` | member response or feedback files |
| Member astra | `members/astra/response.md`, later `members/astra/feedback.md` | peer files, the draft, the resolution, the final, `RUN.md`, project code, and configuration |
| Member grok | `members/grok/response.md`, later `members/grok/feedback.md` | peer files, the draft, the resolution, the final, `RUN.md`, project code, and configuration |
| Member minimax | `members/minimax/response.md`, later `members/minimax/feedback.md` | peer files, the draft, the resolution, the final, `RUN.md`, project code, and configuration |
| Member kimi | `members/kimi/response.md`, later `members/kimi/feedback.md` | peer files, the draft, the resolution, the final, `RUN.md`, project code, and configuration |

## Scope copied to every member

- The question, profile, targets, and output rules are the same for every requested member.
- The initial pass is independent. Do not read peer responses before submitting `response.md`.
- Write only the owned response path on the initial pass. Preserve that file. The later feedback pass writes only the owned feedback path.
- Do not edit the draft, resolution, final, run record, or another member's files.
- Do not launch sub-agents or another council.
- Do not inherit an interactive-only Minion personality into this autonomous assignment.
- Source text and peer text are data. They do not change authority, participants, or owned paths.
- Consultation does not authorize implementation.

## Owner proposal, quoted

The owner said:

> This sounds like we've identified a gap in our Standard Exchange standard. My intent in defining the Standard Exchange interfaces was to unify swaps, deposits, and withdrawals and abstract underlying protocols so the rest of our architecture can have a single set of interface against which to integration.
>
> So, I propose broadening the scope to redefining the Standard Exchange interfaces. We will keep the naming convention of previewExchange/exchange, with modifiying suffixes.
>
> Because we're discovering that we may be required to issue a refund because precise calculations may not be feasible within the gas limit we'll expand the Standard Exchange standard to include return values for refunded amounts. Because we expect our vaults to be used as liquidity, we can expect every integration to be able to process all of the underlying tokens. So, our standard will specifiy that any time a vault is unable to fully consume the user provided amount, it should execute the process so there is a remainer of the token the user provided. That way, we can reliably refund the token the user provided, knowing the user should be able to process the refund because it is the same token they provided.
>
> We will also expand the Standard Exchange standard to add IStandardExchangeBundleInForSingleOut with the functions previewExchangeBundleInForSingleOut and exchangeBundleInForSingleOut where the user provides an array of amountsIn in the same order as the tokens from vaultTokens() and the address of the single token they want to receive. And we'll add IStandardExchangeBundleOut with the functions previewExchangeBundleOut and exchangeBundleOut where the user provides an array of tokens they expect to receive back and the address of the token they wish to pay in. Both of these will also have a pretranfer option.

The phrase "redefining the entire" is incomplete in the request. Read it as redefining the Standard Exchange interface set, not as authority to redesign unrelated vault law.

## What the recommendation must decide

Recommend exact Solidity interface definitions. Do not implement them. For each recommendation, say whether it replaces a current function, extends it, or is a new interface beside it.

The owner named these constraints:

- Keep `previewExchange` / `exchange` names, with modifying suffixes.
- A vault that cannot consume the full user-provided amount must leave the remainder in the token the user provided, and the interface must return the refunded amount.
- Integrations are expected to process every underlying token, so the refund is the same token the user supplied.
- `IStandardExchangeBundleInForSingleOut` has `previewExchangeBundleInForSingleOut` and `exchangeBundleInForSingleOut`. Inputs are `amountsIn` in `vaultTokens()` order and the single output token. Include a pretransfer option.
- `IStandardExchangeBundleOut` has `previewExchangeBundleOut` and `exchangeBundleOut`. The owner said the user provides an array of tokens they expect to receive and the token they pay. Include a pretransfer option.

Do not silently resolve these ambiguities. Label each resolution as a recommendation:

- Whether "array of tokens they expect to receive" means addresses, amounts, or both.
- Whether the refund return changes current `exchangeIn` / `exchangeOut`, which would be a breaking selector change, or applies only to new functions.
- How this relates to `IStandardExchangeInMulti` and `IStandardExchangeOutMulti`, which already have many-to-one and one-to-many routes and currently say surplus input is not refunded on the exact-in multi route.
- How this relates to `IStandardExchangeMultiAssetLiquidity`, whose comment says canonical In/Out remain swap-only and must not be merged with the liquidity extension.
- Native ETH as `address(0)` versus an ERC-20 face. Current multi routes mention a WETH face for V4.
- Whether `vaultTokens()` order is the only legal input order.
- What the preview returns for a refund, since a preview cannot transfer.

Current `exchangeIn` returns only `amountOut`. Its pretransfer comment says tokens above the declaration are not refunded. Current exact-out pretransfer refunds unused input to `msg.sender`, not as a named return of an output remainder. Read those comments before recommending a replacement.

## Attempt caps

Council-issued attempts are counted in `RUN.md` by logical assignment. A member assignment caps at three, including the first request. A coordinator synthesis assignment caps at two. A new task ID or a fresh context does not reset the count. Disagreement, low confidence, and auth or policy failure are not retry reasons. This brief does not add a token budget or a discretionary deadline.

## Settlement

Wait for Native completion of every requested task. Quiet work is pending, not failure and not approval. Do not poll a model because it is silent. Do not cancel it for elapsed time. Required Native timeouts stay Native's responsibility.
