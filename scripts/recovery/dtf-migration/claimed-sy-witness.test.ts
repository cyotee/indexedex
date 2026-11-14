import { test } from "node:test";
import assert from "node:assert/strict";
import { keccak256 } from "ethers";
import { readFile } from "node:fs/promises";
import { z } from "zod";
import { claimFrame, claimFrames, claimWitness, claimWitnessCodeHash, checkClaimEffects,
  witnessedClaimBooks } from "./claimed-sy-witness.js";
import { stakingClaim, stakingSource, claimBookFacets } from "./claimed-sy-source.js";
import { claimedSyCertificate } from "./schema.js";
import { a, h } from "./preparation.fixture.js";

const wallet = a(1);
const router = a(2);
const vault = "0xaf5c0cd3fdedd10bee00eff77fa0429bacdb41f0";
const sy = "0xb55604cf4dcdabb362078e106d20f98512391edf";
const certificate = claimedSyCertificate.parse({
  kind: "complete-remaining-token-staking", chainId: "4663", source: stakingSource, vault, sy,
  snapshotCapture: { transactionHash: h(1), blockHash: h(2), blockNumber: "10" },
  review: { authority: "unit fixture only", originalId: h(3), originalWallet: wallet,
    originalEth: "100", originalDtf: "22", originalWeight: "30", eligibleWeight: "10",
    priorDeliveredCredit: "0", contributionsKnown: true, eligiblePrincipalOnly: true, rewardsExcluded: true,
    aliasesReconciled: true, competingRepresentationsExcluded: true, unrelatedWeightFloor: "7", unrelatedSyFloor: "5" },
  members: [{ transactionHash: h(4), rawSignedTransaction: "0x", blockHash: h(5), blockNumber: "12",
    consumedWeight: "10", receivedSy: "3", redeemedVaultShares: "30",
    execution: { kind: "witnessed-eip7702-v1", delegate: a(3), delegateCodeHash: h(6), witness: router } }],
});
const member = certificate.members[0];
assert.ok(member);
const before = { weight: 17n, supply: 100n, shares: 300n, vaultSupply: 400n, sy: 5n, vaultSy: 80n, sySupply: 90n };
const after = { weight: 7n, supply: 90n, shares: 270n, vaultSupply: 370n, sy: 8n, vaultSy: 77n, sySupply: 90n };

test("transaction-local books enforce each conservation leg and excluded floors", () => {
  checkClaimEffects({ before, after }, member, certificate.review);
  for (const key of Object.keys(after)) {
    assert.throws(() => checkClaimEffects({ before, after: { ...after, [key]: 0n } }, member, certificate.review),
      { code: "PROVENANCE", reason: "EFFECTS" });
  }
  for (const review of [
    { ...certificate.review, unrelatedSyFloor: "6" },
    { ...certificate.review, unrelatedWeightFloor: "8" },
  ]) assert.throws(() => checkClaimEffects({ before, after }, member, review), { reason: "EFFECTS" });
  // A neighboring transaction returning forwarded SY must not repair this claim's net receipt.
  assert.throws(() => checkClaimEffects({ before, after: { ...after, sy: before.sy } }, member, certificate.review),
    { reason: "EFFECTS" });
});

function wireWitness() {
  const requests = [
    [stakingSource, "balanceOf", [wallet]], [stakingSource, "totalSupply", []],
    [vault, "balanceOf", [stakingSource]], [vault, "totalSupply", []],
    [sy, "balanceOf", [wallet]], [sy, "balanceOf", [vault]], [sy, "totalSupply", []],
  ] as const;
  const reads = (values: readonly bigint[]) => requests.map(([to, method, args], i) => ({
    type: "STATICCALL", from: router, to, input: stakingClaim.encodeFunctionData(method, args),
    output: stakingClaim.encodeFunctionResult(method, [values[i]]), calls: [{
      type: "DELEGATECALL", from: to, to: claimBookFacets[to],
      input: stakingClaim.encodeFunctionData(method, args),
      output: stakingClaim.encodeFunctionResult(method, [values[i]]), calls: [],
    }],
  }));
  const inner = { type: "CALL", from: router, to: wallet, input: "0x12345678", output: "0x", calls: [] };
  return claimFrame.parse({ type: "CALL", from: a(9), to: router,
    input: claimWitness.encodeFunctionData("witness", [wallet, inner.input]), output: "0x",
    calls: [...reads([17n, 100n, 300n, 400n, 5n, 80n, 90n]), inner,
      ...reads([7n, 90n, 270n, 370n, 8n, 77n, 90n])] });
}

test("RPC trace decoder requires complete ordered static observations around the original wallet", () => {
  const root = wireWitness();
  assert.deepEqual(witnessedClaimBooks(root, wallet), { before, after });
  for (const changed of [
    { ...root, calls: root.calls.slice(1) },
    { ...root, calls: [...root.calls, root.calls[7]] },
    { ...root, calls: root.calls.map((call, i) => i === 0 ? { ...claimFrame.parse(call), type: "CALL" } : call) },
    { ...root, calls: root.calls.map((call, i) => i === 4 ? { ...claimFrame.parse(call), to: a(99) } : call) },
    { ...root, calls: root.calls.map((call, i) => i === 7 ? { ...claimFrame.parse(call), to: a(99) } : call) },
    { ...root, calls: root.calls.map((call, i) => i === 0 ? { ...claimFrame.parse(call), calls: [] } : call) },
    { ...root, input: claimWitness.encodeFunctionData("witness", [a(99), "0x12345678"]) },
  ]) assert.throws(() => witnessedClaimBooks(changed, wallet), { reason: "WITNESS_SHAPE" });
});

test("caught inner failure is rejected even when the outer witness succeeds", () => {
  const root = wireWitness();
  assert.throws(() => claimFrames({ ...root, calls: root.calls.map((call, i) =>
    i === 7 ? { ...claimFrame.parse(call), calls: [{ ...claimFrame.parse(call), error: "execution reverted" }] } : call) }),
  { code: "PROVENANCE", reason: "TRACE_FAILED" });
});

test("fixed witness pin matches the concrete compiled router used by the rehearsal", async () => {
  const artifact = z.object({ deployedBytecode: z.object({ object: z.string() }) }).parse(
    JSON.parse(await readFile("out/MigrationClaimWitness.sol/MigrationClaimWitness.json", "utf8")));
  assert.equal(keccak256(artifact.deployedBytecode.object), claimWitnessCodeHash);
});
