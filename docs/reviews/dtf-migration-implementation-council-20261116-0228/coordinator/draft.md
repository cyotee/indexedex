# Migration implementation council review - draft r1

Draft ID: `dtf-migration-implementation-council-20261116-0228-r1`.
Date: November 16, 2026. Profile: code review. Result: full four-member council.
This draft is preserved unchanged for one advisory feedback pass.

## Verdict

**The corrected plan is not fully and correctly executed.** Substantial contract
behavior is implemented and has passing test evidence, but source review found
two medium-severity correctness issues and one low-severity presentation issue.
The named evidence documents also need a current, coherent entry point.

The most material issue is a permitted partial bootstrap that leaves donated
capital booked but unavailable to any subsequent reserve-funding path. A
retained native QA lifecycle cannot make the owner purchase required for
activation. The mandatory owner's ordinary bond also displays rewards as
claimable while the contract still blocks their payment.

These are static source findings, not newly executed failing tests. No high or
critical defect was established; that is not a guarantee that none exists.
No implementation, project tests, builds, transactions or Git operations were
performed by this council. Only council review artifacts were authored.

## Authority and scope

The user's explicit request is to review implemented code against
`docs/incidents/2026-09-16-dtf-recovery/MIGRATION_DETF_IMPLEMENTATION_AND_TEST_PLAN.md`.
The coordinator read all 743 lines. Its preparation SHA-256 is
`affff781dfc522d96bba1c2fba28053ec5e7804f97c10504441445eaefef7949`.

The opening November 15 owner correction and sections 1.1-1.10 govern. The
deliverable is migration contracts and simple native Foundry scripts. The
withdrawn custom operator application, portable bundles, journals and application
crash recovery are not completion requirements. Neither historical holder
ancestry nor automatic price capture/no-setter rules are reinstated. Manual
Weighted policy inputs need supported canonical arithmetic, not equality to
a newly selected live production reserve.

The current primary checkout is the implementation target. The conformance
worktree was used only for historical execution evidence and byte comparison.
This is a shared live checkout, not an atomic whole-repository snapshot.
The plan's referenced baseline PRD was read by Astra and Kimi; explicit plan
supersessions prevail. No separate audit was supplied by the user.

Path abbreviations:

| Alias | Repository-relative path |
| --- | --- |
| M | `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/` |
| T | `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/migration/` |
| K | `test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration/` |
| S | `scripts/foundry/recovery/dtf-migration/` |
| D | `docs/incidents/2026-09-16-dtf-recovery/migration/` |
| B | `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/` |
| C | `contracts/vaults/detf/common/` |

## Findings

### F1 - Medium: permitted bootstrap leftovers cannot finish funding the reserve

**Locations:** `M/UniswapV4DetfMigrationAllocationTarget.sol:305-414`,
`M/UniswapV4DetfMigrationWeightedHookTarget.sol:327-377`,
`M/UniswapV4DetfMigrationPolicy.sol:29-63`,
`T/MigrationCore.t.sol:43-72`.

**Requirement:** Task 3's partial/corrective funding and residual handling,
MIG-P13, MIG-AC16 and the funding portion of MIG-AC31; E4 completion.

The owner may select a bootstrap amount smaller than booked donations:
`_genesisPreview` checks only that the selected amount is nonzero and no larger
than available inventory. The existing real-proxy test donates 100 ether of
each leg and bootstraps with 50 ether of each.

After that transition, unused non-self capital remains in `donationInventory`.
Bootstrap cannot be repeated because `isReserveLive` is set. Later live
donations add fresh receipts and release only those fresh amounts. The
permissionless sweep exposes `residualInventory`, while the old donation balance
remains below its protected floor.

The coordinator checked the alternative ordinary donation and recovery routes:
`B/UniswapV4DetfTarget.sol:732-776` takes new payment, and
`M/UniswapV4DetfMigrationRecoveryTarget.sol:441-468` spends separately booked
recovery inventory. Neither releases the genesis remainder. A scoped search
found donation-inventory mutations only in the allocation and retained
donation targets.

**Impact:** a valid partial bootstrap can strand a substantial amount of real
donated capital in the proxy, preventing it from reaching reserve liquidity.
This is an availability/accounting-transition defect, not demonstrated theft.

