import { join } from "node:path";
import { Interface, keccak256 } from "/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-30-recovery-receipts/node_modules/ethers/lib.esm/index.js";
import { OUT, SOURCE, ARCH, W, E, ZERO, LOUPE, intake, json, bound, save, same, check } from "./intake.mjs";

const input = await intake(), observed = await json(join(OUT, "observations.json"));
const producer = await json(`${SOURCE}/observations.json`), producerRouting = await json(`${SOURCE}/code-routing.json`);
const pin = await json(`${SOURCE}/pin.json`), ownPin = await json(join(OUT, "pin.json"));
const own = await json(join(OUT, "http-manifest.json")), old = await json(`${SOURCE}/http-manifest.json`);
const olderWeighted = await json(`${ARCH}/weighted/probe.results.json`);
const olderEarlier = await json(`${ARCH}/earlier-cp/probe-alchemy-retry.source.json`);
const olderRouting = [];
let checks = 0;
function fact(ok, message) { checks++; check(ok, message); }
const equal = (a, b, message) => { checks++; same(a, b, message); };
fact(observed.rows.length === 59 && producer.rows.length === 59 && observed.canonical && producer.canonical &&
  observed.blocker === null && observed.pendingRequests === 0, "complete bounded captures");
const raw = new Map(), originalRaw = new Map(), matches = [], consumed = new Set(), failures = [];
for (const [directory, captures, map] of [[OUT, own, raw], [SOURCE, old, originalRaw]]) {
  for (const c of captures) {
    await bound(c.request, directory); await bound(c.response, directory);
    const req = await json(join(directory, c.request.path)), res = await json(join(directory, c.response.path));
    fact(!map.has(c.id) && req.id === c.id && res.id === c.id && req.jsonrpc === "2.0" && res.jsonrpc === "2.0", "unique exact wire IDs");
    equal(req.params, c.params, "request parameters");
    fact(req.method === c.method && c.response.raw && (c.httpStatus ?? c.http?.status) === 200, "raw successful transport");
    if (["eth_call", "eth_getCode"].includes(req.method)) fact(req.params[1] === pin.tag, "literal numeric state pin");
    if (directory === OUT) equal(res, c.envelope, "own envelope normalization");
    else if ("error" in res) equal(c.failure, { kind: "rpc", error: res.error }, "producer exact RPC failure normalization");
    else { equal(c.result, res.result, "producer result normalization"); fact(c.failure === null, "producer false failure"); }
    map.set(c.id, { req, res });
  }
}
for (const c of own) {
  const index = old.findIndex(x => !consumed.has(x.id) && x.method === c.method &&
    JSON.stringify(x.params) === JSON.stringify(c.params));
  const candidate = index >= 0 ? old[index] : old.find(x => !consumed.has(x.id) &&
    c.method === "eth_getBlockByNumber" && x.method === c.method && x.params[0] === "latest");
  fact(Boolean(candidate), `independently constructed request absent from producer: ${c.id}`);
  consumed.add(candidate.id);
  const a = raw.get(c.id).res, b = originalRaw.get(candidate.id).res;
  equal({ result: a.result, error: a.error }, { result: b.result, error: b.error }, "same-pin live observation differs");
  matches.push({ verifierId: c.id, producerId: candidate.id, method: c.method, matches: true });
  if (a.error) failures.push({ verifierId: c.id, producerId: candidate.id, error: a.error });
}
fact(own.length === 268 && old.length === 268 && consumed.size === 268, "complete request reconciliation");
equal(raw.get(ownPin.beginningRequestId).res.result, pin.header, "independent beginning full header");
fact(BigInt(raw.get(ownPin.chainRequestId).res.result) === 4663n && BigInt(pin.number) >= 108944663n, "chain/pin lower bound");
const ending = await json(join(OUT, "end-canonical.json"));
equal(raw.get(ending.requestId).res.result, pin.header, "canonical final full header");
fact(pin.number === String(BigInt(pin.tag)) && pin.timestamp === String(BigInt(pin.header.timestamp)) &&
  pin.hash === pin.header.hash, "numeric pin/hash/timestamp");
