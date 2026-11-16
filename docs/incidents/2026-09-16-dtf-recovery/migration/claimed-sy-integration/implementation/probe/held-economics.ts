import assert from "node:assert/strict";
import { resolve } from "node:path";
import { AbiCoder, Interface, keccak256 } from "ethers";
import { z } from "zod";
import { address, hash, hex, json, required, root, uint } from "./evidence.js";
import type { receipts } from "./receipts.js";

const sources = ["0x999dae02d22e5fee1c4508430d5196d31d631009",
  "0x923877336b14662cfb5b3a60b14e7d716d54a888", "0x46e068c2393e189fbc86632f67210af253a42aa8"] as const;
const original = z.object({
  originalId: hash, originalWallet: address, source: z.enum(sources), originalUnits: uint,
  originalEth: uint, originalDtf: uint, evidenceId: hash, contributionsKnown: z.literal(true),
});
const observed = z.object({
  kind: z.literal("surrender"), transactionHash: hash, original, q: uint, credit: uint, bondTokenId: uint,
  position: z.tuple([uint, uint, uint, uint, uint]), before: z.tuple([uint, uint, uint, uint]),
  after: z.tuple([uint, uint, uint, uint]), custodyBefore: uint, bookedBefore: uint, protectedBefore: z.string(),
});
const donorTx = z.object({
  from: address, to: address, input: hex, hash, r: z.string(), s: z.string(),
}).passthrough();
const donorReceipt = z.object({
  transactionHash: hash, status: z.string(), from: address, to: address,
  logs: z.array(z.object({ address, topics: z.array(hash), data: hex }).passthrough()),
}).passthrough();
const donorOperation = z.object({
  provenance: z.string(), transaction: donorTx, receipt: donorReceipt, trace: z.unknown(),
  stateDiff: z.unknown().optional(),
}).passthrough();
const holdings = z.array(z.object({ source: address, collector: uint, donor: uint, original: uint, supply: uint }));

async function abi(name: string) {
  return new Interface(JSON.stringify(z.object({ abi: z.array(z.unknown()) }).passthrough()
    .parse(await json(resolve(root, "out", `${name}.sol`, `${name}.json`))).abi));
}

