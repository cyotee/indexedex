import { test } from "node:test";
import assert from "node:assert/strict";
import { mkdtemp, rm, realpath } from "node:fs/promises";
import { join } from "node:path";
import { tmpdir } from "node:os";
import { id } from "ethers";
import { loadCandidateInput } from "./candidate-input.js";
import { receiptReferences, legacy } from "./receipt-input.js";
import { reconcileReference } from "./receipt-reconciliation.js";
import { inputFixture, purchaseTx, purchaseReceipt, purchaseBlock, wallet } from "./receipt.fixture.js";
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
