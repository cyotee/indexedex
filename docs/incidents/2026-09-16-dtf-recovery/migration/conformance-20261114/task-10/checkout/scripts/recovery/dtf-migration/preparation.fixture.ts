// Synthetic wire fixture only. This is not an EVM or a real pricing proof.
import { AbiCoder, Interface, keccak256 } from "ethers";
import type { ParamType } from "ethers";
import { mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { createServer } from "node:http";
import { once } from "node:events";
import { text } from "node:stream/consumers";
import { z } from "zod";
import { canonical, fingerprint } from "./provenance.js";
import { earlierCollection, nftOrigin, weightedCollection, weightedLiquidSource, weightedSySource, dtfCustodySeSource, claimVaultSource } from "./payloads.js";
import { domain as domainSchema, nftOriginal, preparationInput } from "./schema.js";

export const h = (n: number): string => `0x${n.toString(16).padStart(64, "0")}`;
export const a = (n: number): string => `0x${n.toString(16).padStart(40, "0")}`;
const coder = AbiCoder.defaultAbiCoder();
function zero(param: ParamType): unknown {
  if (param.baseType === "tuple") return param.components?.map(zero);
  if (param.baseType === "array" && param.arrayChildren) {
    const child = param.arrayChildren;
    return Array.from({ length: Math.max(0, param.arrayLength ?? 0) }, () => zero(child));
  }
  if (param.type === "address") return a(1);
  if (param.type === "bool") return false;
  if (param.type.startsWith("bytes")) return param.type === "bytes" ? "0x" : h(0);
  return 0n;
}

export async function fixture() {
  const root = await mkdtemp(join(tmpdir(), "dtf-prepare-test-"));
  const artifactPath = resolve("out/UniswapV4DetfMigrationWeightedHookFacet.sol/UniswapV4DetfMigrationWeightedHookFacet.json");
  const artifactBytes = await readFile(artifactPath);
  const artifact = z.object({ abi: z.array(z.unknown()) }).parse(JSON.parse(artifactBytes.toString()));
  const iface = new Interface(JSON.stringify(artifact.abi));
  const fragment = iface.getFunction("migrationWeightedPricing");
  const output = fragment?.outputs[0];
  if (!fragment || !output?.components) throw new Error("warm Migration ABI required");
  const values = output.components.map(zero);
  const set = (name: string, value: unknown): void => {
    const index = output.components?.findIndex((p) => p.name === name);
    if (index === undefined || index < 0) throw new Error(`missing ${name}`);
    values[index] = value;
  };
  set("version", 2n);
  set("chainId", 4663n);
  set("consumer", a(10));
  set("weth", a(14));
  set("originalDtf", a(15));
  const inputs = { swapFeeWad: "1000000000000000", seigniorage: "0", ethIndex: "0", dtfIndex: "1", detfIndex: "2",
    legs: [a(14), a(15), a(10)].map((token, i) => ({ token, standardExchange: a(0), mode: "0", rawReserve: "1000000000000000000000",
      seReserve: "0", weight: i === 2 ? "400000000000000000" : "300000000000000000", invScale: i === 2 ? "1000000000000000000000000000" : "1000000000000000000",
      ratedScale: i === 2 ? "1000000000000000000000000000" : "1000000000000000000", rate: "0",
      deposit: { model: "0", exchange: a(0), request: { tokenIn: a(0), tokenOut: a(0), holder: a(0), mode: "0" },
        token0: a(0), token1: a(0), supply: "0", reserve0: "0", reserve1: "0", minimumLiquidity: "0" } })) };
  set("inputs", inputs);
  const bookId = keccak256(coder.encode(["string", output], ["IndexedEx.manual-weighted-original-credit", values]));
  set("id", bookId);
  const book = iface.encodeFunctionResult(fragment, [values]);
  const inputType = output.components.find((p) => p.name === "inputs");
  if (!inputType) throw new Error("manual input ABI missing");
  const setter = new Interface(["function setMigrationWeightedPricing(" + inputType.format("full") + ") returns(bytes32)",
    "event MigrationWeightedPricingSet(bytes32 indexed bookId)"]);
  const registry = new Interface(["event NewVault(address indexed vault,address indexed package,bytes32 vaultFeeIds,bytes32 indexed contentsId,bytes4[] vaultTypes,address[] tokens)"]);
  const setterEvent = setter.getEvent("MigrationWeightedPricingSet");
  const deployEvent = registry.getEvent("NewVault");
  if (!setterEvent || !deployEvent) throw new Error("event ABI missing");
  const log = (block: number, tx: number, emitter: string, encoded: { topics: readonly string[]; data: string }) => ({
    address: emitter, topics: [...encoded.topics], data: encoded.data, logIndex: "0x0", transactionHash: h(tx), transactionIndex: "0x0",
    blockHash: h(block), blockNumber: "0x" + block.toString(16),
  });
  const pricingLog = log(99, 900, a(10), setter.encodeEventLog(setterEvent, [bookId]));
  const deploymentLog = log(90, 901, a(11), registry.encodeEventLog(deployEvent, [a(10), a(12), h(0), h(1), [], [a(14), a(15)]]));
  const receiptFor = (entry: typeof pricingLog, target: string) => ({ transactionHash: entry.transactionHash, blockHash: entry.blockHash,
    blockNumber: entry.blockNumber, transactionIndex: "0x0", from: a(20), to: target, status: "0x1", logs: [entry] });
  const deploymentReceipt = receiptFor(deploymentLog, a(12));
  const deploymentPath = join(root, "deployment.json");
  const deploymentRaw = canonical(deploymentReceipt);
  await writeFile(deploymentPath, deploymentRaw);
  const pricingReceipt = receiptFor(pricingLog, a(10));
  const preview = new Interface(["function previewOriginalCredit(uint256,uint256) view returns(uint256)"]);
  const changes = { chain: "0x1237", code: "0x6000", book, combinedMismatch: false,
    reads: new Map<string, string>(), quoteDelta: 0n,
    blocks: new Map<string, unknown>(), receipts: new Map<string, unknown>(),
    transactions: new Map<string, unknown>(), logs: new Map<string, unknown>(),
    traces: new Map<string, unknown>() };
  const methods: string[] = [];
  const rpcRequest = z.object({ id: z.number(), method: z.string(), params: z.array(z.unknown()) });
  const server = createServer(async (request, response) => {
      const rpc = rpcRequest.parse(JSON.parse(await text(request)));
      methods.push(rpc.method);
      let result: unknown;
      switch (rpc.method) {
        case "eth_chainId": result = changes.chain; break;
        case "eth_getBlockByNumber": {
          const tag = z.string().parse(rpc.params[0]);
          const n = tag === "latest" ? 100 : Number(BigInt(tag));
          result = changes.blocks.get(tag) ?? { number: "0x" + n.toString(16), hash: h(n), parentHash: h(n - 1), transactions: n === 99 ? [h(900)] : n === 90 ? [h(901)] : [] }; break;
        }
        case "eth_getTransactionReceipt": result = changes.receipts.get(String(rpc.params[0])) ?? (rpc.params[0] === h(900) ? pricingReceipt : rpc.params[0] === h(901) ? deploymentReceipt : null); break;
        case "eth_getTransactionByHash": result = changes.transactions.get(String(rpc.params[0])) ?? { hash: h(900), to: a(10), input: setter.encodeFunctionData("setMigrationWeightedPricing", [inputs]), blockHash: h(99), transactionIndex: "0x0" }; break;
        case "eth_getLogs": {
          const filter = z.object({ blockHash: z.string().optional() }).passthrough().parse(rpc.params[0]);
          result = changes.logs.get(filter.blockHash ?? canonical(filter)) ?? (filter.blockHash === h(99) ? [pricingLog] : filter.blockHash === h(90) ? [deploymentLog] : []); break;
        }
        case "debug_traceCall": {
          const call = z.object({ data: z.string() }).parse(rpc.params[0]);
          const config = z.object({ txIndex: z.string() }).passthrough().parse(rpc.params[2]);
          result = changes.traces.get(call.data + ":" + config.txIndex);
          break;
        }
        case "eth_getCode": result = changes.code; break;
        case "eth_call": {
          const call = z.object({ data: z.string() }).parse(rpc.params[0]);
          const scoped = call.data + "@" + String(rpc.params[1]);
          if (changes.reads.has(scoped)) result = changes.reads.get(scoped);
          else if (changes.reads.has(call.data)) result = changes.reads.get(call.data);
          else if (call.data === iface.encodeFunctionData(fragment)) result = changes.book;
          else if (!call.data.startsWith(preview.getFunction("previewOriginalCredit")?.selector ?? "missing")) {
            const fn = iface.getFunction(call.data.slice(0, 10));
            if (!fn) throw new Error("unhandled fixture read");
            result = iface.encodeFunctionResult(fn, fn.outputs.map(zero));
          }
          else {
            const args = preview.decodeFunctionData("previewOriginalCredit", call.data);
            const eth = BigInt(args[0]);
            const dtf = BigInt(args[1]);
            const value = eth / 10n + dtf / 11n + changes.quoteDelta + (changes.combinedMismatch && eth > 0n && dtf > 0n ? 1n : 0n);
            result = preview.encodeFunctionResult("previewOriginalCredit", [value]);
          }
          break;
        }
        default:
          response.end(JSON.stringify({ jsonrpc: "2.0", id: rpc.id, error: { code: -32601, message: "read not supported" } }));
          return;
      }
      response.setHeader("Content-Type", "application/json");
      response.end(JSON.stringify({ jsonrpc: "2.0", id: rpc.id, result }));
  });
  const ready = once(server, "listening", { signal: AbortSignal.timeout(5000) });
  server.listen(0, "127.0.0.1");
  await ready;
  const listener = server.address();
  if (!listener || typeof listener === "string") throw new Error("missing TCP listener");
  const envName = `DTF_TEST_RPC_${listener.port}`;
  process.env[envName] = `http://127.0.0.1:${listener.port}`;
  const domain = {
    chainId: "4663", proxy: a(10), bookId,
    deploymentBlockNumber: "90", deploymentBlockHash: h(90), deploymentProof: { sourceId: "deployment", pointer: "" }, blockNumber: "100", blockHash: h(100),
    rpcEnv: envName, pricingArtifact: artifactPath,
    bindings: [
      { role: "proxy", address: a(10), codeHash: keccak256("0x6000") },
      { role: "registry", address: a(11), codeHash: keccak256("0x6000") },
      { role: "package", address: a(12), codeHash: keccak256("0x6000") },
      { role: "facet", address: a(13), codeHash: keccak256("0x6000") },
    ],
  };
  const original = { entitlementId: h(200), originalEth: "90071992547409931234",
    originalDtf: "110", evidenceId: h(201) };
  const earlier = { collection: earlierCollection, tokenId: "3", originalWallet: a(21),
    originalUnits: "2281854312954086546", originalEth: "100", originalDtf: "22",
    evidenceId: h(204), contributionsKnown: true };
  const nft = { ...earlier, collection: weightedCollection, originalUnits: "100", evidenceId: h(202),
    originalEth: "999999000000000", originalDtf: "362893857600000000000", separateContributions: true as const };
  const liquid = { originalId: h(205), originalWallet: a(22), source: weightedLiquidSource,
    originalUnits: "3", originalEth: "100", originalDtf: "22", evidenceId: h(206), contributionsKnown: true };
  const sy = { ...liquid, originalId: h(207), source: weightedSySource, evidenceId: h(208) };
  const custodySe = { ...liquid, originalId: h(209), source: dtfCustodySeSource,
    originalUnits: "10000000000000000000000000000", evidenceId: h(215) };
  const claim = { ...liquid, originalId: h(217), source: claimVaultSource,
    originalUnits: "10000000000000000000", evidenceId: h(218) };
  const nftId = nftOrigin(domainSchema.parse(domain), nftOriginal.parse(nft));
  const earlierId = nftOrigin(domainSchema.parse(domain), nftOriginal.parse(earlier));
  const exposures = [
    { originId: h(200), category: "independent", originalUnits: "100", descendants: [{ id: h(210), units: "80" }],
      recoveredUnits: "10", excludedUnits: "10" },
    { originId: nftId, category: "weighted-nft", originalUnits: "100", descendants: [{ id: h(211), units: "100" }],
      recoveredUnits: "0", excludedUnits: "0" },
    { originId: earlierId, category: "earlier-nft", originalUnits: earlier.originalUnits,
      descendants: [{ id: h(212), units: earlier.originalUnits }], recoveredUnits: "0", excludedUnits: "0" },
    { originId: liquid.originalId, category: "weighted-liquid", originalUnits: liquid.originalUnits,
      descendants: [{ id: h(213), units: liquid.originalUnits }], recoveredUnits: "0", excludedUnits: "0" },
  ];
  exposures.push({ originId: sy.originalId, category: "weighted-sy", originalUnits: sy.originalUnits,
    descendants: [{ id: h(214), units: sy.originalUnits }], recoveredUnits: "0", excludedUnits: "0" });
  exposures.push({ originId: custodySe.originalId, category: "dtf-custody-se", originalUnits: custodySe.originalUnits,
    descendants: [{ id: h(216), units: custodySe.originalUnits }], recoveredUnits: "0", excludedUnits: "0" });
  exposures.push({ originId: claim.originalId, category: "claim-vault", originalUnits: claim.originalUnits,
    descendants: [{ id: h(219), units: claim.originalUnits }], recoveredUnits: "0", excludedUnits: "0" });
  const evidence = { originals: [original, nft, earlier, liquid, sy, custodySe, claim], exposures };
  const evidencePath = join(root, "evidence.json");
  const raw = canonical(evidence);
  await writeFile(evidencePath, raw);
  const pricing = { kind: "load", bookId, replaces: null };
  const input = preparationInput.parse({
    version: "dtf-operator-preparation-v2", purpose: "synthetic-local", domain,
    books: [{ bookId, encodedBook: book, observationBlockNumber: "100", observationBlockHash: h(100), setTransactionHash: h(900) }], issuedHistory: [],
    sources: [
      { id: "deployment", path: deploymentPath, sha256: fingerprint(deploymentRaw), bytes: String(Buffer.byteLength(deploymentRaw)), provenance: { kind: "file", authority: "synthetic canonical deployment transport" } },
      { id: "proof", path: evidencePath, sha256: fingerprint(raw), bytes: Buffer.byteLength(raw).toString(),
        provenance: { kind: "file", authority: "Synthetic wire fixture; not an approved historical allocation" } },
      { id: "abi", path: artifactPath, sha256: fingerprint(artifactBytes), bytes: artifactBytes.length.toString(),
        provenance: { kind: "file", authority: "Warm artifact from accepted source base421072a7" } },
    ],
    exposures: exposures.map((e, i) => ({ ...e, proof: { sourceId: "proof", pointer: `/exposures/${i}` } })),
    independent: [{ pricing, recipient: a(20), evidenceId: h(203),
      entitlements: [{ original, proof: { sourceId: "proof", pointer: "/originals/0" } }] }],
    nfts: [
      { pricing, original: nft, proof: { sourceId: "proof", pointer: "/originals/1" } },
      { pricing, original: earlier, proof: { sourceId: "proof", pointer: "/originals/2" } },
    ],
    weightedLiquid: [{ pricing, original: liquid, proof: { sourceId: "proof", pointer: "/originals/3" } }],
    weightedSy: [{ pricing, original: sy, proof: { sourceId: "proof", pointer: "/originals/4" } }],
    dtfCustodySe: [{ pricing, original: custodySe, proof: { sourceId: "proof", pointer: "/originals/5" } }],
    claimVault: [{ pricing, original: claim, proof: { sourceId: "proof", pointer: "/originals/6" } }],
    weightedReceipt: [],
    issueRecipients: [a(20)], harvest: { steps: [], deadline: "0" },
  });
  return { root, input, changes, methods, evidencePath, async close() {
    await new Promise<void>((accept, reject) => server.close((error) => error ? reject(error) : accept()));
    delete process.env[envName];
    await rm(root, { recursive: true });
  } };
}

export async function executionFixture(independentOnly = false) {
  const f = await fixture();
  const { prepareDomain } = await import("./preparation.js");
  const { executionManifest } = await import("./execution-schema.js");
  const { sourceFile, interfaceFile } = await import("./rehearsal-data.js");
  const { DEV } = await import("./execution-rpc.js");
  const input = independentOnly ? { ...f.input, nfts: [], weightedLiquid: [], weightedSy: [], dtfCustodySe: [],
    claimVault: [], weightedReceipt: [], earlierReceipt: [], earlierLiquid: [], heldSeLp: [],
    exposures: f.input.exposures.filter((e) => e.category === "independent") } : f.input;
  const prepared = await prepareDomain(input);
  const preparedManifest = join(f.root, "prepared.json");
  await writeFile(preparedManifest, canonical(prepared), { flag: "wx" });
  const names = {
    migration: ["migration-abi", "out/IUniswapV4DetfMigration.sol/IUniswapV4DetfMigration.json"],
    allocation: ["allocation-abi", "out/IUniswapV4DetfMigration.sol/IUniswapV4DetfMigrationAllocation.json"],
    recovery: ["recovery-abi", "out/IUniswapV4DetfMigrationRecovery.sol/IUniswapV4DetfMigrationRecovery.json"],
    pkg: ["package-abi", "out/IUniswapV4DetfMigrationDFPkg.sol/IUniswapV4DetfMigrationDFPkg.json"],
    syPackage: ["sy-package-abi", "out/IUniswapV4DetfMigrationSYDFPkg.sol/IUniswapV4DetfMigrationSYDFPkg.json"],
  } as const;
  const sources = [...f.input.sources];
  for (const [id, path] of Object.values(names)) sources.push(await sourceFile(id, path));
  const manifest = executionManifest.parse({
    version: "dtf-operator-execution-v2", purpose: f.input.purpose, chainId: f.input.domain.chainId,
    rpcEnv: f.input.domain.rpcEnv, signer: DEV, local: null, proxy: f.input.domain.proxy,
    registry: a(11), package: a(12), bookId: f.input.domain.bookId, pricing: null,
    deployment: null, deploymentReceipt: null, deploymentBlockNumber: "90", deploymentBlockHash: h(90),
    bindings: f.input.domain.bindings, sources, preparedManifest, funding: { donations: [], genesis: null }, ownerBond: null,
  });
  const manifestPath = join(f.root, "execution.json");
  await writeFile(manifestPath, canonical(manifest), { flag: "wx" });
  const abis = {
    migration: await interfaceFile(names.migration[1]), allocation: await interfaceFile(names.allocation[1]),
    recovery: await interfaceFile(names.recovery[1]), pkg: await interfaceFile(names.pkg[1]),
    syPackage: await interfaceFile(names.syPackage[1]),
  };
  const domain = { manifest, prepared, abis,
    domain: { manifest, preparedHash: prepared.normalizedHash, payloadHash: prepared.payloadHash } };
  return { ...f, input, domain, manifestPath, preparedManifest };
}
