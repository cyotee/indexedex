# Independent preparation verification

Date: 2026-11-10.

**AdversarialVerify: confirmed**, exclusively for the five-path, default-preserving preparation increment in `implementation-handoff.md` sections 5-6.

No blocking defect was found in this increment. The extracted implementations have real ordinary production consumers, preserve the previous initialization and funded-accounting semantics, and are bound to the current compiled artifacts. The existing focused run executed **24 tests in 7 suites**, and the existing broad run executed **9,932 tests in 589 suites**; both exited **0**, with **0 failed and 0 skipped**. I independently recounted the raw results and checked their source/artifact binding rather than accepting the implementation report's verdict.

This verdict does **not** close task 3, task 5, E4, E5, legacy E1/E2, full actual-recovery E3, BOOTSTRAP-AUTH, or the separate T5-EGRESS accounting gate. It approves neither pooled-genesis caller policy nor final Migration child composition.

## 1. Scope, authority, and method

Worktree: `/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-03`.

Base and independently observed HEAD: `90ff0307a7a8e084aa073e02eff125e9c7973933`.

I read the requested `phase03-implementation-brief.md`, its preceding phase brief, the complete 374-line worktree `implementation-handoff.md`, the complete `evidence/preparation/report.md`, all five actual changed/new source files, and the complete tracked diff against the base. Applicable repository routers, assistant coding/deployment/testing rules, DETF product/testing law, canonical Crane architecture/deployment/testing/adversarial guidance, IndexedEx testing/adversarial guidance, artifact-build instructions, and test-review discipline informed the review.

The handoff controls the boundary: its earlier ownership/bootstrap/children proposals are not installed behavior, and its initial source reports are not correctness proofs. Sections 2-4 and 7 remain requirements or blockers for later work, not permission to expand the current edit set. No egress-lane output was edited or used to declare E5 complete.

The review combined:

- Direct base/current comparison, including the entire new initializer library.
- Call-chain and storage inspection above and below each extracted operation.
- Independent SHA-256 and Keccak-256 checks, actual artifact metadata/bytecode inspection, and recorded-artifact hash comparison.
- Inspection of new assertions and the existing real-proxy behavioral oracles, matched to raw executed PASS records.
- Fresh Native Solidity diagnostics and a read-only Git whitespace/scope check.

No source or test fix, mutation, new Foundry harness, build, test rerun, dependency/configuration edit, commit, delegation, RPC, fork, broadcast, or public action was performed. The user explicitly required existing valid source-bound passes to stand. No missing, failing, or contradictory runtime check remained that justified repeating them.

### Path aliases

All following aliases are relative to the worktree:

| Alias | Exact prefix |
| --- | --- |
| `D/` | `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/` |
| `C/` | `contracts/vaults/detf/common/` |
| `K/` | `lib/crane/contracts/` |
| `T/` | `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/` |
| `TC/` | `test/foundry/spec/vaults/detf/common/` |
| `P/` | `docs/incidents/2026-09-16-dtf-recovery/migration/package/evidence/preparation/` |
| `V/` | `docs/incidents/2026-09-16-dtf-recovery/migration/package/evidence/preparation-verification/` |

`V/verification-receipt.json` contains the independently calculated hashes, structural comparisons, artifact bindings, raw-result recounts, named witness locations, initial Git status, and exact diagnostic results.

## 2. Complete increment and scope proof

Read-only commands executed successfully:

```text
git -C <worktree> rev-parse HEAD
git -C <worktree> status --short --untracked-files=all --ignore-submodules=all
git -C <worktree> diff 90ff0307a7a8e084aa073e02eff125e9c7973933 --name-status --ignore-submodules=all
git -C <worktree> diff 90ff0307a7a8e084aa073e02eff125e9c7973933 -- <four existing allowed files>
git -C <worktree> show 90ff0307a7a8e084aa073e02eff125e9c7973933:<each existing allowed file>
git -C <worktree> diff --check
```

Each command above exited 0. The current full tracked patch equals `P/source.patch` byte for byte. The only tracked changes are the package, funded bond target, staking target, and existing deployment test. The only new production source is the allowed initializer library. No other tracked source, test, script, interface, repo, deployment helper, rule, or configuration change appears.

