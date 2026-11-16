import { test } from "node:test";
import assert from "node:assert/strict";
import { AbiCoder, keccak256 } from "ethers";
import { fixture, a, h } from "./preparation.fixture.js";
import { preparationInput } from "./schema.js";
import { buildPayloads, configurationId, weightedSySource } from "./payloads.js";
import { prepareDomain } from "./preparation.js";
import { interfaceFile } from "./rehearsal-data.js";
import { readFile, writeFile } from "node:fs/promises";
import { claimedSyCertificate } from "./schema.js";
import type { ClaimedSyCertificate } from "./schema.js";
import { claimedSyEvidenceId } from "./claimed-sy.js";
import { canonical, fingerprint, validateProvenance } from "./provenance.js";

function completeCertificate(original: { readonly originalId: string; readonly originalWallet: string;
  readonly originalEth: string; readonly originalDtf: string }, bookId: string) {
  return claimedSyCertificate.parse({
    kind: "complete-original-token-staking", chainId: "4663",
    source: "0xe4c9ff4cfd17ae73ecb3825ebdf7db113c146d00",
    vault: "0xaf5c0cd3fdedd10bee00eff77fa0429bacdb41f0", sy: weightedSySource,
    pricingSet: { bookId, transactionHash: h(2300), blockNumber: "90", blockHash: h(90) },
    review: { ...original, authority: "synthetic explicit review, not a historical allocation",
      eligibleWeight: "10013", priorDeliveredCredit: "0", contributionsKnown: true,
      eligiblePrincipalOnly: true, rewardsExcluded: true, aliasesReconciled: true,
      competingRepresentationsExcluded: true, unrelatedWeightFloor: "7", unrelatedSyFloor: "5" },
    members: [
      { transactionHash: h(2301), rawSignedTransaction: "0x", blockNumber: "98", blockHash: h(98),
        consumedWeight: "3337", receivedSy: "1", redeemedVaultShares: "10" },
      { transactionHash: h(2302), rawSignedTransaction: "0x", blockNumber: "99", blockHash: h(99),
        consumedWeight: "6676", receivedSy: "2", redeemedVaultShares: "20" },
    ],
  });
}

test("claimed SY uses every complete original component and exact measured split sums", async () => {
  const f = await fixture();
  try {
    const row = f.input.weightedSy[0];
    assert.ok(row);
    const { originalId, originalWallet, originalEth, originalDtf } = row.original;
    const certificate = completeCertificate({ originalId, originalWallet, originalEth, originalDtf }, f.input.domain.bookId);
    const inputFor = (c: ClaimedSyCertificate) => ({ ...f.input, weightedSy: [{
      ...row, claimedOrigin: c,
      original: { ...row.original, evidenceId: claimedSyEvidenceId(f.input.domain, row.original, c) },
    }] });
    const actual = buildPayloads(inputFor(certificate)).weightedSy[0];
    assert.equal(actual?.originalUnits, "3");
    assert.equal(actual?.originalEth, "100");
    assert.equal(actual?.originalDtf, "22");
    assert.throws(() => buildPayloads(inputFor({ ...certificate, members: certificate.members.slice(0, 1) })), /coverage/);
    assert.throws(() => buildPayloads(inputFor({ ...certificate,
      members: [...certificate.members, certificate.members[0]].filter((m) => m !== undefined) })), /coverage/);
    assert.throws(() => buildPayloads(inputFor({ ...certificate,
      members: certificate.members.map((m) => ({ ...m, receivedSy: "0" })) })), /SY sum/);
    const first = certificate.members[0];
    assert.ok(first);
    // A committed zero-output slice stays in coverage; only aggregate zero rejects.
    const zeroSlice = { ...certificate, members: [
      { ...first, consumedWeight: "1", receivedSy: "0" },
      { ...first, transactionHash: h(2303), consumedWeight: "10012", receivedSy: "3" },
    ] };
    assert.equal(buildPayloads(inputFor(zeroSlice)).weightedSy[0]?.originalUnits, "3");
    const duplicate = { ...certificate, members: certificate.members.map((m) => ({ ...m, transactionHash: first.transactionHash })) };
    assert.throws(() => buildPayloads(inputFor(duplicate)), /duplicate member/);
    const secondOriginal = { ...row.original, originalId: h(999) };
    const secondCertificate = { ...certificate, review: { ...certificate.review, originalId: h(999) } };
    assert.throws(() => buildPayloads({ ...inputFor(certificate), weightedSy: [
      ...inputFor(certificate).weightedSy, { ...row, claimedOrigin: secondCertificate,
        original: { ...secondOriginal, evidenceId: claimedSyEvidenceId(f.input.domain, secondOriginal, secondCertificate) } },
    ] }), /duplicate member/);
    const changed = inputFor(certificate);
    assert.throws(() => buildPayloads({ ...changed, domain: { ...changed.domain, proxy: a(99) } }), /commitment/);
    assert.throws(() => buildPayloads({ ...changed, weightedSy: changed.weightedSy.map((r) => ({
      ...r, original: { ...r.original, originalDtf: "23" },
    })) }), /complete original differ/);
  } finally { await f.close(); }
});

