import { spawn } from "node:child_process";
import { writeFile } from "node:fs/promises";
import { join } from "node:path";
import { OUT, identity, save, requireFact } from "./evidence.mjs";

const mode = process.argv[2];
requireFact(["validate", "observe", "prove"].includes(mode), "record mode must be validate, observe or prove");
const label = process.argv[3] ?? mode;
requireFact(/^[a-z][a-z0-9-]*$/.test(label), "invalid command label");
const files = ["evidence.mjs", "rpc.mjs", "observe.mjs", "record.mjs", "prove.mjs", "seal.mjs"];
const sourceIdentities = await Promise.all(files.map(f => identity(join(OUT, f))));
const invocations = mode === "validate"
  ? files.map(f => ({ executable: "/opt/homebrew/bin/node", argv: ["--check", join(OUT, f)] })).concat([
    { executable: process.execPath, argv: ["-e", `const m=await import(${JSON.stringify(join(OUT, "evidence.mjs"))}); const s=await m.intake(); console.log(JSON.stringify({rows:s.rows.length,bindings:s.bindings.length,flows:s.rows.reduce((n,r)=>n+r.joinedRecipientFlow.length,0)}));`] }])
  : [{ executable: process.execPath, argv: [join(OUT, `${mode}.mjs`)] }];
let failed = false;
for (let i = 0; i < invocations.length; i++) {
  const invocation = invocations[i], name = `${label}-${String(i + 1).padStart(2, "0")}`;
  const startedAt = new Date().toISOString();
  const result = await new Promise((resolve, reject) => {
    const child = spawn(invocation.executable, invocation.argv, { cwd: OUT, env: process.env, stdio: ["ignore", "pipe", "pipe"] });
    const stdout = [], stderr = [];
    child.stdout.on("data", b => stdout.push(b));
    child.stderr.on("data", b => stderr.push(b));
    child.once("error", reject);
    child.once("close", (exitCode, signal) => resolve({ pid: child.pid, exitCode, signal,
      stdout: Buffer.concat(stdout), stderr: Buffer.concat(stderr) }));
  });
  const streams = {};
  for (const stream of ["stdout", "stderr"]) {
    let bytes = result[stream], raw = true;
    for (const secret of [process.env.ALCHEMY_KEY, encodeURIComponent(process.env.ALCHEMY_KEY ?? "")].filter(Boolean)) {
      if (bytes.includes(Buffer.from(secret))) { bytes = Buffer.from(bytes.toString().replaceAll(secret, "<redacted>")); raw = false; }
    }
    const path = `${name}.${stream}`;
    await writeFile(join(OUT, path), bytes, { flag: "wx" });
    streams[stream] = { ...await identity(join(OUT, path)), raw };
  }
  await save(`${name}.command.json`, { executable: invocation.executable, argv: invocation.argv, cwd: OUT, startedAt,
    stoppedAt: new Date().toISOString(), pid: result.pid, exitCode: result.exitCode, signal: result.signal,
    runtime: { bun: Bun.version, platform: process.platform, arch: process.arch }, sourceIdentities, streams,
    selectedProvider: mode === "observe" ? "robinhood_mainnet_alchemy" : null, childCloseObserved: true });
  console.log(JSON.stringify({ command: name, exitCode: result.exitCode, signal: result.signal }));
  if (result.exitCode !== 0) failed = true;
}
process.exitCode = failed ? 1 : 0;
