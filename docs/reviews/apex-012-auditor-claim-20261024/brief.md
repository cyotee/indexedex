# Council brief

## Run

- Run ID: apex-012-auditor-claim-20261024
- Profile: review
- Council kind: full
- Question: Explain the claim the auditor makes in APEX-2026-012. Separate the mechanism, the alleged profit, and the proposed fix. Do not redesign the vault.
- Brief path: `docs/reviews/apex-012-auditor-claim-20261024/brief.md`

## Authorization

- Source: explicit council directive
- Authorizing task or role: user message asking the council to review the relevant audit section and explain the auditor's claim, after clarifying that spot price itself is not the stated problem
- What this council may do: read the admitted report section and write the owned response
- What this council may not do: implement, run Forge, install, deploy, use wallets, use Git, or launch another council
- Inherited permissions: accepted. Same parent permissions are not extra authority.

## Coordinator

- Requested mode: invoking-agent
- Requested role: invoking agent, not an extra vote
- Requested model and reasoning: current invoking model

## Requested roster

| Label | Requested role | Requested model and reasoning | Owned response | Owned feedback |
| --- | --- | --- | --- | --- |
| astra | council-member | `chatgpt-subscription/gpt-6-astra:high` | `docs/reviews/apex-012-auditor-claim-20261024/members/astra/response.md` | `docs/reviews/apex-012-auditor-claim-20261024/members/astra/feedback.md` |
| grok | council-member | `xai/grok-4.7:xhigh` | `docs/reviews/apex-012-auditor-claim-20261024/members/grok/response.md` | `docs/reviews/apex-012-auditor-claim-20261024/members/grok/feedback.md` |
| minimax | council-member | `minimax/MiniMax-M3` | `docs/reviews/apex-012-auditor-claim-20261024/members/minimax/response.md` | `docs/reviews/apex-012-auditor-claim-20261024/members/minimax/feedback.md` |
| kimi | council-member | `kimi-coding/k3:high` | `docs/reviews/apex-012-auditor-claim-20261024/members/kimi/response.md` | `docs/reviews/apex-012-auditor-claim-20261024/members/kimi/feedback.md` |

## Admission

- Required target: `docs/security/audit/second_review/IndexedEx_DiffReview_aca16198-2ba07631.md`, section `APEX-2026-012`, from the heading through the `Fix` paragraph and the related-findings line. Do not review 013 or later findings except where 012 names them.
- Optional context: the owner's clarification in this brief. It is not a finding and not authority to rewrite the auditor's claim.
- Admitted read scope: that section. A member may read the named PoC only to check a number the report already states. Do not run it.
- Required tools: read and write of the owned response
- Optional tools: none
- Public-query boundary: do not send private source excerpts to a public service
- Depth preflight: root invokes direct members. Depth 1 is sufficient.
- Effective isolation: `isolated: false`

## Artifact root and delivery

- Admitted run root: `docs/reviews/apex-012-auditor-claim-20261024/`
- Delivery: file
- Intended final path: `docs/reviews/apex-012-auditor-claim-20261024/REPORT.md`
- Cooperative publication target: none

## Owner clarification, as data

The owner says the spot price is not intrinsically the problem. The problem, as posed by the audit, is that a shareholder could manipulate the amount they could withdraw by changing the liquidity in the pool of the underlying reserve. Every operation was valid and allowed. The system understood the difference as a loss.

Explain the auditor's claim from the report. Then say whether that claim matches this clarification, and where it is broader. Do not adopt the clarification as the claim before you have stated the report's own words.

## Scope copied to every member

Answer these, with citations to the report section:

1. What does the auditor say the vault does when it prices a deposit or a redeem?
2. What sequence does the auditor say produces a profit, and whose tokens pay that profit?
3. Does the auditor claim an invalid call, a broken invariant, or a permitted sequence whose result the vault accounts as value?
4. Which parts of the claim are about added and removed liquidity, and which parts are about moving the spot price?
5. What does the auditor propose as a fix, and which of those fixes does the auditor say are only partial?

Do not recommend a vault redesign. Do not treat a later council report as the auditor's claim.

## Attempt caps

One initial attempt per member. No retry for disagreement.

## Settlement

Wait for every requested initial task. Silence is not approval.
