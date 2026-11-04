# Council brief

## Run

- Run ID: se-fullspread-owner-decisions-20261103
- Profile: research
- Council kind: full
- Question: For each owner decision on F1 through F12, is there a problem with the decision, and did the owner misunderstand the recommendation?
- Brief path: `docs/research/se-fullspread-owner-decisions-20261103/brief.md`

## Authorization

- Source: explicit council directive
- Authorizing task or role: the owner asked the council to consider these responses and say whether any decision has a problem and whether the recommendation was misunderstood
- What this council may do: read the admitted sources, write the assigned research artifacts, and report problems and misunderstandings
- What this council may not do: implement findings, run the reviewed project's tests, install dependencies, deploy, operate wallets, stage or commit or push Git, replace configuration, launch an unrequested council, inspect credentials, edit the PRD, edit the blockers file, or edit the prior resolution draft or report
- Inherited permissions: accepted. Members and a coordinator child may have the same permissions as the parent session. That acceptance is not a sandbox, not extra task authority, and not proof that these instructions were enforced.

## Coordinator

- Requested mode: invoking-agent
- Requested role: invoking agent
- Requested model and reasoning: invoking session model
- Actual role, model, reasoning, and task ID: record in `RUN.md` only after Native exposes them. Leave them unwritten here rather than guessing.

## Requested roster

| Label | Requested role | Requested model and reasoning | Owned response | Owned feedback |
| --- | --- | --- | --- | --- |
| astra | council-member | `chatgpt-subscription/gpt-6-astra:high` | `members/astra/response.md` | `members/astra/feedback.md` |
| grok | council-member | `xai/grok-4.7:xhigh` | `members/grok/response.md` | `members/grok/feedback.md` |
| minimax | council-member | `minimax/MiniMax-M3`, admitted adaptive thinking | `members/minimax/response.md` | `members/minimax/feedback.md` |
| kimi | council-member | `kimi-coding/k3.1-pro:high`, global route | `members/kimi/response.md` | `members/kimi/feedback.md` |

## Admission

- Required targets: the owner responses copied below, and the recommendation sentences in `docs/research/se-fullspread-blockers-resolutions-20261103/REPORT.md`
- Optional context: `docs/vaults/PRETRANSFER_DIRECTIVE.md`; the blockers file `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/IMPLEMENTATION_PLAN_BLOCKERS.md`; the PRD only as a locator, not as an edit target; local Uniswap V4 `modifyLiquidity` fee-delta code; Crane Operable and ownership code
- Admitted read scope: the brief, the recommendation report, the pretransfer directive, the blockers file, and the local Crane and vault sources needed to test a decision against an already locked sentence or against protocol behavior. Do not read peer responses. Do not send private excerpts to a search service.
- Required tools: file read
- Optional tools: local search inside the admitted tree
- Public-query boundary: generalize public searches, or use public identifiers. Do not send private source excerpts to those services.
- Depth preflight: invoking agent is the root. Direct members need depth 1.
- Effective isolation: shared workspace, `isolated: false`. No automatic merge.

## Artifact root and delivery

- Admitted run root: `docs/research/se-fullspread-owner-decisions-20261103/`
- Delivery: file
- Intended final path: `docs/research/se-fullspread-owner-decisions-20261103/REPORT.md`
- Cooperative publication target: none. Do not edit the PRD, the blockers file, or the prior resolution artifacts.

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
- This response is research. Do not include a Review findings section. Do not leave `FILL`.

## How to judge

A new owner decision is not a defect merely because it differs from the recommendation. The owner may change a recommendation. Say when they changed it.

A misunderstanding is a restatement that does not match the sentence they said they accepted, or a reason that answers a mechanism the recommendation did not propose.

A problem is one of these, and no others:

- The decision contradicts a sentence the owner already locked, and does not say it is replacing that lock.
- Two implementors would still do different things.
- The decision cannot be executed against the protocol behavior you read.
- The decision leaves the failure mode or the amount unnamed, so the accepted sentence is not yet copyable.

Do not answer a product question the owner did not decide. Do not propose a replacement lock except to name the one missing fact that makes the decision copyable. Do not authorize implementation or a PRD edit.

F13, F14, and F15 were not answered. Record them as not decided. Do not treat silence as acceptance.

## Owner responses

Copied verbatim. Typos are the owner's.

### F1

