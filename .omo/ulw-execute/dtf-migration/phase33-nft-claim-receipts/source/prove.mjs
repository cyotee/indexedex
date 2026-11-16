import { join } from "node:path";
import { id, Interface } from "/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-30-recovery-receipts/node_modules/ethers/lib.esm/index.js";
import { intake, OUT, W, SD, F, L, V30, V31, check, json, save, sha } from "./inputs.mjs";
import { rawHttp, canonical, csv, equal, checkHttpFiles } from "./raw.mjs";

const s = await intake(), a = await json(join(OUT, "archive.json"));
const review = await json(join(OUT, "reconciliation.json")), captures = await json(join(OUT, "http-manifest.json"));
const wire = await rawHttp(OUT, captures);
await checkHttpFiles(OUT, captures);
const priorManifest = await json(`${V30}/actual/http-manifest.json`);
const neededPrior = new Set([1, 2, ...s.refs.filter(r => r.priorIndex >= 0).flatMap(r => s.old30.results[r.priorIndex].requestIds)]);
const priorWire = await rawHttp(`${V30}/actual/http`, priorManifest.filter(c => neededPrior.has(c.id)));
const rows = csv(new TextDecoder("utf-8", { fatal: true }).decode(s.input.bytes.get("evidence/weighted-bonds.csv")));
const refs = rows.flatMap(r => r.fields.claim_transactions ? r.fields.claim_transactions.split("|")
  .map((tx, i) => ({ locator: r.locator, tx, tokenId: r.fields.token_id, occurrence: i + 1 })) : []);
check(rows.length === 43 && refs.length === 23 && new Set(refs.map(r => r.tx)).size === 23, "independent complete S008 population");
equal(refs, review.entries.map(e => ({ locator: e.locator, tx: e.tx, tokenId: e.tokenId, occurrence: e.occurrence })), "all 23 occurrences");
const used = new Set(), usedPrior = new Set(), proofRows = [];
const take = (id, old = false) => {
  const w = (old ? priorWire : wire).get(id);
  check(w && !w.failure, `required raw request ${id}`);
  (old ? usedPrior : used).add(id);
  return w;
};
const exact = (method, params) => {
  const matches = [...wire.values()].filter(w => w.request.method === method && JSON.stringify(w.request.params) === JSON.stringify(params));
  check(matches.length === 1, `unique ${method} request`);
  used.add(matches[0].capture.id);
  check(!matches[0].failure, `successful ${method}`);
  return matches[0].value;
};
const chain = take(1), anchor = take(2);
check(chain.request.method === "eth_chainId" && BigInt(chain.value) === 4663n, "live chain authentication");
equal(anchor.request.params, ["0x67e5d17", false], "historical anchor request");
check(BigInt(anchor.value.number) === 108944663n
  && anchor.value.hash === "0xc497433dd691a40cb85959cfeba2e3fff85a975ae060612d984998e1d5765733", "historical anchor");
