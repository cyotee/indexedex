# Migration deployment gas diagnosis

Date: 2026-11-11.

**Diagnosis reproduced.** The accepted parent-package call consumes exactly
**42,985,843 gas** on the historical local fork. The identical call submitted
with **32,000,000 gas** fails inside raw-SY registry registration and rolls
back the parent. A second distinct instance consumes **42,267,991 gas**
despite reused factories, facets and packages. This is a per-instance
construction problem, not an aggregate-script estimate or cold factory cost.

**One proposed correction:** prepare the two fully bound, zero-supply SY
children through a Migration-specific registered SY package before creating
the parent; retain atomic parent construction, bond/receipt/RT creation,
reciprocal validation, hook removal and parent registry publication in the
final transaction. Section 5 specifies the construction and its exact owned
paths. It is a proposal for independent design admission, not implemented
production code or a claim of corrected target-bounded execution.

## 1. Scope and admitted baseline

- Worktree: `/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-09-deployment-gas`.
- Branch: `work/dtf-migration-phase-09-deployment-gas`.
- HEAD: `421072a7630a0d3d47a6f36e1062d9eae98c93e2`.
- Initial tracked/untracked status was clean with submodules ignored.
  The supplied warm-seed exit 0 and `DEPLOYMENT_GAS_WORKTREE_VERIFIED`
  were supplemented by actual branch/HEAD/cache/link inspection.
- Read the complete phase09 brief and original main-checkout
  `MIGRATION_DETF_IMPLEMENTATION_AND_TEST_PLAN.md`, repository router/rules,
  applicable canonical deployment/architecture and local-launch guidance.
- Read phase08's complete final rehearsal report, execution report, actual
  Stage 00/01 sources, funding/orchestration source, gas/transaction records,
  source bindings and final run `rehearsal-1794376137494` in place.
- Read phase07's complete independent runtime, correction-runtime and source
  commit verification reports and historical `chain-gas-limits.log`.

Only this `diagnosis/` directory was authored. Production, ordinary/common,
Crane, existing tests, operator TypeScript, configuration, dependencies,
historical evidence and other worktrees were not edited. No compile was
needed: accepted, source-bound executable transaction bytes were replayed.
No public transaction, signing key, commit, merge or dependency operation
was used. Historical public RPC reads only establish the pinned limit.

## 2. Limit provenance, not block-limit substitution

Pin: chain **4663**, RPC/L2 block **108944663**, hash
`0xc497433dd691a40cb85959cfeba2e3fff85a975ae060612d984998e1d5765733`.
The header's L1/EVM block number is 26367659. These are not interchangeable.

The following read-only calls were independently repeated with the existing
archive alias and `--block 108944663`; monitor
`mon_TVMDGXT8EKR033Q6`, session `bash_5`, exited **0**:

```text
cast call 0x000000000000000000000000000000000000006c \
  "getGasAccountingParams()(uint256,uint256,uint256)" \
  --rpc-url robinhood_mainnet_alchemy --block 108944663
  => 7000000, 32000000, 32000000

cast call 0x000000000000000000000000000000000000006c \
  "getMaxTxGasLimit()(uint256)" \
  --rpc-url robinhood_mainnet_alchemy --block 108944663
  => 32000000

cast call 0x0000000000000000000000000000000000000064 \
  "arbOSVersion()(uint256)" \
  --rpc-url robinhood_mainnet_alchemy --block 108944663
  => 116
```

These agree with phase07's preserved historical log. The transaction bound
comes from the explicit maximum-transaction getter, not an interpretation of
the accounting tuple. The historical header advertises
`gasLimit=0x4000000000000`; that field is not the 32-million transaction bound.
The owned Anvil block limit is **100,000,000**. Every infrastructure replay
and fail-before transaction was explicitly sent with **32,000,000** gas.
Only diagnostic successful parent transactions used 100,000,000, reproducing
the permissive predecessor rather than repairing or declaring it deployable.

`limits-and-transactions.json` retains the full historical header, node
configuration, limit observations and actual transaction envelopes.
This is historical local EVM execution evidence, not a current live-chain
gas/fee quote or full ArbOS fee-model emulation.

## 3. Actual reproduction

