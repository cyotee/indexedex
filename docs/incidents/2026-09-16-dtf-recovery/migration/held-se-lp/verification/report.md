# Independent three-source stopped candidate verification

Date: 2026-11-12. **Disposition: confirmed for bounded W-SW, E-P and W-P
original-wallet native18 custody and frozen credit.** Blocking candidate
findings: none. **E-S remains unsupported; all three new conversion routes
remain blocked.** The LP acquisition fixture is external-EOA-owner-release
and personal-donation dependent, not claimant or Migration-owner authority.

This verifies the actual completed, stopped candidate. It does not grant
immutable-delivery, full-plan, liquidation, operational-allocation, target-gas
or public acceptance, and authorizes no implementation fix, commit or merge.

## 1. Exact subject and authority

All execution and owned writes used
`/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-21-held-se-lp`,
branch `work/dtf-migration-phase-21-held-se-lp`, unchanged audited HEAD
`3ec0912bafebf9c0aa66770a72f04501e5c11865`. Writes are confined to this
`verification/` tree, except expected ignored build/runtime outputs of the
explicitly required checks. The temporary runtime was removed. No source fix
or producer evidence edit occurred.

Read the complete phase21 admitted-three-source brief, both complete phase20
source/funding briefs, current main plan r5 and PRD r22, the four actual
qualified source contracts/admissions, and complete ED source producer,
source verifier, implementation, runtime verifier, commit receipt and
independent immutable-delivery reports. Current plan sections 1.3-1.5 and
5.1-5.4 govern original-wallet eligibility, Stage2-only surrender, the real
paid owner-first bond, irreversible activation and original-credit recurrence.
Older transferable-compensation, ancestry, preactivation and partly consumed
amendment wording is not restored.

| Actual phase20 input | Raw bytes | Independently checked SHA-256 |
| --- | ---: | --- |
| `source/contract.md` | 18766 | `330c2ce3f77ad20976c27377aec832d375d7f5c615a00d16cdab66946f660df3` |
| `source-verification/report.md` | 26504 | `c1d452153e3c1483e9ed862ce8a46e55aad2cdfbaef15b94d20f15f24fddcb45` |
| `owner-funding/contract.md` | 10950 | `436baf660e440d1c12a66bc6912565f3ef7905183fc87f816959b5c4b8af7184` |
| `owner-funding-verification/report.md` | 20357 | `a8526fb709fd37c163e04a03885c601f423976c9d3baa7acdcfb413a295e2fb3` |

The actual complete producer report, seal, cleanup, source manifest and raw
witnesses exist. Independently checked all 35 frozen candidate paths,
1237 immutable earlier files, 11 authority entries, 1386 inherited ED-parent
entries and all 645 sealed producer files: 3314 binding comparisons, with no
length/hash/mode discrepancy. Producer membership is exactly those 645 files
plus its self-excluded seal. The complete tracked diff and all five added
source/test files were inspected. Eight production roots remain exclusively
Migration-specific. The initial producer PID41253 was absent and port18571
had no listener before this verifier started its own node.

No ordinary/common/Crane production, dependency/configuration, held09,
source governance/role, provider, public-action, index or ref change occurred.
Every Git read used `GIT_MASTER=1 GIT_OPTIONAL_LOCKS=0`; status/diff ignored
submodules. The staged set remains empty.

## 2. Independently executed gates

`checks.sh` is the exact login-shell recipe, including all eight edited
production roots. It performs artifact-first builds before complete tests,
then explicit builds of both concrete operator stages, strict operator types
and one final operator-test invocation. The monitor completed with exit0.

| Gate | Independent result and durable evidence |
| --- | --- |
| All eight production roots, artifact first | exit0, `build.log` |
| Complete current Migration specifications | 167 passed, 0 failed/skipped, 28 suites; `specs.log` |
| Complete current pinned Migration forks | 139 passed, 0 failed/skipped, 23 suites; `forks.log` |
| Both concrete Stage00 and Stage01 builds | exit0, `stages.log`; fresh CLI also executes Stage00 |
| Strict operator types | exit0, `types.log`, including exact optionals and unchecked indexes |
| One operator-test invocation | 88 passed, 0 failed, 10 files; `operator-tests.log` |
| Fresh pinned18571 cumulative CLI | first attempt exit0, `cli.log` |
| Read-only raw HTTP observer | exit0, `fresh-wire.ndjson`, acknowledged subscription and block backfill |
| Final strict owned-probe types | exit0, `probe-types-final.log` |
| Both-run raw/runtime/economic reconciliation | exit0, `independent-audit-pass`, `audit-final.json`; empty `audit-final.stderr.log` |
| Shell syntax, whitespace and actual cleanup | pass; `cleanup.json` |

