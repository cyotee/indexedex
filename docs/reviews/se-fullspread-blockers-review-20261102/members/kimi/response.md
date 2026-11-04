# Kimi independent review

## Identity

- Member: `kimi`
- Profile: `review`
- Phase: initial independent response
- Requested role: `council-member`
- Requested model: `kimi-coding/k3.1-pro:high`, global route
- Runtime identity not supplied in the assignment: not exposed
- Peers read before submission: no

## Disposition

**Requested changes.** The blockers file is not yet consistent and complete enough to serve as the sole source for a comprehensive PRD rewrite. Seven points can still produce divergent implementations or test expectations. The remaining locked items are sufficiently specific, as shown in the coverage table below.

This response does not authorize implementation or a PRD edit.

## Review findings

### F-01. The post-sleeve local reserve term is undefined

**Location:** B-06, together with B-02 and the Donation and compound booking section.

B-06 says, “The local reserve term remains the last committed snapshot.” B-02 removes the local liquidity sleeve, while the booking lock excludes both the booked remainder and uncollected fees from `reserves()`. The file does not say what local value remains to be snapshotted after those exclusions.

One implementor could retain a last-committed local balance in `reserves()` and `reserveOfToken()`, while another could conclude that the sleeve drop makes the reserve deployed-only. Those implementations return different values, especially during a busy-vault read.

**Fix direction:** State the post-sleeve composition of the local reserve term and what its last committed snapshot contains. If no local term remains, make that explicit and reconcile the B-06 snapshot sentence with the booking exclusions.

### F-02. B-07 both requires and appears to forbid per-instance address storage

**Location:** B-07, the two consecutive sentences beginning “When the package initializes a vault instance” and “The repo is not given a second per-vault copy.”

The first sentence requires initialization to write all seven package-immutable addresses into the Uniswap V4 Protocol Aware Repo. The second says that repo is not given a second per-vault copy of those addresses. It is unclear whether “second” prohibits a duplicate in another repo or prohibits the instance copy in the Protocol Aware Repo itself.

One implementor could write the seven addresses into each instance repo; another could leave the repo empty and read package immutables directly. Those are different storage and getter designs.

**Fix direction:** Identify one canonical runtime source for the seven addresses and state precisely where initialization writes them. If the intent is one per-instance copy in the Protocol Aware Repo and no duplicate in the family repo, say that without the ambiguous “second” formulation.

### F-03. Optional share-side scaling leaves externally visible share units undecided

**Location:** B-10, the paragraph beginning “A scale that makes the stored share balances match `decimals()`.”

The lock permits, but does not require, a share-side scale and says no such scale is required. Although a constant scale cancels in the mint and burn ratios, it does not cancel in externally observable balances and supply. Raw-liquidity shares and scaled shares produce different `totalSupply()`, holder balances, genesis floor representation, preview outputs, and minimum-out values for the same economic state.

Two implementors can therefore follow B-10 and still ship incompatible ERC-20 share units.

**Fix direction:** Choose one canonical external share unit and apply it consistently to the floor, minting, burning, previews, and events. Alternatively, prohibit the optional scale explicitly if raw V4 liquidity is intended to be the share unit.

### F-04. `Compounded()` emission is not defined for every maintenance route

**Location:** B-11 and the Donation and compound booking section.

B-11 requires `Compounded()` “when fees are compounded,” but the booking lock also makes `donate()` compound and processes an existing booked remainder when no new fee or donation exists. The file does not specify whether the marker is emitted for a donation-only call, a remainder-only `compound()`, or a call whose best-effort deposit leaves the entire balance booked again.

One implementor could emit only when newly collected fees exist; another could emit for every nonempty maintenance call or only when liquidity actually increases. Indexers would receive different markers for the same PoolManager events.

**Fix direction:** Define the event condition by route and outcome, covering donation-only, remainder-only, mixed balances, successful deployment, and the case where nothing is deployed. Keep the already locked no-fees/no-donation/no-remainder no-event case as one branch of that rule.

### F-05. N-05 leaves the package input ABI optional

**Location:** N-05, “`PkgInit.wrappedNative` may remain only if it must equal that constant.”

Whether `PkgInit.wrappedNative` remains is not merely a storage choice. Keeping or removing it changes the package input structure, deployment call data, `bindingHash` coverage, and validation surface. One implementor could retain and validate the field while another removes it, and both could claim to follow N-05.

**Fix direction:** Decide whether the package field is retained or removed. If retained, specify its equality validation and binding-hash treatment; if removed, make the network constant the sole package-independent source. The internal repo choice can remain an implementation detail.

### F-06. The matrix exclusion is broader than the new booking rules

**Location:** Matrix files, “Booked-remainder rows cannot pass here. Unused input is refunded.”

