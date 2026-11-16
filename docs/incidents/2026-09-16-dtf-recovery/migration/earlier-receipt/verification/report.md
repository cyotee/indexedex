# Independent bounded earlier ER implementation verification

Date: 2026-11-12. **Disposition: confirmed for bounded ER custody and frozen
credit, within the admitted measurement domain.**

No blocking implementation finding was identified. Independent execution
passed all 142 current Migration specs, 101 current pinned Migration forks,
both operator-stage builds, strict operator types, all 72 operator tests in
one invocation, and a fresh actual pinned18568 CLI. Independently authored
auditors verify current source/compiler/artifact/runtime identity, signed
payloads, complete raw interruption receipts, lifecycle and ER economics.
Neither producer summary flags nor its auditor's verdict supplied that proof.

This is runtime verification of the stopped uncommitted candidate, not
immutable delivery, full-plan/full-hermetic acceptance, operational allocation
approval, target-gas acceptance or authorization for public execution.
**ER liquidation remains blocked.**

## 1. Actual handoff, authority and preserved identities

Worktree:
`/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-18-earlier-receipt`.
Branch: `work/dtf-migration-phase-18-earlier-receipt`.
Unchanged HEAD/base: `acdbe319f3a20c3af6bea594c62461b6c7988717`.

The complete implementation brief and original phase18 brief were read,
together with the admitted contract and actual source-verification report.
Governing current authority is the main-checkout plan r5 and PRD r22,
particularly plan sections 1.3-1.5 and 5.1-5.4. The complete phase17 runtime
report and final commit receipt/audit, complete phase11 earlier contract and
verification report/matrix, and referenced phase01 CP source/execution,
provenance and phase07 earlier claim/sale/correction evidence were consulted.
The current original-wallet, Stage2-only surrender, immutable activation and
paid owner-first-bond requirements supersede the identified historical prose;
historical failure labels remain historical.

| Input | Raw bytes | SHA-256 |
| --- | ---: | --- |
| `../source/contract.md` | 22508 | `173bc343faf90a1d01ada52f16f86b0d707f6d87687bc438d9e209654bcbdc91` |
| `../source-verification/report.md` | 20560 | `86d0c1a22ffd398b528f9008c658a8fc51c39f273cdd50275faabd64668fbf35` |
| Actual final producer report | 18760 | `4501cd231c4e1cf23f95d6a37190d44502d159800e8dce3d1d20fe4b48d3216d` |
| Actual final producer seal | 628813 | `5ef85c26ab00282904ad27b47b151427d9018287bd91a9d10ae45e3d0c48c3b6` |

Before runtime execution, the producer's complete report declared the bounded
candidate complete, modifications stopped and cleanup complete. The actual
seal, 34 candidate source/test/operator/runbook paths, 236 immutable
source/admission members, 21 authority inputs and 1386 sealed producer evidence
entries matched their raw lengths/hashes. Port18568 and the checkpoint parent
were absent. The handoff was not accepted from a pending or needs-fix token.

Both final independent audits recheck 1678 preserved binding records, including
duplicates, and exact source/admission membership. They retain current modes
alongside raw lengths/hashes. Producer/source/admission files and seals remain
unchanged. `audit-fresh-final.json` and `audit-producer-final.json` contain the
complete comparisons, not a completed-node count.

The full tracked diff and four added source/test files were inspected.
All 11 production roots are Migration-specific interfaces, repositories,
allocation/recovery targets/facets and the existing legacy interface/helper.
Other changes are adjacent Migration tests, existing operator/stages and the
runbook. No source fix was made by this verifier. There was no ordinary,
common or Crane production edit, dependency/configuration change, held09
inspection/import/replay, provider substitution, public action, commit or merge.

## 2. Independent execution

`execute.sh` contains the exact ordered commands and all 11 actually edited
production roots. `execution.log` records each successful gate after its
command/pipeline returned successfully under `set -euo pipefail`.