I also parsed both recorded SHA-256 inventories, rather than taking their totals from prose: `P/baseline-scope.log` and `P/final-scope.log` each contain 5,207 entries; precisely the four allowed existing files differ, and 5,203 entries agree. These are implementation-time inventories; the fresh Git diff and five-file hash checks establish the current increment. Shared Crane is deliberately excluded from Git submodule traversal because it is a pre-existing read-only-use symlink; this is not a claim of a separate Crane Git audit.

| Current source | Independently calculated SHA-256 |
| --- | --- |
| `D/UniswapV4DetfInitializationLib.sol` | `6e3a8c25dad4c01ca1e0b517ebe365b8340520237ca8bc269a9ac3eceb94af7c` |
| `D/UniswapV4DetfDFPkg.sol` | `14112eb68aac3f67bcbae5d41d1a5e76fe3b526033f6dab782df5c1d396b899d` |
| `C/bondNft/DETFFundedBondTarget.sol` | `ff3c95b45adec74973aabcb874be2a8d86aa79a9af8770949b0b7e635fbcc360` |
| `C/claimToken/StakedDETFTarget.sol` | `fed9bd4bf324c8e1c3d71e1809c3ae516320d05beb580085b2deedb83bb24f82` |
| `T/UniswapV4Detf_Deploy.t.sol` | `d1a4a227847c32bb5b5f3a4b97d9fed8114d2fca47c4c4ff0106b8332248b41e` |

All five match `P/source-manifest.json`. Independently read Git base blobs also match all four recorded `beforeSha256` values.

**Scope conclusion:** no expansion into Migration issuance, activation, donation inventory, receipt partition, pricing integration, or caller policy. No ordinary economic, external ABI, storage-layout, declaration, or salt change was found. The internal library and implemented internal dispatch functions do not introduce proxy selectors. This conclusion comes from the full diff and call-chain review, not from assuming bytecode stayed identical.

## 3. Initializer extraction: order, guards, and immutable wiring

### 3.1 Exact equivalence

The former `D/UniswapV4DetfDFPkg.sol:223-304` initialization/table implementation at the base is now consumed at current `D/UniswapV4DetfDFPkg.sol:215-224`, with the implementation at `D/UniswapV4DetfInitializationLib.sol:25-112`.

An independent body comparison found:

- The initialization body is identical after removing the package-owned decode statement, substituting the five explicitly passed dependency/declaration values for their former package expressions, and normalizing whitespace.
- `_storeTables` is byte-identical to its former package body.
- `_decodeArgs`, `calcSalt`, `processArgs`, `facetCuts`, `facetInterfaces`, `vaultFeeTypeIds`, `vaultTypes`, `postDeploy`, and `deployVault` bodies are byte-identical to the base.

The library receives the actual fee oracle, fee classification, type declarations, bond package, and receipt package. It does not choose ordinary interface IDs or child addresses itself. Current package declarations are pure (`D/UniswapV4DetfDFPkg.sol:104-146`); evaluating those arguments before entering the library moves no storage operation, external callback, authorization, or economic calculation.

### 3.2 Preserved ordered operations

| Order | Current source and verified behavior |
| --- | --- |
| 1 | Package canonical decode remains first, with exact re-encoding rejection at `D/UniswapV4DetfDFPkg.sol:188-192,215-216`. Registry-only processing and hook-excluding salt remain at `:194-208`. |
| 2 | Hook shape, liquidity policy, and predicted-parent self-leg/owner checks occur at `D/UniswapV4DetfInitializationLib.sol:33-35`. Actual validators remain `D/UniswapV4DetfProcessArgsLib.sol:26-65`. |
| 3 | Hook token count, creation-rate validation, and opening-rate fallback precede writes at library `:37-40`; validation and elementwise zero/empty fallback remain in process-args `:67-94`. |
| 4 | Nine-decimal ERC20 metadata, EIP712 name/version, ordered hook-token contents plus the hook, and StandardVault declarations are initialized at library `:42-52`. |
| 5 | Threshold and closure-rate resolution precede guarded core initialization at library `:54-68`. The unchanged authoritative repo rejects nonzero existing `hook` before core writes, initializes inert state, preserves dependencies, and resets only the initial timestamp: `D/UniswapV4DetfRepo.sol:98-110`. |
| 6 | Policy, child metadata, route modes, hook sets/pair rates, and all route tables follow in their former order at library `:69-84`. The hook sets exist before custom-row validation consults them. |
| 7 | Basic-vault contents and `ThresholdsConfigured` remain last at library `:85-86`. Mint, burn, bond, and donation table branches retain their original order at `:89-112`. |

