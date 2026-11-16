# Independent stopped stateful candidate verification

Date: 2026-11-12.

**Disposition: confirmed for the exact stopped bounded test-only increment.**
The two new state machines execute real registered subjects, maintain useful
independent ledgers, and pass the independently repeated bounded gates.
**The complete section 8.2 twelve-property, all-source/unit gate is not
confirmed.** The coverage limits below remain open; a passing scalar SY
ledger is not evidence for standalone gon, internal-share, native19,
native28 or physical-LP state machines.

No blocking SUT defect was established in this bounded execution. No source
fix, existing-test change, producer-evidence edit, commit, ref/index write,
public action, held09 inspection/replay, provider workaround or old
CLI/resume execution occurred.

## 1. Admitted stopped subject and preservation

Worktree:
`/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-24-stateful-invariants`.
Branch: `work/dtf-migration-phase-24-stateful-invariants`.
Initial and final audited HEAD:
`15fd629375edeb361f6a39262795bdc66723ca3a`.

Admission preceded runtime execution. The actual complete producer report,
seal, cleanup, source manifest, complete new-file patch, raw final logs and
preserved failed attempts existed. All 21 evidence members match the seal
in length, SHA-256 and mode, with exact membership excluding only the seal.
All eight source files match both the manifest and the full new-file patch.
All 17 declared authority bindings match. These checks were repeated after
execution, without replacing an original baseline.

Producer seal SHA-256:
`97d7df1bb3b21d7c17f272e48c73fe0e44e5a4377d7ce9318aa125e0a450c303`.
Producer report SHA-256:
`01f68baad98a430d0694ec0b0d9a8b8af83c766765d50ab2c01ea0796e3b3d55`.
Candidate manifest SHA-256:
`84bbedeef002ee142c2cd134c4180ba6c1c6795cc483183cce401a4cc9972ef3`.
Complete patch SHA-256:
`5ab0b43cedb2e9ededee532b0f0ee450621b35a6bc6c6023caafded68c17e953`.

Read the complete brief, root intake, current main implementation plan and
PRD, phase21 source snapshot, exact phase23 implementation/r2/immutable
reports, original-wallet source contract and corrected recovery admission.
The exact phase23 report hashes remain
`49fab644f20998227e1c30013c07e2895a8feeda1e0714ae481a860b4d11e0dd`,
`14750c64ed29a92ddf36b8c68fd6ec8b9fcdd39b7bc61e612662b1ff617a3f41`
and
`653350b3af3d011ad068a0885461c6828d5cb1aff481ba15900a7ff2563f773b`.
Plan sections 1.3-1.5 govern original-wallet eligibility, Stage2-only
surrender and the genuine paid owner-first bond. Older contradictory PRD
paragraphs were not restored as current requirements.

Inspected all eight new Solidity files, including both complete handlers,
the recovery specialization, ledger, fixture, capture library and both
tests. Read the existing real Migration TestBase, inherited pinned NFT and
recovery bases, relevant production custody/issuance/recovery/cliff code,
and existing ordinary-SY/claimed-SY, original-wallet, lifecycle, surface,
reward and focused ordinary regression owners. Existing deterministic
tests are identified as supplements, never counted as new invariant
selectors.

Tracked and staged comparisons against HEAD are empty before and after.
All Git invocations used `GIT_MASTER=1 GIT_OPTIONAL_LOCKS=0`, and
status/diff ignored submodules. Dependency symlink targets, modes and
inodes are unchanged. The producer's original failed logs and seal remain
intact, including the zero-action discovery failure and donation-model
counterexample. This verification never imports or replays held09.

## 2. Independent execution

Each gate ran once against this unchanged final candidate, using
`python3 scripts/forge-artifacts.py test` with artifact-first
`forge build --use solar` before `forge test --use solar`.
The complete Migration directory roots include the new `invariant/`
subdirectories; the native or legacy concrete handler is an explicit
artifact root. Literal outer recipes are in `execution-plan.json`;
complete expanded build/test commands and exits are in
`execution-results.json` and the raw logs.

