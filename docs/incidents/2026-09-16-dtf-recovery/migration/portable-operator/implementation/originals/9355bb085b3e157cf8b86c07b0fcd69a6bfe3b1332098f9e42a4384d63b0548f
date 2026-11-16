import { Interface, Result, keccak256 } from "ethers";
import { join } from "node:path";
import { z } from "zod";
import type { PreparationInput } from "./schema.js";
import { address, hex } from "./schema.js";
import type { ExecutionManifest } from "./execution-schema.js";
import { ExecutionError, quantity } from "./execution-schema.js";
import { LEGACY, legacyAbi } from "./rehearsal-chain.js";
import type { RehearsalChain } from "./rehearsal-chain.js";
import { interfaceFile, RECIPIENTS, save } from "./rehearsal-data.js";
import { DEV } from "./execution-rpc.js";

const token = new Interface([
  "function balanceOf(address) view returns(uint256)",
  "function totalSupply() view returns(uint256)",
  "function allowance(address,address) view returns(uint256)",
]);
const bondAbi = new Interface([
  "function ownerOf(uint256) view returns(address)",
  "function balanceOf(address) view returns(uint256)",
  "function positionOf(uint256) view returns((uint256 principal,uint256 claimedPrincipal,uint256 stakingGons,uint256 startTimestamp,uint256 vestingDuration))",
  "function isMigrationPosition(uint256) view returns(bool)",
]);