Default inbound tables still contain each non-self hook token and its distinct SE share. Custom rows retain their validity and duplicate checks. Custom donation rows must belong to mint or bond with the same vault; default donation remains the mint-then-bond union. These rules are unchanged at `D/UniswapV4DetfProcessArgsLib.sol:112-201`.

The core once-only guard has not been moved ahead of earlier initialization writes. A failure there still reverts the entire transaction, including those preceding writes. The new same-args test is **not** represented as dynamically exercising that guard: occupied proxy deployment returns before initialization at `K/factories/diamondPkg/DiamondPackageCallBackFactory.sol:201-230`. It proves reuse without resetting state. The guard itself is established by unchanged source and the exact extraction comparison.

### 3.3 Child and routing contract

Constructor dependency storage and post-deploy order remain unchanged: bond, then receipt, then both SY wrappers (`D/UniswapV4DetfDFPkg.sol:45-90,227-239`). Bond completion rejects missing hook/repetition and passes the actual parent and hook; receipt completion requires the bond, rejects repetition, and passes the same parent/bond/oracle (`D/UniswapV4DetfTarget.sol:810-849`). Reserved IDs still belong to bond custody, fee owner, and creator-or-fee fallback (`C/bondNft/DETFFundedBondTarget.sol:81-90`).

SY deployment still uses one selected registered package, the parent and receipt identities, separate raw/staking modes, and the initialized mint/burn tokens (`C/sy/DETFSYDeploymentLib.sol:15-27`). No placeholder Migration children or new mutable bindings were installed.

The real fixture deploys facets/packages through FactoryServices and the manager/registry, then predicts the parent, binds the hook's raw token and owner to that prediction, and deploys the parent (`D/TestBase_UniswapV4Detf.sol:186-245,289-321`). The new test observes these actual proxies.

The completed proxy test checks absence of package init, package postDeploy, temporary postDeploy hook, and diamond-cut selectors (`T/UniswapV4Detf_Deploy.t.sol:186-190`). Factory callback initialization and post-hook removal remain unchanged (`K/factories/diamondPkg/DiamondPackageCallBackFactory.sol:343-391,425-451`). No new callable initialization or upgrade route was added.

## 4. Funded creation and claim dispatch

**Creation:** the external `createFundedPosition(principal,duration,recipient)` retains `onlyDetf synchronized nonReentrant`, in that order, and immediately consumes `_createFundedPosition` (`C/bondNft/DETFFundedBondTarget.sol:94-112`). The extracted helper body is byte-identical to the former external body. It still requires initialized reserved IDs, nonzero principal/duration, and a valid recipient before funding or minting the personal NFT.

The actual production caller remains parent `_entryBond` -> `_purchaseBond` / `_purchaseReserveLpBond` -> `_openBondNft` (`D/UniswapV4DetfTarget.sol:527-595,714-724`). The parent mints and approves exactly the principal, invokes the real child, and clears approval. The child measures this call's backing receipt, requires `received == principal`, approves the receipt for exactly principal, stakes, clears allowance, and requires the measured gons increase to equal `principal * currentK` (`C/bondNft/DETFFundedBondTarget.sol:114-130`). Existing escrow surplus is not credited as the new position.

The unchanged repo writes the actual current timestamp, supplied effective duration, zero claimed principal, and exact measured gons, then requires total attributed gons to remain held (`C/bondNft/DETFFundedBondRepo.sol:46-70`). The ordinary purchase still stakes principal before funding its immediate issuance pot; this is not changed into Migration award issuance.

**Synchronization:** child synchronization still precedes its local lock. The parent locked callback exemption remains limited to its wired bond and receipt, not arbitrary callers (`C/bondNft/DETFFundedBondTarget.sol:41-49`; `D/UniswapV4DetfMaintenanceTarget.sol:16-27`). No lock was inserted around donation forwarding.

