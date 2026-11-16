// Adapted read-only from accepted phase19 evidence; original files remain unchanged.
import assert from "node:assert/strict";
import { resolve } from "node:path";
import { AbiCoder, Interface, keccak256 } from "ethers";
import { z } from "zod";
import { address, hash, hex, json, required, root, uint } from "./evidence.js";
import type { receipts } from "./receipts.js";

const ED = "0xaf0e1967c8f755c747615c5427108bc549ca1122";
const original = z.object({
  originalId: hash, originalWallet: address, source: z.literal(ED), originalUnits: uint,
  originalEth: uint, originalDtf: uint, evidenceId: hash, contributionsKnown: z.literal(true),
});
const observation = z.object({
  kind: z.literal("surrender"), transactionHash: hash, original, q: uint, credit: uint, bondTokenId: uint,
  position: z.tuple([uint, uint, uint, uint, uint]), before: z.tuple([uint, uint, uint, uint]),
  after: z.tuple([uint, uint, uint, uint]), custodyBefore: uint, bookedBefore: uint, protectedBefore: z.string(),
});
async function abi(name: string) {
  const file = z.object({ abi: z.array(z.unknown()) }).passthrough()
    .parse(await json(resolve(root, "out", `${name}.sol`, `${name}.json`)));
  return new Interface(JSON.stringify(file.abi));
}
export async function edEconomics(runtime: string, records: Awaited<ReturnType<typeof receipts>>) {
  const migration = await abi("IUniswapV4DetfMigration");
  const allocationArtifact = z.object({ abi: z.array(z.unknown()) }).passthrough()
    .parse(await json(resolve(root, "out/IUniswapV4DetfMigration.sol/IUniswapV4DetfMigrationAllocation.json")));
  const allocation = new Interface(JSON.stringify(allocationArtifact.abi));
  const child = await abi("IUniswapV4DetfMigrationBondNFTVault");
  const token = new Interface(["event Transfer(address indexed from,address indexed to,uint256 amount)",
    "event Approval(address indexed owner,address indexed spender,uint256 amount)"]);
  const components = z.array(z.object({ role: z.string(), address }).passthrough())
    .parse(await json(resolve(runtime, "deployed-runtime-bindings.json")));
  const parent = records.manifest.proxy;
  const bond = required(components.find(c => c.role === "bondNftVault")).address;
  const staking = required(components.find(c => c.role === "rebasingClaimToken")).address;
  const prepared = z.object({
    input: z.object({ domain: z.object({ snapshotId: hash }).passthrough() }).passthrough(),
    payloads: z.object({ configure: z.object({ earlierLiquid: z.array(z.object({
      input: original, configurationId: hash, quotedCredit: uint,
    })) }).passthrough() }).passthrough(),
  }).passthrough().parse(await json(resolve(runtime, "replacement/manifest.json")));
  const configured = required(prepared.payloads.configure.earlierLiquid[0]);
  const parameter = required(allocation.getFunction("configureEarlierLiquidEntitlements")?.inputs[0]?.arrayChildren);
  const configId = keccak256(AbiCoder.defaultAbiCoder().encode(["uint256", "address", "bytes32", parameter],
    [4663, parent, prepared.input.domain.snapshotId, configured.input]));
  assert.equal(configId, configured.configurationId);
  const acquisition = z.object({ source: z.literal(ED), donor: address, originalWallet: address, originalUnits: uint,
    receipt: z.object({ logs: z.array(z.object({ address, topics: z.array(hash), data: hex }).passthrough()) }).passthrough(),
    facets: z.array(z.object({ facet: address, code: hex, codeHash: hash }).passthrough()),
  }).passthrough().parse(await json(resolve(runtime, "earlier-liquid-acquisition.json")));
  assert.equal(acquisition.originalWallet, configured.input.originalWallet);
  assert.equal(BigInt(acquisition.originalUnits) - BigInt(configured.input.originalUnits), 7n);
  assert(acquisition.receipt.logs.some(log => log.address === ED && token.parseLog(log)?.name === "Transfer"
    && token.parseLog(log)?.args[0].toLowerCase() === acquisition.donor
    && token.parseLog(log)?.args[1].toLowerCase() === acquisition.originalWallet
    && token.parseLog(log)?.args[2] === BigInt(acquisition.originalUnits)));
  for (const facet of acquisition.facets) {
    assert.equal(facet.facet, "0x1d17aca0e0717d90cea916372070a1be4652223f");
    assert.equal(keccak256(facet.code), facet.codeHash);
    assert.equal(facet.codeHash, "0xf250dca135b1de9a5fc9ceda732c06af7020fef1d45d7c43dfa92efe02b47e50");
  }
  const rows = [];
  for (const phase of ["partial", "terminal"]) {
    const file = z.object({ observations: z.array(z.unknown()) }).passthrough()
      .parse(await json(resolve(runtime, `earlier-liquid-${phase}.json`)));
    const parsed = file.observations.map(value => observation.safeParse(value)).find(value => value.success);
    assert(parsed?.success);
    const row = parsed.data;
    assert.deepEqual(row.original, configured.input);
    const [consumed, delivered, Q, C] = row.before.map(BigInt);
    const q = BigInt(row.q);
    const credit = q === Q ? C : required(C) * q / required(Q);
    assert(q > 0n && q <= required(Q) && required(credit) > 0n);
    assert.equal(BigInt(row.credit), credit);
    assert.deepEqual(row.after.map(BigInt),
      [required(consumed) + q, required(delivered) + required(credit), required(Q) - q, required(C) - required(credit)]);
    assert.equal(required(consumed) + required(Q), BigInt(configured.input.originalUnits));
    assert.equal(required(delivered) + required(C), BigInt(configured.quotedCredit));
    const raw = required(records.signed.find(s => s.hash === row.transactionHash));
    assert.equal(BigInt(raw.receipt.status), 1n);
    assert.equal(raw.signer?.toLowerCase(), configured.input.originalWallet);
    const args = migration.decodeFunctionData("surrenderMigrationEarlierLiquid", raw.data);
    assert.equal(args[0], configured.input.originalId); assert.equal(args[1], q); assert.equal(args[2], credit);
    assert(args[3] >= BigInt(raw.receipt.blockTimestamp));
    const event = required(raw.receipt.logs.filter(log => log.address === parent)
      .map(log => migration.parseLog(log)).find(log => log?.name === "MigrationEarlierLiquidSurrendered"));
    assert.deepEqual(event.args.toArray().map(String).map(v => v.toLowerCase()),
      [configured.input.originalId, configId, configured.input.originalWallet, q, credit, row.bondTokenId]
        .map(String).map(v => v.toLowerCase()));
    const transfers = raw.receipt.logs.filter(log => (log.address === ED || log.address === parent)
      && log.topics[0] === token.getEvent("Transfer")?.topicHash)
      .map(log => ({ token: log.address, event: token.parseLog(log) }));
    for (const [asset, from, to, amount] of [
      [ED, configured.input.originalWallet, parent, q],
      [parent, "0x0000000000000000000000000000000000000000", parent, credit],
      [parent, parent, bond, credit], [parent, bond, staking, credit],
    ]) assert(transfers.some(t => t.token === asset && t.event?.args[0].toLowerCase() === from
      && t.event?.args[1].toLowerCase() === to && t.event?.args[2] === amount));
    const created = required(raw.receipt.logs.filter(log => log.address === bond)
      .map(log => child.parseLog(log)).find(log => log?.name === "MigrationPositionCreated"));
    assert.equal(created.args[0], BigInt(row.bondTokenId));
    assert.equal(created.args[1].toLowerCase(), configured.input.originalWallet);
    assert.equal(created.args[2], credit); assert.equal(created.args[3], BigInt(raw.receipt.blockTimestamp));
    assert.equal(created.args[4] - created.args[3], 7776000n);
    assert.deepEqual(row.position.slice(0, 2), [String(credit), "0"]);
    assert.equal(row.position[3], String(raw.receipt.blockTimestamp)); assert.equal(row.position[4], "7776000");
    assert.equal(BigInt(row.custodyBefore) - BigInt(row.bookedBefore), 7n);
    assert(BigInt(required(row.protectedBefore.split("|")[0])) > 0n);
    assert(BigInt(required(row.protectedBefore.split("|")[1])) > 0n);
    rows.push(row);
  }
  assert(BigInt(required(rows[0]).bookedBefore) > 0n);
  assert.deepEqual(required(rows[1]).after.slice(2), ["0", "0"]);
  assert.equal(required(rows[1]).after[1], configured.quotedCredit);
  assert.notEqual(required(rows[0]).bondTokenId, required(rows[1]).bondTokenId);
  const failures = records.signed.filter(row => row.path.includes("/ed-signed-") && BigInt(row.receipt.status) === 0n);
  assert.equal(failures.length, 5);
  for (const failure of failures) assert.deepEqual(failure.receipt.logs, []);
  return { acquisition, configuration: configured, configId, rows, failures };
}
