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
import { claimVaultSource } from "./payloads.js";
import { claimVaultAbi } from "./rehearsal-claim-vault-source.js";
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

/** Actual configured claim-vault transferFrom and recovery; original allocation is explicitly synthetic. */
export async function exerciseClaimVault(context: {
  readonly chain: RehearsalChain; readonly manifest: ExecutionManifest; readonly input: PreparationInput;
  readonly evidence: string; readonly phase: "stage1" | "partial" | "final";
}) {
  const { chain, manifest, input, evidence, phase } = context;
  const activated = phase !== "stage1";
  const final = phase === "final";
  const row = input.claimVault[0]?.original;
  if (!row) throw new ExecutionError("STATE", "missing synthetic claim-vault original inputs");
  const migration = await interfaceFile("out/IUniswapV4DetfMigration.sol/IUniswapV4DetfMigration.json");
  const recovery = await interfaceFile("out/IUniswapV4DetfMigrationRecovery.sol/IUniswapV4DetfMigrationRecovery.json");
  const parent = manifest.proxy;
  const wallet = row.originalWallet;
  const bond = address.parse((await chain.call(parent, migration, "bondNftVault"))[0]);
  const receipt = address.parse((await chain.call(parent, migration, "rebasingClaimToken"))[0]);
  const tuple = (value: unknown) => {
    if (!(value instanceof Result)) throw new ExecutionError("STATE", "invalid claim-vault tuple");
    return value;
  };
  const state = async () => tuple((await chain.call(parent, migration, "claimVaultSurrender", [row.originalId]))[0]);
  const config = tuple((await chain.call(parent, migration, "claimVaultEntitlement", [row.originalId]))[0]);
  const c0 = z.bigint().parse(config.getValue("credit"));
  if (config.getValue("configured") !== true
    || address.parse(tuple(config.getValue("original")).getValue("originalWallet")) !== wallet
    || (await chain.call(parent, migration, "migrationActivated"))[0] !== activated) {
    throw new ExecutionError("STATE", "claim-vault configured wallet or lifecycle differs");
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
    (await state()).toString(), (await balance(claimVaultSource, wallet)).toString(),
    (await balance(claimVaultSource, parent)).toString(), (await inventory(claimVaultSource)).toString(),
    (await supply()).toString(), (await balance(parent, receipt)).toString(),
    (await chain.call(claimVaultSource, token, "allowance", [wallet, parent])).toString(),
    (await chain.call(parent, migration, "claimVaultEntitlement", [row.originalId])).toString(),
    (await chain.call(bond, bondAbi, "balanceOf", [wallet])).toString(),
    (await chain.call(receipt, legacyAbi, "stakingState")).toString(),
  ].join("|");
  const observations: unknown[] = [];
  const reject = async (caller: string, origin: string, error: string, args: readonly unknown[], units = 1n) => {
    const data = migration.encodeFunctionData("surrenderMigrationClaimVault",
      [origin, units, "0", (await chain.timestamp() + 3600n).toString()]);
    const expected = migration.encodeErrorResult(error, [...args]).toLowerCase();
    const before = await unchanged();
    let reverted = false;
    try { await chain.send("eth_call", [{ from: caller, to: parent, data }, "latest"]); }
    catch (failure) {
      const actual = z.object({ data: hex }).passthrough().parse(failure).data;
      if (actual !== expected) {
        throw new ExecutionError("STATE", `claim-vault rejection has wrong revert data: expected ${expected}, actual ${actual}`);
      }
      reverted = true;
    }
    if (!reverted) throw new ExecutionError("STATE", "claim-vault negative unexpectedly succeeded");
    await impersonate(caller, async () => {
      const mined = await chain.transact(parent, { from: caller, data }, 0n);
      observations.push({ kind: "rejection", error, caller, originalId: origin,
        transactionHash: mined.transactionHash, status: mined.status, revertData: expected });
    });
    if (await unchanged() !== before) throw new ExecutionError("STATE", "claim-vault rejection changed custody or credit");
  };
  if (!activated) {
    await impersonate(wallet, async () => {
      await chain.transact(claimVaultSource, { from: wallet,
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
    await save(join(evidence, "claim-vault-stage1.json"), {
      syntheticOriginalAllocation: row, originalCredit: c0.toString(), activated, observations,
      remainingUnits: String(unspent.getValue("remainingUnits")), remainingCredit: String(unspent.getValue("remainingCredit")),
    });
    return;
  }
  await reject(wallet, `0x${"a".repeat(64)}`, "InvalidClaimVaultEntitlement", [`0x${"a".repeat(64)}`]);
  const other = RECIPIENTS[3];
  const probeState = await state();
  const probeCredit = z.bigint().parse(probeState.getValue("remainingCredit"));
  const probeUnits = (z.bigint().parse(probeState.getValue("remainingUnits")) + probeCredit - 1n) / probeCredit;
  await impersonate(wallet, async () => {
    await chain.transact(claimVaultSource, { from: wallet, data: legacyAbi.encodeFunctionData("transfer", [other, probeUnits]) });
  });
  await impersonate(other, async () => {
    await chain.transact(claimVaultSource, { from: other, data: legacyAbi.encodeFunctionData("approve", [parent, probeUnits]) });
  });
  await reject(other, row.originalId, "NotOriginalClaimVaultWallet", [other, wallet], probeUnits);
  await impersonate(other, async () => {
    await chain.transact(claimVaultSource, { from: other, data: legacyAbi.encodeFunctionData("transfer", [wallet, probeUnits]) });
  });
  if (!final) {
    await impersonate(wallet, async () => {
      await chain.transact(claimVaultSource, { from: wallet, data: legacyAbi.encodeFunctionData("transfer", [parent, 7]) });
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
  if (q === 0n || expected === 0n) throw new ExecutionError("STATE", "claim-vault fixture has no eligible credit");
  const w0 = await balance(claimVaultSource, wallet);
  const p0 = await balance(claimVaultSource, parent);
  const i0 = await inventory(claimVaultSource);
  const s0 = await supply();
  const b0 = await balance(parent, receipt);
  let bondId = 0n;
  await impersonate(wallet, async () => {
    await chain.transact(claimVaultSource, { from: wallet, data: legacyAbi.encodeFunctionData("approve", [parent, q]) });
    const mined = await chain.transact(parent, { from: wallet,
      data: migration.encodeFunctionData("surrenderMigrationClaimVault",
        [row.originalId, q, expected, (await chain.timestamp() + 3600n).toString()]) });
    const event = mined.logs.filter((log) => log.address === parent).map((log) =>
      migration.parseLog({ topics: [...log.topics], data: log.data }))
      .find((log) => log?.name === "MigrationClaimVaultSurrendered");
    if (!event) throw new ExecutionError("STATE", "missing claim-vault surrender event");
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
      || w0 - await balance(claimVaultSource, wallet) !== q || await balance(claimVaultSource, parent) - p0 !== q
      || await inventory(claimVaultSource) - i0 !== q || await supply() - s0 !== expected
      || await balance(parent, receipt) - b0 !== expected
      || after.getValue("remainingUnits") !== remainingUnits - q
      || after.getValue("remainingCredit") !== remainingCredit - expected
      || after.getValue("consumedUnits") !== z.bigint().parse(before.getValue("consumedUnits")) + q
      || after.getValue("deliveredCredit") !== z.bigint().parse(before.getValue("deliveredCredit")) + expected) {
      throw new ExecutionError("STATE", "claim-vault exact transfer, credit, inventory or funded fresh bond differs");
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
    const data = allocation.encodeFunctionData("configureClaimVaultEntitlements", [[replacement]]);
    const expected = removed.encodeErrorResult("NoTargetFor", [data.slice(0, 10)]).toLowerCase();
    const frozen = await unchanged();
    let rejected = false;
    try { await chain.send("eth_call", [{ from: DEV, to: parent, data }, "latest"]); }
    catch (failure) {
      if (z.object({ data: hex }).passthrough().parse(failure).data !== expected) {
        throw new ExecutionError("STATE", "postactivation claim-vault loader returned the wrong error");
      }
      rejected = true;
    }
    if (!rejected) throw new ExecutionError("STATE", "postactivation claim-vault loader remained callable");
    const mined = await chain.transact(parent, { from: DEV, data }, 0n);
    if (await unchanged() !== frozen) throw new ExecutionError("STATE", "removed loader changed the remaining Q/C");
    observations.push({ kind: "removed-loader", transactionHash: mined.transactionHash, status: mined.status,
      revertData: expected, remainingUnits: String((await state()).getValue("remainingUnits")),
      remainingCredit: String((await state()).getValue("remainingCredit")) });
  }
  const protectedState = [(await state()).toString(), String(await supply()), String(await balance(parent, receipt)),
    (await chain.call(bond, bondAbi, "positionOf", [bondId])).toString()].join("|");
  const inventoryState = async () => {
    const balances = [];
    for (const asset of [claimVaultSource, LEGACY.sy, LEGACY.receipt, LEGACY.detf, LEGACY.dtf]) {
      balances.push(String(await balance(asset, parent)), String(await inventory(asset)));
    }
    return [(await unchanged()), ...balances,
      String(await balance(LEGACY.sy, claimVaultSource)),
      (await chain.call(claimVaultSource, token, "totalSupply")).toString(),
      (await chain.call(parent, recovery, "migrationRecoveryGons")).toString()].join("|");
  };
  const deadline = () => chain.timestamp().then((time) => (time + 3600n).toString());
  const run = async (stage: number, amount: bigint, minimum: bigint, status = 1n) =>
    chain.transact(parent, { from: DEV, data: recovery.encodeFunctionData("recoverMigrationNfts",
      [[{ stage, tokenId: 0, amount, minimum }], await deadline()]) }, status);
  const saved = await inventoryState();
  const minimumFailure = await run(10, q, 2n ** 256n - 1n, 0n);
  if (await inventoryState() !== saved) throw new ExecutionError("STATE", "claim-vault minimum failed rollback");
  const batchFailure = await chain.transact(parent, { from: DEV,
    data: recovery.encodeFunctionData("recoverMigrationNfts", [[
      { stage: 10, tokenId: 0, amount: q / 2n, minimum: 1 },
      { stage: 10, tokenId: 0, amount: q, minimum: 1 },
    ], await deadline()]) }, 0n);
  if (await inventoryState() !== saved) throw new ExecutionError("STATE", "claim-vault selected batch failed rollback");
  const sy0 = await balance(LEGACY.sy, parent);
  const bookedSy0 = await inventory(LEGACY.sy);
  const sourceSy0 = await balance(LEGACY.sy, claimVaultSource);
  const shareSupply0 = z.bigint().parse((await chain.call(claimVaultSource, token, "totalSupply"))[0]);
  const expectedAssets = z.bigint().parse((await chain.call(claimVaultSource, claimVaultAbi, "previewRedeem", [q]))[0]);
  const redeemed = await run(10, q, expectedAssets);
  const output = await inventory(LEGACY.sy) - bookedSy0;
  if (output <= 0n || output !== expectedAssets || await balance(LEGACY.sy, parent) - sy0 !== output
    || sourceSy0 - await balance(LEGACY.sy, claimVaultSource) !== output
    || shareSupply0 - z.bigint().parse((await chain.call(claimVaultSource, token, "totalSupply"))[0]) !== q
    || await balance(claimVaultSource, parent) !== p0 || await inventory(claimVaultSource) !== i0
    || (await chain.call(claimVaultSource, token, "allowance", [parent, claimVaultSource]))[0] !== 0n) {
    throw new ExecutionError("STATE", "claim-vault exact selected burn and measured SY differ");
  }
  const committed = await inventoryState();
  const laterFailure = await run(10, 1n, 1n, 0n);
  if (await inventoryState() !== committed) throw new ExecutionError("STATE", "later failure erased committed redemption");
  const syRedeemed = await run(8, output, 1n);
  const converted = syRedeemed.logs.filter((log) => log.address === parent).map((log) =>
    recovery.parseLog({ topics: [...log.topics], data: log.data }))
    .find((log) => log?.name === "MigrationRecoveryConverted");
  if (!converted || address.parse(converted.args[0]) !== LEGACY.sy
    || address.parse(converted.args[1]) !== LEGACY.receipt || converted.args[2] !== output) {
    throw new ExecutionError("STATE", "missing measured SY toWS conversion");
  }
  const receiptOut = z.bigint().parse(converted.args[3]);
  const wdBefore = await inventory(LEGACY.detf);
  const unstaked = await run(3, receiptOut, 0n);
  if (await inventory(LEGACY.detf) - wdBefore !== receiptOut) throw new ExecutionError("STATE", "claim-vault WS unstake differs");
  const dtfBefore = await inventory(LEGACY.dtf);
  const convertedDtf = await run(4, receiptOut, 1n);
  const dtfOut = await inventory(LEGACY.dtf) - dtfBefore;
  const budget = z.bigint().parse((await chain.call(parent, migration, "migrationDonationInventory", [LEGACY.dtf]))[0]);
  const donated = await run(7, dtfOut, 1n);
  if (await inventory(LEGACY.dtf) !== dtfBefore || await inventory(LEGACY.sy) !== bookedSy0
    || await inventory(LEGACY.detf) !== wdBefore
    || (await chain.call(parent, migration, "migrationDonationInventory", [LEGACY.dtf]))[0] !== budget
    || await balance(LEGACY.dtf, parent) < dtfBefore + budget + 10n ** 18n
    || [(await state()).toString(), String(await supply()), String(await balance(parent, receipt)),
      (await chain.call(bond, bondAbi, "positionOf", [bondId])).toString()].join("|") !== protectedState) {
    throw new ExecutionError("STATE", "claim-vault onward recovery changed protected custody or new bond");
  }
  observations.push({ kind: "redemption", minimumFailure: minimumFailure.transactionHash,
    batchFailure: batchFailure.transactionHash, redeemTransaction: redeemed.transactionHash,
    laterFailure: laterFailure.transactionHash, syRedeemTransaction: syRedeemed.transactionHash,
    unstakeTransaction: unstaked.transactionHash, convertTransaction: convertedDtf.transactionHash,
    donationTransaction: donated.transactionHash, shares: q.toString(), syReceived: output.toString(),
    receiptUnits: receiptOut.toString(), dtfReceived: dtfOut.toString(), dtfDonated: dtfOut.toString(),
    unbookedShares: p0.toString(), donationBudget: budget.toString(), selfAllowance: "0", fixedDestination: parent,
    trace: await chain.send("debug_traceTransaction", [redeemed.transactionHash, { tracer: "callTracer" }]) });
  if (final) {
    if ((await state()).getValue("deliveredCredit") !== c0) throw new ExecutionError("STATE", "claim-vault final credit differs");
    await reject(wallet, row.originalId, "InvalidClaimVaultQuantity", [1, 0]);
  }
  await save(join(evidence, "claim-vault-" + phase + ".json"), {
    syntheticOriginalAllocation: row, originalCredit: c0.toString(), activated, observations,
  });
}
