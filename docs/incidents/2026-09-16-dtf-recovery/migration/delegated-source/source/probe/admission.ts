import { Transaction } from "ethers";
import { z } from "zod";
import { abi, check, frameSchema, T, V, Y } from "./common.js";
import type { capture } from "./common.js";

export type Captured = Awaited<ReturnType<typeof capture>>;
export type Book = {
  readonly weight: bigint; readonly weightSupply: bigint; readonly shares: bigint;
  readonly vaultSupply: bigint; readonly walletSy: bigint; readonly vaultSy: bigint;
  readonly sySupply: bigint; readonly custodySy: bigint; readonly allowance: bigint;
  readonly booked: bigint; readonly rewards: bigint; readonly donorWeight: bigint;
  readonly relayerSy: bigint; readonly walletShares: bigint;
};
export type Member = {
  readonly wallet: string; readonly weight: bigint; readonly before: Book;
  readonly after: Book; readonly captured: Captured;
};
export function frames(raw: unknown) {
  const result: { frame: z.infer<typeof frameSchema>; path: readonly number[]; committed: boolean }[] = [];
  const visit = (item: unknown, path: readonly number[], parentSuccess: boolean): void => {
    const frame = frameSchema.parse(item);
    const committed = parentSuccess && frame.error === undefined;
    result.push({ frame, path, committed });
    frame.calls.forEach((child, i) => visit(child, [...path, i], committed));
  };
  visit(raw, [], true);
  return result;
}

/** Proposal oracle for the controlled isolated-block domain, NOT production intake. */
export function admitMember(member: Member) {
  const { captured: c, wallet, weight, before: b, after: a } = member;
  check(c.raw, "original controlled raw transaction required by local oracle");
  const signed = Transaction.from(c.raw);
  check(signed.isSigned() && signed.hash === c.transaction.hash
    && signed.from?.toLowerCase() === c.transaction.from && signed.chainId === 4663n
    && signed.to?.toLowerCase() === c.transaction.to && signed.data === c.transaction.input
    && signed.value === BigInt(c.transaction.value)
    && signed.nonce === Number(BigInt(c.transaction.nonce)), "signed body changed");
  check(c.receipt.status === "0x1" && c.receipt.transactionHash === signed.hash
    && c.receipt.from === c.transaction.from && c.receipt.to === c.transaction.to
    && c.receipt.blockHash === c.block.hash && c.transaction.blockHash === c.block.hash
    && c.receipt.blockNumber === c.block.number && c.transaction.blockNumber === c.block.number
    && c.receipt.transactionIndex === "0x0" && c.transaction.transactionIndex === "0x0"
    && c.block.transactions.length === 1 && c.block.transactions[0] === signed.hash,
  "failed, changed or nonisolated receipt/block");
  check(c.trace.from === c.transaction.from && c.trace.to === c.transaction.to
    && c.trace.input === c.transaction.input, "outer trace body changed");
  for (const l of c.receipt.logs) check(l.transactionHash === signed.hash && l.blockHash === c.block.hash
    && l.blockNumber === c.block.number && l.transactionIndex === "0x0", "changed log identity");
  const all = frames(c.trace);
  const attempts = all.filter(({ frame: f }) => f.type === "CALL" && f.to === T
    && f.input.startsWith("0xa224dcb7"));
  check(attempts.length === 1, "ambiguous or absent source invocation");
  const source = attempts[0];
  check(source?.committed && source.frame.from === wallet
    && source.frame.input === abi.encodeFunctionData("withdrawClaim", [weight]), "wrong/failed actual source caller or weight");
  const received = z.bigint().parse(abi.decodeFunctionResult("withdrawClaim", source.frame.output)[0]);
  const shares = b.shares - a.shares;
  const within = all.filter(row => row.path.length > source.path.length
    && source.path.every((v, i) => row.path[i] === v));
  const redeems = within.filter(({ frame: f, committed }) => committed && f.type === "CALL"
    && f.from === T && f.to === V && f.input === abi.encodeFunctionData("redeem", [shares, wallet, T])
    && f.output === source.frame.output);
  check(redeems.length === 1, "vault invocation/recipient/return mismatch");
  const decoded = c.receipt.logs.filter(l => [T, V, Y].includes(l.address))
    .map(l => ({ address: l.address, logIndex: l.logIndex, event: abi.parseLog(l) }));
  const claims = decoded.filter(l => l.address === T && l.event?.name === "ClaimWithdrawn");
  check(claims.length === 1 && claims[0]?.event?.args[0].toLowerCase() === wallet
    && claims[0]?.event?.args[1] === weight && claims[0]?.event?.args[2] === received, "canonical claim event mismatch");
  const burns = decoded.filter(l => l.address === V && l.event?.name === "Transfer");
  check(burns.length === 1 && burns[0]?.event?.args[0].toLowerCase() === T
    && burns[0]?.event?.args[1] === "0x0000000000000000000000000000000000000000"
    && burns[0]?.event?.args[2] === shares, "canonical share burn mismatch");
  const outputs = decoded.filter(l => l.address === Y && l.event?.name === "Transfer");
  check(outputs.length === 1 && outputs[0]?.event?.args[0].toLowerCase() === V
    && outputs[0]?.event?.args[1].toLowerCase() === wallet
    && outputs[0]?.event?.args[2] === received, "canonical SY output mismatch");
  const withdrawals = decoded.filter(l => l.address === V && l.event?.name === "Withdraw");
  check(withdrawals.length === 1 && withdrawals[0]?.event?.args[0].toLowerCase() === T
    && withdrawals[0]?.event?.args[1].toLowerCase() === wallet
    && withdrawals[0]?.event?.args[2].toLowerCase() === T
    && withdrawals[0]?.event?.args[3] === received && withdrawals[0]?.event?.args[4] === shares, "canonical vault withdraw mismatch");
  check(weight > 0n && b.weight - a.weight === weight && b.weightSupply - a.weightSupply === weight
    && b.vaultSupply - a.vaultSupply === shares && a.walletSy - b.walletSy === received
    && b.vaultSy - a.vaultSy === received && b.sySupply === a.sySupply
    && b.donorWeight === a.donorWeight && b.relayerSy === a.relayerSy
    && b.rewards === a.rewards && b.walletShares === a.walletShares
    && b.custodySy === a.custodySy && b.booked === a.booked, "measured state/conservation mismatch");
  check(shares === weight * b.shares / b.weightSupply, "observed native18-to-native19 floor mismatch");
  return { transactionHash: c.transaction.hash, sourcePath: source.path,
    sourceCaller: source.frame.from, outerCaller: c.transaction.from, weight, shares, received,
    weightRemainder: weight * b.shares % b.weightSupply,
    vaultFloor: shares * (b.vaultSy + 1n) / (b.vaultSupply + 10n ** 10n),
    vaultRemainder: shares * (b.vaultSy + 1n) % (b.vaultSupply + 10n ** 10n) };
}
export function complete(members: readonly Member[], expected: {
  readonly wallet: string; readonly w0: bigint; readonly q0: bigint;
}) {
  const admitted = members.map(admitMember);
  check(members.every(m => m.wallet === expected.wallet), "original wallet mismatch");
  check(new Set(admitted.map(m => m.transactionHash)).size === admitted.length, "duplicate source member");
  check(admitted.reduce((sum, m) => sum + m.weight, 0n) === expected.w0, "incomplete/excess W0 including zero output");
  check(expected.q0 > 0n && admitted.reduce((sum, m) => sum + m.received, 0n) === expected.q0,
    "measured Q0 excludes unrelated SY");
  return admitted;
}
