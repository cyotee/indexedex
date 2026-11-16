# Independent owner-paid first-bond and D1 verification

Date: 2026-11-11.

**AdversarialVerify: confirmed, for this bounded correction. D1 is closed
under the approved paid-owner-first-bond prerequisite.**

Independent execution passed all 109 current Migration specs, all 52 pinned
Migration forks, all 57 operator tests, both operator-stage builds, strict
TypeScript, and the actual fixed18563 CLI. Three existing critical tests
also passed a detailed trace replay. There are no remaining blocking
findings in this bounded first-bond, Stage2 NFT/W-L and operator-resume
verification. This is neither full-category Migration acceptance nor
public deployment/gas acceptance.

## 1. Authority, handoff and exact candidate

Worktree:
`/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-13-weighted-liquid`.
Branch: `work/dtf-migration-phase-13-weighted-liquid`.
HEAD/base remained `2c2b3370ded30cae1662329025d4fb58f7197330`.

The complete owner-first-bond directive, original Phase13 directives,
current main plan r5 and PRD r22, complete sealed Stage2 producer/verifier
reports and D1 analysis, and complete new producer report were read.
The current owner's paid-purchase and mandatory activation decisions
govern; the former genesis-weight alternatives are superseded.

Replay started only after the actual producer report explicitly declared
source modifications stopped and no owned runtime, and root admitted that
completed handoff. Temporary idle was not treated as a release.

| Bound input | Raw SHA-256 |
| --- | --- |
| Main `phase13-owner-first-bond-correction.md` | `29dca72edabe86612e98665a941d1f621cb7184e707bbfa841385fa779ccfb92` |
| Main `MIGRATION_DETF_IMPLEMENTATION_AND_TEST_PLAN.md`, r5 | `60d02b608c8a10f19cffce7b99838146c205a98410641e9bce45944e620dc56d` |
| Main `MIGRATION_DETF_DRAFT_PRD.md`, r22 | `cfe1853f49de0dc41ae106f1cc1b94eacd24d4aa8f79477c66a5b7f24a4d67ed` |
| New producer `report.md` | `b0aec1774148f103a8d2b6e265b3d3edc0de5a59ca20ed5fc7fa5eebe0f905e8` |
| New producer `bindings.json` | `8e801d24e1b9c87c60b68dabe9801fb77a65759b54be76dcab545f7e9f7f2687` |

Independent admission validated **527 raw manifest bindings**, **57
source/input snapshots**, and **15 seal entries** across the preserved
incomplete, Stage2 and owner-bond handoffs, with no mismatch.
All **54 candidate source/test/operator/runbook files** remain byte-identical
to the admitted owner-bond candidate. The closing check also matched all
468 non-artifact admission entries. The historical reports, failures,
snapshots, receipts and artifact qualifications remain history, unchanged.

`admission.json` records the original raw comparisons.
`artifact-reconciliation.json` records final source identity, compiled-input
checks, test targets, runtime comparisons and old/new artifact hashes.
`bindings.json` and `seal.sha256` bind this independent deliverable.

## 2. D1 closure and actual code coverage

Here M means
`contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/`;
S means the neighboring `test/foundry/spec/.../migration/` directory.
The correction's production and operator changes were inspected, including
the whole new purchase/callback tests and operator reconciliation helpers.
Changed existing fixtures were compared against sealed Stage2 snapshots,
or base where the file was not part of that snapshot manifest.

