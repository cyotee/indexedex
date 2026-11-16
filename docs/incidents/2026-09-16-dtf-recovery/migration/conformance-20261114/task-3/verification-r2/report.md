Independent task 3 verification, round 2, November 15, 2026.

**Verdict: confirmed. Failure class: none. Confidence: 0.95.** This confirms plan task 3's authenticated source and recovery evidence indexes. No unresolved actual source, custody or conservation fact was found within that scope. It does not certify later manual-pricing, two-bond NFT 3 implementation, operator, gas or whole-tree obligations.

The final producer claim was treated as untrusted. Its raw SHA-256 is `5d50fc0b157e2e1a968c5cb3d8a85752eb10a0bc6a00371159f3a71a7fd04ea4`. This review independently read the four indexes, raw archives, deployed source excerpts, recorded commands, complete suite output and assertion bodies. No fixes, delegation, Forge, RPC, installation, commit or public transaction occurred. Only this report, hash-recompute.json and the final round-2 verdict are created.

Manual QA: **PASS**. `hash-recompute.json` records 38 archive-binding comparisons covering 37 unique raw files, with zero missing files and zero mismatches. It also records all 14 row joins, 34 independently recomputed EVM runtime hashes, source-file bindings, historical baseline resolutions, the malformed descriptor comparison and worktree preservation. SHA-256 was computed from raw file bytes, never tool rendering or reserialized archive JSON.

All four indexes contain the required fourteen rows. All 118 manifest ABI pointers resolve; callable selector hashes agree with their schemas, and delegated facet identities agree with archived loupe observations and separately hashed runtime bytes. The two absent TokenStaking delegations are explicitly absent routes, not unidentified callable facets. Shared 370-byte proxy code is never substituted for facet identity. Each row supplies ownership/unit reads, original and remaining units, equations, disabled behavior, surrender/rollback witnesses and conditional recovery.

The following references identify individually named cases within the exact suite sections of the complete raw logs. S denotes `conformance-20261114/task-3/source-state-assertions.log`; H denotes `final-fork-20261113/03.log`, both relative to migration/.

| Required row | Routes | Positive / rollback raw lines | Source and recovery conclusion |
| --- | ---: | --- | --- |
| Weighted fixed-principal NFT | 14 | S:5801 / S:5802 | Native9 principal minus claimed principal; rewards do not become principal. |
| Earlier LP-lock NFT | 11 | S:5794 / S:5797 | Original accounting shares, distinct from reward weight and physical LP; disabled recovery remains conditional. |
| Weighted DETF | 6 | H:4903 / H:4901 | Exact native9 debit/custody delta and proportional frozen credit. |
| Earlier DETF | 8 | H:3510 / H:3508 | Native18 units; conditional conversion uses E-P with ED input. |
| Weighted receipt | 9 | H:4913 / H:4912 | Eligible gons; synchronize before baselines and preserve unrepresentable/unbooked residue. |
| Earlier receipt | 15 | H:3521 / H:3523 | Internal shares; endpoint floors and E/R/B buckets remain distinct. |
| Static SY | 9 | H:4932 / H:4931 | Static native9 shares; measured redemption output and backing are separate. |
| Direct claim-vault rights | 9 | H:3562 / H:3561 | Native19 direct shares with measured SY output, separate from TokenStaking infrastructure. |
| W-SD | 5 | H:4940 / H:4939 | Native28 shares; actual native18 DTF output is measured. |
| W-SW | 5 | H:3590 / H:3587 | Native18 SE shares; registry enablement is an external prerequisite. |
| E-S | 5 | H:3552 / H:3547 | Paid acquisition, external enablement and non-dust output are explicit. |
| W-P | 5 | H:3576 / H:3573 | Physical native18 LP; current-fee-recipient exit exception is conditional. |
| E-P | 8 | H:3539 / S:5787 | Physical native18 LP; authenticated current surface supports permanent protocol custody. |
| TokenStaking prepared remainder | 9 | H:4926 / H:4923 | Prepared original/remainder weights produce measured eligible SY; later rollback cannot restore prior source consumption. |

Runtime recovery uses chain 4663, block 108944663, hash `0xc497433dd691a40cb85959cfeba2e3fff85a975ae060612d984998e1d5765733`. Weighted NFT journal /rpc/550 is a later local code observation; its bytes were compared to the genuine pinned eth_getCode at /rpc/2, with chain/header reads at /rpc/0 and /rpc/1. They are identical. Weighted receipt /rpc/44 is pinned directly. Earlier receipt code is in `evidence/earlier-cp/probe-alchemy-retry.source.json#/proxies/0x4ac89ad061a531fa62ddceed53520c2750113b01/code` at 0x67e5d17; its independent receipt identity header has the same block/hash. All three formerly null hashes are recovered from raw bytes.

