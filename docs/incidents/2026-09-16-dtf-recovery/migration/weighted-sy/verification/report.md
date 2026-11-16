# Independent weighted SY integration verification

Date: 2026-11-11.

**Verdict: confirmed for the bounded phase14 weighted SY increment.** No
needs-fix finding remains in this scope. Independent execution passed all
115 current Migration specs, all 61 pinned Migration forks, all 59 operator
tests in one invocation, strict TypeScript, artifact preparation and both
operator-stage builds, and the actual fixed-port-18564 CLI with all three
mined-before-checkpoint resumes. This is not full-category Migration,
operational-allocation, target-gas or public-execution acceptance.

**No verifier-owned runtime or pending operation remains.** Only this
verification directory's evidence was authored; no production/test fix,
dependency/configuration change, public operation, commit or merge occurred.

## 1. Admission, authority and frozen candidate

- Worktree: `/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-14-weighted-sy`.
- Branch: `work/dtf-migration-phase-14-weighted-sy`.
- Exact unchanged HEAD/base: `75d513cb8b36e53f14c8aa3a352f21703ad91ba1`.
- Root-supplied warm artifacts and dependency links were retained. Independent
  execution did not create another worktree or substitute an earlier base.
- The complete phase14 brief, current main plan r5 and PRD r22, phase13
  owner-first-bond directive, complete owner-bond independent runtime report
  and commit audit, complete phase11 weighted contract and independent
  report/matrix, complete new producer report, actual changed code, archived
  WY target/storage/math and actual historical receipt range were read.
- Historical r3 preactivation surrender and partly consumed amendment wording
  is superseded by Stage2-only surrender and the mandatory paid owner-first
  ordinary bond. Those requirements were not reopened.

Execution began only after the actual producer report explicitly declared
stopped source modifications and no owned runtime. Direct branch/base checks
matched; port 18564 was unused and the fixed checkpoint absent. The producer
report SHA-256 is
`29daaa4d0db079f656f62cb122f62eb6ada954082a523337850a4e557a8884e5`;
its bindings SHA-256 is
`53cef93e4cacb60dbd53cd51d72b0a33de42ebde3312c8efe634948df39fd342`.

| Current authority | Raw SHA-256 |
| --- | --- |
| Main phase14 brief | `6fd8d01b1f279a1245ac70ce68e7b1918df9cf41e53324bbedf6d2f51415b384` |
| Main plan r5 | `60d02b608c8a10f19cffce7b99838146c205a98410641e9bce45944e620dc56d` |
| Main PRD r22 | `cfe1853f49de0dc41ae106f1cc1b94eacd24d4aa8f79477c66a5b7f24a4d67ed` |
| Owner-first-bond directive | `29dca72edabe86612e98665a941d1f621cb7184e707bbfa841385fa779ccfb92` |

Independent admission recomputed **501 raw bindings**: 33 source/test/operator/
runbook files, nine authority inputs, three historical archives, 95 artifacts
and 361 producer evidence files. All match. All 33 complete source snapshots
match actual bytes; all nine producer seal entries match. The closing check
again matches all 501, including producer evidence and current authorities.
No producer or historical evidence was overwritten. `admission.json`,
`source-authority.json` and `artifact-reconciliation.json` retain each path
and comparison, not merely totals.

## 2. Actual legacy source and implementation review

Historical source domain is chain **4663**, L2 block **108944663**, hash
`0xc497433dd691a40cb85959cfeba2e3fff85a975ae060612d984998e1d5765733`.
It is distinct from this run's funded frozen snapshot
`0x990fc4a8d0871532186bb994b27a889c71085b7ef8e542e660bb35d887136aa4`.

| Identity | Fixed address / binding |
| --- | --- |
| WY, native nine-decimal static shares | `0xB55604CF4dcdABB362078e106D20F98512391EdF` |
| WS, rebasing receipt with canonical gons | `0x4Fa4974a8a09660258B8edD430B51C1620eBFE5c` |
| WD, native nine-decimal liquid DETF | `0x4a5cFDC2b07016FCf917f4eD5A51C52111A0fcC7` |
| WY transferFrom and redeem facet | `0x4B6e65CfC9a16aae0DfA4257A680f4697275e5fc` |
| Actual WY facet runtime keccak256 | `0x6da9227c829765d0464b5eeee02c55ea45883e3af2767aea546f5e906e8b143d` |
| Shared proxy runtime keccak256 | `0x2393ee3dc4d7877a9bfb7b59c272f2b9b0d1df92f2dc82ee67df076a99836601` |