test("claimed SY rejects unknown delivery and missing original review rather than inferring zero", async () => {
  const f = await fixture();
  try {
    const row = f.input.weightedSy[0];
    assert.ok(row);
    const { originalId, originalWallet, originalEth, originalDtf } = row.original;
    const certificate = completeCertificate({ originalId, originalWallet, originalEth, originalDtf }, f.input.domain.bookId);
    for (const change of [{ priorDeliveredCredit: "1" }, { priorDeliveredCredit: "unknown" },
      { contributionsKnown: false }, { rewardsExcluded: false }, { aliasesReconciled: false },
      { competingRepresentationsExcluded: false }, { eligiblePrincipalOnly: false }]) {
      assert.equal(claimedSyCertificate.safeParse({ ...certificate, review: { ...certificate.review, ...change } }).success, false);
    }
    for (const field of ["originalEth", "originalDtf", "originalWallet", "eligibleWeight", "priorDeliveredCredit"] as const) {
      const { [field]: _omitted, ...review } = certificate.review;
      assert.equal(claimedSyCertificate.safeParse({ ...certificate, review }).success, false);
    }
    assert.equal(claimedSyCertificate.safeParse({ ...certificate, chainId: "1" }).success, false);
    assert.equal(claimedSyCertificate.safeParse({ ...certificate, vault: a(99) }).success, false);
  } finally { await f.close(); }
});

test("missing claimed-origin certificate cannot use its reviewed evidence as ordinary SY", async () => {
  const f = await fixture();
  try {
    const row = f.input.weightedSy[0];
    assert.ok(row);
    const { originalId, originalWallet, originalEth, originalDtf } = row.original;
    const claimedOrigin = completeCertificate({ originalId, originalWallet, originalEth, originalDtf }, f.input.domain.bookId);
    const original = { ...row.original, evidenceId: claimedSyEvidenceId(f.input.domain, row.original, claimedOrigin) };
    const raw = canonical({ ...JSON.parse(await readFile(f.evidencePath, "utf8")), claimed: { original, claimedOrigin } });
    await writeFile(f.evidencePath, raw);
    const input = preparationInput.parse({ ...f.input,
      sources: f.input.sources.map((s) => s.id === "proof" ? { ...s, sha256: fingerprint(raw), bytes: String(Buffer.byteLength(raw)) } : s),
      weightedSy: [{ pricing: row.pricing, original, claimedOrigin, proof: { sourceId: "proof", pointer: "/claimed" } }],
    });
    await validateProvenance(input);
    const claimed = input.weightedSy[0];
    assert.ok(claimed);
    const { claimedOrigin: _removed, ...ordinaryFallback } = claimed;
    await assert.rejects(validateProvenance({ ...input, weightedSy: [ordinaryFallback] }), /proof does not match/);
    await assert.rejects(validateProvenance({ ...input, weightedSy: [{
      ...ordinaryFallback, proof: { ...ordinaryFallback.proof, pointer: "/claimed/original" },
    }] }), /ordinary SY fallback forbidden/);
    await assert.rejects(validateProvenance({ ...input, weightedSy: [{
      ...ordinaryFallback, proof: { ...ordinaryFallback.proof, pointer: "/originals/4" },
      original: row.original,
    }] }), /ordinary SY fallback forbidden/);
    await assert.rejects(prepareDomain(input), { code: "PROVENANCE", reason: "AUTHENTICATION" });
    assert.ok(f.methods.includes("eth_getTransactionReceipt"));
  } finally { await f.close(); }
});