**Claim calculation:** preview retains existence then reserved-ID handling before dispatch (`C/bondNft/DETFFundedBondTarget.sol:140-149`). Execution retains reserved-ID rejection, existence, owner/approved/operator authorization, recipient resolution/validation, and current-index read before the same dispatch (`:173-186`). `_calculateClaim(tokenId,gonsPerUnit)` is implemented, internal, view, and virtual; it reads the real position and calls the existing linear math at `block.timestamp`. Existing products contain no override of the new dispatch.

The unchanged arithmetic computes vested principal from elapsed duration, rejects overclaimed principal or a funding deficit, and separates rewards as `floor(positionGons / K) - remainingPrincipal` (`C/core/DETFFundedStakingMath.sol:97-116`). Preview describes the stored funded index; execution still synchronizes first. The extraction does not falsely promise pre-settlement preview equality across an epoch transition.

**Payout and retirement:** `_claim` is now virtual, but its body differs only in the calculation call. It still debits exactly `(principalPaid + rewardsPaid) * K` from position and aggregate attribution, transfers sDETF, retires only a fully paid position's sub-native fraction, checks funding, and emits the existing event (`C/bondNft/DETFFundedBondTarget.sol:187-209`). Rewards-only claims retain unpaid principal and the NFT. No no-op permission hook, new external method, storage field, or ordinary cliff policy was introduced.

All three guarded ERC721 transfer overloads remain unchanged at `:220-237`; the live-proxy packaging and surface tests verify their final owning facet and execute the guarded routes.

## 5. Distribution dispatch and economic order

`C/claimToken/StakedDETFTarget.sol:170-190` preserves this exact sequence:

1. Take the local non-reentrant entry and require the initialized parent caller.
2. Reject zero funding.
3. Pull and require the exact transaction-local backing delta.
4. Resolve **current owners** of reserved fee and creator NFTs.
5. Pass actual storage, amount, and those resolved recipients to the implemented virtual distribution policy.
6. Top up standing weights after distribution.
7. Emit and return the same growth/fee/creator values.

The funding caller body is byte-identical after replacing its one `Repo._distribute(...)` expression with `_distributeRewards(...)`. That new function returns the real `Repo._distribute` result, rather than a stub. Exact pull and fee-oracle top-up remain at `C/claimToken/StakedDETFTarget.sol:234-245`.

The repo still increases accounted backing only by the authenticated funding amount; allocates using current ordinary gons and standing weights; carries allocation dust; rebases existing holders; then issues fee receipts followed by creator receipts at the new index (`C/claimToken/DETFFundedStakingRepo.sol:182-201,225-234`). Consequently new role receipts do not earn their own distribution, coincident beneficiaries accumulate both allocations normally, and an oracle feeTo change does not retroactively replace reserved-NFT ownership.

No pending-beneficiary ledger, activation gate, reward repartition, or new index math was added. Unsolicited backing is not promoted into funding. Full ordinary withdrawal still retires only the withdrawing account's own fraction (`C/claimToken/DETFFundedStakingRepo.sol:109-139`). Ordinary destinations remain immediately usable sDETF, as required for this default-preserving increment.

## 6. Test review and executed behavioral evidence

All three original deployment-test bodies are byte-identical to the base. The diff adds imports and three tests only; it removes or weakens no assertion.

| New test | Independent contract observed and retention decision |
| --- | --- |
| `test_deploy_parentMetadataDeclarationsAndDefaults` (`T/UniswapV4Detf_Deploy.t.sol:56-87`) | **Retain.** Real proxy metadata/domain/default thresholds/opening fallback and actual declaration/contents storage; exact default donation rows. Losing a write or contents element fails. Package declaration equality verifies correct storage of package-selected declarations, not an independent proof of the package's entire interface census. |
| `test_deploy_customRoutesMetadataAndChildBindings` (`:89-168`) | **Retain.** Distinct mint/burn/bond inputs and a valid donation subset exercise full rows and modes; explicit rates/metadata/creator differ from defaults. Prediction, child parent/LP/owners, receipt address bound to parent/bond/oracle/package arguments, empty receipt state, and two wrapper backing modes are observed through real proxies. Crossed tables or lost child arguments fail. |
| `test_deploy_sameArgsPreserveFundedStateAndNoInitializerRouting` (`:170-191`) | **Retain.** Genuine paid first bond, captured live supply/children/staking state, registry redeploy, and final selector absence. It tests idempotent reuse and routing, not upgrading occupied CREATE3 addresses or directly replaying the core guard. |

