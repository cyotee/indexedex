# Independent DTF-custody SE verification

Date: 2026-11-12.

**Verdict: confirmed for the bounded phase15 W-SD increment.** No blocking
source or runtime defect was found. Independent execution passed all **122
current Migration specs, 71 pinned Migration forks and 62 operator tests**,
strict TypeScript, artifact preparation, both operator-stage builds and the
actual fixed-port-18565 CLI with all three mined-before-checkpoint resumes.
Actual signed controlled-wallet acquisition, native-28 share custody,
partial/final frozen credit, exact-funded bonds and measured ERC4626 recovery
are independently confirmed. This is not full-category, operational-allocation,
full-plan, target-gas or public-execution acceptance.

**No verifier-owned runtime or pending operation remains.** Only this
verification directory was authored. No production fix, source/test edit,
dependency/configuration change, commit or merge was made.

## 1. Admission and final candidate

Worktree: `/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-15-dtf-custody-se`.
Branch: `work/dtf-migration-phase-15-dtf-custody-se`.
Exact unchanged HEAD/base: `2baab6e58dafcc3fe5f9a94570d99987d58bf42b`.

Root's setup is recorded in the main execution ledger events
`weighted-sy-commit-audited-dtf-custody-worktree-prepared` and
`dtf-custody-share-phase-started`. Root supplied completed creation,
clone-copy warm-seed and exact-clean/link verification receipts:
`mon_XD9K10AC7R7XDPNP`, `mon_H9AW2QYM4QBZ3A3T` and
`mon_1ARFHNWGJE9NQZDP`, all exit 0 before DAG start. Independent HEAD,
branch and prescribed link observations agree. Warm `out/` and configured
`cache_forge/` were retained; no dependency setup was substituted.

The complete phase15 brief, current main plan r5 and PRD r22, phase13
owner-first-bond directive, complete phase14 independent runtime and commit
reports, complete phase11 weighted contract and independent report/matrix,
actual phase01 W-SD archive/receipt ranges, complete final producer report,
and actual 34-file candidate delta were read. Seven additions were read as
complete files; the 27 modifications were inspected as actual complete diffs,
with shared funding, recovery, policy and CLI callers additionally read.
Historical Stage1 surrender/amendment wording is superseded by Stage2-only
surrender and mandatory owner-paid first-bond activation.

The final producer report initially did not exist. Root was notified and a
native creation subscription was armed. No verifier runtime began before the
actual final report and root's explicit completed-producer/stopped-modifications
handoff. Temporary workflow completion was not accepted.

| Final producer artifact | Raw SHA-256 |
| --- | --- |
| implementation/report.md | `5903665aa38c173554ea7a1f66602da3da0e656523ba4aeb6866067b54dd538c` |
| implementation/bindings.json | `9773941ec57f79711e2f01af0791d758b799739cca6745bee6c3fdda6ca81a2e` |

At admission, all **563 raw bindings** match: 34 candidate files, nine authority
inputs, two historical archives, 120 artifacts and 398 producer evidence files.
All 34 complete final source snapshots hash to actual bytes, and all 11 producer
seal entries match. `admission.json` and `source-authority.json` retain the
per-path checks. Closing reconciliation retains every authority, archive,
producer-evidence and candidate identity; the one rebuilt test-artifact
qualification is detailed in section 6, not concealed as unchanged.

## 2. Authenticated source and actual controlled acquisition

| Binding | Independently checked value |
| --- | --- |
| Historical chain / block | 4663 / 108944663 |
| Historical block hash | `0xc497433dd691a40cb85959cfeba2e3fff85a975ae060612d984998e1d5765733` |
| W-SD, native 28-decimal shares | `0x2E9C1F705aB967c5Af59249203d7495bDabb223b` |
| Asset, native 18-decimal DTF | `0xeE5576Fa1Bcaa380e591D01245f406f3f384eb01` |
| Deposit and redemption facet | `0xDbcEEFf98F2388b0eFA0C0fDA2e08cdd263Ce8f5` |
| Actual archived/pinned/recompiled runtime keccak256 | `0x99b74f701969463d5147a782113b30bef06ef1c65f58902d410849d6d2cef616` |
| Actual acquisition | `deposit(uint256,address) -> uint256`, selector `0x6e553f65` |
| Actual recovery | `redeem(uint256,address,address) -> uint256`, selector `0xba087652` |

