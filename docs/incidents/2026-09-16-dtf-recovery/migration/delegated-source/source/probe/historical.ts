import { readFile, mkdir } from "node:fs/promises";
import { join } from "node:path";
import { keccak256 } from "ethers";
import { z } from "zod";
import { Rpc, check, save, hex, qty, T, V, Y, HW, HIST, PIN, PINHASH,
  abi, call, numberAt, receiptSchema, txSchema, blockSchema, ProofError } from "./common.js";

const output = process.argv[2];
check(output, "output required");
await mkdir(output, { recursive: false });
const key = process.env["ALCHEMY_KEY"];
check(key, "existing archive bootstrap unavailable");
const config = await readFile(join(process.cwd(), "foundry.toml"), "utf8");
check(config.includes('robinhood_mainnet_alchemy = "https://robinhood-mainnet.g.alchemy.com/v2/${ALCHEMY_KEY}"'), "alias changed");
const rpc = new Rpc(new URL(`https://robinhood-mainnet.g.alchemy.com/v2/${encodeURIComponent(key)}`),
  join(output, "wire"), key);
check(BigInt(qty.parse(await rpc.send("eth_chainId", []))) === 4663n, "archive chain");
const anchor = blockSchema.parse(await rpc.send("eth_getBlockByNumber", [PIN, false]));
check(anchor.hash === PINHASH, "archive anchor");
const transaction = txSchema.parse(await rpc.send("eth_getTransactionByHash", [HIST]));
const receipt = receiptSchema.parse(await rpc.send("eth_getTransactionReceipt", [HIST]));
const block = blockSchema.parse(await rpc.send("eth_getBlockByNumber", [receipt.blockNumber, false]));
const byHash = blockSchema.parse(await rpc.send("eth_getBlockByHash", [receipt.blockHash, false]));
check(transaction.hash === HIST && receipt.transactionHash === HIST
  && receipt.status === "0x1" && transaction.blockHash === block.hash
  && receipt.blockHash === block.hash && byHash.hash === block.hash
  && transaction.transactionIndex === receipt.transactionIndex
  && block.transactions[Number(BigInt(receipt.transactionIndex))] === HIST, "historical canonical identity");
for (const log of receipt.logs) check(log.blockHash === block.hash && log.transactionHash === HIST
  && log.blockNumber === block.number && log.transactionIndex === receipt.transactionIndex, "historical log identity");
await save(join(output, "canonical.json"), { anchor, transaction, receipt, block, byHash });

// Exactly one known-hash callTracer request. A refusal is retained, never worked around.
let trace: unknown = null;
let traceFailure: string | null = null;
try {
  trace = await rpc.send("debug_traceTransaction", [HIST, { tracer: "callTracer" }]);
} catch (error) {
  if (!(error instanceof ProofError)) throw error;
  traceFailure = error.message;
}
await save(join(output, "trace.json"), { trace, traceFailure, attempts: 1 });
const observations = [];
for (const tag of ["0x4488889", "0x448888a"]) {
  const bindings = [];
  for (const [target, methods] of [
    [T, ["withdrawClaim", "balanceOf", "totalSupply", "phase", "claimVault"]],
    [V, ["redeem", "balanceOf", "totalSupply", "asset", "decimals"]],
    [Y, ["transfer", "balanceOf", "totalSupply", "decimals"]],
  ] as const) {
    const code = hex.parse(await rpc.send("eth_getCode", [target, tag]));
    const routes = [];
    for (const method of methods) {
      const fn = abi.getFunction(method);
      check(fn, "missing ABI method");
      const facet = z.string().parse(await call(rpc, target, "facetAddress", [fn.selector], tag)).toLowerCase();
      const runtime = hex.parse(await rpc.send("eth_getCode", [facet, tag]));
      routes.push({ method, selector: fn.selector, facet, runtime, runtimeHash: keccak256(runtime) });
    }
    bindings.push({ target, code, codeHash: keccak256(code), routes });
  }
  const designation = hex.parse(await rpc.send("eth_getCode", [HW, tag]));
  const delegateCode = designation.startsWith("0xef0100") && designation.length === 48
    ? hex.parse(await rpc.send("eth_getCode", [`0x${designation.slice(8)}`, tag])) : null;
  const state = {
    phase: await numberAt(rpc, T, "phase", [], tag),
    vault: await call(rpc, T, "claimVault", [], tag),
    asset: await call(rpc, V, "asset", [], tag),
    vaultDecimals: await numberAt(rpc, V, "decimals", [], tag),
    syDecimals: await numberAt(rpc, Y, "decimals", [], tag),
    weight: await numberAt(rpc, T, "balanceOf", [HW], tag),
    weightSupply: await numberAt(rpc, T, "totalSupply", [], tag),
    shares: await numberAt(rpc, V, "balanceOf", [T], tag),
    vaultSupply: await numberAt(rpc, V, "totalSupply", [], tag),
    walletSy: await numberAt(rpc, Y, "balanceOf", [HW], tag),
    vaultSy: await numberAt(rpc, Y, "balanceOf", [V], tag),
    sySupply: await numberAt(rpc, Y, "totalSupply", [], tag),
  };
  observations.push({ tag, bindings, designation, delegateCode, state });
}
await save(join(output, "observations.json"), observations);
console.log("HISTORICAL_COMPLETE", traceFailure === null ? "trace-returned" : "trace-refused-retained");
