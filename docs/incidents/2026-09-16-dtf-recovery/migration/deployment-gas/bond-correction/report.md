# Admitted bond-and-SY preparation correction

Date: 2026-11-11.

**Implementation result: the admitted combined preparation passes actual
32,000,000-gas construction for two distinct instances.** First preparation
and finalization use **19,746,590 / 27,449,560 gas**; second preparation and
finalization use **19,595,896 / 26,889,308 gas**. All four receipts have
status 1 and explicit 32,000,000 envelopes. All replayed infrastructure and
new package/hook transactions also fit that envelope.

The unchanged, previously failing bounded regression passes. Final
artifact-first Solar checks pass **109 Migration specs and 40 pinned fork
cases**, with zero failures or skipped tests. The new construction,
negative, rollback, callback and restoration matrix is below. Supplemental
actual transactions demonstrate funding, capture, configuration, exactly
funded independent and legacy-NFT bonds, mature Stage 1 principal, late
surrender, recovery, owner transfer and irreversible activation.

This is the implementation's evidence, **not independent
AdversarialVerify acceptance**. The original independent report remains
`needs-fix` for its preserved two-SY-only candidate. A separate verifier
must assess these corrected bytes and execute its own replay.

No owned node or compiler remains. All holder impersonations ended.
Port 18561 is closed. A terminal metadata-unlink error during final node
termination is recorded in section 8; the process did terminate.

## 1. Admission, scope and preserved baseline

Worktree:
`/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-09-deployment-gas`.

Branch: `work/dtf-migration-phase-09-deployment-gas`.
HEAD: `421072a7630a0d3d47a6f36e1062d9eae98c93e2`.
No source commit, merge or public action occurred.

Read the complete correction instruction, original phase09 brief, original
Migration implementation plan, initial diagnosis/design/implementation
reports, completed independent verification report and
`../bond-design-verification/report.md`. The last report admits this exact
construction and edit boundary. The previous verifier's cleanup was
complete before editing.

Before production edits, all **8/8** source/test/witness texts matched the
preserved implementation evidence, and both package creation/runtime
objects matched its stored artifacts. Those historical files were not
rewritten. The failed baseline, oversized initial attempt, failed two-SY
receipts, failing regression logs and independent adverse report remain
under their original directories.

Relative path prefix `M/` below means
`contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/`.

| Correction path | Exact role |
| --- | --- |
| `M/interfaces/IUniswapV4DetfMigrationDFPkg.sol` | Interface-owned canonical bond arguments in `SyConstruction`; document combined preparation |
| `M/UniswapV4DetfMigrationDFPkg.sol` | Require the complete bond/SY commitment; validate the bond before unchanged wiring and after reserved roles |
| `M/sy/IUniswapV4DetfMigrationSYDFPkg.sol` | Selected bond package/hash in `Preparation`; typed read-only bond validator |
| `M/sy/UniswapV4DetfMigrationSYDFPkg.sol` | Canonical bond derivation, registered deployment/adoption, complete reuse validation and lock-scoped completion |
| `M/TestBase_UniswapV4DetfMigration.sol` | Real alternate-weight hook fixture for same-parent/full-payload isolation |
| `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationDeploymentGas.t.sol` | Preserve both original tests; add the missing construction/safety matrix |
| `test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationDeploymentGas.t.sol` | New pinned two-instance construction and initial-bond proof |
| `scripts/foundry/recovery/dtf-migration/MigrationDeploymentGasLocalQA.s.sol` | Update the real local witness's intermediate assertions for an unreserved prepared bond |

The already changed FactoryService from the two-SY candidate required no
additional edit. Its original candidate text remains intact. No
ordinary/common/Crane source, bond economic implementation, operator
TypeScript, configuration or dependency was edited.

`candidate-correction.patch` is the exact delta against the preserved
two-SY candidate, not a replacement baseline. Final texts and fingerprints
are in `source-artifact-runtime-bindings.json`.

## 2. Construction implemented

`M/sy/UniswapV4DetfMigrationSYDFPkg.sol:76` retains the package-only
preparation entry. Its full identity remains
`keccak256(abi.encode(block.chainid, parentPackage, completeArgs))`.
Parent prediction still clears only the hook in its existing salt copy.
The actual hook remains in the construction commitment and bond LP
argument.