The first sentence is unqualified, but B-05, B-11, and the booking lock expressly require booked remainders from donations, compounding, and withdrawal-collected fees. A reader could exclude every booked-remainder assertion from this family, while another could exclude only inherited rows that book a user's unused exchange input.

Those readings produce materially different integration coverage and could incorrectly omit the locked maintenance behavior.

**Fix direction:** Limit the incompatibility statement to the specific user-route remainder rows that assume unused input is booked rather than refunded. Separately identify the maintenance-booking assertions required by the new donation, compound, and withdrawal rules.

### F-07. APEX-2026-039 is still presented as waiting on an already locked decision

**Location:** Audit tests that wait on an open decision, the APEX-2026-039 row.

The section says these expectations cannot be written until an open item is locked. The 039 row says its expectation waits on attribution through B-13, but B-13 is locked and supplies the attribution rule. The file therefore gives conflicting signals about whether the 039 absence test is ready to specify.

One implementor could treat 039 as unresolved and omit a concrete expectation; another could implement the B-13 test immediately.

**Fix direction:** Reconcile the row with B-13's locked status and state that the absence test now follows the declared-maximum, unbooked-balance, limited-refund, and caller-share rules. Remove any implication that attribution remains an open owner decision.

## Coverage

| Item | Review result |
| --- | --- |
| B-01 | Covered. The net-from-gross fee, 30% clamp, WAD precision, net previews, and exclusion of the genesis floor from the fee base are consistent. No additional defect found. |
| B-02 | Covered. Sleeve removal, owner/operator compounding, unbounded swap limits, withdrawn-net redemption, and the accepted sandwich exposure are explicit. The batch-swap limitation expressly does not revoke the borrowed-unlock or hook rows. |
| B-03 | Covered. The empty-call return is deterministic, and processing a booked remainder is preserved. Event conditions outside the empty case are covered by F-04. |
| B-04 | Covered. The zero-liquidity denominator is intentionally absent because the state is locked unreachable; no alternative denominator is left open. |
| B-05 | Covered. Donation authority, self-funded balancing, zero-supply revert, share-donation behavior, and remainder booking are stated. |
| B-06 | Covered by F-01. The no-coded-view-revert rule and unsupported-route zero are otherwise clear. |
| B-07 | Covered by F-02. Package deployment across chains, the two Crane facet pairs, per-instance position identity, and the `StateLibrary` position read are otherwise specific. |
| B-08 | Covered. The external rate-provider configuration, absence of a vault rate or provider getter, lack of a provider-count cap, and 64-byte preview tuple are clear. Assigning consumer enumeration to the single PRD pass is an explicit work instruction, not a missing economic rule. |
| B-09 | Covered. The borrowed exit pulls and settles the caller's deployed fraction on the existing unlock, with no sleeve fallback or replacement error unit. |
| B-10 | Covered by F-03. The raw-liquidity reserve and ratio formulas are otherwise explicit. |
| B-11 and booking | Covered by F-01 and F-04. The combined-balance processing, actual-held-balance booking, withdrawal fee booking, reserve exclusion, and repeat-compound route are otherwise defined. |
| B-12 | Covered. Both paired event names and their sole indexed caller argument are fully specified. |
| B-13 | Covered. The pretransfer source balance, declared maximum, limited refund, residual unbooked balance, contract-caller restriction, and parked-share exclusion are clear. The stale audit status is F-07. |
| N-01 | Covered. The address-zero floor and direct `_mint` path leave no holder or error choice. |
| N-02 | Covered. The fee base excludes both the floor and fee-on-fee compounding. |
| N-03 | Covered. Dropping the sleeve removes the adjustment swap without changing the authorized entry swap. |
| N-04 | Covered. The note forbids inventing a step cap, minimum spacing, or partial fill and defines quote failure as a revert. Selecting the internal quoting mechanism does not change those locked external rules. |
| N-05 | Covered by F-05. The absence of a getter and WETH-only caller boundary are otherwise clear. |
| N-06 | Covered. The two library slots remain fixed, and assigning already specified operations between them is code organization rather than an unresolved product rule. |
| N-07 | Covered. Liquidity-only issuance remains closed except through an explicit change to FS-MONEY-01. |
| Matrix and evidence files | Covered by F-06. Exact-output rejection, preservation of other families and V3 rows, and replacement of stale V4 evidence are otherwise explicit. |
| Audit table and already-locked summary | Covered by F-07. The summary otherwise restates the substantive locks without adding a separate implementation choice. |

## Limits

This review used only the blockers file and the two admitted context documents. It did not inspect peer responses, modify the blockers or PRD, run implementation tooling, or verify future test behavior.