**Remediation requirement:** make booked genesis leftovers usable through a
fixed reserve destination, using existing accounting where possible. Preserve
separation from unsolicited assets, recovery inventory and bond backing; do not
add arbitrary withdrawals or execution.

**Acceptance:** on a real registry proxy, donate more than the chosen bootstrap
amount, bootstrap, then move the legitimate remainder into reserve liquidity
without new payment or personal issuance. Cover before/after activation and
conversion/join refunds, and retain exact inventory/supply/backing checks.

**Evidence:** current-source control/data flow plus an existing permitted test
setup. Confidence: high. No new reproduction was executed.
**Attribution:** Astra original R1, independently traced by the coordinator.

### F2 - Medium: retained native QA owner cannot satisfy activation

**Locations:** `S/MigrationCoreLocalQA.s.sol:41-82,266-344`;
`M/TestBase_UniswapV4DetfMigration.sol:97-136`;
`M/UniswapV4DetfMigrationAllocationTarget.sol:267-268`.

**Requirement:** plan section 1.5, retained working native scripts in Task 9/F3,
and native lifecycle validation in Task 10.

`deployAndIssue` assigns ownership to `MigrationCoreLocalOwner`, donates,
bootstraps and independently issues compensation. Neither it nor
`_migrationEnvironment` buys the mandatory ordinary owner bond. The helper's
entire API is bind, bootstrap, set/configure/issue and activate. It cannot
purchase a bond, forward arbitrary calls or transfer ownership.

`exerciseAfterCliff` calls that helper's `activate()` at line 320. If execution
reaches activation, the real prerequisite rejects with
`MigrationOwnerFirstBondRequired`: the marker is still zero, and the controller
EOA is not the current proxy owner. Independent compensation and elapsed time
do not satisfy the purchase.

The separate `runMixedRecordRehearsal` does buy an owner bond at line 171, but
creates a different fixture. The native transaction wrapper's `ownerFirstBond`
also does not repair this helper-owned instance. Compilation and operation-gas
tests do not execute the broken two-stage path.

**Impact:** this retained QA lifecycle cannot activate or reach its subsequent
reward assertions. The production activation guard is doing the correct thing.

**Remediation requirement:** add an explicit controller-authorized, genuinely
paid ordinary purchase through the QA owner and sequence it before activation.
Use separate real capital and preserve ordinary bond terms. Do not seed the
marker or substitute compensation.

**Acceptance:** execute the retained two-stage QA path against the actual
registry/proxy graph; assert payment, nonzero funded owner bond, prerequisite,
activation and subsequent claims. Keep a failure witness for missing purchase.

**Evidence:** current-source reachability analysis, not a newly observed revert.
Confidence: high. **Attribution:** independently reported by Astra R2 and Kimi
finding 1, then traced by the coordinator. Kimi's reference to nonexistent plan
section 1.11 is corrected here to section 1.5.

### F3 - Low: owner-first bond metadata reports closed rewards as claimable

**Locations:** `M/bondNft/UniswapV4DetfMigrationBondMetadataTarget.sol:30-32`;
`C/bondNft/DETFFundedBondMetadata.sol:34-42,105-116,166-179`;
`M/bondNft/UniswapV4DetfMigrationBondNFTVaultTarget.sol:73-78`.

**Requirement:** Task 5's truthful metadata and activation-gated reward
presentation, read with section 1.5 and MIG-P08.

The paid owner's ordinary bond is intentionally not a migration-cliff position
and has an ID above the reserved roles. Metadata therefore sets
`migrationPresentation` false and consequently `rewardsClosed` false even
before activation. Shared rendering describes rewards as claimable during
vesting and includes accrued rewards in its numeric claimable totals.

The actual child gates every rewards-only or combined claim on activation.
The owner's ordinary principal terms are correct and must remain ordinary.

**Impact:** NFT consumers display reward amounts that cannot yet be paid. This
does not bypass the payout gate or release funds.

**Remediation requirement:** derive reward availability from parent activation
for every bond in this migration instance, independently of principal vesting
style. Preserve ordinary-package rendering and linear principal for ordinary
purchases.

