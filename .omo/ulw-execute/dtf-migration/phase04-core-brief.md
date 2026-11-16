# Phase 4: working Migration core

This is authorized implementation, not another requirements report.
Root will create `/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-04`
on `work/dtf-migration-phase-04` from the independently verified combined
integration commit and record its exact base before dispatch. Never start
from an uncommitted or unverified integration tree.

Verified base: `6e27ecaa242c4acca132e3575a160514aad07b11`, whose parent is
the accepted pricing commit. The combined check passed 10,035 tests in
602 suites with current artifact/source bindings and owned runtime cleanup.

## Binding inputs and scope

Read the complete main-checkout Migration implementation plan, applicable
repository rules and canonical architecture/deployment/testing skills.
Read the complete phase-03 `migration/package/egress-contract-r3.md` and
`egress-r3-verification.md`, plus the ownership/bootstrap implementation
handoff. R3 supersedes r1/r2; do not implement their tickets, early reward
delivery, one-gon token, Pendle forks, integration factories or adapter.

Current owner decision: only current Crane owner selects/executes pooled
genesis amounts/anchor. Contributions and subsequent ordinary donations
remain permissionless. Ownable acceptance follows actual Crane behavior,
not an invented delay.

Build a genuinely deployed, funded and callable core covering:

- Distinct registry package, owner-aware arguments/salt, exact one-time
  initialization and complete actual child wiring.
- Measured all-leg/native donation budgets and current-owner empty-reserve
  genesis; separate self supply, LP custody and residual accounting.
- One immutable frozen quote book, with actual configured ETH/WETH and DTF
  contribution identities bound by deployment configuration. No caller prices
  or caller-supplied credit. Use the already verified snapshot implementation;
  supported-route admission is explicit, not broadened by an enum or hash.
- Genuine owner configuration and execution of independent compensation,
  quoting each original entitlement separately, summing its user credits and
  creating an exactly funded fresh cliff NFT. Configuration mints nothing.
- Full-value idempotent configuration replacement, including already issued
  recipients, with execution history immutable and no retroactive top-up.
- Actual Migration bond, receipt, raw SY, staking SY and RT behavior from R3,
  including prolonged Stage 1, successful mature-principal exits, zero reward
  receipt/RT delivery while closed, and correct later reward ownership/payment.
- Real parent-before-new-principal settlement and empty-system epoch baseline.
- Stage-1 ordinary acquisition/bond gates before primary/swap selection;
  ordinary active purchases remain ordinary and unmarked.
- Current-owner atomic irreversible activation removing the entire installed
  administration surface, including genesis selection/snapshot/configuration/independent
  execution/activation. Retain lifecycle queries and Ownable; no restoration
  route via package/factory/init/callback or generic updater.

This bounded core does NOT freeze unproved legacy fungible attribution tuples,
implement counterfeit legacy custody, omit a required category, or pretend
surrender/harvest/operator-resume gates are complete. E1/E2-dependent source
entrypoints and their configuration remain later work, not no-op placeholders
installed in this core. Genuine independent compensation is the initial
production cliff caller, as the verified handoff requires.

Actual recovery E3 still needs its pinned bindings/configuration evidence.
Use real WETH and real production reserve/SE components in the core fixtures;
an explicitly labelled mintable ERC20 contribution fixture is an external test
dependency, not proof of historical recovery provenance.

## Code ownership and dependency graph

One phase DAG:

`interfaces -> (receipt-rt + bonds + sy) -> parent-and-tests -> verify-core`.

The first node writes actual shared interfaces/argument types, not fake
implementations. The three component nodes implement complete source in
disjoint domains; they do not start competing compilers. Parent integration
then owns the combined source build, real TestBase/specs and local RPC proof.
The final node independently verifies the complete core.

Repository-relative prefixes:

- M = `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/`
- C = `contracts/vaults/detf/common/`
- D = `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/`
- TM = `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/migration/`

Shared interface node owns new interfaces beneath `M/interfaces/`,
`M/claimToken/`, `M/bondNft/`, `M/sy/`, and `M/sy/rewards/` named in R3.
Package arguments belong in their interfaces. Also supply the parent's real
independent-allocation/configuration query types and exact R3 cross-component
interfaces. Define only implemented current-core selectors; no fabricated
surrender, future-proof tuple, arbitrary-credit issuer or fake lifecycle API.
Write `migration/core/interfaces.md` with the exact interface/file contract.

