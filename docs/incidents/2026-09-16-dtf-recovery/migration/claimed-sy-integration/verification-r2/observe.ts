import assert from "node:assert/strict";
import { HDNodeWallet, Interface } from "ethers";
import { z } from "zod";

// Independent read-only observation of actual historical books, not uploaded
// producer state. The subscription is installed before the bounded backfill.
const source = "0xe4c9ff4cfd17ae73ecb3825ebdf7db113c146d00";
const vault = "0xaf5c0cd3fdedd10bee00eff77fa0429bacdb41f0";
const sy = "0xb55604cf4dcdabb362078e106d20f98512391edf";
const wallets = [231, 232].map(index => HDNodeWallet.fromPhrase(
  "test test test test test test test test test test test junk",
  undefined, `m/44'/60'/0'/0/${index}`).address.toLowerCase());
const abi = new Interface([
  "function balanceOf(address) view returns(uint256)",
  "function totalSupply() view returns(uint256)",
  "function allowance(address,address) view returns(uint256)",
  "function bondNftVault() view returns(address)",
  "function rebasingClaimToken() view returns(address)",
  "function gonsOf(address) view returns(uint256)",
  "function migrationRecoveryInventory(address) view returns(uint256)",
  "function weightedSySurrender(bytes32) view returns((uint256 consumedUnits,uint256 deliveredCredit,uint256 remainingUnits,uint256 remainingCredit))",
  "function surrenderMigrationWeightedSy(bytes32,uint256,uint256,uint256) returns(uint256,uint256)",
]);
const txSchema = z.object({
  hash: z.string(), from: z.string(), to: z.string().nullable(),
  input: z.string(), blockNumber: z.string(),
}).passthrough();
let sequence = 0;
async function rpc(method: string, params: readonly unknown[]): Promise<unknown> {
  const request = { jsonrpc: "2.0", id: ++sequence, method, params };
  const response = await fetch("http://127.0.0.1:18573", {
    method: "POST", headers: { "content-type": "application/json" },
    body: JSON.stringify(request), signal: AbortSignal.timeout(30000),
  });
  assert(response.ok);
  const body = await response.text();
  console.log(JSON.stringify({ kind: "http", request, body }));
  const parsed = z.object({ id: z.number(), result: z.unknown() }).passthrough()
    .parse(JSON.parse(body));
  assert.equal(parsed.id, request.id);
  return parsed.result;
}
async function call(target: string, method: string, args: readonly unknown[], tag: string) {
  return abi.decodeFunctionResult(method, z.string().parse(await rpc("eth_call", [
    { to: target, data: abi.encodeFunctionData(method, args) }, tag,
  ])));
}
const seen = new Set<string>();
async function inspect(height: string) {
  if (seen.has(height)) return;
  seen.add(height);
  const block = z.object({ hash: z.string(), transactions: z.array(txSchema) }).passthrough()
    .parse(await rpc("eth_getBlockByNumber", [height, true]));
  for (const tx of block.transactions) {
    if (!wallets.includes(tx.from)) continue;
    const sourceClaim = tx.to === source && tx.input.startsWith("0xa224dcb7");
    const surrender = tx.input.startsWith(abi.getFunction("surrenderMigrationWeightedSy")?.selector ?? "absent");
    if (!sourceClaim && !surrender) continue;
    assert(tx.to);
    const beforeTag = `0x${(BigInt(height) - 1n).toString(16)}`;
    const books = [];
    for (const tag of [beforeTag, height]) {
      const values: Record<string, unknown> = {};
      for (const [key, target, method, args] of [
        ["rawWeight", source, "balanceOf", [tx.from]],
        ["rawSupply", source, "totalSupply", []],
        ["sourceShares", vault, "balanceOf", [source]],
        ["vaultSupply", vault, "totalSupply", []],
        ["walletSy", sy, "balanceOf", [tx.from]],
        ["vaultSy", sy, "balanceOf", [vault]],
        ["sySupply", sy, "totalSupply", []],
      ] as const) values[key] = (await call(target, method, args, tag)).toArray().map(String);
      if (surrender) {
        const args = abi.decodeFunctionData("surrenderMigrationWeightedSy", tx.input);
        const parent = tx.to;
        const receipt = z.string().parse((await call(parent, "rebasingClaimToken", [], tag))[0]).toLowerCase();
        const bond = z.string().parse((await call(parent, "bondNftVault", [], tag))[0]).toLowerCase();
        for (const [key, target, method, inputs] of [
          ["eligibility", parent, "weightedSySurrender", [args[0]]],
          ["parentSy", sy, "balanceOf", [parent]],
          ["allowance", sy, "allowance", [tx.from, parent]],
          ["inventory", parent, "migrationRecoveryInventory", [sy]],
          ["newSupply", parent, "totalSupply", []],
          ["newBacking", parent, "balanceOf", [receipt]],
          ["bondGons", receipt, "gonsOf", [bond]],
          ["walletBonds", bond, "balanceOf", [tx.from]],
        ] as const) values[key] = (await call(target, method, inputs, tag)).toArray(true);
      }
      books.push({ tag, values });
    }
    const receipt = await rpc("eth_getTransactionReceipt", [tx.hash]);
    const trace = await rpc("debug_traceTransaction", [tx.hash, { tracer: "callTracer" }]);
    console.log(JSON.stringify({ kind: "observed", transaction: tx, receipt, trace, books },
      (_, value: unknown) => typeof value === "bigint" ? String(value) : value));
  }
}
const ws = new WebSocket("ws://127.0.0.1:18573");
const closed = new Promise<void>((resolve, reject) => {
  ws.addEventListener("close", () => resolve(), { once: true });
  ws.addEventListener("error", () => reject(new TypeError("Independent observer websocket failed")), { once: true });
});
await new Promise<void>((resolve, reject) => {
  ws.addEventListener("open", () => resolve(), { once: true });
  ws.addEventListener("error", () => reject(new TypeError("Independent observer connection failed")), { once: true });
});
let tail = Promise.resolve();
const acknowledged = new Promise<void>(resolve => {
  ws.addEventListener("message", event => {
    const value = z.object({
      id: z.number().optional(), result: z.unknown().optional(),
      params: z.object({ result: z.object({ number: z.string() }).passthrough() }).optional(),
    }).passthrough().parse(JSON.parse(z.string().parse(event.data)));
    if (value.id === 1) resolve();
    if (value.params) {
      const number = value.params.result.number;
      tail = tail.then(() => inspect(number));
    }
  });
});
ws.send(JSON.stringify({ jsonrpc: "2.0", id: 1, method: "eth_subscribe", params: ["newHeads"] }));
try {
  await acknowledged;
  const latest = BigInt(z.string().parse(await rpc("eth_blockNumber", [])));
  for (let n = 108944664n; n <= latest; n++) {
    const tag = `0x${n.toString(16)}`;
    tail = tail.then(() => inspect(tag));
  }
  await closed;
  await tail;
  console.log(JSON.stringify({ kind: "independent-observer-closed", blocks: seen.size }));
} finally {
  ws.close();
}
