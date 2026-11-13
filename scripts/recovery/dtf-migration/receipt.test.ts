import { test } from "node:test";
import assert from "node:assert/strict";
import { mkdtemp, mkdir, readFile, rm, realpath } from "node:fs/promises";
import { join } from "node:path";
import { tmpdir } from "node:os";
import { associationConflicts, quantity } from "./receipt-association.js";
import type { Associated } from "./receipt-association.js";
import { purchaseTx, purchaseReceipt, purchaseBlock, txHash, claimHash, fixtureResponse,
  collectionFixture, wireFixture, inputFixture } from "./receipt.fixture.js";
import { ReceiptRpc } from "./receipt-rpc.js";
import { loadCandidateInput } from "./candidate-input.js";
import { receiptReferences, receiptRequests } from "./receipt-input.js";
import { collectReceipts } from "./receipt-evidence.js";
import { main } from "./cli.js";

test("complete wire collection authenticates and associates each known reference", async () => {
  const { archive } = await collectionFixture();
  assert.equal(archive.authenticated, true);
  assert.equal(archive.references, 2);
  assert.equal(archive.completeAssociations, 2);
  assert.equal(archive.referenceConflicts, 0);
});
for (const [label, response] of [
  ["wrong-chain", "0x1"], ["malformed-chain", "0x01237"],
] as const) test(`collection stops before named requests on ${label}`, async () => {
  const { archive, captures } = await collectionFixture((q) => q.method === "eth_chainId"
    ? { jsonrpc: "2.0", id: q.id, result: response } : fixtureResponse(q));
  assert.equal(archive.authenticated, false);
  assert.deepEqual(captures.map((c) => c.method), ["eth_chainId", "eth_getBlockByNumber"]);
  assert.equal(archive.results.filter((r) => r.conflicts.includes("chain-or-anchor-authentication-failed")).length, 2);
});
test("wrong canonical anchor blocks every named collection", async () => {
  const { archive } = await collectionFixture((q) => q.method === "eth_getBlockByNumber"
    ? { jsonrpc: "2.0", id: q.id, result: purchaseBlock } : fixtureResponse(q));
  assert.equal(archive.authenticated, false);
  assert.equal(archive.completeAssociations, 0);
});
const failures: readonly { readonly name: string; readonly response: (id: number) => unknown; readonly reason: string }[] = [
  { name: "null", response: (id) => ({ jsonrpc: "2.0", id, result: null }), reason: "null-result" },
  { name: "missing", response: (id) => ({ jsonrpc: "2.0", id }), reason: "missing-result" },
  { name: "rpc error", response: (id) => ({ jsonrpc: "2.0", id, error: { code: -32000, message: "archive denied" } }), reason: "rpc-error" },
  { name: "wrong id", response: (id) => ({ jsonrpc: "2.0", id: id + 100, result: purchaseTx }), reason: "response-envelope-or-id" },
  { name: "wrong version", response: (id) => ({ jsonrpc: "1.0", id, result: purchaseTx }), reason: "response-envelope-or-id" },
  { name: "malformed quantity", response: (id) => ({ jsonrpc: "2.0", id, result: { ...purchaseTx, value: "0x00" } }), reason: "result-schema" },
];
for (const f of failures) test(`partial ${f.name} failure stays explicit while unaffected transaction completes`, async () => {
  const { archive, captures } = await collectionFixture((q) =>
    q.method === "eth_getTransactionByHash" && q.params[0] === txHash ? f.response(q.id) : fixtureResponse(q));
  assert.equal(archive.completeAssociations, 1);
  assert.ok(archive.results.find((r) => r.tx === txHash)?.conflicts.includes(`transaction:${f.reason}`));
  assert.deepEqual(archive.results.find((r) => r.tx === claimHash)?.conflicts, []);
  assert.equal(captures.filter((c) => c.method === "eth_getTransactionByHash" && c.params[0] === txHash).length, 1);
});
const associated = { transaction: purchaseTx, receipt: purchaseReceipt, byHash: purchaseBlock, byNumber: purchaseBlock };
const mutations = [
  ["transaction-hash", { ...associated, transaction: { ...purchaseTx, hash: claimHash } }],
  ["block-hash", { ...associated, receipt: { ...purchaseReceipt, blockHash: claimHash } }],
  ["block-number", { ...associated, receipt: { ...purchaseReceipt, blockNumber: "0xc" } }],
  ["transaction-index", { ...associated, receipt: { ...purchaseReceipt, transactionIndex: "0x1" } }],
  ["receipt-endpoints", { ...associated, receipt: { ...purchaseReceipt, from: `0x${"9".repeat(40)}` } }],
  ["block-membership", { ...associated, byNumber: { ...purchaseBlock, transactions: [claimHash] } }],
  ["canonical-header", { ...associated, byNumber: { ...purchaseBlock, timestamp: "0x21" } }],
  ["after-anchor", { ...associated, transaction: { ...purchaseTx, blockNumber: "0xfffffff" } }],
  ["transaction-reverted", { ...associated, receipt: { ...purchaseReceipt, status: "0x0" } }],
] as const;
for (const [expected, observation] of mutations) test(`contradictory association identifies ${expected}`, () => {
  assert.ok(associationConflicts(txHash, observation).includes(expected));
});
test("every log identity and strict ordering are verified", () => {
  const first = purchaseReceipt.logs[0]; assert.ok(first);
  for (const change of [{ transactionHash: claimHash }, { blockHash: claimHash }, { blockNumber: "0xc" }, { transactionIndex: "0x1" }]) {
    const changed: Associated = { ...associated, receipt: { ...purchaseReceipt, logs: [{ ...first, ...change }] } };
    assert.ok(associationConflicts(txHash, changed).includes("log-association:0x1"));
  }
  assert.ok(associationConflicts(txHash, { ...associated,
    receipt: { ...purchaseReceipt, logs: [first, first] } }).includes("log-order:0x1"));
});
test("distinct references to one transaction deduplicate requests without losing rows", async () => {
  const parent = await mkdtemp(join(await realpath(tmpdir()), "dtf-reference-"));
  try {
    const refs = receiptReferences(await loadCandidateInput(await inputFixture(parent)));
    const first = refs[0]; assert.ok(first);
    const duplicate = { ...first, row: { ...first.row, locator: "distinct-original#row=9" } };
    const requests = receiptRequests([...refs, duplicate]);
    assert.equal(requests.length, 2);
    assert.ok(requests.find((r) => r.tx === first.tx)?.references.includes("distinct-original#row=9"));
    assert.equal(requests.find((r) => r.tx === first.tx)?.references.length, 2);
  } finally { await rm(parent, { recursive: true }); }
});
test("credential-bearing wire errors retain sanitized bytes and never claim raw capture", async () => {
  const parent = await mkdtemp(join(await realpath(tmpdir()), "dtf-redaction-"));
  const secret = "private-provider-token";
  const server = await wireFixture((q) => ({ jsonrpc: "2.0", id: q.id, error: { code: -1,
    message: `refused https://provider.invalid/v2/${secret} token=${secret}` } }));
  try {
    await mkdir(join(parent, "http"));
    const endpoint = new URL(`${secret}`, server.url);
    const rpc = new ReceiptRpc(endpoint, join(parent, "http"));
    const response = await rpc.read("eth_chainId", [], quantity);
    assert.deepEqual(response, { kind: "failure", id: 1, reason: "credential-bearing-response-redacted" });
    const capture = rpc.captures[0]; assert.ok(capture?.response);
    assert.equal(capture.response.raw, false);
    const bytes = await readFile(join(parent, "http", capture.response.path));
    assert.equal(bytes.includes(secret), false);
    assert.equal(bytes.includes("refused"), true);
  } finally { await server.close(); await rm(parent, { recursive: true }); }
});
test("fresh exclusive publication refuses an existing directory before network requests", async () => {
  const parent = await mkdtemp(join(await realpath(tmpdir()), "dtf-exclusive-"));
  try {
    const root = await inputFixture(parent);
    await assert.rejects(collectReceipts(root, parent, new ReceiptRpc(new URL("http://127.0.0.1:1"), parent)), { code: "EEXIST" });
  } finally { await rm(parent, { recursive: true }); }
});
test("CLI rejects signing, arbitrary endpoint, alias and ambiguous option inputs", async () => {
  for (const extra of [["--broadcast"], ["--execute-local"], ["--rpc-url", "http://127.0.0.1"], ["--input", "other"]]) {
    await assert.rejects(main(["collect-receipts", "--input", "raw", "--output", "new",
      "--rpc-alias", "robinhood_mainnet_alchemy", ...extra]));
  }
});
