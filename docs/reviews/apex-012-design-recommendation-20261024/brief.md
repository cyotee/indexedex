# Council brief

## Run

- Run ID: apex-012-design-recommendation-20261024
- Profile: research
- Council kind: full
- Question: Recommend one vault design that earns swap fees from a reserve exposed to trading and can be priced and exited into one target token. Deposit, redeem, and the rate must use one rule. Name what that design refuses to do.
- Brief path: `docs/reviews/apex-012-design-recommendation-20261024/brief.md`

## Authorization

- Source: explicit council directive
- Authorizing task or role: user message asking what the council recommends to meet those two goals, after reconsidering the entire vault design
- What this council may do: read the admitted local sources and write the owned response
- What this council may not do: implement, run project tests, install, deploy, operate wallets, use Git, replace configuration, launch another council, or inspect credentials
- Inherited permissions: accepted. Same parent permissions are not extra authority.

## Coordinator

- Requested mode: invoking-agent
- Requested role: invoking agent, not an extra vote
- Requested model and reasoning: current invoking model

## Requested roster

| Label | Requested role | Requested model and reasoning | Owned response | Owned feedback |
| --- | --- | --- | --- | --- |
| astra | council-member | `chatgpt-subscription/gpt-6-astra:high` | `docs/reviews/apex-012-design-recommendation-20261024/members/astra/response.md` | `docs/reviews/apex-012-design-recommendation-20261024/members/astra/feedback.md` |
| grok | council-member | `xai/grok-4.7:xhigh` | `docs/reviews/apex-012-design-recommendation-20261024/members/grok/response.md` | `docs/reviews/apex-012-design-recommendation-20261024/members/grok/feedback.md` |
| minimax | council-member | `minimax/MiniMax-M3` | `docs/reviews/apex-012-design-recommendation-20261024/members/minimax/response.md` | `docs/reviews/apex-012-design-recommendation-20261024/members/minimax/feedback.md` |
| kimi | council-member | `kimi-coding/k3:high` | `docs/reviews/apex-012-design-recommendation-20261024/members/kimi/response.md` | `docs/reviews/apex-012-design-recommendation-20261024/members/kimi/feedback.md` |

## Admission

- Required targets: none. This is a research recommendation, not a defect review.
- Required sources: the owner goals in this brief; `docs/reviews/apex-012-deposit-process-20261024/REMEDIATION_PRD.md`; `docs/security/audit/second_review/APEX-2026-012-APPORTIONED-RESERVE-PRD.md` only as the design being reconsidered, not as a binding spec
- Optional context: `contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/UniswapV4UpperLowerWingsStandardExchangeVaultMoney.sol` deposit and redeem; `.omo/ulw-research/20261023-171500/SYNTHESIS.md` if present
- Admitted read scope: those files
- Required tools: read and write of the owned response
- Optional tools: none. Do not send private source to a public search.
- Depth preflight: root invokes direct members. Depth 1 is sufficient.
- Effective isolation: `isolated: false`

## Artifact root and delivery

- Admitted run root: `docs/reviews/apex-012-design-recommendation-20261024/`
- Delivery: file
- Intended final path: `docs/reviews/apex-012-design-recommendation-20261024/REPORT.md`
- Cooperative publication target: none

## Scope copied to every member

Recommend one design. Do not return a survey as the answer. A rejected alternative may be named in one sentence.

The two goals are:

1. The reserve is exposed to trading volume and earns swap fees.
2. A holder can be priced and paid in one target token. The price is a view, one `uint256`, 18 decimals, suitable for a rate provider.

Constraints already established:

- A live same-pool liquidation quote must not be the share price. Temporary liquidity and an in-transaction price move must not mint shares or move the rate.
- Do not use one price for the rate and a different zap-out for redemption.
- A single-sided target range is not, by itself, a fee-earning reserve. It earns only while price is inside it, and then it holds the other token.
- The current Wings deposit does not sell target for the other token. The owner rejected describing the current deposit as that sale. A future design may include a conversion only if the recommendation names why the goals require it.
- `getRate` cannot execute a sale. A number that previews a sale through current depth is the rejected quote.
- The recommendation must state deposit, exit, and the rate as one rule. Say what value is absent from the rate until a real conversion settles.
- Same mechanism for a V3 pool and a V4 pool unless a protocol difference forces a split. Name that difference if you split them.

Write the recommendation as: the position, the deposit, the exit, the rate, the refused behavior, and the cost of the design. Do not implement it.

## Attempt caps

One initial attempt per member. No retry for disagreement.

## Settlement

Wait for every requested initial task. Silence is not approval.
