import { request } from "node:https";
import { mkdir, readFile, writeFile } from "node:fs/promises";
import { join } from "node:path";
import { keccak256 } from "/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-30-recovery-receipts/node_modules/ethers/lib.esm/index.js";
import { OUT, WT, SOURCE, W, E, LOUPE, DETF, STAKE, OLD, intake, check, same, save, sha, json } from "./intake.mjs";

const startedAt = new Date().toISOString(), input = await intake(), pin = await json(`${SOURCE}/pin.json`);
check(pin.number === "113279837" && pin.tag === "0x6c0835d" && BigInt(pin.timestamp) === 1794565137n &&
  pin.hash === "0x78f23110692ee71a64dfea3463f7df0f9687ffa5d5f951fabb22c239921c4113", "producer pin changed");
await save("inputs.json", { inputs: input.inputs, declarations: input.declarations, sourceBindings: input.sourceBindings,
  producer: input.producer, rows: input.rows, specs: input.specs });
const config = await readFile(`${WT}/foundry.toml`, "utf8"), key = process.env.ALCHEMY_KEY;
const template = [...config.matchAll(/^robinhood_mainnet_alchemy\s*=\s*"([^"]+)"\s*$/gm)];
check(template.length === 1 && template[0][1] === "https://robinhood-mainnet.g.alchemy.com/v2/${ALCHEMY_KEY}", "RPC alias differs");
check(Boolean(key), "selected credential unavailable in established login environment");
const endpoint = new URL(template[0][1].replace("${ALCHEMY_KEY}", encodeURIComponent(key)));
const redact = text => [endpoint.href, key, encodeURIComponent(key)].reduce((s, secret) => s.replaceAll(secret, "<redacted>"), text);
await mkdir(join(OUT, "http"));
const captures = [], codes = new Map(), routes = [], globals = {}, rows = [];
async function rpc(method, params) {
  check(["eth_chainId", "eth_getBlockByNumber", "eth_getCode", "eth_call"].includes(method), "RPC method outside scope");
  const id = captures.length + 1;
  check(id <= 300, "finite request limit");
  if (method !== "eth_chainId") check(params[method === "eth_getBlockByNumber" ? 0 : 1] === pin.tag, "moving pin");
  const bytes = Buffer.from(JSON.stringify({ jsonrpc: "2.0", id, method, params }));
  const prefix = `http/${String(id).padStart(4, "0")}`, began = new Date().toISOString();
  await writeFile(join(OUT, `${prefix}.request.json`), bytes, { flag: "wx" });
  const capture = { id, method, params, startedAt: began,
    request: { path: `${prefix}.request.json`, bytes: bytes.length, sha256: sha(bytes) }, response: null, envelope: null, failure: null };
  try {
    const wire = await new Promise((resolve, reject) => {
      const req = request(endpoint, { method: "POST", agent: false, signal: AbortSignal.timeout(20000),
        headers: { "content-type": "application/json", "accept-encoding": "identity", "content-length": bytes.length } }, res => {
        const chunks = [];
        res.on("data", b => chunks.push(b));
        res.once("error", reject);
        res.once("end", () => resolve({ bytes: Buffer.concat(chunks), status: res.statusCode }));
      });
      req.once("error", reject); req.end(bytes);
    });
    const text = new TextDecoder("utf-8", { fatal: true }).decode(wire.bytes), safe = redact(text), raw = text === safe;
    const body = raw ? wire.bytes : Buffer.from(safe), path = `${prefix}.response.${raw ? "raw" : "redacted"}`;
    await writeFile(join(OUT, path), body, { flag: "wx" });
    capture.response = { path, bytes: body.length, sha256: sha(body), raw, receivedBytes: wire.bytes.length };
    capture.httpStatus = wire.status;
    check(raw && wire.status === 200, "nonraw or HTTP failure");
    const envelope = JSON.parse(text);
    check(envelope.jsonrpc === "2.0" && envelope.id === id && (("result" in envelope) !== ("error" in envelope)), "RPC envelope");
    check(envelope.result !== null, "null result is unknown");
    capture.envelope = envelope;
  } catch (error) {
    if (!(error instanceof Error)) throw error;
    capture.failure = { name: error.name, message: redact(error.message), nonraw: true };
  }
  capture.finishedAt = new Date().toISOString();
  captures.push(capture);
  return capture;
}
function required(c) {
  check(c.failure === null && c.envelope && "result" in c.envelope, `required RPC ${c.id} unavailable`);
  return c.envelope.result;
}
async function code(address) {
  if (!codes.has(address)) {
    const c = await rpc("eth_getCode", [address, pin.tag]), bytes = required(c);
    check(/^0x(?:[a-f0-9]{2})+$/i.test(bytes), "empty/malformed runtime");
    codes.set(address, { address, requestId: c.id, bytes, keccak256: keccak256(bytes) });
  }
  return codes.get(address);
}
// Decode static ABI words independently, not through producer or ethers result decoding.
function decode(param, words) {
  if (param.type === "tuple") return Object.fromEntries(param.components.map(p => [p.name, decode(p, words)]));
  const word = words.shift();
  check(word?.length === 64, "truncated ABI");
  if (param.type === "address") { check(/^0{24}/.test(word), "address padding"); return `0x${word.slice(24)}`; }
  check(["uint8", "uint256"].includes(param.type), "unreviewed static type");
  const value = BigInt(`0x${word}`);
  check(param.type !== "uint8" || value < 256n, "uint8 overflow");
  return String(value);
}
async function view(target, name, args = []) {
  const spec = input.specs.find(x => x.target === target && x.name === name);
  check(spec, "getter lacks archived schema");
  const c = await rpc("eth_call", [{ to: target, data: input.iface(spec.facet).encodeFunctionData(name, args) }, pin.tag]);
  if (c.failure || c.envelope.error) return { requestId: c.id, status: "failure", value: null, failure: c.failure ?? { kind: "rpc", error: c.envelope.error } };
  const bytes = required(c);
  check(/^0x(?:[0-9a-f]{64})+$/i.test(bytes), "static result grammar");
  const words = bytes.slice(2).toLowerCase().match(/.{64}/g);
  check(spec.abi.outputs.length === 1, "unreviewed output count");
  const value = decode(spec.abi.outputs[0], words);
  check(words.length === 0, "trailing ABI words");
  return { requestId: c.id, status: "success", value };
}
let blocker = null, canonical = false;
try {
  const chain = await rpc("eth_chainId", []);
  check(BigInt(required(chain)) === 4663n, "chain mismatch");
  const beginning = await rpc("eth_getBlockByNumber", [pin.tag, false]);
  same(required(beginning), pin.header, "initial same-pin full canonical header");
  await save("pin.json", { producerPin: pin, independentHeader: required(beginning),
    chainRequestId: chain.id, beginningRequestId: beginning.id, independentlyCapturedAt: beginning.finishedAt });
  for (const spec of input.specs) {
    const proxy = await code(spec.target), facet = await code(spec.facet), loupe = await code(LOUPE);
    check(proxy.bytes === input.code(W) && facet.bytes === input.code(spec.facet) &&
      loupe.bytes === input.code(LOUPE), "code identity blocker; decode withheld");
    const route = await rpc("eth_call", [{ to: spec.target, data: `0xcdffacc6${spec.selector.slice(2).padEnd(64, "0")}` }, pin.tag]);
    const self = await rpc("eth_call", [{ to: spec.target, data: `0xcdffacc6${"cdffacc6".padEnd(64, "0")}` }, pin.tag]);
    check(required(route) === `0x${spec.facet.slice(2).padStart(64, "0")}` &&
      required(self) === `0x${LOUPE.slice(2).padStart(64, "0")}`, "routing identity blocker; decode withheld");
    routes.push({ ...spec, routingRequestId: route.id, loupeRequestId: self.id,
      proxyRequestId: proxy.requestId, facetRequestId: facet.requestId, loupeCodeRequestId: loupe.requestId, compatible: true });
  }
  for (const [label, target, name, args] of [["weightedDetf", W, "detf"], ["weightedReceipt", DETF, "rebasingClaimToken"],
    ["stakingState", STAKE, "stakingState"], ["detfDecimals", DETF, "decimals"], ["receiptDecimals", STAKE, "decimals"],
    ["earlierLpToken", E, "lpToken"], ["earlierRewardToken", E, "rewardToken"], ["earlierDecimals", OLD, "decimals"],
    ["earlierRewardBalance", OLD, "balanceOf", [E]]]) globals[label] = await view(target, name, args);
  check(globals.weightedDetf.value === DETF && globals.weightedReceipt.value === STAKE &&
    globals.earlierRewardToken.value === OLD && globals.detfDecimals.value === "9" &&
    globals.receiptDecimals.value === "9" && globals.earlierDecimals.value === "18", "dependency or units differ");
  await code(globals.earlierLpToken.value);
  for (const original of input.rows) {
    const observations = {};
    for (const name of original.collection === W ? ["ownerOf", "positionOf", "previewClaim"] :
      ["ownerOf", "getPosition", "originalSharesOf", "unlockTimeOf", "pendingRewards"]) {
      observations[name] = await view(original.collection, name, [original.tokenId]);
    }
    rows.push({ ...original, observations });
  }
  const end = await rpc("eth_getBlockByNumber", [pin.tag, false]);
  same(required(end), pin.header, "end canonical full header");
  canonical = true;
  await save("end-canonical.json", { requestId: end.id, canonical, header: required(end), finishedAt: end.finishedAt });
} catch (error) {
  if (!(error instanceof Error)) throw error;
  blocker = { name: error.name, message: redact(error.message) };
}
await save("http-manifest.json", captures);
await save("observations.json", { startedAt, finishedAt: new Date().toISOString(), provider: "robinhood_mainnet_alchemy",
  pin: pin.number, canonical, blocker, code: [...codes.values()], routes, globals, rows, pendingRequests: 0 });
console.log(JSON.stringify({ rows: rows.length, requests: captures.length, canonical, blocker }));
process.exitCode = blocker || !canonical || rows.length !== 59 ? 2 : 0;
