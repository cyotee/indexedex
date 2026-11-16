import { mkdir } from "node:fs/promises";
import { join, resolve } from "node:path";
import { Rpc, check, save, wallet, signed, qty, hex, abi, T, Y, json } from "./common.js";
import { book, identities, probeAbi } from "./chain.js";
import { setup, FULL, SPLIT, WRONG, W0, UNRELATED_WEIGHT } from "./setup.js";
import { admitMember, complete, frames } from "./admission.js";
import type { Member } from "./admission.js";

const output = resolve(process.argv[2] ?? "");
check(output.startsWith(resolve(import.meta.dirname, "..") + "/run-"), "new owned run directory required");
await mkdir(output, { recursive: false });
const rpc = new Rpc(new URL("http://127.0.0.1:18579/"), join(output, "wire"));
const fixture = await setup(rpc, output);
const operations: { label: string; member: Member }[] = [];
const operation = async (label: string, request: {
  readonly walletIndex: number; readonly signerIndex: number; readonly to: string;
  readonly data: string; readonly weight: bigint;
}) => {
  const claimant = wallet(request.walletIndex).address.toLowerCase();
  const captured = await signed(rpc, request.signerIndex, { to: request.to, data: request.data });
  const priorTag = captured.prior.number, tag = captured.block.number;
  const before = await book(rpc, claimant, fixture.custody, priorTag);
  const after = await book(rpc, claimant, fixture.custody, tag);
  const member: Member = { wallet: claimant, weight: request.weight, before, after, captured,
    delegation: { delegate: fixture.delegate, runtime: fixture.runtime, runtimeHash: fixture.runtimeHash,
      beforeCode: hex.parse(await rpc.send("eth_getCode", [claimant, priorTag])),
      afterCode: hex.parse(await rpc.send("eth_getCode", [claimant, tag])),
      afterRuntime: hex.parse(await rpc.send("eth_getCode", [fixture.delegate, tag])),
      relayer: wallet(0).address.toLowerCase() } };
  await save(join(output, `${label}.json`), member);
  operations.push({ label, member });
  return member;
};
const relayed = (method: string, args: readonly unknown[], index = SPLIT) => ({
  walletIndex: index, signerIndex: 0, to: wallet(index).address,
  data: probeAbi.encodeFunctionData(method, args), weight: 1n,
});
const unchanged = (m: Member) => check(json(m.before) === json(m.after), "economic rollback differs");
const wrong = await operation("wrong-caller", { ...relayed("claim", [W0], FULL), signerIndex: WRONG, weight: W0 });
check(wrong.captured.receipt.status === "0x0", "wrong caller succeeded");
unchanged(wrong);
const caught = await operation("outer-success-inner-failed", { ...relayed("catchClaim", [W0 * 10n]), weight: W0 * 10n });
check(caught.captured.receipt.status === "0x1" && frames(caught.captured.trace)
  .some(r => r.frame.to === T && r.frame.type === "CALL" && r.frame.error !== undefined),
  "failed inner source must be actually executed");
unchanged(caught);
const rolled = await operation("source-success-outer-revert", { ...relayed("claimThenRevert", [10n ** 18n]), weight: 10n ** 18n });
check(rolled.captured.receipt.status === "0x0" && rolled.captured.receipt.logs.length === 0
  && frames(rolled.captured.trace).some(r => r.frame.to === T && r.frame.type === "CALL"
    && r.frame.error === undefined && r.frame.output !== "0x" && !r.committed), "late source revert not exercised");
unchanged(rolled);
const multi = await operation("multiple-source-calls", { ...relayed("doubleClaim", [1n, 1n]), weight: 2n });
check(multi.captured.receipt.status === "0x1" && multi.before.weight - multi.after.weight === 2n
  && multi.after.walletSy === multi.before.walletSy, "actual extra two zero-output calls");
const wrongSource = await operation("wrong-source", {
  walletIndex: FULL, signerIndex: FULL, to: Y, data: abi.encodeFunctionData("withdrawClaim", [W0]), weight: W0,
});
check(wrongSource.captured.receipt.status === "0x0", "wrong source succeeded");
unchanged(wrongSource);
const full = await operation("eligible-full-direct", {
  walletIndex: FULL, signerIndex: FULL, to: T, data: abi.encodeFunctionData("withdrawClaim", [W0]), weight: W0,
});
const split: Member[] = [];
for (const [label, weight] of [["eligible-split-first", 3337000000000000000005n],
  ["eligible-split-zero", 1n], ["eligible-split-final", 6676000000000000000011n]] as const) {
  split.push(await operation(label, { ...relayed("claim", [weight]), weight }));
}
const fullResult = admitMember(full), splitResult = split.map(admitMember);
const q0 = splitResult.reduce((sum, r) => sum + r.received, 0n);
check(splitResult[1]?.received === 0n && splitResult[1]?.shares === 0n, "committed zero member");
const completeFull = { wallet: fixture.full, w0: W0, q0: fullResult.received, weightFloor: UNRELATED_WEIGHT, syFloor: 100n };
const completeSplit = { wallet: fixture.split, w0: W0, q0, weightFloor: UNRELATED_WEIGHT, syFloor: 101n };
complete([full], completeFull);
complete(split, completeSplit);
await save(join(output, "admitted.json"), { full: fullResult, split: splitResult, completeFull, completeSplit,
  originalWeightForRemainingExample: 3n * W0,
  eligibleWeightForRemainingExample: W0,
  qualification: "Only measured source quantities. Full quote C0 is not evaluated; eligible credit would be floor(C0/3) for the synthetic remaining example." });