Compiling commands use Solar
`0.8.38+commit.e7a91fc7.solar.0.3.0-dev`, optimizer enabled/runs1, no viaIR.
No size override or unlimited-size node was added. Unsuppressed Forge compiler
and lint warnings remain in the logs. Bun CLI identifies v1.4.2.

The fresh command was:

```sh
/bin/zsh -lc 'cd /Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-21-held-se-lp && export PATH=/Users/cyotee/.foundry/bin:$PATH && bun scripts/recovery/dtf-migration/cli.ts rehearse --rpc-alias robinhood_mainnet_alchemy --fork-block 108944663 --port 18571 --checkpoint .omo-runtime/dtf-migration-held-se-lp/checkpoints --evidence docs/incidents/2026-09-16-dtf-recovery/migration/held-se-lp/verification/runtime-01'
```

Fresh evidence is `runtime-01/rehearsal-1794486936891`. Source pin is
chain4663/block108944663/hash
`0xc497433dd691a40cb85959cfeba2e3fff85a975ae060612d984998e1d5765733`.
This historical source pin is not the funded frozen quote snapshot.

## 3. Every required behavioral case

Each of the following tests executes separately for W-SW, E-P and W-P through
the real registered Migration and actual source tokens, not a custody helper.
Configuration suite prefix is `MigrationHeldSeLpConfiguration.t.sol`;
fork suite prefix is `MigrationHeldSeLp.t.sol`.

| Required case | Inspected and independently executed evidence |
| --- | --- |
| Complete owner-only original record, native18 Q0, source/generation, known components, evidence and frozen C0 | `test_completeReplacementReplayAndFrozenOriginalGroupingNeverIssue`; actual original/replacement configuration transactions and frozen tuple hashes |
| Complete replacement, idempotence, no issuance; unknown versus known zero; invalid/mixed batch rollback | `test_invalidFieldsSourceChainAndOwnerRejectWholeBatch`, `test_mixedFixedSourcesQuoteOriginalsSeparatelyAndRollbackInvalidLastRow` |
| All inherited origin exclusions, independent current and issued history, wallet corrections, both NFT generations | `test_allCanonicalOriginsExcludeBothDirectionsAfterWalletCorrection`: all 12 alternatives in both directions for each source |
| All pairwise new-source exclusions in both directions | Same test includes the other two fixed sources for each of the three suites: all six ordered pairs |
| Current/pending/former owner lifecycle | Per-source invalid-owner test performs actual ownership transition; complete inherited administration/activation suites also pass |
| Real paid owner-first bond; actual permanent loader cut and retained routes | `test_paidOwnerBondActivationRemovesLoaderAndRetainsRecordsAndQueries`, complete Surface/Recovery/OwnerFirstBond suites, and actual CLI activation receipt |
| Stage1 rejection before custody, allowance, consumption or funding | `test_stageOneRejectsBeforeAllowanceCustodyConsumptionOrFunding`; three actual signed CLI Stage1 reverts |
| Missing record, wrong wallet, missing approval/control, amount/minimum/deadline | `test_absentWrongWalletApprovalBalanceAndLimitsLeaveEverythingUnspent`; independently decoded CLI failed signatures/traces |
| Transfer-away/back neither moves nor resets credit | `test_transfersDoNotMoveCreditAndReturnNeedsNoHistory`; fresh CLI signed transfers between derivations201/202 |
| Finite and maximum allowances decrement by exact q | `test_finiteAndMaximumAllowancesSpendExactNative18WithUnbookedFloor`; independent raw Approval-event reconciliation |
| Positive partial, exact terminal and retained residue; general full precision | `test_realPartialAndFinalSurrenderConservesFrozenCreditAndFreshBonds`, `test_fullPrecisionPreviewRetainsTerminalResidue`; independent integer recurrence from actual signed calldata |
| Zero-credit dust cannot confiscate source or create an empty bond | `test_zeroCreditDustRejectsWithoutConfiscation` |
| Exactly funded same-wallet fresh bond and real cliff release | `test_actualHeldBondsReleasePrincipalOnlyAtTheirFreshCliff`; partial/final tests and actual mint-parent-bond-staking Transfer/MigrationPositionCreated receipts |
| Real late child funding failure, complete source/allowance/budget rollback | `test_actualChildFundingFailureRestoresSourceAllowanceAndEveryBudget`: asserts actual receipt-child exchange call count, bounded late funding failure, full protected budget and source restoration, then successful surrender |
| Late rejecting receiver and callback reentry | `test_bondReceiverRejectionRollsBackActualPullFundingAndInventory`: actual source pull and funded child precede invalid receiver rollback; successful accepting receiver cannot reenter surrender or activation |
| Unrelated/preexisting floors, mixed new sources, positive old NFT/ED/ER/WS inventories and donor/reserve budgets | `test_threeHeldSourcesPreserveMixedNftEdErWsAndDonationInventories`; actual earlier/weighted NFT recoveries, positive ED, both ER E/B, positive WS gons, separate per-source 13-unit floors; protected budget hashes stay equal |
| E-S rejected and no generic arbitrary-token support | `test_earlierSeIsUnsupportedNotAnotherAdmittedNative18Source`, fixed-source/chain negatives, strict operator schema and payload tests |
| No new conversion/debit/donation or production collector-owner method | Full production/operator diff, unchanged recovery-stage enum, fixture-only fixed-loopback acquisition, actual supported selector census |

