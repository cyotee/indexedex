# Astra independent migration implementation review

## Identity

- Member: Astra.
- Profile: review.
- Phase: initial independent response.
- Requested role: `council-member`.
- Requested model: `chatgpt-subscription/gpt-6-astra:high`.
- Runtime model, provider and reasoning configuration: not exposed.
- Date: November 16, 2026.
- Run: `dtf-migration-implementation-council-20261116-0228`.
- Implementation target: the current `/Users/cyotee/Projects/indexedex` checkout. Historical worktrees were used only for supplied execution logs.

## Question and targets

Was `MIGRATION_DETF_IMPLEMENTATION_AND_TEST_PLAN.md` fully and correctly executed, applying its November 15 scope correction and sections 1.1-1.10?

**Execution verdict: not fully executed.** The current contracts substantially implement the accepted migration behavior, and substantial passing execution evidence exists. However, a permitted bootstrap can strand previously donated capital outside every usable reserve-funding budget. A retained native QA lifecycle cannot perform the mandatory owner-first purchase and therefore cannot activate its instance. The paid owner's ordinary bond also reports rewards as claimable while activation still prohibits their payment.

These are current-source findings, not deductions from old failure reports. They do not reinstate the removed application, portable bundles, journals, automatic snapshot capture, historical transfer ancestry, or a selected live reserve composition.

I read the complete brief, complete supplied plan and complete baseline PRD. The PRD currently identifies itself as revision r24; the plan's explicit supersessions govern its retained older wording. The plan fingerprint supplied in the brief is provenance supplied by the coordinator, not a hash computed in this review.

Path abbreviations below are exact repository-relative expansions:

| Prefix | Expansion |
| --- | --- |
| `M/` | `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/` |
| `T/` | `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/migration/` |
| `K/` | `test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration/` |
| `S/` | `scripts/foundry/recovery/dtf-migration/` |
| `D/` | `docs/incidents/2026-09-16-dtf-recovery/migration/` |
| `B/` | `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/` |
| `C/` | `contracts/vaults/detf/common/` |

## Review findings

### R1 - Medium: unused genesis donations become inaccessible to reserve funding

**Current locations:** `M/UniswapV4DetfMigrationAllocationTarget.sol:305-365,369-414`; `M/UniswapV4DetfMigrationWeightedHookTarget.sol:327-377`; `M/UniswapV4DetfMigrationPolicy.sol:29-63`.

**Violated obligations:** Task 3's partial funding, corrective donation and residual handling; MIG-P13; MIG-AC16 and the funding portion of MIG-AC31. E4's positive empty-reserve bootstrap witness does not establish usable handling of all admitted funding.

The owner may bootstrap with less than the booked donation inventory: `_genesisPreview` checks `leg.amount <= available`, not equality. The existing real-proxy test already uses this permitted shape: it donates 100 ether of each leg and bootstraps with 50 ether of each (`T/MigrationCore.t.sol:43-71`). The unused quantities remain in `donationInventory`.

After successful bootstrap:

1. `bootstrapMigrationReserve` rejects because `isReserveLive` is true (`AllocationTarget:311`), and activation subsequently removes the selector.
2. A live `donateMigrationCapital` releases only the fresh amounts pulled or wrapped by that call (`WeightedHookTarget:359-377`). It first increments the donation book by those same receipts. A new donation therefore does not reduce the old remainder.
3. `sweepDust` cannot spend the remainder: `_beginBudget` sets the protected floor to held balance minus `residualInventory`, and `_residualBalance` exposes only the excess above that floor. The old donation book is not moved into `residualInventory`.
4. The inherited donation route pulls a new payment through the bond child (`B/UniswapV4DetfTarget.sol:732-776`). The recovery route debits a separate recovery inventory (`M/UniswapV4DetfMigrationRecoveryTarget.sol:441-468`). Neither releases old genesis donation inventory.

The scoped search for `donationInventory` found its mutations only in the allocation and retained funding targets. There is no other release operation in the migration implementation. The common sweep consistently uses the overridable residual budget (`B/UniswapV4DetfCommon.sol:497-575`).

**Impact:** an allowed partial bootstrap leaves real donated tokens under protocol custody but unusable as reserve funding through the installed routes. This can be a large remainder, not merely unavoidable dust. The accounting can remain internally consistent while the intended recovery capital never reaches the reserve.

**Minimal fix direction:** provide a fixed-destination way to finish joining already booked donation capital, or transfer appropriate genesis leftovers into the existing spendable residual accounting at the bootstrap transition. Preserve the separation from unsolicited balances and legacy recovery inventory. Do not solve this with an arbitrary withdrawal or execution router.

**Regression needed:** donate more than the selected bootstrap amount, bootstrap successfully, then prove the remaining booked capital can reach the reserve without another payment or compensation issuance, before and after activation. Include conversion/join refunds.

**Confidence:** high. **Evidence class:** current-source control/data-flow finding, supported by an existing permitted setup. I did not execute a new reproduction. The existing partial-capital test passes but stops before proving progress for its remainder.

### R2 - Medium: retained native local QA cannot satisfy its own activation prerequisite

**Current locations:** `S/MigrationCoreLocalQA.s.sol:41-81,266-320`; prerequisite at `M/UniswapV4DetfMigrationAllocationTarget.sol:267-268`; owner purchase guard at `M/UniswapV4DetfMigrationBondFacet.sol:38-55`.

**Violated obligations:** retained native scripts in Task 9 and F3; section 1.5's actual paid owner-first purchase; usable native lifecycle validation in Task 10.

`deployAndIssue` deploys `MigrationCoreLocalOwner`, makes that contract the migration owner, funds/bootstrap-configures the instance, and issues an independent compensation bond. It does not buy an ordinary bond. The helper's complete callable administration API consists of `bind`, `bootstrap`, `setConfigureIssue` and `activate`; it has no paid purchase, generic forwarding or ownership-transfer operation.

