import assert from "node:assert/strict";
import { link, mkdir, mkdtemp, readFile, realpath, rm, symlink, writeFile } from "node:fs/promises";
import { createServer } from "node:net";
import { tmpdir } from "node:os";
import { join, relative } from "node:path";
import { parse } from "yaml";
import researchCouncil from "../plugins/research-council";
import reviewCouncil from "../plugins/review-council";

// Bun's node:test-compatible registration surface; no Bun type package is installed.
const { describe, test }: Pick<typeof import("node:test"), "describe" | "test"> = require("bun:test");

const root = new URL("../../", import.meta.url).pathname;
const models = {
  council: "openai/gpt-6-astra",
  "council-astra": "openai/gpt-6-astra",
  "council-grok": "xai/grok-4.7",
  "council-minimax": "minimax/MiniMax-M3",
  "council-kimi": "kimi-code-plan-global/k3",
};
const researchers = ["council-astra", "council-grok", "council-minimax", "council-kimi"];
const documentRoots = ["docs/research", "docs/plans", "docs/strategies", "research", "plans"];
const allowed = ["read", "glob", "grep", "webfetch", "websearch",
  "context7_resolve-library-id", "context7_query-docs", "websearch_web_search_exa"];

// No importable native matcher in repository dependencies. Match v1.18.31, not glob semantics:
// https://github.com/anomalyco/opencode/blob/v1.18.31/packages/opencode/src/util/wildcard.ts
function nativeMatch(input: string, pattern: string): boolean {
  const normalized = input.replace(/\\/g, "/");
  let escaped = pattern.replace(/\\/g, "/").replace(/[.+^${}()|[\]\\]/g, "\\$&")
    .replace(/\*/g, ".*").replace(/\?/g, ".");
  if (escaped.endsWith(" .*")) escaped = escaped.slice(0, -3) + "( .*)?";
  return new RegExp(`^${escaped}$`, process.platform === "win32" ? "si" : "s").test(normalized);
}
function nativeEditPermission(input: string, patterns: Record<string, string>): string {
  let result = "deny";
  for (const [pattern, action] of Object.entries(patterns)) if (nativeMatch(input, pattern)) result = action;
  return result;
}

function message(agent = "council", tool = "task", callID = "call_1", parentID = "user_1") {
  const [providerID, modelID] = (models[agent as keyof typeof models] ?? "openai/gpt-6-astra").split("/");
  return { info: { id: "assistant_1", sessionID: "ses_parent", role: "assistant", agent, parentID,
    providerID, modelID }, parts: [{ type: "tool", callID, tool, state: { status: "running" } }] };
}
function user(agent = "council", id = "user_1") {
  const [providerID, modelID] = (models[agent as keyof typeof models] ?? "openai/gpt-6-astra").split("/");
  return { info: { id, sessionID: "ses_parent", role: "user", agent, model: { providerID, modelID } }, parts: [] };
}
function fixture(agent = "council", tool = "task") {
  const state = {
    messages: [user(agent), message(agent, tool)],
    childMessages: [user("council-grok"), message("council-grok")].map(m => ({
      ...m, info: { ...m.info, sessionID: "ses_child" },
    })),
    parentID: "ses_parent", fail: false, childFail: false,
    agents: Object.entries(models).map(([name, model]) => {
      const [providerID, modelID] = model.split("/");
      return { name, mode: name === "council" ? "primary" : "subagent", model: { providerID, modelID } };
    }),
  };
  const client = {
    session: {
      messages: async ({ path }: { path: { id: string } }): Promise<unknown> => {
        if (state.fail) throw new Error("SDK unavailable");
        if (path.id !== "ses_parent" && state.childFail) throw new Error("Child SDK unavailable");
        return { data: path.id === "ses_parent" ? state.messages : state.childMessages };
      },
      get: async () => ({ data: { id: "ses_child", parentID: state.parentID } }),
    },
    app: { agents: async () => ({ data: state.agents }) },
  };
  return { state, client, input: { tool, sessionID: "ses_parent", callID: "call_1" } };
}
const taskArgs = () => ({ description: "Independent research", prompt: "Investigate the question",
  subagent_type: "council-grok", load_skills: [], run_in_background: false });

type HistoryMessage = { info: Record<string, unknown>; parts: Record<string, unknown>[] };
function compactedHistory(target: string): HistoryMessage[] {
  const sessionID = "ses_child";
  const ordinary = [user(target), message(target)].map(m => ({ ...m, info: { ...m.info, sessionID } }));
  const marker = { info: { ...user(target, "msg_marker").info, sessionID }, parts: [
    { id: "prt_marker", messageID: "msg_marker", sessionID, type: "compaction", auto: true },
  ] };
  const summary = { info: { ...message(target).info, id: "msg_summary", sessionID,
    parentID: "msg_marker", agent: "compaction", mode: "compaction", summary: true,
    time: { created: 10, completed: 20 }, finish: "stop" }, parts: [
    { id: "prt_summary", messageID: "msg_summary", sessionID, type: "text", text: "Persisted research findings." },
  ] };
  return [...ordinary, marker, summary];
}

