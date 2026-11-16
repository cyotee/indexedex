import { keccak256 } from "/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-30-recovery-receipts/node_modules/ethers/lib.esm/index.js";
import { intake, save, W, E, ZERO, GENERIC, FUNDED, EARLIER, LOUPE, requireFact, OUT } from "./evidence.mjs";
import { ReadRpc, endpoint, result } from "./rpc.mjs";

const startedAt = new Date().toISOString();
const source = await intake(); // Authenticate every original before resolving credentials or constructing calls.
await save("inputs.json", { root: "/Users/cyotee/Projects/indexedex/.omo/ulw-execute/dtf-migration/phase27-frozen-input-recovery/input-tree/2026-09-16-dtf-recovery",
  declarations: source.input.bindings, identities: [...source.input.bytes].map(([path, bytes]) =>
    ({ path, bytes: bytes.length, sha256: new Bun.CryptoHasher("sha256").update(bytes).digest("hex") })),
  qualification: "hash-authenticated recovered bodies, not located original captures" });
await save("source-manifest.json", source.bindings);
await save("originals.json", source.rows);
const rpc = new ReadRpc(await endpoint(), "http");
await rpc.start();
const code = new Map(), routes = [], rows = [], globals = {};
let pin = null, canonical = false, blocker = null;
const loupe = source.abiAt(LOUPE);
const proxyBytes = source.wa[W].runtimeBytecode.onchainBytecode;
async function codeRead(address) {
  const target = address.toLowerCase();
  if (!code.has(target)) {
    const capture = await rpc.read("eth_getCode", [target, pin.tag]);
    const raw = capture.failure ? null : capture.result;
    requireFact(raw === null || /^0x(?:[0-9a-f]{2})*$/i.test(raw), `invalid code response: ${capture.id}`);
    code.set(target, { address: target, requestId: capture.id, code: raw,
      keccak256: raw === null ? null : keccak256(raw), failure: capture.failure });
  }
  return code.get(target);
}
async function bind(target, facet, name) {
  const iface = source.abiAt(facet), fn = iface.getFunction(name);
  requireFact(fn && ["view", "pure"].includes(fn.stateMutability), `not inspected view: ${name}`);
  const proxy = await codeRead(target), implementation = await codeRead(facet), router = await codeRead(LOUPE);
  const routing = await rpc.read("eth_call", [{ to: target, data: loupe.encodeFunctionData("facetAddress", [fn.selector]) }, pin.tag]);
  const selfRoute = await rpc.read("eth_call", [{ to: target, data: loupe.encodeFunctionData("facetAddress", [loupe.getFunction("facetAddress").selector]) }, pin.tag]);
  const observedFacet = routing.failure ? null : loupe.decodeFunctionResult("facetAddress", routing.result)[0].toLowerCase();
  const observedRouter = selfRoute.failure ? null : loupe.decodeFunctionResult("facetAddress", selfRoute.result)[0].toLowerCase();
  if (observedFacet && observedFacet !== ZERO) await codeRead(observedFacet);
  if (observedRouter && observedRouter !== ZERO) await codeRead(observedRouter);
  const compatible = proxy.code === proxyBytes && implementation.code === source.codeAt(facet) &&
    router.code === source.codeAt(LOUPE) && observedFacet === facet && observedRouter === LOUPE;
  const row = { target, name, selector: fn.selector, expectedFacet: facet, observedFacet,
    expectedRouter: LOUPE, observedRouter, routingRequestId: routing.id, routerRequestId: selfRoute.id,
    proxyRequestId: proxy.requestId, implementationRequestId: implementation.requestId, compatible,
    exactArchivedAbi: JSON.parse(fn.format("json")),
    archivedFacetRuntimeKeccak256: keccak256(source.codeAt(facet)),
    archivedProxyRuntimeKeccak256: keccak256(proxyBytes),
    difference: compatible ? null : "identity-or-routing-unavailable-or-different; decoding withheld" };
  routes.push(row);
  return { row, iface };
}
function typed(param, value) {
  if (param.baseType === "tuple") return Object.fromEntries(param.components.map((p, i) => [p.name || String(i), typed(p, value[i])]));
  if (param.baseType === "array") return Array.from(value, v => typed(param.arrayChildren, v));
  return typeof value === "bigint" ? value.toString() : typeof value === "string" ? value.toLowerCase() : value;
}
async function view(binding, args = []) {
  if (!binding.row.compatible) return { status: "identity-unavailable", requestId: null, value: null };
  const name = binding.row.name, fn = binding.iface.getFunction(name);
  const c = await rpc.read("eth_call", [{ to: binding.row.target, data: binding.iface.encodeFunctionData(name, args) }, pin.tag]);
  if (c.failure) return { status: "failure", requestId: c.id, value: null, failure: c.failure };
  try {
    const decoded = binding.iface.decodeFunctionResult(name, c.result);
    requireFact(binding.iface.encodeFunctionResult(name, decoded).toLowerCase() === c.result.toLowerCase(), `noncanonical ABI bytes: ${c.id}`);
    return { status: "success", requestId: c.id, value: fn.outputs.length === 1 ? typed(fn.outputs[0], decoded[0]) :
      Object.fromEntries(fn.outputs.map((p, i) => [p.name || String(i), typed(p, decoded[i])])) };
  } catch (error) {
    if (!(error instanceof Error)) throw error;
    return { status: "decode-failure", requestId: c.id, value: null, failure: { name: error.name, message: rpc.redact(error.message) } };
  }
}
try {
  const chain = await rpc.read("eth_chainId", []);
  requireFact(BigInt(result(chain)) === 4663n, "wrong RPC chain");
  const latest = await rpc.read("eth_getBlockByNumber", ["latest", false]);
  const header = result(latest);
  requireFact(/^0x[0-9a-f]+$/i.test(header.number) && /^0x[0-9a-f]{64}$/i.test(header.hash) &&
    /^0x[0-9a-f]+$/i.test(header.timestamp) && BigInt(header.number) >= 108944663n, "latest header unavailable or below lower bound");
  pin = { number: BigInt(header.number).toString(), tag: header.number, hash: header.hash,
    timestamp: BigInt(header.timestamp).toString(), capturedAt: latest.finishedAt, header, chainRequestId: chain.id, latestRequestId: latest.id,
    finality: "actual latest capture, not finalized consensus; canonical hash rechecked only through this same provider" };
  await save("pin.json", pin);
  const weighted = {}, earlier = {};
  for (const [name, facet] of [["ownerOf", GENERIC], ["positionOf", FUNDED], ["previewClaim", FUNDED], ["detf", FUNDED]]) weighted[name] = await bind(W, facet, name);
  for (const [name, facet] of [["ownerOf", GENERIC], ["getPosition", EARLIER], ["originalSharesOf", EARLIER],
    ["unlockTimeOf", EARLIER], ["pendingRewards", EARLIER], ["lpToken", EARLIER], ["rewardToken", EARLIER]]) earlier[name] = await bind(E, facet, name);
  const detf = "0x4a5cfdc2b07016fcf917f4ed5a51c52111a0fcc7", staking = "0x4fa4974a8a09660258b8edd430b51c1620ebfe5c";
  globals.weightedDetf = await view(weighted.detf);
  const receiptBinding = await bind(detf, "0x1d38189b5f3548bc86838061f4318dbfa2f77680", "rebasingClaimToken");
  globals.weightedReceipt = await view(receiptBinding);
  globals.stakingState = await view(await bind(staking, "0xb7581fe833a2b2380dd786b345d61ffb734d36eb", "stakingState"));
  globals.detfDecimals = await view(await bind(detf, "0x1d17aca0e0717d90cea916372070a1be4652223f", "decimals"));
  globals.receiptDecimals = await view(await bind(staking, "0xb7581fe833a2b2380dd786b345d61ffb734d36eb", "decimals"));
  globals.earlierLpToken = await view(earlier.lpToken);
  globals.earlierRewardToken = await view(earlier.rewardToken);
  const oldDetf = "0xaf0e1967c8f755c747615c5427108bc549ca1122";
  globals.earlierDecimals = await view(await bind(oldDetf, "0x1d17aca0e0717d90cea916372070a1be4652223f", "decimals"));
  globals.earlierRewardBalance = await view(await bind(oldDetf, "0x1d17aca0e0717d90cea916372070a1be4652223f", "balanceOf"), [E]);
  const weightedDependencies = globals.weightedDetf.value === detf && globals.weightedReceipt.value === staking &&
    globals.detfDecimals.value === "9" && globals.receiptDecimals.value === "9" && globals.stakingState.status === "success";
  const earlierDependencies = globals.earlierRewardToken.value === oldDetf && globals.earlierDecimals.value === "18" &&
    globals.earlierRewardBalance.status === "success";
  if (globals.earlierLpToken.status === "success") await codeRead(globals.earlierLpToken.value);
  for (const original of source.rows) {
    const selected = original.collection === W ? weighted : earlier;
    const names = original.collection === W ? ["ownerOf", "positionOf", "previewClaim"] :
      ["ownerOf", "getPosition", "originalSharesOf", "unlockTimeOf", "pendingRewards"];
    const observations = {};
    for (const name of names) observations[name] = await view(selected[name], [original.tokenId]);
    const owner = observations.ownerOf.value, position = observations.positionOf?.value ?? observations.getPosition?.value;
    const nonexistentData = `0x7e273289${BigInt(original.tokenId).toString(16).padStart(64, "0")}`;
    const recognizedWeightedAbsence = original.collection === W && owner === ZERO &&
      [observations.positionOf, observations.previewClaim].every(x => x.status === "failure" &&
        x.failure.kind === "rpc" && x.failure.error.data === nonexistentData);
    const recognizedEarlierAbsence = original.collection === E && owner === ZERO &&
      observations.getPosition.status === "success" && Object.values(position).every(x => x === "0");
    let state = "unknown", remaining = null;
    if (recognizedWeightedAbsence || recognizedEarlierAbsence) state = "absent-at-pin-after-proved-historical-mint";
    else if (owner && owner !== ZERO && position) state = "present-at-pin";
    if (original.collection === W && position && BigInt(position.claimedPrincipal) <= BigInt(position.principal)) {
      remaining = (BigInt(position.principal) - BigInt(position.claimedPrincipal)).toString();
    }
    if (original.collection === E && position) remaining = position.originalShares;
    const issues = [];
    if (original.collection === W && !weightedDependencies) issues.push("weighted-preview-dependency-identity-or-units-unavailable");
    if (original.collection === E && !earlierDependencies) issues.push("earlier-reward-dependency-identity-or-units-unavailable");
    if (position && original.collection === W && position.principal !== original.historicalMint.originalUnits) issues.push("principal-original-mismatch");
    if (position && original.collection === W && remaining === null) issues.push("claimed-principal-exceeds-principal");
    rows.push({ ...original, pin: pin.number, observations, state, remaining,
      remainingUnit: original.collection === W ? "weighted-DETF-native9-fixed-principal" : "earlier-original-LP-accounting-shares-not-physical-LP-or-DETF",
      principalAlreadyClaimed: original.collection === E ? { status: "unavailable-source-model", value: null } :
        { status: observations.positionOf.status, value: position?.claimedPrincipal ?? null, requestId: observations.positionOf.requestId },
      originalRecipientControlsAtPin: owner && owner !== ZERO ? owner === original.historicalMint.recipient : null,
      issues, absenceMeaning: state.startsWith("absent") ? "recognized source absence at pin, not a generic revert or independently reconstructed burn transaction" : null });
  }
  const ending = await rpc.read("eth_getBlockByNumber", [pin.tag, false]);
  canonical = !ending.failure && ending.result.hash === pin.hash && ending.result.number === pin.tag && ending.result.timestamp === pin.header.timestamp;
  await save("end-canonical.json", { requestId: ending.id, canonical, header: ending.result, failure: ending.failure });
} catch (error) {
  if (!(error instanceof Error)) throw error;
  blocker = { name: error.name, message: rpc.redact(error.message) };
}
for (const original of source.rows) if (!rows.some(x => x.locator === original.locator)) {
  rows.push({ ...original, pin: pin?.number ?? null, state: "unknown", observations: {}, remaining: null,
    issues: ["required-identity-or-data-unavailable"], blocker });
}
await save("http-manifest.json", rpc.captures);
await save("code-routing.json", { code: [...code.values()], routes, globals });
await save("observations.json", { status: blocker ? "UNAVAILABLE-DATA-OR-IDENTITY" : "NON-ISSUABLE-OBSERVATIONS",
  startedAt, finishedAt: new Date().toISOString(), provider: "robinhood_mainnet_alchemy", pin, canonical, blocker, rows });
console.log(JSON.stringify({ rows: rows.length, requests: rpc.captures.length, canonical, blocker, out: OUT }));
process.exitCode = blocker || !canonical ? 2 : 0;
