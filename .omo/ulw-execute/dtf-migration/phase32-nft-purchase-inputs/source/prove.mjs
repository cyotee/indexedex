import { readFile } from "node:fs/promises";
import { isDeepStrictEqual } from "node:util";
import { intake, json, OUT, CORE, ED, WD, W, DTF, WETH, TRANSFER, LOUPE, addressWord,
  fact, sha, keccak256, table } from "./common.mjs";

const data = await intake();
const result = await json(`${OUT}/reconcile-01.stdout`);
const observation = await json(`${OUT}/observe-02.stdout`);
let checks = 0;
const check = (condition, label) => { fact(condition, label); checks++; };
const used = new Set([1]);
check(observation.captures[0].result === "0x1237", "chain");
for (const capture of observation.captures) {
  const prefix = `${OUT}/http02/${String(capture.id).padStart(4, "0")}`;
  const request = await readFile(`${prefix}.request.json`);
  const response = await readFile(`${prefix}.response.raw`);
  check(request.length === capture.request.bytes && sha(request) === capture.request.sha256, `request identity ${capture.id}`);
  check(response.length === capture.response.bytes && sha(response) === capture.response.sha256, `response identity ${capture.id}`);
  check(request.toString() === capture.request.body && response.toString() === capture.response.body, `raw entities ${capture.id}`);
  const req = JSON.parse(request), res = JSON.parse(response);
  check(req.id === capture.id && res.id === capture.id && req.jsonrpc === "2.0" && res.jsonrpc === "2.0", `envelopes ${capture.id}`);
  check(req.method === capture.method && isDeepStrictEqual(req.params, capture.params), `request semantics ${capture.id}`);
  check(!capture.failure && capture.response.raw && capture.response.httpStatus === 200 && isDeepStrictEqual(res.result, capture.result),
    `safe successful result ${capture.id}`);
  check(["eth_chainId", "eth_getBlockByNumber", "eth_getCode", "eth_call"].includes(req.method), `allowed method ${capture.id}`);
}
const at = id => {
  used.add(id);
  const capture = observation.captures[id - 1];
  check(capture?.id === id, `capture reference ${id}`);
  return capture;
};
const verdicts = [];
for (const original of data.rows) {
  const row = result.rows.find(x => x.original.locator === original.original.locator);
  check(Boolean(row), `complete original ${original.original.locator}`);
  check(isDeepStrictEqual(row.original, original.original), `original fields ${row.tokenId}`);
  check(isDeepStrictEqual(row.retainedFlags, original.review.conflicts), `retained flags ${row.key}`);
  check(isDeepStrictEqual(row.retainedQualifications, original.review.qualifications), `qualifications ${row.key}`);
  check(row.originalAcquiringWallet === original.recipient && row.actualTopLevelCaller === original.result.transactionObservation.from,
    `payer distinction ${row.key}`);
  const tx = original.result.transactionObservation;
  const codes = observation.rows.find(x => x.locator === row.original.locator);
  if (original.direct) {
    check(/^0x7a3b1181[0-9a-f]{384}$/.test(tx.input), `six exact ABI words ${row.key}`);
    const words = tx.input.slice(10).match(/.{64}/g);
    const decoded = { tokenIn: addressWord(`0x${words[0]}`), amountIn: BigInt(`0x${words[1]}`).toString(),
      lockDuration: BigInt(`0x${words[2]}`).toString(), recipient: addressWord(`0x${words[3]}`),
      pretransferred: words[4] === "0".repeat(63) + "1", deadline: BigInt(`0x${words[5]}`).toString() };
    check(words[4] === "0".repeat(64), `false pretransfer ${row.key}`);
    check(isDeepStrictEqual(decoded, row.entry.decoded), `independent ABI decode ${row.key}`);
    check(`0x7a3b1181${words.join("")}` === tx.input, `exact calldata reconstruction ${row.key}`);
    const requests = codes.requests;
    for (const id of Object.values(requests)) if (id !== null) at(id);
    const header = at(requests.header);
    check(header.result.hash === tx.blockHash && header.result.number === tx.blockNumber &&
      header.result.transactions[Number(BigInt(tx.transactionIndex))] === tx.hash, `historical canonical block ${row.key}`);
    for (const name of ["proxy", "loupeCode", "facetCode"]) {
      const code = at(requests[name]);
      check(code.method === "eth_getCode" && code.params[1] === tx.blockNumber, `historical code tag ${row.key}:${name}`);
    }
    const route = at(requests.route), selfRoute = at(requests.loupeRoute);
    check(route.params[0].to === original.parent && route.params[1] === tx.blockNumber &&
      route.params[0].data === `0xcdffacc67a3b1181${"0".repeat(56)}`, `actual bond routing request ${row.key}`);
    check(addressWord(route.result) === codes.facet && addressWord(selfRoute.result) === LOUPE, `actual routing ${row.key}`);
    check(at(requests.loupeCode).result === data.ea.contracts[LOUPE].onchainBytecode, `loupe runtime ${row.key}`);
    const proxy = original.parent === ED ? data.ea.proxies[ED].code : data.wa[W].runtimeBytecode.onchainBytecode;
    check(at(requests.proxy).result === proxy, `proxy runtime ${row.key}`);
    check(keccak256(at(requests.facetCode).result) === codes.facetRuntimeKeccak, `facet runtime hash ${row.key}`);
  } else {
    check(row.entry.decoded === null && row.entry.interpretation === "outer-bundle-not-interpreted", `indirect retained ${row.key}`);
  }
  const supported = original.parent === ED;
  if (supported) {
    const req = codes.requests;
    check(addressWord(at(req.route).result) === CORE && at(req.facetCode).result === data.ea.contracts[CORE].onchainBytecode,
      `authenticated earlier body ${row.key}`);
    check(addressWord(at(req.pairRoute).result) === CORE && addressWord(at(req.pair).result) === DTF, `historical DTF pair ${row.key}`);
    check(data.ea.contracts[CORE].abi.find(x => x.name === "bond").stateMutability === "nonpayable", `nonpayable ABI ${row.key}`);
  }
  for (const component of row.paidComponents) {
    const logs = original.result.receiptObservation.logs;
    const out = logs.filter(log => log.address === component.asset && log.topics[0] === TRANSFER &&
      log.topics.length === 3 && addressWord(log.topics[1]) === original.recipient);
    const incoming = logs.filter(log => log.address === component.asset && log.topics[0] === TRANSFER &&
      log.topics.length === 3 && addressWord(log.topics[2]) === original.recipient);
    if (supported) {
      const primary = component.asset === row.entry.decoded.tokenIn;
      const expected = primary ? row.entry.decoded.amountIn : "0";
      check(component.proposedPaidRaw === expected, `exact proposed ${row.key}:${component.asset}`);
      check(incoming.length === 0 && (primary ? out.length === 1 &&
        BigInt(out[0].data).toString() === expected && addressWord(out[0].topics[2]) === ED : out.length === 0),
      `source-specific payment/no-refund receipt ${row.key}:${component.asset}`);
    } else check(component.proposedPaidRaw === null && component.state === "unknown" && component.missing.length > 0,
      `precise unknown retained ${row.key}:${component.asset}`);
  }
  const state = data.state.rows.find(x => x.locator === row.original.locator);
  check(isDeepStrictEqual(row.currentOwnerAndPosition.row, state), `separate current state ${row.key}`);
  const origins = table(data.input, "conversions.csv").filter(x => x.fields.tx.toLowerCase() === tx.hash);
  check(isDeepStrictEqual(row.economicOriginLinks.map(x => x.original), origins), `all original conversion links ${row.key}`);
  check(row.economicOriginLinks.every(x => x.createsAdditionalContribution === false && x.review.expectedOutput.recipient === W),
    `protocol outputs not purchases ${row.key}`);
  check(row.C0 === null && row.credit === null && row.priorCompensation === null && row.eligibility === "unreviewed",
    `non-issuable financial limits ${row.key}`);
  verdicts.push({ locator: row.original.locator, key: row.key, disposition: row.disposition,
    proposed: row.paidComponents.map(x => ({ asset: x.asset, proposedPaidRaw: x.proposedPaidRaw, state: x.state })) });
}
check(result.rows.length === 59 && new Set(result.rows.map(x => x.key)).size === 59, "complete unique59");
check(result.counts.flags === 19 && result.counts.originPairs === 2 && result.counts.supported === 16, "retained counts");
check(used.size === observation.captures.length && observation.captures.length === 363, "all363 requests referenced");
check(result.rows.filter(x => !x.entry.direct).map(x => x.tokenId).join(",") === "19,20,23,42", "four indirect identities");
console.log(JSON.stringify({ verdict: "producer-proof-passed-not-independent-verifier-verdict", checks,
  rows: verdicts, requestCount: observation.captures.length, allRequestsReferenced: true,
  sourceManifestReauthenticated: true, unproved: ["weighted purchase facet source/ABI", "indirect inner invocations",
    "internal native refunds", "eligibility and prior compensation", "independent downstream verification"] }, null, 2));
