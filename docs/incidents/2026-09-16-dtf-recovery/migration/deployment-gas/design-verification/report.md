# Independent Migration deployment construction verification

Date: 2026-11-11.

**Disposition: admitted.** Admit the diagnosis's two-SY preparation and
atomic parent construction for bounded implementation, subject to the
construction constraints and executable acceptance gates below. No new
product-policy decision is needed for this construction.

This is **design admission, not confirmation that the gas correction works**.
The available successful parent receipts still exceed the target. The proposed
replacement has not been implemented or executed by this verifier. A corrected
first instance and a second distinct instance must each succeed with every
required transaction constrained to at most **32,000,000 gas**. Failure of that
gate means the implementation is not an accepted deployment correction.

The mechanism moves only the two fully initialized, zero-supply SY proxies
into a preceding registered deployment transaction. It does not defer parent
initialization, reserve funding, custody, bond funding or activation checks.
The final transaction must still complete all five children, remove the
temporary hook and publish the parent atomically. The conditions below are
requirements of this admission, not optional hardening.

## 1. Scope and evidence identity

Worktree:
`/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-09-deployment-gas`.

Supplied base: `421072a7630a0d3d47a6f36e1062d9eae98c93e2`, branch
`work/dtf-migration-phase-09-deployment-gas`. Root's warm-seed exit 0 and
`DEPLOYMENT_GAS_WORKTREE_VERIFIED` are supplied prerequisite evidence, not
commands rerun here. No Git operation or compile was necessary for this
independent design review.

Read the complete phase09 brief, complete original main-checkout plan,
repository router and assistant rules, applicable canonical Crane deployment
and architecture guidance, and relevant product law. The Migration plan's
explicit owner and lifecycle exceptions govern over ordinary unowned-DETF
defaults.

Reviewed proposal: `../diagnosis/report.md`, SHA-256 independently computed
from the raw file:
`1f685c1b0f74ac5c300c42df1963afb45bfe33544967765153bd37a29ed2a6dd`.

Original main-checkout plan:
`docs/incidents/2026-09-16-dtf-recovery/MIGRATION_DETF_IMPLEMENTATION_AND_TEST_PLAN.md`,
SHA-256 independently computed:
`56106853d29ddff963ff2b8a872bdfa1840ed95ed29806bdc10d728220b60be7`.

Evidence prefixes used below:

| Prefix | Exact location |
| --- | --- |
| `M/` | This worktree's `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/` |
| `U/` | This worktree's `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/` |
| `S/` | This worktree's `contracts/vaults/detf/common/sy/` |
| `C/` | This worktree's `lib/crane/contracts/` |
| `D/` | This worktree's `docs/incidents/2026-09-16-dtf-recovery/migration/deployment-gas/diagnosis/` |
| `O/` | `/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-08-operator/` |
| `R/` | `/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-07-recovery/` |
| `I/` | `docs/incidents/2026-09-16-dtf-recovery/migration/`, relative to the indicated worktree |

Historical evidence read includes:

- Complete `O/I/operator/rehearsal/report.md` and
  `O/I/operator/execution/report.md`, actual Stage 00 and Stage 01 Solidity
  sources, rehearsal gas/transaction records and source-evidence bindings.
  The final rehearsal is `rehearsal-1794376137494`; earlier runs are not
  silently substituted for it.
- Complete `R/I/nft-recovery/verification/report.md`,
  `correction-verification/report.md` and `commit/verification.md`, and
  `implementation/chain-gas-limits.log`. The original R1 needs-fix finding
  and its later confirmed correction remain distinct historical results.
- Actual parsed `D/accepted-parent-failure.json`,
  `accepted-parent-success.json`, `second-instance.json`,
  `limits-and-transactions.json`, `infrastructure-replay.json`,
  `call-contributors.json`, `source-bindings.json`,
  `commands-and-cleanup.json` and `witness-execution.json`.
  Receipt envelopes and call trees, not only prose totals, informed this
  assessment.

Independently recomputed SHA-256 for all **18** source/test paths in
`R/I/nft-recovery/commit/source-manifest.json` against this worktree:
**18/18 match the accepted hashes**. This includes the parent package,
Migration TestBase and recovery wiring. The diagnosis records 226 source
comparisons and 20 runtime comparisons; those are retained producer
observations, not 226 new independent comparisons or new live RPC reads here.

