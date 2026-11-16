import { afterEach, test } from "node:test";
import assert from "node:assert/strict";
import { readFile, readdir, writeFile } from "node:fs/promises";
import { join } from "node:path";
import { spawn } from "node:child_process";
import { once } from "node:events";
import { text } from "node:stream/consumers";
import { AbiCoder, keccak256 } from "ethers";
import { z } from "zod";
import { fixture, a } from "./preparation.fixture.js";
import { prepareDomain } from "./preparation.js";
import { preparationInput, nftOriginal } from "./schema.js";
import { canonical, fingerprint } from "./provenance.js";
import { buildPayloads, configurationId, weightedCollection } from "./payloads.js";
import { executionManifest } from "./execution-schema.js";
import { plan } from "./execution-plan.js";
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

test("separate NFT mode is bound to the reviewed original, not an operator override", async () => {
  const f = await setup();
  const nfts = f.input.nfts.map((row) => ({ ...row,
    original: { ...row.original, separateContributions: true as const } }));
  await assert.rejects(prepareDomain({ ...f.input, nfts }),
    { name: "PreparationError", code: "PROVENANCE" });
});

test("separate NFT preparation retains two quotes and encodes the two-bond loader", async () => {
  const f = await setup();
  const row = f.input.nfts.find((n) => n.original.collection === weightedCollection);
  assert.ok(row);
  const original = nftOriginal.parse({ ...row.original, separateContributions: true,
    originalEth: "999999000000000", originalDtf: "362893857600000000000" });
  const evidence = z.object({ originals: z.array(z.unknown()), exposures: z.array(z.unknown()) })
    .parse(JSON.parse(await readFile(f.evidencePath, "utf8")));
  const body = canonical({ ...evidence, originals: evidence.originals.map((value, i) => i === 1 ? original : value) });
  await writeFile(f.evidencePath, body);
  const input = preparationInput.parse({ ...f.input,
    nfts: f.input.nfts.map((n) => n === row ? { ...n, original } : n),
    sources: f.input.sources.map((s) => s.id === "proof"
      ? { ...s, sha256: fingerprint(body), bytes: Buffer.byteLength(body).toString() } : s) });
  const prepared = await prepareDomain(input);
  const configured = prepared.payloads.configure.nfts.find((n) => n.input.collection === weightedCollection);
  assert.ok(configured);
  assert.deepEqual(configured.contributions, [
    { originalEth: original.originalEth, originalDtf: "0", credit: "99999900000000" },
    { originalEth: "0", originalDtf: original.originalDtf, credit: "32990350690909090909" },
  ]);
  assert.equal(configured.quotedCredit, "32990450690809090909");
  assert.equal(prepared.quoteEvidence.quotes.some((q) =>
    q.originalEth === original.originalEth && q.originalDtf === original.originalDtf), false);
  const allocation = await interfaceFile("out/IUniswapV4DetfMigration.sol/IUniswapV4DetfMigrationAllocation.json");
  const migration = await interfaceFile("out/IUniswapV4DetfMigration.sol/IUniswapV4DetfMigration.json");
  const recovery = await interfaceFile("out/IUniswapV4DetfMigrationRecovery.sol/IUniswapV4DetfMigrationRecovery.json");
  const pkg = await interfaceFile("out/IUniswapV4DetfMigrationDFPkg.sol/IUniswapV4DetfMigrationDFPkg.json");
  const syPackage = await interfaceFile("out/IUniswapV4DetfMigrationSYDFPkg.sol/IUniswapV4DetfMigrationSYDFPkg.json");
  const manifest = executionManifest.parse({
    version: "dtf-operator-execution-v2", purpose: input.purpose, chainId: input.domain.chainId,
    rpcEnv: input.domain.rpcEnv, signer: a(20), local: null, proxy: input.domain.proxy,
    registry: a(11), package: a(12), bookId: input.domain.bookId,
    bindings: input.domain.bindings, sources: input.sources, preparedManifest: "prepared.json",
    pricing: null, deploymentReceipt: null, deploymentBlockNumber: input.domain.deploymentBlockNumber, deploymentBlockHash: input.domain.deploymentBlockHash,
    deployment: null, funding: { donations: [], genesis: null }, ownerBond: null,
  });
  const operations = plan({ manifest, prepared, abis: { allocation, migration, recovery, pkg, syPackage },
    domain: { manifest, preparedHash: prepared.normalizedHash, payloadHash: prepared.payloadHash } }, "configure");
  const separate = operations.filter((op) => op.method === "configureNftContributionEntitlements");
  assert.equal(separate.length, 1);
  assert.equal(operations.filter((op) => op.method === "configureNftEntitlements").length, 1);
  assert.ok(separate[0]);
  const decoded = allocation.decodeFunctionData("configureNftContributionEntitlements", separate[0].transaction.data);
  assert.equal(decoded[0][0].originalEth, 999999000000000n);
  assert.equal(decoded[0][0].originalDtf, 362893857600000000000n);
  const combined = operations.filter((op) => op.method === "configureNftEntitlements");
  assert.ok(combined[0]);
  assert.notEqual(allocation.decodeFunctionData("configureNftEntitlements",
    combined[0].transaction.data)[0][0].collection.toLowerCase(), weightedCollection);
  console.log(JSON.stringify({ task5Payload: configured, loader: separate[0].method,
    decodedOriginalEth: decoded[0][0].originalEth.toString(),
    decodedOriginalDtf: decoded[0][0].originalDtf.toString(), combinedControl: combined[0].method }));
  const tuple = allocation.getFunction("configureNftContributionEntitlements")?.inputs[0]?.arrayChildren;
  assert.ok(tuple);
  assert.equal(configured.configurationId, keccak256(AbiCoder.defaultAbiCoder().encode(
    ["uint256", "address", "bytes32", tuple, "bool"],
    [input.domain.chainId, input.domain.proxy, input.domain.bookId, original, true])));
  const { separateContributions: _mode, ...single } = original;
  assert.notEqual(configured.configurationId, configurationId(input.domain, single));
  assert.throws(() => buildPayloads({ ...input,
    nfts: input.nfts.map((n) => n.original.collection === weightedCollection ? { ...n, original: single } : n) }),
  { name: "PreparationError", code: "INPUT" });
});