We don't need to snapshot each pretransferred input. The agents are over thinking this gain and trying to protect users by breaking the existing ERC20 standards. There is no standard that reliably alerts the recipient that a ERC20 token was transfered to them. We can't invent a new standard because we need to be comaptible withj existing ERC20 tokens. Is a caller overstates a maximum and ends up being credited another pretransferred balance, that is the fault of the user that pretransferred tokens outside an atomic operation.

### F2

This conclusion is correct. We are NOT interleaving the compound action with the other operations. This means we leave fees untouched while processing any other operation besides donation and compound.

### F3

Yes, this conclusion is correct.

### F4

Ok, the seems like an acceptable definition.

### F5

Yes, that is correct.

### F6

I agree, and accept the proposed sentence. But, to be clear, we're sizing our swap so we will always end up with a remainder of provided token. This should be as easy as swapping 48% of the provided token. But we will need to either prove that mathematically, or through trial and error fuzz testing to discover the correct algorithm for determining how much to swap.

### F7

We emit the Compounded event because we're depositing fees, not because we're claiming fees. Se we would emit Compounded when we deploy booked tokens. We do want an event to log donations. We would emit both Donation() and Compounded() when process a donation that also collects accrued fees.

### F8

Yes, this conclusion is correct.

### F9

Yes, this is correct.

### F10

This is correct.

### F11

This is correct.

### F12

I have reconsidered how to handle this. We want the feeTo() to always have owner controls, even when the feeTo() value changes. We should implment a new set of Ownership modified that check if the caller is the currently configured feeTo() address, and integrate the existing Operable repo if possible to implement the global and function level Operator authorizations.

## Recommendation sentences under review

Read the full sentences in `docs/research/se-fullspread-blockers-resolutions-20261103/REPORT.md`. The short form below is a locator, not a substitute. If the short form and the report differ, the report wins.

- F1: snapshot each pretransferred unbooked balance before use. If any maximum exceeds its snapshot, process nothing, pull nothing, do not revert for the difference, and refund that snapshot. Ordinary previews do not simulate that branch.
- F2: a deposit, bundle deposit, and share-minting `exchangeIn` book any position fees their liquidity modification collects, and do not credit, refund, or deploy those fees. They do not call `compound()`. A pass-through collects none.
- F3: after `donate` or `compound`, booked total is the actual held balance. A zero-size add is skipped. A failed step reverts.
- F4: position ratio is the current pool price at the stored ticks, excluding unpaid fees and booked balances.
- F5: size the one-token swap to the greatest integer liquidity the following add can take. Remainder stays in the input token. "About half" does not survive.
- F6: a one-token exit converts all unwanted withdrawn principal into the selected token or reverts `AmountOutNotMet` without burning shares. It does not pay, book, or abandon the residual. Accepting this scopes the old no-revert sentence to the sleeve.
- F7: emit no-argument `Compounded()` only when `donate` or `compound` adds liquidity and that call collects a nonzero fee. Do not name a donation event. A later deploy of previously booked fees does not emit unless a fee-origin store is added. The proposal does not add one.
- F8: one initialization write of the seven package addresses into the instance Protocol Aware Repo.
- F9: Crane getters serve `poolManager()`, `poolKey()`, ticks, and `positionLiquidity()`. No family-only duplicate.
- F10: `donate(address token, uint256 amount, bool pretransferred)`, no return value. Share donation keeps the flag false.
- F11: borrowed `exchangeIn` may proceed. A one-token exit proceeds only if it is single-output `exchangeBundleOut`. Both-token redeem, bundle-in, donate, and compound still revert `ManagerAlreadyUnlocked`.
- F12: store `feeTo()` once, including zero. A later `feeTo()` change does not move the stored owner. No live read.

## Response shape

Use the research headings: Identity, Question and targets, Evidence, Assumptions, Coverage, Conclusions, Limits. Delete Review findings.

Under Conclusions, one subsection per F1 through F12, then one line for F13 through F15. Each F subsection states:

- Misunderstood: yes or no
- Problem: yes or no
- Changed the recommendation: yes or no
- The reason, with a path and line when the reason depends on code you read
- The one missing fact, if the decision is not yet copyable

Separate source observation from inference. Peers read before submission: no. Write `not exposed` for any runtime identity the assignment did not give you.

## Attempt caps

A member assignment caps at three, including the first request. A coordinator synthesis assignment caps at two. Disagreement, low confidence, and auth or policy failure are not retry reasons.

## Settlement

Wait for Native completion of every requested task. Quiet work is pending, not failure and not approval.
