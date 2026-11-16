import { test } from "node:test";
import assert from "node:assert/strict";
import { mkdtemp, mkdir, writeFile, rm, realpath } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { loadCandidateInput, optionalInteger, parseCandidateCsv, unique } from "./candidate-input.js";
import type { CandidateInput } from "./candidate-input.js";
import { deriveNfts, legacy } from "./candidate-nfts.js";
import { quantityUnit } from "./candidate-inventory.js";
import { canonical, fingerprint } from "./provenance.js";
import { preparationInput } from "./schema.js";
import { executionManifest } from "./execution-schema.js";
import { preparedEnvelope } from "./bundle.js";
import { main } from "./cli.js";

const wallet = `0x${"1".repeat(40)}`;
const other = `0x${"2".repeat(40)}`;
const tx = `0x${"a".repeat(64)}`;
const csv = (header: readonly string[], rows: readonly (readonly string[])[]): string =>
  [header, ...rows].map((r) => r.map((v) => `"${v.replaceAll('"', '""')}"`).join(",")).join("\n") + "\n";
const purchaseHeader = ["token_id", "purchase_tx", "purchase_recipient", "current_owner", "purchase_block", "pre_attack", "original_principal_detf_raw"];
const transferHeader = ["event_id", "block", "transaction_index", "log_index", "tx", "asset", "from", "to", "amount_raw", "token_id"];
const detailHeader = ["tx", "category", "bond_token_id", "dtf_wei", "payer", "bond_recipient"];
const cpHeader = ["token_id", "owner", "original_lp_shares_raw", "direct_dtf_paid_raw", "direct_weth_paid_raw", "routed_dtf_received_by_detf_raw", "purchase_tx"];
function nftInput(shared = false): CandidateInput {
  const event = (asset: string, log: string, from: string, to: string, amount: string, id = ""): readonly string[] =>
    [`${asset}:${tx}:${log}`, "10", "1", log, tx, asset, from, to, amount, id];
  const inputs = new Map([
    ["evidence/weighted-bonds.csv", csv(purchaseHeader, [
      ["3", tx, wallet, other, "10", "true", "7"],
      ...(shared ? [["4", tx, wallet, wallet, "10", "true", "8"]] : []),
    ])],
    ["evidence/earlier-cp-bonds.csv", csv(cpHeader, [["3", wallet, "234", "0", "80", "987654321", tx]])],
    ["evidence/transfers.csv", csv(transferHeader, [
      event(legacy.weightedNft, "2", legacy.zero, wallet, "", "3"),
      event(legacy.dtf, "3", wallet, legacy.weighted, "90071992547409931234"),
      event(legacy.dtf, "4", wallet, legacy.weighted, "6"),
      event(legacy.weth, "5", wallet, legacy.weighted, "80"),
      ...(shared ? [event(legacy.weightedNft, "6", legacy.zero, wallet, "", "4")] : []),
    ])],
    ["../2026-09-16-dtf-pre-exploit/dtf-sold-to-detf-details.csv", csv(detailHeader, [[tx, "bond", "3", "90071992547409931240", wallet, wallet]])],
  ]);
  return { sources: { chainId: 4663, incident: { lastFullBlock: 19, attackBlock: 20, attackTransactionIndex: 1, attackTransaction: tx },
    evidenceCutoff: { block: 30, hash: tx, utc: "historical" }, sourceNotes: [], sources: [] },
    bindings: [], bytes: new Map([...inputs].map(([p, t]) => [p, Buffer.from(t)])) };
}
test("joins exact multiple asset inputs to one collection ID and preserves observations", () => {
  const nfts = deriveNfts(nftInput());
  const weighted = nfts.find((n) => n.model === "fixed-principal");
  assert.ok(weighted);
  assert.deepEqual(weighted.directInputs.map((i) => i.attributedRaw), ["90071992547409931240", "80"]);
  assert.equal(weighted.mintLocators.length, 1);
  assert.equal(weighted.corroboratingLocators.length, 1);
  assert.equal(weighted.recipientObservation, wallet);
  assert.equal(weighted.currentOwnerObservation, other);
  assert.notEqual(nfts[0]?.key, nfts[1]?.key);
});
test("shared purchase transactions never attribute their entire input to each NFT", () => {
  const weighted = deriveNfts(nftInput(true)).filter((n) => n.model === "fixed-principal");
  assert.equal(weighted.length, 2);
  for (const n of weighted) {
    assert.ok(n.flags.includes("ambiguous-transaction-sharing"));
    assert.deepEqual(n.directInputs.map((i) => i.attributedRaw), [null, null]);
  }
});
test("payer conflicts remain unresolved instead of being assigned to the recipient", () => {
  const input = nftInput();
  const raw = input.bytes.get("evidence/transfers.csv");
  assert.ok(raw);
  const changed = Buffer.from(new TextDecoder().decode(raw).replaceAll(`"${wallet}","${legacy.weighted}"`, `"${other}","${legacy.weighted}"`));
  const nfts = deriveNfts({ ...input, bytes: new Map([...input.bytes, ["evidence/transfers.csv", changed]]) });
  assert.deepEqual(nfts.find((n) => n.model === "fixed-principal")?.directInputs.map((i) => i.attributedRaw), [null, null]);
});
test("earlier LP accounting shares keep direct WETH distinct from routed DTF and missing receipts", () => {
  const cp = deriveNfts(nftInput()).find((n) => n.model === "lp-accounting-lock");
  assert.ok(cp);
  assert.deepEqual(cp.directInputs.map((i) => i.observedRaw), ["0", "80"]);
  assert.equal(cp.routedDtfRaw, "987654321");
  assert.equal(cp.basis.value, "234");
  assert.ok(cp.flags.includes("original-raw-receipts-missing"));
  assert.deepEqual(cp.directInputs.map((i) => i.attributedRaw), [null, null]);
});
test("unknown integer is distinct from observed zero and rejects decimal or malformed encodings", () => {
  assert.equal(optionalInteger(""), null);
  assert.equal(optionalInteger("0"), "0");
  for (const value of ["-1", "1.5", "1e18", " 0", "00", "NaN"]) assert.throws(() => optionalInteger(value), /malformed unsigned/);
});
test("CSV parser preserves quoted delimiters and rejects truncation, bad widths and duplicate keys", () => {
  const rows = parseCandidateCsv('id,note\nx,"a,b\nc"\n', "observed.csv");
  assert.equal(rows[0]?.fields["note"], "a,b\nc");
  for (const raw of ['id,note\nx,"unclosed', "id,note\nx\n", "id,id\nx,y\n"]) assert.throws(() => parseCandidateCsv(raw, "bad.csv"));
  assert.throws(() => unique(parseCandidateCsv("id\nx\nx\n", "dup.csv"), "id"), /duplicate/);
});
test("source units distinguish native19 vault shares, native28 SE, raw weights, gons and accounting LP", () => {
  const row = parseCandidateCsv("asset,decimals,kind\nvault,19,legacy_weight_to_sy\n", "positions.csv")[0];
  assert.ok(row);
  assert.equal(quantityUnit(row, "quantity_raw"), "vault:native19");
  assert.equal(quantityUnit({ ...row, fields: { ...row.fields, decimals: "28" } }, "quantity_raw"), "vault:native28");
  assert.equal(quantityUnit(row, "principal_raw"), "raw-weight-native18");
  assert.equal(quantityUnit(row, "staking_gons"), "gons");
  assert.equal(quantityUnit(row, "original_lp_shares_raw"), "LP-accounting-shares-not-physical-LP");
});
test("candidate documents are unsupported by every live input schema and preparation CLI", async () => {
  const candidate = { version: "dtf-historical-review-candidates-v1", status: "NON-ISSUABLE-REVIEW-CANDIDATES", nfts: deriveNfts(nftInput()) };
  for (const schema of [preparationInput, executionManifest, preparedEnvelope]) assert.equal(schema.safeParse(candidate).success, false);
  const dir = await mkdtemp(join(tmpdir(), "dtf-candidate-rejection-"));
  try {
    const path = join(dir, "candidates.json");
    await writeFile(path, canonical(candidate));
    await assert.rejects(main(["prepare", "--input", path, "--output", join(dir, "out")]), { name: "ZodError" });
    await assert.rejects(main(["validate", "--manifest", path]), { name: "ZodError" });
  } finally { await rm(dir, { recursive: true }); }
});
test("all declared bytes authenticate before malformed raw CSV parsing and fail closed on missing files", async () => {
  const parent = await mkdtemp(join(await realpath(tmpdir()), "dtf-candidate-bindings-"));
  const dir = join(parent, "recovery"); await mkdir(dir);
  const raw = '"unclosed';
  const sources = { ...nftInput().sources, sources: [{ id: "S001", path: "raw.csv", description: "raw", bytes: Buffer.byteLength(raw), sha256: fingerprint(raw) }] };
  const sourceText = canonical(sources);
  await writeFile(join(dir, "sources.json"), sourceText);
  await writeFile(join(dir, "manifest.json"), canonical({ files: {
    "sources.json": { bytes: Buffer.byteLength(sourceText), sha256: fingerprint(sourceText) },
    "prose.md": { bytes: 8, sha256: fingerprint("original") },
  } }));
  await writeFile(join(dir, "raw.csv"), raw);
  await writeFile(join(dir, "prose.md"), "changed!");
  try {
    await assert.rejects(loadCandidateInput(dir), /raw binding differs: prose.md/);
    await writeFile(join(dir, "prose.md"), "original");
    const authenticated = await loadCandidateInput(dir);
    assert.equal(authenticated.bindings.length, 3);
    await rm(join(dir, "raw.csv"));
    await assert.rejects(loadCandidateInput(dir), { code: "ENOENT" });
  } finally { await rm(parent, { recursive: true }); }
});
test("offline candidate command rejects signing, broadcast and duplicate input flags", async () => {
  for (const extra of [["--broadcast"], ["--execute-local"], ["--input", "other"]])
    await assert.rejects(main(["derive-candidates", "--input", "raw", "--output", "new", ...extra]), /requires only|duplicate/);
});
