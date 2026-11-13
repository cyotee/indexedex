import { HDNodeWallet, Interface, keccak256 } from "ethers";
import { join } from "node:path";
import { z } from "zod";
import { stakingSource, stakingClaim } from "./claimed-sy.js";
import { claimedSyCertificate, address, hash } from "./schema.js";
import type { ClaimedSyCertificate } from "./schema.js";
import { ExecutionError, quantity } from "./execution-schema.js";
import { subscribeReceipt } from "./execution-rpc.js";
import type { RehearsalChain } from "./rehearsal-chain.js";
import { fingerprint } from "./provenance.js";
import { save } from "./rehearsal-data.js";

const donor = "0x016900aa17a08a52f1cc10a9474b3bbfaeb380a3";
const vault = "0xaf5c0cd3fdedd10bee00eff77fa0429bacdb41f0";
const sy = "0xb55604cf4dcdabb362078e106d20f98512391edf";
const sourceAbi = new Interface([
  ...stakingClaim.fragments,
  "function reassign(address,uint256)",
  "function approve(address,uint256) returns(bool)",
  "function allowance(address,address) view returns(uint256)",
]);
export const claimedWallet = (index: number) => HDNodeWallet.fromPhrase(
  "test test test test test test test test test test test junk", undefined, `m/44'/60'/0'/0/${index}`);

/** Only owned disposable loopbacks; signed bytes are retained before submission. */
export async function claimedSigned(chain: RehearsalChain, evidence: string, request: {
  readonly index: number; readonly to: string; readonly data: string;
  readonly value?: bigint; readonly gas?: bigint; readonly status?: bigint;
}) {
  if (chain.endpoint.hostname !== "127.0.0.1" || !["18573", "18575"].includes(chain.endpoint.port)) {
    throw new ExecutionError("DOMAIN", "claimed SY signer requires owned loopback18573 or18575");
  }
  const signer = claimedWallet(request.index);
  const from = signer.address.toLowerCase();
  const nonce = Number(BigInt(quantity.parse(await chain.send("eth_getTransactionCount", [from, "pending"]))));
  const raw = await signer.signTransaction({ to: request.to, data: request.data, chainId: 4663, nonce,
    value: request.value ?? 0n, gasLimit: request.gas ?? 20000000n, type: 0,
    gasPrice: BigInt(quantity.parse(await chain.send("eth_gasPrice", []))) });
  const transactionHash = keccak256(raw);
  const stem = `claimed-signed-${request.index}-${nonce}`;
  await save(join(evidence, `${stem}-intent.json`), { raw, from, transactionHash, nonce,
    provenance: "original captured controlled development signature before submission" });
  const watch = await subscribeReceipt(chain, transactionHash);
  try {
    if (hash.parse(await chain.send("eth_sendRawTransaction", [raw])) !== transactionHash) {
      throw new ExecutionError("STATE", "claimed source signed hash differs");
    }
    const mined = await watch.mined();
    const actualReceipt = await chain.send("eth_getTransactionReceipt", [transactionHash]);
    const actualTransaction = await chain.send("eth_getTransactionByHash", [transactionHash]);
    const trace = await chain.send("debug_traceTransaction", [transactionHash, { tracer: "callTracer" }]);
    await save(join(evidence, `${stem}-mined.json`), { raw, transactionHash,
      transaction: actualTransaction, receipt: actualReceipt, trace });
    chain.receipts.push(mined);
    if (BigInt(mined.status) !== (request.status ?? 1n) || mined.from !== from) {
      throw new ExecutionError("STATE", `claimed signed status differs: ${transactionHash}`);
    }
    return { mined, raw, trace };
  } finally { watch.close(); }
}

