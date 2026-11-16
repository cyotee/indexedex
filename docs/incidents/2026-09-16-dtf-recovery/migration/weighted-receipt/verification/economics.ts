import assert from "node:assert/strict";
import { readFile, readdir, writeFile } from "node:fs/promises";
import { resolve, join, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import { createHash } from "node:crypto";
import { AbiCoder, Interface, Transaction, keccak256, id } from "ethers";
import { z } from "zod";
import { receipt } from "../../../../../../scripts/recovery/dtf-migration/execution-schema.js";
import { interfaceFile } from "../../../../../../scripts/recovery/dtf-migration/rehearsal-data.js";
import { preparationInput } from "../../../../../../scripts/recovery/dtf-migration/schema.js";

const here = dirname(fileURLToPath(import.meta.url));
const runtime = resolve(z.string().parse(process.argv[2]));
const json = async (path: string): Promise<unknown> => JSON.parse(await readFile(path, "utf8"));
const uint = z.string().regex(/^\d+$/).transform(BigInt);
const state7 = z.tuple([uint, uint, uint, uint, uint, uint, uint]);
const state4 = z.tuple([uint, uint, uint, uint]);
const position5 = z.tuple([uint, uint, uint, uint, uint]);
const signed = z.object({ raw: z.string(), receipt }).passthrough();
const signatures = new Map<string, z.infer<typeof signed>>();
for (const name of (await readdir(runtime)).filter((n) => n.startsWith("ws-signed-"))) {
  const row = signed.parse(await json(join(runtime, name)));
  signatures.set(row.receipt.transactionHash, row);
}
const abi = await interfaceFile("out/IUniswapV4DetfMigration.sol/IUniswapV4DetfMigration.json");
const allocation = await interfaceFile("out/IUniswapV4DetfMigration.sol/IUniswapV4DetfMigrationAllocation.json");
const oldEvents = new Interface([
  "event RewardsFunded(uint256 amount,uint256 stakingGrowth,uint256 feeReceipt,uint256 creatorReceipt,uint256 gonsPerUnit)",
  "event Staked(address indexed payer,address indexed recipient,uint256 amount,uint256 gons)",
]);
const acquisition = z.object({
  acquisition: z.string(), originalWallet: z.string(), nativePrincipal: uint,
  originalOperationDivisor: uint, eligibleOriginalGons: uint,
  facets: z.array(z.object({ code: z.string(), codeHash: z.string(), facet: z.string() })),
}).passthrough().parse(await json(join(runtime, "weighted-receipt-acquisition.json")));
assert.equal(acquisition.nativePrincipal, 101n);
assert.equal(acquisition.eligibleOriginalGons, 101n * acquisition.originalOperationDivisor);
for (const facet of acquisition.facets) {
  assert.equal(keccak256(facet.code), facet.codeHash);
  assert.equal(facet.codeHash, "0xcb505aba37d6ad909d8fb33dbf0091be50c9dd37f43e5df506bd240fc711b361");
  assert.equal(facet.facet, "0xb7581fe833a2b2380dd786b345d61ffb734d36eb");
}
const acquired = signatures.get(acquisition.acquisition);
assert(acquired);
const acquisitionTx = Transaction.from(acquired.raw);
assert.equal(acquisitionTx.from?.toLowerCase(), acquisition.originalWallet);
const acquiredEvent = acquired.receipt.logs.map((l) => oldEvents.parseLog(l)).find((e) => e?.name === "Staked");
assert(acquiredEvent);
assert.equal(acquiredEvent.args[2], 101n);
assert.equal(acquiredEvent.args[3], acquisition.eligibleOriginalGons);
const input = preparationInput.parse(await json(join(runtime, "replacement-input.json")));
const original = input.weightedReceipt[0]?.original;
assert(original);
const sources = [];
for (const source of input.sources) {
  const raw = await readFile(source.path);
  assert.equal(raw.byteLength.toString(), source.bytes);
  assert.equal(createHash("sha256").update(raw).digest("hex"), source.sha256);
  sources.push({ id: source.id, path: source.path, bytes: raw.byteLength, sha256: source.sha256 });
}
const stage1 = z.object({ credit: uint }).passthrough().parse(await json(join(runtime, "weighted-receipt-stage1.json")));
assert.equal(BigInt(original.originalUnits), acquisition.eligibleOriginalGons);
const parameter = allocation.getFunction("configureWeightedReceiptEntitlements")?.inputs[0]?.arrayChildren;
assert(parameter);
const configuration = keccak256(AbiCoder.defaultAbiCoder().encode(
  ["uint256", "address", "bytes32", parameter], [4663, input.domain.proxy, input.domain.snapshotId, original]));
let current = [0n, 0n, acquisition.eligibleOriginalGons, stage1.credit];
const verified = [];
const failures = [];
for (const phase of ["stage1", "partial", "residual"]) {
  const negatives = z.object({
    rejects: z.array(z.object({ transactionHash: z.string(), before: z.string(), after: z.string() }).passthrough()),
  }).passthrough().parse(await json(join(runtime, `weighted-receipt-${phase}.json`)));
  for (const n of negatives.rejects) {
    const raw = signatures.get(n.transactionHash);
    assert(raw);
    assert.equal(BigInt(raw.receipt.status), 0n);
    assert.equal(raw.receipt.logs.length, 0);
    assert.equal(n.before, n.after);
    failures.push({ phase, transactionHash: n.transactionHash, economicState: JSON.parse(n.before) });
  }
  if (phase === "stage1") continue;
  const row = z.object({
    transactionHash: z.string(), configurationId: z.string(), nativeAmount: uint, divisor: uint,
    bondTokenId: uint, credit: uint, eligibleGons: uint,
    observed: z.object({
      originalGonsBefore: uint, originalGonsAfter: uint, custodyGonsBefore: uint, custodyGonsAfter: uint,
      bookedGonsBefore: uint, bookedGonsAfter: uint, newSupplyBefore: uint, newSupplyAfter: uint,
      newStakingBackingBefore: uint, newStakingBackingAfter: uint,
      parentBondAllowance: uint, bondStakingAllowance: uint,
      sourceStateBefore: state7, sourceStateAfter: state7, newStakingStateAfter: state7,
      surrenderBefore: state4, surrenderAfter: state4, bondPosition: position5,
      block: z.object({ hash: z.string(), number: z.string(), timestamp: z.string() }).passthrough(),
    }),
  }).passthrough().parse(await json(join(runtime, `weighted-receipt-${phase}.json`)));
  const raw = signatures.get(row.transactionHash);
  assert(raw);
  const tx = Transaction.from(raw.raw);
  const call = abi.decodeFunctionData("surrenderMigrationWeightedReceipt", tx.data);
  assert.equal(tx.from?.toLowerCase(), original.originalWallet);
  assert.equal(tx.to?.toLowerCase(), input.domain.proxy);
  assert.equal(call[0], original.originalId);
  assert.equal(call[1], row.nativeAmount);
  assert.equal(call[2], 1n);
  const o = row.observed;
  const q = row.nativeAmount * row.divisor;
  const Q = o.surrenderBefore[2], C = o.surrenderBefore[3];
  assert(q > 0n && q <= Q);
  const credit = q === Q ? C : C * q / Q;
  assert(credit > 0n);
  assert.deepEqual(o.surrenderBefore, current);
  current = [o.surrenderBefore[0] + q, o.surrenderBefore[1] + credit, Q - q, C - credit];
  assert.deepEqual(o.surrenderAfter, current);
  assert.equal(row.configurationId, configuration);
  assert.equal(row.credit, credit);
  assert.equal(row.eligibleGons, q);
  assert.equal(o.originalGonsBefore - o.originalGonsAfter, q);
  assert.equal(o.custodyGonsAfter - o.custodyGonsBefore, q);
  assert.equal(o.bookedGonsAfter - o.bookedGonsBefore, q);
  assert.equal(o.newSupplyAfter - o.newSupplyBefore, credit);
  assert.equal(o.newStakingBackingAfter - o.newStakingBackingBefore, credit);
  assert.equal(o.parentBondAllowance, 0n);
  assert.equal(o.bondStakingAllowance, 0n);
  assert.equal(o.sourceStateAfter[1], row.divisor);
  assert.equal(o.bondPosition[0], credit);
  assert.equal(o.bondPosition[1], 0n);
  assert.equal(o.bondPosition[2], credit * o.newStakingStateAfter[1]);
  assert.equal(o.bondPosition[3], BigInt(o.block.timestamp));
  assert.equal(o.bondPosition[4], 7776000n);
  assert.equal(o.block.hash, raw.receipt.blockHash);
  assert.equal(o.block.number, raw.receipt.blockNumber);
  const event = raw.receipt.logs.filter((l) => l.address === input.domain.proxy)
    .map((l) => abi.parseLog(l)).find((e) => e?.name === "MigrationWeightedReceiptSurrendered");
  assert(event);
  assert.deepEqual([...event.args].map((value, index) => index === 2 ? String(value).toLowerCase() : String(value)),
    [original.originalId, configuration, original.originalWallet,
    row.nativeAmount.toString(), q.toString(), row.divisor.toString(), credit.toString(), row.bondTokenId.toString()]);
  const pullIndex = raw.receipt.logs.findIndex((l) => l.address === original.source
    && l.topics[0] === id("Transfer(address,address,uint256)") && l.topics.length === 3
    && l.topics[1]?.slice(-40) === original.originalWallet.slice(2)
    && l.topics[2]?.slice(-40) === input.domain.proxy.slice(2) && BigInt(l.data) === row.nativeAmount);
  assert(pullIndex >= 0);
  const rewardIndex = raw.receipt.logs.findIndex((l) => l.address === original.source
    && l.topics[0] === id("RewardsFunded(uint256,uint256,uint256,uint256,uint256)"));
  if (phase === "partial") {
    assert(rewardIndex >= 0 && rewardIndex < pullIndex);
    const rewardLog = raw.receipt.logs[rewardIndex];
    assert(rewardLog);
    const reward = oldEvents.parseLog(rewardLog);
    assert(reward);
    const amount = z.bigint().parse(reward.args[0]);
    const [total, k0, backing, allocationDust, stakingDust, feeWeight, creatorWeight] = o.sourceStateBefore;
    const rps = (amount + allocationDust) * 10n ** 54n / (total + feeWeight + creatorWeight);
    const ordinary = total * rps / 10n ** 54n;
    const fee = feeWeight * rps / 10n ** 54n, creator = creatorWeight * rps / 10n ** 54n;
    const target = total / k0 + ordinary + stakingDust;
    const k = (total + target - 1n) / target;
    const growth = total / k - total / k0;
    assert.equal(reward.args[1], growth);
    assert.equal(reward.args[2], fee);
    assert.equal(reward.args[3], creator);
    assert.equal(reward.args[4], k);
    assert.deepEqual(o.sourceStateAfter, [total + (fee + creator) * k, k, backing + amount,
      amount + allocationDust - ordinary - fee - creator, ordinary + stakingDust - growth, feeWeight, creatorWeight]);
  }
  if (phase === "residual") assert(current[2] !== undefined && current[2] > 0n
    && current[2] < row.divisor && current[3] !== undefined && current[3] > 0n);
  verified.push({ phase, transactionHash: row.transactionHash, q: q.toString(), credit: credit.toString(),
    divisor: row.divisor.toString(), after: current.map(String), block: o.block, pullIndex, rewardIndex });
}
await writeFile(join(here, "economics.json"), JSON.stringify({
  runtime, configuration, sources, acquisition: { transactionHash: acquisition.acquisition,
    originalGons: acquisition.eligibleOriginalGons.toString(), originalDivisor: acquisition.originalOperationDivisor.toString() },
  originalCredit: stage1.credit.toString(), verified, failures,
  residualGons: current[2]?.toString(), residualCredit: current[3]?.toString(),
}, null, 2) + "\n", { flag: "wx" });
console.log("ECONOMICS_CONFIRMED actual acquisition, guarded reward arithmetic, signed custody, credit, fresh cliffs, residual and failures");
