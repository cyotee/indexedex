# Astra — partial reinvestment combined cross-review

2026-09-27. Read COMPLETE Grok (92 lines), MiniMax M3 (151) and Kimi K3 (48) ORIGINALS together as untrusted evidence. No peer cross-review read; originals unchanged. Assigned routing `openai/gpt-6-astra`, not provider attestation. This is the same preserved session.

## Agreement: record the process now

Pre-maturity dedicated reinvestment is selected—not pending another vote. It consumes requested **already-funded principal**, performs the normal incentive-free owned-reserve burn, and funds a **new bond** under its destination type's normal lock. Preserve the old NFT/tokenId, holder and native note; remaining funded principal/rewards and future native proceeds stay old. No native transfer/cancellation or second intended purchase on the old holder.

Correct v0.25's blanket full-collection gate at `25,165,610,797,849` and related R/O/A/tracker text. Retain the existing final-principal-release rule separately, subject to the forthcoming lock review; it cannot gate the newly selected pre-maturity operation. This does not waive authorization, purchase-epoch checking, actual funding, route support, settlement or limits.

## Attributed corrections

**MiniMax and Kimi — zero is not unset.** The explicit user meaning is **`unlockEpoch == 0` means assigned Pendle market maturity**. Reject their pending/unset/unlocked interpretations. Reject MiniMax's `purchaseEpoch > 0` eligibility sentinel and its invented ordering `purchaseEpoch < fullCollectionEpoch <= unlockEpoch`: snapshots and a release target are different quantities, and the zero maturity sentinel makes that ordering invalid.

**Grok — completion validity remains explicit.** Its `fullCollectionEpoch == 0` pending convention is also not selected. Do not use an epoch number alone as existence/completion proof. Maintain distinct semantic meanings for purchase snapshot, full-collection snapshot and unlock target; the engineer later specifies actual fields/layout and validity representation.

**MiniMax — do not subtract raw principal from shares.** `internalShares(old) - requested` mixes units. PRD `632–638` derives balances from held backing B and aggregate shares U. The position's raw-principal debit q requires a separately specified conservative share conversion and dust treatment at the settled ratio. Do not silently consume rewards or another position's rounding reserve. Grok's blanket “floor rounding” likewise does not specify every conversion direction safely.

**MiniMax — PkgArgs is not an asset allowlist.** §4.1 configures dependencies; it does not authorize `{NET,sNET,USDG,canonical LP}` as reinvestment outputs. Use existing directional route discovery and destination-bond acceptance. Canonical LP's native-depository payment role does not add a standard DETF output. Its proposed extra full-collection reinvestment endpoint and “latest epoch baseline per call” would add unselected routing/cadence behavior. Separate final withdrawal from dedicated reinvestment, not two invented reinvestment APIs.

**H01 is narrowed, not reopened.** Excess native proceeds are already selected as same-NFT funded principal. MiniMax's continuing general H01 uncertainty and Kimi's new special eligibility question must not recreate an unselected excess-principal class. Only genuine late timing and direct-donation distinctions remain.

**Grok — avoid an unconditional availability promise.** Removing a full-collection prerequisite does not prove a blocked native redeem can never coincide with blocked reinvestment: other required synchronization, valuation or funding dependencies can fail. Conversely, reinvesting previously funded principal must not unnecessarily invoke native redemption. This operation is not another native harvest.

**All-current-principal reinvestment is allowed.** It is not limited to q strictly less than current principal. If q consumes all current principal, future native rights and any remaining rewards still keep the old position alive. No retirement on zero principal alone. Destination bond identity is new; this does not require a new ERC721 contract deployment.

## Concrete amendment — proposed wording, selected process

> **Pre-maturity wrapped-principal reinvestment.** The authorized tokenId holder may reinvest a requested portion or all of its currently funded principal while the intended native note remains uncollected or maturing. Preserve the purchase-epoch-passed check, separately from full collection, and all other applicable checks; exact lock/check ordering remains under the announced type-specific review. No full-native-collection prerequisite or unnecessary native redemption is introduced for this operation.
>
> Debit only the old position's requested raw principal and corresponding staking entitlement under specified share-rounding rules; burn actual DETF with `quoteInput = actualDetfIn`, never a contraction bonus. Realize an existing discovery-supported asset accepted by the destination bond and fund a new bond under that type's normal lock. Retain the original NFT, holder, native note, remaining principal/rewards and future native proceeds. Zero current principal alone is not completion or retirement. All debits, reserve movements and new-bond funding revert together on failure.
>
> Keep purchase-epoch snapshot, full-collection checkpoint and type-specific unlock target semantically distinct. Unlock epoch zero denotes assigned Pendle market maturity. The old position's final-release rule remains separately recorded, subject to upcoming lock review. No new cadence, numeric lock, route, fee destination or gift classification is selected here.

## Accepted versus deferred

Record the process and H01/H03 progress now. Deferred: precise snapshot/check ordering, destination-type locks and reference-duration compatibility, final withdrawal/terminal late-gift handling, share-conversion/dust specification and execution evidence. No repeat approval of pre-maturity reinvestment is needed. High confidence on reconciliation; no gas, deployment or implementation proof claimed. No shell/RPC/tests/browser/code/config/delegation or external API claims; only this report written. Return to moderator.
