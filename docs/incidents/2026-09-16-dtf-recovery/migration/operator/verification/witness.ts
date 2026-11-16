import assert from "node:assert/strict";
import { spawn } from "node:child_process";
import { once } from "node:events";
import { watch } from "node:fs";
import { readFile, writeFile } from "node:fs/promises";
import { dirname, join, resolve } from "node:path";
import { z } from "zod";

// Independent driver: never imports the operator's validation or assertion code.
const evidence = resolve("docs/incidents/2026-09-16-dtf-recovery/migration/operator/verification");
const cli = "scripts/recovery/dtf-migration/cli.ts";
const checkpoint = ".omo-runtime/dtf-migration-operator/checkpoints";
const manifestSchema = z.object({
  chainId: z.string(), proxy: z.string(), rpcEnv: z.string(),
  local: z.object({ instanceId: z.string() }),
}).passthrough();

async function command(args: readonly string[]) {
  const process_ = spawn(process.execPath, [cli, ...args], {
    env: { ...process.env, DTF_OPERATOR_LOCAL_RPC: "http://127.0.0.1:18560" },
    stdio: ["ignore", "pipe", "pipe"],
  });
  const closed = once(process_, "close", { signal: AbortSignal.timeout(3600000) });
  let stdout = "";
  let stderr = "";
  process_.stdout.on("data", (chunk: Buffer) => { stdout += chunk.toString(); });
  process_.stderr.on("data", (chunk: Buffer) => { stderr += chunk.toString(); });
  const [code, signal] = await closed;
  return { command: [process.execPath, cli, ...args], pid: process_.pid, code, signal, stdout, stderr };
}

async function publicNegatives(run: string) {
  const manifestPath = join(run, "pre-capture.json");
  const manifest = manifestSchema.parse(JSON.parse(await readFile(manifestPath, "utf8")));
  const cases = [
    {
      name: "synthetic-public-mode",
      args: ["deploy", "--manifest", manifestPath, "--checkpoint", join(evidence, "forbidden-public-journal"),
        "--broadcast", "--confirm-chain", manifest.chainId, "--confirm-proxy", manifest.proxy,
        "--confirm-snapshot", "uncaptured", "--signer-key-env", "INDEPENDENT_UNSET_SIGNING_KEY"],
      message: "fresh chain/proxy/snapshot confirmations required",
    },
    {
      name: "wrong-instance",
      args: ["deploy", "--manifest", manifestPath, "--checkpoint", join(evidence, "forbidden-instance-journal"),
        "--execute-local", "--instance-id", `0x${"1".repeat(64)}`],
      message: "explicit exact local identity required",
    },
  ];
  const results = [];
  for (const item of cases) {
    const result = await command(item.args);
    await writeFile(join(evidence, `${item.name}.json`), JSON.stringify(result, null, 2), { flag: "wx" });
    assert.equal(result.code, 1);
    const error = z.object({ error: z.literal("DOMAIN"), message: z.string() }).parse(JSON.parse(result.stderr));
    assert.equal(error.message, item.message);
    results.push({ name: item.name, code: result.code, error });
  }
  return results;
}

// Subscribe before the real CLI starts. A completed deploy log is the signal;
// the pre-capture manifest was fully written before that child was spawned.
let negativeRun: Promise<Awaited<ReturnType<typeof publicNegatives>>> | undefined;
let notify: () => void = () => undefined;
const signaled = new Promise<void>((resolve_) => { notify = resolve_; });
const watcher = watch(evidence, { recursive: true }, (_event, name) => {
  if (negativeRun || !name?.endsWith("002-deploy.log.command.json")) return;
  negativeRun = publicNegatives(dirname(join(evidence, name)));
  void negativeRun.catch(() => undefined);
  notify();
});
try {
  const run = await command(["rehearse", "--rpc-alias", "robinhood_mainnet_alchemy",
    "--fork-block", "108944663", "--port", "18560", "--checkpoint", checkpoint, "--evidence", evidence]);
  await writeFile(join(evidence, "independent-command.json"), JSON.stringify(run, null, 2), { flag: "wx" });
  assert.equal(run.code, 0, run.stderr);
  await Promise.race([signaled, new Promise<never>((_resolve, reject) => {
    AbortSignal.timeout(15000).addEventListener("abort", () => reject(new Error("deployment signal missing")), { once: true });
  })]);
  assert.ok(negativeRun);
  const negatives = await negativeRun;
  const output = z.object({ evidence: z.string(), fullTask9: z.literal("open"),
    status: z.literal("bounded-rehearsal-complete") }).parse(JSON.parse(run.stdout));
  await writeFile(join(evidence, "witness-result.json"), JSON.stringify({
    ...output, negatives, publicSigningKeyLoaded: false,
    independence: "Fresh actual CLI and Anvil; only evidence destination differs from fixed invocation.",
  }, null, 2), { flag: "wx" });
  console.log(`INDEPENDENT_REHEARSAL_COMPLETE ${output.evidence}`);
} finally {
  watcher.close();
}
