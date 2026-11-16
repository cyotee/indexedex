import assert from "node:assert/strict";
import { z } from "zod";

// Read-only independent observer. Each response retains the actual HTTP body.
const endpoint = "http://127.0.0.1:18569";
const quantity = z.string().regex(/^0x[0-9a-f]+$/i);
const hash = z.string().regex(/^0x[0-9a-f]{64}$/i);
const envelope = z.object({ id: z.number(), jsonrpc: z.literal("2.0"), result: z.unknown() }).passthrough();
let sequence = 0;
async function rpc(method: string, params: readonly unknown[]): Promise<unknown> {
  const request = { jsonrpc: "2.0", id: ++sequence, method, params };
  const response = await fetch(endpoint, {
    method: "POST", headers: { "content-type": "application/json" },
    body: JSON.stringify(request), signal: AbortSignal.timeout(30000),
  });
  assert(response.ok);
  const body = await response.text();
  const parsed = envelope.parse(JSON.parse(body));
  assert.equal(parsed.id, request.id);
  console.log(JSON.stringify({ request, body }));
  return parsed.result;
}

assert.equal(await rpc("eth_chainId", []), "0x1237");
const seen = new Set<string>();
let tail = Promise.resolve();
async function block(number: string) {
  if (seen.has(number)) return;
  seen.add(number);
  const value = z.object({ hash, transactions: z.array(hash) }).passthrough()
    .parse(await rpc("eth_getBlockByNumber", [number, false]));
  for (const tx of value.transactions) {
    await rpc("eth_getTransactionByHash", [tx]);
    const receipt = z.object({ blockHash: hash, transactionHash: hash }).passthrough()
      .parse(await rpc("eth_getTransactionReceipt", [tx]));
    assert.equal(receipt.transactionHash, tx);
    assert.equal(receipt.blockHash, value.hash);
  }
}
const ws = new WebSocket("ws://127.0.0.1:18569");
const closed = new Promise<void>((resolve, reject) => {
  ws.addEventListener("error", () => reject(new TypeError("Independent capture websocket failed")));
  ws.addEventListener("close", () => resolve(), { once: true });
});
await new Promise<void>((resolve, reject) => {
  ws.addEventListener("open", () => resolve(), { once: true });
  ws.addEventListener("error", () => reject(new TypeError("Independent capture connection failed")), { once: true });
});
ws.addEventListener("message", event => {
  const message = z.object({
    params: z.object({ result: z.object({ number: quantity }).passthrough() }).optional(),
  }).passthrough().parse(JSON.parse(z.string().parse(event.data)));
  if (message.params) {
    const number = message.params.result.number;
    tail = tail.then(() => block(number));
  }
});
ws.send(JSON.stringify({ jsonrpc: "2.0", id: 1, method: "eth_subscribe", params: ["newHeads"] }));
try {
  const latest = BigInt(quantity.parse(await rpc("eth_blockNumber", [])));
  for (let height = 108944664n; height <= latest; height++) {
    await block(`0x${height.toString(16)}`);
  }
  await closed;
  await tail;
  console.log(JSON.stringify({ status: "independent-capture-closed", blocks: seen.size }));
} finally {
  ws.close();
}
