# Council brief

## Run

- Run ID: se-fullspread-remediation-plan-20261106
- Profile: research
- Council kind: full
- Question: Write one remediation implementation and test plan from the current `docs/reviews/se-fullspread-plan-execution-20261104/REMEDIATION_PRD.md`. The plan must be specific enough that an implementer can close the adopted gaps without making a product decision.
- Brief path: docs/research/se-fullspread-remediation-plan-20261106/brief.md

## Authorization

- Source: explicit council directive
- Authorizing task or role: the user asked this session to have the council write an implementation plan for the remediation PRD
- What this council may do: read the admitted sources and write the assigned research artifacts, including one synthesized remediation implementation and test plan
- What this council may not do: implement findings, run the reviewed project's tests, install dependencies, deploy, operate wallets, stage or commit or push Git, replace configuration, launch an unrequested council, or inspect credentials
- Inherited permissions: accepted. That acceptance is not a sandbox and not extra task authority.

## Coordinator

- Requested mode: invoking-agent
- Requested role: invoking session, not a fifth vote
- Requested model and reasoning: the invoking session's current model

## Requested roster

| Label | Requested role | Requested model and reasoning | Owned response | Owned feedback |
| --- | --- | --- | --- | --- |
| astra | council-member | `chatgpt-subscription/gpt-6-astra:high` | members/astra/response.md | members/astra/feedback.md |
| grok | council-member | `xai/grok-4.7:xhigh` | members/grok/response.md | members/grok/feedback.md |
| minimax | council-member | `minimax/MiniMax-M3`, admitted adaptive thinking, not a selectable depth | members/minimax/response.md | members/minimax/feedback.md |
| kimi | council-member | `kimi-coding/k3.1-pro:high`, global route | members/kimi/response.md | members/kimi/feedback.md |

## Admission

- Required source: `docs/reviews/se-fullspread-plan-execution-20261104/REMEDIATION_PRD.md`. Read the whole current file, including the 2026-11-06 owner lock and the boundary dust sentence. Do not review an older copy.
- Specification fingerprint, coordinator-supplied, not to be recomputed: `4f1f3204088b39e038a17154d79594be262921a231c6a01eeb33a7ee0373e8f3`
- Base this plan amends, required: the family PRD and the family plan named below. Read them where a remediation sentence depends on them. Do not rewrite them.
- Family PRD: `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_PRD.md`
- Family plan: `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_IMPLEMENTATION_AND_TEST_PLAN.md`
- Not a requirements source: historical question files, the readiness reports, and any deleted remediation plan. A removed sizing method is not a requirement.
- Admitted read scope: the required source, the two base files, and this brief. A declared code file may be read only to name the current function a plan sentence must point at. Label that read as context. Do not review the rest of the repository.
- Public-query boundary: do not send repository text to a public search or fetch service.
- Depth: direct members. Do not launch sub-agents.
- Isolation: `isolated: false`. Members write only the owned response path on this pass.

## Artifact root and delivery

- Admitted run root: `docs/research/se-fullspread-remediation-plan-20261106/`
- Delivery: file
- Intended final path: `docs/research/se-fullspread-remediation-plan-20261106/IMPLEMENTATION_AND_TEST_PLAN.md`
- Cooperative publication target: that same path. Members do not write it. The coordinator publishes it after advisory review.
- This plan does not replace the family plan. It amends the family plan for the remediation PRD's adopted gaps. It does not authorize implementation.

## Owned paths

| Writer | May write | Must not write |
| --- | --- | --- |
| Coordinator | `brief.md`, `RUN.md`, `coordinator/draft.md`, `coordinator/resolution.md`, and `IMPLEMENTATION_AND_TEST_PLAN.md` | member files, the remediation PRD, the family plan, the family PRD, project code |
| Each member | `members/<label>/response.md` on this pass, and later only `members/<label>/feedback.md` | peer files, the draft, the plan, the PRDs, project code |

## Requirement law the plan must copy

Do not reopen these. Do not offer a menu. Do not restore a removed method.

- Inside the position, a one-sided share mint and a one-token `donate` or `compound` swap 49% of the processed input, then deposit. Do not iterate. Do not size an exact output. Do not solve a closed-form root. Do not walk ticks to find a better split.
- If the price is not strictly inside the position, including exactly at either boundary, do not swap. A share mint refunds what the add does not take. A `donate` or `compound` books that dust and does not refund it. The other token is not swapped. A share mint refunds it. A `donate` or `compound` books it.
- A collapsed candidate returns the input and keeps no swap. A share mint refunds that input and mints nothing. A `donate` or `compound` books that input and does not refund it. A first deposit that does not add more than 1,000 liquidity still reverts `MinLiquidityNotMet`. That is not a refund.
- The one-token exit receipt is the swap proceeds, the withdrawn requested-token principal, the requested-token fee portion, and the requested booked claim. An incomplete exit raises `AmountOutNotMet` and does not burn.
- A missing or code-empty infrastructure address reverts `InvalidComponent` before it is stored. The six addresses are `positionDescriptor`, `positionManager`, `quoter`, `stateView`, `reservesLens`, and `universalRouter`.
- The weighted two-leg row keeps its `setUp` override. Do not delete it.
- Do not add an `exchangeRate` test. `getRate` stays uninstalled.
- Gas ceilings stay 11,900,000 cold standalone, 12,000,000 composed, and 5,000,000 preview. Measure every named standalone route and every section 12 row. Do not warm a measurement with a preview.
- This pass does not walk or certify the preview-consumer index. The family plan still requires that migration. This plan does not close it.
- `seBooked()` must not report a balance. Empty capacity overrides stay unless the parent does not require them. Do not add a capacity gate.
- The unresolved list is not a set of new requirements. Do not implement those items in this plan.

## Plan shape

Write one complete remediation plan in the Conclusions section. Use these headings, in this order:

1. Authority. The plan does not authorize implementation. It does not replace the family plan.
2. Sources and precedence. The 2026-11-06 remediation lock wins for the gaps it names.
3. Already closed product choices. Copy the requirement law above. Do not restate a removed method.
4. Production changes, naming the current function each change touches.
5. One-sided size, including the boundary and the collapsed candidate.
6. One-token exit receipt and the incomplete-exit error.
7. Package and fixture assertions.
8. Gas measurements, naming each route and file.
9. Out of scope. Name the preview-index walk and the unresolved list.
10. Tests. Name the assertion and the file. Do not claim a test already passes.
11. Traceability from each adopted remediation finding to a plan section.
12. Stop conditions. Stop when the named rows are true, or when a named blocker is reported.

Do not leave a product question open. Do not implement, test, deploy, or edit the PRD.

## Attempt caps

A member assignment caps at three, including the first request. A coordinator synthesis assignment caps at two. Disagreement is not a retry reason. This brief adds no token budget and no discretionary deadline.

## Settlement

Wait for Native completion of every requested task. Quiet work is pending, not failure and not approval.
