import { spawn } from "node:child_process";
import { readdir } from "node:fs/promises";
import { join } from "node:path";
import { OUT, fact } from "./common.mjs";

const results = [];
for (const name of (await readdir(OUT)).filter(x => x.endsWith(".mjs")).sort()) {
  const child = spawn("/opt/homebrew/bin/node", ["--check", join(OUT, name)], {
    cwd: OUT, env: process.env, stdio: ["ignore", "pipe", "pipe"],
  });
  const stdout = [], stderr = [];
  child.stdout.on("data", chunk => stdout.push(chunk));
  child.stderr.on("data", chunk => stderr.push(chunk));
  const closed = await new Promise((resolve, reject) => {
    child.once("error", reject);
    child.once("close", (exit, signal) => resolve({ exit, signal }));
  });
  results.push({ script: name, executable: "/opt/homebrew/bin/node", argv: ["--check", join(OUT, name)],
    ...closed, stdout: Buffer.concat(stdout).toString(), stderr: Buffer.concat(stderr).toString() });
  fact(closed.exit === 0, `syntax: ${name}`);
}
console.log(JSON.stringify({ results, status: "all-owned-syntax-checks-passed" }, null, 2));
