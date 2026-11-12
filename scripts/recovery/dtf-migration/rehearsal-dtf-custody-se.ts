import { Interface, Result } from "ethers";
import { join } from "node:path";
import { z } from "zod";
import type { PreparationInput } from "./schema.js";
import { address, hex } from "./schema.js";
import type { ExecutionManifest } from "./execution-schema.js";
import { ExecutionError, quantity } from "./execution-schema.js";
import { LEGACY, legacyAbi } from "./rehearsal-chain.js";
import type { RehearsalChain } from "./rehearsal-chain.js";
import { interfaceFile, RECIPIENTS, save } from "./rehearsal-data.js";
import { dtfCustodySeSource } from "./payloads.js";
import { custodySeAbi } from "./rehearsal-dtf-custody-source.js";
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

/** Actual configured W-SD transferFrom and recovery; original allocation is explicitly synthetic. */
export async function exerciseDtfCustodySe(context: {
  readonly chain: RehearsalChain; readonly manifest: ExecutionManifest; readonly input: PreparationInput;
  readonly evidence: string; readonly phase: "stage1" | "partial" | "final";
}) {
  const { chain, manifest, input, evidence, phase } = context;
  const activated = phase !== "stage1";
  const final = phase === "final";
  const row = input.dtfCustodySe[0]?.original;
  if (!row) throw new ExecutionError("STATE", "missing synthetic W-SD original inputs");
  const migration = await interfaceFile("out/IUniswapV4DetfMigration.sol/IUniswapV4DetfMigration.json");
  const recovery = await interfaceFile("out/IUniswapV4DetfMigrationRecovery.sol/IUniswapV4DetfMigrationRecovery.json");
  const parent = manifest.proxy;
  const wallet = row.originalWallet;
  const bond = address.parse((await chain.call(parent, migration, "bondNftVault"))[0]);
  const receipt = address.parse((await chain.call(parent, migration, "rebasingClaimToken"))[0]);
  const tuple = (value: unknown) => {
    if (!(value instanceof Result)) throw new ExecutionError("STATE", "invalid W-SD tuple");
    return value;
  };
  const state = async () => tuple((await chain.call(parent, migration, "dtfCustodySeSurrender", [row.originalId]))[0]);
  const config = tuple((await chain.call(parent, migration, "dtfCustodySeEntitlement", [row.originalId]))[0]);
  const c0 = z.bigint().parse(config.getValue("credit"));
  if (config.getValue("configured") !== true
    || address.parse(tuple(config.getValue("original")).getValue("originalWallet")) !== wallet
    || (await chain.call(parent, migration, "migrationActivated"))[0] !== activated) {
    throw new ExecutionError("STATE", "W-SD configured wallet or lifecycle differs");
  }
  const impersonate = async (who: string, action: () => Promise<void>) => {
    await chain.send("anvil_setBalance", [who, "0x3635c9adc5dea00000"]);
    await chain.send("anvil_impersonateAccount", [who]);
    try { await action(); }
    finally { await chain.send("anvil_stopImpersonatingAccount", [who]); }
  };
  const balance = async (asset: string, who: string) => z.bigint().parse((await chain.call(asset, token, "balanceOf", [who]))[0]);
  const inventory = async (asset: string) => z.bigint().parse((await chain.call(parent, recovery, "migrationRecoveryInventory", [asset]))[0]);
  const supply = async () => z.bigint().parse((await chain.call(parent, token, "totalSupply"))[0]);
  const unchanged = async () => [
    (await state()).toString(), (await balance(dtfCustodySeSource, wallet)).toString(),
    (await balance(dtfCustodySeSource, parent)).toString(), (await inventory(dtfCustodySeSource)).toString(),
    (await supply()).toString(), (await balance(parent, receipt)).toString(),
    (await chain.call(dtfCustodySeSource, token, "allowance", [wallet, parent])).toString(),
    (await chain.call(parent, migration, "dtfCustodySeEntitlement", [row.originalId])).toString(),
    (await chain.call(bond, bondAbi, "balanceOf", [wallet])).toString(),
    (await chain.call(receipt, legacyAbi, "stakingState")).toString(),
  ].join("|");
  const observations: unknown[] = [];
  const reject = async (caller: string, origin: string, error: string, args: readonly unknown[], units = 1n) => {
    const data = migration.encodeFunctionData("surrenderMigrationDtfCustodySe",
      [origin, units, "0", (await chain.timestamp() + 3600n).toString()]);
    const expected = migration.encodeErrorResult(error, [...args]).toLowerCase();
    const before = await unchanged();
    let reverted = false;
    try { await chain.send("eth_call", [{ from: caller, to: parent, data }, "latest"]); }
    catch (failure) {
      const actual = z.object({ data: hex }).passthrough().parse(failure).data;
      if (actual !== expected) {
        throw new ExecutionError("STATE", `W-SD rejection has wrong revert data: expected ${expected}, actual ${actual}`);
      }
      reverted = true;
    }
    if (!reverted) throw new ExecutionError("STATE", "W-SD negative unexpectedly succeeded");
    await impersonate(caller, async () => {
      const mined = await chain.transact(parent, { from: caller, data }, 0n);
      observations.push({ kind: "rejection", error, caller, originalId: origin,
        transactionHash: mined.transactionHash, status: mined.status, revertData: expected });
    });
    if (await unchanged() !== before) throw new ExecutionError("STATE", "W-SD rejection changed custody or credit");
  };
  if (!activated) {
    await impersonate(wallet, async () => {
      await chain.transact(dtfCustodySeSource, { from: wallet,
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
    await save(join(evidence, "dtf-custody-se-stage1.json"), {
      syntheticOriginalAllocation: row, originalCredit: c0.toString(), activated, observations,
      remainingUnits: String(unspent.getValue("remainingUnits")), remainingCredit: String(unspent.getValue("remainingCredit")),
    });
    return;
  }
  await reject(wallet, `0x${"a".repeat(64)}`, "InvalidDtfCustodySeEntitlement", [`0x${"a".repeat(64)}`]);
  const other = RECIPIENTS[3];
  const probeState = await state();
  const probeCredit = z.bigint().parse(probeState.getValue("remainingCredit"));
  const probeUnits = (z.bigint().parse(probeState.getValue("remainingUnits")) + probeCredit - 1n) / probeCredit;
  await impersonate(wallet, async () => {
    await chain.transact(dtfCustodySeSource, { from: wallet, data: legacyAbi.encodeFunctionData("transfer", [other, probeUnits]) });
  });
  await impersonate(other, async () => {
    await chain.transact(dtfCustodySeSource, { from: other, data: legacyAbi.encodeFunctionData("approve", [parent, probeUnits]) });
  });
  await reject(other, row.originalId, "NotOriginalDtfCustodySeWallet", [other, wallet], probeUnits);
  await impersonate(other, async () => {
    await chain.transact(dtfCustodySeSource, { from: other, data: legacyAbi.encodeFunctionData("transfer", [wallet, probeUnits]) });
  });
  if (!final) {
    await impersonate(wallet, async () => {
      await chain.transact(dtfCustodySeSource, { from: wallet, data: legacyAbi.encodeFunctionData("transfer", [parent, 7]) });
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
  if (q === 0n || expected === 0n) throw new ExecutionError("STATE", "W-SD fixture has no eligible credit");
  const w0 = await balance(dtfCustodySeSource, wallet);
  const p0 = await balance(dtfCustodySeSource, parent);
  const i0 = await inventory(dtfCustodySeSource);
  const s0 = await supply();
  const b0 = await balance(parent, receipt);
  let bondId = 0n;
  await impersonate(wallet, async () => {
    await chain.transact(dtfCustodySeSource, { from: wallet, data: legacyAbi.encodeFunctionData("approve", [parent, q]) });
    const mined = await chain.transact(parent, { from: wallet,
      data: migration.encodeFunctionData("surrenderMigrationDtfCustodySe",
        [row.originalId, q, expected, (await chain.timestamp() + 3600n).toString()]) });
    const event = mined.logs.filter((log) => log.address === parent).map((log) =>
      migration.parseLog({ topics: [...log.topics], data: log.data }))
      .find((log) => log?.name === "MigrationDtfCustodySeSurrendered");
    if (!event) throw new ExecutionError("STATE", "missing W-SD surrender event");
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
      || w0 - await balance(dtfCustodySeSource, wallet) !== q || await balance(dtfCustodySeSource, parent) - p0 !== q
      || await inventory(dtfCustodySeSource) - i0 !== q || await supply() - s0 !== expected
      || await balance(parent, receipt) - b0 !== expected
      || after.getValue("remainingUnits") !== remainingUnits - q
      || after.getValue("remainingCredit") !== remainingCredit - expected
      || after.getValue("consumedUnits") !== z.bigint().parse(before.getValue("consumedUnits")) + q
      || after.getValue("deliveredCredit") !== z.bigint().parse(before.getValue("deliveredCredit")) + expected) {
      throw new ExecutionError("STATE", "W-SD exact transfer, credit, inventory or funded fresh bond differs");
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
    const data = allocation.encodeFunctionData("configureDtfCustodySeEntitlements", [[replacement]]);
    const expected = removed.encodeErrorResult("NoTargetFor", [data.slice(0, 10)]).toLowerCase();
    const frozen = await unchanged();
    let rejected = false;
    try { await chain.send("eth_call", [{ from: DEV, to: parent, data }, "latest"]); }
    catch (failure) {
      if (z.object({ data: hex }).passthrough().parse(failure).data !== expected) {
        throw new ExecutionError("STATE", "postactivation W-SD loader returned the wrong error");
      }
      rejected = true;
    }
    if (!rejected) throw new ExecutionError("STATE", "postactivation W-SD loader remained callable");
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
  const inventoryState = async () => {
    const balances = [];
    for (const asset of [dtfCustodySeSource, LEGACY.dtf, LEGACY.sy, LEGACY.receipt, LEGACY.detf]) {
      balances.push(String(await balance(asset, parent)), String(await inventory(asset)));
    }
    return [(await unchanged()), ...balances,
      (await chain.call(parent, recovery, "migrationRecoveryGons")).toString()].join("|");
  };
  const saved = await inventoryState();
  const deadline = () => chain.timestamp().then((time) => (time + 3600n).toString());
  const minimumFailure = await chain.transact(parent, { from: DEV,
    data: recovery.encodeFunctionData("recoverMigrationNfts",
      [[{ stage: 9, tokenId: 0, amount: q, minimum: 2n ** 256n - 1n }], await deadline()]) }, 0n);
  if (await inventoryState() !== saved) throw new ExecutionError("STATE", "W-SD output minimum did not roll back");
  const batchFailure = await chain.transact(parent, { from: DEV,
    data: recovery.encodeFunctionData("recoverMigrationNfts", [[
      { stage: 9, tokenId: 0, amount: q / 2n, minimum: 1 },
      { stage: 9, tokenId: 0, amount: q, minimum: 1 },
    ], await deadline()]) }, 0n);
  if (await inventoryState() !== saved) throw new ExecutionError("STATE", "W-SD selected batch did not roll back");
  const expectedAssets = z.bigint().parse((await chain.call(dtfCustodySeSource, custodySeAbi, "previewRedeem", [q]))[0]);
  const redeemed = await chain.transact(parent, { from: DEV,
    data: recovery.encodeFunctionData("recoverMigrationNfts",
      [[{ stage: 9, tokenId: 0, amount: q, minimum: expectedAssets }], await deadline()]) });
  const output = await inventory(LEGACY.dtf) - recovered0;
  const event = redeemed.logs.filter((log) => log.address === parent).map((log) =>
    recovery.parseLog({ topics: [...log.topics], data: log.data }))
    .find((log) => log?.name === "MigrationRecoveryConverted");
  if (!event || address.parse(event.args[0]) !== dtfCustodySeSource || address.parse(event.args[1]) !== LEGACY.dtf
    || event.args[2] !== q || event.args[3] !== output || output <= 0n || output !== expectedAssets
    || await balance(LEGACY.dtf, parent) - dtf0 !== output
    || await balance(dtfCustodySeSource, parent) !== p0 || await inventory(dtfCustodySeSource) !== i0
    || (await chain.call(dtfCustodySeSource, token, "allowance", [parent, dtfCustodySeSource]))[0] !== 0n) {
    throw new ExecutionError("STATE", "W-SD own-share burn or measured DTF output differs");
  }
  const committed = await inventoryState();
  const laterFailure = await chain.transact(parent, { from: DEV,
    data: recovery.encodeFunctionData("recoverMigrationNfts",
      [[{ stage: 9, tokenId: 0, amount: 1, minimum: 1 }], await deadline()]) }, 0n);
  if (await inventoryState() !== committed) throw new ExecutionError("STATE", "W-SD later failure changed prior receipt");
  const amount = output / 2n;
  const donated = await chain.transact(parent, { from: DEV, data: recovery.encodeFunctionData("recoverMigrationNfts",
    [[{ stage: 7, tokenId: 0, amount, minimum: 1 }], await deadline()]) });
  if (await inventory(LEGACY.dtf) !== recovered0 + output - amount
    || await balance(LEGACY.dtf, parent) < recovered0 + output - amount + donationBudget + 10n ** 18n
    || (await chain.call(parent, migration, "migrationDonationInventory", [LEGACY.dtf]))[0] !== donationBudget
    || [(await state()).toString(), String(await supply()), String(await balance(parent, receipt)),
      (await chain.call(bond, bondAbi, "positionOf", [bondId])).toString()].join("|") !== protectedState) {
    throw new ExecutionError("STATE", "W-SD recovery changed compensation or protected inventory");
  }
  observations.push({ kind: "redemption", minimumFailure: minimumFailure.transactionHash,
    batchFailure: batchFailure.transactionHash, redeemTransaction: redeemed.transactionHash,
    laterFailure: laterFailure.transactionHash, donationTransaction: donated.transactionHash,
    shares: q.toString(), dtfReceived: output.toString(), dtfDonated: amount.toString(),
    unbookedShares: p0.toString(), donationBudget: donationBudget.toString(),
    selfAllowance: "0", compensationUnchanged: true, fixedDestination: parent });
  if (final) {
    if ((await state()).getValue("deliveredCredit") !== c0) throw new ExecutionError("STATE", "W-SD final credit does not conserve C0");
    await reject(wallet, row.originalId, "InvalidDtfCustodySeQuantity", [1, 0]);
  }
  await save(join(evidence, "dtf-custody-se-" + phase + ".json"), {
    syntheticOriginalAllocation: row, originalCredit: c0.toString(), activated, observations,
  });
}
