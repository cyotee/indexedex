import assert from "node:assert/strict";
import { execFile } from "node:child_process";
import { link, lstat, mkdir, mkdtemp, readFile, readdir, realpath, rm, symlink, writeFile } from "node:fs/promises";
import { promisify } from "node:util";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { parse } from "yaml";
import researchCouncil from "../plugins/research-council";
import reviewCouncil from "../plugins/review-council";
import { researchProfile, reviewProfile } from "../support/research-council";
import {
  APPROVED_ARTIFACTS,
  RESEARCH_JSON_LIMITS,
  RESEARCH_JSON_READ_TOOL,
  executeResearchJsonRead,
  isSensitiveArtifactPath,
  pageLogicalLines,
  reconstructLogicalLines,
  splitLogicalLines,
  type ArtifactIO,
} from "../support/research-json-read";

const { describe, test }: Pick<typeof import("node:test"), "describe" | "test"> = require("bun:test");

const root = new URL("../../", import.meta.url).pathname;
const researchers = ["council-astra", "council-grok", "council-minimax", "council-kimi"];
const TARGET = ["sources", "lib/pendle-sy/contracts/core/StandardizedYield/implementations/NET/PendleStakedNetSY.sol", "content"];

function message(agent: string, tool = RESEARCH_JSON_READ_TOOL) {
  const [providerID, modelID] = researchProfile.models[agent].split("/");
  return { info: { id: "assistant_1", sessionID: "ses_parent", role: "assistant", agent, parentID: "user_1",
    providerID, modelID }, parts: [{ type: "tool", callID: "call_1", tool, state: { status: "running" } }] };
}
function user(agent: string) {
  const [providerID, modelID] = researchProfile.models[agent].split("/");
  return { info: { id: "user_1", sessionID: "ses_parent", role: "user", agent, model: { providerID, modelID } }, parts: [] };
}
function clientFor(agent: string, tool = RESEARCH_JSON_READ_TOOL) {
  return {
    session: { messages: async () => ({ data: [user(agent), message(agent, tool)] }), get: async () => ({ data: {} }) },
    app: { agents: async () => ({ data: [] }) },
  };
}

async function sandbox(run: (directory: string) => Promise<void>) {
  const directory = await realpath(await mkdtemp(join(tmpdir(), "research-json-")));
  try { await run(directory); } finally { await rm(directory, { recursive: true, force: true }); }
}

async function artifact(directory: string, name: string, value: unknown) {
  const path = join(directory, name);
  await writeFile(path, JSON.stringify(value));
  return path;
}

function readArgs(artifactId: string, selector: string[], extra: Record<string, unknown> = {}) {
  return { operation: "read_string", artifact: artifactId, selector, ...extra };
}

async function readAll(args: Record<string, unknown>, options: { artifacts: Record<string, string> }) {
  const pages: Array<{ complete: boolean; next: { lineOffset: number; charOffset: number } | null; lines: Array<{ text: string; terminator: string; complete: boolean }> }> = [];
  let cursor: { lineOffset?: number; charOffset?: number } = {};
  for (let guard = 0; guard < 1000; guard++) {
    const page = JSON.parse(await executeResearchJsonRead({ ...args, ...cursor }, options));
    pages.push(page);
    assert.equal(page.complete, page.next === null);
    if (page.complete) return pages;
    cursor = page.next;
  }
  throw new Error("pagination did not complete");
}

describe("logical line pagination", () => {
  test("mixed newlines and an oversized line reconstruct exactly", () => {
    const huge = "X".repeat(RESEARCH_JSON_LIMITS.maxContentChars + 50);
    const text = `a\n\nb\r\nc\r${huge}\nend`;
    const lines = splitLogicalLines(text);
    const slices: Array<{ text: string; terminator: string; complete: boolean }> = [];
    let cursor = { lineOffset: 0, charOffset: 0 };
    let complete = false;
    while (!complete) {
      const page = pageLogicalLines(lines, cursor, 2);
      slices.push(...page.slices);
      complete = page.complete;
      assert.equal(complete, page.next === null);
      if (page.next) cursor = page.next;
    }
    assert.equal(reconstructLogicalLines(slices), text);
    assert.ok(slices.some(slice => slice.complete === false));
  });
});

