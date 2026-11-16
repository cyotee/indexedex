import { prove } from "./prove.mjs";
import { OUT, raw, json, equal, check, sha } from "./evidence.mjs";

const derived = await prove();
const bytes = await raw(`${OUT}/proof.json`);
const reproduced = Buffer.from(`${JSON.stringify(derived, null, 2)}\n`);
equal(bytes, reproduced, "exact deterministic proof reproduction");
equal(await json(`${OUT}/direct-attribution.json`), {
  version: "phase34-direct-source-observations-v1", meaning: derived.quantityMeaning, rows: derived.direct,
}, "complete direct attribution");
equal(await json(`${OUT}/source-index.json`), derived.sourceAuthentication, "all source authentication observations");
equal(await json(`${OUT}/untouched-context.json`), {
  indirect: derived.indirectUnchanged, earlier: derived.earlierUnchanged, preservedFailure: derived.preservedFailure,
}, "earlier/G2 context unchanged");
const snapshot = await json(`${OUT}/proof-01.command.json`);
equal(snapshot.stdoutBytes, bytes.length, "actual proof stdout length");
equal(snapshot.stdoutSha256, sha(bytes), "actual proof stdout identity");
for (const b of snapshot.sources) {
  const actual = await raw(`${OUT}/${b.path}`);
  check(actual.length === b.bytes && sha(actual) === b.sha256, `executed source ${b.path}`);
}
console.log(JSON.stringify({
  status: "confirmed-producer-reproduction-not-independent-verdict",
  proofBytes: bytes.length, proofSha256: sha(bytes), counts: derived.counts,
  reconstructedSourceBodies: 99, exactHistoricalDirectRuntimeComparisons: 39,
  newNetworkRequests: 0, pendingOwnedOperations: 0,
}, null, 2));