**Acceptance:** inspect the paid owner's numeric JSON attributes and rendered
availability before and after activation; test principal terms separately.

**Evidence:** source-level renderer/payout mismatch; no new runtime rendering.
Confidence: high. **Attribution:** Astra R3, verified by the coordinator.

### F4 - Low: named completion documents do not present the current native result

**Locations:** `D/verification.md:1-3,14-25,58-71`;
`D/quote-evidence.md` (historical frozen-capture record);
`D/source-route-matrix.md:3`; `D/recovery-route-disposition.md:3`;
`D/foundry-runbook.md:7-16`.

**Requirement:** Tasks 2/10 and F4 name usable pricing/completion evidence,
commands, versions, results, gas bounds and remaining limitations.

The verification entry remains a November 13 operator-era record. The quote
entry describes superseded one-shot capture. Both route indexes cite the prior
plan hash and 98,213-byte size, while the corrected current plan has 97,559
bytes. The live runbook hardcodes a machine-specific conformance worktree.

These documents are historical evidence, not false test runs. Newer native
results and gas limits do exist. The problem is the missing current navigation
and reconciliation, not missing behavior inferred solely from stale prose.
The two retained scripts changed after the earlier task-13 snapshot currently
match byte-for-byte between the primary checkout and the runbook worktree;
different current script contents there were not established.

**Remediation requirement:** add a dated, source-qualified current completion
entry and clear links from plan-named evidence. Preserve historical records,
identify supersessions, give a portable repository-root instruction, and link
the current native build/test evidence and measured gas limits. Record F1-F3
as open until separately fixed and verified.

**Acceptance:** a reader following the plan can distinguish current native
scope, historical evidence, exact tested sources/commands, measured batch
shapes and unresolved work without reconstructing private session history.

**Evidence:** current document reads and cross-references. Confidence: high.
**Attribution:** consolidates Grok's document findings, Kimi finding 4, and
MiniMax F1/F3/F5, with narrower severity and impact.

## What is implemented and tested

The reviewed paths substantially implement complete manual Weighted books,
full-original quoting and proportional stored-credit consumption; expected-book
load checks; stable economic originals and immutable prior issuance; configured
original-wallet Stage 2 custody; both NFT generations and distinct NFT 3
contributions; source-specific gons/shares/weights; exactly funded fresh
90-day cliffs; instance-wide reward gates; current-owner administration; paid
owner-first activation; removal of all sixteen administration selectors; and
typed bounded recovery with repeatable reward-only harvesting.

Tests use real registry-deployed proxies and production children. Inspected
assertions check custody, exact funding, supply/gons, rollback, selector removal
and successful invariant actions. Passing tests did not cover the disputed
continuation in F1, the exact retained script path in F2, or F3's ordinary
owner-bond metadata.

## Existing runtime evidence and its limits

| Evidence | Observed result | Scope |
| --- | --- | --- |
| Current `.omo/verification/artifact-mismatch-20261116/full-hermetic.log:37617` | 28,641 passed; 0 failed/skipped; 2,691 suites | Existing primary-checkout full hermetic run; council read raw summary |
| Original conformance worktree `.omo/verification/dtf-operator-removal-20261115/native-spec.log:514` | 236 passed; 0 failed/skipped; 34 suites | Post-removal Migration hermetic run |
| Same worktree `native-fork.log:987` | 183 passed; 0 failed/skipped; 30 suites | Pinned legacy Migration forks |
| Primary `.omo/verification/dtf-operator-removal-20261115/REMOVAL.md:39-68` | Native build and suites recorded exit 0 | Scripts compiled; report expressly does not claim broadcast |
| Primary `.omo/verification/artifact-mismatch-20261116/DIAGNOSIS.md:23-52` | Single-Solar rebuild, 279 affected tests and full hermetic run recorded exit 0 | Artifact repair; reports no contract/test edits; forks not rerun afterward |
| `D/conformance-20261114/task-11/batch-limits.md:3-30,43-95` | Recorded 32,000,000 target transaction ceiling and selected batch measurements | Historical measured shapes; not arbitrary Cartesian products |

