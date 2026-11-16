# Independent bounded deployment verification

Date: 2026-11-11.

**AdversarialVerify: needs-fix.** The preserved two-SY preparation candidate
does not meet G1 or G2. Independent execution on a fresh owned historical
fork reproduces successful preparation followed by failed parent publication
for both distinct instances. Every submitted transaction had an actual
**32,000,000-gas envelope**. Both finalizations consume **31,009,212 gas**
and have **status 0**, with an out-of-gas registry delegatecall.
No successful bounded parent, complete final-state acceptance or lifecycle
execution through a bounded parent is claimed.

The independent run mined 257 transactions: 233 successes and 24 failures.
The failures comprise two initial finalizations, one exact finalization retry,
16 premature SY economic operations and five initialization/binding negatives.
All receipts were checked against their canonical local blocks. Cleanup is
complete; no owned runtime remains.

## 1. Blocking finding

**High - G1/G2: final registry publication still exceeds the available
forwarded gas.** The caller is
`contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationDFPkg.sol`,
`deployVault`; the observed failing frame is
`contracts/registries/vault/VaultRegistryDeploymentTarget.sol:63-77`.
The latter completes factory construction and then calls
`VaultRegistryVaultRepo.sol:91-151` to publish discovery indexes.

In both actual failure traces, frame `0.0.0` is the registry deployment
delegatecall at `0x497b819bd10c7eeb3feacd74237c536cf2d7e0bf`,
selector `0x968cbade`. It receives and exhausts **30,963,406 gas**.
The package and manager ancestors revert. The factory's nested deployment
returns successfully before the later registry failure.

First-instance inclusive frame measurements:

| Frame | Trace path | Gas used |
| --- | --- | ---: |
| Parent CREATE2 and initialization | `0.0.0.0.3` | 10,383,639 |
| Parent post-deploy | `0.0.0.0.4` | 13,403,195 |
| Complete callback-factory deployment | `0.0.0.0` | 24,676,299 |
| Completed parent `vaultConfig()` read | `0.0.0.1` | 6,878 |
| Registry delegatecall, failed | `0.0.0` | 30,963,406 |

These are nested inclusive costs, not quantities to add together.
The receipt's lower total than its envelope does not establish sufficiency:
the exhausted nested frame does not receive all gas retained by its callers.
The successful inner construction is rolled back and is not a deployed parent.

The candidate needs a corrected, independently admitted construction that
preserves publication, composition and authority while actually fitting the
bound. The implementation report's proposed additional bond preparation is
**unadmitted and unimplemented**; this verifier neither adopts it nor edits
source. No larger-envelope candidate transaction was submitted.

## 2. Scope and historical limit

Worktree:
`/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-09-deployment-gas`.
Branch: `work/dtf-migration-phase-09-deployment-gas`.
Observed HEAD before and after:
`421072a7630a0d3d47a6f36e1062d9eae98c93e2`.
The reviewed candidate is the existing uncommitted delta on that base.
Root's warm-seed exit 0 and `DEPLOYMENT_GAS_WORKTREE_VERIFIED` are supplied
prerequisites; warm directories and branch/HEAD were independently checked.

Read the complete phase09 brief, original main-checkout implementation plan,
repository/canonical rules, diagnosis, design admission, implementation
checkpoint and all eight changed source/test/witness files. Read the complete
phase08 execution and final rehearsal reports and actual Stage 00/01 sources;
read phase07's independent original, correction and commit-verification
reports and historical gas-limit log. The original plan's Migration owner
and lifecycle requirements govern over ordinary unowned-DETF defaults.

The historical execution pin is Robinhood chain **4663**, RPC/L2 block
**108944663**, hash
`0xc497433dd691a40cb85959cfeba2e3fff85a975ae060612d984998e1d5765733`.
The header's L1 number is 26367659. The owned node's initial chain, block and
hash matched exactly.

The explicit saved `getMaxTxGasLimit()` result is **32,000,000**, exit 0,
in phase07
`migration/nft-recovery/implementation/chain-gas-limits.log`.
The accounting tuple is 7,000,000 / 32,000,000 / 32,000,000 and ArbOS is 116.
Diagnosis independently repeated those historical calls. This verifier read
that evidence; it did not query today's live limit.

