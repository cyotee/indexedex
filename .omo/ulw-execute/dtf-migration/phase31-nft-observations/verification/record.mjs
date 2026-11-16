import { spawn } from "node:child_process";
import { join } from "node:path";
import { writeFile } from "node:fs/promises";
import { OUT, check, save, identity } from "./intake.mjs";

const mode = process.argv[2];
check(["validate", "observe", "proof"].includes(mode), "unsupported recording mode");
const group = process.argv[3] ?? mode;
check(/^[a-z][a-z0-9-]*$/.test(group), "invalid command label");
const scripts = ["intake.mjs", "observe.mjs", "record.mjs", "proof.mjs", "finalize.mjs"];
const sources = await Promise.all(scripts.map(n => identity(join(OUT, n))));
const commands = mode === "validate" ? scripts.map(n => ({ executable: "/opt/homebrew/bin/node", argv: ["--check", join(OUT, n)] })) :
  [{ executable: process.execPath, argv: [join(OUT, `${mode === "proof" ? "proof" : "observe"}.mjs`)] }];
for (let i = 0; i < commands.length; i++) {
  const invocation = commands[i], startedAt = new Date().toISOString();
  const done = await new Promise((resolve, reject) => {
    const child = spawn(invocation.executable, invocation.argv, { cwd: OUT, env: process.env, stdio: ["ignore", "pipe", "pipe"] });
    const stdout = [], stderr = [];
    child.stdout.on("data", b => stdout.push(b)); child.stderr.on("data", b => stderr.push(b));
    child.once("error", reject);
    child.once("close", (exitCode, signal) => resolve({ pid: child.pid, exitCode, signal, stdout: Buffer.concat(stdout), stderr: Buffer.concat(stderr) }));
  });
  const label = `${group}-${String(i + 1).padStart(2, "0")}`, streams = {};
  for (const stream of ["stdout", "stderr"]) {
    let bytes = done[stream], raw = true;
    for (const secret of [process.env.ALCHEMY_KEY, encodeURIComponent(process.env.ALCHEMY_KEY ?? "")].filter(Boolean)) {
      if (bytes.includes(Buffer.from(secret))) { bytes = Buffer.from(bytes.toString().replaceAll(secret, "<redacted>")); raw = false; }
    }
    const path = join(OUT, `${label}.${stream}`);
    await writeFile(path, bytes, { flag: "wx" });
    streams[stream] = { ...await identity(path), raw };
  }
  await save(`${label}.command.json`, { ...invocation, cwd: OUT, startedAt, stoppedAt: new Date().toISOString(),
    pid: done.pid, exitCode: done.exitCode, signal: done.signal, childCloseObserved: true, sources, streams, bun: Bun.version });
  console.log(JSON.stringify({ label, exitCode: done.exitCode, signal: done.signal }));
  if (done.exitCode !== 0) { process.exitCode = done.exitCode ?? 2; break; }
}
