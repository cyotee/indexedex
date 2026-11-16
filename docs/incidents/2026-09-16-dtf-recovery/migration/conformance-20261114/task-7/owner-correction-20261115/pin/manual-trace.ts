import assert from "node:assert/strict";
import { claimFrame, claimFrames, claimWitness, witnessedClaimBooks, checkClaimEffects } from "../../../../../../../../scripts/recovery/dtf-migration/claimed-sy-witness.js";
import { stakingClaim, stakingSource, claimBookFacets } from "../../../../../../../../scripts/recovery/dtf-migration/claimed-sy-source.js";

const wallet = "0x0000000000000000000000000000000000000001";
const router = "0x0000000000000000000000000000000000000002";
const vault = "0xaf5c0cd3fdedd10bee00eff77fa0429bacdb41f0";
const sy = "0xb55604cf4dcdabb362078e106d20f98512391edf";
const before = { weight: 17n, supply: 100n, shares: 300n, vaultSupply: 400n, sy: 5n, vaultSy: 80n, sySupply: 90n };
const after = { weight: 7n, supply: 90n, shares: 270n, vaultSupply: 370n, sy: 8n, vaultSy: 77n, sySupply: 90n };
const member = { transactionHash: "0x", blockNumber: "12", blockHash: "0x", rawSignedTransaction: "0x",
  consumedWeight: "10", redeemedVaultShares: "30", receivedSy: "3" };
const review = {
  authority: "offline operator proof",
  originalId: "0x",
  originalWallet: wallet,
  originalEth: "0",
  originalDtf: "0",
  eligibleWeight: "10",
  priorDeliveredCredit: "0",
  contributionsKnown: true,
  eligiblePrincipalOnly: true,
  rewardsExcluded: true,
  aliasesReconciled: true,
  competingRepresentationsExcluded: true,
  unrelatedWeightFloor: "7",
  unrelatedSyFloor: "5",
} as const;
const requests = [
  [stakingSource, "balanceOf", [wallet]], [stakingSource, "totalSupply", []],
  [vault, "balanceOf", [stakingSource]], [vault, "totalSupply", []],
  [sy, "balanceOf", [wallet]], [sy, "balanceOf", [vault]], [sy, "totalSupply", []],
] as const;

function wireWitness() {
  const reads = (values: readonly bigint[]) => requests.map(([to, method, args], index) => ({
    type: "STATICCALL",
    from: router,
    to,
    input: stakingClaim.encodeFunctionData(method, args),
    output: stakingClaim.encodeFunctionResult(method, [values[index]]),
    calls: [{
      type: "DELEGATECALL",
      from: to,
      to: claimBookFacets[to],
      input: stakingClaim.encodeFunctionData(method, args),
      output: stakingClaim.encodeFunctionResult(method, [values[index]]),
      calls: [],
    }],
  }));
  const inner = { type: "CALL", from: router, to: wallet, input: "0x12345678", output: "0x", calls: [] };
  return claimFrame.parse({
    type: "CALL",
    from: "0x0000000000000000000000000000000000000009",
    to: router,
    input: claimWitness.encodeFunctionData("witness", [wallet, inner.input]),
    output: "0x",
    calls: [...reads([17n, 100n, 300n, 400n, 5n, 80n, 90n]), inner,
      ...reads([7n, 90n, 270n, 370n, 8n, 77n, 90n])],
  });
}

const root = wireWitness();
const books = witnessedClaimBooks(root, wallet);
assert.deepEqual(books, { before, after });
checkClaimEffects(books, member, review);

const tampered = claimFrame.parse({
  ...root,
  calls: root.calls.map((call, index) => index === 0
    ? { ...claimFrame.parse(call), type: "CALL" }
    : call),
});
assert.throws(() => witnessedClaimBooks(tampered, wallet), { reason: "WITNESS_SHAPE" });

const failedInner = claimFrame.parse({
  ...root,
  calls: root.calls.map((call, index) => index === 7
    ? { ...claimFrame.parse(call), calls: [{ ...claimFrame.parse(call), error: "execution reverted" }] }
    : call),
});
assert.throws(() => {
  claimFrames(failedInner);
}, { reason: "TRACE_FAILED" });

console.log(JSON.stringify({
  proof: "offline operator proof; not an EVM execution",
  before: Object.fromEntries(Object.entries(books.before).map(([key, value]) => [key, String(value)])),
  after: Object.fromEntries(Object.entries(books.after).map(([key, value]) => [key, String(value)])),
  tamperedCallOrder: "rejected: WITNESS_SHAPE",
  caughtInnerFailure: "rejected: TRACE_FAILED",
  artifactOrPinLoaded: false,
}, null, 2));