Anvil's 100,000,000 block allowance is not substituted for the transaction
limit. Every actual transaction here has `gas=0x1e84800`; code-size
enforcement remained enabled. This is historical local EVM evidence, not
complete ArbOS fee emulation or public-deployment readiness.

The actual prior operator journal entry in final run
`rehearsal-1794376137494` records parent transaction
`0xbc2ffc265391562244269342481d3d072e17e8fcec09e9f8d4938f69b10ee5ed`,
gas used 42,985,843 and envelope 67,771,942. The diagnosis's separate
100-million-envelope baseline also used 42,985,843, while its bounded
baseline failed at 29,079,047. Those historical receipts remain failures
of deployment feasibility, not corrected successes.

## 3. Independent real construction receipts

The fresh node replayed all 223 current prerequisite transactions in order,
including genuine holder claim/unstake/conversion/funding operations and real
CREATE3/manager infrastructure. Only the two superseded package deployments
are omitted from the original 225-item seed. No contract code or storage was
replaced. Native development funding and five bounded legacy-holder
impersonation windows were used; each impersonation ended in `finally`.

The two current package transactions were decoded as real registry
`deployPkg` calls. Their creation bytes exactly match current Solar artifacts.
Both preparation and finalization use the genuine package/registry path.
Each transaction was simulated with its bounded envelope before submission;
expected failed simulations were retained, followed by actual failed receipts.

| Operation | Status | Gas used | Transaction hash |
| --- | ---: | ---: | --- |
| Current Migration SY package | 1 | 4,609,510 | `0xa128610fe28aea317052e9f2abf3db06d1d3de88bed531cc4e1309fd9b6412d9` |
| Current parent package | 1 | 6,529,977 | `0x2e08a57db70658213423a0f0e5735e7db5c560d1163ad9bf24b4781b5db9a248` |
| First preparation | 1 | 13,505,863 | `0xb47e6afc3fd35a92e7c769b7f9f538a9cd52577b22b2b487ed67ceac77023a36` |
| First finalization | 0 | 31,009,212 | `0x44dae0db2469210973bb479c2496d865f6cd0647cb49b305fc0d0e64dd0c855a` |
| Second preparation | 1 | 13,454,737 | `0xf9ad515679cbd0472f300f4967cd59bbeca56ef101bfea18b6fbb2a36ad0d4f9` |
| Second finalization | 0 | 31,009,212 | `0xb2bed13a0708646f7bc699ad1ed3844d1851763ee8dd19ceeff40e5d00d1a70d` |
| Identical first preparation retry | 1 | 238,737 | `0xa36125ccddf3f163900b88e8eb9eb6fc5eb6ff6f9e6d3b4cbdae8835b8c7a290` |
| Exact first finalization retry | 0 | 31,009,212 | `0xaea7b35078421c5c30dab3d065b05d4bf0672bf6f90c0b1dd57a9dd499e04e50` |

All rows have a 32,000,000-gas envelope. Deterministic replay reproduces the
producer's original hashes; these are newly submitted and independently read
receipts, not merely copied producer results. Supplemental probes have their
own subsequent hashes in `transactions.json`.

| Binding | First instance | Second instance |
| --- | --- | --- |
| Explicit owner argument | `0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266` | `0x1111111111111111111111111111111111111111` |
| Predicted parent | `0xedf7D9f65B9E57D62A3c4278223170DB1308f5F0` | `0x34fAAF4CcCd4f7D74c1A14ff074BBD48a706C9a3` |
| Actual bound hook | `0x4d48367dfa6300587c45fB2C841C18Bc1abfaAa8` | `0x789372B0F44F40fA217Ee186eE52661700C5eAa8` |
| Predicted bond | `0x76D3b85BE8cc91dF1e66cfd3c81681795555E58C` | `0xAf15F3a858a3DD9402f293Fe20d36576bEAA07e5` |
| Predicted receipt | `0xE4F9A217B8eeF5413FE8d5b2524AA975e26554f1` | `0xeB925B4c2570170Bf3947b26E98Cc9466ceEE670` |
| Actual prepared raw SY | `0x72F003517D9BAc1CfcBDD3203eBc8B1d647a6ae0` | `0xc0226794811d36bD84d30b413F8071ADaA78071a` |
| Actual prepared staking SY | `0x4eE804436ac1C9cE679BF4ac1E90d272cd7e589c` | `0x7C308ABEe01Fd73a87dbFc0AB75203b597FF33F8` |

