import { readFile, readdir } from "node:fs/promises";
import { join, basename } from "node:path";
import { keccak256 } from "ethers";
import { z } from "zod";
import { canonical, fingerprint } from "./provenance.js";
import { completion, intent, ExecutionError, quantity } from "./execution-schema.js";
import type { Intent, Receipt } from "./execution-schema.js";
import type { PreparationInput } from "./schema.js";
import { address, hex } from "./schema.js";
import type { RehearsalChain } from "./rehearsal-chain.js";
import { save } from "./rehearsal-data.js";
import { DEV } from "./execution-rpc.js";
import { preparationInput } from "./schema.js";
import { loadExecution } from "./execution-domain.js";
import { plan } from "./execution-plan.js";
import { Journal } from "./journal.js";
import { claimedWallet } from "./rehearsal-claimed-sy-source.js";
import { reconciledFixtureInput, RECIPIENTS } from "./rehearsal-data.js";
import { rejectTamperedCompletions } from "./rehearsal-recovery.js";


/** Capture actual transitive library runtimes at the addresses linked into deployed code. */
export async function captureLinkedLibraries(
  chain: RehearsalChain, facets: readonly { readonly name: string; readonly code: string }[], evidence: string,
) {
  const references = z.object({ deployedBytecode: z.object({ linkReferences:
    z.record(z.string(), z.record(z.string(), z.array(z.object({ start: z.number(), length: z.literal(20) })))).default({}),
  }).passthrough() }).passthrough();
  const pending = facets.map((facet) => ({ ...facet, source: `${facet.name}.sol` }));
  const libraries = new Map<string, { address: string; name: string; source: string; code: string; codeHash: string }>();
  for (let index = 0; index < pending.length; index++) {
    const consumer = pending[index];
    if (!consumer) throw new ExecutionError("STATE", "missing runtime consumer");
    const artifact = references.parse(JSON.parse(await readFile(
      join("out", basename(consumer.source), `${consumer.name}.json`), "utf8")));
    for (const [source, names] of Object.entries(artifact.deployedBytecode.linkReferences)) {
      for (const [name, slots] of Object.entries(names)) for (const slot of slots) {
        const linked = address.parse(`0x${consumer.code.slice(2 + slot.start * 2, 2 + (slot.start + slot.length) * 2)}`);
        const prior = libraries.get(linked);
        if (prior) {
          if (prior.name !== name || prior.source !== source) throw new ExecutionError("STATE", "library identity conflict");
          continue;
        }
        const code = hex.parse(await chain.send("eth_getCode", [linked, "latest"]));
        if (code === "0x" || (code.length - 2) / 2 > 24576) {
          throw new ExecutionError("STATE", "linked library is missing or exceeds EIP170");
        }
        const library = { address: linked, name, source, code, codeHash: keccak256(code) };
        libraries.set(linked, library);
        pending.push(library);
      }
    }
  }
  await save(join(evidence, "linked-library-runtime.json"), [...libraries.values()]);
}

export async function interruptedReceipt(chain: RehearsalChain, checkpoint: string, evidence: string) {
  const files = await readdir(checkpoint);
  const incomplete = files.filter((name) => name.endsWith(".intent.json")
    && !files.includes(name.replace(".intent.json", ".receipt.json")));
  if (incomplete.length !== 1 || !incomplete[0]) throw new ExecutionError("STATE", "expected one mined incomplete intent");
  const record = intent.parse(JSON.parse(await readFile(join(checkpoint, incomplete[0]), "utf8")));
  const mined = await chain.canonicalReceipt(record.transactionHash);
  if (!mined || BigInt(mined.status) !== 1n) throw new ExecutionError("STATE", "interrupted intent lacks successful canonical receipt");
  const actual = z.object({ hash: z.string(), nonce: z.string() }).passthrough().parse(
    await chain.send("eth_getTransactionByHash", [record.transactionHash]));
  if (actual.hash !== record.transactionHash || BigInt(actual.nonce).toString() !== record.nonce) {
    throw new ExecutionError("STATE", "interrupted transaction identity differs");
  }
  await save(evidence, { intent: record, receipt: mined, transaction: actual, completionPresent: false });
  return { intent: record, receipt: mined };
}

