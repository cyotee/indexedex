# Grok 4.7 code-review council

Project-local quality and security review, not code implementation. Start OpenCode
from this repository after a fresh process start so the command, agents and plugin
are discovered:

```text
/review-council Review contracts/vaults/standard against the family PRD. Optional audit: docs/security/audit/REPORT.md
```

An empty `/review-council` asks for a target. The command selects the **primary**
`review-council` agent (`subtask: false`). It does not change `/council` or normal
coding-agent routing. Follow up in the same coordinator session to retain reviewer
IDs. Switch back to a coding agent for a separately authorized fix.

Optional inputs are paths the human supplies: a PRD, an implementation plan, and
an audit report. Missing paths are reported. Absent documents are not invented.
The council reads code and those documents. It creates and updates Markdown
reports. It does not edit code while reviewing. When a full round is done, the
deliverable is a remediation PRD for the errors discovered. The default path is
`docs/reviews/<slug>/REMEDIATION_PRD.md`. A human-named `*REMEDIATION_PRD.md`
path may be created or updated instead. If no errors are confirmed, the PRD
says so and does not invent work. Writing that PRD does not authorize a fix.

| Agent | Role | Fixed model |
|---|---|---|
| `review-council` | Grok 4.7 coordinator | `xai/grok-4.7` |
| `review-council-astra` | Independent reviewer | `openai/gpt-6-astra` |
| `review-council-grok` | Independent reviewer | `xai/grok-4.7` |
| `review-council-minimax` | Independent reviewer | `minimax/MiniMax-M3` |
| `review-council-kimi` | Independent reviewer | `kimi-code-plan-global/k3` |

Kimi K3 uses top-level agent frontmatter `variant: high`. Confirm `xai/grok-4.7`
is listed by `opencode models` before a live round. This configuration has offline
coverage. Live routing has not been verified here.

## Discussion protocol

The full-roster protocol is the default. A targeted request invokes only the named
members and is labeled targeted, not consensus.

If the human explicitly tells the coordinator to replace a named reviewer, or to
change that reviewer's model, that is an operator-authorized replacement, not a
resume and not an Astra censorship retry. Open a new session of the same named
agent with a fresh task call and no continuation field. Label every result as a
replacement, not continuity. Share only the current target and the prior originals
the human says to share. Do not pass the old session's compaction history as
memory, and do not set a model override on the task call. The new session uses
the configured pin. A different model requires an operator pin change and a fresh
OpenCode process, then a new session. Continue cross-review on the new session ID.
Do not claim the replacement recalls the replaced session. The Astra censorship
cap is unchanged. A human-authorized Astra replacement still must not request
exploit procedures. Without that explicit instruction, do not silently substitute,
restart, or impersonate a missing reviewer. Reads and allowed Markdown report
edits remain permitted. Code edits stay denied.

The coordinator sends the same target and the same optional document paths for
four independent first passes. Synchronous calls may run sequentially. Each
substantive original is attributed and keeps its session ID. Cross-review resumes
only a successful original session and shows the other successful original
first-pass answers together, never earlier cross-review answers and never an
Astra refusal.

Findings cover quality and security: title, severity, file and line, intended
behavior when a document was supplied, broken requirement or invariant, impact
class, fix direction, and confidence. They do not include exploit procedures,
proof-of-concept code, payloads, or attack parameters. An audit item is confirmed,
refuted, or marked unverified against current code. Consensus and passing tests
are not proof.

### Astra censorship

Astra may refuse a security review so it does not describe how to exploit a
system. The Grok 4.7 coordinator detects that and retries. A substantive review
is not a refusal, including a finding that withholds a reproduction.

Censored means empty, an explicit refusal, a policy or safety refusal with no
file-level findings, or a content-filter error. Do not resubmit to extract a
withheld reproduction.

