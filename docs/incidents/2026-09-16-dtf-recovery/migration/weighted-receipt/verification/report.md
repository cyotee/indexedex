# Independent weighted receipt implementation verification

Date: 2026-11-12. **Disposition: confirmed for the admitted, bounded weighted
receipt implementation.**

No blocking implementation or executed-route defect was found. Independent
execution passed all 134 current Migration specs, 92 current pinned Migration
forks, both operator-stage builds, strict operator types, all 68 operator tests
in one invocation, and a fresh actual fixed18567 CLI with three real
mined-before-checkpoint interruptions and fresh-process resumes. Independent
raw-byte, compiler-metadata, runtime, signature, receipt and economic audits
passed. No production fix was made or requested.

This is a runtime verdict on the stopped uncommitted candidate, not acceptance
of an immutable delivery, the full Migration plan, operational allocations,
portable/full-F3 execution, target deployment gas, or public execution.
No verifier-owned runtime or operation remains pending.

## 1. Authority, actual handoff and exact candidate

Worktree:
`/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-17-weighted-receipt`.
Unchanged HEAD/base: `a96f0fd26c1a1fdba35750cff74d866afa3a9796`.

Read both complete phase17 briefs, current main plan r5 and PRD r22, the
owner-first-paid-bond directive, the complete phase11 weighted source contract
and independent report/matrix, and all six specified final phase16 reports.
The historical phase16 needs-fix report was read together with its additive F1
closure and final delivery audit, not replaced by the later result. Read the
complete admitted source contract, actual independent admission, and complete
actual producer implementation report and final seal.

| Immutable admitted input | Raw bytes | Independently reproduced SHA-256 |
| --- | ---: | --- |
| `../source/contract.md` | 18779 | `8505a56f2b9dec9a34d9fb322d1a9cd78aa7e151678008427143cce9ff782bd6` |
| `../source-verification/report.md` | 15387 | `b39dd7edeb5f0250ffd257744df2304eb18485c195f121ec64f058eebb077c56` |
| `../implementation/seal.json` | 442031 | `082357f4df799ddd70380f872d6f323e7ab1ce2e5b9865fa9a3e42d75716ce16` |

Before execution, the actual producer report declared source modifications
stopped, its final candidate validated, and no pending runtime. Every one of
958 sealed implementation evidence entries and 36 final changed/new source
paths matched. Port18567 had no listener, producer PID29538 was absent, and the
fixed checkpoint was absent. Thus this was a completed producer handoff, not a
pending, needs-fix or workflow-count substitute.

All 137 files and exact membership of `source/` and `source-verification/`,
including all 236 seal references, remain unchanged. The prior superseded
not-ready inference, original witnesses, failed producer attempts and historical
reports remain intact. All specified main/phase11/phase16 input hashes match.
`bindings.json` retains every independently checked path, raw length, hash and
compiled binding. Final preservation also checks all producer-recorded modes;
none changed. The index is empty and the tracked whitespace gate exits0.

Actual diff inspection covered all 36 candidate paths, including seven added
test/operator files. The nine production edits are confined to Migration
interfaces, storage, allocation/recovery facets/targets and the legacy recovery
library. Existing registry/package/TestBase wiring is reused. No
ordinary/common/Crane production, dependency, configuration, provider, held09,
public, commit or merge operation was performed.

## 2. Independent execution and full required matrix

`commands.json`, `checks.json` and the six raw logs record exact commands,
exit codes, raw byte lengths and SHA-256. Both artifact-first test commands
name all nine edited production roots, including ABI and storage, rather than
only the final target. The complete current spec/fork directories were run.
Solar builds precede tests and actual operator execution; the stage build
covers both Stage00 OperatorEnvironment and Stage01 MigrationExecution.
Existing warm artifacts and prescribed dependency links were retained.