export async function recoveredReceipt(
  before: { readonly intent: Intent; readonly receipt: Receipt }, checkpoint: string, evidence: string,
) {
  const after = completion.parse(JSON.parse(await readFile(join(checkpoint, `${before.intent.id}.receipt.json`), "utf8")));
  if (after.intentHash !== fingerprint(canonical(before.intent)) || canonical(after.receipt) !== canonical(before.receipt)) {
    throw new ExecutionError("STATE", "resume did not recover the identical mined transaction");
  }
  await save(evidence, { transactionHash: before.intent.transactionHash, nonce: before.intent.nonce,
    sameCanonicalReceipt: true, events: after.events, state: after.state });
}

export async function checkRemainingOrder(input: PreparationInput, checkpoint: string, evidence: string) {
  const selected = [...input.issueRecipients].sort();
  if (selected.length < 3) throw new ExecutionError("STATE", "reordering needs at least two unsettled issuance rows");
  const rows = [];
  for (const file of await readdir(checkpoint)) {
    if (!file.endsWith(".intent.json")) continue;
    const record = intent.parse(JSON.parse(await readFile(join(checkpoint, file), "utf8")));
    const done = completion.parse(JSON.parse(await readFile(join(checkpoint, `${record.id}.receipt.json`), "utf8")));
    const issued = done.events.find((event) => event.name === "IndependentAllocationIssued");
    if (!issued) throw new ExecutionError("STATE", "issuance lacks emitted identity");
    rows.push({ nonce: record.nonce, transactionHash: record.transactionHash,
      recipient: issued.values[0]?.toLowerCase(), bondTokenId: issued.values[2], credit: issued.values[3] });
  }
  rows.sort((a, b) => BigInt(a.nonce) < BigInt(b.nonce) ? -1 : 1);
  const expected = [selected[0], ...selected.slice(1).reverse()];
  if (canonical(rows.map((row) => row.recipient)) !== canonical(expected)
    || new Set(rows.map((row) => row.bondTokenId)).size !== selected.length) {
    throw new ExecutionError("STATE", "remaining issuance was not reversed exactly once");
  }
  await save(evidence, { originalOrder: selected, expectedAfterInterruption: expected, actual: rows });
}

export async function checkPreparation(context: {
  readonly input: PreparationInput; readonly evidence: string;
  readonly cli: (args: readonly string[]) => Promise<unknown>;
}) {
  const { input, evidence, cli } = context;
  const path = join(evidence, "reordered-input.json");
  await save(path, { ...input, sources: [...input.sources].reverse(), exposures: [...input.exposures].reverse(),
    independent: [...input.independent].reverse(), nfts: [...input.nfts].reverse(),
    weightedLiquid: [...input.weightedLiquid].reverse(),
    weightedSy: [...input.weightedSy].reverse(),
    dtfCustodySe: [...input.dtfCustodySe].reverse(),
    claimVault: [...input.claimVault].reverse(),
    weightedReceipt: [...input.weightedReceipt].reverse(),
    earlierReceipt: [...input.earlierReceipt].reverse(),
    earlierLiquid: [...input.earlierLiquid].reverse(),
    heldSeLp: [...input.heldSeLp].reverse(),
    issueRecipients: [...input.issueRecipients].reverse(),
    domain: { ...input.domain, bindings: [...input.domain.bindings].reverse() } });
  await cli(["prepare", "--input", path, "--output", join(evidence, "prepared-reordered")]);
  const outputs = [];
  for (const name of ["manifest.json", "independent.json", "nfts.json", "weighted-liquid.json", "weighted-sy.json", "dtf-custody-se.json", "claim-vault.json", "weighted-receipt.json", "earlier-receipt.json", "earlier-liquid.json", "held-se-lp.json"]) {
    const original = await readFile(join(evidence, "prepared", name));
    const reordered = await readFile(join(evidence, "prepared-reordered", name));
    if (!original.equals(reordered)) throw new ExecutionError("STATE", "preparation depends on input order");
    outputs.push({ name, bytes: original.length, sha256: fingerprint(original), byteIdentical: true });
  }
  await save(join(evidence, "deterministic-preparation.json"), { outputs });
}

