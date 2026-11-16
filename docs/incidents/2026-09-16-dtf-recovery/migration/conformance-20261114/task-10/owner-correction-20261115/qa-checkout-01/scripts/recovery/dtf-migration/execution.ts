// allow: SIZE_OK - One ordered durable transaction state machine; this scoped repair preserves its existing boundaries.
import { readFile, readdir, open } from "node:fs/promises";
import { dirname, join } from "node:path";
import { Interface, Transaction, keccak256 } from "ethers";
import { z } from "zod";
import { canonical, fingerprint } from "./provenance.js";
import { checkRelationships, loadExecution, acceptedContext, nextBookId, verifyDeployment, verifyEmptyCensus, requirePrepared } from "./execution-domain.js";
import type { ExecutionDomain } from "./execution-domain.js";
import { plan } from "./execution-plan.js";
import { Rpc, subscribeReceipt } from "./execution-rpc.js";
import { captureCompletion, verifyConfiguration, selectedConfiguration, configurationKey, verifyRow } from "./execution-state.js";
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

export function validateIntent(record: Intent, operation: Operation, chainId: string): void {
  const signed = Transaction.from(record.signedTransaction);
  if (operation.stage === "deploy" && signed.gasLimit > deploymentGasLimit) {
    throw new ExecutionError("INTENT", "deployment intent exceeds target transaction gas limit");
  }
  if (record.id !== operation.id || record.stage !== operation.stage || record.method !== operation.method
    || canonical(record.transaction) !== canonical(operation.transaction)
    || signed.hash !== record.transactionHash || signed.from?.toLowerCase() !== operation.transaction.from
    || signed.to?.toLowerCase() !== operation.transaction.to || signed.data !== operation.transaction.data
    || signed.value.toString() !== operation.transaction.value || String(signed.nonce) !== record.nonce
    || signed.chainId.toString() !== chainId || signed.gasLimit.toString() !== record.gasLimit
    || signed.gasPrice?.toString() !== record.gasPrice) {
    throw new ExecutionError("INTENT", "signed transaction does not match fixed stage operation");
  }
}