The preparation lock and incomplete record are installed before registered
bond construction. The exact existing bond package deploys or adopts the
predicted bond through the manager registry, then both existing Migration
SY constructions run through their registry path. The bond is validated
before and after the SY calls. Only then is the record completed and the
lock cleared. Exact repeated preparation revalidates all three children
while the parent is absent; independently predeployed exact bonds are
accepted, not treated as hostile reservations.

The validator at `M/sy/UniswapV4DetfMigrationSYDFPkg.sol:343` checks actual
factory prediction/package/encoded arguments, fixed parent and LP,
metadata, registry package membership, StandardVault configuration,
interfaces, complete selector composition, no temporary hook, zero
attributed gons, Idle phase and pre/post reserved-role state. It resolves
cuts in order, so the three ERC721 transfer replacements belong to the
Migration bond facet rather than the earlier ERC721 Add cut. Selector
counts exclude extra initializer, owner or cut surfaces.

`M/UniswapV4DetfMigrationDFPkg.sol:293,333` rederives canonical bond
arguments from actual factory-recorded full parent arguments and requires
the matching completed record. It validates before the unchanged
`completeReserveBondNft()` call, which still traverses the real registered
bond package and creates reserved IDs 0/1/2. Receipt and RT construction,
all reciprocal/SY checks, final bond-role checks, temporary-hook removal
and parent publication remain in the final transaction.

No preparer identity becomes an authority. No child balance-zero veto,
parent reservation, owner signature, mutable binding or new initializer
was introduced. Unsolicited ERC20 balances and caller-owned operator
approvals are permitted and survive legitimate finalization.

## 3. Fail-before and actual pass-after receipts

Historical pin: Robinhood chain **4663**, RPC/L2 block **108944663**, hash
`0xc497433dd691a40cb85959cfeba2e3fff85a975ae060612d984998e1d5765733`.
The recorded explicit historical maximum transaction gas is 32,000,000.
This is local historical-fork evidence, not a current live-network quote
or complete ArbOS fee emulation.

Anvil's block allowance is 100,000,000. It was never substituted for the
transaction bound. Code-size enforcement remained on. Every submitted
envelope in both owned runs was 32,000,000; each was simulated before
submission, explicitly mined and checked against its canonical block.

### Preserved adverse results

| Earlier construction | Envelope | Status | Gas used |
| --- | ---: | ---: | ---: |
| Accepted original, bounded | 32,000,000 | 0 | 29,079,047 |
| Accepted original, permissive diagnosis only | 100,000,000 | 1 | 42,985,843 |
| Two-SY candidate, first finalization | 32,000,000 | 0 | 31,009,212 |
| Two-SY candidate, second finalization | 32,000,000 | 0 | 31,009,212 |

Locators: `../diagnosis/accepted-parent-failure.json`,
`../implementation/fail-before.json`, `../implementation/first-current.json`,
`../implementation/second-current.json`, and
`../verification/transactions.json`. The two-SY failure was final registry
publication after successful nested factory construction, not a successful
deployment merely because charged gas was below the envelope.

### Corrected actual transactions

| Operation | Status | Gas used | Transaction hash |
| --- | ---: | ---: | --- |
| Corrected SY package | 1 | 5,635,270 | `0xb4dbaec091947c45ad0045a75a8d1621ec631629bc3c49b95f74b9c9dd573c07` |
| Corrected parent package | 1 | 6,793,129 | `0xf64934b5bdb6ed08144e0760f88affebfea2dafd70a2288c90a0e467046d8512` |
| First bond/SY preparation | 1 | 19,746,590 | `0xb47e6afc3fd35a92e7c769b7f9f538a9cd52577b22b2b487ed67ceac77023a36` |
| First finalization | 1 | 27,449,560 | `0x44dae0db2469210973bb479c2496d865f6cd0647cb49b305fc0d0e64dd0c855a` |
| Second bond/SY preparation | 1 | 19,595,896 | `0xf9ad515679cbd0472f300f4967cd59bbeca56ef101bfea18b6fbb2a36ad0d4f9` |
| Second finalization | 1 | 26,889,308 | `0xb2bed13a0708646f7bc699ad1ed3844d1851763ee8dd19ceeff40e5d00d1a70d` |

All six rows have 32,000,000-gas envelopes. The 223 source-bound prerequisite
transactions all succeed; their maximum gas used is 11,862,619. The second
real hook, three pair operations and finalization separately use
7,876,000 / 76,582 / 79,016 / 79,450 / 7,061,275 gas.

