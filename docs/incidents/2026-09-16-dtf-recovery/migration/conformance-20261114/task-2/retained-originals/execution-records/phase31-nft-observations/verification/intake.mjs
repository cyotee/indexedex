import { readFile, writeFile, lstat } from "node:fs/promises";
import { createHash } from "node:crypto";
import { resolve, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import { isDeepStrictEqual } from "node:util";
import { Interface, keccak256 } from "/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-30-recovery-receipts/node_modules/ethers/lib.esm/index.js";

export const OUT = dirname(fileURLToPath(import.meta.url));
export const ROOT = "/Users/cyotee/Projects/indexedex";
export const WT = "/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-30-recovery-receipts";
export const PHASE = `${ROOT}/.omo/ulw-execute/dtf-migration`;
export const SOURCE = `${PHASE}/phase31-nft-observations/source`;
export const INPUT = `${PHASE}/phase27-frozen-input-recovery/input-tree/2026-09-16-dtf-recovery`;
export const ARCH = "/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-01/docs/incidents/2026-09-16-dtf-recovery/migration/evidence";
export const W = "0xfe4cc6d5faafdf210af4e728f4108fcaad9bb65e";
export const E = "0x15666f0b4c8d09d046d2aa9048afcaf49e8cb391";
export const GENERIC = "0xde5a691cefe1830e8ff2b65f6657738b0d9b9279";
export const FUNDED = "0x3a07364eaba092472d40f0e6788b8891a31fad4d";
export const EARLIER = "0x3ab85813785b43b864f9c171f7ac97d6b76c459b";
export const LOUPE = "0x343590ed92498739225e351c27133bc2c11b91b9";
export const DETF = "0x4a5cfdc2b07016fcf917f4ed5a51c52111a0fcc7";
export const STAKE = "0x4fa4974a8a09660258b8edd430b51c1620ebfe5c";
export const OLD = "0xaf0e1967c8f755c747615c5427108bc549ca1122";
export const ZERO = `0x${"0".repeat(40)}`;
export const sha = b => createHash("sha256").update(b).digest("hex");
export const json = async p => JSON.parse(await readFile(p, "utf8"));
export const save = (p, v) => writeFile(resolve(OUT, p), JSON.stringify(v, null, 2) + "\n", { flag: "wx" });
export class VerificationError extends Error {
  constructor(message) { super(message); this.name = "VerificationError"; }
}
export function check(ok, message) { if (!ok) throw new VerificationError(message); }
export const same = (a, b, message) => check(isDeepStrictEqual(a, b), message);
export async function identity(path) {
  const b = await readFile(path);
  return { path, bytes: b.length, sha256: sha(b) };
}
export async function bound(entry, base = "/") {
  const path = resolve(base, entry.path), actual = await identity(path);
  check(actual.bytes === entry.bytes && actual.sha256 === entry.sha256, `binding: ${path}`);
  return actual;
}
// Independent parser for these two fully quoted, single-line frozen tables.
function table(text, path) {
  const records = text.trimEnd().split(/\r?\n/).map(line => {
    const fields = [...line.matchAll(/"((?:[^"]|"")*)"(?:,|$)/g)];
    check(fields.map(x => x[0]).join("") === line, `CSV grammar: ${path}`);
    return fields.map(x => x[1].replaceAll('""', '"'));
  });
  const header = records.shift();
  check(header && new Set(header).size === header.length, `CSV header: ${path}`);
  return records.map((values, i) => {
    check(values.length === header.length, `CSV width: ${path}:${i + 2}`);
    return { locator: `${path}#row=${i + 2}`, fields: Object.fromEntries(header.map((h, j) => [h, values[j]])) };
  });
}
export async function intake() {
  const inputs = [], producer = [], sourceBindings = [];
  const seal = await json(`${SOURCE}/seal.json`);
  check(seal.status === "COMPLETE-STOPPED-BOUNDED-PRODUCER" && seal.pendingOwnedChildren === 0, "producer is not sealed/stopped");
  producer.push(await identity(`${SOURCE}/seal.json`));
  for (const entry of seal.bindings) producer.push(await bound(entry, SOURCE));
  const manifest = await json(`${SOURCE}/manifest.json`);
  for (const entry of manifest) producer.push(await bound(entry, SOURCE));
  for (const entry of await json(`${SOURCE}/source-manifest.json`)) sourceBindings.push(await bound(entry));
  const cleanup = await json(`${SOURCE}/cleanup.json`);
  check(cleanup.commands.length === 16 && cleanup.pendingOwnedChildOperations.length === 0, "producer cleanup inventory");
  for (const entry of cleanup.commands) {
    const c = await json(`${SOURCE}/${entry.path}`);
    check(c.childCloseObserved && c.exitCode === 0 && c.stoppedAt === entry.stoppedAt && c.pid === entry.pid, "producer close receipt");
    for (const stream of Object.values(c.streams)) await bound(stream);
    // The first validation predates the documented unused-import correction.
    if (!entry.path.startsWith("validate-")) for (const b of c.sourceIdentities) await bound(b);
    if (entry.path.startsWith("validate-final-")) for (const b of c.sourceIdentities) await bound(b);
  }
  const manifestInput = await json(`${INPUT}/manifest.json`);
  inputs.push(await identity(`${INPUT}/manifest.json`));
  await bound({ path: "sources.json", ...manifestInput.files["sources.json"] }, INPUT);
  const sources = await json(`${INPUT}/sources.json`);
  check(sources.chainId === 4663, "input chain");
  const declarations = [...sources.sources, ...Object.entries(manifestInput.files).map(([path, b]) => ({ path, ...b }))];
  for (const d of declarations) {
    const target = resolve(INPUT, d.path);
    check(target.startsWith(dirname(INPUT) + "/") && !(await lstat(target)).isSymbolicLink(), "frozen path");
    inputs.push(await bound(d, INPUT));
  }
  const wa = await json(`${ARCH}/weighted/probe.sources.json`);
  const ea = await json(`${ARCH}/earlier-cp/probe-alchemy-retry.source.json`);
  const contracts = { ...ea.contracts, ...wa };
  const iface = a => new Interface(contracts[a].abi);
  const code = a => contracts[a].runtimeBytecode?.onchainBytecode ?? contracts[a].onchainBytecode;
  const archivePath = sourceBindings.find(x => x.path.endsWith("/receipt-evidence/verification/actual/archive.json")).path;
  const historical = await json(archivePath);
  const reconPath = sourceBindings.find(x => x.path.endsWith("/receipt-evidence/verification/actual/reconciliation.json")).path;
  const recon = await json(reconPath), worksheet = await json(`${PHASE}/observed-recipient-flow-review-20261113.json`);
  const rows = [];
  for (const [id, collection, file] of [["S008", W, "weighted-bonds.csv"], ["S009", E, "earlier-cp-bonds.csv"]]) {
    const path = `evidence/${file}`;
    check(sources.sources.find(x => x.id === id)?.path === path, "source ID binding");
    for (const original of table(await readFile(`${INPUT}/${path}`, "utf8"), path)) {
      const f = original.fields, tokenId = f.token_id, recipient = (f.purchase_recipient ?? f.owner).toLowerCase();
      const tx = f.purchase_tx.toLowerCase(), units = f.original_principal_detf_raw ?? f.original_lp_shares_raw;
      const index = historical.results.findIndex(x => x.tx === tx), h = historical.results[index];
      check(h && h.conflicts.length === 0, `historical transaction: ${original.locator}`);
      const logs = h.receiptObservation.logs;
      const mint = logs.map((log, i) => ({ log, i })).filter(x => x.log.address === collection &&
        x.log.topics[0] === iface(GENERIC).getEvent("Transfer").topicHash && x.log.topics.length === 4 &&
        BigInt(x.log.topics[1]) === 0n && BigInt(x.log.topics[3]).toString() === tokenId);
      check(mint.length === 1 && `0x${mint[0].log.topics[2].slice(-40)}` === recipient, "historical mint");
      const eventName = collection === W ? "BondPurchased" : "NewLock", eventIface = iface(collection === W ? FUNDED : EARLIER);
      const purchase = logs.filter(x => x.address === collection && x.topics[0] === eventIface.getEvent(eventName).topicHash)
        .map(log => ({ log, parsed: eventIface.parseLog(log) })).filter(x => x.parsed.args[0].toString() === tokenId);
      check(purchase.length === 1 && purchase[0].parsed.args[1].toLowerCase() === recipient &&
        purchase[0].parsed.args[2].toString() === units, "historical purchase event");
      const review = recon.find(x => x.locator === original.locator), joined = worksheet.references.find(x => x.locator === original.locator);
      same(review.historicalFields, Object.fromEntries(Object.entries(f).sort()), "historical original fields");
      check(joined.tx === tx && joined.observedRecipient === recipient, "worksheet reference");
      rows.push({ sourceId: id, collection, tokenId, locator: original.locator, originalFields: f, recipient, units,
        mint: { archivePath, index, receiptArrayIndex: mint[0].i, log: mint[0].log, requestIds: h.requestIds },
        purchase: { eventName, log: purchase[0].log, values: Array.from(purchase[0].parsed.args, String) },
        historicalReview: review, joinedReview: joined,
        joinedRecipientFlow: worksheet.recipientFlows.filter(x => x.tx === tx && x.observedRecipient === recipient) });
    }
  }
  check(rows.length === 59 && rows.filter(x => x.collection === W).length === 43 &&
    new Set(rows.map(x => `${x.collection}:${x.tokenId}`)).size === 59, "independently derived named population");
  const parent = "0x1d38189b5f3548bc86838061f4318dbfa2f77680", staking = "0xb7581fe833a2b2380dd786b345d61ffb734d36eb";
  const erc20 = "0x1d17aca0e0717d90cea916372070a1be4652223f";
  const specs = [[W, GENERIC, ["ownerOf"]], [W, FUNDED, ["positionOf", "previewClaim", "detf"]],
    [E, GENERIC, ["ownerOf"]], [E, EARLIER, ["getPosition", "originalSharesOf", "unlockTimeOf", "pendingRewards", "lpToken", "rewardToken"]],
    [DETF, parent, ["rebasingClaimToken"]], [STAKE, staking, ["stakingState", "decimals"]],
    [DETF, erc20, ["decimals"]], [OLD, erc20, ["decimals", "balanceOf"]]]
    .flatMap(([target, facet, names]) => names.map(name => {
      const fn = iface(facet).getFunction(name);
      check(["view", "pure"].includes(fn.stateMutability), "nonview getter");
      return { target, facet, name, selector: fn.selector, abi: JSON.parse(fn.format("json")),
        archivedRuntimeHash: keccak256(code(facet)), archivedProxyHash: keccak256(code(W)) };
    }));
  return { rows, specs, iface, code, inputs, declarations, producer, sourceBindings, cleanup, seal };
}
