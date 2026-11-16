# Resumed Migration deployment-gas correction

Date: 2026-11-13. Worktree: /Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-30-recovery-receipts.
Base: 1694e68a4bd66dd67d3b5e3f145f1da23074ff48, plus the existing current uncommitted product work.

## Result and qualification

The current package successfully deploys TWO distinct real manager-registered Migration instances with the reviewed argument-bound bond-plus-two-SY preparation. Every preparation and final transaction has an explicit 32,000,000-gas envelope and a status-1 receipt. No transaction-cap increase, size-check exception, viaIR, feature deletion, mutable staged parent, executor or new authority was used.

The scoped spec run passed 199/199. The pinned Migration fork run passed 164 and failed one existing donation-floor assertion. A controlled artifact-first run with the exact captured pre-change package/interface/FactoryService/TestBase reproduced the IDENTICAL failure, including both compared integers. The test and economic code were not changed. The corrected four files were then restored byte-for-byte, their concrete artifacts rebuilt, and all 13 deployment-gas/safety cases passed again. The restored executable package bytes exactly equal the bytes used by the successful mined receipts. Thus the local gas correction is verified, but the full Migration fork suite is not green. No broader release or independent-verifier acceptance is claimed.

## Actual gas and instance bindings

All values below are actual receipt gas, not Forge estimates or nested-call budgets.

| Instance | Preparation envelope | Preparation used | Final envelope | Final used |
| --- | ---: | ---: | ---: | ---: |
| First | 32,000,000 | 19,746,568 | 32,000,000 | 29,858,973 |
| Second | 32,000,000 | 19,595,700 | 32,000,000 | 29,297,677 |

| Operation | Transaction hash |
| --- | --- |
| First preparation | 0x9b4cdd6dfb2a247d121fed9ddfda428286de89a9dfb5d4ffb30d9e28bf829fea |
| First final | 0xcc6d1011e02b3ea44222c01abbca5729c65c9e650bb4300bc2c78083108c5b11 |
| Second preparation | 0xe17ba9565e77b30ad9b56189734f0e103635aa317f6c39f56d9f56caf6634b82 |
| Second final | 0x053896daa6981e891fae3e5d4b912180b28b381b25a14be3559867d278f677b7 |

The 242-transaction construction sequence succeeded in full, each with the same 32,000,000 envelope and a bounded eth_call before submission. The maximum prerequisite gas was 11,862,619. Registered SY and parent package deployments used 5,635,270 and 6,799,941 gas respectively. Explicit evm_mine synchronized receipts, with canonical block/transaction checks and no receipt polling. The final transactions retained 2,141,027 and 2,702,323 gas of envelope headroom; this is not a promise for arbitrary larger route/metadata inputs.

| Binding | First | Second |
| --- | --- | --- |
| Initial owner | 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 | 0x70997970C51812dc3A010C7d01b50e0d17dc79C8 |
| Parent | 0x23E7D9ab48812f3e47aC64078D653EEdeda6dA5B | 0x922e83dCCd1b23d33ddd3ac621B1ECE301F1cD13 |
| Hook | 0xEA48fE818E5e7bE3107852C0B75d2A1799CB2Aa8 | 0x5C066F349b73AB2b857Ee06f45542d0AC85baAa8 |
| Bond | 0x9bC2F9d13ad7facA1E1993052D24E3013Ab4614B | 0x370FE5C17615150EB67876AaAee0B176F2ad6543 |
| Receipt | 0x46058e46913479D889b158a0F4339758CbFD0700 | 0xD16d08bbc18EE4425BDBd6B90476791C4aC95758 |
| Raw SY | 0x3263494F8C3E2118EaE755AdBBE1508B80203755 | 0xeb548a540e1CC0A1F656fFb1F09CE5C16273Aa02 |
| Staking SY | 0x0c0e015506730e00E52B106d761b1871540c429B | 0xfE71249411e9f128a3Dcc413da67c8452c15660F |
| RT | 0x52b8131AcD0Fae4bfAC28C7940d5037AF50D6A84 | 0xEB6Df6b50bF897362B6A4F657F990Ddd135c964A |