Several preparation/final transaction hashes intentionally match the old
isolated replay: their sender, nonce and calldata are identical, while
previous transactions installed different package bytes at the same
CREATE3 addresses. A transaction hash alone is not the code/state binding.
The retained block hashes, package-deployment bytes and populated runtime
hashes distinguish the successful corrected run from the old failed run.

### Distinct instance bindings

| Binding | First | Second |
| --- | --- | --- |
| Initial owner | `0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266` | `0x1111111111111111111111111111111111111111` |
| Parent | `0xedf7D9f65B9E57D62A3c4278223170DB1308f5F0` | `0x34fAAF4CcCd4f7D74c1A14ff074BBD48a706C9a3` |
| Hook | `0x4d48367dfa6300587c45fB2C841C18Bc1abfaAa8` | `0x789372B0F44F40fA217Ee186eE52661700C5eAa8` |
| Bond | `0x76D3b85BE8cc91dF1e66cfd3c81681795555E58C` | `0xAf15F3a858a3DD9402f293Fe20d36576bEAA07e5` |
| Receipt | `0xE4F9A217B8eeF5413FE8d5b2524AA975e26554f1` | `0xeB925B4c2570170Bf3947b26E98Cc9466ceEE670` |
| Raw SY | `0x72F003517D9BAc1CfcBDD3203eBc8B1d647a6ae0` | `0xc0226794811d36bD84d30b413F8071ADaA78071a` |
| Staking SY | `0x4eE804436ac1C9cE679BF4ac1E90d272cd7e589c` | `0x7C308ABEe01Fd73a87dbFc0AB75203b597FF33F8` |
| RT | `0xe44e17379970147fa85E3491ec2860F06F454F27` | `0xa793E583c0cf2d8bC7E8c09bb740D8852dcc6a6F` |

The second instance is fresh construction, not the first parent's factory
fast path. Both use the same genuine CREATE3 factory, callback factory
and manager infrastructure.

## 4. Required negative and lifecycle matrix

Spec references below use
`test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/migration/`.
`Gas` means its `MigrationDeploymentGas.t.sol`.
Every listed test passed on final production bytes.

