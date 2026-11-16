# Minimal activation-compliant Migration accounting correction

Worktree: `/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-03`.
Base preparation commit: `6d82859ee0b20804a4ced6e7a5ae395a49f5cdfd`.
This unit authors a corrected construction and evidence, not production code.

## Current authority

The current user resolved genesis: **only the current Crane owner selects and
executes one-time pooled genesis amounts/anchor; contributions and subsequent
ordinary donations remain permissionless.** Do not reopen that decision.
Legacy E1/E2 and actual recovery E3 remain open; no legacy category is dropped.

Read the original Migration implementation plan and applicable source law,
the complete implementation handoff, r1/r2 constructions, and their independent
verification reports. All prior constructions and evidence are immutable
historical inputs. The latest report is
`migration/package/egress-correction-verification.md`.

## Correct the two rejected boundaries

1. **N1, payout:** every new-instance reward payout requires activation.
   Delivering a newly issued, transferable reward receipt before activation is
   not made compliant by gating only its subsequent redemption or renaming it
   a right. Keep accrued beneficiary obligations in protocol custody until
   permitted payout. Successful mature-principal exits must remain possible.
   Distinguish authorized transfer of an existing locked right from issuance
   and delivery of a new reward token using admitted requirements and actual
   custody, not labels.
2. **N2, integration scope:** the fresh local market factory is not admitted
   by the unchanged gauge controller, so the proposed graph may fail on first
   LP mint. Do not repair this by inventing controller/voting deployments,
   external governance actions, skipped/caught reward harvesting, shared-source
   edits or a growing standalone Pendle rollout. Revisit the representation
   and integration boundary instead.

## Scope discipline

The user requested Migration DETF, not a new Pendle protocol deployment.
Distinguish the plan's required new-instance SY/receipt API and money paths
from integrations introduced by the previous drafts. Cite the exact plan or
existing callable contract that requires each integration component. Do not
promote an earlier agent proposal into product law.

Prefer the smallest correction compatible with actual declared interfaces and
their required callers. Do not silently declare incompatible standard APIs
compatible, waive an original required path, or remove a legacy category.
Conversely, do not require a new market/controller deployment merely because
a draft chose a reward representation incompatible with existing consumers.
Explicitly identify optional third-party integration limits without presenting
those optional integrations as delivered or as a prerequisite the user imposed.

Re-examine r2's one-gon-per-token-unit choice and resulting wide-consumer fork:
neither that token quantum nor the five-contract import spine was an owner
requirement. Derive precision, rounding, retained rights and retirement from
the actual plan and canonical funded machinery. Preserve economically owned
rewards and exact principal/backing; no silent truncation, unfunded debt,
invented economic cap or arbitrary forfeiture. Any use of canonical rounding
or retirement must name its actual admitted condition. Do not retain a stronger
draft-only requirement solely because an earlier report asserted it.

Keep the verified native-principal and funded-custody invariants where valid.
Provide one coherent implementable contract, not a menu. If a complete
required-surface solution cannot be established, report the exact unsatisfied
contract and evidence instead of adding unrelated deployments or a fake stub.
No new owner-policy question is a substitute for N1's already-settled rule.

## Deliverables and write boundaries

Author only:

- `migration/package/egress-contract-r3.md`
- Bounded arithmetic/caller evidence under
  `migration/package/evidence/egress-r3/`

Independent reviewer only:

- `migration/package/egress-r3-verification.md`
- Evidence under `migration/package/evidence/egress-r3-verification/`

All migration paths are under the worktree's
`docs/incidents/2026-09-16-dtf-recovery/`.
No production/test/config edits, Forge runs, installs, Git, commits,
broadcasts, shared Crane changes or delegation. Use apply_patch for owned
files and clean any owned finite runtime resources.

## Required evidence

- Exact state, units, API, source/beneficiary/custodian identities and operation
  order for all required receipt/bond/SY direct and parent-composed paths.
- Positive mature-principal exit during prolonged Stage 1; no newly delivered
  reward token/receipt; later correctly owned funded reward payout after
  activation; repeated payout zero; retained rounding rights accounted.
- Standard reward-interface unit/sentinel/ownership consistency where exposed,
  including old-holder claims after principal leaves and multiple cohorts.
- Actual required internal-redemption caller graphs, including owner/operator
  separation, operation-local budgets, wrong-caller negatives and rollback.
- Concrete deployment/caller admission for every component retained as
  required; no implicit privileged setup or counterfactual model registration.
- Exact minimal proposed production edit paths and a real-proxy runtime
  validation contract. Integer models remain models, not E5 acceptance.

The independent reviewer must apply the original plan scope, not demand the
unrequested protocol rollout rejected above. It must independently test N1,
N2 and any retained F1-F3 obligations against the chosen boundary and actual
source semantics, and return ready-for-bounded-implementation or needs-fix.
Neither outcome completes task 5/E5 without production implementation and
real-proxy execution.
