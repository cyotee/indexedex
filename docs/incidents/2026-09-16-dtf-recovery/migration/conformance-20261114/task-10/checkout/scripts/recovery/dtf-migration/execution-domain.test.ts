import { test } from "node:test";
import assert from "node:assert/strict";
import { writeFile, readFile, mkdir } from "node:fs/promises";
import { join } from "node:path";
import { AbiCoder, Interface, Wallet, keccak256 } from "ethers";
import { executionFixture, h } from "./preparation.fixture.js";
import { acceptedContext, loadExecution } from "./execution-domain.js";
import { canonical, fingerprint } from "./provenance.js";
import { plan } from "./execution-plan.js";
import { intent, executionManifest, ExecutionError } from "./execution-schema.js";
import { validateIntent } from "./execution.js";
import { Journal } from "./journal.js";
import { assemble, normalize, validateManifest } from "./preparation.js";

const key = "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80";

test("saved v2 preparation rehydrates without a current-price quote", async () => {
  const f = await executionFixture();
  try {
    f.changes.quoteDelta = 1n;
    const loaded = await loadExecution(f.manifestPath);
    assert.equal(loaded.prepared?.payloadHash, f.domain.prepared.payloadHash);
    assert.equal(loaded.prepared?.payloads.configure.nfts[1]?.originalId,
      f.domain.prepared.payloads.configure.nfts[1]?.originalId);
  } finally { await f.close(); }
});

test("v1 execution manifest is rejected before RPC or signing", async () => {
  const f = await executionFixture();
  try {
    const legacy = { ...f.domain.manifest, version: "dtf-operator-execution-v1" };
    assert.equal(executionManifest.safeParse(legacy).success, false);
    const path = join(f.root, "legacy-v1-execution.json");
    await writeFile(path, canonical(legacy), { flag: "wx" });
    const requestsBefore = f.methods.length;
    await assert.rejects(loadExecution(path), { name: "ZodError" });
    assert.equal(f.methods.length, requestsBefore);
  } finally { await f.close(); }
});

test("overwritten intra-block book authenticates through its exact setter and subsequent load", async () => {
  const f = await executionFixture(true);
  try {
    const abi = f.domain.abis.migration;
    const migrationSource = f.domain.manifest.sources.find((s) => s.id === "migration-abi");
    const row = f.domain.prepared.payloads.configure.independent[0];
    const output = abi.getFunction("migrationWeightedPricing")?.outputs[0];
    assert.ok(migrationSource && row && output);
    const input = normalize({ ...f.domain.prepared.input, sources: f.domain.manifest.sources,
      domain: { ...f.input.domain, pricingArtifact: migrationSource.path } });
    const saved = assemble(input, f.domain.prepared.quoteEvidence);
    const path = join(f.root, "intrablock-prepared.json");
    await writeFile(path, canonical(saved), { flag: "wx" });
    const oldBook = abi.decodeFunctionResult("migrationWeightedPricing", f.changes.book)[0].toObject(true);
    const next = { ...oldBook, id: h(0), inputs: { ...oldBook.inputs, swapFeeWad: BigInt(oldBook.inputs.swapFeeWad) + 1n } };
    const nextId = keccak256(AbiCoder.defaultAbiCoder().encode(["string", output],
      ["IndexedEx.manual-weighted-original-credit", next]));
    f.changes.book = abi.encodeFunctionResult("migrationWeightedPricing", [{ ...next, id: nextId }]);
    f.changes.quoteDelta = 1n;
    const tx = h(1001);
    const later = h(1002);
    f.changes.blocks.set("0x64", { number: "0x64", hash: h(100), parentHash: h(99), transactions: [tx, later] });
    const event = abi.getEvent("IndependentAllocationConfigured");
    assert.ok(event);
    const log = (configurationId: string) => ({
      ...abi.encodeEventLog(event, [row.input.recipient, configurationId, row.input.evidenceId, row.quotedCredit]),
      address: input.domain.proxy, blockHash: h(100), blockNumber: "0x64", transactionHash: tx,
      transactionIndex: "0x0", logIndex: "0x0",
    });
    // The later setter belongs to a different transaction in the same block.
    const pricingAbi = new Interface(["event MigrationWeightedPricingSet(bytes32 indexed bookId)"]);
    const fragment = pricingAbi.getEvent("MigrationWeightedPricingSet");
    assert.ok(fragment);
    const laterLog = { ...pricingAbi.encodeEventLog(fragment, [nextId]), address: input.domain.proxy,
      blockHash: h(100), blockNumber: "0x64", transactionHash: later, transactionIndex: "0x1", logIndex: "0x1" };
    const topics = abi.fragments.filter((f) => f.type === "event").map((f) => abi.getEvent(f.format("sighash")))
      .filter((e) => e?.name.endsWith("Configured")).map((e) => e?.topicHash);
    const census = canonical({ address: input.domain.proxy, fromBlock: "0x63", toBlock: "0x64", topics: [topics] });
    const publish = (configurationId: string) => {
      const configured = log(configurationId);
      f.changes.logs.set(census, [configured]);
      f.changes.logs.set(h(100), [configured, laterLog]);
      f.changes.receipts.set(tx, { transactionHash: tx, blockHash: h(100), blockNumber: "0x64", transactionIndex: "0x0",
        from: f.domain.manifest.signer, to: input.domain.proxy, status: "0x1", logs: [configured] });
    };
    f.changes.transactions.set(tx, { hash: tx, from: f.domain.manifest.signer, to: input.domain.proxy,
      input: f.domain.abis.allocation.encodeFunctionData("configureIndependentAllocations", [[row.input], input.domain.bookId]),
      value: "0x0", chainId: "0x1237", blockHash: h(100), transactionIndex: "0x0" });
    publish(row.configurationId);
    assert.equal((await validateManifest(path)).payloadHash, saved.payloadHash);
    publish(h(9999));
    await assert.rejects(validateManifest(path), /ordered configuration preimages differ/);
    f.changes.logs.set(census, []);
    await assert.rejects(validateManifest(path), /lacks a subsequent canonical accepted configuration/);
    assert.equal(f.methods.includes("eth_sendRawTransaction"), false);
  } finally { await f.close(); }
});