describe("compacted continuation histories (offline)", () => {
  async function resume(history: HistoryMessage[], target = "council-grok", field = "session_id") {
    const f = fixture();
    f.client.session.messages = async ({ path }) => ({ data: path.id === "ses_parent" ? f.state.messages : history });
    const args = { ...taskArgs(), subagent_type: target, [field]: "ses_child" };
    await (await hook(f, field))(args);
    assert.ok(Object.isFrozen(args));
    assert.ok(Object.isFrozen(args.load_skills));
  }
  const part = (fields: Record<string, unknown>) => ({ id: "prt_extra", sessionID: "ses_child", messageID: "msg_summary", ...fields });
  const tokens = () => ({ input: 1, output: 2, reasoning: 3, cache: { read: 0, write: 0 } });
  for (const field of ["task_id", "session_id"]) for (const target of researchers) {
    test(`accepts completed same-pin compaction for ${target} via ${field}`, async () => {
      await resume(compactedHistory(target), target, field);
    });
    test(`accepts framework summary parts and repeated compaction for ${target} via ${field}`, async () => {
      const history = compactedHistory(target);
      Object.assign(history[2].parts[0], { auto: false, overflow: true, tail_start_id: "msg_tail" });
      history[3].parts.push(...[
        { type: "reasoning", text: "", time: { start: 10, end: 11 }, metadata: {} },
        { type: "step-start", snapshot: "snapshot" },
        { type: "step-finish", reason: "stop", cost: 0, tokens: { ...tokens(), total: 6 } },
        { type: "patch", hash: "hash", files: ["docs/research/report.md"] },
        { type: "text", text: "", synthetic: true, ignored: false, time: { start: 12 }, metadata: {} },
      ].map((fields, index) => part({ ...fields, id: `prt_extra${index}` })));
      const second = compactedHistory(target).slice(2);
      second[0].info.id = "msg_marker2";
      Object.assign(second[0].parts[0], { id: "prt_marker2", messageID: "msg_marker2" });
      Object.assign(second[1].info, { id: "msg_summary2", parentID: "msg_marker2" });
      Object.assign(second[1].parts[0], { id: "prt_summary2", messageID: "msg_summary2" });
      await resume([...history, ...second], target, field);
    });
  }
  const mutations: Record<string, (history: HistoryMessage[]) => void> = {
    "duplicate message ID": h => { h[3].info.id = h[0].info.id; },
    "empty message ID": h => { h[0].info.id = " "; },
    "missing message ID": h => { delete h[1].info.id; },
    "unsupported role": h => { h[0].info.role = "system"; },
    "foreign session": h => { h[1].info.sessionID = "ses_other"; },
    "no ordinary user": h => { h.splice(0, 1); },
    "no ordinary assistant": h => { h.splice(1, 1); },
    "compaction only": h => { h.splice(0, 2); },
    "ordinary user switches agent": h => { h[0].info.agent = "build"; },
    "ordinary user switches model": h => { h[0].info.model = { providerID: "other", modelID: "other" }; },
    "ordinary assistant switches agent": h => { h[1].info.agent = "build"; },
    "ordinary assistant switches model": h => { h[1].info.modelID = "other"; },
    "marker switches agent": h => { h[2].info.agent = "build"; },
    "marker switches model": h => { h[2].info.model = { providerID: "other", modelID: "other" }; },
    "marker wrong role": h => { h[2].info.role = "assistant"; },
    "marker missing auto": h => { delete h[2].parts[0].auto; },
    "marker nonboolean auto": h => { h[2].parts[0].auto = "true"; },
    "marker nonboolean overflow": h => { h[2].parts[0].overflow = 1; },
    "marker invalid tail": h => { h[2].parts[0].tail_start_id = "ses_other"; },
    "marker empty tail": h => { h[2].parts[0].tail_start_id = ""; },
    "marker duplicate parts": h => { h[2].parts.push({ ...h[2].parts[0], id: "prt_marker2" }); },
    "marker mixed parts": h => { h[2].parts.push(part({ messageID: "msg_marker", type: "text", text: "extra" })); },
    "marker foreign ownership": h => { h[2].parts[0].messageID = "msg_other"; },
    "marker foreign session": h => { h[2].parts[0].sessionID = "ses_other"; },
    "marker missing part ID": h => { delete h[2].parts[0].id; },
    "unreferenced malformed marker": h => { h.pop(); h[2].parts[0].auto = 1; },
    "summary missing agent": h => { delete h[3].info.agent; },
    "summary researcher agent": h => { h[3].info.agent = "council-grok"; },
    "summary missing mode": h => { delete h[3].info.mode; },
    "summary wrong mode": h => { h[3].info.mode = "council-grok"; },
    "summary missing flag": h => { delete h[3].info.summary; },
    "summary false flag": h => { h[3].info.summary = false; },
    "summary string flag": h => { h[3].info.summary = "true"; },
    "summary switched model": h => { h[3].info.modelID = "other"; },
    "summary switched provider": h => { h[3].info.providerID = "other"; },
    "summary unknown parent": h => { h[3].info.parentID = "msg_unknown"; },
    "summary ordinary user parent": h => { h[3].info.parentID = h[0].info.id; },
    "summary assistant parent": h => { h[3].info.parentID = h[1].info.id; },
    "summary self parent": h => { h[3].info.parentID = h[3].info.id; },
    "summary before marker": h => { [h[2], h[3]] = [h[3], h[2]]; },
    "summary missing time": h => { delete h[3].info.time; },
    "summary unfinished": h => { h[3].info.time = { created: 10 }; },
    "summary invalid time": h => { h[3].info.time = { created: 10, completed: NaN }; },
    "summary negative time": h => { h[3].info.time = { created: -1, completed: 20 }; },
    "summary reversed time": h => { h[3].info.time = { created: 20, completed: 10 }; },
    "summary fractional time": h => { h[3].info.time = { created: 10, completed: 20.5 }; },
    "summary missing finish": h => { delete h[3].info.finish; },
    "summary length finish": h => { h[3].info.finish = "length"; },
    "summary tool finish": h => { h[3].info.finish = "tool-calls"; },
    "summary error": h => { h[3].info.error = { message: "failed" }; },
    "summary null error": h => { h[3].info.error = null; },
    "summary empty parts": h => { h[3].parts = []; },
    "summary whitespace text": h => { h[3].parts[0].text = " \n"; },
    "summary ignored text": h => { h[3].parts[0].ignored = true; },
    "summary nonstring text": h => { h[3].parts[0].text = 7; },
    "summary foreign part session": h => { h[3].parts[0].sessionID = "ses_other"; },
    "summary foreign part message": h => { h[3].parts[0].messageID = "msg_other"; },
    "summary blank part ID": h => { h[3].parts[0].id = ""; },
    "summary duplicate part ID": h => { h[3].parts.push({ ...h[3].parts[0] }); },
    "summary marker part ID collision": h => { h[3].parts[0].id = h[2].parts[0].id; },
    "summary ordinary part ID collision": h => { h[1].parts[0].id = h[3].parts[0].id; },
    "later ordinary part ID collision": h => { h.push({ info: { ...h[1].info, id: "msg_later" }, parts: [{ ...h[1].parts[0], id: h[3].parts[0].id }] }); },
    "ordinary assistant summary flag alone": h => { h[1].info.summary = true; h.splice(2); },
    "ordinary assistant malformed summary flag": h => { h[1].info.summary = "false"; h.splice(2); },
    "ordinary assistant compaction mode alone": h => { h[1].info.mode = "compaction"; h.splice(2); },
    "ordinary user boolean summary": h => { h[0].info.summary = true; h.splice(2); },
    "ordinary user string summary": h => { h[0].info.summary = "true"; h.splice(2); },
    "ordinary user null summary": h => { h[0].info.summary = null; h.splice(2); },
  };
  for (const field of ["task_id", "session_id"]) for (const [name, mutate] of Object.entries(mutations)) {
    test(`rejects ${name} via ${field}`, async () => {
      const history = compactedHistory("council-grok");
      mutate(history);
      await assert.rejects(resume(history, "council-grok", field), /Research council: \[RC_/);
    });
  }
  for (const payload of [
    { type: "tool", callID: "call", tool: "read", state: { status: "completed" } },
    ...["file", "agent", "subtask", "snapshot", "retry", "unknown", "compaction"].map(type => ({ type })),
    { type: "reasoning", text: "no time" }, { type: "reasoning", text: 1, time: { start: 1 } },
    { type: "text", text: "ok", time: { start: 2, end: 1 } },
    { type: "text", text: "ok", ignored: "false" }, { type: "text", text: "ok", synthetic: 1 },
    { type: "text", text: "ok", metadata: [] }, { type: "text", text: "ok", time: null },
    { type: "step-start", snapshot: 1 }, { type: "step-finish", reason: "stop" },
    { type: "step-finish", reason: 1, cost: 0, tokens: tokens() },
    { type: "step-finish", reason: "stop", cost: Infinity, tokens: tokens() },
    { type: "step-finish", reason: "stop", cost: 0, tokens: { ...tokens(), total: "1" } },
    { type: "step-finish", reason: "stop", cost: 0, tokens: { ...tokens(), cache: { read: 0 } } },
    { type: "patch", hash: 1, files: [] }, { type: "patch", hash: "hash", files: [1] },
    { type: "patch", hash: "hash", files: "file" },
  ]) test(`rejects forbidden/malformed part after usable summary: ${JSON.stringify(payload)}`, async () => {
    const history = compactedHistory("council-grok");
    history[3].parts.push(part(payload));
    await assert.rejects(resume(history));
  });
  test("ordinary user diff summary and assistant false flag are not compaction", async () => {
    const history = compactedHistory("council-grok").slice(0, 2);
    history[0].info.summary = { title: "Changes", diffs: [] };
    history[1].info.summary = false;
    await resume(history);
  });
  test("reasoning cannot substitute for usable summary text", async () => {
    const history = compactedHistory("council-grok");
    history[3].parts = [part({ type: "reasoning", text: "Findings", time: { start: 10, end: 20 } })];
    await assert.rejects(resume(history), /\[RC_COMPACTION\]/);
  });
  test("history exception does not authorize an active compaction caller", async () => {
    const f = fixture("council-grok", "read");
    f.state.messages[1].info.agent = "compaction";
    await assert.rejects((await hook(f))({ filePath: `${root}CLAUDE.md` }));
  });
  for (const field of ["task_id", "session_id"]) for (const restriction of ["owner", "schema", "registration", "background", "skills"]) {
    test(`compacted history retains ${restriction} restriction via ${field}`, async () => {
      const f = fixture();
      const history = compactedHistory("council-grok");
      f.client.session.messages = async ({ path }) => ({ data: path.id === "ses_parent" ? f.state.messages : history });
      const args = { ...taskArgs(), [field]: "ses_child" };
      if (restriction === "owner") f.state.parentID = "ses_other";
      if (restriction === "registration") {
        const registered = f.state.agents.find(agent => agent.name === "council-grok");
        assert.ok(registered);
        registered.model.modelID = "other";
      }
      if (restriction === "background") args.run_in_background = true;
      if (restriction === "skills") Object.assign(args, { load_skills: ["forbidden"] });
      const observed = restriction === "schema" ? field === "task_id" ? "session_id" : "task_id" : field;
      await assert.rejects((await hook(f, observed))(args), /\[RC_POLICY\]/);
      assert.equal(Object.isFrozen(args), false);
    });
  }
  for (const id of [null, 42, "prt_", "prt_bad-id", "prt_bad\n", " prt_bad"]) {
    test(`rejects malformed compaction part ID ${JSON.stringify(id)}`, async () => {
      for (const index of [2, 3]) {
        const history = compactedHistory("council-grok");
        history[index].parts[0].id = id;
        await assert.rejects(resume(history));
      }
    });
  }
  for (const value of [-1, NaN, Infinity, "0"]) {
    test(`rejects invalid summary numeric boundary ${String(value)}`, async () => {
      for (const field of ["cost", "input", "output", "reasoning", "read", "write", "total"]) {
        const history = compactedHistory("council-grok");
        const usage = { ...tokens(), total: 0 };
        if (field === "read" || field === "write") Object.assign(usage.cache, { [field]: value });
        else if (field !== "cost") Object.assign(usage, { [field]: value });
        history[3].parts.push(part({ type: "step-finish", reason: "stop", cost: field === "cost" ? value : 0, tokens: usage }));
        await assert.rejects(resume(history), /\[RC_COMPACTION\]/);
      }
    });
  }
  test("zero lifecycle timestamps and usage remain valid", async () => {
    const history = compactedHistory("council-grok");
    history[3].info.time = { created: 0, completed: 0 };
    history[3].parts[0].time = { start: 0, end: 0 };
    history[3].parts.push(part({ type: "step-finish", reason: "stop", cost: 0,
      tokens: { input: 0, output: 0, reasoning: 0, total: 0, cache: { read: 0, write: 0 } } }));
    await resume(history);
  });
  for (const [name, mutate, code, detail] of [
    ["missing summary time", (h: HistoryMessage[]) => { delete h[3].info.time; }, "RC_COMPACTION", "invalid historical compaction"],
    ["malformed part time", (h: HistoryMessage[]) => { h[3].parts[0].time = []; }, "RC_COMPACTION", "invalid historical compaction"],
    ["malformed metadata", (h: HistoryMessage[]) => { h[3].parts[0].metadata = null; }, "RC_COMPACTION", "invalid historical compaction"],
    ["missing tokens", (h: HistoryMessage[]) => { h[3].parts.push(part({ type: "step-finish" })); }, "RC_COMPACTION", "invalid historical compaction"],
    ["malformed cache", (h: HistoryMessage[]) => { h[3].parts.push(part({ type: "step-finish", tokens: { cache: [] } })); }, "RC_COMPACTION", "invalid historical compaction"],
    ["duplicate history ID", (h: HistoryMessage[]) => { h[1].info.id = h[0].info.id; }, "RC_HISTORY", "invalid continuation history"],
    ["nonstring history ID", (h: HistoryMessage[]) => { h[0].info.id = 1; }, "RC_HISTORY", "invalid continuation history"],
    ["missing ordinary assistant", (h: HistoryMessage[]) => { h.splice(1, 1); }, "RC_EVIDENCE", "continuation lacks ordinary researcher evidence"],
  ] as const) test(`exact diagnostic for ${name}`, async () => {
    const history = compactedHistory("council-grok");
    mutate(history);
    await assert.rejects(resume(history), { message: `Research council: [${code}] ${detail}; report the failure, do not bypass it` });
  });
});

describe("fixed diagnostic boundary", () => {
  const unavailable = "Research council: [RC_UNAVAILABLE] attribution or metadata unavailable; report the failure, do not bypass it";
  for (const foreign of [
    new Error("https://secret.example/?token=SECRET"),
    Object.assign(new Error("injected"), { code: "RC_COMPACTION", stack: "SECRET stack" }),
    { code: "RC_IDENTITY", message: "SECRET", name: "CouncilError" },
    "SECRET", null,
    new Proxy({}, { get() { throw new Error("SECRET getter"); } }),
    new Proxy({}, { getPrototypeOf() { throw new Error("SECRET prototype"); } }),
  ]) test(`foreign error ${typeof foreign} cannot supply diagnostic text or code`, async () => {
    const f = fixture();
    f.client.session.messages = async () => { throw foreign; };
    await assert.rejects((await hook(f))(taskArgs()), { message: unavailable });
  });
  test("SDK response errors are not forwarded", async () => {
    const f = fixture();
    f.client.session.messages = async () => ({ error: { code: "RC_HISTORY", message: "SECRET URL" } });
    await assert.rejects((await hook(f))(taskArgs()), { message: unavailable });
  });
  for (const source of ["caller", "child", "agents", "session"]) {
    for (const response of [null, {}, { error: { message: "SECRET", code: "RC_POLICY" }, data: [] }, { data: null }]) {
      test(`${source} malformed SDK response ${JSON.stringify(response)} is unavailable`, async () => {
        const f = fixture();
        const hooks = await researchCouncil({ directory: root, client: {
          session: {
            messages: async ({ path }) => (source === "caller" && path.id === "ses_parent") ||
              (source === "child" && path.id === "ses_child") ? response : f.client.session.messages({ path }),
            get: async () => source === "session" ? response : f.client.session.get(),
          },
          app: { agents: async () => source === "agents" ? response : f.client.app.agents() },
        } });
        await hooks["tool.definition"]({ toolID: "task" }, { jsonSchema: { properties: {
          run_in_background: {}, load_skills: {}, session_id: {},
        } } });
        await assert.rejects(hooks["tool.execute.before"](f.input, { args: { ...taskArgs(), session_id: "ses_child" } }), { message: unavailable });
      });
    }
  }
  for (const reason of ["missing", "duplicate", "stale", "missing-ID", "completed", "wrong-tool", "malformed-state"]) {
    test(`active call ${reason} has attribution diagnostic`, async () => {
      const f = fixture();
      if (reason === "missing") f.input.callID = "call_missing";
      if (reason === "duplicate") f.state.messages.push(message());
      if (reason === "stale") f.state.messages.push(user("council", "user_later"));
      if (reason === "missing-ID") f.input.callID = "";
      if (reason === "completed") Object.assign(f.state.messages[1].parts[0], { state: { status: "completed" } });
      if (reason === "wrong-tool") f.input.tool = "read";
      if (reason === "malformed-state") Object.assign(f.state.messages[1].parts[0], { state: null });
      await assert.rejects((await hook(f))(taskArgs()), {
        message: "Research council: [RC_ATTRIBUTION] active call attribution failed; report the failure, do not bypass it",
      });
    });
  }
  for (const entry of [null, { info: null, parts: [] }, { info: {}, parts: null },
    { info: { ...user("council-grok").info, sessionID: "ses_child" }, parts: [null] }]) {
    test(`malformed child message ${JSON.stringify(entry)} has history diagnostic`, async () => {
      const f = fixture();
      f.client.session.messages = async ({ path }) => ({ data: path.id === "ses_parent" ? f.state.messages : [entry] });
      await assert.rejects((await hook(f))({ ...taskArgs(), session_id: "ses_child" }), {
        message: "Research council: [RC_HISTORY] invalid continuation history; report the failure, do not bypass it",
      });
    });
  }
  test("public guard errors cannot be replayed as private diagnostic errors", async () => {
    const f = fixture();
    let prior: unknown;
    try { await (await hook(f))({ ...taskArgs(), category: "forbidden" }); } catch (error) { prior = error; }
    assert.ok(prior instanceof Error);
    assert.match(prior.message, /\[RC_POLICY\]/);
    f.client.session.messages = async () => { throw prior; };
    await assert.rejects((await hook(f))(taskArgs()), { message: unavailable });
  });
  test("untrusted tool names never enter fixed policy diagnostics", async () => {
    await assert.rejects((await hook(fixture("council", "https://SECRET.example")))({}), {
      message: "Research council: [RC_POLICY] tool policy validation failed; report the failure, do not bypass it",
    });
  });
  test("identity failures have a fixed code without reflected metadata", async () => {
    const f = fixture("council", "websearch");
    Object.assign(f.state.messages[1].info, { modelID: "SECRET" });
    await assert.rejects((await hook(f))({}), {
      message: "Research council: [RC_IDENTITY] agent/model identity mismatch; report the failure, do not bypass it",
    });
  });
});

async function hook(f: ReturnType<typeof fixture>, field = "session_id") {
  const hooks = await researchCouncil({ client: f.client, directory: root });
  await hooks["tool.definition"]({ toolID: "task" }, { jsonSchema: { properties: {
    run_in_background: {}, load_skills: {}, subagent_type: {}, [field]: {},
  } } });
  return (args: unknown) => hooks["tool.execute.before"](f.input, { args });
}

describe("agent and command definitions", () => {
  for (const [name, model] of Object.entries(models)) {
    test(`${name} pins model and default-denies permissions`, async () => {
      const text = await readFile(`${root}.opencode/agents/${name}.md`, "utf8");
      const config = parse(text.split("---")[1]);
      assert.equal(config.model, model);
      assert.equal(config.variant, name === "council-kimi" ? "high" : undefined);
      assert.equal(config.reasoningEffort, undefined);
      assert.equal(config.mode, name === "council" ? "primary" : "subagent");
      assert.equal(config.permission["*"], "deny");
      for (const tool of allowed.filter(t => t !== "read")) assert.equal(config.permission[tool], "allow");
      assert.equal(config.permission.read["*"], "allow");
      for (const pattern of ["**/.env", "**/.env.*", "**/auth.json", "**/*.key", "**/*.pem"])
        assert.equal(config.permission.read[pattern], "deny");
      assert.equal(config.permission.research_json_read, "allow");
      assert.match(text, /The approved structured-data reader may decode and paginate authorized research artifacts/);
      assert.match(text, /peer findings must not be registered as public-source artifacts/);
      assert.deepEqual(Object.keys(config.permission).sort(), [
        "*", ...allowed, "edit", "research_json_read", ...(name === "council" ? ["question", "task"] : []),
      ].sort());
      if (name === "council") assert.deepEqual(config.permission.task, { "*": "deny", "council-astra": "allow", "council-grok": "allow", "council-minimax": "allow", "council-kimi": "allow" });
      assert.ok(text.includes("CLAUDE.md"));
      assert.ok(text.includes("Context7"));
      assert.equal(Object.keys(config.permission.edit)[0], "*");
      assert.equal(config.permission.edit["*"], "deny");
      assert.deepEqual(Object.entries(config.permission.edit).filter(([, value]) => value === "allow").map(([key]) => key),
        documentRoots.flatMap(path => [`${path}/*`, `${path}/**`]));
      for (const pattern of ["**/AGENTS.md", "**/CLAUDE.md", "**/SKILL.md", "**/.*/**", "**/credentials*", "**/secrets*"])
        assert.equal(config.permission.edit[pattern], "deny");
      assert.ok(Object.keys(config.permission.edit).indexOf("**/AGENTS.md") > Object.keys(config.permission.edit).indexOf("plans/**"));
      assert.match(text, /research reports, PRDs and implementation plans/);
      assert.match(text, /no peer artifact reading during independent passes/i);
      assert.match(text, /Writing a plan never authorizes executing it/);
      for (const base of documentRoots) assert.ok(text.includes(`${base}/`));
      assert.match(text, /[Ff]inal\s+consolidation/);
      assert.match(text, /distinct\s+(?:assigned )?output/);
      assert.doesNotMatch(text, /no implementation, file saves|Never implement, edit\/save files/);
    });
    test(`${name} native edit permissions allow direct/nested documents and retain final denies`, async () => {
      const config = parse((await readFile(`${root}.opencode/agents/${name}.md`, "utf8")).split("---")[1]);
      assert.equal(nativeMatch("plans/report.md", "plans/**/*.md"), false);
      assert.equal(nativeMatch("plans/nested/report.md", "plans/**/*.md"), true);
      for (const base of documentRoots) {
        for (const suffix of ["report.md", "nested/report.md", "nested/deeper/report.md"]) {
          const path = `${base}/${suffix}`;
          assert.equal(nativeEditPermission(path, config.permission.edit), "allow", path);
          // Native tools check repository-relative permission paths, including for absolute inputs.
          assert.equal(nativeEditPermission(relative(root, join(root, path)), config.permission.edit), "allow", path);
        }
        for (const suffix of ["sketch.sol", "nested/sketch.ts", "config.json", "notes.py"]) {
          const path = `${base}/${suffix}`;
          assert.equal(nativeEditPermission(path, config.permission.edit), "allow", path);
        }
        for (const suffix of ["AGENTS.md", "CLAUDE.md", "SKILL.md", "credentials.md", "secrets.md", "auth.md", ".env.md",
          ".opencode/report.md", "nested/.github/report.md", "nested/AGENTS.md", "nested/secrets.md"]) {
          const path = `${base}/${suffix}`;
          assert.equal(nativeEditPermission(path, config.permission.edit), "deny", path);
        }
      }
      for (const path of ["report.md", "docs/agent/report.md", "plans-other/report.md", "contracts/vaults/Foo.sol", "code.ts"])
        assert.equal(nativeEditPermission(path, config.permission.edit), "deny", path);
      const entries = Object.entries(config.permission.edit);
      const lastAllow = entries.map(([, action]) => action).lastIndexOf("allow");
      assert.ok(entries.slice(lastAllow + 1).length > 0);
      assert.ok(entries.slice(lastAllow + 1).every(([, action]) => action === "deny"));
    });
  }
  test("command remains a primary-agent command with arguments", async () => {
    const text = await readFile(`${root}.opencode/commands/council.md`, "utf8");
    const config = parse(text.split("---")[1]);
    assert.equal(config.agent, "council");
    assert.equal(config.subtask, false);
    assert.ok(text.includes("$ARGUMENTS"));
    assert.match(text, /empty/i);
    assert.match(text, /follow-up/i);
    assert.match(text, /research reports, PRDs and implementation plans/);
    assert.doesNotMatch(text, /Do not implement or save files/);
    assert.match(text, /four independent first passes/);
    assert.match(text, /other three original answers together/);
    assert.match(text, /four initial calls plus four combined/);
    assert.match(text, /eight total/);
    assert.match(text, /missing or unresolvable ordinary read is not a participant/);
    assert.match(text, /genuine SDK RC_UNAVAILABLE/);
    assert.match(text, /All five agents/);
    assert.match(text, /Kimi K3/);
    assert.match(text, /Operator-authorized replacement/);
    assert.match(text, /do not resume the old session/i);
    assert.match(text, /continuation field/);
    assert.match(text, /Do not set a model override/);
    assert.match(text, /Markdown and code edits under/);
  });
  test("moderator requires four initial passes before four combined cross-reviews", async () => {
    const text = await readFile(`${root}.opencode/agents/council.md`, "utf8");
    for (const name of researchers) assert.ok(text.includes(name));
    assert.match(text, /FOUR independent first passes/);
    assert.match(text, /same question\/context/);
    assert.match(text, /no peer responses until all originals are collected/);
    assert.match(text, /FOUR combined cross-review continuations/);
    assert.match(text, /other THREE ORIGINAL first-pass answers together/);
    assert.match(text, /never earlier cross-review answers/);
    assert.match(text, /Eight total task calls/);
    assert.match(text, /four distinct researcher session IDs/);
    assert.match(text, /resuming its own original session/);
    assert.match(text, /explicitly requests a targeted/);
    assert.match(text, /Do not claim full-council consensus/);
    assert.match(text, /human decision checkpoint/);
    assert.match(text, /xai\/grok-4\.7/);
    assert.match(text, /native file-not-found on one read is not a participant failure/);
  });
  for (const name of researchers) test(`${name} reviews three original peers without cross-review leakage`, async () => {
    const text = await readFile(`${root}.opencode/agents/${name}.md`, "utf8");
    assert.match(text, /other THREE ORIGINAL first-pass answers together/);
    const labels: Record<string, string> = { "council-astra": "Astra", "council-grok": "Grok", "council-minimax": "MiniMax M3", "council-kimi": "Kimi K3" };
    const peers = researchers.filter(peer => peer !== name).map(peer => labels[peer]);
    assert.ok(text.includes(`(${peers.slice(0, -1).join(", ")} and ${peers.at(-1)})`));
    assert.match(text, /never earlier cross-review answers/);
  });
  test("active documentation describes five agents and eight calls", async () => {
    const text = await readFile(`${root}docs/agent/RESEARCH_COUNCIL.md`, "utf8");
    const active = text.split("## Runtime evidence and limits (2026-09-17)")[0];
    for (const name of researchers) assert.ok(active.includes(`\`${name}\``));
    assert.match(active, /kimi-code-plan-global\/k3/);
    assert.match(active, /variant: high/);
    assert.match(active, /eight total task calls: four initial calls and four cross-review resumes/);
    assert.match(active, /all five agents/);
    assert.match(active, /other three \*\*original first-pass answers together\*\*/);
    assert.match(await readFile(`${root}CLAUDE.md`, "utf8"), /Astra \/ Grok \/ MiniMax M3 \/ Kimi K3 research council/);
  });
  test("researcher permission maps are identical", async () => {
    const configs = await Promise.all(researchers.map(async name =>
      parse((await readFile(`${root}.opencode/agents/${name}.md`, "utf8")).split("---")[1])));
    for (const config of configs.slice(1)) assert.deepEqual(config.permission, configs[0].permission);
  });
});

describe("bounded document mutations (real filesystem, no provider)", () => {
  async function sandbox(run: (directory: string) => Promise<void>) {
    const directory = await realpath(await mkdtemp(join(tmpdir(), "council-docs-")));
    try {
      await mkdir(join(directory, "docs/research"), { recursive: true });
      await writeFile(join(directory, "docs/research/existing.md"), "old\n");
      await run(directory);
    } finally { await rm(directory, { recursive: true, force: true }); }
  }
  async function mutation(directory: string, agent: string, tool: string, args: unknown) {
    const f = fixture(agent, tool);
    const hooks = await researchCouncil({ client: f.client, directory });
    const output = { args };
    await hooks["tool.execute.before"](f.input, output);
    return output;
  }
  const patch = (body: string) => `*** Begin Patch\n${body}\n*** End Patch\n`;
  const argsFor = (tool: string, filePath: unknown) => tool === "apply_patch"
    ? { patchText: patch(`*** Add File: ${filePath}\n+# Report`) }
    : tool === "write" ? { filePath, content: "# Report" } : { filePath, oldString: "old", newString: "new" };

  for (const agent of Object.keys(models)) for (const tool of ["write", "edit", "apply_patch"]) {
    test(`${agent} permits bounded ${tool}, relative/absolute/new nested, and freezes arguments`, async () => sandbox(async directory => {
      for (const base of documentRoots) for (const filePath of [`${base}/new/nested/report.md`, `${base}/sketch.sol`, join(directory, base, "report.md"), "docs/research/existing.md"]) {
        const args = argsFor(tool, filePath);
        const output = await mutation(directory, agent, tool, args);
        assert.ok(Object.isFrozen(args));
        assert.throws(() => { output.args = {}; });
        assert.throws(() => { Object.assign(args, argsFor(tool, "code.ts")); });
      }
      await assert.rejects(readFile(join(directory, "docs/research/new/nested/report.md")), { code: "ENOENT" });
    }));
    test(`${agent} rejects unsafe ${tool} paths`, async () => sandbox(async directory => {
      for (const filePath of ["code.ts", "contracts/vaults/Foo.sol", "docs/agent/report.md",
        "docs/research/../plans/report.md", "../plans/report.md", "docs/researchish/report.md", `${directory}-sibling/plans/report.md`,
        "./plans/report.md", "plans//report.md", "plans/report.md/", "plans\\report.md", "plans/%2e%2e/report.md",
        "plans/report.md\n", "plans/report.md\0", "plans/ report.md", "plans/report.md ",
        "plans/AGENTS.md", "plans/claude.MD", "plans/skill.md", "plans/nested/AgEnTs.md",
        ...[".opencode", ".github", ".claude", ".agents", ".codex", ".grok", ".git", ".config"].map(dir => `plans/nested/${dir}/report.md`),
        "plans/credentials.md", "plans/secrets.md", "plans/auth.md", "plans/.env.md", "plans/private.key/report.md"]) {
        await assert.rejects(mutation(directory, agent, tool, argsFor(tool, filePath)), /Research council/);
      }
      for (const value of [undefined, null, 1, [], {}])
        await assert.rejects(mutation(directory, agent, tool, tool === "apply_patch" ? { patchText: value } : argsFor(tool, value)));
    }));
    test(`${agent} rejects ${tool} symlinks, dangling links, hardlinks, directories and ENOTDIR`, async () => sandbox(async directory => {
      const base = join(directory, "docs/research");
      await symlink(join(base, "existing.md"), join(base, "leaf.md"));
      await symlink(join(base, "missing.md"), join(base, "dangling.md"));
      await symlink(base, join(base, "internal"));
      await symlink(join(directory, "missing"), join(base, "dangling-dir"));
      await symlink(tmpdir(), join(base, "external"));
      await link(join(base, "existing.md"), join(base, "hard.md"));
      await mkdir(join(base, "directory.md"));
      for (const name of ["leaf.md", "dangling.md", "internal/report.md", "dangling-dir/report.md", "external/report.md", "hard.md", "existing.md", "directory.md", "existing.md/report.md"])
        await assert.rejects(mutation(directory, agent, tool, argsFor(tool, join(base, name))));
    }));
  }
  test("special file targets fail closed", async () => sandbox(async directory => {
    const socket = join(directory, "docs/research/socket.md");
    const server = createServer();
    await new Promise<void>((resolve, reject) => { server.once("error", reject); server.listen(socket, resolve); });
    try {
      for (const tool of ["write", "edit", "apply_patch"])
        await assert.rejects(mutation(directory, "council", tool, argsFor(tool, "docs/research/socket.md")));
    } finally { await new Promise<void>((resolve, reject) => server.close(error => error ? reject(error) : resolve())); }
  }));
  test("canonicalizes the trusted repository root", async () => sandbox(async directory => {
    const alias = join(directory, "repo-alias");
    await symlink(directory, alias);
    await mutation(alias, "council", "write", argsFor("write", "plans/report.md"));
    for (const tool of ["write", "edit", "apply_patch"])
      await assert.rejects(mutation(alias, "council", tool, argsFor(tool, join(alias, "plans/report.md"))));
  }));
  test("rejects symlinked allowlist roots and non-ENOENT filesystem failures", async () => sandbox(async directory => {
    await symlink(join(directory, "docs/research"), join(directory, "plans"));
    for (const tool of ["write", "edit", "apply_patch"]) {
      await assert.rejects(mutation(directory, "council", tool, argsFor(tool, "plans/report.md")));
      await assert.rejects(mutation(directory, "council", tool, argsFor(tool, `docs/research/${"x".repeat(300)}.md`)));
    }
  }));
  test("mutation arguments cannot supply their own roots, identity or alternative destination", async () => sandbox(async directory => {
    for (const tool of ["write", "edit", "apply_patch"]) for (const extra of [
      { allowedPaths: ["code.ts"] }, { directory: tmpdir() }, { agent: "build" }, { path: "code.ts" }, { moveTo: "plans/other.md" },
    ]) await assert.rejects(mutation(directory, "council", tool, { ...argsFor(tool, "plans/report.md"), ...extra }));
  }));
  for (const agent of Object.keys(models)) {
    test(`${agent} rejects invalid mutation argument types`, async () => sandbox(async directory => {
      for (const [tool, fields] of [["write", ["content"]], ["edit", ["oldString", "newString", "replaceAll"]]] as const) {
        for (const field of fields) for (const value of [undefined, null, 1, [], {}, ...(field === "replaceAll" ? ["false", ""] : [false])]) {
          await assert.rejects(mutation(directory, agent, tool, { ...argsFor(tool, "plans/report.md"), [field]: value }));
        }
      }
      await mutation(directory, agent, "write", { filePath: "plans/report.md", content: "" });
      for (const replaceAll of [false, true])
        await mutation(directory, agent, "edit", { filePath: "plans/report.md", oldString: "old", newString: "", replaceAll });
    }));
    test(`${agent} rejects a trimmed interior patch terminator before a second file`, async () => sandbox(async directory => {
      // Native parsePatch chooses the first trimmed marker, ignoring the second file:
      // https://github.com/anomalyco/opencode/blob/v1.18.31/packages/opencode/src/patch/index.ts
      for (const marker of [" *** End Patch", " *** End Patch  ", " \t*** End Patch\t", " \u00a0*** End Patch\u00a0"]) {
        const patchText = patch(`*** Update File: docs/research/existing.md\n@@\n-old\n+new\n${marker}\n*** Add File: plans/second.md\n+second`);
        assert.ok(patchText.split("\n").findIndex(line => line.trim() === "*** End Patch") < patchText.split("\n").findIndex(line => line === "*** Add File: plans/second.md"));
        await assert.rejects(mutation(directory, agent, "apply_patch", { patchText }));
      }
      await mutation(directory, agent, "apply_patch", { patchText: patch("*** Update File: docs/research/existing.md\n@@\n-old\n+*** End Patch\n*** Add File: plans/second.md\n+second") });
    }));
    test(`${agent} accepts complete multi-file patches and prefixed patch-looking Markdown`, async () => sandbox(async directory => {
      await mutation(directory, agent, "apply_patch", { patchText: patch("*** Add File: plans/new.md\n+*** Delete File: code.ts\n+*** End Patch\n+@@\n*** Update File: docs/research/existing.md\n@@\n-old\n+*** Move to: code.ts\n *** Begin Patch\n*** End of File") });
    }));
    test(`${agent} rejects malformed, mixed, destructive and duplicate patches atomically`, async () => sandbox(async directory => {
      const good = "*** Add File: plans/new.md\n+# Report";
      for (const patchText of ["", "*** Begin Patch\n*** End Patch", `prefix\n${patch(good)}`, `${patch(good)}trailing`, `${patch(good)}${patch(good)}`,
        patch(`${good}\n*** Delete File: plans/old.md`), patch("*** Update File: plans/old.md\n*** Move to: plans/new.md\n@@\n-old\n+new"),
        patch(`${good}\n*** Add File: code.ts\n+bad`), patch(`${good}\n*** Unknown: plans/x.md`),
        patch(`${good}\n*** Add File: plans/new.md\n+duplicate`), patch(`${good}\n*** Add File: plans/NEW.md\n+case alias`),
        patch(`${good}\n*** Update File: ${join(directory, "plans/new.md")}\n@@\n-old\n+new`),
        patch("*** Add File: plans/x.md\nunprefixed"), patch("*** Add File: plans/x.md\n@@\n+new"),
        patch("*** Update File: plans/x.md\n+no hunk"), patch("*** Update File: plans/x.md\n@@"),
        patch("*** Update File: plans/x.md\n@@\n context only"), patch("*** Update File: plans/x.md\n@@\n-old\n+new\n*** End of File\n+after eof"),
        patch("*** Add File: plans/x.md\n*** End of File"), "*** Begin Patch\n*** Add File: plans/x.md\n+missing end"]) {
        const args = { patchText };
        await assert.rejects(mutation(directory, agent, "apply_patch", args));
        assert.equal(Object.isFrozen(args), false);
      }
      assert.equal(await readFile(join(directory, "docs/research/existing.md"), "utf8"), "old\n");
      await assert.rejects(readFile(join(directory, "plans/new.md")), { code: "ENOENT" });
    }));
    test(`${agent} mutation retains model attribution checks`, async () => sandbox(async directory => {
      const f = fixture(agent, "write");
      f.state.messages = [user(agent), { ...message(agent, "write"), info: { ...message(agent, "write").info, modelID: "wrong" } }];
      const hooks = await researchCouncil({ client: f.client, directory });
      await assert.rejects(hooks["tool.execute.before"](f.input, { args: argsFor("write", "plans/report.md") }));
    }));
  }
  test("noncouncil mutations are unchanged, even outside document policy", async () => sandbox(async directory => {
    for (const tool of ["write", "edit", "apply_patch"]) {
      const args = argsFor(tool, "code.ts");
      const output = await mutation(directory, "build", tool, args);
      assert.equal(output.args, args);
      assert.equal(Object.isFrozen(args), false);
      output.args = {};
    }
  }));
});

describe("auto-loaded plugin boundary (SDK doubles, no provider)", () => {
  for (const agent of Object.keys(models)) {
    for (const tool of allowed) test(`${agent} permits ${tool}`, async () => {
      const run = await hook(fixture(agent, tool));
      assert.equal(await run(tool === "read" ? { filePath: `${root}CLAUDE.md` } : {}), undefined);
    });
    for (const tool of ["bash", "write", "edit", "apply_patch", "ast_grep_replace", "lsp_rename",
      "skill", "call_omo_agent", "browser_navigate", "higgsfield_generate_image", "context7_other",
      "background_output", "todowrite", "multi_tool_use.parallel", "unknown_tool"]) {
      test(`${agent} rejects ${tool} regardless of OMO tool enablement`, async () => {
        await assert.rejects((await hook(fixture(agent, tool)))({ agent: "build" }), /Research council/);
      });
    }
  }
  for (const agent of researchers) {
    for (const tool of ["task", "question"]) test(`${agent} cannot ${tool}`, async () => {
      await assert.rejects((await hook(fixture(agent, tool)))(taskArgs()));
    });
  }
  test("moderator may ask the human", async () => {
    assert.equal(await (await hook(fixture("council", "question")))({}), undefined);
  });
  for (const target of researchers) test(`allows explicit synchronous ${target} task`, async () => {
    const args = { ...taskArgs(), subagent_type: target };
    assert.equal(await (await hook(fixture()))(args), undefined);
    assert.ok(Object.isFrozen(args));
    assert.ok(Object.isFrozen(args.load_skills));
  });
  for (const patch of [
    { subagent_type: "build" }, { subagent_type: undefined }, { category: "research" },
    { command: "/implement" }, { run_in_background: true }, { run_in_background: "false" },
    { run_in_background: undefined }, { load_skills: ["git-master"] }, { load_skills: undefined },
    { load_skills: "" }, { prompt: "" }, { description: 7 }, { model: "other" },
    { task_id: "ses_child", session_id: "ses_child" }, { task_id: "bg_1" }, { session_id: "" },
  ]) test(`rejects malformed task ${JSON.stringify(patch)}`, async () => {
    await assert.rejects((await hook(fixture()))({ ...taskArgs(), ...patch }));
  });
  for (const args of [null, [], "task", 0]) test(`rejects non-object args ${JSON.stringify(args)}`, async () => {
    await assert.rejects((await hook(fixture()))(args));
  });
  for (const field of ["task_id", "session_id"]) {
    for (const target of researchers) {
      test(`allows matching same-parent ${target} continuation with ${field}`, async () => {
        const f = fixture();
        f.state.childMessages = [user(target), message(target)].map(m => ({ ...m, info: { ...m.info, sessionID: "ses_child" } }));
        assert.equal(await (await hook(f, field))({ ...taskArgs(), subagent_type: target, [field]: "ses_child" }), undefined);
      });
    }
    for (const target of researchers) for (const reason of ["parent", "agent", "model", "missing", "sdk"]) test(`rejects ${target} ${field} continuation with invalid ${reason}`, async () => {
      const f = fixture();
      f.state.childMessages = [user(target), message(target)].map(m => ({ ...m, info: { ...m.info, sessionID: "ses_child" } }));
      if (reason === "parent") f.state.parentID = "ses_unrelated";
      if (reason === "agent") {
        const other = researchers.find(name => name !== target);
        f.state.childMessages = [user(other), message(other)].map(m => ({ ...m, info: { ...m.info, sessionID: "ses_child" } }));
      }
      if (reason === "model") f.state.childMessages = [user(target), { ...message(target), info: { ...message(target).info, modelID: "wrong" } }].map(m => ({ ...m, info: { ...m.info, sessionID: "ses_child" } }));
      if (reason === "missing") f.state.childMessages = [];
      if (reason === "sdk") f.state.childFail = true;
      await assert.rejects((await hook(f, field))({ ...taskArgs(), subagent_type: target, [field]: "ses_child" }));
    });
  }
  for (const field of ["task_id", "session_id"]) test(`rejects continuation alias not consumed by ${field} runtime`, async () => {
    const other = field === "task_id" ? "session_id" : "task_id";
    await assert.rejects((await hook(fixture(), field))({ ...taskArgs(), [other]: "ses_child" }));
  });
  test("continuation fails closed without observed runtime schema", async () => {
    const f = fixture();
    const hooks = await researchCouncil({ client: f.client, directory: root });
    await assert.rejects(hooks["tool.execute.before"](f.input, { args: { ...taskArgs(), session_id: "ses_child" } }));
  });
  test("native task definition cannot overwrite an observed plugin continuation field", async () => {
    const f = fixture();
    const hooks = await researchCouncil({ client: f.client, directory: root });
    await hooks["tool.definition"]({ toolID: "task" }, { jsonSchema: { properties: {
      run_in_background: {}, load_skills: {}, session_id: {},
    } } });
    await hooks["tool.definition"]({ toolID: "task" }, { jsonSchema: { properties: { task_id: {} } } });
    assert.equal(await hooks["tool.execute.before"](f.input, { args: { ...taskArgs(), session_id: "ses_child" } }), undefined);
  });
  test("ambiguous plugin continuation schema fails closed", async () => {
    const f = fixture();
    const hooks = await researchCouncil({ client: f.client, directory: root });
    await hooks["tool.definition"]({ toolID: "task" }, { jsonSchema: { properties: {
      run_in_background: {}, load_skills: {}, session_id: {}, task_id: {},
    } } });
    await assert.rejects(hooks["tool.execute.before"](f.input, { args: { ...taskArgs(), session_id: "ses_child" } }));
  });
  for (const target of researchers) test(`denies a changed ${target} registered model before dispatch`, async () => {
    const f = fixture();
    const registered = f.state.agents.find(agent => agent.name === target);
    assert.ok(registered);
    registered.model.modelID = "wrong";
    await assert.rejects((await hook(f))({ ...taskArgs(), subagent_type: target }));
  });
  test("freezes the validated output reference against later plugin replacement", async () => {
    const f = fixture();
    const hooks = await researchCouncil({ client: f.client, directory: root });
    const output = { args: taskArgs() };
    await hooks["tool.execute.before"](f.input, output);
    assert.throws(() => { output.args = { ...taskArgs(), subagent_type: "build" }; });
    assert.throws(() => { output.args.subagent_type = "build"; });
  });
  test("SDK error bodies cannot authorize an otherwise valid task", async () => {
    const f = fixture();
    const hooks = await researchCouncil({ client: {
      ...f.client, app: { agents: async () => ({ error: "unavailable", data: f.state.agents }) },
    }, directory: root });
    await assert.rejects(hooks["tool.execute.before"](f.input, { args: taskArgs() }));
  });
  test("coding caller with no known scope during SDK outage is denied temporarily", async () => {
    const f = fixture("build", "bash");
    f.state.fail = true;
    await assert.rejects((await hook(f))({ command: "coding" }));
  });
  test("council caller's model is checked even for allowed research", async () => {
    const f = fixture("council", "websearch");
    f.state.messages = [user(), { ...message("council", "websearch"), info: { ...message().info, modelID: "wrong" } }];
    await assert.rejects((await hook(f))({}));
  });
  test("native-shaped task cannot omit explicit OMO safety parameters", async () => {
    await assert.rejects((await hook(fixture()))({ description: "Research", prompt: "Research", subagent_type: "council-grok" }));
  });
  test("noncouncil call remains unchanged even after an earlier council turn", async () => {
    const f = fixture("build", "bash");
    f.state.messages.unshift(user("council", "old_user"), message("council", "read", "old_call", "old_user"));
    const args = { command: "do coding work" };
    assert.equal(await (await hook(f))(args), undefined);
    assert.equal(Object.isFrozen(args), false);
  });
  for (const reason of ["missing-call", "duplicate-call", "stale-turn", "completed", "wrong-tool", "wrong-session", "wrong-model", "sdk"])
    test(`fails closed for ${reason} attribution`, async () => {
      const f = fixture("council", "websearch");
      if (reason === "missing-call") f.state.messages = [user(), message("council", "websearch", "another_call")];
      if (reason === "duplicate-call") f.state.messages.push(message("council", "websearch"));
      if (reason === "stale-turn") f.state.messages.push(user("build", "user_2"));
      if (reason === "completed") f.state.messages = [user(), { ...message("council", "websearch"), parts: [{ type: "tool", callID: "call_1", tool: "websearch", state: { status: "completed" } }] }];
      if (reason === "wrong-tool") f.input.tool = "read";
      if (reason === "wrong-session") f.input.sessionID = "ses_other";
      if (reason === "wrong-model") f.state.messages = [user(), { ...message("council", "websearch"), info: { ...message().info, modelID: "wrong" } }];
      if (reason === "sdk") f.state.fail = true;
      await assert.rejects((await hook(f))({ query: "public documentation" }));
    });
  test("pending research calls have a passing attribution baseline", async () => {
    const f = fixture("council", "websearch");
    f.state.messages = [user(), { ...message("council", "websearch"), parts: [
      { type: "tool", callID: "call_1", tool: "websearch", state: { status: "pending" } },
    ] }];
    assert.equal(await (await hook(f))({ query: "public documentation" }), undefined);
  });
  test("rejects user model mismatch on an otherwise allowed call", async () => {
    const f = fixture("council", "websearch");
    const changed = user();
    changed.info.model.modelID = "wrong";
    f.state.messages = [changed, message("council", "websearch")];
    await assert.rejects((await hook(f))({ query: "public documentation" }));
  });
  for (const reason of ["missing", "duplicate", "mode"]) test(`rejects invalid registry ${reason}`, async () => {
    const f = fixture();
    const registered = f.state.agents.find(agent => agent.name === taskArgs().subagent_type);
    assert.ok(registered);
    if (reason === "missing") f.state.agents = f.state.agents.filter(agent => agent.name !== registered.name);
    if (reason === "duplicate") f.state.agents.push(registered);
    if (reason === "mode") registered.mode = "primary";
    await assert.rejects((await hook(f))(taskArgs()));
  });
  for (const reason of ["user-only", "assistant-only", "mixed", "session"]) test(`rejects invalid child history ${reason}`, async () => {
    const f = fixture();
    if (reason === "user-only") f.state.childMessages = f.state.childMessages.slice(0, 1);
    if (reason === "assistant-only") f.state.childMessages = f.state.childMessages.slice(1);
    if (reason === "mixed") f.state.childMessages.push({ ...user("build"), info: { ...user("build").info, sessionID: "ses_child" } });
    if (reason === "session") f.state.childMessages[0].info.sessionID = "ses_other";
    await assert.rejects((await hook(f))({ ...taskArgs(), session_id: "ses_child" }));
  });
  for (const reason of ["error", "wrong-id"]) test(`rejects invalid session lookup ${reason}`, async () => {
    const f = fixture();
    const hooks = await researchCouncil({ client: { ...f.client, session: {
      ...f.client.session,
      get: async () => reason === "error" ? { error: "unavailable" } : { data: { id: "ses_other", parentID: "ses_parent" } },
    } }, directory: root });
    await hooks["tool.definition"]({ toolID: "task" }, { jsonSchema: { properties: {
      run_in_background: {}, load_skills: {}, session_id: {},
    } } });
    await assert.rejects(hooks["tool.execute.before"](f.input, { args: { ...taskArgs(), session_id: "ses_child" } }));
  });
  test("sensitive-name and symlink filters reject existing files independently of realpath errors", async () => {
    const directory = await mkdtemp(join(tmpdir(), "council-policy-"));
    try {
      const ordinary = join(directory, "ordinary.txt");
      const secret = join(directory, ".env");
      await writeFile(ordinary, "public fixture");
      await writeFile(secret, "FAKE_TEST_VALUE=not-a-secret");
      await symlink(ordinary, join(directory, "ordinary-link"));
      await symlink(secret, join(directory, "innocent-link"));
      await symlink(join(directory, "missing"), join(directory, "broken-link"));
      const run = await hook(fixture("council", "read"));
      for (const path of [ordinary, join(directory, "ordinary-link"), join(directory, "broken-link"), join(directory, "missing")])
        assert.equal(await run({ filePath: path }), undefined);
      for (const path of [secret, join(directory, "innocent-link")])
        await assert.rejects(run({ filePath: path }), (error: Error) => {
          assert.match(error.message, /\[RC_POLICY\]/);
          assert.doesNotMatch(error.message, /RC_UNAVAILABLE/);
          return true;
        });
    } finally {
      await rm(directory, { recursive: true, force: true });
    }
  });
  for (const file of [".env", ".env.local", "auth.json", "secrets.json", "private.key", "cert.pem", ".ssh/id_ed25519", "credentials.json"])
    test(`rejects sensitive read ${file}`, async () => {
      await assert.rejects((await hook(fixture("council", "read")))({ filePath: `${root}${file}` }));
    });
});

describe("scope before strict attribution (both plugin wrappers)", () => {
  for (const [plugin, owner] of [[researchCouncil, "council"], [reviewCouncil, "review-council"]] as const) {
    async function run(history: unknown[], args: unknown = {}, tool = "apply_patch") {
      let reads = 0;
      const f = fixture();
      f.client.session.messages = async () => { reads++; return { data: history }; };
      const hooks = await plugin({ client: f.client, directory: root });
      const output = { args };
      try { await hooks["tool.execute.before"]({ ...f.input, tool }, output); }
      finally { assert.equal(reads, 1, "one raw history snapshot per guard invocation"); }
      return output;
    }
    const variants: Record<string, (history: HistoryMessage[]) => void> = {
      "missing part": h => { h[1].parts = []; },
      "null state": h => { h[1].parts[0].state = null; },
      "wrong tool": h => { h[1].parts[0].tool = "read"; },
      "completed part": h => { h[1].parts[0].state = { status: "completed" }; },
      "duplicate same identity": h => { h[1].parts.push({ ...h[1].parts[0] }); },
      "incomplete part": h => { h[1].parts = [{ callID: "call_1" }]; },
      "malformed unrelated history": h => { h.unshift(Object.assign(message(owner, "read", "old_call"), { parts: [null] })); },
    };
    for (const agent of ["build", "Sisyphus-Junior", "other-coding-agent"]) {
      for (const [name, mutate] of Object.entries(variants)) test(`${owner}: ${agent} outside with ${name}`, async () => {
        const history: HistoryMessage[] = [user(agent), message(agent, "apply_patch")];
        mutate(history);
        const args = { agent: owner, subagent_type: owner, model: "ignored", load_skills: ["coding"], patchText: "coding edit" };
        const output = await run(history, args);
        assert.equal(output.args, args);
        assert.equal(Object.isFrozen(args), false);
        assert.equal(Object.isFrozen(args.load_skills), false);
        args.load_skills.push("still writable");
        output.args = {};
      });
    }
    for (const [name, mutate] of Object.entries(variants)) test(`${owner}: owned ${name} still denied`, async () => {
      const history: HistoryMessage[] = [user(owner), message(owner, "apply_patch")];
      mutate(history);
      await assert.rejects(run(history), /\[RC_/);
    });
    test(`${owner}: council to coding missing-part fallback ignores unrelated council calls`, async () => {
      await run([user(owner, "old_user"), message(owner, "read", "old_call", "old_user"), user("build", "new_user")]);
    });
    test(`${owner}: coding to council missing-part call stays strict`, async () => {
      await assert.rejects(run([user("build"), user(owner, "new_user")]), /\[RC_ATTRIBUTION\]/);
    });
    test(`${owner}: exact council evidence survives a later coding user`, async () => {
      await assert.rejects(run([user(owner), message(owner, "apply_patch"), user("build", "new_user")]), /\[RC_ATTRIBUTION\]/);
    });
    test(`${owner}: latest council user overrides exact coding evidence`, async () => {
      await assert.rejects(run([user("build"), message("build", "apply_patch"), user(owner, "new_user")]), /\[RC_ATTRIBUTION\]/);
    });
    for (const agent of [undefined, "", null]) test(`${owner}: unresolved latest user ${agent} never rewinds`, async () => {
      await assert.rejects(run([user("build"), { info: { ...user("build", "new_user").info, agent }, parts: [] }]), /\[RC_ATTRIBUTION\]/);
    });
    for (const second of ["other-coding-agent", owner]) test(`${owner}: conflicting exact agents ${second} denied`, async () => {
      await assert.rejects(run([user("build"), message("build", "apply_patch"), message(second, "apply_patch")]), /\[RC_ATTRIBUTION\]/);
    });
    for (const history of [[], [null], [{ info: {}, parts: [] }], [user("build"), { info: null, parts: [] }],
      [user("build"), { info: { ...message("build").info, agent: undefined }, parts: [{ callID: "call_1" }] }],
      [user("build"), { info: { ...user("build", "new_user").info, sessionID: undefined }, parts: [] }]]) {
      test(`${owner}: unknown ownership ${JSON.stringify(history)} fails closed`, async () => {
        await assert.rejects(run(history), /\[RC_ATTRIBUTION\]/);
      });
    }
    for (const response of [null, {}, { data: null }, { data: {} }, { error: "SECRET", data: [user("build")] }]) {
      test(`${owner}: invalid envelope remains unavailable`, async () => {
        const f = fixture("build");
        f.client.session.messages = async () => response;
        const hooks = await plugin({ client: f.client, directory: root });
        await assert.rejects(hooks["tool.execute.before"](f.input, { args: {} }), /\[RC_UNAVAILABLE\]/);
      });
    }
  }
});