`exerciseAfterCliff` eventually calls `account_.activate()` at line 320. That reaches the real `activateMigration`, which requires a nonzero `ownerFirstBondTokenId`. Only the current owner can make the qualifying Stage 1 ordinary purchase, and this owner contract has no route to make it. Independent issuance, waiting 90 days, principal claims and donations cannot set the marker. The controller EOA calling the parent's purchase method is not the current proxy owner.

**Impact:** the retained `deployAndIssue` -> `exerciseAfterCliff` native QA lifecycle cannot reach activation or its later reward assertions. The required contract prerequisite is correctly enforced; the QA script is out of sync with it. This finding does not concern the withdrawn application.

The ordinary native transaction wrapper does contain a paid purchase stage (`S/Phase_08_Stage_01_MigrationExecution.s.sol:224-232`). That does not repair this separate helper-owned QA instance. `T/MigrationOperationGas.t.sol:8-14` exercises `_operationSamples`, not these two QA entrypoints; compiling the retained scripts does not execute this lifecycle.

**Minimal fix direction:** give the QA owner helper an explicit controller-authorized, genuinely paid ordinary purchase operation and sequence it before activation. Verify real payment, funded nonzero principal and the recorded prerequisite; do not seed a marker or add compensation to bypass it.

**Confidence:** high. **Evidence class:** current-source reachability finding. No new script or test was run. The failure is asserted at the activation step if execution reaches it, not presented as an observed failing log.

### R3 - Low: owner-first bond metadata advertises unavailable Stage 1 rewards

**Current locations:** `M/bondNft/UniswapV4DetfMigrationBondMetadataTarget.sol:30-32`; `C/bondNft/DETFFundedBondMetadata.sol:34-42,105-116,166-179`; actual payout gate at `M/bondNft/UniswapV4DetfMigrationBondNFTVaultTarget.sol:73-78`.

**Violated obligations:** Task 5's metadata consistency and activation-gated reward presentation, read with section 1.5 and MIG-P08.

The owner's paid first ordinary bond intentionally has `isMigrationPosition == false` and an ID above the reserved roles. Consequently `migrationPresentation` is false and `rewardsClosed` is forced false even while the parent remains inactive. The shared renderer then describes rewards as claimable during vesting and includes accrued rewards in its numeric "Claimable rewards" and "Total claimable" values.

The real child's reward/combined claim methods reject until activation for this bond too. `T/MigrationOwnerFirstBond.t.sol:34-74` explicitly checks both its ordinary marker/vesting and the reward rejection. The metadata test at `T/MigrationSurface.t.sol:118-135` checks a compensation cliff bond only.

**Impact:** NFT consumers can display a claimable amount that cannot be paid. This does not release funds or bypass the reward gate.

**Minimal fix direction:** derive reward availability from the parent activation state for every bond in this migration instance, independently of whether principal uses a cliff or ordinary linear vesting. Preserve ordinary-package rendering and the owner's ordinary principal terms. Check numeric attributes and the rendered availability for the paid first bond before/after activation.

**Confidence:** high. **Evidence class:** current-source presentation/behavior mismatch; no rendered image or new runtime test was produced in this review.

## Evidence

### Supplied execution evidence actually inspected

The following are existing runs. I performed no builds, tests, shell commands, Git operations, RPC calls or transactions.

| Evidence | What it establishes | Qualification |
| --- | --- | --- |
| `.omo/verification/dtf-operator-removal-20261115/REMOVAL.md:39-67` | Retained contracts/scripts compiled; 236 Migration hermetic and 183 fork cases passed after application removal. | Build exits/toolchain are supplied record claims. It explicitly says the retained scripts were not broadcast. |
| Historical worktree `.omo/verification/dtf-operator-removal-20261115/native-spec.log:514` | Raw summary: 236 passed, zero failed/skipped, 34 suites. | The worktree is evidence only. Named passes were also checked, including pricing, partial capital, metadata, owner purchase and both native invariants. |
| Same historical directory, `native-fork.log:987` | Raw summary: 183 passed, zero failed/skipped, 30 suites. | Named passes at lines 777, 810, 813, 850-851 and 966 include earlier LP authority, second-contribution rollback, NFT 3, iterative reward harvesting and conserved claimed-SY. |
| `.omo/verification/artifact-mismatch-20261116/DIAGNOSIS.md` | Records fresh single-Solar artifact generation, an exit-zero build, 279 affected-suite passes and the full hermetic pass without Solidity/test changes. | Resolves the known mixed-artifact diagnosis as supplied evidence. I did not independently inspect every regenerated artifact. |
| `.omo/verification/artifact-mismatch-20261116/full-hermetic.log:37617` | Raw summary: 28,641 passed, zero failed/skipped, 2,691 suites. | Current primary-checkout run. Relevant Migration suite headers are present at lines 19608, 21099, 21742, 22644, 22720 and 23483. |
| `D/conformance-20261114/task-13/report.md:27-45` | Historical ordinary regression summaries and source-qualified reuse of target gas receipts. | Reports 9,560 V4 DETF cases and 372 common bond/staking cases; Weighted subset 2,272 is not additive. Removed operator failures are historical, not current obligations. |
| Coordinator's additional evidence message | Supplied SHA-256 comparison: 293/299 relevant files match task-13's final manifest; four expressly removed app-only Solidity files are absent and two retained scripts differ. No current Solidity in the four primary target roots was missing from that map. | Coordinator-supplied, not recomputed here. It is not complete dependency or artifact equality certification. |

The historical log directory above is under `/Users/cyotee/Projects/indexedex-wt/dtf-conformance-20261115-wave-1/`. No implementation conclusion was drawn from that worktree's source.

### Source and gas records