| Independently executed check | Actual result |
| --- | --- |
| Artifact-first complete current Migration specs | Exit0; 134 passed,0 failed/skipped;23 suites |
| Artifact-first complete current pinned Migration forks | Exit0;92 passed,0 failed/skipped;18 suites |
| Both current operator-stage builds | Exit0;Solar compilation successful |
| Strict operator types | Exit0; no diagnostics; strict, noUncheckedIndexedAccess, exactOptionalPropertyTypes and verbatimModuleSyntax |
| Seven operator files, one final invocation | Exit0;68 passed,0 failed |
| Actual pinned18567 CLI | Exit0;`bounded-rehearsal-complete`; all three actual mined interruptions/resumes |
| Independent source/artifact/runtime audit | Exit0;36 candidate sources,137 immutable files,25 deployed bindings,675 compiled sources |
| Independent signed journal/receipt audit | Exit0;49 signed completions,13 WS signed operations,three raw receipt comparisons |
| Independent actual economic audit | Exit0;source acquisition/reward arithmetic, exact custody/credit/fresh cliffs and residual |
| Final strict verifier-probe types | Exit0; no diagnostics |

`coverage.json` contains every actual passing test name and log line, not a
sampled checklist. For the table below, M is
`contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/`; the named new
spec/forks are in their existing Migration test homes.

| Required behavior | Actual source and independently executed evidence |
| --- | --- |
| Documented eligible original gons, frozen credit and original grouping | `M/interfaces/IUniswapV4DetfMigration.sol:246-276`, `M/UniswapV4DetfMigrationClaimVaultAllocationTarget.sol:58-94`; configuration replacement/replay checks Q0 and both original components, exact frozen evaluator output and zero issuance. Operator tests reject native/pricingMode substitutions, missing/unknown fields, noninteger inputs and mismatched gon partitions. |
| Owner-only complete/idempotent Stage1 configuration | `MigrationWeightedReceiptConfigurationTest` executes invalid owner, pending/former/current owner, wrong chain/source, missing fields, wallet correction and bad second-row whole-batch rollback. It verifies no supply or staking-gon issuance on loading. |
| Every canonical-origin exclusion, both directions | Its `test_everyCanonicalOriginExclusionWorksBothDirectionsIncludingWalletCorrections` covers independent compensation, both NFT families, WD, WY, W-SD and direct claim-vault shares; also issued-original history after independent replacement. The production guards were inspected in both allocation targets. Opaque documentary aliases still require operational reconciliation. |
| Stage1 closure, Stage2 original-wallet control and transfer-back | `MigrationWeightedReceiptTest.test_stageOneAbsentWalletTransferAndReturnCannotMoveOrRestoreCredit`; fresh CLI contains signed Stage1, missing-record and other-holder failures, actual transfer away/back and later successful original-wallet surrender. No transfer ancestry is required or fabricated. |
| Permanent loader removal and retained queries/surrender | Complete surface/core/configuration tests pass. Actual signed activation removes exactly all11 methods in the current Allocation ABI, including `configureWeightedReceiptEntitlements`, selector `0x92631220`, across both removable facets. Raw cut logs are in `lifecycle-recovery.json`. |
| Real paid owner-first purchase and reward gate | All owner-first-bond and callback specs pass. Fresh CLI activation rejects before actual paid purchase even after independent issuance. Its real `bond` transaction creates ordinary bond6 before activation; duplicate Stage1 purchase, reward and fee payout reject. Snapshot and administration routes remain unchanged by purchase. |
| In-operation protected old-source settlement | `M/legacy/MigrationLegacyRecoveryLib.sol:33-61` first calls old WD `synchronizeRewards()` under the parent's shared guard, then takes both WS baselines. Actual partial CLI receipt contains old reward funding before its WS transfer. The independent audit recomputes allocation floors, ceil-divisor rebase, growth, role issuance and all seven source-state words. |
| Ordinary and both real role endpoints | Both `test_realRoleWalletSettlementExcludesNewlyIssuedRoleGons` and `test_actualRoleNftTransferMakesCustodyRewardsUnbookedNotSurrender` pass. The latter uses an actual authorized creator-role NFT transfer to Migration, not storage/role fabrication. Only n*k is consumed/booked; role gons remain outside that admission. |
| Exact native pull, unchanged measured divisor and exact gon deltas | `M/UniswapV4DetfMigrationRecoveryTarget.sol:51-113` and the pull library require actual native allowance, unchanged k, exact wallet debit and custody credit, and floor(gons/k) native consistency. Actual signed CLI calldata, transfer logs, source-state observations and q/C recurrence independently reconcile in `economics.json`. |
| Positive partial and actual divisible terminal credit | `test_partialAndDivisibleTerminalConsumeExactGonsAndCreateFreshFundedCliffs` genuinely acquires101 WS, surrenders1 then100 at unchanged k, and delivers all frozen C0 with Q/C=0. No source-only arithmetic witness substitutes for this real-Migration branch. |
| Original cap, zero credit and nonrepresentable residual | The growth test retains positive Q<k and C, then genuinely acquires another native unit and proves the configured cap still rejects. The separate zero-credit test rejects an actual approved positive pull without confiscation. Source/minimum/deadline failures retain economic state. The CLI residual is not mislabeled terminal. |
| One exactly funded fresh90-day cliff per successful surrender | `_fundBond` mints exactly delivered credit and uses the actual child's exact pull/stake path; both temporary allowances clear. The child marks the actual fresh position before checking the receiver and emits its own creation event. Fork assertions and raw CLI observations verify principal, zero claimed amount, exact staking gons, block timestamp,7776000 seconds, wallet ownership and separate bond IDs20/21. Existing cliff-boundary specs also pass. |
| Source/funding/callback atomicity and shared reentry guard | `test_sourceFailureAfterDueSynchronizationAndMinimumDeadlineRollback` proves old WD settlement rolls back with a failed source pull or late minimum. `test_lateBondCallbackRevertsSourceFundingCustodyAndCreditThenRejectsReentry` reaches the rejecting real contract wallet after child funding, restores old/new staking, custody, Q/C, supply and backing, then succeeds with attempted reentry rejected. Existing funding-failure/parent-child callback suites also pass. |
| Pre/post-custody growth and full-account retirement | `MigrationRecoveryWeightedReceiptTest.test_postCustodyGrowthFullAccountRetiresActualBookedFractionAndDonatesOnlyRecovery` executes actual full-account retirement, including more than native*k, when every retired gon is booked. Original C0 and new bond backing stay fixed; the real one-DTF donation budget remains protected. |
| Mixed inventory and unbooked full-account boundary | Its mixed NFT/WY/WS test includes unsolicited native/fraction gons,7 unbooked WY shares, unrelated DTF and donor budgets. Full-account spending rejects; smaller valid exits preserve exactly the unbooked gons and fractions. NFT recovery history and new backing remain intact. The retained `requireGonDebit` authorizes actual debit, not displayed native units alone. |
| Fixed WS->WD->DTF->new-reserve route and selected-batch rollback | Both fresh CLI recoveries execute existing stages3/4/7. Independent decoding checks both conversion events against actual selected amounts and DTF outputs, and mined late-failure receipts have status0/no logs. The new fork's bad final selected NFT proves preceding source growth, unstake and conversion roll back together; smaller retry succeeds. |
| Existing categories and operator parity | Complete suites and CLI retain both NFT families, WD, WY, W-SD, direct claim-vault and all earlier recovery/rounding negatives. Preparation, proof records, ABI, configuration hashes, stages, execution reconciliation and runbook were inspected together. All14 typed category dispositions remain present; six unimplemented/blocked categories remain blocked. The historical16 source/exposure rows, including native/WETH limits, remain preserved inputs. |