These are state/wiring observations, not source-string tests, helper-name pins, mocks returning their own expected output, or fabricated postconditions. There are no new sleeps, timing races, test-only setters, storage injection, or SUT substitutions. Deterministic Foundry time advancement in existing bond tests is appropriate because vesting/epoch time is the behavior under test. No mutation run was performed: production/test edits are forbidden for this verifier.

### Behavioral oracle ledger

The following source bodies were read, and their executing suites were checked in the raw logs:

| Obligation | Actual oracle and executed evidence |
| --- | --- |
| New initialization tests execute | `P/focused.log:2904-2911`; `P/broad.log:9013-9021`. All six deployment tests pass, including all three additions. |
| Exact funded principal/gons and unchanged issuance economics | `T/UniswapV4Detf_IoTablesOpenBase.sol:45-79` checks independent allocation floors, exact position gons, backing/supply deltas, and separate self-leg issuance. Broad PASS examples include `P/broad.log:8298`; this shared behavior also runs across production provider fixtures. |
| Actual timestamp/duration and halfway principal | `TC/bondNft/DETFNFTVaultDFPkg_Deploy.t.sol:45-56`, PASS at `P/broad.log:8825`. `T/UniswapV4Detf_ClaimOpenBase.sol:12-26` also preserves zero-at-purchase and exact halfway payment. |
| Reward preview/payment and exact debit; NFT survives | `TC/bondNft/DETFNFTVaultDFPkg_Deploy.t.sol:79-88`, PASS at `P/broad.log:8830`; `T/UniswapV4Detf_ClaimOpenBase.sol:35-51` checks preview equality, receipt delta, no principal debit, and no repeated reward. |
| Isolated retirement and fuzz accounting | `TC/claimToken/FundedStakingSequence.t.sol:37-70,74-149`; both focused tests pass at `P/focused.log:2892-2895`. Assertions reconcile actual backing, liabilities, dust, all owners' gons, and separate NFT fractions. |
| Guarded transfer routing and behavior | `T/UniswapV4Detf_BondNftPackaging.t.sol:13-55`; `TC/bondNft/DETFNFTVault_Surface.t.sol:38-88`; five focused passes at `P/focused.log:2868-2877`. |
| Ordinary index growth, unsolicited backing, full exit | `TC/claimToken/RebasingClaimToken_Accounting.t.sol:53-109`; three focused passes at `P/focused.log:2879-2883`. |
| Current fee-NFT owner, not cached/rotated fee recipient | `TC/bondNft/DETFNFTVaultDFPkg_Deploy.t.sol:114-125` transfers the role after settling the old boundary and observes later income to the new owner; PASS at `P/broad.log:8822`. |
| Allocation/rebase/receipt/top-up ordering | `T/UniswapV4Detf_Alignment_FeeCreatorClaimBase.sol:39-68,71-137`, using the independent integer reference in `contracts/test/bases/FundedRewardAssertions.sol:68-121`. It compares complete staking state and fee/creator gons, not merely positive balances. Broad PASS records include `P/broad.log:8491-8496`. |
| Long sequence invariant | `P/broad.log:25911-25922` executes `invariant_accounting()` with 256 runs, 16,384 calls, and 0 reverts. Calls are not counted as separate tests. |

The complete broad run is regression evidence for the prescribed ordinary V4/common scope, not a claim that this verifier individually audited every one of its 9,932 test bodies or that it is the full repository release gate.

## 7. Exact command outcomes and current artifact binding

### 7.1 Existing commands accepted without rerun

The literal requested focused and broad invocations are retained at `P/focused.log:6` and `P/broad.log:6`, with exact expanded build/test commands at lines 12-13 of each file. They match handoff section 6: all four edited production paths, the seven specified focused roots, then the two specified broad roots, followed by `-- -vv`. `P/run.sh:14-42` contains their argument arrays.

Both use `/Users/cyotee/.foundry/bin` first on PATH and retain configured source/test/output paths. `P/run.sh:43-55` captures the actual command status and propagates it through the logging pipeline. The helper builds before testing and stops on a failed build (`scripts/forge-artifacts.py:394-400`).

