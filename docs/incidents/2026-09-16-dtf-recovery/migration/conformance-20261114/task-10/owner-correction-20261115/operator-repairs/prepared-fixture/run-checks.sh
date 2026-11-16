#!/bin/bash
set -u
set -o pipefail
set -C
cd '/Users/cyotee/Projects/indexedex-wt/dtf-conformance-20261115-wave-1' || exit 90
unset TASK12_EVIDENCE
E='/Users/cyotee/Projects/indexedex-wt/dtf-conformance-20261115-wave-1/docs/incidents/2026-09-16-dtf-recovery/migration/conformance-20261114/task-10/owner-correction-20261115/operator-repairs/prepared-fixture'
status=0
sources=(
'bun.lock'
'docs/incidents/2026-09-16-dtf-recovery/migration/conformance-20261114/task-11/recovery.ts'
'docs/incidents/2026-09-16-dtf-recovery/migration/conformance-20261114/task-12/mixed-fixture.ts'
'docs/incidents/2026-09-16-dtf-recovery/migration/resumed-integration/record-verification.ts'
'docs/incidents/2026-09-16-dtf-recovery/migration/resumed-integration/verify-bounded-deployments.ts'
'node_modules/ethers/package.json'
'node_modules/typescript/bin/tsc'
'node_modules/typescript/package.json'
'node_modules/zod/package.json'
'package.json'
'scripts/recovery/dtf-migration/bundle-files.ts'
'scripts/recovery/dtf-migration/bundle-materialize.ts'
'scripts/recovery/dtf-migration/bundle.test.ts'
'scripts/recovery/dtf-migration/bundle.ts'
'scripts/recovery/dtf-migration/candidate-input.ts'
'scripts/recovery/dtf-migration/candidate-inventory.test.ts'
'scripts/recovery/dtf-migration/candidate-inventory.ts'
'scripts/recovery/dtf-migration/candidate-nfts.ts'
'scripts/recovery/dtf-migration/candidate-proofs.ts'
'scripts/recovery/dtf-migration/candidate-reconciliation.ts'
'scripts/recovery/dtf-migration/candidates.test.ts'
'scripts/recovery/dtf-migration/candidates.ts'
'scripts/recovery/dtf-migration/claim-vault.test.ts'
'scripts/recovery/dtf-migration/claimed-sy-member.ts'
'scripts/recovery/dtf-migration/claimed-sy-source.ts'
'scripts/recovery/dtf-migration/claimed-sy-state.test.ts'
'scripts/recovery/dtf-migration/claimed-sy-state.ts'
'scripts/recovery/dtf-migration/claimed-sy-witness.test.ts'
'scripts/recovery/dtf-migration/claimed-sy-witness.ts'
'scripts/recovery/dtf-migration/claimed-sy.ts'
'scripts/recovery/dtf-migration/cli.ts'
'scripts/recovery/dtf-migration/dtf-custody-se.test.ts'
'scripts/recovery/dtf-migration/earlier-liquid.test.ts'
'scripts/recovery/dtf-migration/earlier-receipt.test.ts'
'scripts/recovery/dtf-migration/execution-deployment.ts'
'scripts/recovery/dtf-migration/execution-domain.test.ts'
'scripts/recovery/dtf-migration/execution-domain.ts'
'scripts/recovery/dtf-migration/execution-owner-bond.ts'
'scripts/recovery/dtf-migration/execution-plan.ts'
'scripts/recovery/dtf-migration/execution-rpc.ts'
'scripts/recovery/dtf-migration/execution-schema.ts'
'scripts/recovery/dtf-migration/execution-state.test.ts'
'scripts/recovery/dtf-migration/execution-state.ts'
'scripts/recovery/dtf-migration/execution.fixture.ts'
'scripts/recovery/dtf-migration/execution.test.ts'
'scripts/recovery/dtf-migration/execution.ts'
'scripts/recovery/dtf-migration/held-se-lp.test.ts'
'scripts/recovery/dtf-migration/journal.ts'
'scripts/recovery/dtf-migration/nft-contributions.test.ts'
'scripts/recovery/dtf-migration/payloads.ts'
'scripts/recovery/dtf-migration/preparation.fixture.ts'
'scripts/recovery/dtf-migration/preparation.test.ts'
'scripts/recovery/dtf-migration/preparation.ts'
'scripts/recovery/dtf-migration/provenance.ts'
'scripts/recovery/dtf-migration/quotes.ts'
'scripts/recovery/dtf-migration/receipt-association.ts'
'scripts/recovery/dtf-migration/receipt-evidence.ts'
'scripts/recovery/dtf-migration/receipt-input.ts'
'scripts/recovery/dtf-migration/receipt-reconciliation.test.ts'
'scripts/recovery/dtf-migration/receipt-reconciliation.ts'
'scripts/recovery/dtf-migration/receipt-rpc.ts'
'scripts/recovery/dtf-migration/receipt.fixture.ts'
'scripts/recovery/dtf-migration/receipt.test.ts'
'scripts/recovery/dtf-migration/rehearsal-admission.ts'
'scripts/recovery/dtf-migration/rehearsal-chain.ts'
'scripts/recovery/dtf-migration/rehearsal-claim-vault-source.ts'
'scripts/recovery/dtf-migration/rehearsal-claim-vault.ts'
'scripts/recovery/dtf-migration/rehearsal-claimed-sy-indirect.ts'
'scripts/recovery/dtf-migration/rehearsal-claimed-sy-intake.ts'
'scripts/recovery/dtf-migration/rehearsal-claimed-sy-local.ts'
'scripts/recovery/dtf-migration/rehearsal-claimed-sy-source.ts'
'scripts/recovery/dtf-migration/rehearsal-claimed-sy-transfer.ts'
'scripts/recovery/dtf-migration/rehearsal-claimed-sy-witness.ts'
'scripts/recovery/dtf-migration/rehearsal-claimed-sy.ts'
'scripts/recovery/dtf-migration/rehearsal-data.ts'
'scripts/recovery/dtf-migration/rehearsal-dtf-custody-se.ts'
'scripts/recovery/dtf-migration/rehearsal-dtf-custody-source.ts'
'scripts/recovery/dtf-migration/rehearsal-earlier-liquid.ts'
'scripts/recovery/dtf-migration/rehearsal-earlier-receipt.ts'
'scripts/recovery/dtf-migration/rehearsal-held-se-lp-source.ts'
'scripts/recovery/dtf-migration/rehearsal-held-se-lp.ts'
'scripts/recovery/dtf-migration/rehearsal-nft-contributions.ts'
'scripts/recovery/dtf-migration/rehearsal-owner-bond.ts'
'scripts/recovery/dtf-migration/rehearsal-portable.ts'
'scripts/recovery/dtf-migration/rehearsal-process.ts'
'scripts/recovery/dtf-migration/rehearsal-proof.ts'
'scripts/recovery/dtf-migration/rehearsal-recovery.ts'
'scripts/recovery/dtf-migration/rehearsal-weighted-liquid.ts'
'scripts/recovery/dtf-migration/rehearsal-weighted-receipt-source.ts'
'scripts/recovery/dtf-migration/rehearsal-weighted-receipt.ts'
'scripts/recovery/dtf-migration/rehearsal-weighted-sy.ts'
'scripts/recovery/dtf-migration/rehearse.ts'
'scripts/recovery/dtf-migration/remaining-claimed-sy.test.ts'
'scripts/recovery/dtf-migration/schema.ts'
'scripts/recovery/dtf-migration/weighted-liquid.test.ts'
'scripts/recovery/dtf-migration/weighted-receipt.test.ts'
'scripts/recovery/dtf-migration/weighted-sy.test.ts'
)
run() {
  local name="$1"; shift
  local dir="$E/$name"
  mkdir "$dir" || exit 91
  printf '%s\0' "$@" > "$dir/argv.nul"
  printf '%q ' "$@" > "$dir/command.txt"; printf '\n' >> "$dir/command.txt"
  pwd > "$dir/cwd.txt"
  date -u '+%Y-%m-%dT%H:%M:%SZ' > "$dir/started.txt"
  shasum -a 256 "${sources[@]}" > "$dir/source-before.sha256" || exit 92
  "$@" > "$dir/stdout.log" 2> "$dir/stderr.log"
  local code=$?
  printf '%s\n' "$code" > "$dir/exit.txt"
  date -u '+%Y-%m-%dT%H:%M:%SZ' > "$dir/finished.txt"
  shasum -a 256 "${sources[@]}" > "$dir/source-after.sha256" || exit 93
  if [ "$code" -ne 0 ]; then status=1; fi
  printf 'PREPARED_FIXTURE_RESULT %s exit=%s\n' "$name" "$code"
}
run 00-bun-path /usr/bin/which bun
run 00-bun-version bun --version
run 00-bun-revision bun --revision
run 00-ts-version bun node_modules/typescript/bin/tsc --version
run 01-focused env "TASK12_EVIDENCE=$E/01-focused" bun test --timeout 15000 ./scripts/recovery/dtf-migration/bundle.test.ts -t 'complete mixed A-SY/B-configuration|default validate on a relocated retained-A|omitting old configured SY'
tests=(./scripts/recovery/dtf-migration/*.test.ts)
run 02-full-tests bun test --timeout 15000 "${tests[@]}"
operators=(scripts/recovery/dtf-migration/*.ts)
run 03-operator-types bun node_modules/typescript/bin/tsc --noEmit --target ES2022 --module ESNext --moduleResolution Bundler --strict --noUncheckedIndexedAccess --exactOptionalPropertyTypes --verbatimModuleSyntax --skipLibCheck --types node "${operators[@]}"
manual_code='import assert from "node:assert/strict";
import { readFile, writeFile, access } from "node:fs/promises";
import { join } from "node:path";
import { mixedFixture } from "./docs/incidents/2026-09-16-dtf-recovery/migration/conformance-20261114/task-12/mixed-fixture.ts";
import { main } from "./scripts/recovery/dtf-migration/cli.js";
import { exportBundle } from "./scripts/recovery/dtf-migration/bundle.js";
import { readBundle } from "./scripts/recovery/dtf-migration/bundle-files.js";
import { materializeBundle } from "./scripts/recovery/dtf-migration/bundle-materialize.js";
import { assemble, normalize } from "./scripts/recovery/dtf-migration/preparation.js";
import { loadExecution, compensationEventTopics } from "./scripts/recovery/dtf-migration/execution-domain.js";
import { canonical, fingerprint } from "./scripts/recovery/dtf-migration/provenance.js";
const f = await mixedFixture();
const commands = [];
const cli = async (argv) => { console.log(canonical({kind:"cli-start",argv})); await main(argv); commands.push({argv,status:"returned"}); };
try {
  const native = await loadExecution(f.manifestPath);
  const query = {address:native.manifest.proxy,fromBlock:"0x"+BigInt(native.manifest.deploymentBlockNumber).toString(16),toBlock:"latest",topics:[compensationEventTopics(native.abis.migration,"configuration")]};
  const rows = f.changes.logs.get(canonical(query));
  assert.ok(rows); assert.equal(rows.length,3);
  const responseBefore = canonical(rows);
  const completeBundle = await exportBundle(f.manifestPath,join(f.root,"manual-complete-bundle"));
  const saved = await readBundle(completeBundle);
  const originals = await Promise.all(saved.manifest.files.map(async item => { const raw = await readFile(item.originalPath); return {...item,sha256:fingerprint(raw),rawBase64:raw.toString("base64")}; }));
  const complete = await materializeBundle(completeBundle,join(f.root,"manual-complete-relocated"));
  assert.equal(complete.kind,"execution");
  const completeDomain = await loadExecution(complete.manifest);
  await cli(["validate","--manifest",completeDomain.manifest.preparedManifest]);
  await cli(["verify","--manifest",complete.manifest,"--checkpoint",join(f.root,"complete-must-not-create")]);
  const omitted = assemble(normalize({...f.finalPrepared.input,weightedSy:[],exposures:f.finalPrepared.input.exposures.filter(r=>r.category!=="weighted-sy")}),f.finalPrepared.quoteEvidence);
  const prepared = await f.save("manual-omitted-sy-prepared.json",omitted);
  const execution = await f.save("manual-omitted-sy-execution.json",{...native.manifest,preparedManifest:prepared.path});
  const omittedBundle = await exportBundle(execution.path,join(f.root,"manual-omitted-sy-bundle"));
  const relocated = await materializeBundle(omittedBundle,join(f.root,"manual-omitted-sy-relocated"));
  assert.equal(relocated.kind,"execution");
  const negativeArgv = ["verify","--manifest",relocated.manifest,"--checkpoint",join(f.root,"omitted-must-not-create")];
  let rejection;
  console.log(canonical({kind:"cli-start",argv:negativeArgv}));
  try { await main(negativeArgv); } catch (error) { if (!(error instanceof Error)) throw error; assert.match(error.message,/configured original omitted from complete deployment census/); rejection={name:error.name,message:error.message}; }
  assert.ok(rejection); commands.push({argv:negativeArgv,status:"expected-throw",rejection});
  assert.equal(canonical(f.changes.logs.get(canonical(query))),responseBefore);
  for (const original of originals) assert.equal(fingerprint(await readFile(original.originalPath)),original.sha256);
  assert.equal(f.methods.includes("eth_getTransactionCount"),false); assert.equal(f.methods.includes("eth_sendRawTransaction"),false);
  const result = {scope:"Synthetic task-12 loopback transport; production CLI main invoked in-process; no EVM or public RPC",query,responseRows:rows,responseSha256:fingerprint(responseBefore),responseRowsUnchanged:true,commands,completeRelocated:{manifest:complete.manifest,prepared:completeDomain.manifest.preparedManifest,status:"validate-and-verify-returned"},omittedRelocated:{manifest:relocated.manifest,status:"rejected",rejection},originalInputs:originals,originalInputsUnchanged:true,methods:f.methods,limits:["Expected rejection is a thrown production CLI error, not a separate process exit.","No live census, Anvil transaction, activation or readiness proof."]};
  await writeFile(join(process.env.PREPARED_FIXTURE_EVIDENCE,"result.json"),JSON.stringify(result,null,2)+"\n",{flag:"wx"});
  console.log(canonical({kind:"manual-complete",complete:"accepted",omitted:"rejected",responseRows:rows.length,originalInputs:originals.length,noSends:true}));
} finally { await f.close(); console.log(canonical({kind:"cleanup",fixtureRoot:f.root,closed:true})); }
'
run 04-manual env "PREPARED_FIXTURE_EVIDENCE=$E/04-manual" bun --eval "$manual_code"
printf '%s\n' "$status" > "$E/overall.exit.txt"
printf 'PREPARED_FIXTURE_COMPLETE exit=%s\n' "$status"
exit "$status"
