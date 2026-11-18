# Migration implementation execution review

## Question and authority

The user requests a council review of the implemented code to determine whether
`docs/incidents/2026-09-16-dtf-recovery/MIGRATION_DETF_IMPLEMENTATION_AND_TEST_PLAN.md`
was fully and correctly executed. Review current working-tree implementation,
tests, native scripts and supporting execution evidence. Do not implement fixes.

Profile: review. Council: full four-member council. Coordinator: invoking agent.
Repository: `/Users/cyotee/Projects/indexedex`.
Run: `dtf-migration-implementation-council-20261116-0228`.
The supplied plan was read completely during preparation; its SHA-256 was
`affff781dfc522d96bba1c2fba28053ec5e7804f97c10504441445eaefef7949`.
This is a live shared checkout, not an atomic frozen source snapshot.

## Requirements and precedence

Read the complete supplied plan, especially its opening November 15, 2026 owner
scope correction and sections 1.1-1.10. The retained deliverable is migration
contracts and simple native Foundry scripts. The custom TypeScript CLI,
preparation application, portable bundles, custom journals and application-level
crash recovery were withdrawn, including older completion-language references.
Do not reopen those requirements or treat their removal as a defect.

Section 1.10's complete manual Weighted pricing and keep-until-reloaded rules
supersede automatic snapshot capture/no-setter requirements and the earlier
live-production-composition prerequisite. Preserve supported-domain canonical
differential evidence. Source identity, custody, conservation, authorization,
funding, activation, reward and gas requirements remain.

Apply original-wallet configuration and Stage 2 surrender, the genuine paid
owner-first ordinary bond, separate weighted NFT 3 contribution bonds, one
conserved TokenStaking original, and repeatable reward-only harvesting.
Historical holder-transfer ancestry is not a prerequisite. Do not restore it.
Independent compensation remains separate from held exposure.

Required baseline context is the referenced
`docs/incidents/2026-09-16-dtf-recovery/MIGRATION_DETF_DRAFT_PRD.md`;
use it subject to the plan's explicit supersessions. No additional audit was
supplied by the user. Existing reviews and implementation reports are evidence
claims to check against current code, not independent authority.

## Required target groups

1. All implementation, interfaces, TestBases and invariant handlers under
   `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/`.
2. Migration hermetic specifications under
   `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/migration/`.
3. Migration legacy fork specifications under
   `test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration/`.
4. Native scripts under `scripts/foundry/recovery/dtf-migration/` and
   `docs/incidents/2026-09-16-dtf-recovery/migration/foundry-runbook.md`.
5. Shared implementation extension points used by Migration in
   `contracts/vaults/detf/common/`, the ordinary V4 DETF and bond packages,
   `contracts/hooks/uniswap/v4/standardExchange/weighted/`, and their related
   interfaces and ordinary regression tests. Identify actual examined files;
   this is not a whole-repository audit.
6. Completion evidence under
   `docs/incidents/2026-09-16-dtf-recovery/migration/`, including source manifests,
   route matrices, quote/package/verification records, gas results and newer
   `conformance-20261114/` records. Follow referenced receipts selectively.
   Archived checkouts and older reports are historical evidence, not current code.

Relevant repository rules, skills, dependency sources (including Crane),
incident provenance and referenced requirements may be read as context.
Use current checkout code as the implementation target. Do not silently switch
to an archived worktree named by an older report.

## Independent review deliverable

Each member independently reviews the same targets. Do not read this run's peer
responses before submitting your original. Trace the implementation rather than
accepting completion claims or counts of passing tests.

Return a clear execution verdict: fully executed, not fully executed, or unable
to determine, with correctness findings separate from missing execution evidence.
A source review cannot guarantee absence of bugs.

Include:

- Identity, Question and targets, Evidence, Assumptions, Coverage, Conclusions,
  Review findings, and Limits. No unfilled template markers.
- A disposition for each of Tasks 1-10 and final verification items F1-F4.
- Traceability for MIG-P01-P15, E1-E5 and all 53 MIG-AC IDs; compact rows may
  share a locator only when the same evidence actually covers each obligation.
  Distinguish implemented/test present, supplied runtime verified, incomplete,
  superseded and unverified. Do not call a test's existence its execution.
- Required target-group coverage with examined, partially examined or not
  examined status, actual file locators and honest omitted scope.
- Findings ordered by severity, each with current file and line/symbol,
  violated requirement, impact, minimal fix direction, confidence and evidence
  class. Do not invent defects merely to populate the report.
- Check real registry/proxy composition, every exposed acquisition/reward/exit
  path, activation removal and restoration routes, accounting/backing,
  source-specific units/custody/recovery, expected-book replacement semantics,
  nonlinear pricing parity, rollback, tests' ability to detect regressions,
  ordinary-package regression evidence, and target-chain gas.
- Check evidence recency and source binding. Historical broad passing runs do
  not automatically validate later code or FactoryService-loaded artifacts.
  Missing runtime evidence is a limitation, not a fabricated failing test.

## Tools and boundaries

Static review and reads of existing logs only. No project builds/tests, installs,
RPC/transactions/wallets, deployments, shell commands, Git operations, code or
configuration edits, external messages or subagents. Reading source with
read/glob/grep and bounded eval filesystem reads is permitted. No external
research is needed for repository-local contract verification.

Members write only their assigned
`docs/reviews/dtf-migration-implementation-council-20261116-0228/members/<label>/response.md`
using apply_patch. If that write is unavailable, return the complete response
inline and report the publication limitation; do not try alternate write tools.
Only the coordinator owns brief, run record, draft, resolution and final PRD.
Inherited tool access does not enlarge this assignment or prove confinement.

Stop after the complete original response and await a separate advisory request.
The coordinator will preserve originals, verify important evidence, write one
identified draft, request one advisory feedback pass, and publish the final
`REMEDIATION_PRD.md`. No report authorizes implementation.
