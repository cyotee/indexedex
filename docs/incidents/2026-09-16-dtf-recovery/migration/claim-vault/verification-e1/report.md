# Independent direct claim-vault E1 verification

Date: 2026-11-12.

**Verdict: confirmed for the bounded direct-share increment under the corrected
plan-aligned E1 gate.** No blocking implementation or executed-route defect was
found. Independent execution passed 130 current Migration specs, 81 pinned
Migration forks, 64 operator tests, strict operator types, current artifact
preparation, both operator-stage builds, and a fresh fixed18566 CLI. Actual
signed acquisition, partial/final original-wallet custody and credit, funded
cliff bonds, own-share redemption, onward recovery, selected-batch rollback,
and all three mined-before-checkpoint resumes are confirmed.

Missing exact archived claim-vault implementation source remains an explicit
provenance limitation. It is neither a feature failure nor an excuse to infer
deployed semantics from current source. No portable/full-F3, operational-award,
full-category, full-plan, target-gas or public-execution acceptance is given.
No production fix is requested. No verifier-owned runtime remains.

## 1. Authority, exact candidate and preserved handoffs

Worktree:
`/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-16-claim-vault`.
Branch: `work/dtf-migration-phase-16-claim-vault`.
Unchanged HEAD/base: `4a53299b490343ed904d70c92ecbc7360fcb7659`.

The corrected main-checkout phase16 brief was read completely, along with the
actual main plan E1/E2 at lines153-159, owner-first-bond directive, phase15
independent runtime and commit reports, phase11 claims sections1/4/5/8/9 and
its independent report/matrix. The complete new producer report and actual
candidate changes were inspected. Root explicitly released the immutable
handoff and confirmed stopped source modifications and no producer runtime
before independent replay. No workflow-count acceptance was substituted.

Warm `out/` and `cache_forge/` were present. Prescribed links remained:
`lib/crane -> /Users/cyotee/Projects/indexedex/lib/crane` and
`node_modules -> /Users/cyotee/Projects/indexedex/node_modules`.
No reseed, dependency installation or configuration change was performed.

Independent closing reconciliation confirms:

| Binding | Result |
| --- | --- |
| Final producer report | SHA-256 `ee81d2c9d15f35befe95bbfe6af48152537af3d2363c4601a1bfd9a248240125` |
| Producer final tree manifest | SHA-256 `6d7c93cf9052a2fbe29c5596ccb43b81944d148cf4dc4bc7d5b289b5c3d37af1`; all541 entries match |
| Candidate code/test/operator/runbook | All40 current files match accepted hashes and byte-exact final snapshots |
| Corrected brief | `d891944faa7c106ad340d89466340d4f70e8b1cb28d77c0bddf952e4aa79a2f1` |
| Main plan r5 | `60d02b608c8a10f19cffce7b99838146c205a98410641e9bce45944e620dc56d` |
| Main PRD r22 binding | `cfe1853f49de0dc41ae106f1cc1b94eacd24d4aa8f79477c66a5b7f24a4d67ed` |
| Predecessor preservation | All9 entries in `final-sealed-preservation.json` unchanged |

`binding-audit.json` retains every recomputed entry. The original sealed
`implementation/report.md` and `verification/report.md` correctly record
no support at their earlier handoff under the former archive gate. Neither
report, its evidence, nor its historical conclusion was overwritten or
relabeled. This is a new, disjoint verification.

## 2. Pinned source identity and independently executed acquisition

| Observation | Actual independent result |
| --- | --- |
| Chain / pinned block | 4663 /108944663 |
| Pinned block hash | `0xc497433dd691a40cb85959cfeba2e3fff85a975ae060612d984998e1d5765733` |
| Direct-share vault | `0xaf5c0cd3fdedd10bee00eff77fa0429bacdb41f0`, native19 shares |
| Underlying | `0xb55604cf4dcdabb362078e106d20f98512391edf`, native9 static WY/SY |
| Proxy runtime keccak256 | `0x2393ee3dc4d7877a9bfb7b59c272f2b9b0d1df92f2dc82ee67df076a99836601` |
| Deposit / redeem facet | `0x517234f78a4bcafc5f880024a3e45d49cf43b305` |
| Actual facet runtime keccak256 | `0x8c1ea71d607b09b21c4e78f850647a059dc7935b6772f7cd3aeaa700a995439f` |
| Executed deposit layout | `deposit(uint256,address) -> uint256`, `0x6e553f65` |
| Executed redemption layout | `redeem(uint256,address,address) -> uint256`, `0xba087652` |