Source anchors inspected directly include the new loader and its shared
origin guard in `UniswapV4DetfMigrationClaimVaultAllocationTarget.sol:14-98`,
activation selector census in `UniswapV4DetfMigrationAllocationTarget.sol`,
exact pull/remaining-credit/booked-inventory path in
`UniswapV4DetfMigrationRecoveryTarget.sol:25-89`, and real funding in
`UniswapV4DetfMigrationRepo.sol:79-89`. Fixture preparation never becomes
production source authority. No caller supplies an award, live NAV or
selected unit/pricing mode. Opaque economic aliases remain operational inputs.

## 4. Actual acquisition and authority labels

The controlled original is `0x9b63f0cef479924e5d2c4e22dbe31e6d0353b448`,
public disposable derivation201. Derivation202 signs wrong-holder operations.
They are neither collector owner nor Migration owner. Their approval,
transfer and surrender payloads authenticate to their own real development
signatures. The historical component assignments are synthetic code-proof
inputs, not historical originals or approved operational awards.

Existing donor `0x72bea6fa3e68ef18c87d045aac7c4aa5249d933b` has empty
code. Collector `0x20af9a1e21a59a411cd3b0c40e70af9084770b2e` actually
reports that owner. Its pullFee selector0x45e94ee3 routes to
`0xf7a99a0aed1a4252c71c99fdd2a5b3250a41f669`, runtime hash
`0x7ae5c353c623b635938a7bb3ebc07cb3eda6469b2cd9dbf76c8bed336ff0b5cb`.
Current collector source is explanatory, not byte-identical legacy-artifact
proof. Actual deployed routing, caller, true return, canonical receipt,
Transfer event and storage deltas establish these local releases.

| Source | Actual controlled acquisition | Fresh local donor transactions |
| --- | --- | --- |
| W-SW `0x999dae02d22e5fee1c4508430d5196d31d631009` | Personal EOA holding869679629029 ->869679619009; original0 ->10020 | Personal transfer `0x543ca06ff2bf4d3bf659164a09cf268773e52f090c0bd500fbf01790fa8de421`; no collector release |
| E-P `0x923877336b14662cfb5b3a60b14e7d716d54a888` | Collector453163036817578813953732920170 ->453163036817578813953732910150; owner receives10020 then donates10020; original0 ->10020 | Owner release `0x7b6e431f64043689fdd5c61e080c36f79b82f7c9ca0e659d063674f83e9c3374`; personal transfer `0x649f55febb4d016bffe32453286287f8fcd8136c67e15457a9d121a7078d51fb` |
| W-P `0x46e068c2393e189fbc86632f67210af253a42aa8` | Collector1516646747724649142 ->1516646747724639122; owner receives10020 then donates10020; original0 ->10020 | Owner release `0x0efc473fc947d4ca9ecfb4e19b496fe6985a6197313bd75a7744294eabfb831c`; personal transfer `0xd2715f6a0518623c746bac9917c9a78d94ad805d0875e4aa3b50e151a86e6079` |

