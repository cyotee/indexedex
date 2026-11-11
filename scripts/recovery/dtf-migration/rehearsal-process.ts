import { spawn } from "node:child_process";
import type { ChildProcess } from "node:child_process";
import { once } from "node:events";
import { writeFile } from "node:fs/promises";
import { join } from "node:path";
import { ExecutionError } from "./execution-schema.js";

export const FOUNDRY = "/Users/cyotee/.foundry/bin";
export async function child(command: readonly string[], evidence: string, environment = process.env) {
  const executable = command[0];
  if (!executable) throw new ExecutionError("DOMAIN", "empty command");
  const process_ = spawn(executable, command.slice(1), { env: environment, stdio: ["ignore", "pipe", "pipe"] });
  const exited = once(process_, "close", { signal: AbortSignal.timeout(3600000) });
  let output = "";
  process_.stdout?.on("data", (data: Buffer) => { output += data.toString(); });
  process_.stderr?.on("data", (data: Buffer) => { output += data.toString(); });
  let result: unknown[];
  try { result = await exited; }
  catch (error) { await stopProcess(process_); throw error; }
  const [code, signal] = result;
  await writeFile(evidence, output, { flag: "wx" });
  await writeFile(`${evidence}.command.json`, JSON.stringify({ command, code, signal }), { flag: "wx" });
  return { code, signal, output };
}

export async function launchAnvil(args: readonly string[], evidence: string, secret: string) {
  const process_ = spawn(join(FOUNDRY, "anvil"), [...args], { env: process.env, stdio: ["ignore", "pipe", "pipe"] });
  let output = "";
  const scrub = (text: string) => text.replaceAll(secret, "<redacted-upstream>");
  const ready = new Promise<void>((resolve, reject) => {
    const signal = AbortSignal.timeout(30000);
    const abort = () => reject(new ExecutionError("RPC", "Anvil did not emit readiness before deadline"));
    signal.addEventListener("abort", abort, { once: true });
    const data = (chunk: Buffer) => {
      output += scrub(chunk.toString());
      if (output.includes("Listening on")) {
        signal.removeEventListener("abort", abort);
        resolve();
      }
    };
    process_.stdout?.on("data", data);
    process_.stderr?.on("data", data);
    process_.once("error", reject);
    process_.once("exit", (code) => reject(new ExecutionError("RPC", `Anvil exited before readiness: ${code}`)));
  });
  try { await ready; }
  catch (error) {
    await stopProcess(process_);
    await writeFile(evidence, output, { flag: "wx" });
    throw error;
  }
  return {
    pid: process_.pid,
    async close() {
      await stopProcess(process_);
      await writeFile(evidence, output, { flag: "wx" });
    },
  };
}

async function stopProcess(process_: ChildProcess) {
  if (process_.exitCode !== null || process_.signalCode !== null) return;
  const exited = once(process_, "exit", { signal: AbortSignal.timeout(15000) });
  process_.kill("SIGTERM");
  await exited;
}