The CLI was independently executed using the approved existing `/bin/zsh -lc`
login environment, installed Foundry and pinned Bun1.4.2. No resolved upstream
credential is printed or retained. This is a fresh execution of the existing
actual CLI, not an independently reimplemented CLI. The byte/signature/receipt
and economic audits in this directory were independently authored; producer
summary flags and producer audit output were not used as their proof.

## 3. Actual pin, registry, source, compiler and runtime identity

Fresh evidence:
`runtime-01/rehearsal-1794461873227/`.
Independent Anvil instance:
`0x35694a2d26b042ea3acfcc310a32ddd5dabf0585c17d76299194210eddd6f427`,
owned PID40856. Historical chain4663/block108944663/hash
`0xc497433dd691a40cb85959cfeba2e3fff85a975ae060612d984998e1d5765733`
is checked before operations. This is distinct from the producer's completed
runtime and is not inferred merely from deterministic transaction hashes.

The actual deployment receipt authenticates registry
`0xaa66038ae217b246f5bf7537104342672e56fed8` emitting `NewVault` for Migration
`0xedf7d9f65b9e57d62a3c4278223170db1308f5f0` and package
`0x642fa76f2f7a6b97ec0822d67a785379a92df347`. Actual TestBase and package
composition use artifact-backed Components and registry package deployment;
there is no directly constructed substitute Migration.

