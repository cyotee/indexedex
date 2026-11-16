import { test } from "node:test";
import assert from "node:assert/strict";
import { mkdtemp, mkdir, writeFile, readFile, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { spawn } from "node:child_process";
import { once } from "node:events";
import { text } from "node:stream/consumers";
import { z } from "zod";

const helper = resolve("scripts/forge-artifacts.py");
// This executable models the external Forge CLI boundary, not SourceGraph or
// the helper under test. The separately recorded real Solar run proves EVM use.
const forgeBoundary = `#!/usr/bin/env bun
import { appendFileSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
const args = process.argv.slice(2);
appendFileSync("calls.jsonl", JSON.stringify(args) + "\\n");
if (args[0] === "config") {
  console.log(JSON.stringify({src:"contracts",out:"out",test:"test/foundry/spec",remappings:[]}));
} else if (args[0] === "build") {
  if (args[1] !== "--use" || args[2] !== "solar"
    || !args.includes("contracts/Facet.sol") || !args.includes("scripts/foundry/Probe.s.sol")) process.exit(19);
  if (process.env.HARNESS_BUILD_EXIT !== "0") process.exit(Number(process.env.HARNESS_BUILD_EXIT));
  mkdirSync("out/Facet.sol", {recursive:true});
  writeFileSync("out/Facet.sol/Facet.json", JSON.stringify({fixtureArtifact:"fresh"}));
} else if (args[0] === "script") {
  if (args[1] !== "--use" || args[2] !== "solar" || args.filter(x => x === "--use").length !== 1) process.exit(20);
  if (JSON.parse(readFileSync("out/Facet.sol/Facet.json", "utf8")).fixtureArtifact !== "fresh") process.exit(21);
  console.log("SCRIPT_USED_REFRESHED_ARTIFACT");
  process.exit(Number(process.env.HARNESS_SCRIPT_EXIT));
} else process.exit(22);
`;

for (const scenario of [
  { name: "script action refreshes runtime artifacts before forwarding remaining arguments", build: 0, script: 0,
    args: ["--sig", "run()", "-vv"], target: "scripts/foundry/Probe.s.sol:Probe" },
  { name: "failed artifact build prevents script execution and preserves the build exit code", build: 23, script: 0,
    args: ["--sig", "run()"], target: "scripts/foundry/Probe.s.sol:Probe" },
  { name: "script failure propagates its actual process exit code", build: 0, script: 37,
    args: ["--sig", "run()"], target: "scripts/foundry/Probe.s.sol:Probe" },
  { name: "explicit contract selection survives forwarding while Solar stays selected", build: 0, script: 0,
    args: ["--tc", "Helper", "--sig", "run()", "--use", "ignored-compiler", "-vvvv"],
    target: "scripts/foundry/Probe.s.sol" },
] as const) {
  test(scenario.name, async () => {
    const root = await mkdtemp(join(tmpdir(), "forge-script-harness-"));
    try {
      await mkdir(join(root, "bin"));
      await mkdir(join(root, "contracts"));
      await mkdir(join(root, "scripts/foundry"), { recursive: true });
      await mkdir(join(root, "out/Facet.sol"), { recursive: true });
      await writeFile(join(root, "contracts/Facet.sol"), "contract Facet {}", { flag: "wx" });
      await writeFile(join(root, "scripts/foundry/Probe.s.sol"),
        'contract Helper {} contract Probe { string constant RUNTIME = "Facet.sol:Facet"; }', { flag: "wx" });
      await writeFile(join(root, "out/Facet.sol/Facet.json"), '{"fixtureArtifact":"stale"}', { flag: "wx" });
      await writeFile(join(root, "bin/forge"), forgeBoundary, { flag: "wx", mode: 0o755 });
      const child = spawn("python3", [helper, "script", "--root", root, "scripts/foundry/Probe.s.sol", ...scenario.args], {
        cwd: root, env: { ...process.env, PATH: `${join(root, "bin")}:${process.env["PATH"]}`,
          PYTHONDONTWRITEBYTECODE: "1", HARNESS_BUILD_EXIT: String(scenario.build), HARNESS_SCRIPT_EXIT: String(scenario.script) },
        stdio: ["ignore", "pipe", "pipe"],
      });
      assert.ok(child.stdout && child.stderr);
      const [stdout, stderr] = await Promise.all([text(child.stdout), text(child.stderr), once(child, "close")]);
      assert.equal(child.exitCode, scenario.build || scenario.script, stderr);
      const calls = (await readFile(join(root, "calls.jsonl"), "utf8")).trim().split("\n")
        .map((line) => z.array(z.string()).parse(JSON.parse(line)));
      assert.deepEqual(calls.map((args) => args[0]), scenario.build ? ["config", "build"] : ["config", "build", "script"]);
      assert.equal(stdout.includes("SCRIPT_USED_REFRESHED_ARTIFACT"), scenario.build === 0);
      if (scenario.build === 0) {
        const forwarded = scenario.args.filter((arg) => arg !== "--use" && arg !== "ignored-compiler");
        assert.deepEqual(calls[2], ["script", "--use", "solar", scenario.target, ...forwarded]);
        assert.equal(JSON.parse(await readFile(join(root, "out/Facet.sol/Facet.json"), "utf8")).fixtureArtifact, "fresh");
      }
    } finally { await rm(root, { recursive: true, force: true }); }
  });
}
