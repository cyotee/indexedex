import { isDeepStrictEqual } from "node:util";
import { Interface } from "/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-30-recovery-receipts/node_modules/ethers/lib.esm/index.js";
import { associationConflicts } from "/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-30-recovery-receipts/scripts/recovery/dtf-migration/receipt-association.ts";
import { intake, json, save, OUT, W, SD, F, ZERO, ARCH, V28, V31, check, sha } from "./inputs.mjs";

const s = await intake(), archive = await json(`${OUT}/archive.json`);
const abi = new Interface(s.wa[F].abi);
const claimTopic = abi.getEvent("BondClaimed").topicHash, transferTopic = abi.getEvent("Transfer").topicHash;
const addr = topic => `0x${topic.slice(-40)}`;
const located = (logs, predicate) => logs.map((log, receiptArrayIndex) => ({ log, receiptArrayIndex })).filter(x => predicate(x.log));
const entries = s.refs.map(ref => {
  const resultIndex = archive.results.findIndex(r => r.tx === ref.tx), a = archive.results[resultIndex];
  if (!a?.observed) return { ...ref, disposition: "unavailable", principal: null, rewards: null, gaps: ["transaction-or-receipt-unavailable"] };
  const o = a.observed, route = archive.routes.find(r => r.tx === ref.tx);
  const conflicts = [...a.conflicts, ...associationConflicts(ref.tx, o)];
  if (!isDeepStrictEqual(o.byHash, o.byNumber)) conflicts.push("complete-canonical-block");
  const logs = o.receipt.logs;
  const claims = located(logs, l => l.address === W && l.topics[0] === claimTopic
    && l.topics.length === 3 && BigInt(l.topics[1]).toString() === ref.tokenId && /^0x[0-9a-f]{128}$/.test(l.data))
    .map(x => { const p = abi.parseLog(x.log); return { ...x, tokenId: p.args[0].toString(),
      recipient: p.args[1].toLowerCase(), principal: p.args[2].toString(), rewards: p.args[3].toString() }; });
  const retirements = located(logs, l => l.address === W && l.topics[0] === transferTopic
    && l.topics.length === 4 && l.data === "0x" && BigInt(l.topics[2]) === 0n && BigInt(l.topics[3]).toString() === ref.tokenId)
    .map(x => ({ ...x, from: addr(x.log.topics[1]), to: ZERO, tokenId: ref.tokenId }));
  const allNative9Transfers = located(logs, l => l.address === SD && l.topics[0] === transferTopic
    && l.topics.length === 3 && /^0x[0-9a-f]{64}$/.test(l.data))
    .map(x => ({ ...x, from: addr(x.log.topics[1]), to: addr(x.log.topics[2]), amount: BigInt(x.log.data).toString(), decimals: 9 }));
  const semantic = conflicts.length === 0 && route?.compatible && claims.length === 1;
  const claim = claims.length === 1 ? claims[0] : null;
  const total = semantic ? (BigInt(claim.principal) + BigInt(claim.rewards)).toString() : null;
  const payouts = total === null ? [] : allNative9Transfers.filter(x => x.from === W && x.to === claim.recipient && x.amount === total);
  const exactPayout = total === "0" ? allNative9Transfers.every(x => x.from !== W || x.to !== claim.recipient) : payouts.length === 1;
  const row = s.rows.find(r => r.locator === ref.locator), f = row.fields;
  const historical = s.current.rows.find(r => r.locator === ref.locator);
  const mintResult = s.old28.results.findIndex(x => x.tx === f.purchase_tx);
  check(mintResult >= 0, "purchase archive result");
  const purchase = s.old28.results[mintResult];
  const mints = located(purchase.observed.receipt.logs, l => l.address === W && l.topics[0] === transferTopic
    && l.topics.length === 4 && BigInt(l.topics[1]) === 0n && BigInt(l.topics[3]).toString() === ref.tokenId);
  check(mints.length === 1 && addr(mints[0].log.topics[2]) === f.purchase_recipient, `mint ${ref.tokenId}`);
  const purchaseEvents = located(purchase.observed.receipt.logs, l => l.address === W && l.topics[0] === abi.getEvent("BondPurchased").topicHash
    && BigInt(l.topics[1]).toString() === ref.tokenId);
  check(purchaseEvents.length === 1, "purchase event");
  const terms = abi.parseLog(purchaseEvents[0].log).args;
  check(terms[2].toString() === f.original_principal_detf_raw && terms[3].toString() === f.start_timestamp
    && terms[4].toString() === f.duration_seconds, `purchase terms ${ref.tokenId}`);
  const gaps = [];
  if (conflicts.length) gaps.push("canonical-conflict");
  if (!route?.compatible) gaps.push("historical-runtime-or-route-incompatible");
  if (claims.length !== 1) gaps.push(`named-claim-event-count:${claims.length}`);
  if (!exactPayout) gaps.push("payout-absent-or-ambiguous");
  // Calldata is context only. No indirect/inner invocation is authenticated here.
  const context = o.transaction;
  return { ...ref, disposition: semantic && exactPayout ? "claim-split-and-exact-payout-confirmed" : "reviewed-with-gaps",
    archiveResultIndex: resultIndex, provenance: a.provenance, block: BigInt(context.blockNumber).toString(),
    transactionIndex: BigInt(context.transactionIndex).toString(), blockHash: context.blockHash,
    context: { from: context.from, to: context.to, valueWei: BigInt(context.value).toString(), calldata: context.input,
      interpretation: "outer transaction context only; not original payer or proof of inner invocation" },
    originalFields: f, historicalMint: { archive: `${V28}/actual/archive.json`, resultIndex: mintResult,
      mint: mints[0], purchase: purchaseEvents[0], requestIds: purchase.requestIds, purchaseRecipient: f.purchase_recipient,
      purchaseOuterFrom: purchase.observed.transaction.from, originalPayer: null },
    current: { archive: `${V31}/observations.json`, locator: ref.locator, pin: s.current.pin,
      observations: historical.observations },
    schemaCompatible: Boolean(route?.compatible), conflicts, claims, retirements, allNative9Transfers,
    payoutMatches: payouts, actualClaimRecipient: claim?.recipient ?? null,
    principal: semantic ? claim.principal : null, rewards: semantic ? claim.rewards : null, payoutTotal: total,
    units: "native9 DETF-equivalent principal/rewards paid as native9 sDETF", gaps,
    currentDescendantControl: null, completeHistory: null, migrationCompensationDeduction: null, E0: null, D0: null, C0: null };
});
const originals = s.rows.map(row => {
  const f = row.fields, claims = entries.filter(e => e.locator === row.locator), current = s.current.rows.find(r => r.locator === row.locator);
  const splitAvailable = claims.every(e => e.principal !== null && e.rewards !== null);
  const principal = splitAvailable ? claims.reduce((n, e) => n + BigInt(e.principal), 0n).toString() : null;
  const rewards = splitAvailable ? claims.reduce((n, e) => n + BigInt(e.rewards), 0n).toString() : null;
  const position = current.observations.positionOf;
  const pc = position.status === "success" ? position.value.claimedPrincipal : null;
  const pr = pc === null ? null : (BigInt(position.value.principal) - BigInt(pc)).toString();
  return { locator: row.locator, collection: W, tokenId: f.token_id, originalFields: f, namedClaimCount: claims.length,
    namedPrincipal: principal, namedRewards: rewards, frozenPrincipalClaimed: f.claimed_principal_detf_raw,
    frozenRewardsClaimed: f.rewards_claimed_sdetf_raw, frozenRemaining: f.remaining_principal_detf_raw,
    frozenMinusNamedPrincipal: principal === null ? null : (BigInt(f.claimed_principal_detf_raw) - BigInt(principal)).toString(),
    frozenMinusNamedRewards: rewards === null ? null : (BigInt(f.rewards_claimed_sdetf_raw) - BigInt(rewards)).toString(),
    currentPin: s.current.pin, currentOwner: current.observations.ownerOf, currentPosition: position,
    currentClaimedPrincipal: pc, currentRemainingPrincipal: pr,
    currentMinusFrozenPrincipal: pc === null ? null : (BigInt(pc) - BigInt(f.claimed_principal_detf_raw)).toString(),
    currentMinusNamedPrincipal: pc === null || principal === null ? null : (BigInt(pc) - BigInt(principal)).toString(),
    currentCumulativeRewards: null, currentRewardsMeaning: "no cumulative claimed-rewards field; preview rewardsDue is unpaid rewards, not cumulative payouts",
    retirementEvidence: claims.flatMap(e => e.retirements ?? []),
    coverage: "named-list arithmetic only; even equality is not an exhaustive claim-history census",
    descendants: { control: null, balance: null, provenance: "no descendant census or control query; payout is not a second original entitlement" },
    originalPayer: null, E0: null, D0: null, eligibility: null, priorMigrationCompensation: null, C0: null, deduction: null };
});
const target = "contracts/vaults/detf/common/bondNft/DETFFundedBondTarget.sol";
const math = "contracts/vaults/detf/common/core/DETFFundedStakingMath.sol";
const repo = "contracts/vaults/detf/common/bondNft/DETFFundedBondRepo.sol";
const sourceRows = [target, math, repo, "contracts/interfaces/IDetfBondNFT.sol", "contracts/vaults/detf/common/bondNft/DETFNFTVaultFacet.sol"]
  .map(path => ({ archive: `${ARCH}/weighted/probe.sources.json`, contract: F, path,
    contentSha256: sha(Buffer.from(s.wa[F].sources[path].content)), content: s.wa[F].sources[path].content }));
