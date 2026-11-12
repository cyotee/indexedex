import { spawn } from "node:child_process";
import { once } from "node:events";
import { copyFile, mkdir, readFile, rm, readdir } from "node:fs/promises";
import { resolve, join, dirname } from "node:path";
import { z } from "zod";
import { Interface } from "ethers";
import { child, FOUNDRY, launchAnvil } from "./rehearsal-process.js";
import { RehearsalChain, LEGACY, legacyAbi } from "./rehearsal-chain.js";
import { bootstrapManifest, interfaceFile, preparationFixture, replacementFixture, RECIPIENTS, save } from "./rehearsal-data.js";
import { DEV } from "./execution-rpc.js";
import { ExecutionError, rpcLog } from "./execution-schema.js";
import { hash } from "./schema.js";
import { exerciseRecovery } from "./rehearsal-recovery.js";
import { exerciseAdmission } from "./rehearsal-admission.js";
import { acquireClaimVaultShares } from "./rehearsal-claim-vault-source.js";
import { exerciseClaimVault } from "./rehearsal-claim-vault.js";
import { acquireDtfCustodyShares } from "./rehearsal-dtf-custody-source.js";
import { exerciseDtfCustodySe } from "./rehearsal-dtf-custody-se.js";
import { exerciseWeightedSy } from "./rehearsal-weighted-sy.js";
import { exerciseWeightedLiquid } from "./rehearsal-weighted-liquid.js";
import { exerciseOwnerBond, exerciseOrdinaryDeposit } from "./rehearsal-owner-bond.js";
import { checkPreparation, checkRemainingOrder, interruptedReceipt, recoveredReceipt } from "./rehearsal-proof.js";

const PIN_HASH = "0xc497433dd691a40cb85959cfeba2e3fff85a975ae060612d984998e1d5765733";
async function resolveAlias(): Promise<string> {
  const config = spawn(join(FOUNDRY, "forge"), ["config", "--json"], { env: process.env, stdio: ["ignore", "pipe", "pipe"] });
  const exit = once(config, "exit", { signal: AbortSignal.timeout(15000) });
  let output = "";
  config.stdout?.on("data", (data: Buffer) => { output += data.toString(); });
  config.stderr?.resume();
  if ((await exit)[0] !== 0) throw new ExecutionError("RPC", "existing Foundry alias resolution failed");
  const parsed = z.object({ rpc_endpoints: z.record(z.string(), z.string()) }).passthrough().parse(JSON.parse(output));
  const url = parsed.rpc_endpoints["robinhood_mainnet_alchemy"]?.replace(/\$\{([A-Z][A-Z0-9_]*)\}/g,
    (match: string, key: string) => process.env[key] ?? match);
  if (!url || url.includes("${")) throw new ExecutionError("RPC", "existing archive credential is unavailable");
  return url;
}