## 2. Gas mechanism established by the evidence

The evidenced target is historical chain **4663**, RPC/L2 block
**108944663**, hash
`0xc497433dd691a40cb85959cfeba2e3fff85a975ae060612d984998e1d5765733`.
The saved explicit `getMaxTxGasLimit()` result is **32,000,000**, with exit 0.
The accounting tuple is `7,000,000 / 32,000,000 / 32,000,000`; ArbOS is 116.
Neither the historical header's oversized block-gas field nor Anvil's
100,000,000 block limit is substituted for the transaction getter.
This is not a claim about today's live-network limit or complete ArbOS fee
accounting.

Independent decoding of `D/limits-and-transactions.json.acceptedTransactions`
and the corresponding receipts gives:

| Instance / execution | Envelope gas | Status | Gas used |
| --- | ---: | ---: | ---: |
| First, target constrained | 32,000,000 | 0 | 29,079,047 |
| First, permissive diagnosis | 100,000,000 | 1 | 42,985,843 |
| Second, target constrained | 32,000,000 | 0 | 29,073,562 |
| Second, permissive diagnosis | 100,000,000 | 1 | 42,267,991 |

The first failed hash is
`0x38fa30f5d5e746a7e19a780e35862cc0767835d2db0b89b11882e179c6200451`;
the first successful diagnostic hash is
`0x1766cd703d2b21c6e3534769bc513989f7d24cc29cac2a18c930a1b8eba77805`.
The second failed and diagnostic successful hashes are respectively
`0xc848c78b8533251ea2e93a298e9c90b54a7ddc81d5d230d0229afddcedb1ca7a`
and `0xca5b8b11a135b403dd57c275a67274e385cceab5c52691d5972eb0fb9fdfccdc`.

The actual first failure trace ends in `out of gas` at
`0.0.0.0.4.0.0.0.7.0.0`, the registry deployment delegatecall inside raw-SY
deployment. Ancestors revert and its receipt has no surviving logs.
Gas retained by outer frames explains why charged gas below 32 million is
not proof that a successful transaction fits that limit.

The successful first trace independently confirms these inclusive costs:

| Subtree | Trace path | Gas |
| --- | --- | ---: |
| Parent CREATE2 and initialization | `0.0.0.0.3` | 10,370,402 |
| Parent post-deploy | `0.0.0.0.4` | 25,169,464 |
| Raw SY and its registration | `0.0.0.0.4.0.0.0.7` | 6,632,351 |
| Staking SY and its registration | `0.0.0.0.4.0.0.0.8` | 6,216,979 |

The SY subtrees total **12,849,330**. Subtracting them from the first receipt
gives **30,136,513**, only an engineering estimate. Repeated registry calls,
cold accesses, added authorization and reciprocal checks, refund changes,
and nested forwarding still cost gas. In particular, reusing a deployed SY
does not make its registry traversal free.

The actual source accounts for this call tree:

- `M/UniswapV4DetfMigrationDFPkg.sol:252-277` unconditionally completes bond
  and receipt, deploys RT, and invokes both SY deployments.
- `S/DETFSYDeploymentLib.sol:15-30` constructs raw and staking arguments
  serially and stores their returned identities in the parent.
- `C/factories/diamondPkg/DiamondPackageCallBackFactory.sol:201-233,377-395`
  performs per-proxy creation, facet/interface installation and initialization.
- `contracts/registries/vault/VaultRegistryDeploymentTarget.sol:63-77`
  registers the parent only after factory completion.
  `VaultRegistryVaultRepo.sol:91-151` writes discovery indexes and emits
  discovery events for each registered vault.

All 225 parsed prerequisite replay receipts succeeded; the diagnosis separates
five holder/funding transactions from 220 infrastructure transactions.
The second parent has a different owner and five distinct children. Its
42,267,991-gas success demonstrates that reusing global factories does not
remove the per-instance excess.

## 3. Admitted construction and binding constraints

### C1. Keep the existing address domain and complete canonical arguments

The public package `prepareSyChildren(PkgArgs)` entry accepts only the existing
complete `IUniswapV4DetfMigrationDFPkg.PkgArgs`. It must run on package SELF, not
through arbitrary delegatecall. Nonzero owner, distinct nonzero WETH/original
DTF, canonical encoding, hook shape, liquidity policy, predicted self-leg and
hook ownership remain validated. Do not replace these with caller-provided
child addresses or a hash that is never tied to actual arguments.