- `D/source-route-matrix.md:5-35` indexes fourteen categories at chain 4663, block 108944663, hash `0xc497433dd691a40cb85959cfeba2e3fff85a975ae060612d984998e1d5765733`. It distinguishes proxy runtime identity from delegated-facet identity. `D/source-manifest.json:1-85` was sampled to inspect its binding format and explicit limitations; the entire 1,648-line manifest and all linked deployed-source archives were not independently reauthenticated.
- `D/recovery-route-disposition.md:11-50` distinguishes working conditional routes from earlier physical LP permanent custody. The actual LP test at `K/MigrationLegacyLpExit.t.sol:38-125` checks the pinned facet hashes, fee-role change, time, parent intake rejection and the different Weighted fee-recipient exception.
- `D/conformance-20261114/task-11/batch-limits.md:3-30,43-95` records a 32,000,000 target transaction ceiling, selected operation sizes, unrelated populations and signed receipts. Examples include 32-recipient issuance at 15,940,796 gas, 64-recipient loading at 17,859,090 gas, and eight Weighted claims at 1,783,679 gas. These are recorded historical measurements, not fresh estimates or guarantees for arbitrary payloads.
- That gas record preserves separate axes for recipients and originals per recipient. It does not approve their Cartesian product; 64-recipient issuance exceeds the measured limit. Recovery measurements compare selected work against unrelated custody populations. `T/MigrationDeploymentGas.t.sol:36-65` separately performs preparation/finalization calls capped at 32,000,000, rather than treating whole-test gas as transaction gas.
- `D/quote-evidence.md` is predominantly the older automatic-capture increment. Its earlier live-composition prerequisite is superseded. Current manual evaluation was assessed from `M/UniswapV4DetfMigrationWeightedPricingLib.sol` and the current manual pricing/differential tests, not by relabeling that old report.
- `D/verification.md` remains an older, qualified record. Its old pending labels are not evidence that the newer admitted runs failed.

### Evidence gaps, separate from defects

1. There is no inspected execution of the exact R1 remainder-progress scenario or R3 paid-bond metadata scenario. Their findings are static; existing successful tests do not exercise the disputed continuation/presentation.
2. The supplied post-removal compilation is not execution of every retained script entrypoint. R2 identifies a concrete missing transition in one of them.
3. No fresh target-chain cold signed-envelope replay of all newly regenerated November 16 artifacts was supplied in the inspected records. Historical gas receipts have source-qualified reuse evidence, and current bounded-call tests pass. Those facts support the measured shapes; they do not certify every compiler/dependency/artifact combination or operational argument set.
4. Full archive-source identity verification, every original-wallet/contribution record, and an approved operational allocation dataset were not supplied as independently checked facts in this review. The owner-authorized loaders still require reviewed inputs. A passing synthetic claim fixture is not an allocation approval.
5. Invariant execution is bounded: supplied native and fork logs report 16 runs, 128 calls and zero reverted handler calls for the inspected invariant targets. This is meaningful positive-action coverage, not an exhaustive proof.

The removed application's witness-pin failure, portable relocation proof, donor-bundle rehearsal and transaction journals are **superseded requirements**, not evidence gaps that must be restored.

## Assumptions

- The explicit owner-loaded historical contributions, original wallets and canonical fungible original IDs are trusted configuration inputs after review. The contract checks matching configured identity and actual custody; it does not discover historical eligibility. Different aliases for one economic original must not be approved as separate originals.
- Original-wallet eligibility does not travel with a transfer. The original wallet must regain/control and surrender the asset; no intermediate transfer ancestry is required.
- Manual books are owner-selected policy operands. Deliberately adjusted inputs do not need to match live pools. Supported arithmetic must remain canonical, and unsupported models must reject.
- Source enablement, genuine reward income and actual legacy fee-role changes remain external prerequisites where documented. Conditional recovery is not unconditional availability and is not permission to transact with legacy governance.
- The earlier physical LP custody disposition is confined to the authenticated existing authority surface. It is not a claim that future unrelated markets can never exist.
- The checkout is live. I did not freeze it or perform Git/source-tree fingerprint operations. The reviewed locators describe the bytes read in this pass.

## Coverage

### Required target groups

