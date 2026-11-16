import { readFile } from "node:fs/promises";
import { createHash } from "node:crypto";
import { resolve, dirname } from "node:path";
import { isDeepStrictEqual } from "node:util";
import { fileURLToPath } from "node:url";
import { keccak256, Interface, id } from "/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-30-recovery-receipts/node_modules/ethers/lib.esm/index.js";

export { keccak256, Interface, id };
export const OUT = dirname(fileURLToPath(import.meta.url));
export const SOURCE = resolve(OUT, "../source");
export const BASE = resolve(OUT, "../..");
export const P32 = resolve(BASE, "phase32-nft-purchase-inputs");
export const FROZEN = resolve(BASE, "phase27-frozen-input-recovery/input-tree/2026-09-16-dtf-recovery");
export const PARENT = "0x4a5cfdc2b07016fcf917f4ed5a51c52111a0fcc7";
export const NFT = "0xfe4cc6d5faafdf210af4e728f4108fcaad9bb65e";
export const FACET = "0xaaf47ef19c9b932b6d00bca3683b000fc6208661";
export const WETH = "0x0bd7d308f8e1639fab988df18a8011f41eacad73";
export const DTF = "0xee5576fa1bcaa380e591d01245f406f3f384eb01";
export const ZERO = "0x0000000000000000000000000000000000000000";
export const identities = new Map();
export const totals = { assertions: 0, bindings: 0, receiptLogs: 0, directLogs: 0 };
export class VerificationError extends Error {
  constructor(label) { super(label); this.name = "VerificationError"; }
}
export function requireFact(value, label) {
  totals.assertions++;
  if (!value) throw new VerificationError(label);
}
export function same(actual, expected, label) {
  requireFact(isDeepStrictEqual(actual, expected), label);
}
export const hash = bytes => createHash("sha256").update(bytes).digest("hex");
export async function bytes(path) {
  const body = await readFile(path);
  identities.set(path, { path, bytes: body.length, sha256: hash(body) });
  return body;
}
export async function json(path) { return JSON.parse(new TextDecoder("utf-8", { fatal: true }).decode(await bytes(path))); }
export async function binding(entry, root) {
  const body = await bytes(resolve(root, entry.path));
  same({ bytes: body.length, sha256: hash(body) }, { bytes: entry.bytes, sha256: entry.sha256 }, `body ${entry.path}`);
  totals.bindings++;
  return body;
}
export async function seal(root) {
  const s = await json(resolve(root, "seal.json"));
  const m = s.manifest ?? s.bindings.find(x => x.path === "manifest.json");
  const manifest = JSON.parse((await binding(m, root)).toString());
  for (const e of s.bindings ?? []) await binding(e, root);
  for (const e of Array.isArray(manifest) ? manifest : manifest.files ?? manifest.entries) await binding(e, root);
  return s;
}
export async function response(entry, root) {
  requireFact(entry, "raw request exists");
  const request = JSON.parse((await binding(entry.request, root)).toString());
  const result = JSON.parse((await binding(entry.response, root)).toString());
  same(request, { jsonrpc: "2.0", id: entry.id, method: entry.method, params: entry.params }, `request ${entry.id}`);
  requireFact(entry.response.raw && (entry.response.httpStatus ?? entry.http.status) === 200, `raw HTTP ${entry.id}`);
  requireFact(result.jsonrpc === "2.0" && result.id === entry.id && !result.error && result.result !== undefined, `RPC ${entry.id}`);
  return result.result;
}
export function addr(word) {
  requireFact(/^0x0{24}[a-f0-9]{40}$/.test(word), "canonical address word");
  return "0x" + word.substring(26);
}
export function table(text, path) {
  // Tokenize complete RFC-style records, with quoted commas/newlines preserved.
  const records = [];
  const cell = /(?:^|,|\r\n|\n|\r)(?:"((?:[^"]|"")*)"|([^",\r\n]*))/gy;
  let record = [], match;
  while ((match = cell.exec(text)) !== null) {
    if (match.index > 0 && /^[\r\n]/.test(match[0])) { records.push(record); record = []; }
    record.push(match[1] === undefined ? match[2] : match[1].replaceAll('""', '"'));
    requireFact(cell.lastIndex > match.index, "CSV makes progress");
    if (cell.lastIndex === text.length) break;
  }
  if (record.length && !(record.length === 1 && record[0] === "")) records.push(record);
  const header = records.shift();
  requireFact(header && new Set(header).size === header.length, `CSV header ${path}`);
  return records.map((r, i) => {
    same(r.length, header.length, `CSV width ${path}:${i + 2}`);
    return { locator: `${path}#row=${i + 2}`, fields: Object.fromEntries(header.map((k, j) => [k, r[j]])) };
  });
}
export async function intake() {
  const subjectSeal = await seal(SOURCE);
  requireFact(subjectSeal.stopped && subjectSeal.finalPublication && subjectSeal.pendingOwnedOperations === 0, "stopped producer seal");
  const refs = await json(resolve(SOURCE, "references.json"));
  for (const e of refs) await binding(e, "/");
  const p28 = refs.find(x => /phase-28/.test(x.path) && x.path.endsWith("/actual/archive.json")).path;
  const v28 = dirname(dirname(p28));
  for (const path of refs.filter(x => x.path.endsWith("/seal.json"))) await seal(dirname(path.path));
  const manifest = await json(resolve(FROZEN, "manifest.json"));
  await binding({ path: "sources.json", ...manifest.files["sources.json"] }, FROZEN);
  const index = await json(resolve(FROZEN, "sources.json"));
  const declarations = [...index.sources, ...Object.entries(manifest.files).map(([path, e]) => ({ path, ...e }))];
  same(declarations.length, 36, "all frozen declarations");
  for (const e of declarations) await binding(e, FROZEN);
  const tables = {};
  for (const p of ["evidence/weighted-bonds.csv", "evidence/earlier-cp-bonds.csv", "evidence/transfers.csv",
    "../2026-09-16-dtf-pre-exploit/dtf-sold-to-detf-details.csv", "conversions.csv"])
    tables[p] = table((await bytes(resolve(FROZEN, p))).toString("utf8"), p);
  const capture = await json(resolve(BASE, "weighted-bond-facet-source-capture-20261113.json"));
  const entity = Buffer.from(capture.bodyBase64Chunks.join(""), "base64");
  same(entity.length, 1636793, "decoded entity bytes");
  same(hash(entity), "adb0729a4d782cef809684171914caa90e8dcc4357446dfef18741f3d7256e27", "decoded entity SHA256");
  const pkg = JSON.parse(new TextDecoder("utf-8", { fatal: true }).decode(entity));
  same(pkg, await json(resolve(SOURCE, "recovered-package.json")), "producer package members");
  same(Object.keys(pkg.sources).sort(), Object.keys(pkg.metadata.sources).sort(), "metadata source set");
  same(Object.keys(pkg.sources).sort(), Object.keys(pkg.stdJsonInput.sources).sort(), "compiler input source set");
  const sourceHashes = [];
  for (const [path, s] of Object.entries(pkg.sources)) {
    const b = Buffer.from(s.content);
    same(keccak256(b), pkg.metadata.sources[path].keccak256, `metadata ${path}`);
    same(s.content, pkg.stdJsonInput.sources[path].content, `compiler input ${path}`);
    sourceHashes.push({ path, bytes: b.length, sha256: hash(b), keccak256: keccak256(b) });
  }
  same(sourceHashes.length, 99, "99 source contents");
  for (const [file, member] of [["abi", "abi"], ["metadata", "metadata"], ["runtime", "runtimeBytecode"], ["creation", "creationBytecode"]])
    same(await json(resolve(SOURCE, `${file}.json`)), pkg[member], `published ${file}`);
  for (const k of ["creationBytecode", "runtimeBytecode"]) {
    same(pkg[k].onchainBytecode, pkg[k].recompiledBytecode, `exact published ${k}`);
    same(pkg[k].transformations, [], `empty transformations ${k}`);
  }
  same(pkg.address.toLowerCase(), FACET, "package address"); same(pkg.chainId, "4663", "package chain");
  same(keccak256(pkg.runtimeBytecode.onchainBytecode), "0x2676830f3b489088787c4ecc21803326a7909fbaaf9fd72994ec62b111bf62f8", "runtime hash");
  same(pkg.abi, pkg.metadata.output.abi, "metadata ABI");
  const compiled = pkg.stdJsonOutput.contracts[pkg.compilation.fullyQualifiedName.split(":")[0]].UniswapV4DetfBondFacet;
  same(compiled.abi, pkg.abi, "compiler-output ABI");
  const signatures = pkg.signatures.function.map(s => {
    same(id(s.signature), s.signatureHash32, "full signature hash");
    same(id(s.signature).slice(0, 10), s.signatureHash4, "function selector");
    return { signature: s.signature, hash: id(s.signature), selector: s.signatureHash4 };
  });
  const abi = new Interface(pkg.abi);
  same(abi.getFunction("bond").stateMutability, "nonpayable", "actual nonpayable bond");
  same(abi.getFunction("bond").selector, "0x7a3b1181", "actual selector");
  return { pkg, abi, tables, sourceHashes, signatures, decodedEntity: { bytes: entity.length, sha256: hash(entity) },
    captureProvenance: { ...capture, bodyBase64Chunks: undefined, checks: undefined },
    archive: await json(p28), archivePath: p28, raw28: resolve(v28, "actual/http"),
    hm28: await json(resolve(v28, "actual/http-manifest.json")), hm32: await json(resolve(P32, "source/http-manifest.json")),
    prior: await json(resolve(P32, "verification/proof.json")), subjectSeal };
}
