import { spawn } from "node:child_process";
import { writeFile, readdir } from "node:fs/promises";
import { join } from "node:path";
import { OUT, fact, identity, text } from "./common.mjs";

const [label, script] = process.argv.slice(2);
fact(/^[a-z0-9-]+$/.test(label ?? "") && /^[a-z]+\.mjs$/.test(script ?? ""), "record label/script");
const startedAt = new Date().toISOString();
const sources = [];
for (const name of (await readdir(OUT)).filter(x => x.endsWith(".mjs")).sort()) sources.push(await identity(join(OUT, name)));
const child = spawn(process.execPath, [join(OUT, script)], { cwd: OUT, env: process.env, stdio: ["ignore", "pipe", "pipe"] });
const stdout = [], stderr = [];
child.stdout.on("data", chunk => stdout.push(chunk));
child.stderr.on("data", chunk => stderr.push(chunk));
const closed = new Promise((resolve, reject) => {
  child.once("error", reject);
  child.once("close", (exit, signal) => resolve({ exit, signal }));
});
const result = await closed;
const finishedAt = new Date().toISOString();
await writeFile(join(OUT, `${label}.stdout`), Buffer.concat(stdout), { flag: "wx" });
await writeFile(join(OUT, `${label}.stderr`), Buffer.concat(stderr), { flag: "wx" });
await writeFile(join(OUT, `${label}.command.json`), text({ executable: process.execPath, argv: [join(OUT, script)],
  cwd: OUT, pid: child.pid, startedAt, finishedAt, ...result, sources,
  stdout: await identity(join(OUT, `${label}.stdout`)), stderr: await identity(join(OUT, `${label}.stderr`)) }), { flag: "wx" });
console.log(`STOPPED ${label} exit=${result.exit} signal=${result.signal}`);
process.exitCode = result.exit ?? 1;
