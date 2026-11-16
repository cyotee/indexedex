import { spawn } from "node:child_process";
import { once } from "node:events";
import { readFile } from "node:fs/promises";
import { dirname, resolve, join } from "node:path";
import { fileURLToPath } from "node:url";
import { createHash } from "node:crypto";
import { z } from "zod";

const here = dirname(fileURLToPath(import.meta.url));
const root = resolve(here, "../../../../../..");
const seal = z.object({
  checks: z.array(z.object({ command: z.string(), name: z.string() })),
}).parse(JSON.parse(await readFile(join(here, "../implementation/seal.json"), "utf8")));
const checks = seal.checks.slice(0, 6);
const cli = checks[5];
if (!cli) throw new Error("missing approved CLI command");
checks[5] = {
  ...cli,
  command: cli.command.replace("/implementation/runtime-02", "/verification/runtime-01"),
};
const { writeFile } = await import("node:fs/promises");
await writeFile(join(here, "commands.json"), JSON.stringify(checks, null, 2) + "\n", { flag: "wx" });
const results = [];
for (const [index, check] of checks.entries()) {
  const name = ["specs", "forks", "stages", "types", "operator", "cli"][index];
  if (!name) throw new Error("invalid command index");
  const command = `cd '${root}' && export PATH=/Users/cyotee/.foundry/bin:/opt/homebrew/Cellar/bun/1.4.2/bin:$PATH; ${check.command}`;
  console.log(`START ${name}`);
  const process_ = spawn("/bin/zsh", ["-lc", command], {
    cwd: root, env: process.env, stdio: ["ignore", "pipe", "pipe"],
  });
  const exited = once(process_, "close");
  const chunks: Buffer[] = [];
  process_.stdout.on("data", (chunk: Buffer) => { chunks.push(chunk); });
  process_.stderr.on("data", (chunk: Buffer) => { chunks.push(chunk); });
  const [code, signal] = await exited;
  const log = Buffer.concat(chunks);
  await writeFile(join(here, `${name}.log`), log, { flag: "wx" });
  results.push({
    name, command: check.command, bootstrap: "/bin/zsh -lc; approved existing login environment",
    code, signal, bytes: log.byteLength, sha256: createHash("sha256").update(log).digest("hex"),
  });
  await writeFile(join(here, `result-${name}.json`), JSON.stringify(results.at(-1), null, 2) + "\n", { flag: "wx" });
  console.log(`RESULT ${name} exit=${code} bytes=${log.byteLength}`);
}
await writeFile(join(here, "checks.json"), JSON.stringify(results, null, 2) + "\n", { flag: "wx" });
console.log("VERIFIER_CHECKS_COMPLETE");
process.exitCode = results.some((result) => result.code !== 0) ? 1 : 0;
