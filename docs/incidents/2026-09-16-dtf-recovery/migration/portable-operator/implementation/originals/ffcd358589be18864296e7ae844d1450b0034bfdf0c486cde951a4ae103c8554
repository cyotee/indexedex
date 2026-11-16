import { Interface, Result } from "ethers";
import { join } from "node:path";
import { z } from "zod";
import { address, hex } from "./schema.js";
import type { PreparationInput } from "./schema.js";
import { ExecutionError, quantity } from "./execution-schema.js";
import type { ExecutionManifest } from "./execution-schema.js";
import { DEV } from "./execution-rpc.js";
import { LEGACY, legacyAbi } from "./rehearsal-chain.js";
import type { RehearsalChain } from "./rehearsal-chain.js";
import { interfaceFile, save } from "./rehearsal-data.js";
import { signWs, wsSourceAbi, wsWallet } from "./rehearsal-weighted-receipt-source.js";

const token = new Interface([
  "function balanceOf(address) view returns(uint256)", "function totalSupply() view returns(uint256)",
  "function allowance(address,address) view returns(uint256)",
]);
const bondAbi = new Interface([
  "function ownerOf(uint256) view returns(address)",
  "function positionOf(uint256) view returns((uint256 principal,uint256 claimedPrincipal,uint256 stakingGons,uint256 startTimestamp,uint256 vestingDuration))",
  "function isMigrationPosition(uint256) view returns(bool)",
]);
function tuple(value: unknown): Result {
  if (!(value instanceof Result)) throw new ExecutionError("STATE", "WS integration tuple differs");
  return value;
}