| Independently executed gate | Result and retained log |
| --- | --- |
| Artifact-first Solar production build | Exit0; `build.log` |
| Complete current Migration spec directory | 142 passed, 0 failed/skipped, 24 suites; `specs.log` |
| Complete current pinned Migration fork directory | 101 passed, 0 failed/skipped, 19 suites; `forks.log` |
| Stage00 OperatorEnvironment and Stage01 MigrationExecution | Exit0; `stages.log` |
| Strict operator TypeScript | Exit0; `types.log` |
| Eight operator test files, one invocation | 72 passed, 0 failed; `operator-tests.log` |
| Fresh actual pinned18568 CLI | Exit0, bounded-rehearsal-complete; `cli.log`, `runtime-01/` |
| Final strict independent probes | Exit0; `probe-types-final.log` |
| Final independent fresh and retained-producer audits | Both exit0; `audit-fresh-final.log`, `audit-producer-final.log` |

Types use noEmit, strict, noUncheckedIndexedAccess,
exactOptionalPropertyTypes and verbatimModuleSyntax. The original operator
test invocation was not repeated to obtain a lucky pass. Auditor-only changes
were separately typechecked and audited; they did not trigger product edits
or another test/CLI run.

The existing `/bin/zsh -lc` archive bootstrap and installed Bun1.4.2/Foundry
nightly were used. Solar metadata identifies
`0.8.38+commit.e7a91fc7.solar.0.3.0-dev`, optimizer enabled/runs1, no viaIR.
Warm `out/` and `cache_forge/` and prescribed dependency links were retained.
No cache deletion, alternate compiler, changed test root/profile or concurrent
compiler writer was introduced.

The fresh run is `runtime-01/rehearsal-1794472643773`, node PID76483,
instance `0x91093656c26ebaf3911691b4b2e06cd09f5ea94f5ef10459535b80c87d9b269f`.
Actual historical chain4663/block108944663/hash
`0xc497433dd691a40cb85959cfeba2e3fff85a975ae060612d984998e1d5765733`
is bound directly. Deterministic addresses shared with the producer do not
substitute for this distinct execution identity.

## 3. Complete bounded requirement matrix

M below is `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/`.
Test filenames are in the existing spec/fork Migration homes. Final audit
coverage arrays retain every actual passing test name.