| Group | Status and examined scope | Omitted scope |
| --- | --- | --- |
| 1. Migration implementation, interfaces, TestBases and handlers | **Partially examined overall; core money-path targets examined.** Complete parent allocation, claim-vault allocation, surrender, recovery, pricing, policy and storage targets; complete bond, receipt, SY and RT business targets; parent/SY/RT packages; factories; selected facets and interfaces. Important locators include `M/UniswapV4DetfMigrationDFPkg.sol:127-389`, `M/sy/UniswapV4DetfMigrationSYDFPkg.sol:76-450`, `M/TestBase_UniswapV4DetfMigration.sol:84-180,207-397`, and `M/TestBase_UniswapV4DetfMigration_Adversarial.sol:20-62`. Native/source-unit ledgers and selected handler actions/assertions were read. | Some interface/event boilerplate, facet metadata wrappers, and full bodies of every legacy/source-unit handler and base were not read end to end. No claim of exhaustive line-by-line coverage of all 63 Solidity files. |
| 2. Hermetic migration specifications | **Partially examined.** Bodies of Core, OwnerFirstBond, Surface, RetainedAccounting, pricing/differential tests and selected Egress, GenesisCapital, DeploymentGas and invariant cases; remaining configuration/hostile/permit cases mapped by declarations and supplied coverage records. | Every assertion in every specification was not independently traced. No new tests or mutation testing. |
| 3. Legacy fork specifications | **Partially examined.** OriginalWallet, LegacySources, NFT3/late-failure lifecycle, claimed-SY preparation, reward accrual/donation, LP authority and invariant entrypoints were examined, with source-unit accounting models. | Not every category's complete fork fixture or external legacy source archive was read. Their supplied passing runs and indexed boundaries are distinguished from independent reauthentication. |
| 4. Native scripts and runbook | **Examined for operational entrypoints and lifecycle.** Complete `Phase_08_Stage_01_MigrationExecution.s.sol`; both CoreLocalQA lifecycle stages and its owner helper; complete DeploymentGasResumedQA; SnapshotLocalQA `run` and its imports; complete `D/foundry-runbook.md`. | Some SnapshotLocalQA infrastructure-construction helpers were not read end to end. No broadcast. R2 is in a retained script. |
| 5. Shared extension points and ordinary regressions | **Partially examined.** `C/bondNft/DETFFundedBondTarget.sol:41-245`, complete relevant metadata renderer, `B/UniswapV4DetfTarget.sol:175-284,715-851`, `B/UniswapV4DetfCommon.sol:465-589,735-797`, shared claim wiring, Weighted claim arithmetic `contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookClaimLib.sol:39-209`, and `contracts/utils/StandardExchangeFrozenQuoteLib.sol:28-56`. Ordinary isolation test and supplied regression summaries inspected. | No whole-repository audit; full ordinary test bodies, every shared staking/SY base method and all transitive AMM/math dependencies were not exhaustively reviewed. |
| 6. Completion evidence | **Partially examined.** Source/route/recovery indexes, quote/package/verification records, conformance task 8/11/13 records, post-removal report/raw summaries, November 16 diagnosis/raw full-hermetic summary, coordinator source comparison. | Not all historical receipts, archived worktrees, source manifests or artifact dependency closures were independently verified. No peer originals from this run were read. |

### Task-by-task disposition

Status vocabulary:

- **IT:** implementation/test present and inspected at the stated scope.
- **RV:** supplied runtime verified for the cited tested behavior; this is an existing run, not one executed by me.
- **I:** incomplete because of a current finding or explicitly missing obligation.
- **U:** unverified in this independent pass; not a failing test.
- **S:** superseded by the accepted scope/requirements correction.

`IT/RV` is not a declaration that all conceivable cases or every line in the target group were reviewed.

| Task | Disposition | Evidence and remaining issue |
| --- | --- | --- |
| 1. Source/custody/provenance | IT/RV for indexed routes; U for complete independent provenance reauthentication | Fixed sources and source units are implemented in `M/legacy/MigrationLegacyNftLib.sol:14-76` and `M/legacy/MigrationLegacyRecoveryLib.sol:25-161`. Fourteen source rows exist; current fork run has 183 passes. TokenStaking preparation and conditional custody are explicit. Operational eligibility remains separate. |
| 2. Manual Weighted pricing | IT/RV within declared supported models | Complete manual inputs; pure evaluation, canonical budget/output/split calls at `M/UniswapV4DetfMigrationWeightedPricingLib.sol:18-145`; real V3/disabled-buffer differential at `T/UniswapV4DetfMigrationSnapshot.t.sol:39-194`; manual mode/domain vectors at `T/MigrationWeightedPricing.t.sol:338-489`. Automatic capture and selected-live-composition prerequisites are S. |
| 3. Package/owner/bootstrap | **I**, with substantial IT/RV | Actual registry construction, owner salt, children and empty bootstrap exist. **R1** leaves admitted excess/refunded genesis donations outside usable reserve budgets. |
| 4. Separate configuration/execution | IT/RV | `M/UniswapV4DetfMigrationRepo.sol:18-58,76-100`; both allocation targets; `T/MigrationCore.t.sol:74-98`; `T/MigrationWeightedPricing.t.sol:192-254,493-537`. Current B configuration does not alter issuance A. |
| 5. Funded cliff/reward gates | IT/RV for economic behavior; **I** for presentation | `M/bondNft/UniswapV4DetfMigrationBondNFTVaultTarget.sol:22-117`; receipt/SY/RT gates and separate liabilities. **R3** affects the mandatory owner's ordinary bond metadata. |
| 6. Atomic surrender | IT/RV for supplied admitted-source cases | Original-wallet checks precede transfers; exact units/remaining credit; fixed NFT identities; rollback through child funding; `K/MigrationOriginalWallet.t.sol:62-176`, `K/MigrationLegacySources.t.sol:31-207`, `K/MigrationNftLifecycle.t.sol:65-190`. |
| 7. Startup gates/irreversible cut | IT/RV | `M/UniswapV4DetfMigrationAllocationTarget.sol:267-303`; real Remove semantics; constructor-only package initialization; `T/MigrationCore.t.sol:184-236`, `T/MigrationSurface.t.sol:67-115`, `T/MigrationWeightedPricing.t.sol:287-334`. No restoration route found in the examined composition. |
| 8. Bounded recovery/donation | IT/RV for selected typed stages | `M/UniswapV4DetfMigrationRecoveryTarget.sol:324-369,441-468`; real source deltas and fixed destinations; repeat reward-only cycles at `K/MigrationRecoveryDonation.t.sol:110-195`. Historical target-gas shapes supplied. |
| 9. Simple native scripts | **I** | Main typed wrapper is present and compilation is supplied. **R2** prevents the retained CoreLocalQA lifecycle from activating. Custom application/bundles/journals are S and are not requested as a remedy. |
| 10. Integration/adversarial/invariant/fork validation | IT/RV for broad supplied runs; **I** as complete correctness closure | Current full hermetic and post-removal forks are passing. Nonvacuous invariant witnesses exist. R1-R3 are uncovered continuations/presentation, and R2 demonstrates why script compilation is insufficient. |
| F1. Policy/source coverage | **I** for full closure | P/AC/E dispositions below; R1 affects funding completeness. No legacy category is rejected merely for lacking transfer ancestry. |
| F2. Production proxy/money paths | IT/RV for tested paths; **I** for full closure | Real proxy/child/surrender/recovery assertions and ordinary regressions supplied. R1 remains in an allowed capital path. |
| F3. Native execution | **I** | Retained scripts compile and contract suites pass; retained QA activation sequence is broken by R2. |
| F4. Completion/deployment limits | **I** as a completion claim | Report current gaps and preserve supplied passing evidence. No public deployment, funding, activation or allocation is authorized by this review. |

