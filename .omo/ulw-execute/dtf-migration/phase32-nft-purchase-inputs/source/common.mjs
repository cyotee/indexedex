import { readFile } from "node:fs/promises";
import { createHash } from "node:crypto";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { isDeepStrictEqual } from "node:util";
import { Interface, keccak256 } from "/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-30-recovery-receipts/node_modules/ethers/lib.esm/index.js";
import { loadCandidateInput, table } from "/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-30-recovery-receipts/scripts/recovery/dtf-migration/candidate-input.ts";

export { Interface, keccak256, loadCandidateInput, table };
export const OUT = dirname(fileURLToPath(import.meta.url));
export const ROOT = "/Users/cyotee/Projects/indexedex";
export const WT = "/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-30-recovery-receipts";
export const PHASE = `${ROOT}/.omo/ulw-execute/dtf-migration`;
export const INPUT = `${PHASE}/phase27-frozen-input-recovery/input-tree/2026-09-16-dtf-recovery`;
export const ARCH = "/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-01/docs/incidents/2026-09-16-dtf-recovery/migration/evidence";
export const V28 = "/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-28-receipt-evidence/docs/incidents/2026-09-16-dtf-recovery/migration/receipt-evidence/verification";
export const V30 = `${WT}/docs/incidents/2026-09-16-dtf-recovery/migration/recovery-receipts/verification`;
export const V31 = `${PHASE}/phase31-nft-observations/verification`;
export const W = "0xfe4cc6d5faafdf210af4e728f4108fcaad9bb65e";
export const E = "0x15666f0b4c8d09d046d2aa9048afcaf49e8cb391";
export const WD = "0x4a5cfdc2b07016fcf917f4ed5a51c52111a0fcc7";
export const ED = "0xaf0e1967c8f755c747615c5427108bc549ca1122";
export const DTF = "0xee5576fa1bcaa380e591d01245f406f3f384eb01";
export const WETH = "0x0bd7d308f8e1639fab988df18a8011f41eacad73";
export const CORE = "0x8333749cc7b1f66b5be568257d362aa749497cf0";
export const LOUPE = "0x343590ed92498739225e351c27133bc2c11b91b9";
export const ZERO = `0x${"0".repeat(40)}`;
export const TRANSFER = "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef";
export const sha = bytes => createHash("sha256").update(bytes).digest("hex");
export const json = async path => JSON.parse(await readFile(path, "utf8"));
export const text = value => `${JSON.stringify(value, null, 2)}\n`;
export class EvidenceError extends Error {
  constructor(message) { super(message); this.name = "EvidenceError"; }
}
export function fact(condition, message) {
  if (!condition) throw new EvidenceError(message);
}
export async function identity(path) {
  const bytes = await readFile(path);
  return { path, bytes: bytes.length, sha256: sha(bytes) };
}
export async function authenticated(binding, directory = OUT) {
  const path = resolve(directory, binding.path);
  const actual = await identity(path);
  fact(actual.bytes === binding.bytes && actual.sha256 === binding.sha256, `binding: ${path}`);
  return actual;
}
export const addressWord = value => {
  fact(/^0x0{24}[0-9a-fA-F]{40}$/.test(value), "invalid ABI address word");
  return `0x${value.slice(-40)}`.toLowerCase();
};
export const loupe = new Interface(["function facetAddress(bytes4) view returns(address)"]);
export const bond = new Interface(["function bond(address,uint256,uint256,address,bool,uint256) returns(uint256,uint256)"]);