The actual phase01 `weighted/probe.sources.json` archive was read, not a
current common ABI. Its archived onchain and recompiled WY runtime hash both
recompute to the facet hash above, with no transformations. The archived
DETFSYTarget, DETFSYRepo and DETFFundedStakingMath bytes match their snapshots
and metadata source keccak256 values. The old source's compiler identity is
solc 0.8.35; it is an archived deployed-source identity, not a compiler used
for this increment. Every current compiling command used Solar.

The authenticated call is
`redeem(MIG,shares,WS,minimum,false) -> uint256`, selector `0x769f8e5d`.
It burns the caller's own WY without a redemption allowance. At the source's
synchronized divisor k, native receipt output is
`floor(shares * floor(10^54/k) / 10^18)`; received gons are output*k.
The remaining `shares*10^36-receivedGons` is legacy conversion dust, not
new custody or compensation. Static shares, receipt display units, gons,
TokenStaking weights and claim-vault shares are not interchangeable.

The actual historical `verification/weighted-replay.results.json` lines
50241-50963 retain custody tx
`0xf5b647c938dffd6f1b7803769278ed7346b12150d437803461d00055db12405d`,
redemption
`0x618b9e42c948cbb8bec5496ab57211c784ccd503ec840f17cf5cb9c5a05bb7ab`,
unstake
`0xe90907636f9b4f5cb689af0d6ced6bc1111329195b443be28614fbae1a5fd38b`
and conversion
`0xa3491916815cc29e641eed88560a2ae0464ca6fb0434958a16fcdb16ed7ddaa4`.
Their 8094 WY -> 9245 WS -> 9245 WD -> 52221256856930805 DTF is a historical
observation, never a hardcoded current quote or approved allocation. The old
ancestry UNPROVEN result is retained under its superseded interpretation.

Here M denotes
`contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/`.

| Inspected source | Independent result and executed coverage |
| --- | --- |
| M/UniswapV4DetfMigrationAllocationTarget.sol:202-235 | Current-owner Stage1 full-value/idempotent WY replacement; fixed chain/source, nonzero origin/wallet/evidence/Q0 and both known components; frozen C0; no mint. Six new configuration specs pass, including bad-second-row rollback and current/pending/former owner checks. |
| M/UniswapV4DetfMigrationAllocationTarget.sol:55-235 | Both-direction WY/WD, either NFT and configured/issued independent-origin collisions reject. Wallet correction cannot evade a wallet-independent known origin. These guards do not prove opaque aliases economically disjoint; operational reconciliation remains required. |
| M/UniswapV4DetfMigrationTarget.sol:127-187 and Repo._fundBond | Stage1 rejects before pull. Stage2 validates matching record/original wallet/control, pulls exact approved shares, measures wallet/proxy deltas, consumes only q and remaining frozen credit, books only newly surrendered WY and creates one exact-funded fresh cliff bond atomically. All six actual WY surrender fork tests pass, including missing record, wrong wallet, return, allowance/balance/minimum/deadline/zero-credit and real rejecting bond-receiver/funding rollback. |
| M/legacy/MigrationLegacyRecoveryLib.sol:75-147 | Selected booked WY only; fixed receiver/output, exact share burn, synchronized double-floor output, actual wrapper debit/proxy gon increase, local dust and return reconciliation. Existing attributed-gon revaluation and unbooked/full-account fractional floors remain. All three new WY recovery fork tests pass. |
| M/UniswapV4DetfMigrationRecoveryTarget.sol:33-90 | Current-owner bounded selected stages, separate custody between transactions, whole-selected-batch rollback and fixed eventual donation. No arbitrary source/receiver/calldata or ordinary-bond purchase route. Mixed NFT inventory, unsolicited WY/WS, growth, downstream failure and smaller successful retry pass. |
| M/UniswapV4DetfMigrationAllocationTarget.sol:237-266 and unchanged BondFacet._entryBond | Actual completed paid owner-first-bond prerequisite remains before stage/cut. All eight administration selectors, including WY loader, disappear atomically. Existing owner-purchase, callback, reward, registry and restoration suites pass; actual CLI receipt ordering and eight removal events agree. |
| Existing typed operator and both Foundry stages | Required weightedSy originals/proofs/native units, origin partition, frozen quote and full configuration hash agree with Solidity. Read-only/domain rejection, actual replacement, preserved NFT/W-L sequence and three fresh-process resumes pass. |

