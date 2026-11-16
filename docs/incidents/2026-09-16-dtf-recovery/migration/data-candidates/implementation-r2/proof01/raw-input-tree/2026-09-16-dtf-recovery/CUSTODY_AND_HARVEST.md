# Held assets, migration custody and DTF harvests

Policy revision: held-assets-no-upfront-credit-20261108. The user directed that current tokens/NFTs be deposited so migration can harvest DTF over time, and that currently held positions be removed from pre-exploit snapshot compensation. This document records that accounting rule. No contract, custody deposit, harvest, approval or issuance is implemented or executed here.

## Two separate accounting tracks

1. **Potential upfront loss credit:** start from snapshot exposure, exclude the full attributable snapshot portion represented by current holdings or descendant claims, and subtract separately attributed recoveries from other portions. Unresolved portions stay blocked. Only an approved remainder can participate in a future new-bond allocation.
2. **Custody and harvesting:** record observed current tokens, claims and exact NFT IDs; validate a way to place them under migration control; record assets actually received; harvest through supported routes over time; record actual DTF receipts. Do not issue new DETF in advance for those held assets.

Depositing an old token or NFT does **not** restore its excluded snapshot credit. A lock, a failed exit today, a low market price or a pending maturity also does not automatically turn that live position into an upfront loss. Future use of harvested DTF (program backing, beneficiary distribution or a later funded allocation) remains a separate decision; this revision promises none of those choices.

## Snapshot-basis exclusion, not current-price subtraction

The historical exposure baseline is preserved in positions.csv. The adjustment is in held-exclusions.csv and account-ledger.csv. For illustration only: if a 100-unit snapshot position has 60 units provably still represented by holdings, those 60 receive zero upfront credit even after deposit. The remaining 40 are not automatically eligible; trace conversions, transfers and economic recoveries first. If 20 of those other units are proven recovered under a consistent valuation, only the remaining 20 can be considered, subject to the outstanding checks.

Use the **same snapshot reference** for V and H. Do not subtract the current depressed value of a live asset from its earlier value and call the difference eligible while retaining the same asset for harvest. If a held portion is harvested, keep its snapshot exclusion assigned to the harvesting track rather than reducing H and reviving upfront credit. Do not count its proceeds a second time in R against another portion.

## What the computed exclusion proves

The frozen weighted cutoff is block 108944663, November 8 at 04:08:21 UTC. No fresh chain scan was made for this revision. Earlier CP receipt amounts remain the separately labelled latest-state observations on November 8.

- Liquid/SY retained lower bound: min(current observed units, max(0, snapshot units - all subsequent outgoing units)). Self-transfers are ignored. Inbounds do not increase the snapshot. Convert retained SY using the frozen snapshot backing ratio.
- sDETF retained lower bound: max(0, snapshot gons - all subsequent outgoing gons). Each outgoing Transfer uses the immediately preceding RewardsFunded index; self-transfers are ignored. Convert the retained gons at the snapshot index, not the later index.
- Legacy TokenStaking: remaining original weight, converted using the snapshot claim-vault and SY ratios. A weight is a claim, not proof of a directly transferable ERC-20.
- Funded NFT: exact NFT ID, snapshot gons minus post-incident claim gons. A claim is matched to the actual sDETF transfer and its event-time index. Fully burned NFTs have no held NFT overlap; their descendants and economic recoveries still need tracing. Partial claims leave the remaining NFT portion excluded; moved sDETF is not assumed lost.
- Earlier CP: current token/receipt/LP-NFT positions are in the no-upfront-credit inventory; their snapshot-reference valuation is unresolved. Do not convert LP shares into modern fixed DETF principal.

These are provable same-form lower bounds, not FIFO/LIFO tax or compensation rules. Transfers, sold-and-rebought lots, SY conversions and claimed-NFT proceeds can make additional exposure still held elsewhere. Therefore a zero matched overlap means **no proven overlap by this method**, not zero current holdings or an eligible loss. No credit issues on the unmatched remainder.

## Custody inventory and future receipt requirements

custody-inventory.csv has 403 observed holdings (374 weighted; 29 earlier CP). An inventory row is a candidate for collection, not proof of an accepted deposit. It includes post-attack holdings with no automatic snapshot eligibility. All upfront-credit-for-holding fields are zero; all operational receipt fields are empty because custody has not occurred.

A later custody implementation must establish, for every accepted source:

- source contract, actual owner/approved sender, destination custodian, beneficiary, exact NFT ID or token amount, and source generation;
- verified balance/ownership change and deposit transaction/log identity, not merely an approval or receipt-token mint;
- links to the snapshot exclusion and any descendant positions, so multiple representations do not create multiple claims;
- per-source principal and reward rights, available public claim routes, maturity/disable constraints and any unsupported paths;
- the fate of a returned asset: return/release must be recorded, revoke any duplicate custody receipt or pending claim, and never erase the already assigned held-position exclusion by itself.

No receipt transferability or beneficiary-rights policy is silently chosen here. Custody registration requires authenticated ownership and attribution. In particular a transferred NFT cannot generate separate compensation for its historical owner and new owner.

## Harvest accounting

For each actual harvest, preserve source holding ID, source NFT ID where applicable, harvest transaction and log indexes, DTF address/decimals, recipient, principal-versus-reward classification when provable, raw DTF received, and remaining source position. Use operation-local DTF receipts and balance deltas; an emitted claim amount, preview, nominal DETF quantity or mint of new DETF is not DTF received.

Use transaction hash plus log index and asset as a unique receipt key. If one transaction harvests several holdings, the per-holding allocations must sum to the received DTF exactly; do not assign the full transaction output to each holding. Principal recovered and funded rewards remain separate when the source supplies that distinction; otherwise classification stays unresolved.

New sDETF received from a bond claim is still an intermediate asset. Follow any later conversion to DTF and record it once. Never log both the bond's sDETF claim and the resulting DTF transfer as two external recoveries. No assumed yield, harvesting schedule, payout, or successful exit is recorded in advance.

Before any award: refresh post-cutoff holdings and recoveries, register custody, finish attribution, approve valuations and the funded allocation, and prove that no snapshot portion appears both in upfront new bonds and in an independently claimable legacy position. The existing new-bond amounts remain unknown and every account remains non-issuable.
