import { Interface, keccak256 } from "ethers";
import { readFile } from "node:fs/promises";
import { join } from "node:path";
import { z } from "zod";
import { claimedSigned, claimedWallet } from "./rehearsal-claimed-sy-source.js";
import { stakingClaim, stakingSource } from "./claimed-sy-source.js";
import { claimFrame, claimWitness, witnessedClaimBooks } from "./claimed-sy-witness.js";
import { address, claimedSyCertificate, hash, hex } from "./schema.js";
import { ExecutionError, quantity } from "./execution-schema.js";
import { subscribeReceipt } from "./execution-rpc.js";
import type { RehearsalChain } from "./rehearsal-chain.js";
import { fingerprint } from "./provenance.js";
import { save } from "./rehearsal-data.js";

const donor = "0x016900aa17a08a52f1cc10a9474b3bbfaeb380a3";
const vault = "0xaf5c0cd3fdedd10bee00eff77fa0429bacdb41f0";
const sy = "0xb55604cf4dcdabb362078e106d20f98512391edf";
const receiver = new Interface([
  "function setWitness(address)", "function claim(uint256) returns(uint256)",
  "function catchClaim(uint256) returns(bool,uint256)", "function doubleClaim(uint256,uint256)",
  "function claimAndForward(uint256,address) returns(uint256)",
]);

/** One signed sender's nonces fix the order; no sleeps or mempool timing assumptions. */
export async function surroundedClaim(chain: RehearsalChain, evidence: string, request: {
  readonly to: string; readonly data: string;
}) {
  if (chain.endpoint.hostname !== "127.0.0.1" || !["18573", "18575"].includes(chain.endpoint.port)) {
    throw new ExecutionError("DOMAIN", "witness batch requires owned local rehearsal");
  }
  const neighbor = claimedWallet(239).address.toLowerCase();
  const signer = claimedWallet(0);
  const nonce = Number(BigInt(quantity.parse(await chain.send("eth_getTransactionCount", [signer.address, "pending"]))));
  const gasPrice = BigInt(quantity.parse(await chain.send("eth_gasPrice", [])));
  const raw = await Promise.all([
    { to: neighbor, data: receiver.encodeFunctionData("claim", [10n ** 16n]) },
    { to: request.to, data: request.data },
    { to: neighbor, data: receiver.encodeFunctionData("claim", [10n ** 16n]) },
  ].map((tx, i) => signer.signTransaction({ ...tx, chainId: 4663, nonce: nonce + i,
    value: 0n, gasLimit: 20000000n, gasPrice, type: 0 })));
  const hashes = raw.map(keccak256);
  const transactionHash = hashes[1];
  const signed = raw[1];
  if (!transactionHash || !signed) throw new ExecutionError("STATE", "missing signed witness");
  await save(join(evidence, `claimed-witness-${nonce}-intent.json`), { raw, hashes, nonce });
  const watch = await subscribeReceipt(chain, transactionHash);
  await chain.send("evm_setAutomine", [false]);
  try {
    for (const [i, bytes] of raw.entries()) {
      if (hash.parse(await chain.send("eth_sendRawTransaction", [bytes])) !== hashes[i]) {
        throw new ExecutionError("STATE", "witness signed hash differs");
      }
    }
    await chain.send("evm_mine", []);
    const mined = await watch.mined();
    const header = z.object({ hash, transactions: z.array(hash) }).passthrough().parse(
      await chain.send("eth_getBlockByNumber", [mined.blockNumber, false]));
    if (BigInt(mined.status) !== 1n || BigInt(mined.transactionIndex) !== 1n
      || JSON.stringify(header.transactions) !== JSON.stringify(hashes)) {
      throw new ExecutionError("STATE", "signed witness was not surrounded at index one");
    }
    const records = [];
    for (const id of hashes) {
      const receipt = await chain.canonicalReceipt(id);
      if (!receipt || BigInt(receipt.status) !== 1n) throw new ExecutionError("STATE", "surrounding operation failed");
      chain.receipts.push(receipt);
      records.push({ receipt, transaction: await chain.send("eth_getTransactionByHash", [id]),
        trace: await chain.send("debug_traceTransaction", [id, { tracer: "callTracer" }]) });
    }
    await save(join(evidence, `claimed-witness-${nonce}-mined.json`), { raw, hashes, header, records });
    const middle = records[1];
    if (!middle) throw new ExecutionError("STATE", "missing mined witness");
    return { mined, raw: signed, trace: middle.trace };
  } finally {
    watch.close();
    await chain.send("evm_setAutomine", [true]);
  }
}