/** The real registry-deployed Migration receives signed native pulls and issues exact-funded cliff bonds. */
export async function exerciseWeightedReceipt(context: {
  readonly chain: RehearsalChain; readonly manifest: ExecutionManifest; readonly input: PreparationInput;
  readonly evidence: string; readonly phase: "stage1" | "partial" | "residual";
}) {
  const { chain, manifest, input, evidence, phase } = context;
  const row = input.weightedReceipt[0]?.original;
  if (!row || row.originalWallet !== wsWallet().address.toLowerCase()) {
    throw new ExecutionError("STATE", "WS original controlled signer or allocation is missing");
  }
  const parent = manifest.proxy;
  const migration = await interfaceFile("out/IUniswapV4DetfMigration.sol/IUniswapV4DetfMigration.json");
  const recovery = await interfaceFile("out/IUniswapV4DetfMigrationRecovery.sol/IUniswapV4DetfMigrationRecovery.json");
  const bond = address.parse((await chain.call(parent, migration, "bondNftVault"))[0]);
  const receipt = address.parse((await chain.call(parent, migration, "rebasingClaimToken"))[0]);
  const state = async () => tuple((await chain.call(parent, migration, "weightedReceiptSurrender", [row.originalId]))[0]);
  const staking = async (source: string = LEGACY.receipt) => tuple((await chain.call(source, legacyAbi, "stakingState"))[0]);
  const gons = async (who: string) => z.bigint().parse((await chain.call(LEGACY.receipt, legacyAbi, "gonsOf", [who]))[0]);
  const balance = async (source: string, who: string) => z.bigint().parse((await chain.call(source, token, "balanceOf", [who]))[0]);
  const booked = async () => z.bigint().parse((await chain.call(parent, recovery, "migrationRecoveryGons"))[0]);
  const config = tuple((await chain.call(parent, migration, "weightedReceiptEntitlement", [row.originalId]))[0]);
  const c0 = z.bigint().parse(config.getValue("credit"));
  if (config.getValue("configured") !== true || (await chain.call(parent, migration, "migrationActivated"))[0] !== (phase !== "stage1")) {
    throw new ExecutionError("STATE", "WS lifecycle or configured original differs");
  }
  const snapshot = async () => {
    const roles = [];
    for (const id of [1, 2]) {
      const owner = address.parse((await chain.call(LEGACY.weighted, legacyAbi, "ownerOf", [id]))[0]);
      roles.push([owner, String(await gons(owner))]);
    }
    return JSON.stringify({
      oldState: String(await staking()), roles, wallet: String(await gons(row.originalWallet)), custody: String(await gons(parent)),
      allowance: String((await chain.call(LEGACY.receipt, token, "allowance", [row.originalWallet, parent]))[0]),
      remaining: String(await state()), booked: String(await booked()), supply: String(await balanceSupply()),
      backing: String(await balance(parent, receipt)), newState: String(await staking(receipt)),
    });
  };
  const balanceSupply = async () => z.bigint().parse((await chain.call(parent, token, "totalSupply"))[0]);
  const rejects: unknown[] = [];
  const reject = async (origin: string, n: bigint, error: string, args: readonly unknown[], index = 117) => {
    const from = wsWallet(index).address.toLowerCase();
    const data = migration.encodeFunctionData("surrenderMigrationWeightedReceipt",
      [origin, n, 0, (await chain.timestamp() + 3600n).toString()]);
    const expected = migration.encodeErrorResult(error, [...args]).toLowerCase();
    const before = await snapshot();
    let failed = false;
    try { await chain.send("eth_call", [{ from, to: parent, data }, "latest"]); }
    catch (failure) {
      if (z.object({ data: hex }).passthrough().parse(failure).data !== expected) {
        throw new ExecutionError("STATE", "WS negative returned an unexpected error");
      }
      failed = true;
    }
    if (!failed) throw new ExecutionError("STATE", "WS negative unexpectedly succeeded");
    const mined = await signWs(chain, evidence, { to: parent, data, index, status: 0n });
    if (mined.logs.length !== 0 || await snapshot() !== before) throw new ExecutionError("STATE", "WS negative changed economic state");
    rejects.push({ transactionHash: mined.transactionHash, status: mined.status, expected, before, after: await snapshot() });
  };
  if (phase === "stage1") {
    await signWs(chain, evidence, { to: LEGACY.receipt,
      data: legacyAbi.encodeFunctionData("approve", [parent, 1000000]) });
    await reject(row.originalId, 1n, "MigrationSurrenderClosed", []);
    await reject(`0x${"a".repeat(64)}`, 1n, "MigrationSurrenderClosed", []);
    if ((await state()).getValue("remainingUnits") !== BigInt(row.originalUnits)
      || (await state()).getValue("remainingCredit") !== c0) throw new ExecutionError("STATE", "WS Stage1 baseline differs");
    await save(join(evidence, "weighted-receipt-stage1.json"), { original: row, credit: String(c0), rejects });
    return;
  }
  if (phase === "partial") {
    await reject(`0x${"a".repeat(64)}`, 1n, "InvalidWeightedReceiptEntitlement", [`0x${"a".repeat(64)}`]);
    const other = wsWallet(118).address.toLowerCase();
    await signWs(chain, evidence, { to: LEGACY.receipt, data: legacyAbi.encodeFunctionData("transfer", [other, 1]) });
    await reject(row.originalId, 1n, "NotOriginalWeightedReceiptWallet", [other, row.originalWallet], 118);
    await signWs(chain, evidence, { to: LEGACY.receipt, data: legacyAbi.encodeFunctionData("transfer", [row.originalWallet, 1]), index: 118 });
    await chain.send("evm_setNextBlockTimestamp", [Number(await chain.timestamp() + 28800n)]);
    await chain.send("evm_mine", []);
  } else {
    await signWs(chain, evidence, { to: LEGACY.detf, data: wsSourceAbi.encodeFunctionData("synchronizeRewards") });
  }
  // Settle only the NEW parent here; the partial WS operation must itself settle old WD.
  await chain.transact(parent, { from: DEV, data: migration.encodeFunctionData("synchronizeRewards") });
  const before = await state();
  const q0 = z.bigint().parse(before.getValue("remainingUnits"));
  const c = z.bigint().parse(before.getValue("remainingCredit"));
  const oldStateBefore = await staking();
  const oldK = z.bigint().parse(oldStateBefore.getValue("gonsPerUnit"));
  const n = phase === "partial" ? 1n : q0 / oldK;
  if (n === 0n) throw new ExecutionError("STATE", "WS fixture has no positive representable partial input");
  const w0 = await gons(row.originalWallet);
  const g0 = await gons(parent);
  const b0 = await booked();
  const s0 = await balanceSupply();
  const backing0 = await balance(parent, receipt);
  const mined = await signWs(chain, evidence, { to: parent, data: migration.encodeFunctionData(
    "surrenderMigrationWeightedReceipt", [row.originalId, n, 1, (await chain.timestamp() + 3600n).toString()]) });
  const event = mined.logs.filter((log) => log.address === parent).map((log) =>
    migration.parseLog({ topics: [...log.topics], data: log.data })).find((log) => log?.name === "MigrationWeightedReceiptSurrendered");
  if (!event) throw new ExecutionError("STATE", "WS surrender event missing");
  const k = z.bigint().parse(event.args[5]);
  const q = n * k;
  const credit = q === q0 ? c : c * q / q0;
  const id = z.bigint().parse(event.args[7]);
  const position = tuple((await chain.call(bond, bondAbi, "positionOf", [id]))[0]);
  const block = z.object({ timestamp: quantity }).passthrough().parse(await chain.send("eth_getBlockByNumber", [mined.blockNumber, false]));
  const after = await state();
  const oldStateAfter = await staking();
  const newStateAfter = await staking(receipt);
  const newK = z.bigint().parse(newStateAfter.getValue("gonsPerUnit"));
  const w1 = await gons(row.originalWallet);
  const g1 = await gons(parent);
  const b1 = await booked();
  const s1 = await balanceSupply();
  const backing1 = await balance(parent, receipt);
  const parentAllowance = z.bigint().parse((await chain.call(parent, token, "allowance", [parent, bond]))[0]);
  const bondAllowance = z.bigint().parse((await chain.call(parent, token, "allowance", [bond, receipt]))[0]);
  if (event.args[0] !== row.originalId || event.args[1] !== config.getValue("configurationId")
    || address.parse(event.args[2]) !== row.originalWallet || event.args[3] !== n || event.args[4] !== q
    || event.args[6] !== credit || credit <= 0n || w0 - w1 !== q
    || g1 - g0 !== q || b1 - b0 !== q
    || after.getValue("remainingUnits") !== q0 - q || after.getValue("remainingCredit") !== c - credit
    || position.getValue("principal") !== credit || position.getValue("claimedPrincipal") !== 0n
    || position.getValue("stakingGons") !== credit * newK || position.getValue("vestingDuration") !== 7776000n
    || position.getValue("startTimestamp") !== BigInt(block.timestamp)
    || address.parse((await chain.call(bond, bondAbi, "ownerOf", [id]))[0]) !== row.originalWallet
    || (await chain.call(bond, bondAbi, "isMigrationPosition", [id]))[0] !== true
    || s1 - s0 !== credit || backing1 - backing0 !== credit || parentAllowance !== 0n || bondAllowance !== 0n) {
    throw new ExecutionError("STATE", "WS exact custody, eligible credit or fresh funded cliff differs");
  }
  const residual = { eligibleGons: String(after.getValue("remainingUnits")), credit: String(after.getValue("remainingCredit")) };
  if (phase === "residual") {
    const remainingQ = BigInt(residual.eligibleGons);
    if (remainingQ <= 0n || remainingQ >= k || BigInt(residual.credit) <= 0n) {
      throw new ExecutionError("STATE", "WS fixture did not preserve the intended positive nonrepresentable Q/C");
    }
    // View independently rejects one native because its k-gon input exceeds Q; no over-surrender policy.
    let rejected = false;
    try { await chain.call(parent, migration, "previewWeightedReceiptSurrender", [row.originalId, 1]); }
    catch (failure) {
      const expected = migration.encodeErrorResult("InvalidWeightedReceiptQuantity", [k, remainingQ]).toLowerCase();
      if (z.object({ data: hex }).passthrough().parse(failure).data !== expected) {
        throw new ExecutionError("STATE", "WS residual view returned an unexpected error");
      }
      rejected = true;
    }
    if (!rejected) throw new ExecutionError("STATE", "WS residual was silently treated as terminal");
    await reject(row.originalId, 0n, "InvalidWeightedReceiptEntitlement", [row.originalId]);
  }
  await save(join(evidence, `weighted-receipt-${phase}.json`), {
    original: row, configurationId: config.getValue("configurationId"), transactionHash: mined.transactionHash,
    nativeAmount: String(n), eligibleGons: String(q), divisor: String(k), oldDivisor: String(oldK),
    credit: String(credit), bondTokenId: String(id), principal: String(position.getValue("principal")),
    stakingGons: String(position.getValue("stakingGons")), start: String(position.getValue("startTimestamp")),
    duration: String(position.getValue("vestingDuration")), residual, rejects,
    observed: {
      originalGonsBefore: String(w0), originalGonsAfter: String(w1), custodyGonsBefore: String(g0),
      custodyGonsAfter: String(g1), bookedGonsBefore: String(b0), bookedGonsAfter: String(b1),
      newSupplyBefore: String(s0), newSupplyAfter: String(s1),
      newStakingBackingBefore: String(backing0), newStakingBackingAfter: String(backing1),
      parentBondAllowance: String(parentAllowance), bondStakingAllowance: String(bondAllowance),
      sourceStateBefore: [...oldStateBefore].map(String), sourceStateAfter: [...oldStateAfter].map(String),
      newStakingStateAfter: [...newStateAfter].map(String),
      surrenderBefore: [...before].map(String), surrenderAfter: [...after].map(String),
      bondPosition: [...position].map(String), block,
    },
  });
  const inventories = async () => {
    const rows = [];
    for (const source of [LEGACY.receipt, LEGACY.detf, LEGACY.dtf]) {
      rows.push(String(await balance(source, parent)),
        String((await chain.call(parent, recovery, "migrationRecoveryInventory", [source]))[0]));
    }
    return JSON.stringify([await snapshot(), ...rows]);
  };
  const deadline = (await chain.timestamp() + 3600n).toString();
  const selected = [
    { stage: 3, tokenId: 0, amount: n, minimum: 0 },
    { stage: 4, tokenId: 0, amount: n, minimum: (1n << 256n) - 1n },
  ];
  const recoveryBefore = await inventories();
  const failed = await chain.transact(parent, { from: DEV,
    data: recovery.encodeFunctionData("recoverMigrationNfts", [selected, deadline]) }, 0n);
  if (failed.logs.length !== 0 || await inventories() !== recoveryBefore) {
    throw new ExecutionError("STATE", "WS selected unstake/conversion late failure did not roll back");
  }
  const gonsBefore = await gons(parent);
  const bookedBefore = await booked();
  const unbooked = gonsBefore - bookedBefore;
  const wdBefore = await balance(LEGACY.detf, parent);
  const dtfBefore = await balance(LEGACY.dtf, parent);
  selected[1] = { stage: 4, tokenId: 0, amount: n, minimum: 1n };
  const converted = await chain.transact(parent, { from: DEV,
    data: recovery.encodeFunctionData("recoverMigrationNfts", [selected, deadline]) });
  const actualDebit = gonsBefore - await gons(parent);
  const dtfOut = await balance(LEGACY.dtf, parent) - dtfBefore;
  if (actualDebit > bookedBefore || actualDebit !== bookedBefore - await booked()
    || await gons(parent) - await booked() !== unbooked || dtfOut <= 0n
    || await balance(LEGACY.detf, parent) !== wdBefore) {
    throw new ExecutionError("STATE", "WS fixed unstake/conversion spent an unbooked budget or returned wrong assets");
  }
  const donated = await chain.transact(parent, { from: DEV, data: recovery.encodeFunctionData(
    "recoverMigrationNfts", [[{ stage: 7, tokenId: 0, amount: dtfOut, minimum: 1 }], deadline]) });
  if ((await state()).getValue("remainingUnits") !== BigInt(residual.eligibleGons)
    || (await state()).getValue("remainingCredit") !== BigInt(residual.credit)
    || await balanceSupply() !== s0 + credit || await balance(parent, receipt) !== backing0 + credit) {
    throw new ExecutionError("STATE", "WS recovery changed original credit or new bond backing");
  }
  await save(join(evidence, `weighted-receipt-${phase}-recovery.json`), {
    failed: failed.transactionHash, converted: converted.transactionHash, donated: donated.transactionHash,
    nativeAmount: String(n), actualGonDebit: String(actualDebit), unbookedGons: String(unbooked),
    dtfOutput: String(dtfOut), residual, fixedRoute: "WS->WD->DTF->new reserve",
  });
}