The accepted environment comprises 220 infrastructure transactions through
real CREATE3/FactoryServices and the manager registry. All 220 replayed
successfully with individual gas limits of 32,000,000. Their maximum actual
gas was **11,862,619**, an underlying V3 SE deployment, not this parent.
Five preceding transactions genuinely claim/unstake/convert legacy assets
and transfer original DTF from the real holder. No legacy code, token
balance/storage, parent storage or deployed subject was replaced.
Only native development-account funding and bounded holder impersonation
were used; every impersonation ended in `finally`.

| Object | Actual address |
| --- | --- |
| CREATE3 factory | `0x85ef1a70ae1352b33bdd2a055de5acefe8b2c01c` |
| Shared callback factory | `0xe68f9de49c682fdb3f5b4b302f896da93da7bee7` |
| Manager registry | `0xaa66038ae217b246f5bf7537104342672e56fed8` |
| Migration package | `0x642fa76f2f7a6b97ec0822d67a785379a92df347` |
| First parent | `0xedf7d9f65b9e57d62a3c4278223170db1308f5f0` |
| Second parent | `0x34faaf4cccd4f7d74c1a14ff074bbd48a706c9a3` |
| Second parent owner | `0x1111111111111111111111111111111111111111` |

The first transaction uses the exact saved phase08 package calldata,
selector `0x70299b19`, not a replacement deployment helper. The second uses
the same package with a distinct owner, freshly predicted parent, freshly
mined owner-bound weighted hook and all three real hook pairs.

| Execution | Status | Gas limit | Gas used | Transaction hash |
| --- | --- | ---: | ---: | --- |
| Exact first parent, target bounded | 0 | 32,000,000 | 29,079,047 | `0x38fa30f5d5e746a7e19a780e35862cc0767835d2db0b89b11882e179c6200451` |
| Exact first parent, diagnostic | 1 | 100,000,000 | 42,985,843 | `0x1766cd703d2b21c6e3534769bc513989f7d24cc29cac2a18c930a1b8eba77805` |
| Second parent, target bounded | 0 | 32,000,000 | 29,073,562 | Full transaction/receipt in `second-instance.json.failure` |
| Second parent, diagnostic | 1 | 100,000,000 | 42,267,991 | Full transaction/receipt in `second-instance.json.success` |

The bounded failure's deepest error is **out of gas** at trace path
`0.0.0.0.4.0.0.0.7.0.0`: the registry deployment facet while registering
the raw SY. Its child factory creation has already returned. Outer frames
revert; the parent has no code afterward and no failed-transaction logs
survive. A failed receipt below 32 million does not establish sufficiency:
nested calls exhaust their forwarded allotment while outer frames retain gas.

Both successful diagnostic instances have zero DETF supply and activation
false, distinct actual owners and five distinct bound children. The first
deployed proxy runtime is 198 bytes. `source-bindings.json` records those
observations and all exact addresses.

### Executed deliverable witness

`reproduce.ts` was typechecked and then executed against a fresh owned node.
It replays 225 funding/infrastructure transactions, mines explicitly rather
than sleeping/polling, checks canonical receipts and absent-parent rollback,
and asserts the exact 42,985,843-gas success. It passed. Its complete returned
transactions, receipts and call traces are in `witness-execution.json`.
The deterministic replay produces the same first-parent hashes above.

Start only an owned node from the dedicated worktree using the existing
credential in the login environment:

```sh
/bin/zsh -lic 'exec /Users/cyotee/.foundry/bin/anvil \
  --host 127.0.0.1 --port 18561 --chain-id 4663 \
  --fork-url "https://robinhood-mainnet.g.alchemy.com/v2/$ALCHEMY_KEY" \
  --fork-block-number 108944663 --gas-limit 100000000 \
  --disable-min-priority-fee --balance 1000000 --silent'
```

Then, after readiness, from the dedicated worktree:

```sh
bun -e 'const { reproduce } = await import("./docs/incidents/2026-09-16-dtf-recovery/migration/deployment-gas/diagnosis/reproduce.ts"); const r = await reproduce(); console.log(JSON.stringify(r));'
```

The witness returns evidence without writing files. It deliberately rejects
a nonfresh node. Stop the owned node afterward. Anvil version:
`1.9.1-nightly`, commit `430523103f3e2f9ba432ffdd2031a9f966153d0d`.
The node retained EIP-170 enforcement. No simulation was suppressed.

