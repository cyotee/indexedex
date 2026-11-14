import { Interface, keccak256 } from "ethers";
import { readFile } from "node:fs/promises";
import { join } from "node:path";
import { z } from "zod";
import { claimedSigned, claimedWallet } from "./rehearsal-claimed-sy-source.js";
import { surroundedClaim } from "./rehearsal-claimed-sy-witness.js";
import { stakingClaim, stakingSource } from "./claimed-sy-source.js";
import { claimFrames } from "./claimed-sy-witness.js";
import { transactionClaimBooks } from "./claimed-sy-state.js";
import { address, claimedSyCertificate, hex } from "./schema.js";
import { ExecutionError, quantity } from "./execution-schema.js";
import type { RehearsalChain } from "./rehearsal-chain.js";
import { fingerprint } from "./provenance.js";
import { save } from "./rehearsal-data.js";

/** The router makes no book reads: this exercises the historical execution shape, not retroactive instrumentation. */
export async function acquireIndirectClaimedSy(chain: RehearsalChain, evidence: string,
  delegate: { readonly delegate: string; readonly delegateCodeHash: string }) {
  const artifact = z.object({ bytecode: z.object({ object: hex }) }).passthrough().parse(JSON.parse(
    await readFile("out/MigrationIndirectClaimFixture.sol/MigrationIndirectClaimFixture.json", "utf8")));
  const deployment = await claimedSigned(chain, evidence, { index: 0, data: artifact.bytecode.object });
  const router = address.parse(deployment.mined["contractAddress"]);
  const outer = new Interface(["function forward(address,bytes) returns(bytes)"]);
  const receiver = new Interface(["function setWitness(address)", "function claim(uint256) returns(uint256)",
    "function catchClaim(uint256) returns(bool,uint256)", "function doubleClaim(uint256,uint256)",
    "function claimAndForward(uint256,address) returns(uint256)"]);
  const wallet = claimedWallet(240);
  const who = wallet.address.toLowerCase();
  const neighbor = claimedWallet(239).address.toLowerCase();
  const donor = "0x016900aa17a08a52f1cc10a9474b3bbfaeb380a3";
  const vault = "0xaf5c0cd3fdedd10bee00eff77fa0429bacdb41f0";
  const sy = "0xb55604cf4dcdabb362078e106d20f98512391edf";
  const w0 = 10n ** 19n;
  const floor = 10n ** 18n;
  const source = new Interface([...stakingClaim.fragments, "function reassign(address,uint256)"]);
  const n = async (target: string, method: string, args: readonly unknown[] = []) =>
    z.bigint().parse((await chain.call(target, stakingClaim, method, args))[0]);
  if (await chain.send("eth_getCode", [who, "latest"]) !== "0x"
    || await n(stakingSource, "balanceOf", [who]) !== 0n || await n(sy, "balanceOf", [who]) !== 0n) {
    throw new ExecutionError("STATE", "indirect signer is not fresh");
  }
  await claimedSigned(chain, evidence, { index: 0, to: who, data: "0x", value: 10n ** 18n });
  const nonce = BigInt(quantity.parse(await chain.send("eth_getTransactionCount", [who, "latest"])));
  const delegation = await claimedSigned(chain, evidence, { index: 0, to: who, data: "0x",
    authorization: wallet.authorizeSync({ address: delegate.delegate, chainId: 4663n, nonce }) });
  const walletCodeHash = keccak256(hex.parse(await chain.send("eth_getCode", [who, "latest"])));
  await claimedSigned(chain, evidence, { index: 240, to: who, data: receiver.encodeFunctionData("setWitness", [router]) });
  const amount = 2n * w0 + floor + 2n;
  const beforeDonor = await n(stakingSource, "balanceOf", [donor]);
  await chain.send("anvil_impersonateAccount", [donor]);
  try {
    const receipt = await chain.transact(stakingSource, { from: donor, data: source.encodeFunctionData("reassign", [who, amount]) });
    const afterDonor = await n(stakingSource, "balanceOf", [donor]);
    if (beforeDonor - afterDonor !== amount || await n(stakingSource, "balanceOf", [who]) !== amount) {
      throw new ExecutionError("STATE", "indirect acquisition did not conserve genuine donor weight");
    }
    await save(join(evidence, "claimed-indirect-donor.json"), { receipt, before: String(beforeDonor),
      after: String(afterDonor), amount: String(amount), delegation: delegation.mined.transactionHash });
  } finally { await chain.send("anvil_stopImpersonatingAccount", [donor]); }
  const negatives = [];
  for (const [kind, data] of [
    ["caught", receiver.encodeFunctionData("catchClaim", [2n ** 255n])],
    ["ambiguous", receiver.encodeFunctionData("doubleClaim", [1n, 1n])],
    ["wrong-beneficiary", receiver.encodeFunctionData("claimAndForward", [w0, neighbor])],
  ]) {
    if (!kind || !data) throw new ExecutionError("STATE", "missing indirect negative");
    const result = await surroundedClaim(chain, evidence, { to: router, data: outer.encodeFunctionData("forward", [who, data]) });
    negatives.push({ kind, transactionHash: result.mined.transactionHash, rawSignedTransaction: result.raw,
      blockNumber: BigInt(result.mined.blockNumber).toString(), blockHash: result.mined.blockHash });
  }
  const result = await surroundedClaim(chain, evidence, { to: router,
    data: outer.encodeFunctionData("forward", [who, receiver.encodeFunctionData("claim", [w0])]) });
  const frames = claimFrames(result.trace);
  // The outer helper has only the wallet CALL, and no before/after observation calls.
  if (frames[0]?.calls.length !== 1) throw new ExecutionError("STATE", "indirect outer unexpectedly instrumented");
  const stateReads: { readonly method: string; readonly params: readonly unknown[]; readonly response: unknown }[] = [];
  const books = await transactionClaimBooks({ send: async (method: string, params: readonly unknown[]) => {
    const response = await chain.send(method, params);
    stateReads.push({ method, params, response });
    return response;
  } }, who,
    { tag: result.mined.blockNumber, index: 1, count: 3 });
  const received = books.after.sy - books.before.sy;
  const shares = books.before.shares - books.after.shares;
  if (books.before.weight - books.after.weight !== w0 || books.after.weight !== floor || received <= 3n) {
    throw new ExecutionError("STATE", "unbracketed source effects differ");
  }
  const member = { transactionHash: result.mined.transactionHash, rawSignedTransaction: result.raw,
    blockNumber: BigInt(result.mined.blockNumber).toString(), blockHash: result.mined.blockHash,
    consumedWeight: String(w0), receivedSy: String(received), redeemedVaultShares: String(shares),
    execution: { kind: "indirect-transaction-v1" as const, walletCodeHash } };
  const certificate = claimedSyCertificate.unwrap().omit({ snapshotCapture: true }).parse({
    kind: "complete-remaining-token-staking", chainId: "4663", source: stakingSource, vault, sy,
    review: { authority: "synthetic one-third eligible remainder; no historical award inferred",
      originalId: `0x${fingerprint("synthetic unbracketed indirect original 240")}`, originalWallet: who,
      originalEth: "10000000000000000", originalDtf: "1000000000000000000",
      originalWeight: String(3n * w0), eligibleWeight: String(w0), priorDeliveredCredit: "0",
      contributionsKnown: true, eligiblePrincipalOnly: true, rewardsExcluded: true, aliasesReconciled: true,
      competingRepresentationsExcluded: true, unrelatedWeightFloor: String(floor), unrelatedSyFloor: "0" },
    members: [member],
  });
  await save(join(evidence, "claimed-indirect-negatives.json"), negatives);
  await save(join(evidence, "claimed-indirect-state-reads.json"), stateReads);
  await save(join(evidence, "claimed-indirect-books.json"), { member, router,
    before: Object.fromEntries(Object.entries(books.before).map(([key, value]) => [key, String(value)])),
    after: Object.fromEntries(Object.entries(books.after).map(([key, value]) => [key, String(value)])),
    qualification: "Real unbracketed indirect execution. Not full ERC-4337, not historical eligibility or historical trace access." });
  return { index: 240, q0: String(received), certificate };
}
