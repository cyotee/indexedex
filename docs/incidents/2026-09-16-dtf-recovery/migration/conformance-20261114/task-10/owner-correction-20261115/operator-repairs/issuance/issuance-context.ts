import assert from "node:assert/strict";
import { readFile, writeFile } from "node:fs/promises";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { Wallet, keccak256 } from "ethers";
import type { Interface } from "ethers";
import { z } from "zod";
import { executionFixture, a, h } from "../../../../../../../../../scripts/recovery/dtf-migration/preparation.fixture.js";
import { loadExecution } from "../../../../../../../../../scripts/recovery/dtf-migration/execution-domain.js";
import { Rpc } from "../../../../../../../../../scripts/recovery/dtf-migration/execution-rpc.js";
import { captureCompletion } from "../../../../../../../../../scripts/recovery/dtf-migration/execution-state.js";
import { intent, receipt } from "../../../../../../../../../scripts/recovery/dtf-migration/execution-schema.js";
import type { Receipt } from "../../../../../../../../../scripts/recovery/dtf-migration/execution-schema.js";
import { canonical, fingerprint } from "../../../../../../../../../scripts/recovery/dtf-migration/provenance.js";
import { interfaceFile, sourceFile } from "../../../../../../../../../scripts/recovery/dtf-migration/rehearsal-data.js";
import { plan } from "../../../../../../../../../scripts/recovery/dtf-migration/execution-plan.js";

export async function actualIssuance() {
  const directory = dirname(dirname(dirname(fileURLToPath(import.meta.url))));
  const blocker = z.object({ canonicalIssuance: z.string(), diagnostic: z.string() }).passthrough()
    .parse(JSON.parse(await readFile(join(directory, "operator-issuance-event-blocker.json"), "utf8")));
  const raw = await readFile(blocker.canonicalIssuance);
  const saved = z.object({
    receipt, header: z.object({ hash: z.string(), number: z.string(), transactions: z.array(z.string()) }).passthrough(),
    transaction: z.object({ hash: z.string() }).passthrough(), trace: z.unknown(),
  }).parse(JSON.parse(raw.toString("utf8")));
  const bondAbi = await interfaceFile(resolve("out/IUniswapV4DetfMigrationBondNFTVault.sol/IUniswapV4DetfMigrationBondNFTVault.json"));
  const creationFragment = bondAbi.getEvent("MigrationPositionCreated");
  const transferFragment = bondAbi.getEvent("Transfer");
  assert.ok(creationFragment && transferFragment);
  const creation = saved.receipt.logs.find((l) => l.topics[0] === creationFragment.topicHash);
  assert.ok(creation);
  const transfer = saved.receipt.logs.find((l) => l.address === creation.address && l.topics[0] === transferFragment.topicHash);
  assert.ok(transfer);
  assert.equal(saved.receipt.status, "0x1");
  assert.equal(transfer.data, "0x");
  assert.equal(transfer.topics.length, 4);
  return { blocker, saved, raw, bondAbi, creation, transfer };
}