| Gate | Independent result | Raw output |
| --- | --- | --- |
| Complete current Migration specifications | 169 passed, zero failed/skipped, 29 suites, exit 0 | `specs-final-01.log` |
| Complete pinned current Migration forks | 144 passed, zero failed/skipped, 25 suites, exit 0 | `forks-final-01.log` |
| Focused ordinary-family regressions | 58 passed, zero failed/skipped, eight suites, exit 0 | `ordinary-final-01.log` |
| Native invariant | 32 runs, depth 16, 512 calls, zero unexpected reverts/discards; seed `0x24a1` | Complete specs log |
| Legacy invariant | 32 runs, depth 16, 512 calls, zero unexpected reverts/discards; seed `0x24a2` | Complete forks log |

The independent run doubles both repository settings, runs16/depth8,
without lowering the producer's settings or reusing its random seeds.
`FOUNDRY_INVARIANT_FAIL_ON_REVERT=true` is explicit. This is still bounded
exploration, not exhaustive transition or source-unit proof.

Ordinary seed is `0x24a3`. The six exact ordinary roots are
`DETFFundedStakingMath.t.sol`, `FundedStakingSequence.t.sol`,
`V4FundedBindings.t.sol`, `prod-se/UniswapV4Detf_Weighted_Univ3Se.t.sol`,
`UniswapV4Detf_Weighted_Alignment_FeeCreatorClaim.t.sol` and
`UniswapV4Detf_Weighted_Adversarial_TrustFlags.t.sol`, with full paths in
the command records. The eight suites include actual CP sequence and
weighted/orbital/curve binding tests; this is not the broad aggregation
root or the whole ordinary repository.

Fresh pre-build Solidity diagnostics returned no diagnostics for all eight
new files. Forge is 1.9.1-nightly,
`430523103f3e2f9ba432ffdd2031a9f966153d0d`.
Artifact compiler identity is
`0.8.38+commit.e7a91fc7.solar.0.3.0-dev`, optimizer enabled/runs1,
viaIR false. No size override was supplied. Existing nightly/configuration
and compiler warnings remain unsuppressed. JSON Biome is unavailable;
JSON evidence is directly parsed, not represented as editor-clean.
Nothing was installed.

The initial overly broad whitespace check also included generated raw
compiler logs and failed on their original trailing spaces. Its complete
failure remains in `whitespace.log`; those logs were not normalized or
edited. The correctly scoped check of all eight candidate sources and
authored Markdown/JSON passed, recorded in `authored-whitespace.log`.

### Generated selector calls and nonvacuity

| Native selector | Calls | Legacy selector | Calls |
| --- | ---: | --- | ---: |
| activate | 38 | changeOwner | 47 |
| advanceTime | 52 | claimWeighted | 46 |
| claimPrincipal | 43 | convert | 45 |
| claimRewards | 42 | donate | 42 |
| configure | 45 | failedIssuance | 43 |
| failedBatch | 34 | failedRecoveryBatch | 48 |
| issue | 44 | redeemSy | 43 |
| market | 39 | surrender | 51 |
| providerRateChange | 36 | takeNft | 42 |
| rejectRoleRewards | 60 | transferAndReject | 49 |
| transferBond | 41 | unstake | 56 |
| transferOwner | 38 | Total | 512 |
| Total | 512 | | |

Every table row has zero unexpected reverted/discarded handler calls.
Expected SUT errors are caught only by exact declared error assertions.
Empty-domain handlers sometimes execute another real prerequisite action;
the selected-selector count is therefore not a count of successful
operations of that selector's nominal name.

The retained native sequence reports 17 successful actions, seven exact
rejections, four zero-valued claims, one market group and three ownership
transitions. Its separate deterministic witness reports 13 successful
actions, eight rejections and two zero-valued claims. The retained legacy
sequence reports 23 successful actions, 13 rejections, one committed
funded-bond callback, three late-failure rollback witnesses, four batch
rollbacks and 12 recovery stages. Its deterministic witness reports
16 successes, four rejections, two callbacks, one late rollback, one batch
rollback and nine recovery stages.

**These handler counters include the prelude and describe individual
retained states, not sums across all 32 sequences.** Callback increments
inside a reverted transaction roll back too. The logs do not expose
aggregate per-action success/rejection outcomes across every sequence;
none are inferred. Zero claims and already-consumed rejections are not
positive custody or payout witnesses.