Preserve `M/UniswapV4DetfMigrationDFPkg.sol:205-215`: parent salt includes
every accepted field and clears **only** `baseArgs.hook`. This supports
parent-first prediction and subsequent owner-bound hook construction.
Do not add a new salt, deployment operator or owner-signature requirement.
The existing `deployVault` helper at line 118 permits callers to construct
for the explicit initial owner; preparation must preserve that distinction.

The preparation identity is:

```text
keccak256(abi.encode(chainId, parentPackage, completeCanonicalParentArgs))
```

The per-instance transaction sequence is
`parentPackage.prepareSyChildren(args)` followed by
`parentPackage.deployVault(args)`, with identical complete canonical arguments
and actual hook. The first call internally performs both real
`registry.deployVault(migrationSyPackage, encodedChildArgs)` constructions.
The second internally uses the existing
`registry.deployVault(parentPackage, abi.encode(args))` path. Each outer
transaction is independently constrained to the target; neither a combined
script total nor a successful internal call is the acceptance receipt.

It includes the **actual hook**, unlike the prediction salt. A record keyed
only by predicted parent is not admitted. Different full payloads must not
overwrite or block each other's preparation merely because they predict
the same parent. An identical completed preparation is idempotent while
the parent remains absent.

Preparation is not an exclusive reservation of that address. The unchanged
permissionless deployment and hook-clearing salt already allow different
valid hook payloads to compete for the same predicted parent. This correction
must neither claim to eliminate that existing first-construction behavior
nor grant the preparer a new veto or right to replace a constructed parent.
An unused alternative preparation has no supply or booked claim.

### C2. Derive all five identities from actual immutable dependencies

Use the existing shared callback factory, actual parent/SY/bond/receipt/RT
packages and fee oracle. Do not deploy another callback factory or use an
off-chain address assertion as authorization.

- Parent prediction follows the existing package salt and factory package
  domain.
- Bond prediction uses the predicted parent, **actual hook** as LP token,
  and the exact resolved bond metadata.
- Receipt prediction uses that bond, predicted parent, actual fee oracle,
  resolved claim metadata and `optionalSalt=keccak256(abi.encode(parent))`.
- Derive raw and staking SY canonical arguments, including their differing
  mode, names/symbols and exact directional route arrays.
- RT remains created during finalization from the live parent and receipt;
  preserve its existing 27 decimals and gon quantum.

Sources: `U/UniswapV4DetfTarget.sol:812-850`,
`contracts/vaults/detf/common/DETFChildTokenMetadata.sol:7-41`,
`common/claimToken/RebasingClaimTokenDFPkg.sol:48-62`,
`S/DETFSYDeploymentLib.sol:15-30`, and
`M/sy/rewards/UniswapV4DetfMigrationRewardTokenDFPkg.sol:96-140`.
The bond, receipt and SY packages hash ABI-encoded argument bytes; do not
silently replace that encoding with a different tuple hash.

Preparation's memory route construction must match
`U/UniswapV4DetfInitializationLib.sol:87-109` and
`U/UniswapV4DetfProcessArgsLib.sol:138-218`.
Defaults follow hook token order, omit the self leg and retain first-insertion
set order for pair/SE tokens. Custom tables preserve validated row order,
membership, closed-form route checks and duplicate rejection. Do not sort
the arrays, accept unvalidated caller route arrays, or alter common code.
Final validation compares them with the parent's actually initialized tables.
Metadata defaults and explicit overrides must both work.

### C3. Preparation authorization is immutable construction evidence

The new Migration SY package must itself be deployed through CREATE3 and
the manager's registered-package path. Its interface owns its initialization
and preparation schemas. It receives the actual callback factory and the
same selected Migration SY, domain and permit facets and fee oracle.

Its typed preparation method authenticates the calling registered parent
package and independently derives the future parent from the supplied full
arguments in that caller's package domain. It must bind the parent package's
actual selected SY dependency to this SY package. Registration alone must
not let a different caller submit a victim parent, factory or child address.
There is no owner-editable approval list or arbitrary package executor.