describe("approved artifact reader", () => {
  test("decodes a single-line JSON bundle and rejects unsafe selectors", async () => sandbox(async directory => {
    const source = "constructor() {}\nfunction _deposit() {}\nfunction _redeem() {}\n";
    const key = "lib/a.b/café/say \"hi\"\\path.sol";
    const path = await artifact(directory, "bundle.json", { sources: { [key]: { content: source }, "ok.sol": { content: "uint x;" } } });
    const artifacts = { "public-bundle": path };
    const listed = JSON.parse(await executeResearchJsonRead({ operation: "list_keys", artifact: "public-bundle", selector: ["sources"], limit: 1 }, { artifacts }));
    assert.equal(listed.totalKeys, 2);
    assert.equal(listed.complete, false);
    assert.deepEqual(listed.next, { offset: 1 });
    const second = JSON.parse(await executeResearchJsonRead({ operation: "list_keys", artifact: "public-bundle", selector: ["sources"], offset: 1, limit: 10 }, { artifacts }));
    assert.deepEqual([...listed.keys, ...second.keys], [key, "ok.sol"]);
    const pages = await readAll(readArgs("public-bundle", ["sources", key, "content"], { limit: 1 }), { artifacts });
    assert.equal(reconstructLogicalLines(pages.flatMap(page => page.lines)), source);
    await assert.rejects(executeResearchJsonRead({ operation: "read_string", artifact: "public-bundle", selector: key }, { artifacts }), /invalid arguments/);
    await assert.rejects(executeResearchJsonRead({ operation: "eval", artifact: "public-bundle", selector: [] }, { artifacts }), /invalid arguments/);
  }));

  test("exact keys survive slashes, dots, unicode and escapes; prototype names are not traversed", async () => sandbox(async directory => {
    const tricky = { "a/b.c": { "ü": { "quote\"slash\\": "kept" } }, constructor: { prototype: "own-data" } };
    const path = await artifact(directory, "keys.json", tricky);
    const artifacts = { "key-fixture": path };
    const unicode = JSON.parse(await executeResearchJsonRead(readArgs("key-fixture", ["a/b.c", "ü", "quote\"slash\\"]), { artifacts }));
    assert.equal(unicode.lines[0].text, "kept");
    const own = JSON.parse(await executeResearchJsonRead(readArgs("key-fixture", ["constructor", "prototype"]), { artifacts }));
    assert.equal(own.lines[0].text, "own-data");
    const keys = JSON.parse(await executeResearchJsonRead({ operation: "list_keys", artifact: "key-fixture", selector: [] }, { artifacts }));
    assert.equal(keys.keys.includes("toString"), false);
    assert.equal(keys.keys.includes("constructor"), true);
    await assert.rejects(executeResearchJsonRead({ operation: "list_keys", artifact: "key-fixture", selector: ["toString"] }, { artifacts }), /selector not found/);
    const polluted = await artifact(directory, "proto.json", JSON.parse('{"__proto__":{"admin":true},"ok":1}'));
    const listed = JSON.parse(await executeResearchJsonRead({ operation: "list_keys", artifact: "proto-fixture", selector: [] }, { artifacts: { "proto-fixture": polluted } }));
    assert.equal(listed.keys.includes("toString"), false);
    assert.equal(({} as { admin?: boolean }).admin, undefined);
  }));

  test("malformed JSON, missing keys, nonstrings, bad cursors and excessive limits fail without echoing content", async () => sandbox(async directory => {
    const path = await artifact(directory, "bad.json", { sources: { a: { content: 1 }, b: ["nope"] }, text: "secret-body" });
    const artifacts = { "bad-fixture": path };
    await writeFile(join(directory, "broken.json"), "{");
    const broken = { "broken-fixture": join(directory, "broken.json") };
    for (const [args, pattern] of [
      [{ operation: "read_string", artifact: "missing", selector: ["text"] }, /artifact not authorized/],
      [{ operation: "read_string", artifact: "bad-fixture", selector: ["nope"] }, /selector not found/],
      [{ operation: "read_string", artifact: "bad-fixture", selector: ["sources", "a", "content"] }, /unsupported JSON value/],
      [{ operation: "list_keys", artifact: "bad-fixture", selector: ["sources", "b"] }, /unsupported JSON value/],
      [{ operation: "read_string", artifact: "broken-fixture", selector: [] }, /malformed JSON/],
      [readArgs("bad-fixture", ["text"], { lineOffset: 4 }), /invalid offset/],
      [readArgs("bad-fixture", ["text"], { charOffset: 1.5 }), /invalid arguments/],
      [readArgs("bad-fixture", ["text"], { limit: RESEARCH_JSON_LIMITS.maxLineRecords + 1 }), /invalid arguments/],
      [{ operation: "list_keys", artifact: "bad-fixture", selector: [], limit: 0 }, /invalid arguments/],
      [{ operation: "read_string", artifact: "bad-fixture", selector: ["text"], offset: 1 }, /invalid arguments/],
      [{ operation: "list_keys", artifact: "bad-fixture", selector: [], lineOffset: 1 }, /invalid arguments/],
      [{ operation: "read_string", artifact: "bad-fixture", selector: ["text"], query: "process.exit(1)" }, /invalid arguments/],
    ] as const) {
      await assert.rejects(executeResearchJsonRead(args, args.artifact === "broken-fixture" ? { artifacts: broken } : { artifacts }), pattern);
    }
    await assert.rejects(executeResearchJsonRead(readArgs("bad-fixture", ["text"], { query: directory }), { artifacts }), (error: Error) => {
      assert.equal(error.message.includes(directory), false);
      assert.equal(error.message.includes("secret-body"), false);
      return true;
    });
  }));

  test("symlink, hardlink, ancestor link, special file, sensitive name and inode replacement are rejected", async () => sandbox(async directory => {
    const real = join(directory, "real");
    await mkdir(real);
    const file = await artifact(real, "public.json", { text: "ok" });
    const linkPath = join(directory, "linked.json");
    await symlink(file, linkPath);
    await assert.rejects(executeResearchJsonRead(readArgs("link", ["text"]), { artifacts: { link: linkPath } }), /artifact failed safety checks/);
    const alias = join(directory, "alias.json");
    await link(file, alias);
    await assert.rejects(executeResearchJsonRead(readArgs("hard", ["text"]), { artifacts: { hard: alias } }), /artifact failed safety checks/);
    const via = join(directory, "via");
    await symlink(real, via);
    await assert.rejects(executeResearchJsonRead(readArgs("ancestor", ["text"]), { artifacts: { ancestor: join(via, "public.json") } }), /artifact failed safety checks/);
    await assert.rejects(executeResearchJsonRead(readArgs("null", []), { artifacts: { null: "/dev/null" } }), /artifact failed safety checks/);
    const fifo = join(directory, "pipe");
    await promisify(execFile)("mkfifo", [fifo]);
    await assert.rejects(executeResearchJsonRead(readArgs("fifo", []), { artifacts: { fifo } }), /artifact failed safety checks/);
    const secret = await artifact(directory, "credentials.json", { text: "nope" });
    await assert.rejects(executeResearchJsonRead(readArgs("secret", ["text"]), { artifacts: { secret } }), /artifact failed safety checks/);
    await assert.rejects(executeResearchJsonRead(readArgs("escape", ["text"]), { artifacts: { escape: `${directory}/../credentials.json` } }), /artifact failed safety checks/);
    const before = await lstat(file);
    const opened = { dev: before.dev + 1, ino: before.ino + 1, nlink: 1, size: before.size, isFile: true, isDirectory: false, isSymbolicLink: false };
    const io: ArtifactIO = {
      async lstat(candidate) {
        if (candidate === file) return { dev: before.dev, ino: before.ino, nlink: 1, size: before.size, isFile: true, isDirectory: false, isSymbolicLink: false };
        return { dev: 1, ino: 1, nlink: 1, size: 0, isFile: false, isDirectory: true, isSymbolicLink: false };
      },
      async open() {
        return { stat: async () => opened, read: async () => Buffer.from("[]"), close: async () => undefined };
      },
    };
    await assert.rejects(executeResearchJsonRead(readArgs("swap", ["text"]), { artifacts: { swap: file }, io }), /artifact failed safety checks/);
    const names = await readdir(directory);
    assert.equal(names.includes("spawned"), false);
  }));

  test("input and output budgets fail closed and caller expressions are data", async () => sandbox(async directory => {
    const huge = join(directory, "huge.json");
    await writeFile(huge, `{"text":"${"a".repeat(RESEARCH_JSON_LIMITS.maxInputBytes)}"}`);
    await assert.rejects(executeResearchJsonRead(readArgs("huge", ["text"]), { artifacts: { huge } }), /input exceeds resource limit/);
    let nested = "0";
    for (let index = 0; index < RESEARCH_JSON_LIMITS.maxDepth + 2; index++) nested = `{"a":${nested}}`;
    const deep = join(directory, "deep.json");
    await writeFile(deep, nested);
    await assert.rejects(executeResearchJsonRead({ operation: "list_keys", artifact: "deep", selector: [] }, { artifacts: { deep } }), /input exceeds resource limit/);
    const expression = "require('child_process').execSync('touch spawned')";
    const path = await artifact(directory, "code.json", { [expression]: expression });
    const page = JSON.parse(await executeResearchJsonRead(readArgs("code", [expression]), { artifacts: { code: path } }));
    assert.equal(page.lines[0].text, expression);
    assert.equal((await readdir(directory)).includes("spawned"), false);
    const source = await readFile(new URL("../support/research-json-read.ts", import.meta.url), "utf8");
    for (const banned of ["child_process", "node:net", "node:http", "writeFile", "appendFile", "execSync", "spawn(", "eval(", "Function(", "fetch("]) {
      assert.equal(source.includes(banned), false, banned);
    }
  }));

  test("sensitive-path rule matches the council guard samples", () => {
    assert.equal(isSensitiveArtifactPath("/tmp/credentials.json"), true);
    assert.equal(isSensitiveArtifactPath("/tmp/.env"), true);
    assert.equal(isSensitiveArtifactPath("/tmp/token.pem"), true);
    assert.equal(isSensitiveArtifactPath("/tmp/public.json"), false);
  });
});

