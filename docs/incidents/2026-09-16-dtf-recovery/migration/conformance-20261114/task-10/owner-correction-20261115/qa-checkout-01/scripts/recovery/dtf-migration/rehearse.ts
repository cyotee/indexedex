import { spawn } from "node:child_process";
import { once } from "node:events";
import { copyFile, mkdir, readFile, rm, readdir } from "node:fs/promises";
import { resolve, join, dirname } from "node:path";
import { z } from "zod";
import { AbiCoder, Interface, keccak256 } from "ethers";
import { child, FORGE, ANVIL, launchAnvil } from "./rehearsal-process.js";
import { RehearsalChain, LEGACY, legacyAbi } from "./rehearsal-chain.js";
import { bootstrapManifest, captureOriginalInputBytes, interfaceFile, preparationFixture, replacementFixture, reconciledFixtureInput, RECIPIENTS, save, sourceFile } from "./rehearsal-data.js";
import { DEV, subscribeReceipt } from "./execution-rpc.js";
import { claimedWallet } from "./rehearsal-claimed-sy-source.js";
import { loadExecution } from "./execution-domain.js";
import { plan } from "./execution-plan.js";
import { execute } from "./execution.js";
import { canonical, fingerprint } from "./provenance.js";
import { ExecutionError, intent, quantity, rpcLog } from "./execution-schema.js";
import { address, hash, hex, pricingInputs, preparationInput } from "./schema.js";
import { exerciseRecovery, rejectInvalidHistory } from "./rehearsal-recovery.js";
import { exerciseAdmission } from "./rehearsal-admission.js";
import { acquireClaimVaultShares } from "./rehearsal-claim-vault-source.js";
import { exerciseClaimVault } from "./rehearsal-claim-vault.js";
import { acquireWeightedReceipt } from "./rehearsal-weighted-receipt-source.js";
import { exerciseWeightedReceipt } from "./rehearsal-weighted-receipt.js";
import { acquireEarlierLiquid, exerciseEarlierLiquid } from "./rehearsal-earlier-liquid.js";
import { acquireHeldSeLp } from "./rehearsal-held-se-lp-source.js";
import { exerciseHeldSeLp } from "./rehearsal-held-se-lp.js";
import { acquireEarlierReceipt, exerciseEarlierReceipt } from "./rehearsal-earlier-receipt.js";
import { acquireSetupFunding, acquireDtfCustodyShares } from "./rehearsal-dtf-custody-source.js";
import { exerciseDtfCustodySe } from "./rehearsal-dtf-custody-se.js";
import { exerciseWeightedSy } from "./rehearsal-weighted-sy.js";
import { acquireClaimedSy } from "./rehearsal-claimed-sy-source.js";
import { exerciseClaimedSy } from "./rehearsal-claimed-sy.js";
import { checkClaimedSyIntake } from "./rehearsal-claimed-sy-intake.js";
import { exerciseClaimedSyTransfer } from "./rehearsal-claimed-sy-transfer.js";
import { exerciseWeightedLiquid } from "./rehearsal-weighted-liquid.js";
import { exerciseOwnerBond, exerciseUnsetPricing, exerciseOrdinaryDeposit } from "./rehearsal-owner-bond.js";
import { surrenderNftThree, exerciseNftReceiverRollback, checkNftThreeModes } from "./rehearsal-nft-contributions.js";
import { sameBlockReplacement, checkPreparation, checkRemainingOrder, interruptedReceipt, recoveredReceipt, captureLinkedLibraries } from "./rehearsal-proof.js";
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

export async function rehearse(options: Parameters<typeof rehearseOne>[0]) {
  const selected = z.enum(["primary", "unset-pricing", "receiver-rollback"]).optional()
    .parse(process.env["DTF_REHEARSAL_SCENARIO"]);
  if (selected) return rehearseOne(options, selected);
  const primary = await rehearseOne(options, "primary");
  const unset = await rehearseOne({ ...options, evidence: join(primary.evidence, "unset-pricing") }, "unset-pricing");
  const receiver = await rehearseOne({ ...options, evidence: join(primary.evidence, "receiver-rollback") }, "receiver-rollback");
  if (new Set([primary.proxy, unset.proxy, receiver.proxy]).size !== 3) throw new ExecutionError("STATE", "separate scenarios reused a proxy address");
  await save(join(primary.evidence, "separate-proxy-scenarios.json"), { primary, unset, receiver });
  return { ...primary, separateScenarios: [unset, receiver] };
}

