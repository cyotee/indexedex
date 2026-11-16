import { test } from "node:test";
import assert from "node:assert/strict";
import { mkdtemp, rm, realpath } from "node:fs/promises";
import { join } from "node:path";
import { tmpdir } from "node:os";
import { id } from "ethers";
import { loadCandidateInput } from "./candidate-input.js";
import { receiptReferences, legacy } from "./receipt-input.js";
import { reconcileReference } from "./receipt-reconciliation.js";
import { inputFixture, purchaseTx, purchaseReceipt, purchaseBlock, wallet, claimTx, claimReceipt } from "./receipt.fixture.js";
import { preparationInput } from "./schema.js";
import { preparedEnvelope } from "./bundle.js";
import { executionManifest } from "./execution-schema.js";

const observation = { transaction: purchaseTx, receipt: purchaseReceipt, byHash: purchaseBlock, byNumber: purchaseBlock };
async function nftReference() {
  const parent = await mkdtemp(join(await realpath(tmpdir()), "dtf-reconcile-"));
  try {
    const input = await loadCandidateInput(await inputFixture(parent));
    const ref = receiptReferences(input).find((r) => r.kind === "nft");
    assert.ok(ref && ref.kind === "nft");
    return ref;
  } finally { await rm(parent, { recursive: true }); }
}
test("source purchase basis is independently required in addition to the mint", async () => {
  const ref = await nftReference();
  const changed = { ...observation, receipt: { ...purchaseReceipt, logs: purchaseReceipt.logs.filter((l) =>
    l.topics[0] !== id("BondPurchased(uint256,address,uint256,uint256,uint256)")) } };
  const result = reconcileReference(ref, changed, 1);
  assert.ok(result.conflicts.includes("source-purchase-event-or-basis"));
  assert.equal("assets" in result && result.assets[0]?.attributableDirect, null);
});
test("routed input stays separate and cannot be attributed as a direct contribution", async () => {
  const ref = await nftReference();
  const direct = purchaseReceipt.logs.find((l) => l.address === legacy.dtf); assert.ok(direct);
  const routed = { ...direct, logIndex: "0x4", data: `0x${(999n).toString(16).padStart(64, "0")}`,
    topics: [id("Transfer(address,address,uint256)"), `0x${"2".repeat(40).padStart(64, "0")}`,
      `0x${legacy.weighted.slice(2).padStart(64, "0")}`] };
  const result = reconcileReference(ref, { ...observation, receipt: { ...purchaseReceipt, logs: [...purchaseReceipt.logs, routed] } }, 1);
  assert.ok("assets" in result);
  assert.equal(result.assets[0]?.observedDirect, "12");
  assert.equal(result.assets[0]?.observedRouted, "999");
  assert.equal(result.assets[0]?.attributableDirect, "12");
});
test("a shared transaction never assigns its entire direct inputs to each original", async () => {
  const result = reconcileReference(await nftReference(), observation, 2);
  assert.ok(result.conflicts.includes("shared-or-multiaction-purchase"));
  assert.ok("assets" in result);
  assert.deepEqual(result.assets.map((a) => a.attributableDirect), [null, null]);
});
test("canonical association conflicts prohibit otherwise matching input attribution", async () => {
  const result = reconcileReference(await nftReference(), { ...observation,
    byNumber: { ...purchaseBlock, hash: `0x${"9".repeat(64)}` } }, 1);
  assert.ok(result.conflicts.includes("block-hash"));
  assert.ok("assets" in result);
  assert.deepEqual(result.assets.map((a) => a.attributableDirect), [null, null]);
});
test("wrong mint recipient is a conflict even with matching direct payment", async () => {
  const ref = await nftReference(), mint = purchaseReceipt.logs[0]; assert.ok(mint);
  const changed = { ...mint, topics: [...mint.topics.slice(0, 2), `0x${"2".repeat(40).padStart(64, "0")}`, ...mint.topics.slice(3)] };
  const result = reconcileReference(ref, { ...observation,
    receipt: { ...purchaseReceipt, logs: [changed, ...purchaseReceipt.logs.slice(1)] } }, 1);
  assert.ok(result.conflicts.includes("mint-recipient-or-id"));
});
test("indirect calls retain calldata and never receive direct claim decoding", async () => {
  const parent = await mkdtemp(join(await realpath(tmpdir()), "dtf-indirect-"));
  try {
    const ref = receiptReferences(await loadCandidateInput(await inputFixture(parent))).find((r) => r.kind === "claim");
    assert.ok(ref);
    const result = reconcileReference(ref, { ...observation, transaction: { ...purchaseTx, from: wallet,
      input: `0x12345678${"0".repeat(64)}` } }, 1);
    assert.ok("decodedDirectWeight" in result);
    assert.equal(result.decodedDirectWeight, null);
    assert.ok(result.conflicts.includes("indirect-or-unexpected-claim-call"));
    assert.equal(result.transactionContext.calldata, `0x12345678${"0".repeat(64)}`);
  } finally { await rm(parent, { recursive: true }); }
});
test("receipt archive format cannot enter preparation, validation or execution loaders", () => {
  const archive = { version: "dtf-finite-receipt-evidence-v1", status: "NON-ISSUABLE-RECEIPT-OBSERVATIONS" };
  for (const schema of [preparationInput, preparedEnvelope, executionManifest]) assert.equal(schema.safeParse(archive).success, false);
});
async function outputReferences() {
  const parent = await mkdtemp(join(await realpath(tmpdir()), "dtf-output-"));
  try {
    return receiptReferences(await loadCandidateInput(await inputFixture(parent)), "conversions-and-recoveries");
  } finally { await rm(parent, { recursive: true }); }
}
test("conversion reconciliation preserves exact native output and blank historical principal", async () => {
  const ref = (await outputReferences()).find((r) => r.kind === "conversion" && r.tx === purchaseTx.hash);
  assert.ok(ref);
  const result = reconcileReference(ref, observation, 1);
  assert.ok("expectedOutput" in result);
  assert.equal(result.expectedOutput.amount, "12");
  assert.equal(result.expectedOutput.decimals, "18");
  assert.equal(result.historicalFields["principal_raw"], "");
  assert.equal(result.outputs.length, 1);
  assert.deepEqual(result.conflicts, []);
  assert.equal(result.compensationDeduction, null);
});
test("conversion ambiguity retains individual matches and never assigns aggregate output", async () => {
  const ref = (await outputReferences()).find((r) => r.kind === "conversion" && r.tx === purchaseTx.hash);
  assert.ok(ref);
  const output = purchaseReceipt.logs[1]; assert.ok(output);
  const result = reconcileReference(ref, { ...observation,
    receipt: { ...purchaseReceipt, logs: [...purchaseReceipt.logs, { ...output, logIndex: "0x4" }] } }, 2);
  assert.ok("outputs" in result);
  assert.equal(result.outputs.length, 2);
  assert.ok(result.conflicts.includes("ambiguous-exact-output"));
  assert.ok(result.conflicts.includes("shared-transaction-output-attribution-unresolved"));
});
test("unknown output remains null and missing rather than matching a zero transfer", async () => {
  const ref = (await outputReferences()).find((r) => r.kind === "conversion");
  assert.ok(ref && ref.kind === "conversion");
  const result = reconcileReference({ ...ref, amount: null }, observation, 1);
  assert.ok("expectedOutput" in result);
  assert.equal(result.expectedOutput.amount, null);
  assert.equal(result.outputs.length, 0);
  assert.ok(result.conflicts.includes("unknown-output-amount"));
});
for (const [label, change] of [
  ["asset", { asset: legacy.dtf }], ["recipient", { recipient: legacy.weighted }],
  ["amount", { amount: "10" }], ["index", { logIndex: "2" }],
  ["block", { expectedBlock: "12" }],
] as const) test(`recovery matching requires the exact declared ${label}`, async () => {
  const ref = (await outputReferences()).find((r) => r.kind === "recovery");
  assert.ok(ref && ref.kind === "recovery");
  const b = { ...purchaseBlock, hash: claimTx.blockHash, number: "0xb", transactions: [claimTx.hash] };
  const result = reconcileReference({ ...ref, ...change }, {
    transaction: claimTx, receipt: claimReceipt, byHash: b, byNumber: b,
  }, 1);
  assert.ok(result.conflicts.includes(label === "block" ? "declared-output-block" : "missing-exact-output"));
});
test("conversion canonical contradiction remains a conflict with a matching output", async () => {
  const ref = (await outputReferences()).find((r) => r.kind === "conversion" && r.tx === purchaseTx.hash);
  assert.ok(ref);
  const result = reconcileReference(ref, { ...observation, byNumber: { ...purchaseBlock, hash: claimTx.blockHash } }, 1);
  assert.ok(result.conflicts.includes("block-hash"));
});
test("selection parses native integers and rejects declared blocks beyond the anchor", async () => {
  const parent = await mkdtemp(join(await realpath(tmpdir()), "dtf-output-schema-"));
  try {
    const input = await loadCandidateInput(await inputFixture(parent));
    const raw = input.bytes.get("observed-recoveries.csv"); assert.ok(raw);
    const text = new TextDecoder().decode(raw);
    for (const [from, to] of [['"9","11"', '"9.5","11"'], ['"9","11"', '"-9","11"'],
      ['"9","11"', '"9","108944664"'], ['"9","9","11"', '"256","9","11"']]) {
      assert.ok(from && to && text.includes(from));
      const bytes = new Map(input.bytes).set("observed-recoveries.csv", new TextEncoder().encode(text.replace(from, to)));
      assert.throws(() => receiptReferences({ ...input, bytes }, "conversions-and-recoveries"));
    }
  } finally { await rm(parent, { recursive: true }); }
});