Earlier IDs 0, 1 and 2 are reserved protocol, fee-recipient and creator positions. The runtime-bound archived DETFNFTVaultFacet.sol constants at 1353-1356, initialization at 16262-16321, and reward-only additions at 16473-16483 were read directly. The pinned raw `source-reserved-complete.log` records reservedBondNftsWired=true, the same facet, the exact three owners and full position tuples. ID 0 has original/effective shares 30553440974423605336759687659017983; IDs 1 and 2 have zero original shares and nonzero reward weights.

The separate ordinary ID 3 acquisition has transaction `0xc0a74f69a4a58540168c070968bb8f2d13759195e4ccabfe469ba3ad3d3d1c75` and canonical block hash `0x65a15c810d06ad9ddae29959c2b5917e5c4ba3f8ef3180b01d85566000f75b3a`. No role conclusion uses Migration's tokenId < 3 guard or the new child. Exact reserved mint receipts remain unrecovered, explicitly documented as a provider range-limit failure. That absence supplies no wallet-wide no-exposure conclusion and hides no source/custody gate.

E-P custody is supported by the exact withdrawal facet `0x81fb72511016b42437fe1ac2d5bdb0ba82f14a35`, keccak256 `0xca224a1792b0b9339c1c5c999c4d5e99bd33f25f8387da864d6eabb4d1d6b398`. Its raw archived source at 7632-7639, 14414-14416 and 14724-14751 connects the owner guard to all three withdrawals. The live owner is the earlier DETF.

Parent source at 24999-25014 restricts claimLiquidity to its NFT/receipt/self callers and recorded custody; 25106-25123 and 25862-25866 bind accepted intake. NFT source at 16206-16214, 16463-16490 and 16693-16697 restricts creation, principal changes and forwarding. Collector source at 5019-5045 synchronizes reserves or transfers its own fees under onlyOwner. These routes supply no Migration-authorized arbitrary-LP exit. The raw negative case also rejects after an actual fork fee-role change, a year advance and external enablement, while preserving LP holdings and supply. Archive paths and exact runtime joins are retained in `recovery-authority.json` and the independently recomputed hash table.

W-P alone uses the different deployed facet `0x1b7a7bc9044642c4e42e64f805f6400d75ad2c16`, hash `0xe5f44175a8c16c705c2c9e5e68b2c3efe842ce694c5e585d2211947802b10d84`. Its archived UniswapV4HookOwnerOnlyLiquidityLib.sol:18-26 admits the actual current fee recipient. The conditional successful exit appears at S:5788. Disablement, dust and absent reward income remain availability conditions for other rows, not permanent-inability claims. No general future-market impossibility is inferred.

The accepted command is `commands.json` run id `source-state-assertions`. Removing only shell quoting, output capture and environment-isolation setup gives the required invocation:

```bash
FOUNDRY_PROFILE=fork python3 scripts/forge-artifacts.py test contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/legacy/MigrationLegacyNftLib.sol --test-root test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationLegacySources.t.sol --test-root test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationLegacyLpExit.t.sol -- -vv
```

It was **not rerun**. The full 395748-byte raw log has SHA-256 `db83a11664e756927aa1530a881ccb65efc265054c12029e162776f9676ce063`. The command record captures exit 0; the raw log contains 2 LP-exit cases and 11 source cases, 13 passed, 0 failed, 0 skipped. Lines 1-3 show the artifact helper's build/test commands, line 14 records unchanged production compilation, and 5782-5784 compile the changed test with Solar before the named cases.

The scoped fingerprint identifier is `5c9111e657d552eb95054c24912dad33af16cf5ae59946a3f075162fdcfdded8`. All 50 constituent file SHA-256/size bindings match current bytes. The record does not specify the aggregate serialization preimage; this review does not claim to have reconstructed that aggregate algorithm. The complete constituent bindings, command, raw log and exact test bodies provide the source binding.

Wrong wallet at S:5802 binds MigrationLegacySources.t.sol:16-29. Invalid/burned/reserved/nonexistent IDs at S:5792 bind that file's 178-207. Both use MigrationNftForkBase.sol:213-220 to check unchanged ownership, consumption, custody, supply, total gons, backing and allowance. E-P unauthorized exit at S:5787 binds MigrationLegacyLpExit.t.sol:38-90 and its exact unchanged LP balance/supply assertions. `source-negative.log` is a composed commentary excerpt and supplies no independent acceptance.

