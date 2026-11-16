import { test } from "node:test";
import assert from "node:assert/strict";
import { AbiCoder, keccak256 } from "ethers";
import { fixture, h } from "./preparation.fixture.js";
import { claimedSyCertificate } from "./schema.js";
import { claimedSyEvidenceId } from "./claimed-sy.js";
import { buildPayloads, configurationId, weightedSySource } from "./payloads.js";
import { interfaceFile } from "./rehearsal-data.js";

test("remaining claimed SY retains the full original and binds its eligible weight fraction", async () => {
  const f = await fixture();
  try {
    const row = f.input.weightedSy[0];
    assert.ok(row);
    const { originalId, originalWallet, originalEth, originalDtf } = row.original;
    const certificate = claimedSyCertificate.parse({
      kind: "complete-remaining-token-staking", chainId: "4663",
      source: "0xe4c9ff4cfd17ae73ecb3825ebdf7db113c146d00",
      vault: "0xaf5c0cd3fdedd10bee00eff77fa0429bacdb41f0", sy: weightedSySource,
      pricingSet: { bookId: f.input.domain.bookId, transactionHash: h(2300), blockNumber: "90", blockHash: h(90) },
      review: { originalId, originalWallet, originalEth, originalDtf,
        authority: "synthetic reviewed remainder, not an operational allocation",
        originalWeight: "30039", eligibleWeight: "10013", priorDeliveredCredit: "0",
        contributionsKnown: true, eligiblePrincipalOnly: true, rewardsExcluded: true,
        aliasesReconciled: true, competingRepresentationsExcluded: true,
        unrelatedWeightFloor: "7", unrelatedSyFloor: "5" },
      members: [{ transactionHash: h(2301), rawSignedTransaction: "0x", blockNumber: "98",
        blockHash: h(98), consumedWeight: "10013", receivedSy: "3", redeemedVaultShares: "30" }],
    });
    const inputFor = (c: typeof certificate) => ({ ...f.input, weightedSy: [{
      ...row, claimedOrigin: c,
      original: { ...row.original, evidenceId: claimedSyEvidenceId(f.input.domain, row.original, c) },
    }] });
    const payload = buildPayloads(inputFor(certificate)).weightedSy[0];
    assert.ok(payload?.claimBasis);
    assert.equal(payload.originalEth, "100");
    assert.equal(payload.originalDtf, "22");
    assert.equal(payload.originalUnits, "3");
    assert.deepEqual(payload.claimBasis, { originalWeight: "30039", eligibleWeight: "10013" });
    const allocation = await interfaceFile("out/IUniswapV4DetfMigration.sol/IUniswapV4DetfMigrationAllocation.json");
    const parameter = allocation.getFunction("configureClaimedSyEntitlements")?.inputs[0]?.arrayChildren;
    assert.ok(parameter);
    const value = { original: payload, ...payload.claimBasis };
    const data = allocation.encodeFunctionData("configureClaimedSyEntitlements", [[value], f.input.domain.bookId]);
    const decoded = allocation.decodeFunctionData("configureClaimedSyEntitlements", data)[0][0];
    assert.equal(decoded.originalWeight, 30039n);
    assert.equal(decoded.eligibleWeight, 10013n);
    assert.equal(decoded.original.originalUnits, 3n);
    assert.equal(configurationId(f.input.domain, payload), keccak256(AbiCoder.defaultAbiCoder().encode(
      ["uint256", "address", "bytes32", parameter],
      [f.input.domain.chainId, f.input.domain.proxy, f.input.domain.bookId, value])));
    const { claimBasis: _basis, ...ordinary } = payload;
    assert.notEqual(configurationId(f.input.domain, payload), configurationId(f.input.domain, ordinary));
    const { originalWeight: _full, ...withoutFull } = certificate.review;
    for (const changed of [
      { ...certificate, review: withoutFull },
      { ...certificate, review: { ...certificate.review, originalWeight: "10012" } },
      { ...certificate, kind: "complete-original-token-staking" as const },
    ]) {
      assert.throws(() => buildPayloads(inputFor(changed)),
        { name: "PreparationError", code: "PROVENANCE" });
    }
    const member = certificate.members[0];
    assert.ok(member);
    assert.throws(() => buildPayloads(inputFor({ ...certificate,
      members: [{ ...member, consumedWeight: "10012" }] })), /coverage/);
  } finally {
    await f.close();
  }
});