Inherited `MigrationRecoveryTest.test_fullAccountGonDebitRejectsUnbookedFractionButAllowsSmallerExit`
and `MigrationPermitAndRetirementTest.test_activeFullWalletExitRetiresOnlyOwnFraction`
pass. The actual mixed WY/NFT/unsolicited-gon fork case synchronizes growth,
redeems both selected WY portions, exits booked WS in two steps and preserves
all unbooked gons and unrelated NFT progress. This mixed case is fork evidence;
the CLI's own WY stage has zero preexisting WS gons and is not mislabeled mixed.

## 3. Independently executed checks

All six required top-level commands exited **0**. Exact full commands,
actual edited roots, monitor IDs, tool versions and qualifications are in
`checks.json`; complete logs remain in this directory. Artifact preparation
preceded each full suite, and both operator stages were built before the CLI.
No configured source/test path, compiler profile, provider or dependency was
changed to obtain a pass.

| Check | Result | Evidence |
| --- | --- | --- |
| Artifact-first current Migration specs | 115 passed, 0 failed, 0 skipped | specs.log |
| Artifact-first all current pinned Migration forks | 61 passed, 0 failed, 0 skipped | forks.log |
| Artifact preparation plus both operator Foundry stages | Exit 0 | operator-artifacts.log; operator-stages.log |
| Four operator test files, one invocation | 59 passed, 0 failed | operator-tests.log |
| Strict TypeScript | Exit 0, no diagnostics | operator-types.log |
| Real pinned fixed-port-18564 CLI | bounded-rehearsal-complete, exit 0 | rehearsal.log; rehearsal-1794437832173/ |

Forge is 1.9.1-nightly commit 430523103f3e2f9ba432ffdd2031a9f966153d0d;
executed Bun is 1.4.2. Existing compiler warnings are visible, not suppressed.
JSON LSP could not start because configured Biome is absent; no install or
configuration change was attempted. Evidence JSON was serialized as JSON.
No new test was needed: the complete current suites already own the requested
contracts, and their actual assertions and fixtures were inspected before use.
`coverage.json` records every executed test name and suite.

## 4. Actual independent local sequence

Run: `rehearsal-1794437832173/`.
Migration: `0xedf7d9f65b9e57d62a3c4278223170db1308f5f0`.
Original WY wallet: `0x11c17f25e958e4637dd26ca362adeae12e24ed5b`.
Final WY configuration: `0x5f6e986912906f8d166be420ce9058103c5512cadcc70858e16bb76e8c43d711`.

Original wallet/origin/Q0/ETH/DTF are explicitly **synthetic inputs**. Actual
holdings prove custody, not original contribution value. Initial Q0=8094,
ETH=10000000000000000 wei and known DTF=0 were replaced during Stage1 by
Q0=8087, ETH=6000000000000000 wei and known DTF=0. Actual configured C0 is
2774608 native new-DETF units. Both configuration receipts and independently
recomputed full ABI configuration identity are retained. Stage1 configured
and unconfigured surrender each has a mined status 0 receipt with unchanged
custody, consumption, allowance, supply and funding under the executed checks.

| Surrender | q WY shares | Credit | Bond | Remaining Q/C | Actual start / duration |
| --- | ---: | ---: | ---: | --- | --- |
| Partial, block 108945068 | 2695 | 924640 | 14 | 5392 /1849968 | 1825676124 /7776000 |
| Final, block 108945084 | 5392 | 1849968 | 15 | 0 /0 | 1825762539 /7776000 |

Actual surrender receipts are
`0x04c1f12c377b42be2d7d952721820bad0ab5b2b3b331cc65f33db6eb85e1d957`
and
`0x3228ab9e74ec1dd994fa5538f76f6a5678b5dfe59b4661b1e2dac73b42eda334`.
Independent integer arithmetic gives floor(2774608*2695/8087)=924640;
the final remaining shares take 1849968 exactly. Actual WY transfer, DETF
mint, funded stake, bond purchase and MigrationPositionCreated logs agree.
Funded gons are 400305336915714785302166457815103350954560 and
800042196391670884266500456689614185453856. Bond starts equal their creation
block timestamps; both have fresh 90-day cliffs. These are local simulated
timestamps, not public issuance dates.