Shared current parent package: 0x61ea4165547b0a67ee98556be00722eb18aa80a2. SY package: 0xb61ba6993373935f896F314c2509eD6148bDF61D. Manager: 0xd9482CBC427879a2f21A09F2583e76dCDE1d8761. Callback factory: 0x96c4CA2Be7e62807c704bd731b3C03d9aA11fA88.

The owned local historical fork was chain 4663, RPC/L2 block 108944663, hash 0xc497433dd691a40cb85959cfeba2e3fff85a975ae060612d984998e1d5765733, port 18561. The historical 32-million transaction limit is preserved phase09 evidence, not a newly asserted live-chain quote. Anvil's larger block/aggregate script allowances were never substituted for actual transaction bounds. EIP-170 stayed enabled. External contribution currencies in the receipt witness are genuine mintable/WETH fixtures; the parent, hook, SEs, registry, fee oracle, packages and children are production contracts. This is not approved financial funding or compensation data. Actual legacy-source behavior is covered by the current pinned fork suites.

## Changed source paths

Only these nine source/test/witness paths are delivered, relative to the current worktree:

- `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationDFPkg.sol`
- `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/interfaces/IUniswapV4DetfMigrationDFPkg.sol`
- `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigration_Pkg_FactoryService.sol`
- `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/TestBase_UniswapV4DetfMigration.sol`
- `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/sy/IUniswapV4DetfMigrationSYDFPkg.sol`
- `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/sy/UniswapV4DetfMigrationSYDFPkg.sol`
- `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationDeploymentGas.t.sol`
- `test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationDeploymentGas.t.sol`
- `scripts/foundry/recovery/dtf-migration/MigrationDeploymentGasResumedQA.s.sol`

The added SY package/interface are the reviewed Migration-only construction composition. Existing ordinary/common/Crane production and config/dependencies were not edited. The current claimVaultAllocationFacet dependency, 15 parent package facets, 156 deployed parent selectors, E-S implementations, NFT 3 two-bond behavior, conserved claimed-SY remainder and paid-owner-first-bond gate remain. No historical phase09 report or source was edited. An initially ported unused old witness was removed; the delivered witness is MigrationDeploymentGasResumedQA.s.sol.

## ABI and staging design

The exact compiled ABI and initial creation hashes were delivered early in staging-abi.json and staging-abi.md. PkgArgs is unchanged. Use the registered Migration SY package as parent PkgInit.baseInit.syPkg, retaining the current claimVaultAllocationFacet field.

Call parentPackage.prepareSyChildren(fullArgs), selector 0x8bda137c, then parentPackage.deployVault(the identical fullArgs). The preparation's historical name covers the unreserved bond plus both SYs. No new selector is installed on a parent or child proxy. The construction ID is keccak256(abi.encode(block.chainid, parentPackage, fullArgs)), including the actual hook. Parent prediction keeps the existing salt with only baseArgs.hook cleared. Child argument hashes use keccak256(abi.encode(childArgs)).

Parent queries: syConstruction(args), syPackage(), preparationDependencies(). The SY preparation(bytes32) tuple is parentPackage, constructionId, parent, bond, bondPackage, bondArgsHash, receipt, rawSy, stakingSy, rawArgsHash, stakingArgsHash, completed. Other queries/validators are documented with full schemas in staging-abi.json.

Resume against actual factory package/full argument records, not only a predicted address or a journal flag. A helper call with a different hook payload cannot misreport an existing parent. Exact existing-parent reuse is not fresh construction, and preparation rejects any already constructed parent.

## C1-C6 construction preservation