The exact historical absolute locators are phase01
`docs/incidents/2026-09-16-dtf-recovery/migration/evidence/verification/other-metered.sources.json:2339-2538`
and `other-metered.json:11077-11498`, under
`/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-01/`.
Their infrastructure-held transfer and redemption remain **historical mechanics
only**, not a user's acquisition or approved original award. Their actual
`0xb9d405ac37e7aa22f544912461c9945bfeb8c858938bd4fdea7264674c5f0ba6`
receipt is not relabeled as this increment's execution.

The producer's complete archived Sourcify response hashes to
`600c072adccc5e624333fd3dfd511787a3d89868193b320efdb8cbfc912483e7`.
All 49 archived source contents independently match metadata keccak256 values.
The archived onchain and recompiled runtime arrays and retained pinned runtime
independently hash identically with no transformations. Archived solc 0.8.35
identifies deployed historical code; no new solc compilation was run.

`legacy-source-extracts.md` preserves the exact authenticated Target/Common/
Repo texts read. `legacy-source-extracts.md:81-83,105-118` calls the shared deposit/redeem
implementations. The common implementation pulls assets from `msg.sender`,
checks payment deltas, mints shares to the receiver, and burns an owner's own
shares without allowance when caller equals owner. Conversion uses virtual
shares and full-precision floor rounding, not a universal decimal-price rule.
These are archived source observations, not assumptions from today's ABI.

Independent run: `rehearsal-1794441946023/`.
Controlled wallet: `0x9c79357189d6af261691ecf48de9a6bbf30438fc`, development
derivation index 104. It starts with **zero DTF and zero W-SD**, receives actual
DTF from the existing legacy-NFT-claim/unstake/conversion-funded development
inventory, and signs its own approval and source deposit. It pays **1e18 DTF**
and actually acquires **1e28 native shares**. No hook/collector share inventory,
fabricated token balance, source role change or bytecode replacement is involved.
The preexisting real EOA-holder funding impersonation is not source-share
infrastructure impersonation or the acquisition authority proof.

| Signed independent acquisition | Actual transaction |
| --- | --- |
| DTF approval, nonce 0 | `0x9b09d4da336f648fc60ecc6836395b9c9f9e21c50807baa8fadf4120b8c15edd` |
| Source deposit, nonce 1 | `0x89e058637c503c4364aa570c3878943538d8b04e1b3de89168f8ea274e325aeb` |

Independent reconstruction of each signed transaction from the public
controlled-wallet derivation and exact nonce/data/gas parameters reproduces its
actual hash and recovers that wallet as signer. Raw status-1 deposit receipt
logs independently decode the wallet-to-source DTF payment, zero-address share
mint and Deposit event. These deterministic nonce-0/1 transactions reproduce
the producer's hashes on the fresh fork; matching hashes alone were not used
as evidence of independence. The separate command/run records, raw receipts,
new snapshot and later differing surrender/recovery transactions bind this run.

## 3. Source, runtime and executed coverage binding

Here M is `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/`.
All named tests below passed in the independent full-suite logs.
`coverage.json` lists every executed test, not sampled pass flags.