Receipt/RT node owns new implementation files under `M/claimToken/` and
`M/sy/rewards/`, excluding shared interfaces, plus only
`C/claimToken/StakedDETFTarget.sol` and `RebasingClaimTokenDFPkg.sol`.
Use canonical backing/gon math and R3 basis/R0/R1/R2/E/U semantics.

Bond node owns new implementation files under `M/bondNft/`, excluding shared
interfaces, plus only `C/bondNft/DETFFundedBondTarget.sol`,
`DETFNFTVaultDFPkg.sol`, and `DETFFundedBondMetadata.sol`.
Keep exact funding, flags, cliff/ordinary distinction, actual callback order,
three guarded transfers and truthful metadata.

SY node owns new implementation files directly under `M/sy/`, excluding
shared interfaces and `rewards/`, plus only `C/sy/DETFSYTarget.sol` and
`DETFSYDFPkg.sol`. Preserve both standard wrappers/routes and R3 bearer self
balance semantics, correct native RT units/sentinel, activation-gated claims
and the explicit remainder API.

Parent integration owns new M root implementations, policy facets, factories,
allocation target/facet and TestBase; `D/UniswapV4DetfCommon.sol` and
`UniswapV4DetfTarget.sol`; new TM core specs; and the local QA paths below.
After all component nodes finish, it may fix their new interfaces/source and
the seven shared C files above for genuine compilation/integration defects.
No concurrent component writer remains then. Preserve ordinary defaults.

Existing verified snapshot library/interface/TestBase, weighted-hook and V3
pricing files are read-only consumers. If a concrete defect requires another
path, report the exact necessity to root before changing it.
No shared Crane, dependencies, configs, locks, ordinary gold TestBases or
unrelated production/test files may change.

Each component returns complete implementation source and a concise report
under `migration/core/components/`. LSP/source checks are appropriate before
fan-in; explicitly label compilation/runtime as pending until the integration
node proves the assembled production system. No placeholder component is a
DoneClaim. Parent integration must fix in-scope issues rather than deliver
uncompiled fragments or shift responsibility to root.

## Runtime and tests

Root seeds the new worktree's warm `out/` and `cache_forge/` and links shared
dependencies read-only before any Forge compilation. Only parent-and-tests
compiles during production work; the verifier compiles only for a concrete
missing/failing/changed-input check.

Use actual FactoryServices/CREATE3 and manager registry deployment. No `new`
facets/packages, SUT subclass, storage injection, etching, parent impersonation,
fake issuer, arbitrary credit or ordinary-child placeholder. Test external
ERC20/callback dependencies may be controllable real implementations under
the repository's policy; SUT stays production.

Add appropriately sized real-proxy suites in TM for deploy/funding,
independent configuration, bonds, reward gates, activation and surfaces.
Include:

- Two isolated owners/hooks; zero owner/reinit/wrong roles; actual owner
  transfer/acceptance and contract owners; immutable child identities.
- Partial then complete all-leg funding; ETH/WETH; early non-owner genesis;
  refunds and unrelated inventory; exact self/LP/fee supply reconciliation.
- No supply from merely configured/unclaimed credit; same-book original
  grouping and stored-credit equality; idempotent replacements, overwrite
  after issuance, once-only actual independent issuance and whole-batch revert.
- Fresh actual clocks, unlock boundaries, delayed first issue beyond an epoch,
  prior-participant settlement and standing-weight-only participation.
- Direct and parent-composed receipt/SY operations, both internal-burn modes,
  every actual configured output, allowances/permits where exposed, mixed
  holders, old reward ownership, RT/remainders, canonical retirement, zero
  early fee/creator receipt delivery, and successful active release.
- Wrong fixed caller, stale k, short receipt, min-out failure, callback-owner
  activation and cross-child reentry; exact rollback of real balances/gons/
  supply/allowances/state. Do not count revert-only tests as payout coverage.
- Actual interface/facet/cut/loupe census, EIP-170 sizes, no surviving
  initializer/updater/old payout/administration restoration edge.
- Decode real tokenURI numeric attributes and inspect rendered cliff/reward
  presentation. Ordinary metadata/economics remain unchanged.

After source edits, use the repo's artifact-aware helper with every changed
production source and the TM directory, then the combined ordinary V4/common
and pricing regression roots from the green integration receipt. All expanded
compiling Forge calls use `--use solar`; no viaIR or profile/source-path changes.
Require actual executed counts and exit 0. Repeat only for changed inputs or
failures. Do not add prose/source-string tests or weaken prior expectations.

## Fixed local QA contract

New paths:
`scripts/foundry/recovery/dtf-migration/MigrationCoreLocalQA.s.sol`
and, only if required for actual-CLI binding,
`scripts/recovery/dtf-migration/core-local-qa-guard.sh`.