| Check | Compiler/build outcome | Actual execution outcome |
| --- | --- | --- |
| Focused, 16:29:39-16:29:46 UTC | 107 build roots, 586-source closure, 104 runtime IDs; 35 files compiled successfully with Solar, then 7 test files successfully compiled (`P/focused.log:11-19,2852-2854`). | Independently counted 7 successful suite rows and 24 `[PASS]` records. Final summary and `COMMAND_EXIT=0`: `:2913-2915`. 0 failed, 0 skipped. |
| Broad, 16:30:09-16:31:40 UTC | 265 build roots, 1,253-source closure, 276 runtime IDs; current artifact build skipped unchanged compilation, then 678 test files compiled successfully with Solar (`P/broad.log:11-17,7617-7619`). | Independently counted 589 successful suite rows and 9,932 `[PASS]` records. Final summary and `COMMAND_EXIT=0`: `:25924-25926`. 0 failed, 0 skipped. |

Focused tests overlap broad tests; the two totals must not be added as distinct coverage. Neither command used a `--match-test` selector filter. The broad helper's path filter explicitly selects the two requested trees; real per-suite/pass rows rule out a no-tests exit-0 false pass.

Raw log SHA-256:

```text
focused.log e33453a4402d890963bae08b66e2644e1be05dc3e8eb52678c4e713031a047bd
broad.log   312e69ba69a60d6db1534b90a13d4b6946e8797e410248a7e6056817da3d86b2
```

The compiler evidence is Forge `1.9.1-nightly`, commit `430523103f3e2f9ba432ffdd2031a9f966153d0d`, built `2026-11-03T06:12:02.538056000Z`; commands explicitly use `--use solar`. Actual artifact compiler metadata is `0.8.38+commit.e7a91fc7.solar.0.3.0-dev`, consistent with the logs' `Solar 0.8.38`. This is not relabelled as the unchanged configured solc version. No via-IR flag or configuration change was introduced.

### 7.2 Independent artifact checks

For each of the five source files I read the actual file, computed SHA-256, and executed `/Users/cyotee/.foundry/bin/cast keccak` on its exact hex-encoded bytes. All five Keccak results match the recorded source manifest. I then read and parsed the current artifact JSON, checked nonempty creation/runtime code, target/compiler metadata, and the relevant metadata source hashes.

| Current artifact | Creation/runtime bytes | Independently calculated SHA-256 |
| --- | --- | --- |
| `out/UniswapV4DetfDFPkg.sol/UniswapV4DetfDFPkg.json` | 17,128 / 16,298 | `12d7e10da4040c1b8dab6b6cfdd0f09f30b26396930af7d0ea924b64459a420c` |
| `out/UniswapV4DetfBondNFTVaultFacet.sol/UniswapV4DetfBondNFTVaultFacet.json` | 8,744 / 8,726 | `14b3b52e2c5fe4109691cb0607a81b8ff9479e409079c25adc51ce11c89da669` |
| `out/RebasingClaimTokenFacet.sol/RebasingClaimTokenFacet.json` | 6,115 / 6,097 | `a059fd6fca4d75e40f5683a1d46148ccd876c383ecb5a85d79210cfa5c745f32` |
| `out/DETFNFTVaultFacet.sol/DETFNFTVaultFacet.json` | 8,732 / 8,714 | `ac747ced538a6dde143ba8cb30ed9d7551d32a8b891a923c926a14adb56efcd5` |
| `out/UniswapV4Detf_Deploy.t.sol/UniswapV4Detf_Deploy.json` | 127,225 / 127,155 | `5d8474f9087b19f417f8720133e5f00fcf86b2564d1154d5542cad8c62e48939` |

The package metadata binds both changed initializer/package sources; both bond facets bind the changed funded target; the receipt facet binds the changed staking target. The deployment-test artifact also binds the exact changed test source, adding a check not present in the original artifact-audit table.

All nine production artifacts inspected, including the five ordinary parent facets, are byte-for-byte hash matches to `P/artifact-bindings-success.log`. Their full results are in `V/verification-receipt.json`. The four artifacts in the table above have no external-library link references, and none exposes a new internal dispatch name in its ABI. The package ABI still includes `ThresholdsConfigured`.

