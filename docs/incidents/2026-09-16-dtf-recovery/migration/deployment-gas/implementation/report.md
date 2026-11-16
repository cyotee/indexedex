# Migration deployment gas implementation checkpoint

Date: 2026-11-11.

**Disposition: unmet G1/G2; the candidate is not a deployment-gas correction.**
The admitted two-SY preparation succeeds, but both distinct parent finalization
transactions fail with their actual envelopes constrained to **32,000,000 gas**.
Both fail in the manager registry's final parent-publication frame, after the
callback factory has successfully returned. The failed candidate, failing
regression, current artifacts and exact receipts remain intact and uncommitted.
Root expressly requested this preservation after inspecting the checkpoint.

All **96 existing Migration specs** and **39 existing pinned Migration fork
cases** pass on this candidate. The full spec run has **97 passes and one
failure**, including the two new deployment cases. The failure is the
target-bounded final call, not an accepted or suppressed result.
There is **no successful target-bounded parent receipt and no pass-after
deployment claim**.

## 1. Scope and source identity

Worktree:
`/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-09-deployment-gas`.

Branch: `work/dtf-migration-phase-09-deployment-gas`.
HEAD remains `421072a7630a0d3d47a6f36e1062d9eae98c93e2`.
Root's warm-seed exit 0 and `DEPLOYMENT_GAS_WORKTREE_VERIFIED` were supplied
prerequisites. Direct branch/HEAD and warm-directory checks agreed.

Read the complete phase09 brief, original main-checkout implementation plan,
diagnosis, independent design-verification report, operator execution and final
rehearsal reports/stages, phase07 independent runtime/correction/commit reports,
historical gas-limit log, repository rules and applicable canonical guidance.
Before editing, all **226/226** diagnosis compiler/source comparisons and both
accepted production creation-bytecode hashes matched this worktree.

The independent design admitted the two-SY split subject to C1-C6 and G1-G8.
It explicitly did not guarantee gas feasibility. This implementation stops at
that failed executable gate; it does not substitute a different construction.

Only these source/test/witness paths changed, relative to the worktree:

| Path | Candidate change |
| --- | --- |
| `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/interfaces/IUniswapV4DetfMigrationDFPkg.sol` | Package-only preparation and immutable dependency/construction queries; canonical parent `PkgArgs` retained |
| `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationDFPkg.sol` | Require completed full-argument preparation, reconcile existing-parent arguments, guard construction context, validate prepared children before publication |
| `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/sy/IUniswapV4DetfMigrationSYDFPkg.sol` | New interface-owned preparation and initialization schemas |
| `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/sy/UniswapV4DetfMigrationSYDFPkg.sol` | New registered composition, deterministic derivation, SELF-held authorization, pre-parent initialization and reuse validation |
| `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigration_Pkg_FactoryService.sol` | CREATE3/manager registration of the new SY package |
| `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/TestBase_UniswapV4DetfMigration.sol` | Select the package and prepare both SYs before genuine parent construction |
| `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationDeploymentGas.t.sol` | Retained failing bounded-construction regression and passing direct-registry preparation negative |
| `scripts/foundry/recovery/dtf-migration/MigrationDeploymentGasLocalQA.s.sol` | Typed package and instance simulation witness using real FactoryServices/registry |

Ordinary/common/Crane production, existing operator TypeScript, configuration,
dependencies and historical evidence were not edited. No commit, merge,
public transaction, public signer, code replacement or storage injection occurred.
The current operator integration remains a separate task, as the design report
requires. No new dedicated gas fork test was added after the gas gate failed;
the complete existing Migration fork directory was executed instead.

## 2. Fail-before and actual constrained candidate receipts

Historical pin: Robinhood chain **4663**, RPC/L2 block **108944663**, hash
`0xc497433dd691a40cb85959cfeba2e3fff85a975ae060612d984998e1d5765733`.
The saved explicit `getMaxTxGasLimit()` result is **32,000,000**.
This is historical local-fork evidence, not today's live-network limit or a
complete ArbOS fee-model claim. The 100,000,000 Anvil block limit is not the
transaction limit.