test("W-Y requires known original wallet, quantity, components and origin, not current holdings", async () => {
  const f = await fixture();
  try {
    const priced = f.input.weightedSy[0];
    assert.ok(priced);
    const original = priced.original;
    assert.equal(preparationInput.safeParse(f.input).success, true);
    // Catches a schema that stops requiring originalId, originalWallet, originalUnits, originalEth, originalDtf, source, or evidenceId.
    for (const field of ["originalId", "originalWallet", "originalUnits", "originalEth", "originalDtf", "source", "evidenceId"] as const) {
      const { [field]: removed, ...kept } = original;
      const omitted = preparationInput.safeParse({ ...f.input, weightedSy: [{ ...priced, original: kept }] });
      if (omitted.success) assert.fail("weightedSy accepted an original that omitted " + field);
      assert.deepEqual(omitted.error.issues.map((issue) => ({
        path: issue.path.map((part) => String(part)).join("."),
        code: issue.code,
        message: issue.message,
      })), [{ path: "weightedSy.0.original." + field, code: "invalid_type", message: "Required" }]);
      assert.equal(preparationInput.safeParse({ ...f.input, weightedSy: [{
        ...priced, original: { ...kept, [field]: removed },
      }] }).success, true);
    }
    for (const changed of [{ originalUnits: "0" }, { originalWallet: a(0) }, { contributionsKnown: false }, { credit: "1001" }]) {
      assert.equal(preparationInput.safeParse({ ...f.input, weightedSy: [{
        ...f.input.weightedSy[0], original: { ...original, ...changed },
      }] }).success, false);
    }
    const row = f.input.weightedSy[0];
    assert.ok(row);
    await assert.rejects(prepareDomain({ ...f.input, weightedSy: [{
      ...row, original: { ...original, originalWallet: a(99) },
    }] }), { name: "PreparationError", code: "PROVENANCE" });
  } finally { await f.close(); }
});

test("W-Y fixed source, original units and economic partition are required by the real payload builder", async () => {
  const f = await fixture();
  try {
    const row = f.input.weightedSy[0];
    assert.ok(row);
    assert.throws(() => buildPayloads({ ...f.input, weightedSy: [{
      ...row, original: { ...row.original, source: a(99) },
    }] }), /fixed WY/);
    assert.throws(() => buildPayloads({ ...f.input, weightedSy: [{
      ...row, original: { ...row.original, originalUnits: "4" },
    }] }), /original units/);
    assert.throws(() => buildPayloads({ ...f.input, weightedSy: [row, row] }), /overlapping original/);
    assert.throws(() => buildPayloads({ ...f.input, weightedSy: [] }), /unassigned origin/);
    const independent = f.input.independent[0];
    assert.ok(independent);
    const overlap = { ...independent, entitlements: [{
      original: { entitlementId: row.original.originalId, originalEth: "100", originalDtf: "22", evidenceId: h(900) },
      proof: row.proof,
    }] };
    assert.throws(() => buildPayloads({ ...f.input, independent: [overlap] }), /missing matching origin/);
    assert.equal(buildPayloads(f.input).weightedSy[0]?.source, weightedSySource);
  } finally { await f.close(); }
});

test("W-Y complete configuration hash agrees with Solidity and typed stage ABI including wallet and Q0", async () => {
  const f = await fixture();
  try {
    const original = f.input.weightedSy[0]?.original;
    assert.ok(original);
    const allocation = await interfaceFile("out/IUniswapV4DetfMigration.sol/IUniswapV4DetfMigrationAllocation.json");
    const stage = await interfaceFile("out/Phase_08_Stage_01_MigrationExecution.s.sol/Phase_08_Stage_01_MigrationExecution.json");
    const parameter = allocation.getFunction("configureWeightedSyEntitlements")?.inputs[0];
    const stageParameter = stage.getFunction("configureWeightedSy")?.inputs[1];
    assert.ok(parameter?.arrayChildren);
    assert.ok(stageParameter);
    assert.equal(parameter.format("full"), stageParameter.format("full"));
    const encoded = allocation.encodeFunctionData("configureWeightedSyEntitlements", [[original], f.input.domain.bookId]);
    const decoded = allocation.decodeFunctionData("configureWeightedSyEntitlements", encoded)[0][0];
    assert.equal(decoded.originalWallet.toLowerCase(), original.originalWallet);
    assert.equal(decoded.originalUnits, 3n);
    assert.equal(decoded.originalId, original.originalId);
    assert.equal(configurationId(f.input.domain, original), keccak256(AbiCoder.defaultAbiCoder().encode(
      ["uint256", "address", "bytes32", parameter.arrayChildren],
      [f.input.domain.chainId, f.input.domain.proxy, f.input.domain.bookId, original])));
    for (const correction of [{ originalWallet: a(99) }, { originalUnits: "4" }, { originalEth: "101" }, { evidenceId: h(900) }]) {
      assert.notEqual(configurationId(f.input.domain, { ...original, ...correction }), configurationId(f.input.domain, original));
    }
  } finally { await f.close(); }
});