test("historical intent domain is reconstructed independently of surrounding reference hashes", async () => {
  const f = await executionFixture();
  try {
    const operation = plan(f.domain, "configure")[0];
    const row = f.domain.prepared.payloads.configure.independent[0];
    assert.ok(operation && row);
    const raw = await new Wallet(key).signTransaction({ to: operation.transaction.to, data: operation.transaction.data,
      value: 0n, nonce: 7, gasLimit: 500000n, gasPrice: 2n, chainId: 4663n, type: 0 });
    const record = intent.parse({ version: "dtf-operator-intent-v2", domainHash: fingerprint(canonical(f.domain.domain)),
      ...operation, nonce: "7", startBlock: "100", gasLimit: "500000", gasPrice: "2",
      signedTransaction: raw, transactionHash: keccak256(raw) });
    const domainPath = join(f.root, "domain.json");
    const intentPath = join(f.root, "configure.intent.json");
    await writeFile(domainPath, canonical(f.domain.domain), { flag: "wx" });
    await writeFile(intentPath, canonical(record), { flag: "wx" });
    const ref = async (path: string) => {
      const bytes = await readFile(path);
      return { path, sha256: fingerprint(bytes), bytes: String(bytes.length) };
    };
    const accepted = { manifest: await ref(f.preparedManifest), executionManifest: await ref(f.manifestPath),
      journalDomain: await ref(domainPath), intent: await ref(intentPath), completion: null, configurationId: row.configurationId };
    const valid = await acceptedContext(accepted, f.domain.prepared.input, new Set());
    assert.equal(valid.record.domainHash, fingerprint(canonical(f.domain.domain)));
    await writeFile(intentPath, canonical({ ...record, domainHash: "f".repeat(64) }));
    const forged = { ...accepted, intent: await ref(intentPath) };
    await assert.rejects(acceptedContext(forged, f.domain.prepared.input, new Set()), /original execution\/preparation\/journal domain/);
    assert.equal(f.methods.includes("eth_getTransactionCount"), false);
    assert.equal(f.methods.includes("eth_sendRawTransaction"), false);
  } finally { await f.close(); }
});

