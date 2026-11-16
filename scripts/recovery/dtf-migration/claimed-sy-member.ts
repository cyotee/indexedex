import { Transaction, keccak256 } from "ethers";
import type { JsonRpcProvider } from "ethers";
import { z } from "zod";
import { address, hash, hex } from "./schema.js";
import type { ClaimedSyCertificate } from "./schema.js";
import { stakingClaim, proxyHash, routes, claimBookFacets, claimBookRuntimeHashes } from "./claimed-sy-source.js";
import { transactionClaimBooks } from "./claimed-sy-state.js";
import { claimFrame, claimFrames, witnessedClaimBooks, checkClaimEffects, claimBookReads,
  requireClaimEvidence as requireEvidence } from "./claimed-sy-witness.js";
const quantity = z.string().regex(/^0x[0-9a-fA-F]+$/);
export const block = z.object({ number: quantity, hash, parentHash: hash, transactions: z.array(hash) }).passthrough();
export const log = z.object({
  address, topics: z.array(hash), data: hex, blockHash: hash, blockNumber: quantity,
  transactionHash: hash, transactionIndex: quantity, removed: z.literal(false),
}).passthrough();
export const receipt = z.object({
  status: quantity, from: address, to: address, transactionHash: hash,
  blockHash: hash, blockNumber: quantity, transactionIndex: quantity, logs: z.array(log),
}).passthrough();
const transaction = z.object({
  hash, from: address, to: address, input: hex, value: quantity, chainId: quantity,
  blockHash: hash, blockNumber: quantity, transactionIndex: quantity,
}).passthrough();


