import assert from "node:assert/strict";
import { resolve } from "node:path";
import { AbiCoder, Interface, Transaction, keccak256, toUtf8Bytes } from "ethers";
import type { LogDescription } from "ethers";
import { z } from "zod";
import { preparationInput } from "../../../../../../../scripts/recovery/dtf-migration/schema.js";
import { canonical, json, required, uint } from "./evidence.js";
import type { receipts } from "./receipts.js";

const claim = new Interface([
  "function withdrawClaim(uint256) returns(uint256)",
  "function redeem(uint256,address,address) returns(uint256)",
  "event ClaimWithdrawn(address indexed user,uint256 stakeAmount,uint256 claimOut)",
  "event MigrationSnapshotCaptured(bytes32 indexed snapshotId,uint256 blockNumber)",
]);
const transfer = new Interface(["event Transfer(address indexed from,address indexed to,uint256 value)"]);
const child = new Interface(["event MigrationPositionCreated(uint256 indexed tokenId,address indexed owner,uint256 principal,uint256 startTimestamp,uint256 unlockTimestamp)"]);
const frame = z.object({ type: z.string(), from: z.string(), to: z.string(), input: z.string(),
  output: z.string().default("0x"), calls: z.array(z.unknown()).default([]), error: z.string().optional() }).passthrough();
function flatten(raw: unknown): z.infer<typeof frame>[] {
  const parsed = frame.parse(raw);
  return [parsed, ...parsed.calls.flatMap(flatten)];
}
const observation = z.object({
  kind: z.literal("surrender"), transactionHash: z.string(), quantity: uint, credit: uint,
  bondTokenId: uint, start: uint, duration: uint, remainingUnits: uint, remainingCredit: uint,
});

