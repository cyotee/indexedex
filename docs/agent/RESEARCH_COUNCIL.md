# Astra / Grok / MiniMax M3 / Kimi K3 research council

Project-local, human-led research and document authoring, not code implementation. Start OpenCode
from this repository after a fresh process start so local agents, commands and
plugins are discovered:

```text
/council Compare the risks of <proposal> against the current PRD. Cite evidence.
```

An empty `/council` asks for a topic. The command selects the **primary** `council`
agent (`subtask: false`); it does not change normal coding-agent routing. Follow
up in the same moderator session to retain the discussion and researcher IDs.
Switch back to your coding agent for a separately authorized implementation.
Configuration changes require a fresh OpenCode process to reload the command,
all five agents and the guard. An already-running council does not acquire these
permissions merely because the files changed.

Use a normal checkout with the required source and guidance readable inside the
worktree. Externally symlinked Crane/skill paths are **not supported by this
initial permission profile**: native `external_directory` checks can deny them.
Report unavailable guidance instead of guessing or broadening permissions. For
that layout, run the council from the canonical checkout; no blanket external
directory permission is granted.

| Agent | Role | Fixed model |
|---|---|---|
| `council` | Astra moderator | `openai/gpt-6-astra` |
| `council-astra` | Independent researcher | `openai/gpt-6-astra` |
| `council-grok` | Independent researcher | `xai/grok-4.7` |
| `council-minimax` | Independent researcher | `minimax/MiniMax-M3` |
| `council-kimi` | Independent researcher | `kimi-code-plan-global/k3` |

Kimi K3 uses top-level agent frontmatter `variant: high` (the provider variant
sets `reasoningEffort: high`). The research Grok pin is now `xai/grok-4.7`.
Sessions recorded as `xai/grok-4.6` fail continuation identity checks and must
not be resumed under this pin. Astra and MiniMax model/effort settings are
unchanged. This configuration has offline coverage; Kimi live routing and the
four-researcher round have not been verified here.

## Discussion protocol

The full-roster protocol below is the default. You can explicitly request a
targeted response, such as "Ask MiniMax to challenge that assumption" or a
connectivity probe. Only the named members are invoked for those requested turns;
existing sessions are reused, permissions remain unchanged, and results are
labeled targeted responses rather than full-council consensus.

The moderator sends the same question/context separately for four independent
first passes, with no peer responses until all four originals are collected.
Synchronous calls may run sequentially; the initial reasoning remains independent. Each returns
attributed original findings, assumptions, code paths/lines, versions, URLs,
access dates, confidence and evidence gaps. The moderator preserves all four
original session IDs and makes four combined cross-review continuations, one
per researcher: each sees the other three **original first-pass answers together**,
never earlier cross-review answers or a moderator paraphrase. A complete round
is **eight total task calls: four initial calls and four cross-review resumes**.
It returns agreements, corrections, dissent and a
human checkpoint, then stops. This round bound is prompt orchestration, not a
runtime call counter. A follow-up can request another bounded round.

Read `CLAUDE.md`, relevant current PRDs and canonical skill files directly;
`skill` is forbidden. Use Context7 first for API/library questions, websearch
for broader research, and primary sources where possible. Do not send secrets
or proprietary source to external services. Consensus, investment narratives,
and passing tests are not proof of security or economic soundness.

Every delegation, including a resume, must include:

```json
{
  "description": "Independent Grok research",
  "prompt": "<question, context, research-only constraints>",
  "subagent_type": "council-grok",
  "load_skills": [],
  "run_in_background": false
}
```

OMO 4.19.4 resumes with `task_id: "ses_..."`; the previously inspected 3.15.3
schema uses `session_id: "ses_..."`. Use the field in the **actual tool schema**,
never both, never `bg_...`, and always retain `subagent_type`. The guard observes
the executor's `tool.definition` JSON schema and accepts only the continuation
field that the loaded OMO task declares. Unknown or ambiguous schemas fail
closed for continuation. Native task schemas that cannot express the explicit safety
parameters are not supported: report incompatibility rather than relaxing the
guard. Do not use category, command, skills, model overrides, or background mode.

## Enforcement

### Document authoring policy