export async function preflightOperation(rpc: Rpc, domain: ExecutionDomain, operation: Operation, mode: Mode): Promise<void> {
  const m = domain.manifest;
  if (operation.stage === "configure") {
    const { key, row } = selectedConfiguration(domain, operation);
    const current = await rpc.call(m.proxy, domain.abis.migration, "migrationWeightedPricing");
    if (current[0].id !== row.pricing.bookId) throw new ExecutionError("STATE", "load book differs from current manual book");
    if (mode.kind === "broadcast" && mode.bookId !== row.pricing.bookId) throw new ExecutionError("DOMAIN", "fresh selected book confirmation required");
    if (row.pricing.kind !== "load") throw new ExecutionError("INTENT", "retained configuration cannot be sent");
    const accepted = row.pricing.replaces;
    if (accepted) {
      const context = await acceptedContext(accepted, requirePrepared(domain).input, new Set(), m.bundle);
      const prior = context.domain.prepared?.payloads.configure[key].find((r) => r.configurationId === accepted.configurationId);
      if (!prior) throw new ExecutionError("STATE", "missing exact replaced configuration");
      await verifyRow(rpc, context.domain, key, prior);
    } else {
      const getter = key === "independent" ? "independentAllocation" : key === "nfts" ? "nftEntitlement" : key + "Entitlement";
      const actual = (await rpc.call(m.proxy, domain.abis.migration, getter, configurationKey(row)))[0];
      if (actual.configurationId !== `0x${"0".repeat(64)}`) throw new ExecutionError("STATE", "unexpected existing configuration; explicit replacement required");
    }
    const input = row.input;
    const originals = "recipient" in input ? input.entitlements : "contributions" in row ? row.contributions : [input];
    for (const original of originals) {
      const expected = domain.prepared?.quoteEvidence.quotes.find((q) => q.bookId === row.pricing.bookId
        && q.originalEth === original.originalEth && q.originalDtf === original.originalDtf);
      const actual = await rpc.call(m.proxy, domain.abis.migration, "previewOriginalCredit", [original.originalEth, original.originalDtf]);
      if (!expected || String(actual[0]) !== expected.credit) throw new ExecutionError("STATE", "fresh manual-book quote changed");
    }
  } else if (operation.stage === "set-pricing") {
    const expected = nextBookId(domain);
    if (m.bookId !== expected || (mode.kind === "broadcast" && mode.bookId !== expected)) {
      throw new ExecutionError("DOMAIN", "selected next manual book differs");
    }
  } else if (operation.stage === "independent-issue") {
    const selected = domain.abis.allocation.decodeFunctionData(operation.method, operation.transaction.data)[0];
    for (const request of selected) {
      const row = domain.prepared?.payloads.configure.independent.find((r) => r.input.recipient === String(request.recipient).toLowerCase());
      if (!row || request.configurationId !== row.configurationId) throw new ExecutionError("INTENT", "unbound independent issue");
      await verifyRow(rpc, domain, "independent", row);
      if ((await rpc.call(m.proxy, domain.abis.migration, "independentIssuance", [row.input.recipient]))[0].issued) {
        throw new ExecutionError("STATE", "recipient is already issued; immutable history required");
      }
    }
  } else if (operation.stage === "owner-bond" && !domain.prepared) {
    await verifyEmptyCensus(rpc, domain);
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
    if (selected !== "deploy") await verifyDeployment(rpc, domain);
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
    if (run.reverse && !["configure", "independent-issue"].includes(selected)) throw new ExecutionError("DOMAIN", "only independent unsettled rows may reorder");
    if (storedRun && canonical([...storedRun.operationIds].sort()) !== canonical(operations.map((o) => o.id).sort())) {
      throw new ExecutionError("DOMAIN", "resume plan differs");
    }
    if (run.faultAfterMined && (run.mode.kind !== "local" || domain.manifest.purpose !== "synthetic-local")) {
      throw new ExecutionError("DOMAIN", "fault injection is synthetic-local only");
    }
    if (run.mode.kind === "simulate") {
      const saved = await Journal.inspect(run.checkpoint, domain.domain);
      const minedIds = new Set<string>();
      for (const record of await saved?.intents() ?? []) {
        const operation = operations.find((o) => o.id === record.id);
        if (!operation) throw new ExecutionError("INTENT", "checkpoint contains unselected operation");
        validateIntent(record, operation, domain.manifest.chainId);
        const mined = await rpc.canonicalReceipt(record.transactionHash);
        const completion = await saved?.completed(record);
        if (mined) {
          const actual = await captureCompletion(rpc, domain, record, mined);
          if (completion && canonical(completion) !== canonical(actual)) throw new ExecutionError("STATE", "saved completion differs");
          minedIds.add(record.id);
        } else if (completion) throw new ExecutionError("AMBIGUOUS", "completed receipt disappeared");
      }
      for (const operation of operations) if (!minedIds.has(operation.id)) await preflightOperation(rpc, domain, operation, run.mode);
      // No wallet, send, inherited mode, or success receipt on the default path.
      return { mode: "read-only", command: selected, domainHash: fingerprint(canonical(domain.domain)),
        operationIds: operations.map((o) => o.id), fullTask9: "open" };
    }
    const journal = await Journal.acquire(run.checkpoint, domain.domain, dirname(run.checkpoint));
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
        validateIntent(record, operation, domain.manifest.chainId);
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
        if (record?.stage === "set-pricing") {
          const unset = new Interface(["error MigrationWeightedPricingNotSet()"]).getError("MigrationWeightedPricingNotSet")?.selector;
          const readBook = async (at: string): Promise<string | null> => {
            try { return hash.parse((await rpc.call(domain.manifest.proxy, domain.abis.migration, "migrationWeightedPricing", [], at))[0].id); }
            catch (error) {
              if (error instanceof ExecutionError && error.code === "RPC" && unset
                && error.message === `eth_call failed; revert=${unset}; endpoint redacted`) return null;
              throw error;
            }
          };
          if (await readBook(`0x${BigInt(record.startBlock).toString(16)}`) !== await readBook("latest")) {
            throw new ExecutionError("INTENT", "unsent setter cannot roll back a later book; select a new immutable execution");
          }
        }
        await preflightOperation(rpc, domain, operation, run.mode);
        if (record) {
          const gasPrice = BigInt(quantity.parse(await rpc.send("eth_gasPrice", [])));
          if (gasPrice.toString() !== record.gasPrice) throw new ExecutionError("INTENT", "unsent signed gas price changed");
          const { from, to, data, value } = operation.transaction;
          const input = { from, to, data, value: `0x${BigInt(value).toString(16)}`,
            ...(operation.stage === "deploy" ? { gas: `0x${deploymentGasLimit.toString(16)}` } : {}) };
          await rpc.send("eth_call", [input, "latest"]);
          const estimate = BigInt(quantity.parse(await rpc.send("eth_estimateGas", [input])));
          const buffered = estimate * 3n / 2n;
          const gas = operation.stage === "deploy" && buffered > deploymentGasLimit ? deploymentGasLimit : buffered;
          if (gas.toString() !== record.gasLimit) throw new ExecutionError("INTENT", "unsent signed gas limit changed");
        }
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
          record = intent.parse({ version: "dtf-operator-intent-v2", domainHash: journal.domainHash,
            id: operation.id, stage: operation.stage, method: operation.method, transaction: operation.transaction,
            nonce: nonce.toString(), startBlock: BigInt((await rpc.header()).number).toString(),
            gasLimit: gasLimit.toString(), gasPrice: gasPrice.toString(),
            signedTransaction: raw, transactionHash: keccak256(raw) });
          await journal.persistIntent(record);
        }
        const watch = await subscribeReceipt(rpc, record.transactionHash);
        try {
          const sent = hash.parse(await rpc.send("eth_sendRawTransaction", [record.signedTransaction]));
          if (sent !== record.transactionHash) throw new ExecutionError("INTENT", "node returned another transaction hash");
          const mined = await watch.mined();
          if (run.faultAfterMined && BigInt(mined.status) === 1n && (record.stage === "configure"
            || ["prepareSyChildren", "donateMigrationCapital", "issueIndependentAllocations", "bond"].includes(record.method))) {
            console.log(JSON.stringify({ fault: "mined-before-checkpoint", transactionHash: mined.transactionHash, nonce: record.nonce }));
            process.kill(process.pid, "SIGKILL");
          }
          const result = await reconcile(rpc, domain, journal, record);
          if (!result) throw new ExecutionError("AMBIGUOUS", "mined transaction disappeared");
          results.push(result);
        } finally { watch.close(); }
      }
      await journal.finish(operations.map((o) => o.id));
      return { state: "complete", command: selected, mode: run.mode.kind, receipts: results, fullTask9: "open" };
    } catch (error) {
      await journal.blocked(error);
      throw error;
    } finally { await journal.close(); }
  } finally { rpc.close(); }
}
