import { readFile, writeFile } from "node:fs/promises";
import { resolve, join } from "node:path";
import { Transaction } from "ethers";
import { z } from "zod";
import { interfaceFile } from "../../../../../../scripts/recovery/dtf-migration/rehearsal-data.js";
import { canonical } from "../../../../../../scripts/recovery/dtf-migration/provenance.js";
import { legacyAbi } from "../../../../../../scripts/recovery/dtf-migration/rehearsal-chain.js";

const runtime = resolve(z.string().parse(process.argv[2]));
const output = resolve(z.string().parse(process.argv[3]));
const json = async (path: string): Promise<unknown> => JSON.parse(await readFile(path, "utf8"));
const uint = z.string().regex(/^\d+$/).transform(BigInt);
const abi = await interfaceFile("out/IUniswapV4DetfMigration.sol/IUniswapV4DetfMigration.json");
const kIndex = legacyAbi.getFunction("stakingState")?.outputs[0]?.components
  ?.findIndex((field) => field.name === "gonsPerUnit");
if (kIndex === undefined || kIndex < 0) throw new Error("seven-word State divisor ABI field missing");
const stage1 = z.object({
  original: z.object({ originalId: z.string(), originalWallet: z.string(), originalUnits: uint }),
  credit: uint,
}).passthrough().parse(await json(join(runtime, "weighted-receipt-stage1.json")));
const acquisition = z.object({
  eligibleOriginalGons: uint, nativePrincipal: uint, originalOperationDivisor: uint,
}).passthrough().parse(await json(join(runtime, "weighted-receipt-acquisition.json")));
if (acquisition.eligibleOriginalGons !== acquisition.nativePrincipal * acquisition.originalOperationDivisor
  || stage1.original.originalUnits !== acquisition.eligibleOriginalGons) throw new Error("original acquisition gons differ");
const signedAudit = z.object({ wsSigned: z.array(z.object({ path: z.string() }).passthrough()) })
  .passthrough().parse(await json(join(output, "signed-receipt-audit.json")));