// A new signed synthetic wire context, not a reconstructed historical state.
export async function issuanceContext() {
  const actual = await actualIssuance();
  const f = await executionFixture(true);
  try {
    const row = f.domain.prepared.payloads.configure.independent[0];
    assert.ok(row);
    const paths = {
      bond: "out/IUniswapV4DetfMigrationBondNFTVault.sol/IUniswapV4DetfMigrationBondNFTVault.json",
      staking: "out/IStakedDETF.sol/IStakedDETF.json",
    } as const;
    const sources = [...f.domain.manifest.sources, await sourceFile("issuance-bond-abi", paths.bond),
      await sourceFile("issuance-staking-abi", paths.staking)];
    const manifestPath = join(f.root, "new-issuance-execution.json");
    await writeFile(manifestPath, canonical({ ...f.domain.manifest, sources }), { flag: "wx" });
    const domain = await loadExecution(manifestPath);
    const operation = plan(domain, "independent-issue")[0];
    assert.ok(operation);
    const raw = await new Wallet("0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80")
      .signTransaction({ to: operation.transaction.to, data: operation.transaction.data, value: 0,
        nonce: 7, chainId: 4663, gasLimit: 500000, gasPrice: 2, type: 0 });
    const record = intent.parse({ version: "dtf-operator-intent-v2", ...operation, domainHash: fingerprint(canonical(domain.domain)),
      nonce: "7", startBlock: "100", gasLimit: "500000", gasPrice: "2", signedTransaction: raw, transactionHash: keccak256(raw) });
    const bondAbi = actual.bondAbi;
    const stakingAbi = await interfaceFile(resolve(paths.staking));
    const bond = a(30);
    const staking = a(31);
    const principal = BigInt(row.quotedCredit);
    const gons = principal * 100n;
    const start = 2000n;
    const makeLog = (abi: Interface, name: string, values: readonly unknown[]) => {
      const fragment = abi.getEvent(name);
      assert.ok(fragment);
      return abi.encodeEventLog(fragment, [...values]);
    };
    const logs = [
      { address: staking, ...makeLog(stakingAbi, "Transfer", [a(0), bond, principal]) },
      { address: staking, ...makeLog(stakingAbi, "Staked", [bond, bond, principal, gons]) },
      { address: bond, ...makeLog(bondAbi, "Transfer", [a(0), row.input.recipient, 3n]) },
      { address: bond, ...makeLog(bondAbi, "BondPurchased", [3n, row.input.recipient, principal, start, 7776000n]) },
      { address: bond, ...makeLog(bondAbi, "MigrationPositionCreated", [3n, row.input.recipient, principal, start, start + 7776000n]) },
      { address: domain.manifest.proxy, ...makeLog(domain.abis.migration, "IndependentAllocationIssued",
        [row.input.recipient, row.configurationId, 3n, principal, start]) },
    ].map((l, i) => ({ ...l, blockHash: h(121), blockNumber: "0x79", transactionHash: record.transactionHash,
      transactionIndex: "0x0", logIndex: `0x${i.toString(16)}` }));
    const mined = receipt.parse({ transactionHash: record.transactionHash, blockHash: h(121), blockNumber: "0x79",
      transactionIndex: "0x0", from: domain.manifest.signer, to: domain.manifest.proxy, status: "0x1", logs });
    f.changes.blocks.set("0x79", { number: "0x79", hash: h(121), transactions: [record.transactionHash] });
    f.changes.transactions.set(record.transactionHash, { hash: record.transactionHash, from: domain.manifest.signer,
      to: domain.manifest.proxy, input: record.transaction.data, value: "0x0", nonce: "0x7", gas: "0x7a120",
      gasPrice: "0x2", blockHash: h(121), transactionIndex: "0x0" });
    const read = (abi: Interface, method: string, values: readonly unknown[]) => f.changes.reads.set(
      abi.encodeFunctionData(method, method === "independentIssuance" ? [row.input.recipient]
        : ["ownerOf", "positionOf", "isMigrationPosition"].includes(method) ? [3n] : []), abi.encodeFunctionResult(method, values));
    read(domain.abis.migration, "independentIssuance", [{ issued: true, configurationId: row.configurationId,
      credit: principal, bondTokenId: 3n, issuedAt: start }]);
    read(domain.abis.migration, "bondNftVault", [bond]);
    read(domain.abis.migration, "rebasingClaimToken", [staking]);
    read(bondAbi, "ownerOf", [row.input.recipient]);
    read(bondAbi, "positionOf", [[principal, 0n, gons, start, 7776000n]]);
    read(bondAbi, "isMigrationPosition", [true]);
    const rpc = new Rpc(domain.manifest);
    return { ...f, actual, domain, record, mined, row, bond, staking, bondAbi, stakingAbi, principal, gons, start,
      async verify(candidate: Receipt) {
        f.changes.receipts.set(record.transactionHash, candidate);
        f.changes.logs.set(candidate.blockHash, candidate.logs);
        const canonicalReceipt = await rpc.canonicalReceipt(record.transactionHash);
        assert.ok(canonicalReceipt);
        return captureCompletion(rpc, domain, record, canonicalReceipt);
      },
      async close() { rpc.close(); await f.close(); },
    };
  } catch (error) { await f.close(); throw error; }
}

