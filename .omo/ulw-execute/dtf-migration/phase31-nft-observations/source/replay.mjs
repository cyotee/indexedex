import { mkdir, writeFile } from "node:fs/promises";
import { join } from "node:path";
import { isDeepStrictEqual } from "node:util";
import { OUT, intake, json, requireFact, sha } from "./evidence.mjs";
import { ReadRpc, endpoint } from "./rpc.mjs";

// Optional same-pin reproduction, never an independent-verifier claim.
// It cannot replace this stopped archive or choose a moving latest.
const label = process.argv[2];
requireFact(/^replay-[a-z0-9-]+$/.test(label ?? ""), "supply a fresh replay-name inside source/");
const source = await intake();
requireFact(source.rows.length === 59, "original population changed");
const pin = await json(join(OUT, "pin.json")), original = await json(join(OUT, "http-manifest.json"));
requireFact(BigInt(pin.number) >= 108944663n && original.length <= 400, "pin or finite bound differs");
const directory = join(OUT, label);
await mkdir(directory, { recursive: false });
const rpc = new ReadRpc(await endpoint(), `${label}/http`);
await rpc.start();
const comparisons = [];
for (const old of original) {
  const requestBytes = await Bun.file(join(OUT, old.request.path)).arrayBuffer();
  requireFact(requestBytes.byteLength === old.request.bytes && sha(Buffer.from(requestBytes)) === old.request.sha256, "original request identity mismatch");
  const request = JSON.parse(new TextDecoder().decode(requestBytes));
  const params = request.method === "eth_getBlockByNumber" ? [pin.tag, false] : request.params;
  requireFact(!["eth_call", "eth_getCode"].includes(request.method) || params[1] === pin.tag, "moving state pin refused");
  const c = await rpc.read(request.method, params);
  const matches = isDeepStrictEqual(c.result, old.result) && isDeepStrictEqual(c.failure, old.failure);
  comparisons.push({ oldRequestId: old.id, newRequestId: c.id, matches });
  if (request.method === "eth_chainId") requireFact(!c.failure && BigInt(c.result) === 4663n, "reproduction chain unavailable or wrong");
  if (request.method === "eth_getBlockByNumber") requireFact(!c.failure && c.result.hash === pin.hash &&
    c.result.number === pin.tag, "pinned header unavailable or changed");
}
await writeFile(join(directory, "http-manifest.json"), `${JSON.stringify(rpc.captures, null, 2)}\n`, { flag: "wx" });
await writeFile(join(directory, "comparison.json"), `${JSON.stringify({ pin, comparisons,
  matched: comparisons.every(x => x.matches), pendingRequests: 0,
  meaning: "same-provider same-pin reproduction, not independent verification or eligibility" }, null, 2)}\n`, { flag: "wx" });
console.log(JSON.stringify({ pin: pin.number, requests: comparisons.length, matches: comparisons.filter(x => x.matches).length }));
process.exitCode = comparisons.every(x => x.matches) ? 0 : 2;
