# Fixed weighted SY implementation and bounded verification

Date: 2026-11-11.

**Producer disposition: confirmed for this bounded weighted SY increment.**
All required final checks passed: 115 current Migration specs, 61 pinned
Migration forks, 59 operator tests in one run, strict TypeScript, artifact
preparation and both operator stages, and the actual fixed18564 CLI. The CLI
includes new WY receipts and all three preserved mined-before-checkpoint
resumes. There is no remaining blocker within this increment. Independent
phase14 verification remains a separate lane; this is not its verdict.

**Source modifications have stopped. No owned runtime remains.** No commit,
merge, public transaction, dependency/configuration edit, provider reroute,
ordinary/common/Crane production edit, or held phase09 inspection/import/replay
was performed. This report does not claim full-category Migration completion
or target-gas/public deployment acceptance.

## 1. Admission and authority

- Worktree: `/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-14-weighted-sy`.
- Branch: `work/dtf-migration-phase-14-weighted-sy`.
- Exact unchanged HEAD/base: `75d513cb8b36e53f14c8aa3a352f21703ad91ba1`.
- The initial tracked/untracked source state was clean. Root-provided warm
  `out/`, `cache_forge/` and the existing Crane dependency link were present.
  Plain Git status rejected the prescribed submodule symlink; the explicit
  `--ignore-submodules=all` status succeeded. No dependency was changed.
- Current main plan r5 SHA-256:
  `60d02b608c8a10f19cffce7b99838146c205a98410641e9bce45944e620dc56d`.
- Current main PRD r22 SHA-256:
  `cfe1853f49de0dc41ae106f1cc1b94eacd24d4aa8f79477c66a5b7f24a4d67ed`.
- Phase14 brief SHA-256:
  `6fd8d01b1f279a1245ac70ce68e7b1918df9cf41e53324bbedf6d2f51415b384`.

The complete phase11 weighted contract and independent report/matrix, phase13
owner-first-bond directive, independent runtime report and commit audit were
read. Their exact absolute paths, bytes and hashes are bound in
`input-snapshots.json` and `bindings.json`. Historical r3 preactivation
surrender/amendment language is superseded by Stage2-only surrender and the
on-chain owner-paid first-bond prerequisite. Those settled requirements were
not reopened. No historical evidence was overwritten.

## 2. Scoped implementation

The 33 changed/new source, test, operator and runbook paths are enumerated with
raw hashes and complete exact-text snapshots in `source-snapshots.json`.
The production delta is confined to nine existing Migration files.

| Surface | Delivered behavior and proof |
| --- | --- |
| Migration interface/repo/allocation target | Separate WY configuration and consumption records; fixed chain/source; nonzero original wallet, canonical origin, evidence and Q0; explicitly known ETH and DTF components. Full-value idempotent Stage1 replacement computes C0 on the existing frozen book and mints nothing. |
| Canonical overlap | WY checks WD, both NFT families, configured independent origins and already-issued independent origins. Existing WD/NFT/independent setters and issuance reject configured WY origins in the reverse direction. Wallet corrections do not create a new origin. New configuration specs cover both NFT families and WD in both directions. Opaque aliases still require operational economic reconciliation. |
| Permanent target/facet | Four new retained WY query/preview/surrender selectors. Surrender rejects in Stage1, then requires the configured original wallet and real approval-based exact WY wallet debit/proxy receipt. It consumes only q and its proportional credit, books only the new shares, and funds one fresh 90-day cliff bond atomically. Final surrender receives all remaining credit. |
| Activation | The new loader is included in the actual irreversible eight-selector cut. Paid owner-first-bond enforcement, child-idle checks, normal registry guards and parent reentrancy lock remain intact. The live proxy exposes the retained WY selectors after activation but neither identical nor changed loader calls work. |
| Legacy recovery interface/lib/target | Append-only `WeightedSyRedeem` ordinal8 uses the existing owner-only selected `recoverMigrationNfts` API. No user-selected source, receiver, calldata or pretransfer mode is introduced. It debits booked WY, calls the authenticated legacy redemption, checks exact share burn and measured WS gon receipt, and feeds only those gons to existing unstake/conversion/donation accounting. |
| Operator | Required `weightedSy` array, exact proofs, source/unit validation, origin partitioning, frozen quote, ABI/configuration identity, review mirror, typed stages and receipt-block reconciliation. Unsupported categories remain explicit. Fixed port18564/checkpoint and the three existing resumes are preserved. |

