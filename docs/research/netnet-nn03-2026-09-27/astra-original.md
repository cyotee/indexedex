# Astra — NN-03 ORIGINAL: synchronization and availability

2026-09-27. PRD v0.26; independent original, prior session retained, no new-round peer artifacts read. Assigned routing `openai/gpt-6-astra`, not provider attestation.

## Plain English: what might conflict?

Three selected requirements must work together:

1. Track all locally held tokens and refresh the full **registered expected-held set** after every successful money route (PRD `375–385`, A49 `980`).
2. Keep historical claims without making ordinary operations traverse indefinitely growing history (`747–749`, A36 `967`).
3. A failed fee-reward forwarding attempt must not block the surrounding operation; preserve the unpaid token/payable for retry (`880`, A11 `942`).

**Example:** an old market paid reward token X, now owed entirely to feeTo. Today's user trades against healthy current assets. If X's transfer fails but `balanceOf` works, isolated forwarding failure and full balance synchronization may coexist. If X's balance query instead reverts, the ordinary full-set helper also reverts—even if its earlier transfer failure was caught. Many readable historical tokens can create a separate growing-work problem.

This is a **conditional compatibility problem**, not proof all selected behavior is impossible. A transfer pause/blacklist does not imply broken `balanceOf`. No evidence establishes a currently hostile configured token, an actual outage, or an attack threshold.

## What current code actually provides

All paths here begin `contracts/vaults/basic/`:

- `BasicVaultCommon.sol:46–54`: obtains `_vaultTokens()`, loops every entry and calls its external `balanceOf`, then writes the result. No per-token failure handling or explicit gas/return-data isolation is specified there. Exact failure/resource behavior must be checked, not assumed away.
- Its full-set and single-token sync functions (`41–54`) are **not virtual**. A proposal cannot claim an existing subclass override solves this. `_secureTokenTransfer` and `_unbookedSurplus` being virtual is different.
- `BasicVaultRepo.sol:20–27` and `MultiAssetBasicVaultRepo.sol:21–26` have the same slot/layout: an address set and raw-balance mapping. Initialization/addition is explicit (`51–80` / `50–80`). Neither supplies archive/quarantine/freshness fields or a removal helper. No automatic registration of arbitrary spam-token transfers was found or selected.
- `BasicVaultRepo._updateReserve:98–109` simply assigns an amount. It neither verifies that amount nor separates backing from payables. `BasicVaultCommon:80–105,123–137` relies on actual-minus-booked balances for pretransfer/refunds.

Thus “just catch and write zero,” “just remove old tokens,” and “just override sync” are not source-grounded solutions.

## Recommended engineering-first resolution

**No owner needs to choose storage structures now.** First produce a token-role × operation dependency table, custody/history lifecycle and resource model showing whether the literal requirements can coexist. Current tracker `101–106` already calls for this.

**Alternative A — preserve literal synchronization.** Demonstrate bounded expected-token sets per relevant custodian, fully settled retirement, or a custody partition that still tracks every holding and preserves all claims. This is not automatically available: old Pendle claims belong to the earning address (`725–735`); a failed token transfer may prevent moving custody. Partitioning must not merely relocate an unbounded mandatory traversal. Any changed custody authority requires explicit review, not invention here.

**Alternative B — narrow freshness policy, UNAPPROVED.** Continue tracking all recognized holdings/liabilities, but refresh a bounded, complete operation-relevant active set; separately maintain historical/fee-only records with truthful stale/unknown status and isolated retries. This **changes literal §6.3/A49** if every registered locally held balance is no longer freshly read after every route. It needs an explicit amendment, not being described as ordinary implementation of A49.

Neither option permits discarding a balance or silently forgiving fees. Prefer A if a concrete design satisfies it; otherwise present a specific B amendment with affected operations and consequences.

## Proof conditions—not new economics

- **Required assets fail closed:** if a missing read is necessary for input credit, output funding, reserve valuation, HLP issuance/exit, solvency or user entitlement, do not continue with fabricated freshness. “Relevant” means all economic dependencies, not just input/output token addresses.
- **History is not automatically irrelevant:** HLP owns current historical asset/claim value. Skipping it needs a proof preserving admission, transfer and exit rights—never marking its value zero or creating unselected detached coupons.
- **Role collisions:** fee-only treatment fails if the same token address also backs principal/interest or receives protocol claims. Segregated attribution and all affected transitions must remain correct.
- **Pretransfer safety:** stale snapshots, donations, rebases and forced claims must not become caller credit. Reactivation must reconcile provenance before use without swallowing legitimate input. Refund only this operation's authorized unused contribution.
- **Failure isolation:** bound calls/return-data processing and retained execution budget; account for real transfer effects exactly once, callbacks and dynamic feeTo. Failed forwarding never becomes an asset sweep, payable write-off or fee-recipient reassignment.

## What must the owner decide?

**Now:** no economic redesign or new token policy is required; direct the specification author to return a concrete design first. **If literal full-set freshness cannot meet the selected availability:** decide this narrow policy question:

> May an otherwise independent operation continue without a fresh read of a demonstrably fee-only or irrelevant historical balance, provided its holdings/claims/payables remain tracked with truthful freshness status, required assets still fail closed, and HLP/pretransfer rights are proven unchanged?

This is permission to amend A49's freshness scope—not approval of a particular quarantine layout. Rejecting that relaxation requires a demonstrated literal-sync design or a separately disclosed availability trade-off; do not silently weaken A11/A36 instead.

Read current CLAUDE, specified PRD/tracker, all three source files and canonical Crane architecture/adversarial plus local adversarial guidance. No external API claim required lookup; no shell/RPC/tests/browser/code/config/delegation or read failure. High confidence in local facts; no feasibility/gas proof performed. Only this report written; no policy selected or PRD edited.