const SF = "0xb7581fe833a2b2380dd786b345d61ffb734d36eb";
for (const path of ["contracts/vaults/detf/common/claimToken/StakedDETFTarget.sol", "contracts/vaults/detf/common/claimToken/DETFFundedStakingRepo.sol"]) {
  const content = s.wa[SF].sources[path].content;
  sourceRows.push({ archive: `${ARCH}/weighted/probe.sources.json`, contract: SF, path, contentSha256: sha(Buffer.from(content)), content });
}
await save("schema-bindings.json", { abi: s.wa[F].abi, payoutAbi: s.wa[SF].abi, sources: sourceRows,
  invariant: "Inspected lifecycle opens claimedPrincipal=0; _claim adds nonnegative principalDue; retirement deletes the position. Equality at two snapshots alone does not prove monotonicity or full-history route coverage.",
  bounds: "runtime/routing sampled at exact named claim blocks, with accepted phase31 current source bindings; no transaction-prefix execution or all-history build claim" });
await save("reconciliation.json", { status: "NON-ISSUABLE-NAMED-EVIDENCE", entries, originals,
  references: entries.length, confirmed: entries.filter(e => e.disposition === "claim-split-and-exact-payout-confirmed").length,
  unknowns: "Original payer/E0/D0, full history, descendant current control, prior migration delivery, eligibility, C0 and deduction remain unknown." });
console.log(JSON.stringify({ references: entries.length, confirmed: entries.filter(e => e.gaps.length === 0).length,
  mismatches: originals.filter(o => o.frozenMinusNamedPrincipal !== "0" || o.frozenMinusNamedRewards !== "0").map(o => o.tokenId) }));