async function rehearseOne(options: {
  readonly rpcAlias: string; readonly forkBlock: string; readonly port: string;
  readonly checkpoint: string; readonly evidence: string;
  readonly bundle: string;
}, scenario: "primary" | "unset-pricing" | "receiver-rollback") {
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
  if (!authorities.rehearsalFundingEvidence) throw new ExecutionError("DOMAIN", "rehearsal requires declared funding evidence");
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
  const cli = async (args: readonly string[], expected: "success" | "fault" | "reject" | "reject-bundle" | "reject-state" = "success") => {
    const rejecting = expected === "reject" || expected === "reject-bundle" || expected === "reject-state";
    const nonceBefore = rejecting ? await chain.send("eth_getTransactionCount", [DEV, "latest"]) : undefined;
    const result = await child([process.execPath, "scripts/recovery/dtf-migration/cli.ts", ...args],
      join(evidence, `${String(++sequence).padStart(3, "0")}-${args[0]}.log`));
    if (expected === "success" && result.code !== 0) {
      if (args[0] === "resume" && !args.includes("--execute-local")) {
        const manifestPath = args[args.indexOf("--manifest") + 1];
        const checkpoint = args[args.indexOf("--checkpoint") + 1];
        if (manifestPath && checkpoint) {
          try { await execute({ command: "resume", manifestPath, checkpoint, mode: { kind: "simulate" },
            reverse: args.includes("--reverse"), faultAfterMined: false }); }
          catch (diagnostic) {
            if (diagnostic instanceof Error) await save(join(evidence, `${sequence}-resume-diagnostic.json`), {
              name: diagnostic.name, message: diagnostic.message.replaceAll(upstream, "<redacted-upstream>"),
              stack: diagnostic.stack?.replaceAll(upstream, "<redacted-upstream>") ?? null,
            });
          }
        }
      }
      throw new ExecutionError("STATE", `CLI ${args[0]} failed; see command evidence`);
    }
    if (expected === "fault" && (result.signal !== "SIGKILL" || !result.output.includes('"fault":"mined-before-checkpoint"'))) {
      throw new ExecutionError("STATE", "expected actual mined interruption did not occur");
    }
    if (rejecting) {
      if (result.code !== 1) throw new ExecutionError("STATE", "negative did not fail with a controlled rejection");
      const rejected = z.object({ error: expected === "reject-state" ? z.literal("STATE") : expected === "reject" ? z.literal("DOMAIN")
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
    const setupDonor = await acquireSetupFunding({ chain, evidence, authorities, reference: authorities.reference });
    const claimedAcquisition = ["18573", "18575"].includes(options.port) ? await acquireClaimedSy(chain, evidence) : [];
    const environmentPath = join(evidence, "environment.json");
    // Forge writes inside this owned checkout's configured filesystem boundary.
    // Preserve those exact output bytes in the separately selected evidence root.
    const stageEnvironmentPath = join(runtime, "environment-output", "environment.json");
    await mkdir(dirname(stageEnvironmentPath));
    const environment: NodeJS.ProcessEnv = { ...process.env, SENDER: DEV, OPERATOR_ENVIRONMENT_OUTPUT: stageEnvironmentPath,
      OPERATOR_REHEARSAL_SCENARIO: scenario };
    delete environment["PRIVATE_KEY"];
    const setup = await child([FORGE, "script", "--use", "solar",
      "scripts/foundry/recovery/dtf-migration/Phase_08_Stage_00_OperatorEnvironment.s.sol:Phase_08_Stage_00_OperatorEnvironment",
      "--sig", "prepareEnvironment()", "--rpc-url", chain.endpoint.toString(), "--sender", DEV,
      "--unlocked", "--broadcast", "--slow", "--legacy", "--gas-price", "2000000000",
      "--gas-limit", "1000000000", "--gas-estimate-multiplier", "200"],
    join(evidence, "environment-stage.log"), environment);
    if (setup.code !== 0) throw new ExecutionError("STATE", "genuine environment stage failed");
    await copyFile(stageEnvironmentPath, environmentPath);
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
    let manifest = await bootstrapManifest(chain, environmentPath, authorities.sources);
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
      if (record.method === "deployVault") {
        const receiptPath = join(evidence, "deployment-receipt.json");
        await save(receiptPath, mined);
        const receiptSource = await sourceFile("deployment-receipt", receiptPath);
        manifest = { ...manifest, deploymentReceipt: {
          path: receiptSource.path, sha256: receiptSource.sha256, bytes: receiptSource.bytes,
        }, deploymentBlockNumber: BigInt(mined.blockNumber).toString(), deploymentBlockHash: mined.blockHash,
        sources: [...manifest.sources, receiptSource] };
      }
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
    pre = join(evidence, "funding-execution.json");
    await save(pre, manifest);
    const fund = join(runtime, "fund");
    await cli(["fund", "--manifest", pre, "--checkpoint", fund, ...local, "--fault-after-mined"], "fault");
    const donationFault = await interruptedReceipt(chain, fund, join(evidence, "donation-before-resume.json"));
    const donorNonce = await chain.send("eth_getTransactionCount", [DEV, "latest"]);
    await cli(["resume", "--manifest", pre, "--checkpoint", fund]);
    if (await chain.send("eth_getTransactionCount", [DEV, "latest"]) !== donorNonce) throw new ExecutionError("STATE", "default resume sent a transaction");
    await cli(["resume", "--manifest", pre, "--checkpoint", fund, ...local]);
    await recoveredReceipt(donationFault, fund, join(evidence, "donation-resumed.json"));
    const completedFundingNonce = await chain.send("eth_getTransactionCount", [DEV, "latest"]);
    await cli(["resume", "--manifest", pre, "--checkpoint", fund, ...local]);
    if (await chain.send("eth_getTransactionCount", [DEV, "latest"]) !== completedFundingNonce) {
      throw new ExecutionError("STATE", "completed donation IDs were sent twice");
    }
    const donationOperations = plan(await loadExecution(pre), "fund");
    const donations = manifest.funding.donations;
    if (donations.length !== 2 || !donations[0] || !donations[1]) throw new ExecutionError("STATE", "two donation identities missing");
    const donationProofs = [];
    for (const [index, donation] of donations.entries()) {
      const group = donationOperations.slice(index * 3, index * 3 + 3);
      if (group.length !== 3) throw new ExecutionError("STATE", "donation approval/delivery operations missing");
      for (const [i, operation] of group.entries()) {
        const expected = fingerprint(canonical(i < 2
          ? { donation: donation.id, token: donation.tokens[i], transaction: operation.transaction }
          : { id: donation.id, transaction: operation.transaction }));
        const signed = intent.parse(JSON.parse(await readFile(join(fund, `${operation.id}.intent.json`), "utf8")));
        const mined = await chain.canonicalReceipt(signed.transactionHash);
        if (expected !== operation.id || !mined || BigInt(mined.status) !== 1n) throw new ExecutionError("STATE", "donation exact preimage or receipt differs");
        donationProofs.push({ donationId: donation.id, operation, expected, signed, receipt: mined });
      }
    }
    if (canonical(donationOperations.slice(0, 3).map((o) => o.transaction))
      !== canonical(donationOperations.slice(3, 6).map((o) => o.transaction))
      || new Set(donationProofs.map((p) => p.operation.id)).size !== 6) {
      throw new ExecutionError("STATE", "identical donation calldata did not preserve distinct IDs");
    }
    await save(join(evidence, "donation-identity-resume.json"), { donations, operations: donationProofs,
      interrupted: donationFault.intent.transactionHash, nonceAfterFirstMined: donorNonce,
      nonceAfterCompletion: completedFundingNonce, nonceAfterCompletedResume: completedFundingNonce,
      exactReceiptRecovered: true, completedResends: 0 });
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
    if (!manifest.deployment) throw new ExecutionError("DOMAIN", "manual rehearsal requires package token identities");
    const zero = "0x0000000000000000000000000000000000000000";
    const pricing = pricingInputs.parse({
      swapFeeWad: "3000000000000000", seigniorage: "50000000000000000", ethIndex: "0", dtfIndex: "1", detfIndex: "2",
      legs: [manifest.deployment.weth, manifest.deployment.originalDtf, manifest.proxy].map((token, i) => ({
        token, standardExchange: zero, mode: "0", rawReserve: i === 2 ? "1000000000000000" : "1000000000000000000000000",
        seReserve: "0", weight: i === 2 ? "400000000000000000" : "300000000000000000",
        invScale: i === 2 ? "1000000000000000000000000000" : "1000000000000000000",
        ratedScale: i === 2 ? "1000000000000000000000000000" : "1000000000000000000", rate: "0",
        deposit: { model: "0", exchange: zero, request: { tokenIn: zero, tokenOut: zero, holder: zero, mode: "0" },
          token0: zero, token1: zero, supply: "0", reserve0: "0", reserve1: "0", minimumLiquidity: "0" },
      })),
    });
    if (scenario === "unset-pricing") {
      const manifestPath = join(evidence, "unset-owner-execution.json");
      await save(manifestPath, manifest);
      await exerciseUnsetPricing({ chain, manifest, manifestPath, evidence, runtime, local, cli });
      return { evidence, proxy: manifest.proxy, status: "unset-pricing-scenario-complete" };
    }
    const bookType = migration.getFunction("migrationWeightedPricing")?.outputs[0];
    if (!bookType) throw new ExecutionError("DOMAIN", "manual book ABI missing");
    const bookIdFor = (inputs: typeof pricing) => keccak256(AbiCoder.defaultAbiCoder().encode(["string", bookType], [
      "IndexedEx.manual-weighted-original-credit", { version: 2, chainId: manifest.chainId, consumer: manifest.proxy,
        weth: manifest.deployment?.weth, originalDtf: manifest.deployment?.originalDtf, id: `0x${"0".repeat(64)}`, inputs },
    ]));
    const bookId = bookIdFor(pricing);
    manifest = { ...manifest, pricing, bookId };
    const pricingPath = join(evidence, "pricing-execution.json");
    await save(pricingPath, manifest);
    await cli(["set-pricing", "--manifest", pricingPath, "--checkpoint", join(runtime, "set-pricing"), ...local]);
    let input = await preparationFixture(chain, manifest, evidence, {
      custodySe: custodyAcquisition, claimVault: claimAcquisition, weightedReceipt: receiptAcquisition,
      earlierReceipt: earlierAcquisition, earlierLiquid: earlierLiquidAcquisition,
      heldSeLp: heldSeLpAcquisition,
      claimedSy: claimedAcquisition,
    });
    let preparationPath = join(evidence, "input.json");
    if (scenario === "receiver-rollback") {
      const original = input.nfts.find(row => row.original.collection === LEGACY.weighted && row.original.tokenId === "3");
      if (!original) throw new ExecutionError("STATE", "receiver scenario lacks exact NFT three originals");
      input = { ...input, nfts: [original], independent: [], weightedLiquid: [], weightedSy: [], dtfCustodySe: [],
        claimVault: [], weightedReceipt: [], earlierReceipt: [], earlierLiquid: [], heldSeLp: [] };
      preparationPath = join(evidence, "receiver-input.json");
      await save(preparationPath, input);
    }
    if ([...input.nfts.map((r) => r.original.originalWallet), ...input.independent.map((r) => r.recipient),
      ...input.weightedLiquid.map((r) => r.original.originalWallet), ...input.weightedSy.map((r) => r.original.originalWallet),
      ...input.dtfCustodySe.map((r) => r.original.originalWallet), ...input.claimVault.map((r) => r.original.originalWallet),
      ...input.weightedReceipt.map((r) => r.original.originalWallet), ...input.earlierReceipt.map((r) => r.original.originalWallet),
      ...input.earlierLiquid.map((r) => r.original.originalWallet), ...input.heldSeLp.map((r) => r.original.originalWallet)].includes(setupDonor)) {
      throw new ExecutionError("STATE", "setup donor is configured for compensation");
    }
    const prepared = join(evidence, "prepared");
    await captureOriginalInputBytes(input, join(evidence, "original-input-bytes.json"));
    await cli(["prepare", "--input", preparationPath, "--output", prepared]);
    await cli(["validate", "--manifest", join(prepared, "manifest.json")]);
    if (scenario === "primary") {
      await checkPreparation({ input, evidence, cli });
      await checkNftThreeModes(input, evidence, cli);
      if (["18573", "18575"].includes(options.port)) await checkClaimedSyIntake(chain, input, evidence);
    }
    let post = { ...manifest, bookId: input.domain.bookId, preparedManifest: join(prepared, "manifest.json") };
    let postPath = join(evidence, "post-capture.json");
    await save(postPath, post);
    const originalPostPath = postPath;
    if (options.port === "18575") {
      const relocated = await relocateExecution({ manifestPath: postPath, evidence, label: "configuration", cli });
      if (!relocated.domain.prepared || !relocated.domain.manifest.preparedManifest || !relocated.domain.manifest.bookId) {
        throw new ExecutionError("STATE", "relocated post-capture domain lacks preparation");
      }
      postPath = relocated.path;
      post = { ...relocated.domain.manifest, preparedManifest: relocated.domain.manifest.preparedManifest,
        bookId: relocated.domain.manifest.bookId };
      input = relocated.domain.prepared.input;
      await rejectChangedBundles({ manifestPath: postPath, evidence, local, cli });
    }
    await cli(["configure", "--manifest", postPath, "--checkpoint", join(runtime, "configure"), ...local, "--reverse"]);
    const supplyBefore = String((await chain.call(manifest.proxy, supplyAbi, "totalSupply"))[0]);
    if (supplyBefore !== genesisSupply) throw new ExecutionError("STATE", "configuration minted supply");
    if (scenario === "receiver-rollback") {
      await exerciseOwnerBond({ chain, manifest: post, manifestPath: postPath, evidence, runtime, local, cli });
      await cli(["activate", "--manifest", postPath, "--checkpoint", join(runtime, "receiver-activate"), ...local]);
      await exerciseNftReceiverRollback({ chain, manifest: post, evidence });
      return { evidence, proxy: manifest.proxy, status: "receiver-rollback-scenario-complete" };
    }
    const { bundle: _unboundBundle, ...unbound } = post;
    const unboundPath = join(evidence, "nonempty-unbound-census.json");
    await save(unboundPath, { ...unbound, preparedManifest: null });
    for (const command of ["owner-bond", "activate"]) await cli([command, "--manifest", unboundPath,
      "--checkpoint", join(evidence, `reject-unbound-${command}`, "checkpoint"), ...local], "reject-state");
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
    input = await reconciledFixtureInput(postPath, join(runtime, "configure"), issue);
    await rejectInvalidHistory(input, evidence, cli);
    const historyInputPath = join(evidence, "issued-history-input.json");
    await save(historyInputPath, input);
    const historyPrepared = join(evidence, "issued-history-prepared");
    await cli(["prepare", "--input", historyInputPath, "--output", historyPrepared]);
    const { bundle: _issuedBundle, ...issuedNative } = post;
    post = { ...issuedNative, preparedManifest: join(historyPrepared, "manifest.json") };
    postPath = join(evidence, "issued-history-execution.json");
    await save(postPath, post);
    await cli(["verify", "--manifest", postPath, "--checkpoint", join(runtime, "verify")]);
    const unclaimed = (await chain.call(manifest.proxy, migration, "independentIssuance",
      [RECIPIENTS[3]]))[0];
    if (unclaimed.issued || unclaimed.bondTokenId !== 0n) throw new ExecutionError("STATE", "unselected configuration issued");
    await save(join(evidence, "issuance-observation.json"), { supplyBefore,
      supplyAfter: String((await chain.call(manifest.proxy, supplyAbi, "totalSupply"))[0]),
      unclaimedIssued: unclaimed.issued, unclaimedBond: String(unclaimed.bondTokenId) });
    // A second immutable configure run has exactly one load. Its signed journal
    // is interrupted after mining and can therefore be completed after owner B.
    const fourth = input.independent.find((r) => r.recipient === RECIPIENTS[3]);
    if (!fourth || fourth.pricing.kind !== "retain") throw new ExecutionError("STATE", "missing accepted unissued A recipient");
    const aInput = preparationInput.parse({ ...input, independent: input.independent.map((r) => r !== fourth ? r : {
      ...r, evidenceId: `0x${fingerprint("synthetic-local interrupted A replacement")}`,
      pricing: { kind: "load", bookId, replaces: fourth.pricing.kind === "retain" ? fourth.pricing.accepted : null },
    }) });
    const aInputPath = join(evidence, "interrupted-a-input.json");
    await save(aInputPath, aInput);
    const aPrepared = join(evidence, "interrupted-a-prepared");
    await cli(["prepare", "--input", aInputPath, "--output", aPrepared]);
    const { bundle: _aBundle, ...aNative } = post;
    const aExecutionPath = join(evidence, "interrupted-a-execution.json");
    await save(aExecutionPath, { ...aNative, preparedManifest: join(aPrepared, "manifest.json") });
    const aCheckpoint = join(runtime, "interrupted-a");
    await cli(["configure", "--manifest", aExecutionPath, "--checkpoint", aCheckpoint, ...local, "--fault-after-mined"], "fault");
    const aFault = await interruptedReceipt(chain, aCheckpoint, join(evidence, "configure-a-before-resume.json"));
    const aDomain = await loadExecution(aExecutionPath);
    const aOperation = plan(aDomain, "configure")[0];
    if (!aOperation || aFault.intent.method !== "configureIndependentAllocations") throw new ExecutionError("STATE", "A fault was not a real configure");
    const bPricing = pricingInputs.parse({ ...pricing, seigniorage: "60000000000000000" });
    const bId = bookIdFor(bPricing);
    const bPath = join(evidence, "owner-b-pricing-execution.json");
    await save(bPath, { ...aNative, preparedManifest: null, pricing: bPricing, bookId: bId });
    const nextNonce = BigInt(quantity.parse(await chain.send("eth_getTransactionCount", [DEV, "latest"])));
    const staleRaw = await claimedWallet(0).signTransaction({ to: aOperation.transaction.to,
      data: aOperation.transaction.data, value: 0n, chainId: 4663n, nonce: Number(nextNonce + 1n),
      gasLimit: 3000000n, gasPrice: BigInt(quantity.parse(await chain.send("eth_gasPrice", []))), type: 0 });
    await save(join(evidence, "stale-signed-a-intent.json"), {
      raw: staleRaw, transactionHash: keccak256(staleRaw), nonce: String(nextNonce + 1n),
      operation: aOperation, originalExecution: aExecutionPath, signedBeforeOwnerB: true });
    await cli(["set-pricing", "--manifest", bPath, "--checkpoint", join(evidence, "independent-owner-b", "set-pricing"), ...local]);
    const bBlock = z.object({ hash, number: quantity, transactions: z.array(hash) }).passthrough().parse(
      await chain.send("eth_getBlockByNumber", ["latest", false]));
    const storedA = (await chain.call(manifest.proxy, migration, "independentAllocation", [RECIPIENTS[3]])).toString();
    const nonceAfterB = await chain.send("eth_getTransactionCount", [DEV, "latest"]);
    await cli(["resume", "--manifest", aExecutionPath, "--checkpoint", aCheckpoint, ...local]);
    await recoveredReceipt(aFault, aCheckpoint, join(evidence, "configure-a-after-b-resumed.json"));
    if (await chain.send("eth_getTransactionCount", [DEV, "latest"]) !== nonceAfterB
      || (await chain.call(manifest.proxy, migration, "independentAllocation", [RECIPIENTS[3]])).toString() !== storedA) {
      throw new ExecutionError("STATE", "A recovery after B resent or mutated configuration");
    }
    await cli(["configure", "--manifest", aExecutionPath, "--checkpoint", join(evidence, "stale-unsent-a", "checkpoint"), ...local], "reject-state");
    const staleWatch = await subscribeReceipt(chain, keccak256(staleRaw));
    try {
      await chain.send("eth_sendRawTransaction", [staleRaw]);
      const rejected = await staleWatch.mined();
      const trace = z.object({ output: hex }).passthrough().parse(
        await chain.send("debug_traceTransaction", [rejected.transactionHash, { tracer: "callTracer" }]));
      const expected = migration.encodeErrorResult("MigrationWeightedPricingBookMismatch", [bookId, bId]);
      if (BigInt(rejected.status) !== 0n || trace.output !== expected
        || (await chain.call(manifest.proxy, migration, "independentAllocation", [RECIPIENTS[3]])).toString() !== storedA) {
        throw new ExecutionError("STATE", "signed stale A did not roll back with exact book mismatch");
      }
      await save(join(evidence, "stale-a-after-b.json"), { receipt: rejected, trace, before: storedA,
        after: (await chain.call(manifest.proxy, migration, "independentAllocation", [RECIPIENTS[3]])).toString() });
    } finally { staleWatch.close(); }
    input = await reconciledFixtureInput(aExecutionPath, aCheckpoint);
    const bBook = (await chain.call(manifest.proxy, migration, "migrationWeightedPricing"))[0];
    const bTransaction = bBlock.transactions[0];
    if (!bTransaction || bBlock.transactions.length !== 1) throw new ExecutionError("STATE", "B setter was not isolated");
    input = preparationInput.parse({ ...input, domain: { ...input.domain, bookId: bId,
      blockNumber: BigInt(bBlock.number).toString(), blockHash: bBlock.hash },
      books: [...input.books, { bookId: bId, encodedBook: migration.encodeFunctionResult("migrationWeightedPricing", [bBook]),
        observationBlockNumber: BigInt(bBlock.number).toString(), observationBlockHash: bBlock.hash, setTransactionHash: bTransaction }]
        .sort((a, b) => a.bookId.localeCompare(b.bookId)) });
    post = { ...aNative, pricing: bPricing, bookId: bId, preparedManifest: post.preparedManifest };
    await save(join(evidence, "mixed-pricing.json"), { bookA: bookId, bookB: bId,
      recoveredA: aFault.intent.transactionHash, nonceBeforeResume: nonceAfterB,
      currentA: storedA, retainedARecipients: [RECIPIENTS[1], RECIPIENTS[2]],
      signedStaleA: keccak256(staleRaw), issuanceHistory: input.issuedHistory });
    for (const field of ["chainId", "proxy", "package", "bookId"] as const) {
      const changed = { ...post, [field]: field === "chainId" ? "1" : field === "bookId" ? `0x${"9".repeat(64)}` : "0x1111111111111111111111111111111111111111" };
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
      if (!relocated.domain.prepared || !relocated.domain.manifest.preparedManifest || !relocated.domain.manifest.bookId) {
        throw new ExecutionError("STATE", "relocated replacement domain lacks preparation");
      }
      postPath = relocated.path;
      post = { ...relocated.domain.manifest, preparedManifest: relocated.domain.manifest.preparedManifest,
        bookId: relocated.domain.manifest.bookId };
      input = relocated.domain.prepared.input;
    }
    await cli(["configure", "--manifest", postPath, "--checkpoint", join(runtime, "replacement"), ...local]);
    if ((await chain.call(manifest.proxy, migration, "independentIssuance", [RECIPIENTS[0]])).toString() !== issuedBeforeReplacement
      || String((await chain.call(manifest.proxy, supplyAbi, "totalSupply"))[0]) !== replacementSupply) {
      throw new ExecutionError("STATE", "full replacement modified delivered issuance or supply");
    }
    await save(join(evidence, "replacement-observation.json"), { issuedBeforeReplacement, replacementSupply,
      issuedAfterReplacement: (await chain.call(manifest.proxy, migration, "independentIssuance", [RECIPIENTS[0]])).toString() });
    await save(join(evidence, "same-recipient-config-b-issuance-a.json"), {
      recipient: RECIPIENTS[0], bookA: bookId, bookB: bId, issuedBeforeReplacement,
      configurationB: (await chain.call(manifest.proxy, migration, "independentAllocation", [RECIPIENTS[0]])).toString(),
      issuedAfterReplacement: (await chain.call(manifest.proxy, migration, "independentIssuance", [RECIPIENTS[0]])).toString(),
      supplyBefore: replacementSupply, supplyAfter: String((await chain.call(manifest.proxy, supplyAbi, "totalSupply"))[0]),
      history: input.issuedHistory,
    });
    const sameBlock = await sameBlockReplacement({ chain, evidence, runtime, manifestPath: postPath,
      configuredCheckpoint: join(runtime, "replacement"), local, cli });
    input = sameBlock.input;
    const afterRacePrepared = join(evidence, "after-race-prepared");
    const afterRaceInput = join(evidence, "after-race-input.json");
    await save(afterRaceInput, input);
    await cli(["prepare", "--input", afterRaceInput, "--output", afterRacePrepared]);
    const { bundle: _raceBundle, ...raceNative } = post;
    post = { ...raceNative, preparedManifest: join(afterRacePrepared, "manifest.json") };
    postPath = join(evidence, "after-race-execution.json");
    await save(postPath, post);
    await cli(["verify", "--manifest", postPath, "--checkpoint", join(runtime, "after-race-verify")]);
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
      const finalPricing = pricingInputs.parse({ ...bPricing, seigniorage: "70000000000000000" });
      const finalBookId = bookIdFor(finalPricing);
      const { bundle: _finalBundle, ...finalNative } = post;
      const finalPricingPath = join(evidence, "post-purchase-pricing-execution.json");
      await save(finalPricingPath, { ...finalNative, preparedManifest: null, bookId: finalBookId, pricing: finalPricing });
      await cli(["set-pricing", "--manifest", finalPricingPath, "--checkpoint", join(runtime, "post-purchase-set"), ...local]);
      await cli(["activate", "--manifest", postPath, "--checkpoint", join(runtime, "activate"), ...local]);
      const retainedBook = (await chain.call(post.proxy, migration, "migrationWeightedPricing"))[0];
      const loupe = new Interface(["function facetAddress(bytes4) view returns(address)"]);
      const allocation = await interfaceFile("out/IUniswapV4DetfMigration.sol/IUniswapV4DetfMigrationAllocation.json");
      const removed = [];
      for (const fragment of allocation.fragments.filter((f) => f.type === "function")) {
        const fn = allocation.getFunction(fragment.format("sighash"));
        if (!fn) throw new ExecutionError("STATE", "administration ABI function missing");
        const facet = String((await chain.call(post.proxy, loupe, "facetAddress", [fn.selector]))[0]);
        if (facet !== zero) throw new ExecutionError("STATE", "activation retained removable administration selector");
        removed.push({ signature: fn.format("sighash"), selector: fn.selector, facet });
      }
      if (retainedBook.id !== finalBookId) throw new ExecutionError("STATE", "retained getter changed after activation");
      await save(join(evidence, "mixed-pricing-activation.json"), { bookA: bookId, bookB: bId, postPurchaseBook: finalBookId,
        removed, retainedGetter: migration.encodeFunctionResult("migrationWeightedPricing", [retainedBook]),
        acceptedBooks: [...new Set(Object.values(input).flatMap((value) => Array.isArray(value)
          ? value.flatMap((row) => typeof row === "object" && row !== null && "pricing" in row
            ? [z.object({ pricing: z.object({ bookId: hash }) }).parse(row).pricing.bookId] : []) : []))] });
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
    await surrenderNftThree({ chain, manifest: post, input, evidence });
    await cli(["verify", "--manifest", postPath, "--checkpoint", join(runtime, "verify-after")]);
    return { evidence, proxy: manifest.proxy, status: "primary-lifecycle-complete" };
  } catch (error) {
    if (error instanceof Error) await save(join(evidence, "failure.json"), {
      name: error.name, message: error.message.replaceAll(upstream, "<redacted-upstream>")
        .replace(/https?:\/\/[^\s"'<>\\]+/g, "<redacted-url>"),
      stack: error.stack?.replaceAll(upstream, "<redacted-upstream>").replace(/https?:\/\/[^\s"'<>\\]+/g, "<redacted-url>") ?? null,
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
        for (const file of await readdir(source)) {
          await copyFile(join(source, file), join(target, file));
          if (file.endsWith(".intent.json")) {
            const signed = intent.parse(JSON.parse(await readFile(join(source, file), "utf8")));
            const receipt = await chain.canonicalReceipt(signed.transactionHash);
            if (receipt) await save(join(target, `${signed.id}.canonical-chain.json`), {
              receipt, transaction: await chain.send("eth_getTransactionByHash", [signed.transactionHash]),
              header: await chain.send("eth_getBlockByNumber", [receipt.blockNumber, false]),
              trace: await chain.send("debug_traceTransaction", [signed.transactionHash, { tracer: "callTracer" }]),
            });
          }
        }
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