All five donor operations are **local impersonated fixture operations**.
They prove no donor-key control or public donor consent. E-P/W-P release is
the existing EOA's collector-owner authority; its subsequent donation is
personal-holder authority. Neither belongs to the claimant, Migration owner,
Migration contract or general operator executor. Actual users must already
control the configured eligible source. No contract-valued owner or collector
contract was impersonated for these new acquisitions.

Both LP release state diffs independently show exactly two source balance-slot
changes, -10020/+10020, no collector storage change and no changed code.
Both source LP contract owners remain ED/WD. Supplies and the recorded other
SE/LP/DTF holdings remain unchanged. Each source is native18, with actual
ERC20 routing to `0x1d17aca0e0717d90cea916372070a1be4652223f`,
runtime hash
`0xf250dca135b1de9a5fc9ceda732c06af7020fef1d45d7c43dfa92efe02b47e50`.
Source proxies retain the admitted 370-byte runtime/hash. No new-source
balance/storage/code/role was injected.

## 5. Independent Q/C and funding witness

Each source's separate configured original uses Q0=10013 native18, synthetic
known original ETH6000000000000000 and DTF0. The real frozen evaluator
computes C0=2774608 new-DETF native9. The three originals are quoted
separately, not merged. Acquisition10020 includes seven excluded units.

| Fresh source | Partial hash; q/credit/bond | Terminal hash; q/credit/bond | Partial/terminal start |
| --- | --- | --- | --- |
| W-SW | `0x51404d8caff0ee6d2d14f88ffb9b2c9dcc2f355ba062f4b6833476c9bb6e2591`;3337/924684/25 | `0x27f41cf5422bd8fa4e9a6d30cd7ba04141c1b1d1c2be4534c7fdee8bc19e123b`;6676/1849924/29 | 1826050752/1826137189 |
| E-P | `0xa2c14fd50ebafe59e6929395df45d981afea08acebe6f97ea6c068b371e02c75`;3337/924684/26 | `0x7c1f4d7d2e66471a444444453b36ce064c0e2f03149a5a30ce7731b92691941d`;6676/1849924/30 | 1826050767/1826137194 |
| W-P | `0x551056a93c0fcba4c2680858175f747e551b7683c7308f327e5ee83f441d7d3d`;3337/924684/27 | `0xd09ef69b92b00d4cd660d40704163d21d42837edeeee21b95ebe2b5789186ea4`;6676/1849924/31 | 1826050782/1826137199 |

Independent arithmetic starts from each complete original, decodes the actual
signed surrender calldata and requires floor(2774608*3337/10013)=924684.
Remaining Q/C=6676/1849924; exact terminal delivers all1849924, ending Q=C=0
and delivered2774608. Finite allowance10013 falls to6676; terminal maximum
allowance becomes2^256-1-6676. Source Approval events confirm both decrements.
Custody minus booked inventory remains7. Each actual new position is
same-wallet, principal=credit, claimedPrincipal=0, with exact funding transfers
and7776000 seconds between its own creation and unlock.

Those Unix starts are deliberately advanced disposable-fork times, not host
dates or an operational schedule. Later bonds have later starts. Eighteen
actual signed new-source failures, six per source, have status0 and no logs.
The positive dedicated mixed-inventory forks cover nonzero WS gons; the CLI's
WS ledger at these late held-source phases is zero and is not mislabeled a
positive mixed-WS witness. Both ER E/B ledgers and ED rewards are protected.

## 6. Actual registration, constructor, compiler and named libraries

Both independently captured runs bind actual registry
`0xaa66038ae217b246f5bf7537104342672e56fed8`, Migration package
`0x642fa76f2f7a6b97ec0822d67a785379a92df347` and proxy
`0xedf7d9f65b9e57d62a3c4278223170db1308f5f0`. Registry NewVault logs
bind proxy/package. Same deterministic addresses and registration hash do not
mean reused node state: producer PID41253 and fresh PID62726 are separate,
and snapshot/block/operation captures differ.

