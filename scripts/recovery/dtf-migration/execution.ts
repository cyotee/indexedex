import { readFile, readdir, open } from "node:fs/promises";
import { join } from "node:path";
import { Transaction, keccak256 } from "ethers";
import { z } from "zod";
import { canonical, fingerprint } from "./provenance.js";
import { checkRelationships, loadExecution } from "./execution-domain.js";
import type { ExecutionDomain } from "./execution-domain.js";
import { plan } from "./execution-plan.js";
import { Rpc, subscribeReceipt } from "./execution-rpc.js";
import { captureCompletion, verifyConfiguration } from "./execution-state.js";
import { deploymentGasLimit, ExecutionError, intent, quantity, stage as stageSchema } from "./execution-schema.js";
import type { Intent, Mode, Operation, Stage } from "./execution-schema.js";
import { Journal } from "./journal.js";
import { hash, hex } from "./schema.js";

type Run = {
  readonly command: Stage | "resume";
  readonly manifestPath: string;
  readonly checkpoint: string;
  readonly mode: Mode;
  readonly reverse: boolean;
  readonly faultAfterMined: boolean;
};
const runSchema = z.object({ stage: stageSchema, operationIds: z.array(z.string()) }).strict();

function validateIntent(record: Intent, operation: Operation): void {
  const signed = Transaction.from(record.signedTransaction);
  if (operation.stage === "deploy" && signed.gasLimit > deploymentGasLimit) {
    throw new ExecutionError("INTENT", "deployment intent exceeds target transaction gas limit");
  }
  if (record.id !== operation.id || record.stage !== operation.stage || record.method !== operation.method
    || canonical(record.transaction) !== canonical(operation.transaction)
    || signed.hash !== record.transactionHash || signed.from?.toLowerCase() !== operation.transaction.from
    || signed.to?.toLowerCase() !== operation.transaction.to || signed.data !== operation.transaction.data
    || signed.value.toString() !== operation.transaction.value || String(signed.nonce) !== record.nonce) {
    throw new ExecutionError("INTENT", "signed transaction does not match fixed stage operation");
  }
}

async function reconcile(rpc: Rpc, domain: ExecutionDomain, journal: Journal, record: Intent) {
  const saved = await journal.completed(record);
  const mined = await rpc.canonicalReceipt(record.transactionHash);
  if (!mined) {
    if (saved) throw new ExecutionError("AMBIGUOUS", "completed receipt disappeared; no replay permitted");
    const found = await rpc.send("eth_getTransactionByHash", [record.transactionHash]);
    if (found !== null) throw new ExecutionError("AMBIGUOUS", "transaction exists without canonical receipt; no resend");
    if (await rpc.nonce("latest") !== BigInt(record.nonce) || await rpc.nonce("pending") !== BigInt(record.nonce)) {
      throw new ExecutionError("AMBIGUOUS", "nonce moved without known canonical receipt; no resend");
    }
    return undefined;
  }
  const actual = z.object({ hash, from: z.string(), to: z.string().nullable(), input: hex,
    value: quantity, nonce: quantity, blockHash: hash }).passthrough().parse(
    await rpc.send("eth_getTransactionByHash", [record.transactionHash]));
  if (actual.hash !== record.transactionHash || actual.from.toLowerCase() !== record.transaction.from
    || actual.to?.toLowerCase() !== record.transaction.to || actual.input !== record.transaction.data
    || BigInt(actual.nonce).toString() !== record.nonce || actual.blockHash !== mined.blockHash
    || BigInt(actual.value).toString() !== record.transaction.value) throw new ExecutionError("INTENT", "canonical transaction differs");
  const result = await captureCompletion(rpc, domain, record, mined);
  if (saved && canonical(saved) !== canonical(result)) throw new ExecutionError("STATE", "canonical receipt/state differs from checkpoint");
  if (!saved) await journal.complete(record, result);
  return result;
}