The second hook deployment, three real pair deployments and finalization
succeeded separately at the same bound. It is not an existing-parent reuse.
Owner rows above describe immutable requested construction, **not observed
owner state on a surviving parent**.

## 4. Observed intermediate safety and its limits

Before and after both failed finalizations, each predicted parent has no code,
`isVault(parent)` is false, its factory package record is zero, and predicted
bond/receipt code is absent. Failed receipts have no surviving logs.
Previously prepared children and their preparation records remain identical.
Exact retry preserves those facts.

For all four SYs, independent queries establish:

- Genuine registry membership and exact callback-factory package/encoded
  argument equality with the construction derived by the current package.
- Six actual loupe facets; every selector declared by the selected three
  package cuts routes to its expected facet. All eight declared interfaces
  are supported; `postDeploy()` has no facet.
- Recorded metadata, nine decimals, yield token, asset identity and ordered
  input/output routes. Current package `validateChild` succeeds for each
  exact canonical argument set.
- Zero supply, zero attributed gons and Idle accounting phase. Read-only
  canonical storage probes independently confirm zero backing gons,
  conversion dust and raw backing.

Sixteen real transactions attempted transfer of zero shares, a one-unit
WETH deposit, a one-share WETH redemption and reward claim on each SY.
Every transaction reverted, used 54,362-54,861 gas, retained no logs and
left the complete inspected state identical. Source
`migration/sy/UniswapV4DetfMigrationSYTarget.sol:34-44` places fixed-parent
synchronization before these economic effects; absent-parent construction
does not create an alternate custody or issuance route.

Five additional real negative transactions rejected direct parent-package
initialization, direct SY-package initialization, prepared-child
initialization, the removed child post-deploy selector, and a direct registry
attempt combining the other owner with an unprepared full hook payload.
Their exact calldata, reverted simulations, receipts and traces are retained.
These are bounded observed negatives, not a universal no-takeover proof.

G3-G8 are **not fully accepted**. No successful bounded parent exists on which
to verify final parent facets/owner, all five surviving child links, reserved
NFT ownership, live funding/custody/activation, or selector restoration
negatives. The complete mutation, alternative-hook, second-child-failure,
reentrancy, approval/donation and disable/re-enable matrix was not executed.
Successful preparation and rollback do not close those missing obligations.

## 5. Source, artifact and regression provenance

Independently recomputed **8/8 changed-file SHA-256 bindings**, **205/205
compiler-source Keccak bindings**, and **18/18 unchanged shared-runtime
hashes**. Actual submitted creation bytes, constructor arguments and salts
are retained. Both live package runtimes match current artifact runtime
objects after normalizing only compiler-declared immutable ranges.

| Current package | Runtime bytes | Creation-bytecode Keccak-256 |
| --- | ---: | --- |
| `UniswapV4DetfMigrationDFPkg` | 22,620 | `0xbaba9e590564c5fe2510f895740f0807c9fd968dd422db587868411ddadfbd2f` |
| `UniswapV4DetfMigrationSYDFPkg` | 17,977 | `0x16c4cd4ac0a4960340b9d3b50f04f99a6e96d508b49dfb1afec5bb414b8815c6` |

Actual immutable-populated runtime hashes:

- Parent package at `0x642fa76f2f7a6b97ec0822d67a785379a92df347`:
  `0x24a81cae1507f3000951d34b8e872e90d46047fabb58125aa1b52909302069c2`.
- SY package at `0x6ff385F9043Aca8252F2630c601660EbA6218C5a`:
  `0x1cd623d5f4fbb2a72aa4325c55d8b6420d6bca3fd4a3a3b43abd83dd15a5a612`.

The shared callback factory is
`0xe68f9de49c682fdb3f5b4b302f896da93da7bee7`; manager registry is
`0xaa66038ae217b246f5bf7537104342672e56fed8`.
Compiler metadata is `0.8.38+commit.e7a91fc7.solar.0.3.0-dev`.
The owned Anvil is 1.9.1-nightly, commit
`430523103f3e2f9ba432ffdd2031a9f966153d0d`.