| Obligation | Independently inspected and executed proof |
| --- | --- |
| Exact original Q0 and known ETH/DTF, frozen C0 | `M/UniswapV4DetfMigrationClaimVaultAllocationTarget.sol:98` computes credit with the real frozen evaluator, hashes chain/proxy/snapshot/full original and stores exact internal units. Configuration spec and funded fork fixtures compare its actual quote; operator tests reject unknown/missing components, award/pricing/unit alternatives, malformed quantities and mismatched partitions. Synthetic components are disclosed, not operational awards. |
| Owner-only, complete replacement and idempotence without issuance | All four `MigrationEarlierReceiptConfigurationTest` tests pass: actual pending/accepted/former/current owner transitions, malformed second-row whole-batch rollback, source/chain/knownness/zero-field negatives, full wallet/unit/component replacement and replay. Raw CLI loader transactions contain no new-DETF mint. |
| All canonical-origin exclusions, both directions | `test_allCanonicalOriginsExcludeBothDirectionsAfterWalletCorrection` executes independent compensation, both NFTs, WD, WY, W-SD, claim-vault and WS collisions in both orders. It includes wallet correction and already-issued independent history after replacement. Opaque aliases still require operational reconciliation. |
| Stage1 closure, paid first owner bond, permanent activation | Configuration/surface/core/owner-first-bond suites and fresh CLI pass. Actual activation removes all 12 current Allocation ABI selectors across the two removable facets. `lifecycle` independently decodes the actual ERC8109 DiamondFunctionRemoved logs; no invented DiamondCut event is required. Retained queries and surrender remain routed. |
| Original wallet and actual control | `test_stageOneMissingWalletTransferBackAndSourceMinimumDeadlineRollback` plus three actual signed CLI negatives cover Stage1, absent record and wrong original holder. Transfer away/back neither moves nor resets configuration. Failed source allowance/control, deadline and late minimum leave the measured economic state unchanged. |
| Literal callable section4 measurement | `M/legacy/MigrationLegacyRecoveryLib.sol:33-108` observes both external-share and displayed endpoints, rate and total external shares immediately around the real fixed-source displayed-unit pull. It requires true, positive q, unchanged rate/supply, floor consistency and the singleton inverse-rate proof. Production uses no internal-share getter, RPC storage read or external-delta-times-scale attribution. |
| Both actual opposite floor carries and old fractions | `test_bothEndpointCarriesPreserveUnrelatedInternalFractions` uses genuine acquisition10000, unrelated custody input1, then pulls4/1. The first custody external delta is floor(q/S)+1 with sender floor(q/S); the next sender delta is floor(q/S)+1 with custody floor(q/S). The unrelated exact internal quantity/fraction survives. |
| Full-precision and checked arithmetic | Four supplemental `MigrationRecoveryTest` cases execute a valid product beyond uint256 multiplication, unresolved/zero external deltas, rate/supply/display inconsistencies, interval/H+1 multiplication overflow and inverse-bound increment overflow. These are supplemental numerical vectors, not manufactured legacy state. |
| Rate movement without repricing | `test_actualRateDonationDoesNotRepriceOriginalOrBookUnrelatedShares` and fresh CLI actually donate DTF to the old rate source. Rate2197 becomes4046; source share supply and original Q0/C0 stay fixed. Independent arithmetic recomputes q, inverse bounds and credit at both rates. |
| Partial and genuine divisible terminal | `_pull` checks exact source internal debit/custody increase, B and cumulative/remaining Q/C, distinct real child NFT ownership/principal/gons/start/cliff and cleared funding allowances. `test_genuineDivisibleTerminalTakesAllFrozenCreditIntoFreshCliffs` genuinely acquires4394 at2197 (Q0=2e27), pulls2197 twice and ends Q=C=0. The documented acquisition, not a forced operational denominator, supplies Q0. |
| Source can transfer more than displayed balance | `test_actualOneMoreThanDisplayedBalanceIsNotAnInputCap` acquires input1, observes display0, then successfully surrenders input1 and all remaining credit through Migration. There is no erroneous absolute display cap. |
| Nonrepresentable residue and over-cap | `test_positiveNonrepresentableResidueRetainsQAndCAndRejectsExtraInput` genuinely acquires2197, pulls1/2196 and retains Q=1,C=1, display0. Additional genuine wallet inventory cannot evade the original cap; no ceiling, clamp, donation, forgiveness, clearing or future-representability promise occurs. |
| Positive credit and zero-credit rollback | `test_zeroCreditRollsBackAnActualApprovedPull` uses a genuinely acquired denominator and disclosed small synthetic components. A positive approved pull that yields zero credit reverts without committing custody, allowance spending, Q/C/B/E, supply or funding state. |
| One exact funded fresh90-day same-wallet bond | Real registry Migration forks and two fresh CLI surrenders pass. Independent raw parent transfers prove exact mint, parent-to-child pull and child-to-staking backing equal credit. Raw child NFT mint/BondPurchased/MigrationPositionCreated, positions and receipt timestamps bind wallet, principal and 7776000-second cliff. Existing actual cliff-boundary specs also pass. |
| Source, funding, receiver and enclosing rollback | `test_lateReceiverRollbackReentryAndLaterDonationRemainSeparate` rejects at the actual receiver after genuine source pull, consumption and child funding; source internal ownership, allowance, Q/C/B/E, new supply/staking/backing and parent funding allowance restore. Earlier independent approval remains. Existing complete funding/callback suites also pass. |
| Shared guard and legitimate later donation | The same real contract-wallet receiver attempts reentry, then legitimately transfers additional ER later in the callback. Reentry does not succeed; only the measured pull q is booked/consumed, and the callback donation remains unbooked. Production ends measurement before funding, avoiding a false later interval-equality condition. |
| Separate E/B, both arrival orders, unrelated fractions | `test_nftExternalAndStandaloneInternalInventoryMixInBothArrivalOrders` executes actual NFT3 sale at its genuine unlock and standalone surrender in both orders. E stays external NFT-sale shares; B is standalone internal shares. Actual internal custody minus E*1e9+B equals the prior unrelated quantity. Fractional B survives. `M/legacy/MigrationLegacyRecoveryLib.sol:111,346` checks composed capacity on both booking routes without changing query units. |
| No extra liquidation path or false status | Recovery Stage enum remains unchanged. There is no new ER conversion/debit/donation stage, executor, decoder, source enablement or governance role. Runbook and all14 operator category dispositions distinguish admitted custody/credit from disabled liquidation. Previous routes and all three real interruption resumes remain present. |

