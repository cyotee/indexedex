// Adapted read-only from accepted phase19 evidence; original files remain unchanged.
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { resolve } from "node:path";
import { Interface } from "ethers";
import { z } from "zod";
import { canonical, files, json, required, root } from "./evidence.js";
import type { receipts } from "./receipts.js";

export async function lifecycle(runtime: string, records: Awaited<ReturnType<typeof receipts>>) {
  const artifact = z.object({ abi: z.array(z.unknown()) }).passthrough().parse(await json(resolve(root,
    "out/IUniswapV4DetfMigration.sol/IUniswapV4DetfMigrationAllocation.json")));
  const allocation = new Interface(JSON.stringify(artifact.abi));
  const diamond = new Interface(["event DiamondFunctionRemoved(bytes4 indexed selector,address indexed oldFacet)"]);
  const activation = required(records.completions.find(c => c.path.includes("/journal-activate/")));
  const decoded = activation.completion.receipt.logs.filter(l => l.address === records.manifest.proxy)
    .map(l => diamond.parseLog(l)).filter(l => l !== null);
  const removed = decoded.map(l => z.string().parse(l.args[0])).sort();
  const selectors: string[] = [];
  allocation.forEachFunction(f => selectors.push(f.selector));
  assert.equal(selectors.length, 14);
  assert.deepEqual(removed, selectors.sort());
  assert(decoded.every(row => row.args[1] !== "0x0000000000000000000000000000000000000000"));
  const commands = [];
  const commandSchema = z.object({ command: z.array(z.string()), code: z.number().nullable(), signal: z.string().nullable() });
  for (const file of (await files(runtime)).filter(p => p.endsWith(".command.json"))) {
    const command = commandSchema.parse(await json(file));
    if (!command.command.includes("--fault-after-mined")) continue;
    assert.equal(command.signal, "SIGKILL"); assert.equal(command.code, null);
    const fault = z.object({ fault: z.literal("mined-before-checkpoint"), transactionHash: z.string(), nonce: z.string() })
      .parse(JSON.parse((await readFile(file.replace(".command.json", ""), "utf8")).trim()));
    assert(records.resumes.some(r => r.before.intent.transactionHash === fault.transactionHash && r.before.intent.nonce === fault.nonce));
    commands.push({ path: file, command, fault });
  }
  assert.equal(commands.length, 3);
  const originalLoad = records.completions.filter(c => z.object({ method: z.string() }).passthrough().parse(c.intent)
    .method === "configureEarlierReceiptEntitlements");
  assert.equal(originalLoad.length, 2);
  const configurations = [];
  for (const c of originalLoad) {
    const signed = required(records.signed.find(s => s.path === c.path));
    const rows = allocation.decodeFunctionData("configureEarlierReceiptEntitlements", signed.data)[0];
    assert.equal(rows.length, 1);
    configurations.push({ transactionHash: signed.hash, input: rows[0].toArray(), state: c.completion.state });
    // The loader's real transaction cannot mint new DETF even during replacements.
    const transferTopic = new Interface(["event Transfer(address indexed from,address indexed to,uint256 amount)"])
      .getEvent("Transfer")?.topicHash;
    assert(!c.completion.receipt.logs.some(l => l.address === records.manifest.proxy
      && l.topics[0] === transferTopic && l.topics[1] === `0x${"0".repeat(64)}`));
  }
  const failures = [];
  for (const name of ["earlier-receipt-stage1.json", "earlier-receipt-partial.json"]) {
    const observation = z.object({
      rejected: z.unknown().optional(), rejects: z.array(z.unknown()).optional(),
    }).passthrough().parse(await json(resolve(runtime, name)));
    for (const raw of observation.rejected ? [observation.rejected] : observation.rejects ?? []) {
      const failure = z.object({ before: z.unknown(), after: z.unknown(), transactionHash: z.string() }).passthrough().parse(raw);
      assert.equal(canonical(failure.before), canonical(failure.after));
      const tx = required(records.signed.find(s => s.hash === failure.transactionHash));
      assert.equal(BigInt(tx.receipt.status), 0n); assert.deepEqual(tx.receipt.logs, []);
      failures.push({ observation: failure, receipt: tx.receipt });
    }
  }
  assert.equal(failures.length, 3);
  return { activationReceipt: activation.completion.receipt, removed, cut: decoded, configurations, interruptions: commands, failures };
}
