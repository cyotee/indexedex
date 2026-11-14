import { spawn } from "node:child_process";
import { once } from "node:events";
import { copyFile, mkdir, readFile, rm, readdir } from "node:fs/promises";
import { resolve, join, dirname } from "node:path";
import { z } from "zod";
import { Interface, keccak256 } from "ethers";
import { child, FORGE, ANVIL, launchAnvil } from "./rehearsal-process.js";
import { RehearsalChain, LEGACY, legacyAbi } from "./rehearsal-chain.js";
import { bootstrapManifest, captureOriginalInputBytes, interfaceFile, preparationFixture, replacementFixture, RECIPIENTS, save } from "./rehearsal-data.js";
import { DEV } from "./execution-rpc.js";
import { ExecutionError, intent, quantity, rpcLog } from "./execution-schema.js";
import { address, hash, hex } from "./schema.js";
import { exerciseRecovery } from "./rehearsal-recovery.js";
import { exerciseAdmission } from "./rehearsal-admission.js";
import { acquireClaimVaultShares } from "./rehearsal-claim-vault-source.js";
import { exerciseClaimVault } from "./rehearsal-claim-vault.js";
import { acquireWeightedReceipt } from "./rehearsal-weighted-receipt-source.js";
import { exerciseWeightedReceipt } from "./rehearsal-weighted-receipt.js";
import { acquireEarlierLiquid, exerciseEarlierLiquid } from "./rehearsal-earlier-liquid.js";
import { acquireHeldSeLp } from "./rehearsal-held-se-lp-source.js";
import { exerciseHeldSeLp } from "./rehearsal-held-se-lp.js";
import { acquireEarlierReceipt, exerciseEarlierReceipt } from "./rehearsal-earlier-receipt.js";
import { acquireDtfCustodyShares } from "./rehearsal-dtf-custody-source.js";
import { exerciseDtfCustodySe } from "./rehearsal-dtf-custody-se.js";
import { exerciseWeightedSy } from "./rehearsal-weighted-sy.js";
import { acquireClaimedSy } from "./rehearsal-claimed-sy-source.js";
import { exerciseClaimedSy } from "./rehearsal-claimed-sy.js";
import { checkClaimedSyIntake } from "./rehearsal-claimed-sy-intake.js";
import { exerciseClaimedSyTransfer } from "./rehearsal-claimed-sy-transfer.js";
import { exerciseWeightedLiquid } from "./rehearsal-weighted-liquid.js";
import { exerciseOwnerBond, exerciseOrdinaryDeposit } from "./rehearsal-owner-bond.js";
import { checkPreparation, checkRemainingOrder, interruptedReceipt, recoveredReceipt, captureLinkedLibraries } from "./rehearsal-proof.js";
import { loadSavedBundle } from "./bundle.js";
import { rejectChangedBundles, relocateExecution } from "./rehearsal-portable.js";