### MIG-P01-P15

| ID | Disposition | Trace |
| --- | --- | --- |
| MIG-P01 | IT/RV | Full-original component evaluation at `M/UniswapV4DetfMigrationWeightedPricingLib.sol:103-145`; loading at `M/UniswapV4DetfMigrationAllocationTarget.sol:59-101`; zero issuance on load at `T/MigrationCore.t.sol:74-89`. |
| MIG-P02 | IT/RV | Remaining-Q/C recurrence at `M/UniswapV4DetfMigrationWeightedHookTarget.sol:58-73,101-108`; kept A credit and explicit B replacement at `T/MigrationWeightedPricing.t.sol:211-234`. |
| MIG-P03 | IT/RV | `M/legacy/MigrationLegacyNftLib.sol:28-45,67-76`; actual partial position at `K/MigrationLegacySources.t.sol:31-52`. |
| MIG-P04 | IT/RV | `NftLib:45,51-62`; reward-only/burned/reserved/zero cases at `K/MigrationLegacySources.t.sol:149-207`. |
| MIG-P05 | IT/RV, reviewed-original identity assumption | Whole consumed record at `M/UniswapV4DetfMigrationWeightedHookTarget.sol:288-304`; cross-representation original indexes in both allocation targets; replay/descendant boundary at `K/MigrationOriginalWallet.t.sol:143-184`. |
| MIG-P06 | IT/RV | Wallet/custody then exact funded bond at `WeightedHookTarget:76-112,262-309`; NFT3 exception at `K/MigrationNftLifecycle.t.sol:65-190`. |
| MIG-P07 | IT/RV | Fresh `90 days` position at `M/bondNft/UniswapV4DetfMigrationBondNFTVaultTarget.sol:29-42`; separate creation times at `K/MigrationWeightedSy.t.sol:160-189`. No migration expiry state/selector found. |
| MIG-P08 | IT/RV economic gate; presentation I | Child `_claim` gate at `BondNFTVaultTarget:73-78`; deferred rewards at `M/claimToken/UniswapV4DetfMigrationStakedDETFTarget.sol:353-371,410-429`; **R3**. |
| MIG-P09 | IT/RV, reviewed-original identity assumption | Recipient allocation/issuance separation at `AllocationTarget:59-149`; duplicate-original indexes and immutable issuance; `T/MigrationCore.t.sol:74-98`. |
| MIG-P10 | IT/RV | No setter-triggered repricing; expected-book read; full record overwrite with separate issuance. `T/MigrationWeightedPricing.t.sol:211-254,493-537`. |
| MIG-P11 | IT/RV | All 16 administration selectors removed, paid owner prerequisite, common finalized state: `AllocationTarget:267-303`; `T/MigrationSurface.t.sol:67-115`. |
| MIG-P12 | IT/RV | Crane current-owner modifier, explicit package owner, setter after purchase: `AllocationTarget:37-55`; `M/UniswapV4DetfMigrationDFPkg.sol:275-294`; `T/MigrationWeightedPricing.t.sol:87-107,258-263`. |
| MIG-P13 | **I**, otherwise IT/RV | Funding/donation functions and no independent readiness flag exist. **R1** prevents completion of already booked surplus funding; native fund/bootstrap stages at `S/Phase_08_Stage_01_MigrationExecution.s.sol:32-53`. |
| MIG-P14 | IT/RV | Fixed typed stages, current owner, transaction atomicity and recovery-only accounting: `RecoveryTarget:324-369`; `K/MigrationRecoveryDonation.t.sol:110-195,220-248`. |
| MIG-P15 | IT/RV within supplied source domain | Same-wallet checks for every reviewed surrender body; source matrix has both generations/categories; actual ownership/control tests at `K/MigrationOriginalWallet.t.sol:62-140`; no transfer ancestry gate. |

### Feasibility gates E1-E5

| Gate | Disposition | Evidence/boundary |
| --- | --- | --- |
| E1 | IT/RV for fourteen indexed source rows; U for exhaustive independent reauthentication | Fixed adapters, source manifest/matrix, 183-case fork run. Earlier physical LP has a source-authority disposition; source disablement alone is not treated as permanent inability. |
| E2 | IT/RV | Stage 1 rejects, original wallet/configuration precedes custody, measured source-specific debit, replay protection and fresh funded bonds. `K/MigrationOriginalWallet.t.sol`, `K/MigrationWeightedSy.t.sol:70-240`, and source-unit invariant witnesses. |
| E3 | IT/RV supported-domain evidence | Pure manual evaluator; canonical Weighted budget/output and user split; real V3/disabled-buffer parity plus Raw/RawRate arithmetic vectors. No live-composition prerequisite restored. Raw/RawRate full observed-hook differential coverage was not independently established beyond the inspected vectors. |
| E4 | **I**, positive bootstrap IT/RV | Real empty-reserve funding works, without fictitious bonds, and self-leg supply is distinct. **R1** shows partial/excess funding can remain unusable after that successful transition. |
| E5 | IT/RV economic payout closure; metadata I | Bond/receipt/SY/RT gates, matured principal before activation, allocation-time role rights, transfer settlement, ordinary isolation/regressions. **R3** is a display mismatch, not a payout bypass. |

### All 53 MIG-AC dispositions

Runtime status in these rows refers to the supplied Migration suites and the current full hermetic run described above. A named test or body alone is IT; RV rests on the supplied run evidence. Where assertions were inspected selectively, the stated scope is preserved by the target-group table.