| Requirement / source | Actual coverage and receipt binding |
| --- | --- |
| M/UniswapV4DetfMigrationAllocationTarget.sol:242-275 | Fixed chain/source, original wallet/origin/Q0/evidence and both known components; frozen C0, replacement and replay without issuance. All seven MigrationDtfCustodySeConfigurationTest specs pass, including bad-second-row rollback and current/pending/former owner checks. Two actual configuration receipts and independently recomputed full ABI hash are in runtime-index.json. |
| M/UniswapV4DetfMigrationAllocationTarget.sol:55-275 | Both-direction canonical-origin rejection versus independent configured/issued compensation, either NFT family, WD and WY, including wallet correction/backing alias. Configuration tests sameCanonicalOriginCannotBeNftOrIndependentInEitherDirection, canonicalCollisionWithWdAndEarlierNftSurvivesWalletCorrection and canonicalOriginCannotBeSyOrBackingAliasInEitherDirection pass. This is known-key collision protection, not global semantic disjointness of opaque origins. |
| M/UniswapV4DetfMigrationTarget.sol:192-247; Repo._fundBond:71-81 | Stage2-only original-wallet exact approved pull, remaining C/Q mulDiv and final residue, book only q, one exact-funded fresh cliff bond. All six MigrationDtfCustodySeTest forks pass: partial/final, Stage1 configured/missing, wallet away/back, missing/amount/minimum/deadline/allowance/balance, zero-credit dust and real contract-wallet acquisition/rejecting-bond callback rollback. Independently decoded share, mint/stake and bond logs bind bonds 16/17 below. |
| M/legacy/MigrationLegacyRecoveryLib.sol:111-128 | Fixed own-share redeem, selected booked debit, exact burn and positive measured output equal returned assets/minimum. Recovery fork selectedNative28BurnUsesActualOutputAndNeverRepricesCredit changes source value by actual asset donation and proves frozen credit unchanged; no historical output is pinned as a future quote. |
| M/UniswapV4DetfMigrationRecoveryTarget.sol:33-90 | Current-owner selected stages, output minimum, zero/overbooked quantity, bad tokenId, full selected-batch rollback, later failure preserving prior committed receipts and fixed donation. All four new recovery forks pass, including mixed NFT/WD/WY inventory. Runtime-index.json binds both exact burn/output and donation receipts plus six mined recovery failures. |
| RecoveryForkBase._protected:82-95; MigrationPolicy budgets | Actual protected hash covers bond/owner, supply/backing/staking state, bond/staking-SY gons, raw-SY and parent DETF, bootstrap supply and donation inventories. Mixed-source test separately checks NFT progress, WD 20, WY 30 booked/37 held and attributed gons. Seven unsolicited W-SD shares, unsolicited DTF, residual/donor budgets and funded backing stay protected. CLI protects its separate actual DTF floor; its donationBudget is 0, not mislabeled the fork's nonzero donor budget. |
| AllocationTarget:278-308; retained Facet declaration | Paid owner-first bond remains required. All nine interface-derived selectors have actual removal events, including new loader 0x9ade58a9; real proxy declaration/restoration tests pass. Permanent surrender/queries and current-owner recovery remain installed. |
| Existing typed operator and both actual Foundry stages | Fixed W-SD category, complete wallet/Q0/component ABI/config identity, raw-proof/domain/origin partition, integer native units, actual Stage1 replacement and removed-loader failure match Solidity. Three new W-SD operator tests and all prior tests pass. Actual CLI resumes all three interruption types without duplicate donation/issuance/purchase. |

Eleven W-SD missing-record/wrong-wallet/Stage1/exhaustion/removed-loader
negative receipts independently have status 0 and no logs in
`negative-receipts.json`. Six recovery minimum/batch/later-overdraw receipts
also have status 0 and no logs; their exact hashes and raw receipts are in
`runtime-index.json`. Reviewed execution assertions compare complete relevant
pre/post state; no negative is called a no-effects proof merely from an error
string. The rejecting contract-wallet fork reaches actual fresh-bond delivery
and proves share/allowance/inventory, credit, supply/backing/gons and bond
rollback, then succeeds when its receiver accepts.

## 4. Actual independent economics and retained routes

Migration proxy: `0xedf7d9f65b9e57d62a3c4278223170db1308f5f0`.
Funded frozen snapshot: `0xc52f810e4f15a666b619f4e4500eac41d512b7cb1e6a2103038ab2ae398c954b`.
Final W-SD configuration: `0x493f0a963f98de962955a25e71f45a786919a746dc9ee484fde6b970d1dcfb8a`.

**Configured original amounts are synthetic, not operational historical
allocations.** Actual acquisition is real source execution, but its configured
compensation basis is deliberately replaced in Stage1 with Q0=1e28-7, known
ETH 0 and DTF 0.6e18. It is not derived from live holdings/rate. C0=277328729
native new-DETF units; configuration alone mints nothing. Seven shares become
an actual unsolicited-custody witness.