The fixed source identities are chain4663 WY
`0xB55604CF4dcdABB362078e106D20F98512391EdF`, WS
`0x4Fa4974a8a09660258B8edD430B51C1620eBFE5c`, and WD
`0x4a5cFDC2b07016FCf917f4eD5A51C52111A0fcC7`.
Historical source pin: block108944663, hash
`0xc497433dd691a40cb85959cfeba2e3fff85a975ae060612d984998e1d5765733`.

Actual archived WY `DETFSYTarget`, `DETFSYRepo` and staking math were read,
not replaced by today's common ABI. The route is
`redeem(MIG,shares,WS,minimum,false) -> uint256`. It burns caller-owned
static shares without a redemption allowance. After synchronization at k:

`receiptUnits = floor(shares * floor(10^54 / k) / 10^18)`.

Received gons must equal `receiptUnits*k`, the wrapper's actual gon debit,
and the proxy's operation-local gon increase. The difference
`shares*10^36 - receivedGons` stays as legacy conversion dust, not Migration
inventory or credit. No pre-sync display-balance subtraction is used. Existing
NFT-attributed gon revaluation, unbooked-gon floors and full-account fractional
retirement protection remain in force.

The chosen implementation preserves the finite source-specific WY ledger and
appends one recovery stage. It rejects the alternative of admitting arbitrary
wrappers or crediting WS display units, current growth, raw balances or backing
again. Synthetic original records are test inputs only; no operational dataset
or historical allocation amount is inferred from a holder's balance.

## 3. Final checks

Every final top-level check below exited **0**. Exact commands, monitor IDs,
compiler versions and qualifications are in `checks.json`; full logs are
retained. All compiling Forge commands use Solar with actual edited roots.

| Check | Result | Evidence |
| --- | --- | --- |
| Artifact-first all current Migration specs | 115 passed, 0 failed, 0 skipped | `specs.log` |
| Artifact-first all current pinned Migration forks | 61 passed, 0 failed, 0 skipped | `forks.log` |
| Artifact preparation and both operator stages | Both stages build successfully | `operator-artifacts.log`, `operator-stages.log` |
| Four operator test files, one invocation | 59 passed, 0 failed | `operator-tests.log` |
| Strict TypeScript | No diagnostic output | `operator-types.log` |
| Actual pinned fixed18564 CLI | `bounded-rehearsal-complete` | `rehearsal.log`, run directory below |
| Production-root LSP and final whitespace | No production diagnostics; diff check passed | `checks.json`, `cleanup.json` |

Forge is 1.9.1-nightly commit
`430523103f3e2f9ba432ffdd2031a9f966153d0d`; executed Bun is 1.4.2.
Compiler warnings remain visible and were not suppressed. An initial fork
shell wrapper exited127 because outer quoting expanded PATH incorrectly; the
corrected single-quoted login command passed without any provider/test change.
The Solidity definition request timed out; actual reads/builds supplied the
trace. JSON LSP could not run because Biome is absent; no install was attempted.

`coverage.json` records every passing test name. New coverage includes
Stage1 closure, frozen/idempotent loaders, both-direction collisions,
partial/final conservation and fresh funded clocks, missing/wrong wallet,
transfer-away/back, zero-credit dust, approval/balance/minimum/deadline
negatives, real receiver callback/funding rollback, authenticated selected WY
redemption, source synchronization/growth/dust, mixed NFT/unsolicited gons,
booked WY floors, downstream batch rollback and fixed-destination donation.
No legacy balance/role/bytecode or SUT replacement was used. The inherited
full-account fractional-retirement and owner-bond suites passed unchanged.

## 4. Actual local receipts and accounting

Run: `rehearsal-1794436891742/`.
Migration proxy: `0xedf7d9f65b9e57d62a3c4278223170db1308f5f0`.
Funded frozen snapshot:
`0x7804bb73ba39748941a6ff851d975a2c721b20608565a7ee94ec0980b782c96f`.
This funded quote snapshot is distinct from the historical source block.
`runtime-index.json` joins observations to actual receipts, decoded events,
raw source transfers, input identities and independent integer recomputation.