Native setup deterministically configures/replaces an already-issued
recipient, exercises a late failing issuance batch, creates another real
funded bond, transfers a bond and owner, rejects funded Stage1 bond/role
rewards, trades, changes fees, donates and changes a real SE provider rate.
Its separate deterministic test successfully pays principal at the exact
cliff, then activates and pays rewards/roles. Legacy setup deterministically
rejects Stage1 surrender, activates after an actual paid purchase, reaches
late receipt funding before a receiver rejection, transfers SY to another
holder and back, surrenders SY, rolls back a recovery batch, takes both
whole NFTs, and performs real staged recovery/donation. Its deterministic
test claims the weighted NFT and exhausts ordinary-SY Q/C exactly.
These successful paths do not depend on random selector luck.

## 3. Real SUT, independent model and deployment identity

`TestBase_UniswapV4DetfMigration.sol:92-130,237-309` deploys the actual
manager/registry package path, CREATE3 facets, real weighted hook,
production SEs and actual bond/receipt/SY/reward children. The new fixtures
inherit that path, not a subclassed SUT. Mintable external currencies,
native test funding and external liquidity seeders are non-SUT fixtures.
No SUT mock, etch, storage injection, substituted source code or
SUT impersonation appears in the new files.

`TestBase_MigrationStateful.sol:24-45` retains the first proxy and its
actual snapshot/children before `_deployMigration` changes the fixture's
hook member. A second independently funded proxy is then adopted.
The two native subjects have distinct parent, hook, bond, receipt, raw-SY,
staking-SY and reward-token identities. Their package and registry are
shared deliberately. They initially share `migrationOwner`; actual owner
transitions subsequently change only the active subject. This is not a
claim of two different initial owners in this new fixture.

The native model starts from known action inputs, initial gons divisor
1e36 and three pre-mutation quote anchors. It independently calculates
principal/gons, weight top-ups, funded reward allocation, rebase floors,
dust, claimed amounts, holders and starts. `BondTypes` supplies ABI structs;
the new ledger does not call the SUT's staking-math functions.
Configuration IDs are independently encoded from inputs and domain.
Issuance records remain distinct from replacement configurations.

Initial nonlinear quote correctness is not independently reimplemented by
the handler: its anchors and paid-purchase quote come from public initial
SUT pricing. They prove subsequent immutability and consistent accounting,
not correctness of the original pricing algorithm by themselves. The
complete existing snapshot gate supplies separate differential coverage.
The high mint threshold deliberately holds subsequent expansion at zero;
only the initial actually funded paid reward changes the native index.

The legacy ghost tracks ordinary-SY Q/C, delivered credit, wallet holdings,
SY custody, attributed WS gons, WD, DTF recovery, protected donation,
spendable protocol residual and new escrow separately. Conversion outputs
are measured external-token receipts, not the parent inventory being
asserted. Weighted NFT principal/rewards are computed from the actual
external source position before recovery. Initial observed external books
are seeds, not mutable current-SUT postconditions.

The earlier donation counterexample is a legitimate model correction:
`UniswapV4DetfMigrationPolicy.sol:32-49` excludes recorded protocol
residual from the protected floor, and
`UniswapV4DetfMigrationRecoveryTarget.sol` releases selected recovery into
that budget. The corrected bound is selected recovery plus previously
recorded spendable residual, not selected recovery alone. The separate
1e18 protected DTF donation remains a floor. No production guard was
weakened.

Fresh offline binding independently derives 179 artifacts from the union
of actual expanded build roots, nine specified foundational artifacts and
the two executed invariant-test artifacts. All 970 unique compiler-source
Keccak comparisons match current raw source bytes; all eight candidate
files are included. There are no conflicting source hashes.

All 522 raw runtime captures were independently decoded from fresh logs,
covering 66 unique address/runtime pairs and six subject records.
Every runtime matches a current artifact, permitting substitution only at
compiler-declared link/immutable spans and requiring repeated values to
agree. Whole remaining bytecode, including metadata, matches; no arbitrary
masking or metadata stripping occurs. The two logged native submitted
package tuples decode through the current actual `deployVault` ABI and
bind their owner and captured main hook.

