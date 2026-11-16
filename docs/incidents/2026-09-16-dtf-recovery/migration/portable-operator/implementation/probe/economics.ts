// Adapted read-only from accepted phase19 evidence; original files remain unchanged.
import assert from "node:assert/strict";
import { resolve } from "node:path";
import { AbiCoder, Interface, Result, keccak256 } from "ethers";
import { z } from "zod";
import { address, hash, hex, json, required, root, uint } from "./evidence.js";
import type { receipts } from "./receipts.js";

const original = z.object({
  originalId: hash, originalWallet: address, source: address, originalUnits: uint,
  originalEth: uint, originalDtf: uint, evidenceId: hash, contributionsKnown: z.literal(true),
});
const state = z.object({
  walletInternal: uint, custodyInternal: uint, walletExternal: uint, custodyExternal: uint,
  walletDisplay: uint, custodyDisplay: uint, rate: uint, total: uint, allowance: uint,
  B: uint, E: uint, supply: uint, backing: uint, surrender: z.tuple([uint, uint, uint, uint]),
});
const er = "0x4ac89ad061a531fa62ddceed53520c2750113b01";
const S = 10n ** 9n, U = 10n ** 27n;
async function abi(name: string) {
  const artifact = z.object({ abi: z.array(z.unknown()) }).passthrough()
    .parse(await json(resolve(root, "out", `${name}.sol`, `${name}.json`)));
  return new Interface(JSON.stringify(artifact.abi));
}

