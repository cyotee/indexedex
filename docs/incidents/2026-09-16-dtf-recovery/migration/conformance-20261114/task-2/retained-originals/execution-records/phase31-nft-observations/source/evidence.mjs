import { readFile, readdir, writeFile } from "node:fs/promises";
import { createHash } from "node:crypto";
import { join, resolve, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import { Interface } from "/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-30-recovery-receipts/node_modules/ethers/lib.esm/index.js";
import { loadCandidateInput, table } from "/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-30-recovery-receipts/scripts/recovery/dtf-migration/candidate-input.ts";

export const ROOT = "/Users/cyotee/Projects/indexedex";
export const WT = "/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-30-recovery-receipts";
export const OUT = dirname(fileURLToPath(import.meta.url));
export const INPUT = `${ROOT}/.omo/ulw-execute/dtf-migration/phase27-frozen-input-recovery/input-tree/2026-09-16-dtf-recovery`;
export const PHASE = `${ROOT}/.omo/ulw-execute/dtf-migration`;
export const ARCH = "/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-01/docs/incidents/2026-09-16-dtf-recovery/migration/evidence";
export const V28 = "/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-28-receipt-evidence/docs/incidents/2026-09-16-dtf-recovery/migration/receipt-evidence/verification";
export const V30 = `${WT}/docs/incidents/2026-09-16-dtf-recovery/migration/recovery-receipts/verification`;
export const W = "0xfe4cc6d5faafdf210af4e728f4108fcaad9bb65e";
export const E = "0x15666f0b4c8d09d046d2aa9048afcaf49e8cb391";
export const ZERO = `0x${"0".repeat(40)}`;
export const GENERIC = "0xde5a691cefe1830e8ff2b65f6657738b0d9b9279";
export const FUNDED = "0x3a07364eaba092472d40f0e6788b8891a31fad4d";
export const EARLIER = "0x3ab85813785b43b864f9c171f7ac97d6b76c459b";
export const LOUPE = "0x343590ed92498739225e351c27133bc2c11b91b9";
export const sha = (bytes) => createHash("sha256").update(bytes).digest("hex");
export class EvidenceError extends Error {
  constructor(message) { super(message); this.name = "EvidenceError"; }
}
export function requireFact(ok, message) { if (!ok) throw new EvidenceError(message); }
export const json = async (path) => JSON.parse(await readFile(path, "utf8"));
export const identity = async (path) => {
  const b = await readFile(path);
  return { path, bytes: b.length, sha256: sha(b) };
};
export const save = (name, value) => writeFile(join(OUT, name),
  `${JSON.stringify(value, null, 2)}\n`, { flag: "wx" });

export async function intake() {
  const input = await loadCandidateInput(INPUT);
  const bindings = [];
  const bind = async (path, expected) => {
    const actual = await identity(path);
    if (expected) requireFact(actual.sha256 === expected.sha256 && actual.bytes === expected.bytes, `binding mismatch: ${path}`);
    bindings.push(actual);
    return path.endsWith(".json") ? json(path) : null;
  };
  const head = (await readFile(`${ROOT}/.git/packed-refs`, "utf8")).split("\n");
  requireFact(head.includes("1694e68a4bd66dd67d3b5e3f145f1da23074ff48 refs/heads/work/dtf-migration-phase-30-recovery-receipts"), "cumulative reference mismatch");
  requireFact((await readFile(`${ROOT}/.git/worktrees/dtf-migration-phase-30-recovery-receipts/HEAD`, "utf8")).trim() ===
    "ref: refs/heads/work/dtf-migration-phase-30-recovery-receipts", "worktree HEAD reference mismatch");
  const worksheet = await bind(`${PHASE}/observed-recipient-flow-review-20261113.json`,
    { bytes: 902872, sha256: "ed8474ac3454453697308ce82adffebb8bbfe9d346050973e0753a46cf6af39e" });
  for (const dir of [V28, V30, `${PHASE}/recipient-flow-review-verification`]) {
    const seal = await bind(`${dir}/seal.json`);
    const entries = Object.values(seal).filter(x => x && typeof x === "object" && typeof x.path === "string");
    for (const entry of [...entries, ...(seal.bindings ?? [])]) await bind(resolve(dir, entry.path), entry);
  }
  const a28 = await bind(`${V28}/actual/archive.json`, { bytes: 3848804, sha256: worksheet.sourceIdentities.archive28 });
  const r28 = await bind(`${V28}/actual/reconciliation.json`, { bytes: 251139, sha256: worksheet.sourceIdentities.recon28 });
  await bind(`${V30}/actual/archive.json`, { bytes: 5917231, sha256: worksheet.sourceIdentities.archive30 });
  await bind(`${V30}/actual/reconciliation.json`, { bytes: 841408, sha256: worksheet.sourceIdentities.recon30 });
  const wa = await bind(`${ARCH}/weighted/probe.sources.json`);
  const ea = await bind(`${ARCH}/earlier-cp/probe-alchemy-retry.source.json`);
  const wr = await bind(`${ARCH}/weighted/probe.results.json`);
  for (const path of ["weighted/report.md", "earlier-cp/report.md"]) bindings.push(await identity(`${ARCH}/${path}`));
  for (const name of await readdir(`${WT}/scripts/recovery/dtf-migration`)) {
    if (name.endsWith(".ts")) bindings.push(await identity(`${WT}/scripts/recovery/dtf-migration/${name}`));
  }
  for (const name of ["IMigrationLegacyNft.sol", "MigrationLegacyNftLib.sol"]) {
    bindings.push(await identity(`${WT}/contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/legacy/${name}`));
  }
  for (const name of ["MIGRATION_DETF_IMPLEMENTATION_AND_TEST_PLAN.md", "MIGRATION_DETF_DRAFT_PRD.md"]) {
    const rel = `docs/incidents/2026-09-16-dtf-recovery/${name}`;
    bindings.push(await identity(`${ROOT}/${rel}`));
  }
  bindings.push(await identity(`${WT}/foundry.toml`), await identity(`${PHASE}/phase31-nft-observations-brief.md`));
  const contracts = { ...ea.contracts, ...wa };
  const abiAt = (address) => new Interface(contracts[address.toLowerCase()].abi);
  const codeAt = (address) => {
    const c = contracts[address.toLowerCase()];
    return c.runtimeBytecode?.onchainBytecode ?? c.onchainBytecode;
  };
  const populations = [["S008", "evidence/weighted-bonds.csv", W], ["S009", "evidence/earlier-cp-bonds.csv", E]];
  const rows = [];
  for (const [sourceId, path, collection] of populations) {
    requireFact(input.sources.sources.find(x => x.id === sourceId)?.path === path, `source declaration differs: ${sourceId}`);
    const originals = table(input, path);
    for (const original of originals) {
      const f = original.fields, tokenId = f.token_id, tx = f.purchase_tx.toLowerCase();
      const recipient = (f.purchase_recipient ?? f.owner).toLowerCase();
      const resultIndex = a28.results.findIndex(x => x.tx === tx);
      const archived = a28.results[resultIndex];
      requireFact(archived?.conflicts.length === 0, `historical association missing: ${original.locator}`);
      const logs = archived.receiptObservation.logs;
      const transfer = new Interface(wa[GENERIC].abi);
      const mints = logs.map((log, index) => ({ log, index })).filter(({ log }) =>
        log.address === collection && log.topics[0] === transfer.getEvent("Transfer").topicHash &&
        log.topics.length === 4 && BigInt(log.topics[1]) === 0n && BigInt(log.topics[3]).toString() === tokenId);
      requireFact(mints.length === 1 && `0x${mints[0].log.topics[2].slice(-40)}` === recipient, `mint mismatch: ${original.locator}`);
      const eventAbi = abiAt(collection === W ? FUNDED : EARLIER);
      const eventName = collection === W ? "BondPurchased" : "NewLock";
      const events = logs.filter(log => log.address === collection && log.topics[0] === eventAbi.getEvent(eventName).topicHash)
        .map(log => ({ log, parsed: eventAbi.parseLog(log) })).filter(x => x.parsed.args[0].toString() === tokenId);
      requireFact(events.length === 1 && events[0].parsed.args[1].toLowerCase() === recipient, `purchase event mismatch: ${original.locator}`);
      const originalUnits = f.original_principal_detf_raw ?? f.original_lp_shares_raw;
      requireFact(events[0].parsed.args[2].toString() === originalUnits, `purchase units mismatch: ${original.locator}`);
      const prior = r28.find(x => x.locator === original.locator);
      requireFact(JSON.stringify(prior.historicalFields) === JSON.stringify(Object.fromEntries(Object.entries(f).sort())),
        `archived original fields mismatch: ${original.locator}`);
      const joined = worksheet.references.find(x => x.locator === original.locator);
      requireFact(joined?.tx === tx && joined.observedRecipient === recipient, `worksheet join mismatch: ${original.locator}`);
      rows.push({ sourceId, collection, tokenId, locator: original.locator, originalFields: f,
        historicalMint: { recipient, transaction: tx, originalUnits, archive: `${V28}/actual/archive.json`,
          resultIndex, receiptArrayIndex: mints[0].index, log: mints[0].log,
          purchaseEvent: { name: eventName, log: events[0].log, values: Array.from(events[0].parsed.args, String) },
          requestIds: archived.requestIds },
        historicalReview: prior, joinedReview: joined,
        joinedRecipientFlow: worksheet.recipientFlows.filter(x => x.tx === tx && x.observedRecipient === recipient),
        eligibility: "unreviewed", originalWalletAuthority: "not-approved-by-mint-or-owner-match",
        E0: null, D0: null, priorCompensation: null, C0: null, credit: null });
    }
  }
  requireFact(rows.filter(x => x.collection === W).length === 43 && rows.filter(x => x.collection === E).length === 16, "named population mismatch");
  requireFact(new Set(rows.map(x => `${x.collection}:${x.tokenId}`)).size === rows.length, "duplicate named identity");
  return { rows, bindings, input, wa, ea, wr, contracts, abiAt, codeAt };
}