| Gate / obligation | Executed proof and result |
| --- | --- |
| G1/G2 constrained construction | Section 3 actual receipts; unchanged `Gas:36` bounded regression; dedicated pinned fork test at `MigrationDeploymentGas.t.sol:15` |
| G3 direct-registry bypass | `Gas:68`: missing completed preparation rejects, with absent parent and factory record |
| G3 metadata and ordered route positives | `Gas:79`: explicit bond/receipt metadata, opposite directional custom tables and exact raw/staking route order survive preparation and bounded finalization |
| G3 wrong bond parent/LP/package/name/symbol/hash | `Gas:215`: mutations cannot validate against the existing bond; canonical encoded argument hash remains authoritative |
| G3 wrong SY parent/receipt/mode/name/symbol/route order | `Gas:215`: both explicit validation and unauthorized deployment reject changed child arguments |
| G3 caller/package/owner/chain/canonical-byte domains | `Gas:215`: direct preparation caller, direct package/factory initialization, direct factory fresh construction, noncanonical registry bytes, changed chain and changed owner reject; exact finalization remains possible |
| G3 alternate hooks sharing parent prediction | `Gas:369`: both preparation orders; distinct full IDs/bonds/receipts; first preparer cannot veto the other payload; mismatching package-helper reuse rejects; direct existing-parent registry reuse preserves actual recorded winning arguments |
| G4 parent absent and complete prepared children | Actual historical-block reads in `construction-and-lifecycle.json`: parent and receipt code absent, parent discovery false, complete preparation, zero bond next ID/positions/gons, zero SY backing/dust, Idle phases and successful canonical validators |
| G4 all early bond economic entry families | `Gas:129`: reserved roles, ordinary and Migration position creation, principal/reward/combined claims, all three ERC721 transfers, held-token sweep, both donation overloads and both Permit2 donation methods reject without rights or ledger changes |
| G4 approvals and unsolicited assets | `Gas:129`: token-specific approval of future IDs 0-3 fails; caller-owned `setApprovalForAll` succeeds without approving another owner; positive external ERC20 donation before code and existing-bond adoption do not veto finalization |
| G4 both early SY money paths | `Gas:179`: transfer, transferFrom, deposit, both redemption burn modes, rewards, current reward indexes and reward remainder reject for each SY; ordinary approvals and unsolicited tokens persist; supply/backing/dust/phase remain zero/Idle |
| G4 direct initializer/hook reachability | `Gas:129,179,215`: proxy initializer and removed hook fail; direct common bond-package initialization can initialize only package-local storage, repeat initialization fails, and the independently deployed child remains unchanged |
| G5 preparation rollback with fresh bond | `Gas:264`: real SY-package disable after registered bond call rolls back bond, SY authorizations, incomplete record and factory/registry entries; re-enable and exact retry succeed |
| G5 preparation rollback with preexisting bond | `Gas:264`: prior bond, donated balance and caller approval survive; new SY/record state rolls back; exact retry adopts the same bond |
| G5 second-SY failure | `Gas:296`: a deliberately smaller 15-million call reaches the staking-SY registry deployment and fails; all newly prepared children and lock/authorization state roll back; exact normal retry succeeds |
| G5 final rollback after roles and during publication | `Gas:309`: real SY disable after reserved minting and a 25-million failure reaching parent `vaultConfig()` at publication; no parent/receipt/RT or their new factory records survive, bond next ID returns to zero, reserved roles/positions/gons remain absent, prior bond/SYs/record/balances/approval survive; exact retry succeeds |
| G5 bond and parent disable/re-enable | `Gas:350`: bond disable prevents preparation; parent disable prevents finalization without consuming committed preparation; authorized re-enable permits exact retry |
| G5 callbacks at both construction boundaries | `Gas:492`: real custom-route preview through the real V3 SE reads a controllable external ERC20; forced callback failure proves reachability, then bounded static reentry attempts fail while legitimate preparation/finalization succeed |
| G6 complete publication/composition | Actual 108 parent selectors and 42 bond selectors, ordered Add/Replace resolution, all declared interfaces, all actual published discovery indexes, factory arguments, five distinct children, metadata/9/27 decimals, fixed links and initial zero/Idle accounting; see section 5 for the unchanged token-array query discrepancy |
| G7 funding/capture/configuration/fresh issuance | Current `MigrationCore`, `MigrationGenesisCapital`, `MigrationNftConfiguration`, `MigrationAdministration`, snapshot and fork suites; also actual funding/genesis/capture/configuration and three exact-funded independent bonds in `continuation-transactions.json` |
| G7 Stage 1 payout/ordinary acquisition and principal | Current core/egress/Permit2/retirement/retained-accounting suites; actual failed reward/combined claims, zero early principal, and a 461-unit mature principal payout while activation is false |
| G7 real NFT custody and late fresh clock | Current legacy-source/lifecycle forks cover both admitted NFT models; actual weighted NFT 26 funds bond 6, and weighted NFT 4 surrendered over 90 days later funds bond 7 with a new 7,776,000-second duration |
| G7 owner transfer, recovery and activation | Current administration/recovery/fork suites; actual recovery leaves new bond gons unchanged; pending/former owner operations reject, accepted owner activates, and all six administration selectors disappear |
| G7 restoration through package/factory/proxy callbacks | `Gas:395` plus actual package helper and factory existing-parent reuse, preparation/update/init/post-deploy negatives, direct factory initialization and proxy temporary-hook calls; removed selectors remain absent |
| G8 preservation/current bytes/cleanup | 215 compiler-source comparisons, both current populated packages, 18 shared-runtime comparisons, 23 facet runtimes plus three recursively verified linked libraries; current specs/forks and cleanup receipts retained |

The callback test uses an external currency fixture, not a mocked parent,
hook, SE, registry, fee oracle, facet or package. Construction-time custom
route reads are static. The canonical bond initializer has no
user-controlled nonstatic callback, and reserved roles use ordinary mint,
not receiver-safe mint. Source call-graph proof and the executable static
callback test are separate evidence; no fictitious mutable callback seam
was inserted into production to manufacture a test.

The 15/25-million deliberately failing calls test rollback only. They do
not replace, raise or weaken either 32-million deployment acceptance
envelope.

## 5. Unchanged discovery-query discrepancy

The actual parent publication indexes are complete: each parent passed
114 membership checks across all-vault, package, published contents ID,
type, token, package/token and type/token indexes.