| Requirement | Source and independently executed evidence |
| --- | --- |
| Genuine first paid purchase, not a seed | `M/UniswapV4DetfMigrationBondFacet.sol:38-56` permits only the current Crane owner during Stage1, only while the completion ID is zero, and rejects pretransfer. It calls the actual ordinary implementation. `S/MigrationOwnerFirstBond.t.sol:24-104` passes immediate and seven-day-delayed purchases and exact principal, gons, supply, backing, weights, allocation dust and retained role rewards. |
| No synthetic participation | `critical-traces.log:35489-35491` shows actual pre-purchase `totalGons`, backing, fee weight and creator weight all zero. The real purchase then emits funded stake, `BondPurchased`, and `RewardsFunded` at lines 36915, 36936 and 36990. It funds principal 605,330,306 and rewards 89,334,239 in the hermetic fixture before publishing purchase ID 3 at line 63114. Configuration in this case issues nothing. |
| Canonical funding before rewards | Ordinary `detf/UniswapV4DetfTarget.sol:528-596,715-725` locks, pulls payment, joins capital, rejects zero principal, opens/funds the bond and then funds rewards. Common `bondNft/DETFFundedBondTarget.sol:107-137` requires exact new principal receipt and exact credited gons. The Migration child at `M/bondNft/UniswapV4DetfMigrationBondNFTVaultTarget.sol:20-26` retains `onlyDetf`, synchronization and its lock; removing the child activation gate does not expose a public creation bypass. |
| Narrow actor/route exception | `MigrationOwnerFirstBondTest.test_pendingFormerAndNonownerCannotBuyButCurrentOwnerCan` passes all four ownership states. `test_exceptionDoesNotOpenOtherAcquisitionOrSecondPurchase` rejects parent acquisition, both SY acquisitions and a second Stage1 bond. The genuine external contract-owner callback test also rejects pretransfer and succeeds only with actual payment. |
| Mandatory purchase, even after compensation | `M/UniswapV4DetfMigrationAllocationTarget.sol:199-214` checks the stored completion ID before cuts or stage publication. `MigrationCoreTest.test_ordinaryDepositOpensWithFundedIndependentParticipation` now proves independent issuance alone cannot activate, then buys, activates and deposits while preserving the independent bond's original timestamp. The CLI separately mines this prerequisite failure after three independent bonds. |
| Original D1 assertion retained | `S/MigrationCore.t.sol:185-235` starts with donation bootstrap and no independent issuance, rejects activation, performs the actual owner purchase, proves failed-cut rollback, activates and executes the original ordinary deposit assertion with positive output and exact recipient delta. It passes both the complete suite and detailed trace run. D1 was not hidden by unrelated compensation. |
| Completion is an execution fact | `M/UniswapV4DetfMigrationRepo.sol:41` stores the instance bond ID; the only new write is after successful inherited purchase and budget settlement in the bond facet. No setter, compensation substitute, snapshot mutation or reward-weight seed was added. |
| Failure rolls back effects | `MigrationOwnerFirstBondTest.test_failedPaymentAndChildMintLeaveNoPurchaseOrEconomicEffects` proves unpaid and invalid-child-recipient failures leave economic state and prerequisite unchanged. `MigrationOwnerBondCallbacksTest` proves short receipt rolls back payment, allowance, callback counter, supply, funded staking and completion; a subsequent real contract-owner purchase succeeds. |
| Callback and payout closure | The inherited purchase lock, expected synchronizer and fixed-child accounting phases remain in force. Contract-owner payment callbacks cannot activate, buy again, acquire through another route or release rewards. Bond-child reward requests remain gated at lines 73-78; receipt role delivery stays in deferred custody at `claimToken/UniswapV4DetfMigrationStakedDETFTarget.sol:354-372`, and release checks activation at lines 410-421. The egress, retained-accounting, administration and permit/retirement suites pass. |
| Ordinary terms and transfers | Purchased bonds remain unmarked, linearly vesting ordinary positions; the immediate test claims half principal at day 45. Compensation/surrender positions retain their distinct cliff marker. The owner-transition test transfers the purchased NFT and proxy ownership, preserves the completion ID, rejects the former owner's activation and accepts the current owner's activation. It then buys another ordinary bond as a nonowner in Stage2. |
| Atomic irreversible activation | The actual cut removes all seven administration selectors and Allocation interface support before publishing activation. The independent 150,000-gas trace reaches **two actual removal events**, then `OutOfGas` at lines 93727-93730. Lines 93731-93766 show Stage1, interface support and all seven original routes restored. Acquisition and both surrender routes remain closed afterward. This is current trace evidence, not reuse of the older three-removal trace. |
| Frozen credit and protected inventory | The paid purchase uses a fresh pull and the existing operation-floor budget, not booked donation/recovery inventory. Snapshot/configuration and configured unissued credit remain unchanged in the purchase tests and actual CLI. No entitlement is consumed. Existing W-L/NFT/recovery suites retain exact custody, protected inventory and rollback assertions with the measured paid-bond baseline. |
| Stage2 behavior | Successful activation removes bootstrap, snapshot capture, both entitlement loaders, independent loading/issuance and activation itself. Existing restoration negatives pass. Ordinary purchases keep normal permissions; the actual CLI executes a successful ordinary deposit from a nonowner, followed by all seven NFT/W-L surrenders. |

