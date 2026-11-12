import { Interface, Transaction, keccak256, toUtf8Bytes } from "ethers";
import type { JsonRpcProvider } from "ethers";
import { z } from "zod";
import { canonical } from "./provenance.js";
import { address, hash, hex, PreparationError } from "./schema.js";
import type { ClaimedSyCertificate, Domain, PreparationInput, WeightedSyOriginal } from "./schema.js";

export const stakingSource = "0xe4c9ff4cfd17ae73ecb3825ebdf7db113c146d00";
export const stakingClaim = new Interface([
  "function withdrawClaim(uint256) returns(uint256)",
  "function balanceOf(address) view returns(uint256)",
  "function totalSupply() view returns(uint256)",
  "function phase() view returns(uint8)",
  "function claimVault() view returns(address)",
  "function asset() view returns(address)",
  "function decimals() view returns(uint8)",
  "function facetAddress(bytes4) view returns(address)",
  "function redeem(uint256,address,address) returns(uint256)",
  "event ClaimWithdrawn(address indexed user,uint256 stakeAmount,uint256 claimOut)",
  "event Transfer(address indexed from,address indexed to,uint256 value)",
  "event Withdraw(address indexed sender,address indexed receiver,address indexed owner,uint256 assets,uint256 shares)",
]);
const quantity = z.string().regex(/^0x[0-9a-fA-F]+$/);
const block = z.object({ number: quantity, hash, parentHash: hash, transactions: z.array(hash) }).passthrough();
const callFrame = z.object({
  from: address, to: address, input: hex, output: hex.default("0x"), type: z.string(),
  error: z.string().optional(), calls: z.array(z.unknown()).default([]),
}).passthrough();
const log = z.object({
  address, topics: z.array(hash), data: hex, blockHash: hash, blockNumber: quantity,
  transactionHash: hash, transactionIndex: quantity, removed: z.literal(false),
}).passthrough();
const receipt = z.object({
  status: quantity, from: address, to: address, transactionHash: hash,
  blockHash: hash, blockNumber: quantity, transactionIndex: quantity, logs: z.array(log),
}).passthrough();
const transaction = z.object({
  hash, from: address, to: address, input: hex, value: quantity, chainId: quantity,
  blockHash: hash, blockNumber: quantity, transactionIndex: quantity,
}).passthrough();
const proxyHash = "0x2393ee3dc4d7877a9bfb7b59c272f2b9b0d1df92f2dc82ee67df076a99836601";
const routes = [
  [stakingSource, "0xa224dcb7", "0x9c90d4a476f3473b9a0e32b530af3474271a80b1",
    "0x5628dcb4bb0a1a24e6bde3b985f92c2ef0894ddd6006a55ddaffccc877a52742"],
  ["0xaf5c0cd3fdedd10bee00eff77fa0429bacdb41f0", "0xba087652", "0x517234f78a4bcafc5f880024a3e45d49cf43b305",
    "0x8c1ea71d607b09b21c4e78f850647a059dc7935b6772f7cd3aeaa700a995439f"],
  ["0xb55604cf4dcdabb362078e106d20f98512391edf", "0xa9059cbb", "0x4b6e65cfc9a16aae0dfa4257a680f4697275e5fc",
    "0x6da9227c829765d0464b5eeee02c55ea45883e3af2767aea546f5e906e8b143d"],
] as const;
function requireEvidence(valid: boolean, message: string): void {
  if (!valid) throw new PreparationError("PROVENANCE", `claimed SY: ${message}`);
}

export function claimedSyEvidenceId(domain: Domain, original: WeightedSyOriginal, certificate: ClaimedSyCertificate) {
  const { evidenceId: _commitment, ...inputs } = original;
  return keccak256(toUtf8Bytes(canonical({
    kind: "IndexedEx.complete-original-claimed-sy-v1",
    chainId: domain.chainId, proxy: domain.proxy, snapshotId: domain.snapshotId,
    original: inputs, certificate,
  })));
}