| ID | Disposition | Implementation/test trace and qualification |
| --- | --- | --- |
| MIG-AC01 | IT/RV, revised owner exception | `M/UniswapV4DetfMigrationExchangeFacet.sol:56-62`, `M/UniswapV4DetfMigrationBondFacet.sol:38-55`; `T/MigrationCore.t.sol:150-157`, `T/MigrationOwnerFirstBond.t.sol:143-156`. |
| MIG-AC02 | IT/RV | `WeightedHookTarget:79-89,151-160,265-277`; `RecoveryTarget:49-63,187-205,265-285,402-415`; `K/MigrationOriginalWallet.t.sol:62-140`. |
| MIG-AC03 | IT/RV | Parent exchange/bond guards, `M/sy/UniswapV4DetfMigrationSYTarget.sol:253-269`; owner-only exception does not open SY acquisitions (`T/MigrationOwnerFirstBond.t.sol:143-156`). |
| MIG-AC04 | IT/RV | Full overwrite at `AllocationTarget:59-101`; immutable issuance at 105-149; complete-record gas axes in `S/MigrationDeploymentGasResumedQA.s.sol:41-85`. |
| MIG-AC05 | IT/RV | Both administration modifiers; `T/MigrationWeightedPricing.t.sol:87-107`; current/pending/former owner purchase tests at `T/MigrationOwnerFirstBond.t.sol:107-139`. |
| MIG-AC06 | IT/RV | Locked measured transfers before `_fundBond`; `K/MigrationNftLifecycle.t.sol:160-190`; claimed-SY late funding rollback at `K/MigrationWeightedSy.t.sol:220-240`. |
| MIG-AC07 | IT/RV, revised | Original contribution stays fixed; `NftLib:28-45,67-76`; `K/MigrationLegacySources.t.sol:31-52,130-146`. |
| MIG-AC08 | IT/RV | NFT eligible units use principal less claimed principal, not gons/rewards; `NftLib:33-38`; `K/MigrationLegacySources.t.sol:75-111,149-175`. |
| MIG-AC09 | IT/RV with canonical-input assumption | Cross-source original collision checks in both allocation targets; irreversible NFT identity; separate recovery inventory. `K/MigrationOriginalWallet.t.sol:143-184`. Semantic alias detection remains input review. |
| MIG-AC10 | IT/RV | Recovery updates only recovery storage/deltas; `LegacyRecoveryLib:177-206,435-478`; `_protected` assertions in `K/MigrationRecoveryDonation.t.sol:110-195`. |
| MIG-AC11 | IT/RV | `NftLib:32-43`; receipt gons/internal-share equations in `LegacyRecoveryLib:68-160`; source matrix rows distinguish physical LP from NFT accounting shares. |
| MIG-AC12 | IT/RV | Distinct package/facets and ordinary isolation at `T/MigrationSurface.t.sol:23-42`; supplied ordinary-family regression results. |
| MIG-AC13 | IT/RV with reviewed-original assumption | Independent issuance has no surrender; held paths require custody. Allocation collision checks plus `T/MigrationCore.t.sol:74-98` and source fork tests. |
| MIG-AC14 | IT/RV economic behavior | Both paths call `Repo._fundBond:92-100` and `createMigrationPosition:29-42`; R3 concerns the separate ordinary owner bond's presentation. |
| MIG-AC15 | IT/RV, revised manual setter | Owner modifiers, proxy initialization, pricing authorization tests; recovery owner check at `RecoveryTarget:324-326`. No fee-recipient administration role. |
| MIG-AC16 | **I**, positive cases RV | Donation and self-leg bootstrap observed in `T/MigrationCore.t.sol:43-71` and GenesisCapital suite; **R1** prevents usable completion of leftover funding. |
| MIG-AC17 | IT/RV | Fixed DTF conversion/donation stages at `RecoveryTarget:324-369,441-468`; iterative reward donation at `K/MigrationRecoveryDonation.t.sol:110-195`; no ordinary bond call in recovery. |
| MIG-AC18 | IT/RV within indexed domain; provenance U in part | Fourteen rows in `D/source-route-matrix.md:11-24`; actual source-specific adapters and supplied fork suite. No category silently labeled absent. |
| MIG-AC19 | IT/RV | Cliff override `BondNFTVaultTarget:60-70`; `T/MigrationCore.t.sol:129-147`; deterministic exact boundaries in `T/invariant/MigrationNativeInvariant.t.sol:42-92`. |
| MIG-AC20 | IT/RV | Bond gate, deferred role/SY rights and postactivation release; `T/MigrationEgress.t.sol:119-145`; `T/MigrationRetainedAccounting.t.sol:61-85`. |
| MIG-AC21 | IT/RV, revised | Same manual book, two separate component calls and canonical fee/user split; `PricingLib:103-145`; `T/UniswapV4DetfMigrationSnapshot.t.sol:39-100`. |
| MIG-AC22 | IT/RV, revised | Stored credit is used at surrender, no evaluator call there; `T/MigrationWeightedPricing.t.sol:211-234`; live mutation independence at `T/UniswapV4DetfMigrationSnapshot.t.sol:61-68,144-194`. |
| MIG-AC23 | IT/RV with reviewed-original assumption | Canonical collision keys and source consumption, not re-quoting claimed/converted proceeds; `K/MigrationWeightedSy.t.sol:103-189`; `LegacyRecoveryLib` stage ledgers. |
| MIG-AC24 | IT/RV, revised | Manual set leaves A untouched; explicit B replacement preserves issuance A; all setter selectors removed. `T/MigrationWeightedPricing.t.sol:211-263,287-334,514-537`. |
| MIG-AC25 | IT/RV | Fresh funded child start per creation; `K/MigrationWeightedSy.t.sol:160-189`; `K/MigrationNftLifecycle.t.sol:98-129`. |
| MIG-AC26 | IT/RV | Actual owner-first prerequisite and all-or-nothing cut; `T/MigrationCore.t.sol:184-224`. Gas-exhausted cut rollback is a real proxy operation, not injected routing state. |
| MIG-AC27 | IT/RV for examined composition | Complete 16-selector removal; `T/MigrationSurface.t.sol:67-115`; package init/update guards at `M/UniswapV4DetfMigrationDFPkg.sol:265-304`. |
| MIG-AC28 | IT/RV | Activation selector removes itself; subsequent handler calls expect exact absent-selector errors (`M/invariant/MigrationNativeHandler.sol:182-189,336-371`). |
| MIG-AC29 | IT/RV | Retained surrender/recovery/query facets and post-cut actual operations; `K/MigrationOriginalWallet.t.sol:104-115`; `K/MigrationRecoveryDonation.t.sol:198-217`. R1 is specific to old genesis donation inventory. |
| MIG-AC30 | IT/RV route checks; U exhaustive cycle coverage | No migration re-close switch found. Inbound/surrender uses registry guards; selected legacy claims remain possible while reserve donation is disabled (`K/MigrationRecoveryDonation.t.sol:238-248`). A full disable/re-enable matrix for every exposed route was not independently established. |
| MIG-AC31 | **I**, revised native scope | Explicit native funding/bootstrap/configuration stages and receipt inspection instructions exist. **R1** affects funding completion and **R2** affects retained lifecycle execution. Custom crash recovery is S. |
| MIG-AC32 | IT/RV | `RecoveryTarget:324-328` enforces current owner; no destination parameter; ownership semantics use the same Crane repo. |
| MIG-AC33 | IT/RV measured shapes; U arbitrary shapes | Selected steps only in `RecoveryTarget:329-367`; task-11 gas table compares populations and bounded batches. No inventory-wide scan in the recovery entry. |
| MIG-AC34 | IT/RV | Operation-local claims, gon revaluation and inventory debits; `K/MigrationRecoveryAccrual.t.sol:19-63,108-184`; repeat retained-principal harvests in RecoveryDonation. |
| MIG-AC35 | IT/RV, revised | Configured original wallet plus actual control; `K/MigrationOriginalWallet.t.sol:62-115`; different holder cannot inherit credit. |
| MIG-AC36 | IT/RV, revised | Remaining fraction changes delivered credit without changing originals; `K/MigrationLegacySources.t.sol:31-52,130-146`; manual replacement tests preserve loaded credit. |
| MIG-AC37 | IT/RV | All configuration and pricing loaders removed; `AllocationTarget:267-303`; `T/MigrationSurface.t.sol:67-115`. No retained source-admission setter found. |
| MIG-AC38 | IT/RV | Complete overwrite and immutable issued facts: `T/MigrationCore.t.sol:74-98`; `T/MigrationWeightedPricing.t.sol:211-234`. Stage 1 surrender is unreachable. |
| MIG-AC39 | IT/RV, revised | Remaining-Q/C recurrence and source-specific units; `M/invariant/MigrationSourceUnitsLedger.sol:187-220`; `K/invariant/MigrationLegacyInvariant.t.sol:169` starts the exact 1001/3 real-proxy witness. |
| MIG-AC40 | IT/RV | No return/cancellation selector in examined facets; custody and child funding in one locked transaction; `K/MigrationNftLifecycle.t.sol:160-190`. |
| MIG-AC41 | IT/RV | Partial fungible recurrence versus whole NFT `consumed`; `K/MigrationWeightedSy.t.sol:160-189`; `K/MigrationOriginalWallet.t.sol:104-115`. Nonrepresentable receipt residue stays outstanding, not confiscated. |
| MIG-AC42 | IT/RV | No surrender beneficiary parameter; configured wallet/holder checks and `_fundBond(..., msg.sender/holder)`; approved-operator negatives at `K/MigrationOriginalWallet.t.sol:80-102`. |
| MIG-AC43 | IT/RV | Shared synchronized ERC721 transfer preserves stored position; `C/bondNft/DETFFundedBondTarget.sol:233-245`; every-position transfer/claim checks in native and source-unit invariants. |
| MIG-AC44 | IT/RV | No catch/skip in selected recovery loop; whole-batch witnesses in `K/invariant/MigrationSourceUnitsInvariant.t.sol:14-35`; earlier stages remain separate transactions. |
| MIG-AC45 | IT/RV | Fixed adapter targets/destination and separate inventory; `LegacyRecoveryLib:342-400`; donation failure retains prior conversion at `K/MigrationRecoveryDonation.t.sol:220-235`. |
| MIG-AC46 | IT/RV | Nonzero explicit owner, full args and owner-aware salt; `M/UniswapV4DetfMigrationDFPkg.sol:240-294,391-393`; `T/MigrationCore.t.sol:21-40`; capped two-owner deployment test. |
| MIG-AC47 | IT/RV | Current/pending/former checks and preserved completed-purchase fact; `T/MigrationOwnerFirstBond.t.sol:107-133`; pricing transfer test at `T/MigrationWeightedPricing.t.sol:87-107`. No acceptance-delay assumption. |
| MIG-AC48 | IT/RV examined surfaces | Reused ordinary targets with narrow overrides, registered packages, actual routing tests; `T/MigrationSurface.t.sol:23-108`. Full transitive dependency audit remains outside this pass. |
| MIG-AC49 | IT/RV, revised | NFT configuration quotes without issuance; `M/UniswapV4DetfMigrationClaimVaultAllocationTarget.sol:27-76`; `NftLib:48-76`; exact live fraction fork case. |
| MIG-AC50 | IT/RV | Collection plus ID economic key, wallet binding and consumed state; `NftLib:20-24`; `K/MigrationLegacySources.t.sol:114-127`; `K/MigrationOriginalWallet.t.sol:62-115`. |
| MIG-AC51 | IT/RV with reviewed-original assumption | Each independent original quoted separately before sum; `AllocationTarget:77-97`; cross-path collision checks and recipient issuance history. No inferred eligibility from wallet turnover. |
| MIG-AC52 | IT/RV contract semantics; withdrawn app behavior S | A/B stale-load, retained-A, same-recipient B/A, mixed-book handler activation and actual removed selectors. `T/MigrationWeightedPricing.t.sol:192-254,493-537`; `M/invariant/MigrationNativeHandler.sol:70-155,348-371`. Native receipt inspection replaces custom resume machinery. |
| MIG-AC53 | IT/RV economic gate | Child `_claim`, receipt reward release, SY claim/RT mint/redemption gates and accounting-phase admission; `M/claimToken/UniswapV4DetfMigrationStakedDETFTarget.sol:143-181,236-292,410-429`; `M/sy/UniswapV4DetfMigrationSYTarget.sol:195-224`. R3 does not imply bypass. |