`coverage.json` lists every executed test by exact source, contract and test
name: 109 specs, 52 forks and three trace replays, plus all 57 operator
test names. No production or test fix was made by this verifier.

## 3. Independent commands and results

All required checks exited **0**. Full exact invocations, shell wrappers,
monitor completion identities and expected negative subprocesses are in
`checks.json`. Pipelines used `pipefail`; the existing archive credential
was inherited through `/bin/zsh -lc` without disclosure or rerouting.

| Check | Independent result | Owned evidence |
| --- | --- | --- |
| Artifact-first Solar complete current Migration specs | 109 passed, 0 failed, 0 skipped | `specs.log` |
| Artifact-first Solar complete pinned Migration forks | 52 passed, 0 failed, 0 skipped | `forks.log` |
| Explicit build of both operator Foundry stages | Exit 0 | `operator-stages.log` |
| Three operator test files, single run | 57 passed, 0 failed | `operator-tests.log` |
| Strict TypeScript | Exit 0, empty diagnostic output | `operator-types.log` |
| Actual block108944663/port18563 CLI | `bounded-rehearsal-complete`, exit 0 | `rehearsal.log` and run directory |
| Detailed D1, unseeded purchase and contract-owner callback traces | 3 passed, 0 failed, 0 skipped | `critical-traces.log` |
| Final whitespace check | Exit 0 | `cleanup.json` |

The artifact helper received all seven actual changed production roots:
the Migration interface, repo, permanent target/facet, allocation target,
bond facet and bond-NFT target. Specs used the complete current Migration
spec directory and both operator stages as consumers; forks used the
complete current Migration fork directory with `FOUNDRY_PROFILE=fork`.
Every compiling Forge command used Solar.

Both
`Phase_08_Stage_00_OperatorEnvironment.s.sol` and
`Phase_08_Stage_01_MigrationExecution.s.sol` were explicitly built before
operator execution. Tests used:

```sh
bun test --timeout 15000 \
  ./scripts/recovery/dtf-migration/preparation.test.ts \
  ./scripts/recovery/dtf-migration/execution.test.ts \
  ./scripts/recovery/dtf-migration/weighted-liquid.test.ts

bun node_modules/typescript/bin/tsc --noEmit --target ES2022 \
  --module ESNext --moduleResolution Bundler --strict \
  --noUncheckedIndexedAccess --exactOptionalPropertyTypes \
  --skipLibCheck --types node scripts/recovery/dtf-migration/*.ts
```

The CLI used the unchanged fixed alias, block, port and checkpoint, with
`--evidence` set to this `owner-bond-verification/` directory. The existing
CLI appended `owner-bond-correction/` inside it, keeping every producer and
historical evidence directory untouched.

Existing compiler warnings remain visible. The Solidity definition LSP
request timed out; actual source traversal and compiling execution supplied
the evidence. JSON LSP was unavailable because Biome is not installed.
No tool, dependency or configuration was installed or changed.

## 4. Actual independent local sequence

Owned run:
`owner-bond-correction/rehearsal-1794433923560/`.

Proxy: `0xedf7d9f65b9e57d62a3c4278223170db1308f5f0`.
Funded snapshot:
`0x990fc4a8d0871532186bb994b27a889c71085b7ef8e542e660bb35d887136aa4`.
Historical source pin: chain 4663, block 108944663, hash
`0xc497433dd691a40cb85959cfeba2e3fff85a975ae060612d984998e1d5765733`.

The CLI deliberately preserves independent issuance before purchase to
test that it cannot substitute for purchase. The separate real
registry-deployed hermetic case above proves the unseeded purchase.

| Operation | Actual receipt |
| --- | --- |
| Activation rejected despite independent compensation | Block 108944935, `0xa2eb210890c6f63b1ed1b1f05df33330be4d3e2ac8d72cc9a0721a95f20fe050`, status 0, `MigrationOwnerFirstBondRequired()` |
| Owner purchase | Block 108944937, nonce 2146, `0x837fecf0c13c873c1860911fbb718b81f70558391989ebfe49178c2cee521417`, status 1, bond 6 |
| Activation | Block 108944941, `0x4c1ca5ff27913c6d844e51d20938eafe0f414af97cf52e3c0e8ff3cec78858b5`, status 1; all seven removal events; 182,796 gas |
| Nonowner ordinary deposit | Block 108944944, `0x4d9b92b7f8603b8ef1bc7d78096df60f690f9d7c60e7e9ab685554acb601af6a`, status 1; output and recipient delta 462,096,413, refund zero |