/** Authenticate one source transaction; eligibility and complete-original coverage remain the caller's job. */
export async function authenticateClaimedSyMember(provider: JsonRpcProvider, c: Omit<ClaimedSyCertificate, "snapshotCapture">,
  m: ClaimedSyCertificate["members"][number]): Promise<void> {
  const wallet = c.review.originalWallet;
  const readAt = async (target: string, method: string, args: readonly unknown[], tag: string) =>
    stakingClaim.decodeFunctionResult(method, hex.parse(await provider.send("eth_call", [
      { to: target, data: stakingClaim.encodeFunctionData(method, args) }, tag,
    ])))[0];
  const codeAt = async (target: string, tag: string) =>
    hex.parse(await provider.send("eth_getCode", [target, tag]));
  const tag = `0x${BigInt(m.blockNumber).toString(16)}`;
  const priorTag = `0x${(BigInt(m.blockNumber) - 1n).toString(16)}`;
  const header = block.parse(await provider.send("eth_getBlockByNumber", [tag, false]));
  const prior = block.parse(await provider.send("eth_getBlockByNumber", [priorTag, false]));
  const mined = receipt.parse(await provider.send("eth_getTransactionReceipt", [m.transactionHash]));
  const tx = transaction.parse(await provider.send("eth_getTransactionByHash", [m.transactionHash]));
  const signed = Transaction.from(m.rawSignedTransaction);
  const data = stakingClaim.encodeFunctionData("withdrawClaim", [m.consumedWeight]);
  const relayed = m.execution?.kind === "relayed-eip7702-v1";
  const witness = m.execution?.kind === "witnessed-eip7702-v1" ? m.execution.witness : undefined;
  const indirect = m.execution?.kind === "indirect-transaction-v1";
  requireEvidence(signed.isSigned() && signed.hash === m.transactionHash
    && signed.chainId === 4663n && signed.value === 0n && signed.authorizationList === null
    && (indirect || (witness ? signed.to?.toLowerCase() === witness && witness !== wallet && witness !== c.source
      : relayed ? signed.to?.toLowerCase() === wallet
      : signed.from?.toLowerCase() === wallet && signed.to?.toLowerCase() === c.source && signed.data === data)),
  "not an admitted signed source or delegated-wallet claim");
  requireEvidence(header.hash === m.blockHash && BigInt(header.number) === BigInt(m.blockNumber)
    && header.parentHash === prior.hash
    && (indirect || witness !== undefined || header.transactions.length === 1)
    && header.transactions[Number(BigInt(tx.transactionIndex))] === m.transactionHash,
  "noncanonical or unwitnessed nonisolated preparation block");
  requireEvidence(tx.hash === m.transactionHash && tx.from === signed.from?.toLowerCase()
    && tx.to === signed.to?.toLowerCase() && tx.input === signed.data
    && BigInt(tx.value) === 0n && BigInt(tx.chainId) === 4663n
    && tx.blockHash === m.blockHash && tx.blockNumber === header.number
    && mined.transactionHash === tx.hash && mined.from === tx.from && mined.to === tx.to
    && mined.blockHash === m.blockHash && mined.blockNumber === header.number
    && BigInt(mined.transactionIndex) === BigInt(tx.transactionIndex)
    && BigInt(mined.status) === 1n, "transaction or successful receipt differs");
  for (const at of [priorTag, tag]) {
    const walletCode = await codeAt(wallet, at);
    if (m.execution?.kind === "indirect-transaction-v1") {
      requireEvidence(walletCode !== "0x" && keccak256(walletCode) === m.execution.walletCodeHash,
        "indirect claimant runtime differs");
    } else if (m.execution) {
      const delegateCode = await codeAt(m.execution.delegate, at);
      requireEvidence(walletCode === `0xef0100${m.execution.delegate.slice(2)}`
        && delegateCode !== "0x" && keccak256(delegateCode) === m.execution.delegateCodeHash,
      "delegated claimant designation or runtime differs");
    } else requireEvidence(walletCode === "0x", "contract or delegated claimant unsupported");
    for (const [target, selector, facet, runtimeHash] of routes) {
      requireEvidence(keccak256(await codeAt(target, at)) === proxyHash
        && address.parse(await readAt(target, "facetAddress", [selector], at)) === facet
        && keccak256(await codeAt(facet, at)) === runtimeHash, "source runtime or routing differs");
    }
    if (indirect || witness) {
      for (const [, target, method, args] of claimBookReads(wallet)) {
        const facet = claimBookFacets[target];
        const selector = stakingClaim.encodeFunctionData(method, args).slice(0, 10);
        requireEvidence(address.parse(await readAt(target, "facetAddress", [selector], at)) === facet
          && keccak256(await codeAt(facet, at)) === claimBookRuntimeHashes[facet],
        "source book implementation differs");
      }
    }
    requireEvidence(await readAt(c.source, "phase", [], at) === 2n
      && address.parse(await readAt(c.source, "claimVault", [], at)) === c.vault
      && address.parse(await readAt(c.vault, "asset", [], at)) === c.sy
      && await readAt(c.vault, "decimals", [], at) === 19n
      && await readAt(c.sy, "decimals", [], at) === 9n, "source phase asset or units differ");
  }
  const frames = claimFrames(await provider.send("debug_traceTransaction", [m.transactionHash, { tracer: "callTracer" }]));
  const sourceFrames = frames.filter((frame) => frame.type === "CALL" && frame.to === c.source
    && frame.input.slice(0, 10) === data.slice(0, 10));
  const sourceFrame = sourceFrames[0];
  requireEvidence(sourceFrames.length === 1 && sourceFrame !== undefined,
  "ambiguous source claim attempts", "TRACE_AMBIGUOUS");
  if (m.execution && !relayed && !witness && !indirect) requireEvidence(frames.every((frame) => frame.to !== wallet),
    "direct delegated claim executed claimant wallet code");
  const root = frames[0];
  const output = stakingClaim.encodeFunctionResult("withdrawClaim", [m.receivedSy]);
  const redeemData = stakingClaim.encodeFunctionData("redeem", [m.redeemedVaultShares, wallet, c.source]);
  const redeems = claimFrames(sourceFrame).filter((f) => f.type === "CALL" && f.from === c.source
    && f.to === c.vault && f.input === redeemData && f.output === output);
  requireEvidence(root?.type === "CALL" && root.from === tx.from && root.to === tx.to && root.input === tx.input
    && sourceFrame.from === wallet && sourceFrame.input === data && sourceFrame.output === output
    && redeems.length === 1, "actual source caller, return or vault recipient differs");
  if (witness || indirect) {
    // Parent/end-block routing alone cannot certify which facet actually executed
    // between neighboring transactions. Authenticate the operation's delegation too.
    for (const [target, selector, facet] of routes) {
      const invoked = frames.filter((f) => (f.type === "CALL" || f.type === "STATICCALL")
        && f.to === target && f.input.startsWith(selector));
      requireEvidence(invoked.length > 0 && invoked.every((frame) => {
        const children = frame.calls.map((raw) => claimFrame.parse(raw));
        const child = children[0];
        return children.length === 1 && child?.type === "DELEGATECALL" && child.from === target
          && child.to === facet && child.input === frame.input && child.output === frame.output;
      }), "transaction-local source routing differs");
    }
  }
  for (const event of mined.logs) {
    requireEvidence(event.transactionHash === m.transactionHash && event.blockHash === m.blockHash
      && event.blockNumber === header.number
      && BigInt(event.transactionIndex) === BigInt(tx.transactionIndex), "noncanonical log");
  }
  const claims = mined.logs.filter((l) => l.address === c.source).map((l) =>
    stakingClaim.parseLog({ topics: [...l.topics], data: l.data })).filter((l) => l?.name === "ClaimWithdrawn");
  requireEvidence(claims.length === 1 && address.parse(claims[0]?.args[0]) === wallet
    && claims[0]?.args[1] === BigInt(m.consumedWeight)
    && claims[0]?.args[2] === BigInt(m.receivedSy), "claim event differs");
  const books = async (at: string) => {
    const n = async (target: string, method: string, args: readonly unknown[] = []) =>
      z.bigint().parse(await readAt(target, method, args, at));
    return { weight: await n(c.source, "balanceOf", [wallet]), supply: await n(c.source, "totalSupply"),
      shares: await n(c.vault, "balanceOf", [c.source]), vaultSupply: await n(c.vault, "totalSupply"),
      sy: await n(c.sy, "balanceOf", [wallet]), vaultSy: await n(c.sy, "balanceOf", [c.vault]),
      sySupply: await n(c.sy, "totalSupply") };
  };
  requireEvidence(root !== undefined, "missing root frame");
  const { before, after } = indirect ? await transactionClaimBooks(provider, wallet,
    { tag, index: Number(BigInt(tx.transactionIndex)), count: header.transactions.length })
    : witness ? witnessedClaimBooks(root, wallet)
    : { before: await books(priorTag), after: await books(tag) };
  checkClaimEffects({ before, after }, m, c.review);
  requireEvidence(block.parse(await provider.send("eth_getBlockByNumber", [tag, false])).hash === header.hash,
    "preparation block changed during authentication");
}
