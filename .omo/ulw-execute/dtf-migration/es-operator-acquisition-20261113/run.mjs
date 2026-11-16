import { RehearsalChain } from "/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-30-recovery-receipts/scripts/recovery/dtf-migration/rehearsal-chain.ts";
import { launchAnvil } from "/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-30-recovery-receipts/scripts/recovery/dtf-migration/rehearsal-process.ts";
import { acquireHeldSeLp } from "/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-30-recovery-receipts/scripts/recovery/dtf-migration/rehearsal-held-se-lp-source.ts";
import { ExecutionError } from "/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-30-recovery-receipts/scripts/recovery/dtf-migration/execution-schema.ts";

const evidence = "/Users/cyotee/Projects/indexedex/.omo/ulw-execute/dtf-migration/es-operator-acquisition-20261113";
const key = process.env.ALCHEMY_KEY;
if (!key) throw new ExecutionError("RPC", "Configured archive credential unavailable");
const upstream = `https://robinhood-mainnet.g.alchemy.com/v2/${encodeURIComponent(key)}`;
let node;
let chain;
try {
  node = await launchAnvil([
    "--host", "127.0.0.1", "--port", "18571", "--chain-id", "4663",
    "--fork-url", upstream, "--fork-block-number", "108944663",
    "--gas-limit", "100000000", "--disable-min-priority-fee", "--balance", "1000000",
  ], `${evidence}/anvil.log`, upstream);
  chain = new RehearsalChain("18571");
  const pin = await chain.send("eth_getBlockByNumber", ["0x67e5d17", false]);
  if (pin?.hash !== "0xc497433dd691a40cb85959cfeba2e3fff85a975ae060612d984998e1d5765733") {
    throw new ExecutionError("DOMAIN", "Historical pin differs");
  }
  const rows = await acquireHeldSeLp(chain, evidence);
  const earlierSe = rows.find((row) => row.source === "0xb7d4bb379d361ad442cddee53ea71a33957826a7");
  if (rows.length !== 4 || earlierSe?.units !== "10013") {
    throw new ExecutionError("STATE", "Four-source acquisition did not include exact E-S units");
  }
  console.log("ES_OPERATOR_ACQUISITION_OK", JSON.stringify({
    sources: rows.length, earlierSe, transactions: chain.receipts.length,
    scope: "owned fork; real legacy tokens; synthetic original allocations; no public transaction",
  }));
} catch (error) {
  const message = error instanceof Error ? `${error.name}: ${error.message}` : String(error);
  console.error(message.replaceAll(upstream, "<redacted-upstream>").replaceAll(key, "<redacted-key>"));
  process.exitCode = 1;
} finally {
  chain?.close();
  if (node) await node.close();
}
