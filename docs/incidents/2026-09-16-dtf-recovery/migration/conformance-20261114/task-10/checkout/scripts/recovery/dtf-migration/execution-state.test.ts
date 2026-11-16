import { test } from "node:test";
import assert from "node:assert/strict";
import { executionFixture, h, a } from "./preparation.fixture.js";
import { plan } from "./execution-plan.js";
import { preflightOperation } from "./execution.js";
import { Rpc } from "./execution-rpc.js";
import { nftOrigin } from "./payloads.js";
import { receipt } from "./execution-schema.js";
import { Interface } from "ethers";
import { Wallet, keccak256 } from "ethers";
import { readFile, writeFile } from "node:fs/promises";
import { join } from "node:path";
import { canonical, fingerprint } from "./provenance.js";
import { intent } from "./execution-schema.js";
import { configurationId } from "./payloads.js";
import { verifyConfiguration, verifyRow } from "./execution-state.js";

test("unsent A rejects current B before nonce allocation or transaction submission", async () => {
  const f = await executionFixture();
  const rpc = new Rpc(f.domain.manifest);
  try {
    const operation = plan(f.domain, "configure")[0];
    assert.ok(operation);
    const migration = f.domain.abis.migration;
    const book = migration.decodeFunctionResult("migrationWeightedPricing", f.changes.book)[0].toObject(true);
    f.changes.book = migration.encodeFunctionResult("migrationWeightedPricing", [{ ...book, id: h(700) }]);
    await assert.rejects(preflightOperation(rpc, f.domain, operation, { kind: "simulate" }), /load book differs/);
    assert.equal(f.methods.includes("eth_getTransactionCount"), false);
    assert.equal(f.methods.includes("eth_sendRawTransaction"), false);
  } finally { rpc.close(); await f.close(); }
});

test("changed quote rejects before nonce allocation even when the book id agrees", async () => {
  const f = await executionFixture();
  const rpc = new Rpc(f.domain.manifest);
  try {
    const operation = plan(f.domain, "configure")[0];
    assert.ok(operation);
    f.changes.quoteDelta = 1n;
    await assert.rejects(preflightOperation(rpc, f.domain, operation, { kind: "simulate" }), /fresh manual-book quote changed/);
    assert.equal(f.methods.includes("eth_getTransactionCount"), false);
    assert.equal(f.methods.includes("eth_sendRawTransaction"), false);
  } finally { rpc.close(); await f.close(); }
});

test("all selected loaders bind their own book and stable NFT identity excludes repricing", async () => {
  const f = await executionFixture();
  try {
    const operations = plan(f.domain, "configure");
    for (const operation of operations) {
      const args = f.domain.abis.allocation.decodeFunctionData(operation.method, operation.transaction.data);
      assert.equal(args[1], f.input.domain.bookId);
    }
    const row = f.input.nfts[0];
    assert.ok(row);
    assert.equal(nftOrigin({ ...f.input.domain, bookId: h(999) }, row.original), nftOrigin(f.input.domain, row.original));
    const nft = f.domain.prepared.payloads.configure.nfts.find((r) => r.input.separateContributions);
    assert.ok(nft);
    assert.deepEqual(nft.contributions.map((r) => [r.originalEth, r.originalDtf]), [
      ["999999000000000", "0"], ["0", "362893857600000000000"],
    ]);
  } finally { await f.close(); }
});

test("NFT current verification binds consumed credit to each original component floor", async () => {
  const f = await executionFixture();
  const rpc = new Rpc(f.domain.manifest);
  try {
    const row = f.domain.prepared.payloads.configure.nfts.find((r) => r.input.separateContributions);
    assert.ok(row);
    const abi = f.domain.abis.migration;
    const args = [row.input.collection, row.input.tokenId];
    const set = (method: string, value: unknown) => f.changes.reads.set(abi.encodeFunctionData(method, args),
      abi.encodeFunctionResult(method, [value]));
    set("nftEntitlement", { original: row.input, configurationId: row.configurationId, originalId: row.originalId, credit: row.quotedCredit });
    set("nftContributions", row.contributions);
    const remaining = BigInt(row.input.originalUnits) / 2n;
    const parts = row.contributions.map((p, i) => ({
      credit: BigInt(p.credit) * remaining / BigInt(row.input.originalUnits), bondTokenId: BigInt(i + 3),
    }));
    const consumed = { consumed: true, configurationId: row.configurationId, holder: row.input.originalWallet,
      originalUnits: row.input.originalUnits, remainingUnits: remaining, credit: parts.reduce((sum, p) => sum + p.credit, 0n),
      bondTokenId: 3n, surrenderedAt: 2000n };
    set("nftContributionSurrenders", parts);
    set("nftSurrender", consumed);
    await verifyRow(rpc, f.domain, "nfts", row);
    set("nftSurrender", { ...consumed, credit: consumed.credit + 1n });
    await assert.rejects(verifyRow(rpc, f.domain, "nfts", row), /NFT consumed configuration/);
  } finally { rpc.close(); await f.close(); }
});

