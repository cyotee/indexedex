import { spawn } from "node:child_process";
import { mkdir, appendFile, writeFile } from "node:fs/promises";
import { resolve, join } from "node:path";

const key = process.env.ALCHEMY_KEY;
if (!key) throw new Error("Existing login-shell archive credential is unavailable");
const label = process.argv[2] ?? "node";
if (!/^node(?:-\d+)?$/.test(label)) throw new Error("bounded node label required");
const directory = resolve(import.meta.dirname, "..", label);
await mkdir(directory, { recursive: false });
const command = "/Users/cyotee/.foundry/bin/anvil";
const args = ["--fork-url", "robinhood_mainnet_alchemy", "--fork-block-number", "108944663",
  "--chain-id", "4663", "--host", "127.0.0.1", "--port", "18579", "--accounts", "1",
  "--hardfork", "prague", "--no-mining", "--no-fork-node-info", "--no-bal",
  "--no-storage-caching", "--compute-units-per-second", "20", "--retries", "0",
  "--disable-default-create2-deployer"];
const child = spawn(command, args, { env: process.env, stdio: ["ignore", "pipe", "pipe"] });
await writeFile(join(directory, "start.json"), JSON.stringify({
  command, args, pid: child.pid, parentPid: process.pid, cwd: process.cwd(),
  existingCredentialPresent: true, started: new Date().toISOString(),
}, null, 2) + "\n", { flag: "wx" });
let pending = Promise.resolve();
for (const stream of [child.stdout, child.stderr]) {
  let carry = "";
  const line = text => {
    const safe = text.replaceAll(key, "[REDACTED]").replaceAll(encodeURIComponent(key), "[REDACTED]");
    pending = pending.then(() => appendFile(join(directory, "output.log"), safe + "\n"));
    process.stdout.write(safe + "\n");
  };
  stream.setEncoding("utf8");
  stream.on("data", chunk => {
    carry += chunk;
    const lines = carry.split("\n");
    carry = lines.pop() ?? "";
    for (const value of lines) line(value);
  });
  stream.on("end", () => { if (carry) line(carry); });
}
for (const signal of ["SIGINT", "SIGTERM"]) process.on(signal, () => child.kill("SIGTERM"));
const result = await new Promise((accept, reject) => {
  child.once("error", reject);
  child.once("close", (exitCode, signal) => accept({ exitCode, signal }));
});
await pending;
await writeFile(join(directory, "exit.json"), JSON.stringify({
  ...result, stopped: new Date().toISOString(), pid: child.pid,
}, null, 2) + "\n", { flag: "wx" });
console.log("NODE_EXIT", result.exitCode, result.signal);