export async function rehearse(options: {
  readonly rpcAlias: string; readonly forkBlock: string; readonly port: string;
  readonly checkpoint: string; readonly evidence: string;
}) {
  if (options.rpcAlias !== "robinhood_mainnet_alchemy" || options.forkBlock !== "108944663" || options.port !== "18566"
    || options.checkpoint !== ".omo-runtime/dtf-migration-claim-vault/checkpoints") {
    throw new ExecutionError("DOMAIN", "rehearsal identity is fixed by the CLI contract");
  }
  const evidence = resolve(options.evidence, `rehearsal-${Date.now()}`);
  const runtime = resolve(options.checkpoint);
  await mkdir(evidence, { recursive: true });
  const upstream = await resolveAlias();
  await mkdir(dirname(runtime), { recursive: true });
  // Rehearsals never reuse an earlier node's runtime. Evidence remains outside it.
  await mkdir(runtime, { recursive: false, mode: 0o700 });
  const args = ["--host", "127.0.0.1", "--port", options.port, "--chain-id", "4663",
    "--fork-url", upstream, "--fork-block-number", options.forkBlock, "--gas-limit", "100000000",
    "--disable-min-priority-fee", "--balance", "1000000"];
  await save(join(evidence, "anvil-command.json"), { command: [join(FOUNDRY, "anvil"), ...args.map((a) => a === upstream ? "<resolved archive alias>" : a)] });
  let node: Awaited<ReturnType<typeof launchAnvil>>;
  try { node = await launchAnvil(args, join(evidence, "anvil.log"), upstream); }
  catch (error) {
    await rm(runtime, { recursive: true });
    await save(join(evidence, "cleanup.json"), { node: "launch failed and process stopped", runtime: "removed" });
    throw error;
  }
  const chain = new RehearsalChain(options.port);
  const previousRpc = process.env["DTF_OPERATOR_LOCAL_RPC"];
  process.env["DTF_OPERATOR_LOCAL_RPC"] = chain.endpoint.toString();
  let sequence = 0;
  const cli = async (args: readonly string[], expected: "success" | "fault" | "reject" = "success") => {
    const nonceBefore = expected === "reject" ? await chain.send("eth_getTransactionCount", [DEV, "latest"]) : undefined;
    const result = await child([process.execPath, "scripts/recovery/dtf-migration/cli.ts", ...args],
      join(evidence, `${String(++sequence).padStart(3, "0")}-${args[0]}.log`));
    if (expected === "success" && result.code !== 0) throw new ExecutionError("STATE", `CLI ${args[0]} failed; see command evidence`);
    if (expected === "fault" && (result.signal !== "SIGKILL" || !result.output.includes('"fault":"mined-before-checkpoint"'))) {
      throw new ExecutionError("STATE", "expected actual mined interruption did not occur");
    }
    if (expected === "reject") {
      if (result.code !== 1) throw new ExecutionError("STATE", "negative did not fail with a controlled rejection");
      z.object({ error: z.literal("DOMAIN") }).passthrough().parse(JSON.parse(result.output.trim()));
      const nonceAfter = await chain.send("eth_getTransactionCount", [DEV, "latest"]);
      if (nonceBefore !== nonceAfter) throw new ExecutionError("STATE", "rejected command submitted a transaction");
      await save(join(evidence, `${String(sequence).padStart(3, "0")}-rejection.json`), { nonceBefore, nonceAfter, error: "DOMAIN" });
    }
    return result;
  };
  try {
    const pin = z.object({ hash, number: z.string(), l1BlockNumber: z.string().optional() }).passthrough().parse(
      await chain.send("eth_getBlockByNumber", ["0x67e5d17", false]));
    if (pin.hash !== PIN_HASH) throw new ExecutionError("DOMAIN", "historical header does not match");
    await save(join(evidence, "historical-header.json"), pin);
    await chain.send("anvil_setBalance", [DEV, "0xd3c21bcecceda1000000"]);
    await chain.withHolder("3", async (holder) => {
      await chain.transact(LEGACY.weighted, { from: holder, data: legacyAbi.encodeFunctionData("claimBond", ["3", holder]) });
      const held = String((await chain.call(LEGACY.receipt, legacyAbi, "balanceOf", [holder]))[0]);
      const deadline = (await chain.timestamp() + 3600n).toString();
      await chain.transact(LEGACY.receipt, { from: holder,
        data: legacyAbi.encodeFunctionData("exchangeIn", [LEGACY.receipt, held, LEGACY.detf, held, holder, false, deadline]) });
      await chain.transact(LEGACY.detf, { from: holder, data: legacyAbi.encodeFunctionData("approve", [LEGACY.detf, held]) });
      await chain.transact(LEGACY.detf, { from: holder,
        data: legacyAbi.encodeFunctionData("exchangeIn", [LEGACY.detf, held, LEGACY.dtf, "10000000000000000000000", holder, false, deadline]) });
      await chain.transact(LEGACY.dtf, { from: holder,
        data: legacyAbi.encodeFunctionData("transfer", [DEV, "10000000000000000000000"]) });
    });
    const environmentPath = join(evidence, "environment.json");
    const environment: NodeJS.ProcessEnv = { ...process.env, SENDER: DEV, OPERATOR_ENVIRONMENT_OUTPUT: environmentPath,
      PATH: `${FOUNDRY}:${process.env["PATH"] ?? ""}` };
    delete environment["PRIVATE_KEY"];
    const setup = await child([join(FOUNDRY, "forge"), "script", "--use", "solar",
      "scripts/foundry/recovery/dtf-migration/Phase_08_Stage_00_OperatorEnvironment.s.sol:Phase_08_Stage_00_OperatorEnvironment",
      "--sig", "prepareEnvironment()", "--rpc-url", chain.endpoint.toString(), "--sender", DEV,
      "--unlocked", "--broadcast", "--slow", "--legacy", "--gas-price", "2000000000",
      "--gas-limit", "1000000000", "--gas-estimate-multiplier", "200"],
    join(evidence, "environment-stage.log"), environment);
    if (setup.code !== 0) throw new ExecutionError("STATE", "genuine environment stage failed");
    await copyFile("broadcast/Phase_08_Stage_00_OperatorEnvironment.s.sol/4663/prepareEnvironment-latest.json",
      join(evidence, "environment-mined-transactions.json"));
    const custodyAcquisition = await acquireDtfCustodyShares(chain, evidence);
    const claimAcquisition = await acquireClaimVaultShares(chain, evidence);
    const manifest = await bootstrapManifest(chain, environmentPath);
    const pre = join(evidence, "pre-capture.json");
    await save(pre, manifest);
    const local = ["--execute-local", "--instance-id", manifest.local?.instanceId ?? ""];
    await cli(["deploy", "--manifest", pre, "--checkpoint", join(runtime, "deploy")]);
    await cli(["deploy", "--manifest", pre, "--checkpoint", join(runtime, "deploy"), ...local]);
    const fund = join(runtime, "fund");
    await cli(["fund", "--manifest", pre, "--checkpoint", fund, ...local, "--fault-after-mined"], "fault");
    const donationFault = await interruptedReceipt(chain, fund, join(evidence, "donation-before-resume.json"));
    const donorNonce = await chain.send("eth_getTransactionCount", [DEV, "latest"]);
    await cli(["resume", "--manifest", pre, "--checkpoint", fund]);
    if (await chain.send("eth_getTransactionCount", [DEV, "latest"]) !== donorNonce) throw new ExecutionError("STATE", "default resume sent a transaction");
    await cli(["resume", "--manifest", pre, "--checkpoint", fund, ...local]);
    await recoveredReceipt(donationFault, fund, join(evidence, "donation-resumed.json"));
    await cli(["resume", "--manifest", pre, "--checkpoint", fund, ...local, "--reverse"], "reject");
    const migration = await interfaceFile("out/IUniswapV4DetfMigration.sol/IUniswapV4DetfMigration.json");
    const receivedEvent = migration.getEvent("MigrationCapitalReceived");
    if (!receivedEvent) throw new ExecutionError("STATE", "missing donation event ABI");
    const fundingLogs = z.array(rpcLog).parse(await chain.send("eth_getLogs", [{
      address: manifest.proxy, fromBlock: "0x67e5d17", toBlock: "latest", topics: [receivedEvent.topicHash],
    }]));
    const fundingTotals = new Map<string, bigint>();
    for (const log of fundingLogs) {
      const parsed = migration.parseLog({ topics: [...log.topics], data: log.data });
      if (!parsed || String(parsed.args[0]).toLowerCase() !== DEV) throw new ExecutionError("STATE", "unexpected funding donor");
      const token = String(parsed.args[1]).toLowerCase();
      fundingTotals.set(token, (fundingTotals.get(token) ?? 0n) + z.bigint().parse(parsed.args[2]));
    }
    if (fundingTotals.get(manifest.deployment?.weth ?? "") !== 1000n * 10n ** 18n
      || fundingTotals.get(LEGACY.dtf) !== 1000n * 10n ** 18n) throw new ExecutionError("STATE", "donation was duplicated or incompletely recovered");
    const supplyAbi = new Interface(["function totalSupply() view returns(uint256)"]);
    const genesisSupply = String((await chain.call(manifest.proxy, supplyAbi, "totalSupply"))[0]);
    await save(join(evidence, "funding-observation.json"), { donorNonce,
      totals: Object.fromEntries([...fundingTotals].map(([token, amount]) => [token, amount.toString()])),
      actualCapitalEvents: fundingLogs.length, genesisSupply });
    await cli(["capture", "--manifest", pre, "--checkpoint", join(runtime, "capture"), ...local]);
    let input = await preparationFixture(chain, manifest, evidence, { custodySe: custodyAcquisition, claimVault: claimAcquisition });
    const prepared = join(evidence, "prepared");
    await cli(["prepare", "--input", join(evidence, "input.json"), "--output", prepared]);
    await cli(["validate", "--manifest", join(prepared, "manifest.json")]);
    await checkPreparation({ input, evidence, cli });
    let post = { ...manifest, snapshotId: input.domain.snapshotId, preparedManifest: join(prepared, "manifest.json") };
    let postPath = join(evidence, "post-capture.json");
    await save(postPath, post);
    await cli(["configure", "--manifest", postPath, "--checkpoint", join(runtime, "configure"), ...local, "--reverse"]);
    const supplyBefore = String((await chain.call(manifest.proxy, supplyAbi, "totalSupply"))[0]);
    if (supplyBefore !== genesisSupply) throw new ExecutionError("STATE", "configuration minted supply");
    const issue = join(runtime, "issue");
    await cli(["independent-issue", "--manifest", postPath, "--checkpoint", issue, ...local, "--fault-after-mined"], "fault");
    const issueFault = await interruptedReceipt(chain, issue, join(evidence, "issuance-before-resume.json"));
    const issueNonce = await chain.send("eth_getTransactionCount", [DEV, "latest"]);
    await cli(["resume", "--manifest", postPath, "--checkpoint", issue]);
    if (await chain.send("eth_getTransactionCount", [DEV, "latest"]) !== issueNonce) throw new ExecutionError("STATE", "default issuance resume sent");
    await cli(["resume", "--manifest", postPath, "--checkpoint", issue, ...local, "--reverse"]);
    await recoveredReceipt(issueFault, issue, join(evidence, "issuance-resumed.json"));
    await checkRemainingOrder(input, issue, join(evidence, "reordered-issuance.json"));
    await cli(["verify", "--manifest", postPath, "--checkpoint", join(runtime, "verify")]);
    const unclaimed = (await chain.call(manifest.proxy, migration, "independentIssuance",
      [RECIPIENTS[3]]))[0];
    if (unclaimed.issued || unclaimed.bondTokenId !== 0n) throw new ExecutionError("STATE", "unselected configuration issued");
    await save(join(evidence, "issuance-observation.json"), { supplyBefore,
      supplyAfter: String((await chain.call(manifest.proxy, supplyAbi, "totalSupply"))[0]),
      unclaimedIssued: unclaimed.issued, unclaimedBond: String(unclaimed.bondTokenId) });
    for (const field of ["chainId", "proxy", "package", "snapshotId"] as const) {
      const changed = { ...post, [field]: field === "chainId" ? "1" : field === "snapshotId" ? `0x${"9".repeat(64)}` : "0x1111111111111111111111111111111111111111" };
      const changedPath = join(evidence, `reject-${field}.json`);
      await save(changedPath, changed);
      await cli(["resume", "--manifest", changedPath, "--checkpoint", issue, ...local], "reject");
    }
    const tamperedPath = join(evidence, "tampered-prepared.json");
    await save(tamperedPath, { ...JSON.parse(await readFile(post.preparedManifest, "utf8")), payloadHash: "f".repeat(64) });
    const tamperedExecution = join(evidence, "reject-payload.json");
    await save(tamperedExecution, { ...post, preparedManifest: tamperedPath });
    await cli(["resume", "--manifest", tamperedExecution, "--checkpoint", issue, ...local], "reject");
    const issuedBeforeReplacement = (await chain.call(manifest.proxy, migration, "independentIssuance", [RECIPIENTS[0]])).toString();
    const replacementSupply = String((await chain.call(manifest.proxy, supplyAbi, "totalSupply"))[0]);
    input = await replacementFixture(input, evidence);
    const replacement = join(evidence, "replacement");
    await cli(["prepare", "--input", join(evidence, "replacement-input.json"), "--output", replacement]);
    post = { ...post, preparedManifest: join(replacement, "manifest.json") };
    postPath = join(evidence, "replacement-execution.json");
    await save(postPath, post);
    await cli(["configure", "--manifest", postPath, "--checkpoint", join(runtime, "replacement"), ...local]);
    if ((await chain.call(manifest.proxy, migration, "independentIssuance", [RECIPIENTS[0]])).toString() !== issuedBeforeReplacement
      || String((await chain.call(manifest.proxy, supplyAbi, "totalSupply"))[0]) !== replacementSupply) {
      throw new ExecutionError("STATE", "full replacement modified delivered issuance or supply");
    }
    await save(join(evidence, "replacement-observation.json"), { issuedBeforeReplacement, replacementSupply,
      issuedAfterReplacement: (await chain.call(manifest.proxy, migration, "independentIssuance", [RECIPIENTS[0]])).toString() });
    await exerciseAdmission({ chain, manifest: post, input, evidence, activated: false });
    await exerciseWeightedLiquid({ chain, manifest: post, input, evidence, phase: "stage1" });
    await exerciseWeightedSy({ chain, manifest: post, input, evidence, phase: "stage1" });
    await exerciseDtfCustodySe({ chain, manifest: post, input, evidence, phase: "stage1" });
    await exerciseClaimVault({ chain, manifest: post, input, evidence, phase: "stage1" });
    await exerciseOwnerBond({ chain, manifest: post, manifestPath: postPath, evidence, runtime, local, cli });
    await cli(["activate", "--manifest", postPath, "--checkpoint", join(runtime, "activate"), ...local]);
    await exerciseOrdinaryDeposit(chain, post, evidence);
    await exerciseWeightedLiquid({ chain, manifest: post, input, evidence, phase: "partial" });
    await exerciseRecovery({ chain, manifest: post, input, evidence, runtime, cli, local });
    await exerciseAdmission({ chain, manifest: post, input, evidence, activated: true, late: true });
    await exerciseWeightedLiquid({ chain, manifest: post, input, evidence, phase: "final" });
    await exerciseWeightedSy({ chain, manifest: post, input, evidence, phase: "partial" });
    await chain.send("evm_setNextBlockTimestamp", [Number(await chain.timestamp() + 86400n)]);
    await chain.send("evm_mine", []);
    await exerciseWeightedSy({ chain, manifest: post, input, evidence, phase: "final" });
    await exerciseDtfCustodySe({ chain, manifest: post, input, evidence, phase: "partial" });
    await chain.send("evm_setNextBlockTimestamp", [Number(await chain.timestamp() + 86400n)]);
    await chain.send("evm_mine", []);
    await exerciseDtfCustodySe({ chain, manifest: post, input, evidence, phase: "final" });
    await exerciseClaimVault({ chain, manifest: post, input, evidence, phase: "partial" });
    await chain.send("evm_setNextBlockTimestamp", [Number(await chain.timestamp() + 86400n)]);
    await chain.send("evm_mine", []);
    await exerciseClaimVault({ chain, manifest: post, input, evidence, phase: "final" });
    await cli(["verify", "--manifest", postPath, "--checkpoint", join(runtime, "verify-after")]);
    return { evidence, fullTask9: "open", status: "bounded-rehearsal-complete" };
  } catch (error) {
    if (error instanceof Error) await save(join(evidence, "failure.json"), {
      name: error.name, message: error instanceof ExecutionError ? error.message : "local rehearsal dependency failed",
      code: error instanceof ExecutionError ? error.code : "LOCAL_DEPENDENCY",
    });
    throw error;
  } finally {
    try {
      await save(join(evidence, "fixture-receipts.json"), chain.receipts);
      // Copy raw bytes, including an interrupted partial publication, as evidence.
      for (const name of await readdir(runtime)) {
        const source = join(runtime, name);
        const target = join(evidence, `journal-${name}`);
        await mkdir(target);
        for (const file of await readdir(source)) await copyFile(join(source, file), join(target, file));
      }
    } finally {
      chain.close();
      await node.close();
      await rm(runtime, { recursive: true });
      if (previousRpc === undefined) delete process.env["DTF_OPERATOR_LOCAL_RPC"];
      else process.env["DTF_OPERATOR_LOCAL_RPC"] = previousRpc;
      await save(join(evidence, "cleanup.json"), { pid: node.pid, node: "exited", runtime: "removed", checkpoint: runtime, evidence: "retained" });
    }
  }
}