export function issuanceCorruptions(f: Awaited<ReturnType<typeof issuanceContext>>) {
  const created = f.mined.logs[4];
  const staked = f.mined.logs[1];
  assert.ok(created && staked);
  const createdFragment = f.bondAbi.getEvent("MigrationPositionCreated");
  const stakedFragment = f.stakingAbi.getEvent("Staked");
  assert.ok(createdFragment && stakedFragment);
  const createdValues = [3n, f.row.input.recipient, f.principal, f.start, f.start + 7776000n];
  const stakedValues = [f.bond, f.bond, f.principal, f.gons];
  const replace = (index: number, patch: Partial<Receipt["logs"][number]>) =>
    f.mined.logs.map((l, i) => i === index ? { ...l, ...patch } : l);
  const creation = (field: number, value: unknown) => replace(4,
    f.bondAbi.encodeEventLog(createdFragment, createdValues.map((v, i) => i === field ? value : v)));
  const funding = (field: number, value: unknown) => replace(1,
    f.stakingAbi.encodeEventLog(stakedFragment, stakedValues.map((v, i) => i === field ? value : v)));
  const cases = [
    { name: "missing position event", logs: f.mined.logs.filter((_, i) => i !== 4) },
    { name: "malformed position data", logs: replace(4, { data: "0x" }) },
    { name: "missing position topic", logs: replace(4, { topics: created.topics.slice(0, 2) }) },
    { name: "duplicate position event", logs: [...f.mined.logs, created] },
    { name: "wrong position emitter", logs: replace(4, { address: a(999) }) },
    { name: "wrong position signature", logs: replace(4, { topics: [h(999), ...created.topics.slice(1)] }) },
    { name: "wrong position ID", logs: creation(0, 4n) },
    { name: "wrong position recipient", logs: creation(1, a(999)) },
    { name: "wrong position principal", logs: creation(2, f.principal + 1n) },
    { name: "wrong position start", logs: creation(3, f.start + 1n) },
    { name: "wrong position cliff", logs: creation(4, f.start + 7776001n) },
    { name: "extra position topic", logs: replace(4, { topics: [...created.topics, h(999)] }) },
    { name: "extra position data", logs: replace(4, { data: created.data + h(999).slice(2) }) },
    { name: "missing staking event", logs: f.mined.logs.filter((_, i) => i !== 1) },
    { name: "malformed staking data", logs: replace(1, { data: "0x" }) },
    { name: "duplicate staking event", logs: [...f.mined.logs, staked] },
    { name: "wrong staking emitter", logs: replace(1, { address: a(999) }) },
    { name: "wrong staking payer", logs: funding(0, a(999)) },
    { name: "wrong staking recipient", logs: funding(1, a(999)) },
    { name: "wrong staked amount", logs: funding(2, f.principal + 1n) },
    { name: "wrong staked gons", logs: funding(3, f.gons + 1n) },
    { name: "extra staking topic", logs: replace(1, { topics: [...staked.topics, h(999)] }) },
    { name: "extra staking data", logs: replace(1, { data: staked.data + h(999).slice(2) }) },
    { name: "creation follows parent issuance", logs: [f.mined.logs[0], staked, f.mined.logs[2],
      f.mined.logs[3], f.mined.logs[5], created] },
    { name: "staking follows creation", logs: [f.mined.logs[0], f.mined.logs[2],
      f.mined.logs[3], created, staked, f.mined.logs[5]] },
  ];
  return cases.map((c) => ({ name: c.name, receipt: receipt.parse({ ...f.mined,
    logs: c.logs.map((l, i) => ({ ...l, logIndex: `0x${i.toString(16)}` })) }) }));
}
