import { lstat, realpath } from "node:fs/promises";
import { isAbsolute, relative, resolve } from "node:path";

// Keep helpers outside plugins/: OpenCode treats every plugin export as an initializer.
export interface CouncilClient {
  session: {
    messages(input: { path: { id: string } }): Promise<unknown>;
    get(input: { path: { id: string } }): Promise<unknown>;
  };
  app: { agents(): Promise<unknown> };
}
export interface ToolInput { tool: string; sessionID: string; callID: string }
export interface CouncilRuntime { continuationField?: "task_id" | "session_id" }
export interface CouncilProfile {
  label: string;
  moderator: string;
  models: Record<string, string>;
  researchers: ReadonlySet<string>;
  documentRoots: readonly string[];
  reportSuffixes?: readonly string[];
  tools: ReadonlySet<string>;
}
const researchTools = new Set(["read", "glob", "grep", "webfetch", "websearch",
  "context7_resolve-library-id", "context7_query-docs", "websearch_web_search_exa"]);
export const researchProfile: CouncilProfile = {
  label: "Research council",
  moderator: "council",
  models: {
    council: "openai/gpt-6-astra",
    "council-astra": "openai/gpt-6-astra",
    "council-grok": "xai/grok-4.7",
    "council-minimax": "minimax/MiniMax-M3",
    "council-kimi": "kimi-code-plan-global/k3",
  },
  researchers: new Set(["council-astra", "council-grok", "council-minimax", "council-kimi"]),
  documentRoots: ["docs/research", "docs/plans", "docs/strategies", "research", "plans"],
  tools: researchTools,
};
export const reviewProfile: CouncilProfile = {
  label: "Review council",
  moderator: "review-council",
  models: {
    "review-council": "xai/grok-4.7",
    "review-council-astra": "openai/gpt-6-astra",
    "review-council-grok": "xai/grok-4.7",
    "review-council-minimax": "minimax/MiniMax-M3",
    "review-council-kimi": "kimi-code-plan-global/k3",
  },
  researchers: new Set(["review-council-astra", "review-council-grok", "review-council-minimax", "review-council-kimi"]),
  documentRoots: ["docs/reviews", "reviews"],
  reportSuffixes: ["REMEDIATION_PRD.md"],
  tools: researchTools,
};

export function observeTaskDefinition(runtime: CouncilRuntime, input: { toolID: string }, output: { jsonSchema?: unknown }) {
  if (input.toolID !== "task" || !output.jsonSchema) return;
  const properties = record(record(output.jsonSchema).properties);
  // The registry includes both native and plugin tasks. Only the OMO schema has
  // our required sync/skill controls; native task cannot run this protocol.
  if (!hasOwn(properties, "run_in_background") || !hasOwn(properties, "load_skills")) return;
  const fields = ["task_id", "session_id"].filter(field => hasOwn(properties, field));
  runtime.continuationField = fields.length === 1
    ? fields[0] === "task_id" ? "task_id" : "session_id"
    : undefined;
}
const taskKeys = new Set(["description", "prompt", "subagent_type", "load_skills",
  "run_in_background", "task_id", "session_id"]);