const rawSigned = await Promise.all(signedAudit.wsSigned.map(async (row) => z.object({
  raw: z.string(), transactionHash: z.string(), receipt: z.object({
    transactionHash: z.string(), blockHash: z.string(), blockNumber: z.string(), status: z.string(),
    logs: z.array(z.object({ address: z.string(), topics: z.array(z.string()), data: z.string() }).passthrough()),
  }).passthrough(),
}).passthrough().parse(await json(row.path))));
let previous = [0n, 0n, stage1.original.originalUnits, stage1.credit];
const verified = [];
for (const phase of ["partial", "residual"]) {
  const row = z.object({
    original: z.object({ originalId: z.string(), originalWallet: z.string(), originalUnits: uint }),
    transactionHash: z.string(), configurationId: z.string(), nativeAmount: uint,
    eligibleGons: uint, divisor: uint, credit: uint, bondTokenId: uint,
    observed: z.object({
      originalGonsBefore: uint, originalGonsAfter: uint, custodyGonsBefore: uint, custodyGonsAfter: uint,
      bookedGonsBefore: uint, bookedGonsAfter: uint, newSupplyBefore: uint, newSupplyAfter: uint,
      newStakingBackingBefore: uint, newStakingBackingAfter: uint, parentBondAllowance: uint, bondStakingAllowance: uint,
      sourceStateBefore: z.array(uint).length(7), sourceStateAfter: z.array(uint).length(7),
      newStakingStateAfter: z.array(uint).length(7), surrenderBefore: z.array(uint).length(4),
      surrenderAfter: z.array(uint).length(4), bondPosition: z.array(uint).length(5),
      block: z.object({ hash: z.string(), number: z.string(), timestamp: z.string() }).passthrough(),
    }),
  }).passthrough().parse(await json(join(runtime, `weighted-receipt-${phase}.json`)));
  const raw = rawSigned.find((s) => s.transactionHash === row.transactionHash);
  if (!raw || BigInt(raw.receipt.status) !== 1n) throw new Error("positive signed WS receipt missing");
  const tx = Transaction.from(raw.raw);
  const call = abi.decodeFunctionData("surrenderMigrationWeightedReceipt", tx.data);
  const event = raw.receipt.logs.filter((l) => l.address.toLowerCase() === tx.to?.toLowerCase())
    .map((l) => abi.parseLog({ topics: l.topics, data: l.data }))
    .find((l) => l?.name === "MigrationWeightedReceiptSurrendered");
  const o = row.observed;
  const q = row.nativeAmount * row.divisor;
  const Q = o.surrenderBefore[2];
  const C = o.surrenderBefore[3];
  if (Q === undefined || C === undefined || q <= 0n || q > Q) throw new Error("nonpositive or excess raw gon surrender");
  const credit = q === Q ? C : C * q / Q;
  if (!event || event.args[0] !== stage1.original.originalId || event.args[1] !== row.configurationId
    || String(event.args[2]).toLowerCase() !== stage1.original.originalWallet || event.args[3] !== row.nativeAmount
    || event.args[4] !== q || event.args[5] !== row.divisor || event.args[6] !== credit || event.args[7] !== row.bondTokenId
    || call[0] !== stage1.original.originalId || call[1] !== row.nativeAmount || call[2] !== 1n
    || tx.from?.toLowerCase() !== stage1.original.originalWallet || row.eligibleGons !== q || row.credit !== credit
    || credit <= 0n || o.originalGonsBefore - o.originalGonsAfter !== q
    || o.custodyGonsAfter - o.custodyGonsBefore !== q || o.bookedGonsAfter - o.bookedGonsBefore !== q
    || o.newSupplyAfter - o.newSupplyBefore !== credit || o.newStakingBackingAfter - o.newStakingBackingBefore !== credit
    || o.parentBondAllowance !== 0n || o.bondStakingAllowance !== 0n
    || o.sourceStateAfter[kIndex] !== row.divisor || o.bondPosition[0] !== credit || o.bondPosition[1] !== 0n
    || o.bondPosition[2] !== credit * z.bigint().parse(o.newStakingStateAfter[kIndex])
    || o.bondPosition[3] !== BigInt(o.block.timestamp) || o.bondPosition[4] !== 7776000n
    || o.block.hash !== raw.receipt.blockHash || o.block.number !== raw.receipt.blockNumber
    || o.surrenderBefore.some((v, i) => v !== previous[i])) throw new Error("raw signed custody, issuance or cliff identity differs");
  const expectedAfter = [z.bigint().parse(previous[0]) + q, z.bigint().parse(previous[1]) + credit, Q - q, C - credit];
  if (o.surrenderAfter.some((v, i) => v !== expectedAfter[i])) throw new Error("immutable original credit recurrence differs");
  previous = expectedAfter;
  verified.push({ phase, transactionHash: row.transactionHash, nativeAmount: String(row.nativeAmount),
    eligibleGons: String(q), divisor: String(row.divisor), credit: String(credit), block: o.block,
    before: o.surrenderBefore.map(String), after: o.surrenderAfter.map(String), exactCustody: true,
    exactFreshBackingAndClearedAllowances: true, exactCliff: true, roleAndRewardGonsNotRepriced: true });
  if (phase === "residual" && (Q - q <= 0n || Q - q >= row.divisor || C - credit <= 0n)) {
    throw new Error("positive nonrepresentable residual was not retained");
  }
}
await writeFile(join(output, "raw-custody-credit-cliff-audit.json"), `${canonical({
  verified, originalGons: String(acquisition.eligibleOriginalGons), originalCredit: String(stage1.credit),
  residualGons: String(previous[2]), residualCredit: String(previous[3]), futureRepresentabilityPromised: false,
})}\n`, { flag: "wx" });
console.log("RAW_SIGNED_CUSTODY_CREDIT_FRESH_CLIFF_AND_RESIDUAL_CONFIRMED");