test("resume rejects wrong nonce, chain, or gas in a persisted signed intent", async () => {
  const f = await executionFixture();
  try {
    const operation = plan(f.domain, "configure")[0];
    assert.ok(operation);
    const raw = await new Wallet(key).signTransaction({ to: operation.transaction.to, data: operation.transaction.data,
      value: 0n, nonce: 7, gasLimit: 500000n, gasPrice: 2n, chainId: 4663n, type: 0 });
    const record = intent.parse({ version: "dtf-operator-intent-v2", domainHash: fingerprint(canonical(f.domain.domain)),
      ...operation, nonce: "7", startBlock: "100", gasLimit: "500000", gasPrice: "2", signedTransaction: raw, transactionHash: keccak256(raw) });
    validateIntent(record, operation, "4663");
    for (const changed of [{ nonce: "8" }, { gasLimit: "500001" }, { gasPrice: "3" }, { transactionHash: h(9000) }]) {
      assert.throws(() => validateIntent({ ...record, ...changed }, operation, "4663"), /signed transaction/);
    }
    assert.throws(() => validateIntent(record, operation, "1"), /signed transaction/);
    assert.equal(f.methods.includes("eth_sendRawTransaction"), false);
  } finally { await f.close(); }
});

test("stale journal and second active checkpoint reject before any signer is created", async () => {
  const f = await executionFixture();
  try {
    const root = join(f.root, "operator");
    await mkdir(root);
    const first = join(root, "first");
    const second = join(root, "second");
    const journal = await Journal.acquire(first, f.domain.domain, root);
    await assert.rejects(Journal.acquire(second, f.domain.domain, root), /second active execution/);
    await journal.close();
    await assert.rejects(Journal.acquire(first, { ...f.domain.domain, payloadHash: "f".repeat(64) }, root), /domain changed/);
    const resumed = await Journal.acquire(first, f.domain.domain, root);
    await resumed.finish([]);
    await resumed.close();
    const next = await Journal.acquire(second, f.domain.domain, root);
    await next.finish([]);
    await next.close();
    assert.equal(JSON.parse(await readFile(join(first, "terminal.json"), "utf8")).state, "complete");
    assert.equal(f.methods.includes("eth_sendRawTransaction"), false);
  } finally { await f.close(); }
});

test("an unsigned blocked attempt closes without trapping the operator root or rewriting its journal", async () => {
  const f = await executionFixture();
  try {
    const root = join(f.root, "operator");
    await mkdir(root);
    const first = join(root, "stale-A");
    const next = join(root, "explicit-B");
    const journal = await Journal.acquire(first, f.domain.domain, root);
    const originalDomain = await readFile(join(first, "domain.json"));
    await journal.blocked(new ExecutionError("STATE", "load book differs"));
    await journal.close();
    assert.equal(JSON.parse(await readFile(join(first, "terminal.json"), "utf8")).state, "blocked");
    await assert.rejects(Journal.acquire(first, f.domain.domain, root), /terminal blocked checkpoint/);
    const replacement = await Journal.acquire(next, { manifest: "explicit new B execution" }, root);
    await replacement.finish([]);
    await replacement.close();
    assert.deepEqual(await readFile(join(first, "domain.json")), originalDomain);
    assert.equal(f.methods.includes("eth_sendRawTransaction"), false);
  } finally { await f.close(); }
});

test("duplicate configure batch rejects while intentional identical donations keep distinct IDs", async () => {
  const f = await executionFixture();
  try {
    const row = f.domain.prepared.payloads.configure.independent[0];
    assert.ok(row);
    const duplicate = { ...f.domain, prepared: { ...f.domain.prepared, payloads: { ...f.domain.prepared.payloads,
      configure: { ...f.domain.prepared.payloads.configure, independent: [row, row] } } } };
    assert.throws(() => plan(duplicate, "configure"), /duplicate operation identity/);
    const donation = { id: h(1), tokens: [f.domain.manifest.proxy], amounts: ["1"], nativeAmount: "0", minimum: "0", deadline: "1000" };
    const manifest = { ...f.domain.manifest, funding: { donations: [donation, { ...donation, id: h(2) }], genesis: null } };
    const operations = plan({ ...f.domain, manifest }, "fund");
    assert.equal(new Set(operations.map((o) => o.id)).size, 4);
    for (const [index, d] of manifest.funding.donations.entries()) {
      const approval = operations[index * 2];
      const transfer = operations[index * 2 + 1];
      assert.ok(approval && transfer);
      assert.equal(approval.id, fingerprint(canonical({ donation: d.id, token: donation.tokens[0], transaction: approval.transaction })));
      assert.equal(transfer.id, fingerprint(canonical({ id: d.id, transaction: transfer.transaction })));
    }
  } finally { await f.close(); }
});