Raw Migration logs reside at
`/Users/cyotee/Projects/indexedex-wt/dtf-conformance-20261115-wave-1/`.
They were read there, not presumed absent because missing from the main tree.
Exit codes above are retained report/receipt evidence; no council-run exit
is invented.

The coordinator compared 299 task-13 manifest entries across relevant
implementation/test/script roots: 293 match current bytes; the differences are
four explicitly removed app-only Solidity files and two retained scripts.
All current Solidity files in the four primary target roots were represented.
The latter scripts also match the post-removal evidence worktree today.
MiniMax separately reports exact equality for all 126 primary target files and
1,594 `contracts/` files across those two checkouts; that broader comparison is
member-supplied evidence, not a coordinator-repeated certification.

These comparisons support source applicability, not complete compiler,
dependency or runtime-byte identity. The November 16 artifact rebuild did not
include a fresh fork replay. Do not discard valid retained source-bound fork
evidence solely for that reason, or call it proof of every new artifact.

Gas evidence explicitly selects separate loading and issuance shapes, including
64 one-original recipients for loading, 32 for issuance, and one recipient with
64 originals. Recovery measures up to eight Weighted claims or one other typed
step. The report excludes 64-recipient issuance from its admitted limit.
Measurements do not approve arbitrary arguments or a public deployment.

## Coverage and requirement dispositions

Every member's original contains detailed requirement traces. The following
is the coordinator's adjudicated disposition, not an assertion of exhaustive
line-by-line review or a new test run.

| Required target | Coverage |
| --- | --- |
| M implementation/interfaces/TestBases/handlers | 63 Solidity files inventoried; core pricing, allocation, custody, funding, recovery, child gates and composition reviewed; some handler/boilerplate/dependency bodies partial |
| T hermetic specifications | 28 Solidity files inventoried; key bodies inspected; existing 236-case execution supplied; remaining assertions partly mapped by suite/name |
| K fork specifications | 31 Solidity files inventoried; key source/custody/reward/rollback cases inspected; existing 183-case execution supplied; not every external source reauthenticated |
| S native scripts and runbook | Four scripts inventoried; typed transaction wrapper and disputed QA lifecycle read; some infrastructure helpers partial; no new script execution |
| Shared DETF, bond, staking, SY and Weighted extension points | Relevant methods and tests examined selectively; no whole-repository audit |
| D and admitted verification records | Relevant route, pricing, gas, build/test records read selectively; large archives not exhaustively read |

MiniMax's opening inventory counts (72/33/36) conflict with its own later
126-file comparison and the coordinator's actual 63/28/31/4 Solidity inventory.
Its broad "examined" labels are treated as partial where it discloses extraction
or unread bodies. No count-based completeness claim relies on that discrepancy.

| Task | Disposition |
| --- | --- |
| 1 Source/custody/provenance | Implemented and tested within fourteen pinned source categories; financial eligibility and full independent source reauthentication not certified |
| 2 Manual Weighted pricing | Supported models implemented with current differential tests; stale named evidence entry under F4 |
| 3 Package/owner/bootstrap | Incomplete: F1; positive deployment/bootstrap coverage remains valid |
| 4 Configuration/consumption | Implemented and tested at reviewed scope, including A/B and immutable issuance |
| 5 Cliff/reward behavior | Economic behavior substantially implemented/tested; presentation incomplete under F3 |
| 6 Atomic surrender | Implemented and tested within admitted source/claim domains |
| 7 Startup/irreversible activation | Implemented and tested at reviewed proxy/child scope |
| 8 Recovery/donations | Implemented and tested for selected typed routes and measured shapes; source conditions remain explicit |
| 9 Native scripts | Incomplete: F2; removed application requirements stay withdrawn |
| 10 Full validation | Broad passing native/fork/ordinary evidence; complete closure blocked by F1-F3 and current reporting under F4 |
| F1 Policy/source verification | Substantial source coverage; full funding-policy closure blocked by F1 |
| F2 Proxy/money-path verification | Substantial real-proxy evidence; F1 remains uncovered |
| F3 Native execution | Compilation and contract suites supplied; retained QA path blocked by F2 |
| F4 Completion record | Incomplete under findings and F4 documentation gap; no deployment authority implied |