Package-construction transaction
`0xedd215c57a7a84d859b6bb27dc8c4393736a4cfcbfdd9c7327842c5429a6ed24`
has initcode hash
`0x112a03e5f981e84609af6a54df9db0044dde59c072b29cdacf2cdd06a0921705`.
Actual registry deployPkg calldata, creation-artifact prefix and all constructor
inputs agree. All22 immutable values are derived from the decoded constructor
and SELF, in source declaration order, then compared at every declared span.
Arbitrary observed immutable bytes are not accepted merely by masking them.

Instance registration
`0x8f91ec9aabd78cfe3c54c8b53ce67dc030e2c3ae8b903c864b62e1e7410c7ace`
uses actual package deployVault calldata. Re-encoding the complete original
manifest PkgArgs is byte-identical to that signed calldata: owner is development
account0, buffer86400, original DTF is fixed legacy DTF, local WETH is
`0x8096e26a26059c5240ab23d69157e121b28d326a`, and hook is
`0x4d48367dfa6300587c45fb2c841c18bc1abfaaa8`. Full base arguments and all
constructor addresses are retained in `audit-final.json`, not summarized away.

For each run, 75 actual runtime capture records bind57 current artifacts and
301 distinct compiler-source hashes, plus both stage artifacts and their
source metadata. Repeated captures are not75 distinct contracts. Named linked
libraries must match captured address, name, source and code. Complete runtime
equality allows only declared immutable/link spans and compiler library
self-address substitution; no arbitrary masking or metadata stripping.

| Current actual runtime | Bytes | Headroom below24576 |
| --- | ---: | ---: |
| Principal Migration facet | 24408 | 168 |
| Allocation facet | 24100 | 476 |
| Recovery facet | 22704 | 1872 |
| ClaimVaultAllocation facet | 11221 | 13355 |
| Migration package | 16714 | 7862 |

The actual registration gas is **45,116,678**, above32,000,000. EIP170
success does not establish target deployment feasibility. Prior accepted
44,863,086 and earlier gas observations remain historical open limits.

## 7. Original wire, signatures and all three genuine resumes

For each run, the actual HTTP observer retains1999 response bodies across671
blocks,663 canonical transactions and663 canonical receipts. Independently
checked request/response IDs, transaction/receipt/block identities and every
nested log's block/transaction identity. All491 nonsynthetic wire signatures
reconstruct to their actual hash/signer/chain4663. The other172 have Anvil
synthetic r=s=1 and are labeled impersonated fixture operations, never
cryptographic user-signature proof.

Within those captures, each run has155 originally retained raw signed records
and four explicitly **offline deterministic reconstructed** acquisition
signatures. These subsets are not added to491 as different transactions.
Reconstructed signing bytes are not original raw captures. Complete canonical
receipt equality is checked for all159 records, including nested log fields.
All five new-source donor transaction and receipt objects also compare
field-completely to actual captured HTTP results.

| Genuine fresh mined-before-checkpoint operation | Actual mined hash adopted by fresh-process resume |
| --- | --- |
| Funding donation | `0xe3c3d25c6f654d2d43049103959540c01a923e257a59549871d0a02bf1558f22` |
| Independent issuance | `0x5635828beb4c23bee076f05f0a116a4bda678e760a2df1cb269112835da0b7b1` |
| Paid owner-first ordinary bond | `0xee8b7bb0308538c1a9846ea8c353b998f5e6d0769affd30aa6b4bde8ace99833` |

Each fault command actually exits SIGKILL/code-null after mining with no
completion checkpoint, then a new CLI process adopts the same intent, raw
signature, nonce and mined transaction. `results[].independent.canonicalResumes`
retains original transaction, before/after records and actual HTTP receipt.
All15 raw receipt fields are compared: blockHash, blockNumber, blockTimestamp,
contractAddress, cumulativeGasUsed, effectiveGasPrice, from, gasUsed, logs,
logsBloom, status, to, transactionHash, transactionIndex and type. The complete
original transaction object also equals the raw HTTP transaction. No second
donation, issuance or purchase is substituted. The producer's three original
resume witnesses are separately reconciled and preserved.

## 8. Exact captures, metadata drift and verification limits

