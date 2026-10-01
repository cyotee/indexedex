# Astra — holder-proxy combined cross-review

2026-09-27. Targeted continuation in the original Astra session. The COMPLETE Grok, MiniMax M3 and Kimi K3 originals were read together before the interruption and remain in context; no peer cross-review read. All originals remain unchanged.

## Retry outcome and roster limits

The ordinary read of the human-corrected **`contracts/fee/collector/FeeCollectorDFPkg.sol`** succeeded. Prior attempts at `contracts/fees/collector/FeeCollectorDFPkg.sol` returned `Research council: [RC_UNAVAILABLE] attribution or metadata unavailable; report the failure, do not bypass it`; those failures remain recorded. The corrected read does **not** diagnose why that guard response occurred. No alternate access method or identity substitution was used.

This completes **Astra's previously interrupted cross-review only**. It does not restart, authorize, or certify completion of the remaining roster. Assigned routing is `openai/gpt-6-astra`, not provider attestation.

## 1. Salt issue resolved by the human's standard-PkgArgs clarification

Direct evidence:

- `contracts/fee/collector/FeeCollectorDFPkg.sol:153–155`: `calcSalt(bytes memory pkgArgs)` returns **`abi.encode(pkgArgs)._hash()`**; `:163–165` returns arguments unchanged.
- `lib/crane/contracts/utils/BetterEfficientHashLib.sol:733–738`: the bytes overload hashes the bytes' contents with keccak256.
- `lib/crane/contracts/factories/diamondPkg/DiamondPackageCallBackFactory.sol:201–218`: combines package address with the returned salt, then returns an existing instance before `processArgs`.

**Use that standard convention unchanged.** Canonically encoded holder PkgArgs already contains `owner` and `providedSalt`; the latter remains **`bytes32(tokenId)`**. Different NFT-contract owners therefore have different input bytes and owner-separated address namespaces under the normal hash assumptions.

**Astra correction:** my original proposed direct `keccak256(abi.encode(owner,providedSalt))`. It is unnecessary and not the identical byte encoding/hash as `keccak256(abi.encode(pkgArgs))` where pkgArgs is already encoded bytes. Withdraw that special derivation; retain the standard source convention. Grok should likewise replace its special formula/shorthand. Kimi correctly identified the standard-args solution, but should not call it automatic factory behavior: the holder Package must actually retain that convention.

**Reject MiniMax's collision rationale.** Owner guards cannot repair two NFT contracts receiving the same address. The second owner would either be denied its holder or improperly share state. Factory early return is idempotency, not collision prevention. Omitting owner from the Package hash is wrong for this selected reusable Package.

Reuse FeeCollector's salt convention—not its upgrade/ownership facet composition (`FeeCollectorDFPkg.sol:26–35,52–57`).

## 2. Existing instances: neither blanket rejection nor blind adoption

Grok's requirement that a pre-existing holder already have an NFT mapping can let someone front-deploy the correct holder and block first registration. Conversely, Kimi's “squatting is benign” is conditional, not proven for an unwritten holder.

Before adopting a returned instance, validate the expected package/behavior, permanently bound NFT owner, salt, dependencies, initialization completion, intended-purchase state and mapping consistency. Exact duplicate deployment must not make a second purchase. Harmless canonical predeployment can be adopted under a specified safe rule; wrong or partially initialized state must fail. The factory's early return skips argument processing, so validation cannot rely solely on that processing running again.

One-time protected initialization, no human upgrade/cut or owner transfer, NFT current-owner/operator authorization, sibling-holder isolation and active-operation callback checks belong in the design. **MiniMax's “no reentrancy guard needed” is unsupported:** holder→depository/token and NFT→reserve/mint/stake operations cross external boundaries. Native `redeem` transfers NET to its requested recipient, not a fixed Treasury; events are not a mechanism for the NFT to synchronously read another call's logs. Specify returned values, authenticated calls and protected state transitions instead.

## 3. Depository binding and note identity

