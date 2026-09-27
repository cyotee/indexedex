import assert from "node:assert/strict";
import { mkdtemp, readFile, realpath, rm, writeFile, mkdir } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join, relative } from "node:path";
import { parse } from "yaml";
import researchCouncil from "../plugins/research-council";
import reviewCouncil from "../plugins/review-council";
import { reviewProfile } from "../support/research-council";

const { describe, test }: Pick<typeof import("node:test"), "describe" | "test"> = require("bun:test");

const root = new URL("../../", import.meta.url).pathname;
const models = reviewProfile.models;
const researchers = [...reviewProfile.researchers];
const documentRoots = [...reviewProfile.documentRoots];
const allowed = [...reviewProfile.tools];

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

function message(agent = "review-council", tool = "task", callID = "call_1", parentID = "user_1") {
  const [providerID, modelID] = (models[agent] ?? "xai/grok-4.7").split("/");
  return { info: { id: "assistant_1", sessionID: "ses_parent", role: "assistant", agent, parentID,
    providerID, modelID }, parts: [{ type: "tool", callID, tool, state: { status: "running" } }] };
}
function user(agent = "review-council", id = "user_1") {
  const [providerID, modelID] = (models[agent] ?? "xai/grok-4.7").split("/");
  return { info: { id, sessionID: "ses_parent", role: "user", agent, model: { providerID, modelID } }, parts: [] };
}
function fixture(agent = "review-council", tool = "task") {
  const state = {
    messages: [user(agent), message(agent, tool)],
    agents: Object.entries(models).map(([name, model]) => {
      const [providerID, modelID] = model.split("/");
      return { name, mode: name === "review-council" ? "primary" : "subagent", model: { providerID, modelID } };
    }),
  };
  const client = {
    session: {
      messages: async () => ({ data: state.messages }),
      get: async () => ({ data: { id: "ses_child", parentID: "ses_parent" } }),
    },
    app: { agents: async () => ({ data: state.agents }) },
  };
  return { client, input: { tool, sessionID: "ses_parent", callID: "call_1" } };
}
const taskArgs = () => ({ description: "Independent Grok review", prompt: "Review the named files",
  subagent_type: "review-council-grok", load_skills: [] as string[], run_in_background: false });

async function hook(f: ReturnType<typeof fixture> = fixture()) {
  const hooks = await reviewCouncil({ client: f.client, directory: root });
  await hooks["tool.definition"]({ toolID: "task" }, { jsonSchema: { properties: {
    run_in_background: {}, load_skills: {}, subagent_type: {}, session_id: {},
  } } });
  return (args: unknown) => hooks["tool.execute.before"](f.input, { args });
}

describe("review-council definitions", () => {
  for (const [name, model] of Object.entries(models)) {
    test(`${name} pins model and review-only markdown writes`, async () => {
      const text = await readFile(`${root}.opencode/agents/${name}.md`, "utf8");
      const config = parse(text.split("---")[1]);
      assert.equal(config.model, model);
      assert.equal(config.variant, name === "review-council-kimi" ? "high" : undefined);
      assert.equal(config.mode, name === "review-council" ? "primary" : "subagent");
      assert.equal(config.permission["*"], "deny");
      assert.deepEqual(Object.entries(config.permission.edit).filter(([, value]) => value === "allow").map(([key]) => key),
        [...documentRoots.flatMap(path => [`${path}/*.md`, `${path}/**/*.md`]), "*REMEDIATION_PRD.md", "**/*REMEDIATION_PRD.md"]);
      for (const base of documentRoots) {
        assert.equal(nativeEditPermission(`${base}/report.md`, config.permission.edit), "allow");
        assert.equal(nativeEditPermission(`${base}/nested/report.md`, config.permission.edit), "allow");
        assert.equal(nativeEditPermission(`${base}/code.ts`, config.permission.edit), "deny");
      }
      assert.equal(nativeEditPermission("docs/research/report.md", config.permission.edit), "deny");
      assert.equal(nativeEditPermission("contracts/vaults/standard/FOO_REMEDIATION_PRD.md", config.permission.edit), "allow");
      assert.equal(nativeEditPermission("contracts/vaults/standard/Foo.sol", config.permission.edit), "deny");
      assert.equal(nativeEditPermission(".opencode/FOO_REMEDIATION_PRD.md", config.permission.edit), "deny");
      assert.match(text, /Do not edit code while reviewing/);
      assert.match(text, /quality and security/i);
      assert.match(text, /Writing a review never authorizes implementing it/);
      assert.match(text, /exploit procedures,\s+proof-of-concept code, payloads/);
      assert.ok(text.includes("docs/reviews/"));
      assert.ok(text.includes("reviews/"));
    });
  }
  test("command selects the Grok coordinator and states the Astra cap", async () => {
    const text = await readFile(`${root}.opencode/commands/review-council.md`, "utf8");
    const config = parse(text.split("---")[1]);
    assert.equal(config.agent, "review-council");
    assert.equal(config.subtask, false);
    assert.ok(text.includes("$ARGUMENTS"));
    assert.match(text, /xai\/grok-4\.7/);
    assert.match(text, /ASTRA_RESUBMISSION_CAP: 2/);
    assert.match(text, /PRD/);
    assert.match(text, /implementation plan/i);
    assert.match(text, /audit report/i);
    assert.match(text, /do not invent intended behavior/i);
    assert.match(text, /continue with Grok, MiniMax M3 and Kimi K3/);
    assert.match(text, /Do not impersonate Astra/);
    assert.match(text, /jailbreak/i);
    assert.match(text, /must not request exploit procedures/);
    assert.match(text, /remediation PRD/);
    assert.match(text, /Do not edit code while reviewing/);
    assert.match(text, /REMEDIATION_PRD\.md/);
  });
  test("coordinator detects censorship without extracting a reproduction", async () => {
    const text = await readFile(`${root}.opencode/agents/review-council.md`, "utf8");
    for (const name of researchers) assert.ok(text.includes(name));
    assert.match(text, /ASTRA_RESUBMISSION_CAP: 2/);
    assert.match(text, /two rewritten\s+resubmissions after the initial call/);
    assert.match(text, /do not resume the refused session/i);
    assert.match(text, /new review-council-astra\nsession/);
    assert.match(text, /do not resubmit to extract the withheld reproduction/i);
    assert.match(text, /no instruction to ignore safety rules/i);
    assert.match(text, /prompt orchestration, not a runtime call counter/);
    assert.match(text, /coordinator notes, never Astra findings/);
    assert.match(text, /deliverable is one remediation PRD/);
    assert.match(text, /Do not edit code while reviewing/);
    assert.equal(nativeMatch("docs/reviews/report.md", "docs/reviews/**/*.md"), false);
    assert.equal(nativeEditPermission("docs/reviews/report.md",
      parse(text.split("---")[1]).permission.edit), "allow");
  });
  test("documentation and router name the review council", async () => {
    const doc = await readFile(`${root}docs/agent/REVIEW_COUNCIL.md`, "utf8");
    assert.match(doc, /ASTRA_RESUBMISSION_CAP: 2/);
    assert.match(doc, /xai\/grok-4\.7/);
    assert.match(doc, /reviewProfile/);
    assert.match(await readFile(`${root}CLAUDE.md`, "utf8"), /Grok 4\.7 code-review council/);
    assert.match(await readFile(`${root}CLAUDE.md`, "utf8"), /Astra \/ Grok \/ MiniMax M3 \/ Kimi K3 research council/);
  });
});