The synthetic WY configuration initially used Q0=8094 and ETH input
10000000000000000 wei, then replaced it in Stage1 with Q0=8087 and ETH
6000000000000000 wei; DTF was explicitly known zero. The final frozen C0 is
**2,774,608 native new-DETF units**. Seven actual WY shares were sent
unsolicited and never booked. Stage1 configured and unconfigured surrender
both have mined status0 receipts with unchanged custody/credit.

| WY operation | Shares | Credit | New bond | Remaining Q/C |
| --- | ---: | ---: | ---: | --- |
| Partial surrender | 2,695 | 924,640 | 14 | 5,392 / 1,849,968 |
| Final surrender | 5,392 | 1,849,968 | 15 | 0 / 0 |

Partial receipt, block108945068:
`0x0711c3387a3665644ee9b7adfe33e8127f70ac978984023eb96d2af405151d06`.
Final receipt, block108945084:
`0x0bdaafba898e5bdafa9c5119b6618b210416c1d70d328e357135714226aaa163`.
Bond starts are simulated timestamps1825676198 and1825762613; both durations
are7,776,000 seconds, with exact new funding and credited gons. They are local
simulated times, not public issuance dates. Partial credit independently
recomputes to floor(2774608*2695/8087)=924640; final credit takes all residue.

| Selected recovery | Partial | Final |
| --- | ---: | ---: |
| WY burned | 2,695 | 5,392 |
| Actual WS units, then WD units | 3,464 | 6,933 |
| Actual received WS gons | 2694800045855751443569029647568368920312 | 5391765145875320612919484094232856980498 |
| Synchronized divisor | 777944585986071432900990083016272783 | 777695823723542566409849140953823306 |
| Legacy conversion dust gons | 199954144248556430970352431631079688 | 234854124679387080515905767143019502 |
| Actual DTF recovered | 18567816538858246 | 37162598069939777 |
| DTF donated | 9283908269429123 | 18581299034969888 |

Redemption receipts:
`0x435fe31d30e2e260d22c048952453fbb377776f9594d4fe3409a774e57c58504`
and
`0xb81f7319e2a83d075022d2388b421e7062f75e96b16c1022c194abd84ee0813c`.
The separate unstake, conversion and donation hashes are in the runtime index.
Both selected recovery failure transactions are mined status0, emit no logs,
and leave the recorded WY/gon/WD/DTF state unchanged; their subsequent valid
stages succeed. Recovery does not change compensation, its bond, or new-bond
backing. The CLI keeps seven unbooked WY shares and its unrelated DTF floor;
the pinned mixed-inventory fork separately proves preservation of preexisting
NFT-attributed and unsolicited WS gons through growth and staged exits.
Historical8094 WY ->9245 WS remains an archived observation, never a hardcoded
current quote.

### Preserved NFT, W-L and owner purchase

The existing sequence still creates W-L partial bond7; weighted NFT4 bond8;
returned-to-original-wallet weighted NFT26 bond9; earlier NFT3 bond10; late
weighted NFT6 bond11; late earlier NFT9 bond12; and W-L final bond13.
Their actual credits are924869,13872781,22233172691,923391925,36992599,46243,
and1849739 respectively. All nine actual NFT/W-L/WY surrender receipts are
strictly after activation and are indexed individually.

Owner purchase remains ordinary paid bond6: actual payment10^18 units,
principal465583908, funded rewards84489332, and backing1383 ->550074623.
Independent issuance alone first fails activation. Successful activation
`0x975c8acd0ba75ca1fe5e495d2d3259f7bc6841c9927003c1d57bae89267a6727`
emits eight removal events plus activation, and actual selector reconciliation
checks all eight absent. A subsequent nonowner ordinary deposit returns
462096413 units with no refund. Three independent recipients receive bonds3-5
of461 units each; the fourth remains unissued with bondID0. The old NFT recovery
now observes103959868 original receipt units plus11892 later-accrued units,
not stale earlier totals. Earlier sale-and-hold remains distinct from liquidation.

