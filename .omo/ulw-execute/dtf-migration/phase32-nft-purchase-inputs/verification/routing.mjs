import { Interface, keccak256 } from "/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-30-recovery-receipts/node_modules/ethers/lib.esm/index.js";
import { SOURCE, ED, W, DTF, CORE, WF, LOUPE, check, equal, raw, json, sha } from "./intake.mjs";

export { Interface, keccak256 };
export function address(word) {
  check(/^0x0{24}[0-9a-f]{40}$/.test(word), "canonical ABI address");
  return `0x${word.slice(-40)}`;
}
export async function routing(data, originals) {
  // Reconstruct the expected schedule from originals, not saved observation booleans.
  let next = 1;
  const requests = [], routes = new Map();
  const httpManifest = await json(`${SOURCE}/http-manifest.json`);
  async function consume(method, params) {
    const id = next++, prefix = `${SOURCE}/http02/${String(id).padStart(4, "0")}`;
    const requestBytes = await raw(`${prefix}.request.json`);
    const responseBytes = await raw(`${prefix}.response.raw`);
    const request = JSON.parse(requestBytes.toString()), response = JSON.parse(responseBytes.toString());
    equal(request, { jsonrpc: "2.0", id, method, params }, `exact derived request ${id}`);
    check(response.jsonrpc === "2.0" && response.id === id && !("error" in response) &&
      response.result !== null && response.result !== undefined, `successful envelope ${id}`);
    const saved = data.observation.captures[id - 1], physical = await json(`${prefix}.capture.json`);
    equal(saved, physical, `physical capture ${id}`);
    check(saved.id === id && saved.method === method && saved.response.raw === true &&
      saved.response.httpStatus === 200 && saved.failure === null, `safe capture ${id}`);
    equal(saved.params, params, `capture params ${id}`);
    equal(saved.result, response.result, `capture result ${id}`);
    for (const [name, bytes] of [["request", requestBytes], ["response", responseBytes]]) {
      const value = saved[name], manifest = httpManifest[id - 1][name];
      check(value.bytes === bytes.length && value.sha256 === sha(bytes) &&
        value.body === bytes.toString(), `capture raw identity ${id}:${name}`);
      check(manifest.bytes === bytes.length && manifest.sha256 === sha(bytes), `wire manifest ${id}:${name}`);
    }
    requests.push({ id, method, params, requestSha256: sha(requestBytes), responseSha256: sha(responseBytes) });
    return { id, result: response.result };
  }
  const chain = await consume("eth_chainId", []);
  equal(chain.result, "0x1237", "historical read chain");
  const abi = new Interface(data.ea.contracts[CORE].abi);
  check(abi.getFunction("bond").selector === "0x7a3b1181" &&
    abi.getFunction("bond").stateMutability === "nonpayable", "archived earlier purchase ABI");
  check(abi.getFunction("pairToken").selector === "0x3de35b79", "archived pair getter ABI");
  const loupeAbi = new Interface(data.ea.contracts[LOUPE].abi);
  equal(loupeAbi.getFunction("facetAddress").selector, "0xcdffacc6", "archived loupe selector");
  const source = data.ea.contracts[CORE];
  const onchain = source.onchainBytecode.slice(2), compiled = source.recompiledBytecode.slice(2);
  equal(source.transformations, [{ id: "1", type: "replace", offset: 35515, reason: "cborAuxdata" }],
    "archived runtime qualification");
  equal(onchain.slice(0, 35515 * 2), compiled.slice(0, 35515 * 2), "runtime executable prefix before CBOR");
  equal(keccak256(source.onchainBytecode), source.codeHash, "archived runtime keccak");
  for (const original of originals.filter(x => x.direct)) {
    const { tx, parent, locator } = original, block = tx.blockNumber;
    const header = await consume("eth_getBlockByNumber", [block, false]);
    check(header.result.number === block && header.result.hash === tx.blockHash &&
      header.result.transactions[Number(BigInt(tx.transactionIndex))] === tx.hash, `canonical historical member ${locator}`);
    const proxy = await consume("eth_getCode", [parent, block]);
    const loupeRoute = await consume("eth_call", [{ to: parent,
      data: loupeAbi.encodeFunctionData("facetAddress", ["0xcdffacc6"]) }, block]);
    equal(address(loupeRoute.result), LOUPE, `loupe self route ${locator}`);
    const loupeCode = await consume("eth_getCode", [LOUPE, block]);
    equal(loupeCode.result, data.ea.contracts[LOUPE].onchainBytecode, `historical loupe code ${locator}`);
    const route = await consume("eth_call", [{ to: parent,
      data: loupeAbi.encodeFunctionData("facetAddress", ["0x7a3b1181"]) }, block]);
    const facet = address(route.result), expectedFacet = parent === ED ? CORE : WF;
    equal(facet, expectedFacet, `historical purchase facet ${locator}`);
    const facetCode = await consume("eth_getCode", [facet, block]);
    equal(proxy.result, parent === ED ? data.ea.proxies[ED].code : data.wa[W].runtimeBytecode.onchainBytecode,
      `historical proxy bytes ${locator}`);
    check(/^0x(?:[0-9a-f]{2})+$/.test(facetCode.result), `nonempty runtime ${locator}`);
    let pairRoute = null, pair = null;
    if (parent === ED) {
      equal(facetCode.result, source.onchainBytecode, `historical earlier exact runtime ${locator}`);
      pairRoute = await consume("eth_call", [{ to: parent,
        data: loupeAbi.encodeFunctionData("facetAddress", ["0x3de35b79"]) }, block]);
      equal(address(pairRoute.result), CORE, `historical pair getter route ${locator}`);
      pair = await consume("eth_call", [{ to: parent, data: "0x3de35b79" }, block]);
      equal(address(pair.result), DTF, `historical pair value ${locator}`);
    } else {
      check(!(facet in data.wa) && !(facet in data.ea.contracts), `weighted actual source absent ${locator}`);
      equal(keccak256(facetCode.result), "0x2676830f3b489088787c4ecc21803326a7909fbaaf9fd72994ec62b111bf62f8",
        `weighted raw runtime identity ${locator}`);
    }
    const ids = { header: header.id, proxy: proxy.id, loupeRoute: loupeRoute.id, loupeCode: loupeCode.id,
      route: route.id, facetCode: facetCode.id, pairRoute: pairRoute?.id ?? null, pair: pair?.id ?? null };
    const independentlyDerived = { locator, tx: tx.hash, block, blockHash: tx.blockHash, requests: ids,
      canonicalHeaderMatches: true, proxyMatches: true, loupeAddress: LOUPE, loupeMatches: true,
      facet, facetRuntimeKeccak: keccak256(facetCode.result), archivedFacetAvailable: parent === ED,
      facetMatches: parent === ED ? true : null, pairToken: pair ? address(pair.result) : null };
    equal(data.observation.rows.find(x => x.locator === locator), independentlyDerived, `complete route observation ${locator}`);
    routes.set(locator, independentlyDerived);
  }
  check(next === 364 && data.observation.captures.length === 363 && data.observation.rows.length === 55 &&
    httpManifest.length === 363 && data.observation.failures.length === 0, "complete finite schedule");
  return { routes, requests, sourceQualification: { match: source.match, runtimeMatch: source.runtimeMatch,
    transformations: source.transformations, executablePrefixBytes: 35515, runtimeKeccak: source.codeHash,
    limits: "Same-provider block-end bindings; not execution-prefix state, exact_match or new compilation." } };
}