export async function intake() {
  const input = await loadCandidateInput(INPUT);
  const bindings = [];
  const bind = async path => { bindings.push(await identity(path)); return json(path); };
  const evidenceDirectories = [V28, V30, V31, `${PHASE}/recipient-flow-review-verification`];
  for (const directory of evidenceDirectories) {
    const seal = await bind(`${directory}/seal.json`);
    const manifestBinding = seal.manifest ?? seal.bindings?.find(x => x.path === "manifest.json");
    fact(manifestBinding?.path, `missing seal manifest: ${directory}`);
    await authenticated(manifestBinding, directory);
    const manifest = await bind(resolve(directory, manifestBinding.path));
    const entries = Array.isArray(manifest) ? manifest : manifest.files ?? manifest.entries;
    fact(Array.isArray(entries), `manifest shape: ${directory}`);
    for (const entry of entries) await authenticated(entry, directory);
    bindings.push(await identity(`${directory}/report.md`));
  }
  const worksheet = await bind(`${PHASE}/observed-recipient-flow-review-20261113.json`);
  fact(bindings.at(-1).sha256 === "ed8474ac3454453697308ce82adffebb8bbfe9d346050973e0753a46cf6af39e", "worksheet identity");
  const a28 = await bind(`${V28}/actual/archive.json`);
  const r28 = await bind(`${V28}/actual/reconciliation.json`);
  const a30 = await bind(`${V30}/actual/archive.json`);
  const r30 = await bind(`${V30}/actual/reconciliation.json`);
  for (const [name, file] of [["archive28", `${V28}/actual/archive.json`], ["recon28", `${V28}/actual/reconciliation.json`],
    ["archive30", `${V30}/actual/archive.json`], ["recon30", `${V30}/actual/reconciliation.json`]]) {
    fact((await identity(file)).sha256 === worksheet.sourceIdentities[name], `worksheet source: ${name}`);
  }
  const wa = await bind(`${ARCH}/weighted/probe.sources.json`);
  const ea = await bind(`${ARCH}/earlier-cp/probe-alchemy-retry.source.json`);
  const state = await bind(`${V31}/observations.json`);
  const p27 = "/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-27-data-candidates/docs/incidents/2026-09-16-dtf-recovery/migration/data-candidates";
  for (const path of [
    `${p27}/implementation-r2/report.md`, `${p27}/verification-r2/report.md`,
    `${p27}/implementation-r2/seal.json`, `${p27}/verification-r2/seal.json`,
    `${PHASE}/phase27-frozen-input-recovery/recovery.json`, `${PHASE}/phase27-frozen-input-recovery/validation.json`,
    `${ARCH}/weighted/probe.results.json`, `${ARCH}/weighted/report.md`, `${ARCH}/earlier-cp/report.md`,
    `${ROOT}/docs/incidents/2026-09-16-dtf-recovery/ENTITLEMENT_LEDGER_PROVENANCE.md`,
    `${ROOT}/docs/incidents/2026-09-16-dtf-recovery/MIGRATION_DETF_IMPLEMENTATION_AND_TEST_PLAN.md`,
    `${ROOT}/docs/incidents/2026-09-16-dtf-recovery/MIGRATION_DETF_DRAFT_PRD.md`,
    `${PHASE}/phase32-nft-purchase-inputs-brief.md`, `${WT}/foundry.toml`,
    `${WT}/scripts/recovery/dtf-migration/candidate-input.ts`,
    `${WT}/scripts/recovery/dtf-migration/candidate-nfts.ts`,
  ]) bindings.push(await identity(path));
  const rows = [];
  for (const [sourceId, path, collection, parent] of [
    ["S008", "evidence/weighted-bonds.csv", W, WD], ["S009", "evidence/earlier-cp-bonds.csv", E, ED],
  ]) {
    fact(input.sources.sources.find(x => x.id === sourceId)?.path === path, `source: ${sourceId}`);
    for (const original of table(input, path)) {
      const f = original.fields, recipient = (f.purchase_recipient ?? f.owner).toLowerCase();
      const resultIndex = a28.results.findIndex(x => x.tx === f.purchase_tx.toLowerCase());
      const result = a28.results[resultIndex];
      fact(result && result.conflicts.length === 0, `canonical purchase: ${original.locator}`);
      const review = r28.find(x => x.locator === original.locator);
      fact(isDeepStrictEqual(review.historicalFields, f), `original fields: ${original.locator}`);
      const mint = result.receiptObservation.logs.map((log, offset) => ({ log, offset })).filter(({ log }) =>
        log.address === collection && log.topics[0] === TRANSFER && log.topics.length === 4 &&
        BigInt(log.topics[1]) === 0n && BigInt(log.topics[3]).toString() === f.token_id);
      fact(mint.length === 1 && addressWord(mint[0].log.topics[2]) === recipient, `mint: ${original.locator}`);
      const tx = result.transactionObservation;
      const direct = tx.to === parent && tx.from === recipient && tx.input.slice(0, 10) === "0x7a3b1181";
      const decoded = direct ? bond.decodeFunctionData("bond", tx.input) : null;
      if (decoded) {
        fact(bond.encodeFunctionData("bond", decoded).toLowerCase() === tx.input, `reencode: ${original.locator}`);
        fact((decoded[3].toLowerCase() === recipient || decoded[3].toLowerCase() === ZERO) &&
          decoded[4] === false && tx.value === "0x0", `direct call: ${original.locator}`);
      }
      rows.push({ sourceId, original, collection, parent, recipient, resultIndex, result, review, mint: mint[0], direct,
        decoded: decoded ? { tokenIn: decoded[0].toLowerCase(), amountIn: decoded[1].toString(),
          lockDuration: decoded[2].toString(), recipient: decoded[3].toLowerCase(), pretransferred: decoded[4],
          deadline: decoded[5].toString() } : null });
    }
  }
  fact(rows.length === 59 && rows.filter(x => x.direct).length === 55, "purchase population");
  return { input, bindings, worksheet, a28, r28, a30, r30, wa, ea, state, rows };
}
