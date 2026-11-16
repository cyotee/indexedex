# Configured original-wallet weighted liquid surrender

## Scope

Implement exactly the phase11 W-L source contract on the independently
verified original-wallet NFT baseline, not general receipts, SY, earlier
tokens, LP, TokenStaking or claim-vault routes.

The owner requires the original acquiring wallet, a matching configured
original entitlement, and actual asset surrender. No record means revert
before any custody, consumption or issuance. Compensation stays with the
recorded wallet through transfers. No transfer-history/native-prefix proof.
The frozen original ETH/DTF quote remains attached to the configured original
record, not computed from current holdings or redemption value.

Read the main plan r3 section1.3, complete phase11 independent report/matrix
and weighted/contract.md in:
`/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-11-same-wallet-sources/docs/incidents/2026-09-16-dtf-recovery/migration/same-wallet-sources/`.
Section3 and section4 of weighted/contract.md define the admitted unit/caller
contract. This is independent evidence for legacy primitives, not existing
integrated runtime support.

## Isolation and unchanged held work

Work only in
`/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-13-weighted-liquid`
on `work/dtf-migration-phase-13-weighted-liquid`, base
`2c2b3370ded30cae1662329025d4fb58f7197330`.
Root verifies warm seed and clean exact HEAD before dispatch.
Read repository rules and applicable canonical Foundry/Crane/testing skills.

This is new source-adapter work under the owner's clarified eligibility
requirements. Do not inspect/import/change/test the refused phase09 gas
candidate or continue its assignment under this task. The known baseline
deployment-gas limitation stays explicit. No provider routing changes.

Allowed paths: Migration-specific interface/repo/targets/facets/package
wiring, legacy helper and TestBase under
`contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/`;
neighboring Migration specs/forks; operator tooling under
`scripts/recovery/dtf-migration/` and
`scripts/foundry/recovery/dtf-migration/`; operator runbook.
No ordinary/common/Crane production, dependency or configuration changes.
Evidence under incident `migration/weighted-liquid/implementation/` or
`verification/` only as owned by each node. No historical evidence edits,
public transactions, commits, push or merge in implementation/review nodes.

## Minimal implementation contract

Source is fixed weighted liquid DETF:
`0x4a5cFDC2b07016FCf917f4eD5A51C52111A0fcC7`,
native nine-decimal nonrebasing units. Do not infer a DTF conversion rate.

Configure the original wallet, canonical original economic-record identity,
source/class, original ETH and DTF components and original eligible Q0.
Unknown original quantities/components reject; they are not zero or inferred
from current balance. Compute C0 with the existing immutable funded snapshot.
No caller-supplied output credit, arbitrary adapter/source or beneficiary.
Use an explicit configured bit/identity and retain owner-only Stage1 loading.
The loaded Q0/component allocation is an execution input, not an approved
real-user allocation merely because a synthetic fixture supplies it.

Use wallet-independent canonical economic origins to retain actual known
cross-path overlap protections. Do not allow the same original allocation
to be reissued as independent compensation or a configured NFT claim.
Do not claim a global alias proof; explicitly report missing operational
origin data. Original wallet/source/origin remains immutable after any
consumption. Full replacement of still-unconsumed configuration must preserve
consumed units and actual delivered credit; do not reopen spent credit or
calculate retroactive `newTotal - oldPaid` payouts. Follow plan section5.3.
If existing text cannot settle a correction arithmetic case, identify that
exact case before inventing a new rule; do all independent implementation first.

For a caller with matching record and remaining Q,C:
require `0 < q <= Q`. Credit is C if q equals Q, otherwise
`floor(C*q/Q)` using full-precision multiplication/division. Zero credit,
expired deadline or unmet minimum rejects with no asset loss.
Require original wallet's actual token holding and approval, pull q into
Migration, and verify exact wallet and Migration balance deltas. Atomically
debit q/credit, book q into the existing weighted DETF recovery inventory,
mint exact delivered principal and fund a new 90-day bond for that wallet.
Reuse production issuance and common transaction/accounting locks. No
pretransfer flag, allowance fallback, generic external call or balance sweep.

Keep existing selected owner recovery: fixed WD self-approval, one-word
legacy exchangeIn return, exact actual input/output, clear allowance,
positive measured DTF inventory, then existing fixed reserve donation.
Direct surrendered WD must join only the explicitly booked inventory;
unbooked holdings, reserved donation budgets and other backing stay protected.
Repeated or staged recovery must not mint additional personal credit.

New configuration selectors and interfaces must be irreversibly removed at
activation, while surrender and current-owner bounded recovery remain.
Preserve the verified NFT wallet guard, independent allocation path, ordinary
products and existing lifecycle semantics.

## Operator and actual local surface

Extend typed preparation/provenance schemas, full payload hashing, loading,
queries/state reconciliation and narrow configuration/surrender fixture data
for W-L. Missing original wallet/Q0/components rejects; do not fill it from a
live balance. Keep every other unsupported category explicitly blocked for
its actual phase11 gap. All synthetic original inputs remain labeled.

Fix this rehearsal invocation before operator edits:

```sh
bun scripts/recovery/dtf-migration/cli.ts rehearse \
  --rpc-alias robinhood_mainnet_alchemy \
  --fork-block 108944663 \
  --port 18563 \
  --checkpoint .omo-runtime/dtf-migration-weighted-liquid/checkpoints \
  --evidence docs/incidents/2026-09-16-dtf-recovery/migration/weighted-liquid
```

Preserve the actual donation/issuance interruption-resume contract, meaningful
remaining-row reordering and unclaimed zero supply. Add actual configured
weighted-liquid partial/final surrender and selected recovery, missing-record
and wrong-wallet rejection, and postactivation surrender with the same record.
Retain historical commands as historical; update current help/runbook.

## Verification gate

Production-first actual registry package and pinned legacy WD only. Add
neighbor-sized deterministic regression tests that fail without this path:
configuration/wallet admission, insufficient balance/approval, partial/final
credit and rounding, no mint at configuration, exact fresh funded bonds,
source balance deltas, callback/funding rollback, prior consumption, original
overlap/correction, activation/removal/restoration and explicit inventory
conversion/donation with unbooked floors. No etched or storage-injected SUT.

Run artifact-first Solar build plus current relevant Migration specs/forks
and final-source script tests/types. Actual local rehearsal proves integration,
not target-gas feasibility. No full repeated ordinary/common run without a
dependency reason; retain exact unchanged evidence qualifications.

Independent verifier executes the real configured partial/final and
wrong-wallet/unconfigured calls and subsequent recovery; inspect final
source/operator parity and actual receipts, and return confirmed/needs-fix
for W-L only. Missing operational Q0 allocations remain an explicit
configuration gate, not fake successful category-wide migration.

Stop owned local nodes/listeners/impersonations; retain evidence and warm
artifacts. A temporary idle is not a handoff: finish final report, source
bindings and cleanup before notifying the verifier.