check(BigInt(take(1, true).value) === 4663n && take(2, true).value.hash === anchor.value.hash, "prior accepted chain and anchor");
equal(a.endCanonical.header, anchor.value, "ending entire anchor header");
used.add(a.endCanonical.requestId);
equal(take(a.endCanonical.requestId).value, anchor.value, "ending raw header");
const topic = id("BondClaimed(uint256,address,uint256,uint256)"), transfer = id("Transfer(address,address,uint256)");
const address = t => `0x${t.slice(-40)}`;
const SF = "0xb7581fe833a2b2380dd786b345d61ffb734d36eb", contractAbi = new Interface(s.wa[F].abi), stakingAbi = new Interface(s.wa[SF].abi);
let logCount = 0;
for (const ref of refs) {
  const priorIndex = s.old30.results.findIndex(r => r.tx === ref.tx), old = priorIndex >= 0;
  const selected = old ? s.old30.results[priorIndex] : a.results.find(r => r.tx === ref.tx);
  const o = selected.observed;
  check(o && selected.conflicts.length === 0, `canonical named receipt ${ref.tx}`);
  logCount += canonical(ref.tx, o);
  const provenance = old ? selected.requestIds : selected.provenance.requestIds;
  const raws = provenance.map(i => take(i, old));
  for (const [method, object] of [["eth_getTransactionByHash", o.transaction], ["eth_getTransactionReceipt", o.receipt],
    ["eth_getBlockByHash", o.byHash], ["eth_getBlockByNumber", o.byNumber]]) {
    const found = raws.filter(w => w.request.method === method);
    check(found.length === 1, "required canonical raw method");
    equal(found[0].value, object, "raw to canonical observation");
    const params = method === "eth_getTransactionByHash" || method === "eth_getTransactionReceipt" ? [ref.tx]
      : method === "eth_getBlockByHash" ? [o.transaction.blockHash, false] : [o.transaction.blockNumber, false];
    equal(found[0].request.params, params, "exact canonical request parameters");
  }
  const combined = a.results.find(r => r.tx === ref.tx);
  equal(combined.observed, o, "combined prior/new observation");
  check(combined.capture === (old ? "reused-phase30" : "new"), "capture provenance");
  const tag = o.transaction.blockNumber;
  for (const address of [W, F, L, SD, SF]) {
    const code = exact("eth_getCode", [address, tag]), source = s.contracts[address];
    equal(code, source.runtimeBytecode?.onchainBytecode ?? source.onchainBytecode, "historical runtime exact archived bytes");
  }
  const routes = [
    ...["claimBond", "claimPrincipal", "claimRewards"].map(n => [W, contractAbi.getFunction(n).selector, F]),
    [W, "0xcdffacc6", L], [SD, stakingAbi.getFunction("transfer").selector, SF],
    [SD, stakingAbi.getFunction("decimals").selector, SF], [SD, "0xcdffacc6", L],
  ];
  for (const [proxy, selector, facet] of routes) {
    const data = `0xcdffacc6${selector.slice(2).padEnd(64, "0")}`;
    equal(exact("eth_call", [{ to: proxy, data }, tag]), `0x${facet.slice(2).padStart(64, "0")}`, "historical facet route");
  }
  const logs = o.receipt.logs;
  const candidates = logs.map((l, i) => ({ l, i })).filter(({ l }) => l.address === W && l.topics[0] === topic
    && l.topics.length === 3 && BigInt(l.topics[1]).toString() === ref.tokenId);
  check(candidates.length === 1, "exact one named claim");
  const { l, i } = candidates[0];
  check(/^0x[0-9a-f]{128}$/.test(l.data) && /^0x0{24}[0-9a-f]{40}$/.test(l.topics[2]), "claim static ABI shape");
  const principal = BigInt(`0x${l.data.slice(2, 66)}`).toString(), rewards = BigInt(`0x${l.data.slice(66)}`).toString();
  const recipient = address(l.topics[2]), total = (BigInt(principal) + BigInt(rewards)).toString();
  const payouts = logs.map((l, i) => ({ l, i })).filter(({ l }) => l.address === SD && l.topics[0] === transfer
    && l.topics.length === 3 && address(l.topics[1]) === W && address(l.topics[2]) === recipient
    && /^0x[0-9a-f]{64}$/.test(l.data) && BigInt(l.data).toString() === total);
  check(total === "0" ? payouts.length === 0 : payouts.length === 1, "exact payout independently matched");
  const burns = logs.map((l, i) => ({ l, i })).filter(({ l }) => l.address === W && l.topics[0] === transfer
    && l.topics.length === 4 && l.data === "0x" && BigInt(l.topics[2]) === 0n && BigInt(l.topics[3]).toString() === ref.tokenId);
  const r = review.entries.find(e => e.tx === ref.tx);
  equal([r.principal, r.rewards, r.actualClaimRecipient, r.payoutTotal], [principal, rewards, recipient, total], "split recipient total");
  equal(r.claims.map(c => c.receiptArrayIndex), [i], "claim locator");
  equal(r.payoutMatches.map(c => c.receiptArrayIndex), payouts.map(p => p.i), "payout locators");
  equal(r.retirements.map(c => c.receiptArrayIndex), burns.map(p => p.i), "retirement locators");
  proofRows.push({ ...ref, provenance: old ? { archive: `${V30}/actual/archive.json`, resultIndex: priorIndex, requestIds: provenance }
    : { archive: "archive.json", requestIds: provenance }, principal, rewards, recipient, total,
    claimLog: l, claimReceiptIndex: i, payoutLogs: payouts, retirementLogs: burns });
}
for (const row of rows) {
  const f = row.fields, claims = proofRows.filter(r => r.locator === row.locator);
  const principal = claims.reduce((n, c) => n + BigInt(c.principal), 0n).toString();
  const rewards = claims.reduce((n, c) => n + BigInt(c.rewards), 0n).toString();
  const output = review.originals.find(r => r.locator === row.locator);
  const current = s.current.rows.find(r => r.locator === row.locator).observations.positionOf;
  equal(output.originalFields, f, "all frozen fields");
  equal([output.namedPrincipal, output.namedRewards], [principal, rewards], "per-original exact sums");
  equal([output.frozenMinusNamedPrincipal, output.frozenMinusNamedRewards],
    [(BigInt(f.claimed_principal_detf_raw) - BigInt(principal)).toString(), (BigInt(f.rewards_claimed_sdetf_raw) - BigInt(rewards)).toString()], "frozen comparisons");
  equal(output.currentPosition, current, "current position or exact error retained");
  equal(output.currentClaimedPrincipal, current.status === "success" ? current.value.claimedPrincipal : null, "current counter unknowns");
  equal(output.currentRemainingPrincipal, current.status === "success" ? (BigInt(current.value.principal) - BigInt(current.value.claimedPrincipal)).toString() : null, "remaining principal unknowns");
  equal(output.currentMinusFrozenPrincipal, current.status === "success"
    ? (BigInt(current.value.claimedPrincipal) - BigInt(f.claimed_principal_detf_raw)).toString() : null, "current versus frozen");
  equal(output.currentMinusNamedPrincipal, current.status === "success"
    ? (BigInt(current.value.claimedPrincipal) - BigInt(principal)).toString() : null, "current versus named");
  for (const k of ["currentCumulativeRewards", "originalPayer", "E0", "D0", "eligibility", "priorMigrationCompensation", "C0", "deduction"]) {
    check(output[k] === null, `financial/current reward unknown: ${k}`);
  }
  const purchaseIndex = s.old28.results.findIndex(r => r.tx === f.purchase_tx), purchase = s.old28.results[purchaseIndex];
  check(purchase.conflicts.length === 0, "accepted mint receipt");
  const mint = purchase.observed.receipt.logs.map((l, i) => ({ l, i })).filter(({l}) => l.address === W
    && l.topics[0] === transfer && l.topics.length === 4 && BigInt(l.topics[1]) === 0n
    && BigInt(l.topics[3]).toString() === f.token_id);
  check(mint.length === 1 && address(mint[0].l.topics[2]) === f.purchase_recipient && mint[0].l.data === "0x", "original mint identity");
  const bought = purchase.observed.receipt.logs.filter(l => l.address === W
    && l.topics[0] === id("BondPurchased(uint256,address,uint256,uint256,uint256)")
    && l.topics.length === 3 && BigInt(l.topics[1]).toString() === f.token_id);
  check(bought.length === 1 && /^0x[0-9a-f]{192}$/.test(bought[0].data), "purchase ABI shape");
  const words = bought[0].data.slice(2).match(/.{64}/g).map(w => BigInt(`0x${w}`).toString());
  equal(words, [f.original_principal_detf_raw, f.start_timestamp, f.duration_seconds], "purchase principal and clock");
  for (const c of review.entries.filter(e => e.locator === row.locator)) {
    check(c.historicalMint.resultIndex === purchaseIndex && c.historicalMint.mint.receiptArrayIndex === mint[0].i, "mint archive locator");
    equal(c.historicalMint.mint.log, mint[0].l, "complete mint log");
  }
}
equal([...used].sort((a,b)=>a-b), [...wire.keys()].sort((a,b)=>a-b), "all new requests accounted");
const queried = captures.filter(c => c.method === "eth_getTransactionByHash").map(c => c.params[0]).sort();
equal(queried, refs.filter(r => !s.old30.results.some(x => x.tx === r.tx)).map(r => r.tx).sort(), "only sixteen missing transaction calls");
equal(captures.filter(c => c.method === "eth_getTransactionReceipt").map(c => c.params[0]).sort(), queried, "only sixteen missing receipt calls");
const schema = await json(join(OUT, "schema-bindings.json"));
for (const source of schema.sources) {
  const content = s.wa[source.contract].sources[source.path].content;
  equal(source.content, content, "exact actual source body");
  check(source.contentSha256 === sha(Buffer.from(content)), "unescaped source binding");
}
const proof = { status: "PASS-BOUNDED-PRODUCER-RAW-PROOF", independentLiveVerifier: false,
  refs: refs.length, originals: rows.length, reused: refs.length - queried.length, new: queried.length,
  rawRequests: captures.length, priorRawRequestsChecked: usedPrior.size, canonicalLogs: logCount, proofRows,
  allNewRequestsAccounted: true, failures: captures.filter(c => c.failure), inputBindings: s.originals.identities,
  currentEvidence: `${V31}/observations.json`, financialAuthority: false, allHistoryCensus: false };
switch (process.argv[2]) {
  case "--stdout": process.stdout.write(`${JSON.stringify(proof, null, 2)}\n`); break;
  case "--verify": equal(await json(join(OUT, "proof.json")), proof, "published proof reproducibility"); break;
  case undefined: await save("proof.json", proof); break;
  default: check(false, "proof mode");
}
if (process.argv[2] !== "--stdout") console.log(JSON.stringify({ proof: "PASS", rows: refs.length, rawRequests: captures.length, canonicalLogs: logCount }));
