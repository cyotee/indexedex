import { Interface } from "ethers";
import { z } from "zod";
import { address, hex, PreparationError } from "./schema.js";
import type { ClaimedSyCertificate } from "./schema.js";
import { stakingClaim, stakingSource, claimBookFacets } from "./claimed-sy-source.js";

export const claimWitness = new Interface([
  "function witness(address wallet,bytes data) returns(uint256[7] beforeBooks,uint256[7] afterBooks)",
]);
export const claimFrame = z.object({
  from: address, to: address, input: hex, output: hex.default("0x"), type: z.string(),
  error: z.string().optional(), calls: z.array(z.unknown()).default([]),
}).passthrough();
export type ClaimFrame = z.infer<typeof claimFrame>;
export type ClaimBooks = {
  readonly weight: bigint; readonly supply: bigint; readonly shares: bigint; readonly vaultSupply: bigint;
  readonly sy: bigint; readonly vaultSy: bigint; readonly sySupply: bigint;
};
export class ClaimedSyEvidenceError extends PreparationError {
  constructor(readonly reason: "AUTHENTICATION" | "TRACE_FAILED" | "TRACE_AMBIGUOUS" | "WITNESS_SHAPE" | "EFFECTS" | "STATE_UNAVAILABLE",
    message: string) { super("PROVENANCE", `claimed SY: ${message}`); }
}
export function requireClaimEvidence(valid: boolean, message: string,
  reason: ClaimedSyEvidenceError["reason"] = "AUTHENTICATION"): asserts valid {
  if (!valid) throw new ClaimedSyEvidenceError(reason, message);
}
export function claimFrames(raw: unknown): ClaimFrame[] {
  const found: ClaimFrame[] = [];
  const pending: unknown[] = [raw];
  while (pending.length) {
    const frame = claimFrame.parse(pending.pop());
    requireClaimEvidence(frame.error === undefined, "failed source trace", "TRACE_FAILED");
    found.push(frame);
    // Preserve execution order, including calls which returned zero.
    pending.push(...[...frame.calls].reverse());
  }
  return found;
}

export function claimBookReads(wallet: string) {
  const vault = "0xaf5c0cd3fdedd10bee00eff77fa0429bacdb41f0";
  const sy = "0xb55604cf4dcdabb362078e106d20f98512391edf";
  return [
    ["weight", stakingSource, "balanceOf", [wallet]],
    ["supply", stakingSource, "totalSupply", []],
    ["shares", vault, "balanceOf", [stakingSource]],
    ["vaultSupply", vault, "totalSupply", []],
    ["sy", sy, "balanceOf", [wallet]],
    ["vaultSy", sy, "balanceOf", [vault]],
    ["sySupply", sy, "totalSupply", []],
  ] as const;
}

/**
 * Consume only the selected RPC's complete callTracer tree, never certificate-supplied books.
 * The outer execution has exactly seven STATICCALLs, one complete wallet CALL, seven STATICCALLs.
 * SSTORE/LOG in the router cannot change another account's books; any CALL/DELEGATECALL/CREATE
 * outside that bracket adds a frame and is rejected. The inner call may be adversarial:
 * its net effects, not merely its source event, must satisfy the economic checks.
 */
export function witnessedClaimBooks(root: ClaimFrame, wallet: string) {
  const calls = root.calls.map((raw) => claimFrame.parse(raw));
  const inner = calls[7];
  requireClaimEvidence(calls.length === 15 && inner?.type === "CALL"
    && inner.from === root.to && inner.to === wallet, "witness does not bracket the complete wallet call", "WITNESS_SHAPE");
  requireClaimEvidence(root.input === claimWitness.encodeFunctionData("witness", [wallet, inner.input]),
    "witness calldata wallet differs", "WITNESS_SHAPE");
  const reads = claimBookReads(wallet);
  const books = (offset: number): ClaimBooks => {
    const values = { weight: 0n, supply: 0n, shares: 0n, vaultSupply: 0n, sy: 0n, vaultSy: 0n, sySupply: 0n };
    for (const [index, [key, target, method, args]] of reads.entries()) {
      const call = calls[offset + index];
      requireClaimEvidence(call?.type === "STATICCALL" && call.from === root.to && call.to === target
        && call.input === stakingClaim.encodeFunctionData(method, args) && call.output.length === 66,
      "transaction-local book read differs", "WITNESS_SHAPE");
      const delegated = call.calls.map((raw) => claimFrame.parse(raw));
      const leaf = delegated[0];
      requireClaimEvidence(delegated.length === 1 && leaf?.type === "DELEGATECALL"
        && leaf.from === target && leaf.to === claimBookFacets[target] && leaf.input === call.input && leaf.output === call.output
        && leaf.calls.length === 0, "transaction-local book implementation differs", "WITNESS_SHAPE");
      values[key] = z.bigint().parse(stakingClaim.decodeFunctionResult(method, call.output)[0]);
    }
    return values;
  };
  return { before: books(0), after: books(8) };
}

export function checkClaimEffects(books: { readonly before: ClaimBooks; readonly after: ClaimBooks },
  member: ClaimedSyCertificate["members"][number], review: ClaimedSyCertificate["review"]) {
  const { before, after } = books;
  requireClaimEvidence(before.weight - after.weight === BigInt(member.consumedWeight)
    && before.supply - after.supply === BigInt(member.consumedWeight)
    && before.shares - after.shares === BigInt(member.redeemedVaultShares)
    && before.vaultSupply - after.vaultSupply === BigInt(member.redeemedVaultShares)
    && after.sy - before.sy === BigInt(member.receivedSy)
    && before.vaultSy - after.vaultSy === BigInt(member.receivedSy)
    && before.sySupply === after.sySupply, "actual source weight vault or measured SY delta differs", "EFFECTS");
  requireClaimEvidence(after.weight >= BigInt(review.unrelatedWeightFloor)
    && before.sy >= BigInt(review.unrelatedSyFloor), "excluded unrelated budget was consumed", "EFFECTS");
}