for (const c of observed.code) {
  const capture = raw.get(c.requestId);
  fact(capture.req.method === "eth_getCode" && capture.req.params[0] === c.address &&
    capture.res.result === c.bytes && keccak256(c.bytes) === c.keccak256, "full code binding");
  const prior = producerRouting.code.find(x => x.address === c.address);
  fact(prior?.code === c.bytes && prior.keccak256 === c.keccak256, "producer code identity");
}
for (const spec of input.specs) {
  const route = observed.routes.find(x => x.target === spec.target && x.name === spec.name);
  const previous = producerRouting.routes.find(x => x.target === spec.target && x.name === spec.name);
  equal(route.abi, spec.abi, "independent archived ABI"); equal(previous.exactArchivedAbi, spec.abi, "producer archived ABI");
  fact(route.compatible && previous.compatible && previous.expectedFacet === spec.facet && previous.selector === spec.selector, "selected schema route compatibility");
  const routed = raw.get(route.routingRequestId), loupe = raw.get(route.loupeRequestId);
  equal(routed.req.params[0], { to: spec.target, data: `0xcdffacc6${spec.selector.slice(2).padEnd(64, "0")}` }, "route request");
  fact(routed.res.result === `0x${spec.facet.slice(2).padStart(64, "0")}` &&
    loupe.res.result === `0x${LOUPE.slice(2).padStart(64, "0")}`, "exact route addresses");
  fact(observed.code.find(c => c.address === spec.facet).bytes === input.code(spec.facet) &&
    observed.code.find(c => c.address === spec.target).bytes === input.code(W), "archive versus current runtime");
  const olderIndex = olderWeighted.rpc.findIndex(x => x.method === "eth_call" && x.params[0].to.toLowerCase() === spec.target &&
    x.params[0].data === `0xcdffacc6${spec.selector.slice(2).padEnd(64, "0")}`);
  const olderFacet = olderEarlier.proxies[spec.target]?.facets.find(x => x.functionSelectors.includes(spec.selector));
  if (olderIndex >= 0) {
    fact(olderWeighted.rpc[olderIndex].result === routed.res.result, "older weighted route changed");
    olderRouting.push({ target: spec.target, name: spec.name, locator: `weighted/probe.results.json#/rpc/${olderIndex}`, matches: true });
  } else if (olderFacet) {
    fact(olderFacet.facetAddress.toLowerCase() === spec.facet, "older earlier route changed");
    olderRouting.push({ target: spec.target, name: spec.name, locator: `earlier-cp/probe-alchemy-retry.source.json#/proxies/${spec.target}/facets`, matches: true });
  } else {
    fact(spec.name === "rebasingClaimToken", "unexpected missing older selected route");
    olderRouting.push({ target: spec.target, name: spec.name, matches: null,
      qualification: "new selected route to inspected archived parent implementation; no older selected route asserted" });
  }
}
function observation(o, spec, args) {
  const c = raw.get(o.requestId), iface = new Interface([spec.abi]);
  equal(c.req.params[0], { to: spec.target, data: iface.encodeFunctionData(spec.name, args) }, "exact getter/input");
  if (c.res.error) { fact(o.status === "failure" && o.value === null, "failure is unknown"); equal(o.failure.error, c.res.error, "exact typed error"); return; }
  fact(o.status === "success", "success status");
  const ordered = p => p.type === "tuple" ? p.components.map(x => orderedValue(x, o.value[x.name])) : o.value;
  const orderedValue = (p, value) => p.type === "tuple" ? p.components.map(x => orderedValue(x, value[x.name])) : value;
  const values = spec.abi.outputs.map(ordered);
  fact(iface.encodeFunctionResult(spec.name, values).toLowerCase() === c.res.result.toLowerCase(), "decoded value re-encodes exact ABI bytes");
}
const globalSpecs = { weightedDetf: [W, "detf"], weightedReceipt: ["0x4a5cfdc2b07016fcf917f4ed5a51c52111a0fcc7", "rebasingClaimToken"],
  stakingState: ["0x4fa4974a8a09660258b8edd430b51c1620ebfe5c", "stakingState"], detfDecimals: ["0x4a5cfdc2b07016fcf917f4ed5a51c52111a0fcc7", "decimals"],
  receiptDecimals: ["0x4fa4974a8a09660258b8edd430b51c1620ebfe5c", "decimals"], earlierLpToken: [E, "lpToken"],
  earlierRewardToken: [E, "rewardToken"], earlierDecimals: ["0xaf0e1967c8f755c747615c5427108bc549ca1122", "decimals"],
  earlierRewardBalance: ["0xaf0e1967c8f755c747615c5427108bc549ca1122", "balanceOf"] };