describe("review-council guard", () => {
  test("allows a synchronous reviewer task and a second Astra call", async () => {
    const args = taskArgs();
    await (await hook())(args);
    assert.ok(Object.isFrozen(args));
    assert.ok(Object.isFrozen(args.load_skills));
    await (await hook())({ ...taskArgs(), description: "Astra retry", subagent_type: "review-council-astra" });
  });
  test("denies research-council targets, shell, and research document writes", async () => {
    await assert.rejects((await hook())({ ...taskArgs(), subagent_type: "council-grok" }), /Review council: \[RC_POLICY\]/);
    await assert.rejects((await hook(fixture("review-council", "bash")))({ command: "forge test" }), /Review council: \[RC_POLICY\]/);
    const directory = await realpath(await mkdtemp(join(tmpdir(), "review-council-")));
    try {
      await mkdir(join(directory, "docs/reviews"), { recursive: true });
      const f = fixture("review-council", "write");
      const hooks = await reviewCouncil({ client: f.client, directory });
      const allowedWrite = { filePath: "docs/reviews/report.md", content: "# Review" };
      await hooks["tool.execute.before"](f.input, { args: allowedWrite });
      assert.ok(Object.isFrozen(allowedWrite));
      await assert.rejects(hooks["tool.execute.before"](f.input, { args: { filePath: "docs/research/report.md", content: "# No" } }),
        /Review council: \[RC_POLICY\]/);
      const prd = { filePath: "contracts/vaults/standard/FOO_REMEDIATION_PRD.md", content: "# PRD" };
      await hooks["tool.execute.before"](f.input, { args: prd });
      assert.ok(Object.isFrozen(prd));
      await assert.rejects(hooks["tool.execute.before"](f.input, { args: { filePath: "contracts/vaults/standard/Foo.sol", content: "contract Foo {}" } }),
        /Review council: \[RC_POLICY\]/);
      await assert.rejects(readFile(join(directory, "docs/reviews/report.md")), { code: "ENOENT" });
    } finally { await rm(directory, { recursive: true, force: true }); }
  });
  test("research guard still rejects review reviewers", async () => {
    const research = await researchCouncil({ client: {
      session: { messages: async () => ({ data: [
        { info: { id: "user_1", sessionID: "ses_parent", role: "user", agent: "council",
          model: { providerID: "openai", modelID: "gpt-6-astra" } }, parts: [] },
        { info: { id: "assistant_1", sessionID: "ses_parent", role: "assistant", agent: "council",
          parentID: "user_1", providerID: "openai", modelID: "gpt-6-astra" },
          parts: [{ type: "tool", callID: "call_1", tool: "task", state: { status: "running" } }] },
      ] }), get: async () => ({ data: {} }) },
      app: { agents: async () => ({ data: [] }) },
    }, directory: root });
    await assert.rejects(research["tool.execute.before"](
      { tool: "task", sessionID: "ses_parent", callID: "call_1" },
      { args: { ...taskArgs(), subagent_type: "review-council-grok" } }), /Research council: \[RC_POLICY\]/);
  });
  test("does not block an unrelated coding read", async () => {
    const f = fixture("build", "read");
    f.input = { tool: "read", sessionID: "ses_parent", callID: "call_1" };
    const filePath = relative(root, join(root, "CLAUDE.md"));
    await (await hook(f))({ filePath });
  });
});