### Fresh accepted-source reproduction

The unchanged diagnosis witness replayed all 225 accepted prerequisite
transactions and reproduced both original results, exit 0:

| Accepted-source execution | Envelope | Status | Gas used | Transaction |
| --- | ---: | ---: | ---: | --- |
| Target constrained | 32,000,000 | 0 | 29,079,047 | `0x38fa30f5d5e746a7e19a780e35862cc0767835d2db0b89b11882e179c6200451` |
| Permissive baseline diagnosis | 100,000,000 | 1 | 42,985,843 | `0x1766cd703d2b21c6e3534769bc513989f7d24cc29cac2a18c930a1b8eba77805` |

`fail-before.json` contains the fresh complete receipts, envelopes, call trees
and all baseline source comparisons. The larger baseline transaction
characterizes the original defect; it is not an accepted deployment.

### Current candidate, fresh owned fork

A new node replayed 223 original prerequisite transactions, omitting only
indices 211 and 212: the superseded SY and parent package deployments.
Every replay transaction had gas 32,000,000 and status 1.
The current Solidity witness then generated the two replacement deployments
through `Packages.deploySy` and `Packages.deployParent`; both were simulated
and actually submitted with the same 32-million bound:

| Current package | Status | Gas used | Transaction |
| --- | ---: | ---: | --- |
| Migration SY package | 1 | 4,609,510 | `0xa128610fe28aea317052e9f2abf3db06d1d3de88bed531cc4e1309fd9b6412d9` |
| Migration parent package | 1 | 6,529,977 | `0x2e08a57db70658213423a0f0e5735e7db5c560d1163ad9bf24b4781b5db9a248` |

Actual dependencies:

- CREATE3 factory: `0x85ef1a70ae1352b33bdd2a055de5acefe8b2c01c`.
- Shared callback factory: `0xe68f9de49c682fdb3f5b4b302f896da93da7bee7`.
- Manager registry: `0xaa66038ae217b246f5bf7537104342672e56fed8`.
- Current parent package: `0x642fa76f2f7a6b97ec0822d67a785379a92df347`.
- Current Migration SY package: `0x6ff385F9043Aca8252F2630c601660EbA6218C5a`.

The second instance uses explicit initial-owner argument
`0x1111111111111111111111111111111111111111`, rather than the first instance's
dev-account owner. Its hook was independently reconstructed from the real
hook argument schema, sorted with its matching weights/providers/decimals,
and mined at nonce **28287**. Its resulting address exactly matches the
diagnosed second hook, `0x789372B0F44F40fA217Ee186eE52661700C5eAa8`.
Hook deployment, three pair deployments and hook finalization all succeeded
with individual 32-million envelopes.

| Candidate operation | Envelope | Status | Gas used | Transaction |
| --- | ---: | ---: | ---: | --- |
| First SY preparation | 32,000,000 | 1 | 13,505,863 | `0xb47e6afc3fd35a92e7c769b7f9f538a9cd52577b22b2b487ed67ceac77023a36` |
| First parent finalization | 32,000,000 | 0 | 31,009,212 | `0x44dae0db2469210973bb479c2496d865f6cd0647cb49b305fc0d0e64dd0c855a` |
| Second SY preparation | 32,000,000 | 1 | 13,454,737 | `0xf9ad515679cbd0472f300f4967cd59bbeca56ef101bfea18b6fbb2a36ad0d4f9` |
| Second parent finalization | 32,000,000 | 0 | 31,009,212 | `0xb2bed13a0708646f7bc699ad1ed3844d1851763ee8dd19ceeff40e5d00d1a70d` |

All 234 current-run transactions are retained: **232 successes and two
failures**, all with the target envelope. There was no permissive candidate
final transaction. The two successful Forge simulations use the broader local
simulation context and are not successful constrained receipts.
Their suggested transaction gas values are estimates, not observed gas used.
Separate `eth_estimateGas` observations were **33,177,411** and **33,177,769**;
these are neither actual receipts nor proofs of an exact minimum.

