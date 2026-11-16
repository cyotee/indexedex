import { afterEach, test } from "node:test";
import assert from "node:assert/strict";
import { writeFile } from "node:fs/promises";
import { AbiCoder, keccak256 } from "ethers";
import { spawn } from "node:child_process";
import { once } from "node:events";
import { text } from "node:stream/consumers";
import { join } from "node:path";
import { fixture, h, a } from "./preparation.fixture.js";
import { canonical, fingerprint } from "./provenance.js";
import { buildPayloads, configurationId, dispositions, nftOrigin } from "./payloads.js";
import { normalize, prepareDomain, prepareFile, validateManifest } from "./preparation.js";
import { preparationInput, uint } from "./schema.js";
import { main } from "./cli.js";
import { interfaceFile } from "./rehearsal-data.js";

const fixtures: Awaited<ReturnType<typeof fixture>>[] = [];
async function setup() {
  const f = await fixture();
  fixtures.push(f);
  return f;
}
afterEach(async () => {
  for (const f of fixtures.splice(0)) await f.close();
});

test("normalizes native integer strings without floating point", () => {
  assert.equal(uint.parse("00090071992547409931234"), "90071992547409931234");
});
for (const value of ["", "-1", "1.5", "1e18", 0, null, (2n ** 256n).toString()]) {
  test(`rejects unknown or non-native amount ${value}`, () => {
    assert.equal(uint.safeParse(value).success, false);
  });
}
test("emits full separate replacements and independently quoted native credits", async () => {
  const f = await setup();
  const result = await prepareDomain(f.input);
  assert.equal(result.payloads.configure.independent[0]?.input.entitlements[0]?.originalEth, "90071992547409931234");
  assert.deepEqual(result.quoteEvidence.quotes, [
    { originalEth: "100", originalDtf: "22", ethCredit: "10", dtfCredit: "2", credit: "12" },
    { originalEth: "90071992547409931234", originalDtf: "110", ethCredit: "9007199254740993123",
      dtfCredit: "10", credit: "9007199254740993133" },
  ]);
  assert.deepEqual(result.payloads.configure.nfts.map((r) => r.input),
    [...f.input.nfts.map((r) => r.original)].sort((a, b) => a.collection.localeCompare(b.collection)));
  assert.deepEqual(result.payloads.independentIssue.requests, [{
    recipient: a(20), configurationId: result.payloads.configure.independent[0]?.configurationId,
  }]);
  assert.equal(result.dispositions.filter((d) => d.disposition === "blocked").length, 9);
  assert.deepEqual(result.payloads.configure.weightedLiquid[0]?.input, f.input.weightedLiquid[0]?.original);
  assert.equal(f.methods.every((m) => ["eth_chainId", "eth_getBlockByNumber", "eth_getCode", "eth_call"].includes(m)), true);
});
test("normalization is stable under reordered records and source bindings", async () => {
  const f = await setup();
  const reordered = { ...f.input, sources: [...f.input.sources].reverse(), exposures: [...f.input.exposures].reverse(),
    domain: { ...f.input.domain, bindings: [...f.input.domain.bindings].reverse() } };
  assert.equal(canonical(normalize(reordered)), canonical(normalize(f.input)));
});
test("full replacements change identities instead of generating credit deltas", async () => {
  const f = await setup();
  const payload = buildPayloads(f.input).independent[0];
  assert.ok(payload);
  const replacement = { ...payload, evidenceId: h(500) };
  assert.notEqual(configurationId(f.input.domain, replacement), configurationId(f.input.domain, payload));
  assert.notEqual(configurationId({ ...f.input.domain, proxy: a(50) }, payload), configurationId(f.input.domain, payload));
});
for (const kind of ["chain", "block", "snapshot", "proxy", "package"] as const) {
  test(`rejects wrong ${kind} domain before accepting payloads`, async () => {
    const f = await setup();
    const input = {
      ...f.input, nfts: [], weightedLiquid: [], exposures: f.input.exposures.filter((e) => e.category === "independent"), domain: {
        ...f.input.domain,
        chainId: kind === "chain" ? "1" : f.input.domain.chainId,
        blockHash: kind === "block" ? h(3) : f.input.domain.blockHash,
        snapshotId: kind === "snapshot" ? h(4) : f.input.domain.snapshotId,
        proxy: kind === "proxy" ? a(99) : f.input.domain.proxy,
        bindings: f.input.domain.bindings.map((b) => kind === "package" && b.role === "package" ? { ...b, codeHash: h(5) } : b),
      },
    };
    const expected = { chain: /wrong chain/, block: /wrong canonical block/, snapshot: /snapshot identity/,
      proxy: /wrong proxy binding/, package: /wrong package code/ };
    await assert.rejects(prepareDomain(input), expected[kind]);
  });
}
test("rejects source tampering rather than trusting quoted originals", async () => {
  const f = await setup();
  await writeFile(f.evidencePath, "{}");
  await assert.rejects(prepareDomain(f.input), /source bytes differ/);
});
test("rejects originals that do not match their raw proof", async () => {
  const f = await setup();
  const row = f.input.nfts[0];
  assert.ok(row);
  await assert.rejects(prepareDomain({ ...f.input, nfts: [{ ...row, original: { ...row.original, originalEth: "101" } }] }),
    /proof does not match/);
});
test("rejects missing or zero NFT original wallets at preparation boundary", async () => {
  const f = await setup();
  const row = f.input.nfts[0];
  assert.ok(row);
  const { originalWallet: _wallet, ...withoutWallet } = row.original;
  for (const original of [withoutWallet, { ...row.original, originalWallet: a(0) }]) {
    const parsed = preparationInput.safeParse({ ...f.input, nfts: [{ ...row, original }] });
    assert.equal(parsed.success, false);
    if (!parsed.success) assert.ok(parsed.error.issues.some((issue) => issue.path.includes("originalWallet")));
  }
});
test("rejects a wallet differing from the full recorded NFT original", async () => {
  const f = await setup();
  const row = f.input.nfts[0];
  assert.ok(row);
  await assert.rejects(prepareDomain({ ...f.input,
    nfts: [{ ...row, original: { ...row.original, originalWallet: a(99) } }] }),
  { name: "PreparationError", code: "PROVENANCE" });
});
test("wallet correction changes full configuration but not economic origin", async () => {
  const f = await setup();
  for (const row of f.input.nfts) {
    const corrected = { ...row.original, originalWallet: a(99) };
    assert.notEqual(configurationId(f.input.domain, corrected), configurationId(f.input.domain, row.original));
    assert.equal(nftOrigin(f.input.domain, corrected), nftOrigin(f.input.domain, row.original));
  }
});
test("NFT payload and configuration identity agree with final Solidity and typed stage ABIs", async () => {
  const f = await setup();
  const allocation = await interfaceFile("out/IUniswapV4DetfMigration.sol/IUniswapV4DetfMigrationAllocation.json");
  const stage = await interfaceFile("out/Phase_08_Stage_01_MigrationExecution.s.sol/Phase_08_Stage_01_MigrationExecution.json");
  const array = allocation.getFunction("configureNftEntitlements")?.inputs[0];
  const stageArray = stage.getFunction("configureNfts")?.inputs[1];
  assert.ok(array?.arrayChildren);
  assert.ok(stageArray?.arrayChildren);
  assert.equal(array.format("full"), stageArray.format("full"));
  for (const { original } of f.input.nfts) {
    const call = allocation.encodeFunctionData("configureNftEntitlements", [[original]]);
    const decoded = allocation.decodeFunctionData("configureNftEntitlements", call)[0][0];
    assert.equal(decoded.originalWallet.toLowerCase(), original.originalWallet);
    const fromAbi: string = keccak256(AbiCoder.defaultAbiCoder().encode(
      ["uint256", "address", "bytes32", array.arrayChildren],
      [f.input.domain.chainId, f.input.domain.proxy, f.input.domain.snapshotId, original]));
    assert.equal(configurationId(f.input.domain, original), fromAbi);
  }
});
test("rejects unknown contributions and arbitrary credit fields at the schema boundary", async () => {
  const f = await setup();
  const row = f.input.nfts[0];
  assert.equal(preparationInput.safeParse({ ...f.input,
    nfts: [{ ...row, original: { ...row?.original, contributionsKnown: false, credit: "100" } }] }).success, false);
});
test("rejects overlapping originals and missing origin partitions", async () => {
  const f = await setup();
  const row = f.input.independent[0];
  assert.ok(row);
  assert.throws(() => buildPayloads({ ...f.input, independent: [row, { ...row, recipient: a(25) }] }), /overlapping original/);
  assert.throws(() => buildPayloads({ ...f.input, nfts: [] }), /unassigned origin/);
});
for (const category of ["earlier-liquid", "weighted-receipt", "earlier-receipt",
  "weighted-sy", "token-staking", "claim-vault", "underlying-se", "fungible-lp", "earlier-liquidation"] as const) {
  test(`blocks ${category} without forging executable config`, async () => {
    const f = await setup();
    const row = f.input.exposures[0];
    assert.ok(row);
    assert.throws(() => buildPayloads({ ...f.input, exposures: [{ ...row, category }] }), new RegExp(category));
  });
}
test("rejects a nonconserving origin partition", async () => {
  const f = await setup();
  const exposures = f.input.exposures.map(({ proof, ...e }, i) => i === 0 ? { ...e, recoveredUnits: "11" } : e);
  const body = canonical({ originals: [f.input.independent[0]?.entitlements[0]?.original,
    ...f.input.nfts.map((n) => n.original), ...f.input.weightedLiquid.map((n) => n.original)], exposures });
  await writeFile(f.evidencePath, body);
  const input = preparationInput.parse({ ...f.input,
    sources: f.input.sources.map((s) => s.id === "proof" ? { ...s, sha256: fingerprint(body), bytes: Buffer.byteLength(body).toString() } : s),
    exposures: f.input.exposures.map((e, i) => i === 0 ? { ...e, recoveredUnits: "11" } : e) });
  await assert.rejects(prepareDomain(input), /origin partition differs/);
});
test("rejects combined quotes that differ from independent frozen component quotes", async () => {
  const f = await setup();
  f.changes.combinedMismatch = true;
  await assert.rejects(prepareDomain(f.input), /component quote mismatch/);
});
test("revalidates persisted manifest payloads and refuses overwrite", async () => {
  const f = await setup();
  const inputPath = join(f.root, "input.json");
  await writeFile(inputPath, canonical(f.input));
  await prepareFile(inputPath, f.root);
  const manifestPath = join(f.root, "manifest.json");
  const result = await validateManifest(manifestPath);
  await writeFile(manifestPath, canonical({ ...result, payloadHash: "f".repeat(64) }));
  await assert.rejects(validateManifest(manifestPath), /binding differs/);
  await assert.rejects(prepareFile(inputPath, f.root), /EEXIST/);
});
test("actual CLI prepares and validates through read-only transport", async () => {
  const f = await setup();
  const input = join(f.root, "input.json");
  await writeFile(input, canonical(f.input));
  for (const args of [["prepare", "--input", input, "--output", f.root], ["validate", "--manifest", join(f.root, "manifest.json")]]) {
    const child = spawn(process.execPath, ["scripts/recovery/dtf-migration/cli.ts", ...args], {
      env: process.env, stdio: ["ignore", "pipe", "pipe"],
    });
    const done = once(child, "exit", { signal: AbortSignal.timeout(5000) });
    assert.ok(child.stdout);
    assert.ok(child.stderr);
    const [stdout, stderr, [exit]] = await Promise.all([text(child.stdout), text(child.stderr), done]);
    assert.deepEqual({ exit, stderr }, { exit: 0, stderr: "" });
    assert.equal(JSON.parse(stdout).mode, "read-only");
  }
});
test("rejects missing RPC and synthetic nonlocal endpoints", async () => {
  const f = await setup();
  await assert.rejects(prepareDomain({ ...f.input, domain: { ...f.input.domain, rpcEnv: "DTF_MISSING_RPC" } }), /missing RPC/);
  const envName = f.input.domain.rpcEnv;
  const previous = process.env[envName];
  process.env[envName] = "https://example.invalid";
  try {
    await assert.rejects(prepareDomain(f.input), /loopback RPC/);
  } finally {
    process.env[envName] = previous;
  }
});
for (const args of [
  ["prepare", "--input", "a", "--input", "b", "--output", "c"],
  ["validate", "--manifest", "x", "--broadcast"],
  ["validate", "--manifest", "x", "--execute-local"],
  ["prepare", "--input", "a"],
]) {
  test(`rejects ambiguous or executing preparation arguments ${args.join(" ")}`, async () => {
    await assert.rejects(main(args));
  });
}
test("rejects invalid recovery fields and unproved multi-conversion batches", async () => {
  const f = await setup();
  const step = { stage: "WeightedUnstake", tokenId: "0", amount: "1", minimum: "0" } as const;
  assert.throws(() => buildPayloads({ ...f.input, harvest: { steps: [{ ...step, tokenId: "3" }], deadline: "100" } }),
    /invalid conversion/);
  assert.throws(() => buildPayloads({ ...f.input, harvest: { steps: [step, step], deadline: "100" } }),
    /batch bound/);
});
test("preserves all category dispositions but emits no manifest for blocked exposure", async () => {
  const f = await setup();
  const exposures = f.input.exposures.map(({ proof, ...e }) => ({ ...e, category: "token-staking" }));
  const raw = canonical({ originals: [f.input.independent[0]?.entitlements[0]?.original,
    ...f.input.nfts.map((n) => n.original), ...f.input.weightedLiquid.map((n) => n.original)], exposures });
  await writeFile(f.evidencePath, raw);
  const input = preparationInput.parse({ ...f.input,
    sources: f.input.sources.map((s) => s.id === "proof" ? { ...s, sha256: fingerprint(raw), bytes: Buffer.byteLength(raw).toString() } : s),
    exposures: f.input.exposures.map((e) => ({ ...e, category: "token-staking" })) });
  const inputPath = join(f.root, "input.json");
  await writeFile(inputPath, canonical(input));
  await assert.rejects(prepareFile(inputPath, f.root), /token-staking/);
  const { readFile } = await import("node:fs/promises");
  const report = JSON.parse(await readFile(join(f.root, "blocked.json"), "utf8"));
  assert.deepEqual(report.dispositions, dispositions(input));
  await assert.rejects(readFile(join(f.root, "manifest.json")), { code: "ENOENT" });
});