The owner actually pays **1,000,000,000,000,000,000** payment-token units.
Raw transfer, stake and purchase events establish principal **465,583,908**
and funded rewards **84,489,332**. Backing moves from **1,383** to
**550,074,623**, exactly principal plus rewards above the prior balance.
The position starts at simulated timestamp 1794111193 with duration
7,776,000 seconds and no migration-cliff marker.

Independent integer recomputation matches every captured final staking
state field: canonical allocation is 50,693,599 staking, 10,138,719 fee,
23,657,012 creator and 2 allocation dust. Representable staking growth is
50,693,598 with 1 staking dust. The final divisor is
901809661440931663891971256078279707. Role reward gons remain deferred;
the executed receipt-block reconciliation verifies backing, beneficiary
receipt balances and cleared child-funding allowances.

Actual bond reward, fee/creator release and duplicate-purchase receipts
all fail with `MigrationRewardsClosed()` before activation. Snapshot and
all seven routes remain unchanged through purchase. `runtime-index.json`
contains exact failed receipt identities, decoded economic events,
recomputed state and all operator/fixture receipt bindings.

### NFT and W-L preservation

All seven positive surrender receipts occur strictly after activation:

| Source / operation | New bond | Exact native credit |
| --- | ---: | ---: |
| W-L partial, 7,075,176 units | 7 | 924,869 |
| Weighted NFT 4 | 8 | 13,872,781 |
| Weighted NFT 26, returned to original wallet | 9 | 22,233,172,691 |
| Earlier NFT 3 | 10 | 923,391,925 |
| Weighted NFT 6, late | 11 | 36,992,599 |
| Earlier NFT 9, late | 12 | 46,243 |
| W-L final, 14,150,354 units | 13 | 1,849,739 |

W-L Q0 is 21,225,530 and C0 is 2,774,608, from the explicitly synthetic
6,000,000,000,000,000-wei original ETH component and zero DTF component.
The partial leaves Q/C = 14,150,354 / 1,849,739; the final consumes all
residue and leaves zero/zero. Actual W-L bond starts are 1794111210 and
1825676105; both have fresh 7,776,000-second cliff durations and exact
funded gons. Simulated timestamps are not public issuance dates.

The independent run retains seven Stage1 NFT failures and two Stage1
W-L failures, plus postactivation missing-record, wrong-wallet,
approved-operator, original-wallet-without-control, consumed/exhausted and
removed-loader failures. Actual positive receipts were independently
decoded and joined to their observation and funding records. Partial/final
loader calls remain mined `NoTargetFor(0x256c417b)` failures, not amendments.

W-L partial conversion receives 37,926,535,439,701,004,167 DTF units and
donates 18,963,267,719,850,502,083. Final conversion receives
75,849,094,819,691,894,738 and donates 37,924,547,409,845,947,369.
Seven unbooked WD units and the separate 1 ETH-unit DTF floor remain
protected, self-allowance is zero, and personal compensation is unchanged.
The NFT recovery observation retains 103,958,457 original receipt units
plus 11,891 later-accrued units, totaling 103,970,348. Earlier sale-and-hold
is still not proven liquidation.

### Three actual mined-before-checkpoint resumes

| Operation | Nonce | Actual canonical transaction |
| --- | ---: | --- |
| Donation | 2118 | `0x997f7a1aaf6566ef78629e4aef31ee70b6bc83dc32bd4b3c44e8ce66d61b5399` |
| Independent issuance | 2131 | `0x1ad4429e039e711bf8e674264ced0c8145d3f7f4c2f63109f00be6acab350d16` |
| Owner purchase | 2146 | `0x837fecf0c13c873c1860911fbb718b81f70558391989ebfe49178c2cee521417` |

For all three, the saved interruption contains a successful mined receipt
while completion is absent. Independent decoding confirms signed
transaction hash, sender and nonce. Every field in the resumed canonical
receipt matches the interrupted receipt. Fresh-process command records
prove actual resumes; the purchase is resumed read-only and twice in
local execution mode without another purchase nonce.