Read and rehashed the actual producer artifact-first build/test logs, and
recounted their terminal results rather than accepting a green summary:

| Retained implementation log | Recorded exit | Observed result |
| --- | ---: | --- |
| `core-02.log` | 0 | Nine core cases pass |
| `gas-spec-03.log` | 1 | One pass, one bounded-final-parent failure |
| `witness-build-04.log` | 0 | Current artifact build, unchanged compilation skipped |
| `spec-current-11.log` | 1 | 97 pass, one fail, zero skipped, 17 suites |
| `fork-current-12.log` | 0 | 39 pass, zero fail/skipped, eight suites |

The repeated failure line in each failing log is a repeated summary, not a
second failed test. The 97 spec passes contain the 96 existing Migration
cases and the new direct-registry preparation negative. Existing
lifecycle/custody/funding/activation coverage is retained producer execution
on the candidate's real fixture, **not this verifier's bounded-chain lifecycle
execution**. Phase07's accepted 9,932 ordinary/common passes remain historical
regression provenance, not a new run.

No production edit or new compilation was performed here. Current artifacts
were checked against sources and the producer's completed Solar build before
replaying their exact real deployment bytes. The already-failed bounded gate
was independently reproduced; no duplicate broader suite or permissive parent
deployment was used to manufacture acceptance. Neither the failed gas test
nor its expectation was changed.

## 6. Evidence and cleanup

All files below are in this owned `verification/` directory:

| File | Content |
| --- | --- |
| `transactions.json` | All 257 exact envelopes, simulations, canonical receipts and calldata |
| `traces.json` | Raw callTracer trees for current packages, preparation/finalization, retry and probes |
| `construction-and-probes.json` | Full arguments, construction commitments, pre/post states, loupe/interface/storage observations and gas index |
| `source-and-regression-bindings.json` | File/compiler/artifact/runtime bindings, constructor bytes, retained logs/commands and historical preservation |
| `commands-and-cleanup.json` | Exact startup, resident RPC/replay/state-check code, resource ownership, cleanup and harness limitations |

The node started from the dedicated worktree through the existing login
environment with host 127.0.0.1, port 18561, chain 4663, historical fork block
108944663, block limit 100000000, `--disable-min-priority-fee` and native dev
balance 1000000. No private endpoint is retained. Explicit `evm_mine` was the
receipt synchronization point; there was no receipt polling or timed sleep.

Owned monitor `mon_W5R5WKY63MZ1GRP9`, session `bash_4`, was stopped with
`kill_bash`. Its exit 1 is intentional node termination, not a test result.
The subsequent cleanup/scope command exited 0 and printed:

```text
OWNED_PORT_CLOSED
WARM_ARTIFACTS_AND_CACHE_PRESERVED
421072a7630a0d3d47a6f36e1062d9eae98c93e2
```

All five holder impersonation windows ended. No WebSocket subscription,
compiler, child task or owned listener remains. Port 18560 was never used.
No source fixes, public transactions, public signer, commits, merges,
configuration/dependency changes, cross-worktree cache writes or arbitrary
authority were introduced. Historical inputs and all eight reviewed changed
files retain their initial hashes.

Read-only harness corrections were an absolute artifact path mistakenly
prefixed twice, ordinary Git status rejecting the prescribed Crane symlink,
and ABI recursive object conversion of selector arrays. They were corrected
before the affected checks; none altered the SUT. JSON LSP is unavailable
because Biome is absent. No installation was attempted; evidence is serialized
from parsed actual RPC/JSON objects. Scoped Git whitespace checks pass.

## 7. Remaining full-plan gates

The bounded deployment correction is **not complete**. G1/G2 fail; complete
G3-G8 acceptance remains unavailable. No later source delivery or release
follows from this report.

All original full-plan limits remain: E2 authenticated transfer/claim/wrapper
attribution; both liquid generations, both receipt models, SY,
TokenStaking/claim-vault rights, underlying SE and fungible LP surrender;
earlier liquidation, disabled dependencies, missing legacy source and masked
authorization; approved original inputs, allocations and funding provenance;
complete E1-E5, tasks 9/10, invariants, F1-F4 and release.

**Final disposition: AdversarialVerify needs-fix. Independent bounded
failure, preserved intermediate-state evidence and cleanup are complete;
successful deployment and full Migration acceptance are not.**