An additional query audit found an existing mismatch:
`UniswapV4DetfInitializationLib.sol:48-56` hashes sorted hook tokens with
the hook appended, whereas
`contracts/registries/vault/VaultRegistryVaultQueryTarget.sol:64-65`
sorts the entire token array before hashing. The registry stores the
provided contents ID unchanged at
`contracts/registries/vault/VaultRegistryVaultRepo.sol:109-120`.
For these parents, `vaultsOfTokens` and corresponding package/type array
convenience queries consequently return empty, while direct published-ID
and individual-token indexes contain the parent.

This is **not fixed or hidden by the correction**. The initialization
source's preserved and current Keccak hash is
`0x3cf91c2b5498d326ae7672e2da07a3fe6667c5a17e26696284f71cf686abd1ba`;
the shared registry runtime is unchanged. Exact observed query results,
including empties, are retained in `construction-and-lifecycle.json`.
No publication index or reciprocal validation was removed. Changing
shared initialization/query semantics is outside this admission and
needs separate scope.

## 6. Actual lifecycle and replay qualifications

On the corrected bounded parent, actual funding creates the reserve before
capture. Configuration leaves the 1,000,000,000,000-unit genesis supply
unchanged. Three independent allocations each create a separate
461-unit exactly funded bond. The fourth configured recipient remains
unissued.

Weighted NFT 26 transfers from its actual holder into parent custody and
funds a new bond with principal 22,233,172,691. A mature independent claim
pays exactly 461 receipt units while rewards remain closed. Later weighted
NFT 4 surrender creates principal 13,872,781 at its actual new timestamp,
with its own full 90-day cliff. Recovery of that old position records
227,020,595 principal and 26,874,395 rewards without changing new bond
gons. Current-owner transfer and activation then execute successfully;
all six removed selectors remain absent after the restoration attempts.

These are synthetic local operational fixtures, not approved compensation
allocations or funding provenance.

The first node ended with exit 0 after its 252 recorded transactions; the
cause was not exposed. Its gas receipts and lifecycle checkpoint were
already retained. A fresh owned node replayed the exact bounded envelopes
and completed the remaining runtime/lifecycle inspection.

The first infrastructure replay initially combined automining with
explicit mining. The second used explicit mining only, changing the local
block schedule and therefore the funded snapshot/configuration IDs.
Replaying one old snapshot-bound issuance correctly reverted with
`IndependentConfigurationMismatch`. That actual failure is preserved.
Subsequent issuance used the current on-chain configuration IDs; no guard,
snapshot, storage or expected credit was patched.

The continuation contains 273 transactions: 261 successes and 12 failures.
Eleven failures are deliberate lifecycle/restoration negatives; the other
is the stale replayed configuration described above. Separate node
generations are not presented as one simultaneous canonical chain.

## 7. Final bytecode and checks

Compiler metadata:
`0.8.38+commit.e7a91fc7.solar.0.3.0-dev`.

| Package | Runtime bytes | Creation-bytecode Keccak |
| --- | ---: | --- |
| `UniswapV4DetfMigrationDFPkg` | 23,828 | `0xc3948f9351d246bcb1c7064b2f687df03495c5d3358b88e259ba29ef8a863557` |
| `UniswapV4DetfMigrationSYDFPkg` | 22,684 | `0x0c1ffe13bebed61ba7f7c290589e916c11d35cca0920fb27fd5e7b9b6937ae85` |

Actual populated package runtime hashes:

- Parent: `0xed651bfaa6ae7a5ed09bbbaf9ad3f4bf0e8db93a02bcf413002b2878fb755ed6`.
- SY: `0x5bf4e933abc5cbf25707d8b8c662355eecec0ee21c3e8e85cd3047c3bffaae64`.

Both match their current artifact runtime after normalizing only declared
immutable ranges. Facet verification additionally resolves only
compiler-declared link ranges and verifies the actual linked libraries;
unlinked placeholder text is not hashed as executable code. Final package
creation/runtime objects still equal the bytes used in the successful
receipts.

Final spec command, from the owned worktree:

```sh
PATH=/Users/cyotee/.foundry/bin:$PATH python3 scripts/forge-artifacts.py test \
  contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationDFPkg.sol \
  contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/sy/UniswapV4DetfMigrationSYDFPkg.sol \
  --test-root test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/migration -- -vv
```