const diagnostics = {
  RC_POLICY: "tool policy validation failed",
  RC_ATTRIBUTION: "active call attribution failed",
  RC_IDENTITY: "agent/model identity mismatch",
  RC_HISTORY: "invalid continuation history",
  RC_COMPACTION: "invalid historical compaction",
  RC_EVIDENCE: "continuation lacks ordinary researcher evidence",
  RC_UNAVAILABLE: "attribution or metadata unavailable",
} as const;
type DiagnosticCode = keyof typeof diagnostics;
class CouncilError extends Error {
  #code: DiagnosticCode;
  constructor(code: DiagnosticCode) { super(diagnostics[code]); this.#code = code; }
  static code(error: unknown): DiagnosticCode {
    return error !== null && typeof error === "object" && #code in error ? error.#code : "RC_UNAVAILABLE";
  }
}
function deny(_reason: string, code: DiagnosticCode = "RC_POLICY"): never { throw new CouncilError(code); }
function record(value: unknown, code: DiagnosticCode = "RC_POLICY"): Record<string, unknown> {
  if (!value || typeof value !== "object" || Array.isArray(value)) deny("invalid metadata or arguments", code);
  return value as Record<string, unknown>;
}
function data(value: unknown): unknown {
  const response = record(value, "RC_UNAVAILABLE");
  if (response.error || response.data === undefined) deny("SDK metadata unavailable", "RC_UNAVAILABLE");
  return response.data;
}
function list(value: unknown, code: DiagnosticCode = "RC_UNAVAILABLE"): unknown[] {
  if (!Array.isArray(value)) deny("expected metadata list", code);
  return value;
}
function text(value: unknown): value is string { return typeof value === "string" && value.trim().length > 0; }
function hasOwn(value: object, key: string): boolean { return Object.prototype.hasOwnProperty.call(value, key); }
function modelOf(info: Record<string, unknown>): string {
  const model = info.role === "user" ? record(info.model) : info;
  return `${model.providerID}/${model.modelID}`;
}
function verifyIdentity(info: Record<string, unknown>, agent: string, profile: CouncilProfile): void {
  if (info.agent !== agent || modelOf(info) !== profile.models[agent]) deny("agent/model identity mismatch", "RC_IDENTITY");
}
async function messages(client: CouncilClient, id: string, code: DiagnosticCode = "RC_HISTORY") {
  return list(data(await client.session.messages({ path: { id } }))).map(value => {
    const message = record(value, code);
    return { info: record(message.info, code), parts: list(message.parts, code) };
  });
}

async function caller(client: CouncilClient, input: ToolInput, profile: CouncilProfile): Promise<string> {
  if (!text(input.sessionID) || !text(input.callID)) deny("missing call identity", "RC_ATTRIBUTION");
  const history = await messages(client, input.sessionID, "RC_ATTRIBUTION");
  const matches = history.flatMap(message => message.parts.filter(value => {
    const part = record(value, "RC_ATTRIBUTION");
    return part.type === "tool" && part.callID === input.callID;
  }).map(part => ({ info: message.info, part: record(part, "RC_ATTRIBUTION") })));
  if (matches.length !== 1) deny("cannot uniquely attribute active tool call; no fallback to last agent", "RC_ATTRIBUTION");
  const { info, part } = matches[0];
  const status = record(part.state, "RC_ATTRIBUTION").status;
  if (info.role !== "assistant" || info.sessionID !== input.sessionID || part.tool !== input.tool ||
      (status !== "pending" && status !== "running") || !text(info.agent)) deny("invalid active tool call", "RC_ATTRIBUTION");
  const latestUser = history.filter(message => message.info.role === "user").at(-1)?.info;
  if (!latestUser || latestUser.sessionID !== input.sessionID || latestUser.id !== info.parentID ||
      latestUser.agent !== info.agent) deny("stale or switched active turn", "RC_ATTRIBUTION");
  if (hasOwn(profile.models, info.agent)) {
    verifyIdentity(info, info.agent, profile);
    verifyIdentity(latestUser, info.agent, profile);
  }
  return info.agent;
}

function finite(value: unknown): value is number {
  return typeof value === "number" && Number.isFinite(value) && value >= 0;
}
function partTime(value: unknown): void {
  const time = record(value, "RC_COMPACTION");
  if (!finite(time.start) || !Number.isInteger(time.start) ||
      (hasOwn(time, "end") && (!finite(time.end) || !Number.isInteger(time.end) || time.end < time.start)))
    deny("invalid part time", "RC_COMPACTION");
}
function summaryPart(part: Record<string, unknown>): boolean {
  const optional = (key: string, valid: (value: unknown) => boolean) => !hasOwn(part, key) || valid(part[key]);
  if (part.type === "text" || part.type === "reasoning") {
    if (typeof part.text !== "string" || !optional("metadata", value => {
      record(value, "RC_COMPACTION"); return true;
    })) deny("invalid summary content", "RC_COMPACTION");
    if (part.type === "reasoning" || hasOwn(part, "time")) partTime(part.time);
    if (!optional("synthetic", value => typeof value === "boolean") ||
        !optional("ignored", value => typeof value === "boolean")) deny("invalid text flags", "RC_COMPACTION");
    return part.type === "text" && part.ignored !== true && text(part.text);
  }
  if (part.type === "step-start" || part.type === "step-finish") {
    if (!optional("snapshot", value => typeof value === "string")) deny("invalid snapshot", "RC_COMPACTION");
    if (part.type === "step-finish") {
      const tokens = record(part.tokens, "RC_COMPACTION");
      const cache = record(tokens.cache, "RC_COMPACTION");
      if (typeof part.reason !== "string" || !finite(part.cost) ||
          ![tokens.input, tokens.output, tokens.reasoning, cache.read, cache.write].every(finite) ||
          (hasOwn(tokens, "total") && !finite(tokens.total))) deny("invalid step finish", "RC_COMPACTION");
    }
    return false;
  }
  if (part.type === "patch" && typeof part.hash === "string" && Array.isArray(part.files) &&
      part.files.every(file => typeof file === "string")) return false;
  deny("forbidden or malformed summary part", "RC_COMPACTION");
}

function validateHistory(history: Awaited<ReturnType<typeof messages>>, sessionID: string, target: string, profile: CouncilProfile) {
  const ids = new Set<string>();
  const partIDs = new Set<string>();
  const markers = new Set<string>();
  let userEvidence = false;
  let assistantEvidence = false;
  for (const { info, parts } of history) {
    if (!text(info.id) || ids.has(info.id) || info.sessionID !== sessionID ||
        (info.role !== "user" && info.role !== "assistant")) deny("invalid history identity", "RC_HISTORY");
    ids.add(info.id);
    const parsed = parts.map(value => record(value, "RC_HISTORY"));
    for (const part of parsed) {
      if (!hasOwn(part, "id")) continue;
      if (!text(part.id) || partIDs.has(part.id)) deny("invalid history part ID", "RC_HISTORY");
      partIDs.add(part.id);
    }
    const marker = parsed.some(part => part.type === "compaction");
    // User summary objects are edit-diff metadata, not compaction summaries.
    // Any partial assistant signature must take the strict path, never be skipped.
    const summary = info.agent === "compaction" || info.mode === "compaction" ||
      (hasOwn(info, "summary") && (info.role === "assistant" ? info.summary !== false :
        !info.summary || typeof info.summary !== "object" || Array.isArray(info.summary)));
    if (marker || summary) {
      for (const part of parsed) {
        if (!text(part.id) || !/^prt_[A-Za-z0-9]+$/.test(part.id) ||
            part.messageID !== info.id || part.sessionID !== sessionID) deny("invalid compaction part ownership", "RC_COMPACTION");
      }
    }
    if (marker) {
      verifyIdentity(info, target, profile);
      const part = parsed[0];
      if (summary || info.role !== "user" || parsed.length !== 1 || typeof part.auto !== "boolean" ||
          (hasOwn(part, "overflow") && typeof part.overflow !== "boolean") ||
          (hasOwn(part, "tail_start_id") && (typeof part.tail_start_id !== "string" ||
            !/^msg_[A-Za-z0-9]+$/.test(part.tail_start_id)))) deny("invalid compaction marker", "RC_COMPACTION");
      markers.add(info.id);
    } else if (summary) {
      if (info.role !== "assistant" || info.agent !== "compaction" || info.mode !== "compaction" ||
          info.summary !== true || modelOf(info) !== profile.models[target] || !text(info.parentID) ||
          !markers.has(info.parentID) || info.finish !== "stop" || info.error !== undefined)
        deny("invalid compaction summary", "RC_COMPACTION");
      const time = record(info.time, "RC_COMPACTION");
      if (!finite(time.created) || !Number.isInteger(time.created) || !finite(time.completed) ||
          !Number.isInteger(time.completed) || time.completed < time.created) deny("unfinished compaction", "RC_COMPACTION");
      // Validate every part, including those after the first usable text.
      const usable = parsed.map(summaryPart);
      if (!usable.some(Boolean)) deny("missing summary text", "RC_COMPACTION");
    } else {
      verifyIdentity(info, target, profile);
      if (info.role === "user") userEvidence = true;
      else assistantEvidence = true;
    }
  }
  if (!userEvidence || !assistantEvidence) deny("missing ordinary evidence", "RC_EVIDENCE");
}

async function validateTask(client: CouncilClient, input: ToolInput, args: Record<string, unknown>, runtime: CouncilRuntime, profile: CouncilProfile) {
  if (Object.keys(args).some(key => !taskKeys.has(key))) deny("unexpected task field (no category/command/model overrides)");
  const target = args.subagent_type;
  if (typeof target !== "string" || !profile.researchers.has(target)) deny("task target must be an explicit council researcher");
  if (args.run_in_background !== false || !Array.isArray(args.load_skills) || args.load_skills.length !== 0 ||
      !text(args.prompt) || !text(args.description)) deny("task requires sync mode, empty load_skills, description and prompt");
  if (hasOwn(args, "task_id") && hasOwn(args, "session_id")) deny("conflicting continuation fields");
  const registered = list(data(await client.app.agents())).map(value => record(value, "RC_UNAVAILABLE")).filter(agent => agent.name === target);
  if (registered.length !== 1 || registered[0].mode !== "subagent") deny("researcher registration missing or ambiguous");
  const registeredModel = record(registered[0].model);
  if (`${registeredModel.providerID}/${registeredModel.modelID}` !== profile.models[target]) deny("registered researcher model changed");
  const continuation = hasOwn(args, "task_id") ? args.task_id : args.session_id;
  if (hasOwn(args, "task_id") || hasOwn(args, "session_id")) {
    if (!runtime.continuationField || !hasOwn(args, runtime.continuationField))
      deny("continuation field does not match the observed task schema");
    if (typeof continuation !== "string" || !/^ses_[A-Za-z0-9]+$/.test(continuation)) deny("invalid continuation session ID");
    const session = record(data(await client.session.get({ path: { id: continuation } })), "RC_UNAVAILABLE");
    if (session.id !== continuation || session.parentID !== input.sessionID || continuation === input.sessionID)
      deny("continuation must belong to this moderator session");
    const history = await messages(client, continuation);
    validateHistory(history, continuation, target, profile);
  }
}

function sensitive(path: string): boolean {
  return path.replace(/\\/g, "/").split("/").some(part =>
    /^(\.env(?:\..*)?|auth(?:\..*)?|credentials?(?:\..*)?|secrets?(?:\..*)?|\.ssh|\.aws|\.gnupg|id_rsa|id_ed25519)$/i.test(part) ||
    /\.(key|pem|p12|pfx|keystore)$/i.test(part));
}
function filesystemCode(error: unknown): string | undefined {
  return error !== null && typeof error === "object" && "code" in error && typeof error.code === "string"
    ? error.code : undefined;
}
async function validateRead(args: Record<string, unknown>, directory: string) {
  if (!text(args.filePath)) deny("read requires filePath");
  const path = resolve(directory, args.filePath);
  if (sensitive(path)) deny("sensitive file read denied");
  // Resolve symlinks before allowing read. A missing ordinary path has no content
  // and no symlink target; the native read tool reports that absence. Do not turn
  // ENOENT/ENOTDIR into an attribution or SDK failure.
  let resolved: string;
  try {
    resolved = await realpath(path);
  } catch (error) {
    const code = filesystemCode(error);
    if (code === "ENOENT" || code === "ENOTDIR") return;
    if (code === "EACCES" || code === "EPERM" || code === "ELOOP" || code === "ENAMETOOLONG")
      deny("unresolvable read path");
    throw error;
  }
  if (sensitive(resolved)) deny("sensitive symlink target denied");
}

async function validateDocumentPath(value: unknown, root: string, profile: CouncilProfile): Promise<string> {
  if (!text(value) || /[\x00-\x1f\x7f\\%:]/.test(value)) deny("ambiguous document path");
  const parts = (isAbsolute(value) ? value.slice(1) : value).split("/");
  if (parts.some(part => !part || part !== part.trim() || part === "." || part === "..")) deny("ambiguous document path");
  const path = resolve(root, value);
  const local = relative(root, path);
  const underRoot = profile.documentRoots.some(base => local.startsWith(`${base}/`));
  const namedReport = (profile.reportSuffixes ?? []).some(suffix => local.toLowerCase().endsWith(suffix.toLowerCase()));
  if ((!underRoot && !namedReport) || !local.endsWith(".md")) deny("outside document roots");
  const segments = local.split("/");
  if (sensitive(local) || segments.some(part => part.startsWith(".") || /^(AGENTS|CLAUDE|SKILL)\.md$/i.test(part)))
    deny("sensitive or instruction document");
  let current = root;
  for (let index = 0; index < segments.length; index++) {
    current = resolve(current, segments[index]);
    try {
      const stat = await lstat(current);
      if (stat.isSymbolicLink()) deny("symlink document path");
      if (index === segments.length - 1) {
        if (!stat.isFile() || stat.nlink !== 1) deny("document target must be a singly linked regular file");
      } else if (!stat.isDirectory()) deny("document ancestor must be a directory");
    } catch (error) {
      if (!(error instanceof Error) || !("code" in error) || error.code !== "ENOENT") throw error;
      // Missing nested directories are permitted, but this precheck never creates them.
      break;
    }
  }
  return path;
}

function patchDestinations(value: unknown): string[] {
  if (!text(value) || value.includes("\r")) deny("invalid patch text");
  const lines = value.split("\n");
  if (lines.at(-1) === "") lines.pop();
  if (lines[0] !== "*** Begin Patch" || lines.at(-1) !== "*** End Patch") deny("invalid patch envelope");
  // Native v1.18.31 selects the first trimmed end marker, even inside update context.
  if (lines.slice(1, -1).some(line => line.trim() === "*** End Patch")) deny("interior patch terminator");
  const paths: string[] = [];
  let index = 1;
  while (index < lines.length - 1) {
    const header = /^\*\*\* (Add|Update) File: (.+)$/.exec(lines[index++]);
    if (!header) deny("only add/update file sections are permitted");
    paths.push(header[2]);
    if (header[1] === "Add") {
      while (index < lines.length - 1 && lines[index].startsWith("+")) index++;
    } else {
      let hunks = 0;
      while (index < lines.length - 1 && (lines[index] === "@@" || lines[index].startsWith("@@ "))) {
        index++;
        hunks++;
        let changed = false;
        while (index < lines.length - 1 && /^[ +\-]/.test(lines[index])) {
          if (/^[+\-]/.test(lines[index])) changed = true;
          index++;
        }
        if (!changed) deny("empty or unchanged patch hunk");
        if (lines[index] === "*** End of File") { index++; break; }
      }
      if (!hunks) deny("update requires a hunk");
    }
    // Every unprefixed line must be the next section or the final envelope marker.
    // Prefixed Markdown that resembles patch directives remains ordinary content.
  }
  if (!paths.length) deny("empty patch");
  return paths;
}

async function validateMutation(tool: string, args: Record<string, unknown>, directory: string, profile: CouncilProfile) {
  const keys = tool === "apply_patch" ? ["patchText"] : tool === "write"
    ? ["filePath", "content"] : ["filePath", "oldString", "newString", "replaceAll"];
  if (Object.keys(args).some(key => !keys.includes(key))) deny("unexpected mutation field");
  if (tool === "write" && typeof args.content !== "string") deny("write requires content");
  if (tool === "edit" && (typeof args.oldString !== "string" || typeof args.newString !== "string" ||
      (hasOwn(args, "replaceAll") && typeof args.replaceAll !== "boolean"))) deny("invalid edit arguments");
  const paths = tool === "apply_patch" ? patchDestinations(args.patchText) : [args.filePath];
  const root = await realpath(directory);
  const destinations = new Set<string>();
  for (const path of paths) {
    const destination = await validateDocumentPath(path, root, profile);
    // Conservative case folding also prevents aliases on case-insensitive filesystems.
    const key = destination.normalize("NFC").toLowerCase();
    if (destinations.has(key)) deny("duplicate patch destination");
    destinations.add(key);
  }
}

export function createCouncilGuard(client: CouncilClient, directory: string, runtime: CouncilRuntime = {}, profile: CouncilProfile = researchProfile) {
  return async (input: ToolInput, output: { args: unknown }): Promise<void> => {
    try {
      const agent = await caller(client, input, profile);
      if (!hasOwn(profile.models, agent)) return;
      const args = record(output.args);
      if (input.tool === "task" && agent === profile.moderator) await validateTask(client, input, args, runtime, profile);
      else if (input.tool === "question" && agent === profile.moderator) { /* Human checkpoint only. */ }
      else if (input.tool === "write" || input.tool === "edit" || input.tool === "apply_patch")
        await validateMutation(input.tool, args, directory, profile);
      else if (!profile.tools.has(input.tool)) deny("tool is not allowed");
      if (input.tool === "read") await validateRead(args, directory);
      if (Array.isArray(args.load_skills)) Object.freeze(args.load_skills);
      Object.freeze(args);
      // Prevent a later hook from replacing the validated argument object.
      Object.defineProperty(output, "args", { value: args, writable: false, configurable: false, enumerable: true });
    } catch (error) {
      // Never leak SDK errors (which can contain URLs or credentials) into model context.
      const code = CouncilError.code(error);
      throw new Error(`${profile.label}: [${code}] ${diagnostics[code]}; report the failure, do not bypass it`);
    }
  };
}
