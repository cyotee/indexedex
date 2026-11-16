import { test } from "node:test";
import assert from "node:assert/strict";
import { AbiCoder, keccak256 } from "ethers";
import { fixture, a, h } from "./preparation.fixture.js";
import { preparationInput } from "./schema.js";
import { buildPayloads, configurationId, dtfCustodySeSource } from "./payloads.js";
import { prepareDomain } from "./preparation.js";
import { interfaceFile } from "./rehearsal-data.js";

test("W-SD requires known original wallet, quantity, components and origin, not current holdings", async () => {
  const f = await fixture();
  try {
    const priced = f.input.dtfCustodySe[0];
    assert.ok(priced);
    const original = priced.original;
    assert.equal(preparationInput.safeParse(f.input).success, true);
    // Catches a schema that stops requiring originalId, originalWallet, originalUnits, originalEth, originalDtf, source, or evidenceId.
    for (const field of ["originalId", "originalWallet", "originalUnits", "originalEth", "originalDtf", "source", "evidenceId"] as const) {
      const { [field]: removed, ...kept } = original;
      const omitted = preparationInput.safeParse({ ...f.input, dtfCustodySe: [{ ...priced, original: kept }] });
      if (omitted.success) assert.fail("dtfCustodySe accepted an original that omitted " + field);
      assert.deepEqual(omitted.error.issues.map((issue) => ({
        path: issue.path.map((part) => String(part)).join("."),
        code: issue.code,
        message: issue.message,
      })), [{ path: "dtfCustodySe.0.original." + field, code: "invalid_type", message: "Required" }]);
      assert.equal(preparationInput.safeParse({ ...f.input, dtfCustodySe: [{
        ...priced, original: { ...kept, [field]: removed },
      }] }).success, true);
    }
    for (const changed of [{ originalUnits: "0" }, { originalWallet: a(0) }, { contributionsKnown: false }, { credit: "1001" }]) {
      assert.equal(preparationInput.safeParse({ ...f.input, dtfCustodySe: [{
        ...f.input.dtfCustodySe[0], original: { ...original, ...changed },
      }] }).success, false);
    }
    const row = f.input.dtfCustodySe[0];
    assert.ok(row);
    await assert.rejects(prepareDomain({ ...f.input, dtfCustodySe: [{
      ...row, original: { ...original, originalWallet: a(99) },
    }] }), { name: "PreparationError", code: "PROVENANCE" });
  } finally { await f.close(); }
});

test("W-SD fixed source, original units and economic partition are required by the real payload builder", async () => {
  const f = await fixture();
  try {
    const row = f.input.dtfCustodySe[0];
    assert.ok(row);
    assert.throws(() => buildPayloads({ ...f.input, dtfCustodySe: [{
      ...row, original: { ...row.original, source: a(99) },
    }] }), /fixed W-SD/);
    assert.throws(() => buildPayloads({ ...f.input, dtfCustodySe: [{
      ...row, original: { ...row.original, originalUnits: "4" },
    }] }), /original units/);
    assert.throws(() => buildPayloads({ ...f.input, dtfCustodySe: [row, row] }), /overlapping original/);
    assert.throws(() => buildPayloads({ ...f.input, dtfCustodySe: [] }), /unassigned origin/);
    const independent = f.input.independent[0];
    assert.ok(independent);
    const overlap = { ...independent, entitlements: [{
      original: { entitlementId: row.original.originalId, originalEth: "100", originalDtf: "22", evidenceId: h(900) },
      proof: row.proof,
    }] };
    assert.throws(() => buildPayloads({ ...f.input, independent: [overlap] }), /missing matching origin/);
    assert.equal(buildPayloads(f.input).dtfCustodySe[0]?.source, dtfCustodySeSource);
  } finally { await f.close(); }
});

test("W-SD complete configuration hash agrees with Solidity and typed stage ABI including wallet and Q0", async () => {
  const f = await fixture();
  try {
    const original = f.input.dtfCustodySe[0]?.original;
    assert.ok(original);
    const allocation = await interfaceFile("out/IUniswapV4DetfMigration.sol/IUniswapV4DetfMigrationAllocation.json");
    const stage = await interfaceFile("out/Phase_08_Stage_01_MigrationExecution.s.sol/Phase_08_Stage_01_MigrationExecution.json");
    const parameter = allocation.getFunction("configureDtfCustodySeEntitlements")?.inputs[0];
    const stageParameter = stage.getFunction("configureDtfCustodySe")?.inputs[1];
    assert.ok(parameter?.arrayChildren);
    assert.ok(stageParameter);
    assert.equal(parameter.format("full"), stageParameter.format("full"));
    const encoded = allocation.encodeFunctionData("configureDtfCustodySeEntitlements", [[original], f.input.domain.bookId]);
    const decoded = allocation.decodeFunctionData("configureDtfCustodySeEntitlements", encoded)[0][0];
    assert.equal(decoded.originalWallet.toLowerCase(), original.originalWallet);
    assert.equal(decoded.originalUnits, 10n ** 28n);
    assert.equal(decoded.originalId, original.originalId);
    assert.equal(configurationId(f.input.domain, original), keccak256(AbiCoder.defaultAbiCoder().encode(
      ["uint256", "address", "bytes32", parameter.arrayChildren],
      [f.input.domain.chainId, f.input.domain.proxy, f.input.domain.bookId, original])));
    for (const correction of [{ originalWallet: a(99) }, { originalUnits: "4" }, { originalEth: "101" }, { evidenceId: h(900) }]) {
      assert.notEqual(configurationId(f.input.domain, { ...original, ...correction }), configurationId(f.input.domain, original));
    }
  } finally { await f.close(); }
});