export async function heldEconomics(runtime: string, records: Awaited<ReturnType<typeof receipts>>) {
  const migration = await abi("IUniswapV4DetfMigration");
  const allocation = new Interface(JSON.stringify(z.object({ abi: z.array(z.unknown()) }).passthrough()
    .parse(await json(resolve(root, "out/IUniswapV4DetfMigration.sol/IUniswapV4DetfMigrationAllocation.json"))).abi));
  const child = await abi("IUniswapV4DetfMigrationBondNFTVault");
  const token = new Interface(["event Transfer(address indexed from,address indexed to,uint256 amount)"]);
  const collectorAbi = new Interface(["function pullFee(address,uint256,address) returns(bool)",
    "function transfer(address,uint256) returns(bool)"]);
  const components = z.array(z.object({ role: z.string(), address }).passthrough())
    .parse(await json(resolve(runtime, "deployed-runtime-bindings.json")));
  const parent = records.manifest.proxy;
  const bond = required(components.find(c => c.role === "bondNftVault")).address;
  const staking = required(components.find(c => c.role === "rebasingClaimToken")).address;
  const prepared = z.object({
    input: z.object({ domain: z.object({ snapshotId: hash }).passthrough() }).passthrough(),
    payloads: z.object({ configure: z.object({ heldSeLp: z.array(z.object({
      input: original, configurationId: hash, quotedCredit: uint,
    })) }).passthrough() }).passthrough(),
  }).passthrough().parse(await json(resolve(runtime, "replacement/manifest.json")));
  assert.deepEqual(prepared.payloads.configure.heldSeLp.map(row => row.input.source).sort(), [...sources].sort());
  const acquisition = z.object({
    beforeAuthority: z.object({ owner: address, ownerCode: z.literal("0x"), collector: address,
      code: hex, facet: address, facetCode: hex }),
    afterAuthority: z.unknown(),
    rows: z.array(z.object({
      source: z.enum(sources), sourceCode: hex, sourceOwner: address.nullable(), originalWallet: address, units: uint,
      before: holdings, after: holdings, release: donorOperation.nullable(), donation: donorOperation,
      facets: z.array(z.object({ selector: hex, facet: address, code: hex })),
    })),
  }).passthrough().parse(await json(resolve(runtime, "held-se-lp-acquisition.json")));
  assert.deepEqual(acquisition.beforeAuthority, acquisition.afterAuthority);
  assert.equal(acquisition.beforeAuthority.owner, "0x72bea6fa3e68ef18c87d045aac7c4aa5249d933b");
  const donor = acquisition.beforeAuthority.owner;
  const collector = acquisition.beforeAuthority.collector;
  assert.equal(collector, "0x20af9a1e21a59a411cd3b0c40e70af9084770b2e");
  assert.equal(keccak256(acquisition.beforeAuthority.facetCode),
    "0x7ae5c353c623b635938a7bb3ebc07cb3eda6469b2cd9dbf76c8bed336ff0b5cb");
  const configuredRows = [];
  for (const configured of prepared.payloads.configure.heldSeLp) {
    const source = configured.input.source;
    const acquired = required(acquisition.rows.find(row => row.source === source));
    assert.equal(acquired.originalWallet, configured.input.originalWallet);
    assert.equal(acquired.units, configured.input.originalUnits);
    assert.equal(keccak256(acquired.sourceCode), "0x2393ee3dc4d7877a9bfb7b59c272f2b9b0d1df92f2dc82ee67df076a99836601");
    for (const facet of acquired.facets) {
      assert.equal(facet.facet, "0x1d17aca0e0717d90cea916372070a1be4652223f");
      assert.equal(keccak256(facet.code), "0xf250dca135b1de9a5fc9ceda732c06af7020fef1d45d7c43dfa92efe02b47e50");
    }
    const beforeHolding = required(acquired.before.find(row => row.source === source));
    const afterHolding = required(acquired.after.find(row => row.source === source));
    const acquiredUnits = BigInt(afterHolding.original) - BigInt(beforeHolding.original);
    assert.equal(acquiredUnits, BigInt(acquired.units) + 7n);
    for (const prior of acquired.before) {
      const after = required(acquired.after.find(row => row.source === prior.source));
      assert.equal(after.supply, prior.supply);
      if (prior.source !== source) assert.deepEqual(after, prior);
    }
    for (const [kind, operation] of [["donation", acquired.donation], ["release", acquired.release]] as const) {
      if (!operation) { assert.equal(source, sources[0]); continue; }
      assert.equal(BigInt(operation.transaction.r), 1n);
      assert.equal(BigInt(operation.transaction.s), 1n);
      assert.equal(operation.transaction.from, donor);
      assert.equal(operation.receipt.from, donor);
      assert.equal(operation.transaction.hash, operation.receipt.transactionHash);
      assert.equal(BigInt(operation.receipt.status), 1n);
      const release = kind === "release";
      assert.equal(operation.transaction.to, release ? collector : source);
      const args = collectorAbi.decodeFunctionData(release ? "pullFee" : "transfer", operation.transaction.input);
      assert.deepEqual(args.toArray().map(String).map(v => v.toLowerCase()), release
        ? [source, String(acquiredUnits), donor] : [acquired.originalWallet, String(acquiredUnits)]);
      assert(operation.receipt.logs.some(log => log.address === source
        && token.parseLog(log)?.args[0].toLowerCase() === (release ? collector : donor)
        && token.parseLog(log)?.args[1].toLowerCase() === (release ? donor : acquired.originalWallet)
        && token.parseLog(log)?.args[2] === acquiredUnits));
      const trace = z.object({ output: hex }).passthrough().parse(operation.trace);
      assert.equal(BigInt(trace.output), 1n);
    }
    if (source !== sources[0]) {
      assert(acquired.release);
      assert.equal(BigInt(beforeHolding.collector) - BigInt(afterHolding.collector), acquiredUnits);
      assert.equal(beforeHolding.donor, afterHolding.donor);
      assert.equal(acquired.sourceOwner, source === sources[1]
        ? "0xaf0e1967c8f755c747615c5427108bc549ca1122" : "0x4a5cfdc2b07016fcf917f4ed5a51c52111a0fcc7");
    }
    const parameter = required(allocation.getFunction("configureHeldSeLpEntitlements")?.inputs[0]?.arrayChildren);
    const configId = keccak256(AbiCoder.defaultAbiCoder().encode(["uint256", "address", "bytes32", parameter],
      [4663, parent, prepared.input.domain.snapshotId, configured.input]));
    assert.equal(configId, configured.configurationId);
    const rows = [];
    for (const phase of ["partial", "terminal"]) {
      const file = z.object({ observations: z.array(z.unknown()) }).passthrough()
        .parse(await json(resolve(runtime, `held-se-lp-${source}-${phase}.json`)));
      const parsed = file.observations.map(value => observed.safeParse(value)).find(value => value.success);
      assert(parsed?.success);
      const row = parsed.data;
      assert.deepEqual(row.original, configured.input);
      const [consumed, delivered, Q, C] = row.before.map(BigInt);
      const q = BigInt(row.q), credit = q === Q ? C : required(C) * q / required(Q);
      assert(q > 0n && q <= required(Q) && required(credit) > 0n);
      assert.equal(BigInt(row.credit), credit);
      assert.deepEqual(row.after.map(BigInt), [required(consumed) + q, required(delivered) + required(credit),
        required(Q) - q, required(C) - required(credit)]);
      assert.equal(required(consumed) + required(Q), BigInt(configured.input.originalUnits));
      assert.equal(required(delivered) + required(C), BigInt(configured.quotedCredit));
      const signed = required(records.signed.find(record => record.hash === row.transactionHash));
      assert.equal(signed.signer?.toLowerCase(), configured.input.originalWallet);
      assert.equal(BigInt(signed.receipt.status), 1n);
      const event = required(signed.receipt.logs.filter(log => log.address === parent)
        .map(log => migration.parseLog(log)).find(log => log?.name === "MigrationHeldSeLpSurrendered"));
      assert.deepEqual(event.args.toArray().map(String).map(v => v.toLowerCase()),
        [configured.input.originalId, configId, configured.input.originalWallet, source, q, credit, row.bondTokenId]
          .map(String).map(v => v.toLowerCase()));
      const args = migration.decodeFunctionData("surrenderMigrationHeldSeLp", signed.data);
      assert.equal(args[0], configured.input.originalId);
      assert.equal(args[1], q); assert.equal(args[2], credit);
      assert(args[3] >= BigInt(signed.receipt.blockTimestamp));
      const transfers = signed.receipt.logs.filter(log => (log.address === source || log.address === parent)
        && log.topics[0] === token.getEvent("Transfer")?.topicHash)
        .map(log => ({ token: log.address, event: token.parseLog(log) }));
      for (const [asset, from, to, amount] of [[source, configured.input.originalWallet, parent, q],
        [parent, "0x0000000000000000000000000000000000000000", parent, credit],
        [parent, parent, bond, credit], [parent, bond, staking, credit]]) {
        assert(transfers.some(transfer => transfer.token === asset && transfer.event?.args[0].toLowerCase() === from
          && transfer.event?.args[1].toLowerCase() === to && transfer.event?.args[2] === amount));
      }
      const created = required(signed.receipt.logs.filter(log => log.address === bond)
        .map(log => child.parseLog(log)).find(log => log?.name === "MigrationPositionCreated"));
      assert.equal(created.args[0], BigInt(row.bondTokenId));
      assert.equal(created.args[1].toLowerCase(), configured.input.originalWallet);
      assert.equal(created.args[2], credit);
      assert.equal(created.args[3], BigInt(signed.receipt.blockTimestamp));
      assert.equal(created.args[4] - created.args[3], 7776000n);
      assert.equal(row.position[3], String(signed.receipt.blockTimestamp));
      assert.equal(row.position[4], "7776000");
      assert.equal(BigInt(row.custodyBefore) - BigInt(row.bookedBefore), 7n);
      rows.push(row);
    }
    assert.deepEqual(required(rows[1]).after.slice(2), ["0", "0"]);
    assert.equal(required(rows[1]).after[1], configured.quotedCredit);
    assert.notEqual(required(rows[0]).bondTokenId, required(rows[1]).bondTokenId);
    assert(BigInt(required(rows[1]).position[3]) > BigInt(required(rows[0]).position[3]));
    configuredRows.push({ configuration: configured, configId, acquisition: acquired, rows });
  }
  const failures = records.signed.filter(row => row.path.includes("/held-signed-") && BigInt(row.receipt.status) === 0n);
  assert.equal(failures.length, 18);
  for (const failure of failures) assert.deepEqual(failure.receipt.logs, []);
  const loads = records.completions.filter(row => z.object({ method: z.string() }).passthrough()
    .parse(row.intent).method === "configureHeldSeLpEntitlements");
  assert.equal(loads.length, 6);
  return { acquisition, configuredRows, failures, loads };
}