Store the write-once record on the **SY package SELF**, containing parent
package, construction ID, predicted parent/bond/receipt, both SY addresses
and canonical SY argument hashes. Child authorization can be made available
before their construction, but the record cannot be usable as **completed**
parent preparation until both real registry deployments, initialization
and temporary-hook removals succeed. An exception or second-child failure
must roll back the entire preparation. Reentrant preparation or finalization
cannot observe or accept a partially completed record.

The factory's processing and initialization adaptor uses delegatecall:
`C/factories/diamondPkg/utils/DiamondFactoryPackageAdaptor.sol:10-29`.
Therefore reading a Solidity mapping locally from those methods would read
factory/proxy storage, not the package's authorization record. Queries must
explicitly address immutable SELF.

For a new SY:

- `processArgs` validates the exact authorized canonical child arguments and
  registry-mediated callback context.
- `updatePkg` accepts only the actual callback factory, the exact predicted
  account, matching arguments and an account without code.
- `initAccount` accepts only the expected child context and factory, checks
  its actual factory package/argument binding, rejects package SELF and
  already initialized storage, and initializes once.

No authorization endpoint is installed on a parent or SY proxy. No endpoint
accepts arbitrary selectors, calldata, destinations, storage writes or
replacement bindings.

### C4. The pre-parent exception changes validation timing, not SY behavior

The ordinary package cannot simply be reordered:
`S/DETFSYDFPkg.sol:114-121` reads live parent/receipt decimals and reciprocal
binding; `S/DETFSYRepo.sol:39-58` reads the staking receipt's parent.
Likewise `common/claimToken/DETFFundedStakingRepo.sol:52-63` requires the
parent's live decimals. Do not relax these common initializers.

A Migration-local composition may replace only the unavailable pre-parent
identity reads with the authorized deterministic construction proof.
Reuse metadata, EIP-712, StandardVault and canonical SY storage initialization.
For staking mode, the proposed raw-mode initializer with receipt prepended
to both route arrays, followed by setting `isStaking=true`, is admissible
only if it produces the exact canonical ordered sets
`[detf, receipt, additional routes]` with normal set deduplication and
invalid-route rejection. It must not omit a field, initialize a second
ledger, or install a later binding setter.

Both children finish their preparation transaction fully initialized with
zero supply, zero raw backing, zero attributed/conversion-dust gons, zero
Migration reward cursors and Idle phase. The temporary factory hook is
absent. Preserve every selected SY selector, including Migration remainder,
attribution and accounting-phase selectors:
`M/sy/UniswapV4DetfMigrationSYFacet.sol:15-65`.

Source reasoning supports pre-parent economic inertness:
`M/sy/UniswapV4DetfMigrationSYTarget.sol:34-44` synchronizes with the fixed
parent before transfers, deposits, redemptions and reward operations.
The absent parent/receipt cannot satisfy those dependencies. This must be
executed as a regression, not taken as a successful runtime observation in
this review. Failed attempts must leave custody, supply and phase unchanged.
Ordinary approvals/permits and read-only metadata are not issuance authority.

Unsolicited external token transfers do not create booked backing or shares.
Do not reject finalization merely because an unrelated token was donated
to a deterministic child address; that would introduce a cheap deployment
denial and a new donation policy.

### C5. Complete and publish the parent in one final transaction

The existing registered parent `deployVault` path remains the final call.
For fresh construction, parent `processArgs` must require the exact completed
full-argument preparation even if called through the registry rather than
the package helper. Parent initialization retains all existing fields,
ownership, thresholds, routes, fee/creator identities, empty snapshot and
Stage 1 state.

Keep bond completion/reserved IDs, receipt deployment and RT deployment
inside finalization with their existing live checks. Resolve the two already
prepared SYs through the registered SY package. Do not replace their registry
deployment with a bare factory bypass.

Before returning from parent post-deploy, independently verify:

- Actual factory package and full processed arguments for both SY addresses,
  not only a package-written record.
- Exact parent, receipt, mode, metadata, decimals, ordered input/output sets,
  canonical argument hashes and required interface/facet composition.
- Zero initial supply, booked backing and conversion dust, Idle accounting,
  and all existing RT/receipt/bond reciprocal conditions.
- All five actual children are distinct where required and are the same
  identities recorded on the parent; reserved bond IDs 0, 1 and 2 retain
  their existing protocol/fee/creator ownership.