| Surrender | Native W-SD q | Credit / bond | Remaining Q / C | Actual start / duration |
| --- | ---: | --- | --- | --- |
| Partial | 3333333333333333333333333331 | 92442909 /16 | 6666666666666666666666666662 /184885820 | 1825762567 /7776000 |
| Final | 6666666666666666666666666662 | 184885820 /17 | 0 /0 | 1825848982 /7776000 |

Partial surrender:
`0xa3af4f42a5acaa01a7e1b39e3fb94e6cc6ff5fe4ff40b190e4223840bd8f25e9`.
Final surrender:
`0xf7622a490bc6595a8d674aa41d871ee8dd05773c59b43ef97cc798981ced9708`.
Independent integer arithmetic yields floor(C0*q/Q0)=92442909 and final
184885820, summing exactly to C0. Raw migration, share transfer, new-DETF
mint/funding, Staked and MigrationPositionCreated events agree. Actual funded
gons are 39978112030692076788462088785436529383762278 and
79870001027932629052503172863810452403245160. Bond starts equal receipt block
timestamps; each unlock is its own start+7776000. These are simulated local
timestamps, not public issuance dates.

| Recovery | Actual DTF received | DTF donated | Protected unbooked shares |
| --- | ---: | ---: | ---: |
| Partial | 333333333333333333 | 166666666666666666 | 7 |
| Final | 666666666666666666 | 333333333333333333 | 7 |

Redemptions:
`0x804698dcc3f1d2198b576b3f2694269de0c82757bf7a2cd9c45816a993ebbefc`
and `0x7ac1096b42089064290d753a4695420dadde603af38be7c2d27df1ea071451cc`.
Donations:
`0xea14c7b2214eab83591785ad8c4ce3cf92aa9bfadac5fe4ad73e707a7a2feb55`
and `0x0584776ac174e7ca2213cc74990a17403d1003bd0e35c03a585662de13da5c2a`.
Raw own-share Withdraw, share burns, source-to-Migration DTF transfers and
MigrationRecoveryConverted logs reconcile; own-share allowance is 0. Measured
output is recovery only, not compensation or another bond. Later failures
leave earlier receipts committed; donation keeps the existing fixed new-DETF
route and backing/inventory floors.

### Owner purchase, activation and prior paths

Independent compensation alone fails activation with no effects at
`0x303448293c42a11088617c715d35a42fe3834e3edc8444958d42c907979a3842`.
The paid owner-first ordinary purchase is bond 6,
`0xb58596f32f8f009b91e0e334ae4befcab44bf073a4defdab234d4229acc25a5a`:
actual payment 1e18, principal 465583908, funded rewards 84489332 and backing
1383 -> 550074623. It retains ordinary purchased-bond terms, not migration-cliff
or synthetic participation-seed semantics. Actual duplicate-purchase and Stage1
reward/fee failures remain mined negatives. Owner/pending/former/nonowner,
contract-owner callback, short-receipt and failed-purchase rollback specs pass.

Activation `0x6b1c61ddf810cc95ff31e91743fe16f74e91b4a67bdd988dcfc6bc4a98d3c7f7`
removes the exact nine-selector set independently derived from the actual
Allocation ABI. All 11 actual NFT/W-L/WY/W-SD surrenders are strictly after
activation. Nonowner ordinary deposit subsequently returns 462096413 with
zero refund, preserving the actual D1 sequence rather than hiding it with
unrelated compensation.

Prior W-L partial/final remain bonds 7/13 and credits 924869/1849739; weighted
NFT 4, returned NFT 26, earlier NFT 3, late weighted NFT 6 and earlier NFT 9 remain
bonds 8-12 with credits 13872781, 22233172691, 923391925, 36992599, 46243. WY
partial/final remain bonds 14/15 and credits 924640/1849968. Their actual raw
receipt hashes/events and recovery observations are retained in runtime-index.
Earlier sale-and-hold is not promoted to liquidation. The fourth independent
recipient remains unissued. Prior attributed-growth, terminal-NFT and unbooked
full-account-gon/fractional-retirement protections pass in the full suites.

