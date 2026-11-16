// allow: SIZE_OK - Existing operator contract suite stays in its owned file during the concurrent repair.
import { afterEach, test } from "node:test";
import assert from "node:assert/strict";
import { mkdtemp, readdir, readFile, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { Wallet, keccak256 } from "ethers";
import { Journal } from "./journal.js";
import { canonical, fingerprint } from "./provenance.js";
import { intent, funding, ownerBond } from "./execution-schema.js";
import { interfaceFile } from "./rehearsal-data.js";
import { main } from "./cli.js";
import { validateIntent } from "./execution.js";
import { deploymentGasLimit } from "./execution-schema.js";
import { censusFixture } from "./execution.fixture.js";
import { acceptedContext, authenticateHistory, loadExecution } from "./execution-domain.js";
import { execute } from "./execution.js";
import { assemble, normalize, validateManifest } from "./preparation.js";
import { h } from "./preparation.fixture.js";
import { routes, stakingSource, stakingClaim } from "./claimed-sy-source.js";
import { configurationTransport, requireInterruption } from "../../../docs/incidents/2026-09-16-dtf-recovery/migration/conformance-20261114/task-10/owner-correction-20261115/operator-repairs/configure-fault/transport.fixture.js";

for (const kind of ["independent", "nft-components", "nft", "weightedLiquid", "weightedSy", "dtfCustodySe", "claimVault"] as const) {
  test(`mined ${kind} configure interrupts before completion and resumes the original receipt exactly once`, async () => {
    const f = await configurationTransport(kind);
    try {
      const record = await requireInterruption(f);
      const original = await readFile(join(f.checkpoint, `${record.id}.intent.json`));
      const counts = f.counts();
      f.staleBook();
      for (let i = 0; i < 2; i++) {
        const resumed = await f.cli(["resume", ...f.localArgs, "--fault-after-mined"]);
        assert.equal(resumed.code, 0, resumed.output);
        assert.equal(JSON.parse(resumed.output).state, "complete");
        assert.equal((await f.completed()).receipt.transactionHash, record.transactionHash);
        assert.equal((await f.completed()).intentHash, fingerprint(canonical(record)));
        assert.deepEqual(f.counts(), counts);
        assert.deepEqual(await readFile(join(f.checkpoint, `${record.id}.intent.json`)), original);
        assert.deepEqual((await readdir(f.checkpoint)).filter((n) => n.endsWith(".receipt.json")), [`${record.id}.receipt.json`]);
      }
    } finally { await f.close(); }
  });
}

for (const mutation of ["missing", "wrong-hash", "malformed", "reverted", "wrong-nonce", "wrong-state", "malformed-intent"] as const) {
  test(`interrupted configure rejects ${mutation} recovery without another nonce or send`, async () => {
    const f = await configurationTransport();
    try {
      const record = await requireInterruption(f);
      const counts = f.counts();
      const mined = f.changes.receipts.get(record.transactionHash);
      const transaction = f.changes.transactions.get(record.transactionHash);
      assert.ok(mined && typeof mined === "object" && transaction && typeof transaction === "object");
      switch (mutation) {
        case "missing": f.changes.receipts.delete(record.transactionHash); break;
        case "wrong-hash": f.changes.receipts.set(record.transactionHash, { ...mined, transactionHash: h(999) }); break;
        case "malformed": f.changes.receipts.set(record.transactionHash, { ...mined, status: "success" }); break;
        case "reverted": f.changes.receipts.set(record.transactionHash, { ...mined, status: "0x0" }); break;
        case "wrong-nonce": f.changes.transactions.set(record.transactionHash, { ...transaction, nonce: "0x8" }); break;
        case "wrong-state":
          f.changes.reads.set(f.domain.abis.migration.encodeFunctionData("independentAllocation", [f.domain.prepared.payloads.configure.independent[0]?.input.recipient]) + "@0x65",
            f.domain.abis.migration.encodeFunctionResult("independentAllocation", [[h(999), h(0), [], 0]]));
          break;
        case "malformed-intent": await writeFile(join(f.checkpoint, `${record.id}.intent.json`), '{"nonce":'); break;
        default: { const unreachable: never = mutation; throw new Error(unreachable); }
      }
      const resumed = await f.cli(["resume", ...f.localArgs, "--fault-after-mined"]);
      assert.equal(resumed.code, 1, resumed.output);
      const expected = { missing: "AMBIGUOUS", "wrong-hash": "AMBIGUOUS", malformed: "INPUT", reverted: "REVERT",
        "wrong-nonce": "INTENT", "wrong-state": "STATE", "malformed-intent": "INPUT" } as const;
      assert.equal(JSON.parse(resumed.output).error, expected[mutation]);
      assert.deepEqual(f.counts(), counts);
      assert.equal((await readdir(f.checkpoint)).some((n) => n.endsWith(".receipt.json") || n === "terminal.json"), false);
    } finally { await f.close(); }
  });
}

test("reverted configure rejects rather than claiming a successful mined interruption", async () => {
  const f = await configurationTransport();
  try {
    f.mining.status = "0x0";
    const rejected = await f.cli(["configure", ...f.localArgs, "--fault-after-mined"]);
    assert.equal(rejected.code, 1, rejected.output);
    assert.equal(rejected.signal, null);
    assert.equal(JSON.parse(rejected.output).error, "REVERT");
    assert.equal((await readdir(f.checkpoint)).some((n) => n.endsWith(".receipt.json") || n === "terminal.json"), false);
  } finally { await f.close(); }
});

test("configure fault injection rejects simulation and operational context without signing", async () => {
  const f = await configurationTransport();
  try {
    const simulated = await f.cli(["configure", "--fault-after-mined"]);
    assert.equal(simulated.code, 1, simulated.output);
    assert.match(simulated.output, /fault injection is synthetic-local only/);
    const prepared = assemble(normalize({ ...f.domain.prepared.input, purpose: "operational-review" }), f.domain.prepared.quoteEvidence);
    await writeFile(f.preparedManifest, canonical(prepared));
    await writeFile(f.manifestPath, canonical({ ...f.domain.manifest, purpose: "operational-review" }));
    const operational = await f.cli(["configure", ...f.localArgs, "--fault-after-mined"]);
    assert.equal(operational.code, 1, operational.output);
    assert.match(operational.output, /fault injection is synthetic-local only/);
    assert.deepEqual(f.counts(), { sends: 0, nonces: 0, signed: 0 });
  } finally { await f.close(); }
});

const roots: string[] = [];
async function directory() {
  const root = await mkdtemp(join(tmpdir(), "dtf-execution-test-"));
  roots.push(root);
  return root;
}
afterEach(async () => { for (const root of roots.splice(0)) await rm(root, { recursive: true }); });

test("complete B loads, verifies and resumes retained authentic X after Y is configured without rewriting A", async () => {
  const f = await censusFixture();
  try {
    const paths = [f.A.preparedPath, f.A.manifestPath, f.A.journalPath, f.A.intentPath, f.B.journalPath, f.B.intentPath];
    const original = await Promise.all(paths.map((p) => readFile(p)));
    assert.equal((await loadExecution(f.B.manifestPath)).prepared?.payloadHash, f.B.domain.prepared.payloadHash);
    f.publishY();
    f.changes.quoteDelta = 1n;
    const requestStart = f.requests.length;
    assert.equal((await loadExecution(f.B.manifestPath)).prepared?.payloadHash, f.B.domain.prepared.payloadHash);
    const run = { manifestPath: f.B.manifestPath, checkpoint: f.B.checkpoint, mode: { kind: "simulate" },
      reverse: false, faultAfterMined: false } as const;
    assert.equal((await execute({ ...run, command: "verify" })).mode, "read-only");
    for (let i = 0; i < 2; i++) {
      assert.deepEqual((await execute({ ...run, command: "resume" })).operationIds, [f.B.record.id]);
    }
    assert.deepEqual(await Promise.all(paths.map((p) => readFile(p))), original);
    assert.deepEqual((await readdir(f.B.checkpoint)).sort(),
      [`${f.B.record.id}.intent.json`, "domain.json", "run.json"].sort());
    const preview = f.domain.abis.migration.getFunction("previewOriginalCredit");
    assert.ok(preview);
    assert.equal(f.requests.slice(requestStart).some((r) => r.method === "eth_call"
      && JSON.stringify(r.params).includes(preview.selector)), false);
    assert.equal(f.methods.includes("eth_getTransactionCount"), false);
    assert.equal(f.methods.includes("eth_sendRawTransaction"), false);
  } finally { await f.close(); }
});

for (const keep of [[h(300)], [h(301)], []]) {
  test(`current census rejects omitted configured origins when keeping ${keep.join(",") || "none"}`, async () => {
    const f = await censusFixture();
    try {
      f.publishY();
      const incomplete = await f.incomplete(keep);
      await assert.rejects(validateManifest(incomplete.preparedPath),
        /previously configured SY origin omitted from complete census/);
      assert.equal(f.methods.includes("eth_getTransactionCount"), false);
      assert.equal(f.methods.includes("eth_sendRawTransaction"), false);
    } finally { await f.close(); }
  });
}

test("rehashing a historical intent and current manifest cannot change the original signed domain", async () => {
  const f = await censusFixture();
  try {
    f.publishY();
    const path = join(f.root, "forged-intent.json");
    await writeFile(path, canonical({ ...f.A.record, domainHash: "f".repeat(64) }));
    const accepted = { ...f.accepted, intent: await f.ref(path) };
    const input = normalize({ ...f.B.domain.prepared.input,
      weightedSy: f.B.domain.prepared.input.weightedSy.map((row) => row.pricing.kind === "retain"
        ? { ...row, pricing: { ...row.pricing, accepted } } : row) });
    const forged = assemble(input, f.B.domain.prepared.quoteEvidence);
    await writeFile(f.B.preparedPath, canonical(forged));
    const journal = { ...f.B.domain.domain, preparedHash: forged.normalizedHash, payloadHash: forged.payloadHash };
    await writeFile(f.B.journalPath, canonical(journal));
    await writeFile(f.B.intentPath, canonical({ ...f.B.record, domainHash: fingerprint(canonical(journal)) }));
    await assert.rejects(loadExecution(f.B.manifestPath), /original execution\/preparation\/journal domain/);
    assert.equal(f.methods.includes("eth_getTransactionCount"), false);
    assert.equal(f.methods.includes("eth_sendRawTransaction"), false);
  } finally { await f.close(); }
});

for (const mutation of ["member", "facet", "economics", "receipt", "historical-census"] as const) {
  test(`historical source authentication still rejects ${mutation} tampering after Y`, async () => {
    const f = await censusFixture();
    try {
      f.publishY();
      const original = f.A.domain.prepared.input.weightedSy[0];
      const member = original?.claimedOrigin?.members[0];
      assert.ok(original && member);
      switch (mutation) {
        case "member": {
          const tx = f.changes.transactions.get(member.transactionHash);
          assert.ok(tx && typeof tx === "object");
          f.changes.transactions.set(member.transactionHash, { ...tx, input: "0x" });
          break;
        }
        case "facet": f.changes.codes.set(routes[0][2], "0x6000"); break;
        case "economics":
          f.changes.reads.set(stakingSource + ":" + stakingClaim.encodeFunctionData("balanceOf", [original.original.originalWallet])
            + "@0x60", stakingClaim.encodeFunctionResult("balanceOf", [6]));
          break;
        case "receipt":
          f.changes.logs.set(h(101), f.configured.filter((l) => l.blockNumber === "0x65").map((l) => ({ ...l, data: "0xff" })));
          break;
        case "historical-census": {
          const event = f.domain.abis.migration.getEvent("WeightedSyEntitlementConfigured");
          const entry = f.configured[1];
          assert.ok(event && entry);
          f.changes.logs.set(canonical({ address: f.input.domain.proxy, fromBlock: "0x5a",
            toBlock: "0x64", topics: [event.topicHash] }), [{ ...entry, blockNumber: "0x64", blockHash: h(100) }]);
          break;
        }
        default: { const unreachable: never = mutation; throw new Error(unreachable); }
      }
      const expected = { member: /transaction or successful receipt differs/, facet: /source runtime or routing differs/,
        economics: /actual source weight vault or measured SY delta differs/, receipt: /canonical transaction logs differ/,
        "historical-census": /previously configured SY origin omitted from complete census/ };
      await assert.rejects(async () => {
        const context = await acceptedContext(f.accepted, f.B.domain.prepared.input, new Set());
        await authenticateHistory(context);
      }, expected[mutation]);
      assert.equal(f.methods.includes("eth_getTransactionCount"), false);
      assert.equal(f.methods.includes("eth_sendRawTransaction"), false);
    } finally { await f.close(); }
  });
}

test("current B verification rejects a changed retained X configuration after accepting its history", async () => {
  const f = await censusFixture();
  try {
    f.publishY();
    const row = f.A.domain.prepared.payloads.configure.weightedSy[0];
    assert.ok(row);
    const abi = f.domain.abis.migration;
    f.changes.reads.set(abi.encodeFunctionData("weightedSyEntitlement", [row.input.originalId]) + "@latest",
      abi.encodeFunctionResult("weightedSyEntitlement", [{ original: row.input, configurationId: h(999),
        credit: row.quotedCredit, configured: true }]));
    await assert.rejects(execute({ command: "verify", manifestPath: f.B.manifestPath, checkpoint: f.B.checkpoint,
      mode: { kind: "simulate" }, reverse: false, faultAfterMined: false }), /current configuration differs/);
    assert.equal(f.methods.includes("eth_getTransactionCount"), false);
    assert.equal(f.methods.includes("eth_sendRawTransaction"), false);
  } finally { await f.close(); }
});

test("journal refuses live concurrent writers and changed domains", async () => {
  const root = await directory();
  const journal = await Journal.acquire(root, { chain: "4663", proxy: "original" });
  await assert.rejects(Journal.acquire(root, { chain: "4663", proxy: "original" }), /live writer/);
  await journal.close();
  await assert.rejects(Journal.acquire(root, { chain: "4663", proxy: "different" }), /domain changed/);
  const resumed = await Journal.acquire(root, { chain: "4663", proxy: "original" });
  await resumed.close();
});

test("durable signed intent survives reopening without acquiring another nonce", async () => {
  const root = await directory();
  const domain = { chain: "4663", snapshot: "frozen", payload: "complete" };
  const journal = await Journal.acquire(root, domain);
  const wallet = new Wallet("0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80");
  const transaction = { from: wallet.address.toLowerCase(), to: "0x1111111111111111111111111111111111111111", data: "0x", value: "19" };
  const raw = await wallet.signTransaction({ to: transaction.to, value: 19n, nonce: 7, gasPrice: 2n, gasLimit: 21000n, chainId: 4663n });
  const record = intent.parse({
    version: "dtf-operator-intent-v2", domainHash: journal.domainHash, id: fingerprint("donation"),
    stage: "fund", method: "donateMigrationCapital", transaction, nonce: "7", startBlock: "100",
    gasLimit: "21000", gasPrice: "2", signedTransaction: raw, transactionHash: keccak256(raw),
  });
  await journal.persistIntent(record);
  await journal.close();
  const resumed = await Journal.acquire(root, domain);
  assert.deepEqual(await resumed.intents(), [record]);
  await assert.rejects(resumed.persistIntent(record), { code: "EEXIST" });
  assert.equal((await readdir(root)).filter((name) => name.endsWith(".intent.json")).length, 1);
  await resumed.close();
});

test("journal rejects a foreign intent rather than accepting its receipt", async () => {
  const root = await directory();
  const journal = await Journal.acquire(root, { payload: "one" });
  await writeFile(join(root, "foreign.intent.json"), "{}");
  await assert.rejects(journal.intents());
  await journal.close();
  assert.equal(JSON.parse(await readFile(join(root, "domain.json"), "utf8")).payload, "one");
});

test("partial unpublished records cannot become completed operations", async () => {
  const root = await directory();
  const journal = await Journal.acquire(root, { payload: "one" });
  await writeFile(join(root, "interrupted.intent.json.pending"), '{"nonce":');
  assert.deepEqual(await journal.intents(), []);
  await journal.close();
});

test("saved deployment intent accepts the ceiling and rejects one gas above it", async () => {
  const wallet = Wallet.fromPhrase("test test test test test test test test test test test junk");
  const transaction = { from: wallet.address.toLowerCase(), to: "0x1111111111111111111111111111111111111111",
    data: "0x", value: "0" };
  const operation = { id: fingerprint("bounded deployment"), stage: "deploy", method: "deployVault", transaction } as const;
  for (const gasLimit of [deploymentGasLimit, deploymentGasLimit + 1n]) {
    const raw = await wallet.signTransaction({ to: transaction.to, data: transaction.data, nonce: 7,
      chainId: 4663n, gasLimit, gasPrice: 2n, type: 0 });
    const saved = intent.parse({ version: "dtf-operator-intent-v2", domainHash: fingerprint("fixed gas policy"),
      ...operation, nonce: "7", startBlock: "108944663", gasLimit: String(gasLimit), gasPrice: "2",
      signedTransaction: raw, transactionHash: keccak256(raw) });
    if (gasLimit === deploymentGasLimit) validateIntent(saved, operation, "4663");
    else assert.throws(() => validateIntent(saved, operation, "4663"),
      /deployment intent exceeds target transaction gas limit/);
  }
});

test("funding rejects arbitrary calldata and unknown native values", () => {
  assert.equal(funding.safeParse({ donations: [], genesis: null, calldata: "0x" }).success, false);
  assert.equal(funding.safeParse({ donations: [{
    id: `0x${"1".repeat(64)}`, tokens: [], amounts: [], nativeAmount: null, minimum: "0", deadline: "100",
  }], genesis: null }).success, false);
});

test("paid owner purchase requires explicit positive payment and ordinary duration", async () => {
  const terms = { token: "0x1111111111111111111111111111111111111111",
    amount: "1000000000000000000", duration: "7776000", deadline: "2000000000" };
  for (const key of ["token", "amount", "duration", "deadline"] as const) {
    const { [key]: _missing, ...omitted } = terms;
    assert.equal(ownerBond.safeParse(omitted).success, false);
  }
  for (const changed of [{ amount: "0" }, { duration: "0" }, { deadline: "0" },
    { pretransferred: true }, { syntheticPrincipal: "1" }]) {
    assert.equal(ownerBond.safeParse({ ...terms, ...changed }).success, false);
  }
  const parsed = ownerBond.parse(terms);
  const parent = await interfaceFile("out/IUniswapV4DetfMigration.sol/IUniswapV4DetfMigration.json");
  const stageAbi = await interfaceFile("out/Phase_08_Stage_01_MigrationExecution.s.sol/Phase_08_Stage_01_MigrationExecution.json");
  const args = [parsed.token, parsed.amount, parsed.duration, terms.token, false, parsed.deadline];
  const decoded = parent.decodeFunctionData("bond", parent.encodeFunctionData("bond", args));
  assert.equal(decoded[1], BigInt(terms.amount));
  assert.equal(decoded[2], BigInt(terms.duration));
  assert.equal(decoded[4], false);
  const stage = stageAbi.decodeFunctionData("ownerFirstBond", stageAbi.encodeFunctionData("ownerFirstBond",
    [terms.token, parsed.token, parsed.amount, parsed.duration, parsed.deadline]));
  assert.equal(stage[2], decoded[1]);
  assert.equal(stage[3], decoded[2]);
  assert.equal(stage[4], decoded[5]);
});

for (const { args, reason } of [
  { args: ["fund", "--manifest", "unused", "--checkpoint", "unused", "--execute-local", "--broadcast"], reason: /execution modes are exclusive/ },
  { args: ["resume", "--manifest", "unused", "--checkpoint", "unused", "--instance-id", "old"], reason: /confirmation requires explicit mode/ },
  { args: ["activate", "--manifest", "unused", "--checkpoint", "unused", "--broadcast"], reason: /all fresh public confirmations required/ },
  { args: ["fund", "--manifest", "unused", "--checkpoint", "unused", "--target", "0x1111111111111111111111111111111111111111"], reason: /Unknown option/ },
]) {
  test(`CLI rejects ambiguous authority before file or network access: ${canonical(args)}`, async () => {
    await assert.rejects(main(args), reason);
  });
}