- C1: complete chain/package/argument commitment; actual hook retained in the commitment; unchanged hook-cleared prediction; permissionless preparation does not grant preparer authority or reserve a parent address.
- C2: canonical bond metadata/LP, receipt identity and directional ordered SY routes derive from actual immutable dependencies. Explicit metadata/custom-direction cases pass. Receipt/RT creation remains final.
- C3: SELF-held immutable records and child authorizations are explicitly queried across delegatecall contexts. Preparation authenticates the registered calling parent and selected SY dependency. Its lock covers bond and both SY constructions; completion is written only after all validation succeeds.
- C4: children are fully initialized and hook-free, not mutable shells. Bond roles/positions/principal and SY supply/booked backing remain empty before parent creation. The common receipt initializer and all economic facets remain unchanged.
- C5: finalization reuses the registered bond, initializes reserved IDs, creates receipt/RT, resolves registered SYs, validates reciprocal links and publishes the completed parent atomically. No initialized parent survives a failed final transaction.
- C6: explicit reuse checks cover actual factory arguments, canonical identities, registry membership and ordered Add/Replace selector ownership. Exact predeployed bonds are adopted. Alternate hook preparations coexist without poisoning. No package callback can restore removed activation selectors.

## Executed G1-G8 evidence

| Gate | Current evidence |
| --- | --- |
| G1/G2 | constrained-receipts.json, all-transactions.json and trace-224/225/240/241.json contain complete actual envelopes, calldata, receipts, canonical blocks and local call trees. Both distinct instances succeed, using the same global factories/packages. |
| G3 | All argument mutation, owner/chain/package context, bond LP/name/symbol, SY mode/parent/receipt/routes, canonical-byte, direct initialization, unprepared registry and alternate-hook tests pass in MigrationDeploymentGas.t.sol. The original first two bounded tests are byte-identical to preserved phase09. |
| G4 | construction-state.json records parent/receipt absence, absent parent discovery, completed prepared records, zero bond next ID, canonical child validation and zero SY backing slots. Real early bond/SY economic, claim, transfer, donation, approval, unsolicited-asset and initializer tests pass without custody/rights or a finalization veto. |
| G5 | Passing tests force fresh/preexisting-bond preparation rollback, second-SY failure, final failure after roles and at publication, registry disable/re-enable, exact retry and real static external-token callbacks at both boundaries. No SUT is mocked or storage-injected. |
| G6 | Each actual parent passes 114 registry memberships and all 156 selector owners/declared interfaces. Full factory arguments, exact five-child links, reserved-role validator, initial zero supply, 9-decimal parent/receipt/SYs and 27-decimal RT are checked. |
| G7 | The 199 specs and 164 passing pinned cases execute current funding/snapshot, configured wallet/source conservation, fresh exact funding, two-original NFT 3, late surrender clocks, principal/rewards, owner and activation behavior. Supplemental local lifecycle receipts independently execute funding/capture, nonminting configuration, two 1,212,032-unit funded bonds (IDs 3/4), required paid owner bond 5, mature Stage1 principal, reward closure, current/pending/former-owner boundaries, activation and all 16 administration-selector removals. Postactivation exact reuse/initializer/update/callback negatives cannot restore them; reward claiming still works. The one independently reproduced pre-existing fork failure remains disclosed below. |
| G8 | source-artifact-runtime-bindings.json verifies 290 compiler source hashes and 29 populated runtimes: two packages, 24 distinct facets and three recursively linked libraries. Actual package deployment bytes match Solar artifacts. Restored artifacts match mined bytes. Cleanup and preserved worktree boundaries are recorded separately. |

Supplemental lifecycle execution has 13 successful and 10 deliberately reverted, zero-log transactions. The historical default dev recipients 0x7099... and 0x3C44... carry delegation code at this pin; their NFT receiver callback correctly fails atomically. That actual negative receipt and local trace are retained. Subsequent synthetic issuance uses two verified code-empty local recipients, with narrowly scoped native funding and impersonation; every impersonation ended. No legacy/SUT bytecode or token storage was replaced.

## Known pre-existing limitations

