import { test } from "node:test";
import assert from "node:assert/strict";
import { AbiCoder, keccak256 } from "ethers";
import { fixture, a, h } from "./preparation.fixture.js";
import { preparationInput } from "./schema.js";
import { buildPayloads, configurationId, weightedLiquidSource } from "./payloads.js";
import { prepareDomain } from "./preparation.js";
import { interfaceFile } from "./rehearsal-data.js";

test("W-L requires known original wallet, quantity, components and origin, not current holdings", async () => {
  const f = await fixture();
  try {
    const original = f.input.weightedLiquid[0]?.original;
    assert.ok(original);
    for (const field of ["originalId", "originalWallet", "originalUnits", "originalEth", "originalDtf", "source", "evidenceId"] as const) {
      const { [field]: _missing, ...omitted } = original;
      assert.equal(preparationInput.safeParse({ ...f.input, weightedLiquid: [{
        original: omitted, proof: f.input.weightedLiquid[0]?.proof,
      }] }).success, false);
    }
    for (const changed of [{ originalUnits: "0" }, { originalWallet: a(0) }, { contributionsKnown: false }, { credit: "1001" }]) {
      assert.equal(preparationInput.safeParse({ ...f.input, weightedLiquid: [{
        ...f.input.weightedLiquid[0], original: { ...original, ...changed },
      }] }).success, false);
    }
    const row = f.input.weightedLiquid[0];
    assert.ok(row);
    await assert.rejects(prepareDomain({ ...f.input, weightedLiquid: [{
      ...row, original: { ...original, originalWallet: a(99) },
    }] }), { name: "PreparationError", code: "PROVENANCE" });
  } finally { await f.close(); }
});

test("W-L fixed source, original units and economic partition are required by the real payload builder", async () => {
  const f = await fixture();
  try {
    const row = f.input.weightedLiquid[0];
    assert.ok(row);
    assert.throws(() => buildPayloads({ ...f.input, weightedLiquid: [{
      ...row, original: { ...row.original, source: a(99) },
    }] }), /fixed WD/);
    assert.throws(() => buildPayloads({ ...f.input, weightedLiquid: [{
      ...row, original: { ...row.original, originalUnits: "4" },
    }] }), /original units/);
    assert.throws(() => buildPayloads({ ...f.input, weightedLiquid: [row, row] }), /overlapping original/);
    assert.throws(() => buildPayloads({ ...f.input, weightedLiquid: [] }), /unassigned origin/);
    const independent = f.input.independent[0];
    assert.ok(independent);
    const overlap = { ...independent, entitlements: [{
      original: { entitlementId: row.original.originalId, originalEth: "100", originalDtf: "22", evidenceId: h(900) },
      proof: row.proof,
    }] };
    assert.throws(() => buildPayloads({ ...f.input, independent: [overlap] }), /missing matching origin/);
    assert.equal(buildPayloads(f.input).weightedLiquid[0]?.source, weightedLiquidSource);
  } finally { await f.close(); }
});

test("W-L complete configuration hash agrees with Solidity and typed stage ABI including wallet and Q0", async () => {
  const f = await fixture();
  try {
    const original = f.input.weightedLiquid[0]?.original;
    assert.ok(original);
    const allocation = await interfaceFile("out/IUniswapV4DetfMigration.sol/IUniswapV4DetfMigrationAllocation.json");
    const stage = await interfaceFile("out/Phase_08_Stage_01_MigrationExecution.s.sol/Phase_08_Stage_01_MigrationExecution.json");
    const parameter = allocation.getFunction("configureWeightedLiquidEntitlements")?.inputs[0];
    const stageParameter = stage.getFunction("configureWeightedLiquid")?.inputs[1];
    assert.ok(parameter?.arrayChildren);
    assert.ok(stageParameter);
    assert.equal(parameter.format("full"), stageParameter.format("full"));
    const encoded = allocation.encodeFunctionData("configureWeightedLiquidEntitlements", [[original]]);
    const decoded = allocation.decodeFunctionData("configureWeightedLiquidEntitlements", encoded)[0][0];
    assert.equal(decoded.originalWallet.toLowerCase(), original.originalWallet);
    assert.equal(decoded.originalUnits, 3n);
    assert.equal(decoded.originalId, original.originalId);
    assert.equal(configurationId(f.input.domain, original), keccak256(AbiCoder.defaultAbiCoder().encode(
      ["uint256", "address", "bytes32", parameter.arrayChildren],
      [f.input.domain.chainId, f.input.domain.proxy, f.input.domain.snapshotId, original])));
    for (const correction of [{ originalWallet: a(99) }, { originalUnits: "4" }, { originalEth: "101" }, { evidenceId: h(900) }]) {
      assert.notEqual(configurationId(f.input.domain, { ...original, ...correction }), configurationId(f.input.domain, original));
    }
  } finally { await f.close(); }
});