The common factory removes the temporary parent hook before returning;
the manager then publishes the completed parent. Failure restores the entire
final transaction, including new children and parent registration. Previously
committed SYs remain fixed, inert and retryable for the same construction.
No stage leaves an initialized-but-mutable parent between transactions.

### C6. Account explicitly for factory reuse and callback windows

The callback factory returns an existing address at
`C/factories/diamondPkg/DiamondPackageCallBackFactory.sol:215-217`
**before** `processArgs`, `updatePkg`, `initAccount` and `postDeploy`.
Therefore:

1. Prepared-child reuse requires explicit final validation; it cannot rely
   on any of those callbacks running again.
2. The package-level final-call helper must reconcile an existing parent
   against the actual factory arguments before claiming success for the
   requested full construction. In particular, a different hook must not
   be reported as the requested deployed hook.
3. An existing-parent return through the unchanged direct registry/factory
   path is not fresh construction or fresh validation. Verify its actual
   immutable state and preserved factory arguments; do not count it as the
   second-instance gas witness. It must not overwrite construction arguments,
   reinitialize the proxy or restore selectors.

Preparation rejects an already deployed parent, before and after activation.
Keep absent-account and one-time initialization guards on every new mutable
package path.

`C/factories/diamondPkg/PostDeployAccountHookFacet.sol:19-22` delegates to its
caller while temporarily installed. No preparation boundary may retain that
selector. Test callbacks during construction as well as between transactions;
atomic rollback alone is not evidence that a reentrant call could not observe
or exploit a temporarily incomplete parent. The admitted design exposes no
new arbitrary callback/initializer and retains hook removal inside each
factory transaction.

## 4. Lifecycle preservation obligations

These are preservation checks, not additions to product policy:

| Obligation | Current source and required result after the packaging change |
| --- | --- |
| Complete composition | `M/UniswapV4DetfMigrationDFPkg.sol:148-201` supplies 14 package facet addresses and 17 declared interfaces, plus factory base surfaces. Preserve the full selected cuts and five children, not merely successful ERC20 reads. Compare actual loupe/selector owners and interfaces. |
| Owner isolation | `M/UniswapV4DetfMigrationDFPkg.sol:235-249` initializes explicit proxy-local Crane ownership. Caller, creator, fee recipient and manager remain distinct. Two different owners must get isolated parents/children. Preserve actual pending/current-owner semantics; do not repair Crane's acceptance buffer in this task. |
| No issuance during construction | Parent and fungible children start at zero supply and have no funded positions or migration credits. Reserved role NFTs are the existing exception, not compensation bonds. Preparation cannot fund a reserve, capture a snapshot or manufacture participation. |
| Exact funding and fresh bonds | `M/UniswapV4DetfMigrationRepo.sol:62-72` mints exactly delivered credit, grants a temporary exact allowance and calls the fixed bond. `common/bondNft/DETFFundedBondTarget.sol:100-137` measures actual pull and staking-gon deltas. `M/bondNft/UniswapV4DetfMigrationBondNFTVaultTarget.sol:29-42` creates a fresh 90-day bond at actual creation and protects receiver callbacks. No premint, surrogate bond, reused clock or escrow-surplus substitution. |
| Custody atomicity | `M/UniswapV4DetfMigrationTarget.sol:65-106` verifies current holder, whole NFT receipt and unchanged position, records consumption/custody and funds the fresh bond in one operation. Packaging cannot alter source eligibility, protected backing, harvest destinations or the separate recovery ledger. |
| Funding before frozen pricing | `M/UniswapV4DetfMigrationTarget.sol:125-159` books actual donations; allocation target lines 180-245 separately bootstraps self-leg/reserve liquidity. Its lines 43-51 capture once. Preparation is not a funding-complete or snapshot-finalization gate and never supplies prices. |
| Stage 1 payout closure | Preserve Migration bond, receipt, SY and RT implementations, including receipt principal/reward separation and all five accounting-phase checks. `M/UniswapV4DetfMigrationPolicy.sol:64-104` binds admission to actual fixed children. A raw/staking SY prepared early must not become an ungated ordinary wrapper after wiring. |
| Long Stage 1 | Preserve mature principal rights, deferred rewards and empty-participation baseline. `M/UniswapV4DetfMigrationPolicy.sol:107-128` prevents empty-weight expansion from becoming a fictitious first participant's reward. No preparation timestamp becomes a bond, reward or activation clock. |
| Irreversible activation | Allocation target lines 153-178 remove all six administration selectors with their actual owning facets, clear allocation interface support and set activation atomically. Added package APIs must not restore any selector, replay initialization or emulate configuration/independent issuance. |
| Registry semantics | Prepared SYs are registered complete SYs; parent discovery remains absent until completed construction. Package disable checks remain real. Parent/child reuse may emit discovery events but cannot create duplicate set entries or change immutable bindings. |