| Policy/gate | Disposition |
| --- | --- |
| MIG-P01 | Full-original quote once per load; implemented/tested |
| MIG-P02 | Stored-credit proportional consumption and residue; implemented/tested |
| MIG-P03 | Actual remaining principal fraction; implemented/tested |
| MIG-P04 | Empty/burned/nonexistent rejection; implemented/tested |
| MIG-P05 | Whole-NFT consumption and source-unit conservation; implemented/tested under reviewed canonical inputs |
| MIG-P06 | Exact funded new bonds and NFT 3 exception; implemented/tested |
| MIG-P07 | Fresh 90-day clocks; implemented/tested |
| MIG-P08 | Economic reward gate implemented/tested; metadata mismatch F3 |
| MIG-P09 | Separate independent compensation; implemented/tested under reviewed disjoint originals |
| MIG-P10 | Full replacement preserving issuance; implemented/tested |
| MIG-P11 | Paid-first-bond activation and permanent administration cut; implemented/tested |
| MIG-P12 | Proxy current-owner administration; implemented/tested; QA caller path F2 |
| MIG-P13 | Funding without added lifecycle gates implemented; unusable genesis remainder F1 |
| MIG-P14 | Bounded typed iterative recovery; implemented/tested |
| MIG-P15 | Original-wallet custody and all admitted categories; implemented/tested within supplied source domains |
| E1 | Fourteen source categories indexed with pinned execution evidence; no complete independent archive reauthentication |
| E2 | Wallet/configuration/custody/conservation evidence supplied |
| E3 | Declared manual models have canonical differential evidence; unsupported domains reject; current evidence navigation F4 |
| E4 | Positive bootstrap works; partial-capital continuation incomplete under F1 |
| E5 | Economic payout closure supported; presentation issue F3 is not a bypass |

The acceptance table below applies all section 1 supersessions. "Supported"
means implemented with relevant inspected source and supplied test evidence,
within the coverage limits above.

