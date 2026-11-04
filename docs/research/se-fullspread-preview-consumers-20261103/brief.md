# Council brief

## Run

- Run ID: se-fullspread-preview-consumers-20261103
- Profile: research
- Council kind: full
- Question: What is the complete in-repo list of consumers of the old 32-byte `previewExchangeIn` return?
- Brief path: `docs/research/se-fullspread-preview-consumers-20261103/brief.md`

## Authorization

- Source: explicit council directive
- Authorizing task or role: the owner accepted F13 and F14, and told the council to read the repo, find all consumers, and write a complete list
- What this council may do: read the repository, write the assigned research artifacts, and list every consumer it can locate
- What this council may not do: implement findings, run the reviewed project's tests, install dependencies, deploy, operate wallets, stage or commit or push Git, replace configuration, launch an unrequested council, inspect credentials, edit the PRD, edit the blockers file, or edit a prior draft or report
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

- Required targets: every in-repo consumer of the old one-word `previewExchangeIn` return, including the rate-provider path named in the blockers file
- Optional context: `docs/research/se-interface-refund-bundle-20261030-01a18660/REPORT.md`; blockers file lines 15 and 196; the full-spread PRD sentence FS-OWN-08
- Admitted read scope: the whole IndexedEx repository, including contracts, tests, scripts, and frontend. Do not read peer responses. Do not send private excerpts to a search service.
- Required tools: file read and local search
- Optional tools: none
- Public-query boundary: generalize public searches, or use public identifiers. Do not send private source excerpts to those services.
- Depth preflight: invoking agent is the root. Direct members need depth 1.
- Effective isolation: shared workspace, `isolated: false`. No automatic merge.

## Artifact root and delivery

- Admitted run root: `docs/research/se-fullspread-preview-consumers-20261103/`
- Delivery: file
- Intended final path: `docs/research/se-fullspread-preview-consumers-20261103/REPORT.md`
- Cooperative publication target: none. Do not edit the PRD, the blockers file, or prior resolution artifacts.

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
- Write only the owned response path on the initial pass.
- Do not launch sub-agents or another council.
- Do not include a Review findings section. No `FILL`.
- F13 and F14 are owner acceptances. They are not this question. Do not reopen them.
- Consultation does not authorize implementation or a PRD edit.

## What a consumer is

The old return is one `uint256`, 32 bytes. The accepted return is `(uint256 amountOut, uint256 amountRefunded)`. The signature is `previewExchangeIn(address,uint256,address)`. The selector is `0x89d61912`. The parameters do not change. `previewExchangeOut` and `exchangeOut` are not this change. `exchangeIn` has the same return change and selector `0xd02d3063`; list its return-decoders in a separate table, and do not mix them into the preview list.

A preview consumer is a call site, type binding, or decoder in this repository that reads that one-word return. Include a direct call, an interface-mediated call, a low-level `staticcall` or `abi.decode` of one word, a wrapper that forwards the one word, a test that asserts one word, and a frontend or script binding that expects one word. The rate-provider path named at blockers file line 196 is a required target. Examine it even if the call is indirect.

A declaration that still says `returns (uint256)` for `previewExchangeIn` is a consumer of the old ABI. The implementation that produces the word is a producer. List a producer only when it also consumes another preview return, and say which role it has.

These are not preview consumers: `previewExchangeOut`, `previewExchangeInManyToOne`, `previewExchangeOutOneToMany`, hook previews that are not `previewExchangeIn`, and salt previews. Put each examined family in an unaffected table with the search that excluded it. Do not omit a family by silence.

## Response shape

Use the research headings. Under Conclusions, three tables:

1. Preview consumers. Columns: path, line, kind (`direct`, `interface`, `low-level`, `wrapper`, `test`, `frontend`), current decoding, disposition (`migrate` or `unaffected`), and the reason.
2. `exchangeIn` return decoders, separate, same columns.
3. Examined and unaffected families, with the search pattern and the path searched.

If a required tree has no hit, write the pattern and the path. Do not invent a row. Cite a path and line you read for every row. Separate source observation from inference.

## Attempt caps

A member assignment caps at three, including the first request. A coordinator synthesis assignment caps at two. Disagreement, low confidence, and auth or policy failure are not retry reasons.

## Settlement

Wait for Native completion of every requested task. Quiet work is pending, not failure and not approval.