### Three mined-before-checkpoint resumes

| Interrupted operation | Nonce | Actual canonical transaction |
| --- | ---: | --- |
| Donation | 2118 | `0x3263410c17724c8b48ddece7feea6c2ea648cd2dbd07e66e99e46582e0912864` |
| Independent issuance | 2132 | `0xf3605c3be19c5e468608dc873ed6026ad7163e36f31d8c4af62a25280a09f1cf` |
| Owner purchase | 2148 | `0x1a230943942d0636fff2abe5ec4ada744c67fd63a0e9f1442a652e2797a5f5a5` |

Each interruption retains a successful mined receipt with no completion file;
the signed hash/nonce and resumed receipt are independently compared. All three
fresh-process resumes recover the identical transaction, not a second payment.
Outstanding independent rows reverse order. Owner purchase resumes read-only
and twice in execution mode without another purchase nonce.

The run has43 successful operator receipts,163 fixture receipts and47 command
records. Its60 mined fixture failures, six controlled DOMAIN rejections and
three intentional SIGKILL interruptions are expected negative witnesses, not
failed acceptance checks. Every required top-level check exits0.

## 5. Final immutable bindings

- `bindings.json`:33 source files,95 exact final artifact JSON identities,
  nine authority inputs, three historical archive bindings and361 evidence
  files, including all raw receipts, journals and command records.
- `source-snapshots.json`: complete UTF-8 source contents and hashes. All33
  current source files still match the pre-rehearsal snapshots exactly.
- `input-snapshots.json`: complete authority snapshots and actual archived
  WY target/storage/math source extracts with their original archive binding.
- `source-artifact-runtime.json`:701 distinct compiled-input keccak256 checks
  match final current bytes across95 bounded artifacts, including47 test-target
  artifacts. No raw artifact JSON changed during the CLI. Eleven Migration
  parent/package/child implementations match captured runtime, masking only
  compiler-declared immutable/library spans and retaining their observed values.
  All 31 captured runtime records match their code hashes. Untouched generic
  captured code is hash-bound, not separately bytecode-matched in this report.
- `runtime-index.json`: decoded new and preserved receipts, actual configuration
  and snapshot identity, independently recomputed WY quantities/gons/dust,
  activation, owner-purchase facts and all three resume comparisons.
- `seal.sha256`: seals this report and the binding/index/snapshot/check files;
  the report and manifest do not recursively hash themselves.

Only producer-owned `implementation/` evidence is authored. Independent
`verification/` remains untouched. No passing claim relies on stale phase13
artifacts, the held phase09 candidate, source hashes alone, or a simulator
success standing in for an actual receipt.

## 6. Cleanup and limits

The CLI stopped owned Anvil PID62267, closed providers/subscriptions, stopped
holder impersonation in finally blocks, copied journals to evidence and removed
the fixed checkpoint. External lsof and ps probes both returned exit1 with
empty output. Checkpoint-absence and final diff checks returned exit0. The
owned empty `.omo-runtime/dtf-migration-weighted-sy` parent was removed with
rmdir, exit0. All six final build/test/rehearsal monitors completed. Warm
artifacts and dependency links remain local and preserved.

Weighted receipt admission, earlier liquid/receipt, direct claim-vault shares,
raw TokenStaking rights, standalone SE/LP and native/WETH exposure remain
required categories with the phase11 matrix's original-record, unit, source
caller, disabled-exit and integration limitations. WY does not silently admit
raw TokenStaking rights or its backing as another compensation source.
No operational original-wallet/origin/Q0/component dataset is approved.

The actual local parent deployment used **43,517,419 gas**, transaction
`0xe477d5b29800a276a84c37f6bd824bb5c81627912d1ce896ddd40d386d8e20aa`.
It ran on the permitted100-million-gas local node and exceeds the retained
historical32-million transaction limit. This report is neither a target-gas
acceptance nor authorization for public deployment, funding or execution.
Ordinary/common/Crane production was unchanged; no full shared-category suite
or full-plan acceptance is claimed.

**Final bounded producer disposition: confirmed. Source modifications stopped;
no owned runtime or pending operation remains.**