| ID | Disposition and principal trace |
| --- | --- |
| MIG-AC01 | Supported: exchange/bond Stage 1 gates; T/MigrationOwnerFirstBond |
| MIG-AC02 | Supported: W/R surrender gates; K/MigrationOriginalWallet |
| MIG-AC03 | Supported: indirect acquisition/callback negatives; T/MigrationSurface and OwnerFirstBond |
| MIG-AC04 | Supported: full-value loaders/replay/cut; allocation targets and configuration suites |
| MIG-AC05 | Supported: current-owner authorization and rollback; T/MigrationAdministration |
| MIG-AC06 | Supported: custody/funding atomicity; K/MigrationNftLifecycle |
| MIG-AC07 | Supported as revised: original quote times actual principal fraction; M/legacy/MigrationLegacyNftLib |
| MIG-AC08 | Supported: rewards excluded from eligible principal; K/MigrationLegacySources |
| MIG-AC09 | Supported within canonical-original assumptions: cross-representation collision/consumption tests |
| MIG-AC10 | Supported: recovery and new funded bond principal separate; recovery conservation tests |
| MIG-AC11 | Supported: distinct principal/share/gon/weight units; source-specific forks and matrix |
| MIG-AC12 | Supported: ordinary-package isolation; T/MigrationSurface and full regressions |
| MIG-AC13 | Supported: independent versus held-exposure paths; allocation/surrender suites |
| MIG-AC14 | Supported: common migration cliff and economic reward gate; bond child/core suites |
| MIG-AC15 | Supported as revised: current owner pricing/harvest authority; administration tests |
| MIG-AC16 | Incomplete: admitted genesis capital can remain unusable, F1 |
| MIG-AC17 | Supported: fixed recovery donation without ordinary purchase; K/MigrationRecoveryDonation |
| MIG-AC18 | Supported for indexed categories; no exhaustive allocation/provenance approval |
| MIG-AC19 | Supported: cliff boundaries; core/surface/invariant tests |
| MIG-AC20 | Supported: accrued rewards retained/released once; egress/retained-accounting tests |
| MIG-AC21 | Supported as revised: canonical full-original manual quote; pricing/differential suites |
| MIG-AC22 | Supported as revised: stored quote/fraction stability; pricing/source tests |
| MIG-AC23 | Supported under reviewed inputs: routed/claimed representations do not create duplicate originals |
| MIG-AC24 | Supported as revised: A/B keep-until-reloaded and cut; T/MigrationWeightedPricing |
| MIG-AC25 | Supported: actual fresh creation clocks; K/MigrationWeightedSy and NftLifecycle |
| MIG-AC26 | Supported in production activation; retained QA cannot reach it, F2 |
| MIG-AC27 | Supported: actual sixteen-selector removal/restoration negatives; surface/deployment tests |
| MIG-AC28 | Supported: repeat activation cannot restore state; surface/invariant tests |
| MIG-AC29 | Supported for retained production operations; F1 specifically limits old donation inventory |
| MIG-AC30 | Supported at reviewed registry routes; exhaustive per-route disable/re-enable matrix not independently established |
| MIG-AC31 | Incomplete native/funding scope under F1/F2; custom resume application withdrawn |
| MIG-AC32 | Supported: current-owner harvest authorization; recovery tests |
| MIG-AC33 | Supported for selected measured shapes; task-11 gas records and K/MigrationRecoveryGas |
| MIG-AC34 | Supported: repeat/overlap/new-income accounting; recovery accrual tests |
| MIG-AC35 | Supported as revised: configured original wallet; K/MigrationOriginalWallet |
| MIG-AC36 | Supported as revised: remaining fraction changes award, not original quote; legacy tests |
| MIG-AC37 | Supported: no postactivation loader/source mutation; surface tests |
| MIG-AC38 | Supported: current B configuration with immutable A issuance; pricing/core tests |
| MIG-AC39 | Supported as revised: conserved wallet Q/C and terminal residue; source-unit tests |
| MIG-AC40 | Supported: failed surrender rolls back; NFT/source rollback tests |
| MIG-AC41 | Supported: partial fungibles, whole NFTs; source-specific tests |
| MIG-AC42 | Supported: surrendering configured wallet receives bond; no beneficiary input |
| MIG-AC43 | Supported: transfers preserve principal clock/rights; bond/source/invariant tests |
| MIG-AC44 | Supported: whole selected recovery transaction rollback; recovery/invariant tests |
| MIG-AC45 | Supported: staged recovery and fixed destination; recovery donation tests |
| MIG-AC46 | Supported: explicit per-proxy owner and isolated construction; core/deployment tests |
| MIG-AC47 | Supported: current/pending/former owner semantics; owner-first/pricing tests |
| MIG-AC48 | Supported at reviewed composition/proxy scope; no exhaustive dependency audit |
| MIG-AC49 | Supported as revised: load without mint, then actual NFT fraction; NFT configuration/forks |
| MIG-AC50 | Supported: collection plus token ID plus original wallet; NFT/source tests |
| MIG-AC51 | Supported under reviewed originals: recipient consolidation sums independent original quotes |
| MIG-AC52 | Supported contract A/B replacement/replay/cut; custom journal/resume requirements withdrawn |
| MIG-AC53 | Supported economic payout closure; F3 is misleading presentation only |

Source categories include both NFT and liquid DETF generations, weighted and
earlier receipts, weighted SY, prepared TokenStaking rights, direct claim-vault
shares, DTF-custody SE, weighted-WETH and earlier SE shares, and both physical
LP categories. Conditional enablement/fee authority and earlier-LP permanent
custody remain source-specific. Prepared claimed-SY coverage is bounded to the
demonstrated direct-caller domain; it does not approve raw-weight ERC20 pulls
or every delegated-wallet history.

Section 8.1's exact examples and successful-action invariants have member
traceability in the originals; examples are not used to waive the uncovered
F1-F3 cases. No production allocation, manual book or recipient dataset is
approved by this review.

## Disagreement and findings not adopted

All four original verdicts were "not fully executed", but their reasons differ.
Agreement on that label does not prove correctness. The coordinator adopts
source-supported findings, not a vote tally.

