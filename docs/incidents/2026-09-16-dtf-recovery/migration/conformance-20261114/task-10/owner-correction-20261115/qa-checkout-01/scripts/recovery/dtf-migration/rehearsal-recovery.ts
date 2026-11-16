import { join } from "node:path";
import { cp, readFile, readdir } from "node:fs/promises";
import { Interface, Result } from "ethers";
import { z } from "zod";
import type { PreparationInput, RecoveryStep } from "./schema.js";
import type { ExecutionManifest } from "./execution-schema.js";
import { completion, ExecutionError } from "./execution-schema.js";
import { LEGACY, legacyAbi } from "./rehearsal-chain.js";
import type { RehearsalChain } from "./rehearsal-chain.js";
import { interfaceFile, save } from "./rehearsal-data.js";
import { DEV } from "./execution-rpc.js";
import { exerciseAdmission } from "./rehearsal-admission.js";
import { canonical } from "./provenance.js";

type Context = {
  readonly chain: RehearsalChain; readonly manifest: ExecutionManifest; readonly input: PreparationInput;
  readonly evidence: string; readonly runtime: string; readonly local: readonly string[];
  readonly cli: (args: readonly string[], expected?: "success" | "fault" | "reject") => Promise<unknown>;
};

export async function rejectTamperedCompletions(context: {
  readonly checkpoint: string; readonly manifestPath: string; readonly evidence: string;
  readonly cli: (args: readonly string[], expected: "reject-state") => Promise<unknown>;
}) {
  const { checkpoint, manifestPath, evidence, cli } = context;
  const receiptName = (await readdir(checkpoint)).find(name => name.endsWith(".receipt.json"));
  if (!receiptName) throw new ExecutionError("STATE", "tamper fixture lacks a real recovered completion");
  const original = completion.parse(JSON.parse(await readFile(join(checkpoint, receiptName), "utf8")));
  const observations = [];
  for (const name of ["transaction-index", "logs", "credit", "event"]) {
    const copy = join(evidence, `same-block-reject-${name}`);
    await cp(checkpoint, copy, { recursive: true, force: false, errorOnExist: true });
    let bad = structuredClone(original);
    if (name === "transaction-index") bad = { ...bad, receipt: { ...bad.receipt, transactionIndex: "0x1" } };
    if (name === "logs") {
      const log = bad.receipt.logs[0];
      if (!log) throw new ExecutionError("STATE", "tamper fixture lacks a real log");
      const data = log.data === "0x" ? `0x${"0".repeat(64)}` : log.data.slice(0, -2) + (log.data.endsWith("00") ? "01" : "00");
      bad = { ...bad, receipt: { ...bad.receipt, logs: bad.receipt.logs.map((entry, index) => index === 0 ? { ...entry, data } : entry) } };
    }
    if (name === "credit" || name === "event") {
      const event = bad.events.find(e => e.name === "IndependentAllocationConfigured");
      if (!event || !event.values[3]) throw new ExecutionError("STATE", "tamper fixture lacks exact configuration credit");
      if (name === "credit") event.values[3] = String(BigInt(event.values[3]) + 1n);
      else event.name = "IndependentAllocationIssued";
    }
    await save(join(copy, receiptName), bad);
    await cli(["resume", "--manifest", manifestPath, "--checkpoint", copy], "reject-state");
    observations.push({ name, checkpoint: copy, originalReceipt: join(checkpoint, receiptName), expected: "STATE" });
  }
  await save(join(evidence, "same-block-tamper-rejections.json"), observations);
}

