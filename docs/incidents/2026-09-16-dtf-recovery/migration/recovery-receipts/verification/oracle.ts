import assert from "node:assert/strict";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { writeFile } from "node:fs/promises";
import { z } from "zod";
import { authenticate, body, bound, csv, digest, field, identity, inputRoot, json, rawArchive } from "./raw.js";
import { loadCandidateInput } from "../../../../../../scripts/recovery/dtf-migration/candidate-input.js";
import { preparationInput } from "../../../../../../scripts/recovery/dtf-migration/schema.js";
import { preparedEnvelope } from "../../../../../../scripts/recovery/dtf-migration/bundle.js";
import { executionManifest } from "../../../../../../scripts/recovery/dtf-migration/execution-schema.js";

const evidence = dirname(fileURLToPath(import.meta.url));
const root = resolve(evidence, "../../../../../..");
const inputs = await authenticate();
const originalSourcesDocument = z.object({ chainId: z.unknown(), incident: z.unknown(), evidenceCutoff: z.unknown(),
  sourceNotes: z.unknown(), sources: z.unknown(), policyRevision: z.string() }).strict()
  .parse(await json(join(inputRoot, "sources.json")));
const { policyRevision, ...normalizedSourcesDocument } = originalSourcesDocument;
const loader = await loadCandidateInput(inputRoot);
assert.equal(loader.bindings.length, inputs.declarations.length);
for (const d of loader.bindings) await bound(inputRoot, d);
const readTable = async (path: string) => csv(await body(resolve(inputRoot, path)), path);
const conversions = await readTable("conversions.csv"), recoveries = await readTable("observed-recoveries.csv");
const rows = [...conversions, ...recoveries].sort((a, b) => a.locator.localeCompare(b.locator));
const transfers = await readTable("evidence/transfers.csv");
const hashes = [...new Set(rows.map((r) => field(r, "tx").toLowerCase()))].sort();
const oldHashes = new Set([
  ...await readTable("evidence/weighted-bonds.csv"), ...await readTable("evidence/earlier-cp-bonds.csv"),
].map((r) => field(r, "purchase_tx").toLowerCase()));
for (const row of conversions) if (field(row, "kind") === "legacy_weight_to_sy") oldHashes.add(field(row, "tx").toLowerCase());
const old = z.object({ results: z.array(z.object({ tx: z.string() })) }).parse(await json(
  "/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-28-receipt-evidence/docs/incidents/2026-09-16-dtf-recovery/migration/receipt-evidence/verification/actual/archive.json"));
assert.deepEqual([...oldHashes].sort(), old.results.map((r) => r.tx).sort());
const kinds = Object.fromEntries([...new Set(conversions.map((r) => field(r, "kind")))]
  .map((kind) => [kind, conversions.filter((r) => field(r, "kind") === kind).length]));
const qualifications = ["native-token-units-not-ETH-C0-or-current-value",
  "internal-conversion-label-not-compensation-status", "gross-output-not-net-contribution",
  "principal-rewards-and-transaction-totals-not-allocated", "prior-compensation-unknown-not-zero",
  "no-entitlement-transfer-or-current-control-proved", "known-output-only-not-full-W0-or-Q0", "no-eligibility-or-source-admission"];
type Transfer = { readonly address: string; readonly from: string; readonly to: string;
  readonly logIndex: string; readonly amount: string | null; readonly tokenId: string | null };