for (const [name, [target, fn]] of Object.entries(globalSpecs)) {
  observation(observed.globals[name], input.specs.find(x => x.target === target && x.name === fn), fn === "balanceOf" ? [E] : []);
  equal(observed.globals[name].value, producerRouting.globals[name].value, "global source observation");
}
const rows = [];
for (const original of input.rows) {
  const o = observed.rows.find(x => x.locator === original.locator), p = producer.rows.find(x => x.locator === original.locator);
  for (const [name, value] of Object.entries(original)) equal(o[name], value, `independent original preserved: ${original.locator}/${name}`);
  equal(p.originalFields, original.originalFields, "producer exact original fields");
  fact(p.collection === original.collection && p.tokenId === original.tokenId && p.sourceId === original.sourceId && p.pin === pin.number, "producer row identity");
  equal(p.historicalMint.log, original.mint.log, "mint log"); equal(p.historicalMint.purchaseEvent.log, original.purchase.log, "purchase log");
  equal(p.historicalReview, original.historicalReview, "historical qualifications");
  equal(p.joinedReview, original.joinedReview, "joined qualifications"); equal(p.joinedRecipientFlow, original.joinedRecipientFlow, "recipient flows");
  fact(p.historicalMint.recipient === original.recipient && p.historicalMint.transaction === original.originalFields.purchase_tx &&
    p.historicalMint.originalUnits === original.units && p.historicalMint.resultIndex === original.mint.index &&
    p.historicalMint.receiptArrayIndex === original.mint.receiptArrayIndex, "exact historical locators");
  for (const [name, value] of Object.entries(o.observations)) {
    observation(value, input.specs.find(x => x.target === original.collection && x.name === name), [original.tokenId]);
    const prior = p.observations[name];
    equal({ status: value.status, value: value.value, failure: value.failure }, { status: prior.status, value: prior.value, failure: prior.failure }, "per-getter independent comparison");
  }
  const owner = o.observations.ownerOf.value, pos = o.observations.positionOf?.value ?? o.observations.getPosition?.value;
  let state = "unknown", remaining = null, principalClaimed = null;
  const control = owner && owner !== ZERO ? owner === original.recipient : null;
  if (original.collection === W) {
    const error = `0x7e273289${BigInt(original.tokenId).toString(16).padStart(64, "0")}`;
    const absent = owner === ZERO && ["positionOf", "previewClaim"].every(name => {
      const failure = o.observations[name].failure;
      return failure?.kind === "rpc" && failure.error.code === 3 && failure.error.message === "execution reverted" && failure.error.data === error;
    });
    if (absent) state = "absent-at-pin-after-proved-historical-mint";
    else if (owner && owner !== ZERO && pos) state = "present-at-pin";
    if (pos) {
      fact(pos.principal === original.units && BigInt(pos.claimedPrincipal) <= BigInt(pos.principal), "P0/principal integrity");
      remaining = String(BigInt(original.units) - BigInt(pos.claimedPrincipal)); principalClaimed = pos.claimedPrincipal;
      const elapsed = BigInt(pin.timestamp) > BigInt(pos.startTimestamp) ? BigInt(pin.timestamp) - BigInt(pos.startTimestamp) : 0n;
      const vested = elapsed >= BigInt(pos.vestingDuration) ? BigInt(pos.principal) : BigInt(pos.principal) * elapsed / BigInt(pos.vestingDuration);
      const rewards = BigInt(pos.stakingGons) / BigInt(observed.globals.stakingState.value.gonsPerUnit) - BigInt(remaining);
      equal(o.observations.previewClaim.value, { vestedPrincipal: String(vested), principalRemaining: remaining,
        principalDue: String(vested - BigInt(pos.claimedPrincipal)), rewardsDue: String(rewards) }, "source-derived independent weighted arithmetic");
      fact(pos.startTimestamp === original.originalFields.start_timestamp && pos.vestingDuration === original.originalFields.duration_seconds, "original weighted clock");
    }
  } else {
    fact(owner !== ZERO && pos, "earlier actual position");
    state = "present-at-pin"; remaining = pos.originalShares;
    fact(pos.originalShares === original.units && o.observations.originalSharesOf.value === remaining &&
      o.observations.unlockTimeOf.value === pos.unlockTime, "earlier accounting units and lock getters");
    fact(p.principalAlreadyClaimed.status === "unavailable-source-model", "no invented earlier claimed principal");
  }
  fact(p.state === state && p.remaining === remaining && p.principalAlreadyClaimed.value === principalClaimed &&
    p.originalRecipientControlsAtPin === control && p.issues.length === 0, "producer semantic state");
  for (const k of ["E0", "D0", "priorCompensation", "C0", "credit"]) fact(p[k] === null, "financial unknown changed");
  fact(p.eligibility === "unreviewed" && p.originalWalletAuthority === "not-approved-by-mint-or-owner-match", "unapproved authority");
  rows.push({ ...o, verdict: "confirmed", state, remaining, principalClaimed, originalRecipientControlsAtPin: control,
    unit: original.collection === W ? "weighted-DETF-native9-fixed-principal" : "earlier-original-LP-accounting-shares",
    earlierClaimedPrincipal: original.collection === E ? "unavailable-source-model-not-zero" : null,
    E0: null, D0: null, priorCompensation: null, C0: null, credit: null, eligibility: "unapproved" });
}
fact(failures.length === 4 && observed.code.length === 13 && observed.routes.length === 17, "complete negative/code/route inventory");
await save("proof.json", { verdict: "confirmed", checks, pin: { number: pin.number, tag: pin.tag, hash: pin.hash, timestamp: pin.timestamp },
  canonical: true, rows, olderRouting, samePinRequestComparisons: matches, exactRpcErrors: failures, pendingOperations: [],
  sourceModelLimits: ["59 named records, not a census", "same-provider canonical check is not consensus finality", "no source/operational/financial acceptance"] });
console.log(JSON.stringify({ verdict: "confirmed", checks, rows: rows.length, requests: own.length, retainedRpcErrors: failures.length }));