export async function economics(runtime: string, records: Awaited<ReturnType<typeof receipts>>) {
  const migration = await abi("IUniswapV4DetfMigration");
  const allocation = await abi("IUniswapV4DetfMigration");
  const child = await abi("IUniswapV4DetfMigrationBondNFTVault");
  const token = new Interface(["event Transfer(address indexed from,address indexed to,uint256 amount)",
    "event Approval(address indexed owner,address indexed spender,uint256 amount)"]);
  const components = z.array(z.object({ role: z.string(), address }).passthrough())
    .parse(await json(resolve(runtime, "deployed-runtime-bindings.json")));
  const parent = records.manifest.proxy;
  const bond = required(components.find(c => c.role === "bondNftVault")).address;
  const staking = required(components.find(c => c.role === "rebasingClaimToken")).address;
  const acquisition = z.object({
    originalWallet: address, nativeInput: uint, originalOperationRate: uint, eligibleOriginalInternal: uint,
    totalOriginalInternal: uint, excludedOriginalInternal: uint,
    facets: z.array(z.object({ facet: address, code: hex, codeHash: hash }).passthrough()),
  }).passthrough().parse(await json(resolve(runtime, "earlier-receipt-acquisition.json")));
  assert.equal(BigInt(acquisition.nativeInput) * U / BigInt(acquisition.originalOperationRate),
    BigInt(acquisition.eligibleOriginalInternal));
  assert.equal(BigInt(acquisition.eligibleOriginalInternal) + BigInt(acquisition.excludedOriginalInternal),
    BigInt(acquisition.totalOriginalInternal));
  for (const f of acquisition.facets) {
    assert.equal(f.facet, "0x25e611fb63eb904776678286ef5cbe2a931b4f9a");
    assert.equal(keccak256(f.code), f.codeHash);
    assert.equal(f.codeHash, "0x31151be4bf8ff8e79f448872f9a0a5c37ee413ce7d2b15206f2debcc59d86ccc");
  }
  const prepared = z.object({
    input: z.object({ domain: z.object({ chainId: uint, proxy: address, snapshotId: hash }).passthrough() }).passthrough(),
    payloads: z.object({ configure: z.object({ earlierReceipt: z.array(z.object({
      input: original, configurationId: hash, quotedCredit: uint,
    })) }).passthrough() }).passthrough(),
    quoteEvidence: z.object({ snapshot: hex, snapshotId: hash }).passthrough(),
  }).passthrough().parse(await json(resolve(runtime, "replacement/manifest.json")));
  const configured = required(prepared.payloads.configure.earlierReceipt[0]);
  const snapshot = migration.decodeFunctionResult("migrationSnapshot", prepared.quoteEvidence.snapshot)[0];
  assert(snapshot instanceof Result);
  const output = required(migration.getFunction("migrationSnapshot")?.outputs[0]);
  const values = snapshot.toArray();
  const idIndex = required(output.components).findIndex(p => p.name === "id");
  assert(idIndex >= 0);
  values[idIndex] = `0x${"0".repeat(64)}`;
  assert.equal(keccak256(AbiCoder.defaultAbiCoder().encode(["string", output],
    ["IndexedEx.frozen-original-credit", values])), prepared.input.domain.snapshotId);
  const parameter = required(allocation.getFunction("earlierReceiptEntitlement")?.outputs[0]?.components)
    .find(p => p.name === "original");
  const configId = keccak256(AbiCoder.defaultAbiCoder().encode(["uint256", "address", "bytes32", required(parameter)],
    [4663, parent, prepared.input.domain.snapshotId, configured.input]));
  assert.equal(configId, configured.configurationId);
  const rows = [];
  for (const phase of ["partial", "changed-rate"]) {
    const observation = z.object({
      original, before: state, after: state, nativeAmount: uint, q: uint, credit: uint,
      bond: uint, position: z.tuple([uint, uint, uint, uint, uint]), transactionHash: hash,
    }).passthrough().parse(await json(resolve(runtime, `earlier-receipt-${phase}.json`)));
    assert.deepEqual(observation.original, configured.input);
    const b = observation.before, a = observation.after;
    const n = BigInt(observation.nativeAmount), r = BigInt(b.rate), q = n * U / r;
    const Q = BigInt(b.surrender[2]), C = BigInt(b.surrender[3]);
    assert(q > 0n && q <= Q && r > 0n);
    const credit = q === Q ? C : C * q / Q;
    assert(credit > 0n);
    assert.equal(q, BigInt(observation.q)); assert.equal(credit, BigInt(observation.credit));
    assert.equal(BigInt(b.walletInternal) - BigInt(a.walletInternal), q);
    assert.equal(BigInt(a.custodyInternal) - BigInt(b.custodyInternal), q);
    assert.equal(BigInt(b.allowance) - BigInt(a.allowance), n);
    assert.equal(a.rate, b.rate); assert.equal(a.total, b.total); assert.equal(a.E, b.E);
    for (const s of [b, a]) {
      assert.equal(BigInt(s.walletInternal) / S, BigInt(s.walletExternal));
      assert.equal(BigInt(s.custodyInternal) / S, BigInt(s.custodyExternal));
      assert.equal(BigInt(s.walletInternal) * r / U, BigInt(s.walletDisplay));
      assert.equal(BigInt(s.custodyInternal) * r / U, BigInt(s.custodyDisplay));
      assert.equal(BigInt(s.surrender[0]) + BigInt(s.surrender[2]), BigInt(configured.input.originalUnits));
      assert.equal(BigInt(s.surrender[1]) + BigInt(s.surrender[3]), BigInt(configured.quotedCredit));
    }
    assert.equal(BigInt(a.B) - BigInt(b.B), q);
    assert.equal(BigInt(a.custodyInternal) - BigInt(a.E) * S - BigInt(a.B),
      BigInt(b.custodyInternal) - BigInt(b.E) * S - BigInt(b.B));
    assert.equal(BigInt(a.surrender[2]), Q - q); assert.equal(BigInt(a.surrender[3]), C - credit);
    assert.equal(BigInt(a.supply) - BigInt(b.supply), credit);
    assert.equal(BigInt(a.backing) - BigInt(b.backing), credit);
    const dw = BigInt(b.walletExternal) - BigInt(a.walletExternal), dm = BigInt(a.custodyExternal) - BigInt(b.custodyExternal);
    const L = ((dw > dm ? dw : dm) - 1n) * S + 1n, H1 = ((dw < dm ? dw : dm) + 1n) * S;
    assert(L > 0n && L < H1 && H1 <= 2n ** 256n - 1n);
    assert.equal(n * U / H1 + 1n, r); assert.equal(n * U / L, r);
    const raw = required(records.signed.find(s => s.hash === observation.transactionHash));
    assert.equal(BigInt(raw.receipt.status), 1n);
    const args = migration.decodeFunctionData("surrenderMigrationEarlierReceipt", raw.data);
    assert.equal(args[0], observation.original.originalId); assert.equal(args[1], n); assert.equal(args[2], credit);
    assert(BigInt(args[3]) >= BigInt(raw.receipt.blockTimestamp));
    const emitted = required(raw.receipt.logs.filter(l => l.address === parent)
      .map(l => migration.parseLog(l)).find(l => l?.name === "MigrationEarlierReceiptSurrendered"));
    assert.deepEqual(emitted.args.toArray().map(String).map(v => v.toLowerCase()),
      [observation.original.originalId, configId, observation.original.originalWallet, n, q, r, credit, observation.bond]
        .map(String).map(v => v.toLowerCase()));
    const bondEvents = raw.receipt.logs.filter(l => l.address === bond).map(l => child.parseLog(l));
    const created = required(bondEvents.find(e => e?.name === "MigrationPositionCreated"));
    assert.equal(created.args[0], BigInt(observation.bond)); assert.equal(created.args[1].toLowerCase(), observation.original.originalWallet);
    assert.equal(created.args[2], credit); assert.equal(created.args[3], BigInt(raw.receipt.blockTimestamp));
    assert.equal(created.args[4] - created.args[3], 7776000n);
    assert.deepEqual(observation.position.slice(0, 2), [String(credit), "0"]);
    assert.equal(observation.position[3], String(raw.receipt.blockTimestamp)); assert.equal(observation.position[4], "7776000");
    const transfers = raw.receipt.logs.filter(l => l.address === parent && l.topics[0] === token.getEvent("Transfer")?.topicHash)
      .map(l => token.parseLog(l));
    for (const [from, to] of [["0x0000000000000000000000000000000000000000", parent], [parent, bond], [bond, staking]]) {
      assert(transfers.some(t => t?.args[0].toLowerCase() === from && t?.args[1].toLowerCase() === to && t?.args[2] === credit));
    }
    rows.push({ phase, observation, q, credit, rLow: n * U / H1 + 1n, rHigh: n * U / L,
      sourceTransfer: raw.receipt.logs.filter(l => l.address === er), childEvents: bondEvents, transaction: raw.hash });
  }
  assert(BigInt(required(rows[1]).observation.before.rate) > BigInt(required(rows[0]).observation.before.rate));
  return { acquisition, configuration: configured, configId, snapshotId: prepared.input.domain.snapshotId, rows };
}
