import { test } from "node:test";
import assert from "node:assert/strict";
import { writeFile } from "node:fs/promises";
import { join } from "node:path";
import { AbiCoder, keccak256 } from "ethers";
import { fixture, a, h } from "./preparation.fixture.js";
import { preparationInput } from "./schema.js";
import { buildPayloads, configurationId, weightedReceiptSource } from "./payloads.js";
import { prepareDomain } from "./preparation.js";
import { canonical, fingerprint } from "./provenance.js";
import { interfaceFile } from "./rehearsal-data.js";

async function receiptFixture() {
  const f = await fixture();
  const original = {
    originalId: h(300), originalWallet: a(117), source: weightedReceiptSource,
    originalUnits: "88423667347055516852883910490677229029",
    originalEth: "100", originalDtf: "22", evidenceId: h(301), contributionsKnown: true as const,
  };
  const exposure = { originId: original.originalId, category: "weighted-receipt" as const,
    originalUnits: original.originalUnits, descendants: [{ id: h(302), units: original.originalUnits }],
    recoveredUnits: "0", excludedUnits: "0" };
  const path = join(f.root, "receipt-original.json");
  const raw = canonical({ original, exposure });
  await writeFile(path, raw);
  const input = preparationInput.parse({ ...f.input,
    sources: [...f.input.sources, { id: "WS-original", path, sha256: fingerprint(raw),
      bytes: String(Buffer.byteLength(raw)), provenance: { kind: "file", authority: "synthetic eligible gon allocation" } }],
    exposures: [...f.input.exposures, { ...exposure, proof: { sourceId: "WS-original", pointer: "/exposure" } }],
    weightedReceipt: [{ original, proof: { sourceId: "WS-original", pointer: "/original" } }],
  });
  return { ...f, input, original };
}

test("WS preparation requires complete known original gons and wallet, never floating-point or live-derived credit", async () => {
  const f = await receiptFixture();
  try {
    for (const field of ["originalId", "originalWallet", "source", "originalUnits", "originalEth", "originalDtf", "evidenceId"] as const) {
      const { [field]: _missing, ...original } = f.original;
      assert.equal(preparationInput.safeParse({ ...f.input, weightedReceipt: [{
        original, proof: { sourceId: "WS-original", pointer: "/original" },
      }] }).success, false);
    }
    for (const correction of [{ originalUnits: 101 }, { originalUnits: "0" }, { originalUnits: "1.0" },
      { originalWallet: a(0) }, { contributionsKnown: false }, { credit: "1001" }, { pricingMode: "native" }]) {
      assert.equal(preparationInput.safeParse({ ...f.input, weightedReceipt: [{
        ...f.input.weightedReceipt[0], original: { ...f.original, ...correction },
      }] }).success, false);
    }
    assert.equal(buildPayloads(f.input).weightedReceipt[0]?.originalUnits, f.original.originalUnits);
  } finally { await f.close(); }
});

test("WS builder enforces fixed source and gon partition and rejects origin reuse", async () => {
  const f = await receiptFixture();
  try {
    const row = f.input.weightedReceipt[0];
    assert.ok(row);
    assert.throws(() => buildPayloads({ ...f.input, weightedReceipt: [{
      ...row, original: { ...row.original, source: a(99) },
    }] }), { code: "DOMAIN" });
    assert.throws(() => buildPayloads({ ...f.input, weightedReceipt: [{
      ...row, original: { ...row.original, originalUnits: "101" },
    }] }), { code: "PROVENANCE" });
    assert.throws(() => buildPayloads({ ...f.input, weightedReceipt: [row, row] }), /overlapping original/);
    assert.throws(() => buildPayloads({ ...f.input, weightedReceipt: [] }), /unassigned origin/);
    const independent = f.input.independent[0];
    assert.ok(independent);
    assert.throws(() => buildPayloads({ ...f.input, independent: [{ ...independent, entitlements: [{
      original: { entitlementId: row.original.originalId, originalEth: "100", originalDtf: "22", evidenceId: h(400) },
      proof: row.proof,
    }] }] }), { code: "PROVENANCE" });
  } finally { await f.close(); }
});

test("WS evidence binding and frozen grouped quote survive exact preparation without scaling by gons", async () => {
  const f = await receiptFixture();
  try {
    const prepared = await prepareDomain(f.input);
    const row = prepared.payloads.configure.weightedReceipt[0];
    assert.equal(row?.quotedCredit, "12"); // Wire oracle:100/10 +22/11, never a gon multiplier.
    assert.equal(row?.input.originalUnits, f.original.originalUnits);
    assert.equal(row?.configurationId, configurationId(f.input.domain, f.original));
    const original = { ...f.original, originalWallet: a(99) };
    await assert.rejects(prepareDomain({ ...f.input, weightedReceipt: [{
      original, proof: { sourceId: "WS-original", pointer: "/original" },
    }] }), { code: "PROVENANCE" });
  } finally { await f.close(); }
});

test("WS Solidity configuration and stage ABI preserve eligible gons separately from native surrender", async () => {
  const f = await receiptFixture();
  try {
    const allocation = await interfaceFile("out/IUniswapV4DetfMigration.sol/IUniswapV4DetfMigrationAllocation.json");
    const migration = await interfaceFile("out/IUniswapV4DetfMigration.sol/IUniswapV4DetfMigration.json");
    const stage = await interfaceFile("out/Phase_08_Stage_01_MigrationExecution.s.sol/Phase_08_Stage_01_MigrationExecution.json");
    const parameter = allocation.getFunction("configureWeightedReceiptEntitlements")?.inputs[0];
    const stageParameter = stage.getFunction("configureWeightedReceipt")?.inputs[1];
    assert.ok(parameter?.arrayChildren);
    assert.ok(stageParameter);
    assert.equal(parameter.format("full"), stageParameter.format("full"));
    assert.equal(configurationId(f.input.domain, f.original), keccak256(AbiCoder.defaultAbiCoder().encode(
      ["uint256", "address", "bytes32", parameter.arrayChildren],
      [f.input.domain.chainId, f.input.domain.proxy, f.input.domain.snapshotId, f.original])));
    const encoded = migration.encodeFunctionData("surrenderMigrationWeightedReceipt", [f.original.originalId, 1n, 7n, 9n]);
    const decoded = migration.decodeFunctionData("surrenderMigrationWeightedReceipt", encoded);
    assert.deepEqual([...decoded], [f.original.originalId, 1n, 7n, 9n]);
    for (const correction of [{ originalWallet: a(99) }, { originalUnits: "4" }, { originalEth: "101" }, { evidenceId: h(900) }]) {
      assert.notEqual(configurationId(f.input.domain, { ...f.original, ...correction }), configurationId(f.input.domain, f.original));
    }
  } finally { await f.close(); }
});
