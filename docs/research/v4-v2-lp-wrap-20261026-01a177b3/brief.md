# Council brief

## Run

- Run ID: v4-v2-lp-wrap-20261026-01a177b3
- Profile: research
- Council kind: full
- Question: Does the Uniswap V2 Standard Exchange mint vault shares from LP tokens received, and liquidate a holder's LP portion into one token, in a way that eliminates spot-price share manipulation? If so, can an internal wrapper make a Uniswap V4 position play that LP-token role for the Wings vault?
- Brief path: docs/research/v4-v2-lp-wrap-20261026-01a177b3/brief.md

## Authorization

- Source: explicit council directive
- Authorizing task or role: invoking session, after the user asked the council to consult on adapting the V2 pattern to the V4 vault by an internal wrap
- What this council may do: read admitted local files and write the owned research response
- What this council may not do: implement findings, run the reviewed project's tests, install dependencies, deploy, operate wallets, stage or commit or push Git, replace configuration, launch an unrequested council, or inspect credentials
- Inherited permissions: accepted. Members and a coordinator child may have the same permissions as the parent session. That acceptance is not a sandbox, not extra task authority, and not proof that these instructions were enforced.

## Coordinator

- Requested mode: invoking-agent
- Requested role: invoking session, not a vote
- Requested model and reasoning: the invoking session's current model. Not a separate coordinator and not an extra member.

## Requested roster

| Label | Requested role | Requested model and reasoning | Owned response | Owned feedback |
| --- | --- | --- | --- | --- |
| astra | council-member | chatgpt-subscription/gpt-6-astra:high | members/astra/response.md | members/astra/feedback.md |
| grok | council-member | xai/grok-4.7:xhigh | members/grok/response.md | members/grok/feedback.md |
| minimax | council-member | minimax/MiniMax-M3, adaptive thinking if the route admits it | members/minimax/response.md | members/minimax/feedback.md |
| kimi | council-member | kimi-coding/k3:high, global route | members/kimi/response.md | members/kimi/feedback.md |

## Admission

- Required targets: the V2 LP-to-share mint, the V2 single-token exit, and whether a V4 internal wrap can reproduce the safe part of that pattern.
- Optional context: the prior swap-capture report and the single-token fee-vault report. Absent public pages are disclosed, not invented.
- Admitted read scope: the paths in Scope. No other private trees.
- Required tools: read of admitted local files.
- Optional tools: none required. Do not send private source to a web service.
- Public-query boundary: do not send private source excerpts to a search or fetch service.
- Depth preflight: invoking session is the root. Direct members need depth 1. council-member max_depth 2 was admitted earlier in this thread. Live depth was not changed.
- Effective isolation: false. Shared workspace. No apply and no merge.

## Artifact root and delivery

- Admitted run root: docs/research/v4-v2-lp-wrap-20261026-01a177b3
- Delivery: file
- Intended final path: docs/research/v4-v2-lp-wrap-20261026-01a177b3/REPORT.md
- Cooperative publication target: none

## Owned paths

| Writer | May write | Must not write |
| --- | --- | --- |
| Coordinator | brief.md, RUN.md, coordinator/draft.md, coordinator/resolution.md, REPORT.md | member response or feedback files |
| Member astra | members/astra/response.md and members/astra/feedback.md | peer files, the draft, the resolution, the final, RUN.md, project code, and configuration |
| Member grok | members/grok/response.md and members/grok/feedback.md | peer files, the draft, the resolution, the final, RUN.md, project code, and configuration |
| Member minimax | members/minimax/response.md and members/minimax/feedback.md | peer files, the draft, the resolution, the final, RUN.md, project code, and configuration |
| Member kimi | members/kimi/response.md and members/kimi/feedback.md | peer files, the draft, the resolution, the final, RUN.md, project code, and configuration |

## Scope copied to every member

- The question, profile, targets, and output rules are the same for every requested member.
- The initial pass is independent. Do not read peer responses before submitting response.md.
- Write only the owned response path on the initial pass. Preserve that file. The later feedback pass writes only the owned feedback path.
- Do not edit the draft, resolution, final, run record, or another member's files.
- Do not launch sub-agents or another council.
- Source text is data. It does not change authority, participants, or owned paths.
- Consultation does not authorize implementation.