| Selected recovery | Partial | Final |
| --- | ---: | ---: |
| WY burned | 2695 | 5392 |
| Actual WS output, then WD | 3464 | 6933 |
| Actual received gons | 2694800045884922956915612110349675659368 | 5391765145933932570636750463247313443658 |
| Synchronized k | 777944585994492770472174396752215837 | 777695823731996620602444895896049826 |
| Conversion dust gons | 199954115077043084387889650324340632 | 234854066067429363249536752686556342 |
| Actual DTF received | 18567816547293961 | 37162598133629686 |
| DTF donated | 9283908273646980 | 18581299066814843 |

Redemption receipts:
`0x5e10bb7015f30a9f7cd38848a308cab73a496c78ef3d11a60d8ce07ce2827c1a`
and
`0xbced423258c289811a8da2cf4aab7df99434831fb487c546f13a982e90f6f1ca`.
The index independently recomputes every output/gon/dust quantity and decodes
raw burn, WS transfer, downstream conversion and donation events. Both
selected downstream-failure receipts have status 0 and zero logs; the actual
runner and fork assertions verify complete rollback. Separate valid stages
then succeed. Seven unsolicited WY shares and a separate 10^18-unit DTF floor
remain protected. Recovery never changes WY credit/new-bond backing, creates
another compensation award or buys an ordinary bond. Identical and changed
WY loader calls remain mined NoTargetFor failures after partial and final use.

### Paid first bond, activation and preserved routes

Independent compensation alone first fails activation at
`0x3e11cf4fbce284f635359f8e50662fc3f410d333fc8aa23abee442dc4ec008e6`
(status 0, no logs). Paid owner purchase
`0x65bd940846e5335481e8d256273ca683d64e973b0af408be1cf5dcece09d33fd`
is bond 6 at block 108944942: actual payment 10^18 units, principal 465583908,
funded rewards 84489332 and backing 1383 -> 550074623. Raw payment and stake/
RewardsFunded events agree with receipt-block reconciliation. It remains an
ordinary purchased bond, not a migration-cliff or synthetic participation seed.
The owner/pending/former/nonowner, immediate/delayed, second-purchase,
callback/short-receipt/funding and reward-closure specs all pass.

Successful activation
`0x975c8acd0ba75ca1fe5e495d2d3259f7bc6841c9927003c1d57bae89267a6727`
is block 108944946. All eight exact interface-derived selectors have actual
removal events; receipt-block verification calls confirm their absence.
Actual nonowner ordinary deposit then returns 462096413 with no refund.

All nine actual NFT/W-L/WY surrender receipts are strictly after activation.
Preserved W-L partial, weighted NFT 4, returned weighted NFT 26, earlier NFT 3,
late weighted NFT 6, late earlier NFT 9 and W-L final create bonds 7-13 with
credits 924869, 13872781, 22233172691, 923391925, 36992599, 46243, 1849739.
Independent recipients retain bonds 3-5 of 461 each; the fourth stays unissued
with bond ID 0. Actual old NFT recovery observes 103958547 original WS units
plus 11891 accrued units. Earlier sale-and-hold remains distinct from proven
liquidation. Exact hashes, event values and source links are in runtime-index.

### Three real mined-before-checkpoint resumes

| Interrupted operation | Nonce | Actual independently executed transaction |
| --- | ---: | --- |
| Donation | 2118 | `0x82cae6fd308ba0d3872d5a6579ae2c20c26524efb2021e7899dd5502a29f111c` |
| Independent issuance | 2132 | `0xcfe405c63762bb5ecacb13144e963c306d3dfadd06b93784da4dbfef53757431` |
| Owner purchase | 2148 | `0x65bd940846e5335481e8d256273ca683d64e973b0af408be1cf5dcece09d33fd` |

For each, the interrupted evidence has a successful mined receipt and no
completion file. Independent signed-transaction decoding reproduces hash and
nonce. Every raw canonical receipt field matches the resumed journal receipt;
these are recomputed comparisons, not copied sameCanonicalReceipt flags.
Actual fresh-process command records retain all three SIGKILL interruptions,
read-only resumes and execute resumes; owner purchase resumes twice without a
second purchase. Outstanding independent issuance reverses order, and the
unselected recipient remains unissued.