The acquired WS selector facets equal admitted
`0xb7581fe833a2b2380dd786b345d61ffb734d36eb`, runtime hash
`0xcb505aba37d6ad909d8fb33dbf0091be50c9dd37f43e5df506bd240fc711b361`.
Admitted archived source was read for synchronization, native allowance,
gon transfer, role distributions and full-account retirement. Existing source
admission supplies the archived-source equivalence boundary; no current legacy
source was fabricated or recompiled as an asserted old deployed match.

`bindings.json` independently compares25 actual deployed facet/package byte
arrays with current artifacts and checks every one of675 distinct
compiler-metadata source keccak256 values against current raw source bytes.
It also binds five current static stage/ABI artifacts. Compiler:
`0.8.38+commit.e7a91fc7.solar.0.3.0-dev`. Runtime length must match exactly;
only explicit compiler-declared link/immutable spans are excluded from byte
comparison, with each observed span retained. No metadata stripping or arbitrary
mask is used. All captured component/runtime hashes are recomputed.

| Actual Migration facet | Runtime bytes | Actual runtime keccak256 |
| --- | ---: | --- |
| Persistent Migration | 24407 | `0x6035c086c919419021ea6460ae007577905e04b3aa3c463e6e73862281a173a4` |
| Allocation | 24419 | `0xcb31598350c9d7179c3e580e95964883933fa6508ab028eb4c4ee113192bd0f7` |
| ClaimVaultAllocation | 7940 | `0x3de80586d85fd0c3758e323afa48420e90b6a3bcfebff4abe1eb00fe44633830` |
| Recovery | 18563 | `0xb175925e6f7fd36a46288f6d83c9e606b398dd6696d5f9f615a70be42bb82046` |

Every captured deployed facet/package satisfies24576 bytes. Script/test sizes
are not presented as facet EIP170 observations.

## 4. Actual original-wallet economics and preserved residual

Controlled development derivation117, wallet
`0x83781cf2371117aac856621805fb83c9ca439bad`, signs WD approval and genuine
staking of101 native WD into WS. Only the existing EOA funding transfer and
native gas funding use the disclosed local fixture mechanics; source balances,
storage, roles and code are not manufactured.

Q0=`88423667347055516852883910490677229029` equals101 times the actual
acquisition divisor `875481854921341751018652579115616129`.
Original ETH0.01 is replaced by synthetic ETH0.006, known DTF0, with the same
Q0; frozen C0 is2774608 native9. These are code-proof originals, not approved
historical operational allocations. Configuration identity independently
recomputes from chain/proxy/snapshot/the complete original tuple:
`0x08b371fca6dbf875314246f9a4437e7814e626b694ed60e58c87bf3af7bfaade`.

| Actual operation | Native n | Eligible q=n*k | Frozen credit |
| --- | ---: | ---: | ---: |
| Partial, bond20 | 1 | 777115857147200976553683127870445154 | 24384 |
| Last currently representable, bond21 | 112 | 87009160927567232191952256653978938688 | 2730223 |

Partial transaction:
`0xd5ffd4246b9279c9e444f1a6f92e0bc9881af0918dd75b9bcb4582846938dd80`.
Residual-producing transaction:
`0x56351ed111421ee389413b37a014f48bc2b1db9adaa726254d7924439280915c`.
Their actual receipt-block timestamps, raw signed calldata/events, all seven
staking-state words, exact backing/supply changes, cleared allowances and
five-word bond positions reconcile in `economics.json`.

The preserved Q is `637390562341083684377970708827845187`; C is20001.
Q is positive and below current k=`776867508281850287428145148696240524`.
Delivered2754607 plus retained20001 equals original2774608. This is not
q==Q, a terminal payout, forfeiture, display-zero clearing, ceiling custody,
clamp, excess donation or a promise of future representability. The divisible
terminal branch is separately executed through the real-source Migration fork.

Actual subsequent DTF recovery outputs are5205757392601 and600367438233269
native18. Raw conversion/donation receipts and selected late failures are
retained in `lifecycle-recovery.json`. Recovery does not enlarge original
eligibility or issue a second personal award.

## 5. All three genuine interruption resumes and raw receipts

| Interrupted operation | Nonce | Actual independent signed transaction |
| --- | ---: | --- |
| Donation | 2125 | `0xdae572ccd88a265cd1d4b4f40fdb5693bacaaa7caae8a14abedc7ecbf8bcbd63` |
| Independent issuance | 2142 | `0xb3fa9c444afb30d6ab19e2cce6e1419207945f1f3f0bec7a2bf8b838f916d388` |
| Paid owner first bond | 2161 | `0x9369dec1a602b6f06030f2c899ad7854b2318ada1823f7659314b026f9a4e995` |

