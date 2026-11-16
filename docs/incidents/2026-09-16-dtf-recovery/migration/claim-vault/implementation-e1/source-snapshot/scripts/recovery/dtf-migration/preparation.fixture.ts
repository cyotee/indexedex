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
  const artifactPath = resolve("out/UniswapV4DetfMigrationFacet.sol/UniswapV4DetfMigrationFacet.json");
  const artifactBytes = await readFile(artifactPath);
  const artifact = z.object({ abi: z.array(z.unknown()) }).parse(JSON.parse(artifactBytes.toString()));
  const iface = new Interface(JSON.stringify(artifact.abi));
  const fragment = iface.getFunction("migrationSnapshot");
  const output = fragment?.outputs[0];
  if (!fragment || !output?.components) throw new Error("warm Migration ABI required");
  const values = output.components.map(zero);
  const set = (name: string, value: unknown): void => {
    const index = output.components?.findIndex((p) => p.name === name);
    if (index === undefined || index < 0) throw new Error(`missing ${name}`);
    values[index] = value;
  };
  set("version", 1n);
  set("chainId", 4663n);
  set("consumer", a(10));
  set("source", [a(10), a(11), a(12), a(13)]);
  const snapshotId = keccak256(coder.encode(["string", output], ["IndexedEx.frozen-original-credit", values]));
  set("id", snapshotId);
  const snapshot = iface.encodeFunctionResult(fragment, [values]);
  const preview = new Interface(["function previewOriginalCredit(uint256,uint256) view returns(uint256)"]);
  const changes = { chain: "0x1237", code: "0x6000", snapshot, combinedMismatch: false };
  const methods: string[] = [];
  const rpcRequest = z.object({ id: z.number(), method: z.string(), params: z.array(z.unknown()) });
  const server = createServer(async (request, response) => {
      const rpc = rpcRequest.parse(JSON.parse(await text(request)));
      methods.push(rpc.method);
      let result: unknown;
      switch (rpc.method) {
        case "eth_chainId": result = changes.chain; break;
        case "eth_getBlockByNumber": result = { number: "0x64", hash: h(100), parentHash: h(99) }; break;
        case "eth_getCode": result = changes.code; break;
        case "eth_call": {
          const call = z.object({ data: z.string() }).parse(rpc.params[0]);
          if (call.data === iface.encodeFunctionData(fragment)) result = changes.snapshot;
          else {
            const args = preview.decodeFunctionData("previewOriginalCredit", call.data);
            const eth = BigInt(args[0]);
            const dtf = BigInt(args[1]);
            const value = eth / 10n + dtf / 11n + (changes.combinedMismatch && eth > 0n && dtf > 0n ? 1n : 0n);
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
    chainId: "4663", proxy: a(10), snapshotId, blockNumber: "100", blockHash: h(100),
    rpcEnv: envName, snapshotArtifact: artifactPath,
    bindings: [
      { role: "proxy", address: a(10), codeHash: keccak256("0x6000") },
      { role: "registry", address: a(11), codeHash: keccak256("0x6000") },
      { role: "package", address: a(12), codeHash: keccak256("0x6000") },
      { role: "facet", address: a(13), codeHash: keccak256("0x6000") },
    ],
  };
  const original = { entitlementId: h(200), originalEth: "90071992547409931234",
    originalDtf: "110", evidenceId: h(201) };
  const nft = { collection: weightedCollection, tokenId: "3", originalWallet: a(21), originalUnits: "100",
    originalEth: "100", originalDtf: "22", evidenceId: h(202), contributionsKnown: true };
  const earlier = { ...nft, collection: earlierCollection, originalUnits: "2281854312954086546", evidenceId: h(204) };
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
  const input = preparationInput.parse({
    version: "dtf-operator-preparation-v1", purpose: "synthetic-local", domain,
    sources: [
      { id: "proof", path: evidencePath, sha256: fingerprint(raw), bytes: Buffer.byteLength(raw).toString(),
        provenance: { kind: "file", authority: "Synthetic wire fixture; not an approved historical allocation" } },
      { id: "abi", path: artifactPath, sha256: fingerprint(artifactBytes), bytes: artifactBytes.length.toString(),
        provenance: { kind: "file", authority: "Warm artifact from accepted source base421072a7" } },
    ],
    exposures: exposures.map((e, i) => ({ ...e, proof: { sourceId: "proof", pointer: `/exposures/${i}` } })),
    independent: [{ recipient: a(20), evidenceId: h(203),
      entitlements: [{ original, proof: { sourceId: "proof", pointer: "/originals/0" } }] }],
    nfts: [
      { original: nft, proof: { sourceId: "proof", pointer: "/originals/1" } },
      { original: earlier, proof: { sourceId: "proof", pointer: "/originals/2" } },
    ],
    weightedLiquid: [{ original: liquid, proof: { sourceId: "proof", pointer: "/originals/3" } }],
    weightedSy: [{ original: sy, proof: { sourceId: "proof", pointer: "/originals/4" } }],
    dtfCustodySe: [{ original: custodySe, proof: { sourceId: "proof", pointer: "/originals/5" } }],
    claimVault: [{ original: claim, proof: { sourceId: "proof", pointer: "/originals/6" } }],
    issueRecipients: [a(20)], harvest: { steps: [], deadline: "0" },
  });
  return { root, input, changes, methods, evidencePath, async close() {
    await new Promise<void>((accept, reject) => server.close((error) => error ? reject(error) : accept()));
    delete process.env[envName];
    await rm(root, { recursive: true });
  } };
}