The owned isolated `route-proof/` replay starts controlled development wallet
`0xd96eb0f2e106ea7c0a939e9c460a17ace65fecff`, derivation105, with zero SY and
shares. Real SY funding comes from existing EOA
`0x11c17f25e958e4637dd26ca362adeae12e24ed5b`. Only that local funding sender
is impersonated, with native gas funding. There is no token-balance, source
storage, role, code or share-custody fabrication.

The wallet signs approval and deposit itself. Deposit
`0x75a42abb8cf4bef4027d8c9c6d658d0ab8147c70f9e9d116631aad75a2a2dddf`
pays3000 native SY and mints29999999967592 native shares. Independent decoding
reconciles the payer debit, source SY increase, share supply increase,
zero-address mint, Deposit event and exact single-word return.

Own-share redemption
`0xacaf2f5ed71aeb20a0865794bde66c49b49ea44fd6a07e7a4d4cb96c24403975`
burns that exact quantity and pays2999 native SY. Its return, source debit,
wallet credit, burn and Withdraw logs agree. No self-approval is required.
The historical share/SY ratio is not used as a universal price.

The isolated replay also executes missing-underlying-approval, over-balance,
zero-recipient and unauthorized-third-party redemption failures, with
unchanged recorded economic state and no logs. A separate deposit recipient
receives actual minted shares without crediting the payer's share balance;
that recipient can redeem its own acquired custody.
**Zero-share source redemption succeeds with a zero return at this pin.**
Migration's positive-selection/output requirements therefore remain its own
enforced checks, not an invented legacy-source promise.

The fresh integrated CLI independently repeats signed acquisition:
approval `0xeb4aa9a428d7f3816718a901f4292e3ee27b958434d1df22bd07b323139f1caa`,
deposit `0xa458cd3d4a1464d8954685d28fc75246f38fab013d717c09928c75e8a10b2c51`.
Reconstruction with actual nonce/data/gas parameters reproduces both hashes
and recovers the controlled wallet. Deterministically matching producer
acquisition hashes are not, by themselves, the independence proof: the
separate fresh execution, later differing receipts and owned witnesses are.

### Repository history is provenance, not source equivalence

Read-only historical inspection confirms commit
`b9e074cfcd12c39e0671ff0f4b658b97c5e4da68` records the exact facet and package
`0xaD70Af09fd9CEDe7575BDf2b16a5e4A7f7465040` in
`deployments/anvil_robinhood_main/phase06_stage08_token_staking_pkg.json`.
Its historical Facet/Target/Common/Repo/DFPkg/Component family was inspected.

Commit `799f28e5fd693821d8ba06aae68ab986b6a723f0` records the claim-vault,
TokenStaking and adapter in
`deployments/robinhood_main_fee_accrual/composition/phase08_stage07_staking_migration_state.json`.
Historical `_wrapClaim`, `withdrawClaim` and `TokenStakingMigrationAdapter`
were inspected. `0xC84999F31eA72A793a65ce73aa05ff624FDCBB51` is the adapter,
not canonical DETF; its compatibility getter names static staking SY.
TokenStaking-owned backing and user weight rights are not direct user shares.

No snapshot was recompiled into an asserted exact deployed match. For example,
the inspected b9 Common rejects zero-share redemption, whereas the pinned
execution above accepts it. Historical/current source-family familiarity
cannot replace the actual runtime and execution proof. No IPFS/Kubo,
compiler-metadata retrieval, provider change or source installation occurred.

## 3. Actual coverage and source/runtime/receipt bindings

Here M is `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/`.
`checks.json:coverage` lists all130 spec,81 fork and64 operator test names
and their actual independent log lines, not sampled pass labels.

