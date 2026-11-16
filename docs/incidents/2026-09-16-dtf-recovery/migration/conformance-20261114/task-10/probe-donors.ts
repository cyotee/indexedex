import { readFile } from "node:fs/promises";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { z } from "zod";
import { RehearsalChain, LEGACY, legacyAbi } from "../../../../../../scripts/recovery/dtf-migration/rehearsal-chain.js";
import { launchAnvil } from "../../../../../../scripts/recovery/dtf-migration/rehearsal-process.js";
import { save } from "../../../../../../scripts/recovery/dtf-migration/rehearsal-data.js";
import { fingerprint } from "../../../../../../scripts/recovery/dtf-migration/provenance.js";
import { address, hash, hex } from "../../../../../../scripts/recovery/dtf-migration/schema.js";
import { quantity } from "../../../../../../scripts/recovery/dtf-migration/execution-schema.js";

// Read-only acquisition preflight. This is not a broadcaster or an operator.
const directory = dirname(fileURLToPath(import.meta.url));
const input = z.object({
  version: z.literal("task-10-donor-budget-probe-v1"),
  budget: z.string().regex(/^[0-9]+$/),
  transferEvidence: z.object({ path: z.string(), sha256: z.string() }),
  holders: z.array(address), authorityAddressSuperset: z.array(address),
}).parse(JSON.parse(await readFile(join(directory, "donor-probe-input.json"), "utf8")));
const transferBytes = await readFile(input.transferEvidence.path);
if (fingerprint(transferBytes) !== input.transferEvidence.sha256) throw new Error("transfer evidence changed");
const node = await launchAnvil(["--host", "127.0.0.1", "--port", "18575", "--chain-id", "4663",
  "--fork-url", "robinhood_mainnet_alchemy", "--fork-block-number", "108944663",
  "--no-fork-node-info"], join(directory, "donor-probe-anvil-r2.log"), process.env["ALCHEMY_KEY"] ?? "");
const chain = new RehearsalChain("18575");
try {
  const header = z.object({ hash, number: quantity }).passthrough().parse(
    await chain.send("eth_getBlockByNumber", ["0x67e5d17", false]));
  if (header.hash !== "0xc497433dd691a40cb85959cfeba2e3fff85a975ae060612d984998e1d5765733") {
    throw new Error("historical header differs");
  }
  const candidates = [...new Set([...input.holders, ...input.authorityAddressSuperset])].sort();
  const rows = [];
  for (const holder of candidates) {
    const data = legacyAbi.encodeFunctionData("balanceOf", [holder]);
    const returned = hex.parse(await chain.send("eth_call", [{ to: LEGACY.dtf, data }, header.number]));
    const balance = z.bigint().parse(legacyAbi.decodeFunctionResult("balanceOf", returned)[0]);
    const code = hex.parse(await chain.send("eth_getCode", [holder, header.number]));
    rows.push({ holder, balance: String(balance), code, coversBudget: balance >= BigInt(input.budget),
      transferWitness: input.holders.includes(holder), request: { method: "eth_call",
        params: [{ to: LEGACY.dtf, data }, header.number] }, returned });
  }
  const nftHolder = String((await chain.call(LEGACY.weighted, legacyAbi, "ownerOf", ["3"]))[0]).toLowerCase();
  const candidatesCovering = rows.filter((row) => row.coversBudget);
  await save(join(directory, "donor-budget-probe.json"), {
    header, budget: input.budget, token: LEGACY.dtf, decimals: 18, rows, candidatesCovering,
    nftThreeHolder: nftHolder, transactionsSent: 0,
    qualification: "Conservative candidate superset, before source/compensation/custody exclusions. No donation is authorized by this probe.",
  });
  console.log(JSON.stringify({ candidates: rows.length, candidatesCovering, nftHolder }));
} finally {
  chain.close();
  await node.close();
}
