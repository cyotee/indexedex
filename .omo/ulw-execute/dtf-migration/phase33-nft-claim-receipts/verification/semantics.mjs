import { id } from "/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-30-recovery-receipts/node_modules/ethers/lib.esm/index.js";
import { W, SD, equal, requireEvidence } from "./evidence.mjs";

export const TRANSFER = id("Transfer(address,address,uint256)");
export const CLAIM = id("BondClaimed(uint256,address,uint256,uint256)");
export const PURCHASE = id("BondPurchased(uint256,address,uint256,uint256,uint256)");
export function addressWord(word) {
  requireEvidence(/^0x0{24}[0-9a-f]{40}$/.test(word), "ABI address padding");
  return `0x${word.slice(26)}`;
}
export function words(data, count) {
  requireEvidence(new RegExp(`^0x[0-9a-f]{${64 * count}}$`).test(data), "static ABI data width");
  return data.slice(2).match(/.{64}/g).map(x => BigInt(`0x${x}`).toString());
}
export const located = logs => logs.map((log, receiptArrayIndex) => ({ log, receiptArrayIndex, logIndex: BigInt(log.logIndex).toString() }));
export function claimEvidence(ref, observed) {
  const logs = located(observed.receipt.logs);
  const claims = logs.filter(x => x.log.address === W && x.log.topics[0] === CLAIM);
  requireEvidence(claims.length === 1, "single actual claim event");
  const claim = claims[0];
  requireEvidence(claim.log.topics.length === 3, "claim topic count");
  equal(BigInt(claim.log.topics[1]).toString(), ref.tokenId, "named token identity");
  const recipient = addressWord(claim.log.topics[2]);
  const [principal, rewards] = words(claim.log.data, 2);
  const total = (BigInt(principal) + BigInt(rewards)).toString();
  const native9Transfers = logs.filter(x => x.log.address === SD && x.log.topics[0] === TRANSFER).map(x => {
    requireEvidence(x.log.topics.length === 3, "sDETF Transfer topic count");
    return { ...x, from: addressWord(x.log.topics[1]), to: addressWord(x.log.topics[2]), amount: words(x.log.data, 1)[0], decimals: 9 };
  });
  const payouts = native9Transfers.filter(x => x.from === W && x.to === recipient && x.amount === total);
  requireEvidence(total === "0" ? payouts.length === 0 : payouts.length === 1, "unique exact P+R payout");
  requireEvidence(payouts.every(p => p.receiptArrayIndex < claim.receiptArrayIndex), "source payout/event order");
  const nftTransfers = logs.filter(x => x.log.address === W && x.log.topics[0] === TRANSFER).map(x => {
    requireEvidence(x.log.topics.length === 4 && x.log.data === "0x", "NFT Transfer schema");
    return { ...x, from: addressWord(x.log.topics[1]), to: addressWord(x.log.topics[2]), tokenId: BigInt(x.log.topics[3]).toString() };
  });
  const retirements = nftTransfers.filter(x => x.tokenId === ref.tokenId && BigInt(x.log.topics[2]) === 0n);
  requireEvidence(retirements.every(x => x.receiptArrayIndex < claim.receiptArrayIndex), "retirement before claim event");
  return { ...ref, principal, rewards, total, recipient, claim, payouts, retirements, nftTransfers, native9Transfers,
    outer: observed.transaction, allLogs: observed.receipt.logs, currentDescendantControl: null,
    originalPayer: null, E0: null, D0: null, C0: null, eligibility: null, compensationDeduction: null, completeHistory: null };
}
export function mintEvidence(row, entry) {
  const f = row.fields, logs = located(entry.observed.receipt.logs);
  const mints = logs.filter(x => x.log.address === W && x.log.topics[0] === TRANSFER
    && x.log.topics.length === 4 && BigInt(x.log.topics[1]) === 0n && BigInt(x.log.topics[3]).toString() === f.token_id);
  requireEvidence(mints.length === 1 && mints[0].log.data === "0x", "one named mint");
  equal(addressWord(mints[0].log.topics[2]), f.purchase_recipient, "mint recipient");
  const purchases = logs.filter(x => x.log.address === W && x.log.topics[0] === PURCHASE
    && x.log.topics.length === 3 && BigInt(x.log.topics[1]).toString() === f.token_id);
  requireEvidence(purchases.length === 1, "one named purchase");
  equal(addressWord(purchases[0].log.topics[2]), f.purchase_recipient, "purchase recipient");
  equal(words(purchases[0].log.data, 3), [f.original_principal_detf_raw, f.start_timestamp, f.duration_seconds], "purchase terms");
  equal(BigInt(entry.observed.transaction.blockNumber).toString(), f.purchase_block, "purchase block");
  return { mint: mints[0], purchase: purchases[0], requestIds: entry.requestIds, transaction: entry.tx,
    purchaseOuterFrom: entry.observed.transaction.from, originalEconomicPayer: null };
}