console.log("CLAIMS_COMPLETE", fullResult.received.toString(), q0.toString(), "zero-member-included");

const custodyResults = [];
for (const [index, eligible, floor] of [[FULL, fullResult.received, 100n], [SPLIT, q0, 101n]] as const) {
  const claimant = wallet(index).address.toLowerCase();
  const approval = await signed(rpc, index, { to: Y, data: abi.encodeFunctionData("approve", [fixture.custody, eligible]) });
  check(approval.receipt.status === "0x1", "actual direct delegated EOA approval");
  const amount = eligible / 3n;
  const nonceBefore = qty.parse(await rpc.send("eth_getTransactionCount", [claimant, "latest"]));
  const late = await operation(`custody-late-failure-${index}`, {
    ...relayed("take", [amount, true], index), signerIndex: index, weight: 0n,
  });
  unchanged(late);
  const transferData = abi.encodeFunctionData("transferFrom", [claimant, fixture.custody, amount]);
  const successfulTransfer = frames(late.captured.trace).find(r => r.frame.type === "CALL" && r.frame.to === Y
    && r.frame.from === fixture.custody && r.frame.input === transferData && r.frame.error === undefined);
  check(late.captured.receipt.status === "0x0" && late.captured.receipt.logs.length === 0
    && successfulTransfer && !successfulTransfer.committed
    && abi.decodeFunctionResult("transferFrom", successfulTransfer.frame.output)[0] === true,
    "late custody must follow actual successful inner transfer");
  const nonceAfter = qty.parse(await rpc.send("eth_getTransactionCount", [claimant, "latest"]));
  check(BigInt(nonceAfter) === BigInt(nonceBefore) + 1n && late.after.weight === UNRELATED_WEIGHT,
    "nonce advances; prior raw claim does not return");
  for (const [part, quantity] of [["partial", amount], ["terminal", eligible - amount]] as const) {
    const result = await operation(`custody-${part}-${index}`, {
      ...relayed("take", [quantity, false], index), signerIndex: index, weight: 0n,
    });
    check(result.captured.receipt.status === "0x1"
      && result.before.walletSy - result.after.walletSy === quantity
      && result.after.custodySy - result.before.custodySy === quantity
      && result.after.booked - result.before.booked === quantity
      && result.after.weight === UNRELATED_WEIGHT && result.before.weightSupply === result.after.weightSupply
      && result.before.shares === result.after.shares && result.before.sySupply === result.after.sySupply
      && result.before.relayerSy === result.after.relayerSy, "measured custody conservation");
  }
  const final = await book(rpc, claimant, fixture.custody);
  check(final.walletSy === floor && final.booked === eligible && final.allowance === 0n,
    "terminal custody preserves excluded SY");
  custodyResults.push({ claimant, eligible, floor, final, nonceBefore, nonceAfter,
    lateFailure: late.captured.transaction.hash });
}
await save(join(output, "custody.json"), custodyResults);
const callbackData = probeAbi.encodeFunctionData("onERC721Received", [wallet(0).address,
  "0x0000000000000000000000000000000000000000", 3n, "0x"]);
const receiverAccepted = await signed(rpc, 0, { to: fixture.full, data: callbackData });
check(receiverAccepted.receipt.status === "0x1"
  && probeAbi.decodeFunctionResult("onERC721Received", receiverAccepted.trace.output)[0] === "0x150b7a02",
  "delegated receiver callback");
check((await signed(rpc, FULL, { to: fixture.full, data: probeAbi.encodeFunctionData("setRejectReceipt", [true]) }))
  .receipt.status === "0x1", "receiver control");
const receiverRejected = await signed(rpc, 0, { to: fixture.full, data: callbackData });
check(receiverRejected.receipt.status === "0x0" && receiverRejected.receipt.logs.length === 0, "receiver rejection");
await save(join(output, "receiver.json"), { accepted: receiverAccepted, rejected: receiverRejected,
  qualification: "Actual delegate callback only. No NFT mint, Migration deployment or funded bond integration claimed." });
const finalBindings = await identities(rpc);
check(json(finalBindings) === json(fixture.bindings), "fixed source bindings changed");
await save(join(output, "source-bindings-after.json"), finalBindings);
await save(join(output, "operations.json"), operations);
await save(join(output, "complete.json"), { result: "bounded-local-source-proof",
  full: completeFull, split: completeSplit, operations: operations.length,
  historicalTraceRetried: false, migrationAward: false, pendingImpersonations: false });
console.log("PROOF_COMPLETE", operations.length, "source-only");