All five agents are expected to author requested/assigned research reports, PRDs
and implementation plans, not merely describe them in chat. Create/update `.md`
files only under these repository-relative roots:

- `docs/research/`
- `docs/plans/`
- `docs/strategies/`
- `research/`
- `plans/`

The moderator owns final consolidation and assigns distinct output paths to each
researcher. Researchers write distinct assigned outputs only. No peer artifact
reading during independent passes, including via read/glob/grep; the shared
filesystem must not leak peers' originals before all four first passes finish.
Preserve originals before revising drafts and pass the other three original answers
at cross-review, never earlier cross-review artifacts. Assignment ownership and
informational independence are prompt obligations, not filesystem access control
between the five agents. Use four initial sessions plus four same-session
cross-reviews. Return saved paths at the human checkpoint.

Writing a plan never authorizes executing it. Code implementation, shell commands,
tests, deployments, configuration/instruction edits, deletion and moving files
remain forbidden. A request for a co-located PRD outside these roots must be
redirected to an allowed document location or handed off to a separately
authorized coding task, not used to broaden the allowlist.

All five agent definitions default-deny permissions. The exact research
allowlist is `read`, `glob`, `grep`, `webfetch`, native `websearch`,
`context7_resolve-library-id`, `context7_query-docs`, and
`websearch_web_search_exa`. The moderator additionally has `question` and `task`
to the four named researchers only. Researchers cannot delegate or ask the user
directly. Native `permission.edit` covers `write`, `edit` and `apply_patch`: its
ordered pattern map starts with `"*": deny`, allows `root/*.md` alongside
`root/**/*.md` for each of the five roots above, then denies instruction filenames,
hidden paths and sensitive names. OpenCode v1.18.31's
[`Wildcard.match`](https://github.com/anomalyco/opencode/blob/v1.18.31/packages/opencode/src/util/wildcard.ts)
maps every `*` to `.*`; `**/` does not match zero directories. The direct-child
patterns therefore permit paths such as `plans/report.md`. Native tools check
repository-relative permission paths, including when their input is absolute.
Patterns are last-match-wins. This is not an unconditional mutation-tool grant;
the runtime guard must also approve every destination. No shell, other file
mutation, LSP/AST writes, browser, skill indirection,
other MCP, background or arbitrary custom tools are allowed.

`.opencode/plugins/research-council.ts` auto-loads the guard implemented in
`.opencode/support/research-council.ts`. This is necessary because OMO replaces
native task execution and can enable `call_omo_agent` in its child prompt. The
guard runs at `tool.execute.before` and throws before tool execution:

- Resolves the actual caller from SDK `session.messages`, matching the exact
  `callID`, tool name and session on a pending/running assistant tool part.
  Its parent must be the latest user turn with the same agent. It never trusts
  caller identity in arguments or falls back to a stale "last agent" cache.
- Observes the plugin task's definition without modifying it and rejects a
  continuation alias not consumed by that executor.
- Checks council caller user/assistant model metadata against the fixed pins.
  Known, attributed noncouncil calls are returned unchanged.
- Validates every task field; checks target registration/model via `app.agents`.
  A continuation must be a child of the current moderator according to
  `session.get`, with ordinary persisted user **and** assistant evidence matching
  the target agent/model and unique, nonempty same-session message IDs. A history-only
  exception accepts completed framework compaction summaries (`agent`/`mode` =
  `compaction`, `summary: true`, `finish: stop`, completed time, no error) linked
  to a preceding researcher-pinned user marker with exactly one valid compaction
  part. The summary must retain that same researcher model pin; configurable
  compaction model overrides are not authorized. Owned, uniquely identified text,
  reasoning, step-start, step-finish and patch parts are validated; usable summary
  text is required, tools and unknown parts are forbidden. Partial signatures and
  malformed markers (even unreferenced ones) fail closed. This exception does not
  change active caller attribution or let compaction replace ordinary evidence.
- Freezes council argument objects and empty skill arrays, and locks the output
  argument reference so a later hook cannot replace the validated task arguments.
  OMO's inspected argument preparation copies/normalizes inputs; it does not
  need to mutate this object. Compatibility still requires live verification.
- Denies `.env`, auth/credential/secret filenames and common key extensions on
  reads; resolves symlinks before the same path check. An ordinary missing path
  (`ENOENT` or `ENOTDIR`) is not a guard denial: the native read tool reports
  the absence. A resolved symlink to a sensitive target is still denied as
  `RC_POLICY`. Other unresolvable read errors are also `RC_POLICY`, never
  `RC_UNAVAILABLE`. Native permissions add matching filename exclusions.
- For writes/edits, validates `filePath`; for patches, parses the entire
  `patchText` envelope before validating all destinations. Only Add/Update file
  sections are supported, with prefixed Add content and explicit Update `@@`
  hunks. Delete/Move, unknown directives, malformed/trailing wrappers, duplicate
  destinations (including relative/absolute aliases), and any mixed
  allowed/forbidden patch are rejected before execution. Prefixed Markdown
  content that looks like a patch directive is still content. Patches use LF
  lines, with at most one trailing newline. Update hunks must contain a change.
  The accepted subset rejects every interior line whose `trim()` is
  `*** End Patch`, including space-prefixed Update context: the
  [v1.18.31 native parser](https://github.com/anomalyco/opencode/blob/v1.18.31/packages/opencode/src/patch/index.ts)
  selects that first trimmed marker and can ignore subsequent file sections.
  Literal added content `+*** End Patch` remains permitted. That ambiguous context
  is outside the supported patch subset; a denial still requires stopping and reporting.
- Uses a canonical repository root and a fixed internal allowlist, not roots
  supplied in tool arguments. Rejects traversal, ambiguous paths, non-`.md`
  targets, sensitive names such as `credentials.md`, case-insensitive
  `AGENTS.md`/`CLAUDE.md`/`SKILL.md`, and all hidden path components at any depth
  (including `.opencode`, `.github`, `.claude`, `.agents`, `.codex`, `.grok`, `.git`).
  Every existing descendant ancestor and leaf is checked with `lstat`: even
  internal/dangling symlinks are rejected; leaves must be regular files with
  `nlink === 1`, not hardlinks, directories or special files. Missing nested
  document directories are accepted without guard writes. Non-ENOENT filesystem
  errors fail closed. Validated mutation arguments and their output reference
  are frozen just like other council calls.

**Fail closed:** if the SDK fails or an active call cannot be attributed, the
guard denies the call even if it might have been a normal coding call. This can
temporarily block coding tools in this project. Do not work around a denial with
a different tool or agent. Report the failure and have the operator investigate
the metadata/lifecycle. A missing ordinary read is not that failure. Record the
path, do not retry it, and continue the roster. Stop without substitutes only
for a researcher session failure or for `RC_ATTRIBUTION`, `RC_IDENTITY`,
`RC_HISTORY`, `RC_COMPACTION`, `RC_EVIDENCE`, or a genuine SDK
`RC_UNAVAILABLE`. The 2026-09-17 smoke that stopped after a nonexistent read is superseded. Fixed diagnostic codes are `RC_POLICY`, `RC_ATTRIBUTION`,
`RC_IDENTITY`, `RC_HISTORY`, `RC_COMPACTION`, `RC_EVIDENCE` and `RC_UNAVAILABLE`.
`RC_ATTRIBUTION` reports "active call attribution failed" for missing, ambiguous,
stale or malformed active calls. SDK response failures use `RC_UNAVAILABLE`;
malformed continuation message structure uses `RC_HISTORY`, and malformed
compaction time, metadata, tokens and cache records use `RC_COMPACTION`. Only private
guard errors select their fixed messages; foreign/SDK exceptions, including forged
public error codes, never supply diagnostic text, URLs or stacks. Compaction handling
is covered offline against the v1.18.31/1.18.32 record shape; live continuation
compatibility remains an operator check, not a claim made by these tests.

This is an **application-level tool guard, not an OS sandbox or DLP system**.
It trusts OpenCode's SDK records, tool implementations and hook dispatch. It
does not prevent another installed plugin's own shell/network activity or its
internal prompt changes. It cannot guarantee provider identity from metadata,
prevent silent provider fallback text without tool calls, or recognize secrets
in innocuously named files. Read exclusions do not filter recursive grep output;
never target credentials through search. Research URLs can cause external GET
requests; no network-isolation claim is made. Do not give this workflow access
to secret-bearing datasets when stronger isolation is required.
Filesystem checks are prechecks, not atomic safe-open operations. They assume
trusted local writers: another process could replace an ancestor/leaf with a
symlink or hardlink after validation and before the native tool writes (TOCTOU).
The guard cannot remove that race, inspect document intent, or distinguish code
embedded in Markdown from research examples. Use OS-level isolation when those
guarantees are required. The configured repository root itself is canonicalized;
symlink rejection applies to its descendant document paths.

## Compaction continuation probe (2026-09-24)

The updated guard passed 578 offline tests and the strict TypeScript command below.
A fresh `opencode run` process resumed original moderator
`ses_f4edfa3f4ffebpDxks20UPWrqB` as `council`. It made exactly one synchronous
`task` continuation using `session_id` to original Grok child
`ses_f4edb8e85ffeCS8Miy5XkGe6Nk`. The task completed, returned
`GROK_CONTINUATION_OK`, and reported `council-grok` / `xai/grok-4.6` in runtime
task metadata. No replacement session, fork, metadata rewrite or guard bypass was
used. This verifies that continuation for this existing compacted history works;
it does not attest to provider internals or every possible compaction history.

Findings recovery was checked separately, without supplying the original answer
to the probe. Grok explicitly reported that its verbatim earliest Pendle-split
first pass was unavailable in retained context and that its recollection was
partly reconstructed from a summary. A separate transcript read confirmed the
original findings remain stored in message `msg_0b1282a71001jgob82x7oWY7fa`
(2026-09-17T20:56:34.673Z), including the unclaimed-interest liquidity distinction,
combined opaque SE proposal and expiry wind-down. The probe did not reproduce that
complete answer and also referenced later design decisions. Therefore **stored
transcript availability is verified; full original-findings recall is not**.
No restoration prompt or new research was performed.

## Runtime evidence and limits (2026-09-17)

The exact MiniMax pin `minimax/MiniMax-M3` was confirmed with `opencode models`.
A targeted live probe in moderator session `ses_f4eb01230ffemgSPUH3kOY8xmq`
launched `council-minimax` as child `ses_f4eafacceffeFCooaHz1c6fPu3`, then
successfully resumed that same child. Runtime metadata reported
`minimax/MiniMax-M3` on both turns. The child returned `M3_RESEARCH_OK` and then
recalled that marker while returning `M3_RESUME_OK`. Exported child records
confirm a completed `read` under the exact MiniMax agent/model identity.
The read requested one line, but the installed wrapper injected additional
repository context; the probe does not establish strict one-line exposure.

The historical offline suite passed 210 tests, with clean strict TypeScript and
LSP checks. The complete three-researcher six-call round was not rerun live;
M3 routing/tool use/continuation were tested directly and the previous Astra/Grok
evidence remains historical. This is runtime metadata evidence, not independent
attestation of provider internals.

Verified CLI: OpenCode **1.18.31**, Bun **1.3.5**. Local
`.opencode/package.json` remains unchanged at plugin type package **1.17.18**.
Both original Astra/Grok models were in `opencode models`. Multiple OMO versions are
cached locally (including 4.19.4 and 3.15.3); do not infer the running version from
the cache. The actual live Task schema used **`session_id`**, and the guard's
definition observer accepted successful continuations with that field.

Historical two-model live smoke session `ses_f4f0bbc8dffeC4ECOCVgATA9Rx` demonstrated:

- A permitted repository read with the local guard loaded.
- Separate Astra (`ses_f4f0a122bffeZIWc9HFJ8f96BG`) and Grok
  (`ses_f4f0953e3ffeqPoWGtdeWY4h23`) research sessions; task metadata reported
  `openai/gpt-6-astra` and `xai/grok-4.6` respectively.
- Successful same-session cross-review for both models, including after a CLI
  timeout interrupted the initial smoke. No replacement sessions were used.
- A further Astra continuation for Context7 research and a successful moderator
  `websearch_web_search_exa` call.
- Exported Astra child records confirm completed `context7_resolve-library-id`
  and `context7_query-docs` calls under `council-astra` / `openai/gpt-6-astra`.
- A deliberately nonexistent, nonsecret file-read probe rejected with the
  guard's fixed denial before the read tool executed. The moderator stopped
  rather than attempting a bypass.
- A separate default coding-agent session completed a repository read and
  returned `SMOKE_OK`, verifying noncouncil read passthrough in the live runtime.

These are runtime routing/behavior observations, not independent attestation of
provider internals. Deliberate mutation and invalid-delegation negatives are
covered by the automated hook tests, not by attempting real writes in this repo.

Installed `~/.cache/opencode/packages/node_modules/oh-my-openagent/dist/index.js`:

- lines 133078-133192: custom task dispatch, independent of native task target
  permission filtering; 132662-132805: registry/model resolution;
- lines 131762-131780: synchronous child prompt; lines 131745-131750 enable
  `call_omo_agent`; 132891 onward prepares task arguments;
- installed `@opencode-ai/plugin/dist/index.d.ts:235`: hook input is
  `{ tool, sessionID, callID }`, **not** an agent field.

The configured OMO npm plugin is global. Documented load order puts global
config plugins before project `.opencode/plugins/`, with hooks in sequence
([OpenCode plugin docs](https://opencode.ai/docs/plugins/), accessed 2026-09-17).
The guard locks its validated output as an additional mutation defense. No
internal monkey patches or global routing changes are used. Live allowed calls,
resumes, and the guard-denied read established call-part visibility and argument
freeze compatibility in the tested runtime. Recheck these after harness/plugin
upgrades; unit tests alone do not establish runtime compatibility. If the call
part is not visible, this implementation deliberately fails closed.

## Validation and operator smoke checklist

Offline checks (no providers, no dependency installation):

```sh
bun test ./.opencode/tests/research-council.test.ts
node node_modules/typescript/bin/tsc --noEmit --strict --skipLibCheck --target es2022 --module esnext --moduleResolution bundler .opencode/plugins/research-council.ts .opencode/support/research-council.ts .opencode/tests/research-council.test.ts
```

The tests use Bun's test runner with Node assertions and its compatible test
registration types (no additional Bun type package). They exercise the real auto-loaded wrapper with SDK doubles, not OMO's
executor or a live provider. YAML parsing uses the existing `yaml` dependency.
They cover default-deny definitions, exact model/tool names, malformed tasks,
researcher escape attempts, both resume field spellings, parent/model mismatch,
stale/switched turns, unknown attribution, SDK errors and noncouncil passthrough.
Document-authoring regressions use disposable filesystem fixtures for all five
agents' writes, edits and patches, scoped native YAML rules, prompt obligations,
path escapes, links, special targets, malformed/mixed patches and argument locks.
These are offline guard/configuration checks. The historical live smoke above
predates document authoring; it does not verify the new permissions or native
mutation execution. No billable council run is required by these offline tests.

To repeat runtime validation after configuration or harness changes, use a fresh process:

1. Inspect the server's read-only `app.agents` registry: all five exact names,
   modes and models, plus Kimi's `high` variant. Do not use a config dump that may expose credentials.
2. Verify the project plugin loads after OMO and that an actual tool call's
   persisted record is visible during the hook. Check normal coding passthrough.
3. Run a minimal non-sensitive `/council` question. Verify four different child
   sessions, each exact agent/model, and one successful same-session combined
   cross-review per researcher (eight calls total). Verify all originals are collected
   before peer sharing and each review sees only the other three original answers.
4. Confirm a Context7 resolve/query and a web search work. Attempt harmless
    denied shell/out-of-scope edit/delegation calls; confirm no underlying tool executes.
5. Verify empty input, follow-up, unavailable participant and failed resume
   handling. No substitute models, invented answers or silent fresh sessions.
6. With explicit operator authorization, verify a harmless assigned `.md` report
   can be created/updated in an allowed root through native tools, and verify
   distinct assignments and no peer artifact reading during independent passes.
   Verify the final human checkpoint and refusal to implement/execute plans/deploy.

If a participant is unavailable, present only the partial evidence actually obtained,
identify the missing participant, stop without substitutes, and return control. If context/identity checks
fail, report continuity failure rather than pretending a new session is a resume.
