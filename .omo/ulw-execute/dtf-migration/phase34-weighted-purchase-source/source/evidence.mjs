import { readFile } from "node:fs/promises";
import { createHash } from "node:crypto";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { isDeepStrictEqual } from "node:util";
import { Interface, keccak256, id } from "/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-30-recovery-receipts/node_modules/ethers/lib.esm/index.js";

export { Interface, keccak256, id };
export const OUT = dirname(fileURLToPath(import.meta.url));
export const ROOT = "/Users/cyotee/Projects/indexedex/.omo/ulw-execute/dtf-migration";
export const P32 = `${ROOT}/phase32-nft-purchase-inputs`;
export const FROZEN = `${ROOT}/phase27-frozen-input-recovery/input-tree/2026-09-16-dtf-recovery`;
export const WETH = "0x0bd7d308f8e1639fab988df18a8011f41eacad73";
export const DTF = "0xee5576fa1bcaa380e591d01245f406f3f384eb01";
export const PARENT = "0x4a5cfdc2b07016fcf917f4ed5a51c52111a0fcc7";
export const NFT = "0xfe4cc6d5faafdf210af4e728f4108fcaad9bb65e";
export const FACET = "0xaaf47ef19c9b932b6d00bca3683b000fc6208661";
export const ZERO = `0x${"0".repeat(40)}`;
export const TRANSFER = id("Transfer(address,address,uint256)");
export const identities = new Map();
export const counts = { assertions: 0, bindings: 0, receiptLogs: 0 };
export class EvidenceError extends Error {
  constructor(label) { super(label); this.name = "EvidenceError"; }
}
export function check(condition, label) {
  counts.assertions++;
  if (!condition) throw new EvidenceError(label);
}
export function equal(actual, expected, label) {
  check(isDeepStrictEqual(actual, expected), label);
}
export const sha = bytes => createHash("sha256").update(bytes).digest("hex");
export async function raw(path) {
  const bytes = await readFile(path);
  identities.set(path, { path, bytes: bytes.length, sha256: sha(bytes) });
  return bytes;
}
export async function json(path) { return JSON.parse((await raw(path)).toString("utf8")); }
export async function bind(entry, directory) {
  const bytes = await raw(resolve(directory, entry.path));
  check(bytes.length === entry.bytes && sha(bytes) === entry.sha256, `binding ${entry.path}`);
  counts.bindings++;
  return bytes;
}
export async function sealed(directory) {
  const seal = await json(`${directory}/seal.json`);
  const mb = seal.manifest ?? seal.bindings.find(x => x.path === "manifest.json");
  await bind(mb, directory);
  for (const b of seal.bindings ?? []) await bind(b, directory);
  const manifest = await json(resolve(directory, mb.path));
  for (const b of Array.isArray(manifest) ? manifest : manifest.files ?? manifest.entries) await bind(b, directory);
  return seal;
}
export function csv(text, path) {
  const rows = [];
  let cells = [], cell = "", quoted = false;
  for (let i = 0; i < text.length; i++) {
    const c = text[i];
    if (c === '"') {
      if (quoted && text[i + 1] === '"') { cell += '"'; i++; }
      else quoted = !quoted;
    } else if (!quoted && (c === "," || c === "\n" || c === "\r")) {
      cells.push(cell); cell = "";
      if (c !== ",") {
        rows.push(cells); cells = [];
        if (c === "\r" && text[i + 1] === "\n") i++;
      }
    } else cell += c;
  }
  check(!quoted, `CSV closed ${path}`);
  if (cell || cells.length) { cells.push(cell); rows.push(cells); }
  const header = rows.shift();
  check(new Set(header).size === header.length, `CSV columns ${path}`);
  return rows.map((values, i) => {
    check(values.length === header.length, `CSV row width ${path}:${i + 2}`);
    return { locator: `${path}#row=${i + 2}`, fields: Object.fromEntries(header.map((h, j) => [h, values[j]])) };
  });
}
export function address(word) {
  check(/^0x0{24}[0-9a-f]{40}$/.test(word), "canonical address word");
  return `0x${word.slice(-40)}`;
}
export async function wire(entry, directory) {
  const request = JSON.parse((await bind(entry.request, directory)).toString("utf8"));
  const response = JSON.parse((await bind(entry.response, directory)).toString("utf8"));
  check(entry.response.raw && (entry.response.httpStatus ?? entry.http.status) === 200, `raw successful ${entry.id}`);
  equal(request, { jsonrpc: "2.0", id: entry.id, method: entry.method, params: entry.params }, `request ${entry.id}`);
  check(response.jsonrpc === "2.0" && response.id === entry.id && !response.error && response.result !== undefined, `response ${entry.id}`);
  return response.result;
}
export async function intake() {
  const references = await json(`${OUT}/references.json`);
  for (const b of references) await bind(b, "/");
  const p28 = references.find(x => x.path.includes("phase-28") && x.path.endsWith("/actual/archive.json")).path;
  const v28 = dirname(dirname(p28));
  const v30 = references.find(x => x.path.includes("phase-30") && x.path.endsWith("/verification/seal.json")).path.replace("/seal.json", "");
  for (const directory of [v28, v30, `${P32}/source`, `${P32}/verification`,
    `${ROOT}/phase31-nft-observations/verification`, `${ROOT}/recipient-flow-review-verification`,
    `${ROOT}/phase33-nft-claim-receipts/source`, `${ROOT}/phase33-nft-claim-receipts/verification`]) await sealed(directory);
  const frozenManifest = await json(`${FROZEN}/manifest.json`);
  await bind({ path: "sources.json", ...frozenManifest.files["sources.json"] }, FROZEN);
  const index = await json(`${FROZEN}/sources.json`);
  const declarations = [...index.sources, ...Object.entries(frozenManifest.files).map(([path, b]) => ({ path, ...b }))];
  for (const b of declarations) await bind(b, FROZEN);
  check(declarations.length === 36, "all frozen declarations");
  const tables = new Map();
  for (const path of ["evidence/weighted-bonds.csv", "evidence/earlier-cp-bonds.csv", "evidence/transfers.csv",
    "../2026-09-16-dtf-pre-exploit/dtf-sold-to-detf-details.csv", "conversions.csv"])
    tables.set(path, csv((await raw(resolve(FROZEN, path))).toString("utf8"), path));
  const capture = await json(`${ROOT}/weighted-bond-facet-source-capture-20261113.json`);
  const bytes = Buffer.from(capture.bodyBase64Chunks.join(""), "base64");
  check(bytes.length === 1636793 && sha(bytes) === "adb0729a4d782cef809684171914caa90e8dcc4357446dfef18741f3d7256e27", "exact decoded entity");
  const pkg = JSON.parse(new TextDecoder("utf8", { fatal: true }).decode(bytes));
  equal(await json(`${OUT}/recovered-package.json`), pkg, "lossless recovered package");
  for (const [file, member] of [["abi", "abi"], ["runtime", "runtimeBytecode"], ["creation", "creationBytecode"], ["metadata", "metadata"]])
    equal(await json(`${OUT}/${file}.json`), pkg[member], `lossless ${file}`);
  equal(Object.keys(pkg.sources).sort(), Object.keys(pkg.metadata.sources).sort(), "complete metadata source set");
  const sources = [];
  for (const [path, source] of Object.entries(pkg.sources)) {
    const b = Buffer.from(source.content);
    const hash = keccak256(b);
    equal(hash, pkg.metadata.sources[path].keccak256, `metadata Keccak ${path}`);
    equal(pkg.stdJsonInput.sources[path].content, source.content, `compiler input source ${path}`);
    sources.push({ path, bytes: b.length, sha256: sha(b), keccak256: hash, metadataKeccak256: pkg.metadata.sources[path].keccak256 });
  }
  check(sources.length === 99, "all 99 sources");
  equal(pkg.address.toLowerCase(), FACET, "facet address");
  equal(pkg.chainId, "4663", "package chain");
  for (const member of ["creationBytecode", "runtimeBytecode"]) {
    equal(pkg[member].onchainBytecode, pkg[member].recompiledBytecode, `published exact bytes ${member}`);
    equal(pkg[member].transformations, [], `no transformations ${member}`);
  }
  equal(keccak256(pkg.runtimeBytecode.onchainBytecode), "0x2676830f3b489088787c4ecc21803326a7909fbaaf9fd72994ec62b111bf62f8", "runtime Keccak");
  const abi = new Interface(pkg.abi);
  equal(abi.getFunction("bond").selector, "0x7a3b1181", "bond selector");
  equal(abi.getFunction("bond").stateMutability, "nonpayable", "bond value restriction");
  equal(pkg.metadata.output.abi, pkg.abi, "metadata ABI");
  return { pkg, abi, sources, captureIdentity: { bytes: bytes.length, sha256: sha(bytes) }, tables,
    a28: await json(p28), p28, hm28: await json(`${v28}/actual/http-manifest.json`),
    hm32: await json(`${P32}/source/http-manifest.json`),
    observed32: await json(`${P32}/source/observe-02.stdout`),
    prior: await json(`${P32}/verification/proof.json`),
    earlier: await json(`${P32}/source/reconcile-01.stdout`) };
}