export async function claimedEconomics(runtime: string, records: Awaited<ReturnType<typeof receipts>>) {
  const manifest = z.object({ input: z.unknown(), payloads: z.object({ configure: z.object({
    weightedSy: z.array(z.object({ input: z.unknown(), configurationId: z.string(), quotedCredit: uint })),
  }).passthrough() }).passthrough() }).passthrough().parse(await json(resolve(runtime, "replacement/manifest.json")));
  const input = preparationInput.parse(manifest.input);
  const migration = new Interface(JSON.stringify(z.object({ abi: z.array(z.unknown()) }).passthrough()
    .parse(await json(resolve("out/IUniswapV4DetfMigration.sol/IUniswapV4DetfMigration.json"))).abi));
  const deployed = z.array(z.object({ role: z.string(), address: z.string() }).passthrough())
    .parse(await json(resolve(runtime, "deployed-runtime-bindings.json")));
  const bond = required(deployed.find(c => c.role === "bondNftVault")).address;
  const staking = required(deployed.find(c => c.role === "rebasingClaimToken")).address;
  const members = new Set<string>();
  const originals = [];
  for (const row of input.weightedSy) {
    const certificate = row.claimedOrigin;
    if (!certificate) continue;
    const { evidenceId, ...originalInputs } = row.original;
    assert.equal(evidenceId, keccak256(toUtf8Bytes(canonical({
      kind: "IndexedEx.complete-original-claimed-sy-v1", chainId: input.domain.chainId,
      proxy: input.domain.proxy, snapshotId: input.domain.snapshotId, original: originalInputs, certificate,
    }))));
    const configured = required(manifest.payloads.configure.weightedSy.find(c =>
      z.object({ originalId: z.string() }).passthrough().parse(c.input).originalId === row.original.originalId));
    const parameter = required(migration.getFunction("weightedSyEntitlement")?.outputs[0]?.components)
      .find(p => p.name === "original");
    const configId = keccak256(AbiCoder.defaultAbiCoder().encode(["uint256", "address", "bytes32", required(parameter)],
      [4663, input.domain.proxy, input.domain.snapshotId, row.original]));
    assert.equal(configId, configured.configurationId);
    const capture = required(records.signed.find(s => s.hash === certificate.snapshotCapture.transactionHash));
    assert.equal(capture.receipt.blockHash, certificate.snapshotCapture.blockHash);
    assert.equal(BigInt(capture.receipt.blockNumber), BigInt(certificate.snapshotCapture.blockNumber));
    assert(capture.receipt.logs.some(l => l.address === input.domain.proxy
      && l.topics[0] === claim.getEvent("MigrationSnapshotCaptured")?.topicHash
      && claim.parseLog(l)?.args[0] === input.domain.snapshotId));
    let weight = 0n, measured = 0n;
    const sourceClaims = [];
    for (const m of certificate.members) {
      assert(!members.has(m.transactionHash));
      members.add(m.transactionHash);
      const raw = required(records.signed.find(s => s.hash === m.transactionHash));
      const tx = Transaction.from(m.rawSignedTransaction);
      assert.equal(raw.raw, m.rawSignedTransaction);
      assert.equal(tx.hash, m.transactionHash);
      assert.equal(tx.from?.toLowerCase(), row.original.originalWallet);
      assert.equal(tx.to?.toLowerCase(), certificate.source);
      assert.equal(tx.chainId, 4663n);
      assert.equal(tx.value, 0n);
      assert.equal(BigInt(raw.receipt.status), 1n);
      assert.equal(raw.receipt.blockHash, m.blockHash);
      assert.equal(BigInt(raw.receipt.blockNumber), BigInt(m.blockNumber));
      assert.equal(claim.decodeFunctionData("withdrawClaim", raw.data)[0], BigInt(m.consumedWeight));
      const event: LogDescription = required(raw.receipt.logs.filter(l => l.address === certificate.source)
        .map(l => claim.parseLog(l)).find(l => l?.name === "ClaimWithdrawn"));
      assert.equal(event.args[0].toLowerCase(), row.original.originalWallet);
      assert.equal(event.args[1], BigInt(m.consumedWeight));
      assert.equal(event.args[2], BigInt(m.receivedSy));
      const mined = z.object({ trace: z.unknown() }).passthrough().parse(await json(raw.path));
      const trace = flatten(mined.trace);
      assert.equal(claim.decodeFunctionResult("withdrawClaim", required(trace[0]).output)[0], BigInt(m.receivedSy));
      assert(trace.every(f => f.error === undefined));
      const redeem: z.infer<typeof frame> = required(trace.find(f => f.type === "CALL" && f.from === certificate.source
        && f.to === certificate.vault && f.input.slice(0, 10) === "0xba087652"));
      assert.deepEqual(claim.decodeFunctionData("redeem", redeem.input).toArray().map(String).map(v => v.toLowerCase()),
        [m.redeemedVaultShares, row.original.originalWallet, certificate.source]);
      assert.equal(BigInt(redeem.output), BigInt(m.receivedSy));
      weight += event.args[1]; measured += event.args[2];
      sourceClaims.push({ transactionHash: raw.hash, weight: String(event.args[1]), output: String(event.args[2]),
        returnData: required(trace[0]).output, redeemedShares: m.redeemedVaultShares });
    }
    assert.equal(weight, BigInt(certificate.review.eligibleWeight));
    assert.equal(measured, BigInt(row.original.originalUnits));
    assert(measured > 0n);
    assert.equal(certificate.review.priorDeliveredCredit, "0");
    assert.equal(certificate.review.originalEth, row.original.originalEth);
    assert.equal(certificate.review.originalDtf, row.original.originalDtf);
    const index = certificate.members.length === 1 ? 231 : 232;
    const phases = [];
    let Q = measured, C = BigInt(configured.quotedCredit), delivered = 0n;
    for (const phase of ["partial", "terminal"]) {
      const file = z.object({ observations: z.array(z.unknown()) }).passthrough()
        .parse(await json(resolve(runtime, `claimed-sy-${index}-${phase}.json`)));
      const parsed = file.observations.map(o => observation.safeParse(o)).find(o => o.success);
      assert(parsed?.success);
      const o = parsed.data;
      const q = BigInt(o.quantity);
      const credit = q === Q ? C : C * q / Q;
      assert(q > 0n && credit > 0n);
      assert.equal(BigInt(o.credit), credit);
      Q -= q; C -= credit; delivered += credit;
      assert.equal(BigInt(o.remainingUnits), Q);
      assert.equal(BigInt(o.remainingCredit), C);
      const raw = required(records.signed.find(s => s.hash === o.transactionHash));
      assert.equal(raw.signer?.toLowerCase(), row.original.originalWallet);
      const args = migration.decodeFunctionData("surrenderMigrationWeightedSy", raw.data);
      assert.deepEqual(args.toArray().slice(0, 3).map(String), [row.original.originalId, String(q), String(credit)]);
      const transfers: { readonly asset: string; readonly event: LogDescription | null }[] =
        raw.receipt.logs.filter(l => (l.address === certificate.sy || l.address === input.domain.proxy)
        && l.topics[0] === transfer.getEvent("Transfer")?.topicHash)
        .map(l => ({ asset: l.address, event: transfer.parseLog(l) }));
      for (const [asset, from, to, amount] of [
        [certificate.sy, row.original.originalWallet, input.domain.proxy, q],
        [input.domain.proxy, "0x0000000000000000000000000000000000000000", input.domain.proxy, credit],
        [input.domain.proxy, input.domain.proxy, bond, credit], [input.domain.proxy, bond, staking, credit],
      ]) assert(transfers.some(t => t.asset === asset && t.event?.args[0].toLowerCase() === from
        && t.event?.args[1].toLowerCase() === to && t.event?.args[2] === amount));
      const created = required(raw.receipt.logs.filter(l => l.address === bond)
        .map(l => child.parseLog(l)).find(l => l?.name === "MigrationPositionCreated"));
      assert.equal(created.args[0], BigInt(o.bondTokenId));
      assert.equal(created.args[1].toLowerCase(), row.original.originalWallet);
      assert.equal(created.args[2], credit);
      assert.equal(created.args[3], BigInt(raw.receipt.blockTimestamp));
      assert.equal(created.args[4] - created.args[3], 7776000n);
      assert.equal(o.start, String(raw.receipt.blockTimestamp));
      phases.push({ phase, observation: o, transactionHash: raw.hash, quantity: String(q), credit: String(credit) });
      for (const rawObservation of file.observations) {
        const failure = z.object({ kind: z.literal("late-funding-rollback"), transactionHash: z.string() })
          .passthrough().safeParse(rawObservation);
        if (!failure.success) continue;
        const failed = required(records.signed.find(s => s.hash === failure.data.transactionHash));
        assert.equal(BigInt(failed.receipt.status), 0n);
        assert.deepEqual(failed.receipt.logs, []);
        assert(certificate.members.every(m => BigInt(m.blockNumber) < BigInt(failed.receipt.blockNumber)));
        const trace = flatten(z.object({ trace: z.unknown() }).passthrough().parse(await json(failed.path)).trace);
        const funding = new Interface(["function exchangeIn(address,uint256,address,uint256,address,bool,uint256)"])
          .encodeFunctionData("exchangeIn", [input.domain.proxy, credit, staking, credit, bond, false, BigInt(failed.receipt.blockTimestamp)]);
        assert(trace.some(f => f.to === staking && f.input === funding));
        assert(trace.every(f => f.to !== certificate.source));
      }
    }
    assert.equal(Q, 0n); assert.equal(C, 0n); assert.equal(delivered, BigInt(configured.quotedCredit));
    assert(BigInt(required(phases[1]).observation.start) > BigInt(required(phases[0]).observation.start));
    originals.push({ original: row.original, configurationId: configId, completeWeight: String(weight),
      measuredSy: String(measured), originalCredit: configured.quotedCredit, sourceClaims, phases });
  }
  assert.equal(originals.length, 2);
  assert.equal(members.size, 4);
  assert(originals.some(o => o.sourceClaims.some(c => c.weight === "1" && c.output === "0")));
  return { originals, uniqueMembers: members.size,
    provenance: "actual retained direct controlled signatures and canonical receipts; historical W0/E0/D0/zero-delivery partitions remain synthetic reviewed inputs" };
}