`audit-final.json` is21061917 bytes, SHA-256
`b3db9108d65b774436452b706c6f151d52e95133b956ff267af12d9fa937e64d`.
The independent raw HTTP file is8608048 bytes, SHA-256
`f2e69c864b25f41bc15d49a66d3ef8530543430b3480e56f4e1709d375414be8`.
Raw file hashes, hashes of serialized objects and original HTTP body bytes are
different provenance classes.

All30 lossless original producer prepared-input captures decode to their
original byte counts/hashes/newline states. Required independent compilation
changed three ignored raw interface artifacts: Allocation and Migration
top-level source-unit id758->534, MigrationDFPkg id760->536. A full structural
JSON comparison finds only those `$.id` differences. ABI, source and executable
runtime are unchanged. Thirty-six repeated producer-manifest references
therefore use the existing exact original base64 captures. `metadata-drift.json`
retains all original/current hashes and the complete enumerated differences.
The producer's sealed original zero-drift observation was not rewritten.

The fresh run has zero prepared-input drift. Its four current raw ABI inputs
are separately losslessly captured in `fresh-captured-inputs/`, with decoded
byte/newline/hash bindings in `fresh-input-captures.json`. No normalized JSON,
offline ABI reconstruction, artifact restoration or invented hash exception
is presented as original evidence. Earlier ED historical48-entry drift and
ER four-ABI reconstruction qualifications remain historical.

Read-only inspected producer binding, receipt, ER/ED/held economic, lifecycle
and constructor algorithms were reused and reexecuted for both runs.
`raw-checks.ts` independently adds transport/block/log identity, donor canonical
field and exact storage-delta checks, every raw resume transaction/receipt field,
signed native Q/C and Approval recurrence, and actual instance-argument ABI
equality. This is not claimed as an entirely unrelated implementation of every
helper. No producer PASS/status flag supplies the result.

`failed-attempts.md` preserves the first owned audit's empty-array display
conversion failure. Only the owned probe changed to byte-exact ABI comparison;
the completed successful audit uses unchanged raw witnesses. No transaction or
required test suite was replayed to repair that evidence-only bug.
Final strict types pass. Audit TypeScript LSP reports no errors; raw-checks LSP
freshness times out. Bash and JSON LSP are unavailable. These are tooling
limits, not clean editor passes; no package/configuration installation occurred.

## 9. Preserved exclusions, actual cleanup and stopped handoff

E-S `0xb7d4bb379d361ad442cddee53ea71a33957826a7` remains outside the
supported source set. The retained read-only E-S mint attempt's VaultDisabled
is not a positive mined fixture. Root31-wallet/93-zero reads are not a census.
The source20 stopRecorded=false summary discrepancy remains untouched; its
actual stop RPC and stopped node control, as qualified in the source admission.

No new conversion/debit/donation stage, successful exit decoder, arbitrary
executor or source enablement appears. W-SW retains VaultDisabled; E-P retains
UnsupportedRoute/native NotOwner; W-P retains ordinary NotOwner and owner-only
liquidity. Existing failed exits were inspected, not replayed as new positive
coverage. Possession of physical LP grants no legacy ED/WD owner permission.

Legacy archives retain match/runtimeMatch qualifications, not exact complete
transitive recompilation; the optional missing ED facet and masked earlier
mature-close authorization remain separate limitations. Operational original
Q0/ETH/DTF datasets, opaque origins, E-S control, all blocked conversions,
raw TokenStaking/native/WETH exposure, full hermetic/cold reconstruction,
host/archive portability, full-plan acceptance and target gas remain open.
Inherited positive ER/WS nonrepresentable residue is accounted state, not a
pending owned operation or promised future redemption.

Fresh Anvil PID62726 exited and is absent; producer PID41253 remains absent.
Loopback18571 has no listener. The exact checkpoint is absent and its empty
owned runtime parent was removed with rmdir. The CLI, raw observer, required
checks and audit monitors all completed. Receipt subscriptions and donor
impersonations close through the inspected finally paths. No owned runtime,
provider, checkpoint, subscription, impersonation or operation is pending.
`cleanup.json` records the final observations. `seal.json` binds the complete
owned evidence tree except its own self-reference.

**Confirmed only for the three admitted bounded custody/credit paths, with
the qualified LP donor fixture and blocked-conversion split intact.**