The fork's diagnostic `vm.load` and CLI `eth_getStorageAt` are read-only
independent observations of actual source ownership. They neither fabricate
source state nor drive production measurement or original pricing.
No ER source balance, rate, code, role or denominator was injected.

## 4. Compiler, registry and runtime bindings

The actual signed deployment receipt has the real registry
`0xaa66038ae217b246f5bf7537104342672e56fed8` emitting NewVault for Migration
`0xedf7d9f65b9e57d62a3c4278223170db1308f5f0` and package
`0x642fa76f2f7a6b97ec0822d67a785379a92df347`.
This is the registry/package deployment path, not a directly constructed SUT.

Each final audit binds 75 runtime capture entries and 57 artifact/runtime
comparisons across 29 distinct artifacts, including parent/child/registry
proxies, facets, package and three actual linked libraries. All 301 distinct
runtime-artifact compiler source keccak256 values match current raw inputs.
Both stage artifacts are additionally raw-hashed; all 545 and 68 respective
metadata source entries match current bytes. All 23 distinct prepared inputs
are independently checked.

Runtime lengths must agree exactly. There is no metadata stripping or
arbitrary mask. Only compiler-declared immutable/link spans are excluded;
actual values and offsets are retained. Every linked address must identify
the correct captured library and its current compiled bytes. A library's
compiler-generated PUSH20 self-address guard is explicitly checked against
that actual library address. The 198-byte proxy runtimes match their compiled
artifact without any excluded span.

| Actual facet | Bytes | Runtime keccak256 |
| --- | ---: | --- |
| Persistent Migration | 24408 | `0xc492fd55e3bf1886efe6d258eebb94abe4361a40588e071940b7834e52cb43ab` |
| Allocation | 24510 | `0x0fe330cdf2a02385305bf1f79dbf4e3048a622763d9a0f6162651e4b37b4c786` |
| Claim/receipt allocation | 8713 | `0xd36b0392ad8fc6c7868cc8cc180244918da6083d919b94c7eae5f3905fa6031d` |
| Recovery | 20416 | `0xdfaf065d1c6f022b39f7a84e3f673176fc6cd8539a79183842fb4cbc6a0f804f` |

Every captured deployed runtime respects24576 bytes. Allocation has only66
bytes headroom. Actual code-size enforcement remains enabled; script/test
sizes are not substituted for deployed-facet observations.

### Raw artifact identity after independent compilation

Required independent compilation regenerated four raw ABI JSON files under
ignored `out/`. Their top-level Solar source-unit IDs changed:
Allocation/Migration2442->534, MigrationDFPkg2444->536 and Recovery2457->543.
This is not concealed as raw-file equality to the earlier producer manifests.

For each original producer input binding, changing only that terminal JSON
`id` in memory reproduces the exact sealed original byte length and SHA-256.
The recovered raw strings, current hashes and original hashes are recorded
under `producerInputReconstruction` in the final producer audit. These are
explicit offline hash recoveries, not original captured files or edits to
producer evidence. No producer artifact, input or seal was rewritten.
Fresh prepared inputs match the current raw artifacts without an exception;
current compiler inputs and actual producer/fresh deployed bytes independently
match throughout.