### Source-category accounting

All categories are retained in the implementation/evidence map. Their meanings are not interchangeable:

| Category | Reviewed implementation route and evidence disposition |
| --- | --- |
| Weighted NFT | `NftLib.position` uses original principal less actual claimed principal; whole source custody; separate NFT3 contributions are atomically funded. IT/RV. |
| Earlier NFT | `NftLib.position` uses original accounting shares, excluding reward weight and physical LP. IT/RV; reserved IDs independently identified in source evidence. |
| Weighted and earlier liquid DETF | Separate fixed sources/native units and stored Q/C; measured transfer before credit. IT/RV supplied source tests. |
| Weighted sDETF | Exact ownership gons after source synchronization, not displayed native balance alone (`LegacyRecoveryLib:137-160`). IT/RV. |
| Earlier receipt | Public endpoint-floor/rate constraints establish internal-share movement; separate NFT-sale and standalone inventory (`LegacyRecoveryLib:68-133,383-431`). IT/RV. |
| Weighted SY | Static shares, measured custody, real wrapper redemption into receipt gons. IT/RV. |
| TokenStaking migrated rights | Prepare eligible source weight into measured SY; keep original denominator, eligible numerator and SY amount distinct; configure one original, then surrender SY. `K/MigrationWeightedSy.t.sol:70-240` supplies direct-caller positive/rollback coverage. IT/RV for that demonstrated domain; no raw-weight approved-pull claim. |
| Direct claim-vault rights | Native19 direct shares, measured native9 SY output; distinct from TokenStaking infrastructure backing. IT/RV supplied route tests; full acquisition provenance not independently reauthenticated. |
| DTF custody SE | Native28 shares and measured native18 DTF output (`LegacyRecoveryLib:243-258`). IT/RV. |
| Weighted WETH SE and earlier SE | Fixed native share custody; source-specific conversion, subject to actual external enablement. IT/RV conditional. |
| Weighted physical LP | Actual fee-recipient authorization can permit exit; fee-minted LP remains unbooked (`LegacyRecoveryLib:361-380`). IT/RV conditional. |
| Earlier physical LP | Surrender/credit remains supported; permanent custody is the supplied authenticated authority disposition, tested against role/time/parent-intake alternatives. No generic LP exit invented. |

