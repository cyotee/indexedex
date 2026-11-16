# Migration DETF phase 3: independent package preflight

## Authority and boundaries

The user authorized implementation of the Migration DETF plan using mass-ulw, task-owned worktrees, LIGHT root orchestration and HEAVY production lanes. This phase initially establishes the package implementation contract; it does not declare task 3 complete or authorize unresolved source policy.

Worktree: `/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-03`.
Branch: `work/dtf-migration-phase-03`.
Base: `90ff0307a7a8e084aa073e02eff125e9c7973933`.
No pricing changes have been integrated into this worktree yet.

Read the main checkout's complete implementation plan:
`/Users/cyotee/Projects/indexedex/docs/incidents/2026-09-16-dtf-recovery/MIGRATION_DETF_IMPLEMENTATION_AND_TEST_PLAN.md`.
Read applicable repository rules and skills, and the plan's cited product law when needed. The new Migration requirements override conflicting ordinary-product defaults only for this distinct family.

Phase-one canonical verification, especially section 6:
`/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-01/docs/incidents/2026-09-16-dtf-recovery/migration/evidence/phase01-verification.md`.
It permits independent package ownership/bootstrap and cliff-bond/reward-gate work, while forbidding unsupported attribution storage/ABI assumptions.

Pricing evidence is read-only context:
`/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-02/docs/incidents/2026-09-16-dtf-recovery/migration/pricing/evidence/verification/report.md`.
That bounded direct-pair/V3-input/raw-output fixture passed pricing checks, but actual recovery E3 remains open. Its F1/F2 local-script/report corrections are running independently. Do not edit that worktree or depend on unaccepted fixes.

Fungible authenticated ancestry and TokenStaking atomic claimant handoff remain unresolved. Owner questions timed out without an answer. Do not substitute a trusted allowance, wrapping-only policy, original-payer eligibility, pretransfer, or a two-step claim policy. Do not freeze affected source tuples.

## Initial topology

Three parallel, disjoint report lanes:

1. Ownership, registry deployment and package composition -> `package/ownership.md`.
2. All-leg donation bootstrap, self-leg supply and empty reward baseline -> `package/bootstrap.md`.
3. Migration child composition, cliff/reward hooks and payout-route inventory -> `package/children.md`.

One independent reviewer consumes all three and writes `package/implementation-handoff.md`. All output paths are below this worktree's `docs/incidents/2026-09-16-dtf-recovery/migration/`.

The reports must identify exact existing source anchors, minimal proposed new/edited paths, concrete callable/storage contracts, real-proxy tests, and which work is independent versus gated. They must resolve engineering choices from source evidence, not create owner policy or a menu of speculative architectures.

This initial wave writes only its named reports. No source/test/script/config edits, builds, installs, Git changes, broadcasts, external messages, or delegation. Shared dependency links are read-only. No temporary runtime process is needed for source inspection; if one is created, record and clean only owned resources.

## Required implementation concerns

- Nonzero current Crane Ownable owner, one-time initialization, actual ownership-buffer acceptance behavior, distinct owner/creator/fee/registry roles and owner-aware salt material.
- Registry-deployed distinct package, compatible base arguments, correct immutable child wiring and no restoration path through factory/init/cut callbacks.
- Donations before entitlement issuance, empty-reserve bootstrap, measured capital, self-leg minting, liquidity ownership, residual assets and reserved child IDs accounted separately.
- Stage 1 ordinary new-money closure without a fictitious user bond or preminted entitlements.
- Parent reward settlement before new principal; empty aggregate-weight baseline and delayed first issuance beyond an epoch without missing weight or backdated accrual.
- Migration-only child extension points for fresh exact-funded 90-day cliffs and Stage 1 payout restrictions, preserving mature principal rights and ordinary products.
- Direct child/receipt/fee/creator routes, callbacks and cross-contract locks, not only parent entrypoints.

The handoff is not implementation acceptance. It must give a coherent, bounded next implementation increment with its test oracle and explain any prerequisite that prevents that increment. Root will amend this same phase run after reading the handoff. Before any future Forge compilation, seed warm `out/` and `cache_forge/` and follow artifact-first Solar builds.

## Completion contract

Each producer returns DoneClaim with its report path, inspected source boundaries, exact findings, limits and cleanup. The reviewer returns ready-for-bounded-implementation or needs-fix with file/line evidence, permitted edit paths, dependencies, verification commands and resource requirements. No original plan checkbox or E1-E5 gate closes from these reports alone.
