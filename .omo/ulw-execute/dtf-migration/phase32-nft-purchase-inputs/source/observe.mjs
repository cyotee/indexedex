import { mkdir } from "node:fs/promises";
import { join } from "node:path";
import { intake, fact, loupe, addressWord, LOUPE, CORE, ED, W, OUT, keccak256 } from "./common.mjs";
import { endpoint, ReadRpc } from "./rpc.mjs";

const data = await intake();
const url = await endpoint();
await mkdir(join(OUT, "http02"));
const rpc = new ReadRpc(url, "http02");
const chain = await rpc.read("eth_chainId", []);
fact(chain.result === "0x1237", "chain4663 required");
const rows = [];
for (const row of data.rows.filter(x => x.direct)) {
  const tx = row.result.transactionObservation, block = tx.blockNumber;
  const header = await rpc.read("eth_getBlockByNumber", [block, false]);
  const proxy = await rpc.read("eth_getCode", [row.parent, block]);
  const loupeRoute = await rpc.read("eth_call", [{ to: row.parent,
    data: loupe.encodeFunctionData("facetAddress", ["0xcdffacc6"]) }, block]);
  const loupeAddress = loupeRoute.result ? addressWord(loupeRoute.result) : null;
  const loupeCode = loupeAddress ? await rpc.read("eth_getCode", [loupeAddress, block]) : null;
  const route = await rpc.read("eth_call", [{ to: row.parent,
    data: loupe.encodeFunctionData("facetAddress", ["0x7a3b1181"]) }, block]);
  const facet = route.result ? addressWord(route.result) : null;
  const facetCode = facet ? await rpc.read("eth_getCode", [facet, block]) : null;
  let pairRoute = null, pair = null;
  if (row.parent === ED) {
    pairRoute = await rpc.read("eth_call", [{ to: row.parent,
      data: loupe.encodeFunctionData("facetAddress", ["0x3de35b79"]) }, block]);
    if (pairRoute.result && addressWord(pairRoute.result) === CORE) {
      pair = await rpc.read("eth_call", [{ to: row.parent, data: "0x3de35b79" }, block]);
    }
  }
  const expectedProxy = row.parent === ED ? data.ea.proxies[row.parent].code : data.wa[W].runtimeBytecode.onchainBytecode;
  const expectedLoupe = data.ea.contracts[LOUPE].onchainBytecode;
  const archived = facet ? data.ea.contracts[facet] ?? data.wa[facet] : null;
  const expectedFacet = archived?.onchainBytecode ?? archived?.runtimeBytecode?.onchainBytecode;
  rows.push({ locator: row.original.locator, tx: tx.hash, block, blockHash: tx.blockHash,
    requests: { header: header.id, proxy: proxy.id, loupeRoute: loupeRoute.id, loupeCode: loupeCode?.id ?? null,
      route: route.id, facetCode: facetCode?.id ?? null, pairRoute: pairRoute?.id ?? null, pair: pair?.id ?? null },
    canonicalHeaderMatches: header.result?.hash === tx.blockHash && header.result?.number === block,
    proxyMatches: proxy.result === expectedProxy, loupeAddress, loupeMatches: loupeAddress === LOUPE && loupeCode?.result === expectedLoupe,
    facet, facetRuntimeKeccak: facetCode?.result && facetCode.result !== "0x" ? keccak256(facetCode.result) : null,
    archivedFacetAvailable: Boolean(expectedFacet), facetMatches: expectedFacet ? facetCode?.result === expectedFacet : null,
    pairToken: pair?.result ? addressWord(pair.result) : null });
}
console.log(JSON.stringify({ status: "NON-ISSUABLE-HISTORICAL-ROUTING-OBSERVATIONS", rows, captures: rpc.captures,
  failures: rpc.captures.filter(x => x.failure).map(x => ({ id: x.id, failure: x.failure })) }, null, 2));