## 4. Exact cost contributors and cause

Call path:

```text
Migration package.deployVault(args)
  manager.deployVault(package, encodedArgs)
    VaultRegistryDeploymentTarget delegatecall
      shared DiamondPackageCallBackFactory.deploy
        processArgs / updatePkg
        CREATE2 parent
          base cuts + parent cuts + initAccount
        package.postDeploy -> temporary parent postDeploy hook
          completeReserveBondNft -> registered bond child
          completeReserveClaim -> funded receipt child
          deployToken -> reward-token child
          deployVault -> registered raw SY
          deployVault -> registered staking SY
          reciprocal binding checks
        remove temporary parent hook
      register completed parent and all discovery indexes
```

The following are actual **inclusive call-frame** costs from
`accepted-parent-success.json.trace`; paths also appear in
`call-contributors.json.first`. Ancestors and descendants must not be added
together. Internal trace gas is before transaction-wide refund accounting;
the root/receipt value is the transaction's charged gas.

| Frame / operation | Trace path | Gas |
| --- | --- | ---: |
| Parent CREATE2, all cuts and initializer | `0.0.0.0.3` | 10,370,402 |
| Parent package initializer within that frame | `0.0.0.0.3.0.8` | 2,907,532 |
| Entire post-deploy construction | `0.0.0.0.4` | 25,169,464 |
| Bond completion, including registered child and reserved IDs | `0.0.0.0.4.0.0.0.0` | 6,128,131 |
| Receipt completion | `0.0.0.0.4.0.0.0.1` | 3,869,458 |
| Reward-token deployment | `0.0.0.0.4.0.0.0.4` | 2,222,005 |
| Raw SY deployment and registry registration | `0.0.0.0.4.0.0.0.7` | 6,632,351 |
| Staking SY deployment and registry registration | `0.0.0.0.4.0.0.0.8` | 6,216,979 |
| Shared factory, entire parent construction | `0.0.0.0` | 36,356,835 |
| Parent registry delegatecall, including that factory | `0.0.0` | 43,736,846 |

Subtracting the factory frame from its registry parent gives **7,380,011**
gas for the registry frame's remaining work, including `vaultConfig` and
parent publication/indexing. This is not all assigned to one opcode.
The two SY subtrees together cost **12,849,330** gas.

Source observations:

- `migration/UniswapV4DetfMigrationDFPkg.sol:252` begins `postDeploy`;
  its child calls are unconditional on first construction.
- `common/sy/DETFSYDeploymentLib.sol:15` constructs both wrappers serially.
- `lib/crane/contracts/factories/diamondPkg/DiamondPackageCallBackFactory.sol`
  `deploy` and `initAccount` install per-proxy cuts, interfaces and package
  state. The same factory's existing-code return is not a fresh-instance
  deployment benchmark.
- `lib/crane/contracts/introspection/ERC2535/ERC2535Repo.sol:182-194`
  writes selector mappings, per-facet selector sets and facet-address sets.
- `contracts/registries/vault/VaultRegistryDeploymentTarget.sol`
  `deployVault` publishes after the factory returns.
  `VaultRegistryVaultRepo.sol:91-151` maintains vault/package/content/type/
  token indexes, including nested type-by-token indexes.

There are **six CREATE2 proxy creations and no CREATE3 logic deployment**
inside each parent transaction. Shared logic was already deployed in the
220 individually bounded infrastructure transactions. Repeated per-instance
selector/interface/storage initialization and registry discovery are the
source-level explanation for the measured constructors and registration
costs; no opcode-level SSTORE census is claimed.

The second distinct parent still creates six proxies. Its parent CREATE2
cost is 10,370,576; bond, receipt, RT, raw-SY and staking-SY CREATE2 costs
remain respectively 3,486,342, 3,495,451, 1,906,400, 4,091,096 and 4,179,472.
Its total is only 717,852 lower in this fixture. That difference includes
registry/index reuse and changed address ordering, not a universal cache
discount. Both instances exceed the target by more than 10 million gas.

### Rejected smaller shortcut, actually executed