1. **Grok's broad current-fork/script-evidence gap is not adopted as stated.**
   The raw 183-case post-removal fork log exists in the named worktree; source
   applicability is supported by comparisons. The retained scripts have a
   post-removal compile record, and the two changed script files match the
   evidence worktree. Exact regenerated-artifact replay remains a limitation.
2. **Absent target-gas bounds is refuted.** Both Grok and MiniMax missed
   `D/conformance-20261114/task-11/batch-limits.md`. It contains numeric limits,
   selected shapes, measured values and receipt locators. Improve navigation
   under F4; do not invent missing gas work.
3. **MiniMax's TokenStaking adapter dependency is not established and is not
   adopted.** `K/MigrationWeightedSy.t.sol:70-101` verifies source phase 2 and
   uses the existing `withdrawClaim` path, followed by configuration and
   surrender at 103-190. The retained fork log at 960-967 records all six
   `MigrationClaimedSyTest` cases passing. The separate
   `contracts/protocols/staking/token/TOKEN_STAKING_MIGRATION_ADAPTER.md:24-41`
   describes migration into the old claim system and expressly says later
   `withdrawClaim` does not call that adapter. Its unrelated test/document
   questions are not evidence that this accepted prepared-SY route is missing.
4. **Kimi's missing native NFT wrapper is a non-blocking usability observation
   on the current wording.** The typed script configures NFTs but has no NFT
   surrender wrapper. The production NFT operation exists. Task 9's corrected
   explicit operation list does not require a wrapper for every user selector.
   Adding/documenting one is useful, but this report does not classify its
   absence as a missing production route or independently sufficient blocker.
5. **Stale plan fingerprints do not invalidate unchanged custody evidence.**
   They belong in F4's documentation correction. No recovery rerun is demanded
   merely because an operator-app scope paragraph changed.
6. **No-defect originals are bounded observations.** Grok, Kimi and MiniMax
   did not identify Astra's F1/F3 paths; their partial coverage does not refute
   the source traces. F2 was independently found by Astra and Kimi.

## Participation and workflow

| Participant | Requested route | Exposed actual identity | Initial task/status |
| --- | --- | --- | --- |
| Coordinator | Invoking agent | environment: xai/grok-4.7; reasoning not exposed | owner session 01a1e22e-b829-7883-8d66-f8c1391146d6; not a vote |
| Astra | chatgpt-subscription/gpt-6-astra:high | Native completion: council-member, chatgpt-subscription/gpt-6-astra; reasoning not exposed there | st_01a1e26e; substantive complete |
| Grok | xai/grok-4.7:high | Native completion: council-member, xai/grok-4.7; reasoning not exposed there | st_01a1e26f; substantive complete |
| MiniMax | minimax/MiniMax-M3 | Native completion: council-member, minimax/MiniMax-M3; local adaptive override observed, actual request thinking not exposed | st_01a1e270; substantive complete |
| Kimi | kimi-coding/k3.1-pro:high, global | Native task-output: kimi-coding/k3.1-pro:high, reasoning high | st_01a1e271; substantive complete |

All four initial tasks settled before this draft. No provider substitutions,
replacement members or extra independent votes were used. Originals are
preserved under `members/<member>/response.md`.
Grok and Kimi returned inline originals after a missing patch tool; the
coordinator archived them verbatim. MiniMax disclosed using an alternate
single-file writer despite the brief's inline-only fallback instruction.
Its output stayed at its assigned report path; the tool-method deviation is
recorded rather than presented as compliance. Astra published its own original.

One advisory pass on this exact draft is next. Feedback is advisory; the final
resolution will preserve disagreements and distinguish coordinator revisions
from reviewed draft text. No further review round is required by this report.

## Limitations and remediation boundary

This review used source reading, scoped searches, read-only byte comparisons and
existing execution logs. It did not rerun tests, render NFT output, broadcast
scripts, verify current public-chain state or audit every dependency/archive.
Some coverage is partial as disclosed. No new failing test is claimed.

The final remediation document will require fixes and focused regressions for
accepted F1-F3 and current evidence navigation for F4. Those are recommendations,
not authorization to edit code or execute public operations. Retain all source
evidence and passing results; do not restore the withdrawn operator application
or weaken tests to close the report.
