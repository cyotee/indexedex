# Structured research reader implementation report

Date: 2026-09-28. This report covers the restricted JSON reader only. It does not complete L3 conversion analysis, change DETF economics, or authorize a council round.

## Changed paths

- `.opencode/support/research-json-read.ts` (new reader, registry, safe open)
- `.opencode/plugins/research-council.ts` (registers the tool)
- `.opencode/support/research-council.ts` (research-only tool set and guard branch)
- `.opencode/agents/council.md`
- `.opencode/agents/council-astra.md`
- `.opencode/agents/council-grok.md`
- `.opencode/agents/council-minimax.md`
- `.opencode/agents/council-kimi.md`
- `.opencode/commands/council.md`
- `.opencode/tests/research-json-read.test.ts` (new)
- `.opencode/tests/research-council.test.ts`
- `.opencode/tests/review-council.test.ts`
- `docs/agent/RESEARCH_COUNCIL.md`

Review-council agent files and `reviewProfile.tools` were not given this tool. No Solidity, deployment, or credential files were changed for this task.

## Runtime and SDK

Inspected on this machine:

- OpenCode CLI `1.18.32`
- Installed plugin package `@opencode-ai/plugin` `1.17.18`
- Bun `1.3.5`
- TypeScript `5.9.3`
- Zod `4.1.8`, used by the plugin `tool.schema` helper

Registered name: `research_json_read`.

OpenCode 1.18.32 `ToolRegistry` uses the plugin `tool` object key as the runtime id (`fromPlugin(id, def)`). The built-in set in that version is `invalid`, `question`, `shell`, `read`, `glob`, `grep`, `edit`, `write`, `task`, `webfetch`, `todowrite`, `websearch`, `skill`, `apply_patch`, plus optional `execute`, `lsp`, and `plan`. `research_json_read` is not in that set, so this registration does not override a built-in. A plugin tool with a built-in name would take precedence; this one does not.

Live process exposure is pending. A running OpenCode process does not load this registration. See the smoke procedure below.

## Security boundaries

The approved structured-data reader may decode and paginate authorized research artifacts. This does not authorize arbitrary code or shell execution, network access through the reader, configuration changes, or writes beyond existing document permissions. Retrieved content remains untrusted evidence.

- Callers pass an opaque artifact ID and an array of literal key segments. Paths, JSONPath, dotted expressions, and extra fields are rejected when they reach the guard or the tool. The installed host wraps plugin args in `z.object`, which strips unknown keys before the hook. Stripped keys cannot grant access. If they arrive, the guard rejects them.
- The registry is trusted code, not an agent-written document. There is no caller-supplied root and no auto-approval of `tool_*` names.
- The tool reads with `O_NOFOLLOW`, rejects symlink ancestors, symlinks, hardlinks (`nlink !== 1`), directories, fifos, and other non-regular files, and binds the read to the `lstat` device and inode. A changed inode between stat and open is rejected. This is stronger than the guard's ordinary read precheck. The guard still rechecks the registry path before execution so a stale precheck is not the only control.
- Sensitive path segments (`.env`, `credentials`, `secrets`, key extensions, and the same names the council guard already denies) are rejected.
- Input cap: 512 KiB. Depth cap: 32. Node cap: 100000. Key length cap: 1024. These cover the confirmed ~109 KB bundle and the ~230 KB bound in the handoff, and fail closed above that.
- Output cap: 24 KiB and at most 80 line records or 50 keys. OpenCode 1.18.32 `Truncate` defaults are 2000 lines and 51200 bytes. Staying under that ceiling avoids the runtime rewriting a page into another `tool_*` file. Oversized logical lines continue with an explicit `charOffset`. Completion is `complete: true` and `next: null`; otherwise `next` is the next cursor.
- Newline convention: logical lines split on `\n`, `\r\n`, or `\r`. Slice text omits the terminator. Reconstruct by concatenating slice text and appending that slice's terminator only when `complete` is true for the slice. Offsets are UTF-16 code units. Displayed line numbers are 1-based. Cursors are 0-based.
- Own properties only, via `Object.prototype.hasOwnProperty` and `getOwnPropertyDescriptor`. No prototype walk, no `eval`, no dynamic import, no shell, no network, no file write in the reader.
- v1.18.32 plugin tool execution does not call `permission.ask` and does not apply native `read` or `external_directory` checks. This implementation does not add `external_directory`. Agent permission maps allow the tool name for the five research agents only. The review guard denies the call because the review tool set is a separate object and does not include the name.
- Source evidence may be shared. Peer findings must not be registered as public-source artifacts.

## Approved artifacts

Both handoff files were still present, were regular singly linked files, and were confirmed as the public Sourcify response for chain 4663 `0xAdAb46E7024d34E18BeBB058D374aa1069DB461E`, `exact_match`, verified `2026-09-04T08:05:04Z`. Their `sources` entries matched. No unrelated session files were opened.