const report = [];
for (const lane of ["implementation", "verification"]) {
  const directory = join(evidence, "..", lane, "actual");
  const raw = await rawArchive(directory, hashes);
  const archive = z.object({ results: z.array(z.unknown()), inputs: identity, http: identity, reconciliation: identity,
    references: z.number(), distinctTransactions: z.number(), completeAssociations: z.number(),
    referenceConflicts: z.number(), authenticated: z.literal(true), chainId: z.literal("4663"),
    provider: z.literal("robinhood_mainnet_alchemy"), selection: z.literal("conversions-and-recoveries"),
    status: z.literal("NON-ISSUABLE-RECEIPT-OBSERVATIONS"), version: z.literal("dtf-finite-receipt-evidence-v1"),
  }).passthrough().parse(await json(join(directory, "archive.json")));
  for (const b of [archive.inputs, archive.http, archive.reconciliation]) await bound(directory, b);
  const archivedInputs = z.object({ identities: z.array(identity), declarations: z.array(identity.extend({ declaration: z.string() })),
    sources: z.unknown() }).parse(await json(join(directory, "inputs.json")));
  assert.deepEqual(archivedInputs.sources, normalizedSourcesDocument);
  assert.deepEqual(archivedInputs.declarations.map(({ path, bytes, sha256, declaration }) => ({ path, bytes, sha256, declaration })),
    inputs.declarations.map(({ path, bytes, sha256, declaration }) => ({ path, bytes, sha256, declaration })));
  assert.deepEqual(archivedInputs.identities.map((b) => b.path).sort(), [...inputs.paths].sort());
  for (const b of archivedInputs.identities) await bound(inputRoot, b);
  const refs = z.object({ refs: z.array(z.unknown()), requests: z.array(z.unknown()),
    selection: z.literal("conversions-and-recoveries") }).parse(await json(join(directory, "references.json")));
  const reconciliation = z.array(z.unknown()).parse(await json(join(directory, "reconciliation.json")));
  const reviews = [], expectedReferences = [], expectedResults = [];
  let savedMatches = 0;
  for (const row of rows) {
    const f = (name: string) => field(row, name), recovery = row.path === "observed-recoveries.csv";
    const kind = recovery ? "recovery" : "conversion", txHash = f("tx").toLowerCase();
    const rawObserved = raw.observations.get(txHash); assert.ok(rawObserved);
    const { requestIds, ...observed } = rawObserved;
    const { transaction: tx, receipt } = observed;
    const asset = f(recovery ? "asset" : "output_asset").toLowerCase(), recipient = f("recipient").toLowerCase();
    const amountText = f(recovery ? "observed_amount_raw" : "output_raw");
    const amount = amountText === "" ? null : amountText;
    const decimals = f(recovery ? "decimals" : "output_decimals"), logIndex = recovery ? f("log_index") : null;
    for (const number of [amount, decimals, f("block"), logIndex]) if (number !== null) assert.match(number, /^(0|[1-9][0-9]*)$/);
    const expectedTransfers = transfers.filter((r) => field(r, "tx").toLowerCase() === txHash
      && field(r, "asset").toLowerCase() === asset && field(r, "to").toLowerCase() === recipient
      && (logIndex === null || field(r, "log_index") === logIndex));
    const decoded = receipt.logs.flatMap<Transfer>((l) => {
      if (l.topics[0] !== "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef") return [];
      const [from, to] = l.topics.slice(1, 3);
      if (!from || !to || !/^0x0{24}[0-9a-f]{40}$/.test(from) || !/^0x0{24}[0-9a-f]{40}$/.test(to)) return [];
      const base = { address: l.address, from: `0x${from.slice(-40)}`, to: `0x${to.slice(-40)}`,
        logIndex: BigInt(l.logIndex).toString() };
      if (l.topics.length === 3 && /^0x[0-9a-f]{64}$/.test(l.data)) return [{ ...base, amount: BigInt(l.data).toString(), tokenId: null }];
      const token = l.topics[3];
      if (l.topics.length === 4 && l.data === "0x" && token) return [{ ...base, amount: null, tokenId: BigInt(token).toString() }];
      return [];
    });
    const candidates = decoded.filter((t) => t.amount !== null && t.address === asset && t.to === recipient);
    const outputs = candidates.filter((t) => amount !== null && t.amount === amount && (logIndex === null || t.logIndex === logIndex));
    const conflicts: string[] = [];
    for (const saved of expectedTransfers) {
      const matches = decoded.filter((t) => t.address === field(saved, "asset").toLowerCase() && t.logIndex === field(saved, "log_index"));
      const t = matches[0];
      if (matches.length !== 1 || !t || t.from !== field(saved, "from").toLowerCase() || t.to !== field(saved, "to").toLowerCase()
        || (t.amount ?? "") !== field(saved, "amount_raw") || (t.tokenId ?? "") !== field(saved, "token_id")
        || BigInt(tx.blockNumber).toString() !== field(saved, "block")
        || BigInt(tx.transactionIndex).toString() !== field(saved, "transaction_index")) conflicts.push(`saved-transfer-conflict:${saved.locator}`);
      else savedMatches++;
    }
    if (amount === null) conflicts.push("unknown-output-amount");
    if (outputs.length === 0) conflicts.push("missing-exact-output");
    if (outputs.length > 1) conflicts.push("ambiguous-exact-output");
    if (BigInt(tx.blockNumber).toString() !== f("block")) conflicts.push("declared-output-block");
    const transactionRefs = rows.filter((r) => field(r, "tx").toLowerCase() === txHash).map((r) => r.locator);
    if (transactionRefs.length > 1) conflicts.push("shared-transaction-output-attribution-unresolved");
    const expected = { locator: row.locator, kind, tx: txHash, historicalFields: row.fields,
      transactionContext: { from: tx.from, to: tx.to, value: BigInt(tx.value).toString(), calldata: tx.input,
        block: BigInt(tx.blockNumber).toString(), transactionIndex: BigInt(tx.transactionIndex).toString() },
      savedTransferLocators: expectedTransfers.map((r) => r.locator), conflicts, candidates, outputs,
      expectedOutput: { asset, recipient, amount, decimals, block: f("block"), logIndex },
      status: "reviewed-observations-only", priorCompensation: null, compensationDeduction: null,
      currentCustody: null, qualifications };
    assert.deepEqual(reconciliation[reviews.length], expected, `${lane}:${row.locator}`);
    reviews.push(expected);
    expectedReferences.push({ kind, row, tx: txHash, recipient, asset, amount, decimals,
      expectedBlock: f("block"), logIndex, expectedTransfers });
    if (recovery) {
      assert.equal(f("classification"), "detf_exchange_output"); assert.equal(f("deduct_from_R"), "false");
      assert.equal(f("R_eth"), ""); assert.equal(decimals, "18");
    } else assert.equal(f("is_external_recovery"), "false");
    const result = { tx: txHash, references: transactionRefs, conflicts: [], requestIds, observed,
      transactionObservation: tx, receiptObservation: receipt };
    assert.deepEqual(await json(join(directory, `${txHash}.json`)), result);
  }
  for (const h of hashes) {
    const o = raw.observations.get(h); assert.ok(o);
    const { requestIds, ...observed } = o;
    expectedResults.push({ tx: h, references: rows.filter((r) => field(r, "tx").toLowerCase() === h).map((r) => r.locator),
      conflicts: [], requestIds, observed, transactionObservation: o.transaction, receiptObservation: o.receipt });
  }
  assert.deepEqual(archive.results, expectedResults);
  assert.deepEqual(refs.refs, expectedReferences);
  assert.deepEqual(refs.requests, expectedResults.map(({ tx, references }) => ({ tx, references })));
  assert.equal(reconciliation.length, rows.length); assert.equal(archive.references, rows.length);
  assert.equal(archive.distinctTransactions, hashes.length); assert.equal(archive.completeAssociations, hashes.length);
  assert.equal(archive.referenceConflicts, reviews.filter((r) => r.conflicts.length).length);
  for (const schema of [preparationInput, preparedEnvelope, executionManifest]) assert.equal(schema.safeParse(archive).success, false);
  report.push({ lane, archiveIdentity: digest(await body(join(directory, "archive.json"))),
    rawCaptures: raw.captures, logs: raw.logs, canonicalAssociations: raw.observations.size,
    savedMatches, reviews, operationalSchemasReject: true, actualFailures: [], unavailable: [],
    redacted: [], conflicts: reviews.filter((r) => r.conflicts.length) });
}
const proof = { status: "independently-reconciled-observations-only", inputRoot, declarations: inputs.declarations,
  originalSourcesDocument, normalizationQualification: { omittedFromParsedSourceIndex: "policyRevision", originalValue: policyRevision,
    rawSourceBodyAuthenticated: true, rowFieldsPreserved: true, policyAuthority: "current plan r5 and PRD r22, not this historical field" },
  inputIdentities: await Promise.all(inputs.paths.map(async (path) => ({ path, ...digest(await body(resolve(inputRoot, path))) }))),
  conversions: conversions.length, recoveries: recoveries.length, distinctTransactions: hashes.length, kinds,
  maxDeclaredBlock: rows.reduce((max, r) => Math.max(max, Number(field(r, "block"))), 0),
  previousArchiveTransactions: oldHashes.size, overlap: rows.filter((r) => oldHashes.has(field(r, "tx").toLowerCase())).map((r) => r.locator),
  missingPreviously: hashes.filter((h) => !oldHashes.has(h)).length, archives: report,
  sourceRoot: root, importsQualification: "Existing loader and intake schemas only; raw CSV/RPC/canonical/output algorithms import no producer collector, association or reconciliation." };
await writeFile(join(evidence, "proof.json"), JSON.stringify(proof, null, 2) + "\n", { flag: "wx" });
console.log(JSON.stringify({ conversions: proof.conversions, recoveries: proof.recoveries, kinds,
  transactions: hashes.length, lanes: report.map((r) => ({ lane: r.lane, logs: r.logs, savedMatches: r.savedMatches,
    rawResponses: r.rawCaptures.length, conflicts: r.conflicts.length })) }));