for (const kind of ["absent", "false", "combined", "missing-eth", "missing-dtf",
  "zero-eth", "zero-dtf", "altered-eth", "altered-dtf", "stale-combined"] as const) {
  test(`weighted NFT three rejects ${kind} before transport and transaction creation`, async () => {
    const f = await setup();
    const row = f.input.nfts.find((n) => n.original.collection === weightedCollection);
    assert.ok(row);
    const { separateContributions: _mode, ...withoutMode } = row.original;
    const { originalEth: _eth, ...withoutEth } = row.original;
    const { originalDtf: _dtf, ...withoutDtf } = row.original;
    const originals = {
      absent: withoutMode,
      false: { ...row.original, separateContributions: false },
      combined: { ...row.original, separateContributions: "combined" },
      "missing-eth": withoutEth,
      "missing-dtf": withoutDtf,
      "zero-eth": { ...row.original, originalEth: "0" },
      "zero-dtf": { ...row.original, originalDtf: "0" },
      "altered-eth": { ...row.original, originalEth: "999999000000001" },
      "altered-dtf": { ...row.original, originalDtf: "362893857600000000001" },
      "stale-combined": { ...withoutMode, originalEth: "100", originalDtf: "22" },
    };
    const candidate = { ...f.input,
      nfts: f.input.nfts.map((n) => n === row ? { ...n, original: originals[kind] } : n) };
    const parsedOriginal = nftOriginal.safeParse(originals[kind]);
    if (parsedOriginal.success) {
      assert.throws(() => buildPayloads({ ...f.input,
        nfts: f.input.nfts.map((n) => n === row ? { ...n, original: parsedOriginal.data } : n) }),
      { name: "PreparationError", code: "INPUT" });
    }
    assert.equal(preparationInput.safeParse(candidate).success, false);
    const inputPath = join(f.root, "input.json");
    await writeFile(inputPath, canonical(candidate));
    const child = spawn(process.execPath, ["scripts/recovery/dtf-migration/cli.ts",
      "prepare", "--input", inputPath, "--output", join(f.root, "prepared")], {
      env: process.env, stdio: ["ignore", "pipe", "pipe"],
    });
    const done = once(child, "exit", { signal: AbortSignal.timeout(5000) });
    assert.ok(child.stdout);
    assert.ok(child.stderr);
    const [stdout, stderr, [exit]] = await Promise.all([text(child.stdout), text(child.stderr), done]);
    assert.equal(exit, 1);
    assert.equal(stdout, "");
    const failure = z.object({ error: z.enum(["INPUT", "PROVENANCE"]) }).passthrough()
      .parse(JSON.parse(stderr));
    assert.deepEqual(f.methods, []);
    await assert.rejects(readdir(join(f.root, "prepared")), { code: "ENOENT" });
    console.log(JSON.stringify({ rejected: kind, error: failure.error,
      transportRequests: f.methods.length, transactions: 0, preparedDirectory: "absent" }));
  });
}

test("weighted NFT three requires explicit matching source proof before transport", async () => {
  const f = await setup();
  const row = f.input.nfts.find((n) => n.original.collection === weightedCollection);
  assert.ok(row);
  const { proof: _proof, ...withoutProof } = row;
  assert.equal(preparationInput.safeParse({ ...f.input,
    nfts: f.input.nfts.map((n) => n === row ? withoutProof : n) }).success, false);
  await assert.rejects(prepareDomain({ ...f.input,
    nfts: f.input.nfts.map((n) => n === row
      ? { ...n, proof: { ...n.proof, pointer: "/originals/2" } } : n) }),
  { name: "PreparationError", code: "PROVENANCE" });
  assert.deepEqual(f.methods, []);
});

test("two-bond NFT mode rejects a missing contribution leg", async () => {
  const f = await setup();
  const row = f.input.nfts[0];
  assert.ok(row);
  for (const amounts of [{ originalEth: "0" }, { originalDtf: "0" }]) {
    assert.equal(nftOriginal.safeParse({ ...row.original, ...amounts, separateContributions: true }).success, false);
  }
});