test("same-block A completion reads transaction-prefix A rather than overwritten block-end B", async () => {
  const f = await executionFixture();
  const rpc = new Rpc(f.domain.manifest);
  try {
    const tag = "0x79";
    const transactionHash = h(1001);
    f.changes.blocks.set(tag, { number: tag, hash: h(121), transactions: [transactionHash, h(1002)] });
    const mined = receipt.parse({ transactionHash, blockHash: h(121), blockNumber: tag, transactionIndex: "0x0",
      from: f.domain.manifest.signer, to: f.domain.manifest.proxy, status: "0x1", logs: [] });
    const abi = new Interface(["function storedCredit() view returns(uint256)"]);
    const data = abi.encodeFunctionData("storedCredit");
    const aValue = abi.encodeFunctionResult("storedCredit", [17n]);
    const bValue = abi.encodeFunctionResult("storedCredit", [29n]);
    f.changes.reads.set(data, bValue);
    f.changes.traces.set(data + ":0x1", { type: "CALL", from: f.domain.manifest.signer, to: f.domain.manifest.proxy,
      input: data, output: aValue, calls: [{ type: "DELEGATECALL", from: f.domain.manifest.proxy, to: a(13), input: data, output: aValue }] });
    assert.equal((await rpc.atReceipt(mined, () => rpc.call(f.domain.manifest.proxy, abi, "storedCredit", [], tag)))[0], 17n);
    assert.equal((await rpc.call(f.domain.manifest.proxy, abi, "storedCredit", [], tag))[0], 29n);
    f.changes.blocks.set(tag, { number: tag, hash: h(121), transactions: [h(1002), transactionHash] });
    await assert.rejects(rpc.atReceipt(mined, () => rpc.call(f.domain.manifest.proxy, abi, "storedCredit", [], tag)), /transaction-prefix header/);
  } finally { rpc.close(); await f.close(); }
});

test("canonical completion rejects forged receipt order and altered transaction log contents", async () => {
  const f = await executionFixture();
  const rpc = new Rpc(f.domain.manifest);
  try {
    const transactionHash = h(1001);
    const tag = "0x79";
    const log = { address: f.domain.manifest.proxy, topics: [h(700)], data: "0x", logIndex: "0x0",
      transactionHash, transactionIndex: "0x0", blockHash: h(121), blockNumber: tag };
    const mined = { transactionHash, blockHash: h(121), blockNumber: tag, transactionIndex: "0x0",
      from: f.domain.manifest.signer, to: f.domain.manifest.proxy, status: "0x1", logs: [log] };
    f.changes.blocks.set(tag, { number: tag, hash: h(121), transactions: [transactionHash, h(1002)] });
    f.changes.receipts.set(transactionHash, mined);
    f.changes.logs.set(h(121), [log]);
    assert.equal((await rpc.canonicalReceipt(transactionHash))?.transactionHash, transactionHash);
    f.changes.logs.set(h(121), [{ ...log, data: "0xff" }]);
    await assert.rejects(rpc.canonicalReceipt(transactionHash), /canonical transaction logs differ/);
    f.changes.logs.set(h(121), [log]);
    f.changes.receipts.set(transactionHash, { ...mined, transactionIndex: "0x1" });
    await assert.rejects(rpc.canonicalReceipt(transactionHash), /transaction order differs/);
  } finally { rpc.close(); await f.close(); }
});