export async function execute(run: Run) {
  const domain = await loadExecution(run.manifestPath);
  const rpc = new Rpc(domain.manifest);
  try {
    await rpc.guard(run.mode);
    const storedRun = run.command === "resume" ? runSchema.parse(
      JSON.parse(await readFile(join(run.checkpoint, "run.json"), "utf8"))) : undefined;
    const selected = storedRun?.stage ?? stageSchema.parse(run.command);
    if (storedRun && canonical(JSON.parse(await readFile(join(run.checkpoint, "domain.json"), "utf8"))) !== canonical(domain.domain)) {
      throw new ExecutionError("DOMAIN", "checkpoint domain changed");
    }
    await checkRelationships(rpc, domain, selected === "deploy");
    if (selected === "verify") return { mode: "read-only", command: selected, verification: await verifyConfiguration(rpc, domain) };
    if (selected === "activate") {
      const verified = await verifyConfiguration(rpc, domain);
      for (const request of domain.prepared?.payloads.independentIssue.requests ?? []) {
        if (!verified.rows.some((row) => row.recipient === request.recipient && row.issued)) {
          throw new ExecutionError("STATE", "selected independent issuance is unfinished");
        }
      }
    }
    const operations = plan(domain, selected);
    if (new Set(operations.map((o) => o.id)).size !== operations.length) throw new ExecutionError("INTENT", "duplicate operation identity");
    if (run.reverse && !["configure", "independent-issue"].includes(selected)) throw new ExecutionError("DOMAIN", "only independent unsettled rows may reorder");
    if (storedRun && canonical([...storedRun.operationIds].sort()) !== canonical(operations.map((o) => o.id).sort())) {
      throw new ExecutionError("DOMAIN", "resume plan differs");
    }
    if (run.faultAfterMined && (run.mode.kind !== "local" || domain.manifest.purpose !== "synthetic-local")) {
      throw new ExecutionError("DOMAIN", "fault injection is synthetic-local only");
    }
    if (run.mode.kind === "simulate") {
      // No wallet, send, inherited mode, or success receipt on the default path.
      return { mode: "read-only", command: selected, domainHash: fingerprint(canonical(domain.domain)),
        operationIds: operations.map((o) => o.id), fullTask9: "open" };
    }
    const journal = await Journal.acquire(run.checkpoint, domain.domain);
    try {
      const runPath = join(run.checkpoint, "run.json");
      const expectedRun = { stage: selected, operationIds: operations.map((o) => o.id) };
      if ((await readdir(run.checkpoint)).includes("run.json")) {
        const previous = runSchema.parse(JSON.parse(await readFile(runPath, "utf8")));
        if (canonical(previous) !== canonical(expectedRun)) throw new ExecutionError("DOMAIN", "checkpoint command changed");
      } else {
        const file = await open(runPath, "wx", 0o600);
        try { await file.writeFile(canonical(expectedRun)); await file.sync(); } finally { await file.close(); }
        await journal.syncDirectory();
      }
      const existing = await journal.intents();
      for (const record of existing) {
        const operation = operations.find((o) => o.id === record.id);
        if (!operation) throw new ExecutionError("INTENT", "checkpoint contains unselected operation");
        validateIntent(record, operation);
        if (Transaction.from(record.signedTransaction).chainId.toString() !== domain.manifest.chainId) {
          throw new ExecutionError("DOMAIN", "signed transaction chain changed");
        }
      }
      const results = [];
      // Resolve every prior intent before assigning another nonce, regardless of batching.
      for (const record of existing) {
        const result = await reconcile(rpc, domain, journal, record);
        if (result) results.push(result);
      }
      for (const operation of run.reverse ? [...operations].reverse() : operations) {
        let record = existing.find((i) => i.id === operation.id);
        if (record && await journal.completed(record)) continue;
        await rpc.guard(run.mode);
        if (!record) {
          const nonce = await rpc.nonce("pending");
          if (nonce !== await rpc.nonce("latest")) throw new ExecutionError("AMBIGUOUS", "signer has pending unrelated transaction");
          const { from, to, data, value } = operation.transaction;
          // Exact finite ABI operation is simulated before signing. No retry after a revert.
          const simulationInput = { from, to, data, value: `0x${BigInt(value).toString(16)}`,
            ...(operation.stage === "deploy" ? { gas: `0x${deploymentGasLimit.toString(16)}` } : {}) };
          let simulated: string;
          try { simulated = hex.parse(await rpc.send("eth_call", [simulationInput, "latest"])); }
          catch (error) {
            if (run.mode.kind === "local") {
              const trace = await rpc.send("debug_traceCall", [simulationInput, "latest", { tracer: "callTracer" }]);
              const file = await open(join(run.checkpoint, `${operation.id}.simulation-failure.json`), "wx", 0o600);
              try { await file.writeFile(canonical({ operation, trace })); await file.sync(); } finally { await file.close(); }
            }
            throw error;
          }
          if (operation.method === "deployVault"
            && String(domain.abis.pkg.decodeFunctionResult("deployVault", simulated)[0]).toLowerCase() !== domain.manifest.proxy) {
            throw new ExecutionError("DOMAIN", "package deployment does not predict bound proxy");
          }
          const estimate = BigInt(quantity.parse(await rpc.send("eth_estimateGas", [simulationInput])));
          if (operation.stage === "deploy" && estimate > deploymentGasLimit) {
            throw new ExecutionError("STATE", "deployment estimate exceeds target transaction gas limit");
          }
          const bufferedGas = estimate * 3n / 2n;
          const gasLimit = operation.stage === "deploy" && bufferedGas > deploymentGasLimit
            ? deploymentGasLimit : bufferedGas;
          const gasPrice = BigInt(quantity.parse(await rpc.send("eth_gasPrice", [])));
          if (nonce > BigInt(Number.MAX_SAFE_INTEGER)) throw new ExecutionError("INTENT", "nonce exceeds signer safe range");
          const raw = await rpc.wallet(run.mode).signTransaction({
            chainId: BigInt(domain.manifest.chainId), nonce: Number(nonce), to, data, value: BigInt(value),
            gasLimit, gasPrice, type: 0,
          });
          record = intent.parse({ version: "dtf-operator-intent-v1", domainHash: journal.domainHash,
            id: operation.id, stage: operation.stage, method: operation.method, transaction: operation.transaction,
            nonce: nonce.toString(), startBlock: BigInt((await rpc.header()).number).toString(),
            signedTransaction: raw, transactionHash: keccak256(raw) });
          await journal.persistIntent(record);
        }
        const watch = await subscribeReceipt(rpc, record.transactionHash);
        try {
          const sent = hash.parse(await rpc.send("eth_sendRawTransaction", [record.signedTransaction]));
          if (sent !== record.transactionHash) throw new ExecutionError("INTENT", "node returned another transaction hash");
          const mined = await watch.mined();
          if (run.faultAfterMined && ["prepareSyChildren", "donateMigrationCapital", "issueIndependentAllocations", "bond"].includes(record.method)) {
            console.log(JSON.stringify({ fault: "mined-before-checkpoint", transactionHash: mined.transactionHash, nonce: record.nonce }));
            process.kill(process.pid, "SIGKILL");
          }
          const result = await reconcile(rpc, domain, journal, record);
          if (!result) throw new ExecutionError("AMBIGUOUS", "mined transaction disappeared");
          results.push(result);
        } finally { watch.close(); }
      }
      return { command: selected, mode: run.mode.kind, receipts: results, fullTask9: "open" };
    } finally { await journal.close(); }
  } finally { rpc.close(); }
}