The two genuinely outstanding independent rows reverse order and create
bonds 4 and 5 after interrupted bond 3. Each principal is 461; supply
moves from 1,000,000,000,000 to 1,000,000,001,383 before purchase. The fourth
recipient remains independently unissued with bond ID zero. Its later
ordinary deposit does not create independent compensation.

This run contains **41 successful operator receipts**, **127 fixture
receipts** and **47 command records**. The 47 mined fixture failures,
six controlled domain-rejection commands and three intentional SIGKILL
interruptions are expected negative witnesses; every required top-level
check exits 0. Some transaction hashes equal the producer's because the
local fixture is deterministic; they were independently executed and
captured in this new run, not copied from its receipt directory.

## 5. Final source, artifact and runtime bindings

The final comparison scans **684 distinct compiled metadata inputs** across
16 production/operator/interface artifacts and 43 test artifacts. Every
source keccak256 matches actual final bytes; all 43 test compilation targets
match. This broader scan includes test-artifact dependencies rather than
merely inheriting the producer's 641-input summary.

Ten relevant parent/package/child deployed runtimes match final artifact
bytes, masking only compiler-declared library or immutable spans and
retaining the observed span values. All 31 captured parent/child runtime
records also match their own code hashes and the producer's captured bytes.
In particular, these changed surfaces match **without any masked spans**:

| Surface | Actual facet | Runtime keccak256 |
| --- | --- | --- |
| Parent paid-bond facet, 9,764 bytes | `0x046402db2a88b54da34dec0fdd0f9ae549b43cc0` | `0x6ac2610d2480e363c4a8db0db96989241d2285333dafe3271811f0ed86b46f7e` |
| Bond-child facet, 9,483 bytes | `0x2961a135928e633bddb5d4ed52603ee46ce023f9` | `0xf9c6357a123f626d53c7b876c04daf84ea06f54a9373128698cef094174eb61f` |

The bond child is `0x76D3b85BE8cc91dF1e66cfd3c81681795555E58C`.
The independently compared staking-child facet is
`0xa4c01791f5042a7878391c9b6603eebefbc3b5a7`.

**Raw-artifact qualification:** 42 of the 59 bound artifact JSON hashes
changed during independent build/test/trace generation; 17 did not.
Every original raw hash matched at admission. No old raw hash is relabeled
unchanged afterward. `artifact-reconciliation.json` records each original
and final hash separately. Final acceptance rests on unchanged source,
matching compiled inputs/test targets and actual runtime parity, not
claimed byte-identical regenerated JSON. Earlier Stage2 reconciliation
of 13 changed hashes remains a separate immutable historical record.

## 6. Limits and owned cleanup

All purchase and allocation amounts are synthetic fixtures. Real
original-wallet, canonical-origin, Q0 and ETH/DTF contribution records
remain operational inputs. Known-origin guards do not establish global
disjointness of opaque aliases. No real payment amount, bond duration,
allocation or public transaction is approved here.

Other legacy categories retain their existing source/unit/mapping/caller,
disabled-route and integration limitations. No full ordinary/common
shared-suite replay was performed: this candidate changes no shared
production input. This bounded green correction does not close all
Migration categories or all plan acceptance rows.

The actual local parent deployment uses **43,263,865 gas** on the
permissive 100-million-gas node, transaction
`0x78479d09e968252e83fad3f99c09bfc55657b48e3d24013489de9bbaa9e306b3`.
It does not establish feasibility against the retained historical
32,000,000 transaction limit. No held phase09 candidate was inspected,
imported or replayed, and no provider was rerouted.

Owned Anvil PID **54333** exited through the scenario's cleanup. External
`ps` and port18563 `lsof` probes returned exit 1 with no process/listener.
The fixed checkpoint is absent, and removal of its empty task-specific
parent exited 0. Impersonation cleanup and provider closure ran before
node shutdown. All five owned build/test/rehearsal/trace monitors completed
with exit 0. **No owned runtime remains pending.**

Only verifier-owned evidence was authored; no production fix, test edit,
dependency/configuration change, public action, commit, push or merge was
performed. Warm `out/` and `cache_forge/` remain local, with no copy to main.

**Final bounded disposition: confirmed. The owner-paid first ordinary
bond and mandatory activation prerequisite close D1; the approved Stage2
NFT/W-L behavior and all three real operator resumes remain confirmed.
The source-category, operational-data and public-gas limits above remain.**