/** Real donor weights, real delegated callers and real source effects; eligibility remains synthetic. */
export async function acquireWitnessedClaimedSy(chain: RehearsalChain, evidence: string,
  delegate: { readonly delegate: string; readonly delegateCodeHash: string }) {
  const artifact = z.object({ bytecode: z.object({ object: hex }) }).passthrough().parse(JSON.parse(
    await readFile("out/MigrationClaimWitness.sol/MigrationClaimWitness.json", "utf8")));
  const deployment = await claimedSigned(chain, evidence, { index: 0, data: artifact.bytecode.object });
  const witness = address.parse(deployment.mined["contractAddress"]);
  const execution = { kind: "witnessed-eip7702-v1" as const, ...delegate, witness };
  const wallet = claimedWallet(238).address.toLowerCase();
  const neighbor = claimedWallet(239).address.toLowerCase();
  const w0 = 10n ** 19n;
  const unrelated = 10n ** 18n;
  const source = new Interface([...stakingClaim.fragments, "function reassign(address,uint256)"]);
  const n = async (target: string, method: string, args: readonly unknown[] = []) =>
    z.bigint().parse((await chain.call(target, stakingClaim, method, args))[0]);
  for (const index of [238, 239]) {
    const account = claimedWallet(index);
    const who = account.address.toLowerCase();
    if (await chain.send("eth_getCode", [who, "latest"]) !== "0x"
      || await n(stakingSource, "balanceOf", [who]) !== 0n || await n(sy, "balanceOf", [who]) !== 0n) {
      throw new ExecutionError("STATE", "witness wallet is not fresh");
    }
    await claimedSigned(chain, evidence, { index: 0, to: who, data: "0x", value: 10n ** 18n });
    const nonce = BigInt(quantity.parse(await chain.send("eth_getTransactionCount", [who, "latest"])));
    await claimedSigned(chain, evidence, { index: 0, to: who, data: "0x",
      authorization: account.authorizeSync({ address: delegate.delegate, chainId: 4663n, nonce }) });
    await claimedSigned(chain, evidence, { index, to: who, data: receiver.encodeFunctionData("setWitness", [witness]) });
    const amount = index === 238 ? 2n * w0 + unrelated + 2n : 10n ** 18n;
    const before = await n(stakingSource, "balanceOf", [donor]);
    await chain.send("anvil_impersonateAccount", [donor]);
    try {
      const receipt = await chain.transact(stakingSource, { from: donor,
        data: source.encodeFunctionData("reassign", [who, amount]) });
      const after = await n(stakingSource, "balanceOf", [donor]);
      if (before - after !== amount || await n(stakingSource, "balanceOf", [who]) !== amount) {
        throw new ExecutionError("STATE", "genuine donor weight was not conserved");
      }
      await save(join(evidence, `claimed-witness-donor-${index}.json`), { receipt, before: String(before),
        after: String(after), amount: String(amount), provenance: "local actual-holder impersonation, not public authorization" });
    } finally { await chain.send("anvil_stopImpersonatingAccount", [donor]); }
  }
  const negatives = [];
  for (const [kind, data] of [
    ["caught", receiver.encodeFunctionData("catchClaim", [2n ** 255n])],
    ["ambiguous", receiver.encodeFunctionData("doubleClaim", [1n, 1n])],
    ["wrong-beneficiary", receiver.encodeFunctionData("claimAndForward", [w0, neighbor])],
  ]) {
    if (!kind || !data) throw new ExecutionError("STATE", "missing adversarial case");
    const result = await surroundedClaim(chain, evidence,
      { to: witness, data: claimWitness.encodeFunctionData("witness", [wallet, data]) });
    negatives.push({ kind, transactionHash: result.mined.transactionHash, rawSignedTransaction: result.raw,
      blockNumber: BigInt(result.mined.blockNumber).toString(), blockHash: result.mined.blockHash });
  }
  const result = await surroundedClaim(chain, evidence, { to: witness,
    data: claimWitness.encodeFunctionData("witness", [wallet, receiver.encodeFunctionData("claim", [w0])]) });
  const books = witnessedClaimBooks(claimFrame.parse(result.trace), wallet);
  const received = books.after.sy - books.before.sy;
  const shares = books.before.shares - books.after.shares;
  if (books.before.weight - books.after.weight !== w0 || books.after.weight !== unrelated
    || received <= 3n || books.before.sy !== 0n) throw new ExecutionError("STATE", "witness source books differ");
  const member = { transactionHash: result.mined.transactionHash, rawSignedTransaction: result.raw,
    blockNumber: BigInt(result.mined.blockNumber).toString(), blockHash: result.mined.blockHash,
    consumedWeight: String(w0), receivedSy: String(received), redeemedVaultShares: String(shares), execution };
  const certificate = claimedSyCertificate.unwrap().omit({ snapshotCapture: true }).parse({
    kind: "complete-remaining-token-staking", chainId: "4663", source: stakingSource, vault, sy,
    review: { authority: "synthetic eligible one-third original, not historical allocation approval",
      originalId: `0x${fingerprint("synthetic witnessed claimed original 238")}`, originalWallet: wallet,
      originalEth: "10000000000000000", originalDtf: "1000000000000000000",
      originalWeight: String(3n * w0), eligibleWeight: String(w0), priorDeliveredCredit: "0",
      contributionsKnown: true, eligiblePrincipalOnly: true, rewardsExcluded: true, aliasesReconciled: true,
      competingRepresentationsExcluded: true, unrelatedWeightFloor: String(unrelated), unrelatedSyFloor: "0" },
    members: [member],
  });
  await save(join(evidence, "claimed-witness-negatives.json"), negatives);
  await save(join(evidence, "claimed-witness-books.json"), { member,
    before: Object.fromEntries(Object.entries(books.before).map(([key, value]) => [key, String(value)])),
    after: Object.fromEntries(Object.entries(books.after).map(([key, value]) => [key, String(value)])),
    scope: "Fixed observation router, not a full EntryPoint implementation; transaction-local RPC trace only." });
  return { index: 238, q0: String(received), certificate };
}