Other rows reuse the source-bound historical run with actual exit 0 and named cases in H. Historical source replacements match `final-source-20261113.json`. Weighted-liquid, weighted-receipt, claim-vault and DTF-custody test sources omitted from that replacement snapshot match its base commit `1694e68a4bd66dd67d3b5e3f145f1da23074ff48` by raw git show comparison. The modified MigrationLegacySources test uses the current accepted run instead. No historical output is presented as a fresh run or proof of the later two-bond NFT 3 change.

The malformed descriptor probe is evidence review, not a new test. Only runtimeCodeHash differs between the retained descriptors. Independently serializing them with two-space JSON plus newline reproduces original SHA-256 `6f28e0381759a6daeaa2bb3e2fc1e3738fd9321e41073ec70b2de6e14204d318` and wrong SHA-256 `35ebda36dba95b2a5d983814de51b12a2cf2aee59105d56f505cad2df79d0b76`. The first matches the inventory; the second fails it.

The retained helper command exited 1, its raw log names stale source inventory, and `integrity-negative/delivery.json` has completed:false and the same failure. Inspection of record-verification.ts:232-241 and 281-294 confirms that the helper detects changed bytes and sets exit 1. It is not an EVM hash validator. Separately recomputed keccak256 rejects the zero runtime hash, and the original archive's raw SHA-256 matches. No archive was modified.

| Adversarial class | Result | Observable result or applicability reason |
| --- | --- | --- |
| stale_state | PASS | All three current index hashes differ from preserved baselines. The preliminary needs-fix verdict applies to the initial blocked claim and supplies no current acceptance. |
| dirty_worktree | PASS | Read-only before/after status is byte-identical: 60373 entries. P diff, 4023 task-2 status entries and seven protected file hashes remain unchanged. |
| misleading_success_output | PASS | Complete raw log, command exit and named cases were inspected against actual assertions. Composed source-negative.log and acceptance_met were not result oracles. |
| generated_or_cached_artifacts | PASS | Raw output records Solar build before test and compilation of the changed test. All 50 scoped file hashes match; historical replacement/base sources were reconciled. Mere out/ existence is not used as proof. |
| untrusted_external_text | PASS | Archive, Markdown, producer claims and prior verdicts were treated as evidence only. No embedded instruction was executed. |
| malformed_input | PASS | Exact descriptor hashes independently reproduced; wrong runtimeCodeHash produces the retained helper's exit 1 and incomplete receipt. Archive remains unchanged. No fresh helper run. |
| cancel_resume | PASS | All 27 structured final claim file bindings match final bytes, including amended indexes, observations and the preserved concurrent claim. |
| hung_or_long_commands | not applicable | No Forge or long-running process was started or rerun during verification. |
| flaky_tests | not applicable | No test rerun was performed; repeatability beyond the retained run is not claimed. |
| repeated_interruptions | not applicable | No repeated interruption was introduced or observed in this verification pass. |

The read-only before/after git status commands both exited 0 and produced identical SHA-256 `36026f9809b52fe440ff2aedf12f47aadc100e50a5045907057732a2f78c360b`. P's diff hash stayed `928269f94a952b9db2e882bed9e773343ebd6d5abd8e895522acdd65a0130536`; all 4023 task-2 status entries remained. Full status was compared in memory rather than copied as a multi-megabyte artifact. The hash report records the counts, equality, zero added/removed entries and protected-byte comparisons. Evidence output is additive after that read-only boundary. This is not a clean-tree claim.

Reproduction is read-only: load source-observations.json, compute SHA-256 on every archiveBindings/liveEvidenceBindings path plus acceptedSourceQa.rawFile and historicalSourceFileBinding, compare bytes and hashes, follow each source runtime/loupe pointer, and recompute keccak256 from raw code. Match named cases to exact suite sections and cited source assertions. Use the saved commands.json execution result; do not rerun Forge for this evidence review. Compare the final claim bindings with current indexes rather than baseline copies or the preliminary verdict.

Known limits are explicit: exact reserved mint receipts are unavailable; no exhaustive operational exposure/allocation dataset is supplied or inferred; external enablement, reward income and the W-P fee-recipient role remain prerequisites. The original combined weighted NFT 3 test is source evidence only, not proof of the later two funded bonds. Historical warnings include failed dependency auto-install attempts and Foundry/lint warnings; they remain alongside the successful command result. JSON output is serialized from structured data. Biome LSP is unavailable because its command is not installed; no installation was attempted under the verifier constraints.