Both failed receipts have no surviving logs. Both predicted parents remain
code-empty and absent from registry discovery:

- First parent: `0xedf7D9f65B9E57D62A3c4278223170DB1308f5F0`.
- Second parent: `0x34fAAF4CcCd4f7D74c1A14ff074BBD48a706C9a3`.

The four previously prepared SYs remain registered, have zero supply and Idle
phase, and have no temporary post-deploy selector. Read-only canonical storage
probes show zero backing gons, conversion dust and raw backing for all four.
Bond and receipt code is absent after each final rollback. These are rollback
and intermediate-state observations, not proof of all G3-G8 negatives.

## 3. Precise remaining publication failure

`post-split-contributors.json` flattens both actual constrained call trees.
Paths below are from `first-current.json.transactions[1].trace`.
The second failure has the same failing outer-frame gas values.

| Frame | Path | Actual inclusive gas used |
| --- | --- | ---: |
| Parent CREATE2 and initialization | `0.0.0.0.3` | 10,383,639 |
| Parent post-deploy | `0.0.0.0.4` | 13,403,195 |
| Complete bond, including reserved IDs | `0.0.0.0.4.1.0.0.0` | 6,111,031 |
| Registered bond construction within that completion | `0.0.0.0.4.1.0.0.0.0.0` | 5,771,637 |
| Receipt completion | `0.0.0.0.4.1.0.0.1` | 3,869,458 |
| Registered raw SY reuse | `0.0.0.0.4.1.0.0.7` | 199,333 |
| Registered staking SY reuse | `0.0.0.0.4.1.0.0.8` | 182,833 |
| Explicit raw SY validation | `0.0.0.0.4.1.0.0.20` | 298,466 |
| Explicit staking SY validation | `0.0.0.0.4.1.0.0.23` | 306,742 |
| Entire callback factory deployment; returns successfully | `0.0.0.0` | 24,676,299 |
| Parent `vaultConfig()`; returns successfully | `0.0.0.1` | 6,878 |
| Registry deployment delegatecall; exhausts its forwarded gas | `0.0.0` | 30,963,406 |

Ancestors and descendants must not be added together. The callback factory
completes parent construction, all five child links, reciprocal validation and
temporary-hook removal inside the ultimately reverted transaction. The later
registry publication is where execution fails.

The failing address is registry deployment facet
`0x497b819bd10c7eeb3feacd74237c536cf2d7e0bf`, selector `0x968cbade`.
It receives **30,963,406 gas**, consumes all of it, and returns `out of gas`.
Its manager-proxy caller received **31,460,141**; outer frames retain gas,
which is why a failed receipt charging 31,009,212 is not evidence that the
successful operation fits a 32-million envelope.

Subtracting the two successful direct child calls from the failing registry
frame gives **6,280,229 gas of exclusive registry work through failure**.
This includes registry work before and after those calls; it is not all
assigned to one opcode or falsely presented as a completed publication cost.
Publication has not finished, so its complete successful cost was not observed
in a candidate receipt.

Source: `contracts/registries/vault/VaultRegistryDeploymentTarget.sol:63-77`
calls the callback factory and then `_registerVault`.
`VaultRegistryVaultRepo.sol:91-151` writes the package/content/type/token
indexes and emits discovery events. These shared sources remain untouched.
The new error location is distinct from the baseline failure inside raw-SY
registration.

## 4. Current artifacts, checks and preserved failures

Compiler: Forge **1.9.1-nightly**,
`430523103f3e2f9ba432ffdd2031a9f966153d0d`; Solar metadata
`0.8.38+commit.e7a91fc7.solar.0.3.0-dev`.
No viaIR, profile-path changes, relaxed code-size limit or simulation bypass.