These are the artifacts actually selected by the fixture's production deployment helpers: `D/UniswapV4Detf_Pkg_FactoryService.sol:16-30` and `C/factory/DetfFacetFactoryService.sol:47-70`. Fresh hermetic deployment loads current local creation code; reusing an occupied address is not an upgrade. The same-args test specifically preserves existing code/state and is not used as evidence of replacement.

## 8. Diagnostics, limits, and required-check disposition

Fresh `lsp_diagnostics` requests with severity `all` returned:

- No diagnostics for all four changed production files.
- `warning[solar] (2018) at 49:4: function state mutability can be restricted to view` for the deployment test. Its unchanged original inert-state test is the warning location; no suppression or unrelated edit was made.

One `_calculateClaim` reference request at bond-target line 146, character 15 returned `LSP request timeout (method: textDocument/references)`. Direct source inspection and a bounded text search then located the implementation and both consumers. The timeout is not represented as a successful semantic-reference census.

The JSON receipt's patch-time diagnostic reported `Command not found: biome`. No server was installed or configuration changed, consistent with the user's prohibition. The receipt was generated with `JSON.stringify` and its constructed JSON parsed successfully; no Biome diagnostic pass is claimed. Solidity compiler/lint warnings remain visible in the original raw logs.

| Required check | Disposition |
| --- | --- |
| Complete five-path diff/new-source review | Complete; no scope or semantic deviation found. |
| Initializer order, guards, defaults, routes, dependencies | Complete source trace plus current-source-bound real-proxy passes. |
| Exact funded creation and preview/execution dispatch | Complete source trace plus paid-bond, linear-claim, exact-gons, and retirement witnesses. |
| Resolved fee/creator owners and distribution/top-up order | Complete source trace plus independent arithmetic and role-transfer witnesses. |
| New tests observe state/wiring; old assertions retained | Complete; all three additions retained and original bodies byte-identical. |
| Artifact-first focused and broad execution | Valid existing Solar results independently accounted for; no runtime rerun required. |
| Current source/artifact binding and no occupied-address upgrade claim | Complete for the inspected package/facets and deployment-test artifact. |
| Failure accounting | No failing test in either prescribed run; no attributable unaddressed compile/test failure found. Known warnings and prior corrected tooling failures are not test failures. |
| Full release, pinned legacy fork, Migration runtime acceptance | Not claimed or run; outside this bounded increment. |

The accepted evidence is bounded to the recorded source hashes, current artifacts, and prescribed scopes. It is not a whole-system security certification, a gas-feasibility proof for recovery routes, or a completed Migration implementation.

## 9. Owned writes and cleanup

Only these two verifier-authored files were created, both with `apply_patch`:

```text
docs/incidents/2026-09-16-dtf-recovery/migration/package/evidence/preparation-verification/report.md
docs/incidents/2026-09-16-dtf-recovery/migration/package/evidence/preparation-verification/verification-receipt.json
```

No task-owned temporary directory, node, listener, RPC client, worktree, build/test process, or long-running command was created. All finite Git/cast probes completed; no owned process remains pending and no cleanup command is necessary. Tool-managed LSP/session resources were not killed or treated as owned resources.

Root's `PACKAGE_WARM_SEED_READY` exit-0 confirmation was supplied in the assignment. I did not reseed or compile. Final resource inspection confirms the worktree still has its `out/` and `cache_forge/` directories and its pre-existing `node_modules` and `lib/crane` symlinks to the main checkout. No shared dependency, warm cache, upstream report, or other lane's file was modified or deleted. The egress lane's new `evidence/egress/results.md` appeared during this review and was preserved.

The implementation lane's own cleanup receipt was read separately: `P/cleanup.log:1-13` records its `rmdir` exit 0, absent failed-launcher PID, and preserved cache/dependency paths. This verifier did not repeat that cleanup or remove the shared parent temporary root.

## 10. Final disposition

**AdversarialVerify: confirmed.** The bounded increment satisfies handoff sections 5.1, 5.2, and 6 with current-source evidence. The decision is to accept the already-valid focused/broad passes after independent binding and semantic review, rather than rerun valid tests or broaden into unresolved Migration behavior.

No owner policy was chosen, no production/test fix is requested for this increment, and no task-3/task-5/E4/E5 closure follows. The ordinary extraction is ready for root's separately controlled next step; pricing, legacy attribution, pooled-genesis authority, and final receipt/SY composition keep their existing independent gates.
