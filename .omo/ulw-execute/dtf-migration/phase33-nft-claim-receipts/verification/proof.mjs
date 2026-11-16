import { join } from "node:path";
import { id } from "/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-30-recovery-receipts/node_modules/ethers/lib.esm/index.js";
import { OUT, SOURCE, V28, V30, V31, ARCH, W, SD, F, SF, L, ANCHOR, intake, json, save, wires, equal, requireEvidence, canonical, sha, treeFiles } from "./evidence.mjs";
import { claimEvidence, mintEvidence, words, addressWord } from "./semantics.mjs";

const s = await intake(), a = await json(`${OUT}/archive.json`);
const verify = process.argv[2] === "--verify";
requireEvidence(process.argv[2] === undefined || verify, "proof mode");
requireEvidence(!a.blocker && a.pendingRequests === 0 && a.entries.length === 16, "complete independent stopped collection");
const ownManifest = await json(`${OUT}/http-manifest.json`), producerManifest = await json(`${SOURCE}/http-manifest.json`);
const ownWire = await wires(OUT, ownManifest), producerWire = await wires(SOURCE, producerManifest);
const priorIds = new Set([1, 2, ...s.refs.filter(x => x.priorIndex >= 0).flatMap(x => s.a30.results[x.priorIndex].requestIds)]);
const priorManifest = (await json(`${V30}/actual/http-manifest.json`)).filter(c => priorIds.has(c.id));
const priorWire = await wires(`${V30}/actual/http`, priorManifest);
const mintIds = new Set([1, 2, ...s.rows.flatMap(r => s.a28.results.find(x => x.tx === r.fields.purchase_tx).requestIds)]);
const mintWire = await wires(`${V28}/actual/http`, (await json(`${V28}/actual/http-manifest.json`)).filter(c => mintIds.has(c.id)));
const currentWire = await wires(V31, await json(`${V31}/http-manifest.json`));
const producerArchive = await json(`${SOURCE}/archive.json`), producerReview = await json(`${SOURCE}/reconciliation.json`);
const findings = [], entries = [], originals = [], routes = [];
const comparison = (actual, expected, label) => {
  try { equal(actual, expected, label); }
  catch (error) { if (!(error instanceof Error)) throw error; findings.push({ label, actual, expected }); }
};
for (const [dir, manifest] of [[OUT, ownManifest], [SOURCE, producerManifest]]) {
  const expected = manifest.flatMap(c => [c.request?.path, c.response?.path].filter(Boolean)).map(p => join(dir, p)).sort();
  equal(await treeFiles(`${dir}/http`), expected, "exact HTTP file inventory");
}
function success(wire) {
  requireEvidence(wire && !wire.capture.failure && !wire.response.error && wire.response.result != null, "successful required raw capture");
  return wire.response.result;
}
function exact(wire, method, params) {
  const matches = [...wire.values()].filter(w => w.request.method === method && JSON.stringify(w.request.params) === JSON.stringify(params));
  requireEvidence(matches.length === 1, `exact ${method} params`);
  return success(matches[0]);
}
function rawAssociation(entry, wire) {
  const t = entry.observed.transaction;
  for (const [method, params, body] of [
    ["eth_getTransactionByHash", [entry.tx], t],
    ["eth_getTransactionReceipt", [entry.tx], entry.observed.receipt],
    ["eth_getBlockByHash", [t.blockHash, false], entry.observed.byHash],
    ["eth_getBlockByNumber", [t.blockNumber, false], entry.observed.byNumber],
  ]) {
    const raw = entry.requestIds.map(i => wire.get(i)).filter(w => w?.request.method === method);
    requireEvidence(raw.length === 1, "one bound canonical method");
    equal(raw[0].request.params, params, "canonical request params");
    equal(success(raw[0]), body, "actual raw canonical body");
  }
}
for (const wire of [ownWire, priorWire, mintWire, producerWire]) {
  requireEvidence(BigInt(exact(wire, "eth_chainId", [])) === 4663n, "chain 4663");
  const anchors = [...wire.values()].filter(w => w.request.method === "eth_getBlockByNumber" && w.request.params[0] === "0x67e5d17");
  requireEvidence(anchors.length > 0, "historical anchor capture");
  for (const w of anchors) equal([success(w).number, success(w).hash], ["0x67e5d17", ANCHOR.hash], "exact historical anchor");
}
equal(a.anchor.result, a.endAnchor.result, "independent ending anchor");
equal(a.anchor.result, producerArchive.endCanonical.header, "independent/producer full anchor");
equal(ownManifest.filter(c => c.method === "eth_getTransactionByHash").map(c => c.params[0]), s.refs.filter(r => r.priorIndex < 0).map(r => r.tx), "only derived missing transactions acquired");
equal(ownManifest.filter(c => c.method === "eth_getTransactionReceipt").map(c => c.params[0]), s.refs.filter(r => r.priorIndex < 0).map(r => r.tx), "only missing receipts acquired");
equal(ownManifest.length, 67, "complete finite schedule");
let canonicalLogs = 0, mintCanonicalLogs = 0, runtimeChecks = 0, routeChecks = 0;
const producerRequestsUsed = new Set([1, 2, producerArchive.endCanonical.requestId]);
for (const ref of s.refs) {
  const old = ref.priorIndex >= 0;
  const e = old ? s.a30.results[ref.priorIndex] : a.entries.find(x => x.tx === ref.tx);
  rawAssociation(e, old ? priorWire : ownWire);
  canonicalLogs += canonical(ref.tx, e.observed);
  const source = producerArchive.results.find(x => x.tx === ref.tx);
  comparison(source.observed, e.observed, `complete independently observed ${ref.tx}`);
  if (old) comparison(source.provenance, { kind: "accepted-reuse-no-new-receipt-call", archive: `${V30}/actual/archive.json`,
    resultIndex: ref.priorIndex, previousReferences: e.references, requestIds: e.requestIds,
    httpManifest: `${V30}/actual/http-manifest.json`, rawDirectory: `${V30}/actual/http` }, `exact prior provenance ${ref.tx}`);
  else rawAssociation({ ...source, requestIds: source.provenance.requestIds }, producerWire);
  if (!old) for (const i of source.provenance.requestIds) producerRequestsUsed.add(i);
  if (!old) {
    equal(await json(`${OUT}/${ref.tx}.json`), e, "independent standalone capture");
    equal(await json(`${SOURCE}/${ref.tx}.json`), source, "producer standalone capture");
  }
  const data = claimEvidence(ref, e.observed);
  data.capture = old ? { kind: "accepted-phase30-reuse-not-new-call", archive: `${V30}/actual/archive.json`, resultIndex: ref.priorIndex,
    requestIds: e.requestIds, previousReferences: e.references, rawRoot: `${V30}/actual/http` }
    : { kind: "independent-live", archive: "archive.json", requestIds: e.requestIds, rawRoot: OUT };
  const sourceRow = producerReview.entries.find(x => x.tx === ref.tx);
  for (const [key, value] of [["principal", data.principal], ["rewards", data.rewards], ["actualClaimRecipient", data.recipient], ["payoutTotal", data.total]]) comparison(sourceRow[key], value, `${ref.tx} ${key}`);
  for (const [key, list] of [["claims", [data.claim]], ["payoutMatches", data.payouts], ["retirements", data.retirements]]) {
    comparison(sourceRow[key].map(x => ({ receiptArrayIndex: x.receiptArrayIndex, log: x.log })), list.map(x => ({ receiptArrayIndex: x.receiptArrayIndex, log: x.log })), `${ref.tx} ${key} exact logs`);
  }
  comparison(sourceRow.allNative9Transfers.map(x => ({ log: x.log, receiptArrayIndex: x.receiptArrayIndex, from: x.from, to: x.to, amount: x.amount, decimals: x.decimals })),
    data.native9Transfers.map(x => ({ log: x.log, receiptArrayIndex: x.receiptArrayIndex, from: x.from, to: x.to, amount: x.amount, decimals: x.decimals })), `${ref.tx} all native9 outputs`);
  const tag = e.observed.transaction.blockNumber;
  const binding = { tx: ref.tx, tag, blockHash: e.observed.transaction.blockHash, runtime: [], selectors: [] };
  for (const address of [W, F, L, SD, SF]) {
    const runtime = exact(producerWire, "eth_getCode", [address, tag]), deployed = s.contracts[address];
    equal(runtime, deployed.runtimeBytecode?.onchainBytecode ?? deployed.onchainBytecode, "actual historical runtime");
    requireEvidence(runtime !== "0x", "nonempty runtime");
    binding.runtime.push({ address, sha256: sha(Buffer.from(runtime.slice(2), "hex")) }); runtimeChecks++;
  }
  const selectors = [
    [W, "claimBond(uint256,address)", F], [W, "claimPrincipal(uint256,address)", F], [W, "claimRewards(uint256,address)", F],
    [W, "facetAddress(bytes4)", L], [SD, "transfer(address,uint256)", SF], [SD, "decimals()", SF], [SD, "facetAddress(bytes4)", L],
  ];
  for (const [proxy, signature, facet] of selectors) {
    const selector = id(signature).slice(0, 10), data = `0xcdffacc6${selector.slice(2).padEnd(64, "0")}`;
    equal(exact(producerWire, "eth_call", [{ to: proxy, data }, tag]), `0x${facet.slice(2).padStart(64, "0")}`, "actual historical facet routing");
    binding.selectors.push({ proxy, signature, selector, facet }); routeChecks++;
  }
  for (const c of producerManifest.filter(c => ["eth_getCode", "eth_call"].includes(c.method) && c.params.at(-1) === tag)) producerRequestsUsed.add(c.id);
  routes.push(binding); entries.push(data);
}
equal([...producerRequestsUsed].sort((a,b)=>a-b), [...producerWire.keys()].sort((a,b)=>a-b), "all producer raw requests accounted");
for (const row of s.rows) {
  const f = row.fields, claims = entries.filter(c => c.locator === row.locator);
  const sum = key => claims.reduce((n, x) => n + BigInt(x[key]), 0n).toString();
  const purchaseIndex = s.a28.results.findIndex(x => x.tx === f.purchase_tx), purchase = s.a28.results[purchaseIndex];
  rawAssociation(purchase, mintWire); mintCanonicalLogs += canonical(purchase.tx, purchase.observed);
  const mint = { ...mintEvidence(row, purchase), archive: `${V28}/actual/archive.json`, resultIndex: purchaseIndex };
  for (const e of producerReview.entries.filter(x => x.locator === row.locator)) {
    comparison(e.historicalMint.resultIndex, purchaseIndex, `${e.tx} mint archive index`);
    comparison(e.historicalMint.mint, { log: mint.mint.log, receiptArrayIndex: mint.mint.receiptArrayIndex }, `${e.tx} complete mint locator`);
    comparison(e.historicalMint.purchase, { log: mint.purchase.log, receiptArrayIndex: mint.purchase.receiptArrayIndex }, `${e.tx} complete purchase locator`);
  }
  const c = s.current.rows.find(x => x.locator === row.locator);
  equal(c.originalFields, f, "current record original fields");
  const positionRead = c.observations.positionOf, ownerRead = c.observations.ownerOf;
  const raw = currentWire.get(positionRead.requestId);
  equal(raw.request.params, [{ to: W, data: `0x46f96023${BigInt(f.token_id).toString(16).padStart(64, "0")}` }, "0x6c0835d"], "current position exact numeric-pin request");
  let currentPosition = null, currentRemaining = null, currentClaimed = null;
  if (raw.response.error) {
    equal(raw.response.error, { code: 3, message: "execution reverted", data: `0x7e273289${BigInt(f.token_id).toString(16).padStart(64, "0")}` }, "exact absent-ID error");
    requireEvidence(["25", "42"].includes(f.token_id), "only recognized absences");
    equal(positionRead.status, "failure", "retained RPC error disposition");
  } else {
    const vals = words(success(raw), 5);
    currentPosition = Object.fromEntries(["principal", "claimedPrincipal", "stakingGons", "startTimestamp", "vestingDuration"].map((k,i) => [k, vals[i]]));
    equal(currentPosition, positionRead.value, "independently decoded current position");
    equal(currentPosition.principal, f.original_principal_detf_raw, "current principal equals historical basis");
    requireEvidence(BigInt(currentPosition.claimedPrincipal) <= BigInt(currentPosition.principal), "principal bounds");
    currentClaimed = currentPosition.claimedPrincipal;
    currentRemaining = (BigInt(currentPosition.principal) - BigInt(currentClaimed)).toString();
  }
  const ownerWire = currentWire.get(ownerRead.requestId), previewRead = c.observations.previewClaim;
  equal(ownerWire.request.params, [{ to: W, data: `0x6352211e${BigInt(f.token_id).toString(16).padStart(64, "0")}` }, "0x6c0835d"], "owner exact pin request");
  equal(addressWord(success(ownerWire)), ownerRead.value, "actual current owner");
  const previewWire = currentWire.get(previewRead.requestId);
  equal(previewWire.request.params, [{ to: W, data: `0xae648e90${BigInt(f.token_id).toString(16).padStart(64, "0")}` }, "0x6c0835d"], "preview exact pin request");
  if (currentPosition === null) {
    equal(previewWire.response.error, raw.response.error, "same exact absent preview error");
    equal([positionRead.value, previewRead.value], [null, null], "unavailable fields remain unknown");
  } else {
    equal(words(success(previewWire), 4), ["vestedPrincipal", "principalRemaining", "principalDue", "rewardsDue"].map(k => previewRead.value[k]), "actual current preview");
  }
  const p = sum("principal"), r = sum("rewards"), producer = producerReview.originals.find(x => x.locator === row.locator);
  const differences = { frozenMinusNamedPrincipal: (BigInt(f.claimed_principal_detf_raw) - BigInt(p)).toString(),
    frozenMinusNamedRewards: (BigInt(f.rewards_claimed_sdetf_raw) - BigInt(r)).toString(),
    currentMinusFrozenPrincipal: currentClaimed === null ? null : (BigInt(currentClaimed) - BigInt(f.claimed_principal_detf_raw)).toString(),
    currentMinusNamedPrincipal: currentClaimed === null ? null : (BigInt(currentClaimed) - BigInt(p)).toString() };
  for (const [k,v] of Object.entries({ ...differences, namedPrincipal: p, namedRewards: r, currentClaimedPrincipal: currentClaimed, currentRemainingPrincipal: currentRemaining })) comparison(producer[k], v, `${row.locator} ${k}`);
  for (const k of ["currentCumulativeRewards", "originalPayer", "E0", "D0", "eligibility", "priorMigrationCompensation", "C0", "deduction"]) comparison(producer[k], null, `${row.locator} unknown ${k}`);
  originals.push({ ...row, collection: W, tokenId: f.token_id, mint, namedClaims: claims.length, namedPrincipal: p, namedRewards: r, differences,
    currentPin: "113279837", currentOwner: ownerRead, currentPosition, currentPositionRead: positionRead, currentPositionWire: raw,
    currentClaimedPrincipal: currentClaimed, currentRemainingPrincipal: currentRemaining, currentCumulativeRewards: null,
    originalEconomicPayer: null, E0: null, D0: null, C0: null, priorMigrationCompensation: null, eligibility: null, compensationDeduction: null,
    historicalFlags: c.joinedReview?.flags ?? [], historyCensus: false, currentDescendantControl: null });
}
const schema = await json(`${SOURCE}/schema-bindings.json`);
for (const x of schema.sources) {
  equal(x.content, s.weighted[x.contract].sources[x.path].content, "unescaped actual deployed source");
  equal(sha(Buffer.from(x.content)), x.contentSha256, "source content hash");
}
equal(schema.abi, s.weighted[F].abi, "exact claim ABI");
equal(schema.payoutAbi, s.weighted[SF].abi, "exact payout ABI");
const schemaProof = { sourceArchive: `${ARCH}/weighted/probe.sources.json`, sources: schema.sources, abi: schema.abi, payoutAbi: schema.payoutAbi, routes,
  meaning: "Actual event words are P/R. P+R is transferred before claim emission. ClaimedPrincipal starts zero and only increases on this inspected lifecycle; retirement deletes it. End-block selected routes do not authenticate a transaction prefix or all historical transitions." };
