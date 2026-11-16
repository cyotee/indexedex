import { readFile } from "node:fs/promises";
import { z } from "zod";

const endpoint = "http://127.0.0.1:18561";
const pin = "0x67e5d17";
const pinHash = "0xc497433dd691a40cb85959cfeba2e3fff85a975ae060612d984998e1d5765733";
const dev = "0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266";
const parent = "0xedf7d9f65b9e57d62a3c4278223170db1308f5f0";
const quantity = z.string().regex(/^0x[0-9a-f]+$/i);
const address = z.string().regex(/^0x[0-9a-f]{40}$/i);
const hex = z.string().regex(/^0x(?:[0-9a-f]{2})*$/i);
const transaction = z.object({
  from: address, to: address, input: hex, value: quantity,
});
const receipt = z.object({
  status: quantity, gasUsed: quantity, transactionHash: hex,
  blockNumber: quantity, blockHash: hex,
}).passthrough();

class WitnessFailure extends Error {
  constructor(readonly operation: string, readonly detail: unknown) {
    super(`${operation}: ${JSON.stringify(detail)}`);
  }
}

async function rpc(method: string, params: readonly unknown[] = []): Promise<unknown> {
  const response = await fetch(endpoint, {
    method: "POST", headers: { "content-type": "application/json" },
    body: JSON.stringify({ jsonrpc: "2.0", id: 1, method, params }),
    signal: AbortSignal.timeout(120000),
  });
  if (!response.ok) throw new WitnessFailure(method, response.status);
  const body = z.object({
    result: z.unknown().optional(),
    error: z.object({ code: z.number(), message: z.string() }).optional(),
  }).parse(await response.json());
  if (body.error) throw new WitnessFailure(method, body.error);
  return body.result;
}

async function submit(
  tx: z.infer<typeof transaction>, gas: string, timestamp?: number,
) {
  if (timestamp !== undefined) await rpc("evm_setNextBlockTimestamp", [timestamp]);
  const hash = hex.parse(await rpc("eth_sendTransaction", [{
    from: tx.from, to: tx.to, data: tx.input, value: tx.value,
    gas, gasPrice: "0x77359400",
  }]));
  // Explicit mining is the signal: no sleeps, receipt polling, or timing luck.
  await rpc("evm_mine");
  const mined = receipt.parse(await rpc("eth_getTransactionReceipt", [hash]));
  const block = z.object({ hash: hex }).parse(
    await rpc("eth_getBlockByNumber", [mined.blockNumber, false]),
  );
  if (block.hash !== mined.blockHash) throw new WitnessFailure("canonical receipt", hash);
  return { transaction: await rpc("eth_getTransactionByHash", [hash]), receipt: mined };
}

/** Run only against a fresh owned Anvil with the command in report.md.
 * Replays accepted CREATE3/registry bytecode and actual holder funding.
 * The larger second limit characterizes the defect; it is not a correction.
 * Returns evidence to the caller and never writes production or evidence files.
 */
export async function reproduce() {
  const chain = quantity.parse(await rpc("eth_chainId"));
  const node = z.object({
    currentBlockNumber: quantity,
    forkConfig: z.object({ forkBlockNumber: z.number() }),
  }).parse(await rpc("anvil_nodeInfo"));
  const header = z.object({ hash: hex }).passthrough().parse(
    await rpc("eth_getBlockByNumber", [pin, false]),
  );
  if (chain !== "0x1237" || node.currentBlockNumber !== pin
    || node.forkConfig.forkBlockNumber !== 108944663 || header.hash !== pinHash) {
    throw new WitnessFailure("fresh owned historical node", node);
  }
  if (await rpc("eth_getCode", [parent, "latest"]) !== "0x") {
    throw new WitnessFailure("parent must not exist", parent);
  }
  const seed = z.object({
    transactions: z.array(z.object({
      transaction,
      receipt: z.object({ blockTimestamp: z.number() }),
    })).length(225),
  }).parse(JSON.parse(await readFile(new URL("./infrastructure-replay.json", import.meta.url), "utf8")));
  const original = z.object({
    transaction: z.object({ from: address, to: address, data: hex }),
  }).parse(JSON.parse(await readFile(new URL("./accepted-parent-success.json", import.meta.url), "utf8")));
  await rpc("evm_setAutomine", [false]);
  const infrastructure = [];
  for (const [index, item] of seed.transactions.entries()) {
    const isHolder = item.transaction.from.toLowerCase() !== dev;
    if (isHolder) {
      if (index >= 5) throw new WitnessFailure("unexpected infrastructure sender", index);
      await rpc("anvil_setBalance", [item.transaction.from, "0x3635c9adc5dea00000"]);
      await rpc("anvil_impersonateAccount", [item.transaction.from]);
    }
    try {
      const result = await submit(item.transaction, "0x1e84800", item.receipt.blockTimestamp);
      infrastructure.push(result);
      if (result.receipt.status !== "0x1") throw new WitnessFailure("infrastructure", { index, result });
    } finally {
      if (isHolder) await rpc("anvil_stopImpersonatingAccount", [item.transaction.from]);
    }
  }
  const tx = { ...original.transaction, input: original.transaction.data, value: "0x0" };
  const failure = await submit(tx, "0x1e84800");
  const failureTrace = await rpc("debug_traceTransaction", [
    failure.receipt.transactionHash, { tracer: "callTracer" },
  ]);
  if (failure.receipt.status !== "0x0"
    || await rpc("eth_getCode", [parent, "latest"]) !== "0x") {
    throw new WitnessFailure("bounded failure with rollback", failure);
  }
  const success = await submit(tx, "0x5f5e100");
  const successTrace = await rpc("debug_traceTransaction", [
    success.receipt.transactionHash, { tracer: "callTracer" },
  ]);
  if (success.receipt.status !== "0x1"
    || BigInt(success.receipt.gasUsed) !== 42985843n) {
    throw new WitnessFailure("exact accepted deployment reproduction", success);
  }
  return {
    header, infrastructure, failure, failureTrace, success, successTrace,
    constraint: "Every setup/failure transaction has gas=32000000; only the diagnostic success has gas=100000000.",
    cleanup: "All holder impersonations ended; caller must stop the owned Anvil.",
  };
}
