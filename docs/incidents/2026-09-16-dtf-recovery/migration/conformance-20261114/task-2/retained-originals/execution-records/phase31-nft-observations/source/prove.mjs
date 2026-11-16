import { readFile } from "node:fs/promises";
import { join } from "node:path";
import { isDeepStrictEqual } from "node:util";
import { Interface, keccak256 } from "/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-30-recovery-receipts/node_modules/ethers/lib.esm/index.js";
import { OUT, W, E, ZERO, intake, json, sha, requireFact, save } from "./evidence.mjs";

// Producer-side raw oracle: no new RPC, no import of observer or transport interpretation.
const source = await intake(), archive = await json(join(OUT, "observations.json"));
const captures = await json(join(OUT, "http-manifest.json")), binding = await json(join(OUT, "code-routing.json"));
const pin = await json(join(OUT, "pin.json")), end = await json(join(OUT, "end-canonical.json"));
const inputs = await json(join(OUT, "inputs.json")), originals = await json(join(OUT, "originals.json"));
let checks = 0;
function check(ok, message) { checks++; requireFact(ok, message); }
check(isDeepStrictEqual(source.rows, originals), "original derivation changed");
check(isDeepStrictEqual(source.bindings, await json(join(OUT, "source-manifest.json"))), "source identities changed");
check(isDeepStrictEqual(source.input.bindings, inputs.declarations), "input declarations changed");
check(archive.rows.length === 59 && pin.number === archive.pin.number && BigInt(pin.number) >= 108944663n, "population/pin mismatch");
const raw = new Map(), failures = [], consumed = new Set();
for (const c of captures) {
  for (const part of [c.request, c.response].filter(Boolean)) {
    const b = await readFile(join(OUT, part.path));
    check(b.length === part.bytes && sha(b) === part.sha256, `entity mismatch: ${part.path}`);
  }
  check(!raw.has(c.id), `duplicate request ID: ${c.id}`);
  const req = await json(join(OUT, c.request.path));
  check(req.id === c.id && req.jsonrpc === "2.0" && req.method === c.method && isDeepStrictEqual(req.params, c.params), `request mismatch: ${c.id}`);
  if (c.method === "eth_call" || c.method === "eth_getCode") check(c.params[1] === pin.tag, `moving state pin: ${c.id}`);
  if (c.response?.raw) {
    const env = JSON.parse(await readFile(join(OUT, c.response.path), "utf8"));
    check(env.id === c.id && env.jsonrpc === "2.0", `response ID mismatch: ${c.id}`);
    if (!c.failure) check("result" in env && isDeepStrictEqual(env.result, c.result), `normalized result mismatch: ${c.id}`);
    else if (c.failure.kind === "rpc") check(isDeepStrictEqual(env.error, c.failure.error), `RPC error mismatch: ${c.id}`);
  }
  if (c.failure) failures.push({ id: c.id, method: c.method, params: c.params, failure: c.failure });
  raw.set(c.id, c);
}
const get = (id) => { consumed.add(id); const c = raw.get(id); requireFact(c, `missing request: ${id}`); return c; };
check(BigInt(get(pin.chainRequestId).result) === 4663n, "chain mismatch");
check(isDeepStrictEqual(get(pin.latestRequestId).result, pin.header), "captured latest mismatch");
check(get(pin.latestRequestId).params[0] === "latest", "capture was not latest");
check(isDeepStrictEqual(get(end.requestId).result, pin.header) && end.canonical && archive.canonical, "end canonical check mismatch");
const code = new Map();
for (const c of binding.code) {
  const capture = get(c.requestId);
  check(capture.method === "eth_getCode" && capture.params[0] === c.address && capture.result === c.code, "code request mismatch");
  check(c.code === null || keccak256(c.code) === c.keccak256, "runtime hash mismatch");
  code.set(c.address, c);
}
for (const route of binding.routes) {
  const iface = source.abiAt(route.expectedFacet), fn = iface.getFunction(route.name);
  check(isDeepStrictEqual(JSON.parse(fn.format("json")), route.exactArchivedAbi), "archived function ABI mismatch");
  const routing = get(route.routingRequestId), self = get(route.routerRequestId);
  check(routing.params[0].to === route.target && routing.params[0].data ===
    `0xcdffacc6${route.selector.slice(2).padEnd(64, "0")}`, "route request mismatch");
  check(self.params[0].to === route.target && self.params[0].data === `0xcdffacc6${"cdffacc6".padEnd(64, "0")}`, "loupe request mismatch");
  const address = c => c.failure ? null : `0x${c.result.slice(-40)}`.toLowerCase();
  check(address(routing) === route.observedFacet && address(self) === route.observedRouter, "route decoding mismatch");
  const compatible = code.get(route.target).code === source.wa[W].runtimeBytecode.onchainBytecode &&
    code.get(route.expectedFacet).code === source.codeAt(route.expectedFacet) &&
    code.get(route.expectedRouter).code === source.codeAt(route.expectedRouter) &&
    route.expectedFacet === route.observedFacet && route.expectedRouter === route.observedRouter;
  check(route.compatible === compatible, "identity compatibility mismatch");
}
function decode(param, words) {
  if (param.type === "tuple") {
    const result = {};
    for (const field of param.components) result[field.name] = decode(field, words);
    return result;
  }
  const word = words.shift();
  requireFact(word?.length === 64, "truncated ABI value");
  if (param.type === "address") {
    requireFact(/^0{24}/.test(word), "noncanonical address");
    return `0x${word.slice(-40)}`;
  }
  requireFact(/^uint(8|256)$/.test(param.type), "oracle unsupported type");
  const value = BigInt(`0x${word}`);
  requireFact(param.type !== "uint8" || value <= 255n, "invalid uint8");
  return String(value);
}
function observation(value, target, name, args = []) {
  const route = binding.routes.find(r => r.target === target && r.name === name);
  check(Boolean(route), `missing getter binding: ${name}`);
  if (!route.compatible) { check(value.status === "identity-unavailable" && value.value === null, "incompatible ABI decoded"); return; }
  const c = get(value.requestId), iface = new Interface([route.exactArchivedAbi]);
  check(c.method === "eth_call" && c.params[0].to === target &&
    c.params[0].data === iface.encodeFunctionData(name, args), `getter request mismatch: ${value.requestId}`);
  if (c.failure) { check(value.value === null && value.status === "failure" && isDeepStrictEqual(value.failure, c.failure), "failure became value"); return; }
  check(/^0x(?:[0-9a-f]{64})*$/i.test(c.result), "malformed static ABI");
  const words = c.result.slice(2).toLowerCase().match(/.{64}/g) ?? [];
  const values = route.exactArchivedAbi.outputs.map(p => decode(p, words));
  check(words.length === 0 && values.length === 1 && value.status === "success" &&
    isDeepStrictEqual(values[0], value.value), `raw getter decode mismatch: ${value.requestId}`);
}
const g = binding.globals;
const globals = [
  ["weightedDetf", W, "detf"], ["weightedReceipt", "0x4a5cfdc2b07016fcf917f4ed5a51c52111a0fcc7", "rebasingClaimToken"],
  ["stakingState", "0x4fa4974a8a09660258b8edd430b51c1620ebfe5c", "stakingState"],
  ["detfDecimals", "0x4a5cfdc2b07016fcf917f4ed5a51c52111a0fcc7", "decimals"],
  ["receiptDecimals", "0x4fa4974a8a09660258b8edd430b51c1620ebfe5c", "decimals"],
  ["earlierLpToken", E, "lpToken"], ["earlierRewardToken", E, "rewardToken"],
  ["earlierDecimals", "0xaf0e1967c8f755c747615c5427108bc549ca1122", "decimals"],
  ["earlierRewardBalance", "0xaf0e1967c8f755c747615c5427108bc549ca1122", "balanceOf", [E]],
];
for (const [key, target, name, args] of globals) observation(g[key], target, name, args);
const proofRows = [];
for (const original of source.rows) {
  const row = archive.rows.find(r => r.locator === original.locator);
  for (const [key, value] of Object.entries(original)) check(isDeepStrictEqual(row[key], value), `original/unknown changed: ${original.locator}/${key}`);
  check(row.pin === pin.number, "row pin differs");
  for (const [name, value] of Object.entries(row.observations)) observation(value, row.collection, name, [row.tokenId]);
  const owner = row.observations.ownerOf.value, p = row.observations.positionOf?.value ?? row.observations.getPosition?.value;
  let state = "unknown", remaining = null;
  if (row.collection === W) {
    const expectedError = `0x7e273289${BigInt(row.tokenId).toString(16).padStart(64, "0")}`;
    const absent = owner === ZERO && ["positionOf", "previewClaim"].every(name =>
      row.observations[name].failure?.kind === "rpc" && row.observations[name].failure.error.data === expectedError);
    if (absent) state = "absent-at-pin-after-proved-historical-mint";
    else if (owner && owner !== ZERO && p) state = "present-at-pin";
    if (p && BigInt(p.claimedPrincipal) <= BigInt(p.principal)) remaining = String(BigInt(p.principal) - BigInt(p.claimedPrincipal));
    const preview = row.observations.previewClaim.value;
    if (p && preview) {
      const elapsed = BigInt(pin.timestamp) > BigInt(p.startTimestamp) ? BigInt(pin.timestamp) - BigInt(p.startTimestamp) : 0n;
      const vested = elapsed >= BigInt(p.vestingDuration) ? BigInt(p.principal) : BigInt(p.principal) * elapsed / BigInt(p.vestingDuration);
      check(preview.vestedPrincipal === String(vested) && preview.principalRemaining === remaining &&
        preview.principalDue === String(vested - BigInt(p.claimedPrincipal)) &&
        preview.rewardsDue === String(BigInt(p.stakingGons) / BigInt(g.stakingState.value.gonsPerUnit) - BigInt(remaining)), "weighted preview arithmetic differs");
    }
  } else {
    if (owner === ZERO && p && Object.values(p).every(v => v === "0")) state = "absent-at-pin-after-proved-historical-mint";
    else if (owner && owner !== ZERO && p) state = "present-at-pin";
    if (p) {
      remaining = p.originalShares;
      check(row.observations.originalSharesOf.value === p.originalShares && row.observations.unlockTimeOf.value === p.unlockTime, "earlier getters disagree");
    }
    check(row.principalAlreadyClaimed.value === null, "invented earlier claimed-principal field");
  }
  check(row.state === state && row.remaining === remaining, "state or remaining mismatch");
  check(row.originalRecipientControlsAtPin === (owner && owner !== ZERO ? owner === original.historicalMint.recipient : null), "wallet control comparison differs");
  proofRows.push({ locator: row.locator, collection: row.collection, tokenId: row.tokenId, state, remaining,
    owner, originalRecipientControlsAtPin: row.originalRecipientControlsAtPin, issues: row.issues });
}
check(consumed.size === captures.length, `unreferenced captures: ${captures.filter(c => !consumed.has(c.id)).map(c => c.id)}`);
const proof = { status: "PRODUCER-RAW-ORACLE-PASS-NOT-INDEPENDENT-VERIFIER", checks, rows: proofRows, pin: pin.number,
  captures: captures.length, failures, canonical: end.canonical, inputDeclarations: source.input.bindings.length,
  scope: "All 59 original rows; exact raw static ABI, selected routes/code, principal and preview arithmetic; no new live acquisition",
  limits: ["same-provider observations, not trustless proof", "no eligibility, original-wallet authority, E0/D0, prior compensation, C0 or credit approval"] };
await save("proof.json", proof);
console.log(JSON.stringify({ status: proof.status, checks, rows: proofRows.length, captures: captures.length, failures: failures.length }));