Exit 0: **109 passed, 0 failed, 0 skipped**, 18 suites.

The same artifact-first source roots under `FOUNDRY_PROFILE=fork`, fork
test root and `-- -j 1 --compute-units-per-second 10 --rpc-timeout 120 -vv`
exit 0: **40 passed, 0 failed, 0 skipped**, nine suites. Existing archive
credentials were inherited through `/bin/zsh -lic`, never copied into
evidence. The final later changes were spec-only acceptance rows; fork
fixtures and production bytes stayed unchanged.

The local Solidity witness built successfully and its corrected package
FactoryService simulation exited 0 before those generated package
transactions were submitted. Actual instance calldata came from the
preserved canonical payloads and was independently simulated at the
bounded envelope before submission. No successful script estimate is
substituted for a receipt.

All eight edited Solidity files had no LSP errors. JSON LSP is unavailable
because Biome is absent; no installation was attempted. Existing compiler
warnings remain visible. No ordinary/common production dependency changed,
so unrelated accepted suites were not rerun.

Retained correction-development failures include the initial wrong
factory-interface cast and a new chain-domain test's restoration failure.
The latter used a rematerializable `block.chainid` local across
`vm.chainId`; using the explicit `vm.getChainId()` read fixed the harness
without changing production or weakening its negative. The initial
verbose failed run exceeded the terminal tail; its concise repeat and
failure summary are retained. Some log files begin in compiler warnings
because the tool returns a bounded tail; complete final suite result lines
and command/exit records are preserved.

## 8. Evidence and cleanup

| File | Contents |
| --- | --- |
| `candidate-correction.patch` | Exact eight-path delta against the preserved candidate |
| `transactions.json` | Initial 234 prerequisite/package/hook/preparation/final transactions, canonical receipts and construction traces |
| `lifecycle-checkpoint.json` | First node's subsequent actual lifecycle receipts and checkpoint |
| `continuation-transactions.json` | Fresh-node replay and completed lifecycle/restoration receipts, including retained stale-configuration failure |
| `construction-and-lifecycle.json` | Pre/final state, complete discovery/routing observations, query discrepancy, zero ledgers and lifecycle outcomes |
| `source-artifact-runtime-bindings.json` | Final source texts/hashes, original-regression equality, compiler inputs, executable objects, populated packages, shared facets and linked libraries |
| `spec-complete.log`, `fork-current.log` | Final 109-spec and 40-fork results |
| `spec-current.log`, `spec-final.log` | Earlier passing matrix checkpoints, preserved rather than overwritten |
| `compile-first-cast-failure.log`, `matrix-before-chain-restoration.log` | Retained correction-development failures |
| `commands-and-cleanup.json` | Exact commands/exits, RPC/submission/inspection routines, runtime ownership and cleanup receipts |

Owned final node `bash_15` was terminated through `kill_bash`. The tool
reported `EPERM` while removing its terminal monitor metadata, but the
monitor then delivered **killed, exit 1**. The independent cleanup command
exited 0 and printed:

```text
OWNED_PORT_CLOSED
WARM_ARTIFACTS_AND_CACHE_PRESERVED
421072a7630a0d3d47a6f36e1062d9eae98c93e2
```

The bookkeeping error is not represented as a successful metadata deletion.
No node/listener, compiler, holder impersonation, WebSocket subscription
or child task remains active. A delegation attempt was rejected at the
nesting limit before any child started. Port 18560, other worktrees,
historical evidence and warm caches were not changed.

## 9. Limits and disposition

The admitted correction now has successful actual bounded construction,
the unweakened regression, current required suites, intermediate safety,
rollback/retry, lifecycle and final-byte evidence. No further split or
product-policy proposal is needed for this result.

The independent final verifier still owns its separate acceptance verdict.
The unchanged token-array discovery discrepancy is disclosed, not silently
repaired. No public readiness, release, operational allocation approval or
operator-integration completion is claimed.

All original full-plan/category limits remain open: E2 authenticated
transfer/claim/wrapper attribution; unsupported liquid/receipt/SY,
TokenStaking/claim-vault, underlying-SE and fungible-LP categories;
earlier liquidation and missing-source/masked-authorization limitations;
approved original inputs, allocation and funding provenance; full E1-E5,
tasks 9/10, invariants, F1-F4 and release.

**Final implementation disposition: admitted correction implemented and
verified within scope; ready for the separate independent replay.**
