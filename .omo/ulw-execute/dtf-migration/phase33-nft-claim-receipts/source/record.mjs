import { spawn } from "node:child_process";
import { writeFile, readdir } from "node:fs/promises";
import { join } from "node:path";
import { OUT, check, identity, save } from "./inputs.mjs";

const mode = process.argv[2], label = process.argv[3] ?? mode;
check(["validate", "collect", "reconcile", "prove"].includes(mode) && /^[a-z][a-z0-9-]*$/.test(label), "record arguments");
const files = (await readdir(OUT)).filter(f => f.endsWith(".mjs"));
const sources = await Promise.all(files.map(f => identity(join(OUT, f))));
const invocations = mode === "validate"
  ? files.map(f => ({ executable: "/opt/homebrew/bin/node", argv: ["--check", join(OUT, f)] })).concat([
    { executable: process.execPath, argv: ["-e", `const m=await import(${JSON.stringify(join(OUT, "inputs.mjs"))}); const s=await m.intake(); console.log(JSON.stringify({rows:s.rows.length,refs:s.refs.length,bindings:s.bindings.length}));`] }])
  : [{ executable: process.execPath, argv: [join(OUT, `${mode}.mjs`), ...(mode === "prove" ? ["--verify"] : [])] }];
let failed = false;
for (let i = 0; i < invocations.length; i++) {
  const invocation = invocations[i], name = `${label}-${String(i + 1).padStart(2, "0")}`;
  const startedAt = new Date().toISOString();
  const childResult = await new Promise((resolve, reject) => {
    const child = spawn(invocation.executable, invocation.argv, { cwd: OUT, env: process.env, stdio: ["ignore", "pipe", "pipe"] });
    const stdout = [], stderr = [];
    child.stdout.on("data", b => stdout.push(b)); child.stderr.on("data", b => stderr.push(b));
    child.once("error", reject);
    child.once("close", (exitCode, signal) => resolve({ pid: child.pid, exitCode, signal,
      stdout: Buffer.concat(stdout), stderr: Buffer.concat(stderr) }));
  });
  const stoppedAt = new Date().toISOString(), streams = {};
  for (const stream of ["stdout", "stderr"]) {
    let bytes = childResult[stream], raw = true;
    for (const secret of [process.env.ALCHEMY_KEY, encodeURIComponent(process.env.ALCHEMY_KEY ?? "")].filter(Boolean)) {
      if (bytes.includes(Buffer.from(secret))) { bytes = Buffer.from(bytes.toString().replaceAll(secret, "<redacted>")); raw = false; }
    }
    const path = `${name}.${stream}`;
    await writeFile(join(OUT, path), bytes, { flag: "wx" });
    streams[stream] = { ...await identity(join(OUT, path)), raw };
  }
  await save(`${name}.command.json`, { ...invocation, cwd: OUT, startedAt, stoppedAt, pid: childResult.pid,
    exitCode: childResult.exitCode, signal: childResult.signal, childCloseObserved: true, sources, streams,
    runtime: { bun: Bun.version, platform: process.platform, arch: process.arch } });
  console.log(JSON.stringify({ command: name, exitCode: childResult.exitCode, signal: childResult.signal }));
  if (childResult.exitCode !== 0) failed = true;
}
process.exitCode = failed ? 1 : 0;