## 5. Independent ER economics

Actual source ER is `0x4AC89aD061A531FA62ddceED53520C2750113b01`.
All captured relevant selectors resolve to admitted receipt facet
`0x25E611FB63Eb904776678286EF5cbe2a931B4f9A`, runtime hash
`0x31151be4bf8ff8e79f448872f9a0a5c37ee413ce7d2b15206f2debcc59d86ccc`.
Archived qualification remains **match**, not exact_match or a complete
transitive historical recompilation.

Controlled original wallet `0x33b1ce5357959ec0043e0d77556a5093ab347862`
genuinely acquired input10000 at rate2197:
Q0=`4551661356395084205735093309` internal shares. The exact original
partition and fixed-source facets are bound. Original ETH0.01, then full
ETH0.006/known DTF0 replacement, are synthetic code-proof records evaluated
by the actual frozen evaluator, not historical approved awards.
Replacement C0 is2774608 native9.

| Fresh operation | Exact q | Credit | Bond | Rate |
| --- | ---: | ---: | ---: | ---: |
| Native input4 | 1820664542558033682294037 | 1109 | 22 | 2197 |
| Native input1 after actual rate donation | 247157686604053386060306 | 150 | 23 | 4046 |

Transactions:
`0x84a2e37669aa60830bd893e9c21588573c4e81f57a12a991764b6d8930dac5a6`
and `0x2f28a5473adc860fd9e8335ac37ba1f6015405aacad6ac91a56ce32cae39c774`.

The independent auditor recomputes q=floor(n*1e27/r), both endpoint external
and displayed floors, L/H+1, both singleton bounds, allowance spending,
remaining-credit recurrence, configuration/snapshot IDs, source debit and
receipt, backing/supply deltas and raw parent/child events. It does not accept
the recorded q/credit/rLow/rHigh fields without recomputation.

Final Q=`4549593534165922118666738966`, C=2773349.
Delivered1259 plus remaining2773349 equals C0.
B=`2067822229162087068354343` internal shares:
whole external representation2067822229162087 and fractional internal68354343
(nine-digit field068354343). E remains485044501927175493321 external shares.
Actual custody is485046569749404655408068354343 internal shares, exactly
E*1e9+B in this CLI history. Separate actual forks prove preservation when
unrelated internal fractions are present.

## 6. All signed payloads and all three genuine resumes

For each final runtime, the independent audit decodes 51 signed operator
intents and21 additional ER/WS raw signed records: 72 retained raw payloads.
It checks hashes, recovered signer, chain4663, nonce, target, value, calldata,
successful operator completion hashes and raw receipts. Eight additional
source/wallet records are actual mined failures with status0; they are not
presented as successful operations.

The four inherited controlled claim-vault/W-SD acquisition signatures do not
retain raw bytes in their acquisition JSON. Their raw bytes are reconstructed
offline from the disclosed public development mnemonic, recorded requests,
native nonce, type0 effective gas price and the inspected2000000 gas limit.
Each reconstruction must hash exactly to its actual retained mined hash and
recover its recorded signer/target. These are labeled reconstructions, never
original raw captures. No transaction is sent by the auditors.

| Fresh interrupted operation | Nonce | Actual transaction |
| --- | ---: | --- |
| Donation | 2128 | `0xc5615d8e3fe8a2026b05e83d92ce5dffdf1e7e296c4a52c1f45f26accfe0e370` |
| Independent issuance | 2146 | `0x21a88fb1c04f2b52f2e00ab6a7eb417e7b1b9622ee4faabff52cd7134d35a90a` |
| Paid owner first bond | 2166 | `0x1ee45128e1363fd1c7bc4505e619105779ede71c0922c03469b3762b90f42466` |