/** Historical review is explicit; no hash or current balance authenticates that review. */
export function validateClaimedSyInputs(input: PreparationInput): void {
  const members = new Set<string>();
  for (const row of input.weightedSy) {
    const c = row.claimedOrigin;
    if (!c) continue;
    const r = c.review;
    const o = row.original;
    requireEvidence(input.domain.chainId === c.chainId && o.source === c.sy
      && r.originalId === o.originalId && r.originalWallet === o.originalWallet
      && r.originalEth === o.originalEth && r.originalDtf === o.originalDtf
      && o.contributionsKnown, "review and complete original differ");
    requireEvidence(c.members.reduce((sum, m) => sum + BigInt(m.consumedWeight), 0n) === BigInt(r.eligibleWeight),
      "incomplete or excess original weight coverage");
    const q0 = c.members.reduce((sum, m) => sum + BigInt(m.receivedSy), 0n);
    requireEvidence(q0 > 0n && q0 === BigInt(o.originalUnits), "measured original SY sum differs");
    for (const member of c.members) {
      requireEvidence(!members.has(member.transactionHash), "duplicate member within or across originals");
      members.add(member.transactionHash);
      requireEvidence(BigInt(member.blockNumber) <= BigInt(input.domain.blockNumber), "preparation follows loading domain");
    }
    requireEvidence(o.evidenceId === claimedSyEvidenceId(input.domain, o, c), "certificate commitment differs");
  }
}