| Requirement / source | Independently executed evidence |
| --- | --- |
| `M/UniswapV4DetfMigrationClaimVaultAllocationTarget.sol:21-57` | Eight configuration specs prove fixed chain/source, explicit wallet/origin/Q0/known components/evidence, full/idempotent replacement, frozen quote and no issuance. Current/pending/former-owner and bad-second-row rollback cases pass. |
| `M/UniswapV4DetfMigrationAllocationTarget.sol:79-281`, separate loader | Both-direction canonical-origin conflicts against configured/issued independent compensation, both NFT families, WD, WY and W-SD pass, including wallet correction. These are known-origin guards, not semantic proof that arbitrary opaque aliases are disjoint. |
| `M/UniswapV4DetfMigrationRecoveryTarget.sol:77-142`; `Repo._fundBond` | Six direct-share forks prove Stage2 original caller, actual approved exact debit/receipt, partial/final C/Q, zero-credit rejection, one exact-funded fresh90-day bond, missing record, transfer away/back, deadline/minimum/quantity/allowance/balance negatives. The real contract-wallet acquisition and rejecting NFT receiver prove pull/funding/bond/callback rollback, followed by success and failed reentry. |
| `M/legacy/MigrationLegacyRecoveryLib.sol:131-154` | Four direct-share recovery forks prove fixed `redeem(q,MIG,MIG)`, selected booked debit, exact share/supply burn, positive measured SY equal return/source debit/minimum, actual source rounding and source-rate change without credit repricing. |
| Recovery stage10 and existing stages8/3/4/7 | Actual CLI partial/final share burn -> SY -> WS gons -> WD -> DTF -> fixed reserve donation. Minimum and whole-selected-batch failures revert; later failed transactions preserve earlier committed recovery. |
| Recovery mixed-inventory case and existing policy budgets | Real NFT recovery, WD20 booked, WY30 booked/37 held, attributed gons and DTF inventory remain separate. Seven unbooked vault shares, unbooked SY/gon fractions/DTF, residual/donation budgets and funded new backing remain protected. The fork has a nonzero one-DTF donor budget; the CLI's later direct-share rows have budget0. |
| Actual package and retained/removable facet surfaces | Real registered deployment, all facets/children EIP170 checks, declaration consistency, permanent reads/surrender/recovery and irreversible ten-selector removal/restoration negatives pass. Exact runtime bindings are below. |
| Preserved base behavior | Complete suites and CLI retain both NFT families, WD, WY, W-SD, attributed-growth/fraction protection, source negatives, genuine paid owner-first purchase, activation prerequisite and Stage1 reward/fee/callback guards. No raw-weight substitution or ordinary/common/Crane production change is included. |

The CLI's before/after assertions measure allowance, wallet/proxy custody,
configuration/remaining credit, inventory, supply, backing, staking state and
bond ownership. Mined negative status0/no-log checks are independently
reconciled in `receipt-audit.json`; an error string alone is not treated as
proof of no effects.

## 4. Fresh original-wallet economics and recovery

Independent run: `cli-run/rehearsal-1794449113009/`.
Migration: `0xedf7d9f65b9e57d62a3c4278223170db1308f5f0`.
Configuration: `0x640c598cae940c9f6a0d9b57b4abe9035efd02c5ebd0916732c7dd31e6b61095`.

Originals are explicitly **synthetic**: known ETH0, original DTF0.6e18 and
Q0=29999999967585 native shares after Stage1 replacement. C0=277328729 native9
new DETF. Seven actual acquired shares remain outside booked entitlement.
These inputs are not inferred from live rates and are not operational awards.

| Actual independent operation | Partial | Final |
| --- | ---: | ---: |
| Native19 q | 9999999989195 | 19999999978390 |
| Native9 frozen credit | 92442909 | 184885820 |
| Bond ID | 18 | 19 |
| Local simulated start | 1825849012 | 1825935430 |
| Cliff duration seconds | 7776000 | 7776000 |
| Exact funded gons | 39935000081969955757728240225564616284591342 | 79784358935368957278151328676364117057057480 |
| Native9 SY recovery | 999 | 2000 |
| Native9 WS/WD conversion | 1284 | 2573 |
| Native18 DTF recovered/donated | 6884417060245978 | 13795799259981483 |

Independent integer arithmetic confirms floor(C0*q1/Q0)=92442909, exact final
credit residue184885820 and final remaining Q/C=0/0. Bond starts match their
actual receipt blocks; these are simulated fork times, not public dates.
Share transfer, mint/funding, bond and recovery logs bind the observations.

| Receipt | Partial | Final |
| --- | --- | --- |
| Surrender | `0x3acdf3bac9f13837af31e753146570ee669f61ab5d75321d678c425af9164721` | `0x9468e69e0f5f2e7a075c2cb77763f40339427a441fb415a0177ff82052c93c5b` |
| Own-share redemption | `0x79099904ea64604699d7d40f7930bed47b72293acf836dbd23a83301cd85d3f6` | `0xe072b7c28e980baf3dd52a6d13b6fa193a1253e67a133361aa25c9a8f6b662e2` |
| Fixed donation | `0x775aae9e1d2cbe0a92c04e54b741c902e133011022a3b5ac8262696d726fe652` | `0x6e2ea4903809d4bf7556294cf5d71d5ea963e743382484307168d29c089c01e7` |