`source-artifact-deployment.json` retains artifact/source identities,
all capture locators, exact substitutions and decoded subjects/arguments.
These are actual in-process Foundry deployments, not independently
authenticated signed constructor transactions or mined receipt archives.
Not every linked library's runtime is separately captured. Warm
artifact/cache and host-dependency provenance is retained; no cold or
portable reconstruction follows.

## 4. Twelve-property assessment

Abbreviations, all repository-relative:

- N: `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/invariant/MigrationNativeHandler.sol`
- B: the same directory's `MigrationNativeLedger.sol`
- L: the same directory's `MigrationLegacyHandler.sol`
- R: the same directory's `MigrationLegacyRecoveryHandler.sol`
- NS: `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/migration/invariant/MigrationNativeInvariant.t.sol`
- LS: the corresponding fork directory's `MigrationLegacyInvariant.t.sol`

Each invariant boundary calls `assertAll`; handlers also assert after
their completed actions. The random results below refer to the actual
32/16 runs, not the producer's earlier 16/8 runs.

| Property | Independent expectation and actual assertions | Successful witness / random actions | Coverage qualification |
| --- | --- | --- | --- |
| 1. Original-wallet frozen-credit conservation | L:95-108,203-213 maintains Q/C recurrence, actual holdings separate, consumed+remaining Q=8000 and delivered+remaining C=C0; terminal takes exact residue | Mandatory partial custody and transfer/return; LS:99-108 exhausts credit; 51 selected surrender calls and 49 transfer/rejection calls | Confirmed for ordinary native9 SY. Not standalone gon/internal-share/native19/native28/LP conservation; those stateful unit models are absent. |
| 2. Configured original wallet and actual eligible asset | L:131-147 asserts exact wrong-wallet error after a real transfer; missing-record error in exhausted branch; economic digest and full ledger restore. Both NFT inputs bind actual historical original wallets | Mandatory real different-holder rejection and successful return/surrender; both whole NFTs are actually surrendered; existing `MigrationOriginalWallet` and SY missing/approval/balance suites pass | Wrong-wallet path is mandatory. The new missing-record branch is conditional on exhaustion, not a separately guaranteed mandatory action; deterministic existing tests supplement. No arbitrary wallet enrollment or claim-origin inference. |
| 3. Corrections cannot alter execution | N:43-94,258-274 separates input-derived replacement from immutable issuance config/credit/ID/time; B:161-190 checks existing funded positions and backing | Mandatory correction of already-issued actor, then another actual issue; 45 configure and 44 issue selections | Confirmed for Stage1 independent corrections. Legacy consumption cannot coexist with mutable Stage1 configuration; all legacy surrender is Stage2-only. No partly consumed correction policy is invented. |
| 4. Every credit has custody or independent authority | N:72-94 records authorized independent inputs; L:95-108,150-176 maps measured SY input or selected whole NFT fraction to a fresh funded bond; L:221-234 checks exact supply/backing/gons | Mandatory independent issuance, partial SY and both NFT creations; 42 takeNft selections, with duplicates rejected | Confirmed action witnesses, but not a complete independent continuous NFT-custody oracle: L:236-242 checks consumption/recorded custody, not actual legacy `ownerOf` after every action. Weighted subsequent recovery and existing deterministic `_surrender` tests check actual ownership. Earlier NFT has no new recovery action. |
| 5. Failed issuance leaves no debit/consumption | N:98-117 models failing second issuance item and unchanged funding; L:115-128,193-200 reaches real receipt funding then exact invalid-receiver error and unchanged SY allowance/custody/Q/C/supply/backing/NFT balance | Both failures are mandatory before randomization; 43 failedIssuance and 48 failedRecoveryBatch selections; retained legacy state has three late rollbacks | Confirmed ordinary-SY late receiver and independent-batch atomicity. Callback state inside the failed transaction is not a committed callback count. Earlier source preparation transactions are outside parent rollback. |
| 6. Funded staking value covers remaining principal | B:93-190 independently calculates exact whole staking state, actual backing, attributed gons, each position and solvency; L:172-176,221-234 tracks fresh legacy principal and fixed index | Actual paid first bond funds rewards; independent and surrender positions are funded, with real claims/transfers | Confirmed bounded native ledger and fresh legacy bonds. No randomized arbitrary expansion or post-issuance legacy claim/index-growth model. Paid ordinary bond is included in solvency but not selected by the new claim actions. |
| 7. Each migration bond respects its own cliff | B:129-182 uses independent creation+90days, exact claims and zero pre-cliff due; NS:24-30 pays zero before, full at the cliff | Mandatory exact-minus-one/exact-cliff witness; 52 time and 43 principal selections; later native issuance records its own start | Confirmed first two independent compensation positions and recorded fresh starts. Claims select only positions0/1; later-issued positions are checked but not actively claimed by new selectors. Legacy handler never warps. Existing delayed NFT/SY tests supplement fresh surrender clocks. |
| 8. No Stage1 new-instance reward payout | N:169-207 declares exact closed errors for actual funded bond and role rewards; B preserves full backing/gons and wallet ledger | Mandatory paid reward funding and Stage1 rejections; deterministic activation followed by actual reward/role payout; 42 reward and 60 role selections | Confirmed direct bond/role state machine. Receipt/SY/RT/combined/egress routes and distinct creator-history behavior are existing deterministic supplements, not newly randomized actions. |
| 9. Stage2 cannot restore allocation authority | N:120-145,248-279 checks actual stage and all14 interface-derived selectors absent after activation; former configure/issue/activate calls assert exact NoTargetFor | Real activation and repeated attempts; ownership transitions and market/claims continue; 38 activation selections | Confirmed bounded public administration probes. Package/init/update restoration probes are in existing `MigrationSurface`, not a new arbitrary-execution state machine. |
| 10. Live market changes cannot reprice configured originals | N:211-244 trades real hook inventory, changes oracle fee, donates reserve capital and changes actual SE backing/provider rate; N:263-269 preserves whole snapshot and three initial quotes | Each market category is mandatory; 39 market and 36 provider-change selections pass | Confirmed fixed initial contribution sizes and bounded inputs. Initial quote anchors are observations, not an independent nonlinear-pricing oracle; no all-domain claim. |
| 11. Recovery reconciles per asset/stage and fixed destination | R:25-106 tracks SY->WS gons->WD->DTF->donation, measured output, exact budget recurrence and allowance reset; R:110-172 checks whole-batch rollback and beneficiary balances; L:203-224 reconciles actual balances | Mandatory redemption/unstake/conversion/donation and failing selected batch; deterministic weighted claim and terminal recovery; random recovery actions pass | Confirmed weighted recovery at fixed pin/rate and protected DTF/residual partitions. Earlier-NFT claim/sale, changing legacy divisor, unrelated WS fractions and other source-unit recoveries remain existing deterministic supplements. No cross-unit total is fabricated. |
| 12. Owner changes preserve pricing, registry, bonds and consumption | N:130-160,258-274 maintains expected current owner, unchanged registry owner, full snapshot/issued facts and separate-instance hash; R:126-138 changes owner and exactly rejects former owner while L checks consumed credit | Mandatory and random owner changes: 38 native and47 legacy selections; real bond transfers and old/pending-owner rejection | Confirmed bounded isolation. Native isolated instance is passive and starts with the same owner; state hash covers its owner/hook/bond/receipt/snapshot/allocation/issuance/supply/staking/bond3, not every possible external or child state. Shared external SE valuations may change. |