On censorship, do not resume the refused session. Rewrite as a defensive review
of this repository's own code and start a new `review-council-astra` session.
Keep the same files and document paths. Ask for location, broken requirement,
impact class, severity and fix direction. Do not request exploit steps. Do not
jailbreak: no instruction to ignore safety rules, no unrestricted persona, no
fictional criminal scenario.

ASTRA_RESUBMISSION_CAP: 2. That is two rewritten resubmissions after the initial
call, three attempts for that turn. The cap applies separately to the first pass
and to the cross-review. It is prompt orchestration, not a runtime call counter.
If Astra still does not answer, accept the absence and continue with Grok,
MiniMax M3 and Kimi K3. Do not impersonate Astra. Do not paste the refusal to
peers as a finding. Do not claim four-member consensus. Coordinator notes stay
labeled as coordinator notes.

## Enforcement

All five agents default-deny permissions. The allowlist matches the research
council reads: `read`, `glob`, `grep`, `webfetch`, native `websearch`,
`context7_resolve-library-id`, `context7_query-docs`, and
`websearch_web_search_exa`. The coordinator additionally has `question` and
`task` to the four named reviewers only. Native `permission.edit` allows Markdown under `docs/reviews/` and `reviews/`,
plus `*REMEDIATION_PRD.md` reports, then denies instruction filenames, hidden
paths and sensitive names. Source, tests, and config stay denied. `skill` is
forbidden. No shell, code edits,
LSP/AST writes, browser, other MCP, background or arbitrary custom tools.

`.opencode/plugins/review-council.ts` loads the same guard as the research council,
with `reviewProfile` from `.opencode/support/research-council.ts`. The research
plugin keeps `researchProfile` and does not accept review-council targets. Each
plugin assesses `owned` / `outside` / `unknown` scope before strict attribution,
using one validated SDK history snapshot for both stages. Positive outside scope
returns arguments unchanged and unfrozen, with `output.args` still writable.
Exact-call enclosing assistant identity does not depend on complete tool/state
payloads. Own-profile exact-call evidence or the latest same-session council user
turn requires strict validation. Conflicting exact identities, ambiguous message
envelopes and unresolved newer users remain strict. No older coding-user fallback,
argument-supplied identity or cached last agent is trusted. Unrelated historical
council calls and malformed historical part payloads do not taint outside scope.

If the exact call part is missing, a valid latest same-session outside-profile
user identity can establish scope. This is not per-call authorization: without a
persisted tool owner, an indistinguishable stale call after a coding switch may
pass. A visible exact council call still stays strict. Unknown scope still uses
the original model, parent, status and unique-call checks; SDK errors and invalid
response envelopes remain sanitized `RC_UNAVAILABLE`. Not all unknown coding
sessions are guaranteed to pass. Both plugin orders retain each owner's policy
and reject cross-profile council delegation. Diagnostic text is
`Review council: [RC_...]`. Codes match the research council. Fixed pins are
checked from metadata, not provider truth.

Restart in a fresh OpenCode process to load guard changes. Current runtime context
is **1.18.32**, with installed plugin/SDK packages **1.17.18**. Source-level
possibilities include native subtask `part.id` versus persisted `part.callID` and
tool-part visibility timing; these are not a live reproduction or confirmed root
cause. See [research council scope and limits](RESEARCH_COUNCIL.md#enforcement).

Writing a review never authorizes implementing it. Do not edit code while reviewing.

## Validation

Offline checks (no providers):

```sh
bun test ./.opencode/tests/research-council.test.ts ./.opencode/tests/review-council.test.ts
node node_modules/typescript/bin/tsc --noEmit --strict --skipLibCheck --target es2022 --module esnext --moduleResolution bundler .opencode/plugins/research-council.ts .opencode/plugins/review-council.ts .opencode/support/research-council.ts .opencode/tests/research-council.test.ts .opencode/tests/review-council.test.ts
```

After a fresh process, a live smoke should show five exact review-council names
and models, a permitted read, a denied shell, and one bounded Astra retry that
stops at the cap without a substitute finding. Do not treat offline tests as
live routing proof.