1. Full fork suite: MigrationRecoveryDonation.t.sol:test_actualRecoveredDtfDonationProtectsUnrelatedInventoryAndBacking fails at the before-minus-donation floor assertion: actual 592832391166386209565 versus expected lower bound 592832391166417981558, difference 31,771,993 raw18 units. The unchanged test on the captured pre-change package reproduces exactly. preexisting-fork-failure-control.json records the command/output and exact four-file restoration. No weakening, skip or economic fix is included. The baseline and current suites are therefore not reported as fully green.
2. Registry token-array convenience queries: the published contents ID appends hook after the sorted hook tokens, while the convenience query sorts the complete array. All stored discovery memberships pass for both parents, but vaultsOfTokens returns empty for the second parent and contains the first. This is the preserved shared-code discrepancy, not an omitted publication index. Shared-source correction is outside this lane.
3. JSON LSP is unavailable because Biome is not installed. Evidence is generated from parsed JSON/ABI values; no dependency installation was attempted. Solidity diagnostics on changed files were clean; baseline restoration temporarily produced diagnostic freshness timeouts, resolved by the subsequent successful compilation and exact-byte checks. Existing Forge warnings remain visible.

## Commands, corrections and cleanup

Compiler: Forge 1.9.1-nightly, commit 430523103f3e2f9ba432ffdd2031a9f966153d0d; Solar 0.8.38+commit.e7a91fc7.solar.0.3.0-dev. All compiling commands use --use solar, directly or through the artifact-first helper. No cache deletion/copy, profile-path change or compiler fallback occurred.

- Artifact-first full Migration spec run: exit 0, 199 passed.
- Artifact-first full pinned Migration fork run: exit 1, 164 passed and the single baseline failure above.
- Captured pre-change package control for that unchanged failure: exit 1, identical failure integers.
- Restored current artifact-first deployment-gas safety run: exit 0, 13 passed.
- New current witness artifact build and final script simulation: exit 0. Its generated transaction estimates are not receipt evidence.
- git diff --check: passed; no commit, merge, push or public transaction occurred.

The first ported callback fixture used an absent old nested OZ import; it was corrected to the existing vendored Crane external ERC20 source, without dependency changes. The first witness attempt exhausted its enclosing 100-million script budget; the repository's normal aggregate simulation budget was used instead, with all actual transactions still explicitly capped at 32 million. A subsequent historical feeHistory lookup was unavailable; the documented local-only legacy 2 gwei fee policy avoided that lookup. No refused historical trace was retried. ABI serialization was corrected to use component-aware tuple/array conversion, retaining empty/singleton arrays rather than mislabeling them as objects. None of these harness corrections changed the production behavior or accepted a failed bounded deployment.

The owned 18561 Anvil was stopped. kill_bash reported EPERM unlinking terminal monitor metadata, then delivered killed/exit 1 for the node; the independent port check records the actual listener state. All compiler/test/script commands ended. Port 18579 was not used. Warm out/cache_forge remain. The permitted temporary lib/crane/lib/forge-std/src symlink points to the primary checkout and is intentionally left for parent cleanup. Populated lib/crane was not replaced.

## Remaining parent integration

1. Deploy/register the new SY package through Packages.deploySy and select it in current parent initialization. Use the exact current PkgInit ABI, not the historical six-field Migration extension.
2. Add preparation/final operations and exact state reconciliation to parent-owned operator TypeScript/Phase_08_Stage_01/runbook, enforcing <=32,000,000 on simulation, estimation and signed/resumed intents.
3. Phase_08_Stage_00_OperatorEnvironment's simulation-only deployVault call also needs simulation-only preparation first. It was deliberately not edited here.
4. Keep the pre-existing donation assertion and token-array discovery discrepancy visible; neither is silently repaired by a deployment-gas release. Remove the temporary forge-std/src link when the parent no longer needs it.
5. Independent replay/review, operational datasets, live deployment/funding/activation and any source commit remain separate parent decisions. This result authorizes none of them and does not close unrelated full-plan/category gates.

Decision settled: reuse the reviewed fully bound bond-and-two-SY preparation, with atomic complete final publication. Rejected: the historical insufficient two-SY/bond-only splits, parent staging, skipped children/indexes, arbitrary executors, cap increases or weaker checks. Assumptions are the current immutable configured dependencies, ordinary EVM rollback and the stated local historical-fork fixture; there is no trusted preparer role.