### Three actual mined-before-checkpoint resumes

| Operation | Nonce | Independent actual transaction |
| --- | ---: | --- |
| Donation | 2120 | `0xd946514847276fe171be81324f275a49157732a476e0bf0746020e3c339b3218` |
| Independent issuance | 2135 | `0x8f6f67ea987a061fb21dd810bf4fd28f0488fd0fa37ffe84208d7cae982b3492` |
| Owner purchase | 2152 | `0xb58596f32f8f009b91e0e334ae4befcab44bf073a4defdab234d4229acc25a5a` |

For each, the saved interrupted record has a successful mined receipt and no
completion marker. Independent signed-intent decoding reproduces its hash,
nonce and signer. All **15 canonical raw receipt fields** independently match
the resumed journal, without trusting sameCanonicalReceipt flags. Actual
fresh-process records show three SIGKILL interruptions, read-only resumes,
execution resumes, repeated owner-purchase reconciliation and outstanding-row
reordering. There are 203 fixture receipts, 45 successful operator receipts and
47 command records: 38 successes, 6 controlled domain rejections and 3 intentional
interruptions. Seventy-seven mined fixture failures are expected negative
witnesses, not failed final acceptance checks.

## 5. Independently executed checks

All six required top-level commands exited **0**. Exact full commands, all
nine actual changed production roots and monitor identities are in
`checks.json`. Artifact preparation preceded each full suite and operator
execution; source/test paths, compiler profiles and provider were unchanged.

| Check | Independent result | Evidence |
| --- | --- | --- |
| Artifact-first complete current Migration specs | 122 passed; 0 failed/skipped, 21 suites | specs.log |
| Artifact-first complete current pinned Migration forks | 71 passed; 0 failed/skipped, 14 suites | forks.log |
| Actual changed-root artifact prep and both Foundry stages | Exit 0 | operator-artifacts.log;operator-stages.log |
| Five operator test files, one invocation | 62 passed; 0 failed | operator-tests.log |
| Strict TypeScript | Exit 0; empty diagnostic output | operator-types-final.log |
| Real pinned18565 CLI | bounded-rehearsal-complete;exit 0 | rehearsal-final.log;rehearsal-1794441946023/ |

Executed Forge is 1.9.1-nightly commit 430523103f3e2f9ba432ffdd2031a9f966153d0d;
all compiling commands select Solar and stage build reports 0.8.38. Executed
Bun is 1.4.2. Existing compiler/nightly/unknown-fmt-key warnings remain visible.
Independent Solidity LSP checks on configuration, surrender and recovery
Targets report no diagnostics. JSON Biome is unavailable; no install or
configuration change was made. Evidence JSON is generated by serialization.

The producer's initial 121/122 selector-control failure and initial CLI failure
are retained historical attempts, not accepted final results. The final
sequencing fix moves actual acquisition after environment funding setup;
it preserves the existing 10000-DTF setup assertion and actual asset payment.
This verifier ran only the fixed final candidate and succeeded. No test,
funding assertion, source role or provider was weakened to get a pass.

## 6. Final raw artifact, metadata and runtime reconciliation

All 34 candidate source files remain byte-identical to admission/final producer
snapshots. All 706 distinct current compiled metadata source keccak256 values
match actual bytes, and compilation targets are recorded per artifact.
All 120 raw artifacts matched producer hashes at admission. Independent builds
regenerated exactly one test artifact:

- `out/MigrationNftConfiguration.t.sol/MigrationNftConfigurationTest.json`:
  admitted `a333899524467f478b78168fa79bb29600066910cb652eceec20f60bfe0d9e3c`;
  rebuilt `99ce5bd22525c8acad1b84c632a7bc50e7bb958a3d8d5b212a421dce27a9a2e5`.