const PIN_HASH = "0xc497433dd691a40cb85959cfeba2e3fff85a975ae060612d984998e1d5765733";
async function resolveAlias(): Promise<string> {
  const config = spawn(FORGE, ["config", "--json"], { env: process.env, stdio: ["ignore", "pipe", "pipe"] });
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
  readonly bundle: string;
}) {
  if (options.rpcAlias !== "robinhood_mainnet_alchemy" || options.forkBlock !== "108944663"
    || !["18567", "18568", "18569", "18571", "18573", "18575"].includes(options.port)
    || options.checkpoint !== (options.port === "18575" ? ".omo-runtime/dtf-migration-portable/checkpoints"
      : options.port === "18573" ? ".omo-runtime/dtf-migration-claimed-sy/checkpoints"
      : options.port === "18571" ? ".omo-runtime/dtf-migration-held-se-lp/checkpoints"
      : options.port === "18569" ? ".omo-runtime/dtf-migration-earlier-liquid/checkpoints" : options.port === "18568"
      ? ".omo-runtime/dtf-migration-earlier-receipt/checkpoints" : ".omo-runtime/dtf-migration-weighted-receipt/checkpoints")) {
    throw new ExecutionError("DOMAIN", "rehearsal identity is fixed by the CLI contract");
  }
  const authorities = await loadSavedBundle(options.bundle);
  if (authorities.kind !== "authorities") throw new ExecutionError("DOMAIN", "rehearsal requires a complete authority bundle");
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
  await save(join(evidence, "anvil-command.json"), { command: [ANVIL, ...args.map((a) => a === upstream ? "<resolved archive alias>" : a)] });
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
  const cli = async (args: readonly string[], expected: "success" | "fault" | "reject" | "reject-bundle" = "success") => {
    const rejecting = expected === "reject" || expected === "reject-bundle";
    const nonceBefore = rejecting ? await chain.send("eth_getTransactionCount", [DEV, "latest"]) : undefined;
    const result = await child([process.execPath, "scripts/recovery/dtf-migration/cli.ts", ...args],
      join(evidence, `${String(++sequence).padStart(3, "0")}-${args[0]}.log`));
    if (expected === "success" && result.code !== 0) throw new ExecutionError("STATE", `CLI ${args[0]} failed; see command evidence`);
    if (expected === "fault" && (result.signal !== "SIGKILL" || !result.output.includes('"fault":"mined-before-checkpoint"'))) {
      throw new ExecutionError("STATE", "expected actual mined interruption did not occur");
    }
    if (rejecting) {
      if (result.code !== 1) throw new ExecutionError("STATE", "negative did not fail with a controlled rejection");
      const rejected = z.object({ error: expected === "reject" ? z.literal("DOMAIN")
        : z.enum(["DOMAIN", "PROVENANCE", "INPUT"]) }).passthrough().parse(JSON.parse(result.output.trim()));
      const nonceAfter = await chain.send("eth_getTransactionCount", [DEV, "latest"]);
      if (nonceBefore !== nonceAfter) throw new ExecutionError("STATE", "rejected command submitted a transaction");
      await save(join(evidence, `${String(sequence).padStart(3, "0")}-rejection.json`), { nonceBefore, nonceAfter, error: rejected.error });
    }
    return result;
  };
  try {
    const pin = z.object({ hash, number: z.string(), l1BlockNumber: z.string().optional() }).passthrough().parse(
      await chain.send("eth_getBlockByNumber", ["0x67e5d17", false]));
    if (pin.hash !== PIN_HASH) throw new ExecutionError("DOMAIN", "historical header does not match");
    await save(join(evidence, "historical-header.json"), pin);
    const claimedAcquisition = ["18573", "18575"].includes(options.port) ? await acquireClaimedSy(chain, evidence) : [];
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
    const environment: NodeJS.ProcessEnv = { ...process.env, SENDER: DEV, OPERATOR_ENVIRONMENT_OUTPUT: environmentPath };
    delete environment["PRIVATE_KEY"];
    const setup = await child([FORGE, "script", "--use", "solar",
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
    const receiptAcquisition = await acquireWeightedReceipt(chain, evidence);
    const earlierAcquisition = await acquireEarlierReceipt(chain, evidence);
    const earlierLiquidAcquisition = await acquireEarlierLiquid(chain, evidence);
    const heldSeLpAcquisition = ["18571", "18573", "18575"].includes(options.port) ? await acquireHeldSeLp(chain, evidence) : [];
    if (!["18571", "18573", "18575"].includes(options.port)) await save(join(evidence, "held-se-lp-acquisition.json"), {
      rows: [], disposition: "not selected on the retained earlier rehearsal ports",
    });
    const manifest = await bootstrapManifest(chain, environmentPath, authorities.sources);
    let pre = join(evidence, "pre-capture.json");
    await save(pre, manifest);
    if (options.port === "18575") {
      pre = (await relocateExecution({ manifestPath: pre, evidence, label: "funding", cli })).path;
    }
    const local = ["--execute-local", "--instance-id", manifest.local?.instanceId ?? ""];
    const deployCheckpoint = join(runtime, "deploy");
    await cli(["deploy", "--manifest", pre, "--checkpoint", deployCheckpoint]);
    await cli(["deploy", "--manifest", pre, "--checkpoint", deployCheckpoint, ...local, "--fault-after-mined"], "fault");
    const preparedFault = await interruptedReceipt(chain, deployCheckpoint, join(evidence, "preparation-before-resume.json"));
    if (preparedFault.intent.method !== "prepareSyChildren"
      || await chain.send("eth_getCode", [manifest.proxy, "latest"]) !== "0x") {
      throw new ExecutionError("STATE", "preparation interruption already published parent");
    }
    const preparationNonce = BigInt(quantity.parse(await chain.send("eth_getTransactionCount", [DEV, "latest"])));
    await cli(["resume", "--manifest", pre, "--checkpoint", deployCheckpoint]);
    if (BigInt(quantity.parse(await chain.send("eth_getTransactionCount", [DEV, "latest"]))) !== preparationNonce) {
      throw new ExecutionError("STATE", "read-only preparation resume sent a transaction");
    }
    await cli(["resume", "--manifest", pre, "--checkpoint", deployCheckpoint, ...local]);
    await recoveredReceipt(preparedFault, deployCheckpoint, join(evidence, "preparation-resumed.json"));
    if (BigInt(quantity.parse(await chain.send("eth_getTransactionCount", [DEV, "latest"]))) !== preparationNonce + 1n) {
      throw new ExecutionError("STATE", "preparation resume did not submit exactly one final transaction");
    }
    const deploymentGas = [];
    for (const name of await readdir(deployCheckpoint)) {
      if (!name.endsWith(".intent.json")) continue;
      const record = intent.parse(JSON.parse(await readFile(join(deployCheckpoint, name), "utf8")));
      const tx = z.object({ gas: quantity }).passthrough().parse(
        await chain.send("eth_getTransactionByHash", [record.transactionHash]));
      const mined = await chain.canonicalReceipt(record.transactionHash);
      if (!mined || BigInt(mined.status) !== 1n || BigInt(tx.gas) > 32_000_000n) {
        throw new ExecutionError("STATE", "deployment did not succeed within the target envelope");
      }
      deploymentGas.push({ method: record.method, transactionHash: record.transactionHash,
        envelope: BigInt(tx.gas).toString(), gasUsed: BigInt(quantity.parse(mined["gasUsed"])).toString() });
    }
    if (deploymentGas.length !== 2) throw new ExecutionError("STATE", "expected preparation and final deployment receipts");
    await save(join(evidence, "bounded-deployment-gas.json"), deploymentGas);
    const deployedAbi = await interfaceFile("out/IUniswapV4DetfMigration.sol/IUniswapV4DetfMigration.json");
    const loupe = new Interface([
      "function facetAddresses() view returns(address[])",
      "function facetName() view returns(string)",
    ]);
    const deployedBindings = [];
    const components = [{ role: "parent", address: manifest.proxy }];
    for (const method of ["bondNftVault", "rebasingClaimToken", "rawSY", "stakingSY", "migrationSyRewardToken"]) {
      components.push({ role: method, address: address.parse((await chain.call(manifest.proxy, deployedAbi, method))[0]) });
    }
    for (const component of components) {
      const code = hex.parse(await chain.send("eth_getCode", [component.address, "latest"]));
      const facets = z.array(address).parse((await chain.call(component.address, loupe, "facetAddresses"))[0]);
      const boundFacets = [];
      for (const facet of facets) {
        const runtime = hex.parse(await chain.send("eth_getCode", [facet, "latest"]));
        const name = z.string().parse((await chain.call(facet, loupe, "facetName"))[0]);
        if ((runtime.length - 2) / 2 > 24576) throw new ExecutionError("STATE", "actual deployed facet exceeds EIP170");
        boundFacets.push({ address: facet, name, code: runtime, codeHash: keccak256(runtime) });
      }
      deployedBindings.push({ ...component, code, codeHash: keccak256(code), facets: boundFacets });
    }
    await save(join(evidence, "deployed-runtime-bindings.json"), deployedBindings);
    await captureLinkedLibraries(chain, deployedBindings.flatMap((component) => component.facets), evidence);
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
    let input = await preparationFixture(chain, manifest, evidence, {
      custodySe: custodyAcquisition, claimVault: claimAcquisition, weightedReceipt: receiptAcquisition,
      earlierReceipt: earlierAcquisition, earlierLiquid: earlierLiquidAcquisition,
      heldSeLp: heldSeLpAcquisition,
      claimedSy: claimedAcquisition,
    });
    const prepared = join(evidence, "prepared");
    await captureOriginalInputBytes(input, join(evidence, "original-input-bytes.json"));
    await cli(["prepare", "--input", join(evidence, "input.json"), "--output", prepared]);
    await cli(["validate", "--manifest", join(prepared, "manifest.json")]);
    await checkPreparation({ input, evidence, cli });
    if (["18573", "18575"].includes(options.port)) await checkClaimedSyIntake(chain, input, evidence);
    let post = { ...manifest, snapshotId: input.domain.snapshotId, preparedManifest: join(prepared, "manifest.json") };
    let postPath = join(evidence, "post-capture.json");
    await save(postPath, post);
    const originalPostPath = postPath;
    if (options.port === "18575") {
      const relocated = await relocateExecution({ manifestPath: postPath, evidence, label: "configuration", cli });
      if (!relocated.domain.prepared || !relocated.domain.manifest.preparedManifest || !relocated.domain.manifest.snapshotId) {
        throw new ExecutionError("STATE", "relocated post-capture domain lacks preparation");
      }
      postPath = relocated.path;
      post = { ...relocated.domain.manifest, preparedManifest: relocated.domain.manifest.preparedManifest,
        snapshotId: relocated.domain.manifest.snapshotId };
      input = relocated.domain.prepared.input;
      await rejectChangedBundles({ manifestPath: postPath, evidence, local, cli });
    }
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
    if (options.port === "18575") {
      await cli(["resume", "--manifest", originalPostPath, "--checkpoint", issue, ...local], "reject");
      const firstPath = join(evidence, "relocation-configuration/materialized-a/execution.json");
      await cli(["resume", "--manifest", firstPath, "--checkpoint", issue, ...local], "reject");
    }
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
    await captureOriginalInputBytes(input, join(evidence, "replacement-original-input-bytes.json"));
    const replacement = join(evidence, "replacement");
    await cli(["prepare", "--input", join(evidence, "replacement-input.json"), "--output", replacement]);
    const { bundle: _oldBundle, ...nativePost } = post;
    post = { ...nativePost, preparedManifest: join(replacement, "manifest.json") };
    postPath = join(evidence, "replacement-execution.json");
    await save(postPath, post);
    if (options.port === "18575") {
      const relocated = await relocateExecution({ manifestPath: postPath, evidence, label: "replacement", cli });
      if (!relocated.domain.prepared || !relocated.domain.manifest.preparedManifest || !relocated.domain.manifest.snapshotId) {
        throw new ExecutionError("STATE", "relocated replacement domain lacks preparation");
      }
      postPath = relocated.path;
      post = { ...relocated.domain.manifest, preparedManifest: relocated.domain.manifest.preparedManifest,
        snapshotId: relocated.domain.manifest.snapshotId };
      input = relocated.domain.prepared.input;
    }
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
    await exerciseClaimedSy({ chain, manifest: post, input, evidence, phase: "stage1" });
    await exerciseDtfCustodySe({ chain, manifest: post, input, evidence, phase: "stage1" });
    await exerciseClaimVault({ chain, manifest: post, input, evidence, phase: "stage1" });
    await exerciseWeightedReceipt({ chain, manifest: post, input, evidence, phase: "stage1" });
    await exerciseEarlierReceipt({ chain, manifest: post, input, evidence, phase: "stage1" });
    await exerciseEarlierLiquid({ chain, manifest: post, input, evidence, phase: "stage1" });
    await exerciseHeldSeLp({ chain, manifest: post, input, evidence, phase: "stage1" });
    const activate = async () => {
      await exerciseOwnerBond({ chain, manifest: post, manifestPath: postPath, evidence, runtime, local, cli });
      await cli(["activate", "--manifest", postPath, "--checkpoint", join(runtime, "activate"), ...local]);
    };
    if (input.weightedSy.some((row) => row.claimedOrigin)) {
      await exerciseClaimedSyTransfer({ chain, manifest: post, input, evidence, activate });
    } else await activate();
    await exerciseOrdinaryDeposit(chain, post, evidence);
    await exerciseWeightedLiquid({ chain, manifest: post, input, evidence, phase: "partial" });
    await exerciseRecovery({ chain, manifest: post, input, evidence, runtime, cli, local });
    await exerciseAdmission({ chain, manifest: post, input, evidence, activated: true, late: true });
    await exerciseWeightedLiquid({ chain, manifest: post, input, evidence, phase: "final" });
    await exerciseWeightedSy({ chain, manifest: post, input, evidence, phase: "partial" });
    await chain.send("evm_setNextBlockTimestamp", [Number(await chain.timestamp() + 86400n)]);
    await chain.send("evm_mine", []);
    await exerciseWeightedSy({ chain, manifest: post, input, evidence, phase: "final" });
    if (["18573", "18575"].includes(options.port)) {
      await exerciseClaimedSy({ chain, manifest: post, input, evidence, phase: "partial" });
      await chain.send("evm_setNextBlockTimestamp", [Number(await chain.timestamp() + 86400n)]);
      await chain.send("evm_mine", []);
      await exerciseClaimedSy({ chain, manifest: post, input, evidence, phase: "terminal" });
    }
    await exerciseDtfCustodySe({ chain, manifest: post, input, evidence, phase: "partial" });
    await chain.send("evm_setNextBlockTimestamp", [Number(await chain.timestamp() + 86400n)]);
    await chain.send("evm_mine", []);
    await exerciseDtfCustodySe({ chain, manifest: post, input, evidence, phase: "final" });
    await exerciseClaimVault({ chain, manifest: post, input, evidence, phase: "partial" });
    await chain.send("evm_setNextBlockTimestamp", [Number(await chain.timestamp() + 86400n)]);
    await chain.send("evm_mine", []);
    await exerciseClaimVault({ chain, manifest: post, input, evidence, phase: "final" });
    await exerciseWeightedReceipt({ chain, manifest: post, input, evidence, phase: "partial" });
    await chain.send("evm_setNextBlockTimestamp", [Number(await chain.timestamp() + 86400n)]);
    await chain.send("evm_mine", []);
    await exerciseWeightedReceipt({ chain, manifest: post, input, evidence, phase: "residual" });
    await exerciseEarlierReceipt({ chain, manifest: post, input, evidence, phase: "partial" });
    await exerciseEarlierReceipt({ chain, manifest: post, input, evidence, phase: "changed-rate" });
    await exerciseEarlierLiquid({ chain, manifest: post, input, evidence, phase: "partial" });
    await exerciseHeldSeLp({ chain, manifest: post, input, evidence, phase: "partial" });
    await chain.send("evm_setNextBlockTimestamp", [Number(await chain.timestamp() + 86400n)]);
    await chain.send("evm_mine", []);
    await exerciseEarlierLiquid({ chain, manifest: post, input, evidence, phase: "terminal" });
    await exerciseHeldSeLp({ chain, manifest: post, input, evidence, phase: "terminal" });
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
