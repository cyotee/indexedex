import { test } from "node:test";
import assert from "node:assert/strict";
import { writeFile } from "node:fs/promises";
import { join } from "node:path";
import { AbiCoder, keccak256 } from "ethers";
import { fixture, a, h } from "./preparation.fixture.js";
import { preparationInput } from "./schema.js";
import { buildPayloads, configurationId, dispositions, earlierLiquidSource } from "./payloads.js";
import { prepareDomain } from "./preparation.js";
import { canonical, fingerprint } from "./provenance.js";
import { interfaceFile } from "./rehearsal-data.js";

async function receiptFixture() {
  const f = await fixture();
  const original = {
    originalId: h(500), originalWallet: a(181), source: earlierLiquidSource,
    originalUnits: "999999999999999999999993",
    originalEth: "100", originalDtf: "22", evidenceId: h(501), contributionsKnown: true as const,
  };
  const exposure = { originId: original.originalId, category: "earlier-liquid" as const,
    originalUnits: original.originalUnits, descendants: [{ id: h(502), units: original.originalUnits }],
    recoveredUnits: "0", excludedUnits: "0" };
  const path = join(f.root, "earlier-liquid-original.json");
  const raw = canonical({ original, exposure });
  await writeFile(path, raw);
  const input = preparationInput.parse({ ...f.input,
    sources: [...f.input.sources, { id: "ED-original", path, sha256: fingerprint(raw),
      bytes: String(Buffer.byteLength(raw)), provenance: { kind: "file", authority: "synthetic exact native18 allocation" } }],
    exposures: [...f.input.exposures, { ...exposure, proof: { sourceId: "ED-original", pointer: "/exposure" } }],
    earlierLiquid: [{ original, proof: { sourceId: "ED-original", pointer: "/original" } }],
  });
  return { ...f, input, original };
}

test("ED preparation requires complete known original native18 units without pricing or unit alternatives", async () => {
  const f = await receiptFixture();
  try {
    for (const field of ["originalId", "originalWallet", "source", "originalUnits", "originalEth", "originalDtf", "evidenceId"] as const) {
      const { [field]: _missing, ...original } = f.original;
      assert.equal(preparationInput.safeParse({ ...f.input, earlierLiquid: [{
        original, proof: { sourceId: "ED-original", pointer: "/original" },
      }] }).success, false);
    }
    for (const correction of [{ originalUnits: 1 }, { originalUnits: "0" }, { originalUnits: "1.0" },
      { originalWallet: a(0) }, { contributionsKnown: false }, { credit: "1001" },
      { pricingMode: "native" }, { unit: "external-shares" }]) {
      assert.equal(preparationInput.safeParse({ ...f.input, earlierLiquid: [{
        ...f.input.earlierLiquid[0], original: { ...f.original, ...correction },
      }] }).success, false);
    }
    assert.equal(buildPayloads(f.input).earlierLiquid[0]?.originalUnits, f.original.originalUnits);
  } finally { await f.close(); }
});

test("ED source and original partition cannot be substituted duplicated or silently omitted", async () => {
  const f = await receiptFixture();
  try {
    const row = f.input.earlierLiquid[0];
    assert.ok(row);
    assert.throws(() => buildPayloads({ ...f.input, earlierLiquid: [{
      ...row, original: { ...row.original, source: a(99) },
    }] }), { code: "DOMAIN" });
    assert.throws(() => buildPayloads({ ...f.input, earlierLiquid: [{
      ...row, original: { ...row.original, originalUnits: "10000" },
    }] }), { code: "PROVENANCE" });
    assert.throws(() => buildPayloads({ ...f.input, earlierLiquid: [row, row] }), /overlapping original/);
    assert.throws(() => buildPayloads({ ...f.input, earlierLiquid: [] }), /unassigned origin/);
    const rows = dispositions(f.input);
    assert.equal(rows.length, 15);
    assert.equal(rows.find((r) => r.category === "earlier-liquid")?.disposition, "bounded");
    assert.equal(rows.find((r) => r.category === "earlier-liquidation")?.disposition, "blocked");
  } finally { await f.close(); }
});

test("ED grouped frozen quote and raw proof binding never scale credit by receipt ownership", async () => {
  const f = await receiptFixture();
  try {
    const prepared = await prepareDomain(f.input);
    const row = prepared.payloads.configure.earlierLiquid[0];
    assert.equal(row?.quotedCredit, "12"); // Synthetic wire oracle only:100/10 +22/11.
    assert.equal(row?.input.originalUnits, f.original.originalUnits);
    assert.equal(row?.configurationId, configurationId(f.input.domain, f.original));
    await assert.rejects(prepareDomain({ ...f.input, earlierLiquid: [{
      original: { ...f.original, originalWallet: a(99) }, proof: { sourceId: "ED-original", pointer: "/original" },
    }] }), { code: "PROVENANCE" });
  } finally { await f.close(); }
});

test("ED operator stage and Solidity share exact tuple ABI and retain separate custody queries", async () => {
  const f = await receiptFixture();
  try {
    const allocation = await interfaceFile("out/IUniswapV4DetfMigration.sol/IUniswapV4DetfMigrationAllocation.json");
    const migration = await interfaceFile("out/IUniswapV4DetfMigration.sol/IUniswapV4DetfMigration.json");
    const recovery = await interfaceFile("out/IUniswapV4DetfMigrationRecovery.sol/IUniswapV4DetfMigrationRecovery.json");
    const stage = await interfaceFile("out/Phase_08_Stage_01_MigrationExecution.s.sol/Phase_08_Stage_01_MigrationExecution.json");
    const parameter = allocation.getFunction("configureEarlierLiquidEntitlements")?.inputs[0];
    const stageParameter = stage.getFunction("configureEarlierLiquid")?.inputs[1];
    assert.ok(parameter?.arrayChildren); assert.ok(stageParameter);
    assert.equal(parameter.format("full"), stageParameter.format("full"));
    assert.equal(configurationId(f.input.domain, f.original), keccak256(AbiCoder.defaultAbiCoder().encode(
      ["uint256", "address", "bytes32", parameter.arrayChildren],
      [f.input.domain.chainId, f.input.domain.proxy, f.input.domain.snapshotId, f.original])));
    const encoded = migration.encodeFunctionData("surrenderMigrationEarlierLiquid", [f.original.originalId, 1n, 7n, 9n]);
    assert.deepEqual([...migration.decodeFunctionData("surrenderMigrationEarlierLiquid", encoded)],
      [f.original.originalId, 1n, 7n, 9n]);
    assert.ok(migration.getFunction("earlierLiquidEntitlement"));
    assert.ok(migration.getFunction("earlierLiquidSurrender"));
    assert.ok(recovery.getFunction("migrationRecoveryInventory"));
  } finally { await f.close(); }
});