| Current artifact | Runtime-object bytes | Creation-bytecode Keccak-256 |
| --- | ---: | --- |
| `UniswapV4DetfMigrationDFPkg` | 22,620 | `0xbaba9e590564c5fe2510f895740f0807c9fd968dd422db587868411ddadfbd2f` |
| `UniswapV4DetfMigrationSYDFPkg` | 17,977 | `0x16c4cd4ac0a4960340b9d3b50f04f99a6e96d508b49dfb1afec5bb414b8815c6` |

Actual populated runtime hashes are respectively
`0x24a81cae1507f3000951d34b8e872e90d46047fabb58125aa1b52909302069c2`
and `0x1cd623d5f4fbb2a72aa4325c55d8b6420d6bca3fd4a3a3b43abd83dd15a5a612`.
Normalizing only the compiler-declared immutable ranges reproduces each
current runtime object exactly. Actual submitted `deployPkg` creation bytes
match these artifact hashes; constructor bytes and CREATE3 salts are retained.

`source-artifact-runtime-bindings.json` includes all eight candidate
source/test/witness texts and fingerprints, current executable objects and
metadata, **205/205** compiler/source comparisons, the immutable values,
**18/18** unchanged shared-runtime comparisons, actual child factory
argument records and intermediate-state probes. At final comparison, only
the owned parent package and its interface differ among the original
226 compiler-input comparisons. The helper/TestBase changes are separately
fingerprinted, not omitted by that compiler-input count.

| Evidence log | Exit | Result |
| --- | ---: | --- |
| `build-01.log` | 0 | First candidate compiled, but parent runtime was 26,805 bytes; not deployable under EIP-170 |
| `core-02.log` | 0 | Artifact-first revised composition; 9 core cases pass |
| `gas-spec-03.log` | 1 | One passing missing-preparation negative; bounded finalization fails |
| `witness-build-04.log` | 0 | Current concrete runtime artifacts built before script use |
| `packages-simulation-05.log`, `witness-compile-06.log` | 1 | Harness PATH could not resolve `solar`; no compiler fallback |
| `witness-compile-07.log` | 0 | Script compiled with installed Solar on PATH |
| `packages-simulation-08.log` | 0 | Genuine current package FactoryService simulation succeeds |
| `first-simulation-09.log`, `second-simulation-10.log` | 0 | Full construction simulations succeed; not constrained receipt acceptance |
| `spec-current-11.log` | 1 | 97 pass, one bounded-gas failure, zero skipped, 17 suites |
| `fork-current-12.log` | 0 | 39 pass, zero failed/skipped, eight suites |

The oversized first attempt and its exact source/artifacts are preserved in
`attempt-01-size.json`. Deterministic derivation was redistributed between the
two admitted package files to fit EIP-170; no common code, feature, selector or
validation was removed. The final candidate remains the bytes exercised by
the actual failed transactions. It was not optimized or changed after root
requested preservation.

The artifact-first spec command was:

```sh
PATH=/Users/cyotee/.foundry/bin:$PATH python3 scripts/forge-artifacts.py test \
  contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationDFPkg.sol \
  contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/sy/UniswapV4DetfMigrationSYDFPkg.sol \
  --test-root test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/migration -- -vv
```

The fork command used the same source roots and helper, with
`FOUNDRY_PROFILE=fork`, test root
`test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration`,
and `-- -j 1 --compute-units-per-second 10 --rpc-timeout 120 -vv`,
inside the existing credential-bearing login environment.
`commands-and-cleanup.json` records complete commands, raw script calldata,
monitor IDs, exits, transaction-submission code and the exact replay order.

Final Solidity diagnostics found no errors on both packages, the TestBase,
new spec and local witness. JSON LSP is unavailable because Biome is absent;
no forbidden installation was attempted. Evidence is serialized from parsed
JSON and actual RPC objects. Existing compiler warnings remain visible.
The current source-scope/whitespace/HEAD command exited 0.

## 5. One minimal next correction proposal -- unadmitted