Use a fresh owned Anvil at `127.0.0.1:18548`, chain 31337, 100M block gas,
code-size enforcement and unlocked standard dev accounts. No fork/private key
or public action. Record exact addresses/receipts and a separate broadcast
directory. Bind guards to the actual selected CLI/RPC, not another service.

Stage A exact command:

```sh
FOUNDRY_BLOCK_GAS_LIMIT=1000000000 forge script --use solar scripts/foundry/recovery/dtf-migration/MigrationCoreLocalQA.s.sol:MigrationCoreLocalQA --sig 'deployAndIssue()' --rpc-url http://127.0.0.1:18548 --broadcast --unlocked --sender 0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266
```

It deploys, funds, captures, configures and independently issues through real
production entrypoints, with no impersonation. Read the actual parent address
from this stage's artifact/receipts. Advance only the owned Anvil using
`evm_increaseTime` by 7776001 seconds and `evm_mine`, then record its timestamp.

Stage B exact argv is the same command except
`--sig 'exerciseAfterCliff(address)' "$MIGRATION_PARENT"`, with that actual
verified parent address. It proves mature principal before activation,
nonzero accrued but unpaid rewards, actual current-owner activation/removal,
then correctly owned reward/RT/remainder payment. No simulated-only time warp
may stand in for a mined chain timestamp. Validate each stage's fresh
receipts/status and state readbacks. The guard must reject a mismatched
local-only endpoint before broadcasting.

This is bounded core QA, not task 9's eventual resumable operator rehearsal.
Do not claim mined-but-uncheckpointed recovery or legacy surrender from it.

## Evidence and stop condition

Evidence under this worktree's incident `migration/core/`:
interfaces/components, implementation report and raw commands/logs/receipts,
source/artifact/selector/supply manifests, metadata captures, cleanup, then
independent `verification/report.md`.

Use explicit task-owned TMPDIR/cache paths and asynchronous completion
monitoring. No early terminal response while a required check or report is
pending. Clean owned processes/ports/temp roots; preserve warm artifacts and
shared links. No commits by production nodes; root lands verified increments.

Stop when this actual core and its required real-proxy/local-chain checks are
complete and independently confirmed, or return an exact external blocker
with all independent in-scope work finished. Keep remaining source,
surrender/recovery, scripts, full-release and operational gates explicit.

## Coordinated component phase handshake

The actual shared enum is Idle=0, Synchronizing=1, Acquiring=2,
Accounting=3, Paying=4. Use these declarations, not separate numeric aliases.

Receipt admission for bond delivery/retirement is fixed-bond Accounting.
Genuine bond creation also executes its local funding body in Accounting:
exact backing pull -> receipt `exchangeIn` to bond self -> exact gon check ->
NFT mint/position `_open`. The new incoming packet is not yet an opened
position while the receipt call runs; do not misapply an outbound post-debit
attribution equality to that legitimate creation interval.

SY ingress/transferFrom and stake-to-self are Acquiring. Its typed defer,
principal, tokenize and remainder calls are Accounting. After acquisition,
pin final k and transition before a checkpoint that invokes those calls.
Coordinate the measured incoming packet's aggregate A bookkeeping so the
receipt sees true post-debit attribution without double credit. Do not
broaden caller/phase admission as a shortcut. Onward parent output routing
is Paying, after debit.

Keep only the actual fixed receipt/bond locked-parent synchronization no-op.
Donation/acquisition exceptions must follow the actual fixed-parent graph.
Each component report must state its implemented ordering; integrated tests
must exercise genuine creation and depositing into an already-earned SY
position, as well as malformed caller/phase rejection.

Sibling implementation handoffs now report the following concrete order,
still requiring integrated/runtime verification:

- Bond uses a temporary common transient lock during Synchronizing, releases
  it after the real parent call, then uses Accounting with the normal local
  nonReentrant body through funding, exact gon check, mint/_open and marking.
  Delivery and retirement remain Accounting; no temporary Paying transition.
- SY publishes the measured incoming gons into A exactly once after changing
  Acquiring to Accounting, then checkpoints the old recipient and debits the
  old earned gons from A before its receipt call. Minting new shares does not
  add the incoming gons a second time. Completed A equals sum(shares*lastK).
- Actual shared-interface names are `deferSyRewards`,
  `issueSyRewardTokens`, and `paySyRewardRemainder`; descriptive aliases in
  earlier analysis are not new selectors.

Receipt admission and the final integration tests must use these actual
source handoffs, not an expanded permissive phase set.
