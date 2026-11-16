# Owner-paid first bond and enforced activation prerequisite

## Approved decision

The owner said: "Simple answer, we'll allow the Owner to buy a first bond.
That way we don't need to redesign the rewards process. We just need to
allow the owner to buy a bond during Stage 1."

Asked whether activation must require the paid first bond to have completed,
the owner explicitly answered: "Enforce on-chain (Recommended)".

Read current main plan r5 section 1.5 and PRD r22 section 1.2:
`/Users/cyotee/Projects/indexedex/docs/incidents/2026-09-16-dtf-recovery/`.
These replace the unresolved genesis-weight question. Neither bootstrap
self-leg seeding nor first-reward seeding is approved. The earlier partial
entitlement amendment question remains obsolete under Stage2-only surrender.

## Worktree and preserved handoffs

Work only in:
`/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-13-weighted-liquid`.
Branch is `work/dtf-migration-phase-13-weighted-liquid`, HEAD/base remains
`2c2b3370ded30cae1662329025d4fb58f7197330`. Preserve its 39-file uncommitted
candidate and warm `out/` / `cache_forge/`. Do not reset or import phase09.

Read complete `migration/weighted-liquid/stage2-correction/report.md`,
`stage2-verification/report.md`, `stage2-verification/d1-analysis.md`, their
bindings and original phase13 directives. These live under
`docs/incidents/2026-09-16-dtf-recovery/` in the worktree.
Independent verification confirmed bounded NFT/W-L behavior, but reproduced
D1: 102 passing specs and one MissingRewardWeight failure. Forks 52/52,
operator tests 56/56, types and real CLI passed. Reports, seals, source
snapshots and old receipts are immutable history. Independent rebuilds
changed 13 artifact JSON hashes; the reconciliation file records why.

New producer evidence:
`migration/weighted-liquid/owner-bond-correction/`.
New independent evidence:
`migration/weighted-liquid/owner-bond-verification/`.
Never overwrite any earlier evidence directory.

## Exact behavior

1. Permit the current Crane proxy owner to execute the first genuine paid
   ordinary bond purchase during Stage1. Reuse ordinary purchase accounting,
   actual payment authorization, principal funding, standing-weight top-up,
   reward distribution and purchased-bond terms. Compensation/migration
   90-day cliff rules are not the purchased bond's terms.
2. Keep the exception narrow. Do not bypass the global acquisition gate for
   every owner call. Nonowner/pending/former owner calls, other Stage1
   acquisition routes, further Stage1 paid purchases after the qualifying
   first purchase, and all Stage1 legacy surrender remain closed.
3. Record successful purchase as an instance-level execution fact only
   after real nonzero paid principal is funded. Failure in payment, custody,
   minting, child funding, callback or settlement rolls back the entire fact
   and all economic effects. Do not count independent compensation, arbitrary
   staking, configuration, donations, reserve self-leg minting or an owner-set
   Boolean as the required purchase.
4. Activation requires this completed purchase on-chain before changing
   selectors or stage. Independent compensation alone does not satisfy it.
   Transfer of ownership or of the purchased NFT does not erase a completed
   instance purchase. Current owner authorization still controls activation.
5. Preserve the shared parent/child locks and Stage1 reward-payout gate,
   including fee/creator delivery and callback routes during the purchase.
   Fund and attribute real rewards under the existing machinery. No seed,
   fictitious stake, carry-forward policy, altered percentage or reward math.
6. After qualifying purchase, atomic activation still removes every
   administration/configuration/discretionary issuance route and opens
   ordinary deposits, eligible surrender and reward payouts. Stage2 ordinary
   purchases remain normally permissioned. Any new Stage1-only selector must
   be included in the actual irreversible cut; prefer reusing existing routes
   if that keeps permissions precise.
7. Keep frozen snapshot/configured credit immutable. A paid purchase is not
   compensation, cannot consume a migration entitlement, and cannot spend
   booked recovery inventory. No new product amount or bond duration is
   approved for public execution; choose explicit valid synthetic fixture
   values for tests and keep actual operator amounts explicit.

Read repo CLAUDE/ASSISTANT_RULES and applicable canonical Crane deployment,
architecture, testing, code-style, IndexedEx testing and script/programming
skills before edits. Allowed production scope is only Migration-specific
contracts/interfaces/facets/package/TestBase and neighboring tests; operator
scope is existing scripts/recovery/dtf-migration, corresponding Foundry
stages and runbook. No ordinary/common/Crane production, dependencies,
configuration, held phase09 work, public actions, commit, push or merge.

## Proof and operator sequence

Retain D1's actual ordinary-deposit assertion. Under the approved rule, test
activation without the paid purchase rejects with unchanged Stage1/routing;
then complete the real owner purchase, activate and execute the ordinary
deposit successfully. Do not make the test green by injecting unrelated
compensation or suppressing its deposit.

Cover owner/pending/former/nonowner and contract-owner authorization,
ordinary payment and funded principal, canonical weight/reward/backing
results, immediate and delayed first purchase, atomic failed-purchase
rollback, callback protection and Stage1 reward retention. Prove that
independent compensation alone does not permit activation, and owner/NFT
transfer after purchase preserves the historical prerequisite. Keep
postactivation ordinary bond and deposit behavior, and all confirmed
NFT/W-L stage/eligibility/custody/rounding/recovery negatives and positives.

Update the typed operator and real fixed18563 rehearsal to execute the
paid owner purchase before activation, reconcile its actual receipt and
funded bond, and avoid duplicate purchase on resume. Preserve actual
donation and independent-issuance mined-before-checkpoint crashes and
fresh-process resumes, outstanding-row reorder, and unclaimed zero issuance.
Do not assume old bond IDs or supply totals after inserting the purchase;
derive and verify the new exact values from the actual sequence.

Use the fixed checkpoint:
`.omo-runtime/dtf-migration-weighted-liquid/checkpoints`.
Keep port18563. Configure a new evidence parent so the CLI cannot overwrite
sealed prior runs. Root changes requirements in main; runtime workers bind
those exact current main files rather than stale worktree copies.

Run artifact-first Solar builds and complete current Migration specs/forks:
`PATH=/Users/cyotee/.foundry/bin:$PATH python3 scripts/forge-artifacts.py test
<actual changed production roots> --test-root
test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/migration/ -- -vv`
and the corresponding fork directory with `FOUNDRY_PROFILE=fork`.
Supply actual edited roots, not literal placeholders. Build both affected
operator stages before running them. Run existing three operator test files
once with `bun test --timeout 15000`, strict TypeScript using the existing
recorded command, and the real CLI pinned to block108944663 on port18563.
All required final checks must pass; do not label a failing suite accepted.
No full shared-suite replay is required unless actual input impact warrants
it. Preserve the gas/public-feasibility and other-source limitations.

## Handoff and independent verification

Producer writes final report, actual command results, source/artifact/input
and receipt bindings, snapshots and cleanup before declaring completion.
Explicitly confirm modifications stopped and no owned runtime remains.
Temporary idle or DAG completion does not satisfy this prerequisite.

Independent verifier reads the entire final producer report and actual
changed code, validates bindings, and executes bounded real checks including
the corrected D1 sequence and owner purchase, preserved surrender/recovery
and operator resumes. It writes only its own verification evidence and
witnesses, not production fixes. Return confirmed/needs-fix with exact
results, remaining limitations and owned-runtime cleanup.

Root admits a scoped commit stage only after the actual independent
handoff confirms a clean increment. This task does not restore the separate
held deployment-gas lane or claim full Migration/source-category completion.
