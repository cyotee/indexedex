import { id } from "ethers";
import { field } from "./candidate-input.js";
import type { TableRow } from "./candidate-input.js";
import { claimSource, earlier, legacy, sy } from "./receipt-input.js";
import type { ReceiptReference } from "./receipt-input.js";
import type { Associated, Log } from "./receipt-association.js";
import { associationConflicts } from "./receipt-association.js";

const transferTopic = id("Transfer(address,address,uint256)");
const bondTopic = id("BondPurchased(uint256,address,uint256,uint256,uint256)");
const lockTopic = id("NewLock(uint256,address,uint256,uint256,uint256)");
const claimTopic = id("ClaimWithdrawn(address,uint256,uint256)");
const withdrawSelector = id("withdrawClaim(uint256)").slice(0, 10);
const addressWord = /^0x0{24}[0-9a-f]{40}$/;
function words(data: string): readonly string[] {
  return /^0x(?:[0-9a-f]{64})*$/.test(data) ? data.slice(2).match(/.{64}/g) ?? [] : [];
}
function indexedAddress(topic: string | undefined): string | null {
  return topic && addressWord.test(topic) ? `0x${topic.slice(-40)}` : null;
}
type Transfer = {
  readonly address: string; readonly from: string; readonly to: string;
  readonly logIndex: string; readonly amount: string | null; readonly tokenId: string | null;
};
function transfers(logs: readonly Log[]): readonly Transfer[] {
  return logs.flatMap<Transfer>((l) => {
    if (l.topics[0] !== transferTopic) return [];
    const from = indexedAddress(l.topics[1]), to = indexedAddress(l.topics[2]);
    const data = words(l.data);
    if (from === null || to === null) return [];
    if (l.topics.length === 3 && data.length === 1 && data[0]) return [{
      address: l.address, from, to, logIndex: BigInt(l.logIndex).toString(),
      amount: BigInt(`0x${data[0]}`).toString(), tokenId: null,
    }];
    const token = l.topics[3];
    if (l.topics.length === 4 && l.data === "0x" && token) return [{
      address: l.address, from, to, logIndex: BigInt(l.logIndex).toString(),
      amount: null, tokenId: BigInt(token).toString(),
    }];
    return [];
  });
}
function savedTransferConflicts(rows: readonly TableRow[], observed: Associated, decoded: readonly Transfer[]): readonly string[] {
  return rows.flatMap((r) => {
    const match = decoded.filter((t) => t.address === field(r, "asset").toLowerCase()
      && t.logIndex === field(r, "log_index"));
    const t = match[0];
    if (match.length !== 1 || !t || t.from !== field(r, "from").toLowerCase()
      || t.to !== field(r, "to").toLowerCase()
      || (t.amount ?? "") !== field(r, "amount_raw") || (t.tokenId ?? "") !== field(r, "token_id")
      || BigInt(observed.transaction.blockNumber).toString() !== field(r, "block")
      || BigInt(observed.transaction.transactionIndex).toString() !== field(r, "transaction_index")) {
      return [`saved-transfer-conflict:${r.locator}`];
    }
    return [];
  });
}