### Tests' ability to detect regressions

The inspected suites contain substantive checks: exact wallet/custody deltas, supply/backing/gon reconciliation, exact revert selectors, real second-contribution receiver rejection, source-unit separation, actual proxy loupe removal and independent integer ledgers. `M/TestBase_UniswapV4DetfMigration_Adversarial.sol:34-61` observes balances, allowances, pricing, credit, issuance, backing, the next NFT owner and routing in one rollback fingerprint. `M/invariant/MigrationNativeLedger.sol:97-175,179-212` calculates expected staking/reward/claim state rather than merely asking the SUT for its answer.

Successful-action requirements prevent the inspected invariant targets from passing solely through reverts: `T/invariant/MigrationNativeInvariant.t.sol:14-39` and `K/invariant/MigrationSourceUnitsInvariant.t.sol:14-35`. Real source diagnostic `vm.load` reads in the earlier-receipt ghost model are not production getters or source state injection.

The specific weaknesses exposed here are narrower:

- The partial-funding test checks authorization, initial supply and reserve creation, but not later use of the admitted remainder.
- Script compilation and operation-gas helper coverage do not establish the retained CoreLocalQA lifecycle.
- Metadata coverage checks cliff positions, not the Stage 1 ordinary owner's reward availability.

## Conclusions

The execution record should retain the real successes: manual Weighted pricing and keep-until-reloaded semantics, separate configuration/issuance, proportional original credit, original-wallet custody, funded fresh cliffs, paid owner-first activation, irreversible selector removal, source-specific recovery, iterative reward harvesting, and broad passing native/fork/ordinary regression runs.

It should not say the corrected plan is fully executed while R1 and R2 remain. R1 is an accepted capital path with no usable continuation; R2 is a retained native script with an unreachable required transition. R3 is a smaller observable product mismatch.

No high- or critical-severity issue was established in the examined money paths. This is not a guarantee of absence. The source findings and suggested directions are advisory only; this response does not replace the plan or authorize implementation, deployment, funding, activation, legacy-governance actions or compensation allocations.

## Limits

This was one independent static review with selective existing-log verification. I did not read this run's peer originals, delegate work, run project tests/builds, use shell/Git/RPC tools, submit transactions, or edit implementation/configuration. No new failing test output is claimed. Some target-group contents and transitive dependencies remain only partially examined as recorded above.

Only this assigned `members/astra/response.md` was authored. The independent response ends here.