/** Authenticate against the selected RPC, never against self-consistent uploaded receipt JSON. */
export async function authenticateClaimedSy(input: PreparationInput, provider: JsonRpcProvider): Promise<void> {
  const budgets = new Map<string, { historical: bigint; current: bigint; floor: bigint; sy: string }>();
  let snapshotBlock: bigint | undefined;
  const surrender = new Interface([
    "function weightedSySurrender(bytes32) view returns((uint256 consumedUnits,uint256 deliveredCredit,uint256 remainingUnits,uint256 remainingCredit))",
  ]);
  const readAt = async (target: string, method: string, args: readonly unknown[], tag: string) =>
    stakingClaim.decodeFunctionResult(method, hex.parse(await provider.send("eth_call", [
      { to: target, data: stakingClaim.encodeFunctionData(method, args) }, tag,
    ])))[0];
  const codeAt = async (target: string, tag: string) =>
    hex.parse(await provider.send("eth_getCode", [target, tag]));
  for (const row of input.weightedSy) {
    const c = row.claimedOrigin;
    if (!c) continue;
    const wallet = row.original.originalWallet;
    const captured = receipt.parse(await provider.send("eth_getTransactionReceipt", [c.snapshotCapture.transactionHash]));
    const captureHeader = block.parse(await provider.send("eth_getBlockByNumber", [captured.blockNumber, false]));
    const captureEvent = new Interface(["event MigrationSnapshotCaptured(bytes32 indexed snapshotId,uint256 blockNumber)"]);
    const captureLogs = captured.logs.filter((l) => l.address === input.domain.proxy
      && l.topics[0] === captureEvent.getEvent("MigrationSnapshotCaptured")?.topicHash);
    requireEvidence(BigInt(captured.status) === 1n && captured.to === input.domain.proxy
      && captured.transactionHash === c.snapshotCapture.transactionHash
      && captured.blockHash === c.snapshotCapture.blockHash && captureHeader.hash === captured.blockHash
      && BigInt(captured.blockNumber) === BigInt(c.snapshotCapture.blockNumber)
      && BigInt(captured.blockNumber) <= BigInt(input.domain.blockNumber)
      && captureLogs.length === 1 && captureLogs.every((l) => l.transactionHash === captured.transactionHash
        && l.blockHash === captured.blockHash && captureEvent.parseLog({ topics: [...l.topics], data: l.data })?.args[0] === input.domain.snapshotId),
    "snapshot capture is not the authentic canonical domain event");
    requireEvidence(snapshotBlock === undefined || snapshotBlock === BigInt(captured.blockNumber), "different capture domains");
    snapshotBlock = BigInt(captured.blockNumber);
    for (const m of c.members) {
      const tag = `0x${BigInt(m.blockNumber).toString(16)}`;
      const priorTag = `0x${(BigInt(m.blockNumber) - 1n).toString(16)}`;
      const header = block.parse(await provider.send("eth_getBlockByNumber", [tag, false]));
      const prior = block.parse(await provider.send("eth_getBlockByNumber", [priorTag, false]));
      const mined = receipt.parse(await provider.send("eth_getTransactionReceipt", [m.transactionHash]));
      const tx = transaction.parse(await provider.send("eth_getTransactionByHash", [m.transactionHash]));
      const signed = Transaction.from(m.rawSignedTransaction);
      const data = stakingClaim.encodeFunctionData("withdrawClaim", [m.consumedWeight]);
      requireEvidence(signed.isSigned() && signed.hash === m.transactionHash && signed.from?.toLowerCase() === wallet
        && signed.to?.toLowerCase() === c.source && signed.chainId === 4663n && signed.value === 0n
        && signed.data === data && signed.authorizationList === null, "not an admitted direct signed EOA claim");
      requireEvidence(header.hash === m.blockHash && BigInt(header.number) === BigInt(m.blockNumber)
        && header.parentHash === prior.hash && header.transactions.length === 1
        && header.transactions[0] === m.transactionHash, "noncanonical or nonisolated preparation block");
      requireEvidence(tx.hash === m.transactionHash && tx.from === wallet && tx.to === c.source
        && tx.input === data && BigInt(tx.value) === 0n && BigInt(tx.chainId) === 4663n
        && tx.blockHash === m.blockHash && tx.blockNumber === header.number && BigInt(tx.transactionIndex) === 0n
        && mined.transactionHash === tx.hash && mined.from === wallet && mined.to === c.source
        && mined.blockHash === m.blockHash && mined.blockNumber === header.number
        && BigInt(mined.transactionIndex) === 0n && BigInt(mined.status) === 1n, "transaction or successful receipt differs");
      for (const at of [priorTag, tag]) {
        requireEvidence(await codeAt(wallet, at) === "0x", "contract or delegated claimant unsupported");
        for (const [target, selector, facet, runtimeHash] of routes) {
          requireEvidence(keccak256(await codeAt(target, at)) === proxyHash
            && address.parse(await readAt(target, "facetAddress", [selector], at)) === facet
            && keccak256(await codeAt(facet, at)) === runtimeHash, "source runtime or routing differs");
        }
        requireEvidence(await readAt(c.source, "phase", [], at) === 2n
          && address.parse(await readAt(c.source, "claimVault", [], at)) === c.vault
          && address.parse(await readAt(c.vault, "asset", [], at)) === c.sy
          && await readAt(c.vault, "decimals", [], at) === 19n
          && await readAt(c.sy, "decimals", [], at) === 9n, "source phase asset or units differ");
      }
      const frames: z.infer<typeof callFrame>[] = [];
      const visit = (raw: unknown): void => {
        const frame = callFrame.parse(raw);
        requireEvidence(frame.error === undefined, "failed source trace");
        frames.push(frame);
        for (const child of frame.calls) visit(child);
      };
      visit(await provider.send("debug_traceTransaction", [m.transactionHash, { tracer: "callTracer" }]));
      const root = frames[0];
      const output = stakingClaim.encodeFunctionResult("withdrawClaim", [m.receivedSy]);
      const redeemData = stakingClaim.encodeFunctionData("redeem", [m.redeemedVaultShares, wallet, c.source]);
      const redeems = frames.filter((f) => f.type === "CALL" && f.from === c.source
        && f.to === c.vault && f.input === redeemData && f.output === output);
      requireEvidence(root?.type === "CALL" && root.from === wallet && root.to === c.source
        && root.input === data && root.output === output && redeems.length === 1, "actual return or vault recipient differs");
      for (const event of mined.logs) {
        requireEvidence(event.transactionHash === m.transactionHash && event.blockHash === m.blockHash
          && event.blockNumber === header.number && BigInt(event.transactionIndex) === 0n, "noncanonical log");
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
      const before = await books(priorTag);
      const after = await books(tag);
      requireEvidence(before.weight - after.weight === BigInt(m.consumedWeight)
        && before.supply - after.supply === BigInt(m.consumedWeight)
        && before.shares - after.shares === BigInt(m.redeemedVaultShares)
        && before.vaultSupply - after.vaultSupply === BigInt(m.redeemedVaultShares)
        && after.sy - before.sy === BigInt(m.receivedSy)
        && before.vaultSy - after.vaultSy === BigInt(m.receivedSy)
        && before.sySupply === after.sySupply, "actual source weight vault or measured SY delta differs");
      requireEvidence(after.weight >= BigInt(c.review.unrelatedWeightFloor)
        && before.sy >= BigInt(c.review.unrelatedSyFloor), "excluded unrelated budget was consumed");
      requireEvidence(block.parse(await provider.send("eth_getBlockByNumber", [tag, false])).hash === header.hash,
        "preparation block changed during authentication");
    }
    const consumed = z.bigint().parse(surrender.decodeFunctionResult("weightedSySurrender",
      hex.parse(await provider.send("eth_call", [{ to: input.domain.proxy,
        data: surrender.encodeFunctionData("weightedSySurrender", [row.original.originalId]) }, "latest"])))[0][0]);
    const q0 = BigInt(row.original.originalUnits);
    requireEvidence(consumed <= q0, "already consumed SY exceeds certified original");
    const previous = budgets.get(wallet) ?? { historical: 0n, current: 0n, floor: 0n, sy: c.sy };
    const excluded = BigInt(c.review.unrelatedSyFloor);
    budgets.set(wallet, { historical: previous.historical + q0, current: previous.current + q0 - consumed,
      floor: previous.floor > excluded ? previous.floor : excluded, sy: c.sy });
  }
  for (const [wallet, budget] of budgets) {
    const historical = z.bigint().parse(await readAt(budget.sy, "balanceOf", [wallet],
      `0x${BigInt(input.domain.blockNumber).toString(16)}`));
    const current = z.bigint().parse(await readAt(budget.sy, "balanceOf", [wallet], "latest"));
    requireEvidence(historical >= budget.historical + budget.floor && current >= budget.current + budget.floor,
      "complete measured descendants are no longer controlled or excluded SY was spent");
  }
  if (input.weightedSy.some((row) => row.claimedOrigin)) {
    // Loading never deletes an origin. A later manifest must retain the complete
    // configured SY census, so omitting an earlier original cannot hide its members.
    const configured = new Interface([
      "event WeightedSyEntitlementConfigured(bytes32 indexed originalId,bytes32 indexed configurationId,address indexed originalWallet,uint256 originalUnits,uint256 credit)",
    ]);
    const event = configured.getEvent("WeightedSyEntitlementConfigured");
    requireEvidence(event !== null, "missing configuration event ABI");
    if (snapshotBlock === undefined) throw new PreparationError("PROVENANCE", "missing authenticated capture block");
    const observed = z.array(log).parse(await provider.send("eth_getLogs", [{
      address: input.domain.proxy, fromBlock: `0x${snapshotBlock.toString(16)}`, toBlock: "latest",
      topics: [event?.topicHash],
    }]));
    for (const entry of observed) {
      const decoded = configured.parseLog({ topics: [...entry.topics], data: entry.data });
      requireEvidence(input.weightedSy.some((row) => row.original.originalId === decoded?.args[0]),
        "previously configured SY origin omitted from complete census");
      requireEvidence(block.parse(await provider.send("eth_getBlockByNumber", [entry.blockNumber, false])).hash === entry.blockHash,
        "noncanonical prior configuration");
    }
  }
}
