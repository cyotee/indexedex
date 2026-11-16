import { spawn } from "node:child_process";
import { writeFile, mkdir } from "node:fs/promises";
import { resolve, join } from "node:path";

const [label, command, ...args] = process.argv.slice(2);
if (!label || !command || !/^[a-z0-9-]+$/.test(label)) throw new Error("label and command required");
const directory = resolve(import.meta.dirname, "../checks");
await mkdir(directory, { recursive: true });
const started = new Date().toISOString();
const child = spawn(command, args, { env: process.env, stdio: ["ignore", "pipe", "pipe"] });
const out = [], err = [];
child.stdout.on("data", b => { out.push(b); process.stdout.write(b); });
child.stderr.on("data", b => { err.push(b); process.stderr.write(b); });
const result = await new Promise((accept, reject) => {
  child.once("error", reject);
  child.once("close", (exitCode, signal) => accept({ exitCode, signal }));
});
await writeFile(join(directory, `${label}.stdout`), Buffer.concat(out), { flag: "wx" });
await writeFile(join(directory, `${label}.stderr`), Buffer.concat(err), { flag: "wx" });
await writeFile(join(directory, `${label}.json`), JSON.stringify({
  command, args, cwd: process.cwd(), started, finished: new Date().toISOString(), ...result,
}, null, 2) + "\n", { flag: "wx" });
console.log("COMMAND_COMPLETE", label, result.exitCode, result.signal);
process.exit(result.exitCode ?? 1);