## 5. Exact implementation boundary

Only the following construction paths from diagnosis section 5.4 are admitted
by this design review:

| Path | Bounded work |
| --- | --- |
| `M/interfaces/IUniswapV4DetfMigrationDFPkg.sol` | Typed package-only preparation/binding queries and documentation; retain canonical parent `PkgArgs` and runtime proxy surface |
| `M/UniswapV4DetfMigrationDFPkg.sol` | Deterministic preparation derivation, full-commitment admission, reuse reconciliation and final reciprocal validation |
| `M/sy/IUniswapV4DetfMigrationSYDFPkg.sol` (new) | Interface-owned package initialization, immutable preparation record and typed queries |
| `M/sy/UniswapV4DetfMigrationSYDFPkg.sol` (new) | Registered Migration-only composition and authorized pre-parent initialization with existing facets/repos |
| `M/UniswapV4DetfMigration_Pkg_FactoryService.sol` | Real CREATE3/manager registration for the new package |
| `M/TestBase_UniswapV4DetfMigration.sol` | Select the new package and execute preparation before genuine parent construction |
| `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationDeploymentGas.t.sol` (new) | Real construction, binding, intermediate-state and lifecycle regression coverage |
| `test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationDeploymentGas.t.sol` (new) | Pinned target construction and initial-state proof |
| `scripts/foundry/recovery/dtf-migration/MigrationDeploymentGasLocalQA.s.sol` (new) | Dedicated local transaction witness, individually bounded preparation/final receipts |

The surrounding brief permits necessary neighboring Migration spec/fork
fixture updates, but not weakening assertions to accommodate missing
preparation or lost behavior. Shared `DETFSYDFPkg` methods are not virtual;
do not change ordinary/common/Crane code to subclass them. Compose the small
Migration-specific package using the existing selected facets/repos.

No existing operator TypeScript, configuration, dependency, ordinary/common
production, Crane source or historical report is an edit target. If a
construction cannot be implemented inside these boundaries, report the exact
necessary contract change before editing outside them. This report itself
changes only design-verification evidence.

The existing operator Stage 00 simulates `migrationPkg.deployVault(args_)`
after preparing the hook; Stage 01 calls that same helper. Neither source
currently performs the new SY preparation. They are baseline evidence, not
proof that an unchanged operator flow will work with the new package.
Use the dedicated admitted gas witness here and leave operator integration
as its separately scoped task; do not silently patch operator TypeScript.

## 6. Required implementation and independent runtime acceptance

Retain the immutable fail-before receipts. After production changes, build
actual artifacts with Solar before running relevant Migration specs/forks
or scripts. Do not use viaIR, change profile paths, delete caches, disable
code-size enforcement, suppress simulation, fake the SUT or modify legacy
deployed code.