All three actual child command receipts show SIGKILL, code null, after the
mined-before-checkpoint fault output. The pre-resume witnesses have canonical
success receipts and no completion. Fresh-process resume archives reconcile
the same signed intents/hashes/nonces; each journal has one matching intent.
The independent audit also compares the raw RPC transaction gas/gasPrice and
r/s/v with the recovered signed bytes.

All15 actual canonical receipt fields are recursively compared before/after:
blockHash, blockNumber, blockTimestamp, contractAddress, cumulativeGasUsed,
effectiveGasPrice, from, gasUsed, logs, logsBloom, status, to, transactionHash,
transactionIndex and type, including every nested raw log field.
The producer's sameCanonicalReceipt flag is not used as proof.
The retained final producer runtime is independently audited in the same way;
it is not relabeled fresh verifier execution.

## 7. Findings, failures, limits and cleanup

**Blocking bounded implementation findings: none.**

Verifier failure history is retained. `audit-producer-01.log` rejects raw
ABI-file drift after the verifier's required recompilation; exact ID-only
hash recovery above resolves the auditor's overly strict cross-compilation
file assumption, not a source defect. `audit-fresh-02.log` rejects a mistaken
auditor assumption that activation emits DiamondCut. Actual Crane source and
receipts emit12 ERC8109 DiamondFunctionRemoved events; the corrected auditor
verifies those against the complete current ABI. Earlier successful audits
remain earlier checks, not substitutes for the final strengthened audits.
No product, test, source/admission or producer evidence was edited to pass.

Existing Foundry/nightly/compiler/lint warnings remain unsuppressed.
Some fresh TypeScript LSP requests timed out; the final strict compiler pass
is the executed type evidence, not a clean-LSP claim. Bash LSP is unavailable;
no dependency/configuration install was attempted. `zsh -n execute.sh` passes.

Historical parent ED redeemClaim tx
`0xe4359e06c585390d0c6e33cfb105c2384f58c4f9b44d75e1e0c566a2a97109e9`
remains FAIL; direct ER redeem tx
`0x22fb95c8bfd0b3f7c58faa20f4672371f4740ffb8a3276cccb3ff2a731880a0d`
retains UNPROVEN. Both actual historical traces return
VaultDisabled at ES `0xb7D4Bb379d361aD442Cddee53EA71A33957826A7`,
status0 and unchanged state. Neither separate unchanged redemption probe was
rerun or promoted to successful conversion coverage.

Operational original-wallet/origin/unit/component datasets, opaque-origin
reconciliation, ER liquidation/donation, other blocked source categories,
native/WETH and raw-claim limitations, archived source qualifications,
host/archive portability and full hermetic/full-plan acceptance remain open.
The phase15 source archive remains at its existing retained worktree path;
phase17 source/admission inputs remain bound at their actual retained paths.

Prior parent gas44,353,454 remains above32million. The fresh actual signed
parent deployment additionally uses **44,653,392 gas**, tx
`0x79b37c8f8d6274380acb04c0d2f6af7b000ab1de236ba1e340a0a23a30238ab4`.
The permissive local100-million node is not target feasibility or acceptance.
Positive remaining Q/C is preserved state, not a pending operation or a
promise that future rates make every remainder redeemable.

Fresh CLI cleanup records exited node PID76483 and removed checkpoint.
The exact empty runtime parent was removed after CLI cleanup. Independent
`cleanup.log` records no producer/verifier PID or18568 listener, absent
runtime parent, unchanged required HEAD/branch, empty staged set and clean
tracked whitespace check. Providers, receipt subscriptions and source-funding
impersonations were closed by the completed CLI finally paths.

Only this `verification/` evidence/probe tree was authored. Required builds
refreshed ignored compiler outputs; the existing CLI produced its usual local
generated broadcast files. No foreign runtime or checkpoint was removed.
`seal.json` binds this final report, independent probes, raw logs, audits and
fresh runtime evidence, excluding only its own self-reference.
All owned executions have ended. **No owned operation remains pending.**