export function reconcileReference(ref: ReceiptReference, observed: Associated, sharedReferences: number) {
  const { transaction: tx, receipt: receipt_ } = observed;
  const decoded = transfers(receipt_.logs);
  const conflicts = [...associationConflicts(ref.tx, observed),
    ...savedTransferConflicts(ref.expectedTransfers, observed, decoded)];
  const transactionContext = { from: tx.from, to: tx.to, value: BigInt(tx.value).toString(), calldata: tx.input,
    block: BigInt(tx.blockNumber).toString(), transactionIndex: BigInt(tx.transactionIndex).toString() };
  const base = { locator: ref.row.locator, kind: ref.kind, tx: ref.tx, historicalFields: ref.row.fields,
    transactionContext, savedTransferLocators: ref.expectedTransfers.map((r) => r.locator) };
  switch (ref.kind) {
    case "nft": {
      const n = ref.nft, target = n.collection === legacy.weightedNft ? legacy.weighted : earlier;
      const mints = decoded.filter((t) => t.address === n.collection && t.from === legacy.zero);
      const mint = mints.filter((t) => t.tokenId === n.tokenId && t.to === n.recipientObservation);
      if (mint.length !== 1) conflicts.push("mint-recipient-or-id");
      const expectedTopic = n.collection === legacy.weightedNft ? bondTopic : lockTopic;
      const events = receipt_.logs.filter((l) => l.address === n.collection && l.topics[0] === expectedTopic);
      const sourceEvents = events.map((l) => ({ logIndex: BigInt(l.logIndex).toString(),
        tokenId: l.topics[1] ? BigInt(l.topics[1]).toString() : null, recipient: indexedAddress(l.topics[2]),
        values: words(l.data).map((w) => BigInt(`0x${w}`).toString()), topics: l.topics }));
      const matches = sourceEvents.filter((e) => e.tokenId === n.tokenId && e.recipient === n.recipientObservation
        && e.topics.length === 3 && e.values.length === 3 && e.values[0] === n.basis.value);
      if (matches.length !== 1) conflicts.push("source-purchase-event-or-basis");
      const expectedBlock = ref.row.fields["purchase_block"];
      if (expectedBlock !== undefined && transactionContext.block !== expectedBlock) conflicts.push("purchase-block");
      const assets = [legacy.dtf, legacy.weth].map((asset) => {
        const inbound = decoded.filter((t) => t.address === asset && t.to === target && t.amount !== null);
        const direct = inbound.filter((t) => t.from === n.recipientObservation);
        const routed = inbound.filter((t) => t.from !== n.recipientObservation);
        const sum = (items: readonly Transfer[]) => items.reduce((v, t) => v + BigInt(t.amount ?? "0"), 0n).toString();
        const observedDirect = sum(direct), observedRouted = sum(routed);
        const expected = n.directInputs.find((i) => i.asset === asset)?.observedRaw;
        if (expected !== null && expected !== undefined && observedDirect !== expected) conflicts.push(`direct-input:${asset}`);
        if (n.collection === legacy.earlierNft && asset === legacy.dtf && n.routedDtfRaw !== null
          && observedRouted !== n.routedDtfRaw) conflicts.push("routed-dtf");
        return { asset, observedDirect, observedRouted, direct, routed };
      });
      const ambiguous = sharedReferences !== 1 || mints.length !== 1 || events.length !== 1;
      if (ambiguous) conflicts.push("shared-or-multiaction-purchase");
      if (tx.to !== target || tx.from !== n.recipientObservation) conflicts.push("indirect-purchase-or-different-caller");
      return { ...base, conflicts, mints, sourceEvents,
        assets: assets.map((a) => ({ ...a, attributableDirect: conflicts.length ? null : a.observedDirect })),
        qualifications: ["gross-transfers-not-net-contribution", "native-refunds-and-routing-not-proved",
          "mint-and-event-not-eligibility", "historical-owner-not-current-control",
          "event-layout-from-local-interface-not-authenticated-deployment-build"] };
    }
    case "claim": {
      const sourceLogs = receipt_.logs.filter((l) => l.address === claimSource);
      const syLogs = receipt_.logs.filter((l) => l.address === sy);
      const events = sourceLogs.filter((l) => l.topics[0] === claimTopic);
      const claims = events.map((l) => ({ logIndex: BigInt(l.logIndex).toString(), user: indexedAddress(l.topics[1]),
        values: words(l.data).map((w) => BigInt(`0x${w}`).toString()), topics: l.topics }));
      if (claims.filter((c) => c.user === ref.recipient && c.values[0] === ref.principal && c.values[1] === ref.output
        && c.topics.length === 2 && c.values.length === 2).length !== 1) conflicts.push("source-claim-event");
      const outputs = decoded.filter((t) => t.address === sy && t.to === ref.recipient && t.amount === ref.output);
      if (outputs.length !== 1 || ref.expectedTransfers.length !== 1) conflicts.push("exact-known-output");
      if (transactionContext.block !== ref.expectedBlock) conflicts.push("claim-block");
      const direct = tx.to === claimSource && tx.input.slice(0, 10) === withdrawSelector && tx.input.length === 74
        && tx.value === "0x0";
      const decodedDirectWeight = direct ? BigInt(`0x${tx.input.slice(10)}`).toString() : null;
      if (!direct || tx.from !== ref.recipient) conflicts.push("indirect-or-unexpected-claim-call");
      if (direct && decodedDirectWeight !== ref.principal) conflicts.push("direct-claim-weight");
      if (claims.length !== 1 || sharedReferences !== 1) conflicts.push("multiaction-claim");
      return { ...base, conflicts, direct, decodedDirectWeight, sourceLogs, syLogs, claims, outputs,
        qualifications: ["known-output-only-not-full-W0-or-Q0", "all-prior-claims-unknown",
          "prior-compensation-unknown-not-zero", "no-credit-created", "source-event-layout-not-build-pedigree"] };
    }
  }
}