| Gate | Required observable evidence |
| --- | --- |
| G1: first construction | Fresh owned local historical fork, real CREATE3/FactoryServices and manager registry. All infrastructure newly required by the correction, the two-SY preparation and final parent transaction each have an explicit gas envelope at or below 32,000,000 and status 1 receipts. Record actual gas used, complete calldata and transaction hash. |
| G2: second construction | Same global factories/packages, different explicit owner, freshly predicted parent/hook and five distinct children. Repeat every per-instance preparation/final transaction with the same bound. Do not reuse the first parent's already-deployed factory fast path. |
| G3: binding negatives | Changed owner, package, chain-domain commitment, hook, parent, receipt, metadata, mode, route ordering or arguments cannot substitute prepared children. Test noncanonical bytes, direct factory/package initialization and direct-registry fresh-parent bypass. Test alternate hook preparations sharing a predicted parent without parent-key poisoning. |
| G4: intermediate safety | Between preparation and finalization, parent code/parent registry discovery are absent; both SYs have complete immutable configuration, no temporary post-deploy hook and zero supply/booked backing. Transfers, deposits, redemptions and reward actions cannot issue or take custody. Approvals and unsolicited donations must not enable takeover or veto legitimate finalization. |
| G5: transaction rollback/retry | Failure while preparing the second SY rolls back the first and the record. Failure in final child validation/publication leaves no parent or partial parent registration, preserves the prior completed preparation, and permits exact retry. Include reentrant preparation/construction and package disable behavior. |
| G6: complete final state | Actual parent/SY factory argument records, registry indexes, facet routing, interfaces, metadata, decimals, owner, hook, all five child links, reserved IDs, zero supply/backing and Idle phases match the canonical construction. Existing-parent reuse cannot report caller-supplied mismatching hook arguments as actual state. |
| G7: lifecycle | Using the corrected construction, execute funding/genesis, frozen capture, configuration without issuance, fresh exact-funded independent/NFT bonds, Stage 1 reward/ordinary acquisition negatives, mature principal, owner transfer, activation and attempts through package/factory/initializer/callback routes to restore removed selectors. Check late surrender's fresh clock and existing custody/recovery protection. |
| G8: source and cleanup | Bind receipts to current source, Solar artifacts and immutable-populated runtime/facets. Retain corrected first/second envelopes and traces. Stop owned nodes, holder impersonations and subscriptions; preserve operator port 18560, other worktrees, warm caches and historical evidence. |

If the final transaction fails at 32 million despite a lower `gasUsed` in a
permissive run, G1/G2 fail. Do not omit reciprocal checks or registry indexes
to manufacture a pass. A materially different split requires design
assessment of that split; it is not implicitly admitted by this report.
The new packages must also fit actual code-size limits.

The targeted Migration suites cover the changed fixture/package flow.
Ordinary/common tests broaden only if an actual dependency impact is found;
there is no shared-production edit admitted here. Later full-plan and release
test obligations remain separate and intact.

## 7. Decision, rejected alternatives and limits

**Decision:** the SY split is an ordinary packaging correction. The fixed
deterministic future identities can replace the unavailable live reads during
preparation, and complete live reciprocal validation can remain at the atomic
parent publication boundary. The current economic facets, initialization
layout and lifecycle do not need to change. Admission depends on C1-C6 and
G1-G8, not on trusting a preparer or on the subtraction estimate.

Rejected alternatives:

- Global factory warming alone: the second distinct instance still exceeds
  the target by more than 10 million gas.
- Script-only early bond/receipt preparation: the diagnosis's bond-only final
  still uses 37,599,068 gas, and the current receipt initializer requires live
  parent decimals. Do not relax that shared check.
- Partially initialized parent or later arbitrary initializer: unnecessary
  and incompatible with atomic complete publication and irreversible
  activation.
- Omitting SY, RT, bond, receipt, facets or registry indexes; raising the
  transaction limit; disabling code-size/simulation checks: outside the
  accepted behavior and not deployment corrections.
- First-writer reservation keyed only by parent, or requiring the initial
  owner to sign preparation: respectively enables hook-payload poisoning
  or introduces a new authority restriction absent from the accepted helper.

No owner decision is outstanding for the specified construction. This does
not authorize a different product policy, public deployment, funding,
activation, compensation, commit or merge.

All original full-plan limits remain: E2 transfer/claim/wrapper attribution;
both liquid generations, both receipt models, SY, TokenStaking/claim-vault
rights, underlying SE and fungible LP surrender; earlier liquidation,
disabled dependencies, missing legacy source and masked authorization
qualifications; approved originals, allocations and funding provenance;
complete E1-E5, tasks 9/10, invariants, F1-F4 and release. Bounded existing
NFT recovery and operator receipts do not close these categories.

This verifier performed local read-only source/evidence analysis, resident
JSON/trace reconciliation and the 18 accepted-source fingerprint checks.
No new EVM run, corrected gas receipt, build, test suite, RPC request or
public operation was executed. No runtime, listener, impersonation,
subscription or child task was started, so none is pending. No production,
test, dependency, configuration or historical evidence file was edited.

**Final disposition: admitted for the specified bounded construction;
corrected deployment feasibility remains an executable acceptance gate.**
