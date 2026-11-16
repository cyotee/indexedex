import { Interface, Result } from "ethers";
import { z } from "zod";
import type { ExecutionDomain } from "./execution-domain.js";
import type { Rpc } from "./execution-rpc.js";
import { ExecutionError, rpcLog } from "./execution-schema.js";
import type { Completion, Intent, Receipt } from "./execution-schema.js";
import { canonical } from "./provenance.js";

const bondAbi = new Interface([
  "event Transfer(address indexed from,address indexed to,uint256 indexed tokenId)",
  "event BondClaimed(uint256 indexed tokenId,address indexed recipient,uint256 principal,uint256 rewards)",
  "event BondPurchased(uint256 indexed tokenId,address indexed owner,uint256 principal,uint256 startTimestamp,uint256 vestingDuration)",
  "function ownerOf(uint256) view returns(address)",
  "function positionOf(uint256) view returns((uint256 principal,uint256 claimedPrincipal,uint256 stakingGons,uint256 startTimestamp,uint256 vestingDuration))",
  "function isMigrationPosition(uint256) view returns(bool)",
  "function attributedBondGons() view returns(uint256)",
]);
const receiptAbi = new Interface([
  "function gonsOf(address) view returns(uint256)",
  "event Staked(address indexed payer,address indexed recipient,uint256 detfAmount,uint256 gons)",
  "event RewardsFunded(uint256 detfAmount,uint256 stakingGrowth,uint256 feeReceipt,uint256 creatorReceipt,uint256 gonsPerUnit)",
  "function stakingState() view returns((uint256 totalGons,uint256 gonsPerUnit,uint256 accountedBacking,uint256 allocationDust,uint256 stakingDust,uint256 feeWeight,uint256 creatorWeight))",
  "function deferredRewardGons(uint8,address) view returns(uint256)",
  "function balanceOf(address) view returns(uint256)",
]);

export async function verifyIndependentBond(rpc: Rpc, domain: ExecutionDomain, issuance: Result, proof: Completion): Promise<void> {
  const header = await rpc.header();
  const at = header.number;
  const parent = domain.manifest.proxy;
  const id = z.bigint().parse(issuance.getValue("bondTokenId"));
  const principal = z.bigint().parse(issuance.getValue("credit"));
  const bond = String((await rpc.call(parent, domain.abis.migration, "bondNftVault", [], at))[0]).toLowerCase();
  const staking = String((await rpc.call(parent, domain.abis.migration, "rebasingClaimToken", [], at))[0]).toLowerCase();
  const logs = z.array(rpcLog).parse(await rpc.send("eth_getLogs", [{
    address: bond, fromBlock: proof.receipt.blockNumber, toBlock: at,
    topics: [[bondAbi.getEvent("Transfer")?.topicHash, bondAbi.getEvent("BondClaimed")?.topicHash]],
  }]));
  let paid = 0n;
  let retired = false;
  const checked = new Set<string>();
  for (const log of logs) {
    if (!checked.has(log.transactionHash)) {
      const receipt = await rpc.canonicalReceipt(log.transactionHash);
      if (!receipt || receipt.blockHash !== log.blockHash) throw new ExecutionError("STATE", "noncanonical bond history");
      checked.add(log.transactionHash);
    }
    const event = bondAbi.parseLog({ topics: [...log.topics], data: log.data });
    if (event?.name === "BondClaimed" && event.args[0] === id) paid += z.bigint().parse(event.args[2]);
    if (event?.name === "Transfer" && event.args[2] === id) {
      retired = String(event.args[1]).toLowerCase() === "0x0000000000000000000000000000000000000000";
    }
  }
  if ((await rpc.call(bond, bondAbi, "isMigrationPosition", [id], at))[0] !== true || paid > principal) {
    throw new ExecutionError("STATE", "migration issuance policy or claimed principal differs");
  }
  if (retired) {
    if (paid !== principal) throw new ExecutionError("STATE", "retired bond lacks full canonical principal claims");
  } else {
    const position = tuple((await rpc.call(bond, bondAbi, "positionOf", [id], at))[0]);
    if (position.getValue("principal") !== principal || position.getValue("claimedPrincipal") !== paid
      || position.getValue("startTimestamp") !== issuance.getValue("issuedAt")
      || position.getValue("vestingDuration") !== 7776000n) {
      throw new ExecutionError("STATE", "immutable issued principal or fresh cliff changed");
    }
  }
  const stakingState = tuple((await rpc.call(staking, receiptAbi, "stakingState", [], at))[0]);
  const backing = z.bigint().parse((await rpc.call(parent, tokenAbi, "balanceOf", [staking], at))[0]);
  const held = z.bigint().parse((await rpc.call(staking, receiptAbi, "gonsOf", [bond], at))[0]);
  const attributed = z.bigint().parse((await rpc.call(bond, bondAbi, "attributedBondGons", [], at))[0]);
  if (backing < z.bigint().parse(stakingState.getValue("accountedBacking")) || held < attributed
    || (await rpc.header(at)).hash !== header.hash) throw new ExecutionError("STATE", "issued escrow insolvency or changed canonical header");
}
const tokenAbi = new Interface([
  "function balanceOf(address) view returns(uint256)",
  "function allowance(address,address) view returns(uint256)",
]);
function tuple(value: unknown): Result {
  if (!(value instanceof Result)) throw new ExecutionError("STATE", "invalid paid bond tuple");
  return value;
}

