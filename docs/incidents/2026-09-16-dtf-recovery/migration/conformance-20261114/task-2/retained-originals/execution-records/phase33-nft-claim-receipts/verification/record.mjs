import { spawn } from "node:child_process";
import { writeFile } from "node:fs/promises";
import { join } from "node:path";
import { OUT, identity, save, requireEvidence, sha } from "./evidence.mjs";

const [mode, label] = process.argv.slice(2);
requireEvidence(["syntax", "acquire", "proof", "intake"].includes(mode) && /^[a-z0-9-]+$/.test(label), "recorded command mode/label");
const files = ["evidence.mjs", "acquire.mjs", "record.mjs", "semantics.mjs", "proof.mjs", "publish.mjs"];
const source = [];
for (const f of files) {
  try { source.push(await identity(join(OUT, f))); }
  catch (error) { if (!(error instanceof Error) || !("code" in error) || error.code !== "ENOENT") throw error; }
}
let args;
switch (mode) {
  case "syntax": args = ["--check", process.argv[4]]; break;
  case "acquire": args = ["acquire.mjs"]; break;
  case "proof": args = ["proof.mjs", ...process.argv.slice(4)]; break;
  case "intake": args = ["-e", 'const m=await import("./evidence.mjs");const s=await m.intake();console.log(JSON.stringify({producer:s.producerBindings.length,bindings:s.bindings.length,rows:s.rows.length,refs:s.refs.length}));']; break;
  default: requireEvidence(false, "unsupported mode");
}
const startedAt = new Date().toISOString(), stdout = [], stderr = [];
const executable = mode === "syntax" ? "/opt/homebrew/bin/node" : process.execPath;
const child = spawn(executable, args, { cwd: OUT, env: process.env, stdio: ["ignore", "pipe", "pipe"] });
child.stdout.on("data", b => stdout.push(b)); child.stderr.on("data", b => stderr.push(b));
const close = await new Promise((resolve, reject) => {
  child.once("error", reject);
  child.once("close", (exitCode, signal) => resolve({ exitCode, signal }));
});
const stoppedAt = new Date().toISOString();
const streams = {};
for (const [name, chunks] of [["stdout", stdout], ["stderr", stderr]]) {
  const bytes = Buffer.concat(chunks);
  await writeFile(join(OUT, `${label}.${name}`), bytes, { flag: "wx" });
  streams[name] = { path: `${label}.${name}`, bytes: bytes.length, sha256: sha(bytes) };
}
await save(`${label}.command.json`, { executable, argv: args, cwd: OUT, pid: child.pid, startedAt, stoppedAt, ...close, streams, source });
console.log(JSON.stringify({ label, pid: child.pid, ...close, stdout: Buffer.concat(stdout).toString(), stderr: Buffer.concat(stderr).toString() }));
process.exitCode = close.exitCode ?? 1;
