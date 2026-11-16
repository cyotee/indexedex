// Owned command recorder. All argv are supplied explicitly; no chain, signer,
// credential lookup or alternate data root is implemented here.
import { spawn } from "node:child_process";
import { once } from "node:events";
import { writeFile } from "node:fs/promises";
import { text } from "node:stream/consumers";
const [prefix, executable, ...args] = process.argv.slice(2);
if (!prefix || !executable) throw new Error("prefix and executable required");
const child = spawn(executable, args, { env: process.env, stdio: ["ignore", "pipe", "pipe"] });
const done = once(child, "exit", { signal: AbortSignal.timeout(120000) });
if (!child.stdout || !child.stderr) throw new Error("missing command streams");
const [stdout, stderr, exit] = await Promise.all([text(child.stdout), text(child.stderr), done]);
await writeFile(`${prefix}.stdout`, stdout, { flag: "wx" });
await writeFile(`${prefix}.stderr`, stderr, { flag: "wx" });
await writeFile(`${prefix}.json`, `${JSON.stringify({
  cwd: process.cwd(), executable, args, exitCode: exit[0], signal: exit[1], stdout: `${prefix}.stdout`, stderr: `${prefix}.stderr`,
}, null, 2)}\n`, { flag: "wx" });
console.log(JSON.stringify({ prefix, exitCode: exit[0], signal: exit[1] }));
process.exitCode = typeof exit[0] === "number" ? exit[0] : 1;
