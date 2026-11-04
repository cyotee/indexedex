# Council brief

## Run

- Run ID: apex-012-prior-vaults-20261024
- Profile: research
- Council kind: full
- Question: From the vault survey already completed, what can IndexedEx take, and what can it not take, for the liquidity-manipulation claim in APEX-2026-012?
- Brief path: `docs/reviews/apex-012-prior-vaults-20261024/brief.md`

## Authorization

- Source: explicit council directive
- Authorizing task or role: user message asking whether the council has suggestions based on the previous Uniswap V3 and V4 vault research
- What this council may do: read the admitted survey and the auditor-claim report, and write the owned response
- What this council may not do: implement, run Forge, install, deploy, use wallets, use Git, launch another council, or start a new protocol search
- Inherited permissions: accepted. Same parent permissions are not extra authority.

## Coordinator

- Requested mode: invoking-agent
- Requested role: invoking agent, not an extra vote
- Requested model and reasoning: current invoking model

## Requested roster

| Label | Requested role | Requested model and reasoning | Owned response | Owned feedback |
| --- | --- | --- | --- | --- |
| astra | council-member | `chatgpt-subscription/gpt-6-astra:high` | `docs/reviews/apex-012-prior-vaults-20261024/members/astra/response.md` | `docs/reviews/apex-012-prior-vaults-20261024/members/astra/feedback.md` |
| grok | council-member | `xai/grok-4.7:xhigh` | `docs/reviews/apex-012-prior-vaults-20261024/members/grok/response.md` | `docs/reviews/apex-012-prior-vaults-20261024/members/grok/feedback.md` |
| minimax | council-member | `minimax/MiniMax-M3` | `docs/reviews/apex-012-prior-vaults-20261024/members/minimax/response.md` | `docs/reviews/apex-012-prior-vaults-20261024/members/minimax/feedback.md` |
| kimi | council-member | `kimi-coding/k3:high` | `docs/reviews/apex-012-prior-vaults-20261024/members/kimi/response.md` | `docs/reviews/apex-012-prior-vaults-20261024/members/kimi/feedback.md` |

## Admission

- Required targets:
  - `.omo/ulw-research/20261023-171500/SYNTHESIS.md`
  - `.omo/ulw-research/20261023-171500/sources-ledger.md`
  - `docs/reviews/apex-012-auditor-claim-20261024/REPORT.md`
- Optional context: the APEX-2026-012 section in `docs/security/audit/second_review/IndexedEx_DiffReview_aca16198-2ba07631.md`, only to check a sentence the claim report cites. Do not review other findings.
- Admitted read scope: those files. A member may open a URL already listed in the sources ledger if a suggestion depends on a sentence the synthesis does not quote. Do not search for new protocols.
- Required tools: read and write of the owned response
- Public-query boundary: do not send private source excerpts to a public service. Do not expand the survey.
- Depth preflight: root invokes direct members. Depth 1 is sufficient.
- Effective isolation: `isolated: false`

## Artifact root and delivery

- Admitted run root: `docs/reviews/apex-012-prior-vaults-20261024/`
- Delivery: file
- Intended final path: `docs/reviews/apex-012-prior-vaults-20261024/REPORT.md`

## Problem the suggestions must answer

The auditor's claim, as the claim report states it: a permitted change in pool liquidity changes the live liquidation quote, so a deposit at the honest quote and a redeem at the inflated quote pays the attacker from the remaining holders. Spot price is not, by itself, the claim. The report is broader only in also stating a spot-move sequence and an unsettled in-unlock path.

The old survey asked a different question: earn swap fees and publish a one-token rate that does not read same-pool spot. Its recommendation is evidence of what was found. It is not a decision already made.

## Scope copied to every member

Answer these. Name the protocol and the synthesis section or ledger id for every suggestion. If the survey does not support a suggestion, say that.

1. Which inspected designs price a withdrawal from live pool depth or live slot0, and therefore do not stop this claim?
2. Which inspected designs, if any, would stop a permitted liquidity change from changing the amount a holder is paid?
3. For each design that might help, what does IndexedEx give up: fee earning, a one-token exit, a continuously executable rate, or something else the survey already recorded?
4. What must not be taken from the survey, because it answers the old spot-rate question and does not answer this liquidity claim?

Do not invent a protocol the survey did not inspect. Do not redesign Wings. Do not treat the synthesis recommendation as already chosen.

## Attempt caps

One initial attempt per member. No retry for disagreement.

## Settlement

Wait for every requested initial task. Silence is not approval.
