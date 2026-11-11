#!/usr/bin/env bun
import { parseArgs } from "node:util";
import { z } from "zod";
import { prepareFile, validateManifest } from "./preparation.js";
import { PreparationError } from "./schema.js";
import { execute } from "./execution.js";
import { ExecutionError, stage } from "./execution-schema.js";
import type { Mode } from "./execution-schema.js";
import { rehearse } from "./rehearse.js";

export const help = `Bounded Migration operator
  bun scripts/recovery/dtf-migration/cli.ts prepare --input <file> --output <directory>
  bun scripts/recovery/dtf-migration/cli.ts validate --manifest <file>
  bun scripts/recovery/dtf-migration/cli.ts <stage> --manifest <file> --checkpoint <directory>
  bun scripts/recovery/dtf-migration/cli.ts resume --manifest <file> --checkpoint <directory>

prepare reads caller-pinned evidence and the actual immutable snapshot.
validate rereads evidence, code identities, snapshot and independent ETH/DTF quotes.
RPC comes only from the manifest's rpcEnv environment variable. No signer is loaded.
All integers are decimal strings. Inputs are full replacements, not deltas.
Unsupported categories fail closed. Synthetic datasets are loopback-only.
Stages: deploy, fund, capture, configure, independent-issue, owner-bond, verify, activate, harvest.
owner-bond requires explicit token, amount, ordinary duration and deadline in the manifest.
Activation requires the confirmed paid owner purchase; resume reconciles its original receipt.
Every stage and resume defaults to read-only validation; no signer is loaded.
Local execution: --execute-local --instance-id <exact observed Anvil instance ID>.
Public execution: --broadcast --confirm-chain <id> --confirm-proxy <address>
  --confirm-snapshot <id> --signer-key-env <selected environment variable name>.
--reverse reorders only independent unsettled configuration/issuance rows.
--fault-after-mined is restricted to synthetic-local interruption rehearsal.
  bun scripts/recovery/dtf-migration/cli.ts rehearse --rpc-alias robinhood_mainnet_alchemy
    --fork-block 108944663 --port 18563
    --checkpoint .omo-runtime/dtf-migration-weighted-liquid/checkpoints
    --evidence docs/incidents/2026-09-16-dtf-recovery/migration/weighted-liquid
`;

export async function main(args: readonly string[]): Promise<void> {
  const { values, positionals, tokens } = parseArgs({
    args: [...args], allowPositionals: true, strict: true, tokens: true,
    options: { input: { type: "string" }, output: { type: "string" },
      manifest: { type: "string" }, checkpoint: { type: "string" }, help: { type: "boolean" },
      "execute-local": { type: "boolean" }, "instance-id": { type: "string" },
      broadcast: { type: "boolean" }, "confirm-chain": { type: "string" },
      "confirm-proxy": { type: "string" }, "confirm-snapshot": { type: "string" },
      "signer-key-env": { type: "string" }, reverse: { type: "boolean" },
      "fault-after-mined": { type: "boolean" }, "rpc-alias": { type: "string" },
      "fork-block": { type: "string" }, port: { type: "string" }, evidence: { type: "string" } },
  });
  const suppliedOptions = tokens.filter((token) => token.kind === "option").map((token) => token.name);
  if (new Set(suppliedOptions).size !== suppliedOptions.length) {
    throw new PreparationError("INPUT", "duplicate options are not accepted");
  }
  if (values.help && positionals.length === 0) {
    console.log(help);
    return;
  }
  if (positionals.length !== 1) throw new PreparationError("INPUT", "exactly one command required");
  if (["prepare", "validate"].includes(positionals[0] ?? "")
    && suppliedOptions.some((name) => !["input", "output", "manifest", "help"].includes(name))) {
    throw new PreparationError("INPUT", "preparation commands accept no execution flags");
  }
  switch (positionals[0]) {
    case "rehearse": {
      if (!values["rpc-alias"] || !values["fork-block"] || !values.port || !values.checkpoint || !values.evidence
        || suppliedOptions.some((name) => !["rpc-alias", "fork-block", "port", "checkpoint", "evidence"].includes(name))) {
        throw new PreparationError("INPUT", "rehearse requires the exact pinned invocation");
      }
      console.log(JSON.stringify(await rehearse({ rpcAlias: values["rpc-alias"], forkBlock: values["fork-block"],
        port: values.port, checkpoint: values.checkpoint, evidence: values.evidence })));
      return;
    }
    case "prepare": {
      if (!values.input || !values.output || values.manifest || values.help) {
        throw new PreparationError("INPUT", "prepare requires only --input and --output");
      }
      const result = await prepareFile(values.input, values.output);
      console.log(JSON.stringify({ command: "prepare", manifestHash: result.normalizedHash,
        payloadHash: result.payloadHash, fullTask9: result.fullTask9, mode: "read-only" }));
      return;
    }
    case "validate": {
      if (!values.manifest || values.input || values.output || values.help) {
        throw new PreparationError("INPUT", "validate requires only --manifest");
      }
      const result = await validateManifest(values.manifest);
      console.log(JSON.stringify({ command: "validate", payloadHash: result.payloadHash,
        fullTask9: result.fullTask9, mode: "read-only" }));
      return;
    }
    default: {
      const command = positionals[0] === "resume" ? "resume" : stage.parse(positionals[0]);
      if (!values.manifest || !values.checkpoint || values.input || values.output || values.help) {
        throw new PreparationError("INPUT", "stage requires only manifest, checkpoint, and explicit execution options");
      }
      if (values["rpc-alias"] || values["fork-block"] || values.port || values.evidence) throw new PreparationError("INPUT", "rehearsal flags require rehearse");
      if (values["execute-local"] && values.broadcast) throw new PreparationError("INPUT", "execution modes are exclusive");
      let mode: Mode = { kind: "simulate" };
      if (values["execute-local"]) {
        if (!values["instance-id"] || values["confirm-chain"] || values["confirm-proxy"]
          || values["confirm-snapshot"] || values["signer-key-env"]) throw new PreparationError("INPUT", "local requires only exact instance confirmation");
        mode = { kind: "local", instanceId: values["instance-id"] };
      } else if (values.broadcast) {
        if (!values["confirm-chain"] || !values["confirm-proxy"] || !values["confirm-snapshot"]
          || !values["signer-key-env"] || values["instance-id"]) throw new PreparationError("INPUT", "all fresh public confirmations required");
        mode = { kind: "broadcast", chainId: values["confirm-chain"], proxy: values["confirm-proxy"].toLowerCase(),
          snapshotId: values["confirm-snapshot"].toLowerCase(), keyEnv: values["signer-key-env"] };
      } else if (values["instance-id"] || values["confirm-chain"] || values["confirm-proxy"]
        || values["confirm-snapshot"] || values["signer-key-env"]) throw new PreparationError("INPUT", "confirmation requires explicit mode");
      console.log(JSON.stringify(await execute({ command, manifestPath: values.manifest, checkpoint: values.checkpoint,
        mode, reverse: values.reverse ?? false, faultAfterMined: values["fault-after-mined"] ?? false })));
      return;
    }
  }
}

if (import.meta.main) {
  try {
    await main(process.argv.slice(2));
  } catch (error) {
    if (error instanceof PreparationError || error instanceof ExecutionError) console.error(JSON.stringify({ error: error.code, message: error.message }));
    else if (error instanceof z.ZodError) console.error(JSON.stringify({ error: "INPUT", issues: error.issues }));
    else console.error(JSON.stringify({ error: "INPUT", message: "command or file acquisition failed" }));
    process.exitCode = 1;
  }
}