/** Queue the independent owner race without changing production nonce policy. */
export async function sameBlockReplacement(context: {
  readonly chain: RehearsalChain; readonly evidence: string; readonly runtime: string;
  readonly manifestPath: string; readonly configuredCheckpoint: string; readonly local: readonly string[];
  readonly cli: (args: readonly string[], expected?: "success" | "fault" | "reject-state") => Promise<unknown>;
}) {
  const { chain, evidence, runtime, local, cli } = context;
  const current = await loadExecution(context.manifestPath);
  const retained = await reconciledFixtureInput(context.manifestPath, context.configuredCheckpoint);
  const recipient = RECIPIENTS[3];
  const prior = retained.independent.find((r) => r.recipient === recipient);
  if (!prior || prior.pricing.kind !== "retain") throw new ExecutionError("STATE", "same-block key lacks current accepted configuration");
  const executions = [];
  for (const label of ["a", "b"] as const) {
    const input = preparationInput.parse({ ...retained, independent: retained.independent.map((row) => row !== prior ? row : {
      ...row, evidenceId: `0x${fingerprint(`synthetic-local same-block full input ${label}`)}`,
      pricing: { kind: "load", bookId: retained.domain.bookId, replaces: prior.pricing.kind === "retain" ? prior.pricing.accepted : null },
    }) });
    const path = join(evidence, `same-block-${label}-input.json`);
    await save(path, input);
    const prepared = join(evidence, `same-block-${label}-prepared`);
    await cli(["prepare", "--input", path, "--output", prepared]);
    const { bundle: _bundle, ...native } = current.manifest;
    const manifestPath = join(evidence, `same-block-${label}-execution.json`);
    await save(manifestPath, { ...native, preparedManifest: join(prepared, "manifest.json") });
    const domain = await loadExecution(manifestPath);
    const operations = plan(domain, "configure");
    const operation = operations[0];
    if (!operation || operations.length !== 1) throw new ExecutionError("STATE", "same-block scenario must select one complete replacement");
    executions.push({ manifestPath, domain, operation, checkpoint: join(runtime, `same-block-${label}`) });
  }
  const a = executions[0], b = executions[1];
  if (!a || !b || a.operation.transaction.data === b.operation.transaction.data) throw new ExecutionError("STATE", "same-block full inputs must differ");
  const nonce = BigInt(quantity.parse(await chain.send("eth_getTransactionCount", [DEV, "latest"])));
  const gasPrice = quantity.parse(await chain.send("eth_gasPrice", []));
  const signedB = await claimedWallet(0).signTransaction({
    chainId: 4663n, nonce: Number(nonce + 1n), to: b.operation.transaction.to,
    data: b.operation.transaction.data, value: BigInt(b.operation.transaction.value),
    gasLimit: 3000000n, gasPrice: BigInt(gasPrice), type: 0,
  });
  const bJournal = await Journal.acquire(b.checkpoint, b.domain.domain);
  let bIntent: Intent;
  try {
    bIntent = intent.parse({ version: "dtf-operator-intent-v2", domainHash: bJournal.domainHash,
      ...b.operation, nonce: String(nonce + 1n), startBlock: BigInt(quantity.parse(await chain.send("eth_blockNumber", []))).toString(),
      gasLimit: "3000000", gasPrice: BigInt(gasPrice).toString(), signedTransaction: signedB, transactionHash: keccak256(signedB) });
    await save(join(b.checkpoint, "run.json"), { stage: "configure", operationIds: [b.operation.id] });
    await bJournal.persistIntent(bIntent);
  } finally { await bJournal.close(); }
  const endpoint = new URL(chain.endpoint);
  endpoint.protocol = "ws:";
  const socket = new WebSocket(endpoint);
  const deadline = AbortSignal.timeout(60000);
  let acknowledge: () => void = () => undefined;
  let failReady: (error: unknown) => void = () => undefined;
  const ready = new Promise<void>((resolve, reject) => { acknowledge = resolve; failReady = reject; });
  let mined: () => void = () => undefined;
  let fail: (error: unknown) => void = () => undefined;
  const queued = new Promise<void>((resolve, reject) => { mined = resolve; fail = reject; });
  void queued.catch(() => undefined);
  const abort = () => { const error = new ExecutionError("STATE", "same-block pending subscription timed out"); failReady(error); fail(error); };
  deadline.addEventListener("abort", abort, { once: true });
  let selected = false;
  socket.addEventListener("open", () => socket.send(JSON.stringify({ jsonrpc: "2.0", id: 1, method: "eth_subscribe", params: ["newPendingTransactions"] })));
  socket.addEventListener("error", () => abort());
  socket.addEventListener("message", (event) => {
    const message = z.object({ id: z.number().optional(), result: z.string().optional(),
      params: z.object({ result: z.string() }).optional() }).passthrough().parse(JSON.parse(String(event.data)));
    if (message.id === 1 && message.result) acknowledge();
    if (!message.params || selected) return;
    const candidate = message.params.result;
    void (async () => {
      const tx = z.object({ from: z.string(), input: hex }).passthrough().parse(await chain.send("eth_getTransactionByHash", [candidate]));
      if (selected || tx.from.toLowerCase() !== DEV || tx.input !== a.operation.transaction.data) return;
      selected = true;
      if (await chain.send("eth_sendRawTransaction", [signedB]) !== bIntent.transactionHash) throw new ExecutionError("STATE", "queued B signed hash differs");
      await chain.send("evm_mine", []);
      mined();
    })().catch(fail);
  });
  try {
    await ready;
    await chain.send("evm_setAutomine", [false]);
    await Promise.all([
      cli(["configure", "--manifest", a.manifestPath, "--checkpoint", a.checkpoint, ...local, "--fault-after-mined"], "fault"),
      queued,
    ]);
  } finally {
    deadline.removeEventListener("abort", abort);
    socket.close();
    await chain.send("evm_setAutomine", [true]);
  }
  const before = await interruptedReceipt(chain, a.checkpoint, join(evidence, "same-block-a-before-resume.json"));
  const bReceipt = await chain.canonicalReceipt(bIntent.transactionHash);
  const header = await chain.send("eth_getBlockByNumber", [before.receipt.blockNumber, false]);
  if (!bReceipt || bReceipt.blockHash !== before.receipt.blockHash || BigInt(before.receipt.transactionIndex) !== 0n
    || BigInt(bReceipt.transactionIndex) !== 1n || BigInt(bReceipt.status) !== 1n) {
    throw new ExecutionError("STATE", "same-block A then B canonical ordering differs");
  }
  const bState = (await chain.call(current.manifest.proxy, current.abis.migration, "independentAllocation", [recipient])).toString();
  const beforeNonce = await chain.send("eth_getTransactionCount", [DEV, "latest"]);
  const trace = await chain.send("debug_traceCall", [{
    from: DEV, to: current.manifest.proxy, data: current.abis.migration.encodeFunctionData("independentAllocation", [recipient]),
  }, before.receipt.blockNumber, { tracer: "callTracer", txIndex: "0x1" }]);
  await save(join(evidence, "same-block-transaction-local-trace.json"), { aIntent: before.intent, aReceipt: before.receipt,
    bIntent, bReceipt, header, trace, bState, executingBindings: current.manifest.bindings });
  await cli(["resume", "--manifest", a.manifestPath, "--checkpoint", a.checkpoint, ...local]);
  await recoveredReceipt(before, a.checkpoint, join(evidence, "same-block-a-resumed.json"));
  await cli(["resume", "--manifest", b.manifestPath, "--checkpoint", b.checkpoint, ...local]);
  await cli(["verify", "--manifest", b.manifestPath, "--checkpoint", join(runtime, "same-block-verify")]);
  await rejectTamperedCompletions({ checkpoint: a.checkpoint, manifestPath: a.manifestPath, evidence, cli });
  const afterNonce = await chain.send("eth_getTransactionCount", [DEV, "latest"]);
  if (afterNonce !== beforeNonce || (await chain.call(current.manifest.proxy, current.abis.migration,
    "independentAllocation", [recipient])).toString() !== bState) throw new ExecutionError("STATE", "same-block recovery resent or replaced B");
  await save(join(evidence, "same-block-config-a-then-b.json"), {
    aIntent: before.intent, aReceipt: before.receipt, bIntent, bReceipt, header,
    trace, currentB: bState, beforeNonce, afterNonce, aCompletionRecovered: true, resends: 0,
  });
  return { manifestPath: b.manifestPath, input: await reconciledFixtureInput(b.manifestPath, b.checkpoint) };
}