/** Actual configured WD transferFrom and recovery; original allocation is explicitly synthetic. */
export async function exerciseWeightedLiquid(context: {
  readonly chain: RehearsalChain; readonly manifest: ExecutionManifest; readonly input: PreparationInput;
  readonly evidence: string; readonly phase: "stage1" | "partial" | "final";
}) {
  const { chain, manifest, input, evidence, phase } = context;
  const activated = phase !== "stage1";
  const final = phase === "final";
  const row = input.weightedLiquid[0]?.original;
  if (!row) throw new ExecutionError("STATE", "missing synthetic W-L original inputs");
  const migration = await interfaceFile("out/IUniswapV4DetfMigration.sol/IUniswapV4DetfMigration.json");
  const recovery = await interfaceFile("out/IUniswapV4DetfMigrationRecovery.sol/IUniswapV4DetfMigrationRecovery.json");
  const parent = manifest.proxy;
  const wallet = row.originalWallet;
  const bond = address.parse((await chain.call(parent, migration, "bondNftVault"))[0]);
  const receipt = address.parse((await chain.call(parent, migration, "rebasingClaimToken"))[0]);
  const tuple = (value: unknown) => {
    if (!(value instanceof Result)) throw new ExecutionError("STATE", "invalid W-L tuple");
    return value;
  };
  const state = async () => tuple((await chain.call(parent, migration, "weightedLiquidSurrender", [row.originalId]))[0]);
  const config = tuple((await chain.call(parent, migration, "weightedLiquidEntitlement", [row.originalId]))[0]);
  const c0 = z.bigint().parse(config.getValue("credit"));
  if (config.getValue("configured") !== true
    || address.parse(tuple(config.getValue("original")).getValue("originalWallet")) !== wallet
    || (await chain.call(parent, migration, "migrationActivated"))[0] !== activated) {
    throw new ExecutionError("STATE", "W-L configured wallet or lifecycle differs");
  }
  if (!activated) {
    const identityAbi = new Interface([
      "function facetAddress(bytes4) view returns(address)",
      "function decimals() view returns(uint8)",
    ]);
    const proxyHash = keccak256(hex.parse(await chain.send("eth_getCode", [LEGACY.detf, "latest"])));
    const custodyFacet = address.parse((await chain.call(LEGACY.detf, identityAbi, "facetAddress", ["0x23b872dd"]))[0]);
    const exchangeFacet = address.parse((await chain.call(LEGACY.detf, identityAbi, "facetAddress", ["0xd02d3063"]))[0]);
    const custodyHash = keccak256(hex.parse(await chain.send("eth_getCode", [custodyFacet, "latest"])));
    const exchangeHash = keccak256(hex.parse(await chain.send("eth_getCode", [exchangeFacet, "latest"])));
    if (proxyHash !== "0x2393ee3dc4d7877a9bfb7b59c272f2b9b0d1df92f2dc82ee67df076a99836601"
      || custodyFacet !== "0x1d17aca0e0717d90cea916372070a1be4652223f"
      || custodyHash !== "0xf250dca135b1de9a5fc9ceda732c06af7020fef1d45d7c43dfa92efe02b47e50"
      || exchangeFacet !== "0x4886f86cd0dfff8b8a836f858925ed4de3a2b291"
      || exchangeHash !== "0x1eadaa06571b1cca173491d149bab9b07d5d1b9dc83d268654e49d3179b1a460"
      || (await chain.call(LEGACY.detf, identityAbi, "decimals"))[0] !== 9n) {
      throw new ExecutionError("DOMAIN", "W-L legacy source identity differs from admitted phase11 evidence");
    }
    await save(join(evidence, "weighted-liquid-source-bindings.json"), {
      chainId: "4663", forkBlock: "108944663", source: LEGACY.detf, proxyHash,
      custodyFacet, custodyHash, exchangeFacet, exchangeHash, decimals: "9",
      snapshotId: manifest.snapshotId, configurationId: config.getValue("configurationId"),
      originalInput: row, purpose: "synthetic-local; not approved historical allocation",
    });
  }
  const impersonate = async (who: string, action: () => Promise<void>) => {
    await chain.fundGas(who);
    await chain.send("anvil_impersonateAccount", [who]);
    try { await action(); }
    finally { await chain.send("anvil_stopImpersonatingAccount", [who]); }
  };
  const balance = async (asset: string, who: string) => z.bigint().parse((await chain.call(asset, token, "balanceOf", [who]))[0]);
  const inventory = async (asset: string) => z.bigint().parse((await chain.call(parent, recovery, "migrationRecoveryInventory", [asset]))[0]);
  const supply = async () => z.bigint().parse((await chain.call(parent, token, "totalSupply"))[0]);
  const unchanged = async () => [
    (await state()).toString(), (await balance(LEGACY.detf, wallet)).toString(),
    (await balance(LEGACY.detf, parent)).toString(), (await inventory(LEGACY.detf)).toString(),
    (await supply()).toString(), (await balance(parent, receipt)).toString(),
    (await chain.call(LEGACY.detf, token, "allowance", [wallet, parent])).toString(),
    (await chain.call(parent, migration, "weightedLiquidEntitlement", [row.originalId])).toString(),
    (await chain.call(bond, bondAbi, "balanceOf", [wallet])).toString(),
    (await chain.call(receipt, legacyAbi, "stakingState")).toString(),
  ].join("|");
  const observations: unknown[] = [];
  const reject = async (caller: string, origin: string, error: string, args: readonly unknown[], units = 1n) => {
    const data = migration.encodeFunctionData("surrenderMigrationWeightedLiquid",
      [origin, units, "0", (await chain.timestamp() + 3600n).toString()]);
    const expected = migration.encodeErrorResult(error, [...args]).toLowerCase();
    const before = await unchanged();
    let reverted = false;
    try { await chain.send("eth_call", [{ from: caller, to: parent, data }, "latest"]); }
    catch (failure) {
      const actual = z.object({ data: hex }).passthrough().parse(failure).data;
      if (actual !== expected) {
        throw new ExecutionError("STATE", `W-L rejection has wrong revert data: expected ${expected}, actual ${actual}`);
      }
      reverted = true;
    }
    if (!reverted) throw new ExecutionError("STATE", "W-L negative unexpectedly succeeded");
    await impersonate(caller, async () => {
      const mined = await chain.transact(parent, { from: caller, data }, 0n);
      observations.push({ kind: "rejection", error, caller, originalId: origin,
        transactionHash: mined.transactionHash, status: mined.status, revertData: expected });
    });
    if (await unchanged() !== before) throw new ExecutionError("STATE", "W-L rejection changed custody or credit");
  };
  if (!activated) {
    await impersonate(wallet, async () => {
      await chain.transact(LEGACY.detf, { from: wallet,
        data: legacyAbi.encodeFunctionData("approve", [parent, row.originalUnits]) });
    });
    await reject(wallet, row.originalId, "MigrationSurrenderClosed", []);
    await reject(wallet, `0x${"a".repeat(64)}`, "MigrationSurrenderClosed", []);
    const unspent = await state();
    if (unspent.getValue("consumedUnits") !== 0n || unspent.getValue("deliveredCredit") !== 0n
      || unspent.getValue("remainingUnits") !== BigInt(row.originalUnits)
      || unspent.getValue("remainingCredit") !== c0) {
      throw new ExecutionError("STATE", "Stage1 full replacement did not initialize the final Q/C baseline");
    }
    await save(join(evidence, "weighted-liquid-stage1.json"), {
      syntheticOriginalAllocation: row, originalCredit: c0.toString(), activated, observations,
      remainingUnits: String(unspent.getValue("remainingUnits")), remainingCredit: String(unspent.getValue("remainingCredit")),
    });
    return;
  }
  await reject(wallet, `0x${"a".repeat(64)}`, "InvalidWeightedLiquidEntitlement", [`0x${"a".repeat(64)}`]);
  const other = RECIPIENTS[3];
  const probeState = await state();
  const probeCredit = z.bigint().parse(probeState.getValue("remainingCredit"));
  const probeUnits = (z.bigint().parse(probeState.getValue("remainingUnits")) + probeCredit - 1n) / probeCredit;
  await impersonate(wallet, async () => {
    await chain.transact(LEGACY.detf, { from: wallet, data: legacyAbi.encodeFunctionData("transfer", [other, probeUnits]) });
  });
  await impersonate(other, async () => {
    await chain.transact(LEGACY.detf, { from: other, data: legacyAbi.encodeFunctionData("approve", [parent, probeUnits]) });
  });
  await reject(other, row.originalId, "NotOriginalWeightedLiquidWallet", [other, wallet], probeUnits);
  await impersonate(other, async () => {
    await chain.transact(LEGACY.detf, { from: other, data: legacyAbi.encodeFunctionData("transfer", [wallet, probeUnits]) });
  });
  if (!final) {
    await impersonate(wallet, async () => {
      await chain.transact(LEGACY.detf, { from: wallet, data: legacyAbi.encodeFunctionData("transfer", [parent, 7]) });
    });
    const dtfBefore = await balance(LEGACY.dtf, parent);
    await chain.transact(LEGACY.dtf, { from: DEV,
      data: legacyAbi.encodeFunctionData("transfer", [parent, 10n ** 18n]) });
    if (await balance(LEGACY.dtf, parent) !== dtfBefore + 10n ** 18n) {
      throw new ExecutionError("STATE", "unbooked DTF fixture was not actually received");
    }
  }
  await chain.transact(parent, { from: DEV, data: migration.encodeFunctionData("synchronizeRewards") });
  const before = await state();
  const remainingUnits = z.bigint().parse(before.getValue("remainingUnits"));
  const remainingCredit = z.bigint().parse(before.getValue("remainingCredit"));
  const q = final ? remainingUnits : BigInt(row.originalUnits) / 3n;
  const expected = q === remainingUnits ? remainingCredit : remainingCredit * q / remainingUnits;
  if (q === 0n || expected === 0n) throw new ExecutionError("STATE", "W-L fixture has no eligible credit");
  const w0 = await balance(LEGACY.detf, wallet);
  const p0 = await balance(LEGACY.detf, parent);
  const i0 = await inventory(LEGACY.detf);
  const s0 = await supply();
  const b0 = await balance(parent, receipt);
  let bondId = 0n;
  await impersonate(wallet, async () => {
    await chain.transact(LEGACY.detf, { from: wallet, data: legacyAbi.encodeFunctionData("approve", [parent, q]) });
    const mined = await chain.transact(parent, { from: wallet,
      data: migration.encodeFunctionData("surrenderMigrationWeightedLiquid",
        [row.originalId, q, expected, (await chain.timestamp() + 3600n).toString()]) });
    const event = mined.logs.filter((log) => log.address === parent).map((log) =>
      migration.parseLog({ topics: [...log.topics], data: log.data }))
      .find((log) => log?.name === "MigrationWeightedLiquidSurrendered");
    if (!event) throw new ExecutionError("STATE", "missing W-L surrender event");
    bondId = z.bigint().parse(event.args[5]);
    const position = tuple((await chain.call(bond, bondAbi, "positionOf", [bondId]))[0]);
    const owner = address.parse((await chain.call(bond, bondAbi, "ownerOf", [bondId]))[0]);
    const divisor = z.bigint().parse(tuple((await chain.call(receipt, legacyAbi, "stakingState"))[0]).getValue("gonsPerUnit"));
    const block = z.object({ timestamp: quantity }).passthrough().parse(
      await chain.send("eth_getBlockByNumber", [mined.blockNumber, false]));
    const after = await state();
    if (event.args[0] !== row.originalId || event.args[1] !== config.getValue("configurationId")
      || address.parse(event.args[2]) !== wallet || event.args[3] !== q || event.args[4] !== expected
      || position.getValue("principal") !== expected || position.getValue("claimedPrincipal") !== 0n
      || position.getValue("stakingGons") !== expected * divisor || owner !== wallet
      || position.getValue("startTimestamp") !== BigInt(block.timestamp)
      || position.getValue("vestingDuration") !== 7776000n
      || (await chain.call(bond, bondAbi, "isMigrationPosition", [bondId]))[0] !== true
      || w0 - await balance(LEGACY.detf, wallet) !== q || await balance(LEGACY.detf, parent) - p0 !== q
      || await inventory(LEGACY.detf) - i0 !== q || await supply() - s0 !== expected
      || await balance(parent, receipt) - b0 !== expected
      || after.getValue("remainingUnits") !== remainingUnits - q
      || after.getValue("remainingCredit") !== remainingCredit - expected
      || after.getValue("consumedUnits") !== z.bigint().parse(before.getValue("consumedUnits")) + q
      || after.getValue("deliveredCredit") !== z.bigint().parse(before.getValue("deliveredCredit")) + expected) {
      throw new ExecutionError("STATE", "W-L exact transfer, credit, inventory or funded fresh bond differs");
    }
    observations.push({ kind: "surrender", transactionHash: mined.transactionHash, originalId: row.originalId,
      configurationId: config.getValue("configurationId"), wallet, quantity: q.toString(), credit: expected.toString(),
      bondTokenId: bondId.toString(), startTimestamp: String(position.getValue("startTimestamp")),
      duration: String(position.getValue("vestingDuration")), gons: String(position.getValue("stakingGons")),
      consumedUnits: String(after.getValue("consumedUnits")), deliveredCredit: String(after.getValue("deliveredCredit")),
      remainingUnits: String(after.getValue("remainingUnits")), remainingCredit: String(after.getValue("remainingCredit")) });
  });
  const allocation = await interfaceFile("out/IUniswapV4DetfMigration.sol/IUniswapV4DetfMigrationAllocation.json");
  const removed = new Interface(["error NoTargetFor(bytes4)"]);
  for (const replacement of [row, { ...row, originalUnits: (BigInt(row.originalUnits) + 7n).toString(),
    originalEth: (BigInt(row.originalEth) + 1n).toString() }]) {
    const data = allocation.encodeFunctionData("configureWeightedLiquidEntitlements", [[replacement]]);
    const expected = removed.encodeErrorResult("NoTargetFor", [data.slice(0, 10)]).toLowerCase();
    const frozen = await unchanged();
    let rejected = false;
    try { await chain.send("eth_call", [{ from: DEV, to: parent, data }, "latest"]); }
    catch (failure) {
      if (z.object({ data: hex }).passthrough().parse(failure).data !== expected) {
        throw new ExecutionError("STATE", "postactivation W-L loader returned the wrong error");
      }
      rejected = true;
    }
    if (!rejected) throw new ExecutionError("STATE", "postactivation W-L loader remained callable");
    const mined = await chain.transact(parent, { from: DEV, data }, 0n);
    if (await unchanged() !== frozen) throw new ExecutionError("STATE", "removed loader changed the remaining Q/C");
    observations.push({ kind: "removed-loader", transactionHash: mined.transactionHash, status: mined.status,
      revertData: expected, remainingUnits: String((await state()).getValue("remainingUnits")),
      remainingCredit: String((await state()).getValue("remainingCredit")) });
  }
  const protectedState = [(await state()).toString(), String(await supply()), String(await balance(parent, receipt)),
    (await chain.call(bond, bondAbi, "positionOf", [bondId])).toString()].join("|");
  const dtf0 = await balance(LEGACY.dtf, parent);
  const recovered0 = await inventory(LEGACY.dtf);
  const donationBudget = z.bigint().parse((await chain.call(parent, migration, "migrationDonationInventory", [LEGACY.dtf]))[0]);
  const converted = await chain.transact(parent, { from: DEV, data: recovery.encodeFunctionData("recoverMigrationNfts",
    [[{ stage: 4, tokenId: 0, amount: q, minimum: 1 }], (await chain.timestamp() + 3600n).toString()]) });
  const output = await inventory(LEGACY.dtf) - recovered0;
  if (output <= 0n || await balance(LEGACY.dtf, parent) - dtf0 !== output
    || await balance(LEGACY.detf, parent) !== p0 || await inventory(LEGACY.detf) !== i0
    || (await chain.call(LEGACY.detf, token, "allowance", [parent, LEGACY.detf]))[0] !== 0n) {
    throw new ExecutionError("STATE", "W-L selected conversion delta or self-approval differs");
  }
  const amount = output / 2n;
  const donated = await chain.transact(parent, { from: DEV, data: recovery.encodeFunctionData("recoverMigrationNfts",
    [[{ stage: 7, tokenId: 0, amount, minimum: 1 }], (await chain.timestamp() + 3600n).toString()]) });
  if (await inventory(LEGACY.dtf) !== recovered0 + output - amount
    // Existing reserve residuals are deliberately swept; recovery, donation budgets and
    // the independently transferred unbooked DTF must remain protected.
    || await balance(LEGACY.dtf, parent) < recovered0 + output - amount + donationBudget + 10n ** 18n
    || (await chain.call(parent, migration, "migrationDonationInventory", [LEGACY.dtf]))[0] !== donationBudget
    || [(await state()).toString(), String(await supply()), String(await balance(parent, receipt)),
      (await chain.call(bond, bondAbi, "positionOf", [bondId])).toString()].join("|") !== protectedState) {
    throw new ExecutionError("STATE", "W-L recovery altered compensation or spent protected inventory");
  }
  observations.push({ kind: "recovery", convertTransaction: converted.transactionHash, donationTransaction: donated.transactionHash,
    quantity: q.toString(), dtfReceived: output.toString(), dtfDonated: amount.toString(),
    weightedUnbookedFloor: p0.toString(), dtfUnbookedFloor: (10n ** 18n).toString(),
    donationBudget: donationBudget.toString(), selfAllowance: "0", compensationUnchanged: true });
  if (final) {
    if ((await state()).getValue("deliveredCredit") !== c0) throw new ExecutionError("STATE", "W-L final credit does not conserve C0");
    await reject(wallet, row.originalId, "InvalidWeightedLiquidQuantity", [1, 0]);
  }
  await save(join(evidence, `weighted-liquid-${phase}.json`), {
    syntheticOriginalAllocation: row, originalCredit: c0.toString(), activated, observations,
  });
}
