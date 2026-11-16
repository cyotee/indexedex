import { spawn } from "node:child_process";
import { once } from "node:events";
import { mkdir, readFile } from "node:fs/promises";
import { join, resolve } from "node:path";
import { z } from "zod";
import { launchAnvil, FORGE, ANVIL } from "./rehearsal-process.js";
import { RehearsalChain } from "./rehearsal-chain.js";
import { acquireClaimedSy } from "./rehearsal-claimed-sy-source.js";
import { authenticateClaimedSyMember } from "./claimed-sy-member.js";
import { ClaimedSyEvidenceError } from "./claimed-sy-witness.js";
import { stakingClaim, stakingSource } from "./claimed-sy-source.js";
import { ExecutionError } from "./execution-schema.js";
import { save } from "./rehearsal-data.js";
import { fingerprint } from "./provenance.js";
import { hex } from "./schema.js";

/** Source-only local regression. Full funded surrender remains in the shared rehearsal. */
async function main() {
  const destination = process.argv[2];
  if (!destination) throw new ExecutionError("DOMAIN", "new receipt evidence directory required");
  const evidence = resolve(destination);
  await mkdir(evidence, { recursive: false });
  const config = spawn(FORGE, ["config", "--json"], { env: process.env, stdio: ["ignore", "pipe", "pipe"] });
  const exited = once(config, "close", { signal: AbortSignal.timeout(15000) });
  let output = "";
  config.stdout.on("data", (bytes: Buffer) => { output += bytes.toString(); });
  config.stderr.resume();
  if ((await exited)[0] !== 0) throw new ExecutionError("RPC", "existing Foundry alias unavailable");
  const aliases = z.object({ rpc_endpoints: z.record(z.string(), z.string()) }).passthrough().parse(JSON.parse(output));
  const upstream = aliases.rpc_endpoints["robinhood_mainnet_alchemy"]?.replace(/\$\{([A-Z][A-Z0-9_]*)\}/g,
    (match: string, key: string) => process.env[key] ?? match);
  if (!upstream || upstream.includes("${")) throw new ExecutionError("RPC", "existing source credential unavailable");
  const command = [ANVIL, "--host", "127.0.0.1", "--port", "18573", "--chain-id", "4663",
    "--fork-url", upstream, "--fork-block-number", "108944663", "--gas-limit", "100000000",
    "--disable-min-priority-fee", "--balance", "1000000"];
  await save(join(evidence, "command.json"), { command: [process.execPath, ...process.argv.slice(1)],
    anvil: command.map((item) => item === upstream ? "<existing robinhood_mainnet_alchemy alias>" : item) });
  const node = await launchAnvil(command.slice(1), join(evidence, "anvil.log"), upstream);
  const chain = new RehearsalChain("18573");
  try {
    const metadata = z.object({ forkedNetwork: z.object({
      chainId: z.number(), forkBlockNumber: z.number(), forkBlockHash: z.string(),
    }) }).passthrough().parse(await chain.send("anvil_metadata", []));
    if (metadata.forkedNetwork.chainId !== 4663 || metadata.forkedNetwork.forkBlockNumber !== 108944663
      || metadata.forkedNetwork.forkBlockHash !== "0xc497433dd691a40cb85959cfeba2e3fff85a975ae060612d984998e1d5765733") {
      throw new ExecutionError("DOMAIN", "source fork identity differs");
    }
    const originals = await acquireClaimedSy(chain, evidence);
    const probeMember = originals.find((row) => row.index === 240)?.certificate.members[0];
    if (!probeMember) throw new ExecutionError("STATE", "missing probe transaction");
    for (const diffMode of [false, true]) {
      try {
        await save(join(evidence, `prestate-${diffMode ? "diff" : "full"}.json`),
          await chain.send("debug_traceTransaction", [probeMember.transactionHash,
            { tracer: "prestateTracer", tracerConfig: { diffMode } }]));
      } catch (error) {
        if (!(error instanceof Error)) throw error;
        await save(join(evidence, `prestate-${diffMode ? "diff" : "full"}-error.json`), { error: error.message });
      }
    }
    for (const txIndex of [0, 1, 2]) {
      try {
        await save(join(evidence, `trace-call-index-${txIndex}.json`),
          await chain.send("debug_traceCall", [{ to: stakingSource, data: stakingClaim.encodeFunctionData("totalSupply") },
            `0x${BigInt(probeMember.blockNumber).toString(16)}`,
            { tracer: "callTracer", txIndex: `0x${txIndex.toString(16)}` }]));
      } catch (error) {
        if (!(error instanceof Error)) throw error;
        await save(join(evidence, `trace-call-index-${txIndex}-error.json`), { error: error.message });
      }
    }
    const accepted = [];
    for (const original of originals) {
      for (const member of original.certificate.members) {
        await authenticateClaimedSyMember(chain.provider, original.certificate, member);
        accepted.push({ index: original.index, transactionHash: member.transactionHash });
      }
    }
    const witnessed = originals.find((row) => row.index === 240);
    const member = witnessed?.certificate.members[0];
    if (!witnessed || !member) throw new ExecutionError("STATE", "missing witnessed original");
    const reasons = { caught: "TRACE_FAILED", ambiguous: "TRACE_AMBIGUOUS", "wrong-beneficiary": "EFFECTS" } as const;
    const rejected = [];
    for (const [index, prefix] of [[238, "witness"], [240, "indirect"]] as const) {
      const original = originals.find((row) => row.index === index);
      const validMember = original?.certificate.members[0];
      if (!original || !validMember) throw new ExecutionError("STATE", "missing indirect original");
      const negatives = z.array(z.object({ kind: z.enum(["caught", "ambiguous", "wrong-beneficiary"]),
        transactionHash: z.string(), rawSignedTransaction: z.string(), blockNumber: z.string(), blockHash: z.string(),
      })).parse(JSON.parse(await readFile(join(evidence, `claimed-${prefix}-negatives.json`), "utf8")));
      for (const { kind, ...transaction } of negatives) {
        try {
          await authenticateClaimedSyMember(chain.provider, original.certificate, { ...validMember, ...transaction });
          throw new ExecutionError("STATE", `${prefix}-${kind} unexpectedly authenticated`);
        } catch (error) {
          if (!(error instanceof ClaimedSyEvidenceError) || error.reason !== reasons[kind]) throw error;
          rejected.push({ kind: `${prefix}-${kind}`, reason: error.reason, transactionHash: transaction.transactionHash });
        }
      }
    }
    const supplyAt = async (height: bigint) => z.bigint().parse(stakingClaim.decodeFunctionResult("totalSupply",
      hex.parse(await chain.send("eth_call", [{ to: stakingSource, data: stakingClaim.encodeFunctionData("totalSupply") },
        `0x${height.toString(16)}`])))[0]);
    const height = BigInt(member.blockNumber);
    const blockConsumed = await supplyAt(height - 1n) - await supplyAt(height);
    if (blockConsumed !== BigInt(member.consumedWeight) + 2n * 10n ** 16n) {
      throw new ExecutionError("STATE", "surrounding source operations were not real state changes");
    }
    const files = [
      "claimed-sy.ts", "claimed-sy-member.ts", "claimed-sy-witness.ts", "claimed-sy-state.ts", "claimed-sy-source.ts", "schema.ts",
      "rehearsal-claimed-sy-source.ts", "rehearsal-claimed-sy-witness.ts", "rehearsal-claimed-sy-indirect.ts",
      "rehearsal-claimed-sy-intake.ts", "rehearsal-claimed-sy.ts", "rehearsal-claimed-sy-local.ts",
    ].map((name) => `scripts/recovery/dtf-migration/${name}`);
    files.push("scripts/foundry/recovery/dtf-migration/MigrationClaimWitness.sol",
      "scripts/foundry/recovery/dtf-migration/MigrationIndirectClaimFixture.sol",
      "scripts/foundry/recovery/dtf-migration/MigrationDelegatedReceiverFixture.sol");
    const sources = await Promise.all(files.map(async (path) => ({ path, sha256: fingerprint(await readFile(path)) })));
    await save(join(evidence, "result.json"), { exitCode: 0, metadata, accepted, rejected, sources,
      blockConsumed: String(blockConsumed), transactionConsumed: member.consumedWeight,
      qualification: "Source authentication only. Eligibility is synthetic. Full Stage 1/2 funded surrender is exercised by rehearse.ts." });
    console.log(JSON.stringify({ evidence, accepted: accepted.length, rejected, exitCode: 0 }));
  } finally {
    chain.close();
    await node.close();
    await save(join(evidence, "cleanup.json"), { node: "stopped", port: 18573 });
  }
}

main().catch((error: unknown) => {
  console.error(error instanceof Error ? error.message : "unknown local rehearsal failure");
  process.exitCode = 1;
});
