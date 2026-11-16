// Independent verifier command recorder. No RPC or signer setup.
import { spawn } from "node:child_process";
import { once } from "node:events";
import { writeFile } from "node:fs/promises";
import { text } from "node:stream/consumers";
import assert from "node:assert/strict";

const [prefix, executable, ...args] = process.argv.slice(2);
assert.ok(prefix && executable, "output prefix and executable required");
const child = spawn(executable, args, {
  env: process.env, stdio: ["ignore", "pipe", "pipe"],
});
const completion = once(child, "exit", { signal: AbortSignal.timeout(120000) });
assert.ok(child.stdout && child.stderr);
const [stdout, stderr, exit] = await Promise.all([
  text(child.stdout), text(child.stderr), completion,
]);
await writeFile(`${prefix}.stdout`, stdout, { flag: "wx" });
await writeFile(`${prefix}.stderr`, stderr, { flag: "wx" });
await writeFile(`${prefix}.json`, `${JSON.stringify({
  executable, args, cwd: process.cwd(), exitCode: exit[0], signal: exit[1],
  stdout: `${prefix}.stdout`, stderr: `${prefix}.stderr`,
}, null, 2)}\n`, { flag: "wx" });
console.log(JSON.stringify({ prefix, exitCode: exit[0], signal: exit[1] }));
process.exitCode = typeof exit[0] === "number" ? exit[0] : 1;