`claim-vault-stage1.json`, `claim-vault-partial.json`, `claim-vault-final.json`,
`fixture-receipts.json` and copied journals retain raw execution evidence.
`receipt-audit.json` binds decoded receipts; `reviewed-summary.json` retains
the independently checked native arithmetic, source logs and snapshot equality.
The seven unsolicited shares and own-share allowance0 remain protected.
Measured recovery creates no second personal credit or ordinary bond.

## 5. Removable allocation facet, real cut and current artifact metadata

The new loader is deployed through existing artifact-backed Components and
the registered Migration package, not a directly constructed substitute.
`TestBase_UniswapV4DetfMigration.sol:248-267` passes the new facet through
interface-owned PkgInit; `DFPkg.facetAddresses/facetCuts` includes it.
The actual package runtime's declared immutable span at byte9113 contains
`0x550fbe01f291cdd4672eda3db21aaec73d854dae`, the bound new facet.

| Actual facet | Address | Runtime bytes |
| --- | --- | ---: |
| Permanent Migration | `0xcd29f772d1c9dbdbafdb0e54504160a5a977c0e8` | 24408 |
| Existing allocation | `0x0a69db3b30b7cb13eaff786832e062d157630bb2` | 24310 |
| New claim-vault allocation | `0x550fbe01f291cdd4672eda3db21aaec73d854dae` | 7002 |
| Retained recovery | `0x2f0c891b4e9a1c9833dd3f7814d1a76f684797e9` | 17077 |

Actual activation
`0x0db12d952e4baa125adc0aca8bb4ae045079e9a5d3f41d57880a36bb3a2549d5`
emits the following exact `DiamondFunctionRemoved` set. It was compared with
the actual Allocation ABI, not accepted from a count:

| Removed method | Selector | Owning removable facet |
| --- | --- | --- |
| bootstrapMigrationReserve | `0xec55c474` | Existing allocation |
| captureMigrationSnapshot | `0x161d9afc` | Existing allocation |
| configureIndependentAllocations | `0xccff9894` | Existing allocation |
| issueIndependentAllocations | `0x787642e8` | Existing allocation |
| activateMigration | `0xe9dc9e6d` | Existing allocation |
| configureNftEntitlements | `0x12076202` | Existing allocation |
| configureWeightedLiquidEntitlements | `0x256c417b` | Existing allocation |
| configureWeightedSyEntitlements | `0x74d1295f` | Existing allocation |
| configureDtfCustodySeEntitlements | `0x9ade58a9` | Existing allocation |
| configureClaimVaultEntitlements | `0xe11315e2` | New claim-vault allocation |

All seven producer-bound raw production/stage artifacts remain identical after
independent execution. Ten current artifacts, including the three new test
contracts, were metadata-audited:628 distinct compiled-source keccak256 values
match actual current source. Targets and compiler
`0.8.38+commit.e7a91fc7.solar.0.3.0-dev` are retained.
All20 captured runtime byte arrays hash correctly.

Five actual artifact/runtime comparisons match, masking only compiler-declared
link/immutable spans and retaining every observed span value. Recovery has no
masked span; its actual runtime hash is
`0xc0ca13b7e9d7eb488cd8a2eab5c0aa631feaac17f18d31181dcdcba2a51cef9d`.
The new allocation's actual linked runtime hash is
`0x1baf3f6df765aa47c65c37e54fbe275a6a63cf3485d13b5089cd2c8fe3380fc3`.
Unlinked templates are not mislabeled deployed runtime. Script/test code sizes
are not facet EIP170 claims. Full package/child size checks pass on real instances.

## 6. Three actual interruption resumes and executed checks

| Interrupted operation | Nonce | Independently decoded canonical transaction |
| --- | ---: | --- |
| Donation | 2123 | `0x5b17d1e14671ab202b71ae48b6ec5402f36588bcf1f107b37cea602beca44b02` |
| Independent issuance | 2139 | `0x0a2f1e4bdd6d7a62ebec64feae5621e40e669f6d338fd86bd665ea92179ee7f6` |
| Paid owner-first bond | 2157 | `0xf5259aa029db69dc5ad451d7650994eef9fcdc3fa7694516d6572e5278871497` |

For each, the raw interrupted intent is signed, mined and recorded before its
completion checkpoint. Independent decoding verifies signature recovery to
`0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266`, chain4663, hash, nonce, target,
value and calldata, then compares all15 canonical raw receipt fields with the
resumed journal, including complete logs. `sameCanonicalReceipt` flags are
not the evidence. All47 successful signed journal completions were checked.
The CLI retains actual SIGKILL/fresh-process resumes, unsettled-row reorder,
unissued fourth recipient, purchase reconciliation and no duplicate execution.
Its249 fixture receipts include deliberate negative transactions.