This is a **recorded raw JSON difference**, not an unchanged-artifact claim.
The producer did not retain its complete old raw test JSON, so field-level
old/new equivalence is not asserted. The current test artifact's source
metadata/target match accepted source, its complete suite passes, and no
production artifact changed. All 120 independently captured pre-CLI hashes
remain identical after the CLI. All other 562 producer raw bindings still
match at close. The prior weighted-SY commit audit's separate unretained
historical aggregate-inventory qualification remains historical and is not
promoted to a stronger preservation assertion here.

All 31 actual captured parent/package/child runtime byte arrays hash correctly.
Eleven Migration artifact/runtime comparisons independently match, masking
only actual compiler-declared link/immutable spans and retaining every observed
span value. This includes all changed permanent/allocation/recovery facets;
recovery has no masked spans. Package comparison includes its declared
immutable spans; generic captures are hash-bound, not independently claimed
artifact-byte-identical. `artifact-reconciliation.json` retains all per-path
metadata/raw hash/runtime span comparisons and closing admission checks.

| Actual changed facet | Deployed address | Runtime keccak256 |
| --- | --- | --- |
| Permanent | `0xcd29f772d1c9dbdbafdb0e54504160a5a977c0e8` | `0x6e2d81b2fad36dd05afa173447c29d18159bed06e71ef8d3af18bed9f59e19bd` |
| Removable allocation | `0x0a69db3b30b7cb13eaff786832e062d157630bb2` | `0xb89b4e15fc81d357f18684782c809e5eb0908fcffb04ee2e320bc42458a4d246` |
| Retained recovery | `0x2f0c891b4e9a1c9833dd3f7814d1a76f684797e9` | `0x04207575f68e1ac44ec4d373185b375a21bdfb9c4614d4a4a94840c55a042569` |

`bindings.json` binds every owned raw evidence/witness file; `seal.sha256`
seals report and manifests without recursive self-hashing. Source-authority,
artifact-reconciliation, runtime-index and negative-receipts supply exact
source/runtime/input/receipt bindings, rather than inherited pass labels.

## 7. Cleanup and bounded limits

The actual CLI closed providers/subscriptions, stopped holder impersonations,
copied raw journals, stopped owned Anvil PID 2461 and removed the fixed
checkpoint. External port 18565 lsof and PID ps probes returned exit 1 with empty
output; checkpoint absence, empty owned-runtime-parent removal and whitespace
checks returned 0. All six execution monitors exited 0. The report-creation
watch completed; the no-longer-needed root RPC watch was explicitly killed.
`cleanup.json` records these receipts. **No owned pending runtime remains.**

Only `migration/dtf-custody-se/verification/` evidence was authored. The
candidate's 34 source files remain unchanged; index is empty and exact base/
branch retained. Shared warm artifacts/caches and prescribed dependency links
remain. Runtime execution may refresh ignored build/broadcast/cache outputs;
none was committed or copied into main. No ordinary/common/Crane production,
dependency/configuration, producer/historical evidence, held09 inspection/
import/replay, source-governance operation, provider bypass, public operation,
commit or merge occurred.

Other source categories remain required with the phase11 matrix's original
record/unit/caller/disabled-exit limitations. W-SD does not establish W-SW,
earlier SE, owner-restricted LP, raw weight/receipt or full-category support.
No approved operational original-wallet/origin/Q0/component dataset is
supplied; synthetic fixture amounts are not approved historical awards.
Opaque economic origins still require operational partition reconciliation.
No unchanged ordinary/common full shared-suite or full-hermetic-monorepo gate
was run or claimed: this increment changes no such production input.

Actual independent local parent deployment
`0xa5453ead9be6d27ebd0a46e50f834fb7bd4b9eb2c22a6dd8885223cc9f5f525e`
uses **43770976 gas**, above the retained historical 32000000 transaction limit,
on the permitted 100-million local node. This is a receipt observation only,
not target-gas feasibility or authorization for public deployment, funding,
activation or compensation execution.

**Final bounded disposition: confirmed. No production fix requested. Real
controlled acquisition, exact custody/credit/recovery, retained guards, all
required independent checks/resumes and owned-runtime cleanup are confirmed
subject to the explicit source-category, data, raw-artifact and gas limits.**

