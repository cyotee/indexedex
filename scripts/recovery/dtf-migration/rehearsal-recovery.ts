import { join } from "node:path";
import type { PreparationInput, RecoveryStep } from "./schema.js";
import type { ExecutionManifest } from "./execution-schema.js";
import { ExecutionError } from "./execution-schema.js";
import { LEGACY, legacyAbi } from "./rehearsal-chain.js";
import type { RehearsalChain } from "./rehearsal-chain.js";
import { interfaceFile, save } from "./rehearsal-data.js";
import { DEV } from "./execution-rpc.js";
import { exerciseAdmission } from "./rehearsal-admission.js";

type Context = {
  readonly chain: RehearsalChain; readonly manifest: ExecutionManifest; readonly input: PreparationInput;
  readonly evidence: string; readonly runtime: string; readonly local: readonly string[];
  readonly cli: (args: readonly string[], expected?: "success" | "fault" | "reject") => Promise<unknown>;
};
export async function exerciseRecovery(context: Context) {
  const { chain, manifest, input, evidence, runtime, cli, local } = context;
  const recovery = await interfaceFile("out/IUniswapV4DetfMigrationRecovery.sol/IUniswapV4DetfMigrationRecovery.json");
  await exerciseAdmission({ chain, manifest, input, evidence, activated: true });
  let sequence = 0;
  const harvest = async (step: RecoveryStep) => {
    const name = `harvest-${String(++sequence).padStart(2, "0")}-${step.stage}`;
    const path = join(evidence, `${name}-input.json`);
    const directory = join(evidence, name);
    await save(path, { ...input, harvest: { steps: [step], deadline: (await chain.timestamp() + 3600n).toString() } });
    await cli(["prepare", "--input", path, "--output", directory]);
    const executionPath = join(evidence, `${name}-execution.json`);
    await save(executionPath, { ...manifest, preparedManifest: join(directory, "manifest.json") });
    await cli(["harvest", "--manifest", executionPath, "--checkpoint", join(runtime, name), ...local]);
  };
  const nftStep = (stage: RecoveryStep["stage"], tokenId: string): RecoveryStep => ({ stage, tokenId, amount: "0", minimum: "0" });
  const conversion = (stage: RecoveryStep["stage"], amount: bigint): RecoveryStep => ({
    stage, tokenId: "0", amount: amount.toString(), minimum: stage === "WeightedUnstake" ? "0" : "1",
  });
  await harvest(nftStep("WeightedClaim", "4"));
  await harvest(nftStep("WeightedPrincipal", "26"));
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
  await chain.send("evm_setNextBlockTimestamp", [Number(await chain.timestamp() + 365n * 86400n)]);
  await chain.send("evm_mine", []);
  await harvest({ ...nftStep("EarlierSale", "3"), minimum: "1" });
  await save(join(evidence, "recovery-observation.json"), {
    original: original.toString(), attributedGonsAfterOriginalSpent: gons.toString(), synchronizedDivisor: divisor.toString(),
    accrued: accrued.toString(), actualWeightedOutput: weighted.toString(), convertedDtf: recovered.toString(),
    donated: donation.toString(), fixedDestination: manifest.proxy, owner: DEV,
    earlierLiquidation: "blocked: SB-E1/E2/E3/E4; sale-and-hold is not liquidation",
  });
}