const totals = { principal: entries.reduce((n,x)=>n+BigInt(x.principal),0n).toString(), rewards: entries.reduce((n,x)=>n+BigInt(x.rewards),0n).toString(), payout: entries.reduce((n,x)=>n+BigInt(x.total),0n).toString() };
const proof = { verdict: findings.length ? "needs-fix" : "confirmed", findings, references: s.refs, entries, originals, totals,
  counts: { references: entries.length, originals: originals.length, newReceipts: a.entries.length, reusedReceipts: s.refs.filter(r=>r.priorIndex>=0).length,
    ownRequests: ownManifest.length, producerRequests: producerManifest.length, priorRequests: priorWire.size, mintRequests: mintWire.size,
    canonicalLogs, mintCanonicalLogs, runtimeChecks, routeChecks, rewardOnly: entries.filter(e=>e.principal==="0" && e.rewards!=="0").length },
  independentLive: true, providerConsensus: false, allHistoryCensus: false, financialAuthority: false, pendingOperations: 0 };
if (verify) {
  equal(await json(`${OUT}/schema-proof.json`), schemaProof, "published schema proof reproducibility");
  equal(await json(`${OUT}/proof.json`), proof, "published all-record proof reproducibility");
} else {
  await save("schema-proof.json", schemaProof);
  await save("proof.json", proof);
}
console.log(JSON.stringify({ verdict: proof.verdict, counts: proof.counts, totals, findings }));