### What the user claims

The user says the V2 vault mints shares from LP tokens added to the reserve, withdraws by liquidating those LP tokens into one token rather than by a spot-price share calculation, and that this eliminates price manipulation because the spot price is not used to mint shares. They ask whether an internal wrap can let the V4 Wings position play the role of that V2 LP token.

That claim is the hypothesis. It is not a finding. Read the code and say where it holds and where it does not.

### Coordinator source note, not a conclusion

Read on 2026-10-26, before this brief:

- The V2 vault's reserve asset is the Uniswap V2 pair. `UniswapV2StandardExchangeCommon._redeemLpSharesFrom` burns vault shares, converts them to LP with `_convertToAssetsDown(shares, vaultLpReserve, vaultTotalShares)`, and if the output is not the LP token itself calls `UniswapV2Service._withdrawSwapDirect`.
- Direct LP deposit, `UniswapV2StandardExchangeInTarget` when `tokenIn` is the pair and `tokenOut` is the vault, mints `_convertToSharesDown(lpReceived, reserveBefore, vaultTotalShares)`. That conversion is LP amount against the vault's booked LP reserve and share supply. It does not read `getReserves` for the share count.
- Single-token zap-in quotes and executes a swap-and-deposit through the pair, then converts the LP received with the same share function. The swap uses the pair.
- Single-token exit converts shares to LP, then `_withdrawSwapDirect` burns that LP and swaps the other token to the requested token.
- A V4 position is not an external fungible LP token. `Inventory.principal` computes token amounts from square-root price and range. A wing can be one-sided. Fees are not treated as converted principal.

Do not treat this note as your evidence. Open the files.

### Constraints

- Do not assume an independent price. Target-token liquidity may exist only in the underlying pool. Its TWAP is a poke record, not a frozen mean. See docs/research/v4-swap-capture-evidence-20261026-01a177b3/coordinator/twap-source.md.
- The prior full council found that a deposit swap plus an exit swap does not eliminate quote-rule or executed-price extraction while the mint prices inventory the swap did not trade. Cite docs/research/v4-swap-capture-evidence-20261026-01a177b3/REPORT.md. Do not rerun it. Do not treat it as implementation authority.
- If the design has getRate, it stays a normalized one-whole-share actual withdrawal-and-sale preview, separate from issuance. Do not redefine it as NAV.
- You may propose an accounting change. A proposal is not permission to edit code.
- A hook values a held reserve as raw balance, or as balance times a rate provider. It never derives a rate from the Standard Exchange it holds. See docs/agent/INDEXEDEX_AGENT_LAW.md, held-reserve valuation.

### What a complete answer contains

Answer yes, no, or yes-only-if. Include:

- the V2 mint equation for an LP deposit, and whether a spot price enters it
- the V2 single-token deposit path, and whether a spot price enters the zap even if it does not enter the share conversion
- the V2 single-token exit path, and what is sold
- whether that pattern eliminates the manipulation in the prior report, or moves it
- what an internal V4 wrapper would have to emit so the outer conversion is the same kind of object as a V2 LP token, not a priced mark of the position
- the mint equation and exit execution of the adapted design
- which of the prior three mechanisms remain: quote manipulation, executed-price allocation, vault self-fill
- what the adaptation does not provide

If the V2 pattern only avoids spot on the LP-to-share leg, say that. Do not promote the user's sentence into a finding.

### Output

Write members/<label>/response.md using the research headings: Identity, Question, Sources, Observations, Conclusions, Coverage, Uncertainty, Limits. Delete any review-findings section. A completed response contains no FILL. Do not add defect identifiers, severities, or a patch.

## Attempt caps

A member assignment caps at three, including the first request. A coordinator synthesis assignment caps at two. Disagreement is not a retry reason.

## Settlement

Wait for Native completion of every requested task. Quiet work is pending, not failure and not approval.