These qualifications are material. In particular, recorded NFT custody is
not by itself an independent proof of persistent actual custody, and
checking a later bond's stored start is not exercising a withdrawal from
that later bond. Existing green deterministic coverage strengthens the
bounded result but does not turn those checks into new stateful coverage.
No mutation experiment was performed because existing-source edits are
forbidden in this verification.

## 5. Source/unit boundary

The fixture selects Robinhood chain4663, L2 block108944663, hash
`0xc497433dd691a40cb85959cfeba2e3fff85a975ae060612d984998e1d5765733`.
`MigrationNftForkBase.sol:45-79` verifies header/hash/state root, Orbit L1
block number26367659, NFT proxy/facet hashes and routes.
`MigrationRecoveryForkBase.sol:27-58` verifies weighted/earlier recovery
facets and selectors. Existing `MigrationRecoveryWeightedSy.t.sol`
also binds the actual SY redeem/transferFrom facet and code hash.
All are executed through the approved login-shell alias
`robinhood_mainnet_alchemy`; no alternative provider or local node is used.

| Source/unit | New stateful status |
| --- | --- |
| W-Y ordinary SY/native9 static shares | Dedicated Q/C custody ledger; synthetic original contract wallet Q0=8000, E0=0.01ETH, D0=0. Actual holder transfers source tokens. |
| W-N/native9 original less paid principal, whole NFT | Actual configured historical NFT4, whole identity, frozen proportional credit and later weighted recovery. |
| E-N/original LP accounting shares, whole NFT | Actual configured historical NFT3 and full-share credit; no physical-LP/principal substitution. No new earlier-recovery selector. |
| WS recovery gons / WD native9 / DTF native18 | Separate recovery ledger after SY redemption or weighted NFT claim. Not standalone W-R original-unit surrender coverage. |
| W-L/native9 liquid original | No dedicated new stateful original handler; complete current deterministic suite passes. |
| E-L/native18 liquid original | No dedicated new stateful original handler; custody-only/disabled-exit qualifications retained. |
| W-R/exact original gons with native9 transfer | No dedicated new stateful Q/C handler or nonrepresentable-residue model. Existing deterministic changed-rate tests remain distinct. |
| E-R/exact internal shares versus floored external shares/native18 display | No dedicated new stateful model. Not inferred from SY or NFT accounting shares; positive nonrepresentable residue remains accounted. |
| C/direct native19 claim-vault shares | No dedicated new stateful original/redeem model; existing deterministic source tests pass. Infrastructure backing is not another user claim. |
| W-SD/native28 source shares | No dedicated new stateful original/recovery handler; retained actual deterministic source archive/route evidence. |
| W-SW/E-P/W-P/native18 held sources | No dedicated new stateful original model; deterministic custody/credit passes, blocked conversion and EOA-owner-release fixture qualifications persist. |
| E-S | Still unsupported/unadmitted for positive integrated original custody; not declared absent or interchangeable with another native18 source. |
| T/raw native18 TokenStaking weights | No direct ordinary-Migration atomic approved-pull/callback admission. Not replaced with ordinary-SY stateful coverage. |
| Complete-original claimed SY | Existing three Foundry cases pass as deterministic supplements. New ordinary-SY callback is not claimed-source evidence. |
| Standalone ETH/WETH exposure | No newly admitted original unit/consumption route. Existing contribution inputs and permissionless donations do not supply one. |

