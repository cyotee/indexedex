# Recovery R1: harvest attributable receipt growth

Continue only in
`/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-07-recovery`,
on the existing uncommitted recovery delta above verified base
`6e7d8b8dc2cda313c7fb19ec051bfb84612f5f31`.
Read the original plan, complete recovery source gate, producer report and
independent `migration/nft-recovery/verification/report.md`, including R1 and
both actual witness traces. Previous evidence is immutable.

## Binding defect and correction

The independent terminal-NFT witness burns the old NFT, later exhausts the
original native claim budget, and leaves488794 whole native receipt units
backed entirely by recovery-owned gons. The one-unit W2 request rejects before
the source even though a genuine external source holder can redeem accrued
receipt value. This is a stale-budget defect, not protected unbooked dust.

Make actual recovery-owned gons' synchronized redeemable value available to
the existing W2 conversion even when the original claim-native inventory is
zero. Preserve an explicit accounting distinction between new NFT claims
and accrual/revaluation/representation adjustment; never emit/recount accrued
value as another NFT claim, compensation, source transfer or new principal.
Maintain exact observed WD receipts, fixed Migration destination, deadlines,
common lock, child-state admission, and selected-batch atomicity.

Keep the actual-gon debit bound and unbooked-gon floor. A whole-account source
exit must not retire unrelated gons. True sub-native amounts may remain held;
whole attributable units may not be stranded solely because an old native
claim budget was spent. New future NFT claims are not a substitute for
recovering value from already held recovery gons.

The source gate's prior no-budget-expansion sentence is superseded only to
the extent it conflicts with original task8's harvestable-accrual requirement.
This is an engineering correction, not a new owner policy or trust decision.
Preserve all other admitted stage/authority/accounting constraints.

## Exact allowed changes

- `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/legacy/MigrationLegacyRecoveryLib.sol`
- `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationRecoveryRepo.sol`
- Existing Migration recovery target/interface only if narrowly necessary
  for truthful accounting/event/query semantics; no generic executor, new
  source, recipient setter, new owner role or discretionary credit surface.
- Related existing/new migration spec/fork regression files and legitimate
  shared Migration TestBase setup only if indispensable for the real fixture.
- New evidence only under worktree incident
  `migration/nft-recovery/correction/`.

Common/ordinary/Crane/config/dependencies and old reports/witnesses are
read-only. No commit, delegation, source-policy change or public operation.
Report an indispensable additional path to root before editing it.

## Required proof

First add a real proxy regression for R1 and capture it failing on the current
defective source. Then implement the minimal correction and execute:

- Actual pinned weighted NFT surrender, final claim/burn, real source index
  movement, old native-budget exhaustion, and successful conversion of later
  whole value through the real Migration proxy without a new NFT claim.
- Exact attributed/unbooked gon conservation for partial and full exits,
  exhausted budget and repeated operation. Unrelated whole and fractional
  receipt inventory must remain protected.
- No double claim/revaluation accounting or new compensation, including
  revaluation followed by a later genuine claim and a subsequent conversion.
- Failed later selected step reverts reconciliation, source receipt debit,
  output inventory and donations together; committed earlier stages survive.
- Existing W1/W3/ER1/ER2/W4 behavior, owner transfer/activation, callback and
  budget protections remain intact. Earlier liquidation remains unimplemented
  and blocked; no broader route is inferred.

Use the accepted real registry/pinned source fixture, not SUT mutation,
parent impersonation, mock receipt or injected balances/gons. Numerical unit
tests may supplement but cannot replace actual R1 conversion.

Artifact-first Solar build then complete current migration specs and pinned
migration fork scope, with exact exits/counts/logs/source/artifact bindings.
Run other regressions only when their inputs changed or a concrete concern
requires it; otherwise preserve source-bound ordinary/common results with
their actual original provenance. Record changed gas/query/event semantics
where relevant. No concurrent compiler; preserve warm artifacts and failures.

Producer report: `migration/nft-recovery/correction/report.md`.
Independent verifier writes only
`migration/nft-recovery/correction-verification/report.md` and supporting
evidence in that directory. It independently executes the formerly stranded
case through Migration, challenges mixed unbooked inventory and accounting,
checks current bindings and all preserved protections, and gives confirmed
or needs-fix. No edits to production/tests by the verifier, redundant large
runs, or terminal DoneClaim before evidence and owned cleanup are complete.

This correction closes R1 only when independently verified. All other original
source/E2/harvest/operator/invariant/gas/release gates remain explicit.