**Extend preparation to deploy the exact predicted existing Migration bond
child through its existing registered package, alongside the two SYs; leave
reserved IDs 0/1/2 initialization, receipt creation, RT creation, all reciprocal
validation, hook removal and parent publication in the final transaction.**

This proposal is **not admitted and was not implemented**. It changes the
previously admitted transaction split and must receive the next independent
design assessment in this same DAG before any implementation.

The actual post-split trace provides the reason: registered bond construction
still costs **5,771,637** inside finalization, while complete bond wiring costs
6,111,031. Only the former construction is proposed for relocation; reserved
role creation remains final. Reuse traversal and validation will still cost
gas. Adding the observed bond-construction scale to the 13.5-million SY
preparation suggests useful headroom, but subtraction/addition is only an
engineering estimate, not a successful bounded transaction.

Source grounding:

- `UniswapV4DetfTarget.sol:812-833` already separates registered bond deployment
  from `initializeReservedBondNfts`.
- `common/bondNft/DETFNFTVaultDFPkg.sol:48-54,105-125` constructs canonical
  name/symbol/parent/LP arguments and initializes the fixed bond storage.
- `common/bondNft/DETFFundedBondRepo.sol:33-44` initializes fixed nonzero parent
  and LP bindings without a live-parent read.
- `common/bondNft/DETFFundedBondTarget.sol:89-98` initializes reserved IDs only
  for the bound parent, once. This remains inside finalization.
- The existing diagnosis separately observed successful early bond creation;
  its bond-only split was insufficient. This proposal adds that early bond to
  the two-SY split rather than repeating the rejected bond-only shortcut.

Independent assessment must establish the expanded intermediate-state contract:
canonical metadata and actual hook LP binding; the same full-argument
construction commitment; no parent-address reservation or new preparer role;
no positions, funded principal or reserved-role NFTs before finalization;
no premature donation/claim/callback route that changes accepted rights; exact
factory/registry reuse validation; failure rollback and retry; and all G1-G8
proofs with two distinct instances. No ordinary/common/Crane modification is
proposed. In particular, this is not permission to relax the receipt's live
parent checks, preinitialize a mutable parent, or remove registry indexes.

## 6. Cleanup and acceptance limits

Owned Anvil sessions `bash_3` and `bash_8` were individually stopped. All
legacy-holder impersonations ended in `finally`. No SUT was impersonated.
All compiler/test/script monitors finished; no WebSocket subscription or
child agent is pending. A delegation attempt was refused by the nesting
limit before any child started.

Cleanup command `bash_21` exited 0 and reported:

```text
OWNED_PORT_CLOSED
WARM_ARTIFACTS_AND_CACHE_PRESERVED
```

Port 18560, other worktrees, shared services and dependency links were not
altered. Warm `out/` and `cache_forge/` remain. Dedicated Foundry dry-run
broadcast/cache artifacts are retained for this witness; no cache deletion
occurred. All six read historical operator/recovery reports/logs remain
byte-identical. No resolved private RPC URL is included in owned evidence.

G1/G2 are failed, not deferred successes. The full new binding-mutation,
pre-parent economic-operation, second-child rollback, reentrancy,
alternate-hook, complete final-state and restoration-negative matrix was not
completed after that gate failed. Existing 96-spec/39-fork lifecycle evidence
does not replace those new-construction obligations. No independent
AdversarialVerify acceptance is claimed.

All original full-plan limits remain: E2 transfer/claim/wrapper attribution;
both liquid generations, both receipt models, SY, TokenStaking/claim-vault
rights, underlying SE and fungible LP surrender; earlier liquidation,
disabled dependencies, missing legacy source and masked authorization;
approved original inputs, allocations and funding provenance; complete
E1-E5, tasks 9/10, invariants, F1-F4 and release.

**Final result: preserved failed candidate and exact unmet publication-gas
gate, with one unadmitted next split for independent design assessment.
No corrected deployment, public readiness or implementation completion.**