Historical original E0/D0, eligible units, original-wallet identity,
known-zero prior delivery and non-overlapping economic origin remain
reviewed input boundaries. Real current source balances or fixture donor
calls do not prove historical eligibility, donor signatures, donor-key
control or public consent. Neither fresh funding nor source rewards become
additional personal original contributions.

Complete-original claimed-source admission remains the prior **direct
signed EOA, canonical isolated-source-block subset** with complete reviewed
originals and known-zero prior compensation. No claimed contract-wallet
preparation, delegation, certificate authentication or CLI replay occurred
here. The ordinary-SY contract callback reaches the shared actual funding
path, not that direct-EOA preparation boundary. Earlier committed raw
claims cannot be restored by a failed later SY surrender.

## 6. Adversarial applicability

| Case | Actual new evidence / supplemental boundary |
| --- | --- |
| A0 | Native real donation/bootstrap precedes first independent issuance; bootstrap self-leg is separate from personal principal. Existing genesis suite passes. Not every source's first-depositor domain. |
| I1-I3 | Inherited ordinary pretransfer surfaces apply. Focused weighted trust-flag regressions pass; no new randomized pretransfer selector is claimed. Legacy surrender uses approved measured pull, not a public trusted-pretransfer flag. |
| J1-J3 | All new money calls target real proxies;14 administration selectors are interface-derived and checked before/after cut. Existing Behavior-based surface/package tests pass. No new production facet was introduced. |
| K1 | Donations do not amend original Q/C or authorized independent credits; protected DTF and spendable residual are distinct. Existing ordinary donation-not-credit test passes. |
| E6 | No caller-selected surrender/recovery refund beneficiary exists on the new action surfaces. Actual donation debit is bounded by selected recovery plus prior protocol residual; protected inventory survives. Ordinary trust-flag regression remains separate. |
| N1 | Ordinary-SY funded-bond receiver attempts nested surrender and activation, requiring exact IsLocked/NoTargetFor; late invalid receiver restores economics. No claimed-origin or every-unit callback inference. |
| Fee/creator nondilution | Independent native weight/rebase/dust/role model plus actual gated payout; existing retained-accounting and ordinary fee/creator tests pass. New native fixture uses creator fallback rather than a randomized distinct-creator transfer model. |
| Source spoofing | Fixed actual addresses and pinned routes; complete configuration/source negative suites pass. New handler does not randomize arbitrary source aliases. |
| Wrapper double-credit | New source units and recovery stages remain separate, but no cross-representation original-enrollment state machine is added. Existing canonical-origin exclusion tests supplement; opaque documentary aliases remain a reviewed-data limit. |
| NFT claim/surrender races | Both real whole NFTs enter the new prelude; weighted claim follows custody. Actual competing pre-custody claim/race/empty cases remain existing deterministic NFT suites, not new random race actions. |
| Activation reentrancy | Ordinary-SY callback occurs after activation and checks absent activation selector. Existing native callback/owner-first tests cover preactivation busy-child behavior; no false claim that the postactivation callback tests partial activation. |
| Custody batch failure | Mandatory real SY redemption first item followed by exact insufficient-WD second item restores custody and parent state; independent issuance has its own late second-item rollback. |