The paid owner-first bond remains ID6, with actual payment and funded ordinary
purchase terms. Activation rejects before that purchase; independent
compensation alone does not satisfy it. Snapshot and all10 admin bindings remain
unchanged through purchase, Stage1 duplicate/reward/fee routes reject, and
activation precedes all successful source surrenders and the real ordinary
deposit. This retains the corrected D1 behavior rather than hiding it.

| Required independent check | Result |
| --- | --- |
| Artifact-first complete current Migration specs | 130 passed,0 failed/skipped,22 suites; exit0 |
| Artifact-first complete pinned Migration forks | 81 passed,0 failed/skipped,16 suites; exit0 |
| All six operator test files, one invocation | 64 passed,0 failed; exit0 |
| Strict operator types plus producer evidence scripts | exit0 |
| Current changed-root artifact preparation | exit0 |
| Both actual operator-stage builds | exit0 |
| Fresh fixed18566 CLI and three mined resumes | bounded-rehearsal-complete; exit0 |
| Independent signature/log/arithmetic/binding audits and witness types | exit0 |

Exact commands and test names are in `checks.json`; logs are owned here.
All compiling Forge operations use Solar; artifact preparation precedes tests
and operator execution. Existing compiler/nightly/unknown-fmt-key warnings
remain visible. Solidity LSP reports no errors for the new allocation Target
and retained Recovery Target. One owned TypeScript LSP freshness request timed
out; strict compiler checks passed. JSON Biome is absent; generated evidence
is parsed instead, with no installation/configuration change.

The first owned receipt decoder failed on ERC20/ERC721 Transfer events sharing
a topic but differing indexed layouts. That audit failure is retained in
`receipt-audit.log`; it was corrected by checking the actual indexed layout,
then the final audit passed. No production or test assertion was changed.
No failed required product check was waived.

## 7. Host dependency, gas observation and cleanup

This is a **bounded workstation-local rehearsal**, not portable/full-F3
acceptance. Existing authority paths and
`rehearsal-process.ts:8` already bind this workstation's Foundry installation.
The newly pointed W-SD archive input at `rehearsal-data.ts:60-68` is:

`/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-15-dtf-custody-se/docs/incidents/2026-09-16-dtf-recovery/migration/dtf-custody-se/implementation/source-archive.json`

Its actual1,047,506 bytes hash to
`600c072adccc5e624333fd3dfd511787a3d89868193b320efdb8cbfc912483e7`.
The fresh CLI manifest and independent closing audit bind it. This input
must be preserved or deliberately relocated with updated bindings before
later phase15-worktree cleanup. It was not deleted or changed here.
No actual blocking scope violation was found; portability is explicitly not
claimed and no production rewrite is proposed by this verification.

Current parent deployment receipt
`0x164e3d434eb60cadf95d1e33baeb9b681fe482964e4fb05d29f8a2e8f448d533`
uses **44,099,850 gas**. This is the actual new integrated-replay receipt,
not a rerun gas experiment, estimate or borrowed phase15 value. It exceeds
the retained historical32,000,000 transaction limit on the permitted
100-million local node. Target deployment feasibility remains unaccepted.

The isolated route node PID57230 and fresh CLI node PID57324 exited.
Actual ps queries return1/empty output; port18566 lsof returns1/empty output.
The fixed `.omo-runtime/dtf-migration-claim-vault/checkpoints` is absent.
Providers/subscriptions closed; funding impersonation stopped; journals and
receipts are retained. Every owned execution monitor finished. Whitespace
validation passed, the index remains empty, and HEAD/base is unchanged.
`cleanup.json` records these observations; `seal.json` binds the complete
owned evidence tree, excluding only its own self-reference.

Only this `verification-e1/` evidence/witness directory was authored. Ignored
build/cache/broadcast outputs may refresh from required local execution; they
were not committed or copied into main. Producer seals/snapshots, predecessor
reports, linked dependencies and the phase15 archive are preserved.
No held09 inspection/import/replay, public action, provider bypass,
source fabrication, ordinary/common/Crane production edit, commit or merge
occurred.

Other receipt/raw-weight/earlier-liquid/blocked-SE/LP categories, approved
original-wallet/origin/Q0/component datasets, opaque-origin reconciliation,
full hermetic/full-plan completion and launch feasibility remain separate.
**Final bounded disposition: confirmed. Verification and cleanup are complete.**