PRD v0.24 `247` configures the native depository on the **DETF instance through PkgArgs**. MiniMax cannot silently replace this with one universal holder-PkgInit depository. Preserve the selected owner+salt holder ABI; the plan must specify how an authenticated parent-instance binding becomes fixed for each holder, including safe predeployment. Do not select a new binding architecture in this review.

`BondDepository.sol:130–138` captures and returns the index **before push**, correcting Grok's “after push” wording and MiniMax's suggestion to record post-call length. Register the actual return from the single authorized purchase; never assume tokenId or zero. Preloads are unsolicited, not grounds for automatic blanket rejection or registration as the intended bond. The user selected one intended purchase, not an empty upstream array.

Kimi's registered-note O(1) read is useful; it does not close all bookkeeping/provenance or aggregate-preview obligations. Native redemption still visits the holder's entire history (`:143–165`). Isolation remains selected without an absolute work bound.

## 4. Receipts, excess and atomicity

Expected collection is the registered note's **currently claimable increment**, not its entire original payout. Actual collection is the measured native-payment receipt in this operation, reconciled with the note's claimed-state change—not the recipient's entire held NET balance. Separate pre-existing NET, direct donations, registered proceeds and attributable unsolicited-note excess. Nominal return values alone do not prove delivered amount.

Accepting greater-than-expected receipt is settled. **Reject MiniMax's invented treasury, forced exclusion of excess from contribution, and deferred excess pot as defaults.** The user has not selected those economics, and PRD `803` does not prohibit gift-funded contribution. Nor may `redeem(to=feeTo)` selectively forward gifts: it pays the aggregate. No new fee/sweep destination is authorized.

Native incremental collection→contribution→mint/stake remains atomic and under the **same NFT**. Failure restores native claim state, accounting and completion markers. Preview limitations concerning additional notes must be explicit; do not promise exact aggregate proceeds from one-note reads.

## 5. Release change is selected; only precision remains

Grok, MiniMax and Kimi should **not repeat a broad adoption vote**. The human expressly selects next processed epoch after full native collection, replacing v0.24 `606,611–613,793` native-maturity-only release. MiniMax also misreads existing elected reinvestment: `604,622` already specify its next-epoch release rule.

Document a precise proposed completion rule: use the **registered intended note's** `claimed == payout` after successful atomic contribution; snapshot the processed NET epoch after all underlying epoch advances within that operation; require a strictly later processed epoch. Do not wait for strangers' notes, reset on NFT transfer, or treat mere maturity/failed collection as completion. Record any remaining boundary interpretation narrowly. Early funded reward claims remain unchanged.

Native incremental harvest under the same NFT is settled. **Later principal rebonding** creates funded replacement after burning/debiting eligible old principal without the contraction incentive; whether replacement uses the same tokenId or a new normal bond remains distinct and unresolved. It does not authorize a second native purchase.

## What docs must record now / narrow questions

Record selected isolation, permanent NFT-contract control, standard owner-containing PkgArgs hash, provided tokenId salt, returned-note registration, one intended purchase, transfer-following rights, excess acceptance, atomic same-NFT incremental funding and the new release rule. Update §§4/10/12, R/O/C/A mappings and C08's status: custody selected, residual per-holder liveness still subject to evidence.

Ask only for unselected semantics:

1. Who receives funded rights from attributable native excess, and what release schedule governs late excess/direct donations?
2. Confirm exact completion-epoch ordering if the proposed end-of-operation marker is not the intended meaning; no renewed vote on the extra wait.
3. Same-tokenId versus new-NFT principal replacement, and preservation/disposition of late-gift rights at retirement. **No transfer of proxy control to a retirement beneficiary:** that would contradict permanent NFT-contract ownership. Do not burn the only entitlement handle or keep strangers' future notes as a perpetual release condition without explicit policy.

Engineering details—safe adoption, authorization, binding propagation, reentrancy and receipt accounting—require specification/evidence, not invented product defaults. No gas bound, deployed equivalence or full feasibility is certified. Current canonical architecture/deployment skills were read directly; this is local-source analysis, with no new external API claim. No shell/RPC/tests/browser/code/configuration/delegation. Only this cross-review written; return to moderator and stop.