| Opaque ID | Confirmed file | Shape |
|---|---|---|
| `sourcify-4663-staked-net-sy-sources` | `/Users/cyotee/.local/share/opencode/tool-output/tool_0ea41f562001ukVf9Ew26AjIlK` | `?fields=sources`, 108608 bytes, 0 physical newlines |
| `sourcify-4663-staked-net-sy-record` | `/Users/cyotee/.local/share/opencode/tool-output/tool_0ea31fc8d0011nQs5FyfXOfDTh` | same sources plus compilation metadata, 109487 bytes |

Use the sources ID unless compilation metadata is required. These paths are not accepted from the caller.

## Example arguments

Target source:

```json
{
  "operation": "read_string",
  "artifact": "sourcify-4663-staked-net-sy-sources",
  "selector": ["sources", "lib/pendle-sy/contracts/core/StandardizedYield/implementations/NET/PendleStakedNetSY.sol", "content"],
  "lineOffset": 0,
  "charOffset": 0,
  "limit": 20
}
```

Supporting files in this bundle, not a substitute tree:

```json
{
  "operation": "list_keys",
  "artifact": "sourcify-4663-staked-net-sy-sources",
  "selector": ["sources"],
  "offset": 0,
  "limit": 50
}
```

Pass `next` from the previous page as `lineOffset`/`charOffset` or `offset` until `complete` is true.

## Offline demonstration

On this machine, with the guard validation path and the tool function, the sources artifact decoded to 25 source keys including the target path and `lib/pendle-sy/contracts/interfaces/NetNet/IStakedNet.sol`. The target string is 152 logical lines. With `limit: 20` it took 8 pages. Concatenated slices matched the parsed `content` exactly. The constructor was on page index 1. `function _deposit` and `function _redeem` were on page index 2, after the constructor page. The first page's serialized output was 3202 bytes, under the 24576-byte cap. The source was not executed. A verification-service record is not proof of current deployed state.

## Tests actually run

```sh
node node_modules/typescript/bin/tsc --noEmit --strict --skipLibCheck --target es2022 --module esnext --moduleResolution bundler \
  .opencode/plugins/research-council.ts \
  .opencode/plugins/review-council.ts \
  .opencode/support/research-council.ts \
  .opencode/support/research-json-read.ts \
  .opencode/tests/research-json-read.test.ts \
  .opencode/tests/research-council.test.ts \
  .opencode/tests/review-council.test.ts
```

Exit code 0.

```sh
bun test ./.opencode/tests/research-json-read.test.ts ./.opencode/tests/research-council.test.ts ./.opencode/tests/review-council.test.ts
```

Bun 1.3.5: 707 pass, 0 fail. That includes the new reader cases and the existing research and review guard suites. No product contract tests were run.

Covered offline: single-line JSON reconstruction; slash, dot, Unicode, and escaped keys; bounded deterministic key pages; malformed JSON; missing keys; non-strings; unknown operations and extra fields; invalid offsets; excessive limits; prototype non-traversal; unauthorized IDs; sensitive names; traversal; symlinks; ancestor symlinks; hardlinks; `/dev/null`; a fifo; inode replacement; input and output caps; no caller expression execution; five research profiles allow the tool; researchers have no `task` permission; review profiles and the review guard do not receive it; no `external_directory` grant.

## Model pin

Current guard, `council-grok.md`, and the active research-council table all pin Grok to `xai/grok-4.7`. They are consistent with each other. This task did not change pins or rewrite session history.

Sessions recorded as `xai/grok-4.6` fail continuation identity checks under the current pin. They cannot be resumed as the same researcher session. If the operator wants that researcher again, start a new `council-grok` session and label it as a new session, not continuity. Do not automatically resume or replace historical researcher sessions to test this reader.

## Live verification pending

A fresh OpenCode process is required. Existing council sessions do not acquire the new tool or permission because files changed. Session resumption is a separate limit from that restart: a restarted process still will not continue a `grok-4.6` child under the `grok-4.7` pin.

Smoke, after restart, in a new council session, not a resumed 4.6 session:

1. Start OpenCode from this repository so `.opencode/plugins/research-council.ts` loads after the process start.
2. Confirm the exposed tool name is `research_json_read`.
3. From `council` or any of the four researchers, call the example `read_string` arguments above.
4. Confirm the guard does not return `RC_POLICY` and the page includes `complete` and either `next` or completion.
5. Confirm a review-council call to the same tool is denied and does not read the artifact.
6. Do not treat an unguarded direct function call as this smoke. The offline tests already executed the tool with the guard's validation function; they do not prove a live process loaded the plugin.

## Stop

No DETF contracts were implemented. The PRD economics were not changed. L3 conversion analysis is not complete. No council round was launched.