describe("guard and agent exposure", () => {
  test("plugin registers research_json_read and review plugin does not", async () => {
    const research = await researchCouncil({ client: clientFor("council"), directory: root });
    const review = await reviewCouncil({ client: clientFor("council"), directory: root });
    assert.equal(typeof research.tool?.[RESEARCH_JSON_READ_TOOL]?.execute, "function");
    assert.equal(Object.prototype.hasOwnProperty.call(review, "tool"), false);
    assert.equal(researchProfile.tools.has(RESEARCH_JSON_READ_TOOL), true);
    assert.equal(reviewProfile.tools.has(RESEARCH_JSON_READ_TOOL), false);
  });

  test("research guard rejects unknown reader arguments and review guard rejects the tool", async () => {
    const research = await researchCouncil({ client: clientFor("council-grok"), directory: root });
    const args = { operation: "list_keys", artifact: "not-approved", selector: [], command: "sh" };
    await assert.rejects(research["tool.execute.before"]({ tool: RESEARCH_JSON_READ_TOOL, sessionID: "ses_parent", callID: "call_1" }, { args }), /Research council: \[RC_POLICY\]/);
    const review = await reviewCouncil({ client: {
      session: { messages: async () => ({ data: [
        { info: { id: "user_1", sessionID: "ses_parent", role: "user", agent: "review-council", model: { providerID: "xai", modelID: "grok-4.7" } }, parts: [] },
        { info: { id: "assistant_1", sessionID: "ses_parent", role: "assistant", agent: "review-council", parentID: "user_1", providerID: "xai", modelID: "grok-4.7" },
          parts: [{ type: "tool", callID: "call_1", tool: RESEARCH_JSON_READ_TOOL, state: { status: "running" } }] },
      ] }), get: async () => ({ data: {} }) },
      app: { agents: async () => ({ data: [] }) },
    }, directory: root });
    await assert.rejects(review["tool.execute.before"](
      { tool: RESEARCH_JSON_READ_TOOL, sessionID: "ses_parent", callID: "call_1" },
      { args: { operation: "list_keys", artifact: "sourcify-4663-staked-net-sy-sources", selector: ["sources"] } }),
      /Review council: \[RC_POLICY\]/);
  });

  test("all five research profiles allow the tool and researchers still cannot delegate", async () => {
    for (const name of ["council", ...researchers]) {
      const config = parse((await readFile(`${root}.opencode/agents/${name}.md`, "utf8")).split("---")[1]);
      assert.equal(config.permission["*"], "deny");
      assert.equal(config.permission[RESEARCH_JSON_READ_TOOL], "allow");
      assert.equal(config.permission.external_directory, undefined);
      if (name !== "council") assert.equal(config.permission.task, undefined);
    }
    for (const name of Object.keys(reviewProfile.models)) {
      const config = parse((await readFile(`${root}.opencode/agents/${name}.md`, "utf8")).split("---")[1]);
      assert.equal(config.permission[RESEARCH_JSON_READ_TOOL], undefined);
    }
  });

  test("guarded production artifact reaches conversion functions beyond the constructor", async () => {
    const artifactId = "sourcify-4663-staked-net-sy-sources";
    const research = await researchCouncil({ client: clientFor("council"), directory: root });
    const args = { operation: "read_string" as const, artifact: artifactId, selector: TARGET, lineOffset: 0, charOffset: 0, limit: 20 };
    try {
      await research["tool.execute.before"]({ tool: RESEARCH_JSON_READ_TOOL, sessionID: "ses_parent", callID: "call_1" }, { args: { ...args } });
    } catch (error) {
      assert.match(String(error), /RC_POLICY/);
      return;
    }
    assert.ok(Object.isFrozen(args.selector));
    const pages = await readAll(args, { artifacts: APPROVED_ARTIFACTS });
    const text = reconstructLogicalLines(pages.flatMap(page => page.lines));
    const parsed = JSON.parse(await readFile(APPROVED_ARTIFACTS[artifactId], "utf8"));
    assert.equal(text, parsed.sources[TARGET[1]].content);
    const constructorPage = pages.findIndex(page => page.lines.some((line: { text: string }) => line.text.includes("constructor")));
    const depositPage = pages.findIndex(page => page.lines.some((line: { text: string }) => line.text.includes("function _deposit")));
    assert.ok(constructorPage >= 0);
    assert.ok(depositPage > constructorPage);
    const keys = JSON.parse(await executeResearchJsonRead({ operation: "list_keys", artifact: artifactId, selector: ["sources"], limit: 50 }, { artifacts: APPROVED_ARTIFACTS }));
    assert.equal(keys.keys.includes(TARGET[1]), true);
    assert.equal(keys.keys.includes("lib/pendle-sy/contracts/interfaces/NetNet/IStakedNet.sol"), true);
    assert.equal(text.includes("function _redeem"), true);
    assert.equal(text.includes("touch spawned"), false);
  });
});
