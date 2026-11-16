import assert from "node:assert/strict";
import { writeFile } from "node:fs/promises";
import { keccak256 } from "viem";

const root = "/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-01";
const out = `${root}/docs/incidents/2026-09-16-dtf-recovery/migration/evidence/verification`;
assert.equal(process.cwd(), root);
const facet = "0x9C90d4a476f3473b9a0e32B530aF3474271a80B1";
const expectedRuntime = "0x5628dcb4bb0a1a24e6bde3b985f92c2ef0894ddd6006a55ddaffccc877a52742";
const url = `https://sourcify.dev/server/v2/contract/4663/${facet}?fields=abi,sources,runtimeBytecode,compilation,metadata`;
const response = await fetch(url, { signal: AbortSignal.timeout(60000) });
const body = await response.text();
await writeFile(`${out}/tokenstaking-source.raw.json`, body);
const receipt = { url, facet, expectedRuntime, status: response.status };
if (response.ok) {
  const source = JSON.parse(body);
  receipt.observedRuntime = keccak256(source.runtimeBytecode.onchainBytecode);
  receipt.runtimeMatch = source.runtimeMatch;
  receipt.matchesPinnedObservedFacet = receipt.observedRuntime === expectedRuntime;
  receipt.functions = source.abi.filter(entry => entry.type === "function");
}
await writeFile(`${out}/tokenstaking-source.receipt.json`, `${JSON.stringify(receipt, null, 2)}\n`);
console.log(`TOKENSTAKING_SOURCE http=${response.status} runtimeMatch=${receipt.matchesPinnedObservedFacet ?? false}`);
process.exitCode = receipt.matchesPinnedObservedFacet ? 0 : 2;