export async function rejectInvalidHistory(input: PreparationInput, evidence: string,
  cli: (args: readonly string[], expected: "reject-bundle") => Promise<unknown>) {
  const history = input.issuedHistory[0];
  const row = input.independent[0];
  if (!history || !row) throw new ExecutionError("STATE", "history negatives require actual issuance");
  const cases = {
    "wrong-issuance-history": { ...input, issuedHistory: input.issuedHistory.map((entry, index) => index === 0
      ? { ...entry, recipient: "0x1111111111111111111111111111111111111111" } : entry) },
    "unsupported-book-c": { ...input, independent: input.independent.map((entry, index) => index === 0
      ? { ...entry, pricing: { ...entry.pricing, bookId: `0x${"9".repeat(64)}` } } : entry) },
  };
  for (const [name, changed] of Object.entries(cases)) {
    const path = join(evidence, `${name}-input.json`);
    await save(path, changed);
    await cli(["prepare", "--input", path, "--output", join(evidence, `${name}-rejected`)], "reject-bundle");
  }
}
export async function exerciseRecovery(context: Context) {
  const { chain, manifest, input, evidence, runtime, cli, local } = context;
  const recovery = await interfaceFile("out/IUniswapV4DetfMigrationRecovery.sol/IUniswapV4DetfMigrationRecovery.json");
  await exerciseAdmission({ chain, manifest, input, evidence, activated: true });
  let sequence = 0;
  const harvest = async (step: RecoveryStep) => {
    const name = `harvest-${String(++sequence).padStart(2, "0")}-${step.stage}`;
    const path = join(evidence, `${name}-input.json`);
    const directory = join(evidence, name);
    // A newly selected harvest is a fresh domain, never a mutation of the saved
    // configuration bundle or its signed journal. Retain its relocated sources.
    const { bundle: _inputBundle, ...nativeInput } = input;
    const { bundle: _executionBundle, ...nativeManifest } = manifest;
    // Recovery uses already consumed on-chain custody, not a new entitlement load.
    // Keep this fresh operation domain free of configuration/issuance selections;
    // the full original configuration is independently verified after the rehearsal.
    await save(path, { ...nativeInput, exposures: [], independent: [], nfts: [], weightedLiquid: [], weightedSy: [],
      dtfCustodySe: [], claimVault: [], weightedReceipt: [], earlierReceipt: [], earlierLiquid: [], heldSeLp: [],
      issueRecipients: [], harvest: { steps: [step], deadline: (await chain.timestamp() + 3600n).toString() } });
    await cli(["prepare", "--input", path, "--output", directory]);
    const executionPath = join(evidence, `${name}-execution.json`);
    await save(executionPath, { ...nativeManifest, preparedManifest: join(directory, "manifest.json") });
    await cli(["harvest", "--manifest", executionPath, "--checkpoint", join(runtime, name), ...local]);
  };
  const nftStep = (stage: RecoveryStep["stage"], tokenId: string): RecoveryStep => ({ stage, tokenId, amount: "0", minimum: "0" });
  const conversion = (stage: RecoveryStep["stage"], amount: bigint): RecoveryStep => ({
    stage, tokenId: "0", amount: amount.toString(), minimum: stage === "WeightedUnstake" ? "0" : "1",
  });
  const source = new Interface([...legacyAbi.fragments,
    "function positionOf(uint256) view returns((uint256 principal,uint256 claimedPrincipal,uint256 stakingGons,uint256 startTimestamp,uint256 vestingDuration))",
    "function getPosition(uint256) view returns((uint256 originalShares,uint256 effectiveShares,uint256 bonusMultiplier,uint256 unlockTime,uint256 rewardDebt))",
    "function owner() view returns(address)", "function isDisabledDetailed(address) view returns(bool,bool,bool)",
    "function packageOfVault(address) view returns(address)", "function setVaultAddressDisabled(address,bool) returns(bool)",
    "function setPackageDisabled(address,bool) returns(bool)",
  ]);
  const retained = async () => {
    const weighted = [];
    for (const id of ["4", "26"]) {
      const p = (await chain.call(LEGACY.weighted, source, "positionOf", [id]))[0];
      if (!(p instanceof Result)) throw new ExecutionError("STATE", "missing weighted position");
      weighted.push({ id, principal: String(p[0]), claimedPrincipal: String(p[1]),
        owner: String((await chain.call(LEGACY.weighted, source, "ownerOf", [id]))[0]) });
    }
    const p = (await chain.call(LEGACY.earlier, source, "getPosition", [3]))[0];
    if (!(p instanceof Result)) throw new ExecutionError("STATE", "missing earlier position");
    return { weighted, earlier: { id: "3", originalShares: String(p[0]),
      owner: String((await chain.call(LEGACY.earlier, source, "ownerOf", [3]))[0]) } };
  };
  const retainedBefore = await retained();
  await harvest(nftStep("WeightedRewards", "4"));
  await harvest(nftStep("WeightedRewards", "26"));
  const original = BigInt((await chain.call(manifest.proxy, recovery, "migrationRecoveryInventory", [LEGACY.receipt]))[0]);
  if (original === 0n) throw new ExecutionError("STATE", "weighted claims created no attributed inventory");
  await chain.send("evm_setNextBlockTimestamp", [Number(await chain.timestamp() + 8n * 3600n)]);
  await chain.send("evm_mine", []);
  await harvest(conversion("WeightedUnstake", original));
  const gons = BigInt((await chain.call(manifest.proxy, recovery, "migrationRecoveryGons"))[0]);
  const divisor = BigInt((await chain.call(LEGACY.receipt, legacyAbi, "stakingState"))[0].gonsPerUnit);
  const accrued = gons / divisor;
  if (accrued === 0n) throw new ExecutionError("STATE", "accrued attributed recovery witness did not grow");
  // Use attributed gons only. The execution path simulates the actual synchronized
  // source operation before signing; never substitute proxy balance or stored zero.
  await harvest(conversion("WeightedUnstake", accrued));
  const weighted = BigInt((await chain.call(manifest.proxy, recovery, "migrationRecoveryInventory", [LEGACY.detf]))[0]);
  if (weighted !== original + accrued) throw new ExecutionError("STATE", "actual gon recovery output differs");
  await harvest(conversion("WeightedConvert", weighted));
  const recovered = BigInt((await chain.call(manifest.proxy, recovery, "migrationRecoveryInventory", [LEGACY.dtf]))[0]);
  const donation = recovered > 10n ** 18n ? 10n ** 18n : recovered;
  await harvest(conversion("Donate", donation));
  await harvest(nftStep("EarlierClaim", "3"));
  const earlierFirst = (await chain.call(manifest.proxy, recovery, "migrationNftRecovery", [LEGACY.earlier, 3]))[0];
  if (!(earlierFirst instanceof Result)) throw new ExecutionError("STATE", "missing earlier recovery");
  await chain.send("evm_setNextBlockTimestamp", [Number(await chain.timestamp() + 365n * 86400n)]);
  await chain.send("evm_mine", []);
  await harvest(nftStep("WeightedRewards", "4"));
  await harvest(nftStep("WeightedRewards", "26"));
  const nextReceipt = z.bigint().parse((await chain.call(manifest.proxy, recovery, "migrationRecoveryInventory", [LEGACY.receipt]))[0]);
  if (nextReceipt === 0n) throw new ExecutionError("STATE", "later weighted rewards did not accrue");
  await harvest(conversion("WeightedUnstake", nextReceipt));
  await harvest(conversion("WeightedConvert", z.bigint().parse(
    (await chain.call(manifest.proxy, recovery, "migrationRecoveryInventory", [LEGACY.detf]))[0])));

  // Explicit local source prerequisites, never public governance or fabricated balances.
  const registry = "0x09682b00d873d913ada0bb69b4d4c9631810d0bc";
  const earlierSe = "0xb7d4bb379d361ad442cddee53ea71a33957826a7";
  const earlierDetf = "0xaf0e1967c8f755c747615c5427108bc549ca1122";
  const administrator = z.string().parse((await chain.call(registry, source, "owner"))[0]).toLowerCase();
  const disabled = await chain.call(registry, source, "isDisabledDetailed", [earlierSe]);
  const prerequisites = [];
  await chain.fundGas(administrator);
  await chain.send("anvil_impersonateAccount", [administrator]);
  try {
    if (disabled[1]) prerequisites.push(await chain.transact(registry, { from: administrator,
      data: source.encodeFunctionData("setVaultAddressDisabled", [earlierSe, false]) }));
    if (disabled[2]) prerequisites.push(await chain.transact(registry, { from: administrator,
      data: source.encodeFunctionData("setPackageDisabled",
        [(await chain.call(registry, source, "packageOfVault", [earlierSe]))[0], false]) }));
  } finally { await chain.send("anvil_stopImpersonatingAccount", [administrator]); }
  const donor = "0x495d9d8bc7b1d00cfb3dfe8aa3666c64771910ed";
  const donorBefore = z.bigint().parse((await chain.call(earlierDetf, source, "balanceOf", [donor]))[0]);
  const income = donorBefore / 4n;
  if (income === 0n) throw new ExecutionError("STATE", "real earlier reward donor unavailable");
  await chain.fundGas(donor);
  await chain.send("anvil_impersonateAccount", [donor]);
  try { prerequisites.push(await chain.transact(earlierDetf, { from: donor,
    data: source.encodeFunctionData("transfer", [LEGACY.earlier, income]) })); }
  finally { await chain.send("anvil_stopImpersonatingAccount", [donor]); }
  if (z.bigint().parse((await chain.call(earlierDetf, source, "balanceOf", [donor]))[0]) !== donorBefore - income) {
    throw new ExecutionError("STATE", "earlier reward income was not actually funded");
  }
  await harvest(nftStep("EarlierClaim", "3"));
  const earlierNext = (await chain.call(manifest.proxy, recovery, "migrationNftRecovery", [LEGACY.earlier, 3]))[0];
  if (!(earlierNext instanceof Result) || earlierNext[1] <= earlierFirst[1] || earlierNext[3] !== false) {
    throw new ExecutionError("STATE", "later earlier rewards did not accrue without sale");
  }
  await harvest(conversion("EarlierConvert", z.bigint().parse(
    (await chain.call(manifest.proxy, recovery, "migrationRecoveryInventory", [earlierDetf]))[0])));
  const combined = z.bigint().parse((await chain.call(manifest.proxy, recovery, "migrationRecoveryInventory", [LEGACY.dtf]))[0]);
  await harvest(conversion("Donate", combined > 10n ** 18n ? 10n ** 18n : combined));
  const retainedAfter = await retained();
  if (canonical(retainedAfter) !== canonical(retainedBefore)) {
    throw new ExecutionError("STATE", "routine reward recovery changed old principal or NFT custody");
  }
  await save(join(evidence, "reward-harvest-retention.json"), { before: retainedBefore, after: retainedAfter,
    nextWeightedReceipt: String(nextReceipt), earlierRewardsBefore: String(earlierFirst[1]),
    earlierRewardsAfter: String(earlierNext[1]), externalEarlierIncome: String(income), prerequisites,
    qualification: "Local source enablement and real external reward income; no claim that time alone guarantees earlier yield." });
  await save(join(evidence, "recovery-observation.json"), {
    original: original.toString(), attributedGonsAfterOriginalSpent: gons.toString(), synchronizedDivisor: divisor.toString(),
    accrued: accrued.toString(), actualWeightedOutput: weighted.toString(), convertedDtf: recovered.toString(),
    donated: donation.toString(), fixedDestination: manifest.proxy, owner: DEV,
    earlierLiquidation: "reward-only claim and fixed public swap; conditional local source enablement",
    routine: "reward-only; old principal and NFT custody preserved across both cycles",
  });
}