## 7. Evidence method, limits and cleanup

Raw independent logs retain every warning and test result. There is no
independent failing test/counterexample to suppress or repair. Producer
failed attempts are preserved and are not relabeled as independent passes.
The initial attempt to parse an elided read-tool JSON view failed in the
inspection tooling; it was replaced with the complete raw-text helper
before admission. That was not a build/test result.

`admission.json` and `preservation.json` retain per-entry original
comparisons. SHA-256 and lengths for these UTF-8 evidence/source documents
match the producer's raw identities. One narrower evidence limitation is
explicit: the initial Git-index digest in `execution-plan.json` was made
over the read helper's decoded string, not raw binary index bytes.
`preservation.json` labels that comparison accordingly; it is not a raw
index-byte attestation. Actual initial/final cached and unstaged Git
comparisons are empty, the owned HEAD/ref text is unchanged, and no
index/ref-writing command was used. No comprehensive foreign-index/ref
audit or held-lane read is claimed.

For reproduction of the offline binding, derive explicit source roots
before the first `--skip` on each actual expanded build command, enumerate
matching `out/<basename>.sol/*.json` compilation targets, add the nine
foundation identities listed in the audit and both invariant-test
artifacts. Compare every metadata source's declared Keccak with current
bytes. Decode STATEFUL_SUBJECT and STATEFUL_RUNTIME from the retained raw
logs, match whole runtime templates, and substitute only compiler-declared
immutable/link spans while checking repeated values. Exact artifact hashes,
spans, source hashes, line locators and decoded arguments are retained.
This algorithm was independently executed in the persistent kernel; it did
not run a producer PASS flag or producer audit runner.

`cleanup.log` records unchanged audited HEAD/branch, empty tracked/index
diffs, no18574 listener and no matching test/build/artifact-helper/owned-node
process. All three owned monitors exited0. No Anvil, CLI, checkpoint,
subscription, impersonation session or delegated operation was started or
left pending. Warm `out/`, `cache_forge/` and dependency links remain; no
cross-worktree copy-back or dependency cleanup was performed.

All authored files are exclusively under this `verification/` directory.
`seal.json` binds its complete final evidence membership, excluding only
itself, along with the unchanged candidate and producer seal. Normal
ignored build/cache outputs come from the explicitly authorized checks.

This report does not close full-plan/all-source stateful acceptance,
full-repository hermetic testing, source/archive portability,
operational-original/allocation approval, raw/partial/prior-delivered
mapping, E-S or blocked conversions, or deployment gas. The retained
registration observation45,116,678 exceeds32,000,000; no gas run or solution
is attempted here. No public deployment, funding, activation, award,
provider or IPFS operation is authorized by this result.

**Confirmed bounded stopped candidate; complete twelve-property/all-unit
closure remains open with the precise stateful gaps above.**