There are 43 successful operator receipts, 163 fixture receipts and 47 command
records. Sixty mined fixture failures, six controlled domain rejections and
three intentional SIGKILL interruptions are expected witnesses, not failed
acceptance checks. Quantities, times and recovery outputs differ slightly from
the producer because this is a fresh execution; no stale receipt or hardcoded
producer accounting was substituted.

## 5. Final raw source/artifact/runtime reconciliation

All 33 candidate files remain byte-identical to admission and producer source
snapshots. All **701 distinct compiled metadata source keccak256 values**
across **95** bounded artifacts match actual final source bytes. All **47**
test compilation targets match. All 95 admitted raw artifact JSON hashes still
match after independent builds/tests/CLI; **zero changed** at admission-to-final
or pre-CLI-to-final comparison. No artifact drift is concealed as unchanged.
The older phase13 regenerated-JSON and aggregate artifact-directory metadata
qualifications remain historical; this report does not promote an aggregate
metadata assertion it did not independently reproduce.

All 31 captured parent/package/child runtime records match their own keccak256
hashes. Eleven relevant Migration artifacts match actually captured deployed
bytes, masking only compiler-declared immutable/library spans and retaining
the observed span values. The new permanent facet, allocation facet and
recovery facet all match. Recovery facet has no masked spans. Generic captured
code is hash-bound, not separately claimed artifact-byte-identical here.

| Actual relevant runtime | Address | Keccak256 |
| --- | --- | --- |
| Permanent Migration facet | `0xcd29f772d1c9dbdbafdb0e54504160a5a977c0e8` | `0xb8cf068bcf99bf8a69460acc7bb0b14ba0b3c1d8c64b85eebca93b2318690687` |
| Removable allocation facet | `0x0a69db3b30b7cb13eaff786832e062d157630bb2` | `0xdcc1eaed7a9c0745884b71156aa22facbe6a0763ad15e1980f71365a94a27b34` |
| Retained recovery facet | `0x2f0c891b4e9a1c9833dd3f7814d1a76f684797e9` | `0xdb34d82897fbf8fc1c32ceac8eae2c4d988c7f9c9d9b4cb7b4ec7a1c593dd718` |

`artifact-reconciliation.json` contains the complete independently computed
source, raw artifact, metadata/test-target, runtime-span and closing-admission
ledger. `runtime-index.json` binds decoded actual receipts and exact
configuration/snapshot/source identities. `bindings.json` binds every owned
raw run file and supporting evidence; `seal.sha256` seals this report and the
manifests without recursive self-hashing.

## 6. Cleanup and retained limits

The CLI closed providers/subscriptions, stopped holder impersonation in finally
blocks, copied raw journals, stopped owned Anvil PID 64671 and removed the fixed
checkpoint. Independent external port 18564 lsof and PID ps probes returned
exit 1 with empty output. Checkpoint-absence and whitespace checks returned 0;
rmdir of the empty owned task-runtime parent returned 0. All six execution
monitors completed with exit 0. **No owned runtime remains.**

Only `weighted-sy/verification/` evidence was authored. Existing runtime
scripts may refresh ignored local artifact/cache/broadcast outputs as part of
admitted execution; none was committed or copied to main. Ordinary/common/
Crane production, dependencies, configuration and producer/historical evidence
were untouched. No provider bypass/reroute, held phase09 inspection/import/
replay, public transaction, commit or merge occurred.

Weighted receipt admission, earlier liquid/receipt, direct claim-vault shares,
raw TokenStaking rights, standalone underlying SE/fungible LP and native/WETH
exposure remain separate required categories with the phase11 matrix's
original-record, unit, source-caller, disabled-exit and integration limits.
This WY increment does not admit raw rights or its backing as another award.
No approved operational wallet/origin/Q0/component dataset exists here. No
unchanged ordinary/common full shared-suite or full-plan/category acceptance
is claimed; this candidate changes no such production input.

Actual local parent deployment receipt
`0xe477d5b29800a276a84c37f6bd824bb5c81627912d1ce896ddd40d386d8e20aa`
uses **43517419 gas** on the permitted 100-million-gas local node, above the
retained historical 32-million transaction limit. This verification neither
accepts target gas nor authorizes public deployment, funding, activation or
compensation execution.

**Final bounded disposition: confirmed. No production fix requested; source,
operator receipts, all three resumes and owned-runtime cleanup are independently
confirmed subject to the explicit category/data/gas limits above.**

