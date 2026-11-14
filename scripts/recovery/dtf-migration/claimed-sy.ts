import { Interface, keccak256, toUtf8Bytes } from "ethers";
import type { JsonRpcProvider } from "ethers";
import { z } from "zod";
import { canonical } from "./provenance.js";
import { address, hex, PreparationError } from "./schema.js";
import type { ClaimedSyCertificate, Domain, PreparationInput, WeightedSyOriginal } from "./schema.js";
import { stakingClaim } from "./claimed-sy-source.js";
import { authenticateClaimedSyMember, block, receipt, log } from "./claimed-sy-member.js";
import { requireClaimEvidence as requireEvidence } from "./claimed-sy-witness.js";
export { stakingSource, stakingClaim } from "./claimed-sy-source.js";

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
    switch (c.kind) {
      case "complete-original-token-staking":
        requireEvidence(r.originalWeight === undefined, "complete original cannot override its weight basis");
        break;
      case "complete-remaining-token-staking":
        requireEvidence(r.originalWeight !== undefined
          && BigInt(r.eligibleWeight) <= BigInt(r.originalWeight), "remaining weight exceeds or lacks full original weight");
        break;
      default: {
        const kind: never = c.kind;
        throw new PreparationError("PROVENANCE", kind);
      }
    }
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
  const budgets = new Map<string, { historical: bigint; floor: bigint; sy: string }>();
  let snapshotBlock: bigint | undefined;
  const surrender = new Interface([
    "function weightedSySurrender(bytes32) view returns((uint256 consumedUnits,uint256 deliveredCredit,uint256 remainingUnits,uint256 remainingCredit))",
  ]);
  const readAt = async (target: string, method: string, args: readonly unknown[], tag: string) =>
    stakingClaim.decodeFunctionResult(method, hex.parse(await provider.send("eth_call", [
      { to: target, data: stakingClaim.encodeFunctionData(method, args) }, tag,
    ])))[0];
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
      await authenticateClaimedSyMember(provider, c, m);
    }
    const consumed = z.bigint().parse(surrender.decodeFunctionResult("weightedSySurrender",
      hex.parse(await provider.send("eth_call", [{ to: input.domain.proxy,
        data: surrender.encodeFunctionData("weightedSySurrender", [row.original.originalId]) }, "latest"])))[0][0]);
    const q0 = BigInt(row.original.originalUnits);
    requireEvidence(consumed <= q0, "already consumed SY exceeds certified original");
    const previous = budgets.get(wallet) ?? { historical: 0n, floor: 0n, sy: c.sy };
    const excluded = BigInt(c.review.unrelatedSyFloor);
    budgets.set(wallet, { historical: previous.historical + q0,
      floor: previous.floor > excluded ? previous.floor : excluded, sy: c.sy });
  }
  for (const [wallet, budget] of budgets) {
    const historical = z.bigint().parse(await readAt(budget.sy, "balanceOf", [wallet],
      `0x${BigInt(input.domain.blockNumber).toString(16)}`));
    // Certify preparation at its pinned block. Later transfers neither invalidate
    // configuration nor veto owner activation; surrender enforces actual custody.
    requireEvidence(historical >= budget.historical + budget.floor,
      "complete measured descendants or excluded floors were not controlled at preparation");
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