Calling the existing bond package before the parent succeeds at **5,633,677**
gas, but the resulting parent still costs **37,599,068**. Trying to prepare
the existing receipt next reverts at **3,719,311** gas:
`DETFFundedStakingRepo.sol:59` calls `decimals()` on the not-yet-deployed
parent. This is not an out-of-gas rejection and must not be disabled globally.
`rejected-naive-preparation.json` retains the exact failed trace and the
subsequent bounded parent failure. `call-contributors.json` retains the
successful bond-only diagnostic final receipt.

The existing SY package also requires live parent/receipt validation in
`DETFSYDFPkg.processArgs`; its staking initialization checks the receipt in
`DETFSYRepo._initialize`. Therefore a script-only reordering cannot simply
pretend both SYs are preparable under current code.

## 5. Proposed correction: bound SY preparation, atomic parent publication

This is the single proposed construction. It changes packaging, not the
Migration lifecycle or economic behavior. It does not stage a usable parent,
add a generic initializer, omit a child or rely on warming global factories.

### 5.1 Preparation transaction

Add `prepareSyChildren(PkgArgs)` to the **package**, not to any parent facet.
It accepts the existing complete canonical parent arguments only: no
user-supplied child addresses, credits, selectors, calldata or route arrays.
Require execution on package `SELF`, nonzero valid owner/bindings, and no code
at the predicted parent. Preserve the existing helper's permissionless
construction for an explicit owner: do not require that owner to sign or
call preparation. The owner remains part of the immutable arguments and
address domain; the preparer gains no permission on either child or parent.

Using the actual shared factory and immutable package dependencies, derive:

1. The parent with the existing `calcSalt` rule, including owner and every
   accepted field while clearing only `baseArgs.hook` for prediction.
2. The bond with the existing metadata resolvers, predicted parent and the
   actual hook. Derive the receipt using the existing metadata resolvers,
   predicted bond, fee oracle and `optionalSalt=keccak256(abi.encode(parent))`.
   Prediction does not deploy or impersonate either child.
3. Both exact `IDETFSYDFPkg.PkgArgs`: predicted parent/receipt; raw then
   staking mode; the current `SY ` / `SY Staked ` names and symbols; and
   the exact mint/burn table token arrays.

Route derivation must preserve the ordering in
`UniswapV4DetfProcessArgsLib.storeDefaultInbound` and `storeCustomTable`.
Defaults walk hook tokens in order, omit the self leg and add each pair
then its distinct SE. Custom tables preserve validated row order and reject
duplicates/invalid rows. This is a Migration-local memory construction,
not permission to alter shared route semantics. Finalization compares it
against the actual initialized parent's tables.

Key preparation by the complete construction identity
`keccak256(abi.encode(chainId, parentPackage, completeCanonicalParentArgs))`.
Unlike prediction, this commitment **includes the actual hook**. Bind both
child argument hashes and addresses and the predicted parent. Each record is
write-once and an identical repeat is idempotent. Do not install a
first-writer-wins record keyed only by parent: because parent prediction
ignores hook, a stranger could otherwise poison a future construction with
another valid hook. Different full payloads have different preparation IDs;
the final call selects only its own exact ID and independently derived
children. No preparation can overwrite or substitute another payload.
Store the record in the new SY package, not in parent proxy storage.
Its interface-owned record contains the parent package, predicted parent,
full construction ID, predicted bond and receipt, both SY addresses and
both canonical SY argument hashes. The parent package queries this record
by its recomputed full construction ID. The record is evidence of fixed
construction, not an owner-editable authorization list.

Select a new **registered Migration-specific SY DFPkg**, with the same
selected SY/domain/permit facets, interfaces, metadata, fee oracle and
common storage layout as the current SY composition. Give it the real
callback-factory address in interface-owned initialization arguments.
Its typed preparation entry authenticates the calling registered parent
package and independently predicts that package's parent from the full
arguments. A different package cannot reserve the victim's parent address:
the factory includes the package address in its salt domain.

The new SY package records exact authorized child argument hashes and
deploys both children through the manager registry in this preparation
transaction. No vault bypass is allowed. Its normal `processArgs`,
`updatePkg` and `initAccount` must require that exact authorization and
predicted child identity. Bind `updatePkg` to the callback factory and an
absent account. Bind initialization to the expected child and factory,
reject package-SELF initialization and repeat initialization.

**Important delegatecall detail:** `DiamondFactoryPackageAdaptor.sol:10-29`
delegatecalls package salt/processing/initialization. Preparation records
must therefore be read through the immutable package `SELF` address, never
accidentally from the factory or proxy's storage.