test("current B configuration is verified independently of authenticated A issuance and principal", async () => {
  const f = await executionFixture(true);
  const rpc = new Rpc(f.domain.manifest);
  try {
    const rowA = f.domain.prepared.payloads.configure.independent[0];
    assert.ok(rowA);
    const migration = f.domain.abis.migration;
    const signer = new Wallet("0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80");
    const ref = async (path: string) => {
      const bytes = await readFile(path);
      return { path, sha256: fingerprint(bytes), bytes: String(bytes.length) };
    };
    const journalPath = join(f.root, "domain.json");
    await writeFile(journalPath, canonical(f.domain.domain), { flag: "wx" });
    const signed = async (stage: "configure" | "independent-issue", nonce: number, blockNumber: number) => {
      const operation = plan(f.domain, stage)[0];
      assert.ok(operation);
      const raw = await signer.signTransaction({ chainId: 4663n, nonce, to: operation.transaction.to, value: 0n,
        data: operation.transaction.data, gasLimit: 500000n, gasPrice: 2n, type: 0 });
      const record = intent.parse({ version: "dtf-operator-intent-v2", ...operation,
        domainHash: fingerprint(canonical(f.domain.domain)), nonce: String(nonce), startBlock: "100",
        gasLimit: "500000", gasPrice: "2", signedTransaction: raw, transactionHash: keccak256(raw) });
      const path = join(f.root, `${stage}.intent.json`);
      await writeFile(path, canonical(record), { flag: "wx" });
      const tag = `0x${blockNumber.toString(16)}`;
      f.changes.blocks.set(tag, { number: tag, hash: h(blockNumber), transactions: [record.transactionHash] });
      f.changes.transactions.set(record.transactionHash, { hash: record.transactionHash, from: record.transaction.from,
        to: record.transaction.to, input: record.transaction.data, value: "0x0", nonce: `0x${nonce.toString(16)}`,
        gas: "0x7a120", gasPrice: "0x2", blockHash: h(blockNumber), transactionIndex: "0x0" });
      return { record, path, tag, blockNumber };
    };
    const configure = await signed("configure", 7, 101);
    const issue = await signed("independent-issue", 8, 102);
    const eventLog = (abi: Interface, name: string, values: readonly unknown[], emitter: string,
      block: number, tx: string, index: number) => {
      const fragment = abi.getEvent(name);
      assert.ok(fragment);
      return { ...abi.encodeEventLog(fragment, [...values]), address: emitter, blockHash: h(block),
        blockNumber: `0x${block.toString(16)}`, transactionHash: tx, transactionIndex: "0x0", logIndex: `0x${index.toString(16)}` };
    };
    const configuredA = eventLog(migration, "IndependentAllocationConfigured",
      [rowA.input.recipient, rowA.configurationId, rowA.input.evidenceId, rowA.quotedCredit],
      f.domain.manifest.proxy, 101, configure.record.transactionHash, 0);
    const principal = BigInt(rowA.quotedCredit);
    const gons = principal * 100n;
    const bond = a(30);
    const staking = a(31);
    const bondAbi = new Interface([
      "function ownerOf(uint256) view returns(address)",
      "function positionOf(uint256) view returns((uint256 principal,uint256 claimedPrincipal,uint256 stakingGons,uint256 startTimestamp,uint256 vestingDuration))",
      "function isMigrationPosition(uint256) view returns(bool)", "function attributedBondGons() view returns(uint256)",
      "event MigrationPositionCreated(uint256 indexed tokenId,address indexed recipient,uint256 principal,uint256 start,uint256 unlockTime)",
      "event Transfer(address indexed from,address indexed to,uint256 indexed tokenId)",
      "event BondClaimed(uint256 indexed tokenId,address indexed recipient,uint256 principal,uint256 rewards)",
    ]);
    const stakingAbi = new Interface([
      "event Staked(address indexed payer,address indexed recipient,uint256 detfAmount,uint256 gons)",
      "function gonsOf(address) view returns(uint256)",
      "function stakingState() view returns((uint256 totalGons,uint256 gonsPerUnit,uint256 accountedBacking,uint256 allocationDust,uint256 stakingDust,uint256 feeWeight,uint256 creatorWeight))",
      "function balanceOf(address) view returns(uint256)", "function totalSupply() view returns(uint256)",
    ]);
    const issuance = { issued: true, configurationId: rowA.configurationId, credit: principal, bondTokenId: 3n, issuedAt: 2000n };
    const issueLogs = [
      eventLog(stakingAbi, "Staked", [bond, bond, principal, gons], staking, 102, issue.record.transactionHash, 0),
      eventLog(bondAbi, "MigrationPositionCreated", [3n, rowA.input.recipient, principal, 2000n, 7778000n], bond, 102, issue.record.transactionHash, 1),
      eventLog(migration, "IndependentAllocationIssued", [rowA.input.recipient, rowA.configurationId, 3n, principal, 2000n],
        f.domain.manifest.proxy, 102, issue.record.transactionHash, 2),
    ];
    const registerReceipt = (block: number, tx: string, logs: readonly ReturnType<typeof eventLog>[]) => {
      f.changes.receipts.set(tx, { transactionHash: tx, blockHash: h(block), blockNumber: `0x${block.toString(16)}`, transactionIndex: "0x0",
        from: f.domain.manifest.signer, to: f.domain.manifest.proxy, status: "0x1", logs });
      f.changes.logs.set(h(block), logs);
    };
    registerReceipt(101, configure.record.transactionHash, [configuredA]);
    registerReceipt(102, issue.record.transactionHash, issueLogs);
    const read = (abi: Interface, method: string, args: readonly unknown[], values: readonly unknown[], tag?: string) =>
      f.changes.reads.set(abi.encodeFunctionData(method, args) + (tag ? "@" + tag : ""), abi.encodeFunctionResult(method, values));
    const storedA = { configurationId: rowA.configurationId, evidenceId: rowA.input.evidenceId, totalCredit: principal,
      entitlements: rowA.input.entitlements.map((original) => ({ original, credit: principal })) };
    read(migration, "independentAllocation", [rowA.input.recipient], [storedA], configure.tag);
    read(migration, "independentIssuance", [rowA.input.recipient], [issuance]);
    read(migration, "bondNftVault", [], [bond]);
    read(migration, "rebasingClaimToken", [], [staking]);
    read(bondAbi, "ownerOf", [3n], [rowA.input.recipient]);
    read(bondAbi, "positionOf", [3n], [[principal, 0n, gons, 2000n, 7776000n]]);
    read(bondAbi, "isMigrationPosition", [3n], [true]);
    read(bondAbi, "attributedBondGons", [], [gons]);
    read(stakingAbi, "stakingState", [], [[gons, 100n, principal, 0n, 0n, 0n, 0n]]);
    read(stakingAbi, "gonsOf", [bond], [gons]);
    read(stakingAbi, "balanceOf", [staking], [principal]);
    read(stakingAbi, "totalSupply", [], [principal]);
    const accepted = { manifest: await ref(f.preparedManifest), executionManifest: await ref(f.manifestPath),
      journalDomain: await ref(journalPath), configurationId: rowA.configurationId, intent: await ref(configure.path), completion: null };
    const history = { recipient: rowA.input.recipient, configuration: accepted, issuancePreparedManifest: await ref(f.preparedManifest),
      issuanceExecutionManifest: await ref(f.manifestPath), issuanceJournalDomain: await ref(journalPath),
      issuanceIntent: await ref(issue.path), issuanceCompletion: null };
    const rowB = { ...rowA, pricing: { kind: "load" as const, bookId: h(700), replaces: accepted },
      configurationId: configurationId({ ...f.input.domain, bookId: h(700) }, rowA.input), quotedCredit: String(principal + 1n) };
    read(migration, "independentAllocation", [rowA.input.recipient], [{
      ...storedA, configurationId: rowB.configurationId, totalCredit: principal + 1n,
      entitlements: rowA.input.entitlements.map((original) => ({ original, credit: principal + 1n })),
    }]);
    f.changes.blocks.set("latest", { number: "0x6a", hash: h(106), transactions: [] });
    const topics = migration.fragments.filter((x) => x.type === "event").map((x) => migration.getEvent(x.format("sighash")))
      .filter((x) => x && x.name.endsWith("Configured")).map((x) => x?.topicHash);
    f.changes.logs.set(canonical({ address: f.domain.manifest.proxy, fromBlock: "0x5a", toBlock: "latest", topics: [topics] }), [configuredA]);
    const preparedB = { ...f.domain.prepared,
      input: { ...f.domain.prepared.input, issuedHistory: [history] },
      payloads: { ...f.domain.prepared.payloads, configure: { ...f.domain.prepared.payloads.configure, independent: [rowB] } },
      quoteEvidence: { ...f.domain.prepared.quoteEvidence, quotes: [
        ...f.domain.prepared.quoteEvidence.quotes,
        ...f.domain.prepared.quoteEvidence.quotes.map((q) => ({ ...q, bookId: h(700), credit: String(principal + 1n) })),
      ] },
    };
    const domainB = { ...f.domain, prepared: preparedB };
    const verified = await verifyConfiguration(rpc, domainB);
    assert.deepEqual(verified.rows, [{ recipient: rowA.input.recipient, issued: true, bondTokenId: "3" }]);
    read(migration, "independentIssuance", [rowA.input.recipient], [{ ...issuance, credit: principal + 1n }]);
    await assert.rejects(verifyConfiguration(rpc, domainB), /immutable issuance differs/);
    assert.equal(f.methods.includes("eth_sendRawTransaction"), false);
  } finally { rpc.close(); await f.close(); }
});