export async function captureOwnerBond(
  rpc: Rpc, domain: ExecutionDomain, item: Intent, mined: Receipt,
): Promise<Readonly<Record<string, string>>> {
  const { manifest: m, abis } = domain;
  const purchase = m.ownerBond;
  if (!purchase) throw new ExecutionError("DOMAIN", "missing explicit paid owner purchase");
  const at = mined.blockNumber;
  const before = `0x${(BigInt(at) - 1n).toString(16)}`;
  const call = (target: string, abi: Interface, method: string, args: readonly unknown[] = [], block = at) =>
    block === before
      ? rpc.atReceipt(mined, () => rpc.call(target, abi, method, args, at), true)
      : rpc.call(target, abi, method, args, block);
  const id = z.bigint().parse((await call(m.proxy, abis.migration, "migrationOwnerFirstBondTokenId"))[0]);
  if (id < 3n || (await call(m.proxy, abis.migration, "migrationOwnerFirstBondTokenId", [], before))[0] !== 0n
    || (await call(m.proxy, abis.migration, "migrationActivated"))[0] !== false
    || String((await call(m.proxy, abis.migration, "owner", [], before))[0]).toLowerCase() !== m.signer) {
    throw new ExecutionError("STATE", "paid owner purchase was not the first completed Stage1 purchase");
  }
  const args = abis.migration.decodeFunctionData("bond", item.transaction.data);
  if (String(args[0]).toLowerCase() !== purchase.token || String(args[1]) !== purchase.amount
    || String(args[2]) !== purchase.duration || String(args[3]).toLowerCase() !== m.signer
    || args[4] !== false || String(args[5]) !== purchase.deadline) {
    throw new ExecutionError("INTENT", "paid purchase differs from explicit operator terms");
  }
  const bond = String((await call(m.proxy, abis.migration, "bondNftVault"))[0]).toLowerCase();
  const staking = String((await call(m.proxy, abis.migration, "rebasingClaimToken"))[0]).toLowerCase();
  const position = tuple((await call(bond, bondAbi, "positionOf", [id]))[0]);
  const principal = z.bigint().parse(position.getValue("principal"));
  const bondEvents = mined.logs.filter((log) => log.address === bond)
    .flatMap((log) => { const parsed = bondAbi.parseLog({ topics: [...log.topics], data: log.data }); return parsed ? [parsed] : []; });
  const purchased = bondEvents.find((event) => event.name === "BondPurchased");
  const receiptEvents = mined.logs.filter((log) => log.address === staking)
    .flatMap((log) => { const parsed = receiptAbi.parseLog({ topics: [...log.topics], data: log.data }); return parsed ? [parsed] : []; });
  const staked = receiptEvents.find((event) => event.name === "Staked");
  if (!purchased || !staked || principal <= 0n || purchased.args[0] !== id
    || String(purchased.args[1]).toLowerCase() !== m.signer || purchased.args[2] !== principal
    || purchased.args[3] !== position.getValue("startTimestamp")
    || purchased.args[4] !== position.getValue("vestingDuration")
    || position.getValue("claimedPrincipal") !== 0n
    || String(staked.args[0]).toLowerCase() !== bond || String(staked.args[1]).toLowerCase() !== bond
    || staked.args[2] !== principal || staked.args[3] !== position.getValue("stakingGons")
    || (await call(bond, bondAbi, "isMigrationPosition", [id]))[0] !== false
    || String((await call(bond, bondAbi, "ownerOf", [id]))[0]).toLowerCase() !== m.signer) {
    throw new ExecutionError("STATE", "paid bond receipt, funded principal or ordinary position differs");
  }
  const paidBefore = z.bigint().parse((await call(purchase.token, tokenAbi, "balanceOf", [m.signer], before))[0]);
  const paidAfter = z.bigint().parse((await call(purchase.token, tokenAbi, "balanceOf", [m.signer]))[0]);
  if (paidBefore - paidAfter !== BigInt(purchase.amount)) throw new ExecutionError("STATE", "actual authorized payment differs");
  const rewards = receiptEvents.filter((event) => event.name === "RewardsFunded");
  const fundedRewards = rewards.reduce((sum, event) => sum + z.bigint().parse(event.args[0]), 0n);
  const oldState = tuple((await call(staking, receiptAbi, "stakingState", [], before))[0]);
  const newState = tuple((await call(staking, receiptAbi, "stakingState"))[0]);
  const backingBefore = z.bigint().parse((await call(m.proxy, tokenAbi, "balanceOf", [staking], before))[0]);
  const backingAfter = z.bigint().parse((await call(m.proxy, tokenAbi, "balanceOf", [staking]))[0]);
  if (backingAfter - backingBefore !== principal + fundedRewards
    || z.bigint().parse(newState.getValue("accountedBacking")) - z.bigint().parse(oldState.getValue("accountedBacking"))
      !== principal + fundedRewards) throw new ExecutionError("STATE", "paid principal and rewards lack exact backing");
  const roleGons = new Map<string, bigint>();
  for (const [role, index] of [[1, 2], [2, 3]] as const) {
    const beneficiary = String((await call(bond, bondAbi, "ownerOf", [role]))[0]).toLowerCase();
    const gons = rewards.reduce((sum, event) => sum
      + z.bigint().parse(event.args[index]) * z.bigint().parse(event.args[4]), 0n);
    roleGons.set(beneficiary, (roleGons.get(beneficiary) ?? 0n) + gons);
  }
  for (const [beneficiary, gons] of roleGons) {
    const oldGons = z.bigint().parse((await call(staking, receiptAbi, "deferredRewardGons", [1, beneficiary], before))[0]);
    const newGons = z.bigint().parse((await call(staking, receiptAbi, "deferredRewardGons", [1, beneficiary]))[0]);
    if (newGons - oldGons !== gons || (await call(staking, receiptAbi, "balanceOf", [beneficiary]))[0]
      !== (await call(staking, receiptAbi, "balanceOf", [beneficiary], before))[0]) {
      throw new ExecutionError("STATE", "Stage1 fee/creator rewards escaped retention");
    }
  }
  for (const [holder, spender] of [[m.proxy, bond], [m.proxy, staking], [bond, staking]]) {
    if ((await call(m.proxy, tokenAbi, "allowance", [holder, spender]))[0] !== 0n) {
      throw new ExecutionError("STATE", "paid purchase left a child funding allowance");
    }
  }
  return { ownerFirstBondTokenId: String(id), paid: (paidBefore - paidAfter).toString(),
    principal: principal.toString(), fundedRewards: fundedRewards.toString(),
    position: canonical(position.toArray().map(String)), stakingBefore: canonical(oldState.toArray().map(String)),
    stakingAfter: canonical(newState.toArray().map(String)), backingBefore: String(backingBefore),
    backingAfter: String(backingAfter), retainedRoleGons: canonical([...roleGons].map(([role, gons]) => [role, String(gons)])) };
}