The sole pre-parent validation substitution is a proof of the exact future
parent/receipt identities in place of reads from absent code. It is not a
blanket `code.length == 0` exception:

- Raw initialization can reuse canonical `DETFSYRepo._initialize` in raw
  mode, retaining the predicted receipt pointer.
- Staking initialization can reuse that initializer in raw mode with the
  predicted receipt prepended to each route array, then set only
  `isStaking=true`. This yields the same `detf, receipt, routes` set order
  and storage as the existing staking initializer without its premature
  external receipt read. Its authorization and final reciprocal proof
  replace that read. All backing, gons, dust, supply and accounting phase
  start at the exact existing zero values.

There is no later setter for these bindings. Children are fully initialized
and have zero supply, not mutable placeholder shells. Before their parent
exists, economic operations must fail through their fixed parent/receipt
dependencies without custody or supply effects. Ordinary zero-supply
approvals confer no power over the future parent's assets.

### 5.2 Final parent transaction

Use the existing registered `deployVault` call. Parent `processArgs` must
require the exact completed preparation commitment, including hook, even
when entered directly through the registry. `initAccount` retains existing
parent initialization, ownership and Stage 1 values.

Keep the existing bond completion and reserved IDs, receipt deployment and
RT deployment **inside this transaction**, with their live reciprocal
checks. Neither the bond nor the receipt needs a relaxed initializer.
For the two SYs, the existing deployment calls resolve the already prepared
exact instances. Registry registration remains genuine/idempotent.

Before returning, explicitly verify both SY factory package/argument
bindings, complete canonical child-argument hashes, mode, actual parent and
receipt, metadata, decimals and ordered route sets against the initialized
parent. Verify initial zero supply/booked backing and idle accounting, and
all existing RT/receipt/SY reciprocal conditions. Do not mistake unsolicited
unrelated asset balances for booked backing or introduce a donation veto.

Keep temporary-hook removal and the manager's parent publication at the
existing atomic boundary. A failure leaves no parent and no partial parent
registration. Previously prepared children remain bound, inert and retryable
for the same immutable construction. Preparation rejects an existing parent;
no package, owner, callback, initializer or activation path can mutate the
completed construction or restore removed allocation selectors.

No new product decision is identified. Permissionless, argument-bound
preparation preserves the existing distinction between deployer and initial
owner; it does not introduce an operator role on a deployed Migration.

### 5.3 Gas claim and required admission proof

Moving both SY subtrees removes a measured **12,849,330** gas of nested
construction from the first final transaction. The simple subtraction gives
**30,136,513**, but that is **not a successful corrected receipt**: cold
accesses, lost refunds, authorization, validation, repeated registry lookup
and forwarded-gas requirements change the result.

The implementation gate must execute this exact construction, every
preparatory transaction and the final transaction with `gas <= 32000000`,
for both a first and a second distinct instance. It must show successful
receipts, not just gas-used arithmetic. If the construction exceeds the
bound, it is not admitted as a fix; do not raise the limit or omit checks.
No corrected success is claimed in this diagnostic node.

### 5.4 Concrete owned edit paths after independent admission

Prefix `M` is `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/`.

| Path | Proposed work |
| --- | --- |
| `M/interfaces/IUniswapV4DetfMigrationDFPkg.sol` | Typed package-only preparation API; preserve parent `PkgArgs` and runtime selectors |
| `M/UniswapV4DetfMigrationDFPkg.sol` | Canonical prediction/preparation, full-argument commitment admission and final child validation |
| `M/sy/IUniswapV4DetfMigrationSYDFPkg.sol` (new) | Interface-owned init/preparation schema and fixed child-authorization queries |
| `M/sy/UniswapV4DetfMigrationSYDFPkg.sol` (new) | Registered, immutable, authorized pre-parent SY composition using existing facets/repos |
| `M/UniswapV4DetfMigration_Pkg_FactoryService.sol` | CREATE3/manager-registry deployment of the new SY package |
| `M/TestBase_UniswapV4DetfMigration.sol` | Select the new package and prepare before final registered parent deployment |
| `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationDeploymentGas.t.sol` (new) | First/second-instance, binding, lifecycle and rollback regressions |
| `test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationDeploymentGas.t.sol` (new) | Target-pinned transaction construction and retained initial-state assertions |
| `scripts/foundry/recovery/dtf-migration/MigrationDeploymentGasLocalQA.s.sol` (new) | Dedicated local receipt witness for preparation and final transactions |