/** Actual holder reassigns; synthetic eligible allocations do not establish historical rights. */
export async function acquireClaimedSy(chain: RehearsalChain, evidence: string) {
  const n = async (target: string, method: string, args: readonly unknown[] = []) =>
    z.bigint().parse((await chain.call(target, sourceAbi, method, args))[0]);
  const w0 = 10013000000000000000017n;
  const unrelated = 7n * 10n ** 18n;
  const seed = 3n * 10n ** 18n;
  if (await chain.send("eth_getCode", [donor, "latest"]) !== "0x"
    || await n(stakingSource, "balanceOf", [donor]) < 2n * (w0 + unrelated + seed)) {
    throw new ExecutionError("DOMAIN", "authentic existing EOA donor unavailable");
  }
  await claimedSigned(chain, evidence, { index: 0, to: donor, data: "0x", value: 10n ** 18n });
  const originals = [];
  for (const index of [231, 232]) {
    const wallet = claimedWallet(index).address.toLowerCase();
    if (await chain.send("eth_getCode", [wallet, "latest"]) !== "0x"
      || await n(stakingSource, "balanceOf", [wallet]) !== 0n || await n(sy, "balanceOf", [wallet]) !== 0n) {
      throw new ExecutionError("DOMAIN", "fresh claimed source signer not an empty EOA");
    }
    await claimedSigned(chain, evidence, { index: 0, to: wallet, data: "0x", value: 10n ** 18n });
    const donorBefore = await n(stakingSource, "balanceOf", [donor]);
    await chain.send("anvil_impersonateAccount", [donor]);
    try {
      const mined = await chain.transact(stakingSource, { from: donor,
        data: sourceAbi.encodeFunctionData("reassign", [wallet, w0 + unrelated + seed]) });
      await save(join(evidence, `claimed-donor-${index}.json`), {
        provenance: "local impersonated actual EOA holder reassign; not donor signature, public consent or source-owner authority",
        transaction: await chain.send("eth_getTransactionByHash", [mined.transactionHash]),
        receipt: await chain.send("eth_getTransactionReceipt", [mined.transactionHash]),
        trace: await chain.send("debug_traceTransaction", [mined.transactionHash, { tracer: "callTracer" }]),
        donorBefore: String(donorBefore), donorAfter: String(await n(stakingSource, "balanceOf", [donor])),
      });
    } finally { await chain.send("anvil_stopImpersonatingAccount", [donor]); }
    if (await n(stakingSource, "balanceOf", [wallet]) !== w0 + unrelated + seed
      || await n(stakingSource, "balanceOf", [donor]) !== donorBefore - w0 - unrelated - seed) {
      throw new ExecutionError("STATE", "actual source acquisition does not conserve weight");
    }
    const claim = async (weight: bigint) => {
      const before = { weight: await n(stakingSource, "balanceOf", [wallet]),
        sy: await n(sy, "balanceOf", [wallet]), shares: await n(vault, "balanceOf", [stakingSource]) };
      const result = await claimedSigned(chain, evidence, { index, to: stakingSource,
        data: sourceAbi.encodeFunctionData("withdrawClaim", [weight]) });
      const after = { weight: await n(stakingSource, "balanceOf", [wallet]),
        sy: await n(sy, "balanceOf", [wallet]), shares: await n(vault, "balanceOf", [stakingSource]) };
      const output = z.object({ output: z.string() }).passthrough().parse(result.trace).output;
      const received = z.bigint().parse(stakingClaim.decodeFunctionResult("withdrawClaim", output)[0]);
      if (before.weight - after.weight !== weight || after.sy - before.sy !== received) {
        throw new ExecutionError("STATE", "measured source claim/return differs");
      }
      await save(join(evidence, `claimed-source-books-${index}-${result.mined.transactionHash}.json`), {
        before: Object.fromEntries(Object.entries(before).map(([k, v]) => [k, String(v)])),
        after: Object.fromEntries(Object.entries(after).map(([k, v]) => [k, String(v)])),
      });
      return { transactionHash: result.mined.transactionHash, rawSignedTransaction: result.raw,
        blockNumber: BigInt(result.mined.blockNumber).toString(), blockHash: result.mined.blockHash,
        consumedWeight: String(weight), receivedSy: String(received), redeemedVaultShares: String(before.shares - after.shares) };
    };
    const excludedSeed = await claim(seed);
    const floor = BigInt(excludedSeed.receivedSy);
    const members = [];
    if (index === 231) members.push(await claim(w0));
    else {
      const first = 3337000000000000000005n;
      members.push(await claim(first));
      // A genuine committed zero-output slice remains part of complete coverage.
      members.push(await claim(1n));
      members.push(await claim(w0 - first - 1n));
    }
    const q0 = members.reduce((sum, m) => sum + BigInt(m.receivedSy), 0n);
    if (floor <= 0n || q0 <= 0n || await n(stakingSource, "balanceOf", [wallet]) !== unrelated
      || await n(sy, "balanceOf", [wallet]) !== q0 + floor) {
      throw new ExecutionError("STATE", "complete preparation or excluded floors differ");
    }
    const certificate: Omit<ClaimedSyCertificate, "snapshotCapture"> = claimedSyCertificate.unwrap().omit({ snapshotCapture: true }).parse({
      kind: "complete-original-token-staking", chainId: "4663", source: stakingSource, vault, sy,
      review: { authority: "synthetic-local code proof only; historical originals and aliases not operationally approved",
        originalId: `0x${fingerprint(`synthetic complete claimed original ${index}`)}`,
        originalWallet: wallet, originalEth: "10000000000000000", originalDtf: "1000000000000000000",
        eligibleWeight: String(w0), priorDeliveredCredit: "0", contributionsKnown: true,
        eligiblePrincipalOnly: true, rewardsExcluded: true, aliasesReconciled: true,
        competingRepresentationsExcluded: true, unrelatedWeightFloor: String(unrelated), unrelatedSyFloor: String(floor) },
      members,
    });
    originals.push({ index, q0: String(q0), certificate });
  }
  await save(join(evidence, "claimed-sy-acquisition.json"), { originals,
    qualification: "real measured source operations; synthetic W0/E0/D0/zero-delivery and origin partitions are not historical awards" });
  return originals;
}
