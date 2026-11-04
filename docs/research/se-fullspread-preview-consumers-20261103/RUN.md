# Council run record

## Identity

- Run ID: se-fullspread-preview-consumers-20261103
- Profile: research
- Council kind: full
- Question: What is the complete in-repo list of consumers of the old 32-byte `previewExchangeIn` return?
- Brief: `docs/research/se-fullspread-preview-consumers-20261103/brief.md`
- Current phase: published
- Phase note: all four inventories settled. The reconciled list is in REPORT.md and INDEX.md. Advisory on the merge was not run. F13 and F14 stay accepted. The PRD and the blockers file were not edited.

## Owner acceptances recorded, not reopened

- F13: accepted. Deployed liquidity is the raw liquidity number used in mint and burn. Deployed token reserves are the token amounts plus unpaid fees returned by `reserves()` and `reserveOfToken`.
- F14: accepted. The PRD pass replaces the named compound and idle sentences with the B-02 lock and the principal-only withdrawal rule.

## Authorization

- Source: explicit council directive
- Authorizing task or role: the owner told the council to find all consumers and write a complete list
- Authorized writes: the run root artifacts named in the brief
- Not authorized: implementation, project tests, installs, deployment, wallets, Git, configuration replacement, edits to the blockers file, the PRD, or prior resolution artifacts
- Inherited permissions: accepted. Same parent permissions are not extra authority and not a sandbox.

## Native owner

- Owner session ID: not exposed
- Root session ID: not exposed
- Owning task ID: not exposed
- Control channel: invoking agent

## Coordinator

| Field | Value |
| --- | --- |
| Requested mode | invoking-agent |
| Requested role | invoking agent |
| Requested model and reasoning | invoking session model |
| Actual role | invoking agent |
| Actual model and reasoning | not exposed |
| Task ID | not exposed |

## Roster

| Label | Requested model | Task ID | Status |
| --- | --- | --- | --- |
| astra | `chatgpt-subscription/gpt-6-astra:high` | st_01a1a1c1 | completed |
| grok | `xai/grok-4.7:xhigh` | st_01a1a1c2 | completed |
| minimax | `minimax/MiniMax-M3` | st_01a1a1c3 | completed |
| kimi | `kimi-coding/k3.1-pro:high` | st_01a1a1c4 | completed |

## Assignments

| Assignment | Attempts | Status |
| --- | --- | --- |
| se-fullspread-preview-consumers-20261103/member/astra/initial | 1 | completed as st_01a1a1c1 |
| se-fullspread-preview-consumers-20261103/member/grok/initial | 1 | completed as st_01a1a1c2 |
| se-fullspread-preview-consumers-20261103/member/minimax/initial | 1 | completed as st_01a1a1c3 |
| se-fullspread-preview-consumers-20261103/member/kimi/initial | 1 | completed as st_01a1a1c4 |
| se-fullspread-preview-consumers-20261103/coordinator/synthesis | 1 | published without advisory |

## Publication

- Final path: `docs/research/se-fullspread-preview-consumers-20261103/REPORT.md`
- Publication state: published
- Implementation authority: none
- Lock authority: none. The list is an inventory, not an owner lock.