Each child command actually terminates by SIGKILL after mining and before
completion publication. The before-resume witness contains a canonical mined
success receipt and no completion. Fresh-process resumes reconcile the same
signed intent. All49 operator completions are decoded independently for raw
hash, recovered signer, chain4663, nonce, target, value and calldata.
Interrupted raw RPC transactions additionally reconcile gas, gasPrice and
r/s/v signature values. Domains are keyed by `(domainHash,id)`, preserving
legitimate idempotent configuration replay across different prepared domains.

For each interrupted operation, all15 actual canonical receipt fields are
compared recursively: blockHash, blockNumber, blockTimestamp, contractAddress,
cumulativeGasUsed, effectiveGasPrice, from, gasUsed, logs, logsBloom, status,
to, transactionHash, transactionIndex and type. Complete nested logs are
included. No `sameCanonicalReceipt` flag substitutes for equality.

All13 additional WS signed operations are independently decoded and bound to
their raw receipts; five are mined status0 failures with no logs and unchanged
recorded economic state. There are273 fixture receipts, overlapping these
collections rather than an additive transaction count. Unlocked local fixture
transactions are not represented as signed original-wallet transactions.
`receipts.json` preserves the complete audited raw receipt objects.

## 6. Findings, failed attempts, limits and cleanup

**Blocking implementation findings: none.**

Two verifier-auditor errors are preserved in `failed-attempts.md`: the first
receipt auditor incorrectly treated identical operation IDs in different
preparation domains as duplicates; the first economic comparison treated
checksummed and lowercase decoded address text as unequal. Corrected
domain-aware and address-byte-equivalent comparisons pass without changing
source, tests, producer evidence or runtime witnesses. Their initial exit1
results remain failed attempts, not accepted checks.

Existing compiler/nightly/unknown-fmt-key warnings remain in raw logs. Solidity
LSP reports no errors for the inspected Recovery target. TypeScript LSP returned
clean results for initial verifier probes but some post-edit freshness requests
timed out. Final strict operator and verifier typechecks pass; stale/failing LSP
requests are not called clean. JSON LSP is unavailable because Biome is absent;
JSON evidence is directly parsed and raw-hashed, with no dependency/configuration
installation or bypass.

Actual signed parent deployment
`0xf535b5d997190bca825a1c732bd6b145f8c5868b92646d8fd5fab8cafd9cfd94`
uses **44,353,454 gas**, above the retained historical32-million transaction
limit. Prior44,099,850 remains historical evidence. The100-million local node
does not establish target feasibility; actual EIP170 checks remain enabled.

Operational original-wallet/origin/Q0/component datasets and semantic
opaque-origin reconciliation remain unapproved. Earlier receipt/liquid,
raw TokenStaking, blocked SE/LP categories and native/WETH exposure limits
remain separate. The phase15 W-SD source archive remains a host dependency:
1,047,506 bytes, SHA-256
`600c072adccc5e624333fd3dfd511787a3d89868193b320efdb8cbfc912483e7`,
at the original phase15 worktree path in `economics.json:sources`.
Exact legacy claim-vault source equivalence remains the prior disclosed limit.
No portable/full-F3, complete hermetic/full-plan, immutable-delivery, target-gas
or public-operation acceptance is given.

Fresh CLI cleanup records PID40856 exited and fixed checkpoint removal.
Independent `ps -p 40856,29538 -o pid=,command=` and
`lsof -nP -iTCP:18567 -sTCP:LISTEN` each exit1 with empty output. The fixed
`.omo-runtime/dtf-migration-weighted-receipt/checkpoints` is absent.
The execution monitor completed with exit0. Providers/subscriptions closed,
funding impersonation stopped, and journals/receipts were retained. No runtime
was adopted or left running. `cleanup.json` records per-command exits.

Only this `verification/` evidence/probe directory was authored. Required
local builds refreshed ignored Foundry outputs; no source, sealed evidence,
dependency or configuration fix was made. No commit or merge occurred.
`seal.json` binds all verifier evidence with raw byte counts and SHA-256,
excluding its own self-reference. Verification and cleanup are complete.