No ordinary/common/Crane or operator-TypeScript edit is proposed. The shared
SY package is nonvirtual in the relevant methods; do not modify it merely
to permit subclassing. Compose the narrowly scoped Migration package from
the same facets/repos. Runtime Migration SY behavior remains the record.

Required negatives: substituted owner/package/hook/parent/receipt/routes;
cross-instance reuse; reentrant preparation or overwritten commitments; direct factory
and package initialization; premature child money operations; failed final
validation and exact retry; preparation after parent creation/activation;
and attempts to restore removed selectors. Preserve all five children,
reserved IDs, zero initial supply, fresh future bonds, exact funding,
snapshot/custody invariants and existing owner transitions.

## 6. Evidence, verification and retained limits

| File | Evidence |
| --- | --- |
| `accepted-parent-{failure,success}.json` | Exact calldata, first-parent receipts and complete callTracer trees |
| `infrastructure-replay.json` | All five holder-funding and 220 infrastructure transaction/receipt pairs |
| `witness-execution.json` | Fresh execution of the delivered witness, canonical receipts and full failure/success traces |
| `second-instance.json` | Distinct hook preparation, parent arguments and both second-instance receipts/traces |
| `call-contributors.json` | Flattened first/second call trees, bond-only result and initial direct-registry diagnostic |
| `rejected-naive-preparation.json` | Successful early bond, failed early receipt and failed bounded final transaction |
| `limits-and-transactions.json` | Historical header, local configuration, independently repeated limit calls and actual gas-limit envelopes |
| `source-bindings.json` | 226/226 source comparisons, accepted artifact identities, 20/20 deployed runtime comparisons and initial-state observations |
| `commands-and-cleanup.json` | Command/exit/resource receipts and final scope check |

The package creation hash is
`0xf9a8cc0c49ddc52cd96274b7354c089f66462f33243654970986e0d844a426c3`;
recovery facet creation hash is
`0xb5c728e1d786308228f9d92388fc5483226229b9207f27d36dbde5f8f0ef1c02`.
They match independently accepted phase07 artifacts. Compiler metadata is
`0.8.38+commit.e7a91fc7.solar.0.3.0-dev`. Runtime-object hashes are kept
separate from immutable-populated deployed runtime hashes.

The witness passed strict TypeScript checking (monitor
`mon_DYGTQ5B9CJRE24YN`, exit 0) and native TypeScript LSP reported no errors.
JSON LSP is unavailable because Biome is absent; no installation was made.
Evidence uses actual parsed JSON. No production edit means no new Solar
build, Migration spec/fork suite or unrelated ordinary/common rerun is
claimed. Those remain mandatory after the admitted implementation edit.

Exploratory snapshots restored actual executed checkpoints, not injected
contract state. Their receipts are historical local branch observations,
not simultaneous canonical transactions; the final delivered witness is
a fresh, linear replay. Harness corrections were preserved: an initial
misexpanded fork URL returned 401 before startup; an immediate automined
receipt read raced mining and was replaced by explicit mining; ethers tuple
object conversion was replaced with component-aware decoding to preserve
empty arrays; artifact metadata was handled in its actual object form.
None changed production or disguised a failed contract call.

Owned nodes `bash_4` and `bash_7` were stopped after evidence capture.
The failed startup `bash_2`, readiness watches and limit/typecheck/scope
commands ended. All holder impersonations ended, no subscriptions remain,
and cleanup verifies no listener on 18561. Shared services, dependency links,
warm artifacts/caches and port 18560 were left untouched.

All original full-plan limits remain: E2 attribution; unsupported liquid,
receipt, SY, TokenStaking/claim-vault, underlying-SE and fungible-LP surrender
categories; earlier liquidation/disabled dependencies and missing-source/
masked-authorization qualifications; approved allocation/funding provenance;
complete E1-E5, tasks 9/10, invariants and F1-F4/release gates. This report
closes only the requested diagnosis and supplies one bounded construction
for independent design review. It does not authorize public execution or
declare the full Migration implemented.
